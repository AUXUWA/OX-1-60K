// stat_panel —— 李萨如图区里的静态铭牌 —— 12 列 × 11 行的 8×16 ASCII 字符板

`timescale 1ns/1ps

module stat_panel #(
    parameter integer X0 = 336,
    parameter integer Y0 = 400,
    parameter integer X1 = 1024,
    parameter integer Y1 = 600,

    parameter integer SX0 = 717,
    parameter integer SY0 = 404,
    parameter integer SW  = 103,
    parameter integer SH  = 192,

    parameter integer TX0 = 720,
    parameter integer TY0 = 412,
    parameter integer NCOLS = 12,
    parameter integer NROWS = 11,

    parameter integer FRAME  = 1,
    parameter integer OUT_LAT = 4,

    parameter integer PIXCLK_MHZ = 48,

    parameter integer FS_HZ    = 48828,
    parameter integer N_VOICE  = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sof,

    input  wire [11:0] gx,
    input  wire [11:0] gy,
    input  wire        gde,

    input  wire [23:0] p_tl,
    input  wire [1:0]  focus_op,

    output wire [23:0] rgb,
    output wire        hit
);

    localparam [15:0] PIXCLK_STR =
        (PIXCLK_MHZ == 48) ? "48" :
        (PIXCLK_MHZ == 51) ? "51" :
        (PIXCLK_MHZ == 50) ? "50" :
        (PIXCLK_MHZ == 49) ? "49" : "??";
    localparam [7:0] PIXCLK_CH0 = PIXCLK_STR[15:8];
    localparam [7:0] PIXCLK_CH1 = PIXCLK_STR[7:0];

    localparam [31:0] RATE_STR =
        (FS_HZ == 48828) ? "48.8" :
        (FS_HZ == 44100) ? "44.1" :
        (FS_HZ == 32000) ? "32.0" :
        (FS_HZ == 24414) ? "24.4" : "??.?";
    localparam [7:0] RATE_CH0 = RATE_STR[31:24];
    localparam [7:0] RATE_CH1 = RATE_STR[23:16];
    localparam [7:0] RATE_CH2 = RATE_STR[15:8];
    localparam [7:0] RATE_CH3 = RATE_STR[7:0];

    localparam [31:0] VOX_STR =
        (N_VOICE == 240) ? " 240" :
        (N_VOICE == 252) ? " 252" :
        (N_VOICE == 128) ? " 128" :
        (N_VOICE ==  64) ? "  64" :
        (N_VOICE ==  32) ? "  32" :
        (N_VOICE ==  16) ? "  16" : " ???";
    localparam [7:0] VOX_CH0 = VOX_STR[31:24];
    localparam [7:0] VOX_CH1 = VOX_STR[23:16];
    localparam [7:0] VOX_CH2 = VOX_STR[15:8];
    localparam [7:0] VOX_CH3 = VOX_STR[7:0];

    localparam [31:0] OSC_STR =
        (N_VOICE == 240) ? " 960" :
        (N_VOICE == 252) ? "1008" :
        (N_VOICE == 128) ? " 512" :
        (N_VOICE ==  64) ? " 256" :
        (N_VOICE ==  32) ? " 128" :
        (N_VOICE ==  16) ? "  64" : "????";
    localparam [7:0] OSC_CH0 = OSC_STR[31:24];
    localparam [7:0] OSC_CH1 = OSC_STR[23:16];
    localparam [7:0] OSC_CH2 = OSC_STR[15:8];
    localparam [7:0] OSC_CH3 = OSC_STR[7:0];

    localparam [11:0] SX0_C  = SX0[11:0];
    localparam [11:0] SY0_C  = SY0[11:0];
    localparam [11:0] SW_C   = SW[11:0];
    localparam [11:0] SH_C   = SH[11:0];
    localparam [11:0] FR_C   = FRAME[11:0];

    localparam [11:0] BOX_X0_C = SX0_C;
    localparam [11:0] BOX_X1_C = SX0_C + SW_C - 12'd1;
    localparam [11:0] BOX_Y0_C = SY0_C;
    localparam [11:0] BOX_Y1_C = SY0_C + SH_C - 12'd1;

    localparam [11:0] IN_X0_C  = BOX_X0_C + FR_C;
    localparam [11:0] IN_X1_C  = BOX_X1_C - FR_C;
    localparam [11:0] IN_Y0_C  = BOX_Y0_C + FR_C;
    localparam [11:0] IN_Y1_C  = BOX_Y1_C - FR_C;

    localparam [11:0] TX0_C    = TX0[11:0];
    localparam [11:0] TY0_C    = TY0[11:0];
    localparam [11:0] TEXT_W_C = NCOLS[11:0] << 3;
    localparam [11:0] TEXT_H_C = NROWS[11:0] << 4;

    localparam [23:0] C_FRM   = 24'h2A3A4A;
    localparam [23:0] C_BODY  = 24'h0D1117;
    localparam [23:0] C_SECT  = 24'h38D2E8;
    localparam [23:0] C_TEXT  = 24'hC8D8E8;
    localparam [23:0] C_LABEL = 24'h7FA8C8;
    localparam [23:0] C_VALUE = 24'hEAF2FA;
    localparam [23:0] C_BG    = 24'h080A0C;

    reg [5:0] tl_byte;
    always @(*) begin
        case (focus_op)
            2'd0   : tl_byte = p_tl[5:0];
            2'd1   : tl_byte = p_tl[11:6];
            2'd2   : tl_byte = p_tl[17:12];
            default: tl_byte = p_tl[23:18];
        endcase
    end
    wire [1:0] tlh = tl_byte[5:4];

    function [7:0] hex_digit;
        input [1:0] v;
        begin
            case (v)
                4'd0: hex_digit = 8'h30;
                4'd1: hex_digit = 8'h31;
                4'd2: hex_digit = 8'h32;
                default: hex_digit = 8'h33;
            endcase
        end
    endfunction

    function [7:0] char_at;
        input [3:0] r;
        input [3:0] c;
        begin
            case ({r, c})

                8'h00: char_at = "S";   8'h01: char_at = "Y";
                8'h02: char_at = "S";   8'h03: char_at = "T";
                8'h04: char_at = "E";   8'h05: char_at = "M";

                8'h20: char_at = "P";   8'h21: char_at = "I";
                8'h22: char_at = "X";   8'h23: char_at = "C";
                8'h24: char_at = "L";   8'h25: char_at = "K";
                8'h27: char_at = PIXCLK_CH0;   8'h28: char_at = PIXCLK_CH1;
                8'h29: char_at = "M";

                8'h40: char_at = "R";   8'h41: char_at = "A";
                8'h42: char_at = "T";   8'h43: char_at = "E";
                8'h46: char_at = RATE_CH0;   8'h47: char_at = RATE_CH1;
                8'h48: char_at = RATE_CH2;   8'h49: char_at = RATE_CH3;
                8'h4A: char_at = "k";

                8'h60: char_at = "B";   8'h61: char_at = "U";
                8'h62: char_at = "F";
                8'h67: char_at = "1";   8'h68: char_at = "0";
                8'h69: char_at = "2";   8'h6A: char_at = "4";

                8'h80: char_at = "V";   8'h81: char_at = "O";
                8'h82: char_at = "I";   8'h83: char_at = "C";
                8'h84: char_at = "E";   8'h85: char_at = "S";
                8'h87: char_at = VOX_CH0;   8'h88: char_at = VOX_CH1;
                8'h89: char_at = VOX_CH2;   8'h8A: char_at = VOX_CH3;

                8'h90: char_at = "O";   8'h91: char_at = "S";
                8'h92: char_at = "C";
                8'h97: char_at = OSC_CH0;   8'h98: char_at = OSC_CH1;
                8'h99: char_at = OSC_CH2;   8'h9A: char_at = OSC_CH3;

                8'hA0: char_at = "T";   8'hA1: char_at = "L";
                8'hA2: char_at = "H";   8'hA3: char_at = "(";
                8'hA4: char_at = "f";   8'hA5: char_at = ")";
                8'hAA: char_at = hex_digit(tlh);

                default: char_at = 8'h20;
            endcase
        end
    endfunction

    wire [11:0] tc_c_a = (gx - TX0_C) >> 3;
    wire [11:0] tc_r_a = (gy - TY0_C) >> 4;
    wire [3:0]  tc_ri  = (gy - TY0_C) & 12'd15;
    wire        in_ta   = (gx >= TX0_C) && (gx < (TX0_C + TEXT_W_C)) &&
                          (gy >= TY0_C) && (gy < (TY0_C + TEXT_H_C));

    wire [7:0] rom_code = char_at(tc_r_a[3:0], tc_c_a[3:0]);
    wire       rom_valid = in_ta;

    wire [7:0] bit_row;

    char_rom #(
        .N_WGT (1)
    ) u_font (
        .clk   (clk),
        .rst_n (rst_n),
        .code  (rom_code),
        .row   (tc_ri),
        .bold  (1'b0),
        .valid (rom_valid),
        .bit_row(bit_row)
    );

    reg [11:0] x_q1 = 12'd0, y_q1 = 12'd0;
    reg [11:0] x_q2 = 12'd0, y_q2 = 12'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_q1 <= 12'd0;  y_q1 <= 12'd0;
            x_q2 <= 12'd0;  y_q2 <= 12'd0;
        end
        else begin
            x_q1 <= gx;  y_q1 <= gy;
            x_q2 <= x_q1; y_q2 <= y_q1;
        end
    end

    wire [11:0] tc_c = (x_q2 - TX0_C) >> 3;
    wire [11:0] tc_r = (y_q2 - TY0_C) >> 4;
    wire [2:0]  tc_ci = (x_q2 - TX0_C) & 12'd7;

    wire in_text = (x_q2 >= TX0_C) && (x_q2 < (TX0_C + TEXT_W_C)) &&
                   (y_q2 >= TY0_C) && (y_q2 < (TY0_C + TEXT_H_C));

    wire       txt_ink = in_text && bit_row[{3'b000, tc_ci} ^ 3'd7];

    reg [23:0] fg_col;
    always @(*) begin
        if      (tc_r == 12'd0)  fg_col = C_SECT;
        else if (tc_r == 12'd10) begin
            if (tc_c == 12'd11)   fg_col = C_VALUE;
            else                  fg_col = C_LABEL;
        end
        else                     fg_col = C_TEXT;
    end

    wire in_box   = (x_q2 >= BOX_X0_C) && (x_q2 <= BOX_X1_C) &&
                    (y_q2 >= BOX_Y0_C) && (y_q2 <= BOX_Y1_C);
    wire in_inner = (x_q2 >= IN_X0_C)  && (x_q2 <= IN_X1_C)  &&
                    (y_q2 >= IN_Y0_C)  && (y_q2 <= IN_Y1_C);
    wire in_frm   = in_box && !in_inner;

    reg [23:0] rgb_c;
    reg        hit_c;

    always @(*) begin
        if (!gde || !in_box) begin
            rgb_c = C_BG;
            hit_c = 1'b0;
        end
        else begin
            hit_c = 1'b1;
            if      (in_frm)   rgb_c = C_FRM;
            else if (txt_ink) rgb_c = fg_col;
            else              rgb_c = C_BODY;
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

    wire _unused = &{1'b0, sof, 1'b0, NROWS[11:8], 1'b0, NCOLS[11:8],
                     1'b0, IN_X1_C[11:8], 1'b0, IN_Y1_C[11:8],
                     1'b0, X0[11:8], 1'b0, Y0[11:8],
                     1'b0, X1[11:8], 1'b0, Y1[11:8]};

endmodule
