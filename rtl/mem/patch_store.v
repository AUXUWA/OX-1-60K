// patch_store

`timescale 1ns/1ps

module patch_store #(
    parameter integer N_SLOT = 16,
    parameter integer N_WR   = 27,
    parameter integer IDX_W  = 5,
    parameter integer RD_LAT = 0,
    localparam integer SLOT_W = $clog2(N_SLOT),
    localparam integer MEM_AW = SLOT_W + IDX_W
)(
    input  wire                clk,
    input  wire                rst_n,

    input  wire                wr_en,
    input  wire [SLOT_W-1:0]   wr_slot,
    input  wire [IDX_W-1:0]    wr_idx,
    input  wire [15:0]         wr_word,

    input  wire                clr_en,
    input  wire [SLOT_W-1:0]   clr_slot,

    input  wire [4:0]          sel,
    output wire                sel_rdy,
    input  wire [IDX_W-1:0]    rd_idx,
    output wire [15:0]         rd_word,
    output wire [N_SLOT-1:0]   valid_bits,
    output wire                sel_valid,
    output wire                rd_ok
);

    reg [15:0] mem [0:(1<<MEM_AW)-1];

    always @(posedge clk) begin
        if (wr_en)
            mem[{wr_slot, wr_idx}] <= wr_word;
    end

    wire [SLOT_W-1:0] sel_local = sel[3:0] - 4'd8;
    wire              sel_is_user = (sel >= 5'd8) && (sel < (5'd8 + N_SLOT));

    generate
    if (RD_LAT == 0) begin : g_shadow
    reg [15:0] shadow [0:N_WR-1];
    reg [IDX_W-1:0] ld_cnt;
    reg             rdy_r;

    reg  [SLOT_W-1:0] sh_slot;
    reg               sh_vld;

    localparam [1:0] L_IDLE = 2'd0, L_ISSUE = 2'd1,
                     L_CAPT  = 2'd2, L_DONE  = 2'd3;
    reg [1:0] l_st;

    reg [15:0] rd_raw;
    always @(posedge clk) begin
        rd_raw <= mem[{sel_local, ld_cnt}];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ld_cnt  <= {IDX_W{1'b0}};
            l_st    <= L_IDLE;
            rdy_r   <= 1'b1;
            sh_slot <= {SLOT_W{1'b0}};
            sh_vld  <= 1'b0;
        end
        else begin
            if (wr_en && sh_vld && (wr_slot == sh_slot) && (wr_idx < N_WR))
                shadow[wr_idx] <= wr_word;

            case (l_st)
                L_IDLE: begin
                    if (sel_is_user && (!sh_vld || (sh_slot != sel_local))) begin
                        ld_cnt <= {IDX_W{1'b0}};
                        rdy_r  <= 1'b0;
                        l_st   <= L_ISSUE;
                    end
                    else begin
                        rdy_r <= 1'b1;
                    end
                end
                L_ISSUE: begin
                    l_st <= L_CAPT;
                end
                L_CAPT: begin
                    shadow[ld_cnt] <= rd_raw;
                    if (ld_cnt == (N_WR-1)) begin
                        sh_slot <= sel_local;
                        sh_vld  <= 1'b1;
                        l_st    <= L_DONE;
                    end
                    else begin
                        ld_cnt <= ld_cnt + {{(IDX_W-1){1'b0}}, 1'b1};
                        l_st   <= L_ISSUE;
                    end
                end
                L_DONE: begin
                    rdy_r <= 1'b1;
                    l_st  <= L_IDLE;
                end
                default: l_st <= L_IDLE;
            endcase
        end
    end

    assign sel_rdy  = sel_is_user ? rdy_r : 1'b1;
    assign rd_word  = (rd_idx < N_WR) ? shadow[rd_idx] : 16'h0000;
    assign rd_ok    = 1'b1;
    end
    else begin : g_direct
    reg [15:0] mem_q;
    reg [MEM_AW-1:0] addr_d;
    always @(posedge clk) begin
        mem_q  <= mem[{sel_local, rd_idx}];
        addr_d <= {sel_local, rd_idx};
    end
    assign rd_word = mem_q;
    assign rd_ok   = (addr_d == {sel_local, rd_idx});
    assign sel_rdy = 1'b1;
    end
    endgenerate

    reg [N_SLOT-1:0] valid_r;
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_r <= {N_SLOT{1'b0}};
        end
        else begin
            if (clr_en) valid_r[clr_slot] <= 1'b0;
            if (wr_en && (wr_idx == (N_WR-1))) valid_r[wr_slot] <= 1'b1;
        end
    end

    assign valid_bits = valid_r;
    assign sel_valid  = sel_is_user ? valid_r[sel_local] : 1'b1;

`ifdef SIMULATION
    initial begin
        if (N_WR != 27) begin
            $display("[patch_store] *** ERROR: N_WR 必须 = 27（SPEC §14.2），实得 %0d ***", N_WR);
            $finish;
        end
        if (N_SLOT != 16) begin
            $display("[patch_store] *** ERROR: N_SLOT 必须 = 16（SPEC §14.1 用户槽 8..23），实得 %0d ***", N_SLOT);
            $finish;
        end
    end
`endif

endmodule
