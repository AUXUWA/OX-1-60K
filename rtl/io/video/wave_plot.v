// wave_plot —— 示波器式波形显示 —— 把音频采样画成"一列一段竖线"的轨迹（右中区域）

`timescale 1ns/1ps

module wave_plot #(
    parameter integer H_ACTIVE   = 1024,
    parameter integer V_ACTIVE   = 600,

    parameter integer X0 = 336,
    parameter integer Y0 = 200,
    parameter integer X1 = 1024,
    parameter integer Y1 = 400,

    parameter integer PAD        = 8,
    parameter integer LINE_THICK = 1,
    parameter integer OUT_LAT    = 4,
    parameter integer WIN        = 1024,
    parameter integer SPAN       = 320,
    parameter integer SIG_MIN    = 6,
    parameter integer SNAP_N     = 641
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        de,
    input  wire [11:0] x,
    input  wire [11:0] y,
    input  wire        sof,

    output wire [9:0]         rd_addr,
    input  wire signed [15:0] pcm,
    input  wire [9:0]         trig_pos,
    input  wire [10:0]        valid_cnt,
    input  wire               trig_valid,

    output wire [23:0] rgb,
    output wire        hit,

    output wire [3:0]  level_msb,

    output wire        busy
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
    localparam [11:0] IWM_C = IW_C - 12'd1;
    localparam [11:0] IHM_C = IH_C >> 1;
    localparam [11:0] IHV_C = IH_C - 12'd1;
    localparam [11:0] IHQ_C = IH_C >> 2;
    localparam [11:0] IH3_C = IH_C - IHQ_C;
    localparam [11:0] LT_C  = LINE_THICK[11:0];
    localparam [11:0] SGM_C = SIG_MIN[11:0];
    localparam [11:0] WINM_C = WIN[11:0] - 12'd1;
    wire        [9:0]  WINM  = WINM_C[9:0];

    localparam [31:0] STEP = ((SPAN * 65536) / IW_C);

    localparam [23:0] C_TRACE = 24'h40FF90,
                      C_AXIS  = 24'h243028,
                      C_GRID  = 24'h151D26,
                      C_WAIT  = 24'h3C444C,
                      C_BG    = 24'h080A0C;

    reg [15:0] colmem [0:IW_C-1];

    reg signed [15:0] snap_mem [0:SNAP_N-1];

    reg [9:0]         snap_addr_r;
    reg signed [15:0] snap_rd;
    always @(posedge clk) begin
        snap_rd <= snap_mem[snap_addr_r];
    end

    function [9:0] snap_idx;
        input [10:0] i;
        begin
            snap_idx = (i < SNAP_N[10:0]) ? i[9:0] : 10'd0;
        end
    endfunction

    reg  [15:0] amp_pk;
    reg  [4:0]  gshift_r;
    reg         guard_r;
    reg [9:0]  midx;

    localparam [9:0] MEAS_LAST = SPAN[9:0];

    reg  [3:0] amax_msb;
    reg  [1:0] g0, g1, g2, g3;
    reg        v0, v1, v2, v3;
    always @(*) begin
        v0 = |amp_pk[3:0];   g0 = amp_pk[3] ? 2'd3 : amp_pk[2] ? 2'd2 : amp_pk[1] ? 2'd1 : 2'd0;
        v1 = |amp_pk[7:4];   g1 = amp_pk[7] ? 2'd3 : amp_pk[6] ? 2'd2 : amp_pk[5] ? 2'd1 : 2'd0;
        v2 = |amp_pk[11:8];  g2 = amp_pk[11] ? 2'd3 : amp_pk[10] ? 2'd2 : amp_pk[9] ? 2'd1 : 2'd0;
        v3 = |amp_pk[15:12]; g3 = amp_pk[15] ? 2'd3 : amp_pk[14] ? 2'd2 : amp_pk[13] ? 2'd1 : 2'd0;
        amax_msb = v3 ? {2'b11, g3} : v2 ? {2'b10, g2} : v1 ? {2'b01, g1} : {2'b00, g0};
    end

    assign level_msb = amax_msb;

    wire [4:0] gshift_w = (amax_msb >= 4'd14) ? 5'd0
                                              : (5'd14 - {1'b0, amax_msb});

    reg  pk_b1;
    integer bi;
    always @(*) begin
        pk_b1 = 1'b0;
        for (bi = 0; bi < 16; bi = bi + 1)
            if (amax_msb == (bi + 1)) pk_b1 = amp_pk[bi];
    end
    wire g_guard_w = (amax_msb == 4'd0) ? 1'b0 : pk_b1;

    wire signed [16:0] pcm_abs = pcm[15] ? -$signed({1'b0, pcm})
                                          :  $signed({1'b0, pcm});
    wire signed [16:0] pk_abs   = $signed({1'b0, amp_pk});

    function [7:0] y_of_sample;
        input signed [15:0] s;
        reg signed [24:0] sx;
        reg signed [24:0] sn;
        reg signed [24:0] m;
        reg signed [24:0] o;
        begin
            sx = {{9{s[15]}}, s};
            if (gshift_r[3:0] != 4'd0) sx = sx <<< gshift_r[3:0];
            sn = sx;
            m  = (sn <<< 7) + (sn <<< 5);
            if (!guard_r)
                m = m + (sn <<< 6) + (sn <<< 4) + sn;
            m  = m >>> 16;
            o  = $signed({13'd0, IHM_C}) - m;
            if (o < 0)             o = 25'sd0;
            if (o > $signed(IHV_C)) o = $signed(IHV_C);
            y_of_sample = o[7:0];
        end
    endfunction

    reg  [7:0]  y0r, y1r;
    reg  [7:0]  prev_y;
    reg  [31:0] acc;

    wire [15:0] idx_full = acc[31:16];
    wire [9:0]  idx_now  = idx_full[9:0];

    wire signed [8:0]  dy_s  = $signed({1'b0, y1r}) - $signed({1'b0, y0r});
    wire signed [16:0] fr_s  = {9'd0, acc[23:16]};
    wire signed [16:0] mul_s = dy_s * fr_s;
    wire signed [16:0] adj_s = mul_s >>> 8;
    wire signed [16:0] ycur_s = $signed({9'd0, y0r}) + adj_s;

    wire [7:0] ycur = (ycur_s < 0)            ? 8'd0 :
                       (ycur_s > $signed(IHV_C)) ? IHV_C[7:0] : ycur_s[7:0];

    wire [7:0] ylo_c = (ycur < prev_y) ? ycur  : prev_y;
    wire [7:0] yhi_c = (ycur < prev_y) ? prev_y : ycur;

    localparam [2:0] CS_IDLE  = 3'd0,
                     CS_MEAS  = 3'd1,
                     CS_MR    = 3'd2,
                     CS_A0    = 3'd3,
                     CS_R0    = 3'd4,
                     CS_R1    = 3'd5,
                     CS_ST    = 3'd6;

    reg [2:0]  cs;
    reg [11:0] cidx;
    reg [9:0]  addr_r;
    reg [7:0]  pk_r;
    reg        trace_live;
    reg [3:0]  quiet_cnt;
    reg [9:0]  base_r;

    assign busy  = (cs != CS_IDLE);
    assign rd_addr = addr_r;

    wire [9:0] trig_next = (trig_pos + 10'd2) & WINM;

    wire [7:0] dev_now = (ycur > IHM_C[7:0]) ? (ycur - IHM_C[7:0])
                                               : (IHM_C[7:0] - ycur);
    wire [7:0] pk_fin  = (pk_r > dev_now) ? pk_r : dev_now;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cs         <= CS_IDLE;
            cidx       <= 12'd0;
            acc        <= 32'd0;
            addr_r     <= 10'd0;
            base_r     <= 10'd0;
            amp_pk     <= 16'd1;
            gshift_r   <= 5'd0;
            guard_r    <= 1'b0;
            midx       <= 10'd0;
            y0r        <= 8'd0;
            y1r        <= 8'd0;
            prev_y     <= 8'd0;
            pk_r       <= 8'd0;
            trace_live <= 1'b0;
            quiet_cnt  <= 4'd0;
        end
        else begin
            case (cs)
            CS_IDLE: begin
                if (sof && trig_valid && (valid_cnt > 0)) begin
                    cidx   <= 12'd0;
                    acc    <= 32'd0;
                    prev_y <= 8'd0;
                    pk_r   <= 8'd0;
                    base_r <= trig_next;
                    amp_pk <= 16'd1;
                    midx   <= 10'd0;
                    cs     <= CS_MEAS;
                end
            end

            CS_MEAS: begin
                addr_r <= (base_r + midx) & WINM;
                cs     <= CS_MR;
            end

            CS_MR: begin
                if (pcm_abs > pk_abs) amp_pk <= pcm_abs[15:0];
                snap_mem[midx] <= pcm;

                if (midx >= MEAS_LAST) begin
                    gshift_r <= (amp_pk < 16'd64) ? 5'd0
                                                  : gshift_w;
                    guard_r  <= (amp_pk < 16'd64) ? 1'b0 : g_guard_w;
                    cidx     <= 12'd0;
                    acc      <= 32'd0;
                    cs       <= CS_A0;
                end
                else begin
                    midx <= midx + 10'd1;
                    cs   <= CS_MEAS;
                end
            end

            CS_A0: begin
                snap_addr_r <= snap_idx(idx_now);
                cs          <= CS_R0;
            end

            CS_R0: begin
                y0r         <= y_of_sample(snap_rd);
                snap_addr_r <= snap_idx(idx_now + 11'd1);
                cs          <= CS_R1;
            end

            CS_R1: begin
                y1r         <= y_of_sample(snap_rd);
                cs          <= CS_ST;
            end

            CS_ST: begin
                colmem[cidx[11:0]] <= (cidx == 12'd0) ? {ycur, ycur}
                                                      : {yhi_c, ylo_c};

                prev_y <= ycur;
                acc    <= acc + STEP;
                pk_r   <= pk_fin;

                if (cidx == IWM_C) begin
                    if (pk_fin >= SGM_C[7:0]) begin
                        trace_live <= 1'b1;
                        quiet_cnt  <= 4'd0;
                    end
                    else if (quiet_cnt == 4'd7) begin
                        trace_live <= 1'b0;
                    end
                    else begin
                        quiet_cnt <= quiet_cnt + 4'd1;
                    end
                    cs <= CS_IDLE;
                end
                else begin
                    cidx <= cidx + 12'd1;
                    cs   <= CS_A0;
                end
            end

            default: cs <= CS_IDLE;
            endcase
        end
    end

    wire in_region = (x >= X0_C) && (x < X1_C) && (y >= Y0_C) && (y < Y1_C);
    wire in_plot   = (x >= IX0_C) && (x < (IX0_C + IW_C)) &&
                     (y >= IY0_C) && (y < (IY0_C + IH_C));

    wire [11:0] col_f  = x - IX0_C;
    wire [11:0] yrow_f = y - IY0_C;

    reg [11:0] col_r1, yrow_r1;
    reg        in_plot_r1;
    reg [11:0] col_r2, yrow_r2;
    reg        in_plot_r2;
    reg [11:0] colmem_rd;
    reg [15:0] span_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_r1 <= 12'd0; yrow_r1 <= 12'd0; in_plot_r1 <= 1'b0;
            col_r2 <= 12'd0; yrow_r2 <= 12'd0; in_plot_r2 <= 1'b0;
        end
        else begin
            col_r1 <= col_f; yrow_r1 <= yrow_f; in_plot_r1 <= in_plot;
            col_r2 <= col_r1; yrow_r2 <= yrow_r1; in_plot_r2 <= in_plot_r1;
        end
    end

    always @(posedge clk) begin
        colmem_rd <= (col_r1 < IW_C) ? col_r1 : 12'd0;
        span_q    <= colmem[colmem_rd];
    end

    wire [11:0] ylo  = {4'd0, span_q[7:0]};
    wire [11:0] yhi  = {4'd0, span_q[15:8]};
    wire [11:0] lo_t = (ylo > LT_C) ? (ylo - LT_C) : 12'd0;
    wire [11:0] hi_t = yhi + LT_C;

    wire trace_on  = in_plot_r2 && (yrow_r2 >= lo_t) && (yrow_r2 <= hi_t);
    wire midline   = in_plot_r2 && (yrow_r2 == IHM_C);
    wire grid_v    = in_plot_r2 && ((col_r2 & 12'd63) == 12'd0);
    wire grid_h    = in_plot_r2 && ((yrow_r2 == IHQ_C) || (yrow_r2 == IH3_C));
    wire wait_dash = in_plot_r2 && (yrow_r2 == IHM_C) && (col_r2[3] == 1'b1);

    reg [23:0] rgb_c;
    reg        hit_c;

    always @(*) begin
        hit_c = 1'b1;
        if (!in_region || !de) begin
            rgb_c = C_BG;
            hit_c = 1'b0;
        end
        else if (trace_live) begin
            if           (trace_on)          rgb_c = C_TRACE;
            else if (grid_v || grid_h)       rgb_c = C_GRID;
            else if (midline)                rgb_c = C_AXIS;
            else                             rgb_c = C_BG;
        end
        else begin
            if      (wait_dash)              rgb_c = C_WAIT;
            else if (grid_v || grid_h)       rgb_c = C_GRID;
            else                             rgb_c = C_BG;
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
