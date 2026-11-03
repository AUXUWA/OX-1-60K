// note_keypad

`timescale 1ns/1ps

module note_keypad #(
    parameter integer GAP_CLK = 16
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       kp_press_pulse,
    input  wire [3:0] kp_press_value,
    input  wire       kp_release_pulse,
    input  wire [3:0] kp_release_value,

    input  wire       key_gate,

    output reg        reg_we,
    output reg  [7:0] reg_addr,
    output reg  [7:0] reg_wdata,

    output reg        note_active,
    output reg  [3:0] cur_note,
    output reg  [2:0] cur_oct,
    output reg        sustain_on,
    output reg        mode_flag,
    output reg        oct_clamp_pulse
);

    localparam [3:0] K_OCT_DN  = 4'd12;
    localparam [3:0] K_MODE    = 4'd13;
    localparam [3:0] K_SUSTAIN = 4'd14;
    localparam [3:0] K_OCT_UP  = 4'd15;

    localparam [2:0] OCT_MIN  = 3'd0;
    localparam [2:0] OCT_C4   = 3'd2;
    localparam [2:0] OCT_MAX  = 3'd4;
    localparam [2:0] BLK_BIAS = 3'd2;

`include "pitch_lut.vh"

    reg [1:0]  st;
    reg [7:0]  gap_cnt;
    reg        req_a0;
    reg        req_b0;
    reg        gate_d;
    reg [11:0] pressed;

    wire       press_note  = kp_press_pulse   && (kp_press_value   < 4'd12);
    wire       release_note= kp_release_pulse && (kp_release_value < 4'd12);
    wire       press_octdn = kp_press_pulse   && (kp_press_value   == K_OCT_DN);
    wire       press_octup = kp_press_pulse   && (kp_press_value   == K_OCT_UP);
    wire       press_sus   = kp_press_pulse   && (kp_press_value   == K_SUSTAIN);
    wire       release_sus = kp_release_pulse && (kp_release_value == K_SUSTAIN);
    wire       press_mode  = kp_press_pulse   && (kp_press_value   == K_MODE);

    wire [11:0] note_oh = (12'd1 << kp_press_value[3:0])   & {12{press_note}};
    wire [11:0] rel_oh  = (12'd1 << kp_release_value[3:0]) & {12{release_note}};

    wire [11:0] pressed_next = (pressed | note_oh) & ~rel_oh;
    wire        sus_next     = sustain_on | press_sus;
    wire        any_note_next= |pressed_next;

    wire oct_moves  = (press_octdn & (cur_oct != OCT_MIN))
                    | (press_octup & (cur_oct != OCT_MAX));

    wire evt_note   = press_note | (oct_moves & note_active);
    wire evt_keyoff = note_active & ~any_note_next & ~sus_next;
    wire evt_gate   = (key_gate != gate_d);

    wire [9:0] cur_fnum = fnum_of(cur_note);
    wire [7:0] fnum_lo  = cur_fnum[7:0];
    wire [1:0] fnum_hi  = cur_fnum[9:8];
    wire [2:0] blk      = cur_oct + BLK_BIAS;
    wire       keyon_des= key_gate | note_active;

    wire [7:0] b0_data  = {2'b00, keyon_des, blk[2:0], fnum_hi[1:0]};

    localparam [1:0] ST_IDLE = 2'd0,
                     ST_GAP  = 2'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st      <= ST_IDLE;
            gap_cnt <= 8'd0;
            req_a0  <= 1'b0;
            req_b0  <= 1'b0;
            reg_we    <= 1'b0;
            reg_addr  <= 8'h00;
            reg_wdata <= 8'h00;
            pressed         <= 12'd0;
            cur_note        <= 4'd0;
            cur_oct         <= OCT_C4;
            note_active     <= 1'b0;
            sustain_on      <= 1'b0;
            mode_flag       <= 1'b0;
            oct_clamp_pulse <= 1'b0;
            gate_d          <= 1'b0;
        end
        else begin
            reg_we          <= 1'b0;
            oct_clamp_pulse <= 1'b0;
            gate_d          <= key_gate;

            pressed <= pressed_next;
            if      (press_sus)    sustain_on <= 1'b1;
            else if (release_sus) sustain_on <= 1'b0;

            if (press_note) begin
                cur_note    <= kp_press_value[3:0];
                note_active <= 1'b1;
            end
            else if (note_active & ~any_note_next & ~sus_next) begin
                note_active <= 1'b0;
            end

            if (press_mode) mode_flag <= 1'b1;

            if (press_octdn) begin
                if (cur_oct != OCT_MIN) cur_oct <= cur_oct - 3'd1;
                else oct_clamp_pulse <= 1'b1;
            end
            else if (press_octup) begin
                if (cur_oct != OCT_MAX) cur_oct <= cur_oct + 3'd1;
                else oct_clamp_pulse <= 1'b1;
            end

            if (evt_note) begin
                req_a0 <= 1'b1;
                req_b0 <= 1'b1;
            end
            else if (evt_keyoff) begin
                req_b0 <= 1'b1;
            end
            else if (evt_gate) begin
                req_b0 <= 1'b1;
            end

            case (st)
            ST_IDLE: begin
                if (req_a0 | req_b0) begin
                    st      <= ST_GAP;
                    gap_cnt <= GAP_CLK[7:0];
                end
            end

            ST_GAP: begin
                if (gap_cnt != 8'd0) begin
                    gap_cnt <= gap_cnt - 8'd1;
                end
                else if (req_a0) begin
                    reg_we    <= 1'b1;
                    reg_addr  <= 8'hA0;
                    reg_wdata <= fnum_lo;
                    req_a0    <= 1'b0;
                    gap_cnt   <= GAP_CLK[7:0];
                end
                else if (req_b0) begin
                    reg_we    <= 1'b1;
                    reg_addr  <= 8'hB0;
                    reg_wdata <= b0_data;
                    req_b0    <= 1'b0;
                    st        <= ST_IDLE;
                end
                else begin
                    st <= ST_IDLE;
                end
            end

            default: st <= ST_IDLE;
            endcase
        end
    end


endmodule
