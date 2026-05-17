module datamemory(
    input clk,
    input memRead,
    input memWrite,
    input [31:0] address,
    input [31:0] writeData,
    output reg [31:0] readData
);

localparam N = 256;

reg [31:0] memory [0:N-1];
wire [$clog2(N)-1:0] index;

assign index = address >> 2;

// WRITE (synchronous)
always @(posedge clk) begin
    if (memWrite)
        memory[index] <= writeData;
end

// READ (combinational)
always @(*) begin
    if (memRead && address < N*4)
	readData = memory[index];
    else
	readData = 32'd0;
end

endmodule
