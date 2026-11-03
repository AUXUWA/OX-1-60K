// adsr_graph —— 李萨如图区左侧空闲块上的 4 算子 ADSR 包络图（纯组合渲染，无状态机）

`timescale 1ns/1ps

module adsr_graph #(
    parameter integer X0 = 336,
    parameter integer Y0 = 400,
    parameter integer X1 = 1024,
    parameter integer Y1 = 600,

    parameter integer AX0 = 340,
    parameter integer AY0 = 404,
    parameter integer AW  = 177,
    parameter integer AH  = 193,

    parameter integer FRAME  = 1,
    parameter integer NLANE  = 4,
    parameter integer LANE_GAP = 2,
    parameter integer LANE_H = 45,

    parameter integer OUT_LAT = 4
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sof,

    input  wire [11:0] gx,
    input  wire [11:0] gy,
    input  wire        gde,

    input  wire [23:0] p_tl,
    input  wire [15:0] p_ar,
    input  wire [15:0] p_dr,
    input  wire [15:0] p_sl,
    input  wire [15:0] p_rr,
    input  wire [1:0]  focus_op,

    output wire [23:0] rgb,
    output wire        hit
);

    localparam [11:0] X0_C  = X0[11:0];
    localparam [11:0] Y0_C  = Y0[11:0];
    localparam [11:0] X1_C  = X1[11:0];
    localparam [11:0] Y1_C  = Y1[11:0];

    localparam [11:0] AX0_C = AX0[11:0];
    localparam [11:0] AY0_C = AY0[11:0];
    localparam [11:0] AW_C  = AW[11:0];
    localparam [11:0] AH_C  = AH[11:0];
    localparam [11:0] FR_C  = FRAME[11:0];

    localparam [11:0] BOX_X0_C = AX0_C;
    localparam [11:0] BOX_X1_C = AX0_C + AW_C - 12'd1;
    localparam [11:0] BOX_Y0_C = AY0_C;
    localparam [11:0] BOX_Y1_C = AY0_C + AH_C - 12'd1;

    localparam [11:0] IN_X0_C  = BOX_X0_C + FR_C;
    localparam [11:0] IN_X1_C  = BOX_X1_C - FR_C;
    localparam [11:0] IN_Y0_C  = BOX_Y0_C + FR_C;
    localparam [11:0] IN_Y1_C  = BOX_Y1_C - FR_C;

    localparam [11:0] LGAP_C = LANE_GAP[11:0];
    localparam [11:0] LANEH_C = LANE_H[11:0];
    localparam [11:0] LANEB_C = LANE_H[11:0] - 12'd1;

    wire [11:0] LT0 = AY0_C + LGAP_C;
    wire [11:0] LT1 = LT0 + 47;
    wire [11:0] LT2 = LT1 + 47;
    wire [11:0] LT3 = LT2 + 47;

    localparam [11:0] ENV_X0 = AX0_C + 12'd3;
    localparam [11:0] ENV_W  = AW_C - 12'd6;
    localparam [11:0] ENV_X1 = ENV_X0 + ENV_W - 12'd1;
    localparam [11:0] SUS_W  = 12'd20;

    localparam [11:0] LB_X = AX0_C + 12'd2;
    localparam [11:0] LB_H = 12'd7;
    localparam [11:0] LB_OX = 12'd18;
    localparam [11:0] LB_END = LB_X + 12'd34;

    localparam [23:0] C_FRM   = 24'h2A3A4A,
                      C_BODY   = 24'h0D1117,
                      C_BASE   = 24'h151D26,
                      C_LBL    = 24'h6E8299,
                      C_OFFM   = 24'h74879C,
                      C_FOCUS  = 24'h1FC04A,
                      C_OP0    = 24'h30C0FF,
                      C_OP1    = 24'h40FF90,
                      C_OP2    = 24'hFFB040,
                      C_OP3    = 24'hE070FF,
                      C_BG     = 24'h080A0C;


    wire in_l0 = (gy >= LT0) && (gy <= (LT0 + LANEB_C));
    wire in_l1 = (gy >= LT1) && (gy <= (LT1 + LANEB_C));
    wire in_l2 = (gy >= LT2) && (gy <= (LT2 + LANEB_C));
    wire in_l3 = (gy >= LT3) && (gy <= (LT3 + LANEB_C));

    reg [2:0] lane;
    always @(*) begin
        if      (in_l3) lane = 3'd3;
        else if (in_l2) lane = 3'd2;
        else if (in_l1) lane = 3'd1;
        else if (in_l0) lane = 3'd0;
        else            lane = 3'd7;
    end

    reg [11:0] ltop;
    always @(*) begin
        case (lane)
            3'd0   : ltop = LT0;
            3'd1   : ltop = LT1;
            3'd2   : ltop = LT2;
            3'd3   : ltop = LT3;
            default: ltop = LT0;
        endcase
    end
    wire [11:0] lbase = ltop + LANEB_C;

    reg [5:0] k_tl;
    reg [3:0] k_ar, k_dr, k_sl, k_rr;
    always @(*) begin
        case (lane)
            3'd0: begin
                k_tl = p_tl[5:0];   k_ar = p_ar[3:0];
                k_dr = p_dr[3:0];   k_sl = p_sl[3:0];   k_rr = p_rr[3:0];
            end
            3'd1: begin
                k_tl = p_tl[11:6];  k_ar = p_ar[7:4];
                k_dr = p_dr[7:4];   k_sl = p_sl[7:4];   k_rr = p_rr[7:4];
            end
            3'd2: begin
                k_tl = p_tl[17:12]; k_ar = p_ar[11:8];
                k_dr = p_dr[11:8];  k_sl = p_sl[11:8];  k_rr = p_rr[11:8];
            end
            3'd3: begin
                k_tl = p_tl[23:18]; k_ar = p_ar[15:12];
                k_dr = p_dr[15:12]; k_sl = p_sl[15:12]; k_rr = p_rr[15:12];
            end
            default: begin
                k_tl = 6'd0;  k_ar = 4'd0;  k_dr = 4'd0;
                k_sl = 4'd0;  k_rr = 4'd0;
            end
        endcase
    end

    wire op_mute = (k_tl == 6'd63);

    wire [11:0] tl_amt = 12'd63 - {6'd0, k_tl};
    wire [11:0] sl_amt = 12'd15 - {8'd0, k_sl};

    wire [12:0] tl_x45 = (tl_amt << 5) + (tl_amt << 3)
                       + (tl_amt << 2) +  tl_amt;
    wire [12:0] sl_x45 = (sl_amt << 5) + (sl_amt << 3)
                       + (sl_amt << 2) +  sl_amt;

    wire [11:0] peak_h = tl_x45[12:6];
    wire [11:0] sust_h = sl_x45[12:4];

    wire [11:0] p_raw = lbase - peak_h;
    wire [11:0] s_raw = lbase - sust_h;
    wire [11:0] vy1_c = (p_raw < ltop) ? ltop
                    : (p_raw > lbase) ? lbase : p_raw;
    wire [11:0] vy2_c = (s_raw < ltop) ? ltop
                    : (s_raw > lbase) ? lbase : s_raw;

    wire [6:0] w_ar = {k_ar, 2'b00};
    wire [6:0] w_dr = {k_dr, 1'b0};
    wire [6:0] w_rr = {k_rr, 2'b00};

    wire [11:0] ex1_c = ENV_X0 + {5'd0, w_ar};
    wire [11:0] ex2_c = ENV_X0 + {5'd0, w_ar} + {5'd0, w_dr};
    wire [11:0] ex3_c = ENV_X0 + {5'd0, w_ar} + {5'd0, w_dr}
                              + SUS_W;
    wire [11:0] ex4_c = ENV_X0 + {5'd0, w_ar} + {5'd0, w_dr}
                              + SUS_W + {5'd0, w_rr};

    reg [2:0]  q_lane;
    reg [11:0] q_ltop2;
    reg [11:0] q_lbase2;
    reg [11:0] ltop_c;
    reg [11:0] q_vy1, q_vy2;
    reg [11:0] q_ex1, q_ex2, q_ex3, q_ex4;
    reg        q_mute;
    reg [11:0] q_gx, q_gy;
    reg        q_gde;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_lane   <= 3'd7;
            q_ltop2  <= 12'd0;
            q_lbase2 <= 12'd0;
            q_vy1  <= 12'd0;
            q_vy2  <= 12'd0;
            q_ex1  <= 12'd0;
            q_ex2  <= 12'd0;
            q_ex3  <= 12'd0;
            q_ex4  <= 12'd0;
            q_mute <= 1'b0;
            q_gx   <= 12'd0;
            q_gy   <= 12'd0;
            q_gde  <= 1'b0;
        end
        else begin
            q_lane   <= lane;
            q_ltop2  <= ltop_c;
            q_lbase2 <= ltop_c + LANEB_C;
            q_vy1  <= vy1_c;
            q_vy2  <= vy2_c;
            q_ex1  <= ex1_c;
            q_ex2  <= ex2_c;
            q_ex3  <= ex3_c;
            q_ex4  <= ex4_c;
            q_mute <= op_mute;
            q_gx   <= gx;
            q_gy   <= gy;
            q_gde  <= gde;
        end
    end

    wire [11:0] gx2 = q_gx;
    wire [11:0] gy2 = q_gy;
    wire        gde2 = q_gde;

    wire in_box   = (gx2 >= BOX_X0_C) && (gx2 <= BOX_X1_C) &&
                    (gy2 >= BOX_Y0_C) && (gy2 <= BOX_Y1_C);
    wire in_inner = (gx2 >= IN_X0_C)  && (gx2 <= IN_X1_C)  &&
                    (gy2 >= IN_Y0_C)  && (gy2 <= IN_Y1_C);
    wire in_frm   = in_box && !in_inner;

    always @(*) begin
        case (lane)
            3'd0   : ltop_c = LT0;
            3'd1   : ltop_c = LT1;
            3'd2   : ltop_c = LT2;
            3'd3   : ltop_c = LT3;
            default: ltop_c = LT0;
        endcase
    end

    wire [11:0] ex1 = q_ex1;
    wire [11:0] ex2 = q_ex2;
    wire [11:0] ex3 = q_ex3;
    wire [11:0] ex4 = q_ex4;
    wire [11:0] vy1 = q_vy1;
    wire [11:0] vy2 = q_vy2;

    function seg_on;
        input [11:0] px, py;
        input [11:0] x0, y0, x1, y1;
        reg   [12:0] dx, ady, n;
        reg   [12:0] dif, ydg;
        reg          up;
        begin
            dx  = {1'b0, x1} - {1'b0, x0};
            up  = (y1 >= y0);
            if (up) begin
                ady = {1'b0, y1} - {1'b0, y0};
                dif = {1'b0, py} - {1'b0, y0};
                ydg = y0 + dx[11:0];
            end
            else begin
                ady = {1'b0, y0} - {1'b0, y1};
                dif = {1'b0, y0} - {1'b0, py};
                ydg = y0 - dx[11:0];
            end
            n = (dx < ady) ? dx : ady;

            seg_on = 1'b0;
            if ((px >= x0) && (px <= (x0 + n[11:0])) &&
                (dif == {1'b0, px - x0})) seg_on = 1'b1;
            if (!seg_on && (dx > ady)) begin
                if ((py == y1) && (px >= (x0 + ady[11:0])) && (px <= x1))
                    seg_on = 1'b1;
            end
            else if (!seg_on && (dx < ady)) begin
                if ((px == x1) &&
                    (up ? ((py >= ydg[11:0]) && (py <= y1))
                        : ((py <= ydg[11:0]) && (py >= y1))))
                    seg_on = 1'b1;
            end
        end
    endfunction

    wire in_env_x = (gx2 >= ENV_X0) && (gx2 <= ex4) && (gx2 <= ENV_X1);

    wire env_on = (q_lane != 3'd7) && in_env_x &&
                  ( seg_on(gx2, gy2, ENV_X0, q_lbase2, ex1,   vy1)   ||
                    seg_on(gx2, gy2, ex1,    vy1,   ex2,   vy2)   ||
                    ((gy2 == vy2) && (gx2 >= ex2) && (gx2 <= ex3))     ||
                    seg_on(gx2, gy2, ex3,    vy2,   ex4,   q_lbase2) );

    wire base_on = (q_lane != 3'd7) && (gy2 == q_lbase2);

    localparam [3:0] CH_O = 4'd0,
                     CH_P = 4'd1,
                     CH_D = 4'd2,
                     CH_F = 4'd6;

    function [4:0] glyph5;
        input [3:0] ch;
        input [2:0] r;
        reg   [34:0] vec;
        reg   [6:0]  bsel;
        begin
            case (ch)
                CH_O : vec = 35'b01110_10001_10001_10001_10001_10001_01110;
                CH_P : vec = 35'b11110_10001_10001_11110_10000_10000_10000;
                CH_D+4'd0 : vec = 35'b01110_10001_10011_10101_11001_10001_01110;
                CH_D+4'd1 : vec = 35'b00100_01100_00100_00100_00100_00100_01110;
                CH_D+4'd2 : vec = 35'b01110_10001_00001_00010_00100_01000_11111;
                CH_D+4'd3 : vec = 35'b11111_00010_00100_00010_00001_10001_01110;
                CH_F : vec = 35'b11111_10000_10000_11110_10000_10000_10000;
                default: vec = 35'd0;
            endcase
            case (r)
                3'd0: glyph5 = vec[34:30];
                3'd1: glyph5 = vec[29:25];
                3'd2: glyph5 = vec[24:20];
                3'd3: glyph5 = vec[19:15];
                3'd4: glyph5 = vec[14:10];
                3'd5: glyph5 = vec[9:5];
                3'd6: glyph5 = vec[4:0];
                default: glyph5 = 5'd0;
            endcase
        end
    endfunction

    wire lband = (q_lane != 3'd7) && (gy2 >= q_ltop2) && (gy2 <= (q_ltop2 + LB_H - 12'd1));
    wire lcol  = (gx2 >= LB_X) && (gx2 <= LB_END);

    reg  [3:0] lch;
    reg  [5:0] lix;
    reg        l_off;
    always @(*) begin
        lch  = CH_O;
        lix  = 6'd0;
        l_off = 1'b0;
        if      (gx2 < (LB_X + 12'd6))  begin lch = CH_O; lix = gx2 - LB_X; end
        else if (gx2 < (LB_X + 12'd12)) begin lch = CH_P; lix = gx2 - LB_X - 12'd6; end
        else if (gx2 < (LB_X + 12'd18)) begin lch = CH_D + {2'd0, q_lane};
                                           lix = gx2 - LB_X - 12'd12; end
        else if (gx2 < (LB_X + 12'd24)) begin lch = CH_O; lix = gx2 - LB_X - 12'd18;
                                           l_off = 1'b1; end
        else if (gx2 < (LB_X + 12'd30)) begin lch = CH_F; lix = gx2 - LB_X - 12'd24;
                                           l_off = 1'b1; end
        else                            begin lch = CH_F; lix = gx2 - LB_X - 12'd30;
                                           l_off = 1'b1; end
    end
    wire l_off_ok = l_off && q_mute;

    wire [2:0] lrow = lband ? gy2[2:0] - q_ltop2[2:0] : 3'd7;
    wire [4:0] grow = glyph5(lch, lrow);
    wire lbit   = (lix < 6'd5) ? grow[4'd4 - lix[2:0]] : 1'b0;
    wire lbl_on = lband && lcol && lbit && (!l_off || l_off_ok);


    reg [11:0] fltop;
    always @(*) begin
        case (focus_op)
            2'd0   : fltop = LT0;
            2'd1   : fltop = LT1;
            2'd2   : fltop = LT2;
            default: fltop = LT3;
        endcase
    end

    wire [11:0] fbase = fltop + LANEB_C;
    wire [11:0] foc_y0 = fltop - 12'd1;
    wire [11:0] foc_y1 = fltop + LANEH_C;

    wire foc_edge = (gx2 >= IN_X0_C) && (gx2 <= IN_X1_C) &&
                    (gy2 >= foc_y0) && (gy2 <= foc_y1) &&
                    ( ((gy2 == foc_y0) || (gy2 == foc_y1)) ||
                      ((gy2 >= fltop) && (gy2 <= fbase) &&
                       ((gx2 == IN_X0_C) || (gx2 == IN_X1_C))) );


    function [23:0] op_col;
        input [2:0] k;
        begin
            case (k)
                3'd0   : op_col = C_OP0;
                3'd1   : op_col = C_OP1;
                3'd2   : op_col = C_OP2;
                3'd3   : op_col = C_OP3;
                default: op_col = C_BODY;
            endcase
        end
    endfunction

    wire [23:0] lane_col = op_col(q_lane);

    reg        r_in_box;
    reg        r_in_frm;
    reg        r_foc;
    reg        r_env;
    reg        r_lbl;
    reg        r_lbl_grey;
    reg        r_base;
    reg [1:0]  r_lane;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_in_box <= 1'b0; r_in_frm <= 1'b0; r_foc <= 1'b0;
            r_env <= 1'b0; r_lbl <= 1'b0; r_base <= 1'b0;
            r_lbl_grey <= 1'b0;
            r_lane <= 2'd0;
        end
        else begin
            r_in_box <= gde2 && in_box;
            r_in_frm <= in_frm;
            r_foc    <= foc_edge;
            r_env    <= env_on;
            r_lbl    <= lbl_on;
            r_lbl_grey <= l_off_ok;
            r_base   <= base_on;
            r_lane   <= q_lane[1:0];
        end
    end

    reg [23:0] lbl_col3;
    reg [23:0] lane_col3;
    always @(*) begin
        case (r_lane)
            2'd0:    lane_col3 = C_OP0;
            2'd1:    lane_col3 = C_OP1;
            2'd2:    lane_col3 = C_OP2;
            default: lane_col3 = C_OP3;
        endcase
        lbl_col3 = r_lbl_grey ? C_OFFM : C_LBL;
    end

    reg [23:0] rgb_c;
    reg        hit_c;

    always @(*) begin
        if (!r_in_box) begin
            rgb_c = C_BG;
            hit_c = 1'b0;
        end
        else begin
            hit_c = 1'b1;
            if      (r_in_frm)         rgb_c = C_FRM;
            else if (r_foc)            rgb_c = C_FOCUS;
            else if (r_env)            rgb_c = lane_col3;
            else if (r_lbl)            rgb_c = lbl_col3;
            else if (r_base)           rgb_c = C_BASE;
            else                       rgb_c = C_BODY;
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

    wire _unused = &{1'b0, sof, 1'b0, NLANE[2:0], 1'b0, LB_OX[11:8],
                     ENV_W[11:8], LANEH_C[11:8], 1'b0, X0_C[11:6], 1'b0};

endmodule
