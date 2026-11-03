// patch_bank

`timescale 1ns/1ps

module patch_bank (
    input  wire [2:0] patch,
    input  wire [4:0] idx,
    output wire [15:0] patch_word
);

    localparam integer PATCHES = 8;
    localparam integer SEQ_LEN  = 27;

    function [15:0] rom_word;
        input [2:0] p;
        input [4:0] i;
        begin
            case (i)
                5'd0: case (p)
                          3'd0: rom_word = {8'h01, 8'h00};
                          3'd1: rom_word = {8'h01, 8'h00};
                          3'd2: rom_word = {8'h01, 8'h00};
                          3'd3: rom_word = {8'h01, 8'h00};
                          3'd4: rom_word = {8'h01, 8'h00};
                          3'd5: rom_word = {8'h01, 8'h00};
                          3'd6: rom_word = {8'h01, 8'h00};
                          3'd7: rom_word = {8'h01, 8'h00};
                          default: rom_word = {8'h01, 8'h00};
                      endcase

                5'd1: case (p)
                          3'd0: rom_word = {8'h20, 8'hA7};
                          3'd1: rom_word = {8'h20, 8'h8E};
                          3'd2: rom_word = {8'h20, 8'hA1};
                          3'd3: rom_word = {8'h20, 8'hA1};
                          3'd4: rom_word = {8'h20, 8'hE1};
                          3'd5: rom_word = {8'h20, 8'hA1};
                          3'd6: rom_word = {8'h20, 8'hA1};
                          3'd7: rom_word = {8'h20, 8'h84};
                          default: rom_word = {8'h20, 8'h87};
                      endcase

                5'd2: case (p)
                          3'd0: rom_word = {8'h21, 8'hA1};
                          3'd1: rom_word = {8'h21, 8'hA1};
                          3'd2: rom_word = {8'h21, 8'h81};
                          3'd3: rom_word = {8'h21, 8'h81};
                          3'd4: rom_word = {8'h21, 8'h62};
                          3'd5: rom_word = {8'h21, 8'hA2};
                          3'd6: rom_word = {8'h21, 8'hA2};
                          3'd7: rom_word = {8'h21, 8'hA1};
                          default: rom_word = {8'h21, 8'hA1};
                      endcase

                5'd3: case (p)
                          3'd0: rom_word = {8'h22, 8'hA2};
                          3'd1: rom_word = {8'h22, 8'hA1};
                          3'd2: rom_word = {8'h22, 8'hA3};
                          3'd3: rom_word = {8'h22, 8'hA4};
                          3'd4: rom_word = {8'h22, 8'hA3};
                          3'd5: rom_word = {8'h22, 8'hA1};
                          3'd6: rom_word = {8'h22, 8'hA3};
                          3'd7: rom_word = {8'h22, 8'hA7};
                          default: rom_word = {8'h22, 8'hA6};
                      endcase

                5'd4: case (p)
                          3'd0: rom_word = {8'h23, 8'h81};
                          3'd1: rom_word = {8'h23, 8'h86};
                          3'd2: rom_word = {8'h23, 8'h81};
                          3'd3: rom_word = {8'h23, 8'h81};
                          3'd4: rom_word = {8'h23, 8'h24};
                          3'd5: rom_word = {8'h23, 8'hA2};
                          3'd6: rom_word = {8'h23, 8'hE1};
                          3'd7: rom_word = {8'h23, 8'h8E};
                          default: rom_word = {8'h23, 8'h81};
                      endcase

                5'd5: case (p)
                          3'd0: rom_word = {8'h40, 8'h10};
                          3'd1: rom_word = {8'h40, 8'h0E};
                          3'd2: rom_word = {8'h40, 8'h12};
                          3'd3: rom_word = {8'h40, 8'h0C};
                          3'd4: rom_word = {8'h40, 8'h08};
                          3'd5: rom_word = {8'h40, 8'h1A};
                          3'd6: rom_word = {8'h40, 8'h20};
                          3'd7: rom_word = {8'h40, 8'h0F};
                          default: rom_word = {8'h40, 8'h9B};
                      endcase

                5'd6: case (p)
                          3'd0: rom_word = {8'h41, 8'h14};
                          3'd1: rom_word = {8'h41, 8'h14};
                          3'd2: rom_word = {8'h41, 8'h06};
                          3'd3: rom_word = {8'h41, 8'h12};
                          3'd4: rom_word = {8'h41, 8'h10};
                          3'd5: rom_word = {8'h41, 8'h16};
                          3'd6: rom_word = {8'h41, 8'h1A};
                          3'd7: rom_word = {8'h41, 8'h0D};
                          default: rom_word = {8'h41, 8'h0D};
                      endcase

                5'd7: case (p)
                          3'd0: rom_word = {8'h42, 8'h16};
                          3'd1: rom_word = {8'h42, 8'h0C};
                          3'd2: rom_word = {8'h42, 8'h0E};
                          3'd3: rom_word = {8'h42, 8'h0C};
                          3'd4: rom_word = {8'h42, 8'h16};
                          3'd5: rom_word = {8'h42, 8'h08};
                          3'd6: rom_word = {8'h42, 8'h1E};
                          3'd7: rom_word = {8'h42, 8'h1E};
                          default: rom_word = {8'h42, 8'h93};
                      endcase

                5'd8: case (p)
                          3'd0: rom_word = {8'h43, 8'h08};
                          3'd1: rom_word = {8'h43, 8'h14};
                          3'd2: rom_word = {8'h43, 8'h0E};
                          3'd3: rom_word = {8'h43, 8'h06};
                          3'd4: rom_word = {8'h43, 8'h1C};
                          3'd5: rom_word = {8'h43, 8'h12};
                          3'd6: rom_word = {8'h43, 8'h02};
                          3'd7: rom_word = {8'h43, 8'h14};
                          default: rom_word = {8'h43, 8'h08};
                      endcase

                5'd9: case (p)
                          3'd0: rom_word = {8'h60, 8'hFC};
                          3'd1: rom_word = {8'h60, 8'hFA};
                          3'd2: rom_word = {8'h60, 8'hFB};
                          3'd3: rom_word = {8'h60, 8'hFB};
                          3'd4: rom_word = {8'h60, 8'h55};
                          3'd5: rom_word = {8'h60, 8'hB9};
                          3'd6: rom_word = {8'h60, 8'h5A};
                          3'd7: rom_word = {8'h60, 8'hF2};
                          default: rom_word = {8'h60, 8'hFF};
                      endcase

                5'd10: case (p)
                          3'd0: rom_word = {8'h61, 8'hF9};
                          3'd1: rom_word = {8'h61, 8'hD8};
                          3'd2: rom_word = {8'h61, 8'hF8};
                          3'd3: rom_word = {8'h61, 8'hF8};
                          3'd4: rom_word = {8'h61, 8'h55};
                          3'd5: rom_word = {8'h61, 8'hB9};
                          3'd6: rom_word = {8'h61, 8'h49};
                          3'd7: rom_word = {8'h61, 8'hE6};
                          default: rom_word = {8'h61, 8'hF9};
                      endcase

                5'd11: case (p)
                          3'd0: rom_word = {8'h62, 8'hFA};
                          3'd1: rom_word = {8'h62, 8'hF5};
                          3'd2: rom_word = {8'h62, 8'hFD};
                          3'd3: rom_word = {8'h62, 8'hFA};
                          3'd4: rom_word = {8'h62, 8'h65};
                          3'd5: rom_word = {8'h62, 8'h99};
                          3'd6: rom_word = {8'h62, 8'h69};
                          3'd7: rom_word = {8'h62, 8'hF9};
                          default: rom_word = {8'h62, 8'hFD};
                      endcase

                5'd12: case (p)
                          3'd0: rom_word = {8'h63, 8'hF6};
                          3'd1: rom_word = {8'h63, 8'hF9};
                          3'd2: rom_word = {8'h63, 8'hFA};
                          3'd3: rom_word = {8'h63, 8'hF6};
                          3'd4: rom_word = {8'h63, 8'h65};
                          3'd5: rom_word = {8'h63, 8'h99};
                          3'd6: rom_word = {8'h63, 8'h54};
                          3'd7: rom_word = {8'h63, 8'hF3};
                          default: rom_word = {8'h63, 8'hF5};
                      endcase

                5'd13: case (p)
                          3'd0: rom_word = {8'h80, 8'h69};
                          3'd1: rom_word = {8'h80, 8'h87};
                          3'd2: rom_word = {8'h80, 8'h68};
                          3'd3: rom_word = {8'h80, 8'hA8};
                          3'd4: rom_word = {8'h80, 8'h25};
                          3'd5: rom_word = {8'h80, 8'h68};
                          3'd6: rom_word = {8'h80, 8'h77};
                          3'd7: rom_word = {8'h80, 8'hE6};
                          default: rom_word = {8'h80, 8'h1A};
                      endcase

                5'd14: case (p)
                          3'd0: rom_word = {8'h81, 8'h48};
                          3'd1: rom_word = {8'h81, 8'h57};
                          3'd2: rom_word = {8'h81, 8'h45};
                          3'd3: rom_word = {8'h81, 8'hA8};
                          3'd4: rom_word = {8'h81, 8'h25};
                          3'd5: rom_word = {8'h81, 8'h68};
                          3'd6: rom_word = {8'h81, 8'h67};
                          3'd7: rom_word = {8'h81, 8'h59};
                          default: rom_word = {8'h81, 8'h3E};
                      endcase

                5'd15: case (p)
                          3'd0: rom_word = {8'h82, 8'h68};
                          3'd1: rom_word = {8'h82, 8'h36};
                          3'd2: rom_word = {8'h82, 8'h8A};
                          3'd3: rom_word = {8'h82, 8'hCC};
                          3'd4: rom_word = {8'h82, 8'h25};
                          3'd5: rom_word = {8'h82, 8'h58};
                          3'd6: rom_word = {8'h82, 8'h77};
                          3'd7: rom_word = {8'h82, 8'h49};
                          default: rom_word = {8'h82, 8'h5B};
                      endcase

                5'd16: case (p)
                          3'd0: rom_word = {8'h83, 8'h45};
                          3'd1: rom_word = {8'h83, 8'h67};
                          3'd2: rom_word = {8'h83, 8'hD6};
                          3'd3: rom_word = {8'h83, 8'hD7};
                          3'd4: rom_word = {8'h83, 8'h25};
                          3'd5: rom_word = {8'h83, 8'h58};
                          3'd6: rom_word = {8'h83, 8'h26};
                          3'd7: rom_word = {8'h83, 8'hE7};
                          default: rom_word = {8'h83, 8'hF8};
                      endcase

                5'd17: case (p)
                          3'd0: rom_word = {8'hE0, 8'h00};
                          3'd1: rom_word = {8'hE0, 8'h00};
                          3'd2: rom_word = {8'hE0, 8'h00};
                          3'd3: rom_word = {8'hE0, 8'h00};
                          3'd4: rom_word = {8'hE0, 8'h00};
                          3'd5: rom_word = {8'hE0, 8'h00};
                          3'd6: rom_word = {8'hE0, 8'h00};
                          3'd7: rom_word = {8'hE0, 8'h00};
                          default: rom_word = {8'hE0, 8'h00};
                      endcase

                5'd18: case (p)
                          3'd0: rom_word = {8'hE1, 8'h00};
                          3'd1: rom_word = {8'hE1, 8'h00};
                          3'd2: rom_word = {8'hE1, 8'h00};
                          3'd3: rom_word = {8'hE1, 8'h00};
                          3'd4: rom_word = {8'hE1, 8'h00};
                          3'd5: rom_word = {8'hE1, 8'h00};
                          3'd6: rom_word = {8'hE1, 8'h00};
                          3'd7: rom_word = {8'hE1, 8'h00};
                          default: rom_word = {8'hE1, 8'h00};
                      endcase

                5'd19: case (p)
                          3'd0: rom_word = {8'hE2, 8'h00};
                          3'd1: rom_word = {8'hE2, 8'h00};
                          3'd2: rom_word = {8'hE2, 8'h00};
                          3'd3: rom_word = {8'hE2, 8'h00};
                          3'd4: rom_word = {8'hE2, 8'h00};
                          3'd5: rom_word = {8'hE2, 8'h06};
                          3'd6: rom_word = {8'hE2, 8'h00};
                          3'd7: rom_word = {8'hE2, 8'h00};
                          default: rom_word = {8'hE2, 8'h00};
                      endcase

                5'd20: case (p)
                          3'd0: rom_word = {8'hE3, 8'h00};
                          3'd1: rom_word = {8'hE3, 8'h00};
                          3'd2: rom_word = {8'hE3, 8'h00};
                          3'd3: rom_word = {8'hE3, 8'h00};
                          3'd4: rom_word = {8'hE3, 8'h00};
                          3'd5: rom_word = {8'hE3, 8'h06};
                          3'd6: rom_word = {8'hE3, 8'h00};
                          3'd7: rom_word = {8'hE3, 8'h00};
                          default: rom_word = {8'hE3, 8'h00};
                      endcase

                5'd21: case (p)
                          3'd0: rom_word = {8'hA0, 8'hBE};
                          3'd1: rom_word = {8'hA0, 8'hBE};
                          3'd2: rom_word = {8'hA0, 8'hBE};
                          3'd3: rom_word = {8'hA0, 8'hBE};
                          3'd4: rom_word = {8'hA0, 8'hBE};
                          3'd5: rom_word = {8'hA0, 8'hBE};
                          3'd6: rom_word = {8'hA0, 8'hBE};
                          3'd7: rom_word = {8'hA0, 8'hBE};
                          default: rom_word = {8'hA0, 8'hBE};
                      endcase

                5'd22: case (p)
                          3'd0: rom_word = {8'hB0, 8'h0E};
                          3'd1: rom_word = {8'hB0, 8'h0E};
                          3'd2: rom_word = {8'hB0, 8'h0E};
                          3'd3: rom_word = {8'hB0, 8'h0E};
                          3'd4: rom_word = {8'hB0, 8'h0E};
                          3'd5: rom_word = {8'hB0, 8'h0E};
                          3'd6: rom_word = {8'hB0, 8'h0E};
                          3'd7: rom_word = {8'hB0, 8'h0E};
                          default: rom_word = {8'hB0, 8'h0E};
                      endcase

                5'd23: case (p)
                          3'd0: rom_word = {8'hC0, 8'h00};
                          3'd1: rom_word = {8'hC0, 8'h01};
                          3'd2: rom_word = {8'hC0, 8'h02};
                          3'd3: rom_word = {8'hC0, 8'h03};
                          3'd4: rom_word = {8'hC0, 8'h04};
                          3'd5: rom_word = {8'hC0, 8'h05};
                          3'd6: rom_word = {8'hC0, 8'h36};
                          3'd7: rom_word = {8'hC0, 8'h07};
                          default: rom_word = {8'hC0, 8'h00};
                      endcase

                5'd24: case (p)
                          3'd0: rom_word = {8'hF0, 8'hB5};
                          3'd1: rom_word = {8'hF0, 8'h99};
                          3'd2: rom_word = {8'hF0, 8'hB5};
                          3'd3: rom_word = {8'hF0, 8'hC7};
                          3'd4: rom_word = {8'hF0, 8'hCD};
                          3'd5: rom_word = {8'hF0, 8'h67};
                          3'd6: rom_word = {8'hF0, 8'hCD};
                          3'd7: rom_word = {8'hF0, 8'hAD};
                          default: rom_word = {8'hF0, 8'hB5};
                      endcase

                5'd25: case (p)
                          3'd0: rom_word = {8'hF1, 8'hBA};
                          3'd1: rom_word = {8'hF1, 8'hDD};
                          3'd2: rom_word = {8'hF1, 8'hBA};
                          3'd3: rom_word = {8'hF1, 8'hCB};
                          3'd4: rom_word = {8'hF1, 8'hED};
                          3'd5: rom_word = {8'hF1, 8'hDB};
                          3'd6: rom_word = {8'hF1, 8'hED};
                          3'd7: rom_word = {8'hF1, 8'hEC};
                          default: rom_word = {8'hF1, 8'hBA};
                      endcase

                5'd26: case (p)
                          3'd0: rom_word = {8'hF2, 8'h00};
                          3'd1: rom_word = {8'hF2, 8'h00};
                          3'd2: rom_word = {8'hF2, 8'h00};
                          3'd3: rom_word = {8'hF2, 8'h00};
                          3'd4: rom_word = {8'hF2, 8'h14};
                          3'd5: rom_word = {8'hF2, 8'h00};
                          3'd6: rom_word = {8'hF2, 8'h0C};
                          3'd7: rom_word = {8'hF2, 8'h08};
                          default: rom_word = {8'hF2, 8'h00};
                      endcase

                default: rom_word = {8'h01, 8'h00};

            endcase
        end
    endfunction

    assign patch_word = rom_word(patch, idx);

endmodule
