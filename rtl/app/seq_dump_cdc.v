// seq_dump_cdc

`timescale 1ns/1ps

module seq_dump_cdc (
    input  wire        clk_sys,
    input  wire        rst_sys_n,
    input  wire        start,
    input  wire        rdy,
    output reg         out_valid,
    output reg  [4:0]  out_step,
    output reg  [7:0]  out_d0,
    output reg  [7:0]  out_d1,
    output reg  [7:0]  out_d2,
    output reg  [7:0]  out_d3,
    input  wire        clk_pix,
    input  wire        rst_pix_n,
    output reg  [4:0]  rd_idx,
    input  wire [23:0] pay_in
);

    localparam [2:0] S_IDLE = 3'd0,
                     S_ALIGN= 3'd1,
                     S_WAL  = 3'd2,
                     S_WACK = 3'd3,
                     S_WRDY = 3'd4,
                     S_DONE = 3'd5;

    reg [2:0]  state;
    reg [4:0]  cell_idx;
    reg [4:0]  ack_cnt;
    reg        req_tgl;
    reg        ack_tgl;
    reg [23:0] pay_r;
    reg        ack_tgl_s1, ack_tgl_s2, ack_tgl_s2_d;
    reg [23:0] pay_s1, pay_s2;
    reg [23:0] data_r;

    wire       ack_edge = ack_tgl_s2 ^ ack_tgl_s2_d;

    always @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
            state     <= S_IDLE;
            cell_idx  <= 5'd0;
            ack_cnt   <= 5'd0;
            req_tgl   <= 1'b0;
            out_valid <= 1'b0;
            out_step  <= 5'd0;
            out_d0    <= 8'd0;
            out_d1    <= 8'd0;
            out_d2    <= 8'd0;
            out_d3    <= 8'd0;
            ack_tgl_s1    <= 1'b0;
            ack_tgl_s2    <= 1'b0;
            ack_tgl_s2_d  <= 1'b0;
            pay_s1    <= 24'd0;
            pay_s2    <= 24'd0;
            data_r    <= 24'd0;
        end
        else begin
            ack_tgl_s1   <= ack_tgl;
            ack_tgl_s2   <= ack_tgl_s1;
            ack_tgl_s2_d <= ack_tgl_s2;
            pay_s1   <= pay_r;
            pay_s2   <= pay_s1;

            out_valid <= 1'b0;

            if (ack_edge) ack_cnt <= ack_cnt + 5'd1;

            case (state)
            S_IDLE: begin
                if (start) state <= S_ALIGN;
            end
            S_ALIGN: begin
                if (!start) begin
                    state <= S_IDLE;
                end
                else if (ack_cnt == 5'd0) begin
                    cell_idx <= 5'd0;
                    req_tgl  <= ~req_tgl;
                    state    <= S_WACK;
                end
                else begin
                    req_tgl  <= ~req_tgl;
                    state    <= S_WAL;
                end
            end
            S_WAL: begin
                if (ack_edge) state <= S_ALIGN;
            end
            S_WACK: begin
                if (ack_edge) begin
                    data_r <= pay_s2;
                    state  <= S_WRDY;
                end
            end
            S_WRDY: begin
                if (!start) begin
                    state <= S_IDLE;
                end
                else if (rdy) begin
                    out_valid <= 1'b1;
                    out_step  <= cell_idx;
                    out_d0    <= {2'b00, data_r[5:0]};
                    out_d1    <= {2'b00, data_r[11:6]};
                    out_d2    <= {2'b00, data_r[17:12]};
                    out_d3    <= {2'b00, data_r[23:18]};
                    cell_idx  <= cell_idx + 5'd1;
                    if (cell_idx == 5'd31) begin
                        state <= S_DONE;
                    end
                    else begin
                        req_tgl <= ~req_tgl;
                        state   <= S_WACK;
                    end
                end
            end
            S_DONE: begin
                if (!start) state <= S_IDLE;
            end
            default: state <= S_IDLE;
            endcase
        end
    end

    localparam [1:0] P_IDLE = 2'd0,
                     P_SETL = 2'd1,
                     P_ACK  = 2'd2;

    reg        req_tgl_s1, req_tgl_s2, req_tgl_s2_d;
    reg [1:0]  pstate;
    reg [1:0]  settle_cnt;
    reg [4:0]  pix_idx;

    always @(posedge clk_pix or negedge rst_pix_n) begin
        if (!rst_pix_n) begin
            req_tgl_s1     <= 1'b0;
            req_tgl_s2     <= 1'b0;
            req_tgl_s2_d   <= 1'b0;
            pstate     <= P_IDLE;
            settle_cnt <= 2'd0;
            pix_idx    <= 5'd0;
            rd_idx     <= 5'd0;
            pay_r      <= 24'd0;
            ack_tgl    <= 1'b0;
        end
        else begin
            req_tgl_s1   <= req_tgl;
            req_tgl_s2   <= req_tgl_s1;
            req_tgl_s2_d <= req_tgl_s2;

            case (pstate)
            P_IDLE: begin
                if (req_tgl_s2 ^ req_tgl_s2_d) begin
                    rd_idx     <= pix_idx;
                    pix_idx    <= pix_idx + 5'd1;
                    settle_cnt <= 2'd0;
                    pstate     <= P_SETL;
                end
            end
            P_SETL: begin
                pay_r <= pay_in;
                if (settle_cnt == 2'd2) begin
                    pstate <= P_ACK;
                end
                else begin
                    settle_cnt <= settle_cnt + 2'd1;
                end
            end
            P_ACK: begin
                ack_tgl <= ~ack_tgl;
                pstate  <= P_IDLE;
            end
            default: pstate <= P_IDLE;
            endcase
        end
    end

endmodule
