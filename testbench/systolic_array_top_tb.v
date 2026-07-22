`timescale 1ns/1ps

module tb_systolic_array_top();

    // Thay doi tham so nho de de test (2x2)
    parameter ROWS = 2;
    parameter COLS = 2;
    parameter K    = 2;
    parameter DW   = 8;
    localparam ACC_DW = 2*DW + $clog2(K);

    // Khai bao cac tin hieu
    reg clk;
    reg rst_n;
    reg start;
    
    reg in_valid;
    reg signed [DW-1:0] in_data;
    wire in_ready;
    
    reg out_ready;
    wire out_valid;
    wire signed [ACC_DW-1:0] out_data;
    
    wire done;

    // Khoi tao module can test (DUT - Device Under Test)
    systolic_array_top #(
        .ROWS(ROWS),
        .COLS(COLS),
        .K(K),
        .DW(DW)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .in_valid(in_valid),
        .in_data(in_data),
        .in_ready(in_ready),
        .out_ready(out_ready),
        .out_valid(out_valid),
        .out_data(out_data),
        .done(done)
    );

    // Tao xung clock 100MHz (Chu ky 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // Task ho tro viec nap du lieu vao theo giao thuc bat tay
    task send_data(input signed [DW-1:0] data);
    begin
        in_valid <= 1'b1;
        in_data <= data;
        
        // Cho den khi module bao san sang (in_ready = 1)
        wait(in_ready == 1'b1);
        @(posedge clk); // Doi 1 nhip clock
        
        in_valid <= 1'b0; // Ha tin hieu valid
        #1; // Delay nho de waveform hien thi dep hon
    end
    endtask

    // Luong kich thich (Stimulus)
    initial begin
        // Khoi tao tin hieu
        rst_n = 0;
        start = 0;
        in_valid = 0;
        in_data = 0;
        out_ready = 1; // Luon san sang nhan ket qua de don gian hoa testbench

        // Reset he thong
        #20;
        rst_n = 1;
        #10;

        // Phat lenh Start
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        $display("-------------------------------------------");
        $display("--- BAT DAU NAP MA TRAN A (Kich thuoc 2x2) ---");
        // Ma tran A = [[1, 2],
        //              [3, 4]]
        send_data(8'd1);
        send_data(8'd2);
        send_data(8'd3);
        send_data(8'd4);

        $display("--- BAT DAU NAP MA TRAN B (Kich thuoc 2x2) ---");
        // Ma tran B = [[5, 6],
        //              [7, 8]]
        send_data(8'd5);
        send_data(8'd6);
        send_data(8'd7);
        send_data(8'd8);

        $display("--- DANG CHO SYSTOLIC ARRAY TINH TOAN... ---");
        
        // Cho den khi he thong bao hoan tat
        wait(done == 1'b1);
        
        $display("--- HOAN TAT CHU KY TINH TOAN ---");
        $display("-------------------------------------------");
        
        #50;
        $finish; // Ket thuc mo phong
    end

    // Monitor: Hien thi du lieu ket qua ngay khi module xuat ra
    always @(posedge clk) begin
        if (out_valid && out_ready) begin
            $display("[Thoi gian: %0t] Xuat du lieu C: %d", $time, out_data);
        end
    end

endmodule
