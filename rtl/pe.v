module pe #(
    parameter DATA_WIDTH = 8,          // do rong du lieu dau vao (a, b)
    parameter ACC_WIDTH  = 32          // do rong thanh ghi tich luy (c)
) (
    input  wire                          clk,
    input  wire                          rst_n,      // reset tich cuc muc thap
    input  wire                          clear_acc,  // = 1: xoa thanh ghi tich luy (bat dau phep tinh moi)

    input  wire signed [DATA_WIDTH-1:0]  a_in,       // du lieu vao tu ben trai
    input  wire signed [DATA_WIDTH-1:0]  b_in,       // du lieu vao tu phia tren

    output reg  signed [DATA_WIDTH-1:0]  a_out,      // chuyen tiep a sang PE ben phai
    output reg  signed [DATA_WIDTH-1:0]  b_out,      // chuyen tiep b sang PE ben duoi
    output reg  signed [ACC_WIDTH-1:0]   acc_out       // ket qua tich luy cua PE nay
);

    reg signed [15:0] a_reg, b_reg;
    (* use_dsp = "yes" *) wire signed [ACC_WIDTH-1:0] product;
    
    assign product = (a_reg * b_reg);
    
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= {DATA_WIDTH{1'b0}};
            b_reg <= {DATA_WIDTH{1'b0}};
            a_out <= {DATA_WIDTH{1'b0}};
            b_out <= {DATA_WIDTH{1'b0}};
            acc_out <= {ACC_WIDTH{1'b0}};
        end else begin
            a_reg <= a_in;
            b_reg <= b_in;
            // chuyen tiep du lieu sang PE lang gieng (pipeline 1 chu ky)
            a_out <= a_reg;
            b_out <= b_reg;
            
            acc_out <= acc_out + product;
            if (clear_acc) begin
                acc_out <= {ACC_WIDTH{1'b0}};
            end
        end
    end

endmodule
