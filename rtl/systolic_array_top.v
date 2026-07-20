`timescale 1ns/1ps
module systolic_array_top #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter K    = 4,
    parameter DW   = 8
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire clear,
    input  wire signed [ROWS*K*DW-1:0]        A_flat,
    input  wire signed [K*COLS*DW-1:0]        B_flat,
    output reg  signed [ROWS*COLS*(2*DW+$clog2(K))-1:0] C_flat,
    output reg  done
);
    localparam ACC_DW = 2*DW + $clog2(K);
    integer i, j, k;
    reg signed [ACC_DW-1:0] sum;
    reg computing;
    integer cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            computing <= 0;
            cnt <= 0;
            C_flat <= 0;
        end else if (clear) begin
            done <= 0;
        end else if (start) begin
            computing <= 1;
            cnt <= 0;
            done <= 0;
        end else if (computing) begin
            if (cnt == K) begin
                for (i = 0; i < ROWS; i = i + 1) begin
                    for (j = 0; j < COLS; j = j + 1) begin
                        sum = 0;
                        for (k = 0; k < K; k = k + 1)
                            sum = sum + $signed(A_flat[(i*K+k)*DW +: DW]) * $signed(B_flat[(k*COLS+j)*DW +: DW]);
                        C_flat[(i*COLS+j)*ACC_DW +: ACC_DW] <= sum;
                    end
                end
                done <= 1;
                computing <= 0;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end
endmodule
