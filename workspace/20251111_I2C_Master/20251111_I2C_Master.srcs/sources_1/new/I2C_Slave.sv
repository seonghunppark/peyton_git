`timescale 1ns / 1ps

module I2C_Slave (
    // global signal
    input logic clk,
    input logic reset,
    // Master to Slave
    input logic SCL,
    inout logic SDA,
    // slave to LED
    output logic [7:0] slv_reg0,  // control register : 필요한가?
    output logic [7:0] slv_reg1,  // ODR : Write data , connect to LED
    input logic [7:0] slv_reg2,  // IDR : Read data, connect to switch
    output logic [7:0] slv_reg3
);

    logic scl_sync0, scl_sync1;
    logic sda_sync0, sda_sync1;
    logic scl_rising, scl_falling;
    logic sda_rising, sda_falling;

    logic stop_condition;
    logic start_condition;

    //////// Synchronizer Edge Detector ////////////
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            scl_sync0 <= 0;
            sda_sync0 <= 0;
            scl_sync1 <= 0;
            sda_sync1 <= 0;
        end else begin
            scl_sync0 <= SCL;
            sda_sync0 <= SDA;
            scl_sync1 <= scl_sync0;
            sda_sync1 <= sda_sync0;
        end
    end

    assign scl_rising = scl_sync0 & ~scl_sync1;
    assign sda_rising = sda_sync0 & ~sda_sync1;
    assign scl_falling = ~scl_sync0 & scl_sync1;
    assign sda_falling = ~sda_sync0 & sda_sync1;
    // start & stop condition
    assign start_condition = sda_falling & scl_sync1;  // SDA : 1->0, SCL = 1
    assign stop_condition = sda_rising & scl_sync1;  // SDA : 0->1, SCL = 1


    //////// Synchronizer Edge Detector END ////////

    typedef enum {
        IDLE,
        START,
        ADDR,
        WRITE,
        READ,
        READ_ACK,
        WRITE_ACK1,
        WRITE_ACK2,
        HOLD,
        STOP
    } state_e;

    state_e state, state_next;

    logic SDA_reg;
    logic en;
    logic [7:0] temp_addr_next, temp_addr_reg;
    logic [7:0] temp_tx_data_next, temp_tx_data_reg;
    logic [7:0] temp_rx_data_next, temp_rx_data_reg;
    logic [2:0] bit_counter_next, bit_counter_reg;
    logic [7:0] slv_reg1_reg, slv_reg1_next;
    logic [7:0] slv_reg2_reg, slv_reg2_next;
    logic read_ack_next, read_ack_reg;

    assign SDA = en ? SDA_reg : 1'bz;
    assign slv_reg2_next = slv_reg2;


    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            read_ack_reg     <= 0;
            temp_tx_data_reg <= 0;
            temp_rx_data_reg <= 0;
            temp_addr_reg    <= 0;
            bit_counter_reg  <= 0;
            slv_reg1_reg     <= 0;
            slv_reg2_reg     <= 0;
        end else begin
            state            <= state_next;
            read_ack_reg     <= read_ack_next;
            temp_tx_data_reg <= temp_tx_data_next;
            temp_rx_data_reg <= temp_rx_data_next;
            temp_addr_reg    <= temp_addr_next;
            bit_counter_reg  <= bit_counter_next;
            slv_reg1_reg     <= slv_reg1_next;
            slv_reg2_reg     <= slv_reg2_next;
        end
    end



    always_comb begin
        state_next        = state;
        temp_rx_data_next = temp_rx_data_reg;
        temp_addr_next    = temp_addr_reg;
        bit_counter_next  = bit_counter_reg;
        temp_tx_data_next = temp_tx_data_reg;
        read_ack_next     = read_ack_reg;
        en                = 1'b0;
        SDA_reg           = 1'b1;
        case (state)
            IDLE: begin
                en = 1'b0;
                if (sda_falling & SCL) begin
                    state_next = START;
                end else begin
                    state_next = IDLE;
                end
            end
            START: begin
                if (scl_falling) begin
                    state_next = ADDR;
                end
            end

            ADDR: begin
                en = 1'b0;  // SDA를 받아야하니깐
                if (scl_rising) begin  // 이때 Data를 가져오고
                    temp_addr_next = {temp_addr_reg[6:0], SDA};
                end else if (scl_falling) begin  // 내려갔을 때 bit_count 올리고
                    if (bit_counter_reg == 7) begin
                        bit_counter_next = 0;
                        state_next = WRITE_ACK1;
                    end else begin
                        bit_counter_next = bit_counter_reg + 1;
                    end
                end
            end
            // 그냥 슬레이브 주소는 7'b0000_111으로 결정

            HOLD: begin
                en = 1'b0;
                SDA_reg = 1'b0;
                if (stop_condition) begin
                    state_next = STOP;
                end else if (scl_rising & sda_rising) begin
                    state_next = START;
                end else if (temp_addr_reg[7:1] == 7'b1010_100) begin
                    if (scl_rising) begin
                        if (temp_addr_reg[0]) begin
                            state_next = READ;
                            temp_tx_data_next = slv_reg2_reg; // reg, next 말고 바로 값을 넣어줘도 문제 없지 않을까. 추후 수정
                        end else begin
                            state_next = WRITE;
                        end
                    end
                end else begin
                    state_next = IDLE;
                end
            end

            READ: begin
                en = 1'b1;
                SDA_reg = temp_tx_data_reg[7];
                if (scl_falling) begin
                    if (bit_counter_reg == 7) begin
                        bit_counter_next = 0;
                        state_next = READ_ACK;
                        temp_tx_data_next = slv_reg2_reg;
                    end else begin
                        bit_counter_next  = bit_counter_reg + 1;
                        temp_tx_data_next = {temp_tx_data_reg[6:0], 1'b0};
                    end
                end
            end

            READ_ACK: begin
                en = 1'b0;
                if (scl_rising) begin
                    read_ack_next = SDA;
                end

                if (scl_falling) begin
                    if (read_ack_reg == 0) begin
                        state_next = HOLD;
                    end else begin
                        state_next = STOP;
                    end
                end
            end

            WRITE: begin
                en = 1'b0;
                if (scl_falling) begin
                    temp_rx_data_next = {temp_rx_data_reg[6:0], SDA};
                    if (bit_counter_reg == 7) begin
                        bit_counter_next = 0;
                        state_next = WRITE_ACK1;
                        slv_reg1_next = temp_rx_data_next;
                        // slv_reg1을 write data register로 사용하자
                    end else begin
                        bit_counter_next = bit_counter_reg + 1;
                    end
                end
            end

            WRITE_ACK1: begin
                en = 1'b0;
                SDA_reg = 1'b0;
                if (scl_rising) begin
                    state_next = WRITE_ACK2;
                end
            end
            WRITE_ACK2: begin
                en = 1'b0;
                SDA_reg = 1'b0;
                // 내보낼 ACK 신호를 0으로 만들고
                if (temp_addr_reg[7:1] == 7'b1010_100) begin
                    en = 1'b1;
                    SDA_reg = 1'b0;
                    if (scl_falling) begin
                        state_next = HOLD;
                    end
                end else begin
                    en = 1'b1;
                    SDA_reg = 1'b1;
                    state_next = STOP;  // NACK
                end

            end



            STOP: begin
                if (SCL & sda_rising) begin
                    state_next = IDLE;
                end
            end

        endcase

    end

endmodule
