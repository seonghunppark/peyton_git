`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Dual Frame Buffer
// Description: Stores current frame and previous frame for motion detection
//              Uses QQVGA resolution (160x120) for efficient processing
//              Ping-pong buffer architecture for smooth operation
//////////////////////////////////////////////////////////////////////////////////

module dual_frame_buffer #(
    parameter WIDTH  = 160,    // QQVGA width
    parameter HEIGHT = 120,    // QQVGA height
    parameter DEPTH  = WIDTH * HEIGHT  // 19200 pixels
)(
    // Write side (from camera, downscaled)
    input  logic        wclk,
    input  logic        reset,
    input  logic        we,
    input  logic [14:0] wAddr,     // log2(19200) = 15 bits
    input  logic [ 7:0] wData,     // Grayscale data
    input  logic        frame_done, // Signal when frame capture is complete

    // Read side (for motion detection)
    input  logic        rclk,
    input  logic        oe,
    input  logic [14:0] rAddr,
    output logic [ 7:0] curr_frame_data,  // Current frame data
    output logic [ 7:0] prev_frame_data,  // Previous frame data
    output logic        buffer_sel        // Current active buffer indicator
);

    // Dual buffer memories
    logic [7:0] buffer_A [0:DEPTH-1];
    logic [7:0] buffer_B [0:DEPTH-1];

    // Buffer select register (toggles each frame)
    logic buf_sel_reg;

    // Synchronize frame_done to write clock domain
    logic frame_done_sync1, frame_done_sync2;
    logic frame_done_edge;

    // Synchronizer for frame_done
    always_ff @(posedge wclk or posedge reset) begin
        if (reset) begin
            frame_done_sync1 <= 1'b0;
            frame_done_sync2 <= 1'b0;
        end else begin
            frame_done_sync1 <= frame_done;
            frame_done_sync2 <= frame_done_sync1;
        end
    end

    assign frame_done_edge = frame_done_sync1 & ~frame_done_sync2;

    // Buffer selection toggle on frame completion
    always_ff @(posedge wclk or posedge reset) begin
        if (reset) begin
            buf_sel_reg <= 1'b0;
        end else if (frame_done_edge) begin
            buf_sel_reg <= ~buf_sel_reg;
        end
    end

    assign buffer_sel = buf_sel_reg;

    // Write to active buffer
    always_ff @(posedge wclk) begin
        if (we) begin
            if (buf_sel_reg == 1'b0) begin
                buffer_A[wAddr] <= wData;
            end else begin
                buffer_B[wAddr] <= wData;
            end
        end
    end

    // Read from both buffers (current = write buffer, previous = other buffer)
    always_ff @(posedge rclk) begin
        if (oe) begin
            if (buf_sel_reg == 1'b0) begin
                curr_frame_data <= buffer_A[rAddr];
                prev_frame_data <= buffer_B[rAddr];
            end else begin
                curr_frame_data <= buffer_B[rAddr];
                prev_frame_data <= buffer_A[rAddr];
            end
        end
    end

endmodule
