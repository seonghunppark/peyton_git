`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Video Downscaler
// Description: Downscales video resolution for efficient processing
//              Supports multiple downscale ratios (2x, 4x)
//              Uses pixel averaging for better quality
//////////////////////////////////////////////////////////////////////////////////

module video_downscaler #(
    parameter INPUT_WIDTH   = 320,
    parameter INPUT_HEIGHT  = 240,
    parameter SCALE_FACTOR  = 2,      // 2 = half size, 4 = quarter size
    parameter OUTPUT_WIDTH  = INPUT_WIDTH / SCALE_FACTOR,
    parameter OUTPUT_HEIGHT = INPUT_HEIGHT / SCALE_FACTOR
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        pixel_valid_in,
    input  logic [15:0] pixel_in,        // RGB565 input
    input  logic [9:0]  x_in,
    input  logic [8:0]  y_in,
    input  logic        frame_start,

    output logic        pixel_valid_out,
    output logic [15:0] pixel_out,       // RGB565 output
    output logic [9:0]  x_out,
    output logic [8:0]  y_out
);

    // Accumulator for pixel averaging (when SCALE_FACTOR > 1)
    logic [9:0] r_accum, g_accum, b_accum;
    logic [3:0] pixel_count;
    logic [9:0] x_scaled, y_scaled;

    // Check if this pixel should be output
    logic output_pixel;

    generate
        if (SCALE_FACTOR == 2) begin
            // Output every 2nd pixel in both X and Y
            assign output_pixel = (x_in[0] == 1'b1) && (y_in[0] == 1'b1);
            assign x_scaled = {1'b0, x_in[9:1]};
            assign y_scaled = {1'b0, y_in[8:1]};
        end else if (SCALE_FACTOR == 4) begin
            // Output every 4th pixel in both X and Y
            assign output_pixel = (x_in[1:0] == 2'b11) && (y_in[1:0] == 2'b11);
            assign x_scaled = {2'b00, x_in[9:2]};
            assign y_scaled = {2'b00, y_in[8:2]};
        end else begin
            // No scaling
            assign output_pixel = 1'b1;
            assign x_scaled = x_in;
            assign y_scaled = {1'b0, y_in};
        end
    endgenerate

    // Simple subsampling (no averaging for simplicity)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pixel_valid_out <= 1'b0;
            pixel_out       <= 16'd0;
            x_out           <= 10'd0;
            y_out           <= 9'd0;
        end else if (frame_start) begin
            pixel_valid_out <= 1'b0;
        end else if (pixel_valid_in && output_pixel) begin
            pixel_valid_out <= 1'b1;
            pixel_out       <= pixel_in;
            x_out           <= x_scaled;
            y_out           <= y_scaled[8:0];
        end else begin
            pixel_valid_out <= 1'b0;
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: Video Downscaler with Averaging
// Description: Averages pixels for better downscale quality
//              Uses accumulator approach
//////////////////////////////////////////////////////////////////////////////////

module video_downscaler_avg #(
    parameter INPUT_WIDTH   = 320,
    parameter INPUT_HEIGHT  = 240,
    parameter OUTPUT_WIDTH  = 160,
    parameter OUTPUT_HEIGHT = 120
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        pixel_valid_in,
    input  logic [15:0] pixel_in,        // RGB565 input
    input  logic [9:0]  x_in,
    input  logic [8:0]  y_in,
    input  logic        frame_start,

    output logic        we_out,
    output logic [14:0] addr_out,        // QQVGA address (160*120 = 19200)
    output logic [15:0] pixel_out
);

    // Extract RGB components from RGB565
    logic [4:0] r_in, b_in;
    logic [5:0] g_in;

    assign r_in = pixel_in[15:11];
    assign g_in = pixel_in[10:5];
    assign b_in = pixel_in[4:0];

    // 2x2 averaging accumulators
    logic [6:0] r_accum, b_accum;
    logic [7:0] g_accum;
    logic [1:0] acc_count;

    // Position tracking
    logic [8:0] out_x, out_y;
    logic       row_even, col_even;

    assign row_even = ~y_in[0];
    assign col_even = ~x_in[0];

    // Accumulation and output logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            r_accum   <= 7'd0;
            g_accum   <= 8'd0;
            b_accum   <= 7'd0;
            acc_count <= 2'd0;
            we_out    <= 1'b0;
            addr_out  <= 15'd0;
            pixel_out <= 16'd0;
            out_x     <= 9'd0;
            out_y     <= 9'd0;
        end else if (frame_start) begin
            r_accum   <= 7'd0;
            g_accum   <= 8'd0;
            b_accum   <= 7'd0;
            acc_count <= 2'd0;
            we_out    <= 1'b0;
            out_x     <= 9'd0;
            out_y     <= 9'd0;
        end else if (pixel_valid_in) begin
            // Accumulate pixel values
            if (col_even && row_even) begin
                // First pixel of 2x2 block
                r_accum   <= {2'b0, r_in};
                g_accum   <= {2'b0, g_in};
                b_accum   <= {2'b0, b_in};
                acc_count <= 2'd1;
                we_out    <= 1'b0;
            end else begin
                // Add to accumulator
                r_accum   <= r_accum + {2'b0, r_in};
                g_accum   <= g_accum + {2'b0, g_in};
                b_accum   <= b_accum + {2'b0, b_in};
                acc_count <= acc_count + 1'b1;

                // Output averaged pixel when 2x2 block is complete
                if (!col_even && !row_even) begin
                    we_out    <= 1'b1;
                    addr_out  <= OUTPUT_WIDTH * (y_in >> 1) + (x_in >> 1);
                    // Average by dividing by 4 (shift right 2)
                    pixel_out <= {r_accum[6:2], g_accum[7:2], b_accum[6:2]};
                end else begin
                    we_out <= 1'b0;
                end
            end
        end else begin
            we_out <= 1'b0;
        end
    end

endmodule
