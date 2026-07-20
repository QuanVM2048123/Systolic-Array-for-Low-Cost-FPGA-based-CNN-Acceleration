`timescale 1ns/1ps

module pe #(
    parameter DW = 8,
    parameter K  = 4,
    parameter ACC_DW = 2*DW + $clog2(K)
)(
    input  wire clk,
    input  wire rst_n,
    input  wire clear,

    input  wire signed [DW-1:0] a_in,
    input  wire signed [DW-1:0] b_in,
    input  wire valid_in,

    output reg signed [DW-1:0] a_out,
    output reg signed [DW-1:0] b_out,
    output reg valid_out,
    output reg signed [ACC_DW-1:0] acc
);

wire signed [ACC_DW-1:0] product;
assign product = a_in * b_in;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin
        a_out <= 0;
        b_out <= 0;
        acc <= 0;
        valid_out <= 0;
    end
    else if(clear) begin
        a_out <= 0;
        b_out <= 0;
        acc <= 0;
        valid_out <= 0;
    end
    else begin
        valid_out <= valid_in;

        if(valid_in) begin
            a_out <= a_in;
            b_out <= b_in;
            acc <= acc + product;
        end
    end
end

endmodule
