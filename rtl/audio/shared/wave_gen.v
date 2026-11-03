// wave_gen —— OPL3 的 8 种波形

module wave_gen (
    input  wire [2:0]         wf,
    input  wire [9:0]         phase,
    input  wire [11:0]        eg_out,
    output wire signed [15:0] op_out
);

    wire [9:0] ph     = phase & 10'h3ff;
    wire [7:0] ph_lo  = ph[7:0];
    wire [7:0] ph_inv = ph_lo ^ 8'hff;

    reg  [7:0]  logsin_addr;
    wire [15:0] logsin_data;

    logsin_rom u_logsin_rom (
        .addr (logsin_addr),
        .data (logsin_data)
    );

    reg  [12:0] log_part;
    reg         neg;
    always @(*) begin
        neg         = 1'b0;
        log_part    = 13'd0;
        logsin_addr = 8'd0;
        case (wf)
            3'd0: begin
                neg         = ph[9];
                logsin_addr = ph[8] ? ph_inv : ph_lo;
                log_part    = logsin_data[12:0];
            end

            3'd1: begin
                logsin_addr = ph[8] ? ph_inv : ph_lo;
                log_part    = ph[9] ? 13'h1000 : logsin_data[12:0];
            end

            3'd2: begin
                logsin_addr = ph[8] ? ph_inv : ph_lo;
                log_part    = logsin_data[12:0];
            end

            3'd3: begin
                logsin_addr = ph_lo;
                log_part    = ph[8] ? 13'h1000 : logsin_data[12:0];
            end

            3'd4: begin
                neg         = (ph[9:8] == 2'b01);
                logsin_addr = ph[7] ? (ph_inv << 1) : (ph_lo << 1);
                log_part    = ph[9] ? 13'h1000 : logsin_data[12:0];
            end

            3'd5: begin
                logsin_addr = ph[7] ? (ph_inv << 1) : (ph_lo << 1);
                log_part    = ph[9] ? 13'h1000 : logsin_data[12:0];
            end

            3'd6: begin
                neg      = ph[9];
                log_part = 13'd0;
            end

            3'd7: begin
                neg      = ph[9];
                log_part = {1'b0, (ph[9] ? (ph[8:0] ^ 9'h1ff) : ph[8:0]), 3'b000};
            end

            default: begin
                log_part = 13'd0;
            end
        endcase
    end

    wire [16:0] level_raw = {4'd0, log_part} + {2'd0, eg_out, 3'b000};
    wire [12:0] level     = (level_raw > 17'h1fff) ? 13'h1fff : level_raw[12:0];

    wire [15:0] exp_data;
    exp_rom u_exp_rom (
        .addr (level[7:0]),
        .data (exp_data)
    );

    wire [15:0] exp_shifted = (exp_data << 1) >> level[12:8];
    wire [15:0] mag         = {3'd0, exp_shifted[12:0]};

    assign op_out = neg ? -$signed(mag) : $signed(mag);

endmodule
