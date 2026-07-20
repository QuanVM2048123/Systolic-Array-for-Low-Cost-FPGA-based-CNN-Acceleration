module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          clear_acc,

    input  wire signed [DATA_WIDTH-1:0]  a_in,
    input  wire signed [DATA_WIDTH-1:0]  b_in,

    output reg  signed [DATA_WIDTH-1:0]  a_out,
    output reg  signed [DATA_WIDTH-1:0]  b_out,
    output reg  signed [ACC_WIDTH-1:0]   acc_out
);

    (* use_dsp = "yes" *) wire signed [ACC_WIDTH-1:0] product;
    assign product = (a_in * b_in);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out   <= {DATA_WIDTH{1'b0}};
            b_out   <= {DATA_WIDTH{1'b0}};
            acc_out <= {ACC_WIDTH{1'b0}};
        end else begin
            a_out   <= a_in;
            b_out   <= b_in;
            acc_out <= acc_out + product;
            if (clear_acc) begin
                acc_out <= {ACC_WIDTH{1'b0}};
            end
        end
    end

endmodule