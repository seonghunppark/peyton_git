`timescale 1ns / 1ps

module I2C_Master (
    // global signal
    input logic clk,
    input logic reset,
    // AXI to I2C
    input logic i2c_en,
    input logic i2c_start,
    input logic i2c_stop,
    // Write
    input logic [7:0] tx_data,
    output logic tx_done,
    output logic tx_ready,
    // Read
    output logic [7:0] rx_data,
    output logic rx_done,
    // Master to Slave
    output logic SCL,
    inout logic SDA
);


    typedef enum {
        IDLE,
        START1,
        START2,
        WDATA1,
        WDATA2,
        WDATA3,
        WDATA4,
        RDATA1,
        RDATA2,
        RDATA3,
        RDATA4,
        WACK1,
        WACK2,
        WACK3,
        WACK4,
        RACK1,
        RACK2,
        RACK3,
        RACK4,
        HOLD,
        STOP1,
        STOP2

    } state_e;

    state_e state, state_next;
    logic SDA_reg;
    logic en;
    logic [7:0] rx_real_data, rx_real_data_next;
    logic temp_ACK_reg, temp_ACK_next;
    logic [7:0] temp_tx_data_reg, temp_tx_data_next;
    logic [7:0] temp_rx_data_reg, temp_rx_data_next;
    logic [$clog2(8)-1:0] bit_counter_reg, bit_counter_next;
    logic [$clog2(500)-1:0] clk_counter_reg, clk_counter_next;

    assign SDA     = en ? SDA_reg : 1'bz;
    assign rx_data = rx_real_data;
    // assign rx_data = temp_rx_data_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            temp_tx_data_reg <= 0;
            temp_rx_data_reg <= 0;
            temp_ACK_reg     <= 0;
            clk_counter_reg  <= 0;
            bit_counter_reg  <= 0;
            rx_real_data     <= 0;
        end else begin
            state            <= state_next;
            temp_tx_data_reg <= temp_tx_data_next;
            temp_rx_data_reg <= temp_rx_data_next;
            temp_ACK_reg     <= temp_ACK_next;
            clk_counter_reg  <= clk_counter_next;
            bit_counter_reg  <= bit_counter_next;
            rx_real_data     <= rx_real_data_next;
        end
    end

    always_comb begin
        SDA_reg           = 1'b1;
        SCL               = 1'b1;
        clk_counter_next  = clk_counter_reg;
        temp_tx_data_next = temp_tx_data_reg;
        temp_rx_data_next = temp_rx_data_reg;
        bit_counter_next  = bit_counter_reg;
        en                = 1'b1;
        tx_done           = 1'b0;
        tx_ready          = 1'b0;
        temp_ACK_next     = temp_ACK_reg;
        state_next        = state;
        rx_done           = 1'b0;
        rx_real_data_next = rx_real_data;
        case (state)
            IDLE: begin
                SDA_reg  = 1'b1;  // SDA는 항상 1로 유지하고 있다
                SCL      = 1'b1;  // SCL도 1로 유지
                tx_ready = 1'b1;
                if (i2c_en & i2c_start) begin  // i2c_en, start값이 들어오면
                    state_next = START1;  // start를 하고
                    temp_tx_data_next = tx_data;  // 보낼 data를 temp에 담는다. 

                end
            end
            START1: begin
                en = 1'b1; // en신호를 1로 올려서 SDA_reg를 SDA에 연결시키고
                SDA_reg = 1'b0;  // 우선 SDA를 0으로 내려서 스타트를 시키고
                SCL = 1'b1;  // 아직 SCL은 1로 유지
                if (clk_counter_reg == 499) begin
                    state_next = START2;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end

            end
            START2: begin
                en = 1'b1;  // 여전히 Master가 SDA 우선권
                SDA_reg = 1'b0;  // 0으로 유지 
                SCL = 1'b0;  // 이제 0으로 바꿔주고
                if (clk_counter_reg == 499) begin
                    state_next        = WDATA1;  //이제 주소를 보내주러 가야지
                    clk_counter_next  = 0;
                    temp_tx_data_next = tx_data;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            WDATA1: begin
                en = 1'b1;
                SDA_reg = temp_tx_data_reg[7];
                SCL = 1'b0;
                if (clk_counter_reg == 249) begin
                    state_next = WDATA2;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            WDATA2: begin
                en = 1'b1;
                SDA_reg = temp_tx_data_reg[7];
                SCL = 1'b1;
                if (clk_counter_reg == 249) begin
                    state_next = WDATA3;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end

            WDATA3: begin
                en = 1'b1;
                SDA_reg = temp_tx_data_reg[7];
                SCL = 1'b1;
                if (clk_counter_reg == 249) begin
                    state_next = WDATA4;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            WDATA4: begin
                en = 1'b1;
                SDA_reg = temp_tx_data_reg[7];
                SCL = 1'b0;
                if (clk_counter_reg == 249) begin
                    if (bit_counter_reg == 7) begin
                        bit_counter_next = 0;
                        clk_counter_next = 0;
                        state_next = WACK1;

                    end else begin
                        bit_counter_next = bit_counter_reg + 1;
                        clk_counter_next = 0;
                        state_next = WDATA1;
                        temp_tx_data_next = {temp_tx_data_reg[6:0], 1'b0};
                    end
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end

            end
            WACK1: begin
                en = 1'b0;  // 우선권을 Slave로 줘서 ACK신호를 받아야지
                SCL = 1'b0;
                SDA_reg = 1'b1;
                if (clk_counter_reg == 249) begin
                    state_next = WACK2;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end

            WACK2: begin
                en  = 1'b0;
                SCL = 1'b1;
                if (clk_counter_reg == 249) begin
                    state_next = WACK3;
                    clk_counter_next = 0;
                    temp_ACK_next = SDA;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            WACK3: begin
                en  = 1'b0;
                SCL = 1'b1;
                if (clk_counter_reg == 249) begin
                    state_next = WACK4;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end

            WACK4: begin
                en = 1'b1;
                SCL = 1'b0;
                SDA_reg = 1'b0;
                if (clk_counter_reg == 249) begin
                    if (temp_ACK_reg == 1'b0) begin
                        state_next       = HOLD;
                        clk_counter_next = 0;
                        tx_done          = 1'b1;
                        temp_ACK_next    = 1'b0;
                    end else begin  //이게 NACK인 거지
                        state_next       = STOP1;
                        tx_done          = 1'b1;
                        clk_counter_next = 0;
                        temp_ACK_next    = 1'b0;
                    end
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            HOLD: begin
                en       = 1'b1;
                SDA_reg  = 1'b0;
                SCL      = 1'b0;
                tx_ready = 1'b1;
                tx_done  = 1'b0;
                case ({
                    i2c_start, i2c_stop
                })
                    2'b00: begin
                        state_next        = WDATA1;
                        temp_tx_data_next = tx_data;
                    end
                    2'b01: state_next = STOP1;
                    2'b10: begin
                        state_next = IDLE;
                        temp_tx_data_next = tx_data;
                    end

                    2'b11: state_next = RDATA1;
                endcase
            end
            RDATA1: begin
                en  = 1'b0;
                SCL = 1'b0;
                if (clk_counter_reg == 249) begin
                    state_next = RDATA2;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            RDATA2: begin
                en  = 1'b0;
                SCL = 1'b1;
                if (clk_counter_reg == 249) begin
                    state_next = RDATA3;
                    temp_rx_data_next = {temp_rx_data_reg[6:0], SDA};
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            RDATA3: begin
                en  = 1'b0;
                SCL = 1'b1;
                if (clk_counter_reg == 249) begin
                    state_next = RDATA4;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            RDATA4: begin
                en  = 1'b0;
                SCL = 1'b0;
                if (clk_counter_reg == 249) begin
                    if (bit_counter_reg == 7) begin
                        bit_counter_next = 0;
                        clk_counter_next = 0;
                        state_next       = RACK1;
                        rx_done          = 1'b1;
                    end else begin
                        bit_counter_next = bit_counter_reg + 1;
                        clk_counter_next = 0;
                        state_next       = RDATA1;
                    end
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end

            RACK1: begin
                en = 1'b1;  // 우선권을 Slave로 줘서 ACK신호를 받아야지
                SCL = 1'b0;
                SDA_reg = 1'b0;
                if (clk_counter_reg == 249) begin
                    state_next = RACK2;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end

            RACK2: begin
                en = 1'b1;
                SCL = 1'b1;
                SDA_reg = 1'b0;
                if (clk_counter_reg == 249) begin
                    state_next = RACK3;
                    clk_counter_next = 0;
                    temp_ACK_next = SDA;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            RACK3: begin
                en = 1'b1;
                SCL = 1'b1;
                SDA_reg = 1'b0;
                if (clk_counter_reg == 249) begin
                    state_next = RACK4;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end

            RACK4: begin
                en = 1'b1;
                SCL = 1'b0;
                SDA_reg = 1'b0;
                if (clk_counter_reg == 249) begin
                    state_next        = RDATA1;
                    rx_done           = 1'b1;
                    rx_real_data_next = temp_rx_data_reg;
                    clk_counter_next  = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end


            STOP1: begin
                en = 1'b1;
                SDA_reg = 1'b0;
                SCL = 1'b1;
                if (clk_counter_reg == 249) begin
                    state_next = STOP2;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            STOP2: begin
                en = 1'b1;
                SDA_reg = 1'b1;
                SCL = 1'b1;
                if (clk_counter_reg == 249) begin
                    state_next = IDLE;
                    clk_counter_next = 0;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
        endcase
    end

endmodule
