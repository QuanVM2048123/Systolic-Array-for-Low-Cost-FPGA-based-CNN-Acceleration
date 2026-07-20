`timescale 1ns/1ps

module pe #(
    parameter DW = 8,
    parameter K  = 4
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     clear,

    input  wire signed [DW-1:0]     a_in,
    input  wire signed [DW-1:0]     b_in,
    input  wire                     valid_in,

    output reg  signed [DW-1:0]     a_out,
    output reg  signed [DW-1:0]     b_out,
    output reg                      valid_out,
    output reg  signed [ACC_DW-1:0] acc
);

    localparam ACC_DW = 2*DW + $clog2(K);

    (* use_dsp = "yes" *) wire signed [ACC_DW-1:0] product;
    assign product = a_in * b_in;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            a_out <= {DW{1'b0}};
            b_out <= {DW{1'b0}};
            acc   <= {ACC_DW{1'b0}};
        end else begin
            if (valid_in) begin
                a_out <= a_in;
                b_out <= b_in;
                acc   <= product + acc;
            end else if (clear) begin
                acc <= {ACC_DW{1'b0}};
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            valid_out <= 1'b0;
        else
            valid_out <= valid_in;
    end

endmodule
