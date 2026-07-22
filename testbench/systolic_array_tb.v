`timescale 1ns/1ps
module tb_systolic_array;
    parameter N          = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;
    reg                             clk;
    reg                             rst_n;
    reg                             clear_acc;
    reg  signed [N*DATA_WIDTH-1:0]  a_in;
    reg  signed [N*DATA_WIDTH-1:0]  b_in;
    wire signed [N*N*ACC_WIDTH-1:0] acc_out;
    systolic_array #(
        .N          (N),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .clear_acc (clear_acc),
        .a_in      (a_in),
        .b_in      (b_in),
        .acc_out   (acc_out)
    );
    initial clk = 0;
    always #5 clk = ~clk;
    initial begin
        rst_n     = 0;
        clear_acc = 0;
        a_in      = 0;
        b_in      = 0;
        #12;
        rst_n = 1;
        #10;
        a_in = {8'd4, 8'd3, 8'd2, 8'd1};
        b_in = {8'd8, 8'd7, 8'd6, 8'd5};
        #10;
        a_in = {8'd1, 8'd1, 8'd1, 8'd1};
        b_in = {8'd2, 8'd2, 8'd2, 8'd2};
        #10;
        a_in = 0;
        b_in = 0;
        #100;
        clear_acc = 1;
        #10;
        clear_acc = 0;
        #20;
        $stop;
    end
    initial begin
        $monitor("time=%0t | a_in=%h | b_in=%h | acc_out=%h", $time, a_in, b_in, acc_out);
    end
endmodule
