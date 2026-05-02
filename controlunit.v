module maincontrol(
    input [6:0] opcode,
    output reg regWrite, memRead, memWrite, memtoReg,
    output reg aluSrc, branch, jump, jalr,
    output reg [1:0] aluOp,
    output reg [2:0] immSel
);
localparam Rtype = 7'b0110011,
           Itype = 7'b0010011,
           Load  = 7'b0000011,
           Store = 7'b0100011,
           Branch= 7'b1100011,
           JAL   = 7'b1101111,
           JALR  = 7'b1100111,
           LUI   = 7'b0110111,
           AUIPC = 7'b0010111;
always @(*) begin
    // Default (safe reset state)
    regWrite = 0;
    memRead  = 0;
    memWrite = 0;
    memtoReg = 0;
    aluSrc   = 0;
    branch   = 0;
    jump     = 0;
    jalr     = 0;
    aluOp    = 2'b00;
    immSel   = 3'b000;
    case(opcode)
        Rtype: begin
            regWrite = 1;
            aluOp = 2'b10;
        end
        Itype: begin
            regWrite = 1;
            aluSrc = 1;
            aluOp = 2'b10;
            immSel = 3'b000;
        end
        Load: begin
            regWrite = 1;
            aluSrc = 1;
            memRead = 1;
            memtoReg = 1;
            aluOp = 2'b00;
            immSel = 3'b000;
        end
        Store: begin
            aluSrc = 1;
            memWrite = 1;
            aluOp = 2'b00;
            immSel = 3'b001;
        end
        Branch: begin
            branch = 1;
            aluOp = 2'b01;
            immSel = 3'b010;
        end
        JAL: begin
            regWrite = 1;
            jump = 1;
            immSel = 3'b100;
        end
        JALR: begin
            regWrite = 1;
            aluSrc = 1;
            jalr = 1;
            immSel = 3'b000;
        end
        LUI: begin
            regWrite = 1;
            aluSrc = 1;
            immSel = 3'b011;
        end
        AUIPC: begin
            regWrite = 1;
            aluSrc = 1;
            immSel = 3'b011;
        end
    endcase
end

endmodule
module alucontrol(ALUcontrol, aluOp, funct3, funct7);
input [1:0]aluOp;
input [2:0]funct3;
input [6:0]funct7;
output reg [3:0]ALUcontrol;
wire [3:0] signal = {funct7[5], funct3};
localparam ADD=4'b0010, SUB=4'b0110, AND=4'b0000, OR=4'b0001, XOR=4'b0011, SLT=4'b0111, SLL=4'b1000, SRL=4'b1001, SRA=4'b1010;
always@(*)
begin
	if (aluOp==2'b00) begin
		ALUcontrol=ADD;
	end
	else if (aluOp==2'b01) begin
		ALUcontrol=SUB;
	end
	else if (aluOp==2'b10) begin
		case (signal) 
		4'b0000: ALUcontrol= ADD;
		4'b1000: ALUcontrol= SUB;
		4'b0111: ALUcontrol= AND;
		4'b0110: ALUcontrol= OR;
		4'b0100: ALUcontrol= XOR;
		4'b0010: ALUcontrol= SLT;
		4'b0001: ALUcontrol= SLL;
		4'b0101: ALUcontrol= SRL;
		4'b1101: ALUcontrol= SRA;
		default: ALUcontrol= 4'b0000;
		endcase
	end
	else ALUcontrol=4'b0000;
end
endmodule
		