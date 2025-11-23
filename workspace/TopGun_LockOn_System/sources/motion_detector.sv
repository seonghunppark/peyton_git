`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Motion Detector
// Description: Frame differencing for motion detection
//              Compares current and previous frames
//              Outputs binary motion mask with configurable threshold
//////////////////////////////////////////////////////////////////////////////////

module motion_detector #(
    parameter THRESHOLD = 8'd30  // Motion detection threshold (adjustable)
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       enable,
    input  logic [7:0] curr_pixel,     // Current frame grayscale pixel
    input  logic [7:0] prev_pixel,     // Previous frame grayscale pixel
    input  logic [7:0] threshold_in,   // Dynamic threshold input
    output logic       motion_detected, // 1 = motion detected at this pixel
    output logic [7:0] diff_value,     // Absolute difference value
    output logic       valid_out
);

    logic [8:0] diff_calc;  // 9-bit for subtraction result (signed handling)
    logic [7:0] abs_diff;

    // Calculate absolute difference
    always_comb begin
        if (curr_pixel >= prev_pixel) begin
            diff_calc = curr_pixel - prev_pixel;
        end else begin
            diff_calc = prev_pixel - curr_pixel;
        end
        abs_diff = diff_calc[7:0];
    end

    // Motion detection with threshold comparison
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            motion_detected <= 1'b0;
            diff_value      <= 8'd0;
            valid_out       <= 1'b0;
        end else if (enable) begin
            diff_value      <= abs_diff;
            motion_detected <= (abs_diff > threshold_in);
            valid_out       <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: Noise Filter (Morphological Operations)
// Description: Simple erosion/dilation for noise removal
//              Uses 3x3 kernel for morphological operations
//////////////////////////////////////////////////////////////////////////////////

module noise_filter #(
    parameter WIDTH  = 160,
    parameter HEIGHT = 120
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        pixel_in,      // Binary motion pixel
    input  logic [7:0]  x_coord,
    input  logic [6:0]  y_coord,
    output logic        pixel_out,     // Filtered pixel
    output logic        valid_out
);

    // Line buffers for 3x3 window (store 2 previous lines)
    logic [WIDTH-1:0] line_buffer_0;
    logic [WIDTH-1:0] line_buffer_1;

    // 3x3 window
    logic [2:0] window_row0, window_row1, window_row2;

    // Shift registers for horizontal window
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            line_buffer_0 <= '0;
            line_buffer_1 <= '0;
        end else if (enable) begin
            // Shift line buffers
            line_buffer_0 <= {line_buffer_0[WIDTH-2:0], pixel_in};
            line_buffer_1 <= {line_buffer_1[WIDTH-2:0], line_buffer_0[WIDTH-1]};
        end
    end

    // Build 3x3 window
    always_comb begin
        window_row0 = {line_buffer_1[WIDTH-1], line_buffer_1[WIDTH-2], line_buffer_1[WIDTH-3]};
        window_row1 = {line_buffer_0[WIDTH-1], line_buffer_0[WIDTH-2], line_buffer_0[WIDTH-3]};
        window_row2 = {pixel_in, line_buffer_0[0], line_buffer_0[1]};
    end

    // Erosion: output 1 only if all neighbors are 1 (removes isolated noise)
    // Simplified: require at least 5 of 9 pixels to be motion
    logic [3:0] motion_count;

    always_comb begin
        motion_count = window_row0[0] + window_row0[1] + window_row0[2] +
                      window_row1[0] + window_row1[1] + window_row1[2] +
                      window_row2[0] + window_row2[1] + window_row2[2];
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pixel_out <= 1'b0;
            valid_out <= 1'b0;
        end else if (enable) begin
            // Output 1 if majority of pixels show motion
            pixel_out <= (motion_count >= 4'd4);
            valid_out <= (x_coord >= 2) && (y_coord >= 2);
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
