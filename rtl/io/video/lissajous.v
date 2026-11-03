// lissajous

`timescale 1ns/1ps

module lissajous #(
    parameter integer X0 = 336,
    parameter integer Y0 = 400,
    parameter integer X1 = 1024,
    parameter integer Y1 = 600,

    parameter integer DPW     = 181,
    parameter integer DPH     = 181,
    parameter integer XLSH    = 0,
    parameter integer YLSH    = 0,
    parameter integer OUT_LAT = 4,
    parameter integer WIN      = 1024
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        de,
    input  wire [11:0] x,
    input  wire [11:0] y,
    input  wire        sof,

    output wire [9:0]         rd_addr,
    input  wire signed [15:0] pcm,
    input  wire [9:0]         trig_pos,
    input  wire [10:0]        valid_cnt,
    input  wire               trig_valid,
    input  wire [4:0]         cur_note,
    input  wire [2:0]         cur_oct,

    output wire [23:0] rgb,
    output wire        hit,
    output wire        busy
);

    localparam [11:0] X0_C  = X0[11:0];
    localparam [11:0] Y0_C  = Y0[11:0];
    localparam [11:0] X1_C  = X1[11:0];
    localparam [11:0] Y1_C  = Y1[11:0];
    localparam [11:0] WINM_C = WIN[11:0] - 12'd1;
    wire  [9:0]        WINM  = WINM_C[9:0];

    localparam [12:0] OFFX = X0[11:0] + ((X1[11:0] - X0[11:0]) >> 1)
                             - (DPW[12:0] >> 1) - XLSH[12:0];
    localparam [12:0] OFFY = Y0[11:0] + ((Y1[11:0] - Y0[11:0]) >> 1)
                             - (DPH[12:0] >> 1) - YLSH[12:0];

    localparam [23:0] C_DOT  = 24'hFFB040,
                      C_GRID = 24'h16202C,
                      C_AXIS = 24'h2A3A4A,
                      C_WAIT = 24'h4A4A52,
                      C_BG   = 24'h080A0C;


    localparam integer BM_WORDS = (DPW * DPH + 7) / 8;
    localparam [12:0]  BM_AW     = 13;

    reg [7:0] bitmap [0:BM_WORDS-1];

    reg [BM_AW-1:0] wr_addr_r;
    reg [7:0]       wr_data_r;
    reg             wr_en_r;

    always @(posedge clk) begin
        if (wr_en_r) bitmap[wr_addr_r] <= wr_data_r;
    end

    function [21:0] row_base;
        input [8:0] yy;
        begin
            row_base = ({13'd0, yy} << 7)
                     + ({13'd0, yy} << 5)
                     + ({13'd0, yy} << 4)
                     + ({13'd0, yy} << 2)
                     + {13'd0, yy};
        end
    endfunction

    function [BM_AW-1:0] bm_word;
        input [8:0] yy;
        input [8:0] xx;
        reg [21:0] flat;
        begin
            flat    = row_base(yy) + {13'd0, xx};
            bm_word = flat[BM_AW+2:3];
        end
    endfunction

    function [2:0] bm_bit;
        input [8:0] yy;
        input [8:0] xx;
        reg [21:0] flat;
        begin
            flat   = row_base(yy) + {13'd0, xx};
            bm_bit = flat[2:0];
        end
    endfunction


    function [8:0] pos_from_sample;
        input signed [15:0] s16;
        integer sx;
        integer sn;
        integer a;
        integer p;
        begin
            sx = s16;
            sn = sx;

            a  = sn + 16384;
            p  = ((a << 7) + (a << 5) + (a << 4) + (a << 2)) >> 15;
            if (p < 0)       p = 0;
            if (p > DPW - 1) p = DPW - 1;
            pos_from_sample = p[8:0];
        end
    endfunction

    localparam [3:0] LS_IDLE  = 4'd0,
                     LS_MEAS  = 4'd1,
                     LS_COUNT = 4'd2,
                     LS_SNAP  = 4'd3,
                     LS_SR    = 4'd4,
                     LS_CLR   = 4'd5,
                     LS_GETX  = 4'd6,
                     LS_GETY  = 4'd7,
                     LS_RDX   = 4'd8,
                     LS_RDY   = 4'd9,
                     LS_INIT  = 4'd10,
                     LS_STEP  = 4'd11,
                     LS_RD    = 4'd12,
                     LS_WRB   = 4'd13,
                     LS_NEXT  = 4'd14;


    reg [3:0]      ls;
    reg [12:0]     clr_word;
    reg [9:0]      pt;
    reg            clr_only;
    reg            trace_live;

    assign rd_addr = 10'd0;
    assign busy    = (ls != LS_IDLE);

    function [6:0] t4_base;
        input [3:0] s;
        begin
            case (s)
                4'd0  : t4_base = 7'd23;
                4'd1  : t4_base = 7'd22;
                4'd2  : t4_base = 7'd21;
                4'd3  : t4_base = 7'd20;
                4'd4  : t4_base = 7'd18;
                4'd5  : t4_base = 7'd17;
                4'd6  : t4_base = 7'd16;
                4'd7  : t4_base = 7'd16;
                4'd8  : t4_base = 7'd15;
                4'd9  : t4_base = 7'd14;
                4'd10 : t4_base = 7'd13;
                4'd11 : t4_base = 7'd12;
                default: t4_base = 7'd12;
            endcase
        end
    endfunction
    wire [1:0] oct_add_l = (cur_note >= 5'd24) ? 2'd2 : (cur_note >= 5'd12) ? 2'd1 : 2'd0;
    wire [4:0] sem_l     = (cur_note >= 5'd24) ? (cur_note - 5'd24)
                         : (cur_note >= 5'd12) ? (cur_note - 5'd12)
                         : cur_note;
    wire [2:0] oct_eff_l = ((cur_oct + {1'b0, oct_add_l}) > 3'd5) ? 3'd5
                                                              : (cur_oct + {1'b0, oct_add_l});
    wire [6:0] t4b       = t4_base(sem_l[3:0]);
    wire signed [3:0] sft_l = $signed({1'b0, oct_eff_l}) - 4'sd2;
    wire [8:0] t4_raw = (sft_l < 0)          ? ({2'b00, t4b} << ((-sft_l))) :
                        (sft_l[1:0] == 2'd0) ? {2'b00, t4b} :
                        (sft_l[1:0] == 2'd1) ? ({2'b00, t4b} >> 1) :
                        (sft_l[1:0] == 2'd2) ? ({2'b00, t4b} >> 2) :
                                               ({2'b00, t4b} >> 3);
    wire [8:0] t4 = (t4_raw < 9'd2) ? 9'd2 : (t4_raw > 9'd94) ? 9'd94 : t4_raw;
    reg  [8:0] t4_hold;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                   t4_hold <= 9'd23;
        else if (cur_note <= 5'd24)   t4_hold <= t4;
    end
    wire       m_big = (t4_hold >= 9'd24);
    wire [10:0] m_num = m_big ? 11'd1024 : 11'd512;
    wire [10:0] m_lim = m_num - 11'd1;

    localparam [2:0] RAT_SEL = 3'd1;
    function [3:0] rat_p;
        input [2:0] s;
        begin
            case (s)
                3'd0: rat_p = 4'd1;
                3'd1: rat_p = 4'd3;
                3'd2: rat_p = 4'd3;
                3'd3: rat_p = 4'd5;
                3'd4: rat_p = 4'd5;
                3'd5: rat_p = 4'd9;
                3'd6: rat_p = 4'd2;
                default: rat_p = 4'd3;
            endcase
        end
    endfunction
    function [3:0] rat_q;
        input [2:0] s;
        begin
            case (s)
                3'd0: rat_q = 4'd2;
                3'd1: rat_q = 4'd2;
                3'd2: rat_q = 4'd4;
                3'd3: rat_q = 4'd4;
                3'd4: rat_q = 4'd6;
                3'd5: rat_q = 4'd8;
                3'd6: rat_q = 4'd1;
                default: rat_q = 4'd1;
            endcase
        end
    endfunction

    localparam [15:0] SIN_A = 16'd15073;
    function [15:0] sin_q;
        input [6:0] o;
        begin
            case (o)
                7'd0  : sin_q = 16'd0;
                7'd1  : sin_q = 16'd370;
                7'd2  : sin_q = 16'd740;
                7'd3  : sin_q = 16'd1109;
                7'd4  : sin_q = 16'd1477;
                7'd5  : sin_q = 16'd1845;
                7'd6  : sin_q = 16'd2212;
                7'd7  : sin_q = 16'd2577;
                7'd8  : sin_q = 16'd2941;
                7'd9  : sin_q = 16'd3303;
                7'd10 : sin_q = 16'd3662;
                7'd11 : sin_q = 16'd4020;
                7'd12 : sin_q = 16'd4375;
                7'd13 : sin_q = 16'd4728;
                7'd14 : sin_q = 16'd5078;
                7'd15 : sin_q = 16'd5425;
                7'd16 : sin_q = 16'd5768;
                7'd17 : sin_q = 16'd6108;
                7'd18 : sin_q = 16'd6445;
                7'd19 : sin_q = 16'd6777;
                7'd20 : sin_q = 16'd7105;
                7'd21 : sin_q = 16'd7429;
                7'd22 : sin_q = 16'd7749;
                7'd23 : sin_q = 16'd8064;
                7'd24 : sin_q = 16'd8374;
                7'd25 : sin_q = 16'd8679;
                7'd26 : sin_q = 16'd8979;
                7'd27 : sin_q = 16'd9273;
                7'd28 : sin_q = 16'd9562;
                7'd29 : sin_q = 16'd9845;
                7'd30 : sin_q = 16'd10122;
                7'd31 : sin_q = 16'd10393;
                7'd32 : sin_q = 16'd10658;
                7'd33 : sin_q = 16'd10917;
                7'd34 : sin_q = 16'd11168;
                7'd35 : sin_q = 16'd11413;
                7'd36 : sin_q = 16'd11652;
                7'd37 : sin_q = 16'd11883;
                7'd38 : sin_q = 16'd12107;
                7'd39 : sin_q = 16'd12323;
                7'd40 : sin_q = 16'd12533;
                7'd41 : sin_q = 16'd12734;
                7'd42 : sin_q = 16'd12929;
                7'd43 : sin_q = 16'd13115;
                7'd44 : sin_q = 16'd13293;
                7'd45 : sin_q = 16'd13464;
                7'd46 : sin_q = 16'd13626;
                7'd47 : sin_q = 16'd13780;
                7'd48 : sin_q = 16'd13926;
                7'd49 : sin_q = 16'd14063;
                7'd50 : sin_q = 16'd14192;
                7'd51 : sin_q = 16'd14312;
                7'd52 : sin_q = 16'd14424;
                7'd53 : sin_q = 16'd14527;
                7'd54 : sin_q = 16'd14621;
                7'd55 : sin_q = 16'd14707;
                7'd56 : sin_q = 16'd14783;
                7'd57 : sin_q = 16'd14851;
                7'd58 : sin_q = 16'd14910;
                7'd59 : sin_q = 16'd14960;
                7'd60 : sin_q = 16'd15000;
                7'd61 : sin_q = 16'd15032;
                7'd62 : sin_q = 16'd15055;
                7'd63 : sin_q = 16'd15068;
                7'd64 : sin_q = 16'd15073;
                default: sin_q = 16'd0;
            endcase
        end
    endfunction
    function [15:0] sin_v;
        input [7:0]  a;
        reg   [6:0]  idx;
        reg   [15:0] m;
        begin
            idx   = a[6] ? (7'd64 - {1'b0, a[5:0]}) : {1'b0, a[5:0]};
            m     = sin_q(idx);
            sin_v = a[7] ? (16'd0 - m) : m;
        end
    endfunction

    wire [3:0]  rat_p_w = rat_p(RAT_SEL);
    wire [3:0]  rat_q_w = rat_q(RAT_SEL);
    reg  [10:0] phx, phy;
    wire [11:0] phx_s  = {1'b0, phx} + {8'd0, rat_p_w};
    wire [11:0] phy_s  = {1'b0, phy} + {8'd0, rat_q_w};
    wire [10:0] phx_nx = (phx_s >= {1'b0, m_num}) ? (phx_s[10:0] - m_num) : phx_s[10:0];
    wire [10:0] phy_nx = (phy_s >= {1'b0, m_num}) ? (phy_s[10:0] - m_num) : phy_s[10:0];
    wire [7:0]  sin_ax = m_big ? phx[9:2] : phx[8:1];
    wire [7:0]  sin_ay = m_big ? phy[9:2] : phy[8:1];
    reg  [7:0]  sin_addr_r;
    reg  [15:0] sin_rd;
    always @(posedge clk) begin
        sin_rd <= sin_v(sin_addr_r);
    end

    reg [8:0] px, py;
    reg [8:0] prev_px, prev_py;
    reg [8:0] tx, ty;
    reg        have_prev;
    reg [13:0] yacc;
    reg [9:0]  dxs, dys;
    reg signed [8:0] sxs, sys_;

    wire [9:0] dabs = (tx > prev_px) ? ({1'b0, tx}     - {1'b0, prev_px})
                                     : ({1'b0, prev_px} - {1'b0, tx});
    wire [9:0] eabs = (ty > prev_py) ? ({1'b0, ty}     - {1'b0, prev_py})
                                     : ({1'b0, prev_py} - {1'b0, ty});

    reg [BM_AW-1:0] dot_addr_r;
    reg [2:0]       dot_bit_r;
    reg [7:0]       dot_dout_r;
    reg             dot_last_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ls          <= LS_CLR;
            clr_word    <= 13'd0;
            clr_only    <= 1'b1;
            pt          <= 10'd0;
            phx         <= 11'd0;
            phy         <= 11'd0;
            sin_addr_r  <= 8'd0;
            dot_addr_r  <= {BM_AW{1'b0}};
            dot_bit_r   <= 3'd0;
            dot_dout_r  <= 8'd0;
            dot_last_r  <= 1'b0;
            px          <= 9'd0; py      <= 9'd0;
            prev_px     <= 9'd0; prev_py <= 9'd0;
            tx          <= 9'd0; ty      <= 9'd0;
            have_prev   <= 1'b0;
            yacc        <= 14'd0;
            dxs         <= 10'sd0; dys    <= 10'sd0;
            sxs         <= 9'sd1; sys_   <= 9'sd1;
            trace_live  <= 1'b0;
            wr_en_r     <= 1'b0;
            wr_addr_r   <= {BM_AW{1'b0}};
            wr_data_r   <= 8'h00;
        end
        else begin
            case (ls)
            LS_IDLE: begin
                if (sof && (valid_cnt == WIN[10:0])) begin
                    clr_word  <= 13'd0;
                    clr_only  <= 1'b0;
                    pt        <= 10'd0;
                    phx       <= 11'd0;
                    phy       <= 11'd0;
                    have_prev <= 1'b0;
                    ls        <= LS_CLR;
                end
            end


            LS_CLR: begin
                wr_addr_r <= clr_word[BM_AW-1:0];
                wr_data_r <= 8'h00;
                wr_en_r   <= 1'b1;
                if (clr_word == BM_WORDS[12:0] - 13'd1) begin
                    if (clr_only) begin
                        clr_only <= 1'b0;
                        ls       <= LS_IDLE;
                    end
                    else begin
                        pt        <= 10'd0;
                        phx       <= 11'd0;
                        phy       <= 11'd0;
                        have_prev <= 1'b0;
                        ls        <= LS_GETX;
                    end
                end
                else clr_word <= clr_word + 13'd1;
            end

            LS_GETX: begin
                sin_addr_r <= sin_ax;
                ls         <= LS_GETY;
            end

            LS_GETY: begin
                sin_addr_r <= sin_ay;
                ls         <= LS_RDX;
            end

            LS_RDX: begin
                tx <= pos_from_sample(sin_rd);
                ls <= LS_RDY;
            end

            LS_RDY: begin
                ty <= pos_from_sample(sin_rd);
                ls <= LS_INIT;
            end

            LS_INIT: begin
                if (!have_prev) begin
                    prev_px   <= tx;
                    prev_py   <= ty;
                    have_prev <= 1'b1;
                    ls        <= LS_NEXT;
                end
                else begin
                    px   <= prev_px; py <= prev_py;
                    dxs  <= dabs;
                    dys  <= eabs;
                    sxs  <= (tx > prev_px) ? 9'sd1  : -9'sd1;
                    sys_ <= (ty > prev_py) ? 9'sd1  : -9'sd1;
                    yacc <= 14'd0;
                    ls        <= LS_STEP;
                end
            end

            LS_STEP: begin
                dot_addr_r <= bm_word(py, px);
                dot_bit_r  <= bm_bit (py, px);
                dot_last_r <= (px == tx) && (py == ty);

                if (dxs >= dys) begin
                    if (px != tx) begin
                        px <= (sxs > 0) ? (px + 9'd1) : (px - 9'd1);
                        if ((yacc + dys) >= dxs) begin
                            py   <= (sys_ > 0) ? (py + 9'd1) : (py - 9'd1);
                            yacc <= (yacc + dys) - dxs;
                        end
                        else yacc <= yacc + dys;
                    end
                end
                else begin
                    if (py != ty) begin
                        py <= (sys_ > 0) ? (py + 9'd1) : (py - 9'd1);
                        if ((yacc + dxs) >= dys) begin
                            px   <= (sxs > 0) ? (px + 9'd1) : (px - 9'd1);
                            yacc <= (yacc + dxs) - dys;
                        end
                        else yacc <= yacc + dxs;
                    end
                end
                ls <= LS_RD;
            end

            LS_RD: begin
                dot_dout_r <= bitmap[dot_addr_r];
                ls         <= LS_WRB;
            end

            LS_WRB: begin
                wr_addr_r <= dot_addr_r;
                wr_data_r <= dot_dout_r | (8'h01 << dot_bit_r);
                wr_en_r   <= 1'b1;
                if (dot_last_r) begin
                    prev_px <= tx;
                    prev_py <= ty;
                    ls      <= LS_NEXT;
                end
                else ls <= LS_STEP;
            end

            LS_NEXT: begin
                if ({1'b0, pt} >= m_lim) begin
                    trace_live <= 1'b1;
                    ls         <= LS_IDLE;
                end
                else begin
                    pt  <= pt + 10'd1;
                    phx <= phx_nx;
                    phy <= phy_nx;
                    ls  <= LS_GETX;
                end
            end

            default: ls <= LS_IDLE;
            endcase
        end
    end

    wire in_region = (x >= X0_C) && (x < X1_C) && (y >= Y0_C) && (y < Y1_C);

    wire [12:0] bcol = {1'b0, x} - OFFX;
    wire [12:0] brow = {1'b0, y} - OFFY;
    wire in_xy = (bcol < DPW[12:0]) && (brow < DPH[12:0]);

    reg [12:0] sc_addr, sc_col, sc_row;
    reg [2:0]  sc_bit;
    reg        sc_in;
    reg [7:0]  sc_dout;
    reg [12:0] sc_col2, sc_row2;
    reg        sc_in2;
    reg [2:0]  sc_bit2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sc_addr <= 13'd0; sc_col <= 13'd0; sc_row <= 13'd0;
            sc_bit  <= 3'd0;  sc_in  <= 1'b0;
            sc_col2 <= 13'd0; sc_row2 <= 13'd0; sc_in2 <= 1'b0;
            sc_bit2 <= 3'd0;  sc_dout <= 8'd0;
        end
        else begin
            sc_addr <= bm_word(brow[8:0], bcol[8:0]);
            sc_col  <= bcol;
            sc_row  <= brow;
            sc_bit  <= bm_bit (brow[8:0], bcol[8:0]);
            sc_in   <= in_xy;
            sc_col2 <= sc_col;
            sc_row2 <= sc_row;
            sc_in2  <= sc_in;
            sc_bit2 <= sc_bit;
            sc_dout <= bitmap[sc_addr];
        end
    end

    wire bitval = sc_in2 && sc_dout[sc_bit2];

    wire on_edge_x = (sc_col2 == 13'd0) || (sc_col2 == (DPW[12:0] - 13'd1));
    wire on_edge_y = (sc_row2 == 13'd0) || (sc_row2 == (DPH[12:0] - 13'd1));
    wire frm  = sc_in2 && (on_edge_x || on_edge_y);
    wire axis = sc_in2 && ((sc_col2 == (DPW[12:0] >> 1)) ||
                           (sc_row2 == (DPH[12:0] >> 1)));
    wire tick = frm && ((on_edge_x && (sc_row2[3:0] == 4'd0)) ||
                        (on_edge_y && (sc_col2[3:0] == 4'd0)));
    wire idle_diag = sc_in2 && ((((sc_col2 + sc_row2) & 13'h0FFF) & 13'h3F) == 13'd0);

    reg [23:0] rgb_c;
    reg        hit_c;

    always @(*) begin
        hit_c = 1'b1;
        if (!in_region || !de) begin
            rgb_c = C_BG;
            hit_c = 1'b0;
        end
        else begin
            if      (bitval)                     rgb_c = C_DOT;
            else if (tick)                       rgb_c = C_AXIS;
            else if (frm || axis)                rgb_c = C_GRID;
            else if (!trace_live && idle_diag)   rgb_c = C_WAIT;
            else                                 rgb_c = C_BG;
        end
    end

    reg [24*OUT_LAT-1:0] rgb_pipe;
    reg [OUT_LAT-1:0]    hit_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rgb_pipe <= {24*OUT_LAT{1'b0}};
            hit_pipe <= {OUT_LAT{1'b0}};
        end
        else begin
            rgb_pipe <= (rgb_pipe << 24) | rgb_c;
            hit_pipe <= (hit_pipe << 1)  | hit_c;
        end
    end

    assign rgb = rgb_pipe[23:0];
    assign hit = hit_pipe[0];

endmodule
