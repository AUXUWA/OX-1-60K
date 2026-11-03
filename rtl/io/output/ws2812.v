// ws2812

`default_nettype none

module ws2812 #(
    parameter integer N_LED   = 25,
    parameter integer CLK_HZ  = 50_000_000,
    parameter [23:0]  COL_OFF  = 24'h000000,
    parameter [23:0]  COL_KEY  = 24'h202020,
    parameter [23:0]  COL_FAR  = 24'h001800,
    parameter [23:0]  COL_HOLD = 24'h300000,
    parameter [23:0]  COL_HIT  = 24'h7F7F7F,
    parameter [23:0]  COL_MATCH= 24'hFFFFFF,
    parameter integer TEST_BRIGHT = 0
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 tick_ms,
    input  wire [N_LED*3-1:0]   lvl_bus,
    input  wire [7:0]           ramp_r,
    output reg                  dout
);

    localparam integer T1H  = (CLK_HZ / 1_000_000) * 66 / 100;
    localparam integer T0H  = (CLK_HZ / 1_000_000) * 28 / 100;
    localparam integer BIT_CYC = 63;
    localparam integer RESET_CYC = (CLK_HZ / 1_000_000) * 300;

    `ifdef SIMULATION
    initial begin
        if (T1H == 0 || T0H == 0)
            $display("*** ERROR ws2812: T1H=%0d T0H=%0d is ZERO - integer division underflow (use (CLK_HZ/1e6)*66/100)", T1H, T0H);
        if (T1H >= BIT_CYC)
            $display("*** ERROR ws2812: T1H(%0d) >= BIT_CYC(%0d)", T1H, BIT_CYC);
        if (T0H >= T1H)
            $display("*** ERROR ws2812: T0H(%0d) >= T1H(%0d) - cannot tell 0 from 1", T0H, T1H);
        if (RESET_CYC < (CLK_HZ / 1_000_000) * 280)
            $display("*** ERROR ws2812: RESET_CYC(%0d) < 280us (datasheet min)", RESET_CYC);
        if (N_LED != 25)
            $display("*** WARN  ws2812: N_LED=%0d (factory 25; change PIX_MAP too)", N_LED);
    end
    `endif

    function integer pix_map;
        input integer j;
        begin
            case (j)
                0:  pix_map = 0;
                1:  pix_map = 2;
                2:  pix_map = 4;
                3:  pix_map = 5;
                4:  pix_map = 7;
                5:  pix_map = 9;
                6:  pix_map = 11;
                7:  pix_map = 12;
                8:  pix_map = 14;
                9:  pix_map = 16;
                10: pix_map = 17;
                11: pix_map = 19;
                12: pix_map = 21;
                13: pix_map = 23;
                14: pix_map = 24;
                15: pix_map = 22;
                16: pix_map = 20;
                17: pix_map = 18;
                18: pix_map = 15;
                19: pix_map = 13;
                20: pix_map = 10;
                21: pix_map = 8;
                22: pix_map = 6;
                23: pix_map = 3;
                24: pix_map = 1;
                default: pix_map = 0;
            endcase
        end
    endfunction

    function [23:0] pal;
        input [2:0] lvl;
        input [7:0] ramp;
        begin
            if (TEST_BRIGHT != 0) begin
                pal = {TEST_BRIGHT[7:0], TEST_BRIGHT[7:0], TEST_BRIGHT[7:0]};
            end
            else case (lvl)
                3'd0:    pal = COL_OFF;
                3'd1:    pal = COL_KEY;
                3'd2:    pal = COL_FAR;
                3'd3:    pal = {8'h00, ramp, 8'h00};
                3'd4:    pal = COL_HOLD;
                3'd5:    pal = COL_HIT;
                3'd6:    pal = COL_MATCH;
                default: pal = COL_OFF;
            endcase
        end
    endfunction

    reg [2:0] lvl_buf [0:N_LED-1];
    reg [7:0] ramp_reg;

    reg  tick_d;
    wire tick_fire = tick_ms & ~tick_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) tick_d <= 1'b0;
        else        tick_d <= tick_ms;
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < N_LED; i = i + 1) lvl_buf[i] <= 3'd0;
            ramp_reg <= 8'd0;
        end else if (tick_fire) begin
            for (i = 0; i < N_LED; i = i + 1)
                lvl_buf[i] <= lvl_bus[i*3 +: 3];
            ramp_reg <= ramp_r;
        end
    end

    localparam [1:0] S_BIT = 2'd1, S_RST = 2'd2;

    reg [1:0]  state;
    reg [4:0]  pix_idx;
    reg [4:0]  grp_idx;
    reg [7:0]  cyc;
    reg [15:0] rst_cnt;
    reg        cur_bit;

    wire [23:0] px_cur  = pal(lvl_buf[pix_map(pix_idx)], ramp_reg);
    wire [23:0] px_next = pal(lvl_buf[pix_map(pix_idx + 5'd1)], ramp_reg);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_RST;
            rst_cnt <= RESET_CYC;
            pix_idx <= 5'd0;
            grp_idx <= 5'd0;
            cyc     <= 8'd0;
            dout    <= 1'b0;
            cur_bit <= 1'b0;
        end
        else begin
            case (state)
                S_RST: begin
                    dout <= 1'b0;
                    if (rst_cnt != 0) begin
                        rst_cnt <= rst_cnt - 16'd1;
                    end else begin
                        pix_idx <= 5'd0;
                        grp_idx <= 5'd0;
                        cyc     <= 8'd0;
                        cur_bit <= px_cur[23];
                        state   <= S_BIT;
                    end
                end
                S_BIT: begin
                    if (cyc == 0) begin
                        dout <= 1'b1;
                        cyc  <= 8'd1;
                    end
                    else if (cyc == (cur_bit ? T1H : T0H)) begin
                        dout <= 1'b0;
                        cyc  <= cyc + 8'd1;
                    end
                    else if (cyc == BIT_CYC - 1) begin
                        dout <= 1'b0;
                        cyc  <= 8'd0;
                        if (pix_idx == N_LED - 1 && grp_idx == 5'd23) begin
                            state   <= S_RST;
                            rst_cnt <= RESET_CYC;
                            pix_idx <= 5'd0;
                            grp_idx <= 5'd0;
                        end else begin
                            if (grp_idx == 5'd23) begin
                                pix_idx <= pix_idx + 5'd1;
                                grp_idx <= 5'd0;
                                cur_bit <= px_next[23];
                            end else begin
                                grp_idx <= grp_idx + 5'd1;
                                cur_bit <= px_cur[23 - (grp_idx + 5'd1)];
                            end
                        end
                    end
                    else begin
                        cyc <= cyc + 8'd1;
                    end
                end
                default: state <= S_RST;
            endcase
        end
    end

endmodule

`default_nettype wire
