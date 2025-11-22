module I2C_top (
    input  logic       clk,
    input  logic       reset,
    input  logic       i2c_en,
    input  logic       i2c_start,
    input  logic       i2c_stop,
    input  logic [7:0] tx_data,
    output logic       tx_done,
    output logic       tx_ready,
    output logic [7:0] rx_data,
    output logic       rx_done,
    // slave to LED
    output logic [7:0] slv_reg1,   // ODR : Write data , connect to LED
    input  logic [7:0] slv_reg2,   // IDR : Read data, connect to switch
    output logic [3:0] led,
    output logic [7:0] temp_addr

);

    logic SCL; 
    wire SDA;

    I2C_Master dut_master (.*);

    I2C_Slave dut_slave (.*);


endmodule
