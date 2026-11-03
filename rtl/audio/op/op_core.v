// op_core —— 单个 OPL3 算子的运算核：相位生成 + 包络 EG + 8 波形

module op_core (
    input  wire [9:0]         fnum,
    input  wire [2:0]         block,
    input  wire               nts,
    input  wire [3:0]         mult,
    input  wire [2:0]         wf,
    input  wire               vib,
    input  wire [5:0]         tl,
    input  wire [3:0]         ar, dr, rr,
    input  wire [4:0]         sl,
    input  wire [1:0]         ksl,
    input  wire               ksr,
    input  wire               reg_type,
    input  wire [7:0]         eg_ksl,
    input  wire [4:0]         ksv,
    input  wire [7:0]         trem,
    input  wire [2:0]         vibpos,
    input  wire               vibshift,
    input  wire               eg_state,
    input  wire [1:0]         eg_timer_lo,
    input  wire [3:0]         eg_add,
    input  wire [23:0]        pg_phase,
    input  wire [8:0]         eg_rout,
    input  wire [1:0]         eg_gen,
    input  wire               key,
    input  wire signed [15:0] mod_in,
    output wire [9:0]         phase_out,
    output wire signed [15:0] op_out,
    output wire [11:0]        eg_out,
    output wire               pg_reset,
    output wire [23:0]        pg_phase_next,
    output wire [8:0]         eg_rout_next,
    output wire [1:0]         eg_gen_next
);

    `include "eg_incstep_tab.vh"

    localparam [1:0] EG_ATTACK  = 2'd0,
                     EG_DECAY   = 2'd1,
                     EG_SUSTAIN = 2'd2,
                     EG_RELEASE = 2'd3;


    wire [2:0] vib_range_raw = fnum[9:7];
    wire [2:0] vib_range_hal = vib_range_raw >> 1;
    wire [2:0] vib_range_a = (!(vibpos & 3'd3)) ? 3'd0
                           : ((vibpos & 3'd1) ? vib_range_hal : vib_range_raw);
    wire [2:0] vib_range_b = vibshift ? (vib_range_a >> 1) : vib_range_a;

    wire [15:0] vib_off = (vibpos & 3'd4)
                        ? ((({13'd0, vib_range_b}) ^ 16'hffff) + 16'd1)
                        :   {13'd0, vib_range_b};

    wire [15:0] fnum_eff = {6'd0, fnum} + (vib ? vib_off : 16'd0);

    wire [23:0] basefreq = ({8'd0, fnum_eff} << block) >> 1;

    wire [7:0] mt_val  = mt_lut(mult);
    wire [4:0] mt_bits = mt_val[4:0];
    wire [27:0] step_sum = basefreq * mt_val;
    wire [23:0] step = step_sum[24:1];

    assign phase_out     = pg_phase[18:9];
    assign pg_phase_next = pg_reset ? step : (pg_phase + step);

    wire [9:0] wave_phase = phase_out + mod_in[9:0];


    wire [11:0] eg_out_sum = {3'd0, eg_rout}
                           + {6'd0, tl, 2'b00}
                           + {4'd0, (eg_ksl >> kslshift_lut(ksl))}
                           + {4'd0, trem};
    assign eg_out = eg_out_sum;

    wire       reset    = key && (eg_gen == EG_RELEASE);
    wire [3:0] reg_rate = reset                  ? ar :
                          (eg_gen == EG_ATTACK)  ? ar :
                          (eg_gen == EG_DECAY)   ? dr :
                          (eg_gen == EG_SUSTAIN) ? (reg_type ? 4'd0 : rr) :
                                                   rr;
    assign pg_reset = reset;

    wire [4:0] ks        = ksv >> ({3'd0, (ksr ^ 1'b1), 1'b0});
    wire       nonzero   = (reg_rate != 4'd0);
    wire [7:0] rate      = {3'd0, ks} + {2'd0, reg_rate, 2'b00};
    wire [7:0] rate_hi_r = rate >> 2;
    wire [1:0] rate_lo   = rate[1:0];
    wire [3:0] rate_hi   = rate_hi_r[4] ? 4'hf : rate_hi_r[3:0];
    wire [4:0] eg_shift  = {1'b0, rate_hi} + {1'b0, eg_add};

    reg [2:0] shift;
    always @(*) begin
        shift = 3'd0;
        if (nonzero) begin
            if (rate_hi < 4'd12) begin
                if (eg_state) begin
                    case (eg_shift)
                        5'd12:   shift = 3'd1;
                        5'd13:   shift = {2'd0, rate_lo[1]};
                        5'd14:   shift = {2'd0, rate_lo[0]};
                        default: shift = 3'd0;
                    endcase
                end
            end
            else begin
                shift = {1'b0, rate_hi[1:0]} + eg_incstep_lut(rate_lo, eg_timer_lo);
                if (shift[2])           shift = 3'd3;
                else if (shift == 3'd0) shift = {2'd0, eg_state};
            end
        end
    end

    wire [3:0] att_k  = 4'd4 - {1'b0, shift};
    wire [9:0] att_2k = (att_k == 4'd3) ? 10'd8 :
                        ((att_k == 4'd2) ? 10'd4 : 10'd2);
    wire [9:0] att_dec_c = ({1'b0, eg_rout} + att_2k) >> att_k;

    reg [8:0]  eg_rout_v;
    reg [8:0]  eg_inc;
    reg [8:0]  eg_att_dec;
    reg        eg_att_en;
    reg        eg_off;
    reg [1:0]  eg_gen_calc;
    always @(*) begin
        eg_rout_v   = eg_rout;
        eg_inc      = 9'd0;
        eg_att_dec  = 9'd0;
        eg_att_en   = 1'b0;
        eg_off      = 1'b0;
        eg_gen_calc = eg_gen;

        if (reset && (rate_hi == 4'hf))
            eg_rout_v = 9'h000;
        if ((eg_rout & 9'h1f8) == 9'h1f8)
            eg_off = 1'b1;
        if ((eg_gen != EG_ATTACK) && !reset && eg_off)
            eg_rout_v = 9'h1ff;

        case (eg_gen)
            EG_ATTACK: begin
                if (eg_rout == 9'h000)
                    eg_gen_calc = EG_DECAY;
                else begin
                    eg_gen_calc = EG_ATTACK;
                    if (key && (shift > 3'd0) && (rate_hi != 4'hf)) begin
                        eg_att_en  = 1'b1;
                        eg_att_dec = att_dec_c[8:0];
                    end
                end
            end

            EG_DECAY: begin
                if ((eg_rout >> 4) == sl)
                    eg_gen_calc = EG_SUSTAIN;
                else begin
                    eg_gen_calc = EG_DECAY;
                    if (!eg_off && !reset && (shift > 3'd0))
                        eg_inc = 9'd1 << (shift - 3'd1);
                end
            end

            default: begin
                eg_gen_calc = eg_gen;
                if (!eg_off && !reset && (shift > 3'd0))
                    eg_inc = 9'd1 << (shift - 3'd1);
            end
        endcase

        if (reset)  eg_gen_calc = EG_ATTACK;
        if (!key)   eg_gen_calc = EG_RELEASE;
    end

    assign eg_rout_next = (eg_att_en ? (eg_rout_v - eg_att_dec)
                                     : (eg_rout_v + eg_inc)) & 9'h1ff;
    assign eg_gen_next  = eg_gen_calc;

    wave_gen u_wave_gen (
        .wf      (wf),
        .phase   (wave_phase),
        .eg_out  (eg_out),
        .op_out  (op_out)
    );

endmodule
