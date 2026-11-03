// param_store —— 每 (声部, 算子) 的音色参数寄存器堆（36bit）—— TDM 读，固定延迟

module param_store #(
    parameter integer DEPTH     = 64,
    parameter integer DW        = 36,
    parameter [DW-1:0]  INIT_VAL = {DW{1'b0}},
    parameter integer USE_BSRAM = 1,
    parameter integer EXTRA_LAT = 0,
    parameter integer AW = (DEPTH <=   2) ? 1 :
                          (DEPTH <=   4) ? 2 :
                          (DEPTH <=   8) ? 3 :
                          (DEPTH <=  16) ? 4 :
                          (DEPTH <=  32) ? 5 :
                          (DEPTH <=  64) ? 6 : 7
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             we,
    input  wire [AW-1:0]    waddr,
    input  wire [DW-1:0]    wdata,
    input  wire             re,
    input  wire [AW-1:0]    raddr,
    output wire [DW-1:0]    rdata,
    output wire             rdata_valid
);

    localparam integer MULT_LSB  = 0;
    localparam integer KSL_LSB   = 4;
    localparam integer TL_LSB    = 6;
    localparam integer AR_LSB    = 12;
    localparam integer DR_LSB    = 16;
    localparam integer SL_LSB    = 20;
    localparam integer RR_LSB    = 25;
    localparam integer KSR_LSB   = 29;
    localparam integer EGT_LSB   = 30;
    localparam integer WF_LSB    = 31;
    localparam integer VIB_LSB   = 34;
    localparam integer TREM_LSB  = 35;

    localparam integer MULT_W  = 4,
                       KSL_W   = 2,
                       TL_W    = 6,
                       AR_W    = 4,
                       DR_W    = 4,
                       SL_W    = 5,
                       RR_W    = 4,
                       KSR_W   = 1,
                       EGT_W   = 1,
                       WF_W    = 3,
                       VIB_W   = 1,
                       TREM_W  = 1;

    localparam integer RD_LAT = 2 + EXTRA_LAT;

    reg [DW-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
    end

    wire [DW-1:0] rd_d;

    generate
        if (USE_BSRAM == 0) begin : g_ff
            reg [DW-1:0] d_ff;
            reg [DW-1:0] d_mid;
            always @(posedge clk) begin
                d_ff  <= mem[raddr];
                d_mid <= d_ff;
            end
            assign rd_d = d_mid;
        end
        else begin : g_bsram
            reg [AW-1:0] raddr_r;
            reg [DW-1:0] d_mid;
            always @(posedge clk) begin
                raddr_r <= raddr;
                d_mid   <= mem[raddr_r];
            end
            assign rd_d = d_mid;
        end
    endgenerate

    reg v1, v2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1 <= 1'b0;
            v2 <= 1'b0;
        end
        else begin
            v1 <= re;
            v2 <= v1;
        end
    end

    reg            val_q [0:EXTRA_LAT];
    reg [DW-1:0]   dat_q [0:EXTRA_LAT];
    integer        e;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (e = 0; e <= EXTRA_LAT; e = e + 1) begin
                val_q[e] <= 1'b0;
                dat_q[e] <= {DW{1'b0}};
            end
        end
        else begin
            val_q[0] <= v2;
            dat_q[0] <= rd_d;
            for (e = 1; e <= EXTRA_LAT; e = e + 1) begin
                val_q[e] <= val_q[e-1];
                dat_q[e] <= dat_q[e-1];
            end
        end
    end

    assign rdata       = dat_q[EXTRA_LAT];
    assign rdata_valid = val_q[EXTRA_LAT];

`ifdef SIMULATION
    integer k;
    initial begin
        if (DEPTH > (1 << AW)) begin
            $display("[param_store] *** ERROR: DEPTH=%0d 超出 AW=%0d 的编址范围 ***",
                     DEPTH, AW);
            $finish;
        end
        if (USE_BSRAM != 0 && USE_BSRAM != 1) begin
            $display("[param_store] *** ERROR: USE_BSRAM 只能 0/1，实得 %0d ***", USE_BSRAM);
            $finish;
        end
        if (MULT_W + KSL_W + TL_W + AR_W + DR_W + SL_W + RR_W
            + KSR_W + EGT_W + WF_W + VIB_W + TREM_W != DW) begin
            $display("[param_store] *** ERROR: 12 个字段位宽之和 != DW=%0d ***", DW);
            $finish;
        end
        for (k = 0; k < DEPTH; k = k + 1)
            mem[k] = INIT_VAL;
    end
`endif

endmodule
