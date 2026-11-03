// ev_tgl_cdc

`timescale 1ns/1ps

module ev_tgl_cdc #(
    parameter integer W      = 7,
    parameter integer SETTLE = 4
)(
    input  wire          src_clk,
    input  wire          src_rst_n,
    input  wire          src_pulse,
    input  wire [W-1:0]  src_payload,
    output reg           src_ovf,
    input  wire          src_ovf_clr,

    input  wire          dst_clk,
    input  wire          dst_rst_n,
    output reg           dst_pulse,
    output reg  [W-1:0]  dst_payload,
    output reg           dst_busy
);
    reg [W-1:0]       pay_r;
    reg               tgl;
    reg               pend;
    reg [15:0]        settle_cnt;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            pay_r        <= {W{1'b0}};
            tgl          <= 1'b0;
            pend         <= 1'b0;
            settle_cnt   <= 16'd0;
            src_ovf      <= 1'b0;
        end
        else begin
            if (src_ovf_clr) src_ovf <= 1'b0;

            if (pend) begin
                if (src_pulse) src_ovf <= 1'b1;

                if (settle_cnt >= SETTLE[15:0]) begin
                    tgl        <= ~tgl;
                    pend       <= 1'b0;
                    settle_cnt <= 16'd0;
                end
                else begin
                    settle_cnt <= settle_cnt + 16'd1;
                end
            end
            else if (src_pulse) begin
                pay_r      <= src_payload;
                pend       <= 1'b1;
                settle_cnt <= 16'd0;
            end
        end
    end

    reg               tgl_s1, tgl_s2, tgl_s2_d;
    reg [W-1:0]       pay_s1, pay_s2;

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            tgl_s1     <= 1'b0;
            tgl_s2     <= 1'b0;
            tgl_s2_d   <= 1'b0;
            pay_s1     <= {W{1'b0}};
            pay_s2     <= {W{1'b0}};
            dst_pulse  <= 1'b0;
            dst_payload<= {W{1'b0}};
        end
        else begin
            tgl_s1   <= tgl;
            tgl_s2   <= tgl_s1;
            tgl_s2_d <= tgl_s2;
            pay_s1   <= pay_r;
            pay_s2   <= pay_s1;

            dst_pulse <= 1'b0;

            if (tgl_s2 ^ tgl_s2_d) begin
                dst_payload <= pay_s2;
                dst_pulse   <= 1'b1;
            end
        end
    end

    reg pend_s1, pend_s2;
    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            pend_s1  <= 1'b0;
            pend_s2  <= 1'b0;
            dst_busy <= 1'b0;
        end
        else begin
            pend_s1  <= pend;
            pend_s2  <= pend_s1;
            dst_busy <= pend_s2;
        end
    end

endmodule
