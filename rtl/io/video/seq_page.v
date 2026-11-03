// seq_page —— PAGE 2 —— 4 轨 32 步音序器整屏渲染器

`timescale 1ns/1ps

module seq_page #(
    parameter integer COLS = 128,
    parameter integer ROWS = 37,
    parameter integer RENDER_GATED = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sof,

    input  wire        page_sel,
    input  wire [1:0]  trk_sel,
    input  wire [4:0]  step_sel,
    input  wire        ui_mode,

    input  wire [5:0]  p_seq_evt,

    input  wire [3:0]  p_fx_wet,
    input  wire [3:0]  p_fx_room,
    input  wire [3:0]  p_fx_damp,
    input  wire [1:0]  p_fx_spread,

    input  wire [7:0]  bt_status,
    input  wire [7:0]  bt_cmd,
    input  wire [7:0]  bt_seq,
    input  wire        bt_link,
    input  wire [15:0] score_total,
    input  wire [15:0] score_step_ms,
    input  wire [7:0]  score_mode,
    input  wire [7:0]  score_cur,
    input  wire        guide_on,
    input  wire        accomp_active,

    input  wire        tempo_inc,
    input  wire        tempo_dec,

    input  wire        mode_tgl_pulse,
    input  wire        tr_up_pulse,
    input  wire        tr_dn_pulse,
    input  wire        mute_tgl_pulse,
    input  wire        step_clear_pulse,

    output reg         we,
    output reg  [6:0]  w_col,
    output reg  [5:0]  w_row,
    output reg  [7:0]  w_ch,
    output reg  [3:0]  w_color,
    output reg         w_bold,

    output reg         seq_tick,
    output reg  [23:0] seq_pay,
    output reg  [4:0]  seq_cur,
    output reg  [20:0] seq_tempo,
    output reg         seq_play_en,

    input  wire [4:0]  exp_idx,
    output reg  [23:0] exp_pay,

    input  wire        dump_act
);

    localparam [3:0] CIDX_DEFAULT   = 4'd0,
                     CIDX_TITLE     = 4'd1,
                     CIDX_LABEL     = 4'd2,
                     CIDX_VALUE     = 4'd3,
                     CIDX_KEYON     = 4'd4,
                     CIDX_KEYIDLE   = 4'd5,
                     CIDX_OK        = 4'd6,
                     CIDX_WARN      = 4'd7,
                     CIDX_ERR       = 4'd8,
                     CIDX_SECTION   = 4'd9,
                     CIDX_ACCENT    = 4'd10,
                     CIDX_FOCUS     = 4'd11,
                     CIDX_FOCUS_COL = 4'd12,
                     CIDX_FOCUS_ROW = 4'd13,
                     CIDX_OP_OFF    = 4'd14,
                     CIDX_KEYFN     = 4'd15;

    localparam [5:0]  LAST_ROW = ROWS[5:0] - 6'd1;
    localparam [6:0]  LAST_COL = COLS[6:0] - 7'd1;
    localparam [12:0] ROM_DEPTH = COLS * ROWS;

    localparam signed [4:0] TR_MAX = 5'sd12;
    localparam signed [4:0] TR_MIN = -5'sd12;

    reg [31:0]       seq4_on    [0:3];
    reg [4:0]        seq4_pitch [0:3][0:31];
    reg              seq4_mode  [0:3];
    reg signed [4:0] seq4_tr    [0:3];
    reg              seq4_mute  [0:3];

    reg  [4:0] cur_base;
    reg  [4:0] cur_adv;
    wire [4:0] cursor = cur_base + cur_adv;

    reg [20:0] seq_frame_cnt;

    reg [7:0]  tpl_rom [0:ROM_DEPTH-1];
    reg [7:0]  tpl_rd_r;
    reg [7:0]  tpl_hold;

    initial begin
        $readmemh("seq_tpl_rom.hex", tpl_rom);
    end

    wire [20:0] tempo_clamped = (seq_tempo > 21'd64) ? 21'd64 :
                                (seq_tempo < 21'd2)  ? 21'd2  : seq_tempo;
    wire [31:0] ms_calc = (tempo_clamped << 4) + tempo_clamped
                         + (tempo_clamped >> 1) + (tempo_clamped >> 4);
    wire [15:0] ms_per_step = ms_calc[15:0];

    function [7:0] hex_digit;
        input [3:0] v;
        begin
            case (v)
                4'h0: hex_digit = "0";  4'h1: hex_digit = "1";
                4'h2: hex_digit = "2";  4'h3: hex_digit = "3";
                4'h4: hex_digit = "4";  4'h5: hex_digit = "5";
                4'h6: hex_digit = "6";  4'h7: hex_digit = "7";
                4'h8: hex_digit = "8";  4'h9: hex_digit = "9";
                4'ha: hex_digit = "A";  4'hb: hex_digit = "B";
                4'hc: hex_digit = "C";  4'hd: hex_digit = "D";
                4'he: hex_digit = "E";  default: hex_digit = "F";
            endcase
        end
    endfunction

    function [15:0] dec2_le15;
        input [3:0] v;
        reg ge;
        begin
            ge = (v >= 4'd10);
            dec2_le15 = {(ge ? 8'h31 : 8'h30),
                         (ge ? (8'h30 + {4'b0, v} - 8'd10) : (8'h30 + {4'b0, v}))};
        end
    endfunction

    function [23:0] tr_chars;
        input signed [4:0] v;
        reg [4:0] a;
        begin
            a = v[4] ? (5'd0 - v) : v;
            tr_chars = {(a >= 5'd10) ? (8'h30 + {4'b0, a[3:0]} - 8'd10) : 8'h20,
                        (a >= 5'd10) ? 8'h31 : (8'h30 + {4'b0, a[3:0]}),
                        v[4] ? 8'h2D : 8'h2B};
        end
    endfunction

    function [4:0] bar_n;
        input [3:0] v;
        input       wide;
        reg [15:0] sv;
        begin
            sv = wide ? ({12'd0, v} << 2) : {12'd0, v};
            bar_n = ((sv << 3) + (sv << 1)) >> 4;
        end
    endfunction

    function [4:0] eff_pitch;
        input [1:0] t;
        input [4:0] k;
        reg [4:0]  base;
        reg signed [6:0] e;
        begin
            if (seq4_mode[t]) base = seq4_pitch[0][k];
            else                base = seq4_pitch[t][k];
            e = $signed({2'b00, base}) +
                $signed({{2{seq4_tr[t][4]}}, seq4_tr[t]});
            if ((e < 0) || (e > 24)) eff_pitch = 5'd31;
            else                     eff_pitch = e[4:0];
        end
    endfunction

    function [23:0] note_chars;
        input [4:0] p;
        reg [7:0] ltr, dig;
        reg sharp;
        begin
            case (p % 5'd12)
                4'd0: begin ltr = "C"; sharp = 1'b0; end
                4'd1: begin ltr = "C"; sharp = 1'b1; end
                4'd2: begin ltr = "D"; sharp = 1'b0; end
                4'd3: begin ltr = "D"; sharp = 1'b1; end
                4'd4: begin ltr = "E"; sharp = 1'b0; end
                4'd5: begin ltr = "F"; sharp = 1'b0; end
                4'd6: begin ltr = "F"; sharp = 1'b1; end
                4'd7: begin ltr = "G"; sharp = 1'b0; end
                4'd8: begin ltr = "G"; sharp = 1'b1; end
                4'd9: begin ltr = "A"; sharp = 1'b0; end
                4'd10:begin ltr = "A"; sharp = 1'b1; end
                default: begin ltr = "B"; sharp = 1'b0; end
            endcase
            dig = 8'h30 + (3 + p / 5'd12);
            if (sharp) note_chars = {ltr, 8'h23, dig};
            else       note_chars = {ltr, dig, 8'h20};
        end
    endfunction

    function [5:0] pay_of;
        input [1:0] t;
        input [4:0] k;
        reg [4:0] p;
        reg       on;
        begin
            p  = eff_pitch(t, k);
            on = seq4_on[t][k] && !seq4_mute[t] && (p != 5'd31);
            pay_of = {on, p};
        end
    endfunction

    reg [7:0]  tp_s1, tp_s0;
    reg [7:0]  tp_t1, tp_t0;
    reg [7:0]  ms_d3, ms_d2, ms_d1, ms_d0;
    reg [7:0]  rv_w1, rv_w0;
    reg [7:0]  rv_da1, rv_da0;
    reg [7:0]  rv_ro1, rv_ro0;
    reg [7:0]  rv_sp1, rv_sp0;
    reg [7:0]  bt_c1, bt_c0;
    reg [7:0]  bt_q1, bt_q0;
    reg [7:0]  bt_t1, bt_t0;
    reg [7:0]  sc_tot3, sc_tot2, sc_tot1, sc_tot0;
    reg [7:0]  sc_ms2, sc_ms1, sc_ms0;
    reg [7:0]  sc_mo1, sc_mo0;
    reg [7:0]  sc_cu2, sc_cu1, sc_cu0;
    reg [23:0] tr_attr [0:3];
    reg [4:0]  lit_w, lit_da, lit_ro, lit_sp;

    wire [4:0] stp_v = seq_cur + 5'd1;
    wire [4:0] stp_q = (stp_v >= 5'd30) ? 5'd3 :
                       (stp_v >= 5'd20) ? 5'd2 :
                       (stp_v >= 5'd10) ? 5'd1 : 5'd0;
    wire [4:0] stp_r = stp_v - ((stp_q << 3) + (stp_q << 1));

    function is_prep_load;
        input [4:0] i;
        begin
            is_prep_load = (i == 5'd0) || (i == 5'd3) || (i == 5'd8) ||
                           (i == 5'd13) || (i == 5'd17) || (i == 5'd20);
        end
    endfunction

    reg [15:0] prep_v;
    reg [4:0]  prep_i;
    reg [28:0] prod_w;
    reg [15:0] q0;
    reg signed [16:0] r0;
    reg signed [16:0] rc;
    reg [15:0] r0c;

    localparam [4:0] F_NONE   = 5'd0,
                     F_TITLE  = 5'd1,
                     F_RULER  = 5'd2,
                     F_HDR    = 5'd3,
                     F_MODE   = 5'd4,
                     F_TRANSP = 5'd5,
                     F_MUTE   = 5'd6,
                     F_NOTE   = 5'd7,
                     F_GATE   = 5'd8,
                     F_TPMODE = 5'd9,
                     F_TPSTEP = 5'd10,
                     F_TPTMPO = 5'd11,
                     F_TPMS   = 5'd12,
                     F_TPEDIT = 5'd13,
                     F_RVWET  = 5'd14,  F_RVWETB  = 5'd15,
                     F_RVDAMP = 5'd16,  F_RVDAMPB = 5'd17,
                     F_RVROOM = 5'd18,  F_RVROOMB = 5'd19,
                     F_RVSPR  = 5'd20,  F_RVSPRB  = 5'd21,
                     F_BTLNK  = 5'd22,  F_BTCMD   = 5'd23,
                     F_BTSEQ  = 5'd24,  F_BTST    = 5'd25,
                     F_BTUP   = 5'd31,
                     F_SCTOT  = 5'd26,  F_SCMS    = 5'd27,
                     F_SCMODE = 5'd28,  F_SCCUR   = 5'd29,
                     F_GUIDE  = 5'd30;

    reg [4:0]  ctx_fld;
    reg [1:0]  ctx_t;
    reg [4:0]  ctx_k;
    reg [3:0]  ctx_off;
    reg        ctx_on;
    reg [4:0]  ctx_eff;
    reg [23:0] ctx_nc;
    reg        ctx_dot;
    reg        ctx_cur;
    reg        ctx_play;

    reg [4:0]  cf;
    reg [1:0]  ct;
    reg [4:0]  ck;
    reg [3:0]  co;
    reg        c_on, c_dot, c_cur, c_play;
    reg [4:0]  c_eff;
    reg [23:0] c_nc;

    reg [7:0]  ch_w;
    reg [47:0] w6;
    reg [31:0] w32;
    reg [23:0] w24;
    reg [3:0]  col_w;
    reg        bld_w;

    localparam [2:0] ST_IDLE  = 3'd0,
                     ST_PRE   = 3'd1,
                     ST_HOLD  = 3'd2,
                     ST_CALC  = 3'd3,
                     ST_CALC2 = 3'd4,
                     ST_WR    = 3'd5,
                     ST_PREP  = 3'd6;

    reg [2:0] st;
    reg [6:0] cur_c;
    reg [5:0] cur_r;
    reg [7:0] ch_r;
    reg [3:0] col_r;
    reg       bld_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st      <= ST_IDLE;
            cur_r   <= 6'd0;
            cur_c   <= 7'd0;
            we      <= 1'b0;
            w_col   <= 7'd0;
            w_row   <= 6'd0;
            w_ch    <= 8'h20;
            w_color <= 4'd0;
            w_bold  <= 1'b0;
            ch_r    <= 8'h20;
            col_r   <= 4'd0;
            bld_r   <= 1'b0;
            tpl_rd_r   <= 8'h20;
            tpl_hold   <= 8'h20;
            prep_v  <= 16'd0;
            prep_i  <= 5'd0;
            q0 <= 16'd0;
            r0 <= 17'sd0;
            rc <= 17'sd0;
            r0c <= 16'd0;
            prod_w <= 29'd0;
            ctx_fld <= F_NONE;
            ctx_t   <= 2'd0;
            ctx_k   <= 5'd0;
            ctx_off <= 4'd0;
            ctx_on  <= 1'b0;
            ctx_eff <= 5'd0;
            ctx_nc  <= 24'd0;
            ctx_dot <= 1'b0;
            ctx_cur <= 1'b0;
            ctx_play<= 1'b0;
            tp_s1 <= 8'h30;  tp_s0 <= 8'h31;
            tp_t1 <= 8'h30;  tp_t0 <= 8'h38;
            ms_d3 <= 8'h20;  ms_d2 <= 8'h30;  ms_d1 <= 8'h30;  ms_d0 <= 8'h30;
            rv_w1 <= 8'h30;  rv_w0 <= 8'h30;
            rv_da1 <= 8'h30; rv_da0 <= 8'h30;
            rv_ro1 <= 8'h30; rv_ro0 <= 8'h30;
            rv_sp1 <= 8'h30; rv_sp0 <= 8'h30;
            bt_c1 <= 8'h30;  bt_c0 <= 8'h30;
            bt_q1 <= 8'h30;  bt_q0 <= 8'h30;
            bt_t1 <= 8'h30;  bt_t0 <= 8'h30;
            sc_tot3 <= 8'h30; sc_tot2 <= 8'h30; sc_tot1 <= 8'h30; sc_tot0 <= 8'h30;
            sc_ms2 <= 8'h30;  sc_ms1 <= 8'h30;  sc_ms0 <= 8'h30;
            sc_mo1 <= 8'h30;  sc_mo0 <= 8'h30;
            sc_cu2 <= 8'h30;  sc_cu1 <= 8'h30;  sc_cu0 <= 8'h30;
            tr_attr[0] <= {8'h20, 8'h30, 8'h2B};
            tr_attr[1] <= {8'h20, 8'h30, 8'h2B};
            tr_attr[2] <= {8'h20, 8'h30, 8'h2B};
            tr_attr[3] <= {8'h20, 8'h30, 8'h2B};
            lit_w <= 5'd0;  lit_da <= 5'd0;  lit_ro <= 5'd0;  lit_sp <= 5'd0;
        end
        else begin
            we <= 1'b0;

            tpl_rd_r <= tpl_rom[{cur_r, cur_c}];

            case (st)
            ST_IDLE: begin
                if (sof && ((RENDER_GATED == 0) || page_sel)) begin
                    cur_r <= 6'd0;
                    cur_c <= 7'd0;
                    tp_s1 <= (stp_v >= 5'd10) ? (8'h30 + {4'b0, stp_q[2:0]}) : 8'h30;
                    tp_s0 <= 8'h30 + {4'b0, stp_r[3:0]};
                    {rv_w1,  rv_w0}  <= dec2_le15(p_fx_wet);
                    {rv_da1, rv_da0} <= dec2_le15(p_fx_damp);
                    {rv_ro1, rv_ro0} <= dec2_le15(p_fx_room);
                    {rv_sp1, rv_sp0} <= dec2_le15({2'b00, p_fx_spread});
                    bt_c1 <= hex_digit(bt_cmd[7:4]);
                    bt_c0 <= hex_digit(bt_cmd[3:0]);
                    bt_q1 <= hex_digit(bt_seq[7:4]);
                    bt_q0 <= hex_digit(bt_seq[3:0]);
                    bt_t1 <= hex_digit(bt_status[7:4]);
                    bt_t0 <= hex_digit(bt_status[3:0]);
                    tr_attr[0] <= tr_chars(seq4_tr[0]);
                    tr_attr[1] <= tr_chars(seq4_tr[1]);
                    tr_attr[2] <= tr_chars(seq4_tr[2]);
                    tr_attr[3] <= tr_chars(seq4_tr[3]);
                    lit_w  <= bar_n(p_fx_wet, 1'b0);
                    lit_da <= bar_n(p_fx_damp, 1'b0);
                    lit_ro <= bar_n(p_fx_room, 1'b0);
                    lit_sp <= bar_n({2'b00, p_fx_spread}, 1'b1);
                    prep_i <= 5'd0;
                    st     <= ST_PREP;
                end
            end

            ST_PREP: begin
                if (is_prep_load(prep_i)) begin
                    case (prep_i)
                        5'd0:    prep_v <= {12'd0, tempo_clamped[3:0]};
                        5'd3:    prep_v <= ms_per_step;
                        5'd8:    prep_v <= (score_total > 16'd9999) ? 16'd9999
                                                                    : score_total;
                        5'd13:   prep_v <= (score_step_ms > 16'd999) ? 16'd999
                                                                     : score_step_ms;
                        5'd17:   prep_v <= {8'd0, score_mode};
                        default: prep_v <= (score_cur > 8'd999) ? 16'd999
                                                                : {8'd0, score_cur};
                    endcase
                    prep_i <= prep_i + 5'd1;
                end
                else begin
                    prod_w = ({13'd0, prep_v} << 1) + ({13'd0, prep_v} << 3)
                           + ({13'd0, prep_v} << 4) + ({13'd0, prep_v} << 7)
                           + ({13'd0, prep_v} << 8) + ({13'd0, prep_v} << 11)
                           + ({13'd0, prep_v} << 12);
                    q0 = prod_w >> 16;
                    r0 = $signed(prep_v) - $signed({q0[15:0], 3'b000})
                                          - $signed({q0[15:0], 1'b0});
                    if (r0 < 0)       begin q0 = q0 - 16'd1; rc = r0 + 17'sd10; end
                    else if (r0 > 9)  begin q0 = q0 + 16'd1; rc = r0 - 17'sd10; end
                    else              begin                  rc = r0;           end
                    r0c = rc[15:0];
                    case (prep_i)
                        5'd1:  tp_t0   <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd2:  tp_t1   <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd4:  ms_d0   <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd5:  ms_d1   <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd6:  ms_d2   <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd7:  ms_d3   <= (r0c == 16'd0) ? 8'h20
                                                         : (8'h30 + {4'b0, r0c[3:0]});
                        5'd9:  sc_tot0 <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd10: sc_tot1 <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd11: sc_tot2 <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd12: sc_tot3 <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd14: sc_ms0  <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd15: sc_ms1  <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd16: sc_ms2  <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd18: sc_mo0  <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd19: sc_mo1  <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd21: sc_cu0  <= 8'h30 + {4'b0, r0c[3:0]};
                        5'd22: sc_cu1  <= 8'h30 + {4'b0, r0c[3:0]};
                        default: sc_cu2 <= 8'h30 + {4'b0, r0c[3:0]};
                    endcase
                    prep_v <= q0;
                    if (prep_i == 5'd23) begin
                        prep_i <= 5'd0;
                        st     <= ST_PRE;
                    end
                    else prep_i <= prep_i + 5'd1;
                end
            end

            ST_PRE: begin
                st <= ST_HOLD;
            end

            ST_HOLD: begin
                tpl_hold <= tpl_rd_r;
                ctx_fld <= cf;
                ctx_t   <= ct;
                ctx_k   <= ck;
                ctx_off <= co;
                ctx_on  <= c_on;
                ctx_eff <= c_eff;
                ctx_nc  <= c_nc;
                ctx_dot <= c_dot;
                ctx_cur <= c_cur;
                ctx_play<= c_play;
                st <= ST_CALC;
            end

            ST_CALC: begin
                case (ctx_fld)
                F_MODE: begin
                    w6 = seq4_mode[ctx_t] ? "MIRROR" : "INDEP ";
                    ch_w = w6[{3'd5 - ctx_off[2:0], 3'b000} +: 8];
                end
                F_TRANSP: begin
                    if      (ctx_off == 4'd0) ch_w = tr_attr[ctx_t][7:0];
                    else if (ctx_off == 4'd1) ch_w = tr_attr[ctx_t][15:8];
                    else                      ch_w = tr_attr[ctx_t][23:16];
                end
                F_MUTE: begin
                    if      (ctx_off == 4'd0) ch_w = 8'h4F;
                    else if (ctx_off == 4'd1) ch_w = seq4_mute[ctx_t] ? 8'h4E : 8'h46;
                    else                      ch_w = seq4_mute[ctx_t] ? 8'h20 : 8'h46;
                end
                F_NOTE: begin
                    if (ctx_off <= 4'd2) begin
                        if (ctx_on && (ctx_eff != 5'd31))
                            ch_w = ctx_nc[{3'd2 - ctx_off[2:0], 3'b000} +: 8];
                        else
                            ch_w = (ctx_off == 4'd2) ? 8'h20 : 8'h2D;
                    end
                    else ch_w = 8'h20;
                end
                F_GATE: begin
                    if (ctx_off <= 4'd2) ch_w = ctx_on ? 8'h23 : 8'h2D;
                    else                 ch_w = 8'h20;
                end
                F_TPMODE: begin
                    w24 = ui_mode ? {"PLA"} : {"EDI"};
                    ch_w = w24[{3'd2 - ctx_off[2:0], 3'b000} +: 8];
                end
                F_TPEDIT: begin
                    w32 = ui_mode ? "PLAY" : "EDIT";
                    ch_w = w32[{3'd3 - ctx_off[2:0], 3'b000} +: 8];
                end
                F_TPSTEP: ch_w = (ctx_off == 4'd0) ? tp_s1 : tp_s0;
                F_TPTMPO: ch_w = (ctx_off == 4'd0) ? tp_t1 : tp_t0;
                F_TPMS: begin
                    case (ctx_off[1:0])
                        2'd0: ch_w = ms_d3;
                        2'd1: ch_w = ms_d2;
                        2'd2: ch_w = ms_d1;
                        default: ch_w = ms_d0;
                    endcase
                end
                F_RVWET:  ch_w = (ctx_off == 4'd0) ? rv_w1  : rv_w0;
                F_RVDAMP: ch_w = (ctx_off == 4'd0) ? rv_da1 : rv_da0;
                F_RVROOM: ch_w = (ctx_off == 4'd0) ? rv_ro1 : rv_ro0;
                F_RVSPR:  ch_w = (ctx_off == 4'd0) ? rv_sp1 : rv_sp0;
                F_RVWETB, F_RVDAMPB, F_RVROOMB, F_RVSPRB:
                          ch_w = ctx_dot ? 8'h23 : 8'h2D;
                F_BTLNK: begin
                    if      (ctx_off == 4'd0) ch_w = bt_link ? 8'h4F : 8'h2D;
                    else if (ctx_off == 4'd1) ch_w = bt_link ? 8'h4B : 8'h2D;
                    else                      ch_w = 8'h20;
                end
                F_BTCMD: ch_w = (ctx_off == 4'd0) ? bt_c1 : bt_c0;
                F_BTSEQ: ch_w = (ctx_off == 4'd0) ? bt_q1 : bt_q0;
                F_BTST:  ch_w = (ctx_off == 4'd0) ? bt_t1 : bt_t0;
                F_BTUP: begin
                    case (ctx_off)
                        4'd0:    ch_w = 8'h55;
                        4'd1:    ch_w = 8'h50;
                        4'd2, 4'd3: ch_w = 8'h20;
                        4'd4:    ch_w = dump_act ? 8'h5B : 8'h2D;
                        4'd5:    ch_w = dump_act ? 8'h4F : 8'h2D;
                        4'd6:    ch_w = dump_act ? 8'h4E : 8'h2D;
                        default: ch_w = dump_act ? 8'h5D : 8'h20;
                    endcase
                end
                F_SCTOT: begin
                    case (ctx_off[1:0])
                        2'd0: ch_w = sc_tot3;
                        2'd1: ch_w = sc_tot2;
                        2'd2: ch_w = sc_tot1;
                        default: ch_w = sc_tot0;
                    endcase
                end
                F_SCMS: begin
                    case (ctx_off[1:0])
                        2'd0: ch_w = sc_ms2;
                        2'd1: ch_w = sc_ms1;
                        default: ch_w = sc_ms0;
                    endcase
                end
                F_SCMODE: ch_w = (ctx_off == 4'd0) ? sc_mo1 : sc_mo0;
                F_SCCUR: begin
                    case (ctx_off[1:0])
                        2'd0: ch_w = sc_cu2;
                        2'd1: ch_w = sc_cu1;
                        default: ch_w = sc_cu0;
                    endcase
                end
                default: ch_w = tpl_hold;
                endcase
                ch_r <= ch_w;
                st   <= ST_CALC2;
            end

            ST_CALC2: begin
                if (ctx_fld == F_TITLE)       bld_w = 1'b1;
                else if (ctx_fld == F_RULER)  bld_w = (ctx_k == seq_cur);
                else if (ctx_cur)             bld_w = 1'b1;
                else if (ctx_play)            bld_w = 1'b1;
                else if (ctx_fld == F_HDR)    bld_w = 1'b1;
                else if ((ctx_fld == F_MODE) || (ctx_fld == F_TRANSP) ||
                         (ctx_fld == F_MUTE)) bld_w = 1'b1;
                else if (ctx_fld == F_GATE)   bld_w = (ctx_off <= 4'd2) && ctx_on;
                else                          bld_w = 1'b0;
                if (ctx_fld == F_TITLE)
                    col_w = CIDX_TITLE;
                else if (ctx_fld == F_RULER)
                    col_w = (ctx_k == seq_cur) ? CIDX_ACCENT : CIDX_LABEL;
                else if (ctx_cur)
                    col_w = CIDX_FOCUS;
                else if (ctx_play)
                    col_w = CIDX_ACCENT;
                else begin
                    case (ctx_fld)
                    F_HDR:   col_w = (ctx_t == trk_sel) ? CIDX_ACCENT : CIDX_LABEL;
                    F_MODE:  col_w = seq4_mode[ctx_t] ? CIDX_ACCENT : CIDX_LABEL;
                    F_TRANSP: col_w = CIDX_VALUE;
                    F_MUTE:  col_w = seq4_mute[ctx_t] ? CIDX_WARN : CIDX_DEFAULT;
                    F_NOTE:  col_w = (ctx_off <= 4'd2)
                                     ? ((ctx_on && (ctx_eff != 5'd31) &&
                                         !seq4_mute[ctx_t]) ? CIDX_KEYON
                                                            : CIDX_OP_OFF)
                                     : CIDX_DEFAULT;
                    F_GATE:  col_w = (ctx_off <= 4'd2)
                                     ? (ctx_on ? CIDX_KEYON : CIDX_OP_OFF)
                                     : CIDX_DEFAULT;
                    F_TPMODE, F_TPEDIT:
                             col_w = ui_mode ? CIDX_OK : CIDX_WARN;
                    F_TPSTEP, F_TPTMPO, F_TPMS:
                             col_w = CIDX_VALUE;
                    F_RVWET, F_RVDAMP, F_RVROOM, F_RVSPR:
                             col_w = CIDX_VALUE;
                    F_RVWETB, F_RVDAMPB, F_RVROOMB, F_RVSPRB:
                             col_w = ctx_dot ? CIDX_OK : CIDX_OP_OFF;
                    F_BTLNK: col_w = bt_link ? CIDX_OK : CIDX_WARN;
                    F_BTCMD, F_BTSEQ, F_BTST:
                             col_w = CIDX_VALUE;
                    F_BTUP:  col_w = dump_act ? CIDX_OK : CIDX_DEFAULT;
                    F_SCTOT, F_SCMS, F_SCMODE, F_SCCUR:
                             col_w = CIDX_VALUE;
                    F_GUIDE: col_w = (guide_on || accomp_active) ? CIDX_OK
                                                                 : CIDX_VALUE;
                    default: col_w = ((cur_r != 6'd18) && (cur_r != 6'd20) &&
                                      (cur_r != 6'd22) && (cur_r != 6'd24) &&
                                      ((tpl_hold == 8'h2D) || (tpl_hold == 8'h3D)))
                                     ? CIDX_LABEL : CIDX_DEFAULT;
                    endcase
                end
                col_r <= col_w;
                bld_r <= bld_w;
                st    <= ST_WR;
            end

            ST_WR: begin
                we      <= 1'b1;
                w_row   <= cur_r;
                w_col   <= cur_c;
                w_ch    <= ch_r;
                w_color <= col_r;
                w_bold  <= bld_r;

                if ((cur_r == LAST_ROW) && (cur_c == LAST_COL)) begin
                    st <= ST_IDLE;
                end
                else if (cur_c == LAST_COL) begin
                    cur_c <= 7'd0;
                    cur_r <= cur_r + 6'd1;
                    st    <= ST_PRE;
                end
                else begin
                    cur_c <= cur_c + 7'd1;
                    st    <= ST_PRE;
                end
            end

            default: st <= ST_IDLE;
            endcase
        end
    end

    reg [6:0] c0_sel;
    reg [6:0] co7;
    reg       dot_pre;
    always @* begin
        cf = F_NONE;
        ct = 2'd0;
        ck = cur_c[6:2];
        co = 4'd0;
        c0_sel = 7'd0;
        c_on = 1'b0;
        c_eff = 5'd0;
        c_nc = 24'd0;
        c_dot = 1'b0;
        dot_pre = 1'b0;
        co7 = cur_c - c0_sel;
        c_cur = (ck == cursor) &&
                ((cur_r == (6'd3 + {2'b00, trk_sel, 2'b00})) ||
                 (cur_r == (6'd4 + {2'b00, trk_sel, 2'b00})));
        c_play = (ck == seq_cur) && (cur_r >= 6'd3) && (cur_r <= 6'd16) &&
                 ((cur_r[1:0] == 2'd3) || (cur_r[1:0] == 2'd0));
        case (cur_r)
        6'd0: cf = F_TITLE;
        6'd1: cf = F_RULER;
        6'd2, 6'd6, 6'd10, 6'd14: begin
            ct = cur_r[3:2];
            if      ((cur_c >= 7'd23) && (cur_c <= 7'd28)) begin
                cf = F_MODE;    c0_sel = 7'd23;
            end
            else if ((cur_c >= 7'd38) && (cur_c <= 7'd40)) begin
                cf = F_TRANSP;  c0_sel = 7'd38;
            end
            else if ((cur_c >= 7'd48) && (cur_c <= 7'd50)) begin
                cf = F_MUTE;    c0_sel = 7'd48;
            end
            else cf = F_HDR;
        end
        6'd3, 6'd7, 6'd11, 6'd15: begin
            cf = F_NOTE;
            ct = cur_r[3:2];
            co = {2'b0, cur_c[1:0]};
            c_on = seq4_on[ct][ck];
            c_eff = eff_pitch(ct, ck);
            if (c_on && (c_eff != 5'd31)) c_nc = note_chars(c_eff);
        end
        6'd4, 6'd8, 6'd12, 6'd16: begin
            cf = F_GATE;
            ct = cur_r[3:2] - 2'd1;
            co = {2'b0, cur_c[1:0]};
            c_on = seq4_on[ct][ck];
        end
        6'd18: begin
            if      ((cur_c >= 7'd13) && (cur_c <= 7'd15)) begin
                cf = F_TPMODE;  c0_sel = 7'd13;
            end
            else if ((cur_c >= 7'd27) && (cur_c <= 7'd28)) begin
                cf = F_TPSTEP;  c0_sel = 7'd27;
            end
            else if ((cur_c >= 7'd45) && (cur_c <= 7'd46)) begin
                cf = F_TPTMPO;  c0_sel = 7'd45;
            end
            else if ((cur_c >= 7'd61) && (cur_c <= 7'd64)) begin
                cf = F_TPMS;    c0_sel = 7'd61;
            end
            else if ((cur_c >= 7'd84) && (cur_c <= 7'd87)) begin
                cf = F_TPEDIT;  c0_sel = 7'd84;
            end
        end
        6'd20: begin
            if      ((cur_c >= 7'd23) && (cur_c <= 7'd24)) begin
                cf = F_RVWET;   c0_sel = 7'd23;
            end
            else if ((cur_c >= 7'd27) && (cur_c <= 7'd36)) begin
                cf = F_RVWETB;  c0_sel = 7'd27;  dot_pre = 1'b1;
            end
            else if ((cur_c >= 7'd54) && (cur_c <= 7'd55)) begin
                cf = F_RVDAMP;  c0_sel = 7'd54;
            end
            else if ((cur_c >= 7'd58) && (cur_c <= 7'd67)) begin
                cf = F_RVDAMPB; c0_sel = 7'd58;  dot_pre = 1'b1;
            end
            else if ((cur_c >= 7'd85) && (cur_c <= 7'd86)) begin
                cf = F_RVROOM;  c0_sel = 7'd85;
            end
            else if ((cur_c >= 7'd89) && (cur_c <= 7'd98)) begin
                cf = F_RVROOMB; c0_sel = 7'd89;  dot_pre = 1'b1;
            end
            else if ((cur_c >= 7'd114) && (cur_c <= 7'd115)) begin
                cf = F_RVSPR;   c0_sel = 7'd114;
            end
            else if ((cur_c >= 7'd118) && (cur_c <= 7'd127)) begin
                cf = F_RVSPRB;  c0_sel = 7'd118; dot_pre = 1'b1;
            end
        end
        6'd22: begin
            if      ((cur_c >= 7'd16) && (cur_c <= 7'd18)) begin
                cf = F_BTLNK;   c0_sel = 7'd16;
            end
            else if ((cur_c >= 7'd26) && (cur_c <= 7'd27)) begin
                cf = F_BTCMD;   c0_sel = 7'd26;
            end
            else if ((cur_c >= 7'd35) && (cur_c <= 7'd36)) begin
                cf = F_BTSEQ;   c0_sel = 7'd35;
            end
            else if ((cur_c >= 7'd49) && (cur_c <= 7'd50)) begin
                cf = F_BTST;    c0_sel = 7'd49;
            end
            else if ((cur_c >= 7'd53) && (cur_c <= 7'd60)) begin
                cf = F_BTUP;    c0_sel = 7'd53;
            end
        end
        6'd24: begin
            if      ((cur_c >= 7'd9) && (cur_c <= 7'd12)) begin
                cf = F_SCTOT;   c0_sel = 7'd9;
            end
            else if ((cur_c >= 7'd22) && (cur_c <= 7'd24)) begin
                cf = F_SCMS;    c0_sel = 7'd22;
            end
            else if ((cur_c >= 7'd41) && (cur_c <= 7'd42)) begin
                cf = F_SCMODE;  c0_sel = 7'd41;
            end
            else if ((cur_c >= 7'd46) && (cur_c <= 7'd59)) begin
                cf = F_GUIDE;
            end
            else if ((cur_c >= 7'd79) && (cur_c <= 7'd81)) begin
                cf = F_SCCUR;   c0_sel = 7'd79;
            end
        end
        default: cf = F_NONE;
        endcase
        co7 = cur_c - c0_sel;
        if ((cf != F_NOTE) && (cf != F_GATE))
            co = co7[3:0];
        if (dot_pre)
            c_dot = (co7 < {2'b0,
                     (cf == F_RVWETB)  ? lit_w  :
                     (cf == F_RVDAMPB) ? lit_da :
                     (cf == F_RVROOMB) ? lit_ro : lit_sp});
    end

    reg [5:0] evt_r1, evt_r2, evt_d2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            evt_r1 <= 6'd0;
            evt_r2 <= 6'd0;
            evt_d2 <= 6'd0;
        end
        else begin
            evt_r1 <= p_seq_evt;
            evt_r2 <= evt_r1;
            evt_d2 <= evt_r2;
        end
    end
    wire evt_hit = evt_r2[5] ^ evt_d2[5];
    wire key_wr  = evt_hit && page_sel && !ui_mode;

    reg [2:0] rst_i;
    reg [5:0] rst_j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_base <= 5'd0;
            cur_adv  <= 5'd0;
            for (rst_i = 3'd0; rst_i < 3'd4; rst_i = rst_i + 3'd1) begin
                seq4_on[rst_i[1:0]]   <= 32'd0;
                seq4_mode[rst_i[1:0]] <= 1'b0;
                seq4_tr[rst_i[1:0]]   <= 5'sd0;
                seq4_mute[rst_i[1:0]] <= 1'b0;
                for (rst_j = 6'd0; rst_j < 6'd32; rst_j = rst_j + 6'd1)
                    seq4_pitch[rst_i[1:0]][rst_j[4:0]] <= 5'd0;
                `ifdef SIMULATION
                if (6'd32 != 6'd32 || 6'd32 <= 6'd0)
                    $display("*** ERROR seq_page: 复位上界 6'd32 异常（截断？）");
                `endif
            end
        end
        else begin
            if (step_sel != cur_base) begin
                cur_base <= step_sel;
                cur_adv  <= 5'd0;
            end
            if (page_sel && !ui_mode) begin
                if (mode_tgl_pulse)
                    seq4_mode[trk_sel] <= ~seq4_mode[trk_sel];
                if (tr_up_pulse)
                    seq4_tr[trk_sel] <= (seq4_tr[trk_sel] >= TR_MAX)
                                        ? TR_MAX : (seq4_tr[trk_sel] + 5'sd1);
                if (tr_dn_pulse)
                    seq4_tr[trk_sel] <= (seq4_tr[trk_sel] <= TR_MIN)
                                        ? TR_MIN : (seq4_tr[trk_sel] - 5'sd1);
                if (mute_tgl_pulse)
                    seq4_mute[trk_sel] <= ~seq4_mute[trk_sel];
                if (step_clear_pulse)
                    seq4_on[trk_sel][cursor] <= 1'b0;
            end
            if (key_wr) begin
                seq4_pitch[trk_sel][cursor] <= evt_r2[4:0];
                seq4_on[trk_sel][cursor]    <= 1'b1;
                if (seq4_mode[trk_sel]) seq4_mode[trk_sel] <= 1'b0;
                cur_adv <= cur_adv + 5'd1;
            end
        end
    end

    reg [4:0] pay_nxt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_frame_cnt <= 21'd0;
            seq_cur       <= 5'd0;
            seq_play_en   <= 1'b0;
            seq_tick      <= 1'b0;
            seq_pay       <= 24'd0;
        end
        else begin
            seq_play_en <= ui_mode;
            seq_tick    <= 1'b0;

            if (sof) begin
                if (!ui_mode) begin
                    seq_frame_cnt <= 21'd0;
                end
                else if (seq_frame_cnt >= seq_tempo) begin
                    seq_frame_cnt <= 21'd0;
                    seq_cur       <= seq_cur + 5'd1;
                    seq_tick      <= 1'b1;
                    pay_nxt = seq_cur + 5'd1;
                    seq_pay[5:0]   <= pay_of(2'd0, pay_nxt);
                    seq_pay[11:6]  <= pay_of(2'd1, pay_nxt);
                    seq_pay[17:12] <= pay_of(2'd2, pay_nxt);
                    seq_pay[23:18] <= pay_of(2'd3, pay_nxt);
                end
                else seq_frame_cnt <= seq_frame_cnt + 21'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) seq_tempo <= 21'd8;
        else if (tempo_inc) begin
            if (seq_tempo >= 21'd64) seq_tempo <= 21'd64;
            else                     seq_tempo <= seq_tempo + 21'd1;
        end
        else if (tempo_dec) begin
            if (seq_tempo <= 21'd2) seq_tempo <= 21'd2;
            else                    seq_tempo <= seq_tempo - 21'd1;
        end
    end

    function [5:0] exp_cell;
        input [1:0] t;
        input [4:0] k;
        reg   [4:0] p;
        begin
            p = eff_pitch(t, k);
            if (seq4_on[t][k] && (p != 5'd31))
                exp_cell = {1'b1, p};
            else
                exp_cell = 6'd0;
        end
    endfunction

    wire [23:0] exp_pay_c = { exp_cell(2'd3, exp_idx),
                              exp_cell(2'd2, exp_idx),
                              exp_cell(2'd1, exp_idx),
                              exp_cell(2'd0, exp_idx) };

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) exp_pay <= 24'd0;
        else        exp_pay <= exp_pay_c;
    end

endmodule
