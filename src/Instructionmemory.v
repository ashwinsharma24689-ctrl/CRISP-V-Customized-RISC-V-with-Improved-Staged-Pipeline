module instructionmem(rd, pc);

input [31:0] pc;
output reg [31:0] rd;

localparam N = 256;

// index must hold values 0?255 ? 8 bits
reg [$clog2(N)-1:0] index;

reg [31:0] memory [0:N-1];

always @(*) begin
    index = pc >> 2;

    if (index < N)
        rd = memory[index];
    else
        rd = 32'd0;   // safe fallback (NOP-like)
end

endmodule
