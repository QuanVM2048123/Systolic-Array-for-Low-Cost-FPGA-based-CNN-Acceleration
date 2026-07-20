module systolic_array #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                             clk,
    input  wire                             rst_n,       // active-low, matches pe.v
    input  wire                             clear_acc,
 
    input  wire signed [N*DATA_WIDTH-1:0]   a_in,        // N activations, packed: a_in[k] = row k
    input  wire signed [N*DATA_WIDTH-1:0]   b_in,        // N weights,     packed: b_in[k] = col k
 
    output wire signed [N*N*ACC_WIDTH-1:0]  acc_out      // N*N accumulators, packed row-major:
                                                          // acc(row r, col c) at bit offset
                                                          // (r*N+c)*ACC_WIDTH
);
 
    // Unpack the flat external buses into per-row / per-column signals.
    wire signed [DATA_WIDTH-1:0] a_ext [0:N-1];
    wire signed [DATA_WIDTH-1:0] b_ext [0:N-1];
 
    genvar k;
    generate
        for (k = 0; k < N; k = k + 1) begin : UNPACK_EXT
            assign a_ext[k] = a_in[DATA_WIDTH*k +: DATA_WIDTH];
            assign b_ext[k] = b_in[DATA_WIDTH*k +: DATA_WIDTH];
        end
    endgenerate
 
    // conn_a[r][c] : a_in of PE(r,c).   conn_a[r][N] is the row's unused output edge.
    // conn_b[r][c] : b_in of PE(r,c).   conn_b[N][c] is the column's unused output edge.
    // acc_link[r][c] : acc_out of PE(r,c).
    wire signed [DATA_WIDTH-1:0] conn_a   [0:N-1][0:N];
    wire signed [DATA_WIDTH-1:0] conn_b   [0:N][0:N-1];
    wire signed [ACC_WIDTH-1:0]  acc_link [0:N-1][0:N-1];
 
    genvar r, c;
 
    // ------------------------------------------------------------------
    // Wire external inputs straight onto the array's left/top boundary
    // ------------------------------------------------------------------
    generate
        for (r = 0; r < N; r = r + 1) begin : ROW_EDGE
            assign conn_a[r][0] = a_ext[r];
        end
        for (c = 0; c < N; c = c + 1) begin : COL_EDGE
            assign conn_b[0][c] = b_ext[c];
        end
    endgenerate
 
    // ------------------------------------------------------------------
    // The N x N grid of PEs
    // ------------------------------------------------------------------
    generate
        for (r = 0; r < N; r = r + 1) begin : ROWS
            for (c = 0; c < N; c = c + 1) begin : COLS
                pe #(
                    .DATA_WIDTH (DATA_WIDTH),
                    .ACC_WIDTH  (ACC_WIDTH)
                ) pe_inst (
                    .clk       (clk),
                    .rst_n     (rst_n),
                    .clear_acc (clear_acc),
                    .a_in      (conn_a[r][c]),
                    .b_in      (conn_b[r][c]),
                    .a_out     (conn_a[r][c+1]),
                    .b_out     (conn_b[r+1][c]),
                    .acc_out   (acc_link[r][c])
                );
            end
        end
    endgenerate
 
    // Pack all N*N accumulators onto the flat acc_out bus, row-major.
    generate
        for (r = 0; r < N; r = r + 1) begin : PACK_ACC_ROW
            for (c = 0; c < N; c = c + 1) begin : PACK_ACC_COL
                assign acc_out[(r*N+c)*ACC_WIDTH +: ACC_WIDTH] = acc_link[r][c];
            end
        end
    endgenerate
 
endmodule