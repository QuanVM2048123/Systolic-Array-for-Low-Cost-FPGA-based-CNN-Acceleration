`timescale 1ns/1ps

// NOTE ON FLATTENING:
//   A_flat[(r*K+k)*DW +: DW]            == original A[r][k]
//   B_flat[(k*COLS+c)*DW +: DW]         == original B[k][c]
//   C_flat[(r*COLS+c)*ACC_DW +: ACC_DW] == original C[r][c]

module systolic_array #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter K    = 4,
    parameter DW   = 8,
    parameter ACC_DW = 2*DW + $clog2(K)
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire clear,

    input  wire signed [ROWS*K*DW-1:0]        A_flat,
    input  wire signed [K*COLS*DW-1:0]        B_flat,

    output wire signed [ROWS*COLS*ACC_DW-1:0] C_flat,
    output wire done
);

    localparam TOTAL_CYCLES = ROWS + COLS + K - 2;
    localparam TOTCYC_W     = $clog2(TOTAL_CYCLES+1);

    wire signed [ROWS*DW-1:0] SKEW_A_flat;
    wire signed [COLS*DW-1:0] SKEW_B_flat;
    wire [ROWS-1:0] valA;
    wire [COLS-1:0] valB;

    wire signed [DW-1:0] SKEW_A [0:ROWS-1];
    wire signed [DW-1:0] SKEW_B [0:COLS-1];

    wire signed [DW-1:0]     pe_a   [0:ROWS-1][0:COLS-1];
    wire signed [DW-1:0]     pe_b   [0:ROWS-1][0:COLS-1];
    wire                     valOut [0:ROWS-1][0:COLS-1];
    wire signed [ACC_DW-1:0] C      [0:ROWS-1][0:COLS-1];

    wire skew_done; // unused, kept for parity with original (lint-off equivalent)

    skew #(
        .ROWS(ROWS),
        .COLS(COLS),
        .K(K),
        .DW(DW)
    ) skew_UUT (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),

        .A_MAT_flat(A_flat),
        .B_MAT_flat(B_flat),

        .SKEWED_A_flat(SKEW_A_flat),
        .SKEWED_B_flat(SKEW_B_flat),
        .valid_a(valA),
        .valid_b(valB),
        .done(skew_done)
    );

    genvar gu;
    generate
        for (gu = 0; gu < ROWS; gu = gu + 1) begin : UNPACK_A
            assign SKEW_A[gu] = SKEW_A_flat[gu*DW +: DW];
        end
        for (gu = 0; gu < COLS; gu = gu + 1) begin : UNPACK_B
            assign SKEW_B[gu] = SKEW_B_flat[gu*DW +: DW];
        end
    endgenerate

    genvar r, c;
    generate
        for (r = 0; r < ROWS; r = r + 1) begin : GEN_ROWS
            for (c = 0; c < COLS; c = c + 1) begin : GEN_COLS
                pe #(
                    .DW(DW),
                    .K(K)
                ) pe_UUT (
                    .clk(clk),
                    .rst_n(rst_n),
                    .clear(clear),
                    .a_in((c == 0) ? SKEW_A[r] : pe_a[r][c-1]),
                    .b_in((r == 0) ? SKEW_B[c] : pe_b[r-1][c]),
                    .valid_in(
                        (c == 0 && r == 0) ? (valA[r] & valB[c]) :
                        (c == 0)           ? (valA[r] & valOut[r-1][c]) :
                        (r == 0)           ? (valOut[r][c-1] & valB[c]) :
                                             (valOut[r][c-1] & valOut[r-1][c])
                    ),
                    .a_out(pe_a[r][c]),
                    .b_out(pe_b[r][c]),
                    .valid_out(valOut[r][c]),
                    .acc(C[r][c])
                );
            end
        end
    endgenerate

    genvar pr, pc;
    generate
        for (pr = 0; pr < ROWS; pr = pr + 1) begin : PACK_C_ROWS
            for (pc = 0; pc < COLS; pc = pc + 1) begin : PACK_C_COLS
                assign C_flat[(pr*COLS+pc)*ACC_DW +: ACC_DW] = C[pr][pc];
            end
        end
    endgenerate

    reg [TOTCYC_W-1:0] cycles;
    reg                running;
    reg                done_r;

    assign done = done_r;

    always @(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin
        running <= 0;
        cycles  <= 0;
        done_r  <= 0;
    end

    else if(clear) begin
        running <= 0;
        cycles  <= 0;
        done_r  <= 0;
    end

    else begin

        if(done_r)
            done_r <= 0;

        if(start && !running) begin
            running <= 1;
            cycles <= 0;
        end

        else if(running) begin

            if(cycles == TOTAL_CYCLES-1) begin
                running <= 0;
                done_r <= 1;
            end

            else begin
                cycles <= cycles + 1'b1;
            end

        end

    end
end
endmodule
