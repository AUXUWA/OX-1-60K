// fm_voice —— N 声部 × 4 算子 TDM 声部阵列 —— 槽位状态 + TDM 调度 + 寄存器解码

module fm_voice #(
    parameter integer N_VOICE = 1,
    parameter integer N_GROUP = 1,
    parameter integer N_SLOT  = 4,
    parameter integer N_PART   = 4,
    parameter integer STORE_BSRAM = 1
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,

    input  wire               reg_we,
    input  wire [7:0]         reg_addr,
    input  wire [7:0]         reg_wdata,

    input  wire [7:0]         vsel,
    input  wire               vsel_we,

    input  wire [36*N_PART*4-1:0] p_bank_flat_in,
    input  wire [3*N_PART-1:0]    p_fb_flat_in,
    input  wire [3*N_PART-1:0]    p_algo_flat_in,

    input  wire               eg_state,
    input  wire [1:0]         eg_timer_lo,
    input  wire [3:0]         eg_add,
    input  wire [7:0]         trem,
    input  wire [2:0]         vibpos,
    input  wire               vibshift,

    output wire               chip_adv,

    output wire signed [15:0] voi_l,
    output wire signed [15:0] voi_r,
    output wire               voi_go,
    output wire               voi_last
);

    `include "algo_tab.vh"

    localparam integer N_VPG   = ((N_VOICE / N_GROUP) < 1) ? 1 : (N_VOICE / N_GROUP);
    localparam integer N_SLOTS = N_GROUP * N_VPG * N_SLOT;
    localparam integer N_VOX   = N_GROUP * N_VPG;

    localparam integer V_W = (N_VOX   <=   2) ? 1 :
                             (N_VOX   <=   4) ? 2 :
                             (N_VOX   <=   8) ? 3 :
                             (N_VOX   <=  16) ? 4 :
                             (N_VOX   <=  32) ? 5 :
                             (N_VOX   <=  64) ? 6 :
                             (N_VOX   <= 128) ? 7 : 8;
    localparam integer G_W = (N_GROUP <=   2) ? 1 :
                             (N_GROUP <=   4) ? 2 :
                             (N_GROUP <=   8) ? 3 : 4;
    localparam integer SLOT_W = (N_SLOTS <=   2) ? 1 :
                                (N_SLOTS <=   4) ? 2 :
                                (N_SLOTS <=   8) ? 3 :
                                (N_SLOTS <=  16) ? 4 :
                                (N_SLOTS <=  32) ? 5 :
                                (N_SLOTS <=  64) ? 6 :
                                (N_SLOTS <= 128) ? 7 :
                                (N_SLOTS <= 256) ? 8 :
                                (N_SLOTS <= 512) ? 9 : 10;

    localparam [1:0] OP_LAST = N_SLOT - 1;
    localparam integer SH_VPG = 2;
    localparam integer SH_NVP = (N_VPG <=  1) ? 0 :
                                (N_VPG <=  2) ? 1 :
                                (N_VPG <=  4) ? 2 :
                                (N_VPG <=  8) ? 3 :
                                (N_VPG <= 16) ? 4 :
                                (N_VPG <= 32) ? 5 :
                                (N_VPG <= 64) ? 6 :
                                (N_VPG <= 128) ? 7 : 8;
    localparam integer SH_GRP = SH_NVP + SH_VPG;

    localparam integer PRE = 3;

    localparam integer N_PART_MIN = (N_PART < 1) ? 1 : N_PART;
    localparam integer PW    = (N_PART_MIN <= 1) ? 1 :
                               (N_PART_MIN <= 2) ? 1 :
                               (N_PART_MIN <= 4) ? 2 :
                               (N_PART_MIN <= 8) ? 3 :
                               (N_PART_MIN <= 16) ? 4 : 5;
    localparam integer N_PW   = N_PART_MIN * N_SLOT;
    localparam [7:0]  N_PART_8 = N_PART_MIN[7:0];

    localparam [1:0] EG_ATTACK  = 2'd0,
                     EG_DECAY   = 2'd1,
                     EG_SUSTAIN = 2'd2,
                     EG_RELEASE = 2'd3;

    localparam [1:0] PH_IDLE = 2'd0, PH_PRE0 = 2'd1, PH_PRE1 = 2'd2, PH_PRE2 = 2'd3;

    reg [2:0]     drn_i;
    reg           drn_act;

    localparam integer PRE_SH_LAST = (N_VOX > 1) ? 3'd7 : 3'd3;
    reg [2:0]     pre_sh;
    reg           pre_act;

    reg           busy;
    reg  [1:0]    ph;
    reg [G_W-1:0] grp_idx;
    reg [V_W-1:0] vpg_idx;
    reg [1:0]     op_idx;

    wire op_last    = busy && (op_idx == OP_LAST);
    wire vpg_last   = op_last && (vpg_idx == N_VPG - 1);
    wire slot_last  = vpg_last && (grp_idx == N_GROUP - 1);
    wire voice_last = op_last;
    wire slot_go    = busy;

    reg              init_act;
    reg              init_done;
    reg [SLOT_W-1:0] init_i;
    reg              tick_pend;

    wire start = init_done && !busy && !drn_act && !pre_act && (ph == PH_IDLE) &&
                 (sample_tick || tick_pend);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy      <= 1'b0;
            ph        <= PH_IDLE;
            grp_idx   <= {G_W{1'b0}};
            vpg_idx   <= {V_W{1'b0}};
            op_idx    <= 2'd0;
            init_act  <= 1'b1;
            init_done <= 1'b0;
            pre_act   <= 1'b0;
            pre_sh    <= 3'd0;
            init_i    <= {SLOT_W{1'b0}};
            tick_pend <= 1'b0;
        end
        else begin
            if (sample_tick && (!init_done || drn_act) && !busy)
                tick_pend <= 1'b1;
            if (start)
                tick_pend <= 1'b0;

            if (init_act) begin
                init_i <= (init_i == N_SLOTS - 1) ? {SLOT_W{1'b0}} : (init_i + 1'b1);
                if (init_i == N_SLOTS - 1) begin
                    init_act  <= 1'b0;
                    init_done <= 1'b1;
                end
            end

            if (busy) begin
                if (op_idx != OP_LAST) begin
                    op_idx <= op_idx + 2'd1;
                end
                else begin
                    op_idx <= 2'd0;
                    if (vpg_idx != N_VPG - 1) begin
                        vpg_idx <= vpg_idx + 1'b1;
                    end
                    else begin
                        vpg_idx <= {V_W{1'b0}};
                        if (grp_idx == N_GROUP - 1) begin
                            busy    <= 1'b0;
                            grp_idx <= {G_W{1'b0}};
                        end
                        else
                            grp_idx <= grp_idx + 1'b1;
                    end
                end
            end
            else if (pre_act) begin
                if (pre_sh == PRE_SH_LAST) begin
                    pre_act <= 1'b0;
                    pre_sh  <= 3'd0;
                    ph      <= PH_PRE0;
                end
                else
                    pre_sh <= pre_sh + 3'd1;
            end
            else begin
                case (ph)
                    PH_PRE0: ph <= PH_PRE1;
                    PH_PRE1: ph <= PH_PRE2;
                    PH_PRE2: begin ph <= PH_IDLE; busy <= 1'b1; end
                    default: if (start) begin
                                 pre_act <= 1'b1;
                                 pre_sh  <= 3'd0;
                             end
                endcase
            end
        end
    end

    assign chip_adv = slot_last;

    wire [SLOT_W-1:0] cur_base  = (grp_idx << SH_GRP) + (vpg_idx << SH_VPG);
    wire [SLOT_W-1:0] cur_slot  = cur_base + op_idx;
    wire [V_W-1:0]    cur_voice = (grp_idx << SH_NVP) + vpg_idx;
    wire [1:0]        cur_op    = op_idx;

    wire [SLOT_W:0]   cur_p3 = {1'b0, cur_slot} + PRE;
    wire [SLOT_W-1:0] rd_run = (cur_p3 >= N_SLOTS) ? (cur_p3 - N_SLOTS) : cur_p3[SLOT_W-1:0];
    wire [SLOT_W-1:0] rd_pre = (ph == PH_PRE0) ? {SLOT_W{1'b0}} :
                               (ph == PH_PRE1) ? {{(SLOT_W-1){1'b0}}, 1'b1} : 2'd2;
    wire [SLOT_W-1:0] rd_idle = {SLOT_W{1'b0}};
    wire [SLOT_W-1:0] tdm_raddr = busy ? rd_run : ((ph == PH_IDLE) ? rd_idle : rd_pre);

    wire [SLOT_W:0]   init_p1 = {1'b0, init_i} + 1'b1;
    wire [SLOT_W-1:0] init_raddr = (init_p1 >= N_SLOTS) ? (init_p1 - N_SLOTS)
                                                        : init_p1[SLOT_W-1:0];

    wire [SLOT_W-1:0] wr_addr = init_act ? init_i : cur_slot;

    localparam integer NB  = 4;
    localparam integer NEED_DRAIN = (N_VOX == 1) ? 1 : 0;
    localparam integer SHW = NB * N_SLOT;

    reg signed [15:0] sh_out   [0:SHW-1];
    reg signed [15:0] sh_prout [0:SHW-1];
    reg [1:0]         sh_bank;
    reg               slot_key [0:N_SLOTS-1];

    wire [1:0]        sh_op    = cur_op;
    wire [3:0]        sh_base  = {sh_bank, 2'b00};
    wire              ov_we;
    wire [SLOT_W-1:0] ov_waddr;
    wire [35:0]       ov_wdata;
    wire [SLOT_W-1:0] ov_raddr;

    wire [SLOT_W:0]   nx8      = {1'b0, cur_slot} + 8;
    wire [SLOT_W-1:0] rd_next  = (nx8 >= N_SLOTS) ? (nx8 - N_SLOTS) : nx8[SLOT_W-1:0];
    wire       ld_run_ok = (N_VOX > 2) && (cur_slot < (N_SLOTS - 8));
    wire [SLOT_W:0]   p2s      = {1'b0, cur_slot} + 2;
    wire [SLOT_W-1:0] rd_safe  = (p2s >= N_SLOTS) ? (p2s - N_SLOTS) : p2s[SLOT_W-1:0];

    wire [1:0] pre_op  = pre_sh[1:0];
    wire       pre_hi  = pre_sh[2];
    wire [1:0] ld_bank = pre_act
                       ? (pre_hi ? ((sh_bank == 2'd3) ? 2'd0 : (sh_bank + 2'd1))
                                 : sh_bank)
                       : ((sh_bank >= 2'd2) ? (sh_bank - 2'd2) : (sh_bank + 2'd2));
    wire [1:0] ld_op   = pre_act ? pre_op : sh_op;
    wire [3:0] ld_coord = {ld_bank, ld_op};
    wire       ld_en   = pre_act ? 1'b1 : (busy && ld_run_ok);
    wire [SLOT_W-1:0] ld_addr = pre_act ? {{(SLOT_W-2){1'b0}}, pre_hi, pre_op}
                                        : (ld_run_ok ? rd_next : rd_safe);

    assign ov_raddr = init_act ? init_raddr : ld_addr;

    reg [31:0] wb_buf [0:3];
    wire [35:0] wb_word = {4'b0, wb_buf[cur_op]};
    wire [SLOT_W:0]   wb_sub  = {1'b0, cur_slot} - 4;
    wire [SLOT_W-1:0] wb_addr = wb_sub[SLOT_W] ? (wb_sub + N_SLOTS) : wb_sub[SLOT_W-1:0];

    assign ov_we    = init_act || drn_act || (slot_go && (N_VOX > 1));
    assign ov_waddr = init_act ? init_i : (drn_act ? {{(SLOT_W-2){1'b0}}, drn_i[1:0]} : wb_addr);
    assign ov_wdata = init_act ? 36'd0
                              : (drn_act ? {4'b0, wb_buf[drn_i[1:0]]} : wb_word);

    reg [3:0] ld_c1, ld_c2, ld_c3;
    reg       ld_v1, ld_v2, ld_v3;

    reg [9:0] voice_fnum  [0:N_VOX-1];
    reg [2:0] voice_block [0:N_VOX-1];

    reg [3:0] voice_vel   [0:N_VOX-1];

    wire [35:0] p_word_f    [0:N_PW-1];
    wire [2:0]  part_fb     [0:N_PART_MIN-1];
    wire [2:0]  part_algo   [0:N_PART_MIN-1];

    genvar rg, rf;
    generate
        for (rg = 0; rg < N_PW; rg = rg + 1) begin : g_rd_word
            assign p_word_f[rg] = p_bank_flat_in[36*rg +: 36];
        end
        for (rf = 0; rf < N_PART_MIN; rf = rf + 1) begin : g_rd_fbalgo
            assign part_fb  [rf] = p_fb_flat_in  [3*rf +: 3];
            assign part_algo[rf] = p_algo_flat_in[3*rf +: 3];
        end
    endgenerate
    reg [PW-1:0] voice_part [0:N_VOX-1];

    reg        nts;

    function [35:0] pack_word;
        input [PW+1:0] idx;
        begin
            pack_word = p_word_f[idx];
        end
    endfunction

    localparam integer IDX_W = V_W;
    wire [IDX_W-1:0]  vsel_i   = vsel[IDX_W-1:0];
    wire              vsel_hit = vsel_we && (vsel < N_VOX);
    wire [SLOT_W-1:0] v_base   = vsel_i << SH_VPG;
    wire [1:0]        op_sel   = reg_addr[1:0];

    wire timbre_wr = reg_we && (
                         ((reg_addr[7:5] == 3'b001) && (reg_addr[4:2] == 3'b000)) ||
                         ((reg_addr[7:5] == 3'b010) && (reg_addr[4:2] == 3'b000)) ||
                         ((reg_addr[7:5] == 3'b011) && (reg_addr[4:2] == 3'b000)) ||
                         ((reg_addr[7:5] == 3'b100) && (reg_addr[4:2] == 3'b000)) ||
                         ((reg_addr[7:5] == 3'b111) && (reg_addr[4:2] == 3'b000)));

    wire part_sel_wr = reg_we && (reg_addr == 8'h02);
    wire part_wr     = vsel_hit && (reg_addr[7:4] == 4'hD);
    wire keyon_set   = vsel_hit && reg_addr[4] && reg_wdata[5];
    wire param_reload = timbre_wr || part_wr || keyon_set;

    reg              pm_dirty;
    reg              sw_wr_seen;
    reg [SLOT_W-1:0] sw_i;

    wire [V_W-1:0] sw_voice = sw_i >> SH_VPG;
    wire [1:0]     sw_op    = sw_i[1:0];

    wire [V_W-1:0] sw_voice_nxt = (sw_voice == N_VOX - 1) ? {V_W{1'b0}}
                                                          : (sw_voice + 1'b1);

    reg  [PW-1:0]  sw_part_r;
    wire [PW+1:0]  sw_pidx  = {sw_part_r, sw_op};
    wire [35:0]    sw_wdata = pack_word(sw_pidx);

    wire [SLOT_W-1:0] pm_raddr = init_act ? init_raddr : tdm_raddr;
    wire sw_go = pm_dirty && (sw_i != pm_raddr);

    wire sw_pass_start = sw_go && (sw_i == {SLOT_W{1'b0}});
    wire sw_pass_done  = sw_go && (sw_i == N_SLOTS - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sw_part_r <= {PW{1'b0}};
        else if (sw_go && (sw_op == 2'd3))
            sw_part_r <= voice_part[sw_voice_nxt];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sw_i        <= {SLOT_W{1'b0}};
            pm_dirty    <= 1'b1;
            sw_wr_seen  <= 1'b0;
        end
        else begin
            if (sw_go)
                sw_i <= sw_pass_done ? {SLOT_W{1'b0}} : (sw_i + 1'b1);
            if (sw_pass_done && !sw_wr_seen && !param_reload)
                pm_dirty <= 1'b0;
            if (sw_pass_start)
                sw_wr_seen <= 1'b0;
            if (param_reload) begin
                pm_dirty   <= 1'b1;
                sw_wr_seen <= 1'b1;
            end
        end
    end

    reg byp_d1, byp_d2, byp_d3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byp_d1 <= 1'b1;
            byp_d2 <= 1'b1;
            byp_d3 <= 1'b1;
        end
        else begin
            byp_d1 <= pm_dirty;
            byp_d2 <= byp_d1;
            byp_d3 <= byp_d2;
        end
    end

    wire        phase_we;
    wire        eg_we;
    wire [23:0] cur_pg_phase_next;
    wire [11:0] cur_eg_wdata;

    wire [23:0] ph_rd;
    wire        ph_rv;
    wire [11:0] eg_rd;
    wire        eg_rv;
    wire [35:0] pm_rd;
    wire        pm_rv;

    phase_store #(
        .DEPTH     (N_SLOTS),
        .DW        (24),
        .INIT_VAL  (24'd0),
        .USE_BSRAM (STORE_BSRAM),
        .AW        (SLOT_W)
    ) u_phase_store (
        .clk         (clk),
        .rst_n       (rst_n),
        .we          (phase_we),
        .waddr       (wr_addr),
        .wdata       (cur_pg_phase_next),
        .re          (1'b1),
        .raddr       (init_act ? init_raddr : tdm_raddr),
        .rdata       (ph_rd),
        .rdata_valid (ph_rv)
    );

    eg_state_store #(
        .DEPTH     (N_SLOTS),
        .DW        (12),
        .INIT_VAL  (12'hFFE),
        .USE_BSRAM (STORE_BSRAM),
        .AW        (SLOT_W)
    ) u_eg_state_store (
        .clk         (clk),
        .rst_n       (rst_n),
        .we          (eg_we),
        .waddr       (wr_addr),
        .wdata       (cur_eg_wdata),
        .re          (1'b1),
        .raddr       (init_act ? init_raddr : tdm_raddr),
        .rdata       (eg_rd),
        .rdata_valid (eg_rv)
    );

    param_store #(
        .DEPTH     (N_SLOTS),
        .DW        (36),
        .INIT_VAL  (36'd0),
        .USE_BSRAM (STORE_BSRAM),
        .AW        (SLOT_W)
    ) u_param_store (
        .clk         (clk),
        .rst_n       (rst_n),
        .we          (sw_go),
        .waddr       (sw_i),
        .wdata       (sw_wdata),
        .re          (1'b1),
        .raddr       (pm_raddr),
        .rdata       (pm_rd),
        .rdata_valid (pm_rv)
    );

    wire [35:0] ov_rd;
    wire        ov_rv;

    phase_store #(
        .DEPTH     (N_SLOTS),
        .DW        (36),
        .INIT_VAL  (36'd0),
        .USE_BSRAM (STORE_BSRAM),
        .AW        (SLOT_W)
    ) u_opval_store (
        .clk         (clk),
        .rst_n       (rst_n),
        .we          (ov_we),
        .waddr       (ov_waddr),
        .wdata       (ov_wdata),
        .re          (1'b1),
        .raddr       (ov_raddr),
        .rdata       (ov_rd),
        .rdata_valid (ov_rv)
    );

    wire [PW-1:0] cur_part  = voice_part[cur_voice];
    wire [PW+1:0] cur_pidx  = {cur_part, cur_op};
    wire [35:0]   cur_pword = pack_word(cur_pidx);
    wire [2:0]    cur_algo  = part_algo[cur_part];
    wire [2:0]    cur_fb    = part_fb[cur_part];

    wire        use_store = ~(byp_d3 | pm_dirty);
    wire [35:0] cur_param = use_store ? pm_rd : cur_pword;

    wire [23:0]        cur_pg_phase = ph_rd;
    wire [8:0]         cur_eg_rout  = eg_rd[11:3];
    wire [1:0]         cur_eg_gen   = eg_rd[2:1];
    wire               cur_key      = slot_key[cur_slot];

    wire [3:0]         cur_mult     = cur_param[3:0];
    wire [1:0]         cur_ksl      = cur_param[5:4];
    wire [5:0]         cur_tl       = cur_param[11:6];
    wire [3:0]         cur_vel      = voice_vel[cur_voice];
    wire [6:0]         tl_sum       = {1'b0, cur_tl} + {1'b0, cur_vel, 2'b00};
    wire [5:0]         cur_tl_eff   = (cur_op == 2'd3)
                                        ? (tl_sum[6] ? 6'd63 : tl_sum[5:0])
                                        : cur_tl;
    wire [3:0]         cur_ar       = cur_param[15:12];
    wire [3:0]         cur_dr       = cur_param[19:16];
    wire [4:0]         cur_sl       = cur_param[24:20];
    wire [3:0]         cur_rr       = cur_param[28:25];
    wire               cur_ksr      = cur_param[29];
    wire               cur_reg_type = cur_param[30];
    wire [2:0]         cur_wf       = cur_param[33:31];
    wire               cur_vib      = cur_param[34];
    wire               cur_trem_en  = cur_param[35];

    wire signed [15:0] cur_prout    = sh_prout [sh_base + cur_op];
    wire signed [15:0] cur_out      = sh_out   [sh_base + cur_op];

    wire [9:0]         cur_fnum     = voice_fnum  [cur_voice];
    wire [2:0]         cur_block    = voice_block [cur_voice];

    wire signed [15:0] v_out0 = sh_out[sh_base];
    wire signed [15:0] v_out1 = sh_out[sh_base + 2'd1];
    wire signed [15:0] v_out2 = sh_out[sh_base + 2'd2];
    wire signed [15:0] v_out3 = sh_out[sh_base + 2'd3];

    wire [7:0] eg_ksl_val;
    wire [4:0] ksv_val;

    op_ksl_ksr u_op_ksl_ksr (
        .fnum    (cur_fnum),
        .block   (cur_block),
        .nts     (nts),
        .ksr     (1'b0),
        .eg_ksl  (eg_ksl_val),
        .ksv     (ksv_val)
    );

    wire [3:0] cur_mod_mask = algo_mod_mask(cur_algo, cur_op);

    wire signed [15:0] mod_out;
    wire signed [15:0] fbmod;

    op_router u_op_router (
        .slot_idx (cur_op),
        .fb       (cur_fb),
        .mod_mask (cur_mod_mask),
        .out0     (v_out0),
        .out1     (v_out1),
        .out2     (v_out2),
        .out3     (v_out3),
        .prout    (cur_prout),
        .mod_out  (mod_out),
        .fbmod    (fbmod)
    );

    wire [9:0]         phase_out;
    wire signed [15:0] op_out;
    wire [11:0]        eg_out;
    wire               pg_reset;
    wire [23:0]        pg_phase_next;
    wire [8:0]         eg_rout_next;
    wire [1:0]         eg_gen_next;

    wire [7:0] cur_trem = cur_trem_en ? trem : 8'd0;

    op_core u_op_core (
        .fnum        (cur_fnum),
        .block       (cur_block),
        .nts         (nts),
        .mult        (cur_mult),
        .wf          (cur_wf),
        .vib         (cur_vib),
        .tl          (cur_tl_eff),
        .ar          (cur_ar),
        .dr          (cur_dr),
        .sl          (cur_sl),
        .rr          (cur_rr),
        .ksl         (cur_ksl),
        .ksr         (cur_ksr),
        .reg_type    (cur_reg_type),
        .eg_ksl      (eg_ksl_val),
        .ksv         (ksv_val),
        .trem        (cur_trem),
        .vibpos      (vibpos),
        .vibshift    (vibshift),
        .eg_state    (eg_state),
        .eg_timer_lo (eg_timer_lo),
        .eg_add      (eg_add),
        .pg_phase    (cur_pg_phase),
        .eg_rout     (cur_eg_rout),
        .eg_gen      (cur_eg_gen),
        .key         (cur_key),
        .mod_in      (mod_out),
        .phase_out      (phase_out),
        .op_out         (op_out),
        .eg_out         (eg_out),
        .pg_reset       (pg_reset),
        .pg_phase_next  (pg_phase_next),
        .eg_rout_next   (eg_rout_next),
        .eg_gen_next    (eg_gen_next)
    );

    assign phase_we = slot_go || init_act;
    assign eg_we    = slot_go || init_act;

    assign cur_pg_phase_next = init_act ? 24'd0 : pg_phase_next;
    assign cur_eg_wdata      = init_act ? 12'hFFE
                                        : {eg_rout_next, eg_gen_next, slot_key[cur_slot]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ld_c1 <= 4'd0; ld_c2 <= 4'd0; ld_c3 <= 4'd0;
            ld_v1 <= 1'b0; ld_v2 <= 1'b0; ld_v3 <= 1'b0;
            sh_bank  <= 2'd3;
            drn_i    <= 3'd0;
            drn_act  <= 1'b0;
        end
        else begin
            ld_c1 <= ld_coord;  ld_v1 <= ld_en;
            ld_c2 <= ld_c1;     ld_v2 <= ld_v1;
            ld_c3 <= ld_c2;     ld_v3 <= ld_v2;

            if (slot_go && op_last)
                sh_bank <= (sh_bank == 2'd3) ? 2'd0 : (sh_bank + 2'd1);

            if (NEED_DRAIN) begin
                if (drn_act) begin
                    if (drn_i == 3'd3)
                        drn_act <= 1'b0;
                    else
                        drn_i <= drn_i + 3'd1;
                end
                else if (slot_go && slot_last) begin
                    drn_act <= 1'b1;
                    drn_i   <= 3'd0;
                end
            end
        end
    end

    integer sb;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (sb = 0; sb < 4; sb = sb + 1)
                wb_buf[sb] <= 32'd0;
            for (sb = 0; sb < SHW; sb = sb + 1) begin
                sh_out  [sb] <= 16'sd0;
                sh_prout[sb] <= 16'sd0;
            end
        end
        else begin
            if (slot_go) begin
                sh_prout[sh_base + cur_op] <= cur_out;
                sh_out  [sh_base + cur_op] <= op_out;
                wb_buf  [cur_op]           <= {op_out, cur_out};
            end
            if (ld_v3) begin
                sh_out  [ld_c3] <= ov_rd[31:16];
                sh_prout[ld_c3] <= ov_rd[15:0];
            end
        end
    end

    wire signed [15:0] vnow0 = (cur_op == 2'd0) ? op_out : v_out0;
    wire signed [15:0] vnow1 = (cur_op == 2'd1) ? op_out : v_out1;
    wire signed [15:0] vnow2 = (cur_op == 2'd2) ? op_out : v_out2;
    wire signed [15:0] vnow3 = (cur_op == 2'd3) ? op_out : v_out3;

    wire [3:0] cmask = algo_carrier_mask(cur_algo);

    wire signed [15:0] voice_sum = (cmask[0] ? vnow0 : 16'sd0)
                                 + (cmask[1] ? vnow1 : 16'sd0)
                                 + (cmask[2] ? vnow2 : 16'sd0)
                                 + (cmask[3] ? vnow3 : 16'sd0);

    assign voi_l    = voice_sum;
    assign voi_r    = voice_sum;
    assign voi_go   = voice_last;
    assign voi_last = slot_last;

    integer j;


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nts <= 1'b0;
            for (j = 0; j < N_VOX; j = j + 1) begin
                voice_fnum  [j] <= 10'd0;
                voice_block [j] <= 3'd0;
                voice_part  [j] <= {PW{1'b0}};
                voice_vel   [j] <= 4'd0;
            end
            for (j = 0; j < N_SLOTS; j = j + 1)
                slot_key[j] <= 1'b0;
        end
        else if (reg_we) begin
            if (vsel_hit) begin
                if (reg_addr[7:4] == 4'h5) begin
                    voice_vel[vsel_i] <= reg_wdata[5:2];
                end
                else if (reg_addr[7:4] == 4'hD) begin
                    if (reg_wdata < N_PART_8)
                        voice_part[vsel_i] <= reg_wdata[PW-1:0];
                end
                else if (reg_addr[4]) begin
                    voice_fnum [vsel_i] <= {reg_wdata[1:0], voice_fnum[vsel_i][7:0]};
                    voice_block[vsel_i] <= reg_wdata[4:2];
                    slot_key[v_base]        <= reg_wdata[5];
                    slot_key[v_base + 2'd1] <= reg_wdata[5];
                    slot_key[v_base + 2'd2] <= reg_wdata[5];
                    slot_key[v_base + 2'd3] <= reg_wdata[5];
                end
                else begin
                    voice_fnum[vsel_i] <= {voice_fnum[vsel_i][9:8], reg_wdata};
                end
            end
            else case (reg_addr)
                8'h01: nts <= reg_wdata[0];
                default: ;
            endcase
        end
    end

`ifdef SIMULATION
    `define FMV_SIMPROBE
`endif
`ifdef QUESTA
    `ifndef FMV_SIMPROBE
        `define FMV_SIMPROBE
    `endif
