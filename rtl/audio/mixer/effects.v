// effects —— 总线混响（4 线 FDN + Haas 展宽）

`timescale 1ns/1ps

module effects #(
    parameter integer DEPTH    = 1024,
    parameter integer PD_DEPTH = 256,
    parameter integer HAAS_N   = 16
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,

    input  wire               reg_we,
    input  wire [7:0]         reg_addr,
    input  wire [7:0]         reg_wdata,

    input  wire signed [15:0] in_l,
    input  wire signed [15:0] in_r,
    output wire signed [15:0] out_l,
    output wire signed [15:0] out_r,

    output wire signed [15:0] wet_l,
    output wire signed [15:0] wet_r
);


    localparam integer LEN0 = 991, LEN1 = 907, LEN2 = 811, LEN3 = 743;

    function [15:0] gval(input [2:0] r, input [1:0] i);
        case ({r, i})
            5'd0:  gval = 16'd25393;  5'd1:  gval = 16'd25870;
            5'd2:  gval = 16'd26187;  5'd3:  gval = 16'd26452;
            5'd4:  gval = 16'd27484;  5'd5:  gval = 16'd27999;
            5'd6:  gval = 16'd28343;  5'd7:  gval = 16'd28629;
            5'd8:  gval = 16'd28380;  5'd9:  gval = 16'd28821;
            5'd10: gval = 16'd29144;  5'd11: gval = 16'd29409;
            5'd12: gval = 16'd29498;  5'd13: gval = 16'd30051;
            5'd14: gval = 16'd30419;  5'd15: gval = 16'd30727;
            5'd16: gval = 16'd30057;  5'd17: gval = 16'd30621;
            5'd18: gval = 16'd30996;  5'd19: gval = 16'd31310;
            5'd20: gval = 16'd30504;  5'd21: gval = 16'd31043;
            5'd22: gval = 16'd31423;  5'd23: gval = 16'd31709;
            5'd24: gval = 16'd30816;  5'd25: gval = 16'd31295;
            5'd26: gval = 16'd31647;  5'd27: gval = 16'd31934;
            5'd28: gval = 16'd31072;  5'd29: gval = 16'd31488;
            5'd30: gval = 16'd31777;  default: gval = 16'd32033;
        endcase
    endfunction

    reg       fx_en;
    reg [2:0] room_reg;
    reg [3:0] damp_reg;
    reg [2:0] wet_reg;
    reg       spread_reg;
    reg [3:0] width_reg;
    reg [7:0] predelay_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fx_en        <= 1'b1;
            room_reg     <= 3'd3;
            damp_reg     <= 4'd8;
            wet_reg      <= 3'd2;
            spread_reg   <= 1'b1;
            width_reg    <= 4'd13;
            predelay_reg <= 8'd0;
        end
        else if (reg_we) begin
            case (reg_addr)
                8'hF0: begin
                    fx_en    <= reg_wdata[0];
                    room_reg <= reg_wdata[3:1];
                    damp_reg <= reg_wdata[7:4];
                end
                8'hF1: begin
                    wet_reg    <= reg_wdata[2:0];
                    spread_reg <= reg_wdata[3];
                    width_reg  <= reg_wdata[7:4];
                end
                8'hF2: predelay_reg <= reg_wdata;
                default: ;
            endcase
        end
    end

    wire       damp_en = (damp_reg != 4'd0);
    wire [1:0] damp_sh = (damp_reg == 4'd1) ? 2'd1 : 2'd2;
    wire signed [17:0] damp_off = (damp_reg == 4'd1) ? 18'sd1 : 18'sd2;

    function signed [17:0] sat18(input signed [20:0] v);
        begin
            if (v > 21'sd131071)            sat18 =  18'sd131071;
            else if (v < -21'sd131072)      sat18 = -18'sd131072;
            else sat18 = v[17:0];
        end
    endfunction

    function signed [15:0] sat16(input signed [17:0] v);
        begin
            if (v > 17'sd32767)             sat16 =  16'sd32767;
            else if (v < -17'sd32768)       sat16 = -16'sd32768;
            else sat16 = v[15:0];
        end
    endfunction

    reg signed [17:0] mem0 [0:DEPTH-1];
    reg signed [17:0] mem1 [0:DEPTH-1];
    reg signed [17:0] mem2 [0:DEPTH-1];
    reg signed [17:0] mem3 [0:DEPTH-1];

    reg [9:0] wptr;
    reg [9:0] raddr0, raddr1, raddr2, raddr3;
    reg       rd_sel;

    wire [9:0] rn0 = wptr - LEN0[9:0];
    wire [9:0] rn1 = wptr - LEN1[9:0];
    wire [9:0] rn2 = wptr - LEN2[9:0];
    wire [9:0] rn3 = wptr - LEN3[9:0];

    localparam [23:0] MOD_STEP0 = 24'd149;
    localparam [23:0] MOD_STEP1 = 24'd197;
    localparam [23:0] MOD_STEP2 = 24'd233;
    localparam [23:0] MOD_STEP3 = 24'd271;
    localparam integer MOD_SH   = 15;

    reg [23:0] ph0, ph1, ph2, ph3;

    wire [22:0] triw0 = ph0[23] ? ~ph0[22:0] : ph0[22:0];
    wire [22:0] triw1 = ph1[23] ? ~ph1[22:0] : ph1[22:0];
    wire [22:0] triw2 = ph2[23] ? ~ph2[22:0] : ph2[22:0];
    wire [22:0] triw3 = ph3[23] ? ~ph3[22:0] : ph3[22:0];

    wire signed [9:0] neg10_0 = -$signed({1'b0, triw0 >> MOD_SH});
    wire signed [9:0] neg10_1 = -$signed({1'b0, triw1 >> MOD_SH});
    wire signed [9:0] neg10_2 = -$signed({1'b0, triw2 >> MOD_SH});
    wire signed [9:0] neg10_3 = -$signed({1'b0, triw3 >> MOD_SH});

    wire signed [8:0] off0 = neg10_0[8:0];
    wire signed [8:0] off1 = neg10_1[8:0];
    wire signed [8:0] off2 = neg10_2[8:0];
    wire signed [8:0] off3 = neg10_3[8:0];

    wire signed [8:0] oi0 = off0 >>> 4;
    wire signed [8:0] oi1 = off1 >>> 4;
    wire signed [8:0] oi2 = off2 >>> 4;
    wire signed [8:0] oi3 = off3 >>> 4;
    wire [3:0] fr0 = off0[3:0];
    wire [3:0] fr1 = off1[3:0];
    wire [3:0] fr2 = off2[3:0];
    wire [3:0] fr3 = off3[3:0];

    wire [9:0] rA0 = rn0 + {{5{oi0[8]}}, oi0[4:0]};
    wire [9:0] rA1 = rn1 + {{5{oi1[8]}}, oi1[4:0]};
    wire [9:0] rA2 = rn2 + {{5{oi2[8]}}, oi2[4:0]};
    wire [9:0] rA3 = rn3 + {{5{oi3[8]}}, oi3[4:0]};
    wire [9:0] rB0 = rA0 + 10'd1;
    wire [9:0] rB1 = rA1 + 10'd1;
    wire [9:0] rB2 = rA2 + 10'd1;
    wire [9:0] rB3 = rA3 + 10'd1;

    reg signed [17:0] d0, d1, d2, d3;
    reg signed [17:0] dA0, dB0, dA1, dB1, dA2, dB2, dA3, dB3;

    wire signed [18:0] df0 = $signed({dB0[17], dB0}) - $signed({dA0[17], dA0});
    wire signed [18:0] df1 = $signed({dB1[17], dB1}) - $signed({dA1[17], dA1});
    wire signed [18:0] df2 = $signed({dB2[17], dB2}) - $signed({dA2[17], dA2});
    wire signed [18:0] df3 = $signed({dB3[17], dB3}) - $signed({dA3[17], dA3});

    wire signed [23:0] vv0 = $signed(df0) * $signed({1'b0, fr0});
    wire signed [23:0] vv1 = $signed(df1) * $signed({1'b0, fr1});
    wire signed [23:0] vv2 = $signed(df2) * $signed({1'b0, fr2});
    wire signed [23:0] vv3 = $signed(df3) * $signed({1'b0, fr3});

    wire signed [23:0] qq0 = dA0 + $signed((vv0 + 24'sd8) >>> 4);
    wire signed [23:0] qq1 = dA1 + $signed((vv1 + 24'sd8) >>> 4);
    wire signed [23:0] qq2 = dA2 + $signed((vv2 + 24'sd8) >>> 4);
    wire signed [23:0] qq3 = dA3 + $signed((vv3 + 24'sd8) >>> 4);
    wire signed [17:0] dq0 = qq0[17:0];
    wire signed [17:0] dq1 = qq1[17:0];
    wire signed [17:0] dq2 = qq2[17:0];
    wire signed [17:0] dq3 = qq3[17:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_sel <= 1'b0;
            raddr0 <= 10'd0; raddr1 <= 10'd0; raddr2 <= 10'd0; raddr3 <= 10'd0;
            d0 <= 18'sd0; d1 <= 18'sd0; d2 <= 18'sd0; d3 <= 18'sd0;
            dA0 <= 18'sd0; dB0 <= 18'sd0; dA1 <= 18'sd0; dB1 <= 18'sd0;
            dA2 <= 18'sd0; dB2 <= 18'sd0; dA3 <= 18'sd0; dB3 <= 18'sd0;
        end
        else begin
            rd_sel <= ~rd_sel;
            raddr0 <= rd_sel ? rA0 : rB0;
            raddr1 <= rd_sel ? rA1 : rB1;
            raddr2 <= rd_sel ? rA2 : rB2;
            raddr3 <= rd_sel ? rA3 : rB3;

            d0 <= mem0[raddr0]; d1 <= mem1[raddr1];
            d2 <= mem2[raddr2]; d3 <= mem3[raddr3];

            if (rd_sel) begin
                dA0 <= d0; dA1 <= d1; dA2 <= d2; dA3 <= d3;
            end else begin
                dB0 <= d0; dB1 <= d1; dB2 <= d2; dB3 <= d3;
            end
        end
    end

    wire signed [16:0] sm  = $signed(in_l) + $signed(in_r);
    wire signed [16:0] sm2 = sm >>> 1;
    wire signed [17:0] xin = $signed({sm2[16], sm2, 1'b0});

    reg signed [17:0] pd_mem [0:PD_DEPTH-1];
    reg [7:0] pdw;
    reg signed [17:0] xpd_r;

    wire signed [17:0] xpd = (predelay_reg == 8'd0) ? xin : xpd_r;

    wire [7:0] pd_rr = pdw - predelay_reg + 8'd1;

    reg signed [17:0] yp0, yp1, yp2, yp3;

    wire signed [18:0] e0 = $signed({yp0[17], yp0}) - $signed({dq0[17], dq0})
                            + $signed({damp_off[17], damp_off});
    wire signed [18:0] e1 = $signed({yp1[17], yp1}) - $signed({dq1[17], dq1})
                            + $signed({damp_off[17], damp_off});
    wire signed [18:0] e2 = $signed({yp2[17], yp2}) - $signed({dq2[17], dq2})
                            + $signed({damp_off[17], damp_off});
    wire signed [18:0] e3 = $signed({yp3[17], yp3}) - $signed({dq3[17], dq3})
                            + $signed({damp_off[17], damp_off});

    wire signed [17:0] y0 = damp_en ? (yp0 - $signed(e0 >>> damp_sh)) : dq0;
    wire signed [17:0] y1 = damp_en ? (yp1 - $signed(e1 >>> damp_sh)) : dq1;
    wire signed [17:0] y2 = damp_en ? (yp2 - $signed(e2 >>> damp_sh)) : dq2;
    wire signed [17:0] y3 = damp_en ? (yp3 - $signed(e3 >>> damp_sh)) : dq3;

    wire signed [34:0] p0 = $signed({16'd0, gval(room_reg, 2'd0)}) * $signed({y0[17], y0});
    wire signed [34:0] p1 = $signed({16'd0, gval(room_reg, 2'd1)}) * $signed({y1[17], y1});
    wire signed [34:0] p2 = $signed({16'd0, gval(room_reg, 2'd2)}) * $signed({y2[17], y2});
    wire signed [34:0] p3 = $signed({16'd0, gval(room_reg, 2'd3)}) * $signed({y3[17], y3});

    wire signed [17:0] f0 = (p0 + 35'sd16384) >>> 15;
    wire signed [17:0] f1 = (p1 + 35'sd16384) >>> 15;
    wire signed [17:0] f2 = (p2 + 35'sd16384) >>> 15;
    wire signed [17:0] f3 = (p3 + 35'sd16384) >>> 15;

    wire signed [18:0] u0 = $signed({f0[17], f0}) + $signed({f1[17], f1});
    wire signed [18:0] u1 = $signed({f0[17], f0}) - $signed({f1[17], f1});
    wire signed [18:0] u2 = $signed({f2[17], f2}) + $signed({f3[17], f3});
    wire signed [18:0] u3 = $signed({f2[17], f2}) - $signed({f3[17], f3});

    wire signed [19:0] w0 = $signed({u0[18], u0}) + $signed({u2[18], u2});
    wire signed [19:0] w1 = $signed({u1[18], u1}) + $signed({u3[18], u3});
    wire signed [19:0] w2 = $signed({u0[18], u0}) - $signed({u2[18], u2});
    wire signed [19:0] w3 = $signed({u1[18], u1}) - $signed({u3[18], u3});

    wire signed [17:0] m0 = (w0 + 20'sd1) >>> 1;
    wire signed [17:0] m1 = (w1 + 20'sd1) >>> 1;
    wire signed [17:0] m2 = (w2 + 20'sd1) >>> 1;
    wire signed [17:0] m3 = (w3 + 20'sd1) >>> 1;

    wire signed [20:0] ysum = $signed({y0[17], y0}) + $signed({y1[17], y1})
                            + $signed({y2[17], y2}) + $signed({y3[17], y3});
    wire signed [17:0] wet18 = (ysum + 21'sd2) >>> 2;

    wire signed [20:0] wr0 = $signed({m0[17], m0}) + $signed({xpd[17], xpd});
    wire signed [20:0] wr1 = $signed({m1[17], m1}) + $signed({xpd[17], xpd});
    wire signed [20:0] wr2 = $signed({m2[17], m2}) + $signed({xpd[17], xpd});
    wire signed [20:0] wr3 = $signed({m3[17], m3}) + $signed({xpd[17], xpd});

    reg signed [15:0] hpipe [0:HAAS_N-1];
    reg signed [15:0] wet16;

    wire signed [15:0] wet16_next = sat16(($signed({wet18[17], wet18}) + 19'sd1) >>> 1);

    wire signed [15:0] wl16 = wet16;
    wire signed [15:0] wr16 = spread_reg ? hpipe[width_reg[3:0]] : wet16;

    wire signed [15:0] wl_s = (wet_reg[0] ? (wl16 >>> 3) : 16'sd0)
                            + (wet_reg[1] ? (wl16 >>> 2) : 16'sd0)
                            + (wet_reg[2] ? (wl16 >>> 1) : 16'sd0);
    wire signed [15:0] wr_s = (wet_reg[0] ? (wr16 >>> 3) : 16'sd0)
                            + (wet_reg[1] ? (wr16 >>> 2) : 16'sd0)
                            + (wet_reg[2] ? (wr16 >>> 1) : 16'sd0);

    wire wet_on = fx_en & (wet_reg != 3'd0);

    assign wet_l = wet_on ? wl_s : 16'sd0;
    assign wet_r = wet_on ? wr_s : 16'sd0;

    assign out_l = sat16($signed({in_l[15], in_l}) + $signed({{2{wl_s[15]}}, wl_s}));
    assign out_r = sat16($signed({in_r[15], in_r}) + $signed({{2{wr_s[15]}}, wr_s}));

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr   <= 10'd0;
            pdw    <= 8'd0;
            xpd_r  <= 18'sd0;
            yp0 <= 18'sd0; yp1 <= 18'sd0; yp2 <= 18'sd0; yp3 <= 18'sd0;
            ph0 <= 24'd0; ph1 <= 24'd0; ph2 <= 24'd0; ph3 <= 24'd0;
            wet16  <= 16'sd0;
`ifdef SIMULATION
            for (i = 0; i < DEPTH; i = i + 1) begin
                mem0[i] <= 18'sd0; mem1[i] <= 18'sd0;
                mem2[i] <= 18'sd0; mem3[i] <= 18'sd0;
            end
            for (i = 0; i < PD_DEPTH; i = i + 1) pd_mem[i] <= 18'sd0;
            for (i = 0; i < HAAS_N; i = i + 1)   hpipe[i]  <= 16'sd0;
`endif
        end
        else if (sample_tick) begin
            mem0[wptr] <= sat18(wr0);
            mem1[wptr] <= sat18(wr1);
            mem2[wptr] <= sat18(wr2);
            mem3[wptr] <= sat18(wr3);
            wptr <= wptr + 1'b1;

            yp0 <= y0; yp1 <= y1; yp2 <= y2; yp3 <= y3;

            ph0 <= ph0 + MOD_STEP0;
            ph1 <= ph1 + MOD_STEP1;
            ph2 <= ph2 + MOD_STEP2;
            ph3 <= ph3 + MOD_STEP3;

            pd_mem[pdw] <= xin;
            xpd_r <= pd_mem[pd_rr];
            pdw <= pdw + 1'b1;

            wet16 <= wet16_next;
            for (i = HAAS_N - 1; i > 0; i = i - 1) hpipe[i] <= hpipe[i-1];
            hpipe[0] <= wet16_next;
        end
    end

endmodule
