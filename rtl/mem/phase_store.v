// phase_store —— 每 (声部, 算子) 的相位状态 pg_phase（24bit）存储 —— TDM 读，固定延迟

module phase_store #(
    parameter integer DEPTH     = 64,
    parameter integer DW        = 24,
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
            $display("[phase_store] *** ERROR: DEPTH=%0d 超出 AW=%0d 的编址范围 ***",
                     DEPTH, AW);
            $finish;
        end
        if (USE_BSRAM != 0 && USE_BSRAM != 1) begin
            $display("[phase_store] *** ERROR: USE_BSRAM 只能 0/1，实得 %0d ***", USE_BSRAM);
            $finish;
        end
        for (k = 0; k < DEPTH; k = k + 1)
            mem[k] = INIT_VAL;
    end
`endif

endmodule
