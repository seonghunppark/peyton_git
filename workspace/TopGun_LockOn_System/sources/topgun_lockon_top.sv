`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Top Module: TopGun Lock-on System
// Description: Real-time target detection and tracking system
//              Integrates all subsystems:
//              - Camera interface (OV7670)
//              - Motion detection (frame differencing)
//              - Target tracking (center of mass calculation)
//              - HUD overlay (lock-on display)
//              - Video scrambling (security feature)
//////////////////////////////////////////////////////////////////////////////////

module topgun_lockon_top (
    // Global signals
    input  logic        clk,           // 100MHz system clock
    input  logic        reset,

    // Camera interface (OV7670)
    output logic        cam_xclk,      // Camera clock output (25MHz)
    input  logic        cam_pclk,      // Pixel clock from camera
    input  logic        cam_href,      // Horizontal reference
    input  logic        cam_vsync,     // Vertical sync
    input  logic [7:0]  cam_data,      // Pixel data from camera

    // VGA output
    output logic        vga_hsync,
    output logic        vga_vsync,
    output logic [3:0]  vga_r,
    output logic [3:0]  vga_g,
    output logic [3:0]  vga_b,

    // Control inputs
    input  logic [3:0]  sw_mode,       // Mode selection switches
    input  logic [3:0]  sw_security,   // Security key switches
    input  logic        btn_scramble,  // Enable scramble button
    input  logic [7:0]  threshold_adj, // Motion threshold adjustment

    // Status outputs
    output logic        led_lock_on,   // Lock-on indicator LED
    output logic        led_motion,    // Motion detected LED
    output logic        led_scramble,  // Scramble active LED
    output logic [7:0]  target_x_out,  // Target X coordinate output
    output logic [6:0]  target_y_out   // Target Y coordinate output
);

    //==========================================================================
    // Internal signals
    //==========================================================================

    // Clock domain signals
    logic sys_clk;              // 25MHz VGA/system clock
    logic pclk_sync;

    // VGA timing signals
    logic        DE;
    logic [9:0]  x_pixel, y_pixel;

    // Frame buffer signals (original resolution 320x240)
    logic        fb_we;
    logic [16:0] fb_wAddr;
    logic [15:0] fb_wData;
    logic [16:0] fb_rAddr;
    logic [15:0] fb_rData;

    // Motion detection frame buffer (QQVGA 160x120)
    logic        md_we;
    logic [14:0] md_wAddr;
    logic [7:0]  md_wData_gray;
    logic [14:0] md_rAddr;
    logic [7:0]  md_curr_frame;
    logic [7:0]  md_prev_frame;
    logic        md_frame_done;
    logic        md_buffer_sel;

    // Grayscale converter signals
    logic [7:0]  gray_pixel;
    logic        gray_valid;

    // Motion detector signals
    logic        motion_detected;
    logic [7:0]  motion_diff;
    logic        motion_valid;
    logic        motion_pixel_filtered;

    // Target tracking signals
    logic [7:0]  target_x;
    logic [6:0]  target_y;
    logic        target_valid;
    logic [15:0] motion_pixel_count;
    logic        calc_done;

    // Bounding box signals
    logic [7:0]  box_x_min, box_x_max;
    logic [6:0]  box_y_min, box_y_max;
    logic        box_valid;

    // Display pipeline signals
    logic [3:0]  r_original, g_original, b_original;
    logic [3:0]  r_highlight, g_highlight, b_highlight;
    logic [3:0]  r_hud, g_hud, b_hud;
    logic [15:0] scrambled_pixel;
    logic        scramble_valid;

    // Scrambler control signals
    logic        scramble_active;
    logic        descramble_key_valid;
    logic [1:0]  scramble_mode;

    // Processing control signals
    logic        frame_start;
    logic        frame_end;
    logic [7:0]  motion_threshold;

    //==========================================================================
    // Clock generation (100MHz -> 25MHz)
    //==========================================================================

    pixel_clk_gen U_pixel_clk_gen (
        .clk  (clk),
        .reset(reset),
        .pclk (sys_clk)
    );

    assign cam_xclk = sys_clk;

    //==========================================================================
    // VGA Timing Generator
    //==========================================================================

    VGA_Syncher U_VGA_Syncher (
        .clk    (sys_clk),
        .reset  (reset),
        .h_sync (vga_hsync),
        .v_sync (vga_vsync),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    // Frame synchronization
    logic vsync_prev;
    always_ff @(posedge sys_clk or posedge reset) begin
        if (reset) begin
            vsync_prev  <= 1'b0;
            frame_start <= 1'b0;
        end else begin
            vsync_prev  <= vga_vsync;
            frame_start <= vga_vsync & ~vsync_prev;  // Rising edge of vsync
        end
    end

    //==========================================================================
    // Camera Data Capture & Original Frame Buffer (320x240)
    //==========================================================================

    OV7670_Mem_controller U_Camera_Controller (
        .pclk (cam_pclk),
        .reset(reset),
        .href (cam_href),
        .vsync(cam_vsync),
        .data (cam_data),
        .we   (fb_we),
        .wAddr(fb_wAddr),
        .wData(fb_wData)
    );

    frame_buffer U_Original_Frame_Buffer (
        .wclk (cam_pclk),
        .we   (fb_we),
        .wAddr(fb_wAddr),
        .wData(fb_wData),
        .rclk (sys_clk),
        .oe   (1'b1),
        .rAddr(fb_rAddr),
        .rData(fb_rData)
    );

    //==========================================================================
    // Image Reader with Upscaling (320x240 -> 640x480)
    //==========================================================================

    ImgMemReader_upscaler U_ImgReader (
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (fb_rAddr),
        .imgData(fb_rData),
        .r_port (r_original),
        .g_port (g_original),
        .b_port (b_original)
    );

    //==========================================================================
    // Motion Detection Pipeline (QQVGA Resolution for efficiency)
    //==========================================================================

    // Grayscale conversion (from original frame buffer data)
    grayscale_converter U_Grayscale (
        .clk      (sys_clk),
        .reset    (reset),
        .enable   (DE),
        .rgb565_in(fb_rData),
        .gray_out (gray_pixel),
        .valid_out(gray_valid)
    );

    // Downscale address calculation for QQVGA (160x120)
    // Sample every 4th pixel (2x from 320x240, then 2x upscale display)
    logic [7:0]  qqvga_x;
    logic [6:0]  qqvga_y;
    logic        qqvga_pixel_valid;

    assign qqvga_x = x_pixel[9:2];  // 640/4 = 160
    assign qqvga_y = y_pixel[9:2];  // 480/4 = 120
    assign qqvga_pixel_valid = (x_pixel[1:0] == 2'b00) && (y_pixel[1:0] == 2'b00) && DE;

    // Write to motion detection buffer (downscaled)
    assign md_we = qqvga_pixel_valid && gray_valid;
    assign md_wAddr = 160 * qqvga_y + qqvga_x;
    assign md_wData_gray = gray_pixel;
    assign md_frame_done = frame_start;

    // Dual frame buffer for motion detection
    dual_frame_buffer #(
        .WIDTH (160),
        .HEIGHT(120)
    ) U_Motion_Frame_Buffer (
        .wclk           (sys_clk),
        .reset          (reset),
        .we             (md_we),
        .wAddr          (md_wAddr),
        .wData          (md_wData_gray),
        .frame_done     (md_frame_done),
        .rclk           (sys_clk),
        .oe             (qqvga_pixel_valid),
        .rAddr          (md_wAddr),  // Read same address for comparison
        .curr_frame_data(md_curr_frame),
        .prev_frame_data(md_prev_frame),
        .buffer_sel     (md_buffer_sel)
    );

    // Motion threshold (adjustable via switches or fixed)
    assign motion_threshold = (threshold_adj != 8'd0) ? threshold_adj : 8'd30;

    // Motion detection
    motion_detector #(
        .THRESHOLD(30)
    ) U_Motion_Detector (
        .clk            (sys_clk),
        .reset          (reset),
        .enable         (qqvga_pixel_valid),
        .curr_pixel     (md_curr_frame),
        .prev_pixel     (md_prev_frame),
        .threshold_in   (motion_threshold),
        .motion_detected(motion_detected),
        .diff_value     (motion_diff),
        .valid_out      (motion_valid)
    );

    // Noise filtering
    noise_filter #(
        .WIDTH (160),
        .HEIGHT(120)
    ) U_Noise_Filter (
        .clk      (sys_clk),
        .reset    (reset),
        .enable   (motion_valid),
        .pixel_in (motion_detected),
        .x_coord  (qqvga_x),
        .y_coord  (qqvga_y),
        .pixel_out(motion_pixel_filtered),
        .valid_out()
    );

    //==========================================================================
    // Target Tracking (Center of Mass & Bounding Box)
    //==========================================================================

    center_of_mass #(
        .WIDTH (160),
        .HEIGHT(120),
        .MIN_PIXEL_COUNT(50)
    ) U_Center_of_Mass (
        .clk         (sys_clk),
        .reset       (reset),
        .frame_start (frame_start),
        .pixel_valid (motion_valid),
        .motion_pixel(motion_pixel_filtered),
        .x_coord     (qqvga_x),
        .y_coord     (qqvga_y),
        .target_x    (target_x),
        .target_y    (target_y),
        .target_valid(target_valid),
        .pixel_count (motion_pixel_count),
        .calc_done   (calc_done)
    );

    bounding_box #(
        .WIDTH (160),
        .HEIGHT(120)
    ) U_Bounding_Box (
        .clk         (sys_clk),
        .reset       (reset),
        .frame_start (frame_start),
        .pixel_valid (motion_valid),
        .motion_pixel(motion_pixel_filtered),
        .x_coord     (qqvga_x),
        .y_coord     (qqvga_y),
        .box_x_min   (box_x_min),
        .box_x_max   (box_x_max),
        .box_y_min   (box_y_min),
        .box_y_max   (box_y_max),
        .box_valid   (box_valid)
    );

    //==========================================================================
    // Motion Region Highlighting
    //==========================================================================

    // Scale up motion mask for VGA display
    logic motion_mask_display;
    assign motion_mask_display = motion_detected && (sw_mode[0]);  // Enable with switch

    motion_highlighter U_Motion_Highlight (
        .clk           (sys_clk),
        .reset         (reset),
        .display_enable(DE),
        .motion_mask   (motion_mask_display),
        .r_in          (r_original),
        .g_in          (g_original),
        .b_in          (b_original),
        .r_out         (r_highlight),
        .g_out         (g_highlight),
        .b_out         (b_highlight)
    );

    //==========================================================================
    // HUD Overlay (Lock-on Display)
    //==========================================================================

    logic lock_on_status;

    hud_overlay #(
        .DISPLAY_WIDTH (640),
        .DISPLAY_HEIGHT(480),
        .CROSSHAIR_SIZE(20),
        .BOX_THICKNESS (2),
        .SCALE_FACTOR  (4)
    ) U_HUD_Overlay (
        .clk           (sys_clk),
        .reset         (reset),
        .x_pixel       (x_pixel),
        .y_pixel       (y_pixel),
        .display_enable(DE),
        .target_x      (target_x),
        .target_y      (target_y),
        .target_valid  (target_valid && sw_mode[1]),  // Enable with switch
        .box_x_min     (box_x_min),
        .box_x_max     (box_x_max),
        .box_y_min     (box_y_min),
        .box_y_max     (box_y_max),
        .box_valid     (box_valid && sw_mode[1]),
        .r_in          (r_highlight),
        .g_in          (g_highlight),
        .b_in          (b_highlight),
        .r_out         (r_hud),
        .g_out         (g_hud),
        .b_out         (b_hud),
        .lock_on_status(lock_on_status)
    );

    //==========================================================================
    // Video Scrambler (Security Feature)
    //==========================================================================

    scrambler_controller U_Scramble_Ctrl (
        .clk                (sys_clk),
        .reset              (reset),
        .key_input          (sw_security),
        .security_code      (4'b1010),  // Fixed security code
        .enable_scramble    (btn_scramble),
        .scramble_active    (scramble_active),
        .descramble_key_valid(descramble_key_valid),
        .scramble_mode      (scramble_mode)
    );

    // Reconstruct RGB565 from HUD output for scrambling
    logic [15:0] display_pixel_rgb565;
    assign display_pixel_rgb565 = {r_hud, 1'b0, g_hud, 2'b00, b_hud, 1'b0};

    video_scrambler #(
        .MODE(2)
    ) U_Video_Scrambler (
        .clk        (sys_clk),
        .reset      (reset),
        .enable     (scramble_active),
        .frame_sync (frame_start),
        .mode_select(scramble_mode),
        .fixed_key  (16'hA5A5),
        .pixel_in   (display_pixel_rgb565),
        .pixel_out  (scrambled_pixel),
        .valid_out  (scramble_valid)
    );

    //==========================================================================
    // Final Output Multiplexer
    //==========================================================================

    always_ff @(posedge sys_clk or posedge reset) begin
        if (reset) begin
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
        end else if (DE) begin
            if (scramble_active && !descramble_key_valid) begin
                // Output scrambled video (appears as noise)
                vga_r <= scrambled_pixel[15:12];
                vga_g <= scrambled_pixel[10:7];
                vga_b <= scrambled_pixel[4:1];
            end else begin
                // Output normal video with HUD overlay
                vga_r <= r_hud;
                vga_g <= g_hud;
                vga_b <= b_hud;
            end
        end else begin
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
        end
    end

    //==========================================================================
    // Status Outputs
    //==========================================================================

    assign led_lock_on  = lock_on_status;
    assign led_motion   = (motion_pixel_count > 16'd50);
    assign led_scramble = scramble_active;
    assign target_x_out = target_x;
    assign target_y_out = target_y;

endmodule