`endif
`ifdef MODELSIM
    `ifndef FMV_SIMPROBE
        `define FMV_SIMPROBE
    `endif
`endif

`ifdef FMV_SIMPROBE
    reg [8:0] slot_eg_rout [0:N_SLOTS-1];
    integer m;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (m = 0; m < N_SLOTS; m = m + 1)
                slot_eg_rout[m] <= 9'h1ff;
        end
        else if (slot_go)
            slot_eg_rout[cur_slot] <= eg_rout_next;
    end
`endif

`ifdef SIMULATION
    reg lat_err_warned;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lat_err_warned <= 1'b0;
        else if (slot_go && !(ph_rv && eg_rv && pm_rv) && !lat_err_warned) begin
            lat_err_warned <= 1'b1;
            $display("*** ERROR fm_voice: store 读延迟契约被破坏（RUN 拍 rdata_valid=0）***");
        end
    end

    initial begin
        if (N_PART < 1)
            $display("*** ERROR fm_voice: N_PART(%0d) < 1", N_PART);
        if ((N_PART_MIN > 1) && (N_PW > (1 << (PW + 2))))
            $display("*** ERROR fm_voice: PW(%0d) 装不下 N_PART=%0d（part_idx 会被截断）",
                     PW, N_PART_MIN);
        if ((N_VOX > 1) && (N_VOX < 4))
            $display("*** ERROR fm_voice: N_VOX(%0d) ∈ {2,3} 不被 P3 shadow 方案支持（见 §3.1 注释）",
                     N_VOX);
        if (N_SLOT != 4)
            $display("*** ERROR fm_voice: N_SLOT(%0d) != 4 —— P3 的 shadow 下标按 N_SLOT=4 写死",
                     N_SLOT);
    end

    reg part_wr_mon;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            part_wr_mon <= 1'b0;
        else if (part_sel_wr && (reg_wdata[PW-1:0] >= N_PART_MIN))
            part_wr_mon <= 1'b1;
        else if (part_wr && (reg_wdata[PW-1:0] >= N_PART_MIN))
            part_wr_mon <= 1'b1;
    end
`endif

`ifdef SIMULATION
    wire _unused_mon = &{1'b0, part_wr_mon, 1'b0};
`endif

    wire _unused = &{1'b0, phase_out, eg_out, fbmod, pg_reset, ph_rv, eg_rv, pm_rv, 1'b0};

endmodule
