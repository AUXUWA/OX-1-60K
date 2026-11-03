// chip_lfo —— 芯片级 LFO —— tremolo（颤音/幅度）+ vibrato（颤音/音高相位）

module chip_lfo (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    input  wire [2:0]  tremolo_shift,
    input  wire        vibshift,
    output reg  [7:0]  trem,
    output reg  [2:0]  vibpos
);

    reg [9:0] timer;
    reg [7:0] tremolopos;

    wire trem_step = ((timer & 10'h03f) == 10'h03f);

    wire [7:0] tremolopos_nxt = trem_step
                              ? ((tremolopos == 8'd209) ? 8'd0 : (tremolopos + 8'd1))
                              : tremolopos;

    wire [7:0] trem_nxt = (tremolopos_nxt < 8'd105)
                        ? (tremolopos_nxt >> tremolo_shift)
                        : ((8'd210 - tremolopos_nxt) >> tremolo_shift);

    wire vib_step = ((timer & 10'h3ff) == 10'h3ff);

    wire [2:0] vibpos_nxt = vib_step ? ((vibpos + 3'd1) & 3'd7) : vibpos;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer      <= 10'd0;
            tremolopos <= 8'd0;
            trem       <= 8'd0;
            vibpos     <= 3'd0;
        end
        else if (sample_tick) begin
            tremolopos <= tremolopos_nxt;
            trem       <= trem_nxt;
            vibpos     <= vibpos_nxt;
            timer      <= timer + 10'd1;
        end
    end

endmodule
