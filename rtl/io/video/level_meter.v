// level_meter —— 李萨如图区右边缘的 12 段 VU 音量条（纯组合渲染，无状态机）

`timescale 1ns/1ps

module level_meter #(
    parameter integer X0 = 336,
    parameter integer Y0 = 400,
    parameter integer X1 = 1024,
    parameter integer Y1 = 600,

    parameter integer MX0 = 952,
    parameter integer MY0 = 404,
    parameter integer MW  = 68,
    parameter integer MH  = 192,

    parameter integer RX0 = 826,
    parameter integer RY0 = 404,
    parameter integer RW  = 120,
    parameter integer RH  = 192,

    parameter integer FRAME  = 1,
    parameter integer NSEG   = 12,
    parameter integer SEG_H  = 14,
    parameter integer GAP    = 1,

    parameter integer OUT_LAT = 4
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        sof,
    input  wire [11:0] gx,
    input  wire [11:0] gy,
    input  wire        gde,

    input  wire [3:0]  level_msb,

    output wire [23:0] rgb,
    output wire        hit
);

    localparam [11:0] X0_C  = X0[11:0];
    localparam [11:0] Y0_C  = Y0[11:0];
    localparam [11:0] X1_C  = X1[11:0];
    localparam [11:0] Y1_C  = Y1[11:0];

    localparam [11:0] MX0_C = MX0[11:0];
    localparam [11:0] MY0_C = MY0[11:0];
    localparam [11:0] FR_C  = FRAME[11:0];
    localparam [11:0] MW_C  = MW[11:0];
    localparam [11:0] MH_C  = MH[11:0];
    localparam [11:0] SEGH_C = SEG_H[11:0];
    localparam [11:0] NSEG_C = NSEG[11:0];

    localparam [11:0] BOX_X0_C = MX0_C;
    localparam [11:0] BOX_X1_C = MX0_C + MW_C - 12'd1;
    localparam [11:0] BOX_Y0_C = MY0_C;
    localparam [11:0] BOX_Y1_C = MY0_C + MH_C - 12'd1;

    localparam [11:0] IN_X0_C  = BOX_X0_C + FR_C;
    localparam [11:0] IN_X1_C  = BOX_X1_C - FR_C;
    localparam [11:0] IN_Y0_C  = BOX_Y0_C + FR_C;
    localparam [11:0] IN_Y1_C  = BOX_Y1_C - FR_C;

    localparam [11:0] PN_X0_C = RX0[11:0];
    localparam [11:0] PN_X1_C = RX0[11:0] + RW[11:0] - 12'd1;
    localparam [11:0] PN_Y0_C = RY0[11:0];
    localparam [11:0] PN_Y1_C = RY0[11:0] + RH[11:0] - 12'd1;

    localparam [11:0] PN_IX0_C = PN_X0_C + FR_C;
    localparam [11:0] PN_IX1_C = PN_X1_C - FR_C;
    localparam [11:0] PN_IY0_C = PN_Y0_C + FR_C;
    localparam [11:0] PN_IY1_C = PN_Y1_C - FR_C;

    wire in_graph  = (gx >= X0_C) && (gx < X1_C) && (gy >= Y0_C) && (gy < Y1_C);
    wire in_box    = (gx >= BOX_X0_C) && (gx <= BOX_X1_C) &&
                     (gy >= BOX_Y0_C) && (gy <= BOX_Y1_C);
    wire in_inner  = (gx >= IN_X0_C)  && (gx <= IN_X1_C)  &&
                     (gy >= IN_Y0_C)  && (gy <= IN_Y1_C);
    wire in_frame  = in_box && !in_inner;

    wire in_pnl    = (gx >= PN_X0_C)  && (gx <= PN_X1_C)  &&
                     (gy >= PN_Y0_C)  && (gy <= PN_Y1_C);
    wire in_pnl_in = (gx >= PN_IX0_C) && (gx <= PN_IX1_C) &&
                     (gy >= PN_IY0_C) && (gy <= PN_IY1_C);
    wire in_pnl_fr = in_pnl && !in_pnl_in;

    localparam [11:0] L0_Y = 12'd431;
    localparam [11:0] L1_Y = 12'd471;
    localparam [11:0] L2_Y = 12'd511;
    localparam [11:0] L3_Y = 12'd551;
    localparam [11:0] L4_X = 12'd855;
    localparam [11:0] L3_X = 12'd863;
    localparam [11:0] RULE_Y = 12'd499;

    localparam [23:0] C_FRAME   = 24'h46525E,
                      C_BODY    = 24'h0D1117,
                      C_OFF     = 24'h1D242E,
                      C_LOW     = 24'h1FC04A,
                      C_MID     = 24'hE8C830,
                      C_HIGH    = 24'hE84838,
                      C_PNL_FRM = 24'h2A3A4A,
                      C_RULE    = 24'h1E2A36,
                      C_TXT_LBL = 24'h6E8299,
                      C_TXT     = 24'hD9E6F2,
                      C_TXT_PK  = 24'h8FA6C0,
                      C_PKMARK  = 24'hF0F4F8,
                      C_BG      = 24'h080A0C;

    function [11:0] pitch_mul;
        input [3:0] i;
        begin
            pitch_mul = ({8'd0, i} << 3)
                      + ({8'd0, i} << 2)
                      + ({8'd0, i} << 1)
                      +  {8'd0, i};
        end
    endfunction

    function [11:0] seg_top;
        input [3:0] i;
        begin
            seg_top = IN_Y1_C - SEGH_C + 12'd1 - pitch_mul(i);
        end
    endfunction

    function [11:0] seg_bot;
        input [3:0] i;
        begin
            seg_bot = IN_Y1_C - pitch_mul(i);
        end
    endfunction

    function [3:0] seg_thr;
        input [3:0] i;
        begin
            case (i)
                4'd0 : seg_thr = 4'd1;
                4'd1 : seg_thr = 4'd2;
                4'd2 : seg_thr = 4'd3;
                4'd3 : seg_thr = 4'd4;
                4'd4 : seg_thr = 4'd5;
                4'd5 : seg_thr = 4'd6;
                4'd6 : seg_thr = 4'd7;
                4'd7 : seg_thr = 4'd8;
                4'd8 : seg_thr = 4'd10;
                4'd9 : seg_thr = 4'd11;
                4'd10: seg_thr = 4'd13;
                4'd11: seg_thr = 4'd14;
                default: seg_thr = 4'hF;
            endcase
        end
    endfunction

    function [23:0] seg_rgb;
        input [3:0] i;
        input       on;
        begin
            if (!on)             seg_rgb = C_OFF;
            else if (i <= 4'd4)  seg_rgb = C_LOW;
            else if (i <= 4'd8)  seg_rgb = C_MID;
            else                 seg_rgb = C_HIGH;
        end
    endfunction

    reg [3:0]  pk_r;
    reg [24:0] dec_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pk_r    <= 4'd0;
            dec_cnt <= 25'd0;
        end
        else if (level_msb > pk_r) begin
            pk_r    <= level_msb;
            dec_cnt <= 25'd0;
        end
        else if (dec_cnt >= 25'd24000000) begin
            dec_cnt <= 25'd0;
            if (pk_r != 4'd0) pk_r <= pk_r - 4'd1;
        end
        else dec_cnt <= dec_cnt + 25'd1;
    end

    function [7:0] db_of;
        input [3:0] m;
        reg   [4:0] gap;
        begin
            gap  = (m >= 4'd14) ? 5'd0 : (5'd14 - {1'b0, m});
            db_of = ({3'd0, gap} << 2) + ({3'd0, gap} << 1);
        end
    endfunction

    function [3:0] db_tens;
        input [7:0] m;
        begin
            if      (m >= 8'd80) db_tens = 4'd8;
            else if (m >= 8'd70) db_tens = 4'd7;
            else if (m >= 8'd60) db_tens = 4'd6;
            else if (m >= 8'd50) db_tens = 4'd5;
            else if (m >= 8'd40) db_tens = 4'd4;
            else if (m >= 8'd30) db_tens = 4'd3;
            else if (m >= 8'd20) db_tens = 4'd2;
            else if (m >= 8'd10) db_tens = 4'd1;
            else                db_tens = 4'd0;
        end
    endfunction

    function [7:0] db_ones;
        input [7:0] m;
        input [3:0] t;
        begin
            db_ones = m - ({4'd0, t} << 3) - ({4'd0, t} << 1);
        end
    endfunction

    function [4:0] gap_of;
        input [3:0] m;
        begin
            gap_of = (m >= 4'd14) ? 5'd0 : (5'd14 - {1'b0, m});
        end
    endfunction

    function [7:0] gap_x6;
        input [4:0] g;
        begin
            gap_x6 = ({3'd0, g} << 2) + ({3'd0, g} << 1);
        end
    endfunction

    function [3:0] tens_of_gap;
        input [4:0] g;
        begin
            case (g)
                5'd0 : tens_of_gap = 4'd0;  5'd1 : tens_of_gap = 4'd0;
                5'd2 : tens_of_gap = 4'd1;  5'd3 : tens_of_gap = 4'd1;
                5'd4 : tens_of_gap = 4'd2;  5'd5 : tens_of_gap = 4'd3;
                5'd6 : tens_of_gap = 4'd3;  5'd7 : tens_of_gap = 4'd4;
                5'd8 : tens_of_gap = 4'd4;  5'd9 : tens_of_gap = 4'd5;
                5'd10: tens_of_gap = 4'd6;  5'd11: tens_of_gap = 4'd6;
                5'd12: tens_of_gap = 4'd7;  5'd13: tens_of_gap = 4'd7;
                5'd14: tens_of_gap = 4'd8;
                default: tens_of_gap = 4'd0;
            endcase
        end
    endfunction

    function [7:0] ones_of_gap;
        input [4:0] g;
        begin
            case (g)
                5'd0 : ones_of_gap = 8'd0;  5'd1 : ones_of_gap = 8'd6;
                5'd2 : ones_of_gap = 8'd2;  5'd3 : ones_of_gap = 8'd8;
                5'd4 : ones_of_gap = 8'd4;  5'd5 : ones_of_gap = 8'd0;
                5'd6 : ones_of_gap = 8'd6;  5'd7 : ones_of_gap = 8'd2;
                5'd8 : ones_of_gap = 8'd8;  5'd9 : ones_of_gap = 8'd4;
                5'd10: ones_of_gap = 8'd0;  5'd11: ones_of_gap = 8'd6;
                5'd12: ones_of_gap = 8'd2;  5'd13: ones_of_gap = 8'd8;
                5'd14: ones_of_gap = 8'd4;
                default: ones_of_gap = 8'd0;
            endcase
        end
    endfunction

    wire [4:0] cur_gap = gap_of(level_msb);
    wire [7:0] cur_mag = gap_x6(cur_gap);
    wire [3:0] cur_tn  = tens_of_gap(cur_gap);
    wire [7:0] cur_on  = ones_of_gap(cur_gap);

    wire [4:0] pk_gap  = gap_of(pk_r);
    wire [7:0] pk_mag  = gap_x6(pk_gap);
    wire [3:0] pk_tn   = tens_of_gap(pk_gap);
    wire [7:0] pk_on   = ones_of_gap(pk_gap);

    function [3:0] lit_top;
        input [3:0] m;
        integer     ii;
        begin
            lit_top = 4'd0;
            for (ii = 0; ii < 12; ii = ii + 1)
                if (seg_thr(ii[3:0]) <= m) lit_top = ii[3:0];
        end
    endfunction

    function [12:0] glyph_row;
        input [4:0] ch;
        input [4:0] r;
        begin
            case (r)
            5'd0 : case (ch)
                5'd0 : glyph_row = 13'h1FFF;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h1FFF;
                5'd3 : glyph_row = 13'h1FFF;
                5'd4 : glyph_row = 13'h1C07;
                5'd5 : glyph_row = 13'h1FFF;
                5'd6 : glyph_row = 13'h1FFF;
                5'd7 : glyph_row = 13'h1FFF;
                5'd8 : glyph_row = 13'h1FFF;
                5'd9 : glyph_row = 13'h1FFF;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h1FFF;
                5'd12: glyph_row = 13'h1C07;
                5'd13: glyph_row = 13'h1FFF;
                5'd14: glyph_row = 13'h1FFF;
                5'd15: glyph_row = 13'h1C00;
                5'd16: glyph_row = 13'h0007;
                5'd17: glyph_row = 13'h1FFF;
                5'd18: glyph_row = 13'h1FFF;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd1 : case (ch)
                5'd0 : glyph_row = 13'h1FFF;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h1FFF;
                5'd3 : glyph_row = 13'h1FFF;
                5'd4 : glyph_row = 13'h1C07;
                5'd5 : glyph_row = 13'h1FFF;
                5'd6 : glyph_row = 13'h1FFF;
                5'd7 : glyph_row = 13'h1FFF;
                5'd8 : glyph_row = 13'h1FFF;
                5'd9 : glyph_row = 13'h1FFF;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h1FFF;
                5'd12: glyph_row = 13'h0E07;
                5'd13: glyph_row = 13'h1FFF;
                5'd14: glyph_row = 13'h1FFF;
                5'd15: glyph_row = 13'h1C00;
                5'd16: glyph_row = 13'h0007;
                5'd17: glyph_row = 13'h1FFF;
                5'd18: glyph_row = 13'h1FFF;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd2 : case (ch)
                5'd0 : glyph_row = 13'h1FFF;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h1FFF;
                5'd3 : glyph_row = 13'h1FFF;
                5'd4 : glyph_row = 13'h1C07;
                5'd5 : glyph_row = 13'h1FFF;
                5'd6 : glyph_row = 13'h1FFF;
                5'd7 : glyph_row = 13'h1FFF;
                5'd8 : glyph_row = 13'h1FFF;
                5'd9 : glyph_row = 13'h1FFF;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h1FFF;
                5'd12: glyph_row = 13'h0707;
                5'd13: glyph_row = 13'h1FFF;
                5'd14: glyph_row = 13'h1FFF;
                5'd15: glyph_row = 13'h1C00;
                5'd16: glyph_row = 13'h0007;
                5'd17: glyph_row = 13'h1FFF;
                5'd18: glyph_row = 13'h1FFF;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd3 : case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h1C00;
                5'd3 : glyph_row = 13'h1C00;
                5'd4 : glyph_row = 13'h1C07;
                5'd5 : glyph_row = 13'h0007;
                5'd6 : glyph_row = 13'h0007;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1C07;
                5'd9 : glyph_row = 13'h1C07;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h1C07;
                5'd12: glyph_row = 13'h0387;
                5'd13: glyph_row = 13'h0007;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1C00;
                5'd16: glyph_row = 13'h0007;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h0007;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd4 : case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h1C00;
                5'd3 : glyph_row = 13'h1C00;
                5'd4 : glyph_row = 13'h1C07;
                5'd5 : glyph_row = 13'h0007;
                5'd6 : glyph_row = 13'h0007;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1C07;
                5'd9 : glyph_row = 13'h1C07;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h1C07;
                5'd12: glyph_row = 13'h01C7;
                5'd13: glyph_row = 13'h0007;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1C00;
                5'd16: glyph_row = 13'h0007;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h0007;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd5 : case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h1C00;
                5'd3 : glyph_row = 13'h1C00;
                5'd4 : glyph_row = 13'h1C07;
                5'd5 : glyph_row = 13'h0007;
                5'd6 : glyph_row = 13'h0007;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1C07;
                5'd9 : glyph_row = 13'h1C07;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h1C07;
                5'd12: glyph_row = 13'h00E7;
                5'd13: glyph_row = 13'h0007;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1C00;
                5'd16: glyph_row = 13'h0007;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h0007;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd6 : case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h1C00;
                5'd3 : glyph_row = 13'h1C00;
                5'd4 : glyph_row = 13'h1C07;
                5'd5 : glyph_row = 13'h0007;
                5'd6 : glyph_row = 13'h0007;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1C07;
                5'd9 : glyph_row = 13'h1C07;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h1C07;
                5'd12: glyph_row = 13'h0077;
                5'd13: glyph_row = 13'h0007;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1C00;
                5'd16: glyph_row = 13'h0007;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h0007;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd7 : case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h1FFF;
                5'd3 : glyph_row = 13'h1FFF;
                5'd4 : glyph_row = 13'h1FFF;
                5'd5 : glyph_row = 13'h1FFF;
                5'd6 : glyph_row = 13'h1FFF;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1FFF;
                5'd9 : glyph_row = 13'h1FFF;
                5'd10: glyph_row = 13'h1FFF;
                5'd11: glyph_row = 13'h1FFF;
                5'd12: glyph_row = 13'h003F;
                5'd13: glyph_row = 13'h1FFF;
                5'd14: glyph_row = 13'h1FFF;
                5'd15: glyph_row = 13'h1FFF;
                5'd16: glyph_row = 13'h1FFF;
                5'd17: glyph_row = 13'h1FFF;
                5'd18: glyph_row = 13'h1FFF;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd8 : case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h0000;
                5'd2 : glyph_row = 13'h1FFF;
                5'd3 : glyph_row = 13'h1FFF;
                5'd4 : glyph_row = 13'h1FFF;
                5'd5 : glyph_row = 13'h1FFF;
                5'd6 : glyph_row = 13'h1FFF;
                5'd7 : glyph_row = 13'h0000;
                5'd8 : glyph_row = 13'h1FFF;
                5'd9 : glyph_row = 13'h1FFF;
                5'd10: glyph_row = 13'h1FFF;
                5'd11: glyph_row = 13'h1FFF;
                5'd12: glyph_row = 13'h001F;
                5'd13: glyph_row = 13'h1FFF;
                5'd14: glyph_row = 13'h1FFF;
                5'd15: glyph_row = 13'h1FFF;
                5'd16: glyph_row = 13'h1FFF;
                5'd17: glyph_row = 13'h1FFF;
                5'd18: glyph_row = 13'h1FFF;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd9 : case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h1FFF;
                5'd3 : glyph_row = 13'h1FFF;
                5'd4 : glyph_row = 13'h1FFF;
                5'd5 : glyph_row = 13'h1FFF;
                5'd6 : glyph_row = 13'h1FFF;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1FFF;
                5'd9 : glyph_row = 13'h1FFF;
                5'd10: glyph_row = 13'h1FFF;
                5'd11: glyph_row = 13'h1FFF;
                5'd12: glyph_row = 13'h003F;
                5'd13: glyph_row = 13'h1FFF;
                5'd14: glyph_row = 13'h1FFF;
                5'd15: glyph_row = 13'h1FFF;
                5'd16: glyph_row = 13'h1FFF;
                5'd17: glyph_row = 13'h1FFF;
                5'd18: glyph_row = 13'h1FFF;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd10: case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h0007;
                5'd3 : glyph_row = 13'h1C00;
                5'd4 : glyph_row = 13'h1C00;
                5'd5 : glyph_row = 13'h1C00;
                5'd6 : glyph_row = 13'h1C07;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1C07;
                5'd9 : glyph_row = 13'h1C00;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h0007;
                5'd12: glyph_row = 13'h0077;
                5'd13: glyph_row = 13'h0007;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1C07;
                5'd16: glyph_row = 13'h1C07;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h1C00;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd11: case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h0007;
                5'd3 : glyph_row = 13'h1C00;
                5'd4 : glyph_row = 13'h1C00;
                5'd5 : glyph_row = 13'h1C00;
                5'd6 : glyph_row = 13'h1C07;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1C07;
                5'd9 : glyph_row = 13'h1C00;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h0007;
                5'd12: glyph_row = 13'h00E7;
                5'd13: glyph_row = 13'h0007;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1C07;
                5'd16: glyph_row = 13'h1C07;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h1C00;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd12: case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h0007;
                5'd3 : glyph_row = 13'h1C00;
                5'd4 : glyph_row = 13'h1C00;
                5'd5 : glyph_row = 13'h1C00;
                5'd6 : glyph_row = 13'h1C07;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1C07;
                5'd9 : glyph_row = 13'h1C00;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h0007;
                5'd12: glyph_row = 13'h01C7;
                5'd13: glyph_row = 13'h0007;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1C07;
                5'd16: glyph_row = 13'h1C07;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h1C00;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd13: case (ch)
                5'd0 : glyph_row = 13'h1C07;
                5'd1 : glyph_row = 13'h1C00;
                5'd2 : glyph_row = 13'h0007;
                5'd3 : glyph_row = 13'h1C00;
                5'd4 : glyph_row = 13'h1C00;
                5'd5 : glyph_row = 13'h1C00;
                5'd6 : glyph_row = 13'h1C07;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1C07;
                5'd9 : glyph_row = 13'h1C00;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h0007;
                5'd12: glyph_row = 13'h0387;
                5'd13: glyph_row = 13'h0007;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1C07;
                5'd16: glyph_row = 13'h1C07;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h1C00;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd14: case (ch)
                5'd0 : glyph_row = 13'h1FFF;
                5'd1 : glyph_row = 13'h1FF8;
                5'd2 : glyph_row = 13'h1FFF;
                5'd3 : glyph_row = 13'h1FFF;
                5'd4 : glyph_row = 13'h1C00;
                5'd5 : glyph_row = 13'h1FFF;
                5'd6 : glyph_row = 13'h1FFF;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1FFF;
                5'd9 : glyph_row = 13'h1FFF;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h0000;
                5'd12: glyph_row = 13'h0707;
                5'd13: glyph_row = 13'h1FFF;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1FFF;
                5'd16: glyph_row = 13'h1FFF;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h1FFF;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd15: case (ch)
                5'd0 : glyph_row = 13'h1FFF;
                5'd1 : glyph_row = 13'h1FF8;
                5'd2 : glyph_row = 13'h1FFF;
                5'd3 : glyph_row = 13'h1FFF;
                5'd4 : glyph_row = 13'h1C00;
                5'd5 : glyph_row = 13'h1FFF;
                5'd6 : glyph_row = 13'h1FFF;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1FFF;
                5'd9 : glyph_row = 13'h1FFF;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h0000;
                5'd12: glyph_row = 13'h0E07;
                5'd13: glyph_row = 13'h1FFF;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1FFF;
                5'd16: glyph_row = 13'h1FFF;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h1FFF;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            5'd16: case (ch)
                5'd0 : glyph_row = 13'h1FFF;
                5'd1 : glyph_row = 13'h1FF8;
                5'd2 : glyph_row = 13'h1FFF;
                5'd3 : glyph_row = 13'h1FFF;
                5'd4 : glyph_row = 13'h1C00;
                5'd5 : glyph_row = 13'h1FFF;
                5'd6 : glyph_row = 13'h1FFF;
                5'd7 : glyph_row = 13'h1C00;
                5'd8 : glyph_row = 13'h1FFF;
                5'd9 : glyph_row = 13'h1FFF;
                5'd10: glyph_row = 13'h0000;
                5'd11: glyph_row = 13'h0000;
                5'd12: glyph_row = 13'h1C07;
                5'd13: glyph_row = 13'h1FFF;
                5'd14: glyph_row = 13'h1C07;
                5'd15: glyph_row = 13'h1FFF;
                5'd16: glyph_row = 13'h1FFF;
                5'd17: glyph_row = 13'h0007;
                5'd18: glyph_row = 13'h1FFF;
                5'd19: glyph_row = 13'h0000;
                default: glyph_row = 13'h0000;
            endcase
            default: glyph_row = 13'h0000;
            endcase
        end
    endfunction

    function [2:0] chi_of;
        input [11:0] cx;
        begin
            if      (cx < 12'd16) chi_of = 3'd0;
            else if (cx < 12'd32) chi_of = 3'd1;
            else if (cx < 12'd48) chi_of = 3'd2;
            else                  chi_of = 3'd3;
        end
    endfunction

    function [3:0] ix_of;
        input [11:0] cx;
        input [2:0]  chi;
        begin
            case (chi)
                3'd0: ix_of = cx[3:0];
                3'd1: ix_of = cx - 12'd16;
                3'd2: ix_of = cx - 12'd32;
                default: ix_of = cx - 12'd48;
            endcase
        end
    endfunction

    wire        band0 = (gy >= L0_Y) && (gy <= (L0_Y + 12'd16));
    wire        band1 = (gy >= L1_Y) && (gy <= (L1_Y + 12'd16));
    wire        band2 = (gy >= L2_Y) && (gy <= (L2_Y + 12'd16));
    wire        band3 = (gy >= L3_Y) && (gy <= (L3_Y + 12'd16));
    wire        txt_band = band0 || band1 || band2 || band3;

    wire        lab_row = band0 || band2;
    wire [11:0] txt_x0  = lab_row ? L4_X : L3_X;
    wire [11:0] txt_cx  = gx - txt_x0;
    wire        in_txt_x = lab_row ? ((gx >= L4_X) && (gx <= (L4_X + 12'd60)))
                                  : ((gx >= L3_X) && (gx <= (L3_X + 12'd44)));
    wire [4:0]  txt_cy  = band0 ? (gy - L0_Y)
                        : band1 ? (gy - L1_Y)
                        : band2 ? (gy - L2_Y) : (gy - L3_Y);

    wire [2:0]  txt_chi = chi_of(txt_cx);
    wire [3:0]  txt_ix  = ix_of(txt_cx, txt_chi);

    localparam [4:0] CH_MINUS = 5'd10,
                      CH_P     = 5'd11,
                      CH_K     = 5'd12,
                      CH_E     = 5'd13,
                      CH_A     = 5'd14,
                      CH_d     = 5'd15,
                      CH_B     = 5'd16,
                      CH_F     = 5'd17,
                      CH_S     = 5'd18,
                      CH_BLANK = 5'd19;

    function [4:0] ch_sign;
        input [7:0] m;
        begin
            ch_sign = (m != 8'd0) ? CH_MINUS : CH_BLANK;
        end
    endfunction

    reg [4:0] ch_sel;
    always @(*) begin
        if (band0) begin
            case (txt_chi)
                3'd0   : ch_sel = CH_d;
                3'd1   : ch_sel = CH_B;
                3'd2   : ch_sel = CH_F;
                default: ch_sel = CH_S;
            endcase
        end
        else if (band2) begin
            case (txt_chi)
                3'd0   : ch_sel = CH_P;
                3'd1   : ch_sel = CH_E;
                3'd2   : ch_sel = CH_A;
                default: ch_sel = CH_K;
            endcase
        end
        else if (band1) begin
            case (txt_chi)
                3'd0   : ch_sel = (cur_mag >= 8'd10) ? ch_sign(cur_mag) : CH_BLANK;
                3'd1   : ch_sel = (cur_mag >= 8'd10) ? {1'b0, cur_tn}  : ch_sign(cur_mag);
                default: ch_sel = {1'b0, cur_on[3:0]};
            endcase
        end
        else begin
            case (txt_chi)
                3'd0   : ch_sel = (pk_mag >= 8'd10) ? ch_sign(pk_mag) : CH_BLANK;
                3'd1   : ch_sel = (pk_mag >= 8'd10) ? {1'b0, pk_tn}   : ch_sign(pk_mag);
                default: ch_sel = {1'b0, pk_on[3:0]};
            endcase
        end
    end

    wire [12:0] g_row = glyph_row(ch_sel, txt_cy);
    wire        txt_ink = in_pnl_in && txt_band && in_txt_x &&
                          (txt_ix < 13) && g_row[txt_ix];

    reg [23:0] txt_col;
    always @(*) begin
        if      (band0 || band2) txt_col = C_TXT_LBL;
        else if (band1)          txt_col = C_TXT;
        else                     txt_col = C_TXT_PK;
    end

    wire        in_rule = in_pnl_in && (gy >= RULE_Y) && (gy <= (RULE_Y + 12'd1));

    wire        pk_mark  = in_inner && (pk_r != 4'd0) &&
                          (gy == seg_top(lit_top(pk_r)));

    reg  [3:0] seg_idx;
    reg        seg_hit;
    integer    kk;
    always @(*) begin
        seg_hit = 1'b0;
        seg_idx = 4'd0;
        for (kk = 0; kk < 12; kk = kk + 1) begin
            if ((gy >= seg_top(kk[3:0])) && (gy <= seg_bot(kk[3:0]))) begin
                seg_hit = 1'b1;
                seg_idx = kk[3:0];
            end
        end
    end

    wire       seg_on  = seg_hit && (level_msb >= seg_thr(seg_idx));
    wire [23:0] seg_col = seg_rgb(seg_idx, seg_on);

    wire        dot_x  = (gx[1:0] < 2'd2);
    wire        dot_y  = (gy[1:0] < 2'd2);
    wire        dot_on = dot_x && dot_y;
    wire [23:0] seg_px = dot_on ? seg_col : C_BODY;


    reg [23:0] rgb_c;
    reg        hit_c;

    always @(*) begin
        if (!in_graph || !gde) begin
            rgb_c = C_BG;
            hit_c = 1'b0;
        end
        else if (!in_box && !in_pnl) begin
            rgb_c = C_BG;
            hit_c = 1'b0;
        end
        else begin
            hit_c = 1'b1;
            if (in_box) begin
                if      (in_frame) rgb_c = C_FRAME;
                else if (pk_mark)  rgb_c = C_PKMARK;
                else if (seg_hit)  rgb_c = seg_px;
                else               rgb_c = C_BODY;
            end
            else begin
                if      (in_pnl_fr) rgb_c = C_PNL_FRM;
                else if (txt_ink)   rgb_c = txt_col;
                else if (in_rule)   rgb_c = C_RULE;
                else                rgb_c = C_BODY;
            end
        end
    end

    reg [24*OUT_LAT-1:0] rgb_pipe;
    reg [OUT_LAT-1:0]    hit_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rgb_pipe <= {24*OUT_LAT{1'b0}};
            hit_pipe <= {OUT_LAT{1'b0}};
        end
        else begin
            rgb_pipe <= (rgb_pipe << 24) | rgb_c;
            hit_pipe <= (hit_pipe << 1)  | hit_c;
        end
    end

    assign rgb = rgb_pipe[23:0];
    assign hit = hit_pipe[0];

    wire _unused = &{1'b0, sof, 1'b0, NSEG_C[3:0]};

endmodule
