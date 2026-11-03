// seq_play

`timescale 1ns/1ps

module seq_play #(
    parameter integer CLK_HZ   = 12_500_000,
    parameter integer GATE_MS  = 120
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_pulse,
    input  wire        step_on,
    input  wire [4:0]  step_pitch,
    input  wire        play_en,
    output reg  [24:0] key_hold,
    output reg  [4:0]  cur_step
);

    localparam integer KEY_W = 25;

    localparam [4:0]   NOTE_TOP = 5'd24;

    localparam [KEY_W-1:0] KEY_ONE  = {{(KEY_W-1){1'b0}}, 1'b1};
    localparam [KEY_W-1:0] KEY_ZERO = {KEY_W{1'b0}};

    localparam integer CLK_KHZ = (CLK_HZ < 1000) ? 1 : (CLK_HZ / 1000);

    localparam integer GATE_CYC = (CLK_KHZ * GATE_MS < 1) ? 1 : (CLK_KHZ * GATE_MS);

    localparam integer GATE_W =
        (GATE_CYC <= (1 <<  4)) ?  5 :
        (GATE_CYC <= (1 <<  8)) ?  9 :
        (GATE_CYC <= (1 << 12)) ? 13 :
        (GATE_CYC <= (1 << 16)) ? 17 :
        (GATE_CYC <= (1 << 20)) ? 21 :
        (GATE_CYC <= (1 << 24)) ? 25 : 32;

    localparam [GATE_W-1:0] GATE_INIT = (GATE_CYC - 1);

    reg [GATE_W-1:0] gate_cnt;
    reg              pend;
    reg [4:0]        pend_pitch;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_hold   <= KEY_ZERO;
            cur_step   <= 4'd0;
            gate_cnt   <= {GATE_W{1'b0}};
            pend       <= 1'b0;
            pend_pitch <= 5'd0;
        end
        else if (!play_en) begin
            key_hold <= KEY_ZERO;
            gate_cnt <= {GATE_W{1'b0}};
            pend     <= 1'b0;
        end
        else if (tick_pulse) begin
            if (step_on && (step_pitch <= NOTE_TOP)) begin
                if (key_hold[step_pitch] || (pend && (pend_pitch == step_pitch))) begin
                    key_hold   <= KEY_ZERO;
                    pend       <= 1'b1;
                    pend_pitch <= step_pitch;
                    gate_cnt   <= {GATE_W{1'b0}};
                end
                else begin
                    key_hold <= KEY_ONE << step_pitch;
                    cur_step <= step_pitch;
                    gate_cnt <= GATE_INIT;
                    pend     <= 1'b0;
                end
            end
            else begin
                key_hold <= KEY_ZERO;
                gate_cnt <= {GATE_W{1'b0}};
                pend     <= 1'b0;
            end
        end
        else if (pend) begin
            key_hold   <= KEY_ONE << pend_pitch;
            cur_step   <= pend_pitch;
            gate_cnt   <= GATE_INIT;
            pend       <= 1'b0;
        end
        else if (|key_hold) begin
            if (gate_cnt == {GATE_W{1'b0}}) key_hold <= KEY_ZERO;
            else                            gate_cnt <= gate_cnt - 1'b1;
        end
    end

endmodule
