// demo_note + patch_led_bridge —— ★ 最小"能出声"验证控制器（本轮临时件，下一轮由 note_manager/音序器取代）

module demo_note #(
    parameter integer SYS_HZ      = 12_500_000,
    parameter integer SETTLE_MS   = 50,
    parameter integer GAP_CLK     = 16,
    parameter integer IDX_TGL_DLY = 32,
    parameter         KEYPAD_OWNS_B0 = 1'b1
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       cfg_ok,
    input  wire       gate,
    input  wire       ev_algo,
    input  wire       ev_wave,
    input  wire       preset_up,
    input  wire       preset_dn,
    input  wire        pt_wr,
    input  wire [1:0]  pt_kind,
    input  wire [4:0]  pt_a,
    input  wire [4:0]  pt_b,
    input  wire [15:0] pt_word,
    output wire [15:0] pt_valid_bits,
    input  wire       seq4part,
    input  wire       reg_gnt,

    output reg        reg_we,
    output reg [7:0]  reg_addr,
    output reg [7:0]  reg_wdata,

    output wire       load_active,

    output reg [4:0]  cur_patch,
    output reg        patch_idx_tgl,
    output reg [2:0]  cur_algo,
    output reg [2:0]  cur_wave
);




    localparam integer SETTLE_CLK = (SYS_HZ / 1000) * SETTLE_MS;
    localparam integer SEQ_LEN    = 27;

    localparam integer QUAD_PARTS = 4;
    localparam integer QUAD_SEQ   = 27;
    localparam [1:0]  QUAD_LAST_PART = 2'd3;

    function [2:0] quad_patch_of;
        input [1:0] p;
        begin
            case (p)
                2'd0:    quad_patch_of = 3'd1;
                2'd1:    quad_patch_of = 3'd6;
                2'd2:    quad_patch_of = 3'd4;
                default: quad_patch_of = 3'd5;
            endcase
        end
    endfunction

    localparam [2:0] ST_SETTLE = 3'd0,
                     ST_LOAD   = 3'd1,
                     ST_RUN    = 3'd2;
    localparam [2:0] ST_QUAD   = 3'd3;

    reg [2:0]  st;
    reg [19:0] settle_cnt;
    reg [4:0]  seq_idx;
    reg [7:0]  gap_cnt;
    reg        keyon;
    reg [7:0]  fnum_lo_r;
    reg [7:0]  b0_base_r;

    reg [1:0]  q_part;
    reg [4:0]  q_step;
    reg        q_fin;
    reg        q_pend;
    reg        seq4part_d;

    assign load_active = (st == ST_LOAD) || (st == ST_QUAD);

    wire       seq4part_on = seq4part;
    wire       seq4part_rise = seq4part_on & (~seq4part_d);

    wire [15:0] rom_word;
    wire [2:0]  rom_algo = rom_word[2:0];

    wire [2:0]  quad_patch = quad_patch_of(q_part);
    wire [4:0]  quad_idx   = q_step - 5'd1;
    wire        in_quad    = (st == ST_QUAD);

    wire        pt_wr_ok   = (pt_wr === 1'b1);

    wire [4:0]  bank_patch = in_quad ? {2'b00, quad_patch} : cur_patch;
    wire [4:0]  bank_idx   = in_quad ? quad_idx   : seq_idx;
    wire        use_user   = (bank_patch >= 5'd8);

    wire [15:0] fac_word;
    patch_bank u_bank (
        .patch      (bank_patch[2:0]),
        .idx        (bank_idx),
        .patch_word (fac_word)
    );

    wire [15:0] user_word;
    wire [15:0] ps_vbits;
    wire        ps_sel_rdy;
    wire        ps_rd_ok;
    patch_store #(
        .RD_LAT     (1)
    ) u_pstore (
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (pt_wr_ok && (pt_kind == 2'd0)),
        .wr_slot    (pt_a[3:0]),
        .wr_idx     (pt_b[4:0]),
        .wr_word    (pt_word),
        .clr_en     (pt_wr_ok && (pt_kind == 2'd1)),
        .clr_slot   (pt_a[3:0]),
        .sel        (cur_patch),
        .sel_rdy    (ps_sel_rdy),
        .rd_idx     (bank_idx),
        .rd_word    (user_word),
        .valid_bits (ps_vbits),
        .sel_valid  (),
        .rd_ok      (ps_rd_ok)
    );

    assign rom_word      = use_user ? user_word : fac_word;
    assign pt_valid_bits = ps_vbits;

    function slot_ok;
        input [4:0] p;
        begin
            slot_ok = (p < 5'd8) ? 1'b1 : ps_vbits[p - 5'd8];
        end
    endfunction


    function [15:0] nl_below;
        input [4:0] n;
        integer kk;
        begin
            for (kk = 0; kk < 16; kk = kk + 1)
                nl_below[kk] = (kk < n);
        end
    endfunction

    function [4:0] nl_lowest;
        input [15:0] m;
        integer kk;
        begin
            nl_lowest = 5'd0;
            for (kk = 15; kk >= 0; kk = kk - 1)
                if (m[kk]) nl_lowest = kk;
        end
    endfunction

    function [4:0] nl_highest;
        input [15:0] m;
        integer kk;
        begin
            nl_highest = 5'd0;
            for (kk = 0; kk < 16; kk = kk + 1)
                if (m[kk]) nl_highest = kk;
        end
    endfunction

    function [4:0] next_loaded;
        input [4:0] from;
        input       up;
        reg [15:0]  lt, gt;
        begin
            lt = ps_vbits &  nl_below(from - 5'd8);
            gt = ps_vbits & ~nl_below(from - 5'd7);
            if (from >= 5'd24) begin
                next_loaded = from;
            end
            else if (up) begin
                if (from <= 5'd6)     next_loaded = from + 5'd1;
                else if (gt != 16'd0) next_loaded = 5'd8 + nl_lowest(gt);
                else                  next_loaded = 5'd0;
            end
            else begin
                if ((from >= 5'd1) && (from <= 5'd8)) next_loaded = from - 5'd1;
                else if (lt != 16'd0)                 next_loaded = 5'd8 + nl_highest(lt);
                else                                  next_loaded = 5'd7;
            end
        end
    endfunction

    reg [4:0]  patch_prev;
    reg [7:0]  tgl_dly;
    reg        tgl_pend;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            patch_prev    <= 5'd0;
            tgl_dly       <= 8'd0;
            tgl_pend      <= 1'b0;
            patch_idx_tgl <= 1'b0;
        end
        else if (cur_patch != patch_prev) begin
            patch_prev <= cur_patch;
            tgl_dly    <= IDX_TGL_DLY[7:0];
            tgl_pend   <= 1'b1;
        end
        else if (tgl_pend) begin
            if (tgl_dly != 8'd0) tgl_dly <= tgl_dly - 8'd1;
            else begin
                tgl_pend      <= 1'b0;
                patch_idx_tgl <= ~patch_idx_tgl;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st         <= ST_SETTLE;
            settle_cnt <= 20'd0;
            seq_idx    <= 5'd0;
            gap_cnt    <= 8'd0;
            keyon      <= 1'b0;
            fnum_lo_r  <= 8'hBE;
            b0_base_r  <= 8'h0E;
            cur_patch  <= 5'd0;
            reg_we     <= 1'b0;
            reg_addr   <= 8'h00;
            reg_wdata  <= 8'h00;
            q_part     <= 2'd0;
            q_step     <= 5'd0;
            q_fin      <= 1'b0;
            q_pend     <= 1'b0;
            seq4part_d <= 1'b0;
        end
        else begin
            reg_we <= 1'b0;

            seq4part_d <= seq4part_on;
            if (seq4part_rise)
                q_pend <= 1'b1;

            case (st)
            ST_SETTLE: begin
                if (!cfg_ok) begin
                    settle_cnt <= 20'd0;
                end
                else if (settle_cnt != SETTLE_CLK[19:0]) begin
                    settle_cnt <= settle_cnt + 20'd1;
                end
                else begin
                    seq_idx <= 5'd0;
                    st      <= ST_LOAD;
                end
            end

            ST_LOAD: begin
                if (gap_cnt != GAP_CLK[7:0]) begin
                    gap_cnt <= gap_cnt + 8'd1;
                end
                else if (!reg_gnt) begin
                    gap_cnt <= GAP_CLK[7:0];
                end
                else if (!ps_rd_ok) begin
                    gap_cnt <= GAP_CLK[7:0];
                end
                else if (!ps_sel_rdy) begin
                    gap_cnt <= GAP_CLK[7:0];
                end
                else begin
                    gap_cnt  <= 8'd0;
                    reg_we   <= 1'b1;
                    reg_addr <= rom_word[15:8];
                    reg_wdata<= rom_word[7:0];

                    if (rom_word[15:8] == 8'hC0) cur_algo  <= rom_algo;
                    if (rom_word[15:8] == 8'hA0) fnum_lo_r <= rom_word[7:0];
                    if (rom_word[15:8] == 8'hB0) b0_base_r <= rom_word[7:0];
                    if (rom_word[15:8] == 8'hE3) cur_wave  <= rom_word[2:0];

                    if (seq_idx < (SEQ_LEN[4:0] - 5'd1)) begin
                        seq_idx <= seq_idx + 5'd1;
                    end
                    else begin
                        seq_idx <= 5'd0;
                        keyon   <= 1'b0;
                        st      <= ST_RUN;
                    end
                end
            end

            ST_RUN: begin
                if (gap_cnt != 8'd0) begin
                    gap_cnt <= gap_cnt - 8'd1;
                end
                else if (q_pend) begin
                    q_pend  <= 1'b0;
                    q_part  <= 2'd0;
                    q_step  <= 5'd0;
                    q_fin   <= 1'b0;
                    keyon   <= 1'b0;
                    gap_cnt <= 8'd0;
                    st      <= ST_QUAD;
                end
                else if (!KEYPAD_OWNS_B0 && (gate != keyon)) begin
                    if (reg_gnt) begin
                        keyon     <= gate;
                        reg_we    <= 1'b1;
                        reg_addr  <= 8'hB0;
                        reg_wdata <= b0_base_r | {gate, 5'b0};
                        gap_cnt   <= GAP_CLK[7:0];
                    end
                end
                else if (ev_algo) begin
                    cur_patch <= next_loaded(cur_patch, 1'b1);
                    keyon     <= 1'b0;
                    seq_idx   <= 5'd0;
                    gap_cnt   <= 8'd0;
                    st        <= ST_LOAD;
                end
                else if (pt_wr_ok && (pt_kind == 2'd2) && slot_ok(pt_a)) begin
                    cur_patch <= pt_a;
                    keyon     <= 1'b0;
                    seq_idx   <= 5'd0;
                    gap_cnt   <= 8'd0;
                    st        <= ST_LOAD;
                end
                else if (preset_up) begin
                    cur_patch <= next_loaded(cur_patch, 1'b1);
                    keyon     <= 1'b0;
                    seq_idx   <= 5'd0;
                    gap_cnt   <= 8'd0;
                    st        <= ST_LOAD;
                end
                else if (preset_dn) begin
                    cur_patch <= next_loaded(cur_patch, 1'b0);
                    keyon     <= 1'b0;
                    seq_idx   <= 5'd0;
                    gap_cnt   <= 8'd0;
                    st        <= ST_LOAD;
                end
                else if (ev_wave) begin
                    if (reg_gnt) begin
                        cur_wave  <= cur_wave + 3'd1;
                        reg_we    <= 1'b1;
                        reg_addr  <= 8'hE3;
                        reg_wdata <= {5'b0, cur_wave + 3'd1};
                        gap_cnt   <= GAP_CLK[7:0];
                    end
                end
            end

            ST_QUAD: begin
                if (gap_cnt != GAP_CLK[7:0]) begin
                    gap_cnt <= gap_cnt + 8'd1;
                end
                else if (!reg_gnt) begin
                    gap_cnt <= GAP_CLK[7:0];
                end
                else begin
                    gap_cnt <= 8'd0;
                    reg_we  <= 1'b1;

                    if (q_fin) begin
                        reg_addr  <= 8'h02;
                        reg_wdata <= 8'h00;
                        q_fin     <= 1'b0;
                        cur_patch <= 3'd1;
                        keyon     <= 1'b0;
                        st        <= ST_RUN;
                    end
                    else if (q_step == 5'd0) begin
                        reg_addr  <= 8'h02;
                        reg_wdata <= {6'd0, q_part};
                        q_step    <= 5'd1;
                    end
                    else begin
                        reg_addr  <= rom_word[15:8];
                        reg_wdata <= rom_word[7:0];

                        if (q_part == 2'd0) begin
                            if (rom_word[15:8] == 8'hC0) cur_algo  <= rom_algo;
                            if (rom_word[15:8] == 8'hA0) fnum_lo_r <= rom_word[7:0];
                            if (rom_word[15:8] == 8'hB0) b0_base_r <= rom_word[7:0];
                            if (rom_word[15:8] == 8'hE3) cur_wave  <= rom_word[2:0];
                        end

                        if (q_step < QUAD_SEQ[4:0]) begin
                            q_step <= q_step + 5'd1;
                        end
                        else begin
                            q_step <= 5'd0;
                            if (q_part < QUAD_LAST_PART) begin
                                q_part <= q_part + 2'd1;
                            end
                            else begin
                                q_part <= 2'd0;
                                q_fin  <= 1'b1;
                            end
                        end
                    end
                end
            end

            default: st <= ST_SETTLE;
            endcase
        end
    end

endmodule


module patch_led_bridge #(
    parameter integer CLK_HZ = 50_000_000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       cfg_done,
    input  wire [2:0] patch_idx,
    input  wire       patch_idx_tgl,
    output reg  [2:0] patch_idx_s,
    output wire [3:0] led
);

    reg [2:0] idx_meta, idx_sync;
    reg       tgl_meta, tgl_sync, tgl_sync_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx_meta   <= 3'd0;
            idx_sync   <= 3'd0;
            tgl_meta   <= 1'b0;
            tgl_sync   <= 1'b0;
            tgl_sync_d <= 1'b0;
            patch_idx_s<= 3'd0;
        end
        else begin
            idx_meta <= patch_idx;       idx_sync <= idx_meta;
            tgl_meta <= patch_idx_tgl;   tgl_sync <= tgl_meta;
            tgl_sync_d <= tgl_sync;
            if (tgl_sync != tgl_sync_d) patch_idx_s <= idx_sync;
        end
    end

    led_driver #(
        .CLK_HZ (CLK_HZ),
        .LED_W  (4)
    ) u_led (
        .clk       (clk),
        .rst_n     (rst_n),
        .led_mode  (~cfg_done),
        .status    (patch_idx_s),
        .led       (led)
    );

endmodule
