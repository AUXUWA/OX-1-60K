// encoder_rotary

`timescale 1ns/1ps

module encoder_rotary #(
    parameter integer CLK_HZ      = 50_000_000,
    parameter integer FILTER_US   = 50,
    parameter integer DEBOUNCE_MS = 10,
    parameter integer LONG_MS     = 600,
    parameter         DIR_FLIP    = 1'b0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire enc_a,
    input  wire enc_b,
    input  wire enc_sw_n,
    output reg  rot_pulse,
    output reg  rot_dir,
    output reg  sw_press_pulse,
    output reg  sw_long_pulse,
    output reg  sw_down
);


    reg [1:0] sync_a, sync_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_a <= 2'b00;
            sync_b <= 2'b00;
        end
        else begin
            sync_a <= {sync_a[0], enc_a};
            sync_b <= {sync_b[0], enc_b};
        end
    end

    wire [1:0] ab_sync = {sync_a[1], sync_b[1]};

    localparam integer DIV_F   = (CLK_HZ / 1000000) * FILTER_US;
    localparam integer FILT_W  = 16;

    reg [1:0]        ab_filt;
    reg [FILT_W-1:0] filt_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ab_filt  <= 2'b00;
            filt_cnt <= {FILT_W{1'b0}};
        end
        else begin
            if (ab_sync == ab_filt) begin
                filt_cnt <= {FILT_W{1'b0}};
            end
            else if (filt_cnt == (DIV_F - 1)) begin
                filt_cnt <= {FILT_W{1'b0}};
                ab_filt  <= ab_sync;
            end
            else begin
                filt_cnt <= filt_cnt + 1'b1;
            end
        end
    end

    function [1:0] quad_delta;
        input [3:0] q;
        begin
            case (q)
                4'b00_01, 4'b01_11, 4'b11_10, 4'b10_00 : quad_delta = 2'd1;
                4'b00_10, 4'b10_11, 4'b11_01, 4'b01_00 : quad_delta = 2'd2;
                default                              : quad_delta = 2'd0;
            endcase
        end
    endfunction

    reg [1:0] ab_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ab_prev <= 2'b00;
        else        ab_prev <= ab_filt;
    end

    wire [1:0] delta = quad_delta({ab_filt, ab_prev});

    localparam [4:0] ACC_BIAS    = 5'd8;
    localparam [4:0] ACC_UP_TRIG = 5'd11;
    localparam [4:0] ACC_DN_TRIG = 5'd5;

    reg [4:0] acc_u;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_u     <= ACC_BIAS;
            rot_pulse <= 1'b0;
            rot_dir   <= 1'b0;
        end
        else begin
            rot_pulse <= 1'b0;

            case (delta)
                2'd1: begin
                    if (acc_u == ACC_UP_TRIG) begin
                        acc_u     <= ACC_BIAS;
                        rot_pulse <= 1'b1;
                        rot_dir   <= ~DIR_FLIP;
                    end
                    else begin
                        acc_u <= acc_u + 1'b1;
                    end
                end
                2'd2: begin
                    if (acc_u == ACC_DN_TRIG) begin
                        acc_u     <= ACC_BIAS;
                        rot_pulse <= 1'b1;
                        rot_dir   <=  DIR_FLIP;
                    end
                    else begin
                        acc_u <= acc_u - 1'b1;
                    end
                end
                default: ;
            endcase
        end
    end

    localparam integer DIV_D = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer CNT_W = 20;
    localparam integer DIV_L = (CLK_HZ / 1000) * LONG_MS;
    localparam integer LC_W  = 26;

    reg [1:0]   sw_sync;
    reg [CNT_W-1:0] d_cnt;
    reg [LC_W-1:0]  l_cnt;
    reg              long_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sw_sync <= 2'b11;
        else        sw_sync <= {sw_sync[0], enc_sw_n};
    end

    wire sw_raw = ~sw_sync[1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_cnt          <= {CNT_W{1'b0}};
            l_cnt          <= {LC_W{1'b0}};
            long_done      <= 1'b0;
            sw_down        <= 1'b0;
            sw_press_pulse <= 1'b0;
            sw_long_pulse  <= 1'b0;
        end
        else begin
            sw_press_pulse <= 1'b0;
            sw_long_pulse  <= 1'b0;

            if (sw_raw == sw_down) begin
                d_cnt <= {CNT_W{1'b0}};
            end
            else if (d_cnt == (DIV_D - 1)) begin
                d_cnt          <= {CNT_W{1'b0}};
                sw_down        <= sw_raw;
                sw_press_pulse <= sw_raw;
            end
            else begin
                d_cnt <= d_cnt + 1'b1;
            end

            if (!sw_down) begin
                l_cnt     <= {LC_W{1'b0}};
                long_done <= 1'b0;
            end
            else if (!long_done) begin
                if (l_cnt == (DIV_L - 1)) begin
                    l_cnt         <= {LC_W{1'b0}};
                    long_done     <= 1'b1;
                    sw_long_pulse <= 1'b1;
                end
                else begin
                    l_cnt <= l_cnt + 1'b1;
                end
            end
        end
    end


endmodule
