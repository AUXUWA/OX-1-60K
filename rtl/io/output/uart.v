// uart

`default_nettype none

module uart #(
    parameter integer CLK_HZ   = 50_000_000,
    parameter integer BAUD     = 115200,
    parameter integer RX_TH0   = 0
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx_busy,
    output reg        txd_o,
    input  wire       rxd_i,
    output reg        rx_valid,
    output reg [7:0]  rx_data
);

    localparam integer BIT_CYC = CLK_HZ / BAUD;
    localparam integer TH0_VAL = (RX_TH0 > 0) ? RX_TH0 : (BIT_CYC/2 + BIT_CYC - 1);

    `ifdef SIMULATION
    initial begin
        if (BIT_CYC < 8)
            $display("*** ERROR uart: BIT_CYC(%0d) < 8 —— 波特率相对时钟过高", BIT_CYC);
    end
    `endif

    localparam [1:0] TX_IDLE = 2'd0, TX_START = 2'd1, TX_DATA = 2'd2, TX_STOP = 2'd3;
    reg [1:0]  tx_state;
    reg [8:0]  tx_sh;
    reg [3:0]  tx_dbit;
    reg [15:0] tx_cyc;

    assign tx_busy = (tx_state != TX_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_sh    <= 9'h1FF;
            tx_dbit  <= 4'd0;
            tx_cyc   <= 16'd0;
            txd_o    <= 1'b1;
        end
        else begin
            case (tx_state)
                TX_IDLE: begin
                    txd_o <= 1'b1;
                    if (tx_start) begin
                        tx_sh    <= {1'b1, tx_data};
                        tx_state <= TX_START;
                        tx_cyc   <= 16'd0;
                        tx_dbit  <= 4'd0;
                    end
                end
                TX_START: begin
                    txd_o <= 1'b0;
                    if (tx_cyc == BIT_CYC - 1) begin
                        tx_cyc   <= 16'd0;
                        tx_state <= TX_DATA;
                    end else tx_cyc <= tx_cyc + 16'd1;
                end
                TX_DATA: begin
                    txd_o <= tx_sh[0];
                    if (tx_cyc == BIT_CYC - 1) begin
                        tx_cyc <= 16'd0;
                        tx_sh  <= {1'b1, tx_sh[8:1]};
                        if (tx_dbit == 4'd7) begin
                            tx_dbit  <= 4'd0;
                            tx_state <= TX_STOP;
                        end else tx_dbit <= tx_dbit + 4'd1;
                    end else tx_cyc <= tx_cyc + 16'd1;
                end
                TX_STOP: begin
                    txd_o <= 1'b1;
                    if (tx_cyc == BIT_CYC - 1) begin
                        tx_cyc   <= 16'd0;
                        tx_state <= TX_IDLE;
                    end else tx_cyc <= tx_cyc + 16'd1;
                end
            endcase
        end
    end

    reg [1:0]  rx_sync;
    reg [7:0]  rx_flt;
    reg        rx_lvl;
    reg        rx_lvl_d;
    wire       rx_fall = rx_lvl_d & ~rx_lvl;

    localparam integer RX_S0 = BIT_CYC/2 + BIT_CYC - 1;
    localparam integer RX_S7 = RX_S0 + 7*BIT_CYC;
    localparam integer RX_ST = RX_S0 + 8*BIT_CYC;

    reg [15:0] rx_cyc;
    reg [3:0]  rx_bitn;
    reg [8:0]  rx_sh;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync <= 2'b11; rx_flt <= 8'hFF; rx_lvl <= 1'b1; rx_lvl_d <= 1'b1;
            rx_cyc <= 16'd0; rx_bitn <= 4'd0; rx_sh <= 9'd0;
            rx_valid <= 1'b0; rx_data <= 8'd0;
        end
        else begin
            rx_sync  <= {rx_sync[0], rxd_i};
            rx_flt   <= {rx_flt[6:0], rx_sync[0]};
            rx_lvl_d <= rx_lvl;
            if (&rx_flt)       rx_lvl <= 1'b1;
            else if (~|rx_flt) rx_lvl <= 1'b0;

            rx_valid <= 1'b0;

            if (rx_bitn == 4'd0) begin
                if (rx_fall) begin
                    rx_cyc  <= 16'd1;
                    rx_bitn <= 4'd1;
                end
            end
            else begin
                rx_cyc <= rx_cyc + 16'd1;
                case (rx_bitn)
                    4'd1: if (rx_cyc == RX_S0) begin rx_sh[0] <= rx_lvl; rx_bitn <= 4'd2; end
                    4'd2: if (rx_cyc == RX_S0 + 1*BIT_CYC) begin rx_sh[1] <= rx_lvl; rx_bitn <= 4'd3; end
                    4'd3: if (rx_cyc == RX_S0 + 2*BIT_CYC) begin rx_sh[2] <= rx_lvl; rx_bitn <= 4'd4; end
                    4'd4: if (rx_cyc == RX_S0 + 3*BIT_CYC) begin rx_sh[3] <= rx_lvl; rx_bitn <= 4'd5; end
                    4'd5: if (rx_cyc == RX_S0 + 4*BIT_CYC) begin rx_sh[4] <= rx_lvl; rx_bitn <= 4'd6; end
                    4'd6: if (rx_cyc == RX_S0 + 5*BIT_CYC) begin rx_sh[5] <= rx_lvl; rx_bitn <= 4'd7; end
                    4'd7: if (rx_cyc == RX_S0 + 6*BIT_CYC) begin rx_sh[6] <= rx_lvl; rx_bitn <= 4'd8; end
                    4'd8: if (rx_cyc == RX_S0 + 7*BIT_CYC) begin rx_sh[7] <= rx_lvl; rx_bitn <= 4'd9; end
                    4'd9: if (rx_cyc == RX_ST) begin
                                                            if (rx_lvl) begin rx_data <= rx_sh[7:0]; rx_valid <= 1'b1; end
                              rx_bitn <= 4'd0;
                          end
                endcase
            end
        end
    end

endmodule

`default_nettype wire
