module skew_buffer #(
    parameter N     = 4,
    parameter WIDTH = 8
) (
    input  wire                          clk,
    input  wire                          rst_n,     // active-low, async
    input  wire signed [N*WIDTH-1:0]     data_in,   // line k at bits [WIDTH*k +: WIDTH]
    output wire signed [N*WIDTH-1:0]     data_out   // line k delayed by k cycles
);
 
    // Unpack the flat bus into N individual lines.
    wire signed [WIDTH-1:0] line_in [0:N-1];
 
    genvar k;
    generate
        for (k = 0; k < N; k = k + 1) begin : UNPACK
            assign line_in[k] = data_in[WIDTH*k +: WIDTH];
        end
    endgenerate
 
    // Shift-register chain per line. Line k needs k stages (line 0 needs none).
    reg signed [WIDTH-1:0] skew_reg [0:N-1][0:N-2];
    wire signed [WIDTH-1:0] line_out [0:N-1];
 
    genvar r, s;
    generate
        for (r = 0; r < N; r = r + 1) begin : DELAY_LINE
            if (r == 0) begin : NO_DELAY
                assign line_out[0] = line_in[0];
            end else begin : DELAY_CHAIN
                for (s = 0; s < r; s = s + 1) begin : STAGE
                    always @(posedge clk or negedge rst_n) begin
                        if (!rst_n)
                            skew_reg[r][s] <= {WIDTH{1'b0}};
                        else if (s == 0)
                            skew_reg[r][s] <= line_in[r];
                        else
                            skew_reg[r][s] <= skew_reg[r][s-1];
                    end
                end
                assign line_out[r] = skew_reg[r][r-1];
            end
        end
    endgenerate
 
    // Pack the N delayed lines back onto the flat output bus.
    generate
        for (r = 0; r < N; r = r + 1) begin : PACK
            assign data_out[WIDTH*r +: WIDTH] = line_out[r];
        end
    endgenerate
 
endmodule