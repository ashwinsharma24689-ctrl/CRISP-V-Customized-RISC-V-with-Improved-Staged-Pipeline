
//   MAIN CONTROL UNIT

module maincontrol (
    input  logic [6:0] opcode,
    output logic       regWrite,
    output logic       memRead,
    output logic       memWrite,
    output logic       memtoReg,
    output logic       aluSrc,
    output logic       branch,
    output logic       jump,
    output logic       jalr,
    output logic       auipc,       // NEW: flag for AUIPC PC-relative add
    output logic [1:0] aluOp,
    output logic [2:0] immSel
);
    // Opcode table (RV32I)
    localparam [6:0]
        RTYPE  = 7'b011_0011,
        ITYPE  = 7'b001_0011,
        LOAD   = 7'b000_0011,
        STORE  = 7'b010_0011,
        BRANCH = 7'b110_0011,
        JAL    = 7'b110_1111,
        JALR   = 7'b110_0111,
        LUI    = 7'b011_0111,
        AUIPC  = 7'b001_0111;

    // immSel encoding
    localparam [2:0]
        IMM_I = 3'b000,
        IMM_S = 3'b001,
        IMM_B = 3'b010,
        IMM_U = 3'b011,
        IMM_J = 3'b100;

    always_comb begin
        // --- Safe defaults (prevents latch inference) ---
        regWrite = 1'b0;
        memRead  = 1'b0;
        memWrite = 1'b0;
        memtoReg = 1'b0;
        aluSrc   = 1'b0;
        branch   = 1'b0;
        jump     = 1'b0;
        jalr     = 1'b0;
        auipc    = 1'b0;
        aluOp    = 2'b00;
        immSel   = IMM_I;

        unique case (opcode)
            RTYPE: begin
                regWrite = 1'b1;
                aluOp    = 2'b10;   // decoded by alucontrol from funct3/funct7
            end

            ITYPE: begin
                regWrite = 1'b1;
                aluSrc   = 1'b1;
                aluOp    = 2'b10;
                immSel   = IMM_I;
            end

            LOAD: begin
                regWrite = 1'b1;
                aluSrc   = 1'b1;
                memRead  = 1'b1;
                memtoReg = 1'b1;
                aluOp    = 2'b00;   // ADD for address calc
                immSel   = IMM_I;
            end

            STORE: begin
                aluSrc   = 1'b1;
                memWrite = 1'b1;
                aluOp    = 2'b00;   // ADD for address calc
                immSel   = IMM_S;
            end

            BRANCH: begin
                branch   = 1'b1;
                aluOp    = 2'b01;   // SUB → flags used for comparison
                immSel   = IMM_B;
            end

            JAL: begin
                regWrite = 1'b1;
                jump     = 1'b1;
                immSel   = IMM_J;
            end

            JALR: begin
                regWrite = 1'b1;
                aluSrc   = 1'b1;
                jalr     = 1'b1;
                immSel   = IMM_I;
            end

            LUI: begin
                regWrite = 1'b1;
                aluSrc   = 1'b1;
                aluOp    = 2'b11;   // pass-through immediate (see alucontrol)
                immSel   = IMM_U;
            end

            AUIPC: begin
                regWrite = 1'b1;
                aluSrc   = 1'b1;
                auipc    = 1'b1;    // signals top-level to mux PC → operand_a
                aluOp    = 2'b00;   // ADD  (PC + imm)
                immSel   = IMM_U;
            end

            default: begin /* all outputs already defaulted */ end
        endcase
    end
endmodule


//  ALU Control

module alucontrol (
    input  logic [1:0] aluOp,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    output logic [3:0] ALUcontrol
);
    // Mirror of alu.v localparams — MUST stay in sync
    localparam [3:0]
        ALU_ADD = 4'b0000,
        ALU_SUB = 4'b1000,
        ALU_AND = 4'b0111,
        ALU_OR  = 4'b0110,
        ALU_XOR = 4'b0100,
        ALU_SLT = 4'b0010,
        ALU_SLL = 4'b0001,
        ALU_SRL = 4'b0101,
        ALU_SRA = 4'b1101;

    logic [3:0] signal;
    assign signal = {funct7[5], funct3};   // 4-bit decode key

    always_comb begin
        ALUcontrol = ALU_ADD;   // safe default

        unique case (aluOp)
            2'b00:   ALUcontrol = ALU_ADD;      // Load / Store / AUIPC

            2'b01:   ALUcontrol = ALU_SUB;      // Branch (uses flags)

            2'b10:   begin                       // R-type / I-type shifts+arith
                unique case (signal)
                    4'b0000: ALUcontrol = ALU_ADD;
                    4'b1000: ALUcontrol = ALU_SUB;
                    4'b0111: ALUcontrol = ALU_AND;
                    4'b0110: ALUcontrol = ALU_OR;
                    4'b0100: ALUcontrol = ALU_XOR;
                    4'b0010: ALUcontrol = ALU_SLT;
                    4'b0001: ALUcontrol = ALU_SLL;
                    4'b0101: ALUcontrol = ALU_SRL;
                    4'b1101: ALUcontrol = ALU_SRA;
                    default: ALUcontrol = ALU_ADD;
                endcase
            end

            2'b11:   ALUcontrol = ALU_OR;       // LUI: (x0 | imm) = imm

            default: ALUcontrol = ALU_ADD;
        endcase
    end
endmodule
