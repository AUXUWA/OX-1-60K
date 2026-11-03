// test_tone_src —— ★★ 16 声部测试音源（D 测试模式用）——直接对 16 个声部写

module test_tone_src #(
    parameter integer N_VOICE  = 16,
    parameter integer N_SLOT   = 4,
    parameter integer CLK_HZ   = 12_500_000,
    parameter integer SETTLE_MS = 50,
    parameter integer GAP_CLK  = 80,
    parameter [5:0]   CARRIER_TL = (N_VOICE <= 16) ? 6'd8 : 6'd57,
    localparam integer CNT_W = (N_VOICE <= 16) ? 5 : (N_VOICE <= 32) ? 6
                             : (N_VOICE <= 64) ? 7 : 8
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cfg_ok,
    input  wire        bus_gnt,
    input  wire        enable,

    output reg         reg_we,
    output reg  [7:0]  reg_addr,
    output reg  [7:0]  reg_wdata,

    output wire        busy,
    output wire        load_done,
    output wire [CNT_W-1:0] voice_cnt,
    output wire [12:0] voice_idx,
    output wire [5:0]  band_idx
);

    localparam integer VKEY_W = (N_VOICE <= 16) ? 4 : (N_VOICE <= 32) ? 5
                              : (N_VOICE <= 64) ? 6
                              : (N_VOICE <= 128) ? 7 : 8;
    localparam integer TONE_STEP_W  = (N_VOICE <= 16) ? 2 : 4;
    localparam integer STEP_SH      = (TONE_STEP_W == 2) ? 1 : 2;
    localparam integer TONE_TAB_MAX = (N_VOICE <= 16) ? 16 : 64;
    localparam integer PITCH_N      = 64;
    localparam integer GRP_N        = 64;
    localparam integer N_TONE_I = 24 + TONE_STEP_W * N_VOICE;
    localparam integer SH_TONE  = (N_TONE_I <=  32) ?  5 : (N_TONE_I <=  64) ?  6 :
                                  (N_TONE_I <= 128) ?  7 : (N_TONE_I <= 256) ?  8 :
                                  (N_TONE_I <= 512) ?  9 : (N_TONE_I <= 1024) ? 10 :
                                  (N_TONE_I <= 2048) ? 11 : 12;
    localparam [SH_TONE-1:0] N_TONE = N_TONE_I[SH_TONE-1:0];
    localparam [SH_TONE-1:0] LAST_TONE = N_TONE - 1'b1;
    localparam [SH_TONE-1:0] LAST_VOICE_W = N_VOICE[SH_TONE-1:0] - 1'b1;
    localparam integer KO_STEP = (TONE_STEP_W == 2) ? 1 : 2;
    localparam [SH_TONE-1:0] LAST_KO = (N_VOICE * KO_STEP) - 1;

    localparam [SH_TONE-1:0] SH_MULT  = 0;
    localparam [SH_TONE-1:0] SH_KTL   = 4;
    localparam [SH_TONE-1:0] SH_ADR   = 8;
    localparam [SH_TONE-1:0] SH_SLR   = 12;
    localparam [SH_TONE-1:0] SH_WF    = 16;
    localparam [SH_TONE-1:0] SH_NTS   = 20;
    localparam [SH_TONE-1:0] SH_ALGO  = 21;
    localparam [SH_TONE-1:0] SH_VOICE = 22;
    localparam [SH_TONE-1:0] SH_FX_EN  = SH_VOICE + TONE_STEP_W * N_VOICE;
    localparam [SH_TONE-1:0] SH_FX_WET = SH_FX_EN + 1;

    localparam integer SETTLE_CLK = (CLK_HZ / 1000) * SETTLE_MS;

    localparam [2:0] ST_IDLE   = 3'd0,
                     ST_SETTLE = 3'd1,
                     ST_LOAD   = 3'd2,
                     ST_RUN    = 3'd3,
                     ST_KEYOFF = 3'd4,
                     ST_PGCLR  = 3'd5;

    function [9:0] fnum_of(input [3:0] v);
        begin
            case (v)
                4'd0:  fnum_of = 10'd537;
                4'd1:  fnum_of = 10'd265;
                4'd2:  fnum_of = 10'd99;
                4'd3:  fnum_of = 10'd527;
                4'd4:  fnum_of = 10'd659;
                4'd5:  fnum_of = 10'd103;
                4'd6:  fnum_of = 10'd515;
                4'd7:  fnum_of = 10'd161;
                4'd8:  fnum_of = 10'd805;
                4'd9:  fnum_of = 10'd1007;
                4'd10: fnum_of = 10'd315;
                4'd11: fnum_of = 10'd396;
                4'd12: fnum_of = 10'd500;
                4'd13: fnum_of = 10'd628;
                4'd14: fnum_of = 10'd796;
                4'd15: fnum_of = 10'd1004;
                default: fnum_of = 10'd537;
            endcase
        end
    endfunction

    function [2:0] block_of(input [3:0] v);
        begin
            case (v)
                4'd0:  block_of = 3'd2;
                4'd1:  block_of = 3'd4;
                4'd2:  block_of = 3'd6;
                4'd3:  block_of = 3'd4;
                4'd4:  block_of = 3'd4;
                4'd5:  block_of = 3'd7;
                4'd6:  block_of = 3'd5;
                4'd7:  block_of = 3'd7;
                4'd8:  block_of = 3'd5;
                4'd9:  block_of = 3'd5;
                4'd10: block_of = 3'd7;
                4'd11: block_of = 3'd7;
                4'd12: block_of = 3'd7;
                4'd13: block_of = 3'd7;
                4'd14: block_of = 3'd7;
                4'd15: block_of = 3'd7;
                default: block_of = 3'd2;
            endcase
        end
    endfunction

    function [5:0] band_of(input [3:0] v);
        begin
            case (v)
                4'd0:  band_of = 6'd0;   4'd1:  band_of = 6'd2;
                4'd2:  band_of = 6'd4;   4'd3:  band_of = 6'd6;
                4'd4:  band_of = 6'd8;   4'd5:  band_of = 6'd11;
                4'd6:  band_of = 6'd14;  4'd7:  band_of = 6'd18;
                4'd8:  band_of = 6'd21;  4'd9:  band_of = 6'd23;
                4'd10: band_of = 6'd25;  4'd11: band_of = 6'd27;
                4'd12: band_of = 6'd29;  4'd13: band_of = 6'd31;
                4'd14: band_of = 6'd33;  4'd15: band_of = 6'd35;
                default: band_of = 6'd0;
            endcase
        end
    endfunction

    function [12:0] tone_of64(input [5:0] k);
        begin
            case (k)
                6'd0: tone_of64 = {3'd2, 10'd537}; 6'd1: tone_of64 = {3'd2, 10'd573}; 6'd2: tone_of64 = {3'd2, 10'd611}; 6'd3: tone_of64 = {3'd2, 10'd652};                6'd4: tone_of64 = {3'd2, 10'd696}; 6'd5: tone_of64 = {3'd2, 10'd742}; 6'd6: tone_of64 = {3'd2, 10'd792}; 6'd7: tone_of64 = {3'd2, 10'd845};                6'd8: tone_of64 = {3'd2, 10'd901}; 6'd9: tone_of64 = {3'd2, 10'd961}; 6'd10: tone_of64 = {3'd3, 10'd513}; 6'd11: tone_of64 = {3'd3, 10'd547};                6'd12: tone_of64 = {3'd3, 10'd584}; 6'd13: tone_of64 = {3'd3, 10'd623}; 6'd14: tone_of64 = {3'd3, 10'd664}; 6'd15: tone_of64 = {3'd3, 10'd709};                6'd16: tone_of64 = {3'd3, 10'd756}; 6'd17: tone_of64 = {3'd3, 10'd807}; 6'd18: tone_of64 = {3'd3, 10'd861}; 6'd19: tone_of64 = {3'd3, 10'd918};                6'd20: tone_of64 = {3'd3, 10'd980}; 6'd21: tone_of64 = {3'd4, 10'd523}; 6'd22: tone_of64 = {3'd4, 10'd557}; 6'd23: tone_of64 = {3'd4, 10'd595};                6'd24: tone_of64 = {3'd4, 10'd634}; 6'd25: tone_of64 = {3'd4, 10'd677}; 6'd26: tone_of64 = {3'd4, 10'd722}; 6'd27: tone_of64 = {3'd4, 10'd770};                6'd28: tone_of64 = {3'd4, 10'd822}; 6'd29: tone_of64 = {3'd4, 10'd877}; 6'd30: tone_of64 = {3'd4, 10'd936}; 6'd31: tone_of64 = {3'd4, 10'd998};                6'd32: tone_of64 = {3'd5, 10'd532}; 6'd33: tone_of64 = {3'd5, 10'd568}; 6'd34: tone_of64 = {3'd5, 10'd606}; 6'd35: tone_of64 = {3'd5, 10'd647};                6'd36: tone_of64 = {3'd5, 10'd690}; 6'd37: tone_of64 = {3'd5, 10'd736}; 6'd38: tone_of64 = {3'd5, 10'd785}; 6'd39: tone_of64 = {3'd5, 10'd838};                6'd40: tone_of64 = {3'd5, 10'd894}; 6'd41: tone_of64 = {3'd5, 10'd953}; 6'd42: tone_of64 = {3'd5, 10'd1017}; 6'd43: tone_of64 = {3'd6, 10'd543};                6'd44: tone_of64 = {3'd6, 10'd579}; 6'd45: tone_of64 = {3'd6, 10'd618}; 6'd46: tone_of64 = {3'd6, 10'd659}; 6'd47: tone_of64 = {3'd6, 10'd703};                6'd48: tone_of64 = {3'd6, 10'd750}; 6'd49: tone_of64 = {3'd6, 10'd800}; 6'd50: tone_of64 = {3'd6, 10'd853}; 6'd51: tone_of64 = {3'd6, 10'd911};                6'd52: tone_of64 = {3'd6, 10'd971}; 6'd53: tone_of64 = {3'd7, 10'd518}; 6'd54: tone_of64 = {3'd7, 10'd553}; 6'd55: tone_of64 = {3'd7, 10'd590};                6'd56: tone_of64 = {3'd7, 10'd629}; 6'd57: tone_of64 = {3'd7, 10'd671}; 6'd58: tone_of64 = {3'd7, 10'd716}; 6'd59: tone_of64 = {3'd7, 10'd764};                6'd60: tone_of64 = {3'd7, 10'd815}; 6'd61: tone_of64 = {3'd7, 10'd870}; 6'd62: tone_of64 = {3'd7, 10'd928}; 6'd63: tone_of64 = {3'd7, 10'd990};                default: tone_of64 = {3'd2, 10'd537};
            endcase
        end
    endfunction

    function [5:0] band_of64(input [5:0] k);
        begin
            case (k)
                6'd0: band_of64 = 6'd0; 6'd1: band_of64 = 6'd0; 6'd2: band_of64 = 6'd0; 6'd3: band_of64 = 6'd1; 6'd4: band_of64 = 6'd1; 6'd5: band_of64 = 6'd1; 6'd6: band_of64 = 6'd1; 6'd7: band_of64 = 6'd1;                6'd8: band_of64 = 6'd2; 6'd9: band_of64 = 6'd2; 6'd10: band_of64 = 6'd2; 6'd11: band_of64 = 6'd2; 6'd12: band_of64 = 6'd3; 6'd13: band_of64 = 6'd3; 6'd14: band_of64 = 6'd3; 6'd15: band_of64 = 6'd4;                6'd16: band_of64 = 6'd4; 6'd17: band_of64 = 6'd4; 6'd18: band_of64 = 6'd5; 6'd19: band_of64 = 6'd5; 6'd20: band_of64 = 6'd6; 6'd21: band_of64 = 6'd6; 6'd22: band_of64 = 6'd7; 6'd23: band_of64 = 6'd7;                6'd24: band_of64 = 6'd8; 6'd25: band_of64 = 6'd9; 6'd26: band_of64 = 6'd9; 6'd27: band_of64 = 6'd10; 6'd28: band_of64 = 6'd11; 6'd29: band_of64 = 6'd12; 6'd30: band_of64 = 6'd13; 6'd31: band_of64 = 6'd14;                6'd32: band_of64 = 6'd15; 6'd33: band_of64 = 6'd16; 6'd34: band_of64 = 6'd17; 6'd35: band_of64 = 6'd18; 6'd36: band_of64 = 6'd20; 6'd37: band_of64 = 6'd20; 6'd38: band_of64 = 6'd21; 6'd39: band_of64 = 6'd21;                6'd40: band_of64 = 6'd22; 6'd41: band_of64 = 6'd22; 6'd42: band_of64 = 6'd23; 6'd43: band_of64 = 6'd23; 6'd44: band_of64 = 6'd24; 6'd45: band_of64 = 6'd25; 6'd46: band_of64 = 6'd25; 6'd47: band_of64 = 6'd26;                6'd48: band_of64 = 6'd26; 6'd49: band_of64 = 6'd27; 6'd50: band_of64 = 6'd27; 6'd51: band_of64 = 6'd28; 6'd52: band_of64 = 6'd28; 6'd53: band_of64 = 6'd29; 6'd54: band_of64 = 6'd29; 6'd55: band_of64 = 6'd30;                6'd56: band_of64 = 6'd31; 6'd57: band_of64 = 6'd31; 6'd58: band_of64 = 6'd32; 6'd59: band_of64 = 6'd32; 6'd60: band_of64 = 6'd33; 6'd61: band_of64 = 6'd33; 6'd62: band_of64 = 6'd34; 6'd63: band_of64 = 6'd34;                default: band_of64 = 6'd0;
            endcase
        end
    endfunction

    function [2:0] wide_group(input [7:0] w);
        begin
            if      (w < 8'd8)   wide_group = 3'd0;
            else if (w < 8'd16)  wide_group = 3'd1;
            else if (w < 8'd32)  wide_group = 3'd2;
            else if (w < 8'd64)  wide_group = 3'd3;
            else if (w < 8'd128) wide_group = 3'd4;
            else                 wide_group = 3'd5;
        end
    endfunction

    function [12:0] tone_wide(input [7:0] v);
        reg [2:0]  g;
        reg [7:0]  j;
        reg [11:0] t;
        reg [9:0]  f;
        begin
            g = wide_group(v + 8'd4);
            case (g)
                3'd0: j = v - 8'd0;
                3'd1: j = v - 8'd4;
                3'd2: j = v - 8'd12;
                3'd3: j = v - 8'd28;
                3'd4: j = v - 8'd60;
                3'd5: j = v - 8'd124;
                default: j = v;
            endcase
            case (g)
                3'd0: t = {4'd0,j} << 7;
                3'd1: t = {4'd0,j} << 6;
                3'd2: t = {4'd0,j} << 5;
                3'd3: t = {4'd0,j} << 4;
                3'd4: t = {4'd0,j} << 3;
                3'd5: t = {4'd0,j} << 2;
                default: t = 12'd0;
            endcase
            f = 10'd512 + t[9:0];
            tone_wide = {g + 3'd2, f[9:0]};
        end
    endfunction

    reg [SH_TONE-1:0] seq_idx;
    wire [1:0] seq_op;
    wire [7:0]         seq_v8;
    wire [VKEY_W-1:0]  seq_v;
    wire [5:0]         seq_k;
    wire               seq_part;
    wire [STEP_SH-1:0] seq_sub;
    reg  [7:0] seq_addr;
    reg  [7:0] seq_wdata;

    wire [SH_TONE-1:0] vdelta = seq_idx - SH_VOICE;
    assign seq_op   = seq_idx[1:0];
    assign seq_v8   = vdelta >> STEP_SH;
    assign seq_v    = seq_v8[VKEY_W-1:0];
    assign seq_k    = seq_v8[5:0];
    assign seq_part = (N_VOICE > GRP_N) ? seq_v8[6] : 1'b0;
    assign seq_sub  = vdelta[STEP_SH-1:0];
    wire [13-1:0] ko_v13 = {4'b0, seq_idx} >> 1;
    wire [7:0] ko_v = (TONE_STEP_W == 2) ? {4'b0, seq_idx[VKEY_W-1:0]} : ko_v13[7:0];
    wire [12:0] seq_tone64 = tone_of64(seq_k);
    wire [9:0]  seq_fnum16 = fnum_of(seq_v[3:0]);
    wire [2:0]  seq_blk16  = block_of(seq_v[3:0]);
    wire [12:0] seq_tone = (N_VOICE > 128) ? tone_wide(seq_v8) : seq_tone64;
    wire        seq_part_out = (N_VOICE > 128) ? 1'b0 : seq_part;
    assign band_idx = (N_VOICE <= 16) ? {2'b00, band_of(seq_v[3:0])}
                                      : {2'b00, band_of64(seq_k)};

    always @* begin
        seq_addr  = 8'h00;
        seq_wdata = 8'h00;

        if      (seq_idx == SH_FX_EN)  begin seq_addr = 8'hF0; seq_wdata = 8'h00; end
        else if (seq_idx == SH_FX_WET) begin seq_addr = 8'hF1; seq_wdata = 8'h00; end
        else if (seq_idx < SH_FX_EN) begin
            if ((seq_idx >= SH_MULT) && (seq_idx < (SH_MULT + N_SLOT))) begin
                seq_addr  = 8'h20 + {6'd0, seq_op};
                seq_wdata = (seq_op == 2'd3) ? 8'h21 : 8'h20;
            end
            else if ((seq_idx >= SH_KTL) && (seq_idx < (SH_KTL + N_SLOT))) begin
                seq_addr  = 8'h40 + {6'd0, seq_op};
                seq_wdata = (seq_op == 2'd3) ? {2'b00, CARRIER_TL} : 8'h3F;
            end
            else if ((seq_idx >= SH_ADR) && (seq_idx < (SH_ADR + N_SLOT))) begin
                seq_addr  = 8'h60 + {6'd0, seq_op};
                seq_wdata = 8'hF0;
            end
            else if ((seq_idx >= SH_SLR) && (seq_idx < (SH_SLR + N_SLOT))) begin
                seq_addr  = 8'h80 + {6'd0, seq_op};
                seq_wdata = 8'hFF;
            end
            else if ((seq_idx >= SH_WF) && (seq_idx < (SH_WF + N_SLOT))) begin
                seq_addr  = 8'hE0 + {6'd0, seq_op};
                seq_wdata = 8'h00;
            end
            else if (seq_idx == SH_NTS) begin
                seq_addr  = 8'h01;
                seq_wdata = 8'h00;
            end
            else if (seq_idx == SH_ALGO) begin
                seq_addr  = 8'hC0;
                seq_wdata = 8'h00;
            end
            else if (TONE_STEP_W == 2) begin
                if (seq_idx[0] == 1'b0) begin
                    seq_addr  = 8'hA0 + {4'd0, seq_v[3:0]};
                    seq_wdata = seq_fnum16[7:0];
                end
                else begin
                    seq_addr  = 8'hB0 + {4'd0, seq_v[3:0]};
                    seq_wdata = {1'b1, seq_blk16, seq_fnum16[9:8]};
                end
            end
            else begin
                case (seq_sub)
                    2'd0: begin
                        seq_addr  = 8'h03;
                        seq_wdata = {4'b0, seq_v8[7:4]};
                    end
                    2'd1: begin
                        seq_addr  = 8'hD0 + {4'd0, seq_v[3:0]};
                        seq_wdata = {6'b0, seq_part_out};
                    end
                    2'd2: begin
                        seq_addr  = 8'hA0 + {4'd0, seq_v[3:0]};
                        seq_wdata = seq_tone[7:0];
                    end
                    default: begin
                        seq_addr  = 8'hB0 + {4'd0, seq_v[3:0]};
                        seq_wdata = {1'b1, seq_tone[12:10], seq_tone[9:8]};
                    end
                endcase
            end
        end
    end

    reg  [2:0]  st;
    reg  [19:0] settle_cnt;
    reg  [15:0] gap_cnt;
    reg         done_pulse;

    assign busy      = (st == ST_LOAD) || (st == ST_KEYOFF) || (st == ST_PGCLR);
    assign load_done = done_pulse;
    assign voice_cnt = (st == ST_RUN) ? N_VOICE[CNT_W-1:0] : {CNT_W{1'b0}};
    assign voice_idx = {{(13-SH_TONE){1'b0}}, seq_idx};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st         <= ST_IDLE;
            seq_idx    <= {SH_TONE{1'b0}};
            settle_cnt <= 20'd0;
            gap_cnt    <= 16'd0;
            reg_we     <= 1'b0;
            reg_addr   <= 8'h00;
            reg_wdata  <= 8'h00;
            done_pulse <= 1'b0;
        end
        else begin
            reg_we     <= 1'b0;
            done_pulse <= 1'b0;

            case (st)
            ST_IDLE: begin
                if (enable) begin
                    settle_cnt <= 20'd0;
                    st         <= ST_SETTLE;
                end
            end

            ST_SETTLE: begin
                if (!cfg_ok)
                    settle_cnt <= 20'd0;
                else if (settle_cnt != SETTLE_CLK[19:0])
                    settle_cnt <= settle_cnt + 20'd1;
                else begin
                    seq_idx <= {SH_TONE{1'b0}};
                    gap_cnt <= 16'd0;
                    st      <= ST_LOAD;
                end
            end

            ST_LOAD: begin
                if (!enable) begin
                    seq_idx <= {SH_TONE{1'b0}};
                    gap_cnt <= 16'd0;
                    st      <= ST_KEYOFF;
                end
                else if (gap_cnt != 16'd0) begin
                    gap_cnt <= gap_cnt - 16'd1;
                end
                else if (!bus_gnt) begin
                    reg_we <= 1'b0;
                    gap_cnt <= 16'd0;
                end
                else begin
                    gap_cnt   <= GAP_CLK[15:0];
                    reg_we    <= 1'b1;
                    reg_addr  <= seq_addr;
                    reg_wdata <= seq_wdata;

                    if (seq_idx < LAST_TONE)
                        seq_idx <= seq_idx + 1'b1;
                    else begin
                        seq_idx    <= {SH_TONE{1'b0}};
                        done_pulse <= 1'b1;
                        st         <= ST_RUN;
                    end
                end
            end

            ST_RUN: begin
                if (!enable) begin
                    seq_idx <= {SH_TONE{1'b0}};
                    gap_cnt <= 16'd0;
                    st      <= ST_KEYOFF;
                end
            end

            ST_KEYOFF: begin
                if (enable) begin
                    settle_cnt <= 20'd0;
                    seq_idx    <= {SH_TONE{1'b0}};
                    gap_cnt    <= 16'd0;
                    st         <= ST_SETTLE;
                end
                else if (gap_cnt != 16'd0) begin
                    gap_cnt <= gap_cnt - 16'd1;
                end
                else if (!bus_gnt) begin
                    reg_we <= 1'b0;
                    gap_cnt <= 16'd0;
                end
                else begin
                    gap_cnt   <= GAP_CLK[15:0];
                    reg_we    <= 1'b1;
                    if (TONE_STEP_W == 2) begin
                        reg_addr  <= 8'hB0 + {4'd0, ko_v[3:0]};
                        reg_wdata <= 8'h00;
                    end
                    else if (seq_idx[0] == 1'b0) begin
                        reg_addr  <= 8'h03;
                        reg_wdata <= {4'b0, ko_v[7:4]};
                    end
                    else begin
                        reg_addr  <= 8'hB0 + {4'd0, ko_v[3:0]};
                        reg_wdata <= 8'h00;
                    end

                    if (seq_idx < LAST_KO)
                        seq_idx <= seq_idx + 1'b1;
                    else begin
                        seq_idx <= {SH_TONE{1'b0}};
                        st      <= ST_PGCLR;
                    end
                end
            end

            ST_PGCLR: begin
                if (gap_cnt != 16'd0) begin
                    gap_cnt <= gap_cnt - 16'd1;
                end
                else begin
                    reg_we    <= 1'b1;
                    reg_addr  <= 8'h03;
                    reg_wdata <= 8'h00;
                    st        <= ST_IDLE;
                end
            end

            default: st <= ST_IDLE;
            endcase
        end
    end

`ifdef SIMULATION
    integer si_v, si_w, si_f, si_p;
    integer si_prev_block, si_prev_fnum, si_bands_hit;
    integer si_tone;

    initial begin
        if (N_SLOT != 4)
            $display("*** ERROR test_tone_src: N_SLOT(%0d) != 4", N_SLOT);
        if (N_VOICE > 256)
            $display("*** ERROR test_tone_src: N_VOICE(%0d) > 256 —— 声部号 8 位装不下（页 4 + 低 4）", N_VOICE);
        if ((N_VOICE > GRP_N) && (N_VOICE <= 128) && ((N_VOICE % GRP_N) != 0))
            $display("*** ERROR test_tone_src: N_VOICE(%0d) 不是 GRP_N(%0d) 的整数倍 —— 分组不整齐",
                     N_VOICE, GRP_N);
        if ((N_VOICE > 16) && (N_VOICE < GRP_N))
            $display("*** NOTE test_tone_src: N_VOICE(%0d) < GRP_N(%0d) —— 只用到前 %0d 个音高（合法，仅备案）",
                     N_VOICE, GRP_N, N_VOICE);
        if (GAP_CLK <= 64)
            $display("*** ERROR test_tone_src: GAP_CLK(%0d) <= 64 —— 会打断 param_store 的扫描", GAP_CLK);

        if (N_VOICE <= 16) begin
            si_p = 0;
            for (si_v = 0; si_v < 16; si_v = si_v + 1) begin
                si_f = ((fnum_of(si_v[3:0]) << block_of(si_v[3:0])) * 4657) / 1000;
                if (si_v > 0 && (si_f * 100) < (si_p * 125))
                    $display("*** ERROR test_tone_src: 频率表 v=%0d 相邻比 < 1.25（%0d -> %0d）",
                             si_v, si_p, si_f);
                if (si_f > 610100)
                    $display("*** ERROR test_tone_src: v=%0d 频率 %0d 超引擎上限（fnum 10bit x block 3bit）",
                             si_v, si_f);
                si_p = si_f;
            end
            for (si_v = 0; si_v < 16; si_v = si_v + 1)
                for (si_w = si_v + 1; si_w < 16; si_w = si_w + 1)
                    if (band_of(si_v[3:0]) == band_of(si_w[3:0]))
                        $display("*** ERROR test_tone_src: v=%0d 与 v=%0d 落在同一档 %0d",
                                 si_v, si_w, band_of(si_v[3:0]));
        end
        else begin
            si_p = -1; si_prev_block = -1; si_prev_fnum = -1; si_bands_hit = 0;
            for (si_v = 0; si_v < PITCH_N; si_v = si_v + 1) begin
                si_tone = tone_of64(si_v[5:0]);
                if (si_tone[12:10] > 3'd7)
                    $display("*** ERROR test_tone_src: tone_of64(%0d) block=%0d > 7",
                             si_v, si_tone[12:10]);
                si_f = ((si_tone[9:0] << si_tone[12:10]) * 4657) / 1000;
                if (si_f > 610100)
                    $display("*** ERROR test_tone_src: tone_of64(%0d) 频率 %0d 超引擎上限", si_v, si_f);
                if (si_p >= 0 && si_f <= si_p)
                    $display("*** ERROR test_tone_src: 等比表 k=%0d 非严格单调（%0d -> %0d）", si_v, si_p, si_f);
                si_p = si_f;
                if (si_v == 0) si_bands_hit = 1;
                else if (band_of64(si_v[5:0]) != band_of64((si_v-1)))
                    si_bands_hit = si_bands_hit + 1;
            end
            if (si_bands_hit < 34)
                $display("*** ERROR test_tone_src: 等比表只点亮 %0d 档（实测应 34；显示侧上限 36）", si_bands_hit);
            else
                $display("*** NOTE test_tone_src: 等比表 64 音高点亮 %0d 档（显示侧上限 36 = 引擎 6.1kHz 只到 band 35）",
                         si_bands_hit);
        end
    end
`endif

    wire _unused = &{1'b0, voice_idx, band_idx, 1'b0};

endmodule
