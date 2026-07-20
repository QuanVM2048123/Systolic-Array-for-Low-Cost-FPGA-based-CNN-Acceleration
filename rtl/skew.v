`timescale 1ns/1ps

module skew #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter K    = 4,
    parameter DW   = 8
)(
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

reg signed [DW-1:0] A [0:ROWS-1][0:K-1];
reg signed [DW-1:0] B [0:K-1][0:COLS-1];

reg signed [DW-1:0] SKEWED_A_r [0:ROWS-1];
reg signed [DW-1:0] SKEWED_B_r [0:COLS-1];

reg [CNT_W-1:0] cycles;
reg skewing;

integer i,j,r,c;
integer ri,ki,ci;

//////////////////////////////////////////////////////////
// Control
//////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cycles   <= 0;
        skewing  <= 0;
    end
    else begin
        if(start && !skewing) begin
            cycles  <= 0;
            skewing <= 1'b1;
        end
        else if(skewing) begin
            if(cycles == CYC_TOT-1) begin
                cycles  <= 0;
                skewing <= 1'b0;
            end
            else begin
                cycles <= cycles + 1'b1;
            end
        end
    end
end

//////////////////////////////////////////////////////////
// Copy matrix
//////////////////////////////////////////////////////////

always @(posedge clk) begin
    if(start && !skewing) begin

        for(ri=0;ri<ROWS;ri=ri+1)
            for(ki=0;ki<K;ki=ki+1)
                A[ri][ki] <= A_MAT_flat[(ri*K+ki)*DW +: DW];

        for(ki=0;ki<K;ki=ki+1)
            for(ci=0;ci<COLS;ci=ci+1)
                B[ki][ci] <= B_MAT_flat[(ki*COLS+ci)*DW +: DW];

    end
end

//////////////////////////////////////////////////////////
// Output skew
//////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin

    if(!rst_n) begin

        for(i=0;i<ROWS;i=i+1) begin
            SKEWED_A_r[i] <= 0;
            valid_a[i] <= 0;
        end

        for(j=0;j<COLS;j=j+1) begin
            SKEWED_B_r[j] <= 0;
            valid_b[j] <= 0;
        end

    end
    else begin

        if(skewing) begin

            for(r=0;r<ROWS;r=r+1) begin

                if(cycles>=r && cycles<r+K) begin
                    SKEWED_A_r[r] <= A[r][cycles-r];
                    valid_a[r] <= 1'b1;
                end
                else begin
                    SKEWED_A_r[r] <= 0;
                    valid_a[r] <= 0;
                end

            end

            for(c=0;c<COLS;c=c+1) begin

                if(cycles>=c && cycles<c+K) begin
                    SKEWED_B_r[c] <= B[cycles-c][c];
                    valid_b[c] <= 1'b1;
                end
                else begin
                    SKEWED_B_r[c] <= 0;
                    valid_b[c] <= 0;
                end

            end

        end
        else begin

            for(i=0;i<ROWS;i=i+1) begin
                SKEWED_A_r[i] <= 0;
                valid_a[i] <= 0;
            end

            for(j=0;j<COLS;j=j+1) begin
                SKEWED_B_r[j] <= 0;
                valid_b[j] <= 0;
            end

        end

    end

end

//////////////////////////////////////////////////////////
// Done
//////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        done <= 1'b0;
    else if(skewing && cycles==CYC_TOT-1)
        done <= 1'b1;
    else
        done <= 1'b0;
end

//////////////////////////////////////////////////////////
// Pack output
//////////////////////////////////////////////////////////

genvar gp;

generate

    for(gp=0;gp<ROWS;gp=gp+1) begin : PACK_A
        assign SKEWED_A_flat[gp*DW +: DW] = SKEWED_A_r[gp];
    end

    for(gp=0;gp<COLS;gp=gp+1) begin : PACK_B
        assign SKEWED_B_flat[gp*DW +: DW] = SKEWED_B_r[gp];
    end

endgenerate

endmodule
