// video_timing —— 视频时序生成（1024×600@60，HDMI/DVI 用）

`timescale 1ns/1ps

module video_timing #(
    parameter integer H_ACTIVE = 1024,
    parameter integer H_FP     = 24,
    parameter integer H_SYNC   = 136,
    parameter integer H_BP     = 160,
    parameter integer V_ACTIVE = 600,
    parameter integer V_FP     = 1,
    parameter integer V_SYNC   = 4,
    parameter integer V_BP     = 23
)(
    input  wire        clk,
    input  wire        rst_n,

    output reg  [11:0] x,
    output reg  [11:0] y,
    output reg         de,
    output reg         hs,
    output reg         vs,

    output reg         sof,
    output reg  [11:0] hcnt,
    output reg  [11:0] vcnt
);

    localparam integer H_TOTAL    = H_SYNC + H_BP + H_ACTIVE + H_FP;
    localparam integer V_TOTAL    = V_SYNC + V_BP + V_ACTIVE + V_FP;
    localparam integer H_DE_BEGIN = H_SYNC + H_BP;
    localparam integer H_DE_END   = H_SYNC + H_BP + H_ACTIVE;
    localparam integer V_DE_BEGIN = V_SYNC + V_BP;
    localparam integer V_DE_END   = V_SYNC + V_BP + V_ACTIVE;

    localparam [11:0] HDE_B = H_DE_BEGIN[11:0];
    localparam [11:0] HDE_E = H_DE_END[11:0];
    localparam [11:0] VDE_B = V_DE_BEGIN[11:0];
    localparam [11:0] VDE_E = V_DE_END[11:0];

    reg [11:0] hcount_r;
    reg [11:0] vcount_r;

    wire h_ov = (hcount_r >= H_TOTAL - 1);
    wire v_ov = (vcount_r >= V_TOTAL - 1);

    wire pix_de = (hcount_r >= HDE_B) && (hcount_r < HDE_E) &&
                  (vcount_r >= VDE_B) && (vcount_r < VDE_E);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hcount_r <= 12'd0;
            vcount_r <= 12'd0;
        end
        else if (h_ov) begin
            hcount_r <= 12'd0;
            if (v_ov) vcount_r <= 12'd0;
            else      vcount_r <= vcount_r + 12'd1;
        end
        else begin
            hcount_r <= hcount_r + 12'd1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x    <= 12'd0;
            y    <= 12'd0;
            de   <= 1'b0;
            hs   <= 1'b1;
            vs   <= 1'b1;
            sof  <= 1'b0;
            hcnt <= 12'd0;
            vcnt <= 12'd0;
        end
        else begin
            hcnt <= hcount_r;
            vcnt <= vcount_r;

            hs <= (hcount_r >= H_SYNC);
            vs <= (vcount_r >= V_SYNC);

            de <= pix_de;

            x <= pix_de ? (hcount_r - HDE_B) : 12'd0;
            y <= pix_de ? (vcount_r  - VDE_B) : 12'd0;

            sof <= (hcount_r == 12'd0) && (vcount_r == V_DE_END);
        end
    end

endmodule
