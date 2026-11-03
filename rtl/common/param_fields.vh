// 引擎「音色 / 算子参数寄存器」的字段描述表（include 用）

localparam [1:0] PF_MODE_STEP1 = 2'd0;
localparam [1:0] PF_MODE_FLIP  = 2'd1;
localparam [1:0] PF_MODE_STEP4 = 2'd2;
localparam [1:0] PF_MODE_NONE  = 2'd3;

localparam [7:0] PF_MULT_BASE = 8'h20;
localparam [7:0] PF_TL_BASE   = 8'h40;
localparam [7:0] PF_AD_BASE   = 8'h60;
localparam [7:0] PF_SR_BASE   = 8'h80;
localparam [7:0] PF_WF_BASE   = 8'hE0;
localparam [7:0] PF_ALGO_BASE = 8'hC0;
localparam [7:0] PF_FX0_BASE  = 8'hF0;
localparam [7:0] PF_FX1_BASE  = 8'hF1;
localparam [7:0] PF_FX2_BASE  = 8'hF2;
localparam [7:0] PF_FX3_BASE  = 8'hF3;


localparam [3:0] PF_MULT_LSB = 4'd0;
localparam [3:0] PF_MULT_WID = 4'd4;
localparam [7:0] PF_MULT_MAX = 8'd15;
localparam [1:0] PF_MULT_MODE = PF_MODE_STEP1;
localparam [3:0] PF_TREM_LSB = 4'd7;  localparam [3:0] PF_TREM_WID = 4'd1;
localparam [3:0] PF_VIBB_LSB = 4'd6;  localparam [3:0] PF_VIBB_WID = 4'd1;
localparam [3:0] PF_EGT_LSB  = 4'd5;  localparam [3:0] PF_EGT_WID  = 4'd1;
localparam [3:0] PF_KSR_LSB  = 4'd4;  localparam [3:0] PF_KSR_WID  = 4'd1;

localparam [3:0] PF_TL_LSB = 4'd0;
localparam [3:0] PF_TL_WID = 4'd6;
localparam [7:0] PF_TL_MAX = 8'd63;
localparam [1:0] PF_TL_MODE = PF_MODE_STEP1;
localparam [3:0] PF_KSL_LSB = 4'd6;  localparam [3:0] PF_KSL_WID = 4'd2;

localparam [3:0] PF_AR_LSB = 4'd4;
localparam [3:0] PF_AR_WID = 4'd4;
localparam [7:0] PF_AR_MAX = 8'd15;
localparam [1:0] PF_AR_MODE = PF_MODE_STEP1;
localparam [3:0] PF_DR_LSB = 4'd0;
localparam [3:0] PF_DR_WID = 4'd4;
localparam [7:0] PF_DR_MAX = 8'd15;
localparam [1:0] PF_DR_MODE = PF_MODE_STEP1;

localparam [3:0] PF_SL_LSB = 4'd4;
localparam [3:0] PF_SL_WID = 4'd4;
localparam [7:0] PF_SL_MAX = 8'd15;
localparam [1:0] PF_SL_MODE = PF_MODE_STEP1;
localparam [3:0] PF_RR_LSB = 4'd0;
localparam [3:0] PF_RR_WID = 4'd4;
localparam [7:0] PF_RR_MAX = 8'd15;
localparam [1:0] PF_RR_MODE = PF_MODE_STEP1;

localparam [3:0] PF_WF_LSB = 4'd0;
localparam [3:0] PF_WF_WID = 4'd3;
localparam [7:0] PF_WF_MAX = 8'd7;
localparam [1:0] PF_WF_MODE = PF_MODE_STEP1;
localparam [3:0] PF_RS_LSB = 4'd3;  localparam [3:0] PF_RS_WID = 4'd3;

localparam [3:0] PF_ALGO_LSB = 4'd0;
localparam [3:0] PF_ALGO_WID = 4'd3;
localparam [7:0] PF_ALGO_MAX = 8'd7;
localparam [1:0] PF_ALGO_MODE = PF_MODE_STEP1;
localparam [3:0] PF_FB_LSB = 4'd4;
localparam [3:0] PF_FB_WID = 4'd3;
localparam [7:0] PF_FB_MAX = 8'd7;
localparam [1:0] PF_FB_MODE = PF_MODE_STEP1;

localparam [3:0] PF_EN_LSB = 4'd0;
localparam [3:0] PF_EN_WID = 4'd1;
localparam [7:0] PF_EN_MAX = 8'd1;
localparam [1:0] PF_EN_MODE = PF_MODE_FLIP;
localparam [3:0] PF_ROOM_LSB = 4'd1;
localparam [3:0] PF_ROOM_WID = 4'd3;
localparam [7:0] PF_ROOM_MAX = 8'd7;
localparam [1:0] PF_ROOM_MODE = PF_MODE_STEP1;
localparam [3:0] PF_DAMP_LSB = 4'd4;
localparam [3:0] PF_DAMP_WID = 4'd4;
localparam [7:0] PF_DAMP_MAX = 8'd15;
localparam [1:0] PF_DAMP_MODE = PF_MODE_STEP1;

localparam [3:0] PF_WET_LSB = 4'd0;
localparam [3:0] PF_WET_WID = 4'd3;
localparam [7:0] PF_WET_MAX = 8'd7;
localparam [1:0] PF_WET_MODE = PF_MODE_STEP1;
localparam [3:0] PF_SPREAD_LSB = 4'd3;
localparam [3:0] PF_SPREAD_WID = 4'd1;
localparam [7:0] PF_SPREAD_MAX = 8'd1;
localparam [1:0] PF_SPREAD_MODE = PF_MODE_FLIP;
localparam [3:0] PF_WIDTH_LSB = 4'd4;
localparam [3:0] PF_WIDTH_WID = 4'd4;
localparam [7:0] PF_WIDTH_MAX = 8'd15;
localparam [1:0] PF_WIDTH_MODE = PF_MODE_NONE;

localparam [3:0] PF_PREDELAY_LSB = 4'd0;
localparam [3:0] PF_PREDELAY_WID = 4'd8;
localparam [7:0] PF_PREDELAY_MAX = 8'd255;
localparam [1:0] PF_PREDELAY_MODE = PF_MODE_STEP4;

localparam [3:0] PF_VIBDEPTH_LSB = 4'd0;
localparam [3:0] PF_VIBDEPTH_WID = 4'd8;
localparam [3:0] PF_VIBDEPTH_EDIT_WID = 4'd4;
localparam [7:0] PF_VIBDEPTH_MAX = 8'd8;
localparam [1:0] PF_VIBDEPTH_MODE = PF_MODE_STEP1;

localparam [7:0] PF_FX0_RESET = 8'h87;
localparam [7:0] PF_FX1_RESET = 8'hDA;
localparam [7:0] PF_FX2_RESET = 8'h00;
localparam [7:0] PF_FX3_RESET = 8'h01;
