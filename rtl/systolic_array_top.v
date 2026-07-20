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

    input  wire in_valid,
    input  wire signed [DW-1:0] in_data,

    input  wire out_ready,

    output wire in_ready,
    output wire out_valid,
    output wire signed [2*DW+$clog2(K)-1:0] out_data,
    output wire done
);

localparam ACC_DW = 2*DW + $clog2(K);

localparam IDLE    = 3'd0;
localparam LOAD_A  = 3'd1;
localparam LOAD_B  = 3'd2;
localparam COMPUTE = 3'd3;
localparam OUTPUT  = 3'd4;


//====================================================
// Memory
//====================================================

reg signed [DW-1:0] A [0:ROWS-1][0:K-1];
reg signed [DW-1:0] B [0:K-1][0:COLS-1];

wire signed [ROWS*K*DW-1:0] A_flat;
wire signed [K*COLS*DW-1:0] B_flat;

wire signed [ROWS*COLS*ACC_DW-1:0] C_flat;


//====================================================
// Counter
//====================================================

reg [2:0] state;

reg [5:0] load_cnt;
reg [5:0] out_cnt;

integer row;
integer col;


//====================================================
// Systolic control
//====================================================

reg sa_start;
reg sa_clear;

wire sa_done;
    //====================================================
// Pack A -> A_flat
//====================================================

genvar r,c;

generate

    for(r=0;r<ROWS;r=r+1) begin : PACK_A_ROW

        for(c=0;c<K;c=c+1) begin : PACK_A_COL

            assign A_flat[(r*K+c)*DW +: DW] = A[r][c];

        end

    end

endgenerate


//====================================================
// Pack B -> B_flat
//====================================================

generate

    for(r=0;r<K;r=r+1) begin : PACK_B_ROW

        for(c=0;c<COLS;c=c+1) begin : PACK_B_COL

            assign B_flat[(r*COLS+c)*DW +: DW] = B[r][c];

        end

    end

endgenerate


//====================================================
// Instantiate Systolic Array
//====================================================

systolic_array #(

    .ROWS(ROWS),
    .COLS(COLS),
    .K(K),
    .DW(DW)

)
u_systolic_array
(

    .clk(clk),
    .rst_n(rst_n),

    .start(sa_start),
    .clear(sa_clear),

    .A_flat(A_flat),
    .B_flat(B_flat),

    .C_flat(C_flat),
    .done(sa_done)

);


//====================================================
// AXI-Stream style handshake
//====================================================

assign in_ready  = (state == LOAD_A) || (state == LOAD_B);

assign out_valid = (state == OUTPUT);

assign done      = (state == IDLE) && (out_cnt == ROWS*COLS);

assign out_data = C_flat[out_cnt*ACC_DW +: ACC_DW];
    //====================================================
// FSM
//====================================================

reg done_r;

assign done = done_r;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin

        state    <= IDLE;

        load_cnt <= 0;
        out_cnt  <= 0;

        sa_start <= 0;
        sa_clear <= 0;

        done_r   <= 0;

    end

    else begin

        sa_start <= 0;
        sa_clear <= 0;
        done_r   <= 0;

        case(state)

        //--------------------------------------------------
        // IDLE
        //--------------------------------------------------

        IDLE:
        begin
            load_cnt <= 0;
            out_cnt  <= 0;

            if(start)
                state <= LOAD_A;
        end

        //--------------------------------------------------
        // LOAD A
        //--------------------------------------------------

        LOAD_A:
        begin
            if(in_valid && in_ready) begin

                A[load_cnt/K][load_cnt%K] <= in_data;

                if(load_cnt == ROWS*K-1)
                    load_cnt <= 0;
                else
                    load_cnt <= load_cnt + 1;

                if(load_cnt == ROWS*K-1)
                    state <= LOAD_B;

            end
        end

        //--------------------------------------------------
        // LOAD B
        //--------------------------------------------------

        LOAD_B:
        begin
            if(in_valid && in_ready) begin

                B[load_cnt/COLS][load_cnt%COLS] <= in_data;

                if(load_cnt == K*COLS-1) begin

                    load_cnt <= 0;

                    sa_start <= 1;

                    state <= COMPUTE;

                end
                else
                    load_cnt <= load_cnt + 1;

            end
        end

        //--------------------------------------------------
        // COMPUTE
        //--------------------------------------------------

        COMPUTE:
        begin

            if(sa_done)
                state <= OUTPUT;

        end
