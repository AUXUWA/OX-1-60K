// param_panel —— 把「当前单音 4 算子 FM 合成链路的参数」渲染成左侧文本面板

`timescale 1ns/1ps

module param_panel #(
    parameter integer PANEL_COLS = 42,
    parameter integer PANEL_ROWS = 37,
    parameter integer HOLD_TICKS = 38400000,

    parameter integer SEQ_STEP_FRAMES = 8
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        sof,

    input  wire [2:0]  p_algo,
    input  wire [2:0]  p_fb,
    input  wire [9:0]  p_fnum,
    input  wire [2:0]  p_block,
    input  wire [15:0] p_mult,
    input  wire [23:0] p_tl,
    input  wire [15:0] p_ar,
    input  wire [15:0] p_dr,
    input  wire [15:0] p_sl,
    input  wire [15:0] p_rr,
    input  wire [11:0] p_wf,
    input  wire [4:0]  p_patch,
    input  wire        p_gate,
    input  wire        p_cfg_ok,
    input  wire [3:0]  p_led,

    input  wire [7:0]  p_vol,
    input  wire [7:0]  p_vib_depth,

    input  wire        p_glide_en,
    input  wire        p_vel_en,

    input  wire        p_fx_en,
    input  wire [2:0]  p_fx_room,
    input  wire [3:0]  p_fx_damp,
    input  wire [2:0]  p_fx_wet,
    input  wire        p_fx_spread,
    input  wire [3:0]  p_fx_width,
    input  wire [7:0]  p_fx_predelay,

    input  wire [3:0]  cur_note,
    input  wire [2:0]  cur_oct,
    input  wire        sustain_on,
    input  wire        mode_flag,
    input  wire [4:0]  cur_patch,

    input  wire [3:0]  p_cur_page,
    input  wire [1:0]  p_cur_focus,
    input  wire        p_ui_mode,
    input  wire        p_tempo_pulse,
    input  wire        p_tempo_dir,

    input  wire [3:0]  p_cur_key,
    input  wire        p_key_on,
    input  wire        p_key_hi,
    input  wire        p_ui_layer,
    input  wire [5:0]  p_fn_btn,

    input  wire [5:0]  p_seq_evt,

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

    input  wire [1:0]  test_st,

    output reg         we,
    output reg  [5:0]  w_col,
    output reg  [5:0]  w_row,
    output reg  [7:0]  w_ch,
    output reg  [3:0]  w_color,
    output reg         w_bold,

    output wire        seq_tick,
    output wire [4:0]  seq_step,
    output wire        seq_step_on
);

    localparam integer NCELL = PANEL_COLS * PANEL_ROWS;

    localparam [3:0] CIDX_DEFAULT = 4'd0,
                     CIDX_TITLE   = 4'd1,
                     CIDX_LABEL   = 4'd2,
                     CIDX_VALUE   = 4'd3,
                     CIDX_KEYON   = 4'd4,
                     CIDX_KEYIDLE = 4'd5,
                     CIDX_OK      = 4'd6,
                     CIDX_WARN    = 4'd7,
                     CIDX_ERR     = 4'd8,
                     CIDX_SECTION = 4'd9,
                     CIDX_ACCENT  = 4'd10,
                     CIDX_FOCUS   = 4'd11,
                     CIDX_FOCUS_COL = 4'd12,
                     CIDX_FOCUS_ROW = 4'd13,
                     CIDX_OP_OFF  = 4'd14,
                     CIDX_KEYFN   = 4'd15;

    function [7:0] tpl_char;
        input [5:0] r;
        input [5:0] c;
        reg [8*42-1:0] line;
        begin
            line = "                                          ";
            case (r)
                6'd0 : line = " OX-1  FM SYNTH             1024x600      ";
                6'd1 : line = "------------------------------------------";
                6'd2 : line = " PATCH ##    ALGO #     FB #              ";
                6'd3 : line = " FNUM ###    BLOCK #                      ";
                6'd4 : line = "------------------------------------------";
                6'd5 : line = " FIELD    OP0     OP1     OP2     OP3     ";
                6'd6 : line = " WF        #       #       #       #      ";
                6'd7 : line = " MULT      #       #       #       #      ";
                6'd8 : line = " TL        ##      ##      ##      ##     ";
                6'd9 : line = " AR        ##      ##      ##      ##     ";
                6'd10: line = " DR        ##      ##      ##      ##     ";
                6'd11: line = " SL        ##      ##      ##      ##     ";
                6'd12: line = " RR        ##      ##      ##      ##     ";
                6'd13: line = "------------------------------------------";
                6'd14: line = " STATUS ----/---- TEMPO 08  EDIT DFLT     ";
                6'd15: line = " GATE#CODEC# LED# VOL255 VIB1             ";
                6'd16: line = "------------------------------------------";
                6'd17: line = " KEYS  OCT @   PATCH ##  [UUUU]  MODE V   ";
                6'd18: line = "  C  C% D  D% E  F  F% G  G% A  A% B  C   ";
                6'd19: line = "  @  @  @  @  @  @  @  @  @  @  @  @  @   ";
                6'd20: line = " ---===---===------===---===---===------  ";
                6'd21: line = "  C  C% D  D% E  F  F% G  G% A  A% B  C   ";
                6'd22: line = "  @  @  @  @  @  @  @  @  @  @  @  @  @   ";
                6'd23: line = " ---===---===------===---===---===------  ";
                6'd24: line = "------------------------------------------";
                6'd25: line = " REVERB  4-LINE FDN + HAAS                ";
                6'd26: line = " EN #    ROOM #  DAMP #   WET #   WID #   ";
                6'd27: line = " SPR #  PRED ##  RT60 .## s   [#-------]  ";
                6'd28: line = "  Room      Studio    Plate     Hall      ";
                6'd29: line = "  Chamber   Audit     Church    Cath      ";
                6'd30: line = "------------------------------------------";
                6'd31: line = " BT  LINK OK  CMD 03  SEQ 12  ST 00 VEL   ";
                6'd32: line = " SCORE 0080 STEPS  0060 MS/STEP  MODE 2   ";
                6'd33: line = "------------------------------------------";
                6'd34: line = " GUIDE ON   ACCOMP ON   HEAD 003/0080 GLD ";
                6'd35: line = " GUIDE LED 25 KEYS  WS2812 ACCOMP ON      ";
                6'd36: line = " MODE EDIT   GUIDE MODE 2 LEDS 25 TEST-   ";
                default: line = "                                          ";
            endcase
            tpl_char = line[(8*(41-c)) +: 8];
        end
    endfunction

function [7:0] room_rt60_cs;
    input [2:0] room;
    begin
        case (room)
            3'd0: room_rt60_cs = 8'd50;
            3'd1: room_rt60_cs = 8'd73;
            3'd2: room_rt60_cs = 8'd91;
            3'd3: room_rt60_cs = 8'd141;
            3'd4: room_rt60_cs = 8'd161;
            3'd5: room_rt60_cs = 8'd186;
            3'd6: room_rt60_cs = 8'd200;
            default: room_rt60_cs = 8'd225;
        endcase
    end
    endfunction


    function [3:0] patch_tens;
        input [4:0] v;
        begin
            patch_tens = (v >= 5'd20) ? 4'd2 : (v >= 5'd10) ? 4'd1 : 4'd0;
        end
    endfunction

    function [3:0] patch_ones;
        input [4:0] v;
        reg [4:0] d;
        begin
            d = (v >= 5'd20) ? (v - 5'd20) : (v >= 5'd10) ? (v - 5'd10) : v;
            patch_ones = d[3:0];
        end
    endfunction

    function [3:0] field_val;
        input [5:0] r;
        input [2:0] s;
        reg [7:0] rt_cs;
        begin
            field_val = 4'h0;

            case (r)
            6'd2: case (s)
                      3'd0: field_val = patch_tens(p_patch);
                      3'd1: field_val = patch_ones(p_patch);
                      3'd2: field_val = {1'b0, p_algo};
                      3'd3: field_val = {1'b0, p_fb};
                  endcase

            6'd3: case (s)
                      3'd0: field_val = {2'b00, p_fnum[9:8]};
                      3'd1: field_val = p_fnum[7:4];
                      3'd2: field_val = p_fnum[3:0];
                      3'd3: field_val = {1'b0, p_block};
                  endcase

            6'd17: case (s)
                      3'd0: field_val = patch_tens(cur_patch);
                      3'd1: field_val = patch_ones(cur_patch);
                  endcase

            6'd6: case (s)
                      3'd0: field_val = {1'b0, p_wf[2:0]};
                      3'd1: field_val = {1'b0, p_wf[5:3]};
                      3'd2: field_val = {1'b0, p_wf[8:6]};
                      3'd3: field_val = {1'b0, p_wf[11:9]};
                  endcase

            6'd7: case (s)
                      3'd0: field_val = p_mult[3:0];
                      3'd1: field_val = p_mult[7:4];
                      3'd2: field_val = p_mult[11:8];
                      3'd3: field_val = p_mult[15:12];
                  endcase

            6'd8: case (s)
                      3'd0: field_val = p_tl[5:2];
                      3'd1: field_val = {2'b00, p_tl[1:0]};
                      3'd2: field_val = p_tl[11:8];
                      3'd3: field_val = {2'b00, p_tl[7:6]};
                      3'd4: field_val = p_tl[17:14];
                      3'd5: field_val = {2'b00, p_tl[13:12]};
                      3'd6: field_val = p_tl[23:20];
                      3'd7: field_val = {2'b00, p_tl[19:18]};
                  endcase

            6'd9: case (s)
                      3'd0: field_val = p_ar[3:2];
                      3'd1: field_val = {2'b00, p_ar[1:0]};
                      3'd2: field_val = p_ar[7:6];
                      3'd3: field_val = {2'b00, p_ar[5:4]};
                      3'd4: field_val = p_ar[11:10];
                      3'd5: field_val = {2'b00, p_ar[9:8]};
                      3'd6: field_val = p_ar[15:14];
                      3'd7: field_val = {2'b00, p_ar[13:12]};
                  endcase

            6'd10: case (s)
                      3'd0: field_val = p_dr[3:2];
                      3'd1: field_val = {2'b00, p_dr[1:0]};
                      3'd2: field_val = p_dr[7:6];
                      3'd3: field_val = {2'b00, p_dr[5:4]};
                      3'd4: field_val = p_dr[11:10];
                      3'd5: field_val = {2'b00, p_dr[9:8]};
                      3'd6: field_val = p_dr[15:14];
                      3'd7: field_val = {2'b00, p_dr[13:12]};
                  endcase

            6'd11: case (s)
                      3'd0: field_val = p_sl[3:2];
                      3'd1: field_val = {2'b00, p_sl[1:0]};
                      3'd2: field_val = p_sl[7:6];
                      3'd3: field_val = {2'b00, p_sl[5:4]};
                      3'd4: field_val = p_sl[11:10];
                      3'd5: field_val = {2'b00, p_sl[9:8]};
                      3'd6: field_val = p_sl[15:14];
                      3'd7: field_val = {2'b00, p_sl[13:12]};
                  endcase

            6'd12: case (s)
                      3'd0: field_val = p_rr[3:2];
                      3'd1: field_val = {2'b00, p_rr[1:0]};
                      3'd2: field_val = p_rr[7:6];
                      3'd3: field_val = {2'b00, p_rr[5:4]};
                      3'd4: field_val = p_rr[11:10];
                      3'd5: field_val = {2'b00, p_rr[9:8]};
                      3'd6: field_val = p_rr[15:14];
                      3'd7: field_val = {2'b00, p_rr[13:12]};
                  endcase

            6'd15: case (s)
                      3'd0: field_val = {3'b0, p_gate};
                      3'd1: field_val = {3'b0, p_cfg_ok};
                      3'd2: field_val = p_led;
                   endcase

            6'd26: case (s)
                      3'd0: field_val = {3'b0, p_fx_en};
                      3'd1: field_val = {1'b0, p_fx_room};
                      3'd2: field_val = p_fx_damp;
                      3'd3: field_val = {1'b0, p_fx_wet};
                      3'd4: field_val = p_fx_width;
                   endcase

            6'd27: begin
                      rt_cs = room_rt60_cs(p_fx_room);
                      case (s)
                          3'd0: field_val = {3'b0, p_fx_spread};
                          3'd1: field_val = p_fx_predelay[7:4];
                          3'd2: field_val = p_fx_predelay[3:0];
                          3'd3: field_val = rt_cs[7:4];
                          3'd4: field_val = rt_cs[3:0];
                          default: field_val = 4'h0;
                      endcase
                  end

            default: field_val = 4'h0;
            endcase
        end
    endfunction

    function [7:0] hex_digit;
        input [3:0] v;
        begin
            hex_digit = (v < 4'd10) ? (8'h30 + {4'b0, v}) : (8'h41 + {4'b0, v} - 8'd10);
        end
    endfunction


    function [3:0] nib_safe;
        input [3:0] v;
        begin
            case (v)
                4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7,
                4'h8, 4'h9, 4'hA, 4'hB, 4'hC, 4'hD, 4'hE, 4'hF:
                    nib_safe = v;
                default: nib_safe = 4'h0;
            endcase
        end
    endfunction

    function b1_safe;
        input b;
        begin
            case (b)
                1'b0:   b1_safe = 1'b0;
                1'b1:   b1_safe = 1'b1;
                default: b1_safe = 1'b0;
            endcase
        end
    endfunction

    function status_ok;
        input [7:0] v;
        begin
            case (v)
                8'h00, 8'hxx, 8'hzz: status_ok = 1'b1;
                default:             status_ok = 1'b0;
            endcase
        end
    endfunction

    function mode_ge2;
        input [7:0] v;
        begin
            case (v)
                8'h00, 8'h01, 8'hxx, 8'hzz: mode_ge2 = 1'b0;
                default:                     mode_ge2 = 1'b1;
            endcase
        end
    endfunction


    function [7:0] key_oct_digit_ch;
        input [5:0] r;
        input [5:0] c;
        reg [1:0] add;
        reg [4:0] t5;
        reg [3:0] snd;
        begin
            if (r == 6'd17) begin
                snd = {2'b0, cur_oct} + 4'd2;
            end
            else begin
                case (c)
                    6'd2,  6'd5,  6'd8,  6'd11, 6'd14, 6'd17,
                    6'd20, 6'd23, 6'd26, 6'd29, 6'd32, 6'd35:
                                       add = (r == 6'd22) ? 2'd1 : 2'd0;
                    6'd38:             add = (r == 6'd22) ? 2'd2 : 2'd1;
                    default:           add = 2'd0;
                endcase
                t5  = {2'b0, cur_oct} + {3'b0, add};
                snd = (t5 > 5'd5) ? 4'd7 : ({2'b0, t5[2:0]} + 4'd2);
            end
            key_oct_digit_ch = 8'h30 + {4'b0, snd};
        end
    endfunction


    wire [4:0] p25_cur_key5 = {p_key_hi, p_cur_key};
    wire       p25_note_ok  = p_key_on && (p25_cur_key5 != 5'h1F) && (p25_cur_key5 < 5'd25);

    wire [25:0] hold_cnt_max = HOLD_TICKS[25:0];

    reg        held;
    reg [4:0]  last_note;
    reg [25:0] last_timer;

    wire       p25_key_press = p25_note_ok;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            held       <= 1'b0;
            last_note  <= 5'h1F;
            last_timer <= 26'd0;
        end
        else if (p25_key_press) begin
            held       <= 1'b1;
            last_note  <= p25_cur_key5;
            last_timer <= 26'd0;
        end
        else if (held) begin
            held       <= 1'b0;
            last_timer <= hold_cnt_max;
        end
        else if (last_timer != 26'd0) begin
            last_timer <= last_timer - 26'd1;
        end
    end

    wire       hl_on  = p25_key_press | (last_timer != 26'd0);
    wire [4:0] hl_key = p25_key_press ? p25_cur_key5 : last_note;

    wire [6:0] hl_3k = {2'b0, hl_key, 1'b0} + {3'b0, hl_key};
    wire [5:0] hl_c0a = hl_3k[5:0] + 6'd1;
    wire [5:0] hl_c2a = hl_c0a + 6'd2;
    wire [6:0] hl_c0b7 = hl_3k - 7'd35;
    wire [5:0] hl_c0b  = hl_c0b7[5:0];
    wire [5:0] hl_c2b  = hl_c0b + 6'd2;

    function hl_cell;
        input [5:0] r;
        input [5:0] c;
        reg hit_a, hit_b;
        begin
            hit_a = (hl_key <  5'd13) && (r >= 6'd18) && (r <= 6'd20) &&
                    (c >= hl_c0a) && (c <= hl_c2a);
            hit_b = (hl_key >= 5'd12) && (r >= 6'd21) && (r <= 6'd23) &&
                    (c >= hl_c0b) && (c <= hl_c2b);
            hl_cell = hl_on && (hit_a || hit_b);
        end
    endfunction


    localparam [5:0] FOCUS_ROW_NONE = 6'd63;
    localparam [3:0] PAGE_RESET     = 4'd1;

    reg [3:0] ui_page_r1,  ui_page_r2;
    reg [1:0] ui_focus_r1, ui_focus_r2;
    reg       ui_mode_r1,  ui_mode_r2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ui_page_r1  <= PAGE_RESET;
            ui_page_r2  <= PAGE_RESET;
            ui_focus_r1 <= 2'd0;
            ui_focus_r2 <= 2'd0;
            ui_mode_r1  <= 1'b0;
            ui_mode_r2  <= 1'b0;
        end
        else begin
            ui_page_r1  <= p_cur_page;
            ui_page_r2  <= ui_page_r1;
            ui_focus_r1 <= p_cur_focus;
            ui_focus_r2 <= ui_focus_r1;
            ui_mode_r1  <= p_ui_mode;
            ui_mode_r2  <= ui_mode_r1;
        end
    end

    wire [3:0] cur_page  = ui_page_r2;

    function [3:0] knob_leg_dig;
        input [5:0] r;
        begin
            case (cur_page)
            4'd0: case (r)
                      6'd6:  knob_leg_dig = 4'd0;
                      6'd7:  knob_leg_dig = 4'd1;
                      6'd8:  knob_leg_dig = 4'd2;
                      default: knob_leg_dig = 4'hF;
                  endcase
            4'd1: case (r)
                      6'd9:  knob_leg_dig = 4'd0;
                      6'd10: knob_leg_dig = 4'd1;
                      6'd11: knob_leg_dig = 4'd2;
                      6'd12: knob_leg_dig = 4'd3;
                      default: knob_leg_dig = 4'hF;
                  endcase
            default: knob_leg_dig = 4'hF;
            endcase
        end
    endfunction
    function knob_leg_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            knob_leg_hit = (c == 6'd5) && (r >= 6'd6) && (r <= 6'd12)
                           && (knob_leg_dig(r) != 4'hF);
        end
    endfunction

    function room_hl;
        input [5:0] r;
        input [5:0] c;
        begin
            room_hl = ((r == 6'd28) && (p_fx_room < 3'd4)) ||
                      ((r == 6'd29) && (p_fx_room >= 3'd4));
            if (room_hl) begin
                case (p_fx_room[1:0])
                    2'd0: room_hl = (c >= 6'd2)  && (c <= 6'd8);
                    2'd1: room_hl = (c >= 6'd12) && (c <= 6'd17);
                    2'd2: room_hl = (c >= 6'd22) && (c <= 6'd27);
                    2'd3: room_hl = (c >= 6'd32) && (c <= 6'd35);
                endcase
            end
        end
    endfunction
    wire [1:0] cur_focus = ui_focus_r2;
    wire       ui_mode   = ui_mode_r2;
    wire [2:0] focus_k   = {1'b0, cur_focus};

    function [5:0] focus_row_of;
        input [3:0] page;
        begin
            case (page)
                4'd0   : focus_row_of = 6'd6;
                4'd1   : focus_row_of = 6'd9;
                4'd2   : focus_row_of = 6'd26;
                4'd3   : focus_row_of = 6'd26;
                4'd4   : focus_row_of = 6'd15;
                default: focus_row_of = FOCUS_ROW_NONE;
            endcase
        end
    endfunction

    function [2:0] op_col_of;
        input [5:0] r;
        input [5:0] c;
        begin
            if      ((r < 6'd5) || (r > 6'd12))       op_col_of = 3'd4;
            else if ((c >= 6'd8)  && (c <= 6'd15))    op_col_of = 3'd0;
            else if ((c >= 6'd16) && (c <= 6'd23))    op_col_of = 3'd1;
            else if ((c >= 6'd24) && (c <= 6'd31))    op_col_of = 3'd2;
            else if ((c >= 6'd32) && (c <= 6'd39))    op_col_of = 3'd3;
            else                                       op_col_of = 3'd4;
        end
    endfunction

    function [5:0] grp_left_col;
        input [2:0] k;
        begin
            grp_left_col = ({3'b000, k} << 3) + 6'd8;
        end
    endfunction

    function focus_cell;
        input [5:0] r;
        input [5:0] c;
        begin
            focus_cell = (r == focus_row_of(cur_page)) &&
                         (op_col_of(r, c) == focus_k);
        end
    endfunction

    function focus_col_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            focus_col_hit = (op_col_of(r, c) == focus_k) && !focus_cell(r, c);
        end
    endfunction

    function focus_row_hit;
        input [5:0] r;
        reg [5:0] fr;
        begin
            fr = focus_row_of(cur_page);
            if (fr == FOCUS_ROW_NONE) focus_row_hit = (r == 6'd2) || (r == 6'd3);
            else                       focus_row_hit = (r == fr);
        end
    endfunction

    function focus_row_cell_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            focus_row_cell_hit = focus_row_hit(r) && (c <= 6'd4);
        end
    endfunction

    wire       vol_ge200 = (p_vol >= 8'd200);
    wire       vol_ge100 = (p_vol >= 8'd100);
    wire [3:0] vol_d2    = vol_ge200 ? 4'd2 : (vol_ge100 ? 4'd1 : 4'd0);
    wire [7:0] vol_r100  = p_vol - (vol_ge200 ? 8'd200 :
                                    (vol_ge100 ? 8'd100 : 8'd0));
    wire       vol_ge50  = (vol_r100 >= 8'd50);
    wire [7:0] vol_r50   = vol_r100 - (vol_ge50 ? 8'd50 : 8'd0);
    wire       vol_ge20  = (vol_r50  >= 8'd20);
    wire [7:0] vol_r20   = vol_r50  - (vol_ge20 ? 8'd20 : 8'd0);
    wire       vol_ge10  = (vol_r20  >= 8'd10);
    wire [7:0] vol_r10   = vol_r20  - (vol_ge10 ? 8'd10 : 8'd0);
    wire [3:0] vol_d1    = (vol_ge50 ? 4'd5 : 4'd0)
                         + (vol_ge20 ? 4'd2 : 4'd0)
                         + (vol_ge10 ? 4'd1 : 4'd0);
    wire [3:0] vol_d0    = vol_r10[3:0];
    wire [3:0] vib_d0    = (p_vib_depth > 8'd8) ? 4'd8 : p_vib_depth[3:0];

    function [7:0] vol_dig_ch;
        input [5:0] c;
        begin
            case (c)
                6'd21:   vol_dig_ch = 8'h30 + {4'b0, vol_d2};
                6'd22:   vol_dig_ch = 8'h30 + {4'b0, vol_d1};
                6'd23:   vol_dig_ch = 8'h30 + {4'b0, vol_d0};
                default: vol_dig_ch = 8'h20;
            endcase
        end
    endfunction

    function [7:0] vib_dig_ch;
        input [5:0] c;
        begin
            vib_dig_ch = (c == 6'd28) ? (8'h30 + {4'b0, vib_d0}) : 8'h20;
        end
    endfunction

    reg  [20:0] seq_tempo;
    wire [20:0] tempo_shown = (seq_tempo > 21'd64) ? 21'd64 :
                             (seq_tempo < 21'd2)  ? 21'd2  : seq_tempo;
    wire       tmp_ge40 = (tempo_shown >= 21'd40);
    wire [20:0] tmp_r40 = tempo_shown - (tmp_ge40 ? 21'd40 : 21'd0);
    wire       tmp_ge20 = (tmp_r40  >= 21'd20);
    wire [20:0] tmp_r20 = tmp_r40  - (tmp_ge20 ? 21'd20 : 21'd0);
    wire       tmp_ge10 = (tmp_r20  >= 21'd10);
    wire [20:0] tmp_r10 = tmp_r20  - (tmp_ge10 ? 21'd10 : 21'd0);
    wire [3:0] tmp_d1    = (tmp_ge40 ? 4'd4 : 4'd0)
                         + (tmp_ge20 ? 4'd2 : 4'd0)
                         + (tmp_ge10 ? 4'd1 : 4'd0);
    wire [3:0] tmp_d0    = tmp_r10[3:0];

    function [7:0] tempo_dig_ch;
        input [5:0] c;
        begin
            case (c)
                6'd24:   tempo_dig_ch = 8'h30 + {4'b0, tmp_d1};
                6'd25:   tempo_dig_ch = 8'h30 + {4'b0, tmp_d0};
                default: tempo_dig_ch = 8'h20;
            endcase
        end
    endfunction

    wire tempo_live = (cur_page == 4'd4);

    function tempo_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            tempo_hit = (r == 6'd14) && (c >= 6'd24) && (c <= 6'd25);
        end
    endfunction

    function [2:0] wf_of_op;
        input [2:0] k;
        begin
            case (k)
                3'd0    : wf_of_op = p_wf[2:0];
                3'd1    : wf_of_op = p_wf[5:3];
                3'd2    : wf_of_op = p_wf[8:6];
                default : wf_of_op = p_wf[11:9];
            endcase
        end
    endfunction

    function [7:0] wave_name_char;
        input [2:0] wf;
        input [1:0] idx;
        begin
            case ({wf, idx})
            {3'd0, 2'd0}: wave_name_char = 8'h53;
            {3'd0, 2'd1}: wave_name_char = 8'h49;
            {3'd0, 2'd2}: wave_name_char = 8'h4E;
            {3'd1, 2'd0}: wave_name_char = 8'h48;
            {3'd1, 2'd1}: wave_name_char = 8'h53;
            {3'd1, 2'd2}: wave_name_char = 8'h4E;
            {3'd2, 2'd0}: wave_name_char = 8'h46;
            {3'd2, 2'd1}: wave_name_char = 8'h57;
            {3'd2, 2'd2}: wave_name_char = 8'h52;
            {3'd3, 2'd0}: wave_name_char = 8'h48;
            {3'd3, 2'd1}: wave_name_char = 8'h41;
            {3'd3, 2'd2}: wave_name_char = 8'h4C;
            {3'd4, 2'd0}: wave_name_char = 8'h44;
            {3'd4, 2'd1}: wave_name_char = 8'h53;
            {3'd4, 2'd2}: wave_name_char = 8'h4E;
            {3'd5, 2'd0}: wave_name_char = 8'h44;
            {3'd5, 2'd1}: wave_name_char = 8'h48;
            {3'd5, 2'd2}: wave_name_char = 8'h41;
            {3'd6, 2'd0}: wave_name_char = 8'h53;
            {3'd6, 2'd1}: wave_name_char = 8'h51;
            {3'd6, 2'd2}: wave_name_char = 8'h52;
            {3'd7, 2'd0}: wave_name_char = 8'h53;
            {3'd7, 2'd1}: wave_name_char = 8'h41;
            {3'd7, 2'd2}: wave_name_char = 8'h57;
            default: wave_name_char = 8'h20;
            endcase
        end
    endfunction

    function wf_digit_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            wf_digit_hit = (r == 6'd6) &&
                           ((c == 6'd10) || (c == 6'd18) || (c == 6'd26) || (c == 6'd34));
        end
    endfunction

    function wf_name_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            wf_name_hit = ((r == 6'd6) && ((c >= 6'd11) && (c <= 6'd13))) ||
                          ((r == 6'd6) && ((c >= 6'd19) && (c <= 6'd21))) ||
                          ((r == 6'd6) && ((c >= 6'd27) && (c <= 6'd29))) ||
                          ((r == 6'd6) && ((c >= 6'd35) && (c <= 6'd37)));
        end
    endfunction

    localparam [20:0] SEQ_STEP_MAX = SEQ_STEP_FRAMES[20:0];

    reg [15:0] seq_on;
    reg [79:0] seq_pitch;
    reg [3:0]  seq_cur;
    reg [20:0] seq_frame_cnt;

    reg [5:0] seq_evt_r1, seq_evt_r2;
    reg [5:0] seq_evt_d2;

    wire seq_evt_hit = seq_evt_r2[5] ^ seq_evt_d2[5];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) seq_tempo <= SEQ_STEP_FRAMES[20:0];
        else if (p_tempo_pulse) begin
            if (p_tempo_dir)
                seq_tempo <= (seq_tempo <= 21'd2)  ? 21'd2  : (seq_tempo - 21'd1);
            else
                seq_tempo <= (seq_tempo >= 21'd64) ? 21'd64 : (seq_tempo + 21'd1);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_frame_cnt <= 21'd0;
            seq_cur       <= 4'd0;
        end
        else if (sof) begin
            if (!ui_mode) begin
                seq_frame_cnt <= 21'd0;
            end
            else if (seq_frame_cnt >= seq_tempo) begin
                seq_frame_cnt <= 21'd0;
                seq_cur       <= seq_cur + 4'd1;
            end
            else seq_frame_cnt <= seq_frame_cnt + 21'd1;
        end
    end

    reg        seq_tick_r;
    reg [4:0]  seq_step_r;
    reg [3:0]  seq_sidx_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_tick_r <= 1'b0;
            seq_step_r <= 5'd0;
            seq_sidx_r <= 4'd0;
        end
        else begin
            seq_tick_r <= 1'b0;
            if (sof && (seq_frame_cnt >= seq_tempo) && ui_mode) begin
                seq_tick_r <= 1'b1;
                seq_step_r <= pitch_of_step(seq_cur + 4'd1);
                seq_sidx_r <= seq_cur + 4'd1;
            end
        end
    end

    assign seq_tick    = seq_tick_r;
    assign seq_step    = seq_step_r;
    assign seq_step_on = seq_on[seq_sidx_r];

    reg  [3:0] seq_ed;
    wire [6:0] ed_base = {1'b0, seq_ed, 2'b00} + {3'b000, seq_ed};
    wire [3:0] seq_mark = ui_mode ? seq_cur : seq_ed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_on     <= 16'h0000;
            seq_pitch  <= 80'd0;
            seq_ed     <= 4'd0;
            seq_evt_r1 <= 6'd0;
            seq_evt_r2 <= 6'd0;
            seq_evt_d2 <= 6'd0;
        end
        else begin
            seq_evt_r1 <= p_seq_evt;
            seq_evt_r2 <= seq_evt_r1;
            seq_evt_d2 <= seq_evt_r2;

            if (seq_evt_hit && !ui_mode) begin
                case (seq_evt_r2[4:0])
                    5'd0,  5'd1,  5'd2,  5'd3,  5'd4,
                    5'd5,  5'd6,  5'd7,  5'd8,  5'd9,
                    5'd10, 5'd11, 5'd12, 5'd13, 5'd14,
                    5'd15, 5'd16, 5'd17, 5'd18, 5'd19,
                    5'd20, 5'd21, 5'd22, 5'd23, 5'd24: begin
                        seq_pitch[ed_base +: 5] <= seq_evt_r2[4:0];
                        seq_on[seq_ed]          <= 1'b1;
                        seq_ed                  <= (seq_ed == 4'd15)
                                                   ? 4'd0
                                                   : (seq_ed + 4'd1);
                    end
                    default: ;
                endcase
            end
        end
    end

    function [7:0] step_key_char;
        input [4:0] n;
        begin
            step_key_char = step_pitch_letter(n);
        end
    endfunction

    function [4:0] pitch_of_step;
        input [3:0] k;
        begin
            case (k)
                4'd0  : pitch_of_step = seq_pitch[4:0];
                4'd1  : pitch_of_step = seq_pitch[9:5];
                4'd2  : pitch_of_step = seq_pitch[14:10];
                4'd3  : pitch_of_step = seq_pitch[19:15];
                4'd4  : pitch_of_step = seq_pitch[24:20];
                4'd5  : pitch_of_step = seq_pitch[29:25];
                4'd6  : pitch_of_step = seq_pitch[34:30];
                4'd7  : pitch_of_step = seq_pitch[39:35];
                4'd8  : pitch_of_step = seq_pitch[44:40];
                4'd9  : pitch_of_step = seq_pitch[49:45];
                4'd10 : pitch_of_step = seq_pitch[54:50];
                4'd11 : pitch_of_step = seq_pitch[59:55];
                4'd12 : pitch_of_step = seq_pitch[64:60];
                4'd13 : pitch_of_step = seq_pitch[69:65];
                4'd14 : pitch_of_step = seq_pitch[74:70];
                default: pitch_of_step = seq_pitch[79:75];
            endcase
        end
    endfunction

    function [7:0] step_pitch_letter;
        input [4:0] k;
        begin
            case (k)
                5'd0,  5'd1,  5'd12, 5'd13 : step_pitch_letter = 8'h43;
                5'd2,  5'd3,  5'd14, 5'd15 : step_pitch_letter = 8'h44;
                5'd4,  5'd16               : step_pitch_letter = 8'h45;
                5'd5,  5'd6,  5'd17, 5'd18 : step_pitch_letter = 8'h46;
                5'd7,  5'd8,  5'd19, 5'd20 : step_pitch_letter = 8'h47;
                5'd9,  5'd10, 5'd21, 5'd22 : step_pitch_letter = 8'h41;
                5'd11, 5'd23               : step_pitch_letter = 8'h42;
                5'd24                      : step_pitch_letter = 8'h43;
                default                    : step_pitch_letter = 8'h20;
            endcase
        end
    endfunction

    function [7:0] step_pitch_sharp;
        input [4:0] k;
        begin
            if ((k == 5'd1)  || (k == 5'd3)  || (k == 5'd6)  ||
                (k == 5'd8)  || (k == 5'd10) ||
                (k == 5'd13) || (k == 5'd15) || (k == 5'd18) ||
                (k == 5'd20) || (k == 5'd22)) step_pitch_sharp = 8'h23;
            else                              step_pitch_sharp = 8'h20;
        end
    endfunction

    function [5:0] step_col_a;
        input [3:0] k;
        begin
            step_col_a = {2'b00, k, 1'b0} + 6'd3;
        end
    endfunction

    function [3:0] step_of_col;
        input [5:0] c;
        integer    kk;
        begin
            step_of_col = 4'd0;
            for (kk = 0; kk < 16; kk = kk + 1)
                if ((c == step_col_a(kk[3:0])) || (c == (step_col_a(kk[3:0]) + 6'd1)))
                    step_of_col = kk[3:0];
        end
    endfunction

    function seq_step_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            seq_step_hit = ((r == 6'd31) || (r == 6'd32)) &&
                           (c >= 6'd3) && (c <= 6'd34);
        end
    endfunction

    function seq_cur_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            seq_cur_hit = seq_step_hit(r, c) && (step_of_col(c) == seq_mark);
        end
    endfunction

    function [3:0] seq_color_of;
        input [5:0] r;
        input [5:0] c;
        reg [3:0] k;
        begin
            k = step_of_col(c);
            if (seq_cur_hit(r, c))
                seq_color_of = CIDX_FOCUS;
            else if (r == 6'd30) begin
                if (c <= 6'd21)  seq_color_of = CIDX_SECTION;
                else             seq_color_of = CIDX_LABEL;
            end
            else if (r == 6'd31) begin
                if (c == 6'd1)                      seq_color_of = CIDX_LABEL;
                else if (seq_cur_hit(r, c))         seq_color_of = CIDX_FOCUS;
                else if (c == step_col_a(k))         seq_color_of = CIDX_LABEL;
                else if (seq_on[k])                  seq_color_of = CIDX_KEYON;
                else                                 seq_color_of = CIDX_OP_OFF;
            end
            else if (r == 6'd32) begin
                if (c == 6'd1)                      seq_color_of = CIDX_LABEL;
                else if (seq_cur_hit(r, c))         seq_color_of = CIDX_FOCUS;
                else if (seq_on[k])                  seq_color_of = CIDX_VALUE;
                else                                 seq_color_of = CIDX_OP_OFF;
            end
            else if (r == 6'd33)               seq_color_of = CIDX_LABEL;
            else if (r == 6'd34)
                seq_color_of = ((c >= 6'd3) && (c <= 6'd33) && (c[0] == 1'b1)) ? CIDX_KEYON
                                                                                : CIDX_LABEL;
            else if (r == 6'd35)               seq_color_of = CIDX_LABEL;
            else if (r == 6'd36) begin
                if ((c >= 6'd5) && (c <= 6'd8))
                    seq_color_of = ui_mode ? CIDX_KEYON : CIDX_LABEL;
                else if ((c >= 6'd28) && (c <= 6'd29))
                    seq_color_of = CIDX_VALUE;
                else seq_color_of = CIDX_LABEL;
            end
            else                               seq_color_of = CIDX_DEFAULT;
        end
    endfunction

    function [7:0] seq_char;
        input [5:0] r;
        input [5:0] c;
        reg [3:0] k;
        begin
            k = step_of_col(c);
            if (r == 6'd31) begin
                if (seq_step_hit(r, c)) begin
                    if (c == step_col_a(k)) seq_char = hex_digit({1'b0, k});
                    else if (k == seq_mark) seq_char = 8'h7C;
                    else if (seq_on[k])    seq_char = 8'h23;
                    else                   seq_char = 8'h2D;
                end
                else if (c == 6'd40) seq_char = hex_digit({1'b0, seq_cur[3:2]});
                else if (c == 6'd41) seq_char = hex_digit(seq_cur[1:0]);
                else                 seq_char = tpl_char(r, c);
            end
            else if (r == 6'd32) begin
                if (seq_step_hit(r, c)) begin
                    if (c == step_col_a(k)) begin
                        seq_char = seq_on[k] ? step_pitch_letter(pitch_of_step(k)) : 8'h2D;
                    end
                    else begin
                        seq_char = (seq_on[k] && (step_pitch_sharp(pitch_of_step(k)) == 8'h23))
                                 ? 8'h23 : 8'h2D;
                    end
                end
                else if (c == 6'd40) seq_char = step_key_char(pitch_of_step(seq_cur));
                else if (c == 6'd41) seq_char = 8'h20;
                else                 seq_char = tpl_char(r, c);
            end
            else if (r == 6'd34) begin
                if ((c >= 6'd3) && (c <= 6'd34)) begin
                    if (c == step_col_a(k))
                        seq_char = step_pitch_letter(pitch_of_step(k));
                    else
                        seq_char = (step_pitch_sharp(pitch_of_step(k)) == 8'h23) ? 8'h23 : 8'h2D;
                end
                else                 seq_char = tpl_char(r, c);
            end
            else if (r == 6'd36) begin
                case (c)
                    6'd5   : seq_char = ui_mode ? 8'h50 : 8'h45;
                    6'd6   : seq_char = ui_mode ? 8'h4C : 8'h44;
                    6'd7   : seq_char = ui_mode ? 8'h41 : 8'h49;
                    6'd8   : seq_char = ui_mode ? 8'h59 : 8'h54;
                    6'd28  : seq_char = hex_digit(seq_tempo[7:4]);
                    6'd29  : seq_char = hex_digit(seq_tempo[3:0]);
                    default: seq_char = tpl_char(r, c);
                endcase
            end
            else                 seq_char = tpl_char(r, c);
        end
    endfunction

    function [2:0] step_of_op;
        input [5:0] c;
        begin
            if      ((c >= 6'd10) && (c <= 6'd13)) step_of_op = 3'd0;
            else if ((c >= 6'd18) && (c <= 6'd21)) step_of_op = 3'd1;
            else if ((c >= 6'd26) && (c <= 6'd29)) step_of_op = 3'd2;
            else if ((c >= 6'd34) && (c <= 6'd37)) step_of_op = 3'd3;
            else                                   step_of_op = 3'd4;
        end
    endfunction

    function [1:0] wf_idx_of_col;
        input [5:0] c;
        input [2:0] k;
        begin
            if (k == 3'd4)                          wf_idx_of_col = 2'd0;
            else if (c == (6'd10 + {3'b0, k, 3'b000})) wf_idx_of_col = 2'd0;
            else                                    wf_idx_of_col = c - (6'd11 + {3'b0, k, 3'b000});
        end
    endfunction

    function enc_mark_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            enc_mark_hit = (op_col_of(r, c) == focus_k) && (c == grp_left_col(focus_k));
        end
    endfunction

    function [7:0] page_tag_char;
        input [5:0] c;
        begin
            case (c)
                6'd38   : page_tag_char = 8'h50;
                6'd39   : page_tag_char = 8'h47;
                6'd40   : page_tag_char = 8'h20;
                6'd41   : page_tag_char = hex_digit(cur_page[3:0]);
                default : page_tag_char = 8'h20;
            endcase
        end
    endfunction


    function page_mark_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            page_mark_hit = (r >= 6'd6) && (r <= 6'd12) && (c == 6'd38) &&
                            (focus_row_of(cur_page) != FOCUS_ROW_NONE) &&
                            (r == focus_row_of(cur_page));
        end
    endfunction



    function [7:0] mode_tag_char;
        input [5:0] c;
        begin
            case (c)
                6'd28   : mode_tag_char = ui_mode ? 8'h50 : 8'h45;
                6'd29   : mode_tag_char = ui_mode ? 8'h4C : 8'h44;
                6'd30   : mode_tag_char = ui_mode ? 8'h41 : 8'h49;
                6'd31   : mode_tag_char = ui_mode ? 8'h59 : 8'h54;
                default : mode_tag_char = 8'h20;
            endcase
        end
    endfunction


    localparam [1:0] ST_IDLE = 2'd0,
                     ST_CALC = 2'd1,
                     ST_WR   = 2'd2,
                     ST_PRE  = 2'd3;

    reg [8:0] tpl_rom [0:2047];
    reg [10:0] tpl_addr_r;
    reg [8:0]  tpl_rd_r;
    reg [7:0]  tpl_hold;

    function [10:0] tpl_idx;
        input [5:0] r;
        input [5:0] c;
        reg [10:0] r42;
        begin
            r42 = {r, 5'b00000} + {r, 3'b000} + {r, 1'b0};
            tpl_idx = r42 + {5'b0, c};
        end
    endfunction

    initial begin
        $readmemh("tpl_rom.hex", tpl_rom);
    end


    reg [1:0]  st;
    reg [11:0] cell_idx;
    reg [7:0]  ch_r;
    reg [3:0]  col_r;
    reg        bld_r;

    localparam [11:0] PCOLS = PANEL_COLS[11:0];

    localparam [5:0] LAST_COL = PANEL_COLS[5:0] - 6'd1;
    localparam [5:0] LAST_ROW = PANEL_ROWS[5:0] - 6'd1;

    reg [5:0] cur_r, cur_c;


    localparam [5:0] TOPO_C0 = 6'd29;
    localparam [5:0] TOPO_C1 = 6'd41;
    localparam [5:0] TOPO_R0 = 6'd2;
    localparam [5:0] TOPO_R1 = 6'd3;

    function topo_hit;
        input [5:0] r;
        input [5:0] c;
        begin
            topo_hit = (c >= TOPO_C0) && (c <= TOPO_C1) &&
                       ((r == TOPO_R0) || (r == TOPO_R1));
        end
    endfunction

    function [7:0] topo_char;
        input [2:0] a;
        input       sub;
        input [5:0] c;
        reg [8*26-1:0] blk;
        reg [5:0] k;
        reg [5:0] idx;
        reg [8:0] bsel;
        begin
            case (a)
            3'd0: blk = {"MASK:0,1,2,4 ", "0>1>2>[3]    "};
            3'd1: blk = {"MASK:0,1,2,0 ", "0>1>[2] [3]  "};
            3'd2: blk = {"MASK:0,1,0,4 ", "0>[1] 2>[3]  "};
            3'd3: blk = {"MASK:0,1,0,6 ", "0>1  1,2>[3] "};
            3'd4: blk = {"MASK:0,0,0,0 ", "[0][1][2][3] "};
            3'd5: blk = {"MASK:0,0,3,0 ", "0,1>[2] [3]  "};
            3'd6: blk = {"MASK:1,1,2,4 ", "(0)>1>2>[3]  "};
            3'd7: blk = {"MASK:2,4,8,1 ", "[0]>3>2>1>[0]"};
            default: blk = {"MASK:0,1,2,4 ", "0>1>2>[3]    "};
            endcase

            k = c - TOPO_C0;
            if (k > 6'd12) k = 6'd12;
            idx = (6'd12 - k) + (sub ? 6'd13 : 6'd0);
            bsel = idx << 3;
            topo_char = blk[bsel +: 8];
        end
    endfunction




    reg p25_ui_layer_r1, p25_ui_layer_r2;
    reg [5:0] p25_fn_btn_r1, p25_fn_btn_r2;
    reg p25_gld_r1, p25_gld_r2;
    reg p25_vel_r1, p25_vel_r2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p25_ui_layer_r1 <= 1'b0;
            p25_ui_layer_r2 <= 1'b0;
            p25_fn_btn_r1   <= 6'd0;
            p25_fn_btn_r2   <= 6'd0;
            p25_gld_r1      <= 1'b0;
            p25_gld_r2      <= 1'b0;
            p25_vel_r1      <= 1'b0;
            p25_vel_r2      <= 1'b0;
        end
        else begin
            p25_ui_layer_r1 <= p_ui_layer;
            p25_ui_layer_r2 <= p25_ui_layer_r1;
            p25_fn_btn_r1   <= p_fn_btn;
            p25_fn_btn_r2   <= p25_fn_btn_r1;
            p25_gld_r1      <= p_glide_en;
            p25_gld_r2      <= p25_gld_r1;
            p25_vel_r1      <= p_vel_en;
            p25_vel_r2      <= p25_vel_r1;
        end
    end

    wire [5:0] p25_fn_btn   = p25_fn_btn_r2;
    wire       p25_ui_layer = p25_ui_layer_r2;


    wire       p25_lyr_shft = p25_ui_layer;

    reg  [5:0] p25_fn_btn_d;
    reg  [2:0] p25_fn_last;
    wire [5:0] p25_fn_new = p25_fn_btn & ~p25_fn_btn_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p25_fn_btn_d <= 6'd0;
            p25_fn_last  <= 3'd0;
        end
        else begin
            p25_fn_btn_d <= p25_fn_btn;
            if (|p25_fn_new) begin
                if      (p25_fn_new[0]) p25_fn_last <= 3'd0;
                else if (p25_fn_new[1]) p25_fn_last <= 3'd1;
                else if (p25_fn_new[2]) p25_fn_last <= 3'd2;
                else if (p25_fn_new[3]) p25_fn_last <= 3'd3;
                else if (p25_fn_new[4]) p25_fn_last <= 3'd4;
                else                p25_fn_last <= 3'd5;
            end
        end
    end

    wire       p25_fn_any  = |p25_fn_btn;
    wire [2:0] p25_fn_show = p25_fn_any ? p25_fn_last : 3'd7;

    function [1:0] p25_cnt3;
        input [2:0] v;
        begin
            p25_cnt3 = {1'b0, v[0]} + {1'b0, v[1]} + {1'b0, v[2]};
        end
    endfunction

    function [7:0] p25_layer_name_ch;
        input [5:0] c;
        begin
            if (!p25_lyr_shft) begin
                case (c)
                    6'd33, 6'd37: p25_layer_name_ch = 8'h44;
                    6'd34, 6'd38: p25_layer_name_ch = 8'h46;
                    6'd35, 6'd39: p25_layer_name_ch = 8'h4C;
                    default:      p25_layer_name_ch = 8'h54;
                endcase
            end
            else begin
                case (c)
                    6'd33, 6'd37: p25_layer_name_ch = 8'h53;
                    6'd34, 6'd38: p25_layer_name_ch = 8'h48;
                    6'd35, 6'd39: p25_layer_name_ch = 8'h46;
                    default:      p25_layer_name_ch = 8'h54;
                endcase
            end
        end
    endfunction


    function [7:0] p25_co_ch;
        input [5:0] c;
        reg [1:0] q;
        begin
            q = c[2:0] - 3'd5;
            p25_co_ch = 8'h20;
            if (p25_lyr_shft && (p25_fn_show != 3'd7)) begin
                if      (p25_fn_show == 3'd3) begin
                    case (q) 2'd0: p25_co_ch = 8'h53;
                               2'd1: p25_co_ch = 8'h54;
                               2'd2: p25_co_ch = 8'h50;
                               default: p25_co_ch = 8'h2D; endcase
                end
                else if (p25_fn_show == 3'd4) begin
                    case (q) 2'd0: p25_co_ch = 8'h53;
                               2'd1: p25_co_ch = 8'h54;
                               2'd2: p25_co_ch = 8'h50;
                               default: p25_co_ch = 8'h2B; endcase
                end
            end
        end
    endfunction

    function [31:0] p25_lbl32;
        input [4:0] id;
        begin
            case (id)
                5'd0 : p25_lbl32 = "OCT-";
                5'd1 : p25_lbl32 = "OCT+";
                5'd2 : p25_lbl32 = "RPT ";
                5'd3 : p25_lbl32 = "SUS ";
                5'd4 : p25_lbl32 = "GLID";
                5'd5 : p25_lbl32 = "VIB ";
                5'd6 : p25_lbl32 = "RST ";
                5'd7 : p25_lbl32 = "SEQS";
                5'd8 : p25_lbl32 = "SHFT";
                5'd9 : p25_lbl32 = "DFLT";
                5'd10: p25_lbl32 = "PG- ";
                5'd11: p25_lbl32 = "PG+ ";
                5'd12: p25_lbl32 = "EDIT";
                5'd13: p25_lbl32 = "TEST";
                5'd14: p25_lbl32 = "P-  ";
                5'd15: p25_lbl32 = "P+  ";
                5'd17: p25_lbl32 = "SCRN";
                5'd18: p25_lbl32 = "STP-";
                5'd19: p25_lbl32 = "STP+";
                5'd20: p25_lbl32 = "TRK-";
                5'd21: p25_lbl32 = "TRK+";
                5'd22: p25_lbl32 = "SCOR";
                5'd23: p25_lbl32 = "GUID";
                5'd24: p25_lbl32 = "MODE";
                5'd25: p25_lbl32 = "SEQP";
                default: p25_lbl32 = "----";
            endcase
        end
    endfunction

    function [4:0] p25_sid;
        input [2:0] k;
        begin
            if (k == 3'd7) begin
                p25_sid = 5'd16;
            end
            else if (!p25_lyr_shft) begin
                case (k)
                    3'd0: p25_sid = 5'd1;
                    3'd1: p25_sid = 5'd0;
                    3'd2: p25_sid = 5'd17;
                    3'd3: p25_sid = 5'd23;
                    3'd4: p25_sid = 5'd4;
                    default: p25_sid = 5'd8;
                endcase
            end
            else begin
                case (k)
                    3'd0: p25_sid = 5'd21;
                    3'd1: p25_sid = 5'd20;
                    3'd2: p25_sid = 5'd12;
                    3'd3: p25_sid = 5'd10;
                    3'd4: p25_sid = 5'd11;
                    default: p25_sid = 5'd9;
                endcase
            end
        end
    endfunction

    function [4:0] p25_lid;
        input [2:0] k;
        begin
            if (k == 3'd7) begin
                p25_lid = 5'd16;
            end
            else if (!p25_lyr_shft) begin
                case (k)
                    3'd0: p25_lid = 5'd25;
                    3'd1: p25_lid = 5'd7;
                    3'd2: p25_lid = 5'd13;
                    3'd3: p25_lid = 5'd3;
                    3'd4: p25_lid = 5'd5;
                    default: p25_lid = 5'd9;
                endcase
            end
            else begin
                case (k)
                    3'd0: p25_lid = 5'd15;
                    3'd1: p25_lid = 5'd6;
                    3'd2: p25_lid = 5'd14;
                    3'd3: p25_lid = 5'd22;
                    3'd4: p25_lid = 5'd24;
                    default: p25_lid = 5'd9;
                endcase
            end
        end
    endfunction

    function [7:0] p25_fn_label_ch;
        input [2:0] k;
        input [5:0] c;
        reg [3:0] q;
        reg [5:0] sh;
        begin
            q = c[3:0] - 4'd1;
            p25_fn_label_ch = 8'h20;
            if (q < 4'd4) begin
                sh = {2'b00, 4'd3 - q} << 3;
                p25_fn_label_ch = p25_lbl32(p25_sid(k)) >> sh;
            end
        end
    endfunction

    function [7:0] p25_pair_ch;
        input [5:0] c;
        reg [3:0] p;
        reg [5:0] sh;
        begin
            p = c[3:0] - 4'd8;
            p25_pair_ch = 8'h20;
            if (p < 4'd4) begin
                sh = {2'b00, 4'd3 - p} << 3;
                p25_pair_ch = p25_lbl32(p25_sid(p25_fn_show)) >> sh;
            end
            else if (p == 4'd4) begin
                p25_pair_ch = 8'h2F;
            end
            else begin
                sh = {2'b00, 4'd8 - p} << 3;
                p25_pair_ch = p25_lbl32(p25_lid(p25_fn_show)) >> sh;
            end
        end
    endfunction

    function [7:0] p25_fn_slot_ch;
        input [5:0] c;
        begin
            p25_fn_slot_ch = (p25_fn_show == 3'd7) ? p25_layer_name_ch(c) : p25_fn_label_ch(p25_fn_show, c);
        end
    endfunction

    function [7:0] p25_fn_count_ch;
        input [5:0] c;
        begin
            if      (c == 6'd37) p25_fn_count_ch = 8'h30 + {6'b0, p25_cnt3(p25_fn_btn[2:0])};
            else if (c == 6'd38) p25_fn_count_ch = 8'h30 + {6'b0, p25_cnt3(p25_fn_btn[5:3])};
            else                 p25_fn_count_ch = 8'h20;
        end
    endfunction


    wire [5:0] wet_bar_end = 6'd31 + {3'b0, p_fx_wet};

    function [7:0] wet_bar_ch;
        input [5:0] c;
        begin
            wet_bar_ch = (c < wet_bar_end) ? 8'h23 : 8'h2D;
        end
    endfunction

    localparam [4:0] BF_NONE    = 5'd0,
                     BF_LINKLBL = 5'd1,
                     BF_LINKST  = 5'd2,
                     BF_CMD     = 5'd3,
                     BF_SEQ     = 5'd4,
                     BF_STATUS  = 5'd5,
                     BF_TOTAL   = 5'd6,
                     BF_MSSTEP  = 5'd7,
                     BF_MODE    = 5'd8,
                     BF_GUIDE   = 5'd9,
                     BF_ACCOMP  = 5'd10,
                     BF_HEAD    = 5'd11,
                     BF_TOTAL2  = 5'd12,
                     BF_ACCST   = 5'd13,
                     BF_UIMODE  = 5'd14,
                     BF_GMODE   = 5'd15,
                     BF_TESTST  = 5'd16,
                     BF_VEL     = 5'd17,
                     BF_GLD     = 5'd18;

    function [4:0] bt_field;
        input [5:0] r;
        input [5:0] c;
        begin
            case (r)
            6'd31: begin
                if      ((c >= 6'd5)  && (c <= 6'd8))  bt_field = BF_LINKLBL;
                else if ((c >= 6'd10) && (c <= 6'd11)) bt_field = BF_LINKST;
                else if ((c >= 6'd18) && (c <= 6'd19)) bt_field = BF_CMD;
                else if ((c >= 6'd26) && (c <= 6'd27)) bt_field = BF_SEQ;
                else if ((c >= 6'd33) && (c <= 6'd34)) bt_field = BF_STATUS;
                else if (c == 6'd39)                   bt_field = BF_VEL;
                else                                   bt_field = BF_NONE;
            end
            6'd32: begin
                if      ((c >= 6'd7)  && (c <= 6'd10)) bt_field = BF_TOTAL;
                else if ((c >= 6'd19) && (c <= 6'd22)) bt_field = BF_MSSTEP;
                else if (c == 6'd38)                   bt_field = BF_MODE;
                else                                   bt_field = BF_NONE;
            end
            6'd34: begin
                if      ((c >= 6'd7)  && (c <= 6'd9))  bt_field = BF_GUIDE;
                else if ((c >= 6'd19) && (c <= 6'd21)) bt_field = BF_ACCOMP;
                else if ((c >= 6'd29) && (c <= 6'd31)) bt_field = BF_HEAD;
                else if ((c >= 6'd33) && (c <= 6'd36)) bt_field = BF_TOTAL2;
                else if (c == 6'd41)                   bt_field = BF_GLD;
                else                                   bt_field = BF_NONE;
            end
            6'd35: begin
                if      ((c >= 6'd34) && (c <= 6'd38)) bt_field = BF_ACCST;
                else                                   bt_field = BF_NONE;
            end
            6'd36: begin
                if      ((c >= 6'd6)  && (c <= 6'd9))  bt_field = BF_UIMODE;
                else if (c == 6'd24)                   bt_field = BF_GMODE;
                else if ((c >= 6'd34) && (c <= 6'd38)) bt_field = BF_TESTST;
                else                                   bt_field = BF_NONE;
            end
            default: bt_field = BF_NONE;
            endcase
        end
    endfunction

    function [7:0] bt_char;
        input [5:0] r;
        input [5:0] c;
        reg [4:0] f;
        begin
            f = bt_field(r, c);
            case (f)
            BF_LINKST: begin
                if (c == 6'd10) bt_char = b1_safe(bt_link) ? 8'h4F : 8'h2D;
                else           bt_char = b1_safe(bt_link) ? 8'h4B : 8'h2D;
            end
            BF_CMD: begin
                if (c == 6'd18) bt_char = hex_digit(nib_safe(bt_cmd[7:4]));
                else            bt_char = hex_digit(nib_safe(bt_cmd[3:0]));
            end
            BF_SEQ: begin
                if (c == 6'd26) bt_char = hex_digit(nib_safe(bt_seq[7:4]));
                else            bt_char = hex_digit(nib_safe(bt_seq[3:0]));
            end
            BF_STATUS: begin
                if (c == 6'd33) bt_char = hex_digit(nib_safe(bt_status[7:4]));
                else            bt_char = hex_digit(nib_safe(bt_status[3:0]));
            end
            BF_TOTAL: begin
                if      (c == 6'd7)  bt_char = hex_digit(nib_safe(score_total[15:12]));
                else if (c == 6'd8)  bt_char = hex_digit(nib_safe(score_total[11:8]));
                else if (c == 6'd9)  bt_char = hex_digit(nib_safe(score_total[7:4]));
                else                 bt_char = hex_digit(nib_safe(score_total[3:0]));
            end
            BF_MSSTEP: begin
                if      (c == 6'd19) bt_char = hex_digit(nib_safe(score_step_ms[15:12]));
                else if (c == 6'd20) bt_char = hex_digit(nib_safe(score_step_ms[11:8]));
                else if (c == 6'd21) bt_char = hex_digit(nib_safe(score_step_ms[7:4]));
                else                 bt_char = hex_digit(nib_safe(score_step_ms[3:0]));
            end
            BF_MODE:  bt_char = hex_digit(nib_safe(score_mode[3:0]));
            BF_GMODE: bt_char = hex_digit(nib_safe(score_mode[3:0]));
            BF_GUIDE: begin
                if      (c == 6'd7) bt_char = 8'h4F;
                else if (c == 6'd8) bt_char = b1_safe(guide_on) ? 8'h4E : 8'h46;
                else                bt_char = b1_safe(guide_on) ? 8'h20 : 8'h46;
            end
            BF_ACCOMP: begin
                if      (c == 6'd19) bt_char = 8'h4F;
                else if (c == 6'd20) bt_char = mode_ge2(score_mode) ? 8'h4E : 8'h46;
                else                bt_char = mode_ge2(score_mode) ? 8'h20 : 8'h46;
            end
            BF_HEAD: begin
                if      (c == 6'd29) bt_char = 8'h30;
                else if (c == 6'd30) bt_char = hex_digit(nib_safe(score_cur[7:4]));
                else                 bt_char = hex_digit(nib_safe(score_cur[3:0]));
            end
            BF_TOTAL2: begin
                if      (c == 6'd33) bt_char = hex_digit(nib_safe(score_total[15:12]));
                else if (c == 6'd34) bt_char = hex_digit(nib_safe(score_total[11:8]));
                else if (c == 6'd35) bt_char = hex_digit(nib_safe(score_total[7:4]));
                else                 bt_char = hex_digit(nib_safe(score_total[3:0]));
            end
            BF_ACCST: begin
                if      (c == 6'd34) bt_char = 8'h4F;
                else if (c == 6'd35) bt_char = b1_safe(accomp_active) ? 8'h4E : 8'h46;
                else if (c == 6'd36) bt_char = b1_safe(accomp_active) ? 8'h20 : 8'h46;
                else                bt_char = 8'h20;
            end
            BF_TESTST: begin
                if      (c == 6'd34) bt_char = 8'h54;
                else if (c == 6'd35) bt_char = 8'h45;
                else if (c == 6'd36) bt_char = 8'h53;
                else if (c == 6'd37) bt_char = 8'h54;
                else if (c == 6'd38) bt_char = (test_st == 2'd1) ? 8'h4C
                                        : (test_st == 2'd2) ? 8'h52
                                                                : 8'h2D;
                else                bt_char = 8'h20;
            end
            BF_UIMODE: begin
                if      (c == 6'd6) bt_char = b1_safe(ui_mode) ? 8'h50 : 8'h45;
                else if (c == 6'd7) bt_char = b1_safe(ui_mode) ? 8'h4C : 8'h44;
                else if (c == 6'd8) bt_char = b1_safe(ui_mode) ? 8'h41 : 8'h49;
                else                bt_char = b1_safe(ui_mode) ? 8'h59 : 8'h54;
            end
            BF_VEL: bt_char = b1_safe(p25_vel_r2) ? 8'h31 : 8'h30;
            BF_GLD: bt_char = b1_safe(p25_gld_r2) ? 8'h31 : 8'h30;
            default:   bt_char = tpl_hold;
            endcase
        end
    endfunction

    function [3:0] bt_color;
        input [5:0] r;
        input [5:0] c;
        reg [4:0] f;
        begin
            f = bt_field(r, c);
            case (f)
            BF_LINKLBL: bt_color = b1_safe(bt_link) ? CIDX_OK : CIDX_WARN;
            BF_LINKST : bt_color = b1_safe(bt_link) ? CIDX_OK : CIDX_WARN;
            BF_STATUS : bt_color = status_ok(bt_status) ? CIDX_OK : CIDX_ERR;
            BF_GUIDE  : bt_color = b1_safe(guide_on) ? CIDX_OK : CIDX_LABEL;
            BF_ACCOMP : bt_color = mode_ge2(score_mode) ? CIDX_OK : CIDX_LABEL;
            BF_ACCST  : bt_color = b1_safe(accomp_active) ? CIDX_OK : CIDX_LABEL;
            BF_UIMODE : bt_color = b1_safe(ui_mode) ? CIDX_OK : CIDX_LABEL;
            BF_TESTST : bt_color = (test_st == 2'd1) ? CIDX_WARN
                                               : (test_st == 2'd2) ? CIDX_OK : CIDX_LABEL;
            BF_VEL    : bt_color = b1_safe(p25_vel_r2) ? CIDX_OK : CIDX_LABEL;
            BF_GLD    : bt_color = b1_safe(p25_gld_r2) ? CIDX_OK : CIDX_LABEL;
            BF_CMD, BF_SEQ, BF_TOTAL, BF_TOTAL2,
            BF_MSSTEP, BF_MODE, BF_GMODE, BF_HEAD: bt_color = CIDX_VALUE;
            default   : bt_color = CIDX_LABEL;
            endcase
        end
    endfunction

    function bt_bold;
        input [5:0] r;
        input [5:0] c;
        begin
            bt_bold = (bt_field(r, c) != BF_NONE);
        end
    endfunction

    function [7:0] panel_char;
        input [5:0] r;
        input [5:0] c;
        input [2:0] slot;
        reg [7:0] t;
        begin
            t = tpl_hold;
            if (knob_leg_hit(r, c))
                panel_char = 8'h30 + knob_leg_dig(r);
            else if (r == 6'd20 || r == 6'd23) begin
                if ((t == 8'h2D) || (t == 8'h3D))
                    panel_char = hl_cell(r, c) ? 8'h23 : t;
                else panel_char = t;
            end
            else if ((r == 6'd14) && (c >= 6'd8) && (c <= 6'd16))
                panel_char = p25_pair_ch(c);
            else if (tempo_hit(r, c))
                panel_char = tempo_dig_ch(c);
            else if ((r == 6'd14) && (c >= 6'd33) && (c <= 6'd36))
                panel_char = p25_layer_name_ch(c);
            else if ((r == 6'd15) && (c >= 6'd33) && (c <= 6'd36))
                panel_char = p25_fn_slot_ch(c);
            else if ((r == 6'd15) && (c >= 6'd29) && (c <= 6'd32))
                panel_char = p25_co_ch(c);
            else if ((r == 6'd15) && (c == 6'd37 || c == 6'd38))
                panel_char = p25_fn_count_ch(c);
            else if ((r == 6'd15) && (c == 6'd41))
                panel_char = p25_lyr_shft ? 8'h23 : 8'h2D;
            else if ((r == 6'd15) && (c >= 6'd21) && (c <= 6'd23))
                panel_char = vol_dig_ch(c);
            else if ((r == 6'd15) && (c == 6'd28))
                panel_char = vib_dig_ch(c);
            else if ((r == 6'd27) && (c >= 6'd31) && (c <= 6'd38))
                panel_char = wet_bar_ch(c);
            else if (topo_hit(r, c)) panel_char = topo_char(p_algo, (r == TOPO_R1), c);
            else if ((r == 6'd5) && (c >= 6'd38) && (c <= 6'd41))
                                        panel_char = page_tag_char(c);
            else if (enc_mark_hit(r, c) && (r == 6'd5))  panel_char = 8'h2A;
            else if (enc_mark_hit(r, c))                  panel_char = 8'h3E;
            else if (page_mark_hit(r, c))                 panel_char = 8'h2A;
            else if (wf_digit_hit(r, c))
                panel_char = hex_digit(field_val(6'd6, slot));
            else if (wf_name_hit(r, c))
                panel_char = wave_name_char(wf_of_op(step_of_op(c)),
                                                   wf_idx_of_col(c, step_of_op(c)));
            else if ((r >= 6'd30) && (r <= 6'd36))    panel_char = bt_char(r, c);
            else if ((r == 6'd14) && (c >= 6'd28) && (c <= 6'd31))
                                         panel_char = mode_tag_char(c);
            else if (t == 8'h23) panel_char = hex_digit(field_val(r, slot));
            else if (r >= 6'd17 && r <= 6'd22) begin
                if      (t == 8'h2A) panel_char = 8'h20;
                else if (t == 8'h40) panel_char = key_oct_digit_ch(r, c);
                else if (t == 8'h55) panel_char = sustain_on ? 8'h53 : 8'h2D;
                else if (t == 8'h56) panel_char = ui_mode ? 8'h31 : 8'h30;
                else if (t == 8'h25) panel_char = 8'h23;
                else                 panel_char = t;
            end
            else                 panel_char = t;
        end
    endfunction


    localparam [5:0] ROWKEY_ST  = 6'd17;



    function [3:0] panel_color;
        input [5:0] r;
        input [5:0] c;
        reg [7:0] t;
        begin
            t = tpl_hold;

            if (knob_leg_hit(r, c) || room_hl(r, c))
                panel_color = CIDX_ACCENT;

            else if ((r >= 6'd18) && (r <= 6'd23)) begin
                panel_color = hl_cell(r, c) ? CIDX_KEYON : CIDX_KEYIDLE;
            end
            else if ((r == 6'd27) && (c >= 6'd31) && (c <= 6'd38))
                panel_color = (c < wet_bar_end) ? CIDX_KEYON : CIDX_LABEL;
            else if (r == ROWKEY_ST) begin
                if      (t == 8'h55) panel_color = sustain_on ? CIDX_KEYON : CIDX_KEYIDLE;
                else if (t == 8'h40 || t == 8'h23 || t == 8'h56)
                    panel_color = CIDX_VALUE;
                else                 panel_color = CIDX_LABEL;
            end
            else if (topo_hit(r, c))
                panel_color = (r == TOPO_R1) ? CIDX_VALUE : CIDX_ACCENT;
            else if (focus_cell(r, c))    panel_color = CIDX_FOCUS;
            else if (focus_col_hit(r, c)) panel_color = CIDX_FOCUS_COL;
            else if (focus_row_cell_hit(r, c)) panel_color = CIDX_FOCUS_ROW;
            else if ((r >= 6'd30) && (r <= 6'd36)) panel_color = bt_color(r, c);
            else if (r == 6'd0) panel_color = CIDX_TITLE;

            else if (t == 8'h2D) panel_color = CIDX_LABEL;

            else if (tempo_hit(r, c))
                panel_color = tempo_live ? CIDX_ACCENT : CIDX_VALUE;
            else if (r == 6'd14 || r == 6'd25 || r == 6'd5)
                panel_color = CIDX_SECTION;

            else if (wf_name_hit(r, c))  panel_color = CIDX_ACCENT;
            else if (wf_digit_hit(r, c)) panel_color = CIDX_VALUE;
            else if (t == 8'h23) panel_color = CIDX_VALUE;

            else if (r == 6'd15) begin
                if ((c >= 6'd33) && (c <= 6'd36))
                    panel_color = CIDX_LABEL;
                else if ((c == 6'd37) || (c == 6'd38))
                    panel_color = CIDX_VALUE;
                else if (c == 6'd41)
                    panel_color = p25_lyr_shft ? CIDX_KEYON : CIDX_LABEL;
                else if (((c >= 6'd21) && (c <= 6'd23)) || (c == 6'd28))
                    panel_color = CIDX_VALUE;
                else if (t == 8'h23)
                    panel_color = CIDX_VALUE;
                else
                    panel_color = CIDX_LABEL;
            end

            else panel_color = CIDX_DEFAULT;
        end
    endfunction

    function panel_bold;
        input [5:0] r;
        input [5:0] c;
        reg [7:0] t;
        begin
            t = tpl_hold;

            if (knob_leg_hit(r, c) || room_hl(r, c))
                panel_bold = 1'b1;
            else if ((r >= 6'd18) && (r <= 6'd23))
                panel_bold = hl_cell(r, c);
            else if ((r == 6'd27) && (c >= 6'd31) && (c <= 6'd38))
                panel_bold = (c < wet_bar_end);
            else if (r == ROWKEY_ST)
                panel_bold = (t == 8'h55) || (t == 8'h40) ||
                             (t == 8'h23) || (t == 8'h56);
            else if (topo_hit(r, c))
                panel_bold = (r != TOPO_R1);
            else if (focus_cell(r, c)) panel_bold = 1'b1;
            else if ((r >= 6'd30) && (r <= 6'd36)) panel_bold = bt_bold(r, c);
            else if (seq_cur_hit(r, c)) panel_bold = 1'b1;
            else if (r == 6'd30)           panel_bold = 1'b1;
            else if (r == 6'd34 || r == 6'd35 || r == 6'd36) panel_bold = 1'b0;
            else if (wf_name_hit(r, c))  panel_bold = 1'b1;
            else if (wf_digit_hit(r, c)) panel_bold = 1'b0;
            else if (r == 6'd0 || r == 6'd14 || r == 6'd25 || r == 6'd5)
                panel_bold = 1'b1;
            else if (t == 8'h2D) panel_bold = 1'b0;
            else if (t == 8'h23) panel_bold = 1'b1;
            else if (r == 6'd15) panel_bold = 1'b1;
            else panel_bold = 1'b0;
        end
    endfunction

    reg  [2:0] slot_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st      <= ST_IDLE;
            cell_idx <= 12'd0;
            cur_r   <= 6'd0;
            cur_c   <= 6'd0;
            slot_cnt <= 3'd0;
            we      <= 1'b0;
            w_col   <= 6'd0;
            w_row   <= 6'd0;
            w_ch    <= 8'h20;
            w_color <= 4'd0;
            w_bold  <= 1'b0;
            ch_r    <= 8'h20;
            col_r   <= 4'd0;
            bld_r   <= 1'b0;
            tpl_addr_r <= 11'd0;
            tpl_rd_r   <= 9'h20;
            tpl_hold   <= 8'h20;
        end
        else begin
            we <= 1'b0;

            if (st == ST_IDLE) tpl_addr_r <= 11'd0;
            else if (st == ST_CALC) tpl_addr_r <= tpl_idx(cur_r, cur_c) + 11'd1;
            tpl_rd_r <= tpl_rom[tpl_addr_r];

            case (st)
            ST_IDLE: begin
                if (sof) begin
                    cell_idx <= 12'd0;
                    cur_r    <= 6'd0;
                    cur_c    <= 6'd0;
                    slot_cnt <= 3'd0;
                    tpl_addr_r <= 11'd0;
                    st   <= ST_PRE;
                end
            end

            ST_PRE: begin
                tpl_hold   <= tpl_rd_r[7:0];
                st         <= ST_CALC;
            end

            ST_CALC: begin
                ch_r  <= panel_char(cur_r, cur_c, slot_cnt);
                col_r <= panel_color(cur_r, cur_c);
                bld_r <= panel_bold(cur_r, cur_c);
                st <= ST_WR;
            end

            ST_WR: begin
                we      <= 1'b1;
                w_row   <= cur_r;
                w_col   <= cur_c;
                w_ch    <= ch_r;
                w_color <= col_r;
                w_bold  <= bld_r;

                cell_idx <= cell_idx + 12'd1;

                if (tpl_hold == 8'h23) slot_cnt <= slot_cnt + 3'd1;

                if ((cur_r == LAST_ROW) && (cur_c == LAST_COL)) begin
                    st <= ST_IDLE;
                end
                else if (cur_c == LAST_COL) begin
                    cur_c <= 6'd0;
                    cur_r <= cur_r + 6'd1;
                    slot_cnt <= 3'd0;
                    st    <= ST_PRE;
                end
                else begin
                    cur_c <= cur_c + 6'd1;
                    st    <= ST_PRE;
                end
            end

            default: st <= ST_IDLE;
            endcase
        end
    end

endmodule
