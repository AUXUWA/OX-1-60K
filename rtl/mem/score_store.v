// score_store

`default_nettype none

module score_store #(
    parameter integer DEPTH = 256
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [7:0]  wr_addr,
    input  wire [39:0] wr_data,
    input  wire        clear_pulse,
    output reg         clear_busy,
    output reg         clear_done,
    input  wire [7:0]  rd_addr,
    output reg  [39:0] rd_data
);

    localparam integer AW = (DEPTH <= 256) ? 8 : 16;
    localparam [AW-1:0] LAST_ADDR = DEPTH - 1;

    reg [39:0] mem [0:DEPTH-1];

    reg [AW-1:0] clr_cnt;
    reg          clr_run;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clr_cnt    <= {AW{1'b0}};
            clr_run    <= 1'b0;
            clear_busy <= 1'b0;
            clear_done <= 1'b0;
            rd_data    <= 40'd0;
        end
        else begin
            clear_done <= 1'b0;

            if (clr_run) begin
                mem[clr_cnt] <= 40'd0;
                if (clr_cnt == LAST_ADDR) begin
                    clr_run    <= 1'b0;
                    clear_busy <= 1'b0;
                    clear_done <= 1'b1;
                end
                else begin
                    clr_cnt <= clr_cnt + 1'b1;
                end
            end
            else if (clear_pulse) begin
                clr_run    <= 1'b1;
                clear_busy <= 1'b1;
                clr_cnt    <= {AW{1'b0}};
            end
            else if (wr_en) begin
                mem[wr_addr] <= wr_data;
            end

            rd_data <= mem[rd_addr];
        end
    end

`ifdef SIMULATION
    initial begin
        if (DEPTH != 256)
            $display("*** WARN score_store: DEPTH=%0d（协议上限 256）", DEPTH);
    end
`endif

endmodule

`default_nettype wire
