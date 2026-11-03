// eg_state_store —— 每 (声部, 算子) 的包络状态 {eg_rout, eg_gen, key}（12bit）存储

module eg_state_store #(
    parameter integer DEPTH     = 64,
    parameter integer DW        = 12,
    parameter [DW-1:0]  INIT_VAL = 12'hffe,
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

    localparam integer KEY_LSB  = 0;
    localparam integer EG_G_LSB = 1;
    localparam integer EG_R_LSB = 3;
    localparam [1:0]   EG_ATTACK  = 2'd0,
                       EG_DECAY   = 2'd1,
                       EG_SUSTAIN = 2'd2,
                       EG_RELEASE = 2'd3;

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
            $display("[eg_state_store] *** ERROR: DEPTH=%0d 超出 AW=%0d 的编址范围 ***",
                     DEPTH, AW);
            $finish;
        end
        if (USE_BSRAM != 0 && USE_BSRAM != 1) begin
            $display("[eg_state_store] *** ERROR: USE_BSRAM 只能 0/1，实得 %0d ***", USE_BSRAM);
            $finish;
        end
        if (INIT_VAL !== {9'h1ff, EG_RELEASE, 1'b0}) begin
            $display("[eg_state_store] *** ERROR: INIT_VAL=%03h 不是 {eg_rout=0x1ff, eg_gen=RELEASE, key=0} = %03h ***",
                     INIT_VAL, {9'h1ff, EG_RELEASE, 1'b0});
            $display("[eg_state_store] *** 提示  : 按字段表解包 INIT_VAL 得 eg_rout=%03h / eg_gen=%0d / key=%b",
                     INIT_VAL[EG_R_LSB +: 9], INIT_VAL[EG_G_LSB +: 2], INIT_VAL[KEY_LSB]);
            $finish;
        end
        for (k = 0; k < DEPTH; k = k + 1)
            mem[k] = INIT_VAL;
    end
`endif

endmodule
