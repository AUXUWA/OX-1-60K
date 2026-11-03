// tmds_encoder —— TMDS 8b/10b 编码（单通道，DVI 1.0 §3.3.3）

`timescale 1ns/1ps

module tmds_encoder (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  din,
    input  wire        c0,
    input  wire        c1,
    input  wire        de,

    output reg  [9:0]  dout
);

    reg [7:0] din_q;
    reg       de_q, c0_q, c1_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_q <= 8'h00;
            de_q  <= 1'b0;
            c0_q  <= 1'b0;
            c1_q  <= 1'b0;
        end
        else begin
            din_q <= din;
            de_q  <= de;
            c0_q  <= c0;
            c1_q  <= c1;
        end
    end

    wire [3:0] n1d = din_q[0] + din_q[1] + din_q[2] + din_q[3] +
                     din_q[4] + din_q[5] + din_q[6] + din_q[7];

    wire decision1 = (n1d > 4'h4) | ((n1d == 4'h4) & (din_q[0] == 1'b0));

    wire [8:0] q_m;
    assign q_m[0] = din_q[0];
    assign q_m[1] = decision1 ? ~(q_m[0] ^ din_q[1]) : (q_m[0] ^ din_q[1]);
    assign q_m[2] = decision1 ? ~(q_m[1] ^ din_q[2]) : (q_m[1] ^ din_q[2]);
    assign q_m[3] = decision1 ? ~(q_m[2] ^ din_q[3]) : (q_m[2] ^ din_q[3]);
    assign q_m[4] = decision1 ? ~(q_m[3] ^ din_q[4]) : (q_m[3] ^ din_q[4]);
    assign q_m[5] = decision1 ? ~(q_m[4] ^ din_q[5]) : (q_m[4] ^ din_q[5]);
    assign q_m[6] = decision1 ? ~(q_m[5] ^ din_q[6]) : (q_m[5] ^ din_q[6]);
    assign q_m[7] = decision1 ? ~(q_m[6] ^ din_q[7]) : (q_m[6] ^ din_q[7]);
    assign q_m[8] = ~decision1;

    wire [3:0] n1q_m = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                       q_m[4] + q_m[5] + q_m[6] + q_m[7];
    wire [3:0] n0q_m = 4'h8 - n1q_m;

    reg [4:0] cnt;

    wire decision2 = (cnt == 5'h00) | (n1q_m == n0q_m);
    wire decision3 = (~cnt[4] & (n1q_m > n0q_m)) |
                     ( cnt[4] & (n0q_m > n1q_m));

    localparam [9:0] CTL0 = 10'b1101010100,
                     CTL1 = 10'b0010101011,
                     CTL2 = 10'b0101010100,
                     CTL3 = 10'b1010101011;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 10'h000;
            cnt  <= 5'd0;
        end
        else if (de_q) begin
            if (decision2) begin
                dout[9]   <= ~q_m[8];
                dout[8]   <=  q_m[8];
                dout[7:0] <=  q_m[8] ?  q_m[7:0] : ~q_m[7:0];
                cnt       <=  q_m[8] ? (cnt + {1'b0, n1q_m} - {1'b0, n0q_m})
                                     : (cnt + {1'b0, n0q_m} - {1'b0, n1q_m});
            end
            else if (decision3) begin
                dout[9]   <= 1'b1;
                dout[8]   <= q_m[8];
                dout[7:0] <= ~q_m[7:0];
                cnt       <= cnt + {q_m[8], 1'b0} + {1'b0, n0q_m} - {1'b0, n1q_m};
            end
            else begin
                dout[9]   <= 1'b0;
                dout[8]   <= q_m[8];
                dout[7:0] <= q_m[7:0];
                cnt       <= cnt - {~q_m[8], 1'b0} + {1'b0, n1q_m} - {1'b0, n0q_m};
            end
        end
        else begin
            cnt  <= 5'd0;
            case ({c1_q, c0_q})
                2'b00:   dout <= CTL0;
                2'b01:   dout <= CTL1;
                2'b10:   dout <= CTL2;
                default: dout <= CTL3;
            endcase
        end
    end

endmodule
