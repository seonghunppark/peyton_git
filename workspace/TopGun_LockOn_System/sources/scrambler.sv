`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Video Scrambler/Descrambler
// Description: Encrypts video data for secure transmission
//              Supports multiple scrambling modes:
//              (1) Fixed XOR key
//              (2) 4th order polynomial LFSR
//              (3) 8th order polynomial LFSR
//////////////////////////////////////////////////////////////////////////////////

module video_scrambler #(
    parameter MODE = 2  // 0: Fixed XOR, 1: 4th order LFSR, 2: 8th order LFSR
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,          // Enable scrambling
    input  logic        frame_sync,      // Frame synchronization (resets LFSR)
    input  logic [1:0]  mode_select,     // Runtime mode selection
    input  logic [15:0] fixed_key,       // Fixed XOR key for mode 0
    input  logic [15:0] pixel_in,        // Input pixel data (RGB565)
    output logic [15:0] pixel_out,       // Scrambled/Descrambled output
    output logic        valid_out
);

    // LFSR registers
    logic [3:0]  lfsr_4bit;   // 4th order LFSR
    logic [7:0]  lfsr_8bit;   // 8th order LFSR
    logic [15:0] scramble_key;

    // 4th order polynomial: x^4 + x^3 + 1 (taps at 4,3)
    // Generates 15-state sequence before repeating
    wire lfsr4_feedback = lfsr_4bit[3] ^ lfsr_4bit[2];

    // 8th order polynomial: x^8 + x^6 + x^5 + x^4 + 1 (taps at 8,6,5,4)
    // Generates 255-state sequence before repeating
    wire lfsr8_feedback = lfsr_8bit[7] ^ lfsr_8bit[5] ^ lfsr_8bit[4] ^ lfsr_8bit[3];

    // LFSR state machine
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            lfsr_4bit <= 4'b1010;   // Non-zero seed
            lfsr_8bit <= 8'b10110100;  // Non-zero seed
        end else if (frame_sync) begin
            // Reset LFSR at frame boundary for synchronization
            lfsr_4bit <= 4'b1010;
            lfsr_8bit <= 8'b10110100;
        end else if (enable) begin
            // Shift LFSR
            lfsr_4bit <= {lfsr_4bit[2:0], lfsr4_feedback};
            lfsr_8bit <= {lfsr_8bit[6:0], lfsr8_feedback};
        end
    end

    // Generate scramble key based on mode
    always_comb begin
        case (mode_select)
            2'b00: scramble_key = fixed_key;
            2'b01: scramble_key = {lfsr_4bit, lfsr_4bit, lfsr_4bit, lfsr_4bit}; // Replicate 4-bit
            2'b10: scramble_key = {lfsr_8bit, lfsr_8bit};  // Replicate 8-bit
            2'b11: scramble_key = {lfsr_8bit, lfsr_4bit, lfsr_4bit}; // Combined
            default: scramble_key = 16'h0000;
        endcase
    end

    // XOR scrambling (symmetric - same operation for scramble and descramble)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pixel_out <= 16'd0;
            valid_out <= 1'b0;
        end else if (enable) begin
            pixel_out <= pixel_in ^ scramble_key;
            valid_out <= 1'b1;
        end else begin
            pixel_out <= pixel_in;  // Pass through when disabled
            valid_out <= 1'b1;
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: Advanced Scrambler with Bit Permutation
// Description: More secure scrambling using bit permutation + XOR
//////////////////////////////////////////////////////////////////////////////////

module advanced_scrambler (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        scramble_mode,   // 1: scramble, 0: descramble
    input  logic        frame_sync,
    input  logic [15:0] pixel_in,
    input  logic [7:0]  key_byte,        // External key input
    output logic [15:0] pixel_out,
    output logic        valid_out
);

    // 8-bit LFSR with polynomial x^8 + x^6 + x^5 + x^4 + 1
    logic [7:0] lfsr;
    wire lfsr_fb = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

    // Permutation lookup (barrel shifter based on LFSR)
    logic [15:0] permuted_data;
    logic [15:0] xor_scrambled;
    logic [3:0]  shift_amount;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            lfsr <= key_byte ^ 8'hA5;  // Initialize with key
        end else if (frame_sync) begin
            lfsr <= key_byte ^ 8'hA5;
        end else if (enable) begin
            lfsr <= {lfsr[6:0], lfsr_fb};
        end
    end

    assign shift_amount = lfsr[3:0];

    // Bit rotation (barrel shift)
    always_comb begin
        if (scramble_mode) begin
            // Scramble: rotate left by shift_amount
            permuted_data = (pixel_in << shift_amount) | (pixel_in >> (16 - shift_amount));
        end else begin
            // Descramble: rotate right by shift_amount
            permuted_data = (pixel_in >> shift_amount) | (pixel_in << (16 - shift_amount));
        end
    end

    // XOR with expanded LFSR value
    assign xor_scrambled = permuted_data ^ {lfsr, lfsr};

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pixel_out <= 16'd0;
            valid_out <= 1'b0;
        end else if (enable) begin
            pixel_out <= xor_scrambled;
            valid_out <= 1'b1;
        end else begin
            pixel_out <= pixel_in;
            valid_out <= 1'b1;
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: Scrambler Controller
// Description: Controls scrambling based on switch/key input
//              Manages secure display mode
//////////////////////////////////////////////////////////////////////////////////

module scrambler_controller (
    input  logic        clk,
    input  logic        reset,
    input  logic [3:0]  key_input,       // Physical key/switch input
    input  logic [3:0]  security_code,   // Expected security code
    input  logic        enable_scramble, // Master scramble enable
    output logic        scramble_active, // Scrambling is active
    output logic        descramble_key_valid, // Correct key entered
    output logic [1:0]  scramble_mode    // Current scramble mode
);

    // Key validation state machine
    typedef enum logic [1:0] {
        LOCKED,
        VALIDATING,
        UNLOCKED
    } state_t;

    state_t state;
    logic [7:0] unlock_timer;

    // Key validation
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state               <= LOCKED;
            scramble_active     <= 1'b0;
            descramble_key_valid <= 1'b0;
            scramble_mode       <= 2'b10;  // Default: 8th order LFSR
            unlock_timer        <= 8'd0;
        end else begin
            case (state)
                LOCKED: begin
                    scramble_active <= enable_scramble;
                    descramble_key_valid <= 1'b0;

                    if (key_input == security_code) begin
                        state <= VALIDATING;
                        unlock_timer <= 8'd100;  // Debounce timer
                    end
                end

                VALIDATING: begin
                    if (unlock_timer > 0) begin
                        unlock_timer <= unlock_timer - 1;
                    end else begin
                        if (key_input == security_code) begin
                            state <= UNLOCKED;
                            descramble_key_valid <= 1'b1;
                            scramble_active <= 1'b0;  // Disable scrambling
                        end else begin
                            state <= LOCKED;
                        end
                    end
                end

                UNLOCKED: begin
                    descramble_key_valid <= 1'b1;
                    scramble_active <= 1'b0;

                    // Re-lock if key is released
                    if (key_input != security_code) begin
                        state <= LOCKED;
                        descramble_key_valid <= 1'b0;
                        scramble_active <= enable_scramble;
                    end
                end

                default: state <= LOCKED;
            endcase

            // Mode selection based on upper bits of key
            scramble_mode <= key_input[3:2];
        end
    end

endmodule
