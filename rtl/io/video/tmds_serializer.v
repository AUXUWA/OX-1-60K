// tmds_serializer —— TMDS 10:1 串行化（4 条 lane：3 数据 + 1 时钟），差分 p/n 输出

`timescale 1ns/1ps

`ifdef SIM_ODDR
  `define TMDS_ODDR(NAME,Q0,Q1,D0,D1,TX,CLK) oddr_sim NAME (Q0, Q1, D0, D1, TX, CLK)
`else
  `define TMDS_ODDR(NAME,Q0,Q1,D0,D1,TX,CLK) ODDR     NAME (Q0, Q1, D0, D1, TX, CLK)
`endif
`ifdef SIM_OSER
  `define TMDS_OSER(NAME,Q,B0,B1,B2,B3,B4,B5,B6,B7,B8,B9,PCLK,FCLK,RST) oser10_sim NAME (Q, B9, B0, B1, B2, B3, B4, B5, B6, B7, B8, PCLK, FCLK, RST)
`else
  `define TMDS_OSER(NAME,Q,B0,B1,B2,B3,B4,B5,B6,B7,B8,B9,PCLK,FCLK,RST) OSER10     NAME (Q, B9, B0, B1, B2, B3, B4, B5, B6, B7, B8, PCLK, FCLK, RST)
