// op_scale —— 载波求和 → 右移定标 + 饱和 → 16bit PCM（送 i2s_tx / 混音器）

module op_scale #(parameter integer SHIFT = 0) (
    input  wire signed [15:0] mix_in,
    output wire signed [15:0] pcm_out
);

    wire signed [15:0] scaled = mix_in >>> SHIFT;

    assign pcm_out = (scaled >  16'sd32767) ?  16'sd32767 :
                     (scaled < -16'sd32767) ? -16'sd32767 : scaled;

endmodule
