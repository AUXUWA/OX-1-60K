// ws2812_guide

`default_nettype none

module ws2812_guide #(
    parameter integer N_KEY = 25
) (
    input  wire [N_KEY-1:0] kb_pressed,
    input  wire [N_KEY-1:0] guide_hit,
    input  wire [N_KEY-1:0] guide_hold,
    input  wire [N_KEY-1:0] guide_breath,
    input  wire [N_KEY-1:0] guide_far,
    output wire [N_KEY*3-1:0] lvl_bus
);

    wire [N_KEY-1:0] g_all = guide_hit | guide_hold | guide_breath | guide_far;

    genvar gi;
    generate
        for (gi = 0; gi < N_KEY; gi = gi + 1) begin : g_key
            wire user_match = g_all[gi] & kb_pressed[gi];
            assign lvl_bus[gi*3 +: 3] =
                  user_match       ? 3'd6 :
                  guide_hit[gi]    ? 3'd5 :
                  guide_hold[gi]   ? 3'd4 :
                  guide_breath[gi] ? 3'd3 :
                  guide_far[gi]    ? 3'd2 :
                  kb_pressed[gi]  ? 3'd1 : 3'd0;
        end
    endgenerate

endmodule

`default_nettype wire
