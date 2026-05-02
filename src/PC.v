module pc (
    input clk, reset,
    input jump, jalr, branch, zero,
    input [31:0] rs1,
    input [31:0] imm,
    output reg [31:0] pc
);

wire [31:0] pc_next;

// Priority: JALR > JUMP > BRANCH > PC+4
assign pc_next =
    (jalr)              ? ((rs1 + imm) & ~32'b1) :
    (jump)              ? (pc + imm) :
    (branch && zero)    ? (pc + imm) :
                          (pc + 4);

always @(posedge clk or posedge reset) begin
    if (reset)
        pc <= 32'b0;
    else
        pc <= pc_next;
end

endmodule
