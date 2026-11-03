// note_manager

`timescale 1ns/1ps

module note_manager #(
    parameter integer N_KEY   = 25,
    parameter integer N_VOICE = 16,
    parameter integer GAP_CLK = 16,
    parameter integer VEL_HEUR = 0,
    parameter integer HER_MS1  = 150,
    parameter integer HER_MS2  = 400,
    parameter integer HER_MS3  = 1000,
    parameter integer VO_W = (N_KEY < N_VOICE) ? ((N_KEY < 1) ? 1 : ((N_KEY > 32) ? 32 : N_KEY))
                                               : ((N_VOICE < 1) ? 1 : ((N_VOICE > 32) ? 32 : N_VOICE)),
    parameter integer CNT_W = (VO_W <= 16) ? 5 : 6
)(

    input  wire         clk,
    input  wire         rst_n,

    input  wire         sample_tick,

    input  wire [24:0]  kp_pressed,

    input  wire         oct_dn_pulse,
    input  wire         oct_up_pulse,
    input  wire         sustain_hold_i,
    input  wire         glide_en_i,
    input  wire         vib_en_i,
    input  wire [7:0]   vib_depth_i,
    input  wire         vel_en_i,
    input  wire [3:0]   vel_level_i,
    input  wire [5:0]   vel_cur_i,
    input  wire         all_keyoff_req,

    input  wire         key_gate,

    input  wire         bus_gnt,
    input  wire         eng_hold,

    output reg          reg_we,
    output reg  [7:0]   reg_addr,
    output reg  [7:0]   reg_wdata,

    output reg          note_active,
    output reg  [4:0]   cur_note,
    output reg  [2:0]   cur_oct,
    output wire         sustain_on,
    output reg          mode_flag,
    output reg          oct_clamp_pulse,
    output reg  [4:0]   cur_key,
    output reg          cur_key_on,
    output reg  [CNT_W-1:0] voice_cnt,
    output wire [VO_W-1:0] v_on_o,
    output wire [VO_W-1:0] v_gate_o,
    output wire         busy,
    output wire         page_dirty
);

    localparam integer N_KEY_OK   = (N_KEY   < 1) ? 1 : ((N_KEY   > 32) ? 32 : N_KEY);
    localparam integer N_VOICE_OK = (N_VOICE < 1) ? 1 : ((N_VOICE > 32) ? 32 : N_VOICE);
    localparam integer SLOTS      = (N_KEY_OK < N_VOICE_OK) ? N_KEY_OK : N_VOICE_OK;
    localparam integer SBITS      = (SLOTS <= 2) ? 1 : (SLOTS <= 4) ? 2 : (SLOTS <= 8) ? 3
                                : (SLOTS <= 16) ? 4 : (SLOTS <= 32) ? 5 : 6;

    localparam integer NOTE_MAX   = ((N_KEY_OK - 1) < 24) ? (N_KEY_OK - 1) : 24;

    localparam integer IDXW = (SLOTS <= 16) ? 4 : 5;
    localparam integer OHW  = (SLOTS <= 16) ? 16 : SLOTS;

    localparam [4:0]   K_NOTE_TOP = 5'd24;
    localparam integer KPW        = 25;

    localparam [2:0]   OCT_MIN    = 3'd0;
    localparam [2:0]   OCT_C4     = 3'd2;
    localparam [2:0]   OCT_MAX    = 3'd4;
    localparam [2:0]   BLK_BIAS   = 3'd2;

    localparam integer VADDR_MAX  = 25;
    localparam integer PG_SPLIT   = 16;
    localparam [7:0]   PG_REG     = 8'h03;

    localparam [7:0]   A0_BASE    = 8'hA0;
    localparam [7:0]   B0_BASE    = 8'hB0;

    localparam [1:0]   ACT_NONE   = 2'd0;
    localparam [1:0]   ACT_PITCH  = 2'd1;
    localparam [1:0]   ACT_ON     = 2'd2;
    localparam [1:0]   ACT_OFF    = 2'd3;

    localparam [2:0]   W_IDLE     = 3'd0;
    localparam [2:0]   W_PG       = 3'd4;
    localparam [2:0]   W_PGCLR    = 3'd5;
    localparam [2:0]   W_A0       = 3'd1;
    localparam [2:0]   W_B0A      = 3'd2;
    localparam [2:0]   W_B0B      = 3'd3;
    localparam [2:0]   W_VEL      = 3'd6;
    localparam [2:0]   W_SVEL     = 3'd7;

    localparam [1:0]   T_NONE     = 2'd0;
    localparam [1:0]   T_KEYON    = 2'd1;
    localparam [1:0]   T_KEYOFF   = 2'd2;
    localparam [1:0]   T_PITCH    = 2'd3;

    localparam [2:0]   J_NONE     = 3'd0;
    localparam [2:0]   J_KEYOFF_ALL = 3'd1;
    localparam [2:0]   J_PITCH_ALL  = 3'd2;
    localparam [2:0]   J_GATE_UP    = 3'd3;
    localparam [2:0]   J_GATE_DN    = 3'd4;
    localparam [2:0]   J_HOLD_REL   = 3'd5;
    localparam [2:0]   J_RESET_ALL  = 3'd6;
    localparam [2:0]   J_PITCH_TGT  = 3'd7;

    localparam integer TICK_MIN   = 2;

    localparam integer HER_TICKS_MS = 12500;
    localparam integer HER_T1       = HER_MS1 * HER_TICKS_MS;
    localparam integer HER_T2       = HER_MS2 * HER_TICKS_MS;
    localparam integer HER_T3       = HER_MS3 * HER_TICKS_MS;
    localparam [23:0]  HER_T1W      = HER_T1;
    localparam [23:0]  HER_T2W      = HER_T2;
    localparam [23:0]  HER_T3W      = HER_T3;
    localparam [23:0]  HER_CNT_MAX  = 24'hFFFFFF;

`ifdef SIMULATION
    initial begin
        if (N_KEY < 1)
            $display("*** ERROR note_manager: N_KEY(%0d) < 1", N_KEY);
        if (N_KEY > 25)
            $display("*** ERROR note_manager: N_KEY(%0d) > 25 —— kp_pressed 只有 25 位（5x5 矩阵键盘，bit0..24 全是半音键）", N_KEY);
        if (N_VOICE < 1)
            $display("*** ERROR note_manager: N_VOICE(%0d) < 1", N_VOICE);
        if (N_VOICE > 256)
            $display("*** ERROR note_manager: N_VOICE(%0d) > 256 —— 声部号 8 位装不下（vpage 4 + reg_addr[3:0] 4）", N_VOICE);
        else if (N_VOICE > VADDR_MAX)
            $display("*** WARN  note_manager: N_VOICE(%0d) > %0d —— 槽账本算得出 %0d 个槽；本模块只服务 %0d 个半音键（5x5），v>=%0d 的声部由**测试模式**负责",
                     N_VOICE, VADDR_MAX, SLOTS, VADDR_MAX, VADDR_MAX);
        if (N_VOICE > 16 && SLOTS <= 16)
            $display("*** WARN  note_manager: N_VOICE=%0d 但 SLOTS=min(N_KEY_OK=%0d,N_VOICE_OK)=%0d —— N_KEY（键位数）才是天花板，引擎槽数没被撑开",
                     N_VOICE, N_KEY_OK, SLOTS);
        if (HER_T3 > 16777215)
            $display("*** WARN  note_manager: HER_MS3(%0d) ⇒ %0d 拍 > 24 bit 饱和计数器上限 16777215 —— 档 6 永远到不了",
                     HER_MS3, HER_T3);
        if ((HER_MS1 > HER_MS2) || (HER_MS2 > HER_MS3))
            $display("*** WARN  note_manager: 门限乱序 HER_MS1=%0d HER_MS2=%0d HER_MS3=%0d —— 档位随间隔不再单调（快 ⇒ 响）",
                     HER_MS1, HER_MS2, HER_MS3);
    end
