// saturate —— 累加域 -> 定标右移 -> 软拐点 -> 硬钳到 ±32767 / −32768（绝不回绕）

`timescale 1ns/1ps

module saturate #(
    parameter integer W_IN    = 24,
    parameter integer SHIFT   = 3,
    parameter integer KNEE_TH = 32768
)(
    input  wire signed [W_IN-1:0] din,
    output wire signed [15:0]     dout,
    output wire                   dbg_soft,
    output wire                   dbg_clip
);

    localparam integer S_W = ((W_IN - SHIFT) < 1) ? 1 : (W_IN - SHIFT);

`ifdef SIMULATION
    initial begin
        if (W_IN < 17)
            $display("*** ERROR saturate: W_IN(%0d) < 17（入口装不下 16bit PCM + 定标余量）", W_IN);
        if (SHIFT < 0)
            $display("*** ERROR saturate: SHIFT(%0d) < 0", SHIFT);
        if ((W_IN - SHIFT) < 16)
            $display("*** ERROR saturate: W_IN(%0d)-SHIFT(%0d) = %0d < 16（定标后位宽不够 16bit）",
                     W_IN, SHIFT, W_IN - SHIFT);
    end
`endif

    wire signed [W_IN-1:0] sh = din >>> SHIFT;

    wire signed [W_IN:0] sh_ext = {sh[W_IN-1], sh};
    wire        [W_IN:0] mag     = sh_ext[W_IN] ? (~sh_ext + 1'b1) : sh_ext;

    localparam [W_IN:0] KNEE_V = KNEE_TH;

    wire               knee_en = (KNEE_TH > 0) && (mag > KNEE_V);
    wire        [W_IN:0] mag_knee = knee_en
                                 ? (KNEE_V + ((mag - KNEE_V) >> 1))
                                 : mag;

    wire [W_IN:0] rail_m = (mag_knee > 32768) ? 32768 : mag_knee;
    wire signed [16:0] mag_s = {1'b0, rail_m[15:0]};

    wire signed [16:0] s17   = sh_ext[W_IN] ? (-mag_s) : mag_s;
    wire signed [16:0] s17c  = (s17 > 17'sd32767) ? 17'sd32767 : s17;

    assign dout     = s17c[15:0];
    assign dbg_soft = knee_en;
    assign dbg_clip = (mag_knee > 32767);

endmodule
