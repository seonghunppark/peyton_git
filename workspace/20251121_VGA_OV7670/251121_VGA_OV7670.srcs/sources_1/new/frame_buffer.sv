`timescale 1ns / 1ps


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

    // write side : 아무리 clk_gen을 camera쪽에 넣었다 하더라도 wclk과 rclk은 다르기때문에 frame buffer를 사용한 거다.
    // CDC 구간문제를 해결하기위해서 Framebuffer를 사용한 것이다.
    always_ff @(posedge wclk) begin
        if (we) mem[wAddr] <= wData;
    end

    // read side
    always_ff @(posedge rclk) begin
        if (oe) rData <= mem[rAddr];
    end

endmodule