`endif

`include "pitch_lut.vh"

    function [9:0] fnum_of_note;
        input [4:0] n;
        begin
            fnum_of_note = fnum_of(sem_of(n));
        end
    endfunction



    function [4:0] low_kidx;
        input [KPW-1:0] m;
        integer k;
        reg     got;
        begin
            low_kidx = 5'd0;
            got      = 1'b0;
            for (k = 0; k < KPW; k = k + 1)
                if (m[k] && !got) begin
                    low_kidx = k[4:0];
                    got      = 1'b1;
                end
        end
    endfunction

    function [OHW-1:0] low_oh;
        input [OHW-1:0] m;
        integer k;
        reg     got;
        begin
            low_oh = {OHW{1'b0}};
            got    = 1'b0;
            for (k = 0; k < SLOTS; k = k + 1)
                if (m[k] && !got) begin
                    low_oh[k] = 1'b1;
                    got       = 1'b1;
                end
        end
    endfunction

    function [IDXW-1:0] low_idx;
        input [OHW-1:0] m;
        integer k;
        reg     got;
        begin
            low_idx = {IDXW{1'b0}};
            got     = 1'b0;
            for (k = 0; k < SLOTS; k = k + 1)
                if (m[k] && !got) begin
                    low_idx = k[IDXW-1:0];
                    got     = 1'b1;
                end
        end
    endfunction

    function [OHW-1:0] oldest_oh;
        input [OHW-1:0]       m;
        input [5*SLOTS-1:0]   rk;
        integer k;
        reg [4:0] best;
        reg       have;
        begin
            oldest_oh = {OHW{1'b0}};
            best      = 5'd0;
            have      = 1'b0;
            for (k = 0; k < SLOTS; k = k + 1)
                if (m[k])
                    if (!have || (rk[5*k +: 5] > best)) begin
                        best         = rk[5*k +: 5];
                        oldest_oh    = {OHW{1'b0}};
                        oldest_oh[k] = 1'b1;
                        have         = 1'b1;
                    end
        end
    endfunction


    function [CNT_W-1:0] pcnt;
        input [OHW-1:0] m;
        integer k;
        begin
            pcnt = {CNT_W{1'b0}};
            for (k = 0; k < SLOTS; k = k + 1)
                if (m[k]) pcnt = pcnt + {{(CNT_W-1){1'b0}}, 1'b1};
        end
    endfunction

    wire [SLOTS-1:0]   st_on;
    wire [SLOTS-1:0]   st_gate;
    wire [2*SLOTS-1:0] st_act;
    wire [5*SLOTS-1:0] st_note;
    wire [3*SLOTS-1:0] st_oct;
    wire [5*SLOTS-1:0] st_rank;

    wire [SLOTS-1:0]   wr_sel;
    wire               wr_on, wr_gate, wr_rank_inc;
    wire [1:0]         wr_act;
    wire [4:0]         wr_note;
    wire [4:0]         wr_rank;
    wire [2:0]         wr_oct;
    wire [SLOTS-1:0]   wr_rank_mask;

    note_store #(
        .SLOTS (SLOTS)
    ) u_store (
        .clk           (clk),
        .rst_n         (rst_n),
        .o_on          (st_on),
        .o_gate        (st_gate),
        .o_act         (st_act),
        .o_note        (st_note),
        .o_oct         (st_oct),
        .o_rank        (st_rank),
        .wr_en         (|wr_sel),
        .wr_sel        (wr_sel),
        .wr_on         (wr_on),
        .wr_gate       (wr_gate),
        .wr_act        (wr_act),
        .wr_note       (wr_note),
        .wr_oct        (wr_oct),
        .wr_rank       (wr_rank),
        .rank_inc      (wr_rank_inc),
        .rank_inc_mask (wr_rank_mask)
    );

    assign v_on_o     = st_on;
    assign v_gate_o   = st_gate;
    assign sustain_on = sustain_hold_i;

    reg [KPW-1:0] lev_d;
    reg [KPW-1:0] pend;
    reg [4:0]  sel_v;
    reg [1:0]  s_ph;
    reg        sus_d, gate_d, hold_d;
    reg [4:0]  last_note;
    reg [2:0]  last_oct;

    wire [4:0]  sel_idx   = low_kidx(pend);
    wire        do_a      = (s_ph == 2'd2);
    wire        bit_press = kp_pressed[sel_v];
    wire        bit_note  = (sel_v <= NOTE_MAX[4:0]);
    wire [4:0]  bit_val   = sel_v;
    wire        ev_down   = do_a & bit_note &  bit_press;
    wire        ev_up     = do_a & (bit_val <= K_NOTE_TOP) & ~bit_press;
    wire        sus_now   = sustain_hold_i;
    wire        sus_fall  = sus_d & ~sus_now;
    wire        gate_rise = key_gate & ~gate_d;
    wire        gate_fall = ~key_gate & gate_d;
    wire        hold_fall = hold_d & ~eng_hold;
    wire        oct_can_dn= (cur_oct != OCT_MIN);
    wire        oct_can_up= (cur_oct != OCT_MAX);
    wire        oct_dn_ev = oct_dn_pulse;
    wire        oct_up_ev = oct_up_pulse;
    wire        oct_moves = (oct_dn_ev & oct_can_dn) | (oct_up_ev & oct_can_up);
    wire        oct_clamp = (oct_dn_ev & ~oct_can_dn) | (oct_up_ev & ~oct_can_up);
    wire        reset_ev  = all_keyoff_req;
    wire [KPW-1:0] sel_v_oh = {{(KPW-1){1'b0}}, 1'b1} << sel_v;

    wire [SLOTS-1:0] act_nz;
    wire [SLOTS-1:0] occ    = st_on | st_gate;
    wire [SLOTS-1:0] used   = occ | act_nz;
    wire [SLOTS-1:0] free_v = ~used;

    genvar gi;
    generate
        for (gi = 0; gi < SLOTS; gi = gi + 1) begin : g_actnz
            assign act_nz[gi] = (st_act[2*gi +: 2] != ACT_NONE);
        end
    endgenerate

    wire [4:0] alloc_note = ev_down ? bit_val : last_note;

    wire [SLOTS-1:0] match_v;
    generate
        for (gi = 0; gi < SLOTS; gi = gi + 1) begin : g_match
            assign match_v[gi] = (st_note[5*gi +: 5] == alloc_note) & occ[gi];
        end
    endgenerate
    wire [OHW-1:0] oh_match  = low_oh({{(OHW-SLOTS){1'b0}}, match_v});
    wire        hit_match = |match_v;

    wire [OHW-1:0] oh_free  = low_oh({{(OHW-SLOTS){1'b0}}, free_v});
    wire        hit_free = |free_v;

    wire [SLOTS-1:0] pre_c1  = st_on & ~st_gate;
    wire [SLOTS-1:0] pre_src = (|pre_c1) ? pre_c1 : st_on;
    wire [OHW-1:0]      oh_pre  = oldest_oh({{(OHW-SLOTS){1'b0}}, pre_src}, st_rank);

    wire [OHW-1:0] oh_alloc  = hit_match ? oh_match : (hit_free ? oh_free : oh_pre);
    wire        alloc_new = ~hit_match;
    wire [IDXW-1:0] alloc_idx = low_idx(oh_alloc);

    wire [SLOTS-1:0] rel_v;
    generate
        for (gi = 0; gi < SLOTS; gi = gi + 1) begin : g_rel
            assign rel_v[gi] = (st_note[5*gi +: 5] == bit_val) & st_gate[gi];
        end
    endgenerate
    wire [OHW-1:0] oh_rel  = low_oh({{(OHW-SLOTS){1'b0}}, rel_v});
    wire        hit_rel = |rel_v;
    wire [IDXW-1:0]  rel_idx = low_idx(oh_rel);

    reg [2:0]       wst;
    reg             scan_wr;

    wire        scan_want = (s_ph == 2'd2) && (ev_down || (ev_up && hit_rel));
    wire        scan_retry= scan_want && ~scan_wr;
    wire [KPW-1:0] scan_keep = scan_retry ? sel_v_oh : {KPW{1'b0}};
    wire [KPW-1:0] clr_oh    = (s_ph == 2'd2) ? (scan_retry ? {KPW{1'b0}} : sel_v_oh)
                                             : {KPW{1'b0}};

    localparam integer HEAL_M = 64;
    reg [KPW-1:0]    kp_d;
    reg [SLOTS-1:0]  gt_d;
    reg [6:0]        qin_cnt;
    reg [6:0]        qgt_cnt;
    localparam integer KPN_W = (SLOTS <= 16) ? SLOTS : ((SLOTS <= KPW) ? SLOTS : KPW);
    wire [KPN_W-1:0] kp_note = kp_pressed[KPN_W-1:0];
    wire             quiet_in = (qin_cnt >= HEAL_M[6:0]) & (kp_pressed == kp_d);
    wire             quiet_gt = (qgt_cnt >= HEAL_M[6:0]) & (st_gate   == gt_d);
    wire             quiet_ok = (wst == W_IDLE) & (pend == {KPW{1'b0}})
                              & (st_act == {(2*SLOTS){1'b0}}) & quiet_in & quiet_gt;
    wire [SLOTS-1:0] heal_bad_v;
    generate
        for (gi = 0; gi < SLOTS; gi = gi + 1) begin : g_heal
            assign heal_bad_v[gi] = st_gate[gi]
                                  & ~kp_pressed[st_note[5*gi +: 5]]
                                  & ~key_gate
                                  & (st_note[5*gi +: 5] <= NOTE_MAX[4:0]);
        end
    endgenerate
    wire [OHW-1:0] oh_heal   = low_oh({{(OHW-SLOTS){1'b0}}, heal_bad_v});
    wire [IDXW-1:0]  heal_i    = low_idx(oh_heal);
    wire [4:0]  heal_note = st_note[5*heal_i +: 5];
    wire        heal_go   = quiet_ok & (|heal_bad_v);
    wire [KPW-1:0] heal_inj = heal_go ? ({{(KPW-1){1'b0}}, 1'b1} << heal_note)
                                      : {KPW{1'b0}};

    reg [2:0]       job;
    wire            job_act = (job != J_NONE) && (wst == W_IDLE);
    reg [SBITS-1:0] job_i;
    reg [1:0]       job_act_i;
    wire [SLOTS-1:0] job_gate = st_gate;
    wire            job_g  = st_gate[job_i];
    wire            job_o  = st_on[job_i];
    wire [4:0]      job_note = st_note[5*job_i +: 5];
    wire [4:0]      job_rank = st_rank[5*job_i +: 5];
    wire [2:0]      job_oct  = st_oct [3*job_i +: 3];
    wire [OHW-1:0]     job_sel_oh = ({{(OHW-1){1'b0}}, 1'b1}) << job_i;
    wire [SLOTS-1:0] job_sel  = job_sel_oh[SLOTS-1:0];

    always @* begin
        job_act_i = st_act[2*job_i +: 2];
    end

    reg  [4:0]  glide_note_r;
    reg  [7:0]  vib_depth_r;
    reg  [3:0]  pf_blk_r;
    wire        pf_hit;
    wire [9:0]  pf_tgt;
    wire [3:0]  pf_blk;
    wire        pf_wr_hit;
    wire [9:0]  pf_num_eff;
    wire        pf_busy;
    wire        glide_rep;
    wire        pf_drain;

    wire j_do_off_all = (job == J_KEYOFF_ALL) & job_o & ~job_g;
    wire j_do_rst_all = (job == J_RESET_ALL)  & job_o;
    wire j_do_pit_tgt = (job == J_PITCH_TGT)  & job_o & (job_note == glide_note_r);
    wire j_do_pit_all = (job == J_PITCH_ALL)  & job_o;
    wire j_do_gup_p   = (job == J_GATE_UP)    & job_g;
    wire j_do_gdn     = (job == J_GATE_DN)    & job_o;
    wire j_do_h_g     = (job == J_HOLD_REL)   & job_g;
    wire j_do_h_o     = (job == J_HOLD_REL)   & ~job_g & job_o;

    reg [2:0] job_next;
    always @* begin
        job_next = J_NONE;
        if (gate_fall)      job_next = J_GATE_DN;
        else if (hold_fall) job_next = J_HOLD_REL;
        else if (reset_ev)  job_next = J_RESET_ALL;
        else if (sus_fall)  job_next = J_KEYOFF_ALL;
        else if (gate_rise) job_next = J_GATE_UP;
        else if (oct_moves) job_next = J_PITCH_ALL;
        else if (glide_rep) job_next = J_PITCH_TGT;
    end


    wire job_run = (job != J_NONE) & (wst == W_IDLE);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lev_d           <= {KPW{1'b0}};
            pend            <= {KPW{1'b0}};
            kp_d            <= {KPW{1'b0}};
            gt_d            <= {SLOTS{1'b0}};
            qin_cnt         <= 7'd0;
            qgt_cnt         <= 7'd0;
            sel_v           <= 5'd0;
            s_ph            <= 2'd0;
            sus_d           <= 1'b0;
            gate_d          <= 1'b0;
            hold_d          <= 1'b0;
            last_note       <= 5'd0;
            last_oct        <= OCT_C4;
            cur_oct         <= OCT_C4;
            mode_flag       <= 1'b0;
            oct_clamp_pulse <= 1'b0;
        end
        else begin
            oct_clamp_pulse <= 1'b0;

            pend  <= (pend | (kp_pressed ^ lev_d) | heal_inj | scan_keep) & ~clr_oh;
            lev_d <= kp_pressed;

            kp_d <= kp_pressed;
            if (kp_pressed == kp_d) begin
                if (qin_cnt != 7'd127) qin_cnt <= qin_cnt + 7'd1;
            end
            else qin_cnt <= 7'd0;
            gt_d <= st_gate;
            if (st_gate == gt_d) begin
                if (qgt_cnt != 7'd127) qgt_cnt <= qgt_cnt + 7'd1;
            end
            else qgt_cnt <= 7'd0;

            if (s_ph == 2'd0) begin
                if (|pend && (job == J_NONE)) begin
                    sel_v <= sel_idx;
                    s_ph  <= 2'd1;
                end
            end
            else if (s_ph == 2'd1) begin
                s_ph  <= 2'd2;
            end
            else begin
                s_ph  <= 2'd0;
            end

            sus_d  <= sus_now;
            gate_d <= key_gate;
            hold_d <= eng_hold;


            if (oct_dn_ev && oct_can_dn) begin
                cur_oct  <= cur_oct - 3'd1;
                last_oct <= cur_oct - 3'd1;
            end
            else if (oct_up_ev && oct_can_up) begin
                cur_oct  <= cur_oct + 3'd1;
                last_oct <= cur_oct + 3'd1;
            end
            if (oct_clamp) oct_clamp_pulse <= 1'b1;

            if (ev_down) last_note <= bit_val;
        end
    end

    reg             tx_fin;
    reg             tx_start;
    reg [SBITS-1:0] tx_v;
    reg [4:0]       tx_note_r;
    reg [2:0]       tx_oct_r;
    reg             tx_keyon_now;
    reg [SLOTS-1:0] tx_sel;

    always @* begin
        tx_sel = {SLOTS{1'b0}};
        if (tx_v < SLOTS) tx_sel[tx_v] = 1'b1;
    end


    reg [SLOTS-1:0] wsel;
    reg             won, wgate, wrank_inc;
    reg [1:0]       wact;
    reg [4:0]       wnote;
    reg [4:0]       wrank;
    reg [2:0]       woct;
    reg [SLOTS-1:0] wrank_mask;

    always @* begin
        wsel      = {SLOTS{1'b0}};
        won       = 1'b0;
        wgate     = 1'b0;
        wact      = ACT_NONE;
        wnote     = 5'd0;
        woct      = OCT_C4;
        wrank     = 5'd0;
        wrank_inc = 1'b0;
        wrank_mask= {SLOTS{1'b0}};
        scan_wr   = 1'b0;

        if (tx_fin) begin
            wsel  = tx_sel;
            won   = tx_keyon_now;
            wgate = st_gate[tx_v];
            wnote = tx_note_r;
            woct  = tx_oct_r;
            wrank = st_rank[5*tx_v +: 5];
            if (tx_keyon_now && (tx_oct_r != cur_oct))            wact = ACT_PITCH;
            else if (tx_keyon_now && !st_gate[tx_v] && !sus_now)  wact = ACT_OFF;
            else if (!tx_keyon_now && st_gate[tx_v])              wact = ACT_ON;
            else                                                  wact = ACT_NONE;
        end

        else if (job != J_NONE && job_act) begin
            if ((job == J_KEYOFF_ALL) && j_do_off_all) begin
                wsel  = job_sel;
                wrank = job_rank;
                wnote = job_note;
            end
            else if ((job == J_RESET_ALL) && j_do_rst_all) begin
                wsel  = job_sel;
                wrank = job_rank;
                wnote = job_note;
            end
            else if ((job == J_PITCH_ALL) && j_do_pit_all) begin
                wsel  = job_sel;
                wrank = job_rank;
                wnote = job_note;
            end
            else if ((job == J_PITCH_TGT) && j_do_pit_tgt) begin
                wsel  = job_sel;
                wrank = job_rank;
                wnote = job_note;
            end
            else if ((job == J_GATE_UP) && j_do_gup_p) begin
                wsel  = job_sel;
                wrank = job_rank;
                wnote = job_note;
            end
            else if ((job == J_GATE_DN) && j_do_gdn) begin
                wsel  = job_sel;
                wrank = job_rank;
                wnote = job_note;
            end
            else if ((job == J_HOLD_REL) && (j_do_h_g || j_do_h_o)) begin
                wsel  = job_sel;
                wrank = job_rank;
                wnote = job_note;
            end
            if (job == J_KEYOFF_ALL) begin
                if (j_do_off_all) begin
                    won   = 1'b0;  wgate = 1'b0;  wact = ACT_OFF;  woct = job_oct;
                end
            end
            else if (job == J_RESET_ALL) begin
                if (j_do_rst_all) begin
                    won   = 1'b0;  wgate = 1'b0;  wact = ACT_OFF;  woct = job_oct;
                end
            end
            else if (job == J_PITCH_ALL) begin
                if (j_do_pit_all) begin
                    won   = 1'b1;  wgate = job_gate[job_i];
                    wact  = (job_act_i > ACT_PITCH) ? job_act_i : ACT_PITCH;
                    woct  = cur_oct;
                end
            end
            else if (job == J_PITCH_TGT) begin
                if (j_do_pit_tgt) begin
                    won   = 1'b1;  wgate = job_gate[job_i];
                    wact  = (job_act_i > ACT_PITCH) ? job_act_i : ACT_PITCH;
                    woct  = cur_oct;
                end
            end
            else if (job == J_GATE_UP) begin
                if (j_do_gup_p) begin
                    won   = 1'b1;  wgate = 1'b1;
                    wact  = (job_act_i > ACT_PITCH) ? job_act_i : ACT_PITCH;
                    woct  = job_oct;
                end
                else if (job_i == {SBITS{1'b0}}) begin
                    if (!(|st_gate)) begin
                        wsel  = oh_alloc;
                        won   = 1'b1;  wgate = 1'b1;  wact = ACT_ON;
                        wnote = last_note;
                        woct  = last_oct;
                        wrank = 5'd0;
                        if (alloc_new) begin
                            wrank_inc  = 1'b1;
                            wrank_mask = st_on & ~oh_alloc[SLOTS-1:0];
                        end
                    end
                end
            end
            else if (job == J_GATE_DN) begin
                if (j_do_gdn) begin
                    won   = 1'b0;  wgate = 1'b0;  wact = ACT_OFF;  woct = job_oct;
                end
            end
            else if (job == J_HOLD_REL) begin
                if (j_do_h_g) begin
                    won   = 1'b0;  wgate = 1'b1;  wact = ACT_ON;  woct = job_oct;
                end
                else if (j_do_h_o) begin
                    won   = 1'b0;  wgate = 1'b0;  wact = ACT_OFF;  woct = job_oct;
                end
            end
        end

        else if (ev_down) begin
            scan_wr = 1'b1;
            wsel  = oh_alloc[SLOTS-1:0];
            won   = 1'b1;
            wgate = 1'b1;
            wact  = ACT_ON;
            wnote = alloc_note;
            woct  = cur_oct;
            wrank = 5'd0;
            if (alloc_new) begin
                wrank_inc  = 1'b1;
                wrank_mask = st_on & ~oh_alloc[SLOTS-1:0];
            end
            else begin
                wrank = st_rank[5*alloc_idx +: 5];
            end
        end
        else if (ev_up && hit_rel) begin
            scan_wr = 1'b1;
            wsel  = oh_rel[SLOTS-1:0];
            won   = st_on[rel_idx];
            wgate = 1'b0;
            wnote = st_note[5*rel_idx +: 5];
            woct  = st_oct [3*rel_idx +: 3];
            wrank = st_rank[5*rel_idx +: 5];
            wact  = (st_on[rel_idx] & sus_now) ? ACT_NONE : ACT_OFF;
        end

        else if (tx_start) begin
            wsel  = tx_sel;
            won   = st_on[tx_v];
            wgate = st_gate[tx_v];
            wnote = tx_note_r;
            woct  = st_oct[3*tx_v +: 3];
            wrank = st_rank[5*tx_v +: 5];
            wact  = ACT_NONE;
        end
    end

    assign wr_sel       = wsel;
    assign wr_on        = won;
    assign wr_gate      = wgate;
    assign wr_act       = wact;
    assign wr_note      = wnote;
    assign wr_oct       = woct;
    assign wr_rank      = wrank;
    assign wr_rank_inc  = wrank_inc;
    assign wr_rank_mask = wrank_mask;

    reg [1:0]       tx_kind;
    reg [4:0]       tx_gap;
    reg [1:0]       tx_tick;
    reg             tx_need_tick;
    reg             tx_vel_en;
    reg [3:0]       tx_vel_lvl;
    reg [5:0]       tx_svel;
    reg [3:0]       tx_heur_lvl;
    reg [23:0]      her_cnt;
    reg             we_pend;
    localparam integer SAMP_N_EST = 256;
    localparam integer W3_GAP_C   = SAMP_N_EST + 1;
    localparam [10:0]  W3_GAP_W  = SAMP_N_EST + 1;
    integer    rci;
    reg [10:0] wr_cyc_cnt;
    reg [10:0] last_wr_cy [0:SLOTS-1];
    reg [SLOTS-1:0] wr_ever;
    reg [SLOTS-1:0] last_wr_v;
    reg             we_ack;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)              glide_note_r <= 5'd0;
        else if (ev_down)        glide_note_r <= bit_val;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) vib_depth_r <= 8'd0;
        else        vib_depth_r <= vib_depth_i;
    end

    assign pf_hit    = (tx_note_r == glide_note_r);
    assign pf_tgt    = fnum_of_note(glide_note_r);
    assign pf_blk    = {1'b0, oct_eff(cur_oct, glide_note_r)} + BLK_BIAS;
    assign pf_wr_hit = pf_hit & ((wst == W_A0) || (wst == W_B0A) || (wst == W_B0B));
    assign glide_rep = (pf_busy & sample_tick) | pf_drain;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)               pf_blk_r <= 4'd0;
        else if (pf_wr_hit)       pf_blk_r <= pf_blk;
    end

    reg  pf_busy_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pf_busy_d <= 1'b0;
        else        pf_busy_d <= pf_busy;
    end
    assign pf_drain = pf_busy_d & ~pf_busy;

    perf_mod u_perf_mod (
        .clk        (clk),
        .rst_n      (rst_n),
        .sample_tick(sample_tick),
        .fnum_tgt   (pf_tgt),
        .wr_hit     (pf_wr_hit),
        .glide_en   (glide_en_i),
        .vib_en     (vib_en_i & (vib_depth_r != 8'd0)),
        .vib_depth  (vib_depth_r),
        .blk_chg    (pf_blk != pf_blk_r),
        .fnum_eff   (pf_num_eff),
        .busy       (pf_busy)
    );

    reg  [9:0]  pf_lat;
    reg         pf_lat_v;
    wire [9:0]  tx_fnum_plain = fnum_of_note(tx_note_r);
    wire [9:0]  tx_fnum = pf_hit ? (pf_lat_v ? pf_lat : pf_num_eff) : tx_fnum_plain;
    wire [7:0] tx_alo  = tx_fnum[7:0];
    wire [1:0] tx_ahi  = tx_fnum[9:8];
    localparam integer V4W = (SBITS > 4) ? SBITS : 4;
    wire [V4W-1:0] tx_v_ext = {{(V4W-SBITS){1'b0}}, tx_v};
    wire [3:0] tx_v4   = tx_v_ext[3:0];
    wire       tx_v_oob = (tx_v >= VADDR_MAX);
    wire [2:0] OCT_WR = oct_eff(cur_oct, tx_note_r);
    wire [7:0] tx_a0a  = {A0_BASE[7:4], tx_v4};
    wire [7:0] tx_b0a  = {B0_BASE[7:4], tx_v4};
    wire [7:0] tx_50a  = {4'h5, tx_v4};
    wire [7:0] tx_vel_data;
    generate
    if (VEL_HEUR != 0) begin : g_vel_data_heur
        assign tx_vel_data = {2'b00, (4'd15 - tx_heur_lvl), 2'b00};
    end else begin : g_vel_data_base
        assign tx_vel_data = {2'b00, (4'd15 - tx_vel_lvl), 2'b00};
    end
    endgenerate
    wire [7:0] tx_pg_data = {4'b0000, 3'b000, (tx_v >= PG_SPLIT)};
    wire [7:0] tx_b0_off = {2'b00, 1'b0, OCT_WR + BLK_BIAS, tx_ahi};
    wire [7:0] tx_b0_on  = {2'b00, 1'b1, OCT_WR + BLK_BIAS, tx_ahi};
`ifdef SIMULATION
    reg tx_oob_seen;
    initial tx_oob_seen = 1'b0;
    always @(posedge clk) begin
        if (rst_n && tx_v_oob && reg_we && !tx_oob_seen) begin
            tx_oob_seen <= 1'b1;
            $display("*** ERROR note_manager: 槽 v=%0d 的写发出去了，但 0xA0+v/0xB0+v 的 v 只有 4 位（实际写到 0x%02h）—— 寄存器映射装不下 32 个声部",
                     tx_v, tx_b0a);
        end
    end
`endif

    wire             tx_active = (wst != W_IDLE);
    wire [SLOTS-1:0] req_v  = act_nz & ~(tx_active ? tx_sel : {SLOTS{1'b0}});
    wire [OHW-1:0]      oh_req  = low_oh({{(OHW-SLOTS){1'b0}}, req_v});
    wire [IDXW-1:0]     req_i   = low_idx(oh_req);
    wire             req_hit = |req_v;
    wire [10:0]      w3_last_sel = last_wr_cy[req_i];
    wire [10:0]      w3_age_sel  = wr_cyc_cnt - w3_last_sel;
    wire             req_go      = req_hit & (~wr_ever[req_i] | (w3_age_sel >= W3_GAP_W));
    wire [1:0]       req_a  = st_act[2*req_i +: 2];

    wire             tx_boot = (wst == W_IDLE) & ~(job_run & job_act) & req_go;
    wire             her_clr = tx_boot & (req_a == ACT_ON);
    wire [3:0]       her_lvl;
    generate
    if (VEL_HEUR != 0) begin : g_heur
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)                      her_cnt <= 24'd0;
            else if (her_clr)                her_cnt <= 24'd0;
            else if (her_cnt != HER_CNT_MAX) her_cnt <= her_cnt + 24'd1;
        end
        assign her_lvl = (her_cnt < HER_T1W) ? 4'd15
                       : (her_cnt < HER_T2W) ? 4'd12
                       : (her_cnt < HER_T3W) ? 4'd9
                       :                        4'd6;
    end else begin : g_heur_off
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) her_cnt <= 24'd0;
            else        her_cnt <= 24'd0;
        end
        assign her_lvl = 4'd15;
    end
    endgenerate


    wire job_wants = ((job == J_KEYOFF_ALL) & j_do_off_all)
                   | ((job == J_RESET_ALL)  & j_do_rst_all)
                   | ((job == J_PITCH_ALL)  & j_do_pit_all)
                   | ((job == J_PITCH_TGT)  & j_do_pit_tgt)
                   | ((job == J_GATE_UP)    & (j_do_gup_p | (job_i == {SBITS{1'b0}})))
                   | ((job == J_GATE_DN)    & j_do_gdn)
                   | ((job == J_HOLD_REL)   & (j_do_h_g | j_do_h_o));
    wire job_wr    = ~job_wants | ~tx_fin;
    reg job_need_next;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            job           <= J_NONE;
            job_i         <= {SBITS{1'b0}};
            job_need_next <= 1'b0;
        end
        else if (job == J_NONE) begin
            if (job_next != J_NONE) begin
                job           <= job_next;
                job_i         <= {SBITS{1'b0}};
                job_need_next <= 1'b0;
            end
        end
        else if (wst == W_IDLE && job_need_next) begin
            if (job_i == (SLOTS - 1)) begin
                job           <= J_NONE;
                job_i         <= {SBITS{1'b0}};
                job_need_next <= 1'b0;
            end
            else begin
                job_i         <= job_i + 1'b1;
                job_need_next <= 1'b0;
            end
        end
        else if (wst == W_IDLE && job_wr) begin
            job_need_next <= 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wst          <= W_IDLE;
            tx_kind      <= T_NONE;
            tx_v         <= {SBITS{1'b0}};
            tx_gap       <= 5'd0;
            tx_tick      <= 2'd0;
            tx_need_tick <= 1'b0;
            tx_fin       <= 1'b0;
            tx_start     <= 1'b0;
            tx_keyon_now <= 1'b0;
            tx_note_r    <= 5'd0;
            tx_oct_r     <= OCT_C4;
            reg_we       <= 1'b0;
            we_pend      <= 1'b0;
            we_ack       <= 1'b0;
            pf_lat       <= 10'd0;
            pf_lat_v     <= 1'b0;
            tx_heur_lvl  <= 4'd15;
            wr_cyc_cnt   <= 11'd0;
            wr_ever      <= {SLOTS{1'b0}};
            for (rci = 0; rci < SLOTS; rci = rci + 1) last_wr_cy[rci] <= 11'd0;
            last_wr_v    <= {SLOTS{1'b0}};
            reg_addr     <= B0_BASE;
            reg_wdata    <= 8'h00;
            cur_note     <= 5'd0;
            cur_key      <= 5'h1F;
            cur_key_on   <= 1'b0;
            note_active  <= 1'b0;
            voice_cnt    <= {CNT_W{1'b0}};
        end
        else begin
            wr_cyc_cnt <= wr_cyc_cnt + 11'd1;
            if (we_pend && reg_we) begin
                if (bus_gnt && !eng_hold) begin
                    we_ack   <= 1'b1;
                    reg_we   <= 1'b0;
                    we_pend  <= 1'b0;
                    last_wr_v <= tx_sel;
                    if ((tx_v < SLOTS) &&
                        ((reg_addr[7:4] == 4'hA) || (reg_addr[7:4] == 4'hB))) begin
                        last_wr_cy[tx_v] <= wr_cyc_cnt;
                        wr_ever[tx_v]    <= 1'b1;
                    end
                end
            end
            else we_ack <= 1'b0;
            tx_fin       <= 1'b0;
            tx_start     <= 1'b0;
            note_active  <= |st_on;
            voice_cnt    <= pcnt({{(OHW-SLOTS){1'b0}}, st_on});

            if (tx_boot) tx_heur_lvl <= her_lvl;

            if (do_a) begin
                cur_key    <= bit_val;
                cur_key_on <= bit_press;
            end
            if (ev_up) cur_key_on <= 1'b0;

            case (wst)
            W_IDLE: begin
                if (job_run && job_act) begin
                end
                else if (req_go) begin
                    tx_v      <= req_i[SBITS-1:0];
                    tx_note_r <= st_note[5*req_i +: 5];
                    tx_oct_r  <= st_oct [3*req_i +: 3];
                    tx_gap    <= GAP_CLK[4:0];
                    tx_tick   <= 2'd0;
                    tx_need_tick <= 1'b0;
                    tx_start  <= 1'b1;
                    tx_keyon_now <= 1'b0;
                    pf_lat_v  <= 1'b0;
                    tx_vel_en  <= vel_en_i;
                    tx_vel_lvl <= vel_level_i;
                    tx_svel    <= vel_cur_i;
                    if (req_a == ACT_ON) begin
                        tx_kind <= T_KEYON;
                        wst     <= (req_i >= PG_SPLIT) ? W_PG
                                 : ((vel_cur_i != 6'd0) ? W_SVEL
                                    : (vel_en_i ? W_VEL : W_A0));
                    end
                    else if (req_a == ACT_OFF) begin
                        tx_kind <= T_KEYOFF;
                        wst     <= (req_i >= PG_SPLIT) ? W_PG : W_B0A;
                    end
                    else begin
                        tx_kind <= T_PITCH;
                        wst     <= (req_i >= PG_SPLIT) ? W_PG : W_A0;
                    end
                end
            end
            default: begin
                if (tx_gap != 5'd0) begin
                    if (bus_gnt && !eng_hold) tx_gap <= tx_gap - 5'd1;
                end
                else begin
                    case (wst)
                    W_A0: begin
                        if (!we_pend) begin
                            if (we_ack) begin
                                tx_gap <= GAP_CLK[4:0];
                                wst    <= W_B0A;
                            end
                            else if (bus_gnt && !eng_hold) begin
                                reg_we       <= 1'b1;
                                reg_addr     <= tx_a0a;
                                reg_wdata    <= tx_alo;
                                tx_keyon_now <= 1'b0;
                                we_pend      <= 1'b1;
                                pf_lat       <= pf_num_eff;
                                pf_lat_v     <= 1'b1;
                            end
                        end
                    end
                    W_B0A: begin
                        if (!we_pend) begin
                          if (we_ack) begin
                            if (tx_kind == T_KEYOFF) begin
                                tx_fin   <= 1'b1;
                                cur_note <= tx_note_r;
                                wst      <= (tx_v >= PG_SPLIT) ? W_PGCLR : W_IDLE;
                            end
                            else if (tx_kind == T_PITCH) begin
                                tx_fin   <= 1'b1;
                                cur_note <= tx_note_r;
                                wst      <= (tx_v >= PG_SPLIT) ? W_PGCLR : W_IDLE;
                            end
                            else begin
                                tx_gap       <= GAP_CLK[4:0];
                                tx_need_tick <= 1'b1;
                                tx_tick      <= 2'd0;
                                wst          <= W_B0B;
                            end
                          end
                          else if (bus_gnt && !eng_hold) begin
                            reg_we   <= 1'b1;
                            reg_addr <= tx_b0a;
                            we_pend  <= 1'b1;
                            if (tx_kind == T_KEYOFF) begin
                                reg_wdata    <= {2'b00, 1'b0, OCT_WR + BLK_BIAS, tx_ahi};
                                tx_keyon_now <= 1'b0;
                            end
                            else if (tx_kind == T_PITCH) begin
                                reg_wdata    <= {2'b00, 1'b1, OCT_WR + BLK_BIAS, tx_ahi};
                                tx_keyon_now <= 1'b1;
                            end
                            else begin
                                reg_wdata    <= {2'b00, 1'b0, OCT_WR + BLK_BIAS, tx_ahi};
                                tx_keyon_now <= 1'b0;
                            end
                          end
                        end
                    end
                    W_B0B: begin
                        if (we_pend) begin
                        end
                        else if (we_ack) begin
                            tx_fin   <= 1'b1;
                            cur_note <= tx_note_r;
                            wst      <= (tx_v >= PG_SPLIT) ? W_PGCLR : W_IDLE;
                        end
                        else if (tx_need_tick) begin
                            if (sample_tick) begin
                                if (tx_tick == (TICK_MIN - 1)) tx_need_tick <= 1'b0;
                                else                           tx_tick <= tx_tick + 2'd1;
                            end
                        end
                        else if (tx_oct_r != cur_oct && tx_kind == T_KEYON) begin
                            tx_oct_r <= cur_oct;
                            tx_gap   <= GAP_CLK[4:0];
                            wst      <= W_A0;
                        end
                        else if (bus_gnt && !eng_hold) begin
                            reg_we       <= 1'b1;
                            reg_addr     <= tx_b0a;
                            reg_wdata    <= {2'b00, 1'b1, OCT_WR + BLK_BIAS, tx_ahi};
                            we_pend      <= 1'b1;
                            tx_keyon_now <= 1'b1;
                        end
                    end
                    W_PG: begin
                        if (!we_pend) begin
                            if (we_ack) begin
                                tx_gap <= GAP_CLK[4:0];
                                wst    <= (tx_kind == T_KEYOFF) ? W_B0A
                                         : ((tx_kind == T_KEYON && (tx_svel != 6'd0)) ? W_SVEL
                                            : ((tx_kind == T_KEYON && tx_vel_en) ? W_VEL : W_A0));
                            end
                            else if (bus_gnt && !eng_hold) begin
                                reg_we    <= 1'b1;
                                reg_addr  <= PG_REG;
                                reg_wdata <= tx_pg_data;
                                we_pend   <= 1'b1;
                            end
                        end
                    end
                    W_VEL: begin
                        if (!we_pend) begin
                            if (we_ack) begin
                                tx_gap <= GAP_CLK[4:0];
                                wst    <= W_A0;
                            end
                            else if (bus_gnt && !eng_hold) begin
                                reg_we    <= 1'b1;
                                reg_addr  <= tx_50a;
                                reg_wdata <= tx_vel_data;
                                we_pend   <= 1'b1;
                            end
                        end
                    end
                    W_SVEL: begin
                        if (!we_pend) begin
                            if (we_ack) begin
                                tx_gap <= GAP_CLK[4:0];
                                wst    <= W_A0;
                            end
                            else if (bus_gnt && !eng_hold) begin
                                reg_we    <= 1'b1;
                                reg_addr  <= tx_50a;
                                reg_wdata <= {2'b00, tx_svel};
                                we_pend   <= 1'b1;
                            end
                        end
                    end
                    W_PGCLR: begin
                        if (!we_pend) begin
                            if (we_ack) begin
                                wst <= W_IDLE;
                            end
                            else if (bus_gnt && !eng_hold) begin
                                reg_we    <= 1'b1;
                                reg_addr  <= PG_REG;
                                reg_wdata <= 8'h00;
                                we_pend   <= 1'b1;
                            end
                        end
                    end
                    default: begin
                        if (we_pend) begin
                        end
                        else if (we_ack) begin
                            tx_fin   <= 1'b1;
                            cur_note <= tx_note_r;
                            wst      <= (tx_v >= PG_SPLIT) ? W_PGCLR : W_IDLE;
                        end
                        else if (bus_gnt && !eng_hold) begin
                            reg_we       <= 1'b1;
                            reg_addr     <= tx_b0a;
                            reg_wdata    <= {2'b00, 1'b1, OCT_WR + BLK_BIAS, tx_ahi};
                            we_pend      <= 1'b1;
                            tx_keyon_now <= 1'b1;
                        end
                    end
                    endcase
                end
            end
            endcase
        end
    end

    assign busy = (wst != W_IDLE);
    assign page_dirty = (tx_v >= PG_SPLIT) && (wst != W_IDLE);

`ifdef T20_DBG
    integer n_heal, n_heal_busy, n_heal_act, n_heal_hold;
    integer n_repair;
    initial begin n_heal = 0; n_heal_busy = 0; n_heal_act = 0; n_heal_hold = 0;
                  n_repair = 0; end
    always @(posedge clk) if (rst_n) begin
        if (heal_go) begin
            n_heal = n_heal + 1;
            if (busy)                 n_heal_busy = n_heal_busy + 1;
            if (|st_act)              n_heal_act  = n_heal_act + 1;
            if (job != J_NONE)        n_heal_hold = n_heal_hold + 1;
            $display("[HEAL] cyc=%0d n=%0d slot=%0d note=%0d qi=%0d qg=%0d busy=%b act=%b pend=%0d gate=%b kp16=%b",
                     wr_cyc_cnt, n_heal, heal_i, heal_note, qin_cnt, qgt_cnt, busy, st_act, pend,
                     st_gate, kp_pressed);
        end
        if ((s_ph == 2'd2) && ev_up && hit_rel) begin
            n_repair = n_repair + 1;
            $display("[D4] cyc=%0d n=%0d v=%0d note=%0d on=%b sus=%b gate=%b kpn=%b heal=%b",
                     wr_cyc_cnt, n_repair, rel_idx, st_note[5*rel_idx +: 5],
                     st_on[rel_idx], sus_now, st_gate, kp_note, heal_go);
        end
    end
`endif

    wire _unused = &{1'b0, 1'b0};

`ifdef T20_DBG
    always @(posedge clk) if (rst_n && wr_sel[7])
        $display("[W7] cyc=%0d gate7=%b|wr_gate=%b wr_act=%0d wr_on=%b pend=%h s_ph=%0d evup=%b hitrel=%b txfin=%b txst=%b job=%0d wst=%0d",
                 wr_cyc_cnt, st_gate[7], wr_gate, wr_act, wr_on, pend, s_ph,
                 ev_up, hit_rel, tx_fin, tx_start, job, wst);
`endif

`ifdef T20_DBG
    integer dbg_t;
    integer w3b_t [0:SLOTS-1];
    integer w3a_t [0:SLOTS-1];
    integer n_w3v;
    integer w3i;
    initial begin
        dbg_t = 0; n_w3v = 0;
        for (w3i = 0; w3i < SLOTS; w3i = w3i + 1) begin
            w3b_t[w3i] = -1000000; w3a_t[w3i] = -1000000;
        end
    end
    always @(posedge clk) if (rst_n) begin
        dbg_t = dbg_t + 1;
        if (reg_we) begin
            if (reg_addr[7:4] == 4'hA) begin
                if ((dbg_t - w3a_t[reg_addr[3:0]]) < 256) begin
                    n_w3v = n_w3v + 1;
                    $display("[W3V-A0] t=%0d slot=%0d gap=%0d txkind=%0d wst=%0d",
                             dbg_t, reg_addr[3:0], dbg_t - w3a_t[reg_addr[3:0]], tx_kind, wst);
                end
                w3a_t[reg_addr[3:0]] = dbg_t;
            end
            else if (reg_addr[7:4] == 4'hB) begin
                if ((dbg_t - w3b_t[reg_addr[3:0]]) < 256) begin
                    n_w3v = n_w3v + 1;
                    $display("[W3V-B0] t=%0d slot=%0d gap=%0d txkind=%0d wst=%0d",
                             dbg_t, reg_addr[3:0], dbg_t - w3b_t[reg_addr[3:0]], tx_kind, wst);
                end
                w3b_t[reg_addr[3:0]] = dbg_t;
            end
        end
        if ((wst == W_IDLE) && req_go && ~(job_run && job_act))
            $display("[START] t=%0d cyc=%0d v=%0d a=%0d ok=%b age=%0d last=%0d ever=%b job=%0d hold=%b",
                     dbg_t, wr_cyc_cnt, req_i, req_a, ~wr_ever[req_i] | (w3_age_sel >= W3_GAP_W),
                     wr_cyc_cnt - last_wr_cy[req_i], last_wr_cy[req_i], wr_ever[req_i],
                     job, eng_hold);
        if (we_pend && reg_we && bus_gnt && !eng_hold)
            $display("[ACK] t=%0d cyc=%0d v=%0d kind=%0d addr=%h data=%h wsel=%h",
                     dbg_t, wr_cyc_cnt, tx_v, tx_kind, reg_addr, reg_wdata, tx_sel);
    end
`endif

endmodule
