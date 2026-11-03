// eg_incstep_tab.vh —— OPL3 常量表函数集合（原版逐字对应）—— include 用

    function [7:0] mt_lut;
        input [3:0] m;
        begin
            case (m)
                4'd0:  mt_lut = 8'd1;   4'd1:  mt_lut = 8'd2;
                4'd2:  mt_lut = 8'd4;   4'd3:  mt_lut = 8'd6;
                4'd4:  mt_lut = 8'd8;   4'd5:  mt_lut = 8'd10;
                4'd6:  mt_lut = 8'd12;  4'd7:  mt_lut = 8'd14;
                4'd8:  mt_lut = 8'd16;  4'd9:  mt_lut = 8'd18;
                4'd10: mt_lut = 8'd20;  4'd11: mt_lut = 8'd20;
                4'd12: mt_lut = 8'd24;  4'd13: mt_lut = 8'd24;
                4'd14: mt_lut = 8'd30;  4'd15: mt_lut = 8'd30;
            endcase
        end
    endfunction

    function [7:0] kslrom_lut;
        input [3:0] a;
        begin
            case (a)
                4'd0:  kslrom_lut = 8'd0;   4'd1:  kslrom_lut = 8'd32;
                4'd2:  kslrom_lut = 8'd40;  4'd3:  kslrom_lut = 8'd45;
                4'd4:  kslrom_lut = 8'd48;  4'd5:  kslrom_lut = 8'd51;
                4'd6:  kslrom_lut = 8'd53;  4'd7:  kslrom_lut = 8'd55;
                4'd8:  kslrom_lut = 8'd56;  4'd9:  kslrom_lut = 8'd58;
                4'd10: kslrom_lut = 8'd59;  4'd11: kslrom_lut = 8'd60;
                4'd12: kslrom_lut = 8'd61;  4'd13: kslrom_lut = 8'd62;
                4'd14: kslrom_lut = 8'd63;  4'd15: kslrom_lut = 8'd64;
            endcase
        end
    endfunction

    function [3:0] kslshift_lut;
        input [1:0] k;
        begin
            case (k)
                2'd0: kslshift_lut = 4'd8;
                2'd1: kslshift_lut = 4'd1;
                2'd2: kslshift_lut = 4'd2;
                2'd3: kslshift_lut = 4'd0;
            endcase
        end
    endfunction

    function [2:0] eg_incstep_lut;
        input [1:0] rate_lo;
        input [1:0] timer_lo;
        reg [2:0] v;
        begin
            case (rate_lo)
                2'd0: v = 3'd0;
                2'd1: v = (timer_lo == 2'd0) ? 3'd1 : 3'd0;
                2'd2: v = ((timer_lo == 2'd0) || (timer_lo == 2'd2)) ? 3'd1 : 3'd0;
                2'd3: v = (timer_lo == 2'd3) ? 3'd0 : 3'd1;
            endcase
            eg_incstep_lut = v;
        end
    endfunction
