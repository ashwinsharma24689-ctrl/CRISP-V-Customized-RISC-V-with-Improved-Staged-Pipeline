module reg_array ( sr1, sr2, rs1, rs2 , wr, wd, write_enable, clk, rst);
input write_enable, clk, rst;
input [4:0] sr1, sr2, wr;
input [31:0] wd;
output [31:0] rs1, rs2;
reg [31:0] register_array [0:31];
integer i;
assign rs1 = (sr1 == 5'd0) ? 32'd0 : register_array[sr1];
assign rs2 = (sr2 == 5'd0) ? 32'd0 : register_array[sr2];
always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                register_array[i] <= 32'd0;
            end
        end
        else begin
            if (write_enable && (wr != 5'd0)) begin
                register_array[wr] <= wd;
            end
        end
    end
endmodule
