// score_link

`default_nettype none

module score_link #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 115200
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rx_valid,
    input  wire [7:0]  rx_data,
    output reg         tx_start,
    output reg  [7:0]  tx_data,
    input  wire        tx_busy,
    output reg         wr_en,
    output reg  [7:0]  wr_addr,
    output reg  [39:0] wr_data,
    output reg         clear_pulse,
    input  wire        clear_done,
    output reg         cmd_head,
    output reg  [15:0] cmd_total_steps,
    output reg  [15:0] cmd_step_ms,
    output reg         cmd_loop,
    output reg         cmd_start,
    output reg         cmd_stop,
    output reg  [1:0]  cmd_mode,
    output reg         cmd_mode_pulse,
    input  wire        notify_pulse,
    input  wire [7:0]  notify_cmd,
    input  wire [7:0]  notify_status,
    input  wire        st_playing,
    input  wire        st_seq_play,
    input  wire [1:0]  st_mode,
    input  wire        st_loop,
    input  wire [8:0]  st_total,
    input  wire [8:0]  st_cur,
    input  wire        st_step_tick,
    input  wire        st_hold_ovf,
    output reg         seqd_req,
    output reg         seqd_rdy,
    input  wire        seqd_valid,
    input  wire [4:0]  seqd_step,
    input  wire [7:0]  seqd_d0,
    input  wire [7:0]  seqd_d1,
    input  wire [7:0]  seqd_d2,
    input  wire [7:0]  seqd_d3,
    input  wire        seqd_local,
    output reg         pt_wr,
    output reg         pt_wr_kind,
    output reg  [3:0]  pt_wr_slot,
    output reg  [4:0]  pt_wr_idx,
    output reg  [15:0] pt_wr_word,
    output reg  [4:0]  pt_sel,
    output reg         pt_sel_upd,
    input  wire [15:0] pt_valid_bits,

    output reg  [7:0]  obs_status,
    output reg  [7:0]  obs_seq,
    output reg  [7:0]  obs_cmd
);

    localparam [7:0] SOF      = 8'hA5;
    localparam [7:0] ACK_SOF  = 8'h5A;
    localparam [7:0] MAX_PAY  = 8'd24;

    localparam integer BIT_CYC    = (CLK_HZ / BAUD) > 0 ? (CLK_HZ / BAUD) : 1;
    localparam integer BYTE_CYC   = BIT_CYC * 10;
    localparam integer TIMEOUT_CYC = BYTE_CYC * 5;

    localparam [7:0] CMD_HEAD  = 8'h01;
    localparam [7:0] CMD_DATA  = 8'h02;
    localparam [7:0] CMD_START = 8'h03;
    localparam [7:0] CMD_STOP  = 8'h04;
    localparam [7:0] CMD_MODE  = 8'h05;
    localparam [7:0] CMD_PING  = 8'h06;
    localparam [7:0] CMD_CLEAR = 8'h07;
    localparam [7:0] CMD_STQ   = 8'h08;
    localparam [7:0] CMD_SEQD  = 8'h09;
    localparam [7:0] CMD_PHEAD = 8'h0A;
    localparam [7:0] CMD_PDATA = 8'h0B;
    localparam [7:0] CMD_PSEL  = 8'h0C;
    localparam [7:0] CMD_ECHO  = 8'h0F;

    localparam [7:0] NT_STAT   = 8'h0A;
    localparam [7:0] NT_STAT2  = 8'h0B;
    localparam [7:0] NT_SEQD   = 8'h0C;

    localparam [7:0] ST_OK       = 8'h00;
    localparam [7:0] ST_CHECK    = 8'h01;
    localparam [7:0] ST_HEADBAD  = 8'h02;
    localparam [7:0] ST_TOOBIG   = 8'h03;
    localparam [7:0] ST_STEPBAD  = 8'h04;
    localparam [7:0] ST_UNKCMD   = 8'h05;
    localparam [7:0] ST_OVERFLOW = 8'h06;
    localparam [7:0] ST_FORMAT   = 8'h08;
    localparam [7:0] ST_PATCH_CNT = 8'h09;
    localparam [7:0] ST_PATCH_SEQ = 8'h0A;
    localparam [7:0] ST_PATCH_VAL = 8'h0B;

    function [7:0] crc8_nib;
        input [7:0] c_in;
        input [3:0] n_in;
        reg [7:0] t;
        begin
            t = {c_in[3:0], 4'h0};
            case (c_in[7:4] ^ n_in)
                4'h0: t = t ^ 8'h00;
                4'h1: t = t ^ 8'h07;
                4'h2: t = t ^ 8'h0E;
                4'h3: t = t ^ 8'h09;
                4'h4: t = t ^ 8'h1C;
                4'h5: t = t ^ 8'h1B;
                4'h6: t = t ^ 8'h12;
                4'h7: t = t ^ 8'h15;
                4'h8: t = t ^ 8'h38;
                4'h9: t = t ^ 8'h3F;
                4'hA: t = t ^ 8'h36;
                4'hB: t = t ^ 8'h31;
                4'hC: t = t ^ 8'h24;
                4'hD: t = t ^ 8'h23;
                4'hE: t = t ^ 8'h2A;
                4'hF: t = t ^ 8'h2D;
                default: t = t ^ 8'h00;
            endcase
            crc8_nib = t;
        end
    endfunction

    function [7:0] crc8_next;
        input [7:0] crc_in;
        input [7:0] dat_in;
        reg [7:0] c;
        begin
            c = crc8_nib(crc_in, dat_in[7:4]);
            c = crc8_nib(c, dat_in[3:0]);
            crc8_next = c;
        end
    endfunction

    function cmd_known;
        input [7:0] c;
        begin
            case (c)
                8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06,
                8'h07, 8'h08, 8'h09,
                8'h0A, 8'h0B, 8'h0C,
                8'h0F: cmd_known = 1'b1;
                default:                                 cmd_known = 1'b0;
            endcase
        end
    endfunction

    function addr_ok;
        input [7:0] a;
        begin
            case (a)
                8'h01, 8'hA0, 8'hB0, 8'hC0: addr_ok = 1'b1;
                8'h20, 8'h21, 8'h22, 8'h23,
                8'h40, 8'h41, 8'h42, 8'h43,
                8'h60, 8'h61, 8'h62, 8'h63,
                8'h80, 8'h81, 8'h82, 8'h83,
                8'hE0, 8'hE1, 8'hE2, 8'hE3,
                8'hF0, 8'hF1, 8'hF2:         addr_ok = 1'b1;
                default:                     addr_ok = 1'b0;
            endcase
        end
    endfunction

    localparam [2:0] S_HUNT = 3'd0, S_CMD = 3'd1, S_LEN = 3'd2,
                     S_PAY  = 3'd3, S_SEQ = 3'd4, S_CHK = 3'd5;

    reg [2:0]  rx_state;
    reg [7:0]  cmd_r;
    reg [7:0]  len_r;
    reg [7:0]  seq_r;
    reg [7:0]  crc_acc;
    reg [5:0]  pay_cnt;
    reg [63:0] pay_sh;

    reg [8:0]  cur_total;

    reg        st_v  [0:3];
    reg [7:0]  st_ad [0:3];
    reg [39:0] st_da [0:3];
    reg [2:0]  st_cnt;
    reg        st_err;
    reg        st_fmt;

    reg [3:0]  ev_size;
    reg [3:0]  ev_cnt;

    reg [15:0] gap_cnt;

    reg [7:0]  last_seq;
    reg        last_seq_v;
    reg [7:0]  last_st;

    reg        wr_busy;
    reg [2:0]  wr_cnt;

    localparam [4:0] T_IDLE = 5'd0,  T_S0 = 5'd1,  T_W0 = 5'd2,  T_S1 = 5'd3,
                     T_W1   = 5'd4,  T_S2 = 5'd5,  T_W2 = 5'd6,  T_S3 = 5'd7,
                     T_W3   = 5'd8,  T_S4 = 5'd9,  T_W4 = 5'd10,
                     T_S5   = 5'd11, T_W5 = 5'd12, T_S6 = 5'd13, T_W6 = 5'd14,
                     T_S7   = 5'd15, T_W7 = 5'd16, T_S8 = 5'd17, T_W8 = 5'd18;
    reg [4:0]  tx_state;
    reg [7:0]  tx_b1, tx_b2, tx_b3, tx_b4;

    localparam QDEPTH = 4;
    reg [39:0] q_mem [0:QDEPTH-1];
    reg [2:0]  q_cnt;
    reg [39:0] q_mem_n [0:QDEPTH-1];
    reg [2:0]  q_cnt_n;

    reg        ack_push;
    reg [39:0] ack_push_d;
    reg        ack_push_prio;

    reg        head_pend;
    reg [39:0] head_pend_d;

    reg        st_play_d;
    reg        hold_ovf_r;
    reg        seqd_busy;
    reg        seqd_pend;
    reg [7:0]  seqd_idx_r;
    reg [7:0]  seqd_p0, seqd_p1, seqd_p2, seqd_p3;
    reg [5:0]  seqd_cnt;
    reg        tx_9b;
    reg        seqd_pend_ack;
    reg        cmd_stop_seen;
    wire [7:0] st_stat_byte  = {st_playing, st_seq_play, st_mode, st_loop, 3'b000};
    wire [7:0] st_stat2_byte = {st_playing, hold_ovf_r, st_cur[5:0]};

    reg        enq_stat;
    reg [39:0] enq_stat_d;
    wire       enq_ack  = ack_push || (head_pend && clear_done);
    wire       enq_ntf  = notify_pulse && !enq_ack;
    wire       enq_stat_now = enq_stat && !enq_ack && !enq_ntf;
    wire       enq_any  = enq_ack || enq_ntf || enq_stat_now;
    reg [39:0] enq_d;
    reg        enq_prio;

    always @* begin : blk_enq
        if (enq_ack) begin
            if (ack_push)
                enq_d = ack_push_d;
            else
                enq_d = head_pend_d;
            enq_prio = 1'b1;
        end
        else if (enq_ntf) begin
            enq_d = {ACK_SOF, 8'hFF, notify_cmd, notify_status,
                     ack_crc(notify_cmd, notify_status)};
            enq_prio = 1'b0;
        end
        else begin
            enq_d = enq_stat_d;
            enq_prio = 1'b0;
        end
    end

    wire stat_lose = enq_stat && !enq_stat_now;

    wire       deq_cond = (tx_state == T_IDLE) && (q_cnt != 3'd0);

    integer qi;
    always @* begin : blk_ackq
        q_cnt_n = q_cnt;
        for (qi = 0; qi < QDEPTH; qi = qi + 1) q_mem_n[qi] = q_mem[qi];
        if (deq_cond) begin
            for (qi = 0; qi < QDEPTH-1; qi = qi + 1) q_mem_n[qi] = q_mem[qi+1];
            q_mem_n[QDEPTH-1] = 40'd0;
            q_cnt_n = q_cnt - 3'd1;
        end
        if (enq_any) begin
            if (q_cnt_n < QDEPTH[2:0]) begin
                q_mem_n[q_cnt_n[1:0]] = enq_d;
                q_cnt_n = q_cnt_n + 3'd1;
            end
            else if (!enq_prio) begin
            end
            else begin
                if (q_mem_n[0][31:24] == 8'hFF) begin
                    for (qi = 0; qi < QDEPTH-1; qi = qi + 1) q_mem_n[qi] = q_mem_n[qi+1];
                    q_mem_n[QDEPTH-1] = enq_d;
                end
            end
        end
    end

    wire [15:0] h_total  = {pay_sh[15:8], pay_sh[7:0]};
    wire [15:0] h_stepms = {pay_sh[31:24], pay_sh[23:16]};
    wire [7:0]  h_loop   = pay_sh[39:32];
    wire        h_len_ok = (len_r == 8'd8);

    wire [63:0] pay_sh_next = {rx_data, pay_sh[63:8]};
    wire [7:0]  ev_rem    = len_r[7:0] - {2'b00, pay_cnt[5:0]};
    wire        ev_rem7   = (ev_rem == 8'd7) || (ev_rem == 8'd14) || (ev_rem == 8'd21);
    wire [3:0]  ev_size_c = (ev_cnt == 4'd0)
                          ? (ev_rem7 ? 4'd7 : 4'd6)
                          : ev_size;
    wire [15:0] ev_step  = (ev_size_c == 4'd7)
                         ? {pay_sh_next[23:16], pay_sh_next[15:8]}
                         : {pay_sh_next[31:24], pay_sh_next[23:16]};
    wire [7:0]  ev_flag  = (ev_size_c == 4'd7) ? pay_sh_next[31:24]
                                                : pay_sh_next[39:32];
    wire [24:0] ev_bm    = (ev_size_c == 4'd7)
                         ? {pay_sh_next[55:48], pay_sh_next[47:40], pay_sh_next[39:32]}
                         : {pay_sh_next[63:56], pay_sh_next[55:48], pay_sh_next[47:40]};
    wire [5:0]  ev_vel   = (ev_size_c == 4'd7) ? pay_sh_next[61:56] : 6'd0;
    wire        ev_valid = ev_flag[7];
    wire [6:0]  ev_dur   = ev_flag[6:0];
    wire [5:0]  ev_durm1 = (ev_dur == 7'd0) ? 6'd0 :
                          (ev_dur >  7'd64) ? 6'd63 : (ev_dur[6:0] - 7'd1);
    wire [39:0] ev_slot  = {2'b00, ev_vel, ev_valid, ev_durm1, ev_bm};
    wire        ev_ok    = (cur_total != 9'd0) && ({7'd0, ev_step} < cur_total);

    function data_len_ok;
        input [7:0] l;
        begin
            case (l)
                8'd6, 8'd7, 8'd12, 8'd13, 8'd14,
                8'd18, 8'd19, 8'd20, 8'd21, 8'd24: data_len_ok = 1'b1;
                default:                             data_len_ok = 1'b0;
            endcase
        end
    endfunction

    wire        is_exec_cmd = (cmd_r == CMD_START) || (cmd_r == CMD_STOP)
                           || (cmd_r == CMD_MODE);
    wire        dup_exec    = last_seq_v && (seq_r == last_seq) && is_exec_cmd;

    wire        is_patch_cmd = (cmd_r == CMD_PHEAD) || (cmd_r == CMD_PDATA)
                            || (cmd_r == CMD_PSEL);
    wire        dup_patch    = last_seq_v && (seq_r == last_seq) && is_patch_cmd;
    reg  [7:0]  pt_last_st;

    function [7:0] ack_crc;
        input [7:0] c;
        input [7:0] t;
        begin
            ack_crc = crc8_next(crc8_next(8'h00, c), t);
        end
    endfunction

    integer i;

    wire [7:0] pt_p0 = pay_sh[55:48];
    wire [7:0] pt_p1 = pay_sh[63:56];
    wire [3:0] pt_slot_local = pt_p0[3:0] - 4'd8;
    wire       pt_hslot_ok   = (pt_p0 >= 8'd8) && (pt_p0 <= 8'd23);
    wire       pt_param_ok   = addr_ok(pt_p0)
                            && !((pt_p0 == 8'hB0) && pt_p1[5]);
    wire       pt_sel_ok     = (pt_p1 > 8'd23) ? 1'b0
                             : (pt_p1[4:0] >= 5'd8)
                               ? pt_valid_bits[pt_p1[3:0] - 4'd8]
                               : 1'b1;

    reg        pt_active;
    reg [5:0]  pt_cnt;
    reg [3:0]  pt_head_slot;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state   <= S_HUNT;
            cmd_r      <= 8'd0;
            len_r      <= 8'd0;
            seq_r      <= 8'd0;
            crc_acc    <= 8'h00;
            pay_cnt    <= 6'd0;
            pay_sh     <= 64'd0;
            cur_total  <= 9'd0;
            st_cnt     <= 3'd0;
            st_err     <= 1'b0;
            st_fmt     <= 1'b0;
            ev_size    <= 4'd6;
            ev_cnt     <= 4'd0;
            gap_cnt    <= 16'd0;
            last_seq   <= 8'd0;
            last_seq_v <= 1'b0;
            last_st    <= 8'h00;
            wr_busy    <= 1'b0;
            wr_cnt     <= 3'd0;
            wr_en      <= 1'b0;
            wr_addr    <= 8'd0;
            wr_data    <= 32'd0;
            clear_pulse<= 1'b0;
            cmd_head   <= 1'b0;
            cmd_total_steps <= 16'd0;
            cmd_step_ms<= 16'd0;
            cmd_loop   <= 1'b0;
            cmd_start  <= 1'b0;
            cmd_stop   <= 1'b0;
            cmd_mode   <= 2'd2;
            cmd_mode_pulse <= 1'b0;
            q_cnt      <= 3'd0;
            for (i = 0; i < QDEPTH; i = i + 1) q_mem[i] <= 40'd0;
            ack_push   <= 1'b0;
            ack_push_d <= 40'd0;
            enq_stat   <= 1'b0;
            enq_stat_d <= 40'd0;
            head_pend  <= 1'b0;
            head_pend_d<= 40'd0;
            st_play_d  <= 1'b0;
            hold_ovf_r <= 1'b0;
            cmd_stop_seen <= 1'b0;
            seqd_req   <= 1'b0;
            seqd_busy  <= 1'b0;
            seqd_pend  <= 1'b0;
            seqd_cnt   <= 6'd0;
            seqd_pend_ack <= 1'b0;
            tx_9b      <= 1'b0;
            tx_state   <= T_IDLE;
            tx_start   <= 1'b0;
            tx_data    <= 8'h00;
            tx_b1      <= 8'h00;
            tx_b2      <= 8'h00;
            tx_b3      <= 8'h00;
            tx_b4      <= 8'h00;
            obs_status <= 8'h00;
            obs_seq    <= 8'h00;
            obs_cmd    <= 8'h00;
            pt_wr       <= 1'b0;
            pt_wr_kind  <= 1'b0;
            pt_wr_slot  <= 4'd0;
            pt_wr_idx   <= 5'd0;
            pt_wr_word  <= 16'd0;
            pt_sel      <= 5'd0;
            pt_sel_upd  <= 1'b0;
            pt_active   <= 1'b0;
            pt_cnt      <= 6'd0;
            pt_head_slot<= 4'd0;
            pt_last_st  <= 8'h00;
            for (i = 0; i < 4; i = i + 1) begin
                st_v[i]  <= 1'b0;
                st_ad[i] <= 8'd0;
                st_da[i] <= 40'd0;
            end
        end
        else begin
            ack_push    <= 1'b0;
            cmd_head    <= 1'b0;
            cmd_start   <= 1'b0;
            cmd_stop    <= 1'b0;
            cmd_mode_pulse <= 1'b0;
            clear_pulse <= 1'b0;
            wr_en       <= 1'b0;
            pt_wr       <= 1'b0;
            pt_sel_upd  <= 1'b0;

            if (rx_valid) gap_cnt <= 16'd0;
            else if (gap_cnt < TIMEOUT_CYC[15:0]) gap_cnt <= gap_cnt + 16'd1;
            if (!rx_valid && (gap_cnt >= TIMEOUT_CYC[15:0]) && (rx_state != S_HUNT))
                rx_state <= S_HUNT;

            q_cnt <= q_cnt_n;
            for (i = 0; i < QDEPTH; i = i + 1) q_mem[i] <= q_mem_n[i];
            enq_stat <= 1'b0;
            if (stat_lose) begin
                enq_stat   <= 1'b1;
                enq_stat_d <= enq_stat_d;
            end
            if (head_pend && clear_done) head_pend <= 1'b0;

            seqd_rdy <= seqd_busy && !seqd_pend
                        && (q_cnt_n < QDEPTH[2:0] - 3'd2);
            if (st_hold_ovf) hold_ovf_r <= 1'b1;
            if (cmd_stop_seen) hold_ovf_r <= 1'b0;
            st_play_d <= st_playing;
            if (st_step_tick && !seqd_busy && !enq_stat) begin
                enq_stat   <= 1'b1;
                enq_stat_d <= {ACK_SOF, 8'hFF, NT_STAT2,
                               st_stat2_byte, ack_crc(NT_STAT2, st_stat2_byte)};
            end

            if (seqd_local && !seqd_busy) begin
                seqd_req      <= 1'b1;
                seqd_busy     <= 1'b1;
                seqd_cnt      <= 6'd0;
                seqd_pend_ack <= 1'b1;
            end
            if (seqd_valid && seqd_busy && !seqd_pend) begin
                seqd_pend  <= 1'b1;
                seqd_idx_r <= {3'd0, seqd_step};
                seqd_p0 <= seqd_d0; seqd_p1 <= seqd_d1;
                seqd_p2 <= seqd_d2; seqd_p3 <= seqd_d3;
            end

            case (tx_state)
                T_IDLE: begin
                    tx_start <= 1'b0;
                    if (seqd_pend_ack) begin
                        tx_data  <= ACK_SOF;
                        tx_b1    <= 8'hFF;
                        tx_b2    <= CMD_SEQD;
                        tx_b3    <= ST_OK;
                        tx_b4    <= ack_crc(CMD_SEQD, ST_OK);
                        tx_start <= 1'b1;
                        tx_9b    <= 1'b0;
                        seqd_pend_ack <= 1'b0;
                        tx_state <= T_S0;
                    end
                    else if (seqd_pend) begin
                        tx_data  <= ACK_SOF;
                        tx_b1    <= 8'hFF;
                        tx_b2    <= NT_SEQD;
                        tx_b3    <= seqd_idx_r;
                        tx_b4    <= ack_crc(NT_SEQD, seqd_idx_r);
                        tx_start <= 1'b1;
                        tx_9b    <= 1'b1;
                        tx_state <= T_S0;
                    end
                    else if (q_cnt != 3'd0) begin
                        tx_b1    <= q_mem[0][31:24];
                        tx_b2    <= q_mem[0][23:16];
                        tx_b3    <= q_mem[0][15:8];
                        tx_b4    <= q_mem[0][7:0];
                        tx_data  <= ACK_SOF;
                        tx_start <= 1'b1;
                        tx_9b    <= 1'b0;
                        tx_state <= T_S0;
                    end
                end
                T_S0: begin tx_start <= 1'b0; if (tx_busy) tx_state <= T_W0; end
                T_W0: begin
                    if (!tx_busy) begin
                        tx_data <= tx_b1; tx_start <= 1'b1; tx_state <= T_S1;
                    end
                end
                T_S1: begin tx_start <= 1'b0; if (tx_busy) tx_state <= T_W1; end
                T_W1: begin
                    if (!tx_busy) begin
                        tx_data <= tx_b2; tx_start <= 1'b1; tx_state <= T_S2;
                    end
                end
                T_S2: begin tx_start <= 1'b0; if (tx_busy) tx_state <= T_W2; end
                T_W2: begin
                    if (!tx_busy) begin
                        tx_data <= tx_b3; tx_start <= 1'b1; tx_state <= T_S3;
                    end
                end
                T_S3: begin tx_start <= 1'b0; if (tx_busy) tx_state <= T_W3; end
                T_W3: begin
                    if (!tx_busy) begin
                        tx_data <= tx_b4; tx_start <= 1'b1; tx_state <= T_S4;
                    end
                end
                T_S4: begin tx_start <= 1'b0; if (tx_busy) tx_state <= T_W4; end
                T_W4: begin
                    if (!tx_busy) begin
                        if (tx_9b) begin
                            tx_data <= seqd_p0; tx_start <= 1'b1; tx_state <= T_S5;
                        end
                        else begin
                            tx_state <= T_IDLE;
                        end
                    end
                end
                T_S5: begin tx_start <= 1'b0; if (tx_busy) tx_state <= T_W5; end
                T_W5: begin
                    if (!tx_busy) begin
                        tx_data <= seqd_p1; tx_start <= 1'b1; tx_state <= T_S6;
                    end
                end
                T_S6: begin tx_start <= 1'b0; if (tx_busy) tx_state <= T_W6; end
                T_W6: begin
                    if (!tx_busy) begin
                        tx_data <= seqd_p2; tx_start <= 1'b1; tx_state <= T_S7;
                    end
                end
                T_S7: begin tx_start <= 1'b0; if (tx_busy) tx_state <= T_W7; end
                T_W7: begin
                    if (!tx_busy) begin
                        tx_data <= seqd_p3; tx_start <= 1'b1; tx_state <= T_S8;
                    end
                end
                T_S8: begin tx_start <= 1'b0; if (tx_busy) tx_state <= T_W8; end
                T_W8: begin
                    if (!tx_busy) begin
                        seqd_pend <= 1'b0;
                        seqd_cnt  <= seqd_cnt + 6'd1;
                        if (seqd_cnt == 6'd31) begin
                            seqd_busy <= 1'b0;
                            seqd_req  <= 1'b0;
                        end
                        tx_state <= T_IDLE;
                    end
                end
                default: tx_state <= T_IDLE;
            endcase

            if (wr_busy) begin
                if (wr_cnt < st_cnt) begin
                    wr_en   <= 1'b1;
                    wr_addr <= st_ad[wr_cnt];
                    wr_data <= st_da[wr_cnt];
                    wr_cnt  <= wr_cnt + 3'd1;
                end
                else begin
                    wr_busy <= 1'b0;
                    ack_push    <= 1'b1;
                    ack_push_d  <= {ACK_SOF, seq_r, cmd_r,
                                    st_err ? ST_STEPBAD : ST_OK,
                                    ack_crc(cmd_r, st_err ? ST_STEPBAD : ST_OK)};
                    obs_status <= st_err ? ST_STEPBAD : ST_OK;
                end
            end

            if (rx_valid && !wr_busy) begin
                case (rx_state)
                    S_HUNT: begin
                        if (rx_data == SOF) rx_state <= S_CMD;
                    end
                    S_CMD: begin
                        if (!cmd_known(rx_data)) begin
                            rx_state   <= S_HUNT;
                            ack_push    <= 1'b1;
                            ack_push_d  <= {ACK_SOF, 8'h00, 8'h00, ST_UNKCMD,
                                            ack_crc(8'h00, ST_UNKCMD)};
                            obs_status <= ST_UNKCMD;
                        end
                        else begin
                            cmd_r    <= rx_data;
                            crc_acc  <= crc8_next(8'h00, rx_data);
                            rx_state <= S_LEN;
                        end
                    end
                    S_LEN: begin
                        if (rx_data > MAX_PAY) begin
                            rx_state   <= S_HUNT;
                            ack_push    <= 1'b1;
                            ack_push_d  <= {ACK_SOF, 8'h00, 8'h00, ST_FORMAT,
                                            ack_crc(8'h00, ST_FORMAT)};
                            obs_status <= ST_FORMAT;
                        end
                        else begin
                            len_r    <= rx_data;
                            crc_acc  <= crc8_next(crc_acc, rx_data);
                            pay_cnt  <= 6'd0;
                            pay_sh   <= 64'd0;
                            st_cnt   <= 3'd0;
                            st_err   <= 1'b0;
                            st_fmt   <= 1'b0;
                            ev_cnt   <= 4'd0;
                            ev_size  <= 4'd6;
                            rx_state <= (rx_data == 8'd0) ? S_SEQ : S_PAY;
                        end
                    end
                    S_PAY: begin
                        pay_sh  <= pay_sh_next;
                        crc_acc <= crc8_next(crc_acc, rx_data);
                        pay_cnt <= pay_cnt + 6'd1;
                        if (cmd_r == CMD_DATA) begin
                            ev_size <= ev_size_c;
                            if ((ev_cnt == 4'd0) && (ev_rem < 8'd6)) st_fmt <= 1'b1;
                            if ((ev_cnt + 4'd1) == ev_size_c) begin
                                if (ev_ok && (st_cnt < 3'd4)) begin
                                    st_v [st_cnt] <= 1'b1;
                                    st_ad[st_cnt] <= ev_step[7:0];
                                    st_da[st_cnt] <= ev_slot;
                                    st_cnt        <= st_cnt + 3'd1;
                                end
                                else begin
                                    st_err <= 1'b1;
                                end
                                ev_cnt <= 4'd0;
                            end
                            else begin
                                ev_cnt <= ev_cnt + 4'd1;
                            end
                        end
                        if ((pay_cnt + 6'd1) == {2'd0, len_r})
                            rx_state <= S_SEQ;
                    end
                    S_SEQ: begin
                        seq_r    <= rx_data;
                        crc_acc  <= crc8_next(crc_acc, rx_data);
                        rx_state <= S_CHK;
                    end
                    S_CHK: begin
                        rx_state <= S_HUNT;
                        if (crc_acc == rx_data) begin
                            obs_status <= ST_OK;
                            obs_seq    <= seq_r;
                            obs_cmd    <= cmd_r;
                            last_seq   <= seq_r;
                            last_seq_v <= 1'b1;
                            case (cmd_r)
                                CMD_HEAD: begin
                                    if (!h_len_ok) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                    end
                                    else if ((h_total < 16'd1) || (h_total > 16'd256)) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_TOOBIG,
                                            ack_crc(cmd_r, ST_TOOBIG)};
                                        obs_status <= ST_TOOBIG;
                                    end
                                    else if ((h_stepms < 16'd10) || (h_stepms > 16'd10000)
                                          || (h_loop > 8'd1)) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_HEADBAD,
                                            ack_crc(cmd_r, ST_HEADBAD)};
                                        obs_status <= ST_HEADBAD;
                                    end
                                    else begin
                                        clear_pulse     <= 1'b1;
                                        cur_total       <= h_total[8:0];
                                        cmd_head        <= 1'b1;
                                        cmd_total_steps <= h_total;
                                        cmd_step_ms     <= h_stepms;
                                        cmd_loop        <= h_loop[0];
                                        head_pend       <= 1'b1;
                                        head_pend_d     <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                    end
                                end
                                CMD_DATA: begin
                                    if (!data_len_ok(len_r) || st_fmt) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                    end
                                    else if (st_cnt == 3'd0 && !st_err) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                    end
                                    else begin
                                        wr_busy <= 1'b1;
                                        wr_cnt  <= 3'd0;
                                    end
                                end
                                CMD_START: begin
                                    if (dup_exec) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, last_st,
                                            ack_crc(cmd_r, last_st)};
                                        obs_status <= last_st;
                                    end
                                    else if (len_r != 8'd0) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                    end
                                    else if (cur_total == 9'd0) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_STEPBAD,
                                            ack_crc(cmd_r, ST_STEPBAD)};
                                        obs_status <= ST_STEPBAD;
                                    end
                                    else begin
                                        cmd_start <= 1'b1;
                                        last_st   <= ST_OK;
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                    end
                                end
                                CMD_STOP: begin
                                    if (len_r != 8'd0) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                    end
                                    else if (dup_exec) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, last_st,
                                            ack_crc(cmd_r, last_st)};
                                        obs_status <= last_st;
                                    end
                                    else begin
                                        cmd_stop <= 1'b1;
                                        cmd_stop_seen <= 1'b1;
                                        last_st   <= ST_OK;
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                    end
                                end
                                CMD_MODE: begin
                                    if (dup_exec) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, last_st,
                                            ack_crc(cmd_r, last_st)};
                                        obs_status <= last_st;
                                    end
                                    else if (len_r != 8'd1) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                    end
                                    else if (pay_sh[63:56] > 8'd2) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_HEADBAD,
                                            ack_crc(cmd_r, ST_HEADBAD)};
                                        obs_status <= ST_HEADBAD;
                                    end
                                    else begin
                                        cmd_mode       <= pay_sh[57:56];
                                        cmd_mode_pulse <= 1'b1;
                                        last_st   <= ST_OK;
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                    end
                                end
                                CMD_PHEAD: begin
                                    if (len_r != 8'd2) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                        pt_last_st <= ST_FORMAT;
                                    end
                                    else if (dup_patch) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, pt_last_st,
                                            ack_crc(cmd_r, pt_last_st)};
                                        obs_status <= pt_last_st;
                                    end
                                    else if (!pt_hslot_ok) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_PATCH_SEQ,
                                            ack_crc(cmd_r, ST_PATCH_SEQ)};
                                        obs_status <= ST_PATCH_SEQ;
                                        pt_last_st <= ST_PATCH_SEQ;
                                    end
                                    else if (pt_p1 != 8'd27) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_PATCH_CNT,
                                            ack_crc(cmd_r, ST_PATCH_CNT)};
                                        obs_status <= ST_PATCH_CNT;
                                        pt_last_st <= ST_PATCH_CNT;
                                    end
                                    else begin
                                        pt_last_st   <= ST_OK;
                                        pt_head_slot <= pt_slot_local;
                                        pt_cnt       <= 6'd0;
                                        pt_active    <= 1'b1;
                                        pt_wr        <= 1'b1;
                                        pt_wr_kind   <= 1'b1;
                                        pt_wr_slot   <= pt_slot_local;
                                        pt_wr_idx    <= 5'd0;
                                        pt_wr_word   <= 16'h0000;
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                        obs_status <= ST_OK;
                                    end
                                end
                                CMD_PDATA: begin
                                    if (len_r != 8'd2) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                        pt_last_st <= ST_FORMAT;
                                    end
                                    else if (dup_patch) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, pt_last_st,
                                            ack_crc(cmd_r, pt_last_st)};
                                        obs_status <= pt_last_st;
                                    end
                                    else if ((!pt_active) || (pt_cnt >= 6'd27)) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_PATCH_SEQ,
                                            ack_crc(cmd_r, ST_PATCH_SEQ)};
                                        obs_status <= ST_PATCH_SEQ;
                                        pt_last_st <= ST_PATCH_SEQ;
                                    end
                                    else if (!pt_param_ok) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_PATCH_VAL,
                                            ack_crc(cmd_r, ST_PATCH_VAL)};
                                        obs_status <= ST_PATCH_VAL;
                                        pt_last_st <= ST_PATCH_VAL;
                                    end
                                    else begin
                                        pt_last_st   <= ST_OK;
                                        pt_wr        <= 1'b1;
                                        pt_wr_kind   <= 1'b0;
                                        pt_wr_slot   <= pt_head_slot;
                                        pt_wr_idx    <= pt_cnt[4:0];
                                        pt_wr_word   <= {pt_p0, pt_p1};
                                        pt_cnt       <= pt_cnt + 6'd1;
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                        obs_status <= ST_OK;
                                    end
                                end
                                CMD_PSEL: begin
                                    if (len_r != 8'd1) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                        pt_last_st <= ST_FORMAT;
                                    end
                                    else if (dup_patch) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, pt_last_st,
                                            ack_crc(cmd_r, pt_last_st)};
                                        obs_status <= pt_last_st;
                                    end
                                    else if (!pt_sel_ok) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_PATCH_SEQ,
                                            ack_crc(cmd_r, ST_PATCH_SEQ)};
                                        obs_status <= ST_PATCH_SEQ;
                                        pt_last_st <= ST_PATCH_SEQ;
                                    end
                                    else begin
                                        pt_last_st <= ST_OK;
                                        pt_sel     <= pt_p1[4:0];
                                        pt_sel_upd <= 1'b1;
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                        obs_status <= ST_OK;
                                    end
                                end
                                CMD_CLEAR: begin
                                    if (len_r != 8'd0) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                    end
                                    else if (dup_exec) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, last_st,
                                            ack_crc(cmd_r, last_st)};
                                        obs_status <= last_st;
                                    end
                                    else begin
                                        clear_pulse <= 1'b1;
                                        last_st   <= ST_OK;
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                    end
                                end
                                CMD_STQ: begin
                                    if (len_r != 8'd0) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                    end
                                    else begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                        if (!enq_stat) begin
                                            enq_stat   <= 1'b1;
                                            enq_stat_d <= {ACK_SOF, 8'hFF, NT_STAT,
                                                st_stat_byte, ack_crc(NT_STAT, st_stat_byte)};
                                        end
                                    end
                                end
                                CMD_SEQD: begin
                                    if (len_r != 8'd0) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                    end
                                    else begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                        seqd_req  <= 1'b1;
                                        seqd_busy <= 1'b1;
                                        seqd_cnt  <= 6'd0;
                                    end
                                end
                                CMD_PING: begin
                                    if (len_r != 8'd0) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                    end
                                    else begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_OK,
                                            ack_crc(cmd_r, ST_OK)};
                                    end
                                end
                                CMD_ECHO: begin
                                    if (len_r != 8'd1) begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_FORMAT,
                                            ack_crc(cmd_r, ST_FORMAT)};
                                        obs_status <= ST_FORMAT;
                                    end
                                    else begin
                                        ack_push   <= 1'b1;
                                        ack_push_d <= {ACK_SOF, seq_r, cmd_r, pay_sh[63:56],
                                            ack_crc(cmd_r, pay_sh[63:56])};
                                        obs_status <= pay_sh[63:56];
                                    end
                                end
                                default: begin
                                    ack_push   <= 1'b1;
                                    ack_push_d <= {ACK_SOF, seq_r, cmd_r, ST_UNKCMD,
                                        ack_crc(cmd_r, ST_UNKCMD)};
                                    obs_status <= ST_UNKCMD;
                                end
                            endcase
                        end
                        else begin
                            rx_state   <= (rx_data == SOF) ? S_CMD : S_HUNT;
                            ack_push    <= 1'b1;
                            ack_push_d  <= {ACK_SOF, seq_r, cmd_r, ST_CHECK,
                                            ack_crc(cmd_r, ST_CHECK)};
                            obs_status <= ST_CHECK;
                        end
                    end
                    default: rx_state <= S_HUNT;
                endcase
            end
        end
    end

`ifdef SIMULATION
    initial begin
        if (MAX_PAY != 8'd24)
            $display("*** WARN score_link: MAX_PAY=%0d（协议 v1.1 规定 24）", MAX_PAY);
        if (TIMEOUT_CYC < (BYTE_CYC * 2))
            $display("*** ERROR score_link: 字节间超时(%0d) < 2 字节(%0d) —— 真机会丢帧",
                     TIMEOUT_CYC, BYTE_CYC * 2);
    end
`endif

endmodule

`default_nettype wire
