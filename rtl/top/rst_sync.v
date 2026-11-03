// rst_sync

`timescale 1ns/1ps

module rst_sync (
    input  wire clk,
    input  wire arst_n,
    output wire rst_n
);

    reg [1:0] sync_reg;

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            sync_reg <= 2'b00;
        else
            sync_reg <= {sync_reg[0], 1'b1};
    end

    assign rst_n = sync_reg[1];

endmodule
