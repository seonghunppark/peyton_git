`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: HUD Overlay Generator (TopGun Lock-on System)
// Description: Generates heads-up display overlay for target lock-on
//              Includes crosshair, bounding box, and status indicators
//              Inspired by TopGun movie target tracking display
//////////////////////////////////////////////////////////////////////////////////

module hud_overlay #(
    parameter DISPLAY_WIDTH  = 640,
    parameter DISPLAY_HEIGHT = 480,
    parameter CROSSHAIR_SIZE = 20,    // Size of crosshair arms
    parameter BOX_THICKNESS  = 2,     // Bounding box line thickness
    parameter SCALE_FACTOR   = 4      // QQVGA to VGA upscale factor
)(
    input  logic        clk,
    input  logic        reset,

    // Current pixel coordinates (VGA resolution)
    input  logic [9:0]  x_pixel,
    input  logic [9:0]  y_pixel,
    input  logic        display_enable,

    // Target tracking data (QQVGA coordinates, will be upscaled)
    input  logic [7:0]  target_x,       // Center X (0-159)
    input  logic [6:0]  target_y,       // Center Y (0-119)
    input  logic        target_valid,   // Target lock valid

    // Bounding box data (QQVGA coordinates)
    input  logic [7:0]  box_x_min,
    input  logic [7:0]  box_x_max,
    input  logic [6:0]  box_y_min,
    input  logic [6:0]  box_y_max,
    input  logic        box_valid,

    // Original pixel data
    input  logic [3:0]  r_in,
    input  logic [3:0]  g_in,
    input  logic [3:0]  b_in,

    // HUD overlaid output
    output logic [3:0]  r_out,
    output logic [3:0]  g_out,
    output logic [3:0]  b_out,

    // Lock-on status
    output logic        lock_on_status
);

    // Upscaled target coordinates to VGA resolution
    logic [9:0] target_x_vga, target_y_vga;
    logic [9:0] box_x_min_vga, box_x_max_vga;
    logic [9:0] box_y_min_vga, box_y_max_vga;

    // Scale coordinates from QQVGA to VGA
    assign target_x_vga   = {2'b0, target_x} << 2;  // * 4
    assign target_y_vga   = {3'b0, target_y} << 2;  // * 4
    assign box_x_min_vga  = {2'b0, box_x_min} << 2;
    assign box_x_max_vga  = {2'b0, box_x_max} << 2;
    assign box_y_min_vga  = {3'b0, box_y_min} << 2;
    assign box_y_max_vga  = {3'b0, box_y_max} << 2;

    // HUD element detection signals
    logic is_crosshair_h, is_crosshair_v;
    logic is_crosshair_center;
    logic is_bounding_box;
    logic is_corner_marker;
    logic is_lock_diamond;

    // Crosshair detection (center cross)
    assign is_crosshair_h = target_valid &&
                           (y_pixel >= target_y_vga - 1) &&
                           (y_pixel <= target_y_vga + 1) &&
                           (x_pixel >= target_x_vga - CROSSHAIR_SIZE) &&
                           (x_pixel <= target_x_vga + CROSSHAIR_SIZE) &&
                           !((x_pixel >= target_x_vga - 5) && (x_pixel <= target_x_vga + 5));

    assign is_crosshair_v = target_valid &&
                           (x_pixel >= target_x_vga - 1) &&
                           (x_pixel <= target_x_vga + 1) &&
                           (y_pixel >= target_y_vga - CROSSHAIR_SIZE) &&
                           (y_pixel <= target_y_vga + CROSSHAIR_SIZE) &&
                           !((y_pixel >= target_y_vga - 5) && (y_pixel <= target_y_vga + 5));

    // Center dot
    assign is_crosshair_center = target_valid &&
                                (x_pixel >= target_x_vga - 2) &&
                                (x_pixel <= target_x_vga + 2) &&
                                (y_pixel >= target_y_vga - 2) &&
                                (y_pixel <= target_y_vga + 2);

    // Bounding box detection (rectangle around target)
    logic is_box_top, is_box_bottom, is_box_left, is_box_right;

    assign is_box_top = box_valid &&
                       (y_pixel >= box_y_min_vga) &&
                       (y_pixel <= box_y_min_vga + BOX_THICKNESS) &&
                       (x_pixel >= box_x_min_vga) &&
                       (x_pixel <= box_x_max_vga);

    assign is_box_bottom = box_valid &&
                          (y_pixel >= box_y_max_vga - BOX_THICKNESS) &&
                          (y_pixel <= box_y_max_vga) &&
                          (x_pixel >= box_x_min_vga) &&
                          (x_pixel <= box_x_max_vga);

    assign is_box_left = box_valid &&
                        (x_pixel >= box_x_min_vga) &&
                        (x_pixel <= box_x_min_vga + BOX_THICKNESS) &&
                        (y_pixel >= box_y_min_vga) &&
                        (y_pixel <= box_y_max_vga);

    assign is_box_right = box_valid &&
                         (x_pixel >= box_x_max_vga - BOX_THICKNESS) &&
                         (x_pixel <= box_x_max_vga) &&
                         (y_pixel >= box_y_min_vga) &&
                         (y_pixel <= box_y_max_vga);

    assign is_bounding_box = is_box_top || is_box_bottom || is_box_left || is_box_right;

    // Corner markers (L-shaped brackets at corners) - TopGun style
    localparam CORNER_SIZE = 15;

    logic is_corner_tl, is_corner_tr, is_corner_bl, is_corner_br;

    // Top-left corner
    assign is_corner_tl = box_valid &&
        (((x_pixel >= box_x_min_vga - 5) && (x_pixel <= box_x_min_vga - 3) &&
          (y_pixel >= box_y_min_vga - 5) && (y_pixel <= box_y_min_vga + CORNER_SIZE)) ||
         ((y_pixel >= box_y_min_vga - 5) && (y_pixel <= box_y_min_vga - 3) &&
          (x_pixel >= box_x_min_vga - 5) && (x_pixel <= box_x_min_vga + CORNER_SIZE)));

    // Top-right corner
    assign is_corner_tr = box_valid &&
        (((x_pixel >= box_x_max_vga + 3) && (x_pixel <= box_x_max_vga + 5) &&
          (y_pixel >= box_y_min_vga - 5) && (y_pixel <= box_y_min_vga + CORNER_SIZE)) ||
         ((y_pixel >= box_y_min_vga - 5) && (y_pixel <= box_y_min_vga - 3) &&
          (x_pixel >= box_x_max_vga - CORNER_SIZE) && (x_pixel <= box_x_max_vga + 5)));

    // Bottom-left corner
    assign is_corner_bl = box_valid &&
        (((x_pixel >= box_x_min_vga - 5) && (x_pixel <= box_x_min_vga - 3) &&
          (y_pixel >= box_y_max_vga - CORNER_SIZE) && (y_pixel <= box_y_max_vga + 5)) ||
         ((y_pixel >= box_y_max_vga + 3) && (y_pixel <= box_y_max_vga + 5) &&
          (x_pixel >= box_x_min_vga - 5) && (x_pixel <= box_x_min_vga + CORNER_SIZE)));

    // Bottom-right corner
    assign is_corner_br = box_valid &&
        (((x_pixel >= box_x_max_vga + 3) && (x_pixel <= box_x_max_vga + 5) &&
          (y_pixel >= box_y_max_vga - CORNER_SIZE) && (y_pixel <= box_y_max_vga + 5)) ||
         ((y_pixel >= box_y_max_vga + 3) && (y_pixel <= box_y_max_vga + 5) &&
          (x_pixel >= box_x_max_vga - CORNER_SIZE) && (x_pixel <= box_x_max_vga + 5)));

    assign is_corner_marker = is_corner_tl || is_corner_tr || is_corner_bl || is_corner_br;

    // Diamond shape around center (lock-on indicator)
    logic [9:0] dx, dy;
    logic [10:0] diamond_dist;

    always_comb begin
        dx = (x_pixel > target_x_vga) ? (x_pixel - target_x_vga) : (target_x_vga - x_pixel);
        dy = (y_pixel > target_y_vga) ? (y_pixel - target_y_vga) : (target_y_vga - y_pixel);
        diamond_dist = dx + dy;
    end

    assign is_lock_diamond = target_valid &&
                            (diamond_dist >= 10'd28) && (diamond_dist <= 10'd32);

    // Lock-on status (target is valid and stable)
    assign lock_on_status = target_valid && box_valid;

    // Color output multiplexer
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            r_out <= 4'd0;
            g_out <= 4'd0;
            b_out <= 4'd0;
        end else if (display_enable) begin
            if (is_crosshair_center) begin
                // Center dot - bright red
                r_out <= 4'hF;
                g_out <= 4'h0;
                b_out <= 4'h0;
            end else if (is_crosshair_h || is_crosshair_v) begin
                // Crosshair - red
                r_out <= 4'hE;
                g_out <= 4'h2;
                b_out <= 4'h0;
            end else if (is_lock_diamond) begin
                // Lock diamond - green when locked
                r_out <= 4'h0;
                g_out <= 4'hF;
                b_out <= 4'h0;
            end else if (is_corner_marker) begin
                // Corner brackets - bright green (TopGun style)
                r_out <= 4'h0;
                g_out <= 4'hF;
                b_out <= 4'h0;
            end else if (is_bounding_box) begin
                // Bounding box - yellow
                r_out <= 4'hF;
                g_out <= 4'hF;
                b_out <= 4'h0;
            end else begin
                // Pass through original pixel
                r_out <= r_in;
                g_out <= g_in;
                b_out <= b_in;
            end
        end else begin
            r_out <= 4'd0;
            g_out <= 4'd0;
            b_out <= 4'd0;
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: Motion Region Highlighter
// Description: Highlights detected motion regions in red color
//              Used for visual feedback of motion detection
//////////////////////////////////////////////////////////////////////////////////

module motion_highlighter (
    input  logic       clk,
    input  logic       reset,
    input  logic       display_enable,
    input  logic       motion_mask,    // Motion detected at current pixel
    input  logic [3:0] r_in,
    input  logic [3:0] g_in,
    input  logic [3:0] b_in,
    output logic [3:0] r_out,
    output logic [3:0] g_out,
    output logic [3:0] b_out
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            r_out <= 4'd0;
            g_out <= 4'd0;
            b_out <= 4'd0;
        end else if (display_enable) begin
            if (motion_mask) begin
                // Highlight motion in red (blend with original)
                r_out <= 4'hF;                    // Max red
                g_out <= r_in[3:2];               // Reduced green
                b_out <= b_in[3:2];               // Reduced blue
            end else begin
                // Pass through original
                r_out <= r_in;
                g_out <= g_in;
                b_out <= b_in;
            end
        end else begin
            r_out <= 4'd0;
            g_out <= 4'd0;
            b_out <= 4'd0;
        end
    end

endmodule
