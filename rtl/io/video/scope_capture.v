// scope_capture —— 抓取音频 PCM 到环形缓冲，供屏幕画波形 / 李萨如 / 频谱

`timescale 1ns/1ps

module scope_capture #(
    parameter integer        WIN     = 1024,
    parameter integer        DECIM   = 4,
    parameter integer        ADDR_W  = 10,
    parameter signed [15:0]  TRIG_TH = 16'sd64,
    parameter integer        TGL_DLY = 8
)(
    input  wire               mclk,
    input  wire               mrst_n,
    input  wire               sample_tick,
    input  wire signed [15:0] pcm_l,
    input  wire signed [15:0] pcm_r,

    input  wire               pix_clk,
    input  wire               prst_n,
    input  wire               trig_arm,
    input  wire [ADDR_W-1:0]  wav_addr,
    input  wire [ADDR_W-1:0]  lis_addr,
    output reg  signed [15:0] pcm_out,
    output reg  signed [15:0] pcm_out_y,
    output reg  [ADDR_W-1:0]  trig_pos,
    output reg                trig_valid,

    output reg  [ADDR_W:0]    valid_cnt,
    output wire [ADDR_W-1:0]  dbg_wptr
);

    localparam integer WIN_MASK = WIN - 1;

    reg  arm_tgl;
    reg  arm_hold;
    wire arm_pulse = trig_arm && !arm_hold;

    reg [1:0] arm_sync;
    reg       arm_sync_d;

    always @(posedge mclk or negedge mrst_n) begin
        if (!mrst_n) begin
            arm_sync   <= 2'b00;
            arm_sync_d <= 1'b0;
        end
        else begin
            arm_sync   <= {arm_sync[0], arm_tgl};
            arm_sync_d <= arm_sync[1];
        end
    end

    wire ev_arm = arm_sync[1] ^ arm_sync_d;

    reg [7:0]        dec_cnt;
    reg              schmitt;
    reg              armed;
    reg [ADDR_W-1:0] wptr;
    reg [ADDR_W-1:0] trig_pos_a;
    reg [ADDR_W:0]   valid_cnt_a;
    reg [ADDR_W:0]   gray_cnt_a;
    reg              trig_ev_tgl;

    wire [ADDR_W:0] next_cnt = (valid_cnt_a != WIN[ADDR_W:0])
                             ? (valid_cnt_a + {{ADDR_W{1'b0}}, 1'b1})
                             : valid_cnt_a;

    wire signed [16:0] mix17 = {pcm_l[15], pcm_l} + {pcm_r[15], pcm_r};
    wire signed [15:0] pcm   = mix17[16:1];

    reg  we_audio_q;

    always @(posedge mclk or negedge mrst_n) begin
        if (!mrst_n) begin
            dec_cnt    <= 8'd0;
            schmitt    <= 1'b0;
            armed      <= 1'b1;
            wptr       <= {ADDR_W{1'b0}};
            trig_pos_a <= {ADDR_W{1'b0}};
            valid_cnt_a<= {(ADDR_W+1){1'b0}};
            gray_cnt_a <= {(ADDR_W+1){1'b0}};
            we_audio_q <= 1'b0;
        end
        else if (ev_arm) begin
            armed <= 1'b1;
            if (sample_tick) begin
                if (dec_cnt == DECIM[7:0] - 8'd1) dec_cnt <= 8'd0;
                else                              dec_cnt <= dec_cnt + 8'd1;
                we_audio_q <= (dec_cnt == DECIM[7:0] - 8'd1);
                if (dec_cnt == DECIM[7:0] - 8'd1) begin
                    wptr        <= wptr + {{(ADDR_W-1){1'b0}}, 1'b1};
                    valid_cnt_a <= next_cnt;
                    gray_cnt_a  <= next_cnt ^ (next_cnt >> 1);
                end
            end
        end
        else if (sample_tick) begin
            we_audio_q <= (dec_cnt == DECIM[7:0] - 8'd1);
            if (dec_cnt == DECIM[7:0] - 8'd1) dec_cnt <= 8'd0;
            else                              dec_cnt <= dec_cnt + 8'd1;

            if (we_audio_q) begin
                if (pcm >= TRIG_TH)       schmitt <= 1'b1;
                else if (pcm <= -TRIG_TH) schmitt <= 1'b0;

                if (armed && (pcm >= TRIG_TH) && !schmitt) begin
                    trig_pos_a  <= wptr;
                    armed       <= 1'b0;
                    trig_ev_tgl <= ~trig_ev_tgl;
                end

                wptr <= wptr + {{(ADDR_W-1){1'b0}}, 1'b1};

                valid_cnt_a <= next_cnt;

                gray_cnt_a <= next_cnt ^ (next_cnt >> 1);
            end
        end
    end



    assign dbg_wptr = wptr;

    reg signed [15:0] ram [0:WIN-1];

    always @(posedge mclk) begin
        if (we_audio_q) ram[wptr] <= pcm;
    end

    wire signed [15:0] rd_l = ram[wav_addr & WIN_MASK[ADDR_W-1:0]];
    wire signed [15:0] rd_y = ram[lis_addr & WIN_MASK[ADDR_W-1:0]];

    always @(posedge pix_clk or negedge prst_n) begin
        if (!prst_n) begin
            pcm_out   <= 16'sd0;
            pcm_out_y <= 16'sd0;
        end
        else begin
            pcm_out   <= rd_l;
            pcm_out_y <= rd_y;
        end
    end

    reg [ADDR_W-1:0] snap_pos;
    reg [7:0]        tgl_dly;
    reg              tgl_pend;
    reg              evt_tgl;

    always @(posedge mclk or negedge mrst_n) begin
        if (!mrst_n) begin
            snap_pos    <= {ADDR_W{1'b0}};
            tgl_dly     <= 8'd0;
            tgl_pend    <= 1'b0;
            evt_tgl     <= 1'b0;
        end
        else if (trig_pos_a != snap_pos) begin
            snap_pos <= trig_pos_a;
            tgl_dly  <= TGL_DLY[7:0];
            tgl_pend <= 1'b1;
        end
        else if (tgl_pend) begin
            if (tgl_dly != 8'd0) tgl_dly <= tgl_dly - 8'd1;
            else begin
                tgl_pend <= 1'b0;
                evt_tgl  <= ~evt_tgl;
            end
        end
    end

    reg [ADDR_W-1:0] pos_meta, pos_sync;
    reg              tgl_meta, tgl_sync, tgl_sync_d;
    reg              tev_meta, tev_sync, tev_sync_d;

    always @(posedge pix_clk or negedge prst_n) begin
        if (!prst_n) begin
            pos_meta   <= {ADDR_W{1'b0}};
            pos_sync   <= {ADDR_W{1'b0}};
            tgl_meta   <= 1'b0;
            tgl_sync   <= 1'b0;
            tgl_sync_d <= 1'b0;
            tev_meta   <= 1'b0;
            tev_sync   <= 1'b0;
            tev_sync_d <= 1'b0;
            trig_pos   <= {ADDR_W{1'b0}};
            trig_valid <= 1'b0;
            arm_tgl    <= 1'b0;
            arm_hold   <= 1'b0;
        end
        else begin
            pos_meta   <= snap_pos;
            pos_sync   <= pos_meta;
            tgl_meta   <= evt_tgl;
            tgl_sync   <= tgl_meta;
            tgl_sync_d <= tgl_sync;
            tev_meta   <= trig_ev_tgl;
            tev_sync   <= tev_meta;
            tev_sync_d <= tev_sync;
            arm_hold   <= trig_arm;

            if (arm_pulse) begin
                trig_valid <= 1'b0;
                trig_pos   <= {ADDR_W{1'b0}};
                arm_tgl    <= ~arm_tgl;
            end
            else if ((tgl_sync != tgl_sync_d) || (tev_sync != tev_sync_d)) begin
                trig_pos   <= pos_sync;
                trig_valid <= 1'b1;
            end
        end
    end

    reg [ADDR_W:0] gray_meta, gray_sync;
    wire [ADDR_W:0] gray_bin = gray_sync ^ (gray_sync >> 1) ^ (gray_sync >> 2) ^
                               (gray_sync >> 3) ^ (gray_sync >> 4) ^ (gray_sync >> 5) ^
                               (gray_sync >> 6) ^ (gray_sync >> 7) ^ (gray_sync >> 8) ^
                               (gray_sync >> 9) ^ (gray_sync >> 10);

    always @(posedge pix_clk or negedge prst_n) begin
        if (!prst_n) begin
            gray_meta <= {(ADDR_W+1){1'b0}};
            gray_sync <= {(ADDR_W+1){1'b0}};
            valid_cnt <= {(ADDR_W+1){1'b0}};
        end
        else begin
            gray_meta <= gray_cnt_a;
            gray_sync <= gray_meta;
            valid_cnt <= gray_bin;
        end
    end

endmodule
