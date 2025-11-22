`timescale 1ns / 1ps

module VGA_ColorBar(
    input  logic       DE,
    input  logic [9:0] x_pixel,         // 0 ~ 800
    input  logic [9:0] y_pixel,         // 0 ~ 524
    output logic [3:0] red_port,
    output logic [3:0] green_port,
    output logic [3:0] blue_port
);

    localparam H_VISIBLE_AREA = 640;
    localparam H_WHOLE_LINE = 800;

    localparam V_VISIBLE_AREA = 480;
    localparam V_WHOLE_FRAME = 525;

    localparam WHITE_R = 4'hf, WHITE_G = 4'hf, WHITE_B = 4'hf;
    localparam YELLOW_R = 4'hf, YELLOW_G = 4'hf, YELLOW_B = 4'h0;
    localparam CYAN_R = 4'h0, CYAN_G = 4'hf, CYAN_B = 4'hf;
    localparam GREEN_R = 4'h0, GREEN_G = 4'hf, GREEN_B = 4'h0;
    localparam MAGENTA_R = 4'hf, MAGENTA_G = 4'h0, MAGENTA_B = 4'hf;
    localparam RED_R = 4'hf, RED_G = 4'h0, RED_B = 4'h0;
    localparam BLUE_R = 4'h0, BLUE_G = 4'h0, BLUE_B = 4'hf;
    localparam BLACK_R = 4'h0, BLACK_G = 4'h0, BLACK_B = 4'h0;
    localparam GRAY_R = 4'h7, GRAY_G = 4'h7, GRAY_B = 4'h7;
    localparam LGRAY_R = 4'ha, LGRAY_G = 4'ha, LGRAY_B = 4'ha;
    localparam DGRAY_R = 4'h2, DGRAY_G = 4'h2, DGRAY_B = 4'h2;
    localparam NAVY_R = 4'h2, NAVY_G = 4'h5, NAVY_B = 4'h8;
    localparam PURPLE_R = 4'h5, PURPLE_G = 4'h2, PURPLE_B = 4'ha;

    always_comb begin
        if (DE) begin
            if (y_pixel >= 0 && y_pixel < 320) begin
                if (x_pixel >= 0 && x_pixel < 91) begin
                    red_port   = WHITE_R;
                    green_port = WHITE_G;
                    blue_port  = WHITE_B;
                end else if (x_pixel >= 91 && x_pixel < 182) begin
                    red_port   = YELLOW_R;
                    green_port = YELLOW_G;
                    blue_port  = YELLOW_B;
                end else if (x_pixel >= 182 && x_pixel < 273) begin
                    red_port   = CYAN_R;
                    green_port = CYAN_G;
                    blue_port  = CYAN_B;
                end else if (x_pixel >= 273 && x_pixel < 364) begin
                    red_port   = GREEN_R;
                    green_port = GREEN_G;
                    blue_port  = GREEN_B;
                end else if (x_pixel >= 364 && x_pixel < 455) begin
                    red_port   = MAGENTA_R;
                    green_port = MAGENTA_G;
                    blue_port  = MAGENTA_B;
                end else if (x_pixel >= 455 && x_pixel < 546) begin
                    red_port   = RED_R;
                    green_port = RED_G;
                    blue_port  = RED_B;
                end else if (x_pixel >= 546 && x_pixel < 640) begin
                    red_port   = BLUE_R;
                    green_port = BLUE_G;
                    blue_port  = BLUE_B;
                end else begin
                    red_port   = BLACK_R;
                    green_port = BLACK_G;
                    blue_port  = BLACK_B;
                end
            end else if (y_pixel >= 320 && y_pixel < 360) begin
                if (x_pixel >= 0 && x_pixel < 91) begin
                    red_port   = BLUE_R;
                    green_port = BLUE_G;
                    blue_port  = BLUE_B;
                end else if (x_pixel >= 182 && x_pixel < 273) begin
                    red_port   = MAGENTA_R;
                    green_port = MAGENTA_G;
                    blue_port  = MAGENTA_B;
                end else if (x_pixel >= 364 && x_pixel < 455) begin
                    red_port   = CYAN_R;
                    green_port = CYAN_G;
                    blue_port  = CYAN_B;
                end else if (x_pixel >= 546 && x_pixel < 640) begin
                    red_port   = WHITE_R;
                    green_port = WHITE_G;
                    blue_port  = WHITE_B;
                end else begin
                    red_port   = BLACK_R;
                    green_port = BLACK_G;
                    blue_port  = BLACK_B;
                end
            end else begin
                if (x_pixel >= 0 && x_pixel < 106) begin
                    red_port   = NAVY_R;
                    green_port = NAVY_G;
                    blue_port  = NAVY_B;
                end else if (x_pixel >= 106 && x_pixel < 212) begin
                    red_port   = WHITE_R;
                    green_port = WHITE_G;
                    blue_port  = WHITE_B;
                end else if (x_pixel >= 212 && x_pixel < 318) begin
                    red_port   = PURPLE_R;
                    green_port = PURPLE_G;
                    blue_port  = PURPLE_B;
                end else if (x_pixel >= 318 && x_pixel < 424) begin
                    red_port   = DGRAY_R;
                    green_port = DGRAY_G;
                    blue_port  = DGRAY_B;
                end else if (x_pixel >= 424 && x_pixel < 459) begin
                    red_port   = BLACK_R;
                    green_port = BLACK_G;
                    blue_port  = BLACK_B;
                end else if (x_pixel >= 459 && x_pixel < 494) begin
                    red_port   = DGRAY_R;
                    green_port = DGRAY_G;
                    blue_port  = DGRAY_B;
                end else if (x_pixel >= 494 && x_pixel < 530) begin
                    red_port   = GRAY_R;
                    green_port = GRAY_G;
                    blue_port  = GRAY_B;
                end else begin
                    red_port   = BLACK_R;
                    green_port = BLACK_G;
                    blue_port  = BLACK_B;
                end
            end
        end else begin
            red_port   = BLACK_R;
            green_port = BLACK_G;
            blue_port  = BLACK_B;
        end
    end

endmodule
