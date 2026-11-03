// audio_mixer —— N 声部累加（保护位口径）→ 定标 → 软限幅 → 总线 PCM（送 effects）

`timescale 1ns/1ps

module audio_mixer #(
    parameter integer N_VOICE = 16,
    parameter integer VOICE_W = 16,
    parameter integer IN_W = VOICE_W,
    parameter integer GUARD   = 3,
    parameter integer SHIFT   = 3,
    parameter integer KNEE_TH = 32768,
    parameter integer ACC_W   = IN_W + GUARD
                              + ((N_VOICE <= 1) ? 0 : $clog2(N_VOICE))
                              + 1
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                sample_tick,
    input  wire                slot_go,
    input  wire                slot_last,

    input  wire signed [IN_W-1:0] in_l,
    input  wire signed [IN_W-1:0] in_r,

    output wire signed [15:0]  out_l,
    output wire signed [15:0]  out_r,

    output wire signed [ACC_W-1:0] acc_l,
    output wire signed [ACC_W-1:0] acc_r,
    output wire                  soft_l,
    output wire                  clip_l
);

    localparam integer V_W  = IN_W + GUARD;
    localparam integer N_AW = (N_VOICE <= 1) ? 0 : $clog2(N_VOICE);

`ifdef SIMULATION
    initial begin
        if (N_VOICE < 1)
            $display("*** ERROR audio_mixer: N_VOICE(%0d) < 1", N_VOICE);
        if (GUARD < 0)
            $display("*** ERROR audio_mixer: GUARD(%0d) < 0", GUARD);
        if (ACC_W < (IN_W + GUARD + N_AW))
            $display("*** ERROR audio_mixer: ACC_W(%0d) < IN_W+GUARD+clog2(N_VOICE)(%0d) —— 会回绕",
                     ACC_W, IN_W + GUARD + N_AW);
        if (GUARD != SHIFT)
            $display("*** WARN  audio_mixer: GUARD(%0d) != SHIFT(%0d) —— 「单声部恒等」不成立",
                     GUARD, SHIFT);
    end
`endif

    wire signed [V_W-1:0] ext_l = {{(V_W-IN_W){in_l[IN_W-1]}}, in_l};

    wire signed [V_W-1:0] vo_l = ext_l <<< GUARD;

    reg signed [ACC_W-1:0] acc_l_r;

    wire signed [ACC_W-1:0] acc_l_n = acc_l_r + {{(ACC_W-V_W){vo_l[V_W-1]}}, vo_l};
    wire signed [ACC_W-1:0] acc_r_n = acc_l_n;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_l_r <= {ACC_W{1'b0}};
        end
        else if (sample_tick) begin
            acc_l_r <= {ACC_W{1'b0}};
        end
        else if (slot_go) begin
            acc_l_r <= acc_l_n;
        end
    end

    wire signed [15:0] sat_l;
    wire               soft_flag;

    saturate #(
        .W_IN    (ACC_W),
        .SHIFT   (SHIFT),
        .KNEE_TH (KNEE_TH)
    ) u_saturate_l (
        .din      (acc_l_n),
        .dout     (sat_l),
        .dbg_soft (soft_flag),
        .dbg_clip (clip_l)
    );


    reg signed [15:0] out_l_r;
    reg signed [15:0] out_r_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_l_r <= 16'sd0;
            out_r_r <= 16'sd0;
        end
        else if (slot_last) begin
            out_l_r <= sat_l;
            out_r_r <= sat_l;
        end
    end

    assign out_l  = out_l_r;
    assign out_r  = out_r_r;
    assign acc_l  = acc_l_n;
    assign acc_r  = acc_r_n;
    assign soft_l = soft_flag;

endmodule
