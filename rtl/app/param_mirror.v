// param_mirror

`timescale 1ns/1ps

module param_mirror #(
    parameter integer REBUILD_DLY = 256,

    parameter integer TGL_DLY = 8
)(
    input  wire               mclk,
    input  wire               mrst_n,

    input  wire               reg_we,
    input  wire [7:0]         reg_addr,
    input  wire [7:0]         reg_wdata,
    input  wire               test_mode,

    input  wire [4:0]         cur_patch,
    input  wire               gate,
    input  wire               cfg_ok,
    input  wire [3:0]         led_stat,

    input  wire [4:0]         cur_key,
    input  wire               cur_key_on,

    input  wire               pix_clk,
    input  wire               prst_n,

    output reg  [2:0]         p_algo,
    output reg  [2:0]         p_fb,
    output reg  [9:0]         p_fnum,
    output reg  [2:0]         p_block,
    output reg  [15:0]        p_mult,
    output reg  [23:0]        p_tl,
    output reg  [15:0]        p_ar,
    output reg  [15:0]        p_dr,
    output reg  [15:0]        p_sl,
    output reg  [15:0]        p_rr,
    output reg  [11:0]        p_wf,
    output reg  [4:0]         p_patch,
    output reg                p_gate,
    output reg                p_cfg_ok,
    output reg  [3:0]         p_led,

    output reg                p_fx_en,
    output reg  [2:0]         p_fx_room,
    output reg  [3:0]         p_fx_damp,
    output reg  [2:0]         p_fx_wet,
    output reg                p_fx_spread,
    output reg  [3:0]         p_fx_width,
    output reg  [7:0]         p_fx_predelay,
    output reg  [7:0]         p_vib_depth,
    output reg  [7:0]         p_vol,
    output reg  [3:0]         p_vel_level,

    output reg  [4:0]         p_cur_key,
    output reg                p_key_on
);

`include "param_fields.vh"

    reg [9:0]  sh_fnum;
    reg [2:0]  sh_block;
    reg [2:0]  sh_fb;
    reg [2:0]  sh_algo;
    reg [15:0] sh_mult;
    reg [23:0] sh_tl;
    reg [15:0] sh_ar;
    reg [15:0] sh_dr;
    reg [15:0] sh_sl;
    reg [15:0] sh_rr;
    reg [11:0] sh_wf;

    reg        sh_fx_en;
    reg [2:0]  sh_fx_room;
    reg [3:0]  sh_fx_damp;
    reg [2:0]  sh_fx_wet;
    reg        sh_fx_spread;
    reg [3:0]  sh_fx_width;
    reg [7:0]  sh_fx_predelay;
    reg [7:0]  sh_vib_depth;
    reg [7:0]  sh_vol;
    reg [3:0]  sh_vel_level;

    wire [1:0] slot = reg_addr[1:0];

    reg [15:0] settle_cnt;

    always @(posedge mclk or negedge mrst_n) begin
        if (!mrst_n) begin
            sh_fnum  <= 10'd0;
            sh_block <= 3'd0;
            sh_fb    <= 3'd0;
            sh_algo  <= 3'd0;
            sh_mult  <= 16'd0;
            sh_tl    <= 24'd0;
            sh_ar    <= 16'd0;
            sh_dr    <= 16'd0;
            sh_sl    <= 16'd0;
            sh_rr    <= 16'd0;
            sh_wf    <= 12'd0;
            sh_fx_en       <= 1'b1;
            sh_fx_room     <= 3'd3;
            sh_fx_damp     <= 4'd8;
            sh_fx_wet      <= 3'd2;
            sh_fx_spread   <= 1'b1;
            sh_fx_width    <= 4'd13;
            sh_fx_predelay <= 8'd0;
            sh_vib_depth   <= 8'd0;
            sh_vol         <= 8'd255;
            sh_vel_level   <= 4'd15;
        end
        else if (reg_we && !test_mode) begin
            case (reg_addr)
                8'h20, 8'h21, 8'h22, 8'h23:
                    sh_mult[{slot, 2'b00} +: 4] <= reg_wdata[PF_MULT_LSB +: PF_MULT_WID];

                8'h40, 8'h41, 8'h42, 8'h43:
                    sh_tl[slot*6 +: 6] <= reg_wdata[PF_TL_LSB +: PF_TL_WID];

                8'h60, 8'h61, 8'h62, 8'h63: begin
                    sh_ar[{slot, 2'b00} +: 4] <= reg_wdata[PF_AR_LSB +: PF_AR_WID];
                    sh_dr[{slot, 2'b00} +: 4] <= reg_wdata[PF_DR_LSB +: PF_DR_WID];
                end

                8'h80, 8'h81, 8'h82, 8'h83: begin
                    sh_sl[{slot, 2'b00} +: 4] <= (reg_wdata[7:4] == 4'hf)
                                                 ? 4'hf : reg_wdata[PF_SL_LSB +: PF_SL_WID];
                    sh_rr[{slot, 2'b00} +: 4] <= reg_wdata[PF_RR_LSB +: PF_RR_WID];
                end

                8'hE0, 8'hE1, 8'hE2, 8'hE3:
                    sh_wf[slot*3 +: 3] <= reg_wdata[PF_WF_LSB +: PF_WF_WID];

                8'hA0: sh_fnum[7:0] <= reg_wdata;

                8'hB0: begin
                    sh_fnum[9:8] <= reg_wdata[1:0];
                    sh_block     <= reg_wdata[4:2];
                end

                8'hC0: begin
                    sh_fb   <= reg_wdata[PF_FB_LSB +: PF_FB_WID];
                    sh_algo <= reg_wdata[PF_ALGO_LSB +: PF_ALGO_WID];
                end

                8'hF0: begin
                    sh_fx_en   <= reg_wdata[PF_EN_LSB +: PF_EN_WID];
                    sh_fx_room <= reg_wdata[PF_ROOM_LSB +: PF_ROOM_WID];
                    sh_fx_damp <= reg_wdata[PF_DAMP_LSB +: PF_DAMP_WID];
                end

                8'hF1: begin
                    sh_fx_wet    <= reg_wdata[PF_WET_LSB +: PF_WET_WID];
                    sh_fx_spread <= reg_wdata[PF_SPREAD_LSB +: PF_SPREAD_WID];
                    sh_fx_width  <= reg_wdata[PF_WIDTH_LSB +: PF_WIDTH_WID];
                end

                8'hF2: sh_fx_predelay <= reg_wdata;

                8'hF3: sh_vib_depth <= reg_wdata;

                8'hF4: sh_vol <= reg_wdata;

                8'hF6: sh_vel_level <= reg_wdata[3:0];

                default: ;
            endcase
        end
    end

    always @(posedge mclk or negedge mrst_n) begin
        if (!mrst_n) p_vel_level <= 4'd15;
        else        p_vel_level <= sh_vel_level;
    end

    reg        tgl;
    reg        tgl_pend;
    reg [15:0] hold_cnt;

    wire write_seen = reg_we;
    wire settle_done = (settle_cnt == REBUILD_DLY[15:0]);

    always @(posedge mclk or negedge mrst_n) begin
        if (!mrst_n) begin
            settle_cnt <= 16'd0;
            hold_cnt   <= 16'd0;
            tgl        <= 1'b0;
            tgl_pend   <= 1'b0;
        end
        else begin
            if (write_seen) begin
                settle_cnt <= 16'd1;
                hold_cnt   <= 16'd0;
                tgl_pend   <= 1'b1;
            end
            else begin
                if (!settle_done)
                    settle_cnt <= settle_cnt + 16'd1;
                else begin
                    settle_cnt <= settle_cnt;
                    if (hold_cnt != TGL_DLY[15:0]) begin
                        hold_cnt <= hold_cnt + 16'd1;
                    end
                end
            end

            if (!write_seen && settle_done && (hold_cnt == TGL_DLY[15:0]) && tgl_pend) begin
                tgl      <= ~tgl;
                tgl_pend <= 1'b0;
            end
        end
    end

    reg [1:0] tgl_sync;
    reg       tgl_sync_d;

    always @(posedge pix_clk or negedge prst_n) begin
        if (!prst_n) begin
            tgl_sync   <= 2'b00;
            tgl_sync_d <= 1'b0;
        end
        else begin
            tgl_sync   <= {tgl_sync[0], tgl};
            tgl_sync_d <= tgl_sync[1];
        end
    end

    wire ev_load = tgl_sync[1] ^ tgl_sync_d;

    always @(posedge pix_clk or negedge prst_n) begin
        if (!prst_n) begin
            p_fnum   <= 10'd0;
            p_block  <= 3'd0;
            p_fb     <= 3'd0;
            p_algo   <= 3'd0;
            p_mult   <= 16'd0;
            p_tl     <= 24'd0;
            p_ar     <= 16'd0;
            p_dr     <= 16'd0;
            p_sl     <= 16'd0;
            p_rr     <= 16'd0;
            p_wf     <= 12'd0;
            p_patch  <= 5'd0;
            p_gate   <= 1'b0;
            p_cfg_ok <= 1'b0;
            p_led    <= 4'd0;
            p_fx_en       <= 1'b1;
            p_fx_room     <= 3'd3;
            p_fx_damp     <= 4'd8;
            p_fx_wet      <= 3'd2;
            p_fx_spread   <= 1'b1;
            p_fx_width    <= 4'd13;
            p_fx_predelay <= 8'd0;
            p_vib_depth   <= 8'd0;
            p_vol         <= 8'd255;
        end
        else if (ev_load) begin
            p_fnum   <= sh_fnum;
            p_block  <= sh_block;
            p_fb     <= sh_fb;
            p_algo   <= sh_algo;
            p_mult   <= sh_mult;
            p_tl     <= sh_tl;
            p_ar     <= sh_ar;
            p_dr     <= sh_dr;
            p_sl     <= sh_sl;
            p_rr     <= sh_rr;
            p_wf     <= sh_wf;
            p_patch  <= cur_patch;
            p_gate   <= gate;
            p_cfg_ok <= cfg_ok;
            p_led    <= led_stat;

            p_fx_en       <= sh_fx_en;
            p_fx_room     <= sh_fx_room;
            p_fx_damp     <= sh_fx_damp;
            p_fx_wet      <= sh_fx_wet;
            p_fx_spread   <= sh_fx_spread;
            p_fx_width    <= sh_fx_width;
            p_fx_predelay <= sh_fx_predelay;
            p_vib_depth   <= sh_vib_depth;
            p_vol         <= sh_vol;
        end
    end

    parameter integer KEY_DLY = 4;

    reg [5:0]  key_prev;
    reg [15:0] key_settle;
    reg        key_pend;
    reg        key_tgl;

    wire [5:0] key_now  = {cur_key_on, cur_key};
    wire       key_diff = (key_now != key_prev);

    always @(posedge mclk or negedge mrst_n) begin
        if (!mrst_n) begin
            key_prev   <= 6'h1F;
            key_settle <= 16'd0;
            key_pend   <= 1'b0;
            key_tgl    <= 1'b0;
        end
        else begin
            key_prev <= key_now;
            if (key_diff) begin
                key_settle <= 16'd1;
                key_pend   <= 1'b1;
            end
            else if (key_pend) begin
                if (key_settle == KEY_DLY[15:0]) begin
                    key_tgl  <= ~key_tgl;
                    key_pend <= 1'b0;
                end
                else key_settle <= key_settle + 16'd1;
            end
        end
    end

    reg [1:0] key_tgl_sync;
    reg       key_tgl_sync_d;

    always @(posedge pix_clk or negedge prst_n) begin
        if (!prst_n) begin
            key_tgl_sync   <= 2'b00;
            key_tgl_sync_d <= 1'b0;
            p_cur_key      <= 5'h1F;
            p_key_on       <= 1'b0;
        end
        else begin
            key_tgl_sync   <= {key_tgl_sync[0], key_tgl};
            key_tgl_sync_d <= key_tgl_sync[1];
            if (key_tgl_sync[1] ^ key_tgl_sync_d) begin
                p_cur_key <= cur_key;
                p_key_on  <= cur_key_on;
            end
        end
    end

    wire _unused = &{1'b0, hold_cnt[15], 1'b0};

endmodule
