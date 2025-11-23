`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Grayscale Converter
// Description: RGB565 to Grayscale conversion
//              Y = 0.299*R + 0.587*G + 0.114*B (ITU-R BT.601)
//              Using fixed-point: Y = (77*R + 150*G + 29*B) >> 8
//////////////////////////////////////////////////////////////////////////////////

module grayscale_converter (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic [15:0] rgb565_in,   // RGB565 format: RRRRR_GGGGGG_BBBBB
    output logic [ 7:0] gray_out,    // 8-bit grayscale output
    output logic        valid_out
);

    // Extract RGB components from RGB565
    logic [7:0] r_8bit, g_8bit, b_8bit;
    logic [15:0] y_calc;

    // RGB565 to 8-bit conversion (extend to 8 bits)
    // R: 5 bits -> 8 bits (shift left 3, fill with MSB)
    // G: 6 bits -> 8 bits (shift left 2, fill with MSB)
    // B: 5 bits -> 8 bits (shift left 3, fill with MSB)
    assign r_8bit = {rgb565_in[15:11], rgb565_in[15:13]};  // 5-bit R to 8-bit
    assign g_8bit = {rgb565_in[10:5], rgb565_in[10:9]};    // 6-bit G to 8-bit
    assign b_8bit = {rgb565_in[4:0], rgb565_in[4:2]};      // 5-bit B to 8-bit

    // Grayscale conversion: Y = (77*R + 150*G + 29*B) >> 8
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            gray_out  <= 8'd0;
            valid_out <= 1'b0;
        end else if (enable) begin
            y_calc    <= (77 * r_8bit + 150 * g_8bit + 29 * b_8bit);
            gray_out  <= y_calc[15:8];  // >> 8
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
