`timescale 1ns / 1ps


module tb_I2C_Master ();


    logic       clk;
    logic       reset;
    logic       i2c_en;
    logic       i2c_start;
    logic       i2c_stop;
    logic [7:0] tx_data;
    logic       tx_done;
    logic       tx_ready;
    logic [7:0] rx_data;
    logic       rx_done;
    logic       SCL;
    tri         SDA;
    logic [7:0] slv_reg0;
    logic [7:0] slv_reg1;
    logic [7:0] slv_reg2;
    logic [7:0] slv_reg3;




    I2C_Master dut_master (.*);

    I2C_Slave dut_slave (.*);

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        #10;
        reset = 0;
    end

    task automatic start_write(byte data);
        i2c_start = 1'b1;
        i2c_en = 1'b1;
        i2c_stop = 1'b0;
        @(posedge clk);
        tx_data   = data;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        i2c_start = 1'b0; // start:0, stop:0 -> WDATA 
        wait (tx_done);
    endtask  //automatic

    task automatic start_read(byte data);
        i2c_en = 1'b1;
        i2c_start = 1'b1;
        i2c_stop = 1'b0;
        tx_data = data;
        slv_reg2 = 8'h0f;
        @(posedge clk);
        @(posedge clk);
        wait(tx_done);
        i2c_start = 1'b0;
        i2c_stop = 1'b0;
        wait(tx_ready);
        i2c_stop = 1'b1;
        i2c_start = 1'b1;
        @(posedge clk);

        
    endtask //automatic

    task automatic stop();
    
        i2c_stop = 1'b1;
        i2c_start = 1'b0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
    endtask //automatic

    

    
    task automatic write(byte data);
        tx_data   = data;
        @(posedge clk);
        i2c_en = 1'b1;
        i2c_start = 1'b0;
        i2c_stop = 1'b0;
        @(posedge clk);
        wait (tx_done);
        i2c_stop = 1'b0;
    endtask  //automatic




    initial begin
        start_write(8'ha8);
        write(8'hff);
        write(8'h55);
        write(8'h11);
        start_read(8'ha9);
        #20;
        $finish;
    end




endmodule


