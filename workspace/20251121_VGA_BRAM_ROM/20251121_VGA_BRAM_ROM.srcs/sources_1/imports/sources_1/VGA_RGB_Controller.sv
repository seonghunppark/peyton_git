`timescale 1ns / 1ps

module VGA_RGB_Controller (
    input  logic       clk,
    input  logic       reset,
    input  logic       scale_sel,
    input  logic       mode_sel,
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port
);
    logic                         DE;
    logic [                  9:0] x_pixel;  // 0 ~ 800
    logic [                  9:0] y_pixel;  // 0 ~ 524
    logic [                  3:0] img_r;
    logic [                  3:0] img_g;
    logic [                  3:0] img_b;
    logic [                  3:0] img_r_qvga;
    logic [                  3:0] img_g_qvga;
    logic [                  3:0] img_b_qvga;
    logic [                  3:0] img_r_vga;
    logic [                  3:0] img_g_vga;
    logic [                  3:0] img_b_vga;
    logic [                  3:0] colorBar_r;
    logic [                  3:0] colorBar_g;
    logic [                  3:0] colorBar_b;
    logic [$clog2(320*240)-1 : 0] addr;
    logic [$clog2(320*240)-1 : 0] addr_qvga;
    logic [$clog2(320*240)-1 : 0] addr_vga;
    logic [                 15:0] imgData;
    logic [                 15:0] imgData_qvga;
    logic [                 15:0] imgData_vga;

    logic                         pclk;

    pixel_clk_gen U_Pixel_Clk_Gen (
        .*,
        .pclk(pclk)
    );


    VGA_Syncher U_VGA_Syncher (
        .clk(pclk),
        .*
    );

    ImgROM U_ROM (
        .clk (pclk),
        .addr(addr),
        .data(imgData)
    );

    demux_2x1 U_Demux (
        .sel   (scale_sel),
        .data  (imgData),
        .data_0(imgData_qvga),
        .data_1(imgData_vga)
    );

    mux_2x1 #(
        .BIT_SIZE(17)
    ) U_MUX_Addr (
        .sel  (scale_sel),
        .rgb_0(addr_qvga),
        .rgb_1(addr_vga),
        .rgb  (addr)
    );

    ImgMemReader U_ImgMemReader (
        .*,
        .addr   (addr_qvga),
        .imgData(imgData_qvga),
        .r_port (img_r_qvga),
        .g_port (img_g_qvga),
        .b_port (img_b_qvga)
    );

    ImgMemReader_upscaler U_ImgMemReader_Upscaler (
        .*,
        .addr   (addr_vga),
        .imgData(imgData_vga),
        .r_port (img_r_vga),
        .g_port (img_g_vga),
        .b_port (img_b_vga)
    );

    mux_2x1 #(
        .BIT_SIZE(12)
    ) U_MUX_Scale (
        .sel  (scale_sel),
        .rgb_0({img_r_qvga, img_g_qvga, img_b_qvga}),
        .rgb_1({img_r_vga, img_g_vga, img_b_vga}),
        .rgb  ({img_r, img_g, img_b})
    );

    VGA_ColorBar U_VGA_ColorBar (
        .*,
        .red_port  (colorBar_r),
        .green_port(colorBar_g),
        .blue_port (colorBar_b)
    );

    mux_2x1 #(
        .BIT_SIZE(12)
    ) U_MUX_Mode (
        .sel  (mode_sel),
        .rgb_0({colorBar_r, colorBar_g, colorBar_b}),
        .rgb_1({img_r, img_g, img_b}),
        .rgb  ({r_port, g_port, b_port})
    );
endmodule

module mux_2x1 #(
    parameter BIT_SIZE = 12
) (
    input  logic                sel,
    input  logic [BIT_SIZE-1:0] rgb_0,
    input  logic [BIT_SIZE-1:0] rgb_1,
    output logic [BIT_SIZE-1:0] rgb
);
    always_comb begin
        rgb = 0;
        case (sel)
            1'b0: rgb = rgb_0;
            1'b1: rgb = rgb_1;
        endcase
    end
endmodule

module pixel_clk_gen (
    input  logic clk,
    input  logic reset,
    output logic pclk
);
    logic [1:0] p_counter;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            p_counter <= 0;
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

module demux_2x1 (
    input  logic        sel,
    input  logic [15:0] data,
    output logic [15:0] data_0,
    output logic [15:0] data_1
);
    always_comb begin
        data_0 = 0;
        data_1 = 0;
        case (sel)
            1'b0: data_0 = data;
            1'b1: data_1 = data;
        endcase
    end
endmodule