`endif

module tmds_serializer #(
    parameter integer USE_NEG_ODDR = 0,
    parameter integer USE_OSER10 = 0
) (
    input  wire        ser_clk,
    input  wire        pix_clk,
    input  wire        rst_n,

    input  wire [9:0]  d_lane0,
    input  wire [9:0]  d_lane1,
    input  wire [9:0]  d_lane2,
    input  wire [9:0]  d_lane3,

    output wire [2:0]  tmds_data_p,
    output wire [2:0]  tmds_data_n,
    output wire        tmds_clk_p,
    output wire        tmds_clk_n
);

    generate
    if (USE_OSER10 == 0) begin : g_oddr_path
    reg [2:0] mod5;

    always @(posedge ser_clk or negedge rst_n) begin
        if (!rst_n)             mod5 <= 3'd0;
        else if (mod5 == 3'd4)  mod5 <= 3'd0;
        else                    mod5 <= mod5 + 3'd1;
    end

    wire load = (mod5 == 3'd4);

    reg [4:0] sh_rise0, sh_fall0;
    reg [4:0] sh_rise1, sh_fall1;
    reg [4:0] sh_rise2, sh_fall2;
    reg [4:0] sh_rise3, sh_fall3;

    always @(posedge ser_clk or negedge rst_n) begin
        if (!rst_n) begin
            sh_rise0 <= 5'd0; sh_fall0 <= 5'd0;
            sh_rise1 <= 5'd0; sh_fall1 <= 5'd0;
            sh_rise2 <= 5'd0; sh_fall2 <= 5'd0;
            sh_rise3 <= 5'd0; sh_fall3 <= 5'd0;
        end
        else if (load) begin
            sh_rise0 <= {d_lane0[8], d_lane0[6], d_lane0[4], d_lane0[2], d_lane0[0]};
            sh_fall0 <= {d_lane0[9], d_lane0[7], d_lane0[5], d_lane0[3], d_lane0[1]};
            sh_rise1 <= {d_lane1[8], d_lane1[6], d_lane1[4], d_lane1[2], d_lane1[0]};
            sh_fall1 <= {d_lane1[9], d_lane1[7], d_lane1[5], d_lane1[3], d_lane1[1]};
            sh_rise2 <= {d_lane2[8], d_lane2[6], d_lane2[4], d_lane2[2], d_lane2[0]};
            sh_fall2 <= {d_lane2[9], d_lane2[7], d_lane2[5], d_lane2[3], d_lane2[1]};
            sh_rise3 <= {d_lane3[8], d_lane3[6], d_lane3[4], d_lane3[2], d_lane3[0]};
            sh_fall3 <= {d_lane3[9], d_lane3[7], d_lane3[5], d_lane3[3], d_lane3[1]};
        end
        else begin
            sh_rise0 <= {1'b0, sh_rise0[4:1]};
            sh_fall0 <= {1'b0, sh_fall0[4:1]};
            sh_rise1 <= {1'b0, sh_rise1[4:1]};
            sh_fall1 <= {1'b0, sh_fall1[4:1]};
            sh_rise2 <= {1'b0, sh_rise2[4:1]};
            sh_fall2 <= {1'b0, sh_fall2[4:1]};
            sh_rise3 <= {1'b0, sh_rise3[4:1]};
            sh_fall3 <= {1'b0, sh_fall3[4:1]};
        end
    end

    wire tmds_unused0, tmds_unused1, tmds_unused2, tmds_unused3,
         tmds_unused4, tmds_unused5, tmds_unused6, tmds_unused7;

    `TMDS_ODDR(oddr_d0_p, tmds_data_p[0], tmds_unused0, sh_rise0[0], sh_fall0[0], 1'b0, ser_clk);
    `TMDS_ODDR(oddr_d1_p, tmds_data_p[1], tmds_unused2, sh_rise1[0], sh_fall1[0], 1'b0, ser_clk);
    `TMDS_ODDR(oddr_d2_p, tmds_data_p[2], tmds_unused4, sh_rise2[0], sh_fall2[0], 1'b0, ser_clk);
    `TMDS_ODDR(oddr_ck_p, tmds_clk_p,     tmds_unused6, sh_rise3[0], sh_fall3[0], 1'b0, ser_clk);

        if (USE_NEG_ODDR != 0) begin : g_neg_oddr
            `TMDS_ODDR(oddr_d0_n, tmds_data_n[0], tmds_unused1, ~sh_rise0[0], ~sh_fall0[0], 1'b0, ser_clk);
            `TMDS_ODDR(oddr_d1_n, tmds_data_n[1], tmds_unused3, ~sh_rise1[0], ~sh_fall1[0], 1'b0, ser_clk);
            `TMDS_ODDR(oddr_d2_n, tmds_data_n[2], tmds_unused5, ~sh_rise2[0], ~sh_fall2[0], 1'b0, ser_clk);
            `TMDS_ODDR(oddr_ck_n, tmds_clk_n,     tmds_unused7, ~sh_rise3[0], ~sh_fall3[0], 1'b0, ser_clk);
        end
        else begin : g_neg_z
            assign tmds_data_n  = 3'bzzz;
            assign tmds_clk_n   = 1'bz;
        end
    end
    else begin : g_oser_path
    `TMDS_OSER(oser_d0, tmds_data_p[0],
               d_lane0[0],d_lane0[1],d_lane0[2],d_lane0[3],d_lane0[4],
               d_lane0[5],d_lane0[6],d_lane0[7],d_lane0[8],d_lane0[9],
               pix_clk, ser_clk, 1'b0);
    `TMDS_OSER(oser_d1, tmds_data_p[1],
               d_lane1[0],d_lane1[1],d_lane1[2],d_lane1[3],d_lane1[4],
               d_lane1[5],d_lane1[6],d_lane1[7],d_lane1[8],d_lane1[9],
               pix_clk, ser_clk, 1'b0);
    `TMDS_OSER(oser_d2, tmds_data_p[2],
               d_lane2[0],d_lane2[1],d_lane2[2],d_lane2[3],d_lane2[4],
               d_lane2[5],d_lane2[6],d_lane2[7],d_lane2[8],d_lane2[9],
               pix_clk, ser_clk, 1'b0);
    `TMDS_OSER(oser_ck, tmds_clk_p,
               d_lane3[0],d_lane3[1],d_lane3[2],d_lane3[3],d_lane3[4],
               d_lane3[5],d_lane3[6],d_lane3[7],d_lane3[8],d_lane3[9],
               pix_clk, ser_clk, 1'b0);
    assign tmds_data_n = 3'bzzz;
    assign tmds_clk_n  = 1'bz;
    end
    endgenerate

endmodule
