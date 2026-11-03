// seq_play4

`timescale 1ns/1ps

module seq_play4 #(
    parameter integer CLK_HZ  = 12_500_000,
    parameter integer GATE_MS = 120,
    parameter integer TICK_MIN = 2,
    parameter integer VOICE0   = 124,
    parameter [5:0]   SEQ_VEL   = 6'd0
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    input  wire        bus_gnt,
    output wire        reg_we,
    output wire [7:0]  reg_addr,
    output wire [7:0]  reg_wdata,
    output wire        busy,
    output reg         entered_without_auth,
    input  wire        tick_pulse,
    input  wire        seq4part,
    input  wire [23:0] track_pay,
    input  wire        play_en,
    output reg  [24:0] key_hold,
    output reg  [4:0]  cur_step
);

    localparam integer KEY_W = 25;

    localparam [4:0]   NOTE_TOP = 5'd24;

    localparam [KEY_W-1:0] KEY_ONE  = {{(KEY_W-1){1'b0}}, 1'b1};
    localparam [KEY_W-1:0] KEY_ZERO = {KEY_W{1'b0}};

    localparam integer TRK_N  = 4;
    localparam integer TRK_W  = 6;
    localparam integer TRK_PW = 5;

    localparam integer CLK_KHZ = (CLK_HZ < 1000) ? 1 : (CLK_HZ / 1000);

    localparam integer GATE_CYC = (CLK_KHZ * GATE_MS < 1) ? 1 : (CLK_KHZ * GATE_MS);

    localparam integer GATE_W =
        (GATE_CYC <= (1 <<  4)) ?  5 :
        (GATE_CYC <= (1 <<  8)) ?  9 :
        (GATE_CYC <= (1 << 12)) ? 13 :
        (GATE_CYC <= (1 << 16)) ? 17 :
        (GATE_CYC <= (1 << 20)) ? 21 :
        (GATE_CYC <= (1 << 24)) ? 25 : 32;

    localparam [GATE_W-1:0] GATE_INIT = (GATE_CYC - 1);

    localparam [7:0]   PG_REG     = 8'h03;
    localparam [3:0]   SQ_PAGE    = 4'd7;
    localparam [3:0]   SQ_NIB     = 4'd12;
    localparam [7:0]   A0_BASE    = 8'hA0;
    localparam [7:0]   B0_BASE    = 8'hB0;
    localparam [7:0]   VEL_BASE   = 8'h50;
    localparam [7:0]   PART_BASE  = 8'hD0;

    localparam [2:0]   OCT_C4     = 3'd2;
    localparam [2:0]   BLK_BIAS   = 3'd2;

    localparam [3:0]   V_IDLE     = 4'd0;
    localparam [3:0]   V_PG       = 4'd1;
    localparam [3:0]   V_PART     = 4'd8;
    localparam [3:0]   V_VEL      = 4'd2;
    localparam [3:0]   V_A0       = 4'd3;
    localparam [3:0]   V_B0A      = 4'd4;
    localparam [3:0]   V_WAIT     = 4'd5;
    localparam [3:0]   V_B0B      = 4'd6;
    localparam [3:0]   V_PGC      = 4'd7;

    localparam [1:0]   TK_LAST    = (TICK_MIN <= 1) ? 2'd0 :
                                    (TICK_MIN == 2) ? 2'd1 :
                                    (TICK_MIN == 3) ? 2'd2 : 2'd3;

    function [KEY_W-1:0] mask_of;
        input [23:0] pay;
        integer      ti;
        reg  [23:0]      w;
        reg  [KEY_W-1:0] m;
        reg  [4:0]       p;
        begin
            m = KEY_ZERO;
            w = pay;
            for (ti = 0; ti < TRK_N; ti = ti + 1) begin
                p = w[TRK_PW-1:0];
                if (w[TRK_PW] && (p <= NOTE_TOP))
                    m = m | (KEY_ONE << p);
                w = w >> TRK_W;
            end
            mask_of = m;
        end
    endfunction

`include "pitch_lut.vh"

    function [2:0] blk_of;
        input [4:0] n;
        reg [2:0] t;
        begin
            t = OCT_C4 + {1'b0, oct_add_of(n)};
            blk_of = ((t > 3'd5) ? 3'd5 : t) + BLK_BIAS;
        end
    endfunction

    reg [3:0]  v_st;
    reg [1:0]  v_cnt;
    reg [1:0]  v_tk;
    reg [23:0] v_pay;
    reg        v_play_r;

    reg [4:0] trk_pay;
    reg       trk_on;
    always @(*) begin
        case (v_cnt)
            2'd0    : begin trk_pay = v_pay[TRK_PW-1:0];       trk_on = v_pay[TRK_PW];   end
            2'd1    : begin trk_pay = v_pay[TRK_W+TRK_PW-1:TRK_W]; trk_on = v_pay[TRK_W+TRK_PW]; end
            2'd2    : begin trk_pay = v_pay[2*TRK_W+TRK_PW-1:2*TRK_W]; trk_on = v_pay[2*TRK_W+TRK_PW]; end
            default : begin trk_pay = v_pay[3*TRK_W+TRK_PW-1:3*TRK_W]; trk_on = v_pay[3*TRK_W+TRK_PW]; end
        endcase
    end

    wire [4:0] trk_p   = trk_on ? trk_pay : 5'd0;
    wire [9:0] trk_fn  = fnum_of(sem_of(trk_p));
    wire [2:0] trk_blk = blk_of(trk_p);

    wire [7:0] sq_a0   = A0_BASE | {4'b0000, SQ_NIB} | {6'd0, v_cnt};
    wire [7:0] sq_b0   = B0_BASE | {4'b0000, SQ_NIB} | {6'd0, v_cnt};
    wire [7:0] sq_v50  = VEL_BASE | {4'b0000, SQ_NIB} | {6'd0, v_cnt};
    wire [7:0] sq_d0   = PART_BASE | {4'b0000, SQ_NIB} | {6'd0, v_cnt};
    wire [7:0] sq_d_prt= {6'd0, v_cnt};
    wire [7:0] sq_d_a0 = trk_fn[7:0];
    wire [7:0] sq_d_b0a= {2'b00, 1'b0,  trk_blk, trk_fn[9:8]};
    wire [7:0] sq_d_b0b= {2'b00, trk_on, trk_blk, trk_fn[9:8]};
    wire [7:0] sq_d_vel= {2'b00, (trk_on ? SEQ_VEL : 6'd0)};

    wire       seq4part_on = seq4part;

    wire       v_use_part = seq4part_on;

    wire v_wv = (v_st == V_PG)  | (v_st == V_PART) | (v_st == V_VEL) |
                (v_st == V_A0)  | (v_st == V_B0A) | (v_st == V_B0B) |
                (v_st == V_PGC);

    assign reg_we    = v_wv & bus_gnt;
    assign reg_addr  = (v_st == V_PART)? sq_d0   :
                       (v_st == V_VEL) ? sq_v50  :
                       (v_st == V_A0)  ? sq_a0   :
                       (v_st == V_B0A) ? sq_b0   :
                       (v_st == V_B0B) ? sq_b0   : PG_REG;
    assign reg_wdata = (v_st == V_PG)  ? {4'b0000, SQ_PAGE} :
                       (v_st == V_PART)? sq_d_prt :
                       (v_st == V_VEL) ? sq_d_vel :
                       (v_st == V_A0)  ? sq_d_a0  :
                       (v_st == V_B0A) ? sq_d_b0a :
                       (v_st == V_B0B) ? sq_d_b0b : 8'h00;
    assign busy      = (v_st != V_IDLE);

    wire v_trig = (tick_pulse & play_en) | (~play_en & v_play_r);

    reg         v_pend;
    reg [GATE_W-1:0] gate_cnt;
    reg [KEY_W-1:0] pend_mask;
    reg              pend_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_hold   <= KEY_ZERO;
            cur_step   <= 5'd0;
            gate_cnt   <= {GATE_W{1'b0}};
            pend_mask  <= KEY_ZERO;
            pend_valid <= 1'b0;
        end
        else if (!play_en) begin
            key_hold   <= KEY_ZERO;
            gate_cnt   <= {GATE_W{1'b0}};
            pend_mask  <= KEY_ZERO;
            pend_valid <= 1'b0;
        end
        else if (tick_pulse) begin
            if ((mask_of(track_pay) == key_hold) && (|key_hold)) begin
                key_hold   <= KEY_ZERO;
                pend_mask  <= mask_of(track_pay);
                pend_valid <= 1'b1;
                gate_cnt   <= {GATE_W{1'b0}};
            end
            else begin
                key_hold   <= mask_of(track_pay);
                pend_mask  <= KEY_ZERO;
                pend_valid <= 1'b0;
                if (|mask_of(track_pay)) gate_cnt <= GATE_INIT;
                else                       gate_cnt <= {GATE_W{1'b0}};
            end
            cur_step <= cur_step + 5'd1;
        end
        else if (pend_valid) begin
            key_hold   <= pend_mask;
            gate_cnt   <= GATE_INIT;
            pend_valid <= 1'b0;
        end
        else if (|key_hold) begin
            if (gate_cnt == {GATE_W{1'b0}}) key_hold <= KEY_ZERO;
            else                            gate_cnt <= gate_cnt - 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_st     <= V_IDLE;
            v_cnt    <= 2'd0;
            v_tk     <= 2'd0;
            v_pay    <= 24'd0;
            v_play_r <= 1'b0;
            v_pend   <= 1'b0;
            entered_without_auth <= 1'b0;
        end
        else begin
            v_play_r <= play_en;
            case (v_st)
            V_IDLE: begin
                if (bus_gnt) begin
                    if (v_trig || v_pend) begin
                        if (v_trig) v_pay <= play_en ? track_pay : 24'd0;
                        v_cnt  <= 2'd0;
                        v_st   <= V_PG;
                        if (!bus_gnt) entered_without_auth <= 1'b1;
                    end
                end
                else if (v_trig) begin
                    v_pend <= 1'b1;
                    v_pay  <= play_en ? track_pay : 24'd0;
                end
            end
            V_PG: begin
                if (reg_we) begin
                    v_st  <= v_use_part ? V_PART : V_VEL;
                    v_cnt <= 2'd0;
                    v_pend <= 1'b0;
                end
            end
            V_PART: begin
                if (reg_we) begin
                    if (v_cnt == 2'd3) begin
                        v_cnt <= 2'd0;
                        v_st  <= V_VEL;
                    end
                    else v_cnt <= v_cnt + 2'd1;
                end
            end
            V_VEL: begin
                if (reg_we) begin
                    if (v_cnt == 2'd3) begin
                        v_cnt <= 2'd0;
                        v_st  <= V_A0;
                    end
                    else v_cnt <= v_cnt + 2'd1;
                end
            end
            V_A0: begin
                if (reg_we) begin
                    if (v_cnt == 2'd3) begin
                        v_cnt <= 2'd0;
                        v_st  <= V_B0A;
                    end
                    else v_cnt <= v_cnt + 2'd1;
                end
            end
            V_B0A: begin
                if (reg_we) begin
                    if (v_cnt == 2'd3) begin
                        v_cnt <= 2'd0;
                        v_tk  <= 2'd0;
                        v_st  <= V_WAIT;
                    end
                    else v_cnt <= v_cnt + 2'd1;
                end
            end
            V_WAIT: begin
                if (sample_tick) begin
                    if (v_tk == TK_LAST) begin
                        v_tk  <= 2'd0;
                        v_cnt <= 2'd0;
                        v_st  <= V_B0B;
                    end
                    else v_tk <= v_tk + 2'd1;
                end
            end
            V_B0B: begin
                if (reg_we) begin
                    if (v_cnt == 2'd3) v_st <= V_PGC;
                    else               v_cnt <= v_cnt + 2'd1;
                end
            end
            V_PGC: begin
                if (reg_we) v_st <= V_IDLE;
            end
            default: v_st <= V_IDLE;
            endcase
        end
    end

`ifdef SIMULATION
    initial begin
        if ((SQ_PAGE * 16 + SQ_NIB) != VOICE0)
            $display("*** ERROR seq_play4: 页/低位与 VOICE0 不自洽（页=%0d 低位=%0d VOICE0=%0d）",
                     SQ_PAGE, SQ_NIB, VOICE0);
        if (VOICE0 < 25)
            $display("*** ERROR seq_play4: VOICE0(%0d) 落在 note_manager 的 0..24 里 ⇒ 抢声部",
                     VOICE0);
    end
`endif

endmodule
