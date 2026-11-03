// i2s_tx

`timescale 1ns/1ps

module i2s_tx #(
    parameter integer WS_DELAY_BITS = 0,
    parameter integer LEFT_ON_WS_LOW = 0
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire signed [15:0] l_data,
    input  wire signed [15:0] r_data,
    output reg                bclk,
    output reg                lrclk,
    output reg                dacdat,
    output reg                sample_tick
);

    reg [2:0]  div;
    reg [4:0]  bit_cnt;
    reg [15:0] sr_l;
    reg [15:0] sr_r;

    wire [4:0] next_cnt  = bit_cnt + 5'd1;
    wire       bclk_fall = (div == 3'd0);

    wire [4:0] slot = next_cnt;

    localparam [5:0] LD_BEG = 6'd0  + WS_DELAY_BITS;
    localparam [5:0] LD_END = 6'd16 + WS_DELAY_BITS;
    localparam [5:0] RD_BEG = 6'd16 + WS_DELAY_BITS;
    localparam [5:0] RD_END = 6'd32 + WS_DELAY_BITS;

    wire [5:0] slot6     = {1'b0, slot};
    wire       in_left  = (slot6 >= LD_BEG) && (slot6 < LD_END);
    wire       in_right = (slot6 >= RD_BEG) && (slot6 < RD_END);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div         <= 3'd0;
            bclk        <= 1'b0;
            lrclk       <= 1'b0;
            dacdat      <= 1'b0;
            sample_tick <= 1'b0;
            bit_cnt     <= 5'd0;
            sr_l        <= 16'd0;
            sr_r        <= 16'd0;
        end
        else begin
            div  <= div + 3'd1;
            bclk <= div[2];

            if (bclk_fall) begin
                bit_cnt <= slot;

                lrclk <= LEFT_ON_WS_LOW ? slot[4] : ~slot[4];

                sample_tick <= (slot == 5'd0);

                if (in_left) begin
                    dacdat <= sr_l[15];
                    sr_l   <= {sr_l[14:0], 1'b0};
                end
                else if (in_right) begin
                    dacdat <= sr_r[15];
                    sr_r   <= {sr_r[14:0], 1'b0};
                    if (slot == 5'd31) begin
                        sr_l <= l_data;
                        sr_r <= r_data;
                    end
                end
                else begin
                    dacdat <= 1'b0;
                end
            end
            else begin
                sample_tick <= 1'b0;
            end
        end
    end

endmodule
