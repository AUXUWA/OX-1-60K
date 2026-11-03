// note_store —— note_manager 的每声部音符状态存储（分配器的"账本"）

`timescale 1ns/1ps

module note_store #(
    parameter integer SLOTS = 12
)(
    input  wire                 clk,
    input  wire                 rst_n,

    output wire [SLOTS-1:0]     o_on,
    output wire [SLOTS-1:0]     o_gate,
    output wire [2*SLOTS-1:0]   o_act,
    output wire [5*SLOTS-1:0]   o_note,
    output wire [3*SLOTS-1:0]   o_oct,
    output wire [5*SLOTS-1:0]   o_rank,

    input  wire                 wr_en,
    input  wire [SLOTS-1:0]     wr_sel,
    input  wire                 wr_on,
    input  wire                 wr_gate,
    input  wire [1:0]           wr_act,
    input  wire [4:0]           wr_note,
    input  wire [2:0]           wr_oct,
    input  wire [4:0]           wr_rank,

    input  wire                 rank_inc,
    input  wire [SLOTS-1:0]     rank_inc_mask
);

`ifdef SIMULATION
    initial begin
        if (SLOTS < 1)
            $display("*** ERROR note_store: SLOTS(%0d) < 1", SLOTS);
        if (SLOTS > 25)
            $display("*** ERROR note_store: SLOTS(%0d) > 25 —— 键位只有 25 个（5x5），槽数不该超过它",
                     SLOTS);
    end
`endif

    reg [SLOTS-1:0]     f_on;
    reg [SLOTS-1:0]     f_gate;
    reg [2*SLOTS-1:0]   f_act;
    reg [5*SLOTS-1:0]   f_note;
    reg [3*SLOTS-1:0]   f_oct;

    assign o_on   = f_on;
    assign o_gate = f_gate;
    assign o_act  = f_act;
    assign o_note = f_note;
    assign o_oct  = f_oct;
    assign o_rank = {5*SLOTS{1'b0}};

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f_on   <= {SLOTS{1'b0}};
            f_gate <= {SLOTS{1'b0}};
            f_act  <= {(2*SLOTS){1'b0}};
            f_note <= {(5*SLOTS){1'b0}};
            f_oct  <= {(3*SLOTS){1'b0}};
        end
        else begin
            if (wr_en) begin
                f_on   <= (f_on   & ~wr_sel) | (wr_sel & {SLOTS{wr_on}});
                f_gate <= (f_gate & ~wr_sel) | (wr_sel & {SLOTS{wr_gate}});
                for (i = 0; i < SLOTS; i = i + 1) begin
                    if (wr_sel[i]) begin
                        f_act [2*i +: 2] <= wr_act;
                        f_note[5*i +: 5] <= wr_note;
                        f_oct [3*i +: 3] <= wr_oct;
                    end
                end
            end

        end
    end

endmodule
