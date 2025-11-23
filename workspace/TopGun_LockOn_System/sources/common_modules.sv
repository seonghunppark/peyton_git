`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Common Modules for TopGun Lock-on System
// Description: Shared utility modules used across the system
//////////////////////////////////////////////////////////////////////////////////

//================================================================================
// Pixel Clock Generator (100MHz -> 25MHz for VGA)
//================================================================================
module pixel_clk_gen (
    input  logic clk,
    input  logic reset,
    output logic pclk
);
    logic [1:0] p_counter;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            p_counter <= 0;
            pclk      <= 1'b0;
        end else begin
            if (p_counter == 3) begin
                p_counter <= 0;
                pclk      <= 1'b1;
            end else begin
                p_counter <= p_counter + 1;
                pclk      <= 1'b0;
            end
        end
    end
endmodule

//================================================================================
// VGA Timing Generator (Syncher)
//================================================================================
module VGA_Syncher (
    input  logic       clk,
    input  logic       reset,
    output logic       h_sync,
    output logic       v_sync,
    output logic       DE,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel
);
    logic [9:0] h_counter;
    logic [9:0] v_counter;

    pixel_counter U_Pixel_Counter (.*);
    vgaDecoder U_VGA_Decoder (.*);
endmodule

module pixel_counter (
    input  logic       clk,
    input  logic       reset,
    output logic [9:0] h_counter,
    output logic [9:0] v_counter
);
    localparam H_MAX = 800, V_MAX = 525;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            h_counter <= 0;
        end else begin
            if (h_counter == H_MAX - 1) begin
                h_counter <= 0;
            end else begin
                h_counter <= h_counter + 1;
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            v_counter <= 0;
        end else begin
            if (h_counter == H_MAX - 1) begin
                if (v_counter == V_MAX - 1) begin
                    v_counter <= 0;
                end else begin
                    v_counter <= v_counter + 1;
                end
            end
        end
    end
endmodule

module vgaDecoder (
    input  logic [9:0] h_counter,
    input  logic [9:0] v_counter,
    output logic       h_sync,
    output logic       v_sync,
    output logic       DE,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel
);

    localparam H_Visible_area = 640;
    localparam H_Front_porch = 16;
    localparam H_Sync_pulse = 96;
    localparam H_Back_porch = 48;

    localparam V_Visible_area = 480;
    localparam V_Front_porch = 10;
    localparam V_Sync_pulse = 2;
    localparam V_Back_porch = 33;

    assign h_sync = !((h_counter >= H_Visible_area + H_Front_porch) &&
                      (h_counter < H_Visible_area + H_Front_porch + H_Sync_pulse));
    assign v_sync = !((v_counter >= V_Visible_area + V_Front_porch) &&
                      (v_counter < V_Visible_area + V_Front_porch + V_Sync_pulse));
    assign DE = (h_counter < H_Visible_area) && (v_counter < V_Visible_area);
    assign x_pixel = h_counter;
    assign y_pixel = v_counter;

endmodule

//================================================================================
// Frame Buffer (Dual-Port RAM)
//================================================================================
module frame_buffer (
    // write side
    input  logic        wclk,
    input  logic        we,
    input  logic [16:0] wAddr,
    input  logic [15:0] wData,
    // read side
    input  logic        rclk,
    input  logic        oe,
    input  logic [16:0] rAddr,
    output logic [15:0] rData
);

    logic [15:0] mem[0:(320*240)-1];

    // write side
    always_ff @(posedge wclk) begin
        if (we) mem[wAddr] <= wData;
    end

    // read side
    always_ff @(posedge rclk) begin
        if (oe) rData <= mem[rAddr];
    end

endmodule

//================================================================================
// OV7670 Memory Controller
//================================================================================
module OV7670_Mem_controller (
    input  logic        pclk,
    input  logic        reset,
    input  logic        href,
    input  logic        vsync,
    input  logic [ 7:0] data,
    output logic        we,
    output logic [16:0] wAddr,
    output logic [15:0] wData
);

    logic [17:0] pixelCounter;
    logic [15:0] pixelData;

    assign wData = pixelData;

    always_ff @(posedge pclk) begin
        if (reset) begin
            pixelCounter <= 0;
            pixelData    <= 0;
            we           <= 1'b0;
            wAddr        <= 0;
        end else begin
            if (href) begin
                if (pixelCounter[0] == 1'b0) begin
                    we              <= 1'b0;
                    pixelData[15:8] <= data;
                end else begin
                    we             <= 1'b1;
                    pixelData[7:0] <= data;
                    wAddr          <= wAddr + 1;
                end
                pixelCounter <= pixelCounter + 1;
            end else if (vsync) begin
                we           <= 1'b0;
                wAddr        <= 0;
                pixelCounter <= 0;
            end
        end
    end

endmodule

//================================================================================
// Image Memory Reader with Upscaling (320x240 -> 640x480)
//================================================================================
module ImgMemReader_upscaler (
    input  logic                         DE,
    input  logic [                  9:0] x_pixel,
    input  logic [                  9:0] y_pixel,
    output logic [$clog2(320*240)-1 : 0] addr,
    input  logic [                 15:0] imgData,
    output logic [                  3:0] r_port,
    output logic [                  3:0] g_port,
    output logic [                  3:0] b_port
);

    assign addr = DE ? (320 * y_pixel[9:1] + x_pixel[9:1]) : 'bz;
    assign {r_port, g_port, b_port} = DE ? {imgData[15:12], imgData[10:7], imgData[4:1]} : 0;

endmodule

//================================================================================
// Edge Detector (Rising/Falling)
//================================================================================
module edge_detector (
    input  logic clk,
    input  logic reset,
    input  logic signal_in,
    output logic rising_edge,
    output logic falling_edge
);
    logic signal_d;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            signal_d <= 1'b0;
        end else begin
            signal_d <= signal_in;
        end
    end

    assign rising_edge  = signal_in & ~signal_d;
    assign falling_edge = ~signal_in & signal_d;

endmodule

//================================================================================
// Debouncer for button/switch inputs
//================================================================================
module debouncer #(
    parameter DEBOUNCE_TIME = 250000  // 2.5ms at 100MHz
)(
    input  logic clk,
    input  logic reset,
    input  logic btn_in,
    output logic btn_out
);
    logic [17:0] counter;
    logic        btn_sync1, btn_sync2;
    logic        btn_stable;

    // Synchronizer
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            btn_sync1 <= 1'b0;
            btn_sync2 <= 1'b0;
        end else begin
            btn_sync1 <= btn_in;
            btn_sync2 <= btn_sync1;
        end
    end

    // Debounce counter
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            counter    <= 18'd0;
            btn_stable <= 1'b0;
            btn_out    <= 1'b0;
        end else begin
            if (btn_sync2 != btn_stable) begin
                counter <= counter + 1;
                if (counter >= DEBOUNCE_TIME) begin
                    btn_stable <= btn_sync2;
                    btn_out    <= btn_sync2;
                    counter    <= 18'd0;
                end
            end else begin
                counter <= 18'd0;
            end
        end
    end

endmodule
