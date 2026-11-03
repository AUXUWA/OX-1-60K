// param_edit

`timescale 1ns/1ps

module param_edit #(
    parameter integer MW = 8
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        bus_we,
    input  wire [7:0]  bus_addr,
    input  wire [7:0]  bus_wdata,

    input  wire        base_snap,

    input  wire        req_pulse,
    input  wire [4:0]  req_page,
    input  wire [1:0]  req_op,
    input  wire        req_dir,

    output reg         pe_we,
    output reg  [7:0]  pe_addr,
    output reg  [7:0]  pe_wdata,
    input  wire        pe_gnt,

    output reg         busy,
    output reg  [3:0]  dbg_val
);

    `include "param_fields.vh"

`ifdef SIMULATION
    initial begin
        if (MW != 8)
            $display("*** ERROR param_edit: MW(%0d) != 8 -- engine regs are 8 bit; the field table is written for 8 bit", MW);
    end
`endif

    reg [MW-1:0] by_20, by_21, by_22, by_23;
    reg [MW-1:0] by_40, by_41, by_42, by_43;
    reg [MW-1:0] by_60, by_61, by_62, by_63;
    reg [MW-1:0] by_80, by_81, by_82, by_83;
    reg [MW-1:0] by_E0, by_E1, by_E2, by_E3;
    reg [MW-1:0] by_C0;
    reg [MW-1:0] by_F0, by_F1, by_F2;
    reg [MW-1:0] by_F3;
    reg [MW-1:0] by_F4;
    reg [MW-1:0] by_F5;

    reg [MW-1:0] bb_20, bb_21, bb_22, bb_23;
    reg [MW-1:0] bb_40, bb_41, bb_42, bb_43;
    reg [MW-1:0] bb_60, bb_61, bb_62, bb_63;
    reg [MW-1:0] bb_80, bb_81, bb_82, bb_83;
    reg [MW-1:0] bb_E0, bb_E1, bb_E2, bb_E3;
    reg [MW-1:0] bb_C0;
    reg [MW-1:0] bb_F0, bb_F1, bb_F2;
    reg [MW-1:0] bb_F4;
    reg [MW-1:0] bb_F5;

    localparam [4:0] BID_MULT = 5'd0;
    localparam [4:0] BID_TL   = 5'd4;
    localparam [4:0] BID_AD   = 5'd8;
    localparam [4:0] BID_SR   = 5'd12;
    localparam [4:0] BID_WF   = 5'd16;
    localparam [4:0] BID_ALGO = 5'd20;
    localparam [4:0] BID_FX0  = 5'd21;
    localparam [4:0] BID_FX1  = 5'd22;
    localparam [4:0] BID_FX2  = 5'd23;
    localparam [4:0] BID_FX3  = 5'd24;
    localparam [4:0] BID_VOL  = 5'd25;
    localparam [4:0] BID_4PT  = 5'd26;

    wire [2:0]  sh_algo     = by_C0[2:0];
    wire [2:0]  sh_fb       = by_C0[6:4];
    wire [2:0]  sh_room     = by_F0[3:1];
    wire        sh_fx_en    = by_F0[0];
    wire [3:0]  sh_damp     = by_F0[7:4];
    wire [2:0]  sh_wet      = by_F1[2:0];
    wire        sh_spread   = by_F1[3];
    wire [3:0]  sh_width    = by_F1[7:4];
    wire [7:0]  sh_predelay = by_F2;
    wire [15:0] sh_mult     = {by_23[3:0], by_22[3:0], by_21[3:0], by_20[3:0]};
    wire [23:0] sh_tl       = {by_43[5:0], by_42[5:0], by_41[5:0], by_40[5:0]};
    wire [15:0] sh_ar       = {by_63[7:4], by_62[7:4], by_61[7:4], by_60[7:4]};
    wire [15:0] sh_dr       = {by_63[3:0], by_62[3:0], by_61[3:0], by_60[3:0]};
    wire [15:0] sh_sl       = {by_83[7:4], by_82[7:4], by_81[7:4], by_80[7:4]};
    wire [15:0] sh_rr       = {by_83[3:0], by_82[3:0], by_81[3:0], by_80[3:0]};
    wire [11:0] sh_wf       = {by_E3[2:0], by_E2[2:0], by_E1[2:0], by_E0[2:0]};

    wire [2:0]  base_algo     = bb_C0[2:0];
    wire [2:0]  base_fb       = bb_C0[6:4];
    wire [2:0]  base_room     = bb_F0[3:1];
    wire        base_fx_en    = bb_F0[0];
    wire [3:0]  base_damp     = bb_F0[7:4];
    wire [2:0]  base_wet      = bb_F1[2:0];
    wire        base_spread   = bb_F1[3];
    wire [3:0]  base_width    = bb_F1[7:4];
    wire [7:0]  base_predelay = bb_F2;
    wire [15:0] base_mult     = {bb_23[3:0], bb_22[3:0], bb_21[3:0], bb_20[3:0]};
    wire [23:0] base_tl       = {bb_43[5:0], bb_42[5:0], bb_41[5:0], bb_40[5:0]};
    wire [15:0] base_ar       = {bb_63[7:4], bb_62[7:4], bb_61[7:4], bb_60[7:4]};
    wire [15:0] base_dr       = {bb_63[3:0], bb_62[3:0], bb_61[3:0], bb_60[3:0]};
    wire [15:0] base_sl       = {bb_83[7:4], bb_82[7:4], bb_81[7:4], bb_80[7:4]};
    wire [15:0] base_rr       = {bb_83[3:0], bb_82[3:0], bb_81[3:0], bb_80[3:0]};
    wire [11:0] base_wf       = {bb_E3[2:0], bb_E2[2:0], bb_E1[2:0], bb_E0[2:0]};


    reg [4:0]  q0_page, q1_page;
    reg [1:0]  q0_op,   q1_op;
    reg        q0_dir,  q1_dir;
    reg [1:0]  q_cnt;

    reg [7:0]    t_addr;
    reg [4:0]    t_id;
    reg [3:0]    t_lsb;
    reg [3:0]    t_wid;
    reg [7:0]    t_max;
    reg          t_valid;
    reg [MW-1:0] t_byte;
    reg [7:0]    t_cur;
    reg [7:0]    t_nv;
    reg [7:0]    t_mask;
    reg [MW-1:0] t_newbyte;

    always @(*) begin
        t_addr  = 8'h00;
        t_id    = BID_ALGO;
        t_lsb   = 4'd0;
        t_wid   = 4'd0;
        t_max   = 8'h00;
        t_valid = 1'b0;

        case (q0_page[4:2])
            3'd0: begin
                case (q0_page[1:0])
                    2'd0:    begin t_valid=1'b1; t_addr=8'hE0+q0_op; t_id=BID_WF  +q0_op; t_lsb=4'd0; t_wid=4'd3; t_max=8'd7;   end
                    2'd1:    begin t_valid=1'b1; t_addr=8'h20+q0_op; t_id=BID_MULT+q0_op; t_lsb=4'd0; t_wid=4'd4; t_max=8'd15;  end
                    2'd2:    begin t_valid=1'b1; t_addr=8'h40+q0_op; t_id=BID_TL  +q0_op; t_lsb=4'd0; t_wid=4'd6; t_max=8'd63;  end
                    default: begin t_valid=1'b1; t_addr=8'hC0; t_id=BID_ALGO; t_lsb=4'd0; t_wid=4'd3; t_max=8'd7; end
                endcase
            end
            3'd1: begin
                t_valid = 1'b1;
                case (q0_page[1:0])
                    2'd0:    begin t_addr=8'h60+q0_op; t_id=BID_AD  +q0_op; t_lsb=4'd4; t_wid=4'd4; t_max=8'd15; end
                    2'd1:    begin t_addr=8'h60+q0_op; t_id=BID_AD  +q0_op; t_lsb=4'd0; t_wid=4'd4; t_max=8'd15; end
                    2'd2:    begin t_addr=8'h80+q0_op; t_id=BID_SR  +q0_op; t_lsb=4'd4; t_wid=4'd4; t_max=8'd15; end
                    default: begin t_addr=8'h80+q0_op; t_id=BID_SR  +q0_op; t_lsb=4'd0; t_wid=4'd4; t_max=8'd15; end
                endcase
            end
            3'd2: begin
                t_valid = 1'b1;
                case (q0_page[1:0])
                    2'd0:    begin t_addr=8'hF0; t_id=BID_FX0;  t_lsb=4'd1; t_wid=4'd3; t_max=8'd7;   end
                    2'd1:    begin t_addr=8'hF1; t_id=BID_FX1;  t_lsb=4'd0; t_wid=4'd3; t_max=8'd7;   end
                    2'd2:    begin t_addr=8'hF3; t_id=BID_FX3;  t_lsb=4'd0; t_wid=4'd4; t_max=8'd8;   end
                    default: begin t_addr=8'hF4; t_id=BID_VOL;  t_lsb=4'd0; t_wid=4'd8; t_max=8'd255; end
                endcase
            end
            3'd3: begin
                t_valid = 1'b1;
                case (q0_page[1:0])
                    2'd0:    begin t_addr=8'hF0; t_id=BID_FX0; t_lsb=4'd0; t_wid=4'd1; t_max=8'd1;   end
                    2'd1:    begin t_addr=8'hF0; t_id=BID_FX0; t_lsb=4'd4; t_wid=4'd4; t_max=8'd15;  end
                    2'd2:    begin t_addr=8'hF1; t_id=BID_FX1; t_lsb=4'd3; t_wid=4'd1; t_max=8'd1;   end
                    default: begin t_addr=8'hF2; t_id=BID_FX2; t_lsb=4'd0; t_wid=4'd8; t_max=8'd255; end
                endcase
            end
            3'd4: begin
                t_valid = 1'b1;
                case (q0_page[1:0])
                    2'd0:    begin t_addr=8'hF1; t_id=BID_FX1; t_lsb=4'd0; t_wid=4'd3; t_max=8'd7;  end
                    2'd1:    begin t_addr=8'hF0; t_id=BID_FX0; t_lsb=4'd4; t_wid=4'd4; t_max=8'd15; end
                    2'd2:    begin t_addr=8'hF0; t_id=BID_FX0; t_lsb=4'd1; t_wid=4'd3; t_max=8'd7;  end
                    default: begin t_addr=8'hF1; t_id=BID_FX1; t_lsb=4'd3; t_wid=4'd1; t_max=8'd1;  end
                endcase
            end
            3'd5: begin
                case (q0_page[1:0])
                    2'd0:    begin t_valid=1'b1; t_addr=8'hF3; t_id=BID_FX3; t_lsb=4'd0; t_wid=4'd4; t_max=8'd8;   end
                    2'd1:    begin t_valid=1'b1; t_addr=8'hF4; t_id=BID_VOL; t_lsb=4'd0; t_wid=4'd8; t_max=8'd255; end
                    2'd2:    begin t_valid=1'b1; t_addr=8'hF5; t_id=BID_4PT; t_lsb=4'd0; t_wid=4'd1; t_max=8'd1;   end
                    default: ;
                endcase
            end
            default: ;
        endcase

        case (t_id)
            BID_MULT + 5'd0: t_byte = by_20;
            BID_MULT + 5'd1: t_byte = by_21;
            BID_MULT + 5'd2: t_byte = by_22;
            BID_MULT + 5'd3: t_byte = by_23;
            BID_TL   + 5'd0: t_byte = by_40;
            BID_TL   + 5'd1: t_byte = by_41;
            BID_TL   + 5'd2: t_byte = by_42;
            BID_TL   + 5'd3: t_byte = by_43;
            BID_AD   + 5'd0: t_byte = by_60;
            BID_AD   + 5'd1: t_byte = by_61;
            BID_AD   + 5'd2: t_byte = by_62;
            BID_AD   + 5'd3: t_byte = by_63;
            BID_SR   + 5'd0: t_byte = by_80;
            BID_SR   + 5'd1: t_byte = by_81;
            BID_SR   + 5'd2: t_byte = by_82;
            BID_SR   + 5'd3: t_byte = by_83;
            BID_WF   + 5'd0: t_byte = by_E0;
            BID_WF   + 5'd1: t_byte = by_E1;
            BID_WF   + 5'd2: t_byte = by_E2;
            BID_WF   + 5'd3: t_byte = by_E3;
            BID_ALGO:        t_byte = by_C0;
            BID_FX0:         t_byte = by_F0;
            BID_FX1:         t_byte = by_F1;
            BID_FX2:         t_byte = by_F2;
            BID_FX3:         t_byte = by_F3;
            BID_VOL:         t_byte = by_F4;
            BID_4PT:         t_byte = by_F5;
            default:         t_byte = {MW{1'b0}};
        endcase
        t_mask = (t_wid == 4'd8) ? 8'hFF : ((8'd1 << t_wid) - 8'd1);
        t_cur  = (t_byte >> t_lsb) & t_mask;

        if (t_wid == 4'd1) begin
            t_nv = {7'd0, ~t_cur[0]};
        end
        else if ((t_wid == 4'd8) && (t_addr == 8'hF2)) begin
            if (q0_dir) t_nv = (t_cur > 8'd251) ? 8'hFF : (t_cur + 8'd4);
            else        t_nv = (t_cur < 8'd4)   ? 8'h00 : (t_cur - 8'd4);
        end
        else begin
            if (q0_dir) t_nv = (t_cur >= t_max) ? t_max : (t_cur + 8'd1);
            else        t_nv = (t_cur == 8'd0)  ? 8'h00 : (t_cur - 8'd1);
        end

        t_newbyte = (t_byte & ~(t_mask << t_lsb)) | ((t_nv & t_mask) << t_lsb);
    end

    always @(*) begin
        busy     = (q_cnt != 2'd0);
        pe_we    = (q_cnt != 2'd0) && t_valid && pe_gnt;
        pe_addr  = t_addr;
        pe_wdata = t_newbyte;
    end

    wire       q_pop = (q_cnt != 2'd0) && (t_valid ? pe_gnt : 1'b1);
    wire [1:0] q_eff = q_cnt - {1'b0, q_pop};
    wire       q_acc = req_pulse && (q_eff < 2'd2);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_cnt   <= 2'd0;
            q0_page <= 4'd0; q0_op <= 2'd0; q0_dir <= 1'b0;
            q1_page <= 4'd0; q1_op <= 2'd0; q1_dir <= 1'b0;
            dbg_val <= 4'd0;
        end
        else begin
            if (q_pop) begin
                q0_page <= q1_page;
                q0_op   <= q1_op;
                q0_dir  <= q1_dir;
            end
            if (q_acc) begin
                if (q_eff == 2'd0) begin
                    q0_page <= req_page;
                    q0_op   <= req_op;
                    q0_dir  <= req_dir;
                end
                else begin
                    q1_page <= req_page;
                    q1_op   <= req_op;
                    q1_dir  <= req_dir;
                end
            end
            q_cnt <= q_cnt + {1'b0, q_acc} - {1'b0, q_pop};
            if (pe_we) dbg_val <= t_nv[3:0];
        end
    end

`ifdef SIMULATION
    reg pe_bad_seen;
    initial pe_bad_seen = 1'b0;
    always @(posedge clk) begin
        if (rst_n && q_pop && !t_valid && !pe_bad_seen) begin
            pe_bad_seen <= 1'b1;
            $display("*** WARN param_edit: req_page=%0d has no field (PAGE 6/7 undefined) -- request consumed, no write", q0_page);
        end
    end
`endif

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            by_20 <= {MW{1'b0}}; by_21 <= {MW{1'b0}}; by_22 <= {MW{1'b0}}; by_23 <= {MW{1'b0}};
            by_40 <= {MW{1'b0}}; by_41 <= {MW{1'b0}}; by_42 <= {MW{1'b0}}; by_43 <= {MW{1'b0}};
            by_60 <= {MW{1'b0}}; by_61 <= {MW{1'b0}}; by_62 <= {MW{1'b0}}; by_63 <= {MW{1'b0}};
            by_80 <= {MW{1'b0}}; by_81 <= {MW{1'b0}}; by_82 <= {MW{1'b0}}; by_83 <= {MW{1'b0}};
            by_E0 <= {MW{1'b0}}; by_E1 <= {MW{1'b0}}; by_E2 <= {MW{1'b0}}; by_E3 <= {MW{1'b0}};
            by_C0 <= {MW{1'b0}};
            by_F0 <= 8'h87;
            by_F1 <= 8'hDA;
            by_F2 <= 8'h00;
            by_F3 <= 8'd0;
            by_F4 <= 8'd255;
            by_F5 <= 8'd0;

            bb_20 <= {MW{1'b0}}; bb_21 <= {MW{1'b0}}; bb_22 <= {MW{1'b0}}; bb_23 <= {MW{1'b0}};
            bb_40 <= {MW{1'b0}}; bb_41 <= {MW{1'b0}}; bb_42 <= {MW{1'b0}}; bb_43 <= {MW{1'b0}};
            bb_60 <= {MW{1'b0}}; bb_61 <= {MW{1'b0}}; bb_62 <= {MW{1'b0}}; bb_63 <= {MW{1'b0}};
            bb_80 <= {MW{1'b0}}; bb_81 <= {MW{1'b0}}; bb_82 <= {MW{1'b0}}; bb_83 <= {MW{1'b0}};
            bb_E0 <= {MW{1'b0}}; bb_E1 <= {MW{1'b0}}; bb_E2 <= {MW{1'b0}}; bb_E3 <= {MW{1'b0}};
            bb_C0 <= {MW{1'b0}};
            bb_F0 <= 8'h87;
            bb_F1 <= 8'hDA;
            bb_F2 <= 8'h00;
            bb_F4 <= 8'd255;
            bb_F5 <= 8'd0;
        end
        else begin
            if (bus_we) begin
                case (bus_addr)
                    8'h20: by_20 <= bus_wdata;
                    8'h21: by_21 <= bus_wdata;
                    8'h22: by_22 <= bus_wdata;
                    8'h23: by_23 <= bus_wdata;

                    8'h40: by_40 <= bus_wdata;
                    8'h41: by_41 <= bus_wdata;
                    8'h42: by_42 <= bus_wdata;
                    8'h43: by_43 <= bus_wdata;

                    8'h60: by_60 <= bus_wdata;
                    8'h61: by_61 <= bus_wdata;
                    8'h62: by_62 <= bus_wdata;
                    8'h63: by_63 <= bus_wdata;

                    8'h80: by_80 <= bus_wdata;
                    8'h81: by_81 <= bus_wdata;
                    8'h82: by_82 <= bus_wdata;
                    8'h83: by_83 <= bus_wdata;

                    8'hE0: by_E0 <= bus_wdata;
                    8'hE1: by_E1 <= bus_wdata;
                    8'hE2: by_E2 <= bus_wdata;
                    8'hE3: by_E3 <= bus_wdata;

                    8'hC0: by_C0 <= bus_wdata;

                    8'hF0: by_F0 <= bus_wdata;
                    8'hF1: by_F1 <= bus_wdata;
                    8'hF2: by_F2 <= bus_wdata;
                    8'hF3: by_F3 <= bus_wdata;
                    8'hF4: by_F4 <= bus_wdata;
                    8'hF5: by_F5 <= bus_wdata;

                    default: ;
                endcase
            end

            if (base_snap) begin
                bb_20 <= by_20; bb_21 <= by_21; bb_22 <= by_22; bb_23 <= by_23;
                bb_40 <= by_40; bb_41 <= by_41; bb_42 <= by_42; bb_43 <= by_43;
                bb_60 <= by_60; bb_61 <= by_61; bb_62 <= by_62; bb_63 <= by_63;
                bb_80 <= by_80; bb_81 <= by_81; bb_82 <= by_82; bb_83 <= by_83;
                bb_E0 <= by_E0; bb_E1 <= by_E1; bb_E2 <= by_E2; bb_E3 <= by_E3;
                bb_C0 <= by_C0;
                bb_F0 <= by_F0;
                bb_F1 <= by_F1;
                bb_F2 <= by_F2;
                bb_F4 <= by_F4;
                bb_F5 <= by_F5;
            end

            if (pe_we) begin
                case (t_id)
                    BID_MULT + 5'd0: by_20 <= t_newbyte;
                    BID_MULT + 5'd1: by_21 <= t_newbyte;
                    BID_MULT + 5'd2: by_22 <= t_newbyte;
                    BID_MULT + 5'd3: by_23 <= t_newbyte;
                    BID_TL   + 5'd0: by_40 <= t_newbyte;
                    BID_TL   + 5'd1: by_41 <= t_newbyte;
                    BID_TL   + 5'd2: by_42 <= t_newbyte;
                    BID_TL   + 5'd3: by_43 <= t_newbyte;
                    BID_AD   + 5'd0: by_60 <= t_newbyte;
                    BID_AD   + 5'd1: by_61 <= t_newbyte;
                    BID_AD   + 5'd2: by_62 <= t_newbyte;
                    BID_AD   + 5'd3: by_63 <= t_newbyte;
                    BID_SR   + 5'd0: by_80 <= t_newbyte;
                    BID_SR   + 5'd1: by_81 <= t_newbyte;
                    BID_SR   + 5'd2: by_82 <= t_newbyte;
                    BID_SR   + 5'd3: by_83 <= t_newbyte;
                    BID_WF   + 5'd0: by_E0 <= t_newbyte;
                    BID_WF   + 5'd1: by_E1 <= t_newbyte;
                    BID_WF   + 5'd2: by_E2 <= t_newbyte;
                    BID_WF   + 5'd3: by_E3 <= t_newbyte;
                    BID_ALGO:        by_C0 <= t_newbyte;
                    BID_FX0:         by_F0 <= t_newbyte;
                    BID_FX1:         by_F1 <= t_newbyte;
                    BID_FX2:         by_F2 <= t_newbyte;
                    BID_FX3:         by_F3 <= t_newbyte;
                    BID_VOL:         by_F4 <= t_newbyte;
                    BID_4PT:         by_F5 <= t_newbyte;
                    default: ;
                endcase
            end
        end
    end

    wire _unused = &{1'b0, sh_algo, sh_fb, sh_room, sh_fx_en, sh_damp, sh_wet,
                     sh_spread, sh_width, sh_predelay, sh_mult, sh_tl, sh_ar,
                     sh_dr, sh_sl, sh_rr, sh_wf,
                     base_algo, base_fb, base_room, base_fx_en, base_damp,
                     base_wet, base_spread, base_width, base_predelay,
                     base_mult, base_tl, base_ar, base_dr, base_sl, base_rr,
                     base_wf, q1_page, q1_op, q1_dir, 1'b0};

endmodule
