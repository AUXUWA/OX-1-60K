// text_buf —— 屏幕字符缓冲 + 字模取行（参数面板的"显存"）

`timescale 1ns/1ps

module text_buf #(
    parameter integer PANEL_COLS = 42,
    parameter integer PANEL_ROWS = 30,
    parameter integer OUT_LAT    = 4,
    parameter [23:0]  FG_COLOR   = 24'hC8D8E8,
    parameter [23:0]  BG_COLOR   = 24'h101418,
    parameter integer COLW       = (PANEL_COLS <= 64) ? 6 : 7
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        we,
    input  wire [COLW-1:0] w_col,
    input  wire [5:0]  w_row,
    input  wire [7:0]  w_ch,
    input  wire [3:0]  w_color,
    input  wire        w_bold,

    input  wire        de,
    input  wire [11:0] x,
    input  wire [11:0] y,
    output wire [23:0] rgb,
    output wire        hit
);

    localparam integer PANEL_W = PANEL_COLS * 8;
    localparam integer PANEL_H = PANEL_ROWS * 16;

    localparam [11:0] PW_C = PANEL_W[11:0];
    localparam [11:0] PH_C = PANEL_H[11:0];
    localparam [11:0] NC_C = PANEL_COLS[11:0];

    localparam integer NCELL = PANEL_COLS * PANEL_ROWS;

    localparam integer ADDR_W = (NCELL <= 2048) ? 11 : 13;

    reg [7:0] cb [0:NCELL-1];

    reg [3:0] cpal [0:NCELL-1];
    reg       cbold[0:NCELL-1];


    wire [ADDR_W-1:0] w_row_e = {{(ADDR_W-6){1'b0}}, w_row};
    wire [ADDR_W-1:0] w_col_e = {{(ADDR_W-COLW){1'b0}}, w_col};

    wire [ADDR_W-1:0] cb_waddr;
    generate
        if (PANEL_COLS == 128) begin : g_addr_pow2
            assign cb_waddr = {w_row_e[5:0], w_col_e[6:0]};
        end else begin : g_addr_mul
            assign cb_waddr = (w_row_e << 5)
                            + (w_row_e << 3)
                            + (w_row_e << 1)
                            + w_col_e;
        end
    endgenerate

    always @(posedge clk) begin
        if (we) begin
            cb[cb_waddr[ADDR_W-1:0]]    <= w_ch;
            cpal[cb_waddr[ADDR_W-1:0]]  <= w_color;
            cbold[cb_waddr[ADDR_W-1:0]] <= w_bold;
        end
    end

    wire in_panel = de && (x < PW_C) && (y < PH_C);

    wire [COLW-1:0] c_col;
    generate
        if (PANEL_COLS <= 64) begin : g_col6
            assign c_col = x[8:3];
        end else begin : g_colN
            assign c_col = x[9:3];
        end
    endgenerate
    wire [5:0] c_row = y[9:4];
    wire [2:0] sub_c = x[2:0];
    wire [3:0] sub_r = y[3:0];

    wire [ADDR_W-1:0] c_row_e = {{(ADDR_W-6){1'b0}}, c_row};
    wire [ADDR_W-1:0] c_col_e = {{(ADDR_W-COLW){1'b0}}, c_col};

    wire [ADDR_W-1:0] cb_addr;
    generate
        if (PANEL_COLS == 128) begin : g_raddr_pow2
            assign cb_addr = {c_row_e[5:0], c_col_e[6:0]};
        end else begin : g_raddr_mul
            assign cb_addr = (c_row_e << 5)
                           + (c_row_e << 3)
                           + (c_row_e << 1)
                           + c_col_e;
        end
    endgenerate
    wire [ADDR_W-1:0] cb_addr_s = in_panel ? cb_addr : {ADDR_W{1'b0}};

    reg [ADDR_W-1:0] cb_addr_r;
    reg [3:0]  row_r1;
    reg        ok_r1;

    reg [7:0]  cur_ch;
    reg [3:0]  row_r2;
    reg        ok_r2;

    reg [3:0]  cur_col;
    reg        cur_bold;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cb_addr_r <= {ADDR_W{1'b0}};
            row_r1    <= 4'd0;
            ok_r1     <= 1'b0;
            cur_ch    <= 8'h20;
            row_r2    <= 4'd0;
            ok_r2     <= 1'b0;
            cur_col   <= 4'd0;
            cur_bold  <= 1'b0;
        end
        else begin
            cb_addr_r <= cb_addr_s;
            row_r1    <= sub_r;
            ok_r1     <= in_panel;
            cur_ch    <= cb[cb_addr_r];
            cur_col   <= cpal[cb_addr_r];
            cur_bold  <= cbold[cb_addr_r];
            row_r2    <= row_r1;
            ok_r2     <= ok_r1;
        end
    end

    wire [7:0] rom_bit;

    char_rom u_char_rom (
        .clk     (clk),
        .rst_n   (rst_n),
        .code    (cur_ch),
        .row     (row_r2),
        .bold    (cur_bold),
        .valid   (ok_r2),
        .bit_row (rom_bit)
    );

    reg [2:0] sub_c_r1, sub_c_r2, sub_c_r3, sub_c_r4;
    reg       in_p_r1,  in_p_r2,  in_p_r3,  in_p_r4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sub_c_r1 <= 3'd0; sub_c_r2 <= 3'd0; sub_c_r3 <= 3'd0; sub_c_r4 <= 3'd0;
            in_p_r1  <= 1'b0; in_p_r2  <= 1'b0; in_p_r3  <= 1'b0; in_p_r4  <= 1'b0;
        end
        else begin
            sub_c_r1 <= sub_c; sub_c_r2 <= sub_c_r1;
            sub_c_r3 <= sub_c_r2; sub_c_r4 <= sub_c_r3;
            in_p_r1  <= in_panel; in_p_r2  <= in_p_r1;
            in_p_r3  <= in_p_r2;  in_p_r4  <= in_p_r3;
        end
    end

    wire pix_on = rom_bit[3'd7 - sub_c_r4];

    localparam [3:0] CIDX_DEFAULT  = 4'd0,
                     CIDX_TITLE    = 4'd1,
                     CIDX_LABEL    = 4'd2,
                     CIDX_VALUE    = 4'd3,
                     CIDX_KEYON    = 4'd4,
                     CIDX_KEYIDLE  = 4'd5,
                     CIDX_OK       = 4'd6,
                     CIDX_WARN     = 4'd7,
                     CIDX_ERR      = 4'd8,
                     CIDX_SECTION  = 4'd9,
                     CIDX_ACCENT   = 4'd10,
                     CIDX_FOCUS    = 4'd11,
                     CIDX_FOCUS_COL= 4'd12,
                     CIDX_FOCUS_ROW= 4'd13,
                     CIDX_OP_OFF   = 4'd14,
                     CIDX_KEYFN    = 4'd15;

    function [47:0] palette_pair;
        input [3:0] ci;
        reg [23:0] f;
        reg [23:0] b;
        begin
            f = FG_COLOR;
            b = BG_COLOR;
            case (ci)
                CIDX_TITLE  : f = 24'hFFD24A;
                CIDX_LABEL  : f = 24'h7FA8C8;
                CIDX_VALUE  : f = 24'hEAF2FA;
                CIDX_KEYON  : f = 24'h2BFF6A;
                CIDX_KEYIDLE: f = 24'hEAF2FA;
                CIDX_OK     : f = 24'h2BE07A;
                CIDX_WARN   : f = 24'hFFB03A;
                CIDX_ERR    : f = 24'hFF5A4A;
                CIDX_SECTION: f = 24'h38D2E8;
                CIDX_ACCENT : f = 24'hE070FF;

                CIDX_FOCUS    : begin f = BG_COLOR; b = 24'hFFD24A; end
                CIDX_FOCUS_COL: begin f = 24'hDCE8F5; b = 24'h1E3A55; end
                CIDX_FOCUS_ROW: begin f = 24'hEAF2FA; b = 24'h121A22; end
                CIDX_OP_OFF   : begin f = 24'h74879C; b = BG_COLOR;    end
                CIDX_KEYFN    : begin f = 24'hFFB03A; b = BG_COLOR;    end

                CIDX_DEFAULT: f = FG_COLOR;
                default     : begin f = FG_COLOR; b = BG_COLOR; end
            endcase
            palette_pair = {b, f};
        end
    endfunction

    reg [3:0] cur_col_r3, cur_col_r4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_col_r3 <= CIDX_DEFAULT;
            cur_col_r4 <= CIDX_DEFAULT;
        end
        else begin
            cur_col_r3 <= cur_col;
            cur_col_r4 <= cur_col_r3;
        end
    end

    wire [47:0] pal = palette_pair(cur_col_r4);

    assign hit = in_p_r4;
    assign rgb = in_p_r4 ? (pix_on ? pal[23:0] : pal[47:24]) : BG_COLOR;

endmodule
