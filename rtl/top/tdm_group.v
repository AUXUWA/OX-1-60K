// tdm_group —— 一组 TDM 的完整边界封装 —— 1 份 FM 算核 + 组边界 + 输出（B7）

module tdm_group #(
    parameter integer N_VOICE = 1,
    parameter integer N_GROUP = 1,
    parameter integer N_CORE = 1,
    localparam integer N_VPG = ((N_VOICE / N_GROUP) < 1) ? 1 : (N_VOICE / N_GROUP),
    localparam integer N_VOX = N_GROUP * N_VPG,
    localparam integer V_W   = (N_VOX <=  2) ? 1 :
                              (N_VOX <=  4) ? 2 :
                              (N_VOX <=  8) ? 3 :
                              (N_VOX <= 16) ? 4 :
                              (N_VOX <= 32) ? 5 :
                               (N_VOX <= 64) ? 6 :
                               (N_VOX <=128) ? 7 : 8,
    localparam integer VW8   = (V_W > 8) ? V_W : 8
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,

    input  wire               reg_we,
    input  wire [7:0]         reg_addr,
    input  wire [7:0]         reg_wdata,

    output wire signed [15:0] out_l,
    output wire signed [15:0] out_r,

    output wire               sel_hit,
    output wire [7:0]         sel_grp,
    output wire [7:0]         sel_vpg,
    output wire [7:0]         sel_first_voice,
    output wire [7:0]         sel_last_voice,
    output wire [7:0]         sel_first_slot,
    output wire [7:0]         sel_last_slot
);

    localparam integer N_SLOT  = 4;
    localparam integer N_SLOTS = N_VOX * N_SLOT;
    localparam integer N_SLOTS_PER_CORE =
        (N_CORE < 1) ? N_SLOTS : ((N_SLOTS + N_CORE - 1) / N_CORE);
    localparam integer PRE     = 3;
    localparam integer GRP_MAX = (N_GROUP > 16) ? 16 : N_GROUP;

    function integer grp_first_voice(input integer g);
        grp_first_voice = g * N_VPG;
    endfunction

    function integer grp_last_voice(input integer g);
        grp_last_voice = g * N_VPG + N_VPG - 1;
    endfunction

    function integer grp_first_slot(input integer g);
        grp_first_slot = g * N_VPG * N_SLOT;
    endfunction

    function integer grp_last_slot(input integer g);
        grp_last_slot = grp_first_slot(g) + N_VPG * N_SLOT - 1;
    endfunction

    wire [3:0]     eng_vpage;
    wire [7:0]     sel_vno8  = {eng_vpage, reg_addr[3:0]};
    wire [VW8-1:0] sel_vno_w = {{(VW8-8){1'b0}}, sel_vno8};
    wire [V_W-1:0] sel_vno = sel_vno_w[V_W-1:0];
    wire       sel_pg  = (reg_addr[7:4] == 4'hA) || (reg_addr[7:4] == 4'hB);
    wire       sel_in  = (sel_vno8 < N_VOX);

    reg  [V_W-1:0] grp_r;
    reg  [V_W-1:0] vpg_r;
    integer        gc;

    always @* begin
        grp_r = {V_W{1'b0}};
        vpg_r = sel_vno;
        for (gc = 1; gc <= GRP_MAX - 1; gc = gc + 1) begin
            if (sel_vno >= (gc * N_VPG)) begin
                grp_r = gc;
                vpg_r = sel_vno - (gc * N_VPG);
            end
        end
    end

    assign sel_hit         = sel_pg && sel_in;
    assign sel_grp         = grp_r;
    assign sel_vpg         = vpg_r;
    assign sel_first_voice = grp_first_voice(sel_grp);
    assign sel_last_voice  = grp_last_voice (sel_grp);
    assign sel_first_slot  = grp_first_slot (sel_grp);
    assign sel_last_slot   = grp_last_slot  (sel_grp);

    fm_engine #(
        .N_VOICE (N_VOICE),
        .N_GROUP (N_GROUP),
        .N_CORE  (N_CORE)
    ) u_fm_engine (
        .clk         (clk),
        .rst_n       (rst_n),
        .sample_tick (sample_tick),
        .reg_we      (reg_we),
        .reg_addr    (reg_addr),
        .reg_wdata   (reg_wdata),
        .vpage_o     (eng_vpage),
        .out_l       (out_l),
        .out_r       (out_r)
    );

`ifdef SIMULATION
    integer si_g, si_h;

    initial begin
        if (N_GROUP < 1)
            $display("*** ERROR tdm_group: N_GROUP(%0d) < 1", N_GROUP);
        if ((N_VOICE % N_GROUP) != 0)
            $display("*** ERROR tdm_group: N_VOICE(%0d) %% N_GROUP(%0d) != 0（组内声部数被截断）",
                     N_VOICE, N_GROUP);
        if (N_GROUP > 16)
            $display("*** ERROR tdm_group: N_GROUP(%0d) > 16 —— sel_grp 只有 4bit", N_GROUP);
        if (N_VOX > 256)
            $display("*** ERROR tdm_group: N_VOX(%0d) > 256 —— 声部寻址 V_W 最多 8 bit", N_VOX);
        if (N_SLOT != 4)
            $display("*** ERROR tdm_group: N_SLOT(%0d) != 4 —— 算子位宽/掩码表/波形表都按 4 写死", N_SLOT);
        if (PRE + N_SLOTS_PER_CORE >= 256)
            $display("*** ERROR tdm_group: 每核 PRE(%0d)+N_SLOTS_PER_CORE(%0d) 超过每采样 256 拍预算（N_SLOTS=%0d / N_CORE=%0d）",
                     PRE, N_SLOTS_PER_CORE, N_SLOTS, N_CORE);
        if ((N_CORE >= 1) && ((N_SLOTS % N_CORE) != 0))
            $display("*** ERROR tdm_group: N_SLOTS(%0d) %% N_CORE(%0d) != 0（每核槽数被截断）",
                     N_SLOTS, N_CORE);

        for (si_g = 0; si_g < N_GROUP; si_g = si_g + 1) begin
            if (grp_first_voice(si_g) != grp_first_slot(si_g) / N_SLOT)
                $display("*** ERROR tdm_group: 组%0d 声部首/槽首 不一致", si_g);
            if (grp_last_voice(si_g) - grp_first_voice(si_g) != N_VPG - 1)
                $display("*** ERROR tdm_group: 组%0d 声部区间宽度 != N_VPG(%0d)", si_g, N_VPG);
            if (grp_last_slot(si_g) - grp_first_slot(si_g) != N_VPG * N_SLOT - 1)
                $display("*** ERROR tdm_group: 组%0d 槽区间宽度 != N_VPG*N_SLOT(%0d)",
                         si_g, N_VPG * N_SLOT);
            for (si_h = 0; si_h < si_g; si_h = si_h + 1) begin
                if (grp_first_voice(si_g) <= grp_last_voice(si_h))
                    $display("*** ERROR tdm_group: 组%0d 与组%0d 声部区间重叠", si_g, si_h);
            end
        end
        if (grp_last_voice(N_GROUP - 1) != N_VOX - 1)
            $display("*** ERROR tdm_group: 末组末声部(%0d) != N_VOX-1(%0d)",
                     grp_last_voice(N_GROUP - 1), N_VOX - 1);
    end

    reg dec_reported;

    always @(posedge clk) begin
        if (!rst_n)
            dec_reported <= 1'b0;
        else if (sel_pg && (u_fm_engine.vsel_we !== (reg_we && sel_hit)) && !dec_reported) begin
            dec_reported <= 1'b1;
            $display("*** ERROR tdm_group: 组边界译码与 fm_engine 内部不一致 addr=%02h we=%b",
                     reg_addr, reg_we);
        end
    end
`endif

    wire _unused = &{1'b0, sel_first_voice, sel_last_voice,
                     sel_first_slot,  sel_last_slot, 1'b0};

endmodule
