// display_top —— 整屏合成 —— 把"左侧参数面板 + 右上频谱 + 右中波形 + 右下李萨如"

`timescale 1ns/1ps

module display_top #(
    parameter integer H_ACTIVE = 1024,
    parameter integer V_ACTIVE = 600,
    parameter integer OUT_LAT  = 4,
    parameter [7:0]   BUILD_SIG = 8'hA5,
    parameter integer PROBE_EN  = 0,
    parameter integer CHAR_ROM_SELFTEST = 0,

    parameter integer FS_HZ    = 48828,
    parameter integer N_VOICE  = 1
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        de,
    input  wire [11:0] x,
    input  wire [11:0] y,
    input  wire        sof,

    input  wire        probe_pan_we,
    input  wire        probe_locks,

    input  wire        p_we,
    input  wire [5:0]  p_col,
    input  wire [5:0]  p_row,
    input  wire [7:0]  p_ch,
    input  wire [3:0]  p_color,
    input  wire        p_bold,

    input  wire        page_sel,
    input  wire        sq_we,
    input  wire [6:0]  sq_col,
    input  wire [5:0]  sq_row,
    input  wire [7:0]  sq_ch,
    input  wire [3:0]  sq_color,
    input  wire        sq_bold,

    input  wire [23:0] p_tl,
    input  wire [15:0] p_ar,
    input  wire [15:0] p_dr,
    input  wire [15:0] p_sl,
    input  wire [15:0] p_rr,
    input  wire [1:0]  focus_op,

    input  wire [23:0] spec_rgb,   input wire spec_hit,
    input  wire [23:0] wave_rgb,   input wire wave_hit,
    input  wire [23:0] lis_rgb,    input wire lis_hit,

    input  wire [3:0]  level_msb,

    output reg  [23:0] rgb,

    output wire [11:0] gx,
    output wire [11:0] gy,
    output wire        gde
);

    localparam integer PANEL_W = 336;
    localparam integer PANEL_H = 592;

    localparam integer SPEC_Y0 = 0,   SPEC_Y1 = 200;
    localparam integer WAVE_Y0 = 200, WAVE_Y1 = 400;
    localparam integer LIS_Y0  = 400, LIS_Y1  = 600;

    localparam integer GX0 = PANEL_W;
    localparam integer GX1 = H_ACTIVE;

    localparam [11:0] PROBE_BOX_X0   = 12'd990;
    localparam [11:0] PROBE_BOX_W    = 12'd8;
    localparam [11:0] PROBE_BOX_Y0   = 12'd4;
    localparam [11:0] PROBE_BOX_PIT  = 12'd10;
    localparam [11:0] PROBE_SIG_X0   = 12'd991;
    localparam [11:0] PROBE_SIG_PITCH= 12'd4;
    localparam [11:0] PROBE_SIG_W    = 12'd3;
    localparam [11:0] PROBE_SIG_Y0   = 12'd16;
    localparam [11:0] PROBE_SIG_Y1   = 12'd31;
    localparam [11:0] PROBE_SIG_CY0  = 12'd17;
    localparam [11:0] PROBE_SIG_CY1  = 12'd30;

    localparam [23:0] P_MAGENTA = 24'hFF00FF,
                      P_CYAN    = 24'h00FFFF,
                      P_GREEN   = 24'h00FF00,
                      P_OFF     = 24'h404040,
                      P_WHITE   = 24'hFFFFFF,
                      P_BLACK   = 24'h000000;

    localparam [11:0] PB1_X0 = PROBE_BOX_X0;
    localparam [11:0] PB1_X1 = PB1_X0 + PROBE_BOX_W - 12'd1;
    localparam [11:0] PB2_X0 = PB1_X0 + PROBE_BOX_PIT;
    localparam [11:0] PB2_X1 = PB2_X0 + PROBE_BOX_W - 12'd1;
    localparam [11:0] PB3_X0 = PB2_X0 + PROBE_BOX_PIT;
    localparam [11:0] PB3_X1 = PB3_X0 + PROBE_BOX_W - 12'd1;
    localparam [11:0] PB_Y0  = PROBE_BOX_Y0;
    localparam [11:0] PB_Y1  = PB_Y0 + PROBE_BOX_W - 12'd1;
    localparam [11:0] SIG_X1 = PROBE_SIG_X0 + PROBE_SIG_PITCH * 12'd7 + PROBE_SIG_W - 12'd1;


    localparam [11:0] GX0_C = GX0[11:0];
    localparam [11:0] GX1_C = GX1[11:0];
    localparam [11:0] SPEC_Y0_C = SPEC_Y0[11:0];
    localparam [11:0] SPEC_Y1_C = SPEC_Y1[11:0];
    localparam [11:0] WAVE_Y0_C = WAVE_Y0[11:0];
    localparam [11:0] WAVE_Y1_C = WAVE_Y1[11:0];
    localparam [11:0] LIS_Y0_C  = LIS_Y0[11:0];
    localparam [11:0] LIS_Y1_C  = LIS_Y1[11:0];
    localparam [11:0] HA_C = H_ACTIVE[11:0];
    localparam [11:0] VA_C = V_ACTIVE[11:0];

    localparam [23:0] C_BG      = 24'h080A0C,
                      C_DIVIDER = 24'h303840,
                      C_FRAME   = 24'h506070,
                      C_PANEL_BG= 24'h101418;

    reg [12*OUT_LAT-1:0] xpipe, ypipe;
    reg [OUT_LAT-1:0]    de_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            xpipe <= {12*OUT_LAT{1'b0}};
            ypipe <= {12*OUT_LAT{1'b0}};
            de_pipe <= {OUT_LAT{1'b0}};
        end
        else begin
            xpipe   <= (xpipe << 12) | x;
            ypipe   <= (ypipe << 12) | y;
            de_pipe <= (de_pipe << 1) | de;
        end
    end

    wire [11:0] y_q = ypipe[12*(OUT_LAT-1) +: 12];
    wire [11:0] x_q = xpipe[12*(OUT_LAT-1) +: 12];
    wire        de_q = de_pipe[OUT_LAT-1];


    reg pan_ever;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        pan_ever <= 1'b0;
        else if (probe_pan_we) pan_ever <= 1'b1;
    end

    wire probe_pan_ever = pan_ever;

    wire probe_in_box3 = (x_q >= PB3_X0) && (x_q <= PB3_X1) &&
                         (y_q >= PB_Y0)  && (y_q <= PB_Y1);
    wire probe_in_box2 = (x_q >= PB2_X0) && (x_q <= PB2_X1) &&
                         (y_q >= PB_Y0)  && (y_q <= PB_Y1);
    wire probe_in_box1 = (x_q >= PB1_X0) && (x_q <= PB1_X1) &&
                         (y_q >= PB_Y0)  && (y_q <= PB_Y1);

    wire sig_in_frame = (x_q >= PROBE_SIG_X0) && (x_q <= SIG_X1) &&
                        (y_q >= PROBE_SIG_Y0) && (y_q <= PROBE_SIG_Y1);
    reg sig_cell;
    reg sig_bit;
    always @(*) begin
        sig_cell = 1'b0;
        sig_bit  = 1'b0;
        if ((y_q >= PROBE_SIG_CY0) && (y_q <= PROBE_SIG_CY1)) begin
            if      ((x_q >= PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd0) &&
                     (x_q <  PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd0 + PROBE_SIG_W)) begin sig_cell = 1'b1; sig_bit = BUILD_SIG[7]; end
            else if ((x_q >= PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd1) &&
                     (x_q <  PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd1 + PROBE_SIG_W)) begin sig_cell = 1'b1; sig_bit = BUILD_SIG[6]; end
            else if ((x_q >= PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd2) &&
                     (x_q <  PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd2 + PROBE_SIG_W)) begin sig_cell = 1'b1; sig_bit = BUILD_SIG[5]; end
            else if ((x_q >= PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd3) &&
                     (x_q <  PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd3 + PROBE_SIG_W)) begin sig_cell = 1'b1; sig_bit = BUILD_SIG[4]; end
            else if ((x_q >= PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd4) &&
                     (x_q <  PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd4 + PROBE_SIG_W)) begin sig_cell = 1'b1; sig_bit = BUILD_SIG[3]; end
            else if ((x_q >= PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd5) &&
                     (x_q <  PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd5 + PROBE_SIG_W)) begin sig_cell = 1'b1; sig_bit = BUILD_SIG[2]; end
            else if ((x_q >= PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd6) &&
                     (x_q <  PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd6 + PROBE_SIG_W)) begin sig_cell = 1'b1; sig_bit = BUILD_SIG[1]; end
            else if ((x_q >= PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd7) &&
                     (x_q <  PROBE_SIG_X0 + PROBE_SIG_PITCH*12'd7 + PROBE_SIG_W)) begin sig_cell = 1'b1; sig_bit = BUILD_SIG[0]; end
        end
    end

    wire probe_on  = PROBE_EN && (probe_in_box1 || probe_in_box2 || probe_in_box3 || sig_in_frame);
    wire [23:0] probe_rgb =
        probe_in_box1 ? (probe_pan_ever ? P_MAGENTA : P_OFF) :
        probe_in_box2 ? (probe_locks    ? P_CYAN    : P_OFF) :
        probe_in_box3 ? ((CHAR_ROM_SELFTEST != 0) ? P_GREEN : P_OFF) :
                        (sig_cell ? (sig_bit ? P_WHITE : P_BLACK) : P_OFF);

    wire in_gfx_x = (x_q >= GX0_C) && (x_q < GX1_C);

    wire in_spec = in_gfx_x && (y_q >= SPEC_Y0_C) && (y_q < SPEC_Y1_C);
    wire in_wave = in_gfx_x && (y_q >= WAVE_Y0_C) && (y_q < WAVE_Y1_C);
    wire in_lis  = in_gfx_x && (y_q >= LIS_Y0_C)  && (y_q < LIS_Y1_C);

    wire border = (x_q < 12'd2) || (x_q >= (HA_C - 12'd2)) ||
                  (y_q < 12'd2) || (y_q >= (VA_C - 12'd2));

    wire vdiv = (x_q >= (GX0_C - 12'd1)) && (x_q <= (GX0_C + 12'd1));
    wire hdiv = in_gfx_x &&
                (((y_q >= (SPEC_Y1_C - 12'd1)) && (y_q <= (SPEC_Y1_C + 12'd1))) ||
                 ((y_q >= (WAVE_Y1_C - 12'd1)) && (y_q <= (WAVE_Y1_C + 12'd1))));

    wire [23:0] panel_rgb_main;
    wire        panel_hit_main;

    text_buf #(
        .PANEL_COLS (42),
        .PANEL_ROWS (37),
        .OUT_LAT    (OUT_LAT),
        .FG_COLOR   (24'hC8D8E8),
        .BG_COLOR   (C_PANEL_BG)
    ) u_text_buf (
        .clk   (clk),
        .rst_n (rst_n),
        .we    (p_we),
        .w_col (p_col),
        .w_row (p_row),
        .w_ch  (p_ch),
        .w_color (p_color),
        .w_bold  (p_bold),
        .de    (de),
        .x     (x),
        .y     (y),
        .rgb   (panel_rgb_main),
        .hit   (panel_hit_main)
    );

    wire [23:0] panel_rgb_seq;
    wire        panel_hit_seq;

    text_buf #(
        .PANEL_COLS (128),
        .PANEL_ROWS (37),
        .OUT_LAT    (OUT_LAT),
        .FG_COLOR   (24'hC8D8E8),
        .BG_COLOR   (C_PANEL_BG)
    ) u_text_buf_seq (
        .clk   (clk),
        .rst_n (rst_n),
        .we    (sq_we),
        .w_col (sq_col),
        .w_row (sq_row),
        .w_ch  (sq_ch),
        .w_color (sq_color),
        .w_bold  (sq_bold),
        .de    (de),
        .x     (x),
        .y     (y),
        .rgb   (panel_rgb_seq),
        .hit   (panel_hit_seq)
    );

    wire [23:0] panel_rgb = page_sel ? panel_rgb_seq : panel_rgb_main;
    wire        panel_hit = page_sel ? panel_hit_seq : panel_hit_main;

    wire [23:0] lm_rgb;
    wire        lm_hit;

    level_meter #(
        .X0      (336),  .Y0 (400),
        .X1      (1024), .Y1 (600),
        .MX0     (952),  .MY0 (404),
        .MW      (68),   .MH  (192),
        .RX0     (826),  .RY0 (404),
        .RW      (120),  .RH  (192),
        .NSEG    (12),   .SEG_H (14), .GAP (1),
        .OUT_LAT (OUT_LAT)
    ) u_level_meter (
        .clk        (clk),
        .rst_n      (rst_n),
        .sof        (sof),
        .gx         (gx),
        .gy         (gy),
        .gde        (gde),
        .level_msb  (level_msb),
        .rgb        (lm_rgb),
        .hit        (lm_hit)
    );

    wire [23:0] adsr_rgb;
    wire        adsr_hit;

    adsr_graph #(
        .X0      (336),  .Y0 (400),
        .X1      (1024), .Y1 (600),
        .AX0     (340),  .AY0 (404),
        .AW      (177),  .AH  (193),
        .FRAME   (1),    .NLANE (4),
        .LANE_GAP (2),   .LANE_H (45),
        .OUT_LAT (OUT_LAT)
    ) u_adsr_graph (
        .clk        (clk),
        .rst_n      (rst_n),
        .sof        (sof),
        .gx         (gx),
        .gy         (gy),
        .gde        (gde),
        .p_tl       (p_tl),
        .p_ar       (p_ar),
        .p_dr       (p_dr),
        .p_sl       (p_sl),
        .p_rr       (p_rr),
        .focus_op   (focus_op),
        .rgb        (adsr_rgb),
        .hit        (adsr_hit)
    );

    wire [23:0] stat_rgb;
    wire        stat_hit;

    stat_panel #(
        .X0      (336),  .Y0 (400),
        .X1      (1024), .Y1 (600),
        .SX0     (717),  .SY0 (404),
        .SW      (103),  .SH  (192),
        .TX0     (720),  .TY0 (412),
        .NCOLS   (12),   .NROWS (11),
        .FRAME   (1),
        .OUT_LAT (OUT_LAT),
        .FS_HZ   (FS_HZ),
        .N_VOICE (N_VOICE)
    ) u_stat_panel (
        .clk        (clk),
        .rst_n      (rst_n),
        .sof        (sof),
        .gx         (gx),
        .gy         (gy),
        .gde        (gde),
        .p_tl       (p_tl),
        .focus_op   (focus_op),
        .rgb        (stat_rgb),
        .hit        (stat_hit)
    );

    localparam [23:0] C_RULE5 = 24'h1E2A36,
                      C_TXT5  = 24'h6E8299;

    function [14:0] mini5;
        input [7:0] ch;
        begin
            case (ch)
                "0": mini5 = 15'b111_101_101_101_111;
                "1": mini5 = 15'b111_010_010_110_010;
                "2": mini5 = 15'b111_100_111_001_111;
                "3": mini5 = 15'b111_001_111_001_111;
                "4": mini5 = 15'b001_001_111_101_101;
                "5": mini5 = 15'b111_001_111_100_111;
                "6": mini5 = 15'b111_101_111_100_111;
                "7": mini5 = 15'b010_010_010_001_111;
                "8": mini5 = 15'b111_101_111_101_111;
                "9": mini5 = 15'b111_001_111_101_111;
                "A": mini5 = 15'b101_101_111_101_010;
                "C": mini5 = 15'b111_100_100_100_111;
                "D": mini5 = 15'b110_101_101_101_110;
                "G": mini5 = 15'b111_100_101_101_111;
                "H": mini5 = 15'b101_101_111_101_101;
                "I": mini5 = 15'b111_010_010_010_111;
                "K": mini5 = 15'b101_101_110_101_101;
                "M": mini5 = 15'b101_101_111_111_101;
                "N": mini5 = 15'b101_111_111_111_101;
                "O": mini5 = 15'b111_101_101_101_111;
                "P": mini5 = 15'b100_100_111_101_111;
                "R": mini5 = 15'b101_101_110_101_110;
                "S": mini5 = 15'b110_001_010_100_011;
                "T": mini5 = 15'b010_010_010_010_111;
                "U": mini5 = 15'b111_101_101_101_101;
                "Z": mini5 = 15'b111_001_010_100_111;
                "/": mini5 = 15'b001_001_010_100_100;
                ".": mini5 = 15'b010_000_000_000_000;
                default: mini5 = 15'd0;
            endcase
        end
    endfunction

    localparam [11:0] SB_X0 = 12'd338, SB_X1 = 12'd1021;
    localparam [11:0] S5_TY = 12'd194, S5_BY = 12'd198;
    localparam [11:0] W2_TY = 12'd202, W2_BY = 12'd206;
    localparam [11:0] W1_RY = 12'd392,
                      W1_TY = 12'd393, W1_BY = 12'd397;

    wire in_sb = (x_q >= SB_X0) && (x_q <= SB_X1) &&
                 (((y_q >= S5_TY) && (y_q <= S5_BY)) ||
                  ((y_q >= W2_TY) && (y_q <= W2_BY)) ||
                  ((y_q >= W1_RY) && (y_q <= W1_BY)));

    wire [11:0] s5_d = x_q - 12'd354;
    wire [11:0] w1_d = x_q - 12'd343;

    integer s5_slot, s5_ch, s5_col_i, w1_slot, w1_ch, w1_col_i, w2_ch, w2_col_i;
    always @(*) begin
        s5_slot = -1; s5_ch = -1; s5_col_i = -1;
        w1_slot = -1; w1_ch = -1; w1_col_i = -1;
        w2_ch   = -1; w2_col_i = -1;
        if (in_sb) begin
            if ((y_q >= S5_TY) && (y_q <= S5_BY)) begin
                if ((x_q >= 12'd1009) && (x_q <= 12'd1019)) begin
                    s5_slot  = 7'd6;
                    s5_ch    = (x_q - 12'd1009) >> 2;
                    s5_col_i = (x_q - 12'd1009) & 12'd3;
                end
                else if (s5_d < 12'd768) begin
                    s5_slot  = s5_d[11:7];
                    s5_ch    = s5_d[6:2];
                    s5_col_i = s5_d[1:0];
                end
            end
            else if ((y_q >= W1_TY) && (y_q <= W1_BY)) begin
                if ((x_q >= 12'd1009) && (x_q <= 12'd1019)) begin
                    w1_slot  = 7'd6;
                    w1_ch    = (x_q - 12'd1009) >> 2;
                    w1_col_i = (x_q - 12'd1009) & 12'd3;
                end
                else if (w1_d < 12'd768) begin
                    w1_slot  = w1_d[11:7];
                    w1_ch    = w1_d[6:2];
                    w1_col_i = w1_d[1:0];
                end
            end
            else if ((y_q >= W2_TY) && (y_q <= W2_BY)) begin
                if ((x_q >= 12'd343) && (x_q <= 12'd513)) begin
                    w2_ch    = (x_q - 12'd343) >> 2;
                    w2_col_i = (x_q - 12'd343) & 12'd3;
                end
            end
        end
    end

    reg [8*3-1:0] s5_str;
    reg [8*3-1:0] w1_str;
    reg [8*44-1:0] w2_str;
    always @(*) begin
        case (s5_slot)
            7'd0: s5_str = "95 ";
            7'd1: s5_str = "477";
            7'd2: s5_str = "858";
            7'd3: s5_str = "2K ";
            7'd4: s5_str = "4K ";
            7'd5: s5_str = "11K";
            7'd6: s5_str = "HZ ";
            default: s5_str = "   ";
        endcase
        case (w1_slot)
            7'd0: w1_str = "0  ";
            7'd1: w1_str = "2.5";
            7'd2: w1_str = "5  ";
            7'd3: w1_str = "7.5";
            7'd4: w1_str = "10 ";
            7'd5: w1_str = "12.5";
            7'd6: w1_str = "MS ";
            default: w1_str = "   ";
        endcase
        w2_str = "24.4 KSA/S  SPAN 320  13.1 MS  TRIG AUTO    ";
    end

    wire [7:0] s5_ch_byte = (s5_ch >= 0 && s5_ch < 3) ? s5_str[8*(2-s5_ch) +: 8] : 8'h20;
    wire [7:0] w1_ch_byte = (w1_ch >= 0 && w1_ch < 3) ? w1_str[8*(2-w1_ch) +: 8] : 8'h20;
    wire [7:0] w2_ch_byte = (w2_ch >= 0 && w2_ch < 44) ? w2_str[8*(43-w2_ch) +: 8] : 8'h20;

    wire s5_rule = 1'b0;
    wire w1_rule = in_sb && (y_q == W1_RY);
    wire [14:0] g5 = mini5(s5_ch_byte);
    wire [14:0] g1 = mini5(w1_ch_byte);
    wire [14:0] g2 = mini5(w2_ch_byte);
    wire [2:0] s5_row = (y_q - S5_TY) & 12'd7;
    wire [2:0] w1_row = (y_q - W1_TY) & 12'd7;
    wire [2:0] w2_row = (y_q - W2_TY) & 12'd7;
    wire [1:0] s5_col = s5_col_i[1:0];
    wire [1:0] w1_col = w1_col_i[1:0];
    wire [1:0] w2_col = w2_col_i[1:0];
    wire [1:0] s5_coli = 2'd2 - s5_col;
    wire [1:0] w1_coli = 2'd2 - w1_col;
    wire [1:0] w2_coli = 2'd2 - w2_col;
    wire [4:0] s5_idx = {2'd0, s5_row} + ({2'd0, s5_row} << 1) + {3'd0, s5_coli};
    wire [4:0] w1_idx = {2'd0, w1_row} + ({2'd0, w1_row} << 1) + {3'd0, w1_coli};
    wire [4:0] w2_idx = {2'd0, w2_row} + ({2'd0, w2_row} << 1) + {3'd0, w2_coli};
    wire s5_ink = in_sb && (y_q >= S5_TY) && (y_q <= S5_BY) && (s5_col != 2'd3) && g5[s5_idx];
    wire w1_ink = in_sb && (y_q >= W1_TY) && (y_q <= W1_BY) && (w1_col != 2'd3) && g1[w1_idx];
    wire w2_ink = in_sb && (y_q >= W2_TY) && (y_q <= W2_BY) && (w2_col != 2'd3) && g2[w2_idx];

    wire        sband_on = in_sb && (s5_rule || w1_rule || s5_ink || w1_ink || w2_ink);
    wire [23:0] sband_rgb = (s5_rule || w1_rule) ? C_RULE5 : C_TXT5;

    always @(*) begin
        if (!de_q) begin
            rgb = 24'h000000;
        end
        else if (probe_on) begin
            rgb = probe_rgb;
        end
        else if (border) begin
            rgb = C_FRAME;
        end
        else if ((vdiv || hdiv) && !page_sel) begin
            rgb = C_DIVIDER;
        end
        else if (panel_hit) begin
            rgb = panel_rgb;
        end
        else if (sband_on) begin
            rgb = sband_rgb;
        end
        else if (in_spec && !page_sel) begin
            rgb = spec_hit ? spec_rgb : C_BG;
        end
        else if (in_wave && !page_sel) begin
            rgb = wave_hit ? wave_rgb : C_BG;
        end
        else if (in_lis && !page_sel) begin
            rgb = lm_hit ? lm_rgb :
                  (stat_hit ? stat_rgb :
                              (adsr_hit ? adsr_rgb :
                                          (lis_hit ? lis_rgb : C_BG)));
        end
        else begin
            rgb = C_BG;
        end
    end

    assign gx  = x;
    assign gy  = y;
    assign gde = de;

    wire _unused = &{1'b0, sof, 1'b0};

endmodule
