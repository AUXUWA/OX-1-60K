// perf_mod

module perf_mod #(
    parameter integer GLIDE_MS      = 120,
    parameter [13:0]  GLIDE_TICKS   = 14'd5859,
    parameter [12:0]  VIB_FULL      = 13'd4096,
    parameter [8:0]   VIB_DIV       = 9'd305,
    parameter integer VIB_SH        = 11,
    parameter [7:0]   VIB_DEPTH_DEF = 8'd0,
    parameter [7:0]   VIB_DEPTH_MAX = 8'd8
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    input  wire [9:0]  fnum_tgt,
    input  wire        wr_hit,
    input  wire        glide_en,
    input  wire        vib_en,
    input  wire [7:0]  vib_depth,
    input  wire        blk_chg,
    output wire [9:0]  fnum_eff,
    output wire        busy
);

`ifdef SIMULATION
    initial begin
        if (GLIDE_TICKS == 0) $display("*** ERROR perf_mod: GLIDE_TICKS 不能为 0");
        if (VIB_DIV     == 0) $display("*** ERROR perf_mod: VIB_DIV 不能为 0");
        if (VIB_DEPTH_MAX == 0) $display("*** ERROR perf_mod: VIB_DEPTH_MAX 不能为 0");
    end
`endif

    localparam [13:0] DEN     = GLIDE_TICKS;
    localparam [12:0] ONE_DN  = 13'd1;

    reg  [9:0]  fnum_cur;
    reg  [9:0]  fnum_tgt_r;
    reg  [9:0]  gl_num;
    reg         gl_dir;
    reg  [12:0] gl_rem;
    reg         gl_run;
    reg         gl_run_d;
    reg         gl_seen;

    wire [9:0]  gl_delta = (fnum_tgt > fnum_cur) ? (fnum_tgt - fnum_cur)
                                                 : (fnum_cur - fnum_tgt);
    wire        gl_up    = (fnum_tgt > fnum_cur);
    wire        new_tgt  = wr_hit && (fnum_tgt != fnum_tgt_r);
    wire        gl_jump  = new_tgt && (!glide_en || blk_chg || !gl_seen);

    wire [13:0] rem_sum = {1'b0, gl_rem} + {4'b0, gl_num};
    wire        rem_bump = (rem_sum >= DEN);
    wire [12:0] rem_nxt = rem_bump ? (rem_sum[12:0] - DEN[12:0]) : rem_sum[12:0];
    wire [9:0]  cur_nxt = rem_bump ? (gl_dir ? (fnum_cur + 10'd1) : (fnum_cur - 10'd1))
                                   : fnum_cur;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fnum_cur   <= 10'd0;
            fnum_tgt_r <= 10'd0;
            gl_num     <= 10'd0;
            gl_dir     <= 1'b0;
            gl_rem     <= 13'd0;
            gl_run     <= 1'b0;
            gl_run_d   <= 1'b0;
            gl_seen    <= 1'b0;
        end
        else begin
            gl_run_d <= gl_run;
            if (new_tgt) begin
                fnum_tgt_r <= fnum_tgt;
                gl_seen    <= 1'b1;
                if (gl_jump) begin
                    fnum_cur <= fnum_tgt;
                    gl_num   <= 10'd0;
                    gl_rem   <= 13'd0;
                    gl_run   <= 1'b0;
                end
                else begin
                    gl_num <= gl_delta;
                    gl_dir <= gl_up;
                    gl_rem <= 13'd0;
                    gl_run <= (gl_delta != 10'd0);
                end
            end
            else if (!glide_en) begin
                fnum_cur <= fnum_tgt_r;
                gl_run   <= 1'b0;
                gl_rem   <= 13'd0;
            end
            else if (gl_run && sample_tick) begin
                fnum_cur <= cur_nxt;
                gl_rem   <= rem_nxt;
                if (cur_nxt == fnum_tgt_r) gl_run <= 1'b0;
            end
        end
    end

    localparam [8:0] VIB_DIV_LAST = VIB_DIV - 9'd1;

    reg  [8:0]  vib_div;
    reg  [12:0] vib_ph;
    reg         vib_dir;
    reg  [7:0]  vib_depth_eff;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vib_div       <= 9'd0;
            vib_ph        <= 13'd0;
            vib_dir       <= 1'b1;
            vib_depth_eff <= VIB_DEPTH_DEF;
        end
        else begin
            vib_depth_eff <= (vib_depth > VIB_DEPTH_MAX) ? VIB_DEPTH_MAX : vib_depth;
            if (vib_div == VIB_DIV_LAST) begin
                vib_div <= 9'd0;
                if (vib_dir) begin
                    if (vib_ph >= VIB_FULL) begin
                        vib_dir <= 1'b0;
                        vib_ph  <= vib_ph - ONE_DN;
                    end
                    else vib_ph <= vib_ph + ONE_DN;
                end
                else begin
                    if (vib_ph == 13'd0) begin
                        vib_dir <= 1'b1;
                        vib_ph  <= vib_ph + ONE_DN;
                    end
                    else vib_ph <= vib_ph - ONE_DN;
                end
            end
            else vib_div <= vib_div + 9'd1;
        end
    end

    localparam [19:0] VIB_ROUND = (1 << VIB_SH) >> 1;

    reg [19:0] dsp_mul_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) dsp_mul_r <= 20'd0;
        else        dsp_mul_r <= vib_ph * vib_depth_eff;
    end

    wire [19:0]        dsp_round = dsp_mul_r + VIB_ROUND;
    wire [9:0]         vib_mag   = dsp_round >> VIB_SH;
    wire signed [10:0] vib_mag_s = $signed({1'b0, vib_mag});
    wire signed [10:0] vib_off   = vib_dir ? vib_mag_s : -vib_mag_s;

    wire [9:0] gl_base = (!glide_en) ? fnum_tgt
                       : (gl_jump   ? fnum_tgt : fnum_cur);
    wire signed [11:0] vib_sum_s = $signed({1'b0, gl_base}) + vib_off;
    wire [9:0]         vib_sum   = (vib_sum_s < 0)             ? 10'd0
                                 : (vib_sum_s > 12'sd1023)     ? 10'd1023
                                 : vib_sum_s[9:0];

    assign fnum_eff = vib_en ? vib_sum : gl_base;
    assign busy     = glide_en & (gl_run | gl_run_d);

endmodule
