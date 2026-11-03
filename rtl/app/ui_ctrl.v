// ui_ctrl

`timescale 1ns/1ps

module ui_ctrl #(
    parameter integer CLK_HZ          = 50_000_000,
    parameter integer ENC_FILTER_US   = 50,
    parameter integer ENC_DEBOUNCE_MS = 10,
    parameter integer ENC_LONG_MS     = 600,
    parameter [3:0]   ENC_DIR_FLIP    = 4'b1111,
    parameter integer KP_DEBOUNCE_MS  = 20,
    parameter integer KP_SCAN_DIV     = 500,
    parameter integer KP_ROWS         = 5,
    parameter integer KP_COLS         = 5,
    parameter integer BTN_DEBOUNCE_MS = 10,
    parameter integer BTN_LONG_MS     = 600,
    parameter integer BTN_REP_MS      = 150,
    parameter integer N_KEY = KP_ROWS * KP_COLS,
    parameter integer KV_W  = (KP_ROWS*KP_COLS <=  2) ? 1 : (KP_ROWS*KP_COLS <=  4) ? 2 :
                              (KP_ROWS*KP_COLS <=  8) ? 3 : (KP_ROWS*KP_COLS <= 16) ? 4 :
                              (KP_ROWS*KP_COLS <= 32) ? 5 : 6,
    parameter integer KCNT_W = (KP_ROWS*KP_COLS <=  1) ? 1 : (KP_ROWS*KP_COLS <=  3) ? 2 :
                               (KP_ROWS*KP_COLS <=  7) ? 3 : (KP_ROWS*KP_COLS <= 15) ? 4 :
                               (KP_ROWS*KP_COLS <= 31) ? 5 : 6,
    parameter integer BTN_N  = 6
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_ms,

    input  wire [3:0]  enc_a_i,
    input  wire [3:0]  enc_b_i,
    input  wire [3:0]  enc_sw_n_i,

    input  wire [KP_ROWS-1:0]  kb_row_i,
    output wire [KP_COLS-1:0]  kb_col_o,

    input  wire        key_gate,
    input  wire        key_preset_pulse,
    input  wire        key_diag_pulse,


    input  wire [BTN_N-1:0] key_btn_n_i,

    input  wire        ev_ack,

    output reg  [1:0]  ev_busy,
    output reg  [3:0]  ev_kind,
    output reg  [4:0]  ev_arg,

    output wire [3:0]  enc_rot_pulse,
    output wire [3:0]  enc_rot_dir,
    output wire [3:0]  enc_sw_press,
    output wire [3:0]  enc_sw_long,
    output wire [3:0]  enc_sw_down,

    output wire [N_KEY-1:0]       kb_pressed,
    output wire [KCNT_W-1:0]      kb_key_count,
    output wire                   kb_multi_key,
    output wire                   kb_press_pulse,
    output wire [KV_W-1:0]        kb_press_value,
    output wire [KP_ROWS+KP_COLS-1:0] kb_press_key_code,
    output wire                   kb_release_pulse,
    output wire [KV_W-1:0]        kb_release_value,
    output wire [KP_ROWS+KP_COLS-1:0] kb_release_key_code,

    output wire        key_gate_o,
    output wire        key_preset_o,
    output wire        key_diag_o,

    output wire [1:0]  led_mode,
    output wire [3:0]  led_data,

    output wire [3:0]  cur_page,
    output wire [1:0]  cur_focus,
    output wire        ui_mode,

    output wire        ui_layer,
    output wire        shift_home_pulse,
    output wire [BTN_N-1:0] btn_pressed,
    output wire        sustain_hold,
    output wire        oct_dn_pulse,
    output wire        oct_up_pulse,
    output wire        oct_dn_rep,
    output wire        oct_up_rep,
    output wire        glide_tgl_pulse,
    output wire        vel_tgl_pulse,
    output wire        ctrl_reset_all,
    output wire        seq_stop_pulse,
    output wire        preset_dn_pulse,
    output wire        preset_up_pulse,
    output wire        test_mode_req_pulse,

    output wire        page_sel,
    output wire [1:0]  seq_trk_sel,
    output wire [4:0]  seq_step_sel,

    output wire        sc_play_toggle_pulse,
    output wire        sc_guide_toggle_pulse,
    output wire        sc_mode_cycle_pulse
);

    localparam [3:0] EV_NONE       = 4'd0,
                     EV_ENC_INC    = 4'd1,
                     EV_ENC_DEC    = 4'd2,
                     EV_ENC_SHORT  = 4'd3,
                     EV_ENC_LONG   = 4'd4,
                     EV_KEY_DOWN   = 4'd5,
                     EV_KEY_UP     = 4'd6,
                     EV_PRESET     = 4'd7,
                     EV_GATE       = 4'd8,
                     EV_KEY_MULTI  = 4'd9,
                     EV_BTN_SHORT  = 4'd11,
                     EV_BTN_LONG   = 4'd12,
                     EV_BTN_REP    = 4'd13,
                     EV_LAYER      = 4'd14,
                     EV_RESET      = 4'd15;

    localparam [1:0] EV_IDLE = 2'd0,
                     EV_WAIT = 2'd1,
                     EV_PEND = 2'd2,
                     EV_OVF  = 2'd3;

    localparam [2:0] BTN_K1 = 3'd0,
                     BTN_K2 = 3'd1,
                     BTN_K3 = 3'd2,
                     BTN_K4 = 3'd3,
                     BTN_K5 = 3'd4,
                     BTN_K6 = 3'd5;

    localparam [BTN_N-1:0] BTN_REP_KEYS = 6'b000000;
    localparam [BTN_N-1:0] BTN_K6_ONE   = 6'b100000;

    localparam [3:0] PAGE_N    = 4'd5;
    localparam [3:0] PAGE_INIT = 4'd0;
    localparam [3:0] PAGE_MAX  = PAGE_N - 4'd1;
    localparam       UI_MODE_PLAY = 1'b1;

    wire rot_p0, rot_p1, rot_p2, rot_p3;
    wire rot_d0, rot_d1, rot_d2, rot_d3;
    wire swp_0,  swp_1,  swp_2,  swp_3;
    wire swl_0,  swl_1,  swl_2,  swl_3;
    wire swd_0,  swd_1,  swd_2,  swd_3;

    localparam integer ENC_PHYS_0 = 0;
    localparam integer ENC_PHYS_1 = 1;
    localparam integer ENC_PHYS_2 = 3;
    localparam integer ENC_PHYS_3 = 2;

    encoder_rotary #(
        .CLK_HZ      (CLK_HZ), .FILTER_US(ENC_FILTER_US),
        .DEBOUNCE_MS (ENC_DEBOUNCE_MS), .LONG_MS(ENC_LONG_MS), .DIR_FLIP(ENC_DIR_FLIP[0])
    ) u_enc0 (
        .clk(clk), .rst_n(rst_n),
        .enc_a(enc_a_i[ENC_PHYS_0]), .enc_b(enc_b_i[ENC_PHYS_0]), .enc_sw_n(enc_sw_n_i[ENC_PHYS_0]),
        .rot_pulse(rot_p0), .rot_dir(rot_d0),
        .sw_press_pulse(swp_0), .sw_long_pulse(swl_0), .sw_down(swd_0)
    );

    encoder_rotary #(
        .CLK_HZ      (CLK_HZ), .FILTER_US(ENC_FILTER_US),
        .DEBOUNCE_MS (ENC_DEBOUNCE_MS), .LONG_MS(ENC_LONG_MS), .DIR_FLIP(ENC_DIR_FLIP[1])
    ) u_enc1 (
        .clk(clk), .rst_n(rst_n),
        .enc_a(enc_a_i[ENC_PHYS_1]), .enc_b(enc_b_i[ENC_PHYS_1]), .enc_sw_n(enc_sw_n_i[ENC_PHYS_1]),
        .rot_pulse(rot_p1), .rot_dir(rot_d1),
        .sw_press_pulse(swp_1), .sw_long_pulse(swl_1), .sw_down(swd_1)
    );

    encoder_rotary #(
        .CLK_HZ      (CLK_HZ), .FILTER_US(ENC_FILTER_US),
        .DEBOUNCE_MS (ENC_DEBOUNCE_MS), .LONG_MS(ENC_LONG_MS), .DIR_FLIP(ENC_DIR_FLIP[2])
    ) u_enc2 (
        .clk(clk), .rst_n(rst_n),
        .enc_a(enc_a_i[ENC_PHYS_2]), .enc_b(enc_b_i[ENC_PHYS_2]), .enc_sw_n(enc_sw_n_i[ENC_PHYS_2]),
        .rot_pulse(rot_p2), .rot_dir(rot_d2),
        .sw_press_pulse(swp_2), .sw_long_pulse(swl_2), .sw_down(swd_2)
    );

    encoder_rotary #(
        .CLK_HZ      (CLK_HZ), .FILTER_US(ENC_FILTER_US),
        .DEBOUNCE_MS (ENC_DEBOUNCE_MS), .LONG_MS(ENC_LONG_MS), .DIR_FLIP(ENC_DIR_FLIP[3])
    ) u_enc3 (
        .clk(clk), .rst_n(rst_n),
        .enc_a(enc_a_i[ENC_PHYS_3]), .enc_b(enc_b_i[ENC_PHYS_3]), .enc_sw_n(enc_sw_n_i[ENC_PHYS_3]),
        .rot_pulse(rot_p3), .rot_dir(rot_d3),
        .sw_press_pulse(swp_3), .sw_long_pulse(swl_3), .sw_down(swd_3)
    );

    assign enc_rot_pulse = {rot_p3, rot_p2, rot_p1, rot_p0};
    assign enc_rot_dir   = {rot_d3, rot_d2, rot_d1, rot_d0};
    assign enc_sw_press  = {swp_3,  swp_2,  swp_1,  swp_0};
    assign enc_sw_long   = {swl_3,  swl_2,  swl_1,  swl_0};
    assign enc_sw_down   = {swd_3,  swd_2,  swd_1,  swd_0};

    wire kp_diag_col_multi_obs;
    wire [KP_ROWS-1:0] kp_diag_row_low_obs;

    keypad_matrix #(
        .ROWS        (KP_ROWS),
        .COLS        (KP_COLS),
        .CLK_HZ      (CLK_HZ),
        .DEBOUNCE_MS (KP_DEBOUNCE_MS),
        .SCAN_DIV    (KP_SCAN_DIV)
    ) u_keypad (
        .clk(clk), .rst_n(rst_n),
        .row_i(kb_row_i), .col_o(kb_col_o),
        .pressed(kb_pressed),
        .key_count(kb_key_count),
        .multi_key(kb_multi_key),
        .press_pulse(kb_press_pulse), .press_value(kb_press_value),
        .press_key_code(kb_press_key_code),
        .release_pulse(kb_release_pulse), .release_value(kb_release_value),
        .release_key_code(kb_release_key_code),
        .key_value(), .key_code(),
        .diag_col_multi(kp_diag_col_multi_obs),
        .diag_row_low  (kp_diag_row_low_obs)
    );

    wire [BTN_N-1:0] btn_press_pulse;
    wire [BTN_N-1:0] btn_release_pulse;
    wire [BTN_N-1:0] btn_long_pulse;
    wire [BTN_N-1:0] btn_rep_pulse;

    key_bank #(
        .N_BTN       (BTN_N),
        .CLK_HZ      (CLK_HZ),
        .DEBOUNCE_MS (BTN_DEBOUNCE_MS),
        .LONG_MS     (BTN_LONG_MS),
        .REP_MS      (BTN_REP_MS),
        .REP_MASK    (BTN_REP_KEYS)
    ) u_key_bank (
        .clk(clk), .rst_n(rst_n), .tick_ms(tick_ms),
        .btn_n_i(key_btn_n_i),
        .pressed(btn_pressed),
        .press_pulse(btn_press_pulse),
        .release_pulse(btn_release_pulse),
        .long_pulse(btn_long_pulse),
        .rep_pulse(btn_rep_pulse)
    );

    assign key_gate_o   = key_gate;
    assign key_preset_o = key_preset_pulse;
    assign key_diag_o   = key_diag_pulse;

    reg key_gate_q;
    reg kb_multi_q;

    wire gate_edge  = key_gate ^ key_gate_q;
    wire multi_rise = kb_multi_key & ~kb_multi_q;

    reg  [BTN_N-1:0] long_seen;
    reg              ui_layer_r;

    wire [BTN_N-1:0] btn_short_raw = btn_release_pulse & ~long_seen;
    wire [BTN_N-1:0] btn_long_raw  = btn_long_pulse & ~BTN_REP_KEYS & ~BTN_K6_ONE;
    wire [BTN_N-1:0] btn_rep_raw   = btn_rep_pulse;
    wire [BTN_N-1:0] btn_short_ev = btn_short_raw & ~BTN_K6_ONE;

    wire layer_now = ui_layer_r;
    wire [BTN_N-1:0] short_now = btn_short_raw;

    wire oct_up_now  = ~layer_now & short_now[BTN_K1];
    wire oct_dn_now  = ~layer_now & short_now[BTN_K2];
    wire oct_upr_now = 1'b0;
    wire oct_dnr_now = 1'b0;
    wire sc_play_now  = layer_now  & btn_long_pulse[BTN_K4];
    wire sc_guide_now = ~layer_now & short_now[BTN_K4];
    wire glide_now   = ~layer_now & short_now[BTN_K5];
    wire vel_now     = ~layer_now & btn_long_pulse[BTN_K5];
    wire testmode_now  = ~layer_now & btn_long_pulse[BTN_K3];
    wire reset_now     = layer_now  & btn_long_pulse[BTN_K2];
    wire seqplay_now   = ~layer_now & btn_long_pulse[BTN_K1];
    wire seqstop_now   = ~layer_now & btn_long_pulse[BTN_K2];
    wire sc_mode_now   = layer_now  & btn_long_pulse[BTN_K5];
    wire preset_up_now = layer_now  & btn_long_pulse[BTN_K1];
    wire preset_dn_now = layer_now  & btn_long_pulse[BTN_K3];
    wire modetgl_now   = layer_now  & short_now[BTN_K3];
    wire page_up_btn   = layer_now  & short_now[BTN_K5];
    wire page_dn_btn   = layer_now  & short_now[BTN_K4];

    wire page_tgl_now   = ~layer_now & short_now[BTN_K3];
    wire seqtrk_up_now  = layer_now & short_now[BTN_K1];
    wire seqtrk_dn_now  = layer_now & short_now[BTN_K2];
    wire seqstep_up_now = layer_now & short_now[BTN_K5];
    wire seqstep_dn_now = layer_now & short_now[BTN_K4];

    wire k6_long_now = btn_long_pulse[BTN_K6];
    wire layer_next  = k6_long_now ? 1'b0 : (short_now[BTN_K6] ? ~ui_layer_r : ui_layer_r);
    wire layer_changed = (layer_next != ui_layer_r);

    assign sustain_hold = ~ui_layer_r & btn_pressed[BTN_K4];

    reg oct_dn_r, oct_up_r, oct_dnr_r, oct_upr_r;
    reg glide_r,  vel_r,   reset_r, seqstop_r;
    reg sc_play_r, sc_guide_r, sc_mode_r;
    reg preset_dn_r, preset_up_r, testmode_r;
    reg shift_home_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            oct_dn_r    <= 1'b0;
            oct_up_r    <= 1'b0;
            oct_dnr_r   <= 1'b0;
            oct_upr_r   <= 1'b0;
            glide_r     <= 1'b0;
            vel_r       <= 1'b0;
            reset_r     <= 1'b0;
            seqstop_r   <= 1'b0;
            preset_dn_r <= 1'b0;
            preset_up_r <= 1'b0;
            testmode_r  <= 1'b0;
            sc_play_r   <= 1'b0;
            sc_guide_r  <= 1'b0;
            sc_mode_r   <= 1'b0;
            shift_home_r<= 1'b0;
            ui_layer_r  <= 1'b0;
            long_seen   <= {BTN_N{1'b0}};
        end
        else begin
            oct_dn_r    <= oct_dn_now;
            oct_up_r    <= oct_up_now;
            oct_dnr_r   <= oct_dnr_now;
            oct_upr_r   <= oct_upr_now;
            glide_r     <= glide_now;
            vel_r       <= vel_now;
            reset_r     <= reset_now;
            seqstop_r   <= seqstop_now;
            preset_dn_r <= preset_dn_now;
            preset_up_r <= preset_up_now;
            testmode_r  <= testmode_now;
            sc_play_r   <= sc_play_now;
            sc_guide_r  <= sc_guide_now;
            sc_mode_r   <= sc_mode_now;
            shift_home_r<= k6_long_now;
            ui_layer_r  <= layer_next;
            long_seen   <= (long_seen | btn_long_pulse) & ~btn_release_pulse;
        end
    end

    assign ui_layer          = ui_layer_r;
    assign shift_home_pulse  = shift_home_r;
    assign oct_dn_pulse      = oct_dn_r;
    assign oct_up_pulse      = oct_up_r;
    assign oct_dn_rep        = oct_dnr_r;
    assign oct_up_rep        = oct_upr_r;
    assign glide_tgl_pulse   = glide_r;
    assign vel_tgl_pulse     = vel_r;
    assign ctrl_reset_all    = reset_r;
    assign seq_stop_pulse    = seqstop_r;
    assign preset_dn_pulse   = preset_dn_r;
    assign preset_up_pulse   = preset_up_r;
    assign test_mode_req_pulse = testmode_r;
    assign sc_play_toggle_pulse  = sc_play_r;
    assign sc_guide_toggle_pulse = sc_guide_r;
    assign sc_mode_cycle_pulse   = sc_mode_r;

    reg        sel_hit;
    reg [3:0]  sel_kind;
    reg [4:0]  sel_arg;

    always @(*) begin
        sel_hit  = 1'b0;
        sel_kind = EV_NONE;
        sel_arg  = 5'd0;

        if (enc_rot_pulse[0]) begin
            sel_hit  = 1'b1;
            sel_kind = enc_rot_dir[0] ? EV_ENC_INC : EV_ENC_DEC;
            sel_arg  = 5'd0;
        end
        else if (enc_rot_pulse[1]) begin
            sel_hit  = 1'b1;
            sel_kind = enc_rot_dir[1] ? EV_ENC_INC : EV_ENC_DEC;
            sel_arg  = 5'd1;
        end
        else if (enc_rot_pulse[2]) begin
            sel_hit  = 1'b1;
            sel_kind = enc_rot_dir[2] ? EV_ENC_INC : EV_ENC_DEC;
            sel_arg  = 5'd2;
        end
        else if (enc_rot_pulse[3]) begin
            sel_hit  = 1'b1;
            sel_kind = enc_rot_dir[3] ? EV_ENC_INC : EV_ENC_DEC;
            sel_arg  = 5'd3;
        end
        else if (enc_sw_long[0]) begin
            sel_hit  = 1'b1; sel_kind = EV_ENC_LONG; sel_arg = 5'd0;
        end
        else if (enc_sw_long[1]) begin
            sel_hit  = 1'b1; sel_kind = EV_ENC_LONG; sel_arg = 5'd1;
        end
        else if (enc_sw_long[2]) begin
            sel_hit  = 1'b1; sel_kind = EV_ENC_LONG; sel_arg = 5'd2;
        end
        else if (enc_sw_long[3]) begin
            sel_hit  = 1'b1; sel_kind = EV_ENC_LONG; sel_arg = 5'd3;
        end
        else if (enc_sw_press[0]) begin
            sel_hit  = 1'b1; sel_kind = EV_ENC_SHORT; sel_arg = 5'd0;
        end
        else if (enc_sw_press[1]) begin
            sel_hit  = 1'b1; sel_kind = EV_ENC_SHORT; sel_arg = 5'd1;
        end
        else if (enc_sw_press[2]) begin
            sel_hit  = 1'b1; sel_kind = EV_ENC_SHORT; sel_arg = 5'd2;
        end
        else if (enc_sw_press[3]) begin
            sel_hit  = 1'b1; sel_kind = EV_ENC_SHORT; sel_arg = 5'd3;
        end
        else if (key_preset_pulse) begin
            sel_hit  = 1'b1;
            sel_kind = EV_PRESET;
            sel_arg  = 5'd0;
        end
        else if (gate_edge) begin
            sel_hit  = 1'b1;
            sel_kind = EV_GATE;
            sel_arg  = {4'd0, key_gate};
        end
        else if (btn_short_ev[0]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_SHORT; sel_arg = 5'd0;
        end
        else if (btn_short_ev[1]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_SHORT; sel_arg = 5'd1;
        end
        else if (btn_short_ev[2]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_SHORT; sel_arg = 5'd2;
        end
        else if (btn_short_ev[3]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_SHORT; sel_arg = 5'd3;
        end
        else if (btn_short_ev[4]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_SHORT; sel_arg = 5'd4;
        end
        else if (btn_short_ev[5]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_SHORT; sel_arg = 5'd5;
        end
        else if (btn_long_raw[0]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_LONG; sel_arg = 5'd0;
        end
        else if (btn_long_raw[1]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_LONG; sel_arg = 5'd1;
        end
        else if (btn_long_raw[2]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_LONG; sel_arg = 5'd2;
        end
        else if (btn_long_raw[3]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_LONG; sel_arg = 5'd3;
        end
        else if (btn_long_raw[4]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_LONG; sel_arg = 5'd4;
        end
        else if (btn_long_raw[5]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_LONG; sel_arg = 5'd5;
        end
        else if (btn_rep_raw[0]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_REP; sel_arg = 5'd0;
        end
        else if (btn_rep_raw[1]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_REP; sel_arg = 5'd1;
        end
        else if (btn_rep_raw[2]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_REP; sel_arg = 5'd2;
        end
        else if (btn_rep_raw[3]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_REP; sel_arg = 5'd3;
        end
        else if (btn_rep_raw[4]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_REP; sel_arg = 5'd4;
        end
        else if (btn_rep_raw[5]) begin
            sel_hit  = 1'b1; sel_kind = EV_BTN_REP; sel_arg = 5'd5;
        end
        else if (layer_changed) begin
            sel_hit  = 1'b1;
            sel_kind = EV_LAYER;
            sel_arg  = {4'd0, layer_next};
        end
        else if (kb_press_pulse) begin
            sel_hit  = 1'b1;
            sel_kind = EV_KEY_DOWN;
            sel_arg  = kb_press_value;
        end
        else if (kb_release_pulse) begin
            sel_hit  = 1'b1;
            sel_kind = EV_KEY_UP;
            sel_arg  = kb_release_value;
        end
        else if (multi_rise) begin
            sel_hit  = 1'b1;
            sel_kind = EV_KEY_MULTI;
            sel_arg  = kb_key_count;
        end
    end

    reg ev_ovf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ev_busy    <= EV_IDLE;
            ev_kind    <= EV_NONE;
            ev_arg     <= 5'd0;
            ev_ovf     <= 1'b0;
            key_gate_q <= 1'b0;
            kb_multi_q <= 1'b0;
        end
        else begin
            key_gate_q <= key_gate;
            kb_multi_q <= kb_multi_key;

            case (ev_busy)
            EV_IDLE: begin
                if (sel_hit) begin
                    ev_kind <= sel_kind;
                    ev_arg  <= sel_arg;
                    ev_busy <= EV_PEND;
                end
            end
            EV_WAIT: begin
                if (sel_hit) begin
                    ev_kind <= sel_kind;
                    ev_arg  <= sel_arg;
                    ev_busy <= EV_PEND;
                end
                else begin
                    ev_busy <= EV_IDLE;
                end
            end
            EV_PEND: begin
                if (ev_ack) begin
                    ev_kind <= EV_NONE;
                    ev_arg  <= 5'd0;
                    ev_ovf  <= 1'b0;
                    ev_busy <= ev_ovf ? EV_OVF : EV_WAIT;
                end
                else if (sel_hit) begin
                    if (ev_kind == EV_KEY_MULTI) begin
                        ev_kind <= sel_kind;
                        ev_arg  <= sel_arg;
                    end
                    else begin
                        ev_ovf <= 1'b1;
                    end
                end
            end
            EV_OVF: begin
                if (ev_ack) begin
                    ev_busy <= EV_WAIT;
                end
            end
            default: ev_busy <= EV_IDLE;
            endcase
        end
    end

    assign led_mode = 2'd0;
    assign led_data = 4'd0;


    reg [3:0] page_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                        page_r <= PAGE_INIT;
        else if (page_dn_btn)
                                           page_r <= (page_r == 4'd0)     ? PAGE_MAX : (page_r - 4'd1);
        else if (page_up_btn)
                                           page_r <= (page_r == PAGE_MAX) ? 4'd0    : (page_r + 4'd1);
    end
    assign cur_page = page_r;

    reg        page_sel_r;
    reg [1:0]  focus_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                          focus_r <= 2'd0;
        else if (!page_sel_r && enc_sw_press[0]) focus_r <= 2'd0;
        else if (!page_sel_r && enc_sw_press[1]) focus_r <= 2'd1;
        else if (!page_sel_r && enc_sw_press[2]) focus_r <= 2'd2;
        else if (!page_sel_r && enc_sw_press[3]) focus_r <= 2'd3;
    end
    assign cur_focus = focus_r;

    reg ui_mode_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)              ui_mode_r <= UI_MODE_PLAY;
        else if (seqstop_r)      ui_mode_r <= 1'b0;
        else if (seqplay_now)    ui_mode_r <= 1'b1;
        else if (modetgl_now)    ui_mode_r <= ~ui_mode_r;
    end
    assign ui_mode = ui_mode_r;

    reg [1:0]  seq_trk_r;
    reg [4:0]  seq_step_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            page_sel_r <= 1'b0;
            seq_trk_r  <= 2'd0;
            seq_step_r <= 5'd0;
        end
        else begin
            if (page_tgl_now) begin
                page_sel_r <= ~page_sel_r;
                if (!page_sel_r) begin
                    seq_trk_r  <= 2'd0;
                    seq_step_r <= 5'd0;
                end
            end
            else if (seqtrk_dn_now)
                seq_trk_r <= (seq_trk_r == 2'd0) ? 2'd3 : (seq_trk_r - 2'd1);
            else if (seqtrk_up_now)
                seq_trk_r <= (seq_trk_r == 2'd3) ? 2'd0 : (seq_trk_r + 2'd1);

            if (seqstep_dn_now)
                seq_step_r <= (seq_step_r == 5'd0)  ? 5'd31 : (seq_step_r - 5'd1);
            else if (seqstep_up_now)
                seq_step_r <= (seq_step_r == 5'd31) ? 5'd0  : (seq_step_r + 5'd1);
        end
    end

    assign page_sel     = page_sel_r;
    assign seq_trk_sel  = seq_trk_r;
    assign seq_step_sel = seq_step_r;

endmodule
