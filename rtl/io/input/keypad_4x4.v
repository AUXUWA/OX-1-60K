// keypad_4x4

`timescale 1ns/1ps

module keypad_4x4 #(
    parameter integer CLK_HZ      = 50_000_000,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer SCAN_DIV    = 500,
    parameter         IDLE_COL    = 4'b0000
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [3:0]  row_i,
    output reg  [3:0]  col_o,

    output reg  [15:0] pressed,
    output reg  [3:0]  key_count,
    output reg         multi_key,

    output reg         diag_col_multi,
    output reg  [3:0]  diag_row_low,

    output reg         press_pulse,
    output reg  [3:0]  press_value,
    output reg  [7:0]  press_key_code,

    output reg         release_pulse,
    output reg  [3:0]  release_value,
    output reg  [7:0]  release_key_code,

    output reg  [3:0]  key_value,
    output reg  [7:0]  key_code
);

    reg  [3:0] rsync0, rsync1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsync0 <= 4'b1111;
            rsync1 <= 4'b1111;
        end
        else begin
            rsync0 <= row_i;
            rsync1 <= rsync0;
        end
    end

    wire [3:0] row_s = rsync1;

    reg  [1:0]  col_idx;
    reg  [15:0] col_map;
    reg  [2:0]  col_pop;

    integer mi;
    always @(*) begin
        col_map = 16'd0;
        col_pop = 3'd0;
        for (mi = 0; mi < 4; mi = mi + 1)
            if (!row_s[mi]) begin
                col_map[{mi[1:0], col_idx}] = 1'b1;
                col_pop = col_pop + 3'd1;
            end
    end

    wire col_multi_now = (col_pop >= 3'd2);

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

    reg  [2:0]        state;
    reg  [SCAN_W-1:0] rsc_cnt;
    reg  [SCAN_W-1:0] scan_cnt;
    reg  [15:0]       cur_map;
    reg  [4:0]        n_hits;

    reg  [3:0]        row_all_low;
    reg  [3:0]        row_all_low_q;
    reg  [3:0]        row_low_cnt;
    reg               col_multi_round;

    reg  [15:0]       cand;
    reg  [7:0]        cand_cnt;

    reg  [15:0]       q_press, q_rel;
    reg               ev_busy;
    reg               ev_ph;
    reg  [3:0]        ev_idx;

    wire [4:0]  ev_idx_p1 = ev_idx + 5'd1;
    wire [15:0] ev_above   = 16'hffff << ev_idx_p1;

    wire [15:0]       held = pressed;

    always @(*) begin
        if (state == ST_SCAN) begin
            col_o = 4'bzzzz;
            col_o[col_idx] = 1'b0;
        end
        else if (state == ST_INIT) begin
            col_o = 4'bzzzz;
        end
        else begin
            col_o = IDLE_COL;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_INIT;
            rsc_cnt           <= {SCAN_W{1'b0}};
            scan_cnt         <= {SCAN_W{1'b0}};
            col_idx          <= 2'd0;
            cur_map          <= 16'd0;
            n_hits           <= 5'd0;
            row_all_low      <= 4'b1111;
            row_all_low_q    <= 4'b1111;
            row_low_cnt      <= 4'd0;
            col_multi_round  <= 1'b0;
            diag_col_multi   <= 1'b0;
            diag_row_low     <= 4'd0;
            cand             <= 16'd0;
            cand_cnt         <= 8'd0;
            q_press          <= 16'd0;
            q_rel            <= 16'd0;
            ev_busy          <= 1'b0;
            ev_ph            <= 1'b0;
            ev_idx           <= 4'd0;
            pressed          <= 16'd0;
            key_count        <= 4'd0;
            multi_key        <= 1'b0;
            press_pulse      <= 1'b0;
            press_value      <= 4'd0;
            press_key_code   <= 8'd0;
            release_pulse    <= 1'b0;
            release_value    <= 4'd0;
            release_key_code <= 8'd0;
            key_value        <= 4'd0;
            key_code         <= 8'd0;
        end
        else begin
            press_pulse   <= 1'b0;
            release_pulse <= 1'b0;

            if (!ev_busy) begin
                if ((q_press | q_rel) != 16'd0) begin
                    ev_busy <= 1'b1;
                    ev_ph   <= 1'b0;
                    ev_idx  <= 4'd0;
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
                    release_key_code <= {~(4'd1 << ev_idx[3:2]), ~(4'd1 << ev_idx[1:0])};
                end
                else if (q_press[ev_idx]) begin
                    press_pulse    <= 1'b1;
                    press_value    <= ev_idx;
                    press_key_code <= {~(4'd1 << ev_idx[3:2]), ~(4'd1 << ev_idx[1:0])};
                    key_value      <= ev_idx;
                    key_code       <= {~(4'd1 << ev_idx[3:2]), ~(4'd1 << ev_idx[1:0])};
                end
                if (((q_press | q_rel) & ev_above) == 16'd0) begin
                    ev_busy <= 1'b0;
                    q_press <= 16'd0;
                    q_rel   <= 16'd0;
                end
                else begin
                    ev_idx <= ev_idx + 1'b1;
                end
            end

            case (state)
            ST_INIT: begin
                state <= ST_HOLD;
            end
            ST_HOLD: begin
                if (rsc_cnt == (RSC_DIV - 1)) begin
                    rsc_cnt <= {SCAN_W{1'b0}};
                    col_idx <= 2'd0;
                    cur_map <= 16'd0;
                    n_hits  <= 5'd0;
                    row_all_low     <= 4'b1111;
                    col_multi_round <= 1'b0;
                    state   <= ST_SCAN;
                end
                else begin
                    rsc_cnt <= rsc_cnt + 1'b1;
                end
            end
            ST_SCAN: begin
                if (scan_cnt == (SCAN_DIV - 1)) begin
                    scan_cnt <= {SCAN_W{1'b0}};
                    cur_map <= cur_map | col_map;
                    n_hits  <= n_hits + {2'b0, col_pop};
                    if (col_multi_now) col_multi_round <= 1'b1;
                    row_all_low <= row_all_low & ~row_s;
                    if (col_idx == 2'd3)
                        state <= ST_REG;
                    else
                        col_idx <= col_idx + 1'b1;
                end
                else begin
                    scan_cnt <= scan_cnt + 1'b1;
                end
            end
            ST_REG: begin
                if (cur_map != cand) begin
                    cand     <= cur_map;
                    cand_cnt <= 8'd0;
                end
                else if (cand_cnt < CONF_LAST) begin
                    cand_cnt <= cand_cnt + 1'b1;
                end
                else if (cur_map != held) begin
                    pressed   <= cur_map;
                    key_count <= (n_hits > 5'd15) ? 4'hF : n_hits[3:0];
                    multi_key <= (n_hits >= 5'd2);
                    q_press   <= cur_map & ~held;
                    q_rel     <= held & ~cur_map;
                end
                row_all_low_q <= row_all_low;
                if (col_multi_round) diag_col_multi <= 1'b1;
                if ((row_all_low != 4'd0) && (row_all_low == row_all_low_q)) begin
                    if (row_low_cnt >= DIAG_LAST)
                        diag_row_low <= diag_row_low | row_all_low;
                    else
                        row_low_cnt <= row_low_cnt + 1'b1;
                end
                else begin
                    row_low_cnt <= (row_all_low != 4'd0) ? 4'd1 : 4'd0;
                end
                rsc_cnt <= {SCAN_W{1'b0}};
                state   <= ST_HOLD;
            end
            default: state <= ST_INIT;
            endcase
        end
    end

endmodule
