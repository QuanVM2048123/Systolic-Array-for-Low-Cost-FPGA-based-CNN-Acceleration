module top #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                             clk,
    input  wire                             rst_n,     // active-low, matches pe.v
    input  wire                             clear_acc,
 
    input  wire signed [N*DATA_WIDTH-1:0]   a_in_raw,  // N activations, packed: a_in_raw[k] = row k, unskewed
    input  wire signed [N*DATA_WIDTH-1:0]   b_in_raw,  // N weights,     packed: b_in_raw[k] = col k, unskewed
 
    output wire signed [N*N*ACC_WIDTH-1:0]  acc_out    // N*N accumulators, packed row-major:
                                                        // acc(row r, col c) at bit offset
                                                        // (r*N+c)*ACC_WIDTH
);
 
    wire signed [N*DATA_WIDTH-1:0] a_skewed;
    wire signed [N*DATA_WIDTH-1:0] b_skewed;
 
    // Delay row r of a_in_raw by r cycles.
    skew_buffer #(
        .N     (N),
        .WIDTH (DATA_WIDTH)
    ) skew_a (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (a_in_raw),
        .data_out (a_skewed)
    );
 
    // Delay column c of b_in_raw by c cycles.
    skew_buffer #(
        .N     (N),
        .WIDTH (DATA_WIDTH)
    ) skew_b (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (b_in_raw),
        .data_out (b_skewed)
    );
 
    // The N x N PE grid, fed with already-skewed inputs.
    systolic_array #(
        .N          (N),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) array (
        .clk       (clk),
        .rst_n     (rst_n),
        .clear_acc (clear_acc),
        .a_in      (a_skewed),
        .b_in      (b_skewed),
        .acc_out   (acc_out)
    );
 
endmodule