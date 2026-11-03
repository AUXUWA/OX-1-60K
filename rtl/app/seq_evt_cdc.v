// seq_evt_cdc —— 音序器按键事件的原子化跨域传输（mclk → pix）

`timescale 1ns/1ps

module seq_evt_cdc #(
    parameter integer SETTLE = 2,
    parameter integer SKEW  = 0
)(
    input  wire        src_clk,
    input  wire        src_rst_n,
    input  wire        src_pulse,
    input  wire [4:0]  src_payload,
    output wire        src_ovf,

    input  wire        dst_clk,
    input  wire        dst_rst_n,
    output wire [5:0]  dst_bus
);

    localparam [1:0] S_IDLE = 2'd0, S_PRE = 2'd1, S_HOLD = 2'd2;

    reg [1:0]  st;
    reg [4:0]  pay;
    reg        tgl;
    reg [4:0]  q_pay;
    reg        q_v;
    reg [15:0] cnt;
    reg        ovf;

    reg [1:0]  st_n;
    reg [4:0]  pay_n;
    reg        tgl_n;
    reg [4:0]  q_pay_n;
    reg        q_v_n;
    reg [15:0] cnt_n;
    reg        ovf_n;

    always @(*) begin
        st_n = st; pay_n = pay; tgl_n = tgl;
        q_pay_n = q_pay; q_v_n = q_v; cnt_n = cnt; ovf_n = ovf;

        case (st)
            S_IDLE: begin
                if (src_pulse) begin
                    pay_n = src_payload;
                    cnt_n = 16'd0;
                    st_n  = S_PRE;
                end
            end
            S_PRE: begin
                if (cnt >= SETTLE[15:0]) begin
                    tgl_n  = ~tgl;
                    cnt_n  = 16'd0;
                    st_n   = S_HOLD;
                    if (q_v) begin
                        pay_n = q_pay;
                        q_v_n = 1'b0;
                    end
                end else begin
                    cnt_n = cnt + 16'd1;
                end
            end
            S_HOLD: begin
                if (cnt >= SETTLE[15:0]) begin
                    cnt_n = 16'd0;
                    if (q_v) begin
                        pay_n = q_pay;
                        q_v_n = 1'b0;
                        st_n  = S_PRE;
                    end else begin
                        st_n = S_IDLE;
                    end
                end else begin
                    cnt_n = cnt + 16'd1;
                end
            end
            default: st_n = S_IDLE;
        endcase

        if (src_pulse && (st != S_IDLE)) begin
            if (q_v_n) begin
                ovf_n = 1'b1;
            end else begin
                q_pay_n = src_payload;
                q_v_n   = 1'b1;
            end
        end
    end

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            st    <= S_IDLE;
            pay   <= 5'd0;
            tgl   <= 1'b0;
            q_pay <= 5'd0;
            q_v   <= 1'b0;
            cnt   <= 16'd0;
            ovf   <= 1'b0;
        end else begin
            st    <= st_n;
            pay   <= pay_n;
            tgl   <= tgl_n;
            q_pay <= q_pay_n;
            q_v   <= q_v_n;
            cnt   <= cnt_n;
            ovf   <= ovf_n;
        end
    end

    assign src_ovf = ovf;

    reg [4:0] pay_d1, pay_d2;
    reg       tgl_d1, tgl_d2;

    generate
        if (SKEW == 0) begin : g_noskew
            always @(posedge dst_clk or negedge dst_rst_n) begin
                if (!dst_rst_n) begin
                    pay_d1 <= 5'd0;
                    tgl_d1 <= 1'b0;
                end else begin
                    pay_d1 <= pay;
                    tgl_d1 <= tgl;
                end
            end
        end else begin : g_skew
            reg [4:0] sk [0:SKEW];
            integer i;
            always @(posedge dst_clk or negedge dst_rst_n) begin
                if (!dst_rst_n) begin
                    for (i = 0; i <= SKEW; i = i + 1) sk[i] <= 5'd0;
                    pay_d1 <= 5'd0;
                    tgl_d1 <= 1'b0;
                end else begin
                    sk[0] <= pay;
                    for (i = 1; i <= SKEW; i = i + 1) sk[i] <= sk[i-1];
                    pay_d1 <= sk[SKEW];
                    tgl_d1 <= tgl;
                end
            end
        end
    endgenerate

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            pay_d2 <= 5'd0;
            tgl_d2 <= 1'b0;
        end else begin
            pay_d2 <= pay_d1;
            tgl_d2 <= tgl_d1;
        end
    end

    assign dst_bus = {tgl_d2, pay_d2};

endmodule
