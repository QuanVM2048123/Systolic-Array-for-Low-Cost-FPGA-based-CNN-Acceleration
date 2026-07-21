`timescale 1ns/1ps
module tb_pe;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;
    reg clk;
    reg rst_n;
    reg clear_acc;
    reg signed [DATA_WIDTH-1:0] a_in;
    reg signed [DATA_WIDTH-1:0] b_in;
    wire signed [DATA_WIDTH-1:0] a_out;
    wire signed [DATA_WIDTH-1:0] b_out;
    wire signed [ACC_WIDTH-1:0]  acc_out;
    pe #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .clear_acc (clear_acc),
        .a_in      (a_in),
        .b_in      (b_in),
        .a_out     (a_out),
        .b_out     (b_out),
        .acc_out   (acc_out)
    );
    initial clk = 0;
    always #5 clk = ~clk;
    initial begin
        rst_n = 0;
        clear_acc = 0;
        a_in = 0;
        b_in = 0;
        #12;
        rst_n = 1;
        #10;
        a_in = 3;  b_in = 4;
        #10;
        a_in = 5;  b_in = 6;
        #10;
        a_in = -2; b_in = 7;
        #10;
        clear_acc = 1;
        #10;
        clear_acc = 0;
        a_in = 2;  b_in = 2;
        #10;
        #20;
        $stop;
    end
    initial begin
        $monitor("time=%0t | a_in=%d b_in=%d | a_out=%d b_out=%d | acc_out=%d",
                   $time, a_in, b_in, a_out, b_out, acc_out);
    end
endmodule
