// chip_eg_timer —— 芯片级 EG 定时器（位扫描）—— 全芯片一份，广播给所有算子

module chip_eg_timer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    output reg         eg_state,
    output reg  [1:0]  eg_timer_lo,
    output reg  [3:0]  eg_add
);

    localparam [35:0] EG_TIMER_MAX = 36'hF_FFFF_FFFF;

    reg [35:0] eg_timer;
    reg        eg_timerrem;

    reg [4:0] scan_shift;
    integer k;
    always @(*) begin
        scan_shift = 5'd13;
        for (k = 12; k >= 0; k = k - 1)
            if (eg_timer[k]) scan_shift = k;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            eg_state     <= 1'b0;
            eg_timer_lo  <= 2'd0;
            eg_add       <= 4'd0;
            eg_timer     <= 36'd0;
            eg_timerrem  <= 1'b0;
        end
        else if (sample_tick) begin
            if (eg_state) begin
                eg_add      <= (scan_shift > 5'd12) ? 4'd0 : (scan_shift[3:0] + 4'd1);
                eg_timer_lo <= eg_timer[1:0];
            end

            if (eg_timerrem || eg_state) begin
                if (eg_timer == EG_TIMER_MAX) begin
                    eg_timer    <= 36'd0;
                    eg_timerrem <= 1'b1;
                end
                else begin
                    eg_timer    <= eg_timer + 36'd1;
                    eg_timerrem <= 1'b0;
                end
            end

            eg_state <= ~eg_state;
        end
    end

endmodule
