// op_router —— 调制路由 —— 掩码调制求和 + 自反馈（FB），纯组合

module op_router (
    input  wire [1:0]         slot_idx,
    input  wire [2:0]         fb,
    input  wire [3:0]         mod_mask,
    input  wire signed [15:0] out0,
    input  wire signed [15:0] out1,
    input  wire signed [15:0] out2,
    input  wire signed [15:0] out3,
    input  wire signed [15:0] prout,
    output wire signed [15:0] mod_out,
    output wire signed [15:0] fbmod
);

    wire signed [15:0] out_i = (slot_idx == 2'd0) ? out0 :
                               (slot_idx == 2'd1) ? out1 :
                               (slot_idx == 2'd2) ? out2 : out3;

    wire [3:0] self_bit = (slot_idx == 2'd0) ? 4'b0001 :
                          (slot_idx == 2'd1) ? 4'b0010 :
                          (slot_idx == 2'd2) ? 4'b0100 : 4'b1000;

    wire signed [31:0] fb_sum     = prout + out_i;
    wire signed [31:0] fb_shifted = fb_sum >>> (9 - fb);
    assign fbmod = (fb == 3'd0) ? 16'sd0 : fb_shifted[15:0];

    wire [3:0]  src_mask = mod_mask & ~self_bit;

    wire [15:0] s0 = src_mask[0] ? out0 : 16'h0000;
    wire [15:0] s1 = src_mask[1] ? out1 : 16'h0000;
    wire [15:0] s2 = src_mask[2] ? out2 : 16'h0000;
    wire [15:0] s3 = src_mask[3] ? out3 : 16'h0000;

    wire [15:0] mod_sum = s0 + s1 + s2 + s3;

    wire [15:0] fb_term = mod_mask[slot_idx] ? fbmod : 16'sd0;

    assign mod_out = mod_sum + fb_term;

endmodule
