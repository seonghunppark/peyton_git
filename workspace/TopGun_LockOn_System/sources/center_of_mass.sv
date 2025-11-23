`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Center of Mass Calculator
// Description: Calculates centroid (center of mass) of detected motion area
//              Uses weighted average: X_c = Sum(x*m)/Sum(m), Y_c = Sum(y*m)/Sum(m)
//              Operates over QQVGA (160x120) resolution for efficiency
//////////////////////////////////////////////////////////////////////////////////

module center_of_mass #(
    parameter WIDTH  = 160,
    parameter HEIGHT = 120,
    parameter MIN_PIXEL_COUNT = 50  // Minimum pixels to consider valid target
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        frame_start,    // Start of new frame
    input  logic        pixel_valid,    // Valid motion pixel input
    input  logic        motion_pixel,   // 1 = motion detected at this pixel
    input  logic [7:0]  x_coord,        // Current X coordinate
    input  logic [6:0]  y_coord,        // Current Y coordinate

    output logic [7:0]  target_x,       // Target center X coordinate
    output logic [6:0]  target_y,       // Target center Y coordinate
    output logic        target_valid,   // Target detected and coordinates valid
    output logic [15:0] pixel_count,    // Number of motion pixels detected
    output logic        calc_done       // Calculation complete signal
);

    // Accumulators for centroid calculation
    logic [23:0] sum_x;         // Sum of x coordinates (max: 160*19200 = 3,072,000)
    logic [23:0] sum_y;         // Sum of y coordinates (max: 120*19200 = 2,304,000)
    logic [15:0] sum_pixels;    // Total motion pixels (max: 19200)

    // Division results
    logic [7:0] center_x_reg;
    logic [6:0] center_y_reg;
    logic       valid_reg;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        ACCUMULATE,
        CALCULATE,
        OUTPUT,
        DONE
    } state_t;

    state_t state, next_state;

    // Division counter (for iterative division)
    logic [4:0] div_counter;
    logic [23:0] dividend_x, dividend_y;
    logic [15:0] divisor;
    logic [7:0] quotient_x;
    logic [6:0] quotient_y;

    // State register
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (frame_start) next_state = ACCUMULATE;
            end
            ACCUMULATE: begin
                // Wait for frame_start again (end of current frame processing)
                if (frame_start && sum_pixels > 0) next_state = CALCULATE;
            end
            CALCULATE: begin
                if (div_counter == 5'd20) next_state = OUTPUT;
            end
            OUTPUT: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Accumulation logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sum_x      <= 24'd0;
            sum_y      <= 24'd0;
            sum_pixels <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (frame_start) begin
                        sum_x      <= 24'd0;
                        sum_y      <= 24'd0;
                        sum_pixels <= 16'd0;
                    end
                end
                ACCUMULATE: begin
                    if (pixel_valid && motion_pixel) begin
                        sum_x      <= sum_x + {16'd0, x_coord};
                        sum_y      <= sum_y + {17'd0, y_coord};
                        sum_pixels <= sum_pixels + 1'b1;
                    end
                end
                default: ;
            endcase
        end
    end

    // Division logic (iterative subtract-shift division)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            div_counter <= 5'd0;
            dividend_x  <= 24'd0;
            dividend_y  <= 24'd0;
            divisor     <= 16'd1;
            quotient_x  <= 8'd0;
            quotient_y  <= 7'd0;
        end else begin
            case (state)
                ACCUMULATE: begin
                    if (next_state == CALCULATE) begin
                        dividend_x  <= sum_x;
                        dividend_y  <= sum_y;
                        divisor     <= (sum_pixels > 0) ? sum_pixels : 16'd1;
                        quotient_x  <= 8'd0;
                        quotient_y  <= 7'd0;
                        div_counter <= 5'd0;
                    end
                end
                CALCULATE: begin
                    // Simple division using repeated subtraction (for synthesis)
                    // In practice, you might use IP core for faster division
                    if (div_counter < 5'd20) begin
                        div_counter <= div_counter + 1;
                        // Compute quotient_x = dividend_x / divisor
                        if (dividend_x >= {8'd0, divisor}) begin
                            dividend_x <= dividend_x - {8'd0, divisor};
                            quotient_x <= quotient_x + 1'b1;
                        end
                        if (dividend_y >= {8'd0, divisor}) begin
                            dividend_y <= dividend_y - {8'd0, divisor};
                            quotient_y <= quotient_y + 1'b1;
                        end
                    end
                end
                default: ;
            endcase
        end
    end

    // Output logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            target_x     <= 8'd0;
            target_y     <= 7'd0;
            target_valid <= 1'b0;
            pixel_count  <= 16'd0;
            calc_done    <= 1'b0;
            center_x_reg <= 8'd0;
            center_y_reg <= 7'd0;
            valid_reg    <= 1'b0;
        end else begin
            case (state)
                OUTPUT: begin
                    if (sum_pixels >= MIN_PIXEL_COUNT) begin
                        // Use simple average calculation for synthesis
                        target_x     <= sum_x[23:16] / (sum_pixels[15:8] + 1);  // Simplified
                        target_y     <= sum_y[22:16] / (sum_pixels[15:8] + 1);  // Simplified
                        // Better approach: use actual quotients
                        center_x_reg <= quotient_x;
                        center_y_reg <= quotient_y;
                        target_valid <= 1'b1;
                        valid_reg    <= 1'b1;
                    end else begin
                        target_valid <= 1'b0;
                        valid_reg    <= 1'b0;
                    end
                    pixel_count <= sum_pixels;
                    calc_done   <= 1'b1;
                end
                DONE: begin
                    calc_done    <= 1'b0;
                    target_x     <= center_x_reg;
                    target_y     <= center_y_reg;
                    target_valid <= valid_reg;
                end
                default: begin
                    calc_done <= 1'b0;
                end
            endcase
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: Bounding Box Calculator
// Description: Calculates min/max coordinates of motion region
//              Provides bounding box for lock-on display
//////////////////////////////////////////////////////////////////////////////////

module bounding_box #(
    parameter WIDTH  = 160,
    parameter HEIGHT = 120
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        frame_start,
    input  logic        pixel_valid,
    input  logic        motion_pixel,
    input  logic [7:0]  x_coord,
    input  logic [6:0]  y_coord,

    output logic [7:0]  box_x_min,
    output logic [7:0]  box_x_max,
    output logic [6:0]  box_y_min,
    output logic [6:0]  box_y_max,
    output logic        box_valid
);

    // Working registers
    logic [7:0] x_min_reg, x_max_reg;
    logic [6:0] y_min_reg, y_max_reg;
    logic       first_pixel;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x_min_reg   <= 8'hFF;
            x_max_reg   <= 8'h00;
            y_min_reg   <= 7'h7F;
            y_max_reg   <= 7'h00;
            first_pixel <= 1'b1;
            box_valid   <= 1'b0;
        end else begin
            if (frame_start) begin
                // Latch previous results and reset for new frame
                box_x_min   <= x_min_reg;
                box_x_max   <= x_max_reg;
                box_y_min   <= y_min_reg;
                box_y_max   <= y_max_reg;
                box_valid   <= (x_max_reg > x_min_reg) && (y_max_reg > y_min_reg);

                // Reset for new frame
                x_min_reg   <= 8'hFF;
                x_max_reg   <= 8'h00;
                y_min_reg   <= 7'h7F;
                y_max_reg   <= 7'h00;
                first_pixel <= 1'b1;
            end else if (pixel_valid && motion_pixel) begin
                first_pixel <= 1'b0;

                // Update min values
                if (x_coord < x_min_reg) x_min_reg <= x_coord;
                if (y_coord < y_min_reg) y_min_reg <= y_coord;

                // Update max values
                if (x_coord > x_max_reg) x_max_reg <= x_coord;
                if (y_coord > y_max_reg) y_max_reg <= y_coord;
            end
        end
    end

endmodule
