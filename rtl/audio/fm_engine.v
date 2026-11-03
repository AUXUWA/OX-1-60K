// fm_engine —— FM 引擎顶层 —— 寄存器接口 + 声部阵列 + 芯片级共享单元

module fm_engine #(
    parameter integer N_VOICE = 1,
    parameter integer N_GROUP = 1,
    parameter integer N_CORE  = 1,
    parameter integer N_PART  = 4,
    parameter integer WIN_CLK = 256,
    parameter integer MIX_KNEE_TH = 24576
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,

    input  wire               reg_we,
    input  wire [7:0]         reg_addr,
    input  wire [7:0]         reg_wdata,

    output wire [3:0]         vpage_o,

    output wire signed [15:0] out_l,
    output wire signed [15:0] out_r
);

    localparam integer N_VPG   = ((N_VOICE / N_GROUP) < 1) ? 1 : (N_VOICE / N_GROUP);
    localparam integer N_VOX   = N_GROUP * N_VPG;
    localparam integer N_SLOTS = N_GROUP * N_VPG * 4;
    localparam integer N_VPC   = ((N_VOX / N_CORE) < 1) ? 1 : (N_VOX / N_CORE);

`ifdef SIMULATION
    initial begin
        if (N_CORE < 1)
            $display("*** ERROR fm_engine: N_CORE(%0d) < 1", N_CORE);
        else if ((N_VOX % N_CORE) != 0)
            $display("*** ERROR fm_engine: N_VOX(%0d) %% N_CORE(%0d) != 0（每核声部数会被截断 ⇒ 后段声部永不被扫描）",
                     N_VOX, N_CORE);
        else if ((N_VPC * 4 + 11) > WIN_CLK)
            $display("*** ERROR fm_engine: 每核 N_VPC(%0d)×4 + 11（预热 8 + PH_PRE 3）= %0d > %0d 拍采样窗口（本核装不下 ⇒ 声部扫不完 ⇒ 大部分声部静音）",
                     N_VPC, N_VPC * 4 + 11, WIN_CLK);
        if (N_GROUP < 1)
            $display("*** ERROR fm_engine: N_GROUP(%0d) < 1", N_GROUP);
        else if ((N_VOICE % N_GROUP) != 0)
            $display("*** ERROR fm_engine: N_VOICE(%0d) %% N_GROUP(%0d) != 0（组内声部数会被截断）",
                     N_VOICE, N_GROUP);
        if ((N_CORE == 1) && (N_SLOTS + 1 >= WIN_CLK))
            $display("*** ERROR fm_engine: N_CORE=1 时 N_SLOTS(%0d) 超过每采样 %0d 拍预算",
                     N_SLOTS, WIN_CLK);
        if (N_VOX > 256)
            $display("*** ERROR fm_engine: N_VOX(%0d) > 256 —— 声部号 8 位装不下（vpage 4 + reg_addr[3:0] 4）",
                     N_VOX);
        if (N_VPC > 256)
            $display("*** ERROR fm_engine: N_VPC(%0d) > 256 —— core_vsel 只有 8 位", N_VPC);
        if (N_VOX > 16)
            $display("*** WARN  fm_engine: N_VOICE(%0d) > 16 —— 0x03 页寄存器已把寻址抬到 0..255，但 note_manager 侧的写序列只到 VADDR_MAX=25（note_manager.v:286）⇒ v=25..%0d **暂时没有驱动源**",
                     N_VOICE, N_VOX - 1);
    end
`endif

    wire        eg_state;
    wire [1:0]  eg_timer_lo;
    wire [3:0]  eg_add;
    wire [7:0]  trem;
    wire [2:0]  vibpos;
    wire        chip_adv;
    wire [N_CORE-1:0] core_adv;

    localparam [2:0] LFO_TREM_SHIFT_DFLT = 3'd4;
    localparam       LFO_VIB_SHIFT_DFLT  = 1'b1;

    wire vibshift = LFO_VIB_SHIFT_DFLT;

    chip_eg_timer u_chip_eg_timer (
        .clk         (clk),
        .rst_n       (rst_n),
        .sample_tick (chip_adv),
        .eg_state    (eg_state),
        .eg_timer_lo (eg_timer_lo),
        .eg_add      (eg_add)
    );

    chip_lfo u_chip_lfo (
        .clk           (clk),
        .rst_n         (rst_n),
        .sample_tick   (chip_adv),
        .tremolo_shift (LFO_TREM_SHIFT_DFLT),
        .vibshift      (LFO_VIB_SHIFT_DFLT),
        .trem          (trem),
        .vibpos        (vibpos)
    );

    localparam integer N_SLOT  = 4;
    localparam integer NPW     = (N_PART < 1) ? N_SLOT : (N_PART * N_SLOT);
    localparam integer PW_B    = (N_PART <= 1) ? 1 :
                                  (N_PART <= 2) ? 1 :
                                  (N_PART <= 4) ? 2 :
                                  (N_PART <= 8) ? 3 :
                                  (N_PART <= 16) ? 4 : 5;

    reg [35:0]                     p_bank [0:NPW-1];
    reg [2:0]                      p_fb   [0:((N_PART<1)?0:N_PART-1)];
    reg [2:0]                      p_algo [0:((N_PART<1)?0:N_PART-1)];
    reg [PW_B-1:0]                 p_sel;

    wire                           s_timbre_wr = reg_we && (
                                    ((reg_addr[7:5] == 3'b001) && (reg_addr[4:2] == 3'b000)) ||
                                    ((reg_addr[7:5] == 3'b010) && (reg_addr[4:2] == 3'b000)) ||
                                    ((reg_addr[7:5] == 3'b011) && (reg_addr[4:2] == 3'b000)) ||
                                    ((reg_addr[7:5] == 3'b100) && (reg_addr[4:2] == 3'b000)) ||
                                    ((reg_addr[7:5] == 3'b111) && (reg_addr[4:2] == 3'b000)));
    wire [1:0]                     s_op_sel   = reg_addr[1:0];
    wire [PW_B+1:0]                s_pidx     = {p_sel, s_op_sel};
    wire                           s_part_ok  = (reg_wdata < ((N_PART < 1) ? 8'd1 : N_PART[7:0]));

    integer pb;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (pb = 0; pb < NPW; pb = pb + 1)      p_bank[pb] <= 36'd0;
            for (pb = 0; pb < N_PART; pb = pb + 1) begin
                p_fb[pb]   <= 3'd0;
                p_algo[pb] <= 3'd0;
            end
            p_sel <= {PW_B{1'b0}};
        end
        else if (reg_we) begin
            case (reg_addr)
                8'h02: if (s_part_ok) p_sel <= reg_wdata[PW_B-1:0];
                8'hC0: begin
                    p_fb  [p_sel] <= reg_wdata[6:4];
                    p_algo[p_sel] <= reg_wdata[2:0];
                end
                8'h20, 8'h21, 8'h22, 8'h23: begin
                    p_bank[s_pidx][35]    <= reg_wdata[7];
                    p_bank[s_pidx][34]    <= reg_wdata[6];
                    p_bank[s_pidx][30]    <= reg_wdata[5];
                    p_bank[s_pidx][29]    <= reg_wdata[4];
                    p_bank[s_pidx][3:0]   <= reg_wdata[3:0];
                end
                8'h40, 8'h41, 8'h42, 8'h43: begin
                    p_bank[s_pidx][5:4]   <= reg_wdata[7:6];
                    p_bank[s_pidx][11:6]  <= reg_wdata[5:0];
                end
                8'h60, 8'h61, 8'h62, 8'h63: begin
                    p_bank[s_pidx][15:12] <= reg_wdata[7:4];
                    p_bank[s_pidx][19:16] <= reg_wdata[3:0];
                end
                8'h80, 8'h81, 8'h82, 8'h83: begin
                    p_bank[s_pidx][24:20] <= (reg_wdata[7:4] == 4'hf)
                                                 ? 5'h1f : {1'b0, reg_wdata[7:4]};
                    p_bank[s_pidx][28:25] <= reg_wdata[3:0];
                end
                8'hE0, 8'hE1, 8'hE2, 8'hE3: p_bank[s_pidx][33:31] <= reg_wdata[2:0];
                default: ;
            endcase
        end
    end

    wire [36*NPW-1:0]  p_bank_flat;
    wire [3*N_PART-1:0] p_fb_flat;
    wire [3*N_PART-1:0] p_algo_flat;
    genvar pg, pf;
    generate
        for (pg = 0; pg < NPW; pg = pg + 1) begin : g_bank_flat
            assign p_bank_flat[36*pg +: 36] = p_bank[pg];
        end
        for (pf = 0; pf < N_PART; pf = pf + 1) begin : g_fbalgo_flat
            assign p_fb_flat  [3*pf +: 3] = p_fb  [pf];
            assign p_algo_flat[3*pf +: 3] = p_algo[pf];
        end
    endgenerate

    reg [3:0] vpage;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            vpage <= 4'd0;
        else if (reg_we && (reg_addr == 8'h03))
            vpage <= reg_wdata[3:0];
    end

    wire [7:0] vsel    = {vpage, reg_addr[3:0]};
    assign     vpage_o = vpage;
    wire       vsel_pg = (reg_addr[7:4] == 4'hA) || (reg_addr[7:4] == 4'hB)
                       || (reg_addr[7:4] == 4'hD)
                       || (reg_addr[7:4] == 4'h5);
    wire       vsel_ok = (vsel < N_VOX);
    wire       vsel_we = reg_we && vsel_pg && vsel_ok;

    wire signed [15:0] core_l   [0:N_CORE-1];
    wire signed [15:0] core_r   [0:N_CORE-1];
    wire               core_go  [0:N_CORE-1];
    wire               core_lst [0:N_CORE-1];
    wire [N_CORE-1:0]  core_go_v;

    genvar gc;
    generate
    for (gc = 0; gc < N_CORE; gc = gc + 1) begin : g_core
        wire                 core_hit  = (vsel >= (gc * N_VPC)) &&
                                         (vsel <  ((gc + 1) * N_VPC));
        wire [7:0]           core_vsel = vsel - (gc * N_VPC);

        fm_voice #(
            .N_VOICE (N_VPC),
            .N_GROUP (1),
            .N_SLOT  (4),
            .N_PART  (N_PART)
        ) u_fm_voice (
            .clk         (clk),
            .rst_n       (rst_n),
            .sample_tick (sample_tick),
            .reg_we      (reg_we),
            .reg_addr    (reg_addr),
            .reg_wdata   (reg_wdata),
            .vsel        (core_vsel),
            .vsel_we     (vsel_we && core_hit),
            .p_bank_flat_in  (p_bank_flat),
            .p_fb_flat_in    (p_fb_flat),
            .p_algo_flat_in  (p_algo_flat),
            .eg_state    (eg_state),
            .eg_timer_lo (eg_timer_lo),
            .eg_add      (eg_add),
            .trem        (trem),
            .vibpos      (vibpos),
            .vibshift    (vibshift),
            .chip_adv    (core_adv[gc]),
            .voi_l       (core_l  [gc]),
            .voi_r       (core_r  [gc]),
            .voi_go      (core_go [gc]),
            .voi_last    (core_lst[gc])
        );

        assign core_go_v[gc] = core_go[gc];
    end
    endgenerate

    assign chip_adv = core_adv[0];

    wire voi_go_all = |core_go_v;

    localparam integer MIX_IN_W = 16 + ((N_CORE <= 1) ? 0 : $clog2(N_CORE));
    reg  signed [MIX_IN_W-1:0] voi_l_r, voi_r_r;
    integer gm;
    always @(*) begin
        voi_l_r = {MIX_IN_W{1'b0}};
        voi_r_r = {MIX_IN_W{1'b0}};
        for (gm = 0; gm < N_CORE; gm = gm + 1) begin
            if (core_go[gm]) begin
                voi_l_r = voi_l_r + core_l[gm];
                voi_r_r = voi_r_r + core_r[gm];
            end
        end
    end

    wire signed [MIX_IN_W-1:0] voi_l = voi_l_r;
    wire signed [MIX_IN_W-1:0] voi_r = voi_r_r;
    wire               voi_go   = voi_go_all;
    wire               voi_last = core_lst[0];

    localparam integer MIX_AW = MIX_IN_W + 3 + ((N_VOX <= 1) ? 0 : $clog2(N_VOX)) + 1;
    wire signed [MIX_AW-1:0] mix_acc_l, mix_acc_r;
    wire               mix_soft_l, mix_clip_l;

    audio_mixer #(
        .N_VOICE (N_VOX),
        .VOICE_W (16),
        .IN_W    (MIX_IN_W),
        .GUARD   (3),
        .SHIFT   (3),
        .KNEE_TH (MIX_KNEE_TH)
    ) u_audio_mixer (
        .clk         (clk),
        .rst_n       (rst_n),
        .sample_tick (sample_tick),
        .slot_go     (voi_go),
        .slot_last   (voi_last),
        .in_l        (voi_l),
        .in_r        (voi_r),
        .out_l       (out_l),
        .out_r       (out_r),
        .acc_l       (mix_acc_l),
        .acc_r       (mix_acc_r),
        .soft_l      (mix_soft_l),
        .clip_l      (mix_clip_l)
    );

    wire _unused_mix = &{1'b0, mix_acc_l, mix_acc_r, mix_soft_l, mix_clip_l, 1'b0};

endmodule
