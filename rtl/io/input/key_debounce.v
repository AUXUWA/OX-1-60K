// key_debounce

`timescale 1ns/1ps

module key_debounce #(
    parameter integer DEBOUNCE_MS = 10
)(
    input  wire clk,
    input  wire rst_n,
    input  wire tick_ms,
    input  wire key_n,
    output reg  pressed,
    output reg  press_pulse
);

    localparam integer TCNT_W = (DEBOUNCE_MS <= 1) ? 1 : $clog2(DEBOUNCE_MS);

    reg [1:0] sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sync <= 2'b11;
        else        sync <= {sync[0], key_n};
    end

    wire key_raw = ~sync[1];

    reg [TCNT_W-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt         <= {TCNT_W{1'b0}};
            pressed     <= 1'b0;
            press_pulse <= 1'b0;
        end
        else begin
            press_pulse <= 1'b0;

            if (key_raw == pressed) begin
                cnt <= {TCNT_W{1'b0}};
            end
            else if (tick_ms) begin
                if (cnt == DEBOUNCE_MS-1) begin
                    cnt         <= {TCNT_W{1'b0}};
                    pressed     <= key_raw;
                    press_pulse <= key_raw;
                end
                else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

endmodule
