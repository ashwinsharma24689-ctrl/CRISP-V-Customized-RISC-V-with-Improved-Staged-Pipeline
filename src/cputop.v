module cpu (
    input clk,
    input reset
);

// ==========================
// ?? WIRE DECLARATIONS
// ==========================

// PC + Instruction
wire [31:0] pc;
wire [31:0] instruction;

// Instruction fields
wire [6:0] opcode;
wire [4:0] rd, rs1, rs2;
wire [2:0] funct3;
wire [6:0] funct7;

// Control signals
wire regWrite, memRead, memWrite, memtoReg;
wire aluSrc, branch, jump, jalr;
wire [1:0] aluOp;
wire [2:0] immSel;

// Register file
wire [31:0] rs1_data, rs2_data;

// Immediate
wire [31:0] imm;

// ALU
wire [31:0] alu_in2;
wire [31:0] alu_result;
wire zero;

// Memory
wire [31:0] read_data;

// Writeback
wire [31:0] write_data;

// ALU control
wire [3:0] ALUcontrol;


// ==========================
// ?? INSTRUCTION FETCH
// ==========================

pc PC_inst (
    .clk(clk),
    .reset(reset),
    .jump(jump),
    .jalr(jalr),
    .branch(branch),
    .zero(zero),
    .rs1(rs1_data),
    .imm(imm),
    .pc(pc)
);

instructionmem IMEM (
    .pc(pc),
    .rd(instruction)
);


// ==========================
// ?? DECODE
// ==========================

assign opcode = instruction[6:0];
assign rd     = instruction[11:7];
assign funct3 = instruction[14:12];
assign rs1    = instruction[19:15];
assign rs2    = instruction[24:20];
assign funct7 = instruction[31:25];


// ==========================
// ?? CONTROL UNIT
// ==========================

maincontrol CTRL (
    .opcode(opcode),
    .regWrite(regWrite),
    .memRead(memRead),
    .memWrite(memWrite),
    .memtoReg(memtoReg),
    .aluSrc(aluSrc),
    .branch(branch),
    .jump(jump),
    .aluOp(aluOp)
    // ?? You must extend this with immSel + jalr
);


// ==========================
// ?? REGISTER FILE
// ==========================

reg_array RF (
    .sr1(rs1),
    .sr2(rs2),
    .wr(rd),
    .wd(write_data),
    .write_enable(regWrite),
    .clk(clk),
    .rst(reset),
    .rs1(rs1_data),
    .rs2(rs2_data)
);


// ==========================
// ?? IMMEDIATE GENERATOR
// ==========================

immediate_generator IMM (
    .instruction(instruction),
    .immSel(immSel),   // ?? must come from control
    .immOut(imm)
);


// ==========================
// ?? ALU INPUT MUX
// ==========================

assign alu_in2 = (aluSrc) ? imm : rs2_data;


// ==========================
// ?? ALU CONTROL + ALU
// ==========================

alucontrol ALUCTRL (
    .ALUcontrol(ALUcontrol),
    .aluOp(aluOp),
    .funct3(funct3),
    .funct7(funct7)
);

alu ALU (
    .operand_a(rs1_data),
    .operand_b(alu_in2),
    .alu_control(ALUcontrol),
    .alu_result(alu_result),
    .zero_flag(zero),
    .comp_flag(),
    .carry_flag(),
    .sign_bit(),
    .borrow(),
    .overflow()
);


// ==========================
// ?? DATA MEMORY
// ==========================

datamemory DMEM (
    .clk(clk),
    .memRead(memRead),
    .memWrite(memWrite),
    .address(alu_result),
    .writeData(rs2_data),
    .readData(read_data)
);


// ==========================
// ?? WRITE BACK MUX
// ==========================

assign write_data =
    (jump || jalr) ? (pc + 4) :   // JAL / JALR
    (memtoReg)     ? read_data :
                     alu_result;

endmodule
