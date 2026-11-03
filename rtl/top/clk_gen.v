// clk_gen

`timescale 1ns/1ps

module clk_gen (
    input  wire clk_50m,
    output wire mclk,
    output wire lock
);

    wire [7:0] mdrdo_o;
    wire clkout1_o, clkout2_o, clkout3_o, clkout4_o, clkout5_o, clkout6_o;
    wire clkfbout_o;
    wire gw_vcc;
    wire gw_gnd;

    assign gw_vcc = 1'b1;
    assign gw_gnd = 1'b0;

    PLLA PLLA_inst (
        .CLKOUT0       (mclk),
        .CLKOUT1       (clkout1_o),
        .CLKOUT2       (clkout2_o),
        .CLKOUT3       (clkout3_o),
        .CLKOUT4       (clkout4_o),
        .CLKOUT5       (clkout5_o),
        .CLKOUT6       (clkout6_o),
        .CLKFBOUT      (clkfbout_o),
        .MDRDO         (mdrdo_o),
        .LOCK          (lock),
        .CLKIN         (clk_50m),
        .CLKFB         (gw_gnd),
        .PSSEL         ({gw_gnd, gw_gnd, gw_gnd}),
        .PSDIR         (gw_gnd),
        .PSPULSE       (gw_gnd),
        .SSCPOL        (gw_gnd),
        .SSCON         (gw_gnd),
        .SSCMDSEL      ({gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd}),
        .SSCMDSEL_FRAC ({gw_gnd, gw_gnd, gw_gnd}),
        .MDWDI         ({gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd}),
        .MDCLK         (gw_gnd),
        .MDOPC         ({gw_gnd, gw_gnd}),
        .MDAINC        (gw_gnd),
        .RESET         (gw_gnd),
        .PLLPWD        (gw_gnd),
        .RESET_I       (gw_gnd),
        .RESET_O       (gw_gnd)
    );

    defparam PLLA_inst.FCLKIN         = "50";
    defparam PLLA_inst.IDIV_SEL       = 1;
    defparam PLLA_inst.FBDIV_SEL      = 1;
    defparam PLLA_inst.MDIV_SEL       = 16;
    defparam PLLA_inst.MDIV_FRAC_SEL  = 0;
    defparam PLLA_inst.ODIV0_SEL      = 64;
    defparam PLLA_inst.ODIV0_FRAC_SEL = 0;
    defparam PLLA_inst.CLKFB_SEL      = "INTERNAL";

    defparam PLLA_inst.CLKOUT0_EN     = "TRUE";
    defparam PLLA_inst.CLKOUT1_EN     = "FALSE";
    defparam PLLA_inst.CLKOUT2_EN     = "FALSE";
    defparam PLLA_inst.CLKOUT3_EN     = "FALSE";
    defparam PLLA_inst.CLKOUT4_EN     = "FALSE";
    defparam PLLA_inst.CLKOUT5_EN     = "FALSE";
    defparam PLLA_inst.CLKOUT6_EN     = "FALSE";

    defparam PLLA_inst.CLK0_IN_SEL    = 1'b0;
    defparam PLLA_inst.CLK0_OUT_SEL   = 1'b0;
    defparam PLLA_inst.CLK1_IN_SEL    = 1'b0;
    defparam PLLA_inst.CLK1_OUT_SEL   = 1'b0;
    defparam PLLA_inst.CLK2_IN_SEL    = 1'b0;
    defparam PLLA_inst.CLK2_OUT_SEL   = 1'b0;
    defparam PLLA_inst.CLK3_IN_SEL    = 1'b0;
    defparam PLLA_inst.CLK3_OUT_SEL   = 1'b0;
    defparam PLLA_inst.CLK4_IN_SEL    = 2'b00;
    defparam PLLA_inst.CLK4_OUT_SEL   = 1'b0;
    defparam PLLA_inst.CLK5_IN_SEL    = 1'b0;
    defparam PLLA_inst.CLK5_OUT_SEL   = 1'b0;
    defparam PLLA_inst.CLK6_IN_SEL    = 1'b0;
    defparam PLLA_inst.CLK6_OUT_SEL   = 1'b0;

    defparam PLLA_inst.CLKOUT0_DT_DIR = 1'b1;
    defparam PLLA_inst.CLKOUT1_DT_DIR = 1'b1;
    defparam PLLA_inst.CLKOUT2_DT_DIR = 1'b1;
    defparam PLLA_inst.CLKOUT3_DT_DIR = 1'b1;
    defparam PLLA_inst.CLKOUT0_DT_STEP = 0;
    defparam PLLA_inst.CLKOUT1_DT_STEP = 0;
    defparam PLLA_inst.CLKOUT2_DT_STEP = 0;
    defparam PLLA_inst.CLKOUT3_DT_STEP = 0;

    defparam PLLA_inst.CLKOUT0_PE_COARSE = 0;
    defparam PLLA_inst.CLKOUT0_PE_FINE   = 0;
    defparam PLLA_inst.CLKOUT1_PE_COARSE = 0;
    defparam PLLA_inst.CLKOUT1_PE_FINE   = 0;
    defparam PLLA_inst.CLKOUT2_PE_COARSE = 0;
    defparam PLLA_inst.CLKOUT2_PE_FINE   = 0;
    defparam PLLA_inst.CLKOUT3_PE_COARSE = 0;
    defparam PLLA_inst.CLKOUT3_PE_FINE   = 0;
    defparam PLLA_inst.CLKOUT4_PE_COARSE = 0;
    defparam PLLA_inst.CLKOUT4_PE_FINE   = 0;
    defparam PLLA_inst.CLKOUT5_PE_COARSE = 0;
    defparam PLLA_inst.CLKOUT5_PE_FINE   = 0;
    defparam PLLA_inst.CLKOUT6_PE_COARSE = 0;
    defparam PLLA_inst.CLKOUT6_PE_FINE   = 0;

    defparam PLLA_inst.DE0_EN         = "FALSE";
    defparam PLLA_inst.DE1_EN         = "FALSE";
    defparam PLLA_inst.DE2_EN         = "FALSE";
    defparam PLLA_inst.DE3_EN         = "FALSE";
    defparam PLLA_inst.DE4_EN         = "FALSE";
    defparam PLLA_inst.DE5_EN         = "FALSE";
    defparam PLLA_inst.DE6_EN         = "FALSE";
    defparam PLLA_inst.DYN_DPA_EN     = "FALSE";
    defparam PLLA_inst.DYN_PE0_SEL    = "FALSE";
    defparam PLLA_inst.DYN_PE1_SEL    = "FALSE";
    defparam PLLA_inst.DYN_PE2_SEL    = "FALSE";
    defparam PLLA_inst.DYN_PE3_SEL    = "FALSE";
    defparam PLLA_inst.DYN_PE4_SEL    = "FALSE";
    defparam PLLA_inst.DYN_PE5_SEL    = "FALSE";
    defparam PLLA_inst.DYN_PE6_SEL    = "FALSE";
    defparam PLLA_inst.RESET_I_EN     = "FALSE";
    defparam PLLA_inst.RESET_O_EN     = "FALSE";
    defparam PLLA_inst.ICP_SEL        = 6'bXXXXXX;
    defparam PLLA_inst.LPF_RES        = 3'bXXX;
    defparam PLLA_inst.LPF_CAP        = 2'b00;
    defparam PLLA_inst.SSC_EN         = "FALSE";

endmodule
