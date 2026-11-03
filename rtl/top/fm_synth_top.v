// fm_synth_top

`timescale 1ns/1ps

module fm_synth_top #(
    parameter integer N_VOICE = 240,
    parameter integer N_GROUP = 1,
    parameter integer N_CORE  = 4,
    parameter integer PA_EN_ACTIVE_LOW = 1,
    parameter integer PA_ON_DELAY_MS   = 50
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        key1_n,
    input  wire        key2_n,

    input  wire [4:0]  kp_row_i,
    output wire [4:0]  kp_col_o,

    input  wire [5:0]  keyb_btn_n,


    input  wire [3:0]  enc_a_i,
    input  wire [3:0]  enc_b_i,
    input  wire [3:0]  enc_sw_n_i,
    output wire        aud_i2c_scl,
    inout  wire        aud_i2c_sda,
    output wire        i2s_mclk,
    output wire        i2s_bclk,
    output wire        i2s_daclrc,
    output wire        i2s_dacdat,
    output wire        pa_en,
    output wire [3:0]  led,

    output wire        tmds_clk_p,
    output wire        tmds_clk_n,
    output wire [2:0]  tmds_data_p,
    output wire [2:0]  tmds_data_n,

    output wire        ws2812_do,
    output wire        bt_txd_o,
    input  wire        bt_rxd_i
);

    localparam integer SYS_CLK_HZ = 50_000_000;
    localparam integer MCLK_HZ    = 12_500_000;

    wire mclk;
    wire pll_lock;

    clk_gen u_clk_gen (
        .clk_50m (clk),
        .mclk    (mclk),
        .lock    (pll_lock)
    );

    wire sys_rst_n;

    rst_sync u_rst_sync_sys (
        .clk    (clk),
        .arst_n (rst_n),
        .rst_n  (sys_rst_n)
    );

    wire aud_arst_n = rst_n & pll_lock;
    wire aud_rst_n;

    rst_sync u_rst_sync_aud (
        .clk    (mclk),
        .arst_n (aud_arst_n),
        .rst_n  (aud_rst_n)
    );

    wire codec_ready = 1'b1;
    assign aud_i2c_scl = 1'b1;
    assign aud_i2c_sda = 1'bz;

    wire key1_pressed, key1_pulse;
    wire key2_pressed, key2_pulse;

    localparam integer MS_DIV = SYS_CLK_HZ / 1000;
    reg  [15:0] ms_div_cnt;
    reg         tick_ms;
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            ms_div_cnt <= 16'd0;
            tick_ms    <= 1'b0;
        end
        else begin
            tick_ms <= 1'b0;
            if (ms_div_cnt == MS_DIV[15:0] - 16'd1) begin
                ms_div_cnt <= 16'd0;
                tick_ms    <= 1'b1;
            end
            else begin
                ms_div_cnt <= ms_div_cnt + 16'd1;
            end
        end
    end

    key_debounce #(
        .DEBOUNCE_MS (10)
    ) u_key1 (
        .clk         (clk),
        .rst_n       (sys_rst_n),
        .tick_ms     (tick_ms),
        .key_n       (key1_n),
        .pressed     (key1_pressed),
        .press_pulse (key1_pulse)
    );

    key_debounce #(
        .DEBOUNCE_MS (10)
    ) u_key2 (
        .clk         (clk),
        .rst_n       (sys_rst_n),
        .tick_ms     (tick_ms),
        .key_n       (key2_n),
        .pressed     (key2_pressed),
        .press_pulse (key2_pulse)
    );




    wire        ui_layer;
    wire        ui_shift_home;
    wire [5:0]  ui_btn_pressed;
    wire        uk_sustain_hold;
    wire        uk_oct_dn, uk_oct_up;
    wire        uk_oct_dnr, uk_oct_upr;
    wire        uk_glide_tgl, uk_vel_tgl;
    wire        uk_reset_all;
    wire        uk_seq_stop;
    wire        uk_preset_dn, uk_preset_up;
    wire        uk_sc_play, uk_sc_guide, uk_sc_mode;
    wire        uk_testmode_req;

    localparam integer KEY2_LONG_MS = 1200;
    localparam integer KEY2_HOLD_W = 11;

    reg  [KEY2_HOLD_W-1:0] key2_hold;
    reg        key2_long_sent;
    reg        key2_long_pulse;
    reg        key2_pressed_d;
    reg        key2_was_long;
    reg        key2_preset_pulse;
    reg        test_mode_sys;
    reg        test_tgl;

    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            key2_pressed_d    <= 1'b0;
            key2_hold         <= {KEY2_HOLD_W{1'b0}};
            key2_long_sent    <= 1'b0;
            key2_long_pulse   <= 1'b0;
            key2_was_long     <= 1'b0;
            key2_preset_pulse <= 1'b0;
        end
        else begin
            key2_long_pulse   <= 1'b0;
            key2_preset_pulse <= 1'b0;
            key2_pressed_d    <= key2_pressed;

            if (!key2_pressed) begin
                if (key2_pressed_d && !key2_was_long)
                    key2_preset_pulse <= 1'b1;
                key2_hold       <= {KEY2_HOLD_W{1'b0}};
                key2_long_sent  <= 1'b0;
                key2_was_long   <= 1'b0;
            end
            else if (!key2_long_sent && tick_ms) begin
                if (key2_hold == KEY2_LONG_MS[KEY2_HOLD_W-1:0] - 1'b1) begin
                    key2_long_sent  <= 1'b1;
                    key2_was_long   <= 1'b1;
                    key2_long_pulse <= 1'b1;
                end
                else begin
                    key2_hold <= key2_hold + 1'b1;
                end
            end
        end
    end

    parameter ENABLE_TESTMODE_ENTRY_B = 0;
    wire test_mode_tgl_req = key2_long_pulse
                           | (ENABLE_TESTMODE_ENTRY_B ? uk_testmode_req : 1'b0);

    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            test_mode_sys <= 1'b0;
            test_tgl      <= 1'b0;
        end
        else if (test_mode_tgl_req) begin
            test_mode_sys <= ~test_mode_sys;
            test_tgl      <= ~test_tgl;
        end
    end

    reg test_tgl_s1, test_tgl_s2;
    always @(posedge mclk or negedge aud_rst_n) begin
        if (!aud_rst_n) begin
            test_tgl_s1 <= 1'b0;
            test_tgl_s2 <= 1'b0;
        end
        else begin
            test_tgl_s1 <= test_tgl;
            test_tgl_s2 <= test_tgl_s1;
        end
    end

    wire test_mode = test_tgl_s2;

    wire [1:0]  ui_ev_busy;
    wire [3:0]  ui_ev_kind;
    wire [4:0]  ui_ev_arg;
    wire [3:0]  ui_enc_rot_pulse, ui_enc_rot_dir;
    wire [3:0]  ui_enc_sw_press,  ui_enc_sw_long, ui_enc_sw_down;
    wire [24:0] ui_kb_pressed;
    wire [4:0]  ui_kb_key_count;
    wire        ui_kb_multi_key;
    wire        ui_kb_press_pulse;
    wire [4:0]  ui_kb_press_value;
    wire        ui_kb_release_pulse;
    wire [4:0]  ui_kb_release_value;
    wire        ui_key_gate, ui_key_preset, ui_key_diag;
    wire [1:0]  ui_led_mode;
    wire [3:0]  ui_led_data;
    wire [3:0]  ui_cur_page;
    wire [1:0]  ui_cur_focus;
    wire        ui_mode;
    wire        ui_page_sel;
    wire [1:0]  ui_seq_trk;
    wire [4:0]  ui_seq_step;

    ui_ctrl #(
        .CLK_HZ         (SYS_CLK_HZ),
        .ENC_DIR_FLIP   (4'b1111),
        .KP_DEBOUNCE_MS (3),
        .KP_SCAN_DIV    (500)
    ) u_ui_ctrl (
        .clk          (clk),
        .rst_n        (sys_rst_n),
        .tick_ms      (tick_ms),
        .enc_a_i      (enc_a_i),
        .enc_b_i      (enc_b_i),
        .enc_sw_n_i   (enc_sw_n_i),
        .kb_row_i     (kp_row_i),
        .kb_col_o     (kp_col_o),
        .key_btn_n_i  (keyb_btn_n),
        .key_gate     (key1_pressed),
        .key_preset_pulse(key2_preset_pulse),
        .key_diag_pulse(key2_long_pulse),
        .ev_ack       (1'b1),
        .ev_busy      (ui_ev_busy),
        .ev_kind      (ui_ev_kind),
        .ev_arg       (ui_ev_arg),
        .enc_rot_pulse(ui_enc_rot_pulse), .enc_rot_dir(ui_enc_rot_dir),
        .enc_sw_press (ui_enc_sw_press),  .enc_sw_long(ui_enc_sw_long),
        .enc_sw_down  (ui_enc_sw_down),
        .kb_pressed   (ui_kb_pressed), .kb_key_count(ui_kb_key_count),
        .kb_multi_key (ui_kb_multi_key),
        .kb_press_pulse(ui_kb_press_pulse), .kb_press_value(ui_kb_press_value),
        .kb_release_pulse(ui_kb_release_pulse), .kb_release_value(ui_kb_release_value),
        .key_gate_o   (ui_key_gate), .key_preset_o(ui_key_preset), .key_diag_o(ui_key_diag),
        .led_mode     (ui_led_mode), .led_data(ui_led_data),
        .cur_page     (ui_cur_page),
        .cur_focus    (ui_cur_focus),
        .ui_mode      (ui_mode),
        .page_sel     (ui_page_sel),
        .seq_trk_sel  (ui_seq_trk),
        .seq_step_sel (ui_seq_step),
        .ui_layer        (ui_layer),
        .shift_home_pulse(ui_shift_home),
        .btn_pressed     (ui_btn_pressed),
        .sustain_hold    (uk_sustain_hold),
        .oct_dn_pulse    (uk_oct_dn),
        .oct_up_pulse    (uk_oct_up),
        .oct_dn_rep      (uk_oct_dnr),
        .oct_up_rep      (uk_oct_upr),
        .glide_tgl_pulse (uk_glide_tgl),
        .vel_tgl_pulse   (uk_vel_tgl),
        .ctrl_reset_all  (uk_reset_all),
        .seq_stop_pulse  (uk_seq_stop),
        .preset_dn_pulse (uk_preset_dn),
        .preset_up_pulse (uk_preset_up),
        .test_mode_req_pulse (uk_testmode_req),
        .sc_play_toggle_pulse  (uk_sc_play),
        .sc_guide_toggle_pulse (uk_sc_guide),
        .sc_mode_cycle_pulse   (uk_sc_mode)
    );


    wire uk_octd_evt = uk_oct_dn | uk_oct_dnr;
    wire uk_octu_evt = uk_oct_up | uk_oct_upr;

    wire oct_dn_m, oct_up_m;
    wire glide_tgl_m, vel_tgl_m;
    wire reset_all_m;
    wire preset_dn_m, preset_up_m;

    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_btn_cdc_octdn (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(uk_octd_evt),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(mclk), .dst_rst_n(aud_rst_n), .dst_pulse(oct_dn_m),
        .dst_payload(), .dst_busy()
    );
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_btn_cdc_octup (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(uk_octu_evt),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(mclk), .dst_rst_n(aud_rst_n), .dst_pulse(oct_up_m),
        .dst_payload(), .dst_busy()
    );
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_btn_cdc_glide (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(uk_glide_tgl),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(mclk), .dst_rst_n(aud_rst_n), .dst_pulse(glide_tgl_m),
        .dst_payload(), .dst_busy()
    );
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_btn_cdc_vel (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(uk_vel_tgl),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(mclk), .dst_rst_n(aud_rst_n), .dst_pulse(vel_tgl_m),
        .dst_payload(), .dst_busy()
    );
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_btn_cdc_reset (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(uk_reset_all),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(mclk), .dst_rst_n(aud_rst_n), .dst_pulse(reset_all_m),
        .dst_payload(), .dst_busy()
    );
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_btn_cdc_prestdn (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(uk_preset_dn),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(mclk), .dst_rst_n(aud_rst_n), .dst_pulse(preset_dn_m),
        .dst_payload(), .dst_busy()
    );
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_btn_cdc_presetup (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(uk_preset_up),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(mclk), .dst_rst_n(aud_rst_n), .dst_pulse(preset_up_m),
        .dst_payload(), .dst_busy()
    );

    reg glide_en_mclk, vel_en_mclk;
    always @(posedge mclk or negedge aud_rst_n) begin
        if (!aud_rst_n) begin
            glide_en_mclk <= 1'b0;
            vel_en_mclk   <= 1'b0;
        end
        else begin
            if (glide_tgl_m) glide_en_mclk <= ~glide_en_mclk;
            if (vel_tgl_m)   vel_en_mclk   <= ~vel_en_mclk;
        end
    end

    reg sus_hold_s1, sus_hold_s2;
    always @(posedge mclk or negedge aud_rst_n) begin
        if (!aud_rst_n) begin
            sus_hold_s1 <= 1'b0;
            sus_hold_s2 <= 1'b0;
        end
        else begin
            sus_hold_s1 <= uk_sustain_hold;
            sus_hold_s2 <= sus_hold_s1;
        end
    end
    wire sustain_hold_mclk = sus_hold_s2;


    wire         nkp_gate_mclk;
    wire [24:0]  kp_level_mclk;

    wire [24:0]  seq_key_hold;
    wire [15:0] sl_total_steps, sl_step_ms;
    wire [7:0]  sl_obs_status, sl_obs_seq, sl_obs_cmd;
    wire        sl_pt_wr, sl_pt_kind, sl_pt_sel_upd;
    wire [3:0]  sl_pt_slot;
    wire [4:0]  sl_pt_idx, sl_pt_sel;
    wire [15:0] sl_pt_word;
    wire [15:0] sl_pt_vbits_sys;
    wire        pcdc_pulse;
    wire [1:0]  pcdc_kind;
    wire [4:0]  pcdc_a, pcdc_b;
    wire [15:0] pcdc_word;
    wire [15:0] ps_valid_bits;
    wire        pcdc_req    = sl_pt_wr | sl_pt_sel_upd;
    wire [1:0]  pcdc_kind_i = sl_pt_sel_upd ? 2'd2 : {1'b0, sl_pt_kind};
    wire [4:0]  pcdc_a_i    = sl_pt_sel_upd ? sl_pt_sel : {1'b0, sl_pt_slot};
    wire [4:0]  pcdc_b_i    = sl_pt_idx;
    wire [15:0] pcdc_word_i = sl_pt_word;

    reg  [15:0] pvb_m, pvb_s;
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            pvb_m <= 16'd0;
            pvb_s <= 16'd0;
        end
        else begin
            pvb_m <= ps_valid_bits;
            pvb_s <= pvb_m;
        end
    end
    assign sl_pt_vbits_sys = pvb_s;
    wire        sp_playing;
    wire [24:0] sp_accomp;
    wire [7:0]  score_mode_v;
    wire [7:0]  sp_cur_step_o;
    wire [7:0]  sp_cur_step8 = sp_cur_step_o;
    wire [1:0]  sp_mode_o;
    wire        sp_accomp_active = |sp_accomp;
    reg         sc_guide_en_r;
    wire [24:0]  seq_kp_merged;

    assign seq_kp_merged = kp_level_mclk;

    wire [24:0] kp_level_src = ui_kb_pressed | sp_accomp;

    keypad_event_cdc #(
        .W        (25),
        .SETTLE   (4),
        .KEEP_DIV (50_000)
    ) u_kp_cdc (
        .sys_clk   (clk),
        .sys_rst_n (sys_rst_n),
        .sys_level (kp_level_src),
        .sys_gate  (key1_pressed),
        .mclk      (mclk),
        .m_rst_n   (aud_rst_n),
        .m_level   (kp_level_mclk),
        .m_gate    (nkp_gate_mclk)
    );

    wire sample_tick;

    reg [1:0] cfg_sync;
    reg [1:0] gate_sync;
    reg [1:0] algo_sync;
    reg       algo_tgl;
    reg       algo_tgl_d;

    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) algo_tgl <= 1'b0;
        else if (key2_preset_pulse) algo_tgl <= ~algo_tgl;
    end

    always @(posedge mclk or negedge aud_rst_n) begin
        if (!aud_rst_n) begin
            cfg_sync     <= 2'b00;
            gate_sync    <= 2'b00;
            algo_sync    <= 2'b00;
            algo_tgl_d   <= 1'b0;
        end
        else begin
            cfg_sync   <= {cfg_sync[0],  codec_ready};
            gate_sync  <= {gate_sync[0], key1_pressed};
            algo_sync  <= {algo_sync[0], algo_tgl};
            algo_tgl_d <= algo_sync[1];
        end
    end

    wire cfg_ok_mclk = cfg_sync[1];
    wire gate_mclk   = gate_sync[1];
    wire ev_algo     = algo_sync[1] ^ algo_tgl_d;

    wire [4:0] dbg_patch;
    wire [2:0] dbg_algo, dbg_wave;
    wire       patch_tgl;

    wire       dn_gnt;
    wire       nm_gnt;
    wire       eng_hold;

    wire       dn_we;
    wire [7:0] dn_addr;
    wire [7:0] dn_wdata;
    wire       dn_load;

    reg        seq4part_r;

    demo_note #(
        .SYS_HZ    (12_500_000),
        .SETTLE_MS (50),
        .GAP_CLK   (16)
    ) u_demo_note (
        .clk           (mclk),
        .rst_n         (aud_rst_n),
        .cfg_ok        (cfg_ok_mclk),
        .gate          (gate_mclk),
        .ev_algo       (ev_algo),
        .ev_wave       (1'b0),
        .reg_gnt       (dn_gnt),
        .reg_we        (dn_we),
        .reg_addr      (dn_addr),
        .reg_wdata     (dn_wdata),
        .load_active   (dn_load),
        .preset_up     (preset_up_m),
        .preset_dn     (preset_dn_m),
        .seq4part      (seq4part_r),
        .pt_wr         (pcdc_pulse),
        .pt_kind       (pcdc_kind),
        .pt_a          (pcdc_a),
        .pt_b          (pcdc_b),
        .pt_word       (pcdc_word),
        .pt_valid_bits (ps_valid_bits),
        .cur_patch     (dbg_patch),
        .patch_idx_tgl (patch_tgl),
        .cur_algo      (dbg_algo),
        .cur_wave      (dbg_wave)
    );

    localparam integer KP_N_KEY = 25;
    localparam integer VO_W = (KP_N_KEY < N_VOICE) ? ((KP_N_KEY < 1) ? 1 : ((KP_N_KEY > 32) ? 32 : KP_N_KEY))
                                                   : ((N_VOICE  < 1) ? 1 : ((N_VOICE  > 32) ? 32 : N_VOICE));
    localparam integer CNT_W = (VO_W <= 16) ? 5 : 6;
    wire       nkp_we;
    wire [7:0] nkp_addr, nkp_wdata;
    wire       nkp_note_active, nkp_sustain_on, nkp_mode_flag, nkp_oct_clamp;
    wire [4:0] nkp_cur_note;
    wire [2:0] nkp_cur_oct;
    wire [3:0] nkp_voice_cnt;
    wire [CNT_W-1:0] nkp_voice_cnt5;
    wire [VO_W-1:0] nkp_v_on_o, nkp_v_gate_o;
    wire       nkp_busy;
    wire       nkp_page_dirty;
    wire       nkp_gnt;
    wire [7:0] pp_vib_depth;
    wire [3:0]  pp_vel_level;
    wire [7:0] pp_vol;
    wire [4:0] nkp_cur_key;
    wire       nkp_key_on;
    wire [5:0] sp_vel;
    wire [5:0] vel_cur_mclk;

    note_manager #(
        .N_KEY   (KP_N_KEY),
        .N_VOICE (N_VOICE),
        .GAP_CLK (16),
        .VEL_HEUR (1)
    ) u_note_manager (
        .clk            (mclk),
        .rst_n          (aud_rst_n),
        .sample_tick    (sample_tick),
        .kp_pressed     (seq_kp_merged),
        .oct_dn_pulse   (oct_dn_m),
        .oct_up_pulse   (oct_up_m),
        .sustain_hold_i (sustain_hold_mclk),
        .glide_en_i     (glide_en_mclk),
        .vib_en_i       (1'b1),
        .vib_depth_i    (pp_vib_depth),
        .vel_en_i       (vel_en_mclk),
        .vel_level_i    (pp_vel_level[3:0]),
        .vel_cur_i      (vel_cur_mclk),
        .all_keyoff_req (reset_all_m),
        .key_gate       (nkp_gate_mclk),
        .bus_gnt        (nkp_gnt),
        .eng_hold       (eng_hold),
        .reg_we         (nkp_we),
        .reg_addr       (nkp_addr),
        .reg_wdata      (nkp_wdata),
        .note_active    (nkp_note_active),
        .cur_note       (nkp_cur_note),
        .cur_oct        (nkp_cur_oct),
        .sustain_on     (nkp_sustain_on),
        .mode_flag      (nkp_mode_flag),
        .oct_clamp_pulse(nkp_oct_clamp),
        .cur_key        (nkp_cur_key),
        .cur_key_on     (nkp_key_on),
        .voice_cnt      (nkp_voice_cnt5),
        .v_on_o         (nkp_v_on_o),
        .v_gate_o       (nkp_v_gate_o),
        .busy           (nkp_busy),
        .page_dirty     (nkp_page_dirty)
    );

    assign nkp_voice_cnt = nkp_voice_cnt5[3:0];

    wire pix_clk, ser_clk, vid_lock, vid_rst_n;

    wire pan_we;

    wire [5:0] pp_seq_evt_m;
    reg [24:0] kp_level_d;
    reg [24:0] kp_down_oh;
    reg  [4:0] kp_down_idx;
    reg        kp_down_any;

    always @* begin
        kp_down_oh  = kp_level_mclk & ~kp_level_d;
        kp_down_any = |kp_down_oh;
        kp_down_idx = 5'd0;
        if (kp_down_oh[0])  kp_down_idx = 5'd0;
        else if (kp_down_oh[1])  kp_down_idx = 5'd1;
        else if (kp_down_oh[2])  kp_down_idx = 5'd2;
        else if (kp_down_oh[3])  kp_down_idx = 5'd3;
        else if (kp_down_oh[4])  kp_down_idx = 5'd4;
        else if (kp_down_oh[5])  kp_down_idx = 5'd5;
        else if (kp_down_oh[6])  kp_down_idx = 5'd6;
        else if (kp_down_oh[7])  kp_down_idx = 5'd7;
        else if (kp_down_oh[8])  kp_down_idx = 5'd8;
        else if (kp_down_oh[9])  kp_down_idx = 5'd9;
        else if (kp_down_oh[10]) kp_down_idx = 5'd10;
        else if (kp_down_oh[11]) kp_down_idx = 5'd11;
        else if (kp_down_oh[12]) kp_down_idx = 5'd12;
        else if (kp_down_oh[13]) kp_down_idx = 5'd13;
        else if (kp_down_oh[14]) kp_down_idx = 5'd14;
        else if (kp_down_oh[15]) kp_down_idx = 5'd15;
        else if (kp_down_oh[16]) kp_down_idx = 5'd16;
        else if (kp_down_oh[17]) kp_down_idx = 5'd17;
        else if (kp_down_oh[18]) kp_down_idx = 5'd18;
        else if (kp_down_oh[19]) kp_down_idx = 5'd19;
        else if (kp_down_oh[20]) kp_down_idx = 5'd20;
        else if (kp_down_oh[21]) kp_down_idx = 5'd21;
        else if (kp_down_oh[22]) kp_down_idx = 5'd22;
        else if (kp_down_oh[23]) kp_down_idx = 5'd23;
        else if (kp_down_oh[24]) kp_down_idx = 5'd24;
    end

    always @(posedge mclk or negedge aud_rst_n) begin
        if (!aud_rst_n) kp_level_d <= 25'd0;
        else          kp_level_d <= kp_level_mclk;
    end

    wire       pp_seq_ovf;
    wire [5:0] pp_seq_evt;
    seq_evt_cdc #(.SETTLE(2), .SKEW(0)) u_seq_evt_cdc (
        .src_clk    (mclk),
        .src_rst_n  (aud_rst_n),
        .src_pulse  (kp_down_any),
        .src_payload(kp_down_idx),
        .src_ovf    (pp_seq_ovf),
        .dst_clk    (pix_clk),
        .dst_rst_n  (vid_rst_n),
        .dst_bus    (pp_seq_evt)
    );

    wire       eng_we;
    wire [7:0] eng_addr;
    wire [7:0] eng_wdata;

    wire       tt_we, tt_done, tt_busy;
    wire       tt_owns_eff;

    wire [7:0] tt_addr, tt_wdata;
    wire [7:0]  tt_vcnt;

    wire        test_run    = (tt_vcnt != 8'd0);
    wire [1:0]  test_st_mclk = (!test_mode) ? 2'd0
                                  : (test_run ? 2'd2 : 2'd1);
    reg  [1:0]  test_st_s1, test_st_s2;
    always @(posedge pix_clk or negedge vid_rst_n) begin
        if (!vid_rst_n) begin
            test_st_s1 <= 2'd0;
            test_st_s2 <= 2'd0;
        end
        else begin
            test_st_s1 <= test_st_mclk;
            test_st_s2 <= test_st_s1;
        end
    end
    wire [1:0]  test_st_pix = test_st_s2;

    wire [9:0]  tt_vidx;
    wire [5:0]  tt_band;

    test_tone_src #(
        .N_VOICE (N_VOICE),
        .CLK_HZ  (12_500_000)
    ) u_test_tone (
        .clk       (mclk),
        .rst_n     (aud_rst_n),
        .cfg_ok    (codec_ready),
        .enable    (test_mode),
        .bus_gnt  (tt_owns_eff),
        .reg_we    (tt_we),
        .reg_addr  (tt_addr),
        .reg_wdata (tt_wdata),
        .busy      (tt_busy),
        .load_done (tt_done),
        .voice_cnt (tt_vcnt),
        .voice_idx (tt_vidx),
        .band_idx  (tt_band)
    );

    wire tt_owns = test_mode | tt_busy | tt_we;
    wire        sqv_busy;
    wire        sqv_busy_lock;


    wire        pe_we;
    wire [7:0]  pe_addr;
    wire [7:0]  pe_wdata;
    wire        pe_gnt;

    wire        sqv_we;
    wire [7:0]  sqv_addr;
    wire [7:0]  sqv_wdata;
    wire        sqv_gnt;

    assign dn_gnt   = ~tt_owns_eff & ~pe_we & ~nkp_page_dirty & ~sqv_busy;
    assign nm_gnt   = ~tt_owns_eff & ~pe_we & ~dn_we & ~sqv_busy;
    assign eng_hold = tt_owns_eff | sqv_busy | dn_load;
    assign pe_gnt   = ~tt_owns_eff & ~nkp_page_dirty;
    assign nkp_gnt = nm_gnt;

    assign sqv_gnt   = ~(test_mode | tt_busy | tt_we);

    assign sqv_busy_lock = sqv_busy;
    assign tt_owns_eff   = tt_owns;

    wire dn_we_ok = dn_we   & ~sqv_busy;
    wire nm_we_ok = nkp_we  & ~sqv_busy;

    assign eng_we    = tt_we ? tt_we : sqv_we ? sqv_we : pe_we ? pe_we
                    : dn_we_ok ? dn_we_ok : nm_we_ok ? nm_we_ok : 1'b0;
    assign eng_addr  = tt_we ? tt_addr : sqv_we ? sqv_addr : pe_we ? pe_addr
                    : dn_we_ok ? dn_addr  : nm_we_ok ? nkp_addr  : 8'h00;
    assign eng_wdata = tt_we ? tt_wdata : sqv_we ? sqv_wdata : pe_we ? pe_wdata
                    : dn_we_ok ? dn_wdata : nm_we_ok ? nkp_wdata : 8'h00;

    wire        tempo_page_ok = ~ui_page_sel & (ui_cur_page == 4'd4);
    wire [3:0]  pe_enc    = ui_enc_rot_pulse & ~{3'b000, tempo_page_ok};
    wire        pe_any    = |pe_enc;
    wire [1:0]  pe_knob_c = pe_enc[3] ? 2'd3 :
                            pe_enc[2] ? 2'd2 :
                            pe_enc[1] ? 2'd1 : 2'd0;
    wire        pe_dir_c  = pe_enc[3] ? ui_enc_rot_dir[3] :
                            pe_enc[2] ? ui_enc_rot_dir[2] :
                            pe_enc[1] ? ui_enc_rot_dir[1] : ui_enc_rot_dir[0];

    wire [2:0]  pe_page_c = ui_page_sel                     ? 3'd4
                          : (ui_cur_page[2:0] == 3'd4)      ? 3'd5
                          : ui_cur_page[2:0];
    wire [7:0]  pe_pay_m;
    wire        pe_req_pulse;
    wire        pe_ovf;

    ev_tgl_cdc #(
        .W      (8),
        .SETTLE (4)
    ) u_edit_cdc (
        .src_clk     (clk),
        .src_rst_n   (sys_rst_n),
        .src_pulse   (pe_any),
        .src_payload ({ui_cur_focus, pe_page_c, pe_knob_c, pe_dir_c}),
        .src_ovf     (pe_ovf),
        .src_ovf_clr (1'b0),
        .dst_clk     (mclk),
        .dst_rst_n   (aud_rst_n),
        .dst_pulse   (pe_req_pulse),
        .dst_payload (pe_pay_m),
        .dst_busy    ()
    );

    reg dn_load_d;
    always @(posedge mclk or negedge aud_rst_n) begin
        if (!aud_rst_n) dn_load_d <= 1'b0;
        else            dn_load_d <= dn_load;
    end
    wire pe_base_snap = dn_load_d & ~dn_load;

    wire        pe_busy;
    wire [3:0]  pe_dbg_val;

    param_edit u_param_edit (
        .clk        (mclk),
        .rst_n      (aud_rst_n),
        .bus_we     (eng_we),
        .bus_addr   (eng_addr),
        .bus_wdata  (eng_wdata),
        .base_snap  (pe_base_snap),
        .req_pulse  (pe_req_pulse),
        .req_page   ({pe_pay_m[5:3], pe_pay_m[2:1]}),
        .req_op     (pe_pay_m[7:6]),
        .req_dir    (pe_pay_m[0]),
        .pe_we      (pe_we),
        .pe_addr    (pe_addr),
        .pe_wdata   (pe_wdata),
        .pe_gnt     (pe_gnt),
        .busy       (pe_busy),
        .dbg_val    (pe_dbg_val)
    );


    wire signed [15:0] eng_l, eng_r;
    wire signed [15:0] fx_l, fx_r;

    wire       eng_vsel_hit;
    wire [7:0] eng_vsel_grp;
    wire [7:0] eng_vsel_vpg;
    wire [7:0] eng_grp_first_voice;
    wire [7:0] eng_grp_last_voice;
    wire [7:0] eng_grp_first_slot;
    wire [7:0] eng_grp_last_slot;

    tdm_group #(
        .N_VOICE (N_VOICE),
        .N_GROUP (N_GROUP),
        .N_CORE  (N_CORE)
    ) u_fm_engine (
        .clk         (mclk),
        .rst_n       (aud_rst_n),
        .sample_tick (sample_tick),
        .reg_we      (eng_we),
        .reg_addr    (eng_addr),
        .reg_wdata   (eng_wdata),
        .out_l       (eng_l),
        .out_r       (eng_r),
        .sel_hit         (eng_vsel_hit),
        .sel_grp         (eng_vsel_grp),
        .sel_vpg         (eng_vsel_vpg),
        .sel_first_voice (eng_grp_first_voice),
        .sel_last_voice  (eng_grp_last_voice),
        .sel_first_slot  (eng_grp_first_slot),
        .sel_last_slot   (eng_grp_last_slot)
    );

    wire signed [15:0] fx_wet_l, fx_wet_r;

    effects u_effects (
        .clk         (mclk),
        .rst_n       (aud_rst_n),
        .sample_tick (sample_tick),
        .reg_we      (eng_we),
        .reg_addr    (eng_addr),
        .reg_wdata   (eng_wdata),
        .in_l        (eng_l),
        .in_r        (eng_r),
        .out_l       (fx_l),
        .out_r       (fx_r),
        .wet_l       (fx_wet_l),
        .wet_r       (fx_wet_r)
    );

    reg  [7:0] vol_r;

    always @(posedge mclk or negedge aud_rst_n) begin
        if (!aud_rst_n)
            vol_r <= 8'd255;
        else if (eng_we && (eng_addr == 8'hF4))
            vol_r <= eng_wdata;
    end

    always @(posedge mclk or negedge aud_rst_n) begin
        if (!aud_rst_n)
            seq4part_r <= 1'b0;
        else if (eng_we && (eng_addr == 8'hF5))
            seq4part_r <= eng_wdata[0];
    end

    wire signed [23:0] l_vol = $signed(fx_l) * $signed({1'b0, vol_r});
    wire signed [23:0] r_vol = $signed(fx_r) * $signed({1'b0, vol_r});

    wire signed [15:0] l_data = l_vol[23:8];
    wire signed [15:0] r_data = r_vol[23:8];

    i2s_tx #(
        .WS_DELAY_BITS (0),
        .LEFT_ON_WS_LOW(0)
    ) u_i2s_tx (
        .clk         (mclk),
        .rst_n       (aud_rst_n),
        .l_data      (l_data),
        .r_data      (r_data),
        .bclk        (i2s_bclk),
        .lrclk       (i2s_daclrc),
        .dacdat      (i2s_dacdat),
        .sample_tick (sample_tick)
    );

    assign i2s_mclk = 1'b0;

    localparam integer PA_ON_DELAY_CYC = (SYS_CLK_HZ / 1000) * PA_ON_DELAY_MS;

    wire pa_gate = pll_lock & codec_ready;

    reg        pa_on;
    reg [31:0] pa_cnt;

    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            pa_on  <= 1'b0;
            pa_cnt <= 32'd0;
        end
        else if (!pa_gate) begin
            pa_on  <= 1'b0;
            pa_cnt <= 32'd0;
        end
        else if (!pa_on) begin
            if (pa_cnt >= PA_ON_DELAY_CYC - 1)
                pa_on  <= 1'b1;
            else
                pa_cnt <= pa_cnt + 32'd1;
        end
    end

    assign pa_en = PA_EN_ACTIVE_LOW ? ~pa_on : pa_on;

    assign led = 4'b0000;

    clk_gen_video u_clk_gen_video (
        .clk_50m (clk),
        .pix_clk (pix_clk),
        .ser_clk (ser_clk),
        .lock    (vid_lock)
    );

    rst_sync u_rst_sync_vid (
        .clk    (pix_clk),
        .arst_n (rst_n & vid_lock),
        .rst_n  (vid_rst_n)
    );

    wire [11:0] vx, vy;
    wire        vde, vhs, vvs, vsof;

    video_timing #(
        .H_ACTIVE (1024),
        .H_FP     (24),
        .H_SYNC   (136),
        .H_BP     (160),
        .V_ACTIVE (600),
        .V_FP     (1),
        .V_SYNC   (4),
        .V_BP     (23)
    ) u_video_timing (
        .clk   (pix_clk),
        .rst_n (vid_rst_n),
        .x     (vx),
        .y     (vy),
        .de    (vde),
        .hs    (vhs),
        .vs    (vvs),
        .sof   (vsof),
        .hcnt  (),
        .vcnt  ()
    );

    wire [2:0]  pp_algo, pp_fb, pp_block;
    wire [4:0]  pp_patch;
    wire [9:0]  pp_fnum;
    wire [15:0] pp_mult, pp_ar, pp_dr, pp_sl, pp_rr;
    wire [23:0] pp_tl;
    wire [11:0] pp_wf;
    wire        pp_gate, pp_cfg_ok;
    wire [3:0]  pp_led;
    wire       pp_fx_en;
    wire [2:0] pp_fx_room;
    wire [3:0] pp_fx_damp;
    wire [2:0] pp_fx_wet;
    wire       pp_fx_spread;
    wire [3:0] pp_fx_width;
    wire [7:0] pp_fx_predelay;
    wire [4:0] pp_cur_key;
    wire [3:0] pp_cur_key_p;
    wire       pp_key_on;

    assign pp_cur_key_p = pp_cur_key[3:0];

    param_mirror u_param_mirror (
        .mclk      (mclk),
        .mrst_n    (aud_rst_n),
        .reg_we    (eng_we),
        .reg_addr  (eng_addr),
        .reg_wdata (eng_wdata),
        .test_mode (test_mode),
        .cur_patch (dbg_patch),
        .gate      (gate_mclk),
        .cfg_ok    (cfg_ok_mclk),
        .led_stat  (4'b0000),
        .cur_key   (nkp_cur_key),
        .cur_key_on(nkp_key_on),
        .pix_clk   (pix_clk),
        .prst_n    (vid_rst_n),
        .p_algo    (pp_algo),
        .p_fb      (pp_fb),
        .p_fnum    (pp_fnum),
        .p_block   (pp_block),
        .p_mult    (pp_mult),
        .p_tl      (pp_tl),
        .p_ar      (pp_ar),
        .p_dr      (pp_dr),
        .p_sl      (pp_sl),
        .p_rr      (pp_rr),
        .p_wf      (pp_wf),
        .p_patch   (pp_patch),
        .p_gate    (pp_gate),
        .p_cfg_ok  (pp_cfg_ok),
        .p_led     (pp_led),
        .p_fx_en       (pp_fx_en),
        .p_fx_room     (pp_fx_room),
        .p_fx_damp     (pp_fx_damp),
        .p_fx_wet      (pp_fx_wet),
        .p_fx_spread   (pp_fx_spread),
        .p_fx_width    (pp_fx_width),
        .p_fx_predelay (pp_fx_predelay),
        .p_vib_depth   (pp_vib_depth),
        .p_vol         (pp_vol),
        .p_vel_level   (pp_vel_level),
        .p_cur_key    (pp_cur_key),
        .p_key_on     (pp_key_on)
    );

    wire [5:0]  pan_col, pan_row;
    wire [7:0]  pan_ch;
    wire [3:0]  pan_color;
    wire        pan_bold;

    reg [4:0]  pp_cur_note_m,  pp_cur_note_s;
    reg [2:0]  pp_cur_oct_m,   pp_cur_oct_s;
    reg        pp_sustain_m,   pp_sustain_s;
    reg        pp_mode_m,      pp_mode_s;
    reg [4:0]  pp_patch_m,     pp_patch_s;

    always @(posedge mclk or negedge aud_rst_n) begin
        if (!aud_rst_n) begin
            pp_cur_note_m <= 5'd31;
            pp_cur_oct_m  <= 3'd2;
            pp_sustain_m  <= 1'b0;
            pp_mode_m     <= 1'b0;
            pp_patch_m    <= 5'd0;
        end
        else begin
            pp_cur_note_m <= nkp_cur_note;
            pp_cur_oct_m  <= nkp_cur_oct;
            pp_sustain_m  <= nkp_sustain_on;
            pp_mode_m     <= ui_mode;
            pp_patch_m    <= dbg_patch;
        end
    end

    always @(posedge pix_clk or negedge vid_rst_n) begin
        if (!vid_rst_n) begin
            pp_cur_note_s <= 5'd31;
            pp_cur_oct_s  <= 3'd2;
            pp_sustain_s  <= 1'b0;
            pp_mode_s     <= 1'b0;
            pp_patch_s    <= 5'd0;
        end
        else begin
            pp_cur_note_s <= pp_cur_note_m;
            pp_cur_oct_s  <= pp_cur_oct_m;
            pp_sustain_s  <= pp_sustain_m;
            pp_mode_s     <= pp_mode_m;
            pp_patch_s    <= pp_patch_m;
        end
    end

    wire [4:0] pp_cur_note  = pp_cur_note_s;
    wire [2:0] pp_cur_oct   = pp_cur_oct_s;
    wire       pp_sustain_on = pp_sustain_s;
    wire       pp_mode_flag  = pp_mode_s;
    wire [4:0] pp_cur_patch  = pp_patch_s;
    wire [3:0] pp_cur_note_p = pp_cur_note[3:0];

    wire       pp_seq_tick;
    wire [4:0] pp_seq_step;
    wire       pp_seq_step_on;
    wire       pp_tempo_pulse;
    wire [0:0] pp_tempo_pay;

    reg  sc_gen_r1, sc_gen_r2;
    always @(posedge pix_clk or negedge vid_rst_n) begin
        if (!vid_rst_n) begin
            sc_gen_r1 <= 1'b0; sc_gen_r2 <= 1'b0;
        end
        else begin
            sc_gen_r1 <= 1'b1; sc_gen_r2 <= sc_gen_r1;
        end
    end
    wire sc_guide_en_p = sc_gen_r2;

    param_panel u_param_panel (
        .clk      (pix_clk),
        .rst_n    (vid_rst_n),
        .sof      (vsof),
        .p_algo   (pp_algo),
        .p_fb     (pp_fb),
        .p_fnum   (pp_fnum),
        .p_block  (pp_block),
        .p_mult   (pp_mult),
        .p_tl     (pp_tl),
        .p_ar     (pp_ar),
        .p_dr     (pp_dr),
        .p_sl     (pp_sl),
        .p_rr     (pp_rr),
        .p_wf     (pp_wf),
        .p_patch  (pp_patch),
        .p_gate   (pp_gate),
        .p_cfg_ok (pp_cfg_ok),
        .p_led    (pp_led),
        .p_fx_en       (pp_fx_en),
        .p_fx_room     (pp_fx_room),
        .p_fx_damp     (pp_fx_damp),
        .p_fx_wet      (pp_fx_wet),
        .p_fx_spread   (pp_fx_spread),
        .p_fx_width    (pp_fx_width),
        .p_fx_predelay (pp_fx_predelay),
        .p_vol         (pp_vol),
        .p_vib_depth   (pp_vib_depth),
        .cur_note      (pp_cur_note_p),
        .cur_oct       (pp_cur_oct),
        .sustain_on    (pp_sustain_on),
        .mode_flag     (pp_mode_flag),
        .cur_patch     (pp_cur_patch),
        .p_cur_page    (ui_cur_page),
        .p_cur_focus   (ui_cur_focus),
        .p_ui_mode     (ui_mode),
        .p_cur_key     (pp_cur_key_p),
        .p_key_on      (pp_key_on),
        .p_key_hi      (pp_cur_key[4]),
        .p_ui_layer    (ui_layer),
        .p_fn_btn      (ui_btn_pressed[5:0]),
        .p_seq_evt     (pp_seq_evt),
        .seq_tick      (pp_seq_tick),
        .seq_step      (pp_seq_step),
        .seq_step_on   (pp_seq_step_on),
        .bt_status      (sl_obs_status),
        .bt_cmd         (sl_obs_cmd),
        .bt_seq         (sl_obs_seq),
        .bt_link        (1'b1),
        .score_total    (sl_total_steps),
        .score_step_ms  (sl_step_ms),
        .score_mode     (score_mode_v),
        .score_cur      (sp_cur_step8),
        .guide_on       (sp_playing),
        .p_glide_en     (glide_en_mclk),
        .p_vel_en       (vel_en_mclk),
        .accomp_active  (sp_accomp_active),
        .test_st        (test_st_pix),
        .p_tempo_pulse (pp_tempo_pulse),
        .p_tempo_dir   (pp_tempo_pay),
        .we       (pan_we),
        .w_col    (pan_col),
        .w_row    (pan_row),
        .w_ch     (pan_ch),
        .w_color  (pan_color),
        .w_bold   (pan_bold)
    );

    wire [5:0] seq_pay_m;
    wire       seq_tick_m;
    wire       play_en_mclk;

    ev_tgl_cdc #(
        .W      (6),
        .SETTLE (4)
    ) u_seq_cdc (
        .src_clk     (pix_clk),
        .src_rst_n   (vid_rst_n),
        .src_pulse   (pp_seq_tick),
        .src_payload ({pp_seq_step_on, pp_seq_step}),
        .src_ovf     (),
        .src_ovf_clr (1'b0),
        .dst_clk     (mclk),
        .dst_rst_n   (aud_rst_n),
        .dst_pulse   (seq_tick_m),
        .dst_payload (seq_pay_m),
        .dst_busy    ()
    );

    reg play_en_s1, play_en_s2;
    always @(posedge mclk or negedge aud_rst_n) begin
        if (!aud_rst_n) begin
            play_en_s1 <= 1'b0;
            play_en_s2 <= 1'b0;
        end
        else begin
            play_en_s1 <= ui_mode;
            play_en_s2 <= play_en_s1;
        end
    end
    assign play_en_mclk = play_en_s2;

    seq_play #(
        .CLK_HZ  (MCLK_HZ),
        .GATE_MS (120)
    ) u_seq_play (
        .clk        (mclk),
        .rst_n      (aud_rst_n),
        .tick_pulse (seq_tick_m),
        .step_on    (seq_pay_m[5]),
        .step_pitch (seq_pay_m[4:0]),
        .play_en    (play_en_mclk),
        .key_hold   (seq_key_hold),
        .cur_step   ()
    );


    reg        page_sel_r1, page_sel_r2;
    reg [1:0]  seq_trk_r1, seq_trk_r2;
    reg [4:0]  seq_step_r1, seq_step_r2;
    reg        umode_r1, umode_r2;

    always @(posedge pix_clk or negedge vid_rst_n) begin
        if (!vid_rst_n) begin
            page_sel_r1 <= 1'b0; page_sel_r2 <= 1'b0;
            seq_trk_r1  <= 2'd0; seq_trk_r2  <= 2'd0;
            seq_step_r1 <= 5'd0; seq_step_r2 <= 5'd0;
            umode_r1    <= 1'b0; umode_r2    <= 1'b0;
        end
        else begin
            page_sel_r1 <= ui_page_sel; page_sel_r2 <= page_sel_r1;
            seq_trk_r1  <= ui_seq_trk;  seq_trk_r2  <= seq_trk_r1;
            seq_step_r1 <= ui_seq_step; seq_step_r2 <= seq_step_r1;
            umode_r1    <= ui_mode;     umode_r2    <= umode_r1;
        end
    end

    reg  [7:0]  sp_cur_r1, sp_cur_r2;
    reg         sp_acc_r1,  sp_acc_r2;
    reg  [1:0]  sp_mode_r1, sp_mode_r2;

    always @(posedge pix_clk or negedge vid_rst_n) begin
        if (!vid_rst_n) begin
            sp_cur_r1 <= 8'd0; sp_cur_r2 <= 8'd0;
            sp_acc_r1 <= 1'b0; sp_acc_r2 <= 1'b0;
            sp_mode_r1 <= 2'd2; sp_mode_r2 <= 2'd2;
        end
        else begin
            sp_cur_r1 <= sp_cur_step8; sp_cur_r2 <= sp_cur_r1;
            sp_acc_r1 <= sp_accomp_active; sp_acc_r2 <= sp_acc_r1;
            sp_mode_r1 <= 2'd2;  sp_mode_r2 <= sp_mode_r1;
        end
    end
    wire [7:0] sp_cur_step8_p     = sp_cur_r2;
    wire       sp_accomp_active_p = sp_acc_r2;
    wire [1:0] sp_mode_p          = sp_mode_r2;

    wire        sq_we;
    wire [6:0]  sq_col;
    wire [5:0]  sq_row;
    wire [7:0]  sq_ch;
    wire [3:0]  sq_color;
    wire        sq_bold;
    wire        sq_tick;
    wire [23:0] sq_pay;
    wire [4:0]  sq_cur;
    wire [20:0] sq_tempo;
    wire        sq_play_en;

    wire sq_tempo_inc = page_sel_r2 & ui_enc_sw_press[0];
    wire sq_tempo_dec = page_sel_r2 & ui_enc_sw_long[0];

    reg k3_level_d;
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n)          k3_level_d <= 1'b0;
        else                     k3_level_d <= ui_btn_pressed[2];
    end
    wire k3_release_pulse = ~ui_btn_pressed[2] & k3_level_d;

    wire sq_mode_tgl_s   = ui_page_sel & ui_enc_sw_press[1];
    wire sq_mute_tgl_s   = ui_page_sel & ui_enc_sw_long[1];
    wire sq_tr_up_s      = ui_page_sel & ui_enc_sw_press[2];
    wire sq_tr_dn_s      = ui_page_sel & ui_enc_sw_long[2];
    wire sq_step_clear_s = ui_page_sel & k3_release_pulse;

    wire sq_dump_trig_s = ui_page_sel & ui_enc_sw_press[3];

    wire sq_mode_tgl, sq_mute_tgl, sq_tr_up, sq_tr_dn, sq_step_clear;
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_sq_mode_cdc (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(sq_mode_tgl_s),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(pix_clk), .dst_rst_n(vid_rst_n),
        .dst_pulse(sq_mode_tgl), .dst_payload(), .dst_busy());
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_sq_mute_cdc (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(sq_mute_tgl_s),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(pix_clk), .dst_rst_n(vid_rst_n),
        .dst_pulse(sq_mute_tgl), .dst_payload(), .dst_busy());
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_sq_trup_cdc (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(sq_tr_up_s),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(pix_clk), .dst_rst_n(vid_rst_n),
        .dst_pulse(sq_tr_up), .dst_payload(), .dst_busy());
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_sq_trdn_cdc (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(sq_tr_dn_s),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(pix_clk), .dst_rst_n(vid_rst_n),
        .dst_pulse(sq_tr_dn), .dst_payload(), .dst_busy());
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_sq_clr_cdc (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(sq_step_clear_s),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(pix_clk), .dst_rst_n(vid_rst_n),
        .dst_pulse(sq_step_clear), .dst_payload(), .dst_busy());

    wire sq_dump_trig;
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_sq_dump_cdc (
        .src_clk(clk), .src_rst_n(sys_rst_n), .src_pulse(sq_dump_trig_s),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(pix_clk), .dst_rst_n(vid_rst_n),
        .dst_pulse(sq_dump_trig), .dst_payload(), .dst_busy());


    wire [4:0]  sd_rd_idx;
    wire [23:0] sd_exp_pay;

    wire        sl_seqd_req;
    reg         sd_act_r1, sd_act_r2;
    always @(posedge pix_clk or negedge vid_rst_n) begin
        if (!vid_rst_n) begin
            sd_act_r1 <= 1'b0; sd_act_r2 <= 1'b0;
        end
        else begin
            sd_act_r1 <= sl_seqd_req; sd_act_r2 <= sd_act_r1;
        end
    end

    seq_page #(
        .COLS (128),
        .ROWS (37)
    ) u_seq_page (
        .clk        (pix_clk),
        .rst_n      (vid_rst_n),
        .sof        (vsof),
        .page_sel   (page_sel_r2),
        .trk_sel    (seq_trk_r2),
        .step_sel   (seq_step_r2),
        .ui_mode    (umode_r2),
        .p_seq_evt  (pp_seq_evt),
        .p_fx_wet   (pp_fx_wet),
        .p_fx_room  (pp_fx_room),
        .p_fx_damp  (pp_fx_damp),
        .p_fx_spread(pp_fx_spread),
        .bt_status  (sl_obs_status),
        .bt_cmd     (sl_obs_cmd),
        .bt_seq     (sl_obs_seq),
        .bt_link    (1'b1),
        .score_total(sl_total_steps),
        .score_step_ms(sl_step_ms),
        .score_mode (score_mode_v),
        .score_cur  (sp_cur_step8_p),
        .guide_on   (sp_playing),
        .accomp_active(sp_accomp_active_p),
        .tempo_inc  (sq_tempo_inc),
        .tempo_dec  (sq_tempo_dec),
        .we         (sq_we),
        .w_col      (sq_col),
        .w_row      (sq_row),
        .w_ch       (sq_ch),
        .w_color    (sq_color),
        .w_bold     (sq_bold),
        .mode_tgl_pulse   (sq_mode_tgl),
        .tr_up_pulse      (sq_tr_up),
        .tr_dn_pulse      (sq_tr_dn),
        .mute_tgl_pulse   (sq_mute_tgl),
        .step_clear_pulse (sq_step_clear),
        .seq_tick   (sq_tick),
        .seq_pay    (sq_pay),
        .seq_cur    (sq_cur),
        .seq_tempo  (sq_tempo),
        .seq_play_en(sq_play_en),
        .exp_idx    (sd_rd_idx),
        .exp_pay    (sd_exp_pay),
        .dump_act   (sd_act_r2)
    );

    wire [24:0] sq_pay_m;
    wire        sq_tick_m;

    ev_tgl_cdc #(
        .W      (25),
        .SETTLE (4)
    ) u_seq4_cdc (
        .src_clk     (pix_clk),
        .src_rst_n   (vid_rst_n),
        .src_pulse   (sq_tick),
        .src_payload ({1'b0, sq_pay}),
        .src_ovf     (),
        .src_ovf_clr (1'b0),
        .dst_clk     (mclk),
        .dst_rst_n   (aud_rst_n),
        .dst_pulse   (sq_tick_m),
        .dst_payload (sq_pay_m),
        .dst_busy    ()
    );

    seq_play4 #(
        .CLK_HZ   (MCLK_HZ),
        .GATE_MS  (120),
        .TICK_MIN (2),
        .VOICE0   (124)
    ) u_seq_play4 (
        .clk        (mclk),
        .rst_n      (aud_rst_n),
        .sample_tick(sample_tick),
        .bus_gnt    (sqv_gnt),
        .reg_we     (sqv_we),
        .reg_addr   (sqv_addr),
        .reg_wdata  (sqv_wdata),
        .busy       (sqv_busy),
        .tick_pulse (sq_tick_m),
        .track_pay  (sq_pay_m[23:0]),
        .play_en    (play_en_mclk),
        .seq4part   (seq4part_r),
        .key_hold   (),
        .cur_step   ()
    );

    wire        tempo_enc_ok = tempo_page_ok;
    ev_tgl_cdc #(
        .W      (1),
        .SETTLE (4)
    ) u_tempo_cdc (
        .src_clk     (clk),
        .src_rst_n   (sys_rst_n),
        .src_pulse   (ui_enc_rot_pulse[3] & tempo_enc_ok),
        .src_payload (ui_enc_rot_dir[3]),
        .src_ovf     (),
        .src_ovf_clr (1'b0),
        .dst_clk     (pix_clk),
        .dst_rst_n   (vid_rst_n),
        .dst_pulse   (pp_tempo_pulse),
        .dst_payload (pp_tempo_pay),
        .dst_busy    ()
    );

    wire [9:0]         cap_wav_addr, cap_lis_addr;
    wire signed [15:0] cap_pcm, cap_pcm_y;
    wire [9:0]         cap_trig_pos;
    wire [10:0]        cap_valid_cnt;
    wire               cap_trig_valid;

    wire [9:0]  spec_rd_addr;
    wire        wave_busy;
    wire        spec_busy;
    wire        lis_busy;

    wire cap_arm = vsof;

    scope_capture #(
        .WIN     (1024),
        .DECIM   (2),
        .ADDR_W  (10),
        .TRIG_TH (16'sd32),
        .TGL_DLY (8)
    ) u_scope_capture (
        .mclk        (mclk),
        .mrst_n      (aud_rst_n),
        .sample_tick (sample_tick),
        .pcm_l       (l_data),
        .pcm_r       (r_data),
        .pix_clk     (pix_clk),
        .prst_n      (vid_rst_n),
        .trig_arm    (cap_arm),
        .wav_addr    (wave_busy ? cap_wav_addr : spec_rd_addr),
        .lis_addr    (cap_lis_addr),
        .pcm_out     (cap_pcm),
        .pcm_out_y   (cap_pcm_y),
        .trig_pos    (cap_trig_pos),
        .trig_valid  (cap_trig_valid),
        .valid_cnt   (cap_valid_cnt),
        .dbg_wptr    ()
    );

    wire [11:0] gx, gy;
    wire        gde;

    wire [23:0] spec_rgb, wave_rgb, lis_rgb;
    wire        spec_hit, wave_hit, lis_hit;
    wire [3:0]  level_msb;

    wire [23:0] disp_rgb;

    reg [1:0] focus_ff1, focus_ff2;
    always @(posedge pix_clk or negedge vid_rst_n) begin
        if (!vid_rst_n) begin
            focus_ff1 <= 2'd0;
            focus_ff2 <= 2'd0;
        end
        else begin
            focus_ff1 <= ui_cur_focus;
            focus_ff2 <= focus_ff1;
        end
    end
    wire [1:0] focus_op_pix = focus_ff2;

    reg [12:0] post_sof;
    always @(posedge pix_clk or negedge vid_rst_n) begin
        if (!vid_rst_n)            post_sof <= 13'd0;
        else if (vsof)             post_sof <= 13'd0;
        else if (post_sof != 13'd3900) post_sof <= post_sof + 13'd1;
    end

    wire spec_go = (post_sof == 13'd3900) && !spec_busy;
    wire lis_go  = vsof & ~lis_busy;

    wire [15:0]     spec_mag;
    wire [5:0]      spec_band;
    wire            spec_we;

    spectrum_dft #(
        .N        (512),
        .NBAND    (42),
        .WIN      (1024),
        .MAGW     (16),
        .MAG_SH   (24),
        .FS_STORE (24414)
    ) u_spectrum_dft (
        .clk       (pix_clk),
        .rst_n     (vid_rst_n),
        .start     (spec_go),
        .busy      (spec_busy),
        .rd_addr   (spec_rd_addr),
        .pcm       (cap_pcm),
        .valid_cnt (cap_valid_cnt),
        .mag_out   (spec_mag),
        .band_idx  (spec_band),
        .mag_we    (spec_we)
    );

    spectrum_bars #(
        .X0      (336),
        .Y0      (0),
        .X1      (1024),
        .Y1      (200),
        .NBAND   (42),
        .MAGW    (16),
        .OUT_LAT (4),
        .PAD     (6),
        .GAP     (1),
        .BWLOG   (4)
    ) u_spectrum_bars (
        .clk       (pix_clk),
        .rst_n     (vid_rst_n),
        .de        (gde),
        .x         (gx),
        .y         (gy),
        .mag_in    (spec_mag),
        .band_idx  (spec_band),
        .mag_we    (spec_we),
        .trig_valid(cap_trig_valid),
        .valid_cnt (cap_valid_cnt),
        .rgb       (spec_rgb),
        .hit       (spec_hit)
    );

    wave_plot #(
        .X0   (336),
        .Y0   (200),
        .X1   (1024),
        .Y1   (400),
        .PAD  (8),
        .WIN  (1024),
        .OUT_LAT (4),
        .SPAN    (320),
        .LINE_THICK (1)
    ) u_wave_plot (
        .clk       (pix_clk),
        .rst_n     (vid_rst_n),
        .de        (gde),
        .x         (gx),
        .y         (gy),
        .sof       (vsof),
        .rd_addr   (cap_wav_addr),
        .pcm       (cap_pcm),
        .trig_pos  (cap_trig_pos),
        .valid_cnt (cap_valid_cnt),
        .trig_valid(cap_trig_valid),
        .rgb       (wave_rgb),
        .hit       (wave_hit),
        .level_msb (level_msb),
        .busy      (wave_busy)
    );

    lissajous #(
        .X0        (336),
        .Y0        (400),
        .X1        (1024),
        .Y1        (600),
        .DPW       (181),
        .DPH       (181),
        .OUT_LAT   (4),
        .WIN       (1024),
        .XLSH      (60),
        .YLSH      (0)
    ) u_lissajous (
        .clk       (pix_clk),
        .rst_n     (vid_rst_n),
        .de        (gde),
        .x         (gx),
        .y         (gy),
        .sof       (lis_go),
        .rd_addr   (cap_lis_addr),
        .pcm       (cap_pcm_y),
        .trig_pos  (cap_trig_pos),
        .valid_cnt (cap_valid_cnt),
        .trig_valid(cap_trig_valid),
        .cur_note  (pp_cur_note),
        .cur_oct   (pp_cur_oct),
        .rgb       (lis_rgb),
        .hit       (lis_hit),
        .busy      (lis_busy)
    );


    wire probe_pan_we = pan_we;

    reg probe_locks_ff1, probe_locks_ff2;
    always @(posedge pix_clk or negedge vid_rst_n) begin
        if (!vid_rst_n) begin
            probe_locks_ff1 <= 1'b0;
            probe_locks_ff2 <= 1'b0;
        end
        else begin
            probe_locks_ff1 <= (pll_lock & vid_lock);
            probe_locks_ff2 <= probe_locks_ff1;
        end
    end
    wire probe_locks_pix = probe_locks_ff2;

    display_top #(
        .H_ACTIVE (1024),
        .V_ACTIVE (600),
        .BUILD_SIG (8'hA5),
        .CHAR_ROM_SELFTEST (0),
        .FS_HZ    (12_500_000/256),
        .N_VOICE  (240)
    ) u_display_top (
        .clk      (pix_clk),
        .rst_n    (vid_rst_n),
        .de       (vde),
        .x        (vx),
        .y        (vy),
        .sof      (vsof),
        .probe_pan_we (probe_pan_we),
        .probe_locks  (probe_locks_pix),
        .p_we     (pan_we),
        .p_col    (pan_col),
        .p_row    (pan_row),
        .p_ch     (pan_ch),
        .p_color  (pan_color),
        .p_bold   (pan_bold),
        .page_sel (page_sel_r2),
        .sq_we     (sq_we),
        .sq_col   (sq_col),
        .sq_row   (sq_row),
        .sq_ch    (sq_ch),
        .sq_color (sq_color),
        .sq_bold  (sq_bold),
        .spec_rgb (spec_rgb),  .spec_hit (spec_hit),
        .wave_rgb (wave_rgb),  .wave_hit (wave_hit),
        .lis_rgb  (lis_rgb),   .lis_hit  (lis_hit),
        .level_msb(level_msb),
        .p_tl      (pp_tl),
        .p_ar      (pp_ar),
        .p_dr      (pp_dr),
        .p_sl      (pp_sl),
        .p_rr      (pp_rr),
        .focus_op  (focus_op_pix),
        .rgb      (disp_rgb),
        .gx       (gx),
        .gy       (gy),
        .gde      (gde)
    );

    hdmi_tx_top #(
        .USE_NEG_ODDR (0),
        .USE_OSER10   (1)
    ) u_hdmi_tx (
        .pix_clk    (pix_clk),
        .ser_clk    (ser_clk),
        .rst_n      (vid_rst_n),
        .vde        (vde),
        .hs         (vhs),
        .vs         (vvs),
        .rgb        (disp_rgb),
        .tmds_data_p(tmds_data_p),
        .tmds_data_n(tmds_data_n),
        .tmds_clk_p (tmds_clk_p),
        .tmds_clk_n (tmds_clk_n)
    );


    wire _unused = &{1'b0, key1_pulse, sample_tick,
                     dbg_algo, dbg_wave,
                     cap_trig_pos, cap_trig_valid, 1'b0,
                     fx_wet_l, fx_wet_r, 1'b0,
                     nkp_v_on_o, nkp_v_gate_o, nkp_busy,
                     eng_vsel_hit, eng_vsel_grp, eng_vsel_vpg,
                     eng_grp_first_voice, eng_grp_last_voice,
                     eng_grp_first_slot, eng_grp_last_slot,
                     tt_done, tt_vcnt, tt_vidx, tt_band, 1'b0,
                     nkp_cur_key, nkp_key_on,
                     pe_ovf, pe_busy, pe_dbg_val,
                     nkp_mode_flag,
                     ui_layer, ui_btn_pressed, ui_shift_home, uk_seq_stop,
                     sl_obs_status, sl_obs_seq, sl_obs_cmd, sp_playing};

    wire [7:0]  bt_rx_data;
    wire        bt_rx_valid;
    wire        bt_tx_start;
    wire [7:0]  bt_tx_data;
    wire        bt_tx_busy;

    wire        sl_wr_en;
    wire [7:0]  sl_wr_addr;
    wire [39:0] sl_wr_data;
    wire        sl_clear_pulse;
    wire        sl_clear_done;
    wire        sl_cmd_head, sl_cmd_start, sl_cmd_stop, sl_cmd_mode_pulse;
    wire        sl_loop;
    wire [1:0]  sl_mode;

    wire [7:0]  sp_rd_addr;
    wire [39:0] sp_rd_data;
    wire [24:0] sp_hit, sp_hold, sp_breath, sp_far;
    wire [7:0]  sp_ramp;
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            sc_guide_en_r <= 1'b1;
        end
        else if (uk_sc_guide) sc_guide_en_r <= ~sc_guide_en_r;
    end

    wire sc_start_eff      = sl_cmd_start | (uk_sc_play & ~sp_playing);
    wire sc_stop_eff       = sl_cmd_stop  | (uk_sc_play &  sp_playing);

    wire [24:0] sp_hit_g    = sp_hit    & {25{sc_guide_en_r}};
    wire [24:0] sp_hold_g   = sp_hold   & {25{sc_guide_en_r}};
    wire [24:0] sp_breath_g = sp_breath & {25{sc_guide_en_r}};
    wire [24:0] sp_far_g    = sp_far    & {25{sc_guide_en_r}};

    assign score_mode_v = {6'd0, sl_mode};

    patch_wr_cdc #(.SETTLE(3)) u_patch_wr_cdc (
        .src_clk    (clk),
        .src_rst_n  (sys_rst_n),
        .src_pulse  (pcdc_req),
        .src_kind   (pcdc_kind_i),
        .src_a      (pcdc_a_i),
        .src_b      (pcdc_b_i),
        .src_word   (pcdc_word_i),
        .dst_clk    (mclk),
        .dst_rst_n  (aud_rst_n),
        .dst_kind   (pcdc_kind),
        .dst_a      (pcdc_a),
        .dst_b      (pcdc_b),
        .dst_word   (pcdc_word),
        .dst_pulse  (pcdc_pulse)
    );

    wire        sp_notify_pulse;
    wire [7:0]  sp_notify_cmd, sp_notify_status;

    wire [74:0] guide_lvl;


    uart #(
        .CLK_HZ (SYS_CLK_HZ),
        .BAUD   (115_200)
    ) u_bt_uart (
        .clk    (clk),
        .rst_n  (sys_rst_n),
        .tx_start (bt_tx_start),
        .tx_data  (bt_tx_data),
        .tx_busy  (bt_tx_busy),
        .txd_o  (bt_txd_o),
        .rxd_i  (bt_rxd_i),
        .rx_valid (bt_rx_valid),
        .rx_data  (bt_rx_data)
    );

    reg  [7:0] sp_cur_d;
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) sp_cur_d <= 8'd0;
        else            sp_cur_d <= sp_cur_step_o;
    end
    wire        st_step_tick = (sp_cur_step_o != sp_cur_d) && sp_playing;
    wire        st_hold_ovf  = sp_notify_pulse && (sp_notify_cmd == 8'h02)
                                               && (sp_notify_status == 8'h06);

    wire        sl_seqd_local;
    ev_tgl_cdc #(.W(1), .SETTLE(4)) u_sq_dump_sys_cdc (
        .src_clk(pix_clk), .src_rst_n(vid_rst_n), .src_pulse(sq_dump_trig),
        .src_payload(1'b1), .src_ovf(), .src_ovf_clr(1'b0),
        .dst_clk(clk), .dst_rst_n(sys_rst_n),
        .dst_pulse(sl_seqd_local), .dst_payload(), .dst_busy());

    wire        sl_seqd_rdy;
    wire        seqd_valid;
    wire [4:0]  seqd_step;
    wire [7:0]  seqd_d0, seqd_d1, seqd_d2, seqd_d3;

    seq_dump_cdc u_seq_dump_cdc (
        .clk_sys   (clk),
        .rst_sys_n (sys_rst_n),
        .start     (sl_seqd_req),
        .rdy       (sl_seqd_rdy),
        .out_valid (seqd_valid),
        .out_step  (seqd_step),
        .out_d0    (seqd_d0),
        .out_d1    (seqd_d1),
        .out_d2    (seqd_d2),
        .out_d3    (seqd_d3),
        .clk_pix   (pix_clk),
        .rst_pix_n (vid_rst_n),
        .rd_idx    (sd_rd_idx),
        .pay_in    (sd_exp_pay)
    );

    score_link #(
        .CLK_HZ (SYS_CLK_HZ),
        .BAUD   (115_200)
    ) u_score_link (
        .clk         (clk),
        .rst_n       (sys_rst_n),
        .rx_valid    (bt_rx_valid),
        .rx_data     (bt_rx_data),
        .tx_start    (bt_tx_start),
        .tx_data     (bt_tx_data),
        .tx_busy     (bt_tx_busy),
        .wr_en       (sl_wr_en),
        .wr_addr     (sl_wr_addr),
        .wr_data     (sl_wr_data),
        .clear_pulse (sl_clear_pulse),
        .clear_done  (sl_clear_done),
        .cmd_head    (sl_cmd_head),
        .cmd_total_steps (sl_total_steps),
        .cmd_step_ms (sl_step_ms),
        .cmd_loop    (sl_loop),
        .cmd_start   (sl_cmd_start),
        .cmd_stop    (sl_cmd_stop),
        .cmd_mode    (sl_mode),
        .cmd_mode_pulse (sl_cmd_mode_pulse),
        .notify_pulse (sp_notify_pulse),
        .notify_cmd   (sp_notify_cmd),
        .notify_status (sp_notify_status),
        .pt_wr         (sl_pt_wr),
        .pt_wr_kind    (sl_pt_kind),
        .pt_wr_slot    (sl_pt_slot),
        .pt_wr_idx     (sl_pt_idx),
        .pt_wr_word    (sl_pt_word),
        .pt_sel        (sl_pt_sel),
        .pt_sel_upd    (sl_pt_sel_upd),
        .pt_valid_bits (sl_pt_vbits_sys),
        .obs_status (sl_obs_status),
        .obs_seq    (sl_obs_seq),
        .obs_cmd    (sl_obs_cmd),
        .st_playing  (sp_playing),
        .st_seq_play (ui_mode),
        .st_mode     (sp_mode_o),
        .st_loop     (sl_loop),
        .st_total    (sl_total_steps),
        .st_cur      ({1'b0, sp_cur_step_o}),
        .st_step_tick(st_step_tick),
        .st_hold_ovf (st_hold_ovf),
        .seqd_valid  (seqd_valid),
        .seqd_step   (seqd_step),
        .seqd_d0     (seqd_d0),
        .seqd_d1     (seqd_d1),
        .seqd_d2     (seqd_d2),
        .seqd_d3     (seqd_d3),
        .seqd_req    (sl_seqd_req),
        .seqd_rdy    (sl_seqd_rdy),
        .seqd_local  (sl_seqd_local)
    );

    score_store u_score_store (
        .clk         (clk),
        .rst_n       (sys_rst_n),
        .wr_en       (sl_wr_en),
        .wr_addr     (sl_wr_addr),
        .wr_data     (sl_wr_data),
        .clear_pulse (sl_clear_pulse),
        .clear_busy  (),
        .clear_done  (sl_clear_done),
        .rd_addr     (sp_rd_addr),
        .rd_data     (sp_rd_data)
    );

    score_play u_score_play (
        .clk         (clk),
        .rst_n       (sys_rst_n),
        .tick_ms     (tick_ms),
        .cmd_head    (sl_cmd_head),
        .cmd_total_steps (sl_total_steps),
        .cmd_step_ms (sl_step_ms),
        .cmd_loop    (sl_loop),
        .cmd_start   (sc_start_eff),
        .cmd_stop    (sc_stop_eff),
        .cmd_mode    (sl_mode),
        .cmd_mode_pulse (sl_cmd_mode_pulse),
        .cmd_mode_local (uk_sc_mode),
        .rd_addr     (sp_rd_addr),
        .rd_data     (sp_rd_data),
        .guide_hit    (sp_hit),
        .guide_hold   (sp_hold),
        .guide_breath (sp_breath),
        .guide_far    (sp_far),
        .ramp_r       (sp_ramp),
        .accomp       (sp_accomp),
        .vel_cur      (sp_vel),
        .playing      (sp_playing),
        .cur_step_o   (sp_cur_step_o),
        .mode_o       (sp_mode_o),
        .notify_pulse (sp_notify_pulse),
        .notify_cmd   (sp_notify_cmd),
        .notify_status (sp_notify_status)
    );

    reg  [5:0] sp_vel_d;
    reg        sp_vel_pulse;
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            sp_vel_d     <= 6'd0;
            sp_vel_pulse <= 1'b0;
        end
        else begin
            sp_vel_pulse <= (sp_vel != sp_vel_d);
            sp_vel_d     <= sp_vel;
        end
    end

    ev_tgl_cdc #(.W(6), .SETTLE(2)) u_vel_cdc (
        .src_clk      (clk),
        .src_rst_n    (sys_rst_n),
        .src_pulse    (sp_vel_pulse),
        .src_payload  (sp_vel),
        .src_ovf      (),
        .src_ovf_clr  (1'b1),
        .dst_clk      (mclk),
        .dst_rst_n    (aud_rst_n),
        .dst_pulse    (),
        .dst_payload  (vel_cur_mclk),
        .dst_busy     ()
    );


    ws2812_guide u_guide (
        .kb_pressed (ui_kb_pressed),
        .guide_hit  (sp_hit_g),
        .guide_hold (sp_hold_g),
        .guide_breath (sp_breath_g),
        .guide_far  (sp_far_g),
        .lvl_bus    (guide_lvl)
    );

    reg [23:0] ws_por_cnt;
    reg        ws_por_n;
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            ws_por_cnt <= 24'd0;
            ws_por_n   <= 1'b0;
        end
        else if (ws_por_cnt != 24'd50_000) begin
            ws_por_cnt <= ws_por_cnt + 24'd1;
            ws_por_n   <= 1'b0;
        end
        else begin
            ws_por_n   <= 1'b1;
        end
    end

    ws2812 #(
        .CLK_HZ (SYS_CLK_HZ),
        .TEST_BRIGHT (0)
    ) u_ws2812 (
        .clk    (clk),
        .rst_n  (sys_rst_n & ws_por_n),
        .tick_ms(tick_ms),
        .lvl_bus(guide_lvl),
        .ramp_r (sp_ramp),
        .dout   (ws2812_do)
    );

endmodule
