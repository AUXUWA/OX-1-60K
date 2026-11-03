// algo_tab.vh —— 4 算子 FM 的 8 种算法掩码常量表（include 用）

    function [3:0] algo_mod_mask;
        input [2:0] algo;
        input [1:0] op;
        reg [15:0] row;
        begin
            case (algo)
                3'd0:    row = {4'h4, 4'h2, 4'h1, 4'h0};
                3'd1:    row = {4'h0, 4'h2, 4'h1, 4'h0};
                3'd2:    row = {4'h4, 4'h0, 4'h1, 4'h0};
                3'd3:    row = {4'h6, 4'h0, 4'h1, 4'h0};
                3'd4:    row = {4'h0, 4'h0, 4'h0, 4'h0};
                3'd5:    row = {4'h0, 4'h3, 4'h0, 4'h0};
                3'd6:    row = {4'h4, 4'h2, 4'h1, 4'h1};
                3'd7:    row = {4'h1, 4'h8, 4'h4, 4'h2};
                default: row = {4'h0, 4'h0, 4'h0, 4'h0};
            endcase

            case (op)
                2'd0:    algo_mod_mask = row[3:0];
                2'd1:    algo_mod_mask = row[7:4];
                2'd2:    algo_mod_mask = row[11:8];
                2'd3:    algo_mod_mask = row[15:12];
                default: algo_mod_mask = 4'h0;
            endcase
        end
    endfunction

    function [3:0] algo_carrier_mask;
        input [2:0] algo;
        begin
            case (algo)
                3'd0:    algo_carrier_mask = 4'h8;
                3'd1:    algo_carrier_mask = 4'hC;
                3'd2:    algo_carrier_mask = 4'hA;
                3'd3:    algo_carrier_mask = 4'h8;
                3'd4:    algo_carrier_mask = 4'hF;
                3'd5:    algo_carrier_mask = 4'hC;
                3'd6:    algo_carrier_mask = 4'h8;
                3'd7:    algo_carrier_mask = 4'h9;
                default: algo_carrier_mask = 4'h8;
            endcase
        end
    endfunction
