// hdmi_tx_top —— HDMI/DVI 发送物理层（TMDS 编码 + 10:1 串行化 + 差分输出）

`timescale 1ns/1ps

module hdmi_tx_top #(
    parameter integer USE_NEG_ODDR = 0,
    parameter integer USE_OSER10   = 1
)(
    input  wire        pix_clk,
    input  wire        ser_clk,
    input  wire        rst_n,

    input  wire        vde,
    input  wire        hs,
    input  wire        vs,
    input  wire [23:0] rgb,

    output wire [2:0]  tmds_data_p,
    output wire [2:0]  tmds_data_n,
    output wire        tmds_clk_p,
    output wire        tmds_clk_n
);

    reg [1:0] ser_rst_sync;

    always @(posedge ser_clk or negedge rst_n) begin
        if (!rst_n) ser_rst_sync <= 2'b00;
        else        ser_rst_sync <= {ser_rst_sync[0], 1'b1};
    end

    wire ser_rst_n = ser_rst_sync[1];

    wire [9:0] tmds_b, tmds_g, tmds_r;

    tmds_encoder u_enc_b (
        .clk   (pix_clk),
        .rst_n (rst_n),
        .din   (rgb[7:0]),
        .c0    (hs),
        .c1    (vs),
        .de    (vde),
        .dout  (tmds_b)
    );

    tmds_encoder u_enc_g (
        .clk   (pix_clk),
        .rst_n (rst_n),
        .din   (rgb[15:8]),
        .c0    (1'b0),
        .c1    (1'b0),
        .de    (vde),
        .dout  (tmds_g)
    );

    tmds_encoder u_enc_r (
        .clk   (pix_clk),
        .rst_n (rst_n),
        .din   (rgb[23:16]),
        .c0    (1'b0),
        .c1    (1'b0),
        .de    (vde),
        .dout  (tmds_r)
    );

    tmds_serializer #(
        .USE_NEG_ODDR (USE_NEG_ODDR),
        .USE_OSER10   (USE_OSER10)
    ) u_ser (
        .ser_clk    (ser_clk),
        .pix_clk    (pix_clk),
        .rst_n      (ser_rst_n),
        .d_lane0    (tmds_b),
        .d_lane1    (tmds_g),
        .d_lane2    (tmds_r),
        .d_lane3    (10'b1111100000),
        .tmds_data_p(tmds_data_p),
        .tmds_data_n(tmds_data_n),
        .tmds_clk_p (tmds_clk_p),
        .tmds_clk_n (tmds_clk_n)
    );

endmodule
