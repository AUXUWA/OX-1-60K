// 时序约束（Synopsys Design Constraints）

create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]


set_false_path -from [get_ports {rst_n}]
set_false_path -from [get_ports {key1_n}]
set_false_path -from [get_ports {key2_n}]

set_false_path -to [get_ports {led[*]}]






set_false_path -from [get_pins {u_ui_ctrl/u_key_bank/u_db*/pressed_s*/Q}] -to [get_pins {u_param_panel/p25_fn_btn_r1_*_s*/D}]


set_false_path -from [get_pins {u_ui_ctrl/page_r_*_s*/Q}] -to [get_pins {u_param_panel/ui_page_r1_*_s*/D}]
set_false_path -from [get_pins {u_ui_ctrl/page_r_*_s*/Q}] -to [get_pins {u_param_panel/ui_page_r1_*_s*/D}]
set_false_path -from [get_pins {u_ui_ctrl/page_r_*_s*/Q}] -to [get_pins {u_param_panel/ui_page_r1_*_s*/D}]
set_false_path -from [get_pins {u_ui_ctrl/page_r_*_s*/Q}] -to [get_pins {u_param_panel/ui_page_r1_*_s*/D}]
set_false_path -from [get_pins {u_ui_ctrl/ui_layer_r_s*/Q}] -to [get_pins {u_param_panel/p25_ui_layer_r1_s*/D}]
set_false_path -from [get_pins {u_ui_ctrl/ui_mode_r_s*/Q}]

set_false_path -to [get_pins {focus_ff1_*_s*/D}]

set_false_path -from [get_pins {page_sel_r2*_s*/Q}]
set_false_path -from [get_pins {seq_trk_r2*_s*/Q}]
set_false_path -from [get_pins {seq_step_r2*_s*/Q}]
set_false_path -from [get_pins {umode_r2*_s*/Q}]
set_false_path -from [get_pins {u_score_link/cmd_total_steps_*_s*/Q}]
set_false_path -from [get_pins {u_score_link/cmd_step_ms_*_s*/Q}]
set_false_path -from [get_pins {u_score_link/obs_status_*_s*/Q}]
set_false_path -from [get_pins {u_score_link/last_seq_*_s*/Q}]
set_false_path -from [get_pins {u_score_link/cur_total_*_s*/Q}]
set_false_path -from [get_pins {u_score_play/accomp_*_s*/Q}]
set_false_path -from [get_pins {u_score_play/cur_step_*_s*/Q}]
set_false_path -from [get_pins {u_score_play/ms_cnt_*_s*/Q}]
set_false_path -from [get_pins {u_score_link/obs_cmd_*_s*/Q}]
set_false_path -from [get_pins {u_score_play/playing_s*/Q}]
set_false_path -from [get_pins {u_score_link/cmd_mode_*_s*/Q}]
set_false_path -from [get_pins {u_ui_ctrl/u_enc0/sw_press_pulse_s*/Q}]
set_false_path -from [get_pins {u_ui_ctrl/u_enc0/sw_long_pulse_s*/Q}]
set_false_path -from [get_pins {u_ui_ctrl/seq_step_r_*_s*/Q}]
set_false_path -from [get_pins {u_ui_ctrl/seq_trk_r_*_s*/Q}]
set_false_path -from [get_pins {u_ui_ctrl/page_sel_r_s*/Q}]
set_false_path -from [get_pins {u_sq_mute_cdc/tgl_s1*/Q}]
set_false_path -from [get_pins {u_sq_mode_cdc/tgl_s1*/Q}]
set_false_path -from [get_pins {u_sq_trup_cdc/tgl_s1*/Q}]
set_false_path -from [get_pins {u_sq_trdn_cdc/tgl_s1*/Q}]
set_false_path -from [get_pins {u_sq_clr_cdc/tgl_s1*/Q}]

set_false_path -from [get_pins {u_seq_dump_cdc/req_tgl*/Q}]
set_false_path -from [get_pins {u_seq_dump_cdc/ack_tgl*/Q}]
set_false_path -from [get_pins {u_seq_dump_cdc/pay_r*/Q}]
set_false_path -from [get_pins {u_sq_dump_cdc/tgl*/Q}]
set_false_path -from [get_pins {u_sq_dump_sys_cdc/tgl*/Q}]

set_false_path -from [get_pins {u_btn_cdc_vel/tgl*/Q}]

set_false_path -from [get_pins {glide_en_mclk*_s*/Q}] -to [get_pins {u_param_panel/p25_gld_r1_s*/D}]
set_false_path -from [get_pins {vel_en_mclk*_s*/Q}]   -to [get_pins {u_param_panel/p25_vel_r1_s*/D}]

set_false_path -to [get_pins {u_patch_wr_cdc/tgl_sync_*/D}]
set_false_path -to [get_pins {u_patch_wr_cdc/dst_*/D}]
set_false_path -to [get_pins {pvb_m*_s*/D}]

set_false_path -from [get_pins {u_vel_cdc/tgl*/Q}]
set_false_path -from [get_pins {u_vel_cdc/pay_r*/Q}]
