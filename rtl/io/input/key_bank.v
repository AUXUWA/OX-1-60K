// key_bank

`timescale 1ns/1ps

module key_bank #(
    parameter integer N_BTN       = 6,
    parameter integer CLK_HZ      = 50_000_000,
    parameter integer DEBOUNCE_MS = 10,
    parameter integer LONG_MS     = 600,
    parameter integer REP_MS      = 150,
    parameter [N_BTN-1:0] REP_MASK = 6'b000000
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 tick_ms,

    input  wire [N_BTN-1:0]     btn_n_i,

    output wire [N_BTN-1:0]     pressed,

    output wire [N_BTN-1:0]     press_pulse,
    output wire [N_BTN-1:0]     release_pulse,
    output wire [N_BTN-1:0]     long_pulse,
    output wire [N_BTN-1:0]     rep_pulse
);

    localparam integer HOLD_W = (LONG_MS <=     2) ?  1 :
                                (LONG_MS <=     4) ?  2 :
                                (LONG_MS <=     8) ?  3 :
                                (LONG_MS <=    16) ?  4 :
                                (LONG_MS <=    32) ?  5 :
                                (LONG_MS <=    64) ?  6 :
                                (LONG_MS <=   128) ?  7 :
                                (LONG_MS <=   256) ?  8 :
                                (LONG_MS <=   512) ?  9 :
                                (LONG_MS <=  1024) ? 10 :
                                (LONG_MS <=  2048) ? 11 : 12;
    localparam integer REP_W  = (REP_MS  <=     2) ?  1 :
                                (REP_MS  <=     4) ?  2 :
                                (REP_MS  <=     8) ?  3 :
                                (REP_MS  <=    16) ?  4 :
                                (REP_MS  <=    32) ?  5 :
                                (REP_MS  <=    64) ?  6 :
                                (REP_MS  <=   128) ?  7 :
                                (REP_MS  <=   256) ?  8 :
                                (REP_MS  <=   512) ?  9 : 10;

    localparam [HOLD_W-1:0] LONG_LAST = LONG_MS[HOLD_W-1:0] - {{(HOLD_W-1){1'b0}}, 1'b1};
    localparam [REP_W-1:0]  REP_LAST  = REP_MS [REP_W-1:0]  - {{(REP_W-1){1'b0}},  1'b1};

    wire [N_BTN-1:0] db_pressed;
    wire [N_BTN-1:0] db_press_pulse;

    key_debounce #(.DEBOUNCE_MS(DEBOUNCE_MS)) u_db0 (
        .clk(clk), .rst_n(rst_n), .tick_ms(tick_ms), .key_n(btn_n_i[0]),
        .pressed(db_pressed[0]), .press_pulse(db_press_pulse[0]));
    key_debounce #(.DEBOUNCE_MS(DEBOUNCE_MS)) u_db1 (
        .clk(clk), .rst_n(rst_n), .tick_ms(tick_ms), .key_n(btn_n_i[1]),
        .pressed(db_pressed[1]), .press_pulse(db_press_pulse[1]));
    key_debounce #(.DEBOUNCE_MS(DEBOUNCE_MS)) u_db2 (
        .clk(clk), .rst_n(rst_n), .tick_ms(tick_ms), .key_n(btn_n_i[2]),
        .pressed(db_pressed[2]), .press_pulse(db_press_pulse[2]));
    key_debounce #(.DEBOUNCE_MS(DEBOUNCE_MS)) u_db3 (
        .clk(clk), .rst_n(rst_n), .tick_ms(tick_ms), .key_n(btn_n_i[3]),
        .pressed(db_pressed[3]), .press_pulse(db_press_pulse[3]));
    key_debounce #(.DEBOUNCE_MS(DEBOUNCE_MS)) u_db4 (
        .clk(clk), .rst_n(rst_n), .tick_ms(tick_ms), .key_n(btn_n_i[4]),
        .pressed(db_pressed[4]), .press_pulse(db_press_pulse[4]));
    key_debounce #(.DEBOUNCE_MS(DEBOUNCE_MS)) u_db5 (
        .clk(clk), .rst_n(rst_n), .tick_ms(tick_ms), .key_n(btn_n_i[5]),
        .pressed(db_pressed[5]), .press_pulse(db_press_pulse[5]));

    assign pressed = db_pressed;

    reg [N_BTN-1:0]  db_pressed_d;
    reg [HOLD_W-1:0] hold_cnt [0:N_BTN-1];
    reg [REP_W-1:0]  rep_cnt  [0:N_BTN-1];
    reg              long_sent[0:N_BTN-1];
    reg [N_BTN-1:0]  press_pulse_r, release_pulse_r, long_pulse_r, rep_pulse_r;

    integer bi;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            db_pressed_d    <= {N_BTN{1'b0}};
            press_pulse_r   <= {N_BTN{1'b0}};
            release_pulse_r <= {N_BTN{1'b0}};
            long_pulse_r    <= {N_BTN{1'b0}};
            rep_pulse_r     <= {N_BTN{1'b0}};
            for (bi = 0; bi < N_BTN; bi = bi + 1) begin
                hold_cnt [bi] <= {HOLD_W{1'b0}};
                rep_cnt  [bi] <= {REP_W{1'b0}};
                long_sent[bi] <= 1'b0;
            end
        end
        else begin
            db_pressed_d <= db_pressed;

            for (bi = 0; bi < N_BTN; bi = bi + 1) begin
                press_pulse_r[bi]   <= db_press_pulse[bi];
                release_pulse_r[bi] <= 1'b0;
                long_pulse_r[bi]    <= 1'b0;
                rep_pulse_r[bi]     <= 1'b0;

                if (!db_pressed[bi]) begin
                    hold_cnt [bi] <= {HOLD_W{1'b0}};
                    rep_cnt  [bi] <= {REP_W{1'b0}};
                    long_sent[bi] <= 1'b0;
                    if (db_pressed_d[bi]) release_pulse_r[bi] <= 1'b1;
                end
                else if (tick_ms) begin
                    if (!long_sent[bi]) begin
                        if (hold_cnt[bi] == LONG_LAST) begin
                            hold_cnt[bi]  <= LONG_MS[HOLD_W-1:0];
                            long_sent[bi] <= 1'b1;
                            long_pulse_r[bi] <= 1'b1;
                            if (REP_MASK[bi]) begin
                                rep_pulse_r[bi] <= 1'b1;
                                rep_cnt[bi]     <= {REP_W{1'b0}};
                            end
                        end
                        else begin
                            hold_cnt[bi] <= hold_cnt[bi] + {{(HOLD_W-1){1'b0}}, 1'b1};
                        end
                    end
                    else if (REP_MASK[bi]) begin
                        if (rep_cnt[bi] == REP_LAST) begin
                            rep_cnt[bi]     <= {REP_W{1'b0}};
                            rep_pulse_r[bi] <= 1'b1;
                        end
                        else begin
                            rep_cnt[bi] <= rep_cnt[bi] + {{(REP_W-1){1'b0}}, 1'b1};
                        end
                    end
                end
            end
        end
    end

    assign press_pulse   = press_pulse_r;
    assign release_pulse = release_pulse_r;
    assign long_pulse    = long_pulse_r;
    assign rep_pulse     = rep_pulse_r;

`ifdef SIMULATION
    initial begin
        if (CLK_HZ / 1000 < 1)
            $display("*** ERROR key_bank: CLK_HZ(%0d) 太小，毫秒节拍无意义", CLK_HZ);
        if (DEBOUNCE_MS < 1)
            $display("*** ERROR key_bank: DEBOUNCE_MS(%0d) 必须 >= 1", DEBOUNCE_MS);
        if (LONG_MS < DEBOUNCE_MS)
            $display("*** ERROR key_bank: LONG_MS(%0d) < DEBOUNCE_MS(%0d)",
                     LONG_MS, DEBOUNCE_MS);
        if (REP_MS < 1)
            $display("*** ERROR key_bank: REP_MS(%0d) 必须 >= 1", REP_MS);
        if (N_BTN > 6)
            $display("*** ERROR key_bank: N_BTN(%0d) > 6（REP_MASK 只有 6 位常量表）", N_BTN);
    end
`endif

endmodule
