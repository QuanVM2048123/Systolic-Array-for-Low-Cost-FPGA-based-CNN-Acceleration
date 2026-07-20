`timescale 1ns/1ps

module systolic_array_top #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter K    = 4,
    parameter DW   = 8
) (
    input  wire clk,
    input  wire rst_n,
    input  wire start,

    input  wire              in_valid,
    input  wire [DW-1:0]      in_data,
    input  wire               out_ready,

    output wire                in_ready,
    output wire                out_valid,
    output wire [ACC_DW-1:0]   out_data,
    output wire                done
);

    localparam ROW_W = $clog2(ROWS);
    localparam COL_W = $clog2(COLS);
    localparam K_W   = $clog2(K);

    localparam ACC_DW = 2*DW + $clog2(K);

    // Counters
    reg [ROW_W:0] a_rows;
    reg [K_W:0]   a_cols;
    reg [K_W:0]   b_rows;
    reg [COL_W:0] b_cols;
    reg [ROW_W:0] c_rows;
    reg [COL_W:0] c_cols;

    // Memory (2D arrays are fine for internal signals in plain Verilog)
    reg signed [DW-1:0]     A [0:ROWS-1][0:K-1];
    reg signed [DW-1:0]     B [0:K-1][0:COLS-1];

    // Flattened bus to/from the systolic_array submodule
    wire signed [ROWS*K*DW-1:0]        A_flat;
    wire signed [K*COLS*DW-1:0]        B_flat;
    wire signed [ROWS*COLS*ACC_DW-1:0] C_flat;

    // FSM state - typedef enum replaced with localparams
    localparam [2:0]
        IDLE    = 3'd0,
        LOAD_A  = 3'd1,
        LOAD_B  = 3'd2,
        DELAY   = 3'd3,
        COMPUTE = 3'd4,
        OUTPUT  = 3'd5;

    reg [2:0] state, next_state;

    wire sa_done;

    systolic_array #(
        .ROWS (ROWS),
        .COLS (COLS),
        .K    (K),
        .DW   (DW)
    ) u_systolic_array (
        .clk   (clk),
        .rst_n (rst_n),
        .start (state == DELAY),
        .clear (state == DELAY),

        .A_flat (A_flat),
        .B_flat (B_flat),

        .C_flat (C_flat),
        .done   (sa_done)
    );

    // Pack A, B (loaded serially below) into the flattened submodule ports
    genvar gr, gk, gc;
    generate
        for (gr = 0; gr < ROWS; gr = gr + 1) begin : PACK_A_ROWS
            for (gk = 0; gk < K; gk = gk + 1) begin : PACK_A_COLS
                assign A_flat[(gr*K+gk)*DW +: DW] = A[gr][gk];
            end
        end
        for (gk = 0; gk < K; gk = gk + 1) begin : PACK_B_ROWS
            for (gc = 0; gc < COLS; gc = gc + 1) begin : PACK_B_COLS
                assign B_flat[(gk*COLS+gc)*DW +: DW] = B[gk][gc];
            end
        end
    endgenerate

    // Next State logic
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_A;
            end
            LOAD_A: begin
                if (a_rows == ROWS-1 && a_cols == K-1 && in_valid && in_ready) begin
                    next_state = LOAD_B;
                end
            end
            LOAD_B: begin
                if (b_rows == K-1 && b_cols == COLS-1 && in_valid && in_ready) begin
                    next_state = DELAY;
                end
            end
            DELAY: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                if (sa_done)
                    next_state = OUTPUT;
            end
            OUTPUT: begin
                if (c_cols == COLS-1 && c_rows == ROWS-1 && out_valid && out_ready)
                    next_state = IDLE;
            end
            default: begin
                next_state = state;
            end
        endcase
    end

    // Handshake Signals - AXI-S
    assign in_ready  = (state == LOAD_A) || (state == LOAD_B);
    assign out_valid = (state == OUTPUT);
    assign out_data  = C_flat[(c_rows*COLS+c_cols)*ACC_DW +: ACC_DW];
    assign done      = (state == OUTPUT && next_state == IDLE);

    // Sequential Logic - Load A & B
    always @(posedge clk) begin
        if (state == LOAD_A && in_valid && in_ready)
            A[a_rows][a_cols] <= in_data;
        if (state == LOAD_B && in_valid && in_ready)
            B[b_rows][b_cols] <= in_data;
    end

    // Sequential Logic - Update Counters
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            a_cols <= {(K_W+1){1'b0}};
            b_cols <= {(COL_W+1){1'b0}};
            c_cols <= {(COL_W+1){1'b0}};

            a_rows <= {(ROW_W+1){1'b0}};
            b_rows <= {(K_W+1){1'b0}};
            c_rows <= {(ROW_W+1){1'b0}};

            state <= IDLE;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    a_cols <= {(K_W+1){1'b0}};
                    b_cols <= {(COL_W+1){1'b0}};
                    c_cols <= {(COL_W+1){1'b0}};

                    a_rows <= {(ROW_W+1){1'b0}};
                    b_rows <= {(K_W+1){1'b0}};
                    c_rows <= {(ROW_W+1){1'b0}};
                end
                LOAD_A: begin
                    if (in_valid && in_ready) begin
                        if (a_cols == K - 1) begin
                            a_cols <= {(K_W+1){1'b0}};
                            a_rows <= a_rows + 1'b1;
                        end else begin
                            a_cols <= a_cols + 1'b1;
                        end
                    end
                end
                LOAD_B: begin
                    if (in_valid && in_ready) begin
                        if (b_cols == COLS - 1) begin
                            b_cols <= {(COL_W+1){1'b0}};
                            b_rows <= b_rows + 1'b1;
                        end else begin
                            b_cols <= b_cols + 1'b1;
                        end
                    end
                end
                DELAY: begin
                end
                COMPUTE: begin
                end
                OUTPUT: begin
                    if (out_valid && out_ready) begin
                        if (c_cols == COLS - 1) begin
                            c_cols <= {(COL_W+1){1'b0}};
                            c_rows <= c_rows + 1'b1;
                        end else begin
                            c_cols <= c_cols + 1'b1;
                        end
                    end
                end
                default: begin
                end
            endcase
        end
    end

endmodule
