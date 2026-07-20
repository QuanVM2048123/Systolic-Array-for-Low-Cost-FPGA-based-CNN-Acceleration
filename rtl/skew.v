`timescale 1ns/1ps

/***************************************
 * Start : wait for one clk, copy
 * register in this clk. Next clk: Start
 * skew
 ***************************************/

// NOTE ON FLATTENING (Verilog has no unpacked-array ports):
//   A_MAT_flat[(r*K+k)*DW +: DW]    == original A_MAT[r][k]
//   B_MAT_flat[(k*COLS+c)*DW +: DW] == original B_MAT[k][c]
//   SKEWED_A_flat[r*DW +: DW]       == original SKEWED_A[r]
//   SKEWED_B_flat[c*DW +: DW]       == original SKEWED_B[c]
//   valid_a[r] / valid_b[c] map directly to bit r / bit c (packed vector)

module skew #(
    parameter ROWS = 8,
    parameter COLS = 8,
    parameter K    = 8,
    parameter DW   = 16
) (
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        start,

    input  wire signed [ROWS*K*DW-1:0] A_MAT_flat,
    input  wire signed [K*COLS*DW-1:0] B_MAT_flat,

    output wire signed [ROWS*DW-1:0]   SKEWED_A_flat,
    output wire signed [COLS*DW-1:0]   SKEWED_B_flat,
    output reg  [ROWS-1:0]             valid_a,
    output reg  [COLS-1:0]             valid_b,
    output reg                         done
);

localparam CYC_A   = ROWS + K - 1;
localparam CYC_B   = K + COLS - 1;
localparam CYC_TOT = (CYC_A > CYC_B) ? CYC_A : CYC_B;
localparam CNT_W   = $clog2(CYC_TOT+1);

// Internal register copy of the input matrices (2D arrays are fine for
// *internal* signals in plain Verilog-2001 - only port arrays are illegal)
reg signed [DW-1:0] A [0:ROWS-1][0:K-1];
reg signed [DW-1:0] B [0:K-1][0:COLS-1];

// Per-element skewed registers, packed into the flat output ports below
reg signed [DW-1:0] SKEWED_A_r [0:ROWS-1];
reg signed [DW-1:0] SKEWED_B_r [0:COLS-1];

// Counters
reg [CNT_W-1:0] cycles;
reg             skewing;

integer i, j, r, c;
integer ri, ki, ci;

/* Timing note: `skewing` is set to 1 at the edge where `start` pulses.
 * SKEW_LOGIC reads `skewing` in a separate always block, so during
 * the start cycle itself, SKEW_LOGIC sees the old value (0) and does
 * not emit. First emission happens one cycle after start, with cycles=0.
 * This is correct behavior and relies on non-blocking assignment semantics.
 */
always @(posedge clk or negedge rst_n) begin : CTRL_LOGIC
    if (~rst_n) begin
        cycles  <= {CNT_W{1'b0}};
        skewing <= 1'b0;
    end else begin
        if (start) begin
            skewing <= 1'b1;
            cycles  <= {CNT_W{1'b0}};
        end else if (skewing) begin
            cycles <= cycles + 1'b1;
            if (cycles == CYC_TOT - 1) skewing <= 1'b0;
        end
    end
end

// Copy matrices at start (unpack the flat input ports into 2D storage)
always @(posedge clk) begin : REG_COPY
    if (start) begin
        for (ri = 0; ri < ROWS; ri = ri + 1)
            for (ki = 0; ki < K; ki = ki + 1)
                A[ri][ki] <= A_MAT_flat[(ri*K+ki)*DW +: DW];
        for (ki = 0; ki < K; ki = ki + 1)
            for (ci = 0; ci < COLS; ci = ci + 1)
                B[ki][ci] <= B_MAT_flat[(ki*COLS+ci)*DW +: DW];
    end
end

// Sequential Logic
always @(posedge clk or negedge rst_n) begin : SKEW_LOGIC
    if (~rst_n) begin
        for (i = 0; i < ROWS; i = i + 1) begin
            SKEWED_A_r[i] <= {DW{1'b0}};
            valid_a[i]    <= 1'b0;
        end
        for (j = 0; j < COLS; j = j + 1) begin
            SKEWED_B_r[j] <= {DW{1'b0}};
            valid_b[j]    <= 1'b0;
        end
    end else begin
        if (start) begin
            for (i = 0; i < ROWS; i = i + 1) begin
                SKEWED_A_r[i] <= {DW{1'b0}};
                valid_a[i]    <= 1'b0;
            end
            for (j = 0; j < COLS; j = j + 1) begin
                SKEWED_B_r[j] <= {DW{1'b0}};
                valid_b[j]    <= 1'b0;
            end
        end

        if (skewing) begin
            for (r = 0; r < ROWS; r = r + 1) begin
                if (cycles >= r && cycles < r+K) begin
                    SKEWED_A_r[r] <= A[r][cycles - r];
                    valid_a[r]    <= 1'b1;
                end else begin
                    SKEWED_A_r[r] <= {DW{1'b0}};
                    valid_a[r]    <= 1'b0;
                end
            end
            for (c = 0; c < COLS; c = c + 1) begin
                if (cycles >= c && cycles < c+K) begin
                    SKEWED_B_r[c] <= B[cycles - c][c];
                    valid_b[c]    <= 1'b1;
                end else begin
                    SKEWED_B_r[c] <= {DW{1'b0}};
                    valid_b[c]    <= 1'b0;
                end
            end
        end
    end
end

/* Mainly used for debugging or to fix vulnerabilities
 * that may occur later.
 */
always @(posedge clk or negedge rst_n) begin : DONE_FLAG
    if (~rst_n) begin
        done <= 1'b0;
    end else begin
        if (cycles == CYC_TOT - 1)
            done <= 1'b1;
        else
            done <= 1'b0;
    end
end

// Pack per-element skewed registers into the flat output ports
genvar gp;
generate
    for (gp = 0; gp < ROWS; gp = gp + 1) begin : PACK_A
        assign SKEWED_A_flat[gp*DW +: DW] = SKEWED_A_r[gp];
    end
    for (gp = 0; gp < COLS; gp = gp + 1) begin : PACK_B
        assign SKEWED_B_flat[gp*DW +: DW] = SKEWED_B_r[gp];
    end
endgenerate

endmodule
