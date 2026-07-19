`timescale 1ns/1ps
module tb_skew_buffer;
    parameter N     = 4;
    parameter WIDTH = 8;
    reg                      clk;
    reg                      rst_n;
    reg  signed [N*WIDTH-1:0] data_in;
    wire signed [N*WIDTH-1:0] data_out;
    skew_buffer #(
        .N     (N),
        .WIDTH (WIDTH)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (data_in),
        .data_out (data_out)
    );
    initial clk = 0;
    always #5 clk = ~clk;
    initial begin
        rst_n = 0;
        data_in = 0;
        #12;
        rst_n = 1;
        data_in = {8'd4, 8'd3, 8'd2, 8'd1};
        #10;
        data_in = {8'd8, 8'd7, 8'd6, 8'd5};
        #10;
        data_in = {8'd12, 8'd11, 8'd10, 8'd9};
        #10;
        data_in = {8'd16, 8'd15, 8'd14, 8'd13};
        #10;
        data_in = 0;
        #40;
        $stop;
    end
    initial begin
        $monitor("time=%0t | data_in=%h | data_out=%h", $time, data_in, data_out);
    end
endmodule
