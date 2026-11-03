// op_ksl_ksr —— OPL3 的 KSL (Key Scale Level) 与 KSR (Key Scale Rate) 计算

module op_ksl_ksr (
    input  wire [9:0]   fnum,
    input  wire [2:0]   block,
    input  wire         nts,
    input  wire         ksr,

    output wire [7:0]   eg_ksl,
    output wire [4:0]   ksv
);

    `include "eg_incstep_tab.vh"

    wire [15:0] ksl_calc = ({8'd0, kslrom_lut(fnum[9:6])} << 2);
    wire [15:0] ksl_sub  = ({12'd0, (4'd8 - {1'b0, block})} << 5);
    wire [15:0] ksl_diff = (ksl_calc >= ksl_sub) ? (ksl_calc - ksl_sub) : 16'd0;

    assign eg_ksl = ksl_diff[7:0];

    assign ksv = {block, 1'b0} | {4'd0, fnum[9 - nts]};

endmodule
