// spectrum_bars —— 频谱柱状图显示（右上区域）

`timescale 1ns/1ps

module spectrum_bars #(
    parameter integer X0 = 336,
    parameter integer Y0 = 0,
    parameter integer X1 = 1024,
    parameter integer Y1 = 200,

    parameter integer NBAND  = 42,
    parameter integer MAGW   = 16,
    parameter integer OUT_LAT = 4,
    parameter integer PAD    = 6,
    parameter integer GAP    = 1,
    parameter integer BWLOG  = 4
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        de,
    input  wire [11:0] x,
    input  wire [11:0] y,

    input  wire [MAGW-1:0] mag_in,
    input  wire [5:0]      band_idx,
    input  wire            mag_we,

    input  wire            trig_valid,
    input  wire [10:0]     valid_cnt,

    output wire [23:0] rgb,
    output wire        hit
);

    localparam [11:0] X0_C  = X0[11:0];
    localparam [11:0] Y0_C  = Y0[11:0];
    localparam [11:0] X1_C  = X1[11:0];
    localparam [11:0] Y1_C  = Y1[11:0];
    localparam [11:0] PAD_C = PAD[11:0];
    localparam [11:0] IX0_C = X0_C + PAD_C;
    localparam [11:0] IY0_C = Y0_C + PAD_C;
    localparam [11:0] IW_C  = X1_C - PAD_C - IX0_C;
    localparam [11:0] IH_C  = Y1_C - PAD_C - IY0_C;
    localparam [11:0] IHV_C = IH_C - 12'd1;
    localparam [11:0] IHH_C = IH_C >> 1;
    localparam [11:0] NB_C  = NBAND[11:0];
    localparam [11:0] BW_C  = (12'd1 << BWLOG[3:0]);
    localparam [11:0] GAP_C = GAP[11:0];

    localparam [23:0] C_BAR   = 24'h30C0FF,
                      C_PEAK  = 24'hFFFF70,
                      C_FLOOR = 24'h1B242E,
                      C_GRID  = 24'h131A22,
                      C_WAIT  = 24'h333A44,
                      C_BG    = 24'h080A0C;

    localparam integer STEPH = IH_C / 8;
    localparam integer FLOOR_MSB = 4;

    function integer mul_step;
        input integer v;
        begin
            mul_step = v + (v << 1) + (v << 2) + (v << 4);
        end
    endfunction

    function [9:0] mag_to_height;
        input [MAGW-1:0] m;
        integer msb;
        integer h;
        integer k;
        integer lo;
        begin
            msb = 0;
            for (k = 0; k < MAGW; k = k + 1)
                if (m[k]) msb = k;

            if (m == 0 || msb < FLOOR_MSB) begin
                h = 0;
            end
            else begin
                lo = 0;
                for (k = 0; k < FLOOR_MSB; k = k + 1)
                    if (m[k]) lo = lo | (1 << k);
                h = mul_step(msb - FLOOR_MSB + 1) + (mul_step(lo) >> FLOOR_MSB);
            end

            if (h < 0)       h = 0;
            if (h > IHV_C) h = IHV_C;
            mag_to_height = h[9:0];
        end
    endfunction

    reg [9:0] barh [0:NBAND-1];

    always @(posedge clk) begin
        if (mag_we && (band_idx < NB_C[5:0])) barh[band_idx] <= mag_to_height(mag_in);
    end

    reg trace_live;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)            trace_live <= 1'b0;
        else if (trig_valid)   trace_live <= 1'b1;
    end

    wire in_region = (x >= X0_C) && (x < X1_C) && (y >= Y0_C) && (y < Y1_C);
    wire in_bars   = (x >= IX0_C) && (x < (IX0_C + IW_C)) &&
                     (y >= IY0_C) && (y < (IY0_C + IH_C));

    wire [11:0] xrel  = x - IX0_C;
    wire [11:0] bwv   = xrel >> BWLOG[3:0];
    wire [5:0]  band_f = bwv[5:0];
    wire [11:0] inbar  = xrel[BWLOG[4:0]-1:0];

    wire [11:0] yrel      = y - IY0_C;
    wire [11:0] from_bot  = IHV_C - yrel;

    wire [9:0]  h_sel  = (band_f < NB_C[5:0]) ? barh[band_f] : 10'd0;
    wire [11:0] h_ext  = {2'b0, h_sel};

    wire body_on = in_bars && (band_f < NB_C[5:0]) &&
                   (inbar < (BW_C - GAP_C)) && (from_bot < h_ext);
    wire peak_on = body_on && (from_bot == (h_ext - 12'd1));

    wire grid_v = in_bars && (band_f[3] == 1'b0) && (inbar == 12'd15);
    wire grid_h = in_bars && ((yrel == (IH_C >> 1)) ||
                              (yrel == (IH_C - (IH_C >> 2))) ||
                              (yrel == (IH_C >> 2)));

    reg [23:0] rgb_c;
    reg        hit_c;

    always @(*) begin
        hit_c = 1'b1;
        if (!in_region || !de) begin
            rgb_c = C_BG;
            hit_c = 1'b0;
        end
        else if (!trace_live || (valid_cnt == 0)) begin
            if      (in_bars && (from_bot == 12'd0)) rgb_c = C_FLOOR;
            else if (grid_v || grid_h)               rgb_c = C_GRID;
            else                                     rgb_c = C_BG;
        end
        else begin
            if      (peak_on)                        rgb_c = C_PEAK;
            else if (body_on)                        rgb_c = C_BAR;
            else if (in_bars && (from_bot == 12'd0)) rgb_c = C_FLOOR;
            else if (grid_v || grid_h)               rgb_c = C_GRID;
            else                                     rgb_c = C_BG;
        end
    end

    reg [24*OUT_LAT-1:0] rgb_pipe;
    reg [OUT_LAT-1:0]    hit_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rgb_pipe <= {24*OUT_LAT{1'b0}};
            hit_pipe <= {OUT_LAT{1'b0}};
        end
        else begin
            rgb_pipe <= (rgb_pipe << 24) | rgb_c;
            hit_pipe <= (hit_pipe << 1)  | hit_c;
        end
    end

    assign rgb = rgb_pipe[23:0];
    assign hit = hit_pipe[0];

endmodule
