// keypad_event_cdc

`timescale 1ns/1ps

module keypad_event_cdc #(
    parameter integer W        = 25,
    parameter integer SETTLE   = 4,
    parameter integer KEEP_DIV = 50_000
)(
    input  wire          sys_clk,
    input  wire          sys_rst_n,
    input  wire [W-1:0]  sys_level,
    input  wire          sys_gate,

    input  wire          mclk,
    input  wire          m_rst_n,
    output reg  [W-1:0]  m_level,
    output wire          m_gate
);

    reg [W-1:0] level_r;
    reg         pend_r;
    reg [7:0]   settle_cnt;
    reg [15:0]  keep_cnt;
    reg         tgl;

    localparam integer SETTLE_C = (SETTLE   < 1) ? 1 : SETTLE;
    localparam integer KEEP_C   = (KEEP_DIV < 2) ? 2 : KEEP_DIV;

    localparam integer KW = (KEEP_C <=     2) ? 1 :
                            (KEEP_C <=     4) ? 2 :
                            (KEEP_C <=     8) ? 3 :
                            (KEEP_C <=    16) ? 4 :
                            (KEEP_C <=    32) ? 5 :
                            (KEEP_C <=    64) ? 6 :
                            (KEEP_C <=   128) ? 7 :
                            (KEEP_C <=   256) ? 8 :
                            (KEEP_C <=  1024) ? 10 :
                            (KEEP_C <=  4096) ? 12 :
                            (KEEP_C <= 16384) ? 14 :
                            (KEEP_C <= 65536) ? 17 : 18;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            level_r    <= {W{1'b0}};
            pend_r     <= 1'b0;
            settle_cnt <= 8'd0;
            keep_cnt   <= 16'd0;
            tgl        <= 1'b0;
        end
        else begin
            if (!pend_r) begin
                if (sys_level != level_r) begin
                    pend_r     <= 1'b1;
                    settle_cnt <= SETTLE_C[7:0];
                end
                else if (keep_cnt >= KEEP_C) begin
                    keep_cnt <= 16'd0;
                    tgl      <= ~tgl;
                end
                else begin
                    keep_cnt <= keep_cnt + 16'd1;
                end
            end
            else begin
                if (settle_cnt != 8'd0) begin
                    settle_cnt <= settle_cnt - 8'd1;
                end
                else begin
                    level_r <= sys_level;
                    pend_r  <= 1'b0;
                    tgl     <= ~tgl;
                    keep_cnt<= 16'd0;
                end
            end
        end
    end

    reg [1:0]   tgl_sync;
    reg         tgl_sync_d;
    reg [W-1:0] lev_meta, lev_sync;

    always @(posedge mclk or negedge m_rst_n) begin
        if (!m_rst_n) begin
            tgl_sync   <= 2'b00;
            tgl_sync_d <= 1'b0;
            lev_meta   <= {W{1'b0}};
            lev_sync   <= {W{1'b0}};
        end
        else begin
            tgl_sync   <= {tgl_sync[0], tgl};
            tgl_sync_d <= tgl_sync[1];
            lev_meta   <= level_r;
            lev_sync   <= lev_meta;
        end
    end

    wire ev_load = tgl_sync[1] ^ tgl_sync_d;

    always @(posedge mclk or negedge m_rst_n) begin
        if (!m_rst_n) m_level <= {W{1'b0}};
        else if (ev_load) m_level <= lev_sync;
    end

    reg [1:0] gate_sync;
    always @(posedge mclk or negedge m_rst_n) begin
        if (!m_rst_n) gate_sync <= 2'b00;
        else          gate_sync <= {gate_sync[0], sys_gate};
    end
    assign m_gate = gate_sync[1];

endmodule
