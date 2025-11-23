`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: TopGun Lock-on System
// Description: Simulation testbench for the target tracking system
//////////////////////////////////////////////////////////////////////////////////

module tb_topgun_lockon;

    // Parameters
    localparam CLK_PERIOD = 10;      // 100MHz = 10ns period
    localparam PCLK_PERIOD = 40;     // 25MHz pixel clock

    // Test signals
    logic        clk;
    logic        reset;

    // Camera interface
    logic        cam_xclk;
    logic        cam_pclk;
    logic        cam_href;
    logic        cam_vsync;
    logic [7:0]  cam_data;

    // VGA output
    logic        vga_hsync;
    logic        vga_vsync;
    logic [3:0]  vga_r;
    logic [3:0]  vga_g;
    logic [3:0]  vga_b;

    // Control inputs
    logic [3:0]  sw_mode;
    logic [3:0]  sw_security;
    logic        btn_scramble;
    logic [7:0]  threshold_adj;

    // Status outputs
    logic        led_lock_on;
    logic        led_motion;
    logic        led_scramble;
    logic [7:0]  target_x_out;
    logic [6:0]  target_y_out;

    // Test frame buffer (simulate camera output)
    logic [15:0] test_frame [0:320*240-1];
    logic [15:0] test_frame_motion [0:320*240-1];

    // Frame counter
    integer frame_count;
    integer pixel_count;
    integer line_count;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    topgun_lockon_top DUT (
        .clk          (clk),
        .reset        (reset),
        .cam_xclk     (cam_xclk),
        .cam_pclk     (cam_pclk),
        .cam_href     (cam_href),
        .cam_vsync    (cam_vsync),
        .cam_data     (cam_data),
        .vga_hsync    (vga_hsync),
        .vga_vsync    (vga_vsync),
        .vga_r        (vga_r),
        .vga_g        (vga_g),
        .vga_b        (vga_b),
        .sw_mode      (sw_mode),
        .sw_security  (sw_security),
        .btn_scramble (btn_scramble),
        .threshold_adj(threshold_adj),
        .led_lock_on  (led_lock_on),
        .led_motion   (led_motion),
        .led_scramble (led_scramble),
        .target_x_out (target_x_out),
        .target_y_out (target_y_out)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================

    // System clock (100MHz)
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Camera pixel clock (25MHz, derived from cam_xclk)
    always @(posedge clk) begin
        cam_pclk <= cam_xclk;
    end

    //==========================================================================
    // Test Frame Generation
    //==========================================================================

    // Initialize test frames
    initial begin
        // Background frame (gradient pattern)
        for (int y = 0; y < 240; y++) begin
            for (int x = 0; x < 320; x++) begin
                // Create gradient background
                test_frame[y * 320 + x] = {y[7:3], x[7:2], x[7:3]};  // RGB565
            end
        end

        // Motion frame (background + moving object)
        for (int y = 0; y < 240; y++) begin
            for (int x = 0; x < 320; x++) begin
                // Create gradient background with moving white rectangle
                if ((x >= 100) && (x <= 150) && (y >= 80) && (y <= 130)) begin
                    // Moving object (white)
                    test_frame_motion[y * 320 + x] = 16'hFFFF;
                end else begin
                    test_frame_motion[y * 320 + x] = {y[7:3], x[7:2], x[7:3]};
                end
            end
        end
    end

    //==========================================================================
    // Camera Signal Generation (OV7670 Timing Simulation)
    //==========================================================================

    task generate_frame;
        input logic use_motion_frame;
        begin
            // VSYNC pulse (active high)
            cam_vsync <= 1'b1;
            repeat(3) @(posedge cam_pclk);
            cam_vsync <= 1'b0;

            // Vertical back porch
            repeat(17) begin
                cam_href <= 1'b0;
                repeat(784) @(posedge cam_pclk);
            end

            // Active lines (240 lines)
            for (line_count = 0; line_count < 240; line_count++) begin
                // Horizontal back porch
                cam_href <= 1'b0;
                repeat(88) @(posedge cam_pclk);

                // Active pixels (320 pixels = 640 bytes in RGB565)
                cam_href <= 1'b1;
                for (pixel_count = 0; pixel_count < 320; pixel_count++) begin
                    logic [15:0] pixel_data;

                    if (use_motion_frame)
                        pixel_data = test_frame_motion[line_count * 320 + pixel_count];
                    else
                        pixel_data = test_frame[line_count * 320 + pixel_count];

                    // Send high byte first
                    cam_data <= pixel_data[15:8];
                    @(posedge cam_pclk);

                    // Send low byte
                    cam_data <= pixel_data[7:0];
                    @(posedge cam_pclk);
                end

                // Horizontal front porch
                cam_href <= 1'b0;
                repeat(8) @(posedge cam_pclk);
            end

            // Vertical front porch
            repeat(10) begin
                cam_href <= 1'b0;
                repeat(784) @(posedge cam_pclk);
            end
        end
    endtask

    //==========================================================================
    // Test Sequence
    //==========================================================================

    initial begin
        // Initialize signals
        reset         <= 1'b1;
        cam_href      <= 1'b0;
        cam_vsync     <= 1'b0;
        cam_data      <= 8'd0;
        sw_mode       <= 4'b0011;   // Enable motion highlight and HUD
        sw_security   <= 4'b0000;
        btn_scramble  <= 1'b0;
        threshold_adj <= 8'd30;
        frame_count   <= 0;

        // Reset sequence
        #100;
        reset <= 1'b0;
        #100;

        $display("========================================");
        $display("TopGun Lock-on System Testbench");
        $display("========================================");

        //----------------------------------------------------------------------
        // Test 1: Normal operation (no motion)
        //----------------------------------------------------------------------
        $display("\nTest 1: Normal operation - Background only");

        generate_frame(0);  // Background frame
        frame_count++;
        #1000;

        generate_frame(0);  // Another background frame
        frame_count++;
        #1000;

        $display("  Frame count: %d", frame_count);
        $display("  Motion detected: %b", led_motion);
        $display("  Lock-on status: %b", led_lock_on);

        //----------------------------------------------------------------------
        // Test 2: Motion detection
        //----------------------------------------------------------------------
        $display("\nTest 2: Motion detection test");

        generate_frame(1);  // Frame with moving object
        frame_count++;
        #1000;

        generate_frame(1);  // Same motion frame
        frame_count++;
        #1000;

        $display("  Frame count: %d", frame_count);
        $display("  Motion detected: %b", led_motion);
        $display("  Lock-on status: %b", led_lock_on);
        $display("  Target X: %d", target_x_out);
        $display("  Target Y: %d", target_y_out);

        //----------------------------------------------------------------------
        // Test 3: Scrambling test
        //----------------------------------------------------------------------
        $display("\nTest 3: Video scrambling test");

        btn_scramble <= 1'b1;
        #1000;

        generate_frame(1);
        frame_count++;
        #1000;

        $display("  Scramble active: %b", led_scramble);

        // Enter security code
        sw_security <= 4'b1010;
        #5000;

        $display("  Security code entered");
        $display("  Scramble active: %b", led_scramble);

        //----------------------------------------------------------------------
        // Test 4: Mode switching
        //----------------------------------------------------------------------
        $display("\nTest 4: Mode switching test");

        sw_mode <= 4'b0001;  // Motion highlight only
        generate_frame(1);
        #1000;

        sw_mode <= 4'b0010;  // HUD only
        generate_frame(1);
        #1000;

        sw_mode <= 4'b0011;  // Both enabled
        generate_frame(1);
        #1000;

        //----------------------------------------------------------------------
        // Test Complete
        //----------------------------------------------------------------------
        $display("\n========================================");
        $display("Testbench Complete");
        $display("Total frames processed: %d", frame_count);
        $display("========================================");

        #10000;
        $finish;
    end

    //==========================================================================
    // Monitoring
    //==========================================================================

    // Monitor VGA output
    always @(posedge vga_vsync) begin
        $display("[%0t] VGA Frame sync - Target: (%d, %d), Lock: %b, Motion: %b",
                 $time, target_x_out, target_y_out, led_lock_on, led_motion);
    end

    // Waveform dump
    initial begin
        $dumpfile("topgun_lockon.vcd");
        $dumpvars(0, tb_topgun_lockon);
    end

endmodule
