// char_rom —— 8×16 ASCII 点阵字库（两套字重，2 拍延迟，进 BSRAM）

`timescale 1ns/1ps

module char_rom #(
    parameter integer N_WGT   = 2,
    parameter integer SELFTEST = 0
) (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  code,
    input  wire [3:0]  row,
    input  wire        bold,
    input  wire        valid,

    output reg  [7:0]  bit_row
);

    localparam integer N_CHARS    = 96;
    localparam integer CELL_ROWS  = 16;
    localparam integer WGT_DEPTH  = N_CHARS * CELL_ROWS;
    localparam integer FONT_DEPTH = N_WGT * WGT_DEPTH;

    reg [7:0] font [0:FONT_DEPTH-1];

    initial begin
        $readmemh("font_8x16.hex", font);
    end

    wire [11:0] wgt_base = ((N_WGT > 1) && bold) ? (12'd1024 + 12'd512) : 12'd0;
    wire [11:0] base     = wgt_base
                         + (({3'b000, code} - 11'h020) << 4);
    wire [11:0] a_idx    = base + {8'b0, row};

    reg [11:0] a_idx_r;
    reg        valid_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_idx_r <= 12'd0;
            valid_r <= 1'b0;
        end
        else begin
            a_idx_r <= a_idx;
            valid_r <= valid;
        end
    end

    wire [7:0] d_raw = font[a_idx_r];

    wire [7:0] st_base =
        (row[3:2] == 2'd0) ? 8'hAA :
        (row[3:2] == 2'd1) ? 8'hCC :
        (row[3:2] == 2'd2) ? 8'hF0 : 8'h0F;
    wire [7:0] st_pat  = a_idx_r[0] ? ~st_base : st_base;
    wire [7:0] st_pat_b = bold ? ~st_pat : st_pat;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) bit_row <= 8'h00;
        else if (SELFTEST != 0) bit_row <= st_pat_b;
        else        bit_row <= (valid_r && (a_idx_r < FONT_DEPTH)) ? d_raw : 8'h00;
    end

endmodule
