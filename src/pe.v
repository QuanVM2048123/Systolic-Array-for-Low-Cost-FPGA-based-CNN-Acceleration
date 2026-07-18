module pe_mac #(
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= {DATA_WIDTH{1'b0}};
            b_out <= {DATA_WIDTH{1'b0}};
            acc_out <= {ACC_WIDTH{1'b0}};
        end else begin
            // chuyen tiep du lieu sang PE lang gieng (pipeline 1 chu ky)
            a_out <= a_in;
            b_out <= b_in;

            // MAC: neu clear_acc thi bat dau tich luy moi, nguoc lai cong don
            if (clear_acc)
                acc_out <= a_in * b_in;
            else
                acc_out <= acc_out + (a_in * b_in);
        end
    end

endmodule
