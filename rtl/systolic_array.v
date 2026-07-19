module systolic_array #(
    parameter ROWS      = 4,
    parameter COLS      = 4,
    parameter ACT_WIDTH = 8,   // bit width of each North/South element
    parameter SUM_WIDTH = 24   // bit width of each West/East element
) (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              load_weight,   // Global load signal
 
    input  wire [COLS*ACT_WIDTH-1:0]         in_n,          // COLS inputs from North
    input  wire [ROWS*SUM_WIDTH-1:0]         in_w,          // ROWS inputs from West
 
    output wire [COLS*ACT_WIDTH-1:0]         out_s,         // COLS outputs to South
    output wire [ROWS*SUM_WIDTH-1:0]         out_e          // ROWS outputs to East
);
 
    // These 2D arrays store the connections BETWEEN PEs.
    // conn_n[i][j] : North input for PE at row i, col j (conn_n[0][*] = external in_n)
    // conn_w[i][j] : West input for PE at row i, col j  (conn_w[*][0] = external in_w)
    wire signed [ACT_WIDTH-1:0] conn_n [ROWS:0][COLS-1:0];
    wire signed [SUM_WIDTH-1:0] conn_w [ROWS-1:0][COLS:0];
 
    genvar i, j;
    generate
        // Map the flat external in_n bus onto the top row (row 0)
        for (j = 0; j < COLS; j = j + 1) begin : INPUT_MAP_N
            assign conn_n[0][j] = in_n[ACT_WIDTH*j +: ACT_WIDTH];
        end
 
        // Map the flat external in_w bus onto the left column (col 0)
        for (i = 0; i < ROWS; i = i + 1) begin : INPUT_MAP_W
            assign conn_w[i][0] = in_w[SUM_WIDTH*i +: SUM_WIDTH];
        end
 
        // Instantiate the ROWS x COLS grid of PEs
        for (i = 0; i < ROWS; i = i + 1) begin : ROW_LOOP
            for (j = 0; j < COLS; j = j + 1) begin : COL_LOOP
 
                pe #(
                    .ACT_WIDTH (ACT_WIDTH),
                    .SUM_WIDTH (SUM_WIDTH)
                ) pe_inst (
                    .clk         (clk),
                    .rst         (rst),
                    .load_weight (load_weight),
                    .in_n        (conn_n[i][j]),        // North input  (row i, col j)
                    .in_w        (conn_w[i][j]),        // West input   (row i, col j)
                    .out_s       (conn_n[i+1][j]),       // South output -> North input of row i+1
                    .out_e       (conn_w[i][j+1])        // East output  -> West input of col j+1
                );
 
            end
        end
 
        // Map the bottom row's South outputs (row ROWS) onto the flat out_s bus
        for (j = 0; j < COLS; j = j + 1) begin : OUTPUT_MAP_S
            assign out_s[ACT_WIDTH*j +: ACT_WIDTH] = conn_n[ROWS][j];
        end
 
        // Map the rightmost column's East outputs (col COLS) onto the flat out_e bus
        for (i = 0; i < ROWS; i = i + 1) begin : OUTPUT_MAP_E
            assign out_e[SUM_WIDTH*i +: SUM_WIDTH] = conn_w[i][COLS];
        end
    endgenerate
 
endmodule