// spectrum_dft —— 滑窗离散傅里叶变换（DFT）—— 为频谱柱状图提供各频段幅度

`timescale 1ns/1ps

module spectrum_dft #(
    parameter integer N        = 512,
    parameter integer NBAND    = 42,
    parameter integer WIN      = 1024,
    parameter integer MAGW     = 16,
    parameter integer MAG_SH   = 24,
    parameter integer FS_STORE = 24414
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    output wire        busy,

    output wire [9:0]         rd_addr,
    input  wire signed [15:0] pcm,
    input  wire [10:0]        valid_cnt,

    output reg  [MAGW-1:0]    mag_out,
    output reg  [5:0]         band_idx,
    output reg                mag_we
);

    localparam [10:0] N_C  = N[10:0];
    localparam [10:0] WINM_C = WIN[11:0] - 12'd1;
    wire  [9:0]       WINM = WINM_C[9:0];

    function signed [15:0] rom_q;
        input [7:0] i;
        begin
            case (i)
            8'd0: rom_q = 16'sd16384;  8'd1: rom_q = 16'sd16379;  8'd2: rom_q = 16'sd16364;
            8'd3: rom_q = 16'sd16340;  8'd4: rom_q = 16'sd16305;  8'd5: rom_q = 16'sd16261;
            8'd6: rom_q = 16'sd16207;  8'd7: rom_q = 16'sd16143;  8'd8: rom_q = 16'sd16069;
            8'd9: rom_q = 16'sd15986;  8'd10: rom_q = 16'sd15893; 8'd11: rom_q = 16'sd15791;
            8'd12: rom_q = 16'sd15679;  8'd13: rom_q = 16'sd15557; 8'd14: rom_q = 16'sd15426;
            8'd15: rom_q = 16'sd15286;  8'd16: rom_q = 16'sd15137; 8'd17: rom_q = 16'sd14978;
            8'd18: rom_q = 16'sd14811;  8'd19: rom_q = 16'sd14635; 8'd20: rom_q = 16'sd14449;
            8'd21: rom_q = 16'sd14256;  8'd22: rom_q = 16'sd14053; 8'd23: rom_q = 16'sd13842;
            8'd24: rom_q = 16'sd13623;  8'd25: rom_q = 16'sd13395; 8'd26: rom_q = 16'sd13160;
            8'd27: rom_q = 16'sd12916;  8'd28: rom_q = 16'sd12665; 8'd29: rom_q = 16'sd12406;
            8'd30: rom_q = 16'sd12140;  8'd31: rom_q = 16'sd11866; 8'd32: rom_q = 16'sd11585;
            8'd33: rom_q = 16'sd11297;  8'd34: rom_q = 16'sd11003; 8'd35: rom_q = 16'sd10702;
            8'd36: rom_q = 16'sd10394;  8'd37: rom_q = 16'sd10080; 8'd38: rom_q = 16'sd9760;
            8'd39: rom_q = 16'sd9434;   8'd40: rom_q = 16'sd9102;  8'd41: rom_q = 16'sd8765;
            8'd42: rom_q = 16'sd8423;   8'd43: rom_q = 16'sd8076;  8'd44: rom_q = 16'sd7723;
            8'd45: rom_q = 16'sd7366;   8'd46: rom_q = 16'sd7005;  8'd47: rom_q = 16'sd6639;
            8'd48: rom_q = 16'sd6270;   8'd49: rom_q = 16'sd5897;  8'd50: rom_q = 16'sd5520;
            8'd51: rom_q = 16'sd5139;   8'd52: rom_q = 16'sd4756;  8'd53: rom_q = 16'sd4370;
            8'd54: rom_q = 16'sd3981;   8'd55: rom_q = 16'sd3590;  8'd56: rom_q = 16'sd3196;
            8'd57: rom_q = 16'sd2801;   8'd58: rom_q = 16'sd2404;  8'd59: rom_q = 16'sd2006;
            8'd60: rom_q = 16'sd1606;   8'd61: rom_q = 16'sd1205;  8'd62: rom_q = 16'sd804;
            8'd63: rom_q = 16'sd402;    8'd64: rom_q = 16'sd0;
            default: rom_q = 16'sd0;
            endcase
        end
    endfunction


    function [8:0] k_of_band;
        input [5:0] b;
        begin
            case (b)
            6'd0: k_of_band = 9'd2;   6'd1: k_of_band = 9'd3;
            6'd2: k_of_band = 9'd4;   6'd3: k_of_band = 9'd5;
            6'd4: k_of_band = 9'd6;   6'd5: k_of_band = 9'd7;
            6'd6: k_of_band = 9'd8;   6'd7: k_of_band = 9'd9;
            6'd8: k_of_band = 9'd10;  6'd9: k_of_band = 9'd11;
            6'd10: k_of_band = 9'd12; 6'd11: k_of_band = 9'd13;
            6'd12: k_of_band = 9'd14; 6'd13: k_of_band = 9'd15;
            6'd14: k_of_band = 9'd16; 6'd15: k_of_band = 9'd17;
            6'd16: k_of_band = 9'd18; 6'd17: k_of_band = 9'd19;
            6'd18: k_of_band = 9'd20; 6'd19: k_of_band = 9'd21;
            6'd20: k_of_band = 9'd22; 6'd21: k_of_band = 9'd25;
            6'd22: k_of_band = 9'd28; 6'd23: k_of_band = 9'd31;
            6'd24: k_of_band = 9'd35; 6'd25: k_of_band = 9'd39;
            6'd26: k_of_band = 9'd44; 6'd27: k_of_band = 9'd50;
            6'd28: k_of_band = 9'd56; 6'd29: k_of_band = 9'd63;
            6'd30: k_of_band = 9'd70; 6'd31: k_of_band = 9'd79;
            6'd32: k_of_band = 9'd89; 6'd33: k_of_band = 9'd100;
            6'd34: k_of_band = 9'd112; 6'd35: k_of_band = 9'd126;
            6'd36: k_of_band = 9'd141; 6'd37: k_of_band = 9'd158;
            6'd38: k_of_band = 9'd178; 6'd39: k_of_band = 9'd200;
            6'd40: k_of_band = 9'd224; 6'd41: k_of_band = 9'd252;
            default: k_of_band = 9'd2;
            endcase
        end
    endfunction

    reg signed [15:0] snap_mem [0:N-1];

    reg [9:0]         snap_addr_r;
    reg signed [15:0] snap_rd;
    always @(posedge clk) begin
        snap_rd <= snap_mem[snap_addr_r];
    end

    localparam [2:0] DS_IDLE = 3'd0,
                     DS_SNAP = 3'd1,
                     DS_SR   = 3'd2,
                     DS_ACC  = 3'd3,
                     DS_DONE = 3'd4;

    reg [2:0]  ds;
    reg        snap_phase;
    reg [9:0]  sidx;
    reg [5:0]  band;
    reg [9:0]  n_idx;
    reg [9:0]  phase;
    reg [9:0]  k_r;
    reg [10:0]  win_base;
    reg signed [39:0] acc_re, acc_im;

    assign busy = (ds != DS_IDLE);

    wire [10:0] ph_sum = {1'b0, phase} + {1'b0, k_r};

    wire [9:0] rd_a = (!snap_phase) ? ((win_base[9:0] + sidx[9:0]) & WINM)
                                   : snap_addr_r;

    assign rd_addr = rd_a;

    localparam integer ROM_SH = (N == 256) ? 0 : (N == 512) ? 1 : (N == 1024) ? 2 : 0;
    wire [7:0] rom_idx = phase[ROM_SH +: 8];

    wire [1:0] quad = rom_idx[7:6];
    wire [5:0] sub  = rom_idx[5:0];
    wire [6:0] refl = 7'd64 - {1'b0, sub};
    wire [6:0] c_idx = quad[0] ? refl : {1'b0, sub};
    wire       c_neg = quad[0] ^ quad[1];
    wire [6:0] s_idx = quad[0] ? {1'b0, sub} : refl;
    wire       s_neg = quad[1];
    wire signed [15:0] c_t = rom_q({1'b0, c_idx});
    wire signed [15:0] s_t = rom_q({1'b0, s_idx});
    wire signed [15:0] cos_v = c_neg ? -c_t : c_t;
    wire signed [15:0] sin_v = s_neg ? -s_t : s_t;

    wire signed [15:0] pcm_ds = snap_phase ? snap_rd : pcm;

    wire signed [31:0] prod_re = pcm_ds * cos_v;
    wire signed [31:0] prod_im = pcm_ds * sin_v;

    wire [39:0] abs_re = acc_re[39] ? (~acc_re + 40'd1) : acc_re;
    wire [39:0] abs_im = acc_im[39] ? (~acc_im + 40'd1) : acc_im;
    wire [39:0] mag_sum = abs_re + abs_im;

    wire [MAGW-1:0] mag_sliced = mag_sum[MAG_SH +: MAGW];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ds       <= DS_IDLE;
            snap_phase <= 1'b0;
            sidx     <= 10'd0;
            band     <= 6'd0;
            n_idx    <= 10'd0;
            phase    <= 10'd0;
            k_r      <= 10'd0;
            win_base <= 11'd0;
            acc_re   <= 40'sd0;
            acc_im   <= 40'sd0;
            mag_out  <= {MAGW{1'b0}};
            band_idx <= 6'd0;
            mag_we   <= 1'b0;
        end
        else begin
            mag_we <= 1'b0;

            case (ds)
            DS_IDLE: begin
                if (start && (valid_cnt >= N_C)) begin
                    band     <= 6'd0;
                    n_idx    <= 10'd0;
                    phase    <= 10'd0;
                    acc_re   <= 40'sd0;
                    acc_im   <= 40'sd0;
                    k_r      <= {1'b0, k_of_band(6'd0)};
                    win_base <= valid_cnt[10:0] - N_C;
                    sidx      <= 10'd0;
                    snap_phase <= 1'b0;
                    ds        <= DS_SNAP;
                end
            end

            DS_SNAP: begin
                ds <= DS_SR;
            end

            DS_SR: begin
                snap_mem[sidx] <= pcm;
                if (sidx >= N_C[9:0] - 10'd1) begin
                    sidx       <= 10'd0;
                    snap_phase <= 1'b1;
                    n_idx      <= 10'd0;
                    phase      <= 10'd0;
                    acc_re     <= 40'sd0;
                    acc_im     <= 40'sd0;
                    band       <= 6'd0;
                    k_r        <= {1'b0, k_of_band(6'd0)};
                    snap_addr_r <= 10'd0;
                    ds         <= DS_ACC;
                end
                else begin
                    sidx <= sidx + 10'd1;
                    ds   <= DS_SNAP;
                end
            end

            DS_ACC: begin
                acc_re <= acc_re + prod_re;
                acc_im <= acc_im + prod_im;

                if (ph_sum >= {1'b0, N_C[9:0]}) phase <= ph_sum[9:0] - N_C[9:0];
                else                            phase <= ph_sum[9:0];

                if (n_idx == (N_C[9:0] - 10'd1)) ds <= DS_DONE;
                else begin
                    n_idx        <= n_idx + 10'd1;
                    snap_addr_r  <= snap_addr_r + 10'd1;
                end
            end

            DS_DONE: begin
                mag_out  <= mag_sliced;
                band_idx <= band;
                mag_we   <= 1'b1;

                if (band == NBAND[5:0] - 6'd1) ds <= DS_IDLE;
                else begin
                    band     <= band + 6'd1;
                    n_idx    <= 10'd0;
                    phase    <= 10'd0;
                    acc_re   <= 40'sd0;
                    acc_im   <= 40'sd0;
                    k_r      <= {1'b0, k_of_band(band + 6'd1)};
                    snap_addr_r <= 10'd0;
                    ds       <= DS_ACC;
                end
            end

            default: ds <= DS_IDLE;
            endcase
        end
    end

endmodule
