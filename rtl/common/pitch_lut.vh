// 半音号 → (FNUM, 八度偏移, BLOCK) 的共享真值表（include 用）

function [9:0] fnum_of;
    input [3:0] n;
    begin
        case (n)
            4'd0 : fnum_of = 10'd351;
            4'd1 : fnum_of = 10'd372;
            4'd2 : fnum_of = 10'd394;
            4'd3 : fnum_of = 10'd417;
            4'd4 : fnum_of = 10'd442;
            4'd5 : fnum_of = 10'd468;
            4'd6 : fnum_of = 10'd496;
            4'd7 : fnum_of = 10'd526;
            4'd8 : fnum_of = 10'd557;
            4'd9 : fnum_of = 10'd590;
            4'd10: fnum_of = 10'd625;
            4'd11: fnum_of = 10'd662;
            default: fnum_of = 10'd590;
        endcase
    end
endfunction

function [1:0] oct_add_of;
    input [4:0] n;
    begin
        oct_add_of = (n >= 5'd24) ? 2'd2 : (n >= 5'd12) ? 2'd1 : 2'd0;
    end
endfunction

function [4:0] sem_of;
    input [4:0] n;
    begin
        sem_of = (n >= 5'd24) ? (n - 5'd24) : (n >= 5'd12) ? (n - 5'd12) : n;
    end
endfunction

function [2:0] oct_eff;
    input [2:0] base_oct;
    input [4:0] n;
    reg [2:0] t;
    begin
        t = base_oct + {1'b0, oct_add_of(n)};
        oct_eff = (t > 3'd5) ? 3'd5 : t;
    end
endfunction
