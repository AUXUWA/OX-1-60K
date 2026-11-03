// score_play

`default_nettype none

module score_play (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_ms,

    input  wire        cmd_head,
    input  wire [15:0] cmd_total_steps,
    input  wire [15:0] cmd_step_ms,
    input  wire        cmd_loop,
    input  wire        cmd_start,
    input  wire        cmd_stop,
    input  wire [1:0]  cmd_mode,
    input  wire        cmd_mode_pulse,
    input  wire        cmd_mode_local,

    output reg  [7:0]  rd_addr,
    input  wire [39:0] rd_data,

    output reg  [24:0] guide_hit,
    output reg  [24:0] guide_hold,
    output reg  [24:0] guide_breath,
    output reg  [24:0] guide_far,
    output reg  [7:0]  ramp_r,
    output reg  [24:0] accomp,
    output reg  [5:0]  vel_cur,
    output reg         playing,
    output wire [7:0]  cur_step_o,
    output wire [1:0]  mode_o,
    output reg         notify_pulse,
    output reg  [7:0]  notify_cmd,
    output reg  [7:0]  notify_status
);

    localparam integer QN = 8;

    reg [15:0] step_ms_r;
    reg [8:0]  total_r;
    reg        loop_r;
    reg [1:0]  mode_r;
    reg [15:0] flash_ms_r;
    reg [15:0] ramp_inc_r;

    reg [8:0]  cur_step;
    reg [15:0] ms_cnt;
    reg [15:0] ramp_frac;
    reg [7:0]  ramp8;

    reg [39:0] win0, win1, win2, win3;
    reg  [5:0] step_vel;
    reg        step_has_note;
    reg        win_valid;
    reg [2:0]  fetch_cnt;
    reg        fetch_busy;
    reg [1:0]  fetch_req;

    reg        q_valid [0:QN-1];
    reg [8:0]  q_expire[0:QN-1];
    reg [24:0] q_bm    [0:QN-1];

    reg  [24:0] hold_bm;
    reg         ins_found;
    reg  [2:0]  ins_idx;

    always @* begin : blk_comb
        integer k;
        hold_bm   = 25'd0;
        ins_found = 1'b0;
        ins_idx   = 3'd0;
        for (k = 0; k < QN; k = k + 1) begin
            if (q_valid[k]) hold_bm = hold_bm | q_bm[k];
            if (!ins_found && !q_valid[k]) begin
                ins_found = 1'b1;
                ins_idx   = k;
            end
        end
    end

    wire [8:0]  rd_next9  = {1'b0, rd_addr} + 9'd1;
    wire        rd_wrap   = (rd_next9 >= total_r);
    wire [7:0]  rd_next   = rd_wrap ? 8'd0 : rd_next9[7:0];

    wire        step_tick = tick_ms && playing && (ms_cnt + 16'd1 >= step_ms_r);
    wire        want_fetch = step_tick || cmd_start;

    wire        mode_on   = (mode_r != 2'd0);
    wire        have_next = loop_r ? 1'b1 : ((cur_step + 9'd1) < total_r);
    wire        have_f2   = loop_r ? 1'b1 : ((cur_step + 9'd2) < total_r);
    wire        have_f3   = loop_r ? 1'b1 : ((cur_step + 9'd3) < total_r);
    wire        hit_on    = playing && mode_on && win_valid && (ms_cnt < flash_ms_r);

    wire [24:0] hit_next    = hit_on ? win0[24:0] : 25'd0;
    wire [24:0] hold_next   = (playing && mode_on) ? hold_bm : 25'd0;
    wire [24:0] breath_next = (playing && mode_on && win_valid && have_next)
                              ? win1[24:0] : 25'd0;
    wire [24:0] far_next    = (playing && mode_on && win_valid)
                              ? ((have_f2 ? win2[24:0] : 25'd0) |
                                 (have_f3 ? win3[24:0] : 25'd0)) : 25'd0;
    wire [7:0]  ramp_next   = (playing && mode_on) ? (8'd24 + {ramp8[7:3], 1'b0})
                                                   : 8'd0;
    wire [24:0] accomp_next = (mode_r == 2'd2) ? hold_bm : 25'd0;
    wire [5:0]  vel_cur_next = (playing && (mode_r == 2'd2) && step_has_note)
                               ? step_vel : 6'd0;

    integer qi;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_ms_r    <= 16'd100;
            total_r      <= 9'd0;
            loop_r       <= 1'b0;
            mode_r       <= 2'd2;
            flash_ms_r   <= 16'd25;
            ramp_inc_r   <= 16'd100;
            cur_step     <= 9'd0;
            ms_cnt       <= 16'd0;
            ramp_frac    <= 16'd0;
            ramp8        <= 8'd0;
            win0         <= 40'd0;
            win1         <= 40'd0;
            win2         <= 40'd0;
            win3         <= 40'd0;
            win_valid    <= 1'b0;
            step_vel     <= 6'd0;
            step_has_note<= 1'b0;
            vel_cur      <= 6'd0;
            fetch_cnt    <= 3'd0;
            fetch_busy   <= 1'b0;
            fetch_req    <= 2'd0;
            rd_addr      <= 8'd0;
            for (qi = 0; qi < QN; qi = qi + 1) begin
                q_valid[qi]  <= 1'b0;
                q_expire[qi] <= 9'd0;
                q_bm[qi]     <= 25'd0;
            end
            guide_hit    <= 25'd0;
            guide_hold   <= 25'd0;
            guide_breath <= 25'd0;
            guide_far    <= 25'd0;
            ramp_r       <= 8'd0;
            accomp       <= 25'd0;
            playing      <= 1'b0;
            notify_pulse <= 1'b0;
            notify_cmd   <= 8'd0;
            notify_status<= 8'd0;
        end
        else begin
            notify_pulse <= 1'b0;

            guide_hit    <= hit_next;
            guide_hold   <= hold_next;
            guide_breath <= breath_next;
            guide_far    <= far_next;
            ramp_r       <= ramp_next;
            accomp       <= accomp_next;
            vel_cur      <= vel_cur_next;

            if (cmd_mode_pulse)
                mode_r <= cmd_mode;
            else if (cmd_mode_local)
                mode_r <= (mode_r == 2'd2) ? 2'd0 : (mode_r + 2'd1);

            if (cmd_head) begin
                playing   <= 1'b0;
                cur_step  <= 9'd0;
                ms_cnt    <= 16'd0;
                ramp8     <= 8'd0;
                ramp_frac <= 16'd0;
                win_valid <= 1'b0;
                for (qi = 0; qi < QN; qi = qi + 1) q_valid[qi] <= 1'b0;
            end

            if (cmd_stop) begin
                playing   <= 1'b0;
                ms_cnt    <= 16'd0;
                win_valid <= 1'b0;
                for (qi = 0; qi < QN; qi = qi + 1) q_valid[qi] <= 1'b0;
            end

            if (cmd_start) begin
                playing    <= 1'b1;
                cur_step   <= 9'd0;
                ms_cnt     <= 16'd0;
                ramp8      <= 8'd0;
                ramp_frac  <= 16'd0;
                win_valid  <= 1'b0;
                fetch_busy <= 1'b0;
                fetch_cnt  <= 3'd0;
            end

            if (cmd_head) begin
                step_ms_r <= cmd_step_ms;
                total_r   <= cmd_total_steps[8:0];
                loop_r    <= cmd_loop;
                if ((cmd_step_ms >> 2) > 16'd60)
                    flash_ms_r <= (cmd_step_ms >> 2) > cmd_step_ms ? cmd_step_ms
                                                                  : (cmd_step_ms >> 2);
                else if (16'd60 > cmd_step_ms)
                    flash_ms_r <= cmd_step_ms;
                else
                    flash_ms_r <= 16'd60;
                ramp_inc_r <= (cmd_step_ms >= 16'd256) ? 16'd256 : cmd_step_ms;
            end

            if (tick_ms && playing) begin
                if (ms_cnt + 16'd1 >= step_ms_r) begin
                    ms_cnt    <= 16'd0;
                    ramp8     <= 8'd0;
                    ramp_frac <= 16'd0;
                    if (cur_step + 9'd1 >= total_r) begin
                        if (loop_r) begin
                            cur_step <= 9'd0;
                            for (qi = 0; qi < QN; qi = qi + 1)
                                if (q_valid[qi] && q_expire[qi] >= total_r)
                                    q_valid[qi] <= 1'b0;
                        end else begin
                            playing   <= 1'b0;
                            win_valid <= 1'b0;
                            for (qi = 0; qi < QN; qi = qi + 1) q_valid[qi] <= 1'b0;
                            notify_pulse  <= 1'b1;
                            notify_cmd    <= 8'h03;
                            notify_status <= 8'h00;
                        end
                    end else begin
                        cur_step <= cur_step + 9'd1;
                        for (qi = 0; qi < QN; qi = qi + 1)
                            if (q_valid[qi] && q_expire[qi] == cur_step + 9'd1)
                                q_valid[qi] <= 1'b0;
                    end
                end else begin
                    ms_cnt    <= ms_cnt + 16'd1;
                    ramp_frac <= ramp_frac + ramp_inc_r;
                    if (ramp_frac + ramp_inc_r >= step_ms_r) begin
                        ramp_frac <= ramp_frac + ramp_inc_r - step_ms_r;
                        ramp8     <= ramp8 + 8'd1;
                    end
                end
            end

            if (fetch_req != 2'd0 && !fetch_busy) begin
                fetch_busy  <= 1'b1;
                fetch_cnt   <= 3'd0;
                rd_addr   <= cur_step[7:0];
            end
            else if (fetch_busy) begin
                case (fetch_cnt)
                    3'd0: begin
                        rd_addr <= rd_next;
                        fetch_cnt <= 3'd1;
                    end
                    3'd1: begin
                        win0      <= rd_data;
                        rd_addr <= rd_next;
                        fetch_cnt <= 3'd2;
                    end
                    3'd2: begin
                        win1      <= rd_data;
                        rd_addr <= rd_next;
                        fetch_cnt <= 3'd3;
                    end
                    3'd3: begin
                        win2      <= rd_data;
                        fetch_cnt <= 3'd4;
                    end
                    default: begin
                        win3       <= rd_data;
                        fetch_busy <= 1'b0;
                        win_valid  <= 1'b1;
                        step_vel      <= win0[37:32];
                        step_has_note <= win0[31] && (win0[24:0] != 25'd0);
                        if (win0[31] && (win0[24:0] != 25'd0)) begin
                            if (ins_found) begin
                                q_valid [ins_idx] <= 1'b1;
                                q_bm    [ins_idx] <= win0[24:0];
                                q_expire[ins_idx] <= cur_step
                                                    + {3'd0, win0[30:25]} + 9'd1;
                            end else begin
                                notify_pulse  <= 1'b1;
                                notify_cmd    <= 8'h02;
                                notify_status <= 8'h06;
                            end
                        end
                    end
                endcase
            end

            if (want_fetch)
                fetch_req <= (fetch_req < 2'd2) ? fetch_req + 2'd1 : fetch_req;
            else if ((fetch_req != 2'd0) && !fetch_busy)
                fetch_req <= fetch_req - 2'd1;
        end
    end

`ifdef SIMULATION
    initial begin
        if (QN != 8)
            $display("*** WARN score_play: hold 队列深度 QN=%0d（协议 v1.1 规定 8）", QN);
    end
`endif

    assign cur_step_o = cur_step[7:0];
    assign mode_o = mode_r;

endmodule

`default_nettype wire
