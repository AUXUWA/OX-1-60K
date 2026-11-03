// keypad_matrix

`timescale 1ns/1ps

module keypad_matrix #(
    parameter integer ROWS        = 5,
    parameter integer COLS        = 5,
    parameter integer CLK_HZ      = 50_000_000,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer SCAN_DIV    = 500,
    parameter [COLS-1:0] IDLE_COL = {COLS{1'b0}},
    parameter integer GHOST_FILTER = 1,
    parameter integer GHOST_MINNEW = 1,

    parameter integer KV_W   = (ROWS*COLS <=  2) ? 1 : (ROWS*COLS <=  4) ? 2 :
                               (ROWS*COLS <=  8) ? 3 : (ROWS*COLS <= 16) ? 4 :
                               (ROWS*COLS <= 32) ? 5 : 6,
    parameter integer KCNT_W = (ROWS*COLS <=  1) ? 1 : (ROWS*COLS <=  3) ? 2 :
                               (ROWS*COLS <=  7) ? 3 : (ROWS*COLS <= 15) ? 4 :
                               (ROWS*COLS <= 31) ? 5 : 6,
    parameter integer NH_W   = (ROWS*COLS <=  1) ? 2 : (ROWS*COLS <=  3) ? 3 :
                               (ROWS*COLS <=  7) ? 4 : (ROWS*COLS <= 15) ? 5 :
                               (ROWS*COLS <= 31) ? 6 : 7,
    parameter integer ROWBITS = (ROWS <= 2) ? 1 : (ROWS <= 4) ? 2 : (ROWS <= 8) ? 3 : 4,
    parameter integer COLBITS = (COLS <= 2) ? 1 : (COLS <= 4) ? 2 : (COLS <= 8) ? 3 : 4,
    parameter integer CB_W    = (ROWS <= 1) ? 1 : (ROWS <= 3) ? 2 : (ROWS <= 7) ? 3 : 4
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire [ROWS-1:0]      row_i,
    output reg  [COLS-1:0]      col_o,

    output reg  [ROWS*COLS-1:0] pressed,
    output reg  [KCNT_W-1:0]    key_count,
    output reg                  multi_key,

    output reg                  diag_col_multi,
    output reg  [ROWS-1:0]      diag_row_low,

    output reg                  press_pulse,
    output reg  [KV_W-1:0]      press_value,
    output reg  [ROWS+COLS-1:0] press_key_code,

    output reg                  release_pulse,
    output reg  [KV_W-1:0]      release_value,
    output reg  [ROWS+COLS-1:0] release_key_code,

    output reg  [KV_W-1:0]      key_value,
    output reg  [ROWS+COLS-1:0] key_code
);

    localparam integer N_KEY = ROWS * COLS;

    localparam [31:0] ONE32 = 32'd1;

    reg  [ROWS-1:0] rsync0, rsync1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsync0 <= {ROWS{1'b1}};
            rsync1 <= {ROWS{1'b1}};
        end
        else begin
            rsync0 <= row_i;
            rsync1 <= rsync0;
        end
    end

    wire [ROWS-1:0] row_s = rsync1;


    function [KV_W-1:0] semitone_of_rowcol;
        input [ROWBITS-1:0] r;
        input [COLBITS-1:0] c;
        begin
            case ({r, c})
                6'b000_000 : semitone_of_rowcol = 5'd1 ;
                6'b000_001 : semitone_of_rowcol = 5'd3 ;
                6'b000_010 : semitone_of_rowcol = 5'd6 ;
                6'b000_011 : semitone_of_rowcol = 5'd8 ;
                6'b000_100 : semitone_of_rowcol = 5'd10;
                6'b001_000 : semitone_of_rowcol = 5'd13;
                6'b001_001 : semitone_of_rowcol = 5'd15;
                6'b001_010 : semitone_of_rowcol = 5'd18;
                6'b001_011 : semitone_of_rowcol = 5'd20;
                6'b001_100 : semitone_of_rowcol = 5'd22;
                6'b010_000 : semitone_of_rowcol = 5'd17;
                6'b010_001 : semitone_of_rowcol = 5'd19;
                6'b010_010 : semitone_of_rowcol = 5'd21;
                6'b010_011 : semitone_of_rowcol = 5'd23;
                6'b010_100 : semitone_of_rowcol = 5'd24;
                6'b011_000 : semitone_of_rowcol = 5'd9 ;
                6'b011_001 : semitone_of_rowcol = 5'd11;
                6'b011_010 : semitone_of_rowcol = 5'd12;
                6'b011_011 : semitone_of_rowcol = 5'd14;
                6'b011_100 : semitone_of_rowcol = 5'd16;
                6'b100_000 : semitone_of_rowcol = 5'd0 ;
                6'b100_001 : semitone_of_rowcol = 5'd2 ;
                6'b100_010 : semitone_of_rowcol = 5'd4 ;
                6'b100_011 : semitone_of_rowcol = 5'd5 ;
                6'b100_100 : semitone_of_rowcol = 5'd7 ;
                default:    semitone_of_rowcol = 5'd0;
            endcase
        end
    endfunction

    function [ROWBITS+COLBITS-1:0] rowcol_of_semitone;
        input [KV_W-1:0] v;
        begin
            case (v)
                5'd0 : rowcol_of_semitone = {3'd4, 3'd0};
                5'd1 : rowcol_of_semitone = {3'd0, 3'd0};
                5'd2 : rowcol_of_semitone = {3'd4, 3'd1};
                5'd3 : rowcol_of_semitone = {3'd0, 3'd1};
                5'd4 : rowcol_of_semitone = {3'd4, 3'd2};
                5'd5 : rowcol_of_semitone = {3'd4, 3'd3};
                5'd6 : rowcol_of_semitone = {3'd0, 3'd2};
                5'd7 : rowcol_of_semitone = {3'd4, 3'd4};
                5'd8 : rowcol_of_semitone = {3'd0, 3'd3};
                5'd9 : rowcol_of_semitone = {3'd3, 3'd0};
                5'd10: rowcol_of_semitone = {3'd0, 3'd4};
                5'd11: rowcol_of_semitone = {3'd3, 3'd1};
                5'd12: rowcol_of_semitone = {3'd3, 3'd2};
                5'd13: rowcol_of_semitone = {3'd1, 3'd0};
                5'd14: rowcol_of_semitone = {3'd3, 3'd3};
                5'd15: rowcol_of_semitone = {3'd1, 3'd1};
                5'd16: rowcol_of_semitone = {3'd3, 3'd4};
                5'd17: rowcol_of_semitone = {3'd2, 3'd0};
                5'd18: rowcol_of_semitone = {3'd1, 3'd2};
                5'd19: rowcol_of_semitone = {3'd2, 3'd1};
                5'd20: rowcol_of_semitone = {3'd1, 3'd3};
                5'd21: rowcol_of_semitone = {3'd2, 3'd2};
                5'd22: rowcol_of_semitone = {3'd1, 3'd4};
                5'd23: rowcol_of_semitone = {3'd2, 3'd3};
                5'd24: rowcol_of_semitone = {3'd2, 3'd4};
                default: rowcol_of_semitone = {(ROWBITS+COLBITS){1'b0}};
            endcase
        end
    endfunction

    reg  [COLBITS-1:0] col_idx;
    reg  [N_KEY-1:0]   col_map;
    reg  [CB_W-1:0]    col_pop;

    integer mi;
    always @(*) begin
        col_map = {N_KEY{1'b0}};
        col_pop = {CB_W{1'b0}};
        for (mi = 0; mi < ROWS; mi = mi + 1)
            if (!row_s[mi]) begin
                col_map[semitone_of_rowcol(mi[ROWBITS-1:0], col_idx)] = 1'b1;
                col_pop = col_pop + {{(CB_W-1){1'b0}}, 1'b1};
            end
    end

    wire col_multi_now = (col_pop >= {{(CB_W-1){1'b0}}, 1'b1} + {{(CB_W-1){1'b0}}, 1'b1});

    function [ROWBITS-1:0] row_of_value;
        input [KV_W-1:0] v;
        reg   [ROWBITS+COLBITS-1:0] rc;
        begin
            rc          = rowcol_of_semitone(v);
            row_of_value = rc[ROWBITS+COLBITS-1:COLBITS];
        end
    endfunction

    function [COLBITS-1:0] col_of_value;
        input [KV_W-1:0] v;
        reg   [ROWBITS+COLBITS-1:0] rc;
        begin
            rc          = rowcol_of_semitone(v);
            col_of_value = rc[COLBITS-1:0];
        end
    endfunction

    reg [31:0] onehot32;
    function [ROWS+COLS-1:0] code_of_value;
        input [KV_W-1:0] v;
        reg   [ROWS-1:0] rc;
        reg   [COLS-1:0] cc;
        begin
            onehot32 = ONE32 << row_of_value(v);
            rc       = ~onehot32[ROWS-1:0];
            onehot32 = ONE32 << col_of_value(v);
            cc       = ~onehot32[COLS-1:0];
            code_of_value = {rc, cc};
        end
    endfunction

    localparam [2:0] ST_INIT = 3'd0,
                     ST_HOLD = 3'd1,
                     ST_SCAN = 3'd2,
                     ST_REG  = 3'd3;

    localparam integer DB_DIV = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer RSC_DIV = (CLK_HZ / 1000);
    localparam integer NCONF   = (DB_DIV > RSC_DIV) ? (DB_DIV / RSC_DIV) : 1;
    localparam [7:0]   CONF_LAST = (NCONF > 1) ? (NCONF - 1) : 8'd0;
    localparam integer SCAN_W = ((RSC_DIV > 65535) || (SCAN_DIV > 65535)) ? 24 : 16;

    localparam integer DIAG_ROUNDS = 8;
    localparam [3:0]   DIAG_LAST   = (DIAG_ROUNDS > 1) ? (DIAG_ROUNDS - 1) : 4'd1;

    reg  [2:0]         state;
    reg  [SCAN_W-1:0]  rsc_cnt;
    reg  [SCAN_W-1:0]  scan_cnt;
    reg  [N_KEY-1:0]   cur_map;
    reg  [NH_W-1:0]    n_hits;

    reg  [ROWS-1:0]    row_all_low;
    reg  [ROWS-1:0]    row_all_low_q;
    reg  [3:0]         row_low_cnt;
    reg                col_multi_round;

    reg  [N_KEY-1:0]   cand;
    reg  [7:0]         cand_cnt;

    reg  [N_KEY-1:0]   q_press, q_rel;
    reg                ev_busy;
    reg                ev_ph;
    reg  [KV_W-1:0]    ev_idx;

    wire [KV_W:0]      ev_idx_p1 = {1'b0, ev_idx} + {{KV_W{1'b0}}, 1'b1};
    wire [N_KEY-1:0]   ev_above  = {N_KEY{1'b1}} << ev_idx_p1;

    wire [N_KEY-1:0]   held = pressed;

    always @(*) begin
        if (state == ST_SCAN) begin
            col_o = {COLS{1'bz}};
            col_o[col_idx] = 1'b0;
        end
        else if (state == ST_INIT) begin
            col_o = {COLS{1'bz}};
        end
        else begin
            col_o = IDLE_COL;
        end
    end

    reg [N_KEY-1:0] new_map_c, ghost_c;
    reg [ROWS-1:0]  arow_c;
    reg [COLS-1:0]  acol_c;
    integer gi, gj, n_new_c, n_ghost_c;
    always @(*) begin
        new_map_c = cur_map & ~held;
        n_new_c = 0;
        for (gi = 0; gi < N_KEY; gi = gi + 1)
            if (new_map_c[gi]) n_new_c = n_new_c + 1;
        arow_c = {ROWS{1'b0}};
        acol_c = {COLS{1'b0}};
        for (gj = 0; gj < N_KEY; gj = gj + 1)
            if (held[gj]) begin
                arow_c[row_of_value(gj[KV_W-1:0])] = 1'b1;
                acol_c[col_of_value(gj[KV_W-1:0])] = 1'b1;
            end
        ghost_c = {N_KEY{1'b0}};
        if ((GHOST_FILTER != 0) && (n_new_c >= GHOST_MINNEW) && (n_new_c <= 4)) begin
            for (gi = 0; gi < N_KEY; gi = gi + 1) begin
                if (new_map_c[gi]) begin
                    if (arow_c[row_of_value(gi[KV_W-1:0])] &&
                        acol_c[col_of_value(gi[KV_W-1:0])])
                        ghost_c[gi] = 1'b1;
                    else begin
                        arow_c[row_of_value(gi[KV_W-1:0])] = 1'b1;
                        acol_c[col_of_value(gi[KV_W-1:0])] = 1'b1;
                    end
                end
            end
        end
        n_ghost_c = 0;
        for (gi = 0; gi < N_KEY; gi = gi + 1)
            if (ghost_c[gi]) n_ghost_c = n_ghost_c + 1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_INIT;
            rsc_cnt          <= {SCAN_W{1'b0}};
            scan_cnt         <= {SCAN_W{1'b0}};
            col_idx          <= {COLBITS{1'b0}};
            cur_map          <= {N_KEY{1'b0}};
            n_hits           <= {NH_W{1'b0}};
            row_all_low      <= {ROWS{1'b1}};
            row_all_low_q    <= {ROWS{1'b1}};
            row_low_cnt      <= 4'd0;
            col_multi_round  <= 1'b0;
            diag_col_multi   <= 1'b0;
            diag_row_low     <= {ROWS{1'b0}};
            cand             <= {N_KEY{1'b0}};
            cand_cnt         <= 8'd0;
            q_press          <= {N_KEY{1'b0}};
            q_rel            <= {N_KEY{1'b0}};
            ev_busy          <= 1'b0;
            ev_ph            <= 1'b0;
            ev_idx           <= {KV_W{1'b0}};
            pressed          <= {N_KEY{1'b0}};
            key_count        <= {KCNT_W{1'b0}};
            multi_key        <= 1'b0;
            press_pulse      <= 1'b0;
            press_value      <= {KV_W{1'b0}};
            press_key_code   <= {(ROWS+COLS){1'b0}};
            release_pulse    <= 1'b0;
            release_value    <= {KV_W{1'b0}};
            release_key_code <= {(ROWS+COLS){1'b0}};
            key_value        <= {KV_W{1'b0}};
            key_code         <= {(ROWS+COLS){1'b0}};
        end
        else begin
            press_pulse   <= 1'b0;
            release_pulse <= 1'b0;

            if (!ev_busy) begin
                if ((q_press | q_rel) != {N_KEY{1'b0}}) begin
                    ev_busy <= 1'b1;
                    ev_ph   <= 1'b0;
                    ev_idx  <= {KV_W{1'b0}};
                end
            end
            else if (!ev_ph) begin
                ev_ph <= 1'b1;
            end
            else begin
                ev_ph <= 1'b0;
                if (q_rel[ev_idx]) begin
                    release_pulse    <= 1'b1;
                    release_value    <= ev_idx;
                    release_key_code <= code_of_value(ev_idx);
                end
                else if (q_press[ev_idx]) begin
                    press_pulse    <= 1'b1;
                    press_value    <= ev_idx;
                    press_key_code <= code_of_value(ev_idx);
                    key_value      <= ev_idx;
                    key_code       <= code_of_value(ev_idx);
                end
                if (((q_press | q_rel) & ev_above) == {N_KEY{1'b0}}) begin
                    ev_busy <= 1'b0;
                    q_press <= {N_KEY{1'b0}};
                    q_rel   <= {N_KEY{1'b0}};
                end
                else begin
                    ev_idx <= ev_idx + {{(KV_W-1){1'b0}}, 1'b1};
                end
            end

            case (state)
            ST_INIT: begin
                state <= ST_HOLD;
            end
            ST_HOLD: begin
                if (rsc_cnt == (RSC_DIV - 1)) begin
                    rsc_cnt <= {SCAN_W{1'b0}};
                    col_idx <= {COLBITS{1'b0}};
                    cur_map <= {N_KEY{1'b0}};
                    n_hits  <= {NH_W{1'b0}};
                    row_all_low     <= {ROWS{1'b1}};
                    col_multi_round <= 1'b0;
                    state   <= ST_SCAN;
                end
                else begin
                    rsc_cnt <= rsc_cnt + {{(SCAN_W-1){1'b0}}, 1'b1};
                end
            end
            ST_SCAN: begin
                if (scan_cnt == (SCAN_DIV - 1)) begin
                    scan_cnt <= {SCAN_W{1'b0}};
                    cur_map <= cur_map | col_map;
                    n_hits  <= n_hits + {{(NH_W-CB_W){1'b0}}, col_pop};
                    if (col_multi_now) col_multi_round <= 1'b1;
                    row_all_low <= row_all_low & ~row_s;
                    if (col_idx == (COLS - 1))
                        state <= ST_REG;
                    else
                        col_idx <= col_idx + {{(COLBITS-1){1'b0}}, 1'b1};
                end
                else begin
                    scan_cnt <= scan_cnt + {{(SCAN_W-1){1'b0}}, 1'b1};
                end
            end
            ST_REG: begin
                if (cur_map != cand) begin
                    cand     <= cur_map;
                    cand_cnt <= 8'd0;
                end
                else if (cand_cnt < CONF_LAST) begin
                    cand_cnt <= cand_cnt + 8'd1;
                end
                else if (cur_map != held) begin
                    pressed   <= cur_map & ~ghost_c;
                    key_count <= ((n_hits - n_ghost_c[NH_W-1:0]) > N_KEY[NH_W-1:0])
                                 ? N_KEY[KCNT_W-1:0] : (n_hits - n_ghost_c[NH_W-1:0]);
                    multi_key <= ((n_hits - n_ghost_c[NH_W-1:0])
                                  >= {{(NH_W-1){1'b0}}, 1'b1} + {{(NH_W-1){1'b0}}, 1'b1});
                    q_press   <= (cur_map & ~ghost_c) & ~held;
                    q_rel     <= held & ~(cur_map & ~ghost_c);
                end
                row_all_low_q <= row_all_low;
                if (col_multi_round) diag_col_multi <= 1'b1;
                if ((row_all_low != {ROWS{1'b0}}) && (row_all_low == row_all_low_q)) begin
                    if (row_low_cnt >= DIAG_LAST)
                        diag_row_low <= diag_row_low | row_all_low;
                    else
                        row_low_cnt <= row_low_cnt + 4'd1;
                end
                else begin
                    row_low_cnt <= (row_all_low != {ROWS{1'b0}}) ? 4'd1 : 4'd0;
                end
                rsc_cnt <= {SCAN_W{1'b0}};
                state   <= ST_HOLD;
            end
            default: state <= ST_INIT;
            endcase
        end
    end

`ifdef SIMULATION
    initial begin
        if (N_KEY > (1 << KV_W)) begin
            $display("*** ERROR keypad_matrix: N_KEY(%0d) 装不进 KV_W(%0d) bit", N_KEY, KV_W);
        end
        if (N_KEY > ((1 << KCNT_W) - 1)) begin
            $display("*** ERROR keypad_matrix: key_count 位宽 KCNT_W(%0d) 装不下 N_KEY(%0d)",
                     KCNT_W, N_KEY);
        end
        if (N_KEY > ((1 << NH_W) - 1)) begin
            $display("*** ERROR keypad_matrix: n_hits 位宽 NH_W(%0d) 装不下 N_KEY(%0d)",
                     NH_W, N_KEY);
        end
        if (NCONF > 255) begin
            $display("*** ERROR keypad_matrix: NCONF(%0d) > 255（cand_cnt 只有 8bit）", NCONF);
        end
        if (SCAN_DIV < 4) begin
            $display("*** ERROR keypad_matrix: SCAN_DIV(%0d) < 4（行码 2FF 同步要 2 拍）", SCAN_DIV);
        end
    end

    always @(posedge clk) begin
        if (rst_n && (state == ST_REG) && (n_hits > N_KEY[NH_W-1:0]))
            $display("*** ERROR keypad_matrix: n_hits(%0d) > N_KEY(%0d)", n_hits, N_KEY);
    end
`endif

endmodule
