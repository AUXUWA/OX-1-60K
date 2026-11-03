// led_driver

`timescale 1ns/1ps

module led_driver #(
    parameter integer CLK_HZ        = 50_000_000,
    parameter integer LED_W         = 4,
    parameter integer HEART_MS      = 250,
    parameter integer BLINK_MS      = 125,
    parameter [0:0]   ACTIVE_LOW    = 1'b0
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             led_mode,
    input  wire [LED_W-2:0] status,
    output wire [LED_W-1:0] led
);

    localparam integer HEART_DIV = (CLK_HZ / 1000) * HEART_MS;
    localparam integer BLINK_DIV = (CLK_HZ / 1000) * BLINK_MS;
    localparam integer CNT_W     = 24;

    reg [CNT_W-1:0] div_cnt;
    reg             blink;

    wire [CNT_W-1:0] div_target = led_mode ? BLINK_DIV[CNT_W-1:0]
                                           : HEART_DIV[CNT_W-1:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= {CNT_W{1'b0}};
            blink   <= 1'b0;
        end
        else if (div_cnt >= (div_target - 1'b1)) begin
            div_cnt <= {CNT_W{1'b0}};
            blink   <= ~blink;
        end
        else begin
            div_cnt <= div_cnt + 1'b1;
        end
    end

    wire [LED_W-1:0] led_hi = {status, blink};

    assign led = ACTIVE_LOW ? ~led_hi : led_hi;

endmodule
