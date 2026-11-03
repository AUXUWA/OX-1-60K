// patch_wr_cdc

`timescale 1ns/1ps

module patch_wr_cdc #(
    parameter integer SETTLE = 3
)(
    input  wire        src_clk,
    input  wire        src_rst_n,
    input  wire        src_pulse,
    input  wire [1:0]  src_kind,
    input  wire [4:0]  src_a,
    input  wire [4:0]  src_b,
    input  wire [15:0] src_word,

    input  wire        dst_clk,
    input  wire        dst_rst_n,
    output reg  [1:0]  dst_kind,
    output reg  [4:0]  dst_a,
    output reg  [4:0]  dst_b,
    output reg  [15:0] dst_word,
    output reg         dst_pulse
);

    reg [1:0]  s_kind;
    reg [4:0]  s_a;
    reg [4:0]  s_b;
    reg [15:0] s_word;
    reg        req_tgl;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            s_kind  <= 2'd0;
            s_a     <= 5'd0;
            s_b     <= 5'd0;
            s_word  <= 16'd0;
            req_tgl <= 1'b0;
        end
        else if (src_pulse) begin
            s_kind  <= src_kind;
            s_a     <= src_a;
            s_b     <= src_b;
            s_word  <= src_word;
            req_tgl <= ~req_tgl;
        end
    end

    reg [2:0] tgl_sync;

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            tgl_sync <= 3'b000;
        end
        else begin
            tgl_sync <= {tgl_sync[1:0], req_tgl};
        end
    end

    wire dst_new = tgl_sync[2] ^ tgl_sync[1];

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            dst_kind  <= 2'd0;
            dst_a     <= 5'd0;
            dst_b     <= 5'd0;
            dst_word  <= 16'd0;
            dst_pulse <= 1'b0;
        end
        else begin
            dst_pulse <= 1'b0;
            if (dst_new) begin
                dst_kind  <= s_kind;
                dst_a     <= s_a;
                dst_b     <= s_b;
                dst_word  <= s_word;
                dst_pulse <= 1'b1;
            end
        end
    end

`ifdef SIMULATION
    initial begin
        if (SETTLE < 3) begin
            $display("[patch_wr_cdc] *** ERROR: SETTLE 必须 >= 3（载荷稳定拍数），实得 %0d ***", SETTLE);
            $finish;
        end
    end
`endif

endmodule
