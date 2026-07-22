`timescale 1ns/1ps
//======================================================================
// Systolic Array-Based Matrix Multiplication Accelerator
//
// Top-level controller for the systolic array accelerator.
//
// Functions:
//   1. Receive matrix A and matrix B through a streaming interface.
//   2. Store input matrices into local buffers.
//   3. Launch the systolic array computation engine.
//   4. Collect and stream out matrix multiplication results.
//
// Architecture:
//   - Input Buffer
//   - Systolic Array Core
//   - Output Controller
//
// The computation core is implemented using:
//   - Skewing Unit
//   - 2D Processing Element (PE) Array
//   - Pipelined Multiply-Accumulate Operations
//
//======================================================================
module systolic_array_top #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter K    = 4,
    parameter DW   = 8
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,

    // Nga vao nhan du lieu A, B (nhan tuan tu tung phan tu)
    input  wire in_valid,
    input  wire signed [DW-1:0] in_data,
    output wire in_ready,

    // Nga ra xuat du lieu C (xuat tuan tu tung phan tu)
    input  wire out_ready,
    output wire out_valid,
    output wire signed [2*DW+$clog2(K)-1:0] out_data,

    output wire done
);

localparam ACC_DW = 2*DW + $clog2(K);

// So phan tu can nhan / xuat
localparam A_LEN = ROWS*K;
localparam B_LEN = K*COLS;
localparam C_LEN = ROWS*COLS;

// Do rong bo dem du de chua het so phan tu lon nhat trong 3 so tren
localparam CNT_W = $clog2(C_LEN+1);

// Ma cac trang thai cua FSM
localparam IDLE    = 3'd0;
localparam LOAD_A  = 3'd1;
localparam LOAD_B  = 3'd2;
localparam COMPUTE = 3'd3;
localparam OUTPUT  = 3'd4;

reg [2:0] state;

//====================================================
// Bo nho luu ma tran A, B (dang mang 2 chieu cho de doc)
//====================================================

reg signed [DW-1:0] A [0:ROWS-1][0:K-1];
reg signed [DW-1:0] B [0:K-1][0:COLS-1];

// Dang "trai phang" (flatten) de dua vao khoi systolic_array,
// vi cong module chi nhan duoc 1 bus 1 chieu
wire signed [ROWS*K*DW-1:0] A_flat;
wire signed [K*COLS*DW-1:0] B_flat;

wire signed [ROWS*COLS*ACC_DW-1:0] C_flat;

//====================================================
// Bo dem dung chung cho ca 3 giai doan load A / load B / xuat C
//====================================================

reg [CNT_W-1:0] cnt;

//====================================================
// Tin hieu dieu khien khoi systolic_array
//====================================================

reg  sa_start;
reg  sa_clear;
wire sa_done;

//====================================================
// Goi trai phang A -> A_flat
//====================================================

genvar ra, ca;

generate
    for (ra = 0; ra < ROWS; ra = ra + 1) begin : PACK_A_ROW
        for (ca = 0; ca < K; ca = ca + 1) begin : PACK_A_COL
            assign A_flat[(ra*K+ca)*DW +: DW] = A[ra][ca];
        end
    end
endgenerate

//====================================================
// Goi trai phang B -> B_flat
//====================================================

genvar rb, cb;

generate
    for (rb = 0; rb < K; rb = rb + 1) begin : PACK_B_ROW
        for (cb = 0; cb < COLS; cb = cb + 1) begin : PACK_B_COL
            assign B_flat[(rb*COLS+cb)*DW +: DW] = B[rb][cb];
        end
    end
endgenerate

//====================================================
// Instance khoi systolic_array
//====================================================

systolic_array #(
    .ROWS(ROWS),
    .COLS(COLS),
    .K(K),
    .DW(DW)
) u_systolic_array (
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
// Cac tin hieu bat tay (handshake) xuat ra ngoai module
//====================================================

assign in_ready  = (state == LOAD_A) || (state == LOAD_B);
assign out_valid = (state == OUTPUT);

// Lay ra 1 phan tu C dang chi boi cnt
assign out_data = C_flat[cnt*ACC_DW +: ACC_DW];

reg done_r;
assign done = done_r;

//====================================================
// FSM chinh
//====================================================

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n) begin

        state    <= IDLE;
        cnt      <= 0;

        sa_start <= 1'b0;
        sa_clear <= 1'b1;

        done_r   <= 1'b0;

    end
    else begin

        // Mac dinh moi chu ky la 0, chi bat len 1 xung khi can
        sa_start <= 1'b0;
        sa_clear <= 1'b0;
        done_r   <= 1'b0;

        case (state)

        //--------------------------------------------------
        // IDLE: cho lenh bat dau
        //--------------------------------------------------
        IDLE:
        begin
            cnt <= 0;

            if (start) begin
                sa_clear <= 1'b1;   // xoa acc cu trong cac PE truoc khi lam vong moi
                state    <= LOAD_A;
            end
        end

        //--------------------------------------------------
        // LOAD_A: nhan tung phan tu cua ma tran A
        //--------------------------------------------------
        LOAD_A:
        begin
            if (in_valid && in_ready) begin

                A[cnt/K][cnt%K] <= in_data;

                if (cnt == A_LEN-1) begin
                    cnt   <= 0;
                    state <= LOAD_B;
                end
                else begin
                    cnt <= cnt + 1'b1;
                end

            end
        end

        //--------------------------------------------------
        // LOAD_B: nhan tung phan tu cua ma tran B
        //--------------------------------------------------
        LOAD_B:
        begin
            if (in_valid && in_ready) begin

                B[cnt/COLS][cnt%COLS] <= in_data;

                if (cnt == B_LEN-1) begin
                    cnt      <= 0;
                    sa_start <= 1'b1;   // bao cho systolic_array bat dau tinh
                    state    <= COMPUTE;
                end
                else begin
                    cnt <= cnt + 1'b1;
                end

            end
        end

        //--------------------------------------------------
        // COMPUTE: cho khoi systolic_array tinh xong
        //--------------------------------------------------
        COMPUTE:
        begin
            if (sa_done) begin
                cnt   <= 0;
                state <= OUTPUT;
            end
        end

        //--------------------------------------------------
        // OUTPUT: xuat tung phan tu cua ma tran C ra ngoai
        //--------------------------------------------------
        OUTPUT:
        begin
            if (out_valid && out_ready) begin

                if (cnt == C_LEN-1) begin
                    cnt    <= 0;
                    done_r <= 1'b1;   // bao hoan tat 1 xung
                    state  <= IDLE;
                end
                else begin
                    cnt <= cnt + 1'b1;
                end

            end
        end

        default:
        begin
            state <= IDLE;
        end

        endcase

    end
end

endmodule
