
`timescale 1ns/1ps
`default_nettype none

// =============================================================================
//  Testbench : maincontrol + alucontrol
//  Tests every opcode path in maincontrol and every aluOp/funct encoding
//  in alucontrol, including R-type, I-type, branch, load/store, and jump ops.
// =============================================================================

module control_tb;

    // -------------------------------------------------------------------------
    // maincontrol DUT signals
    // -------------------------------------------------------------------------
    reg  [6:0] opcode;

    wire       regWrite;
    wire       memRead;
    wire       memWrite;
    wire       memtoReg;
    wire       aluSrc;
    wire [1:0] alu_src_a;
    wire [1:0] aluOp;
    wire [2:0] immSel;
    wire       branch;
    wire       jump;
    wire       jalr;

    // -------------------------------------------------------------------------
    // alucontrol DUT signals
    // -------------------------------------------------------------------------
    reg  [1:0] aluOp_in;
    reg  [2:0] funct3;
    reg  [6:0] funct7;
    wire [3:0] ALUcontrol;

    // -------------------------------------------------------------------------
    // Test tracking
    // -------------------------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // -------------------------------------------------------------------------
    // Opcode localparams (mirrors DUT)
    // -------------------------------------------------------------------------
    localparam Rtype  = 7'b0110011,
               Itype  = 7'b0010011,
               Load   = 7'b0000011,
               Store  = 7'b0100011,
               Branch = 7'b1100011,
               JAL    = 7'b1101111,
               JALR   = 7'b1100111,
               LUI    = 7'b0110111,
               AUIPC  = 7'b0010111;

    // immSel localparams
    localparam I_IMM = 3'b000,
               S_IMM = 3'b001,
               B_IMM = 3'b010,
               U_IMM = 3'b011,
               J_IMM = 3'b100;

    // ALU control localparams (mirrors alucontrol DUT)
    localparam ALU_ADD = 4'b0000,
               ALU_SUB = 4'b1000,
               ALU_AND = 4'b0111,
               ALU_OR  = 4'b0110,
               ALU_XOR = 4'b0100,
               ALU_SLT = 4'b0010,
               ALU_SLL = 4'b0001,
               ALU_SRL = 4'b0101,
               ALU_SRA = 4'b1101;

    // -------------------------------------------------------------------------
    // DUT instantiations
    // -------------------------------------------------------------------------
    maincontrol u_main (
        .opcode    (opcode),
        .regWrite  (regWrite),
        .memRead   (memRead),
        .memWrite  (memWrite),
        .memtoReg  (memtoReg),
        .aluSrc    (aluSrc),
        .alu_src_a (alu_src_a),
        .aluOp     (aluOp),
        .immSel    (immSel),
        .branch    (branch),
        .jump      (jump),
        .jalr      (jalr)
    );

    alucontrol u_alu (
        .aluOp      (aluOp_in),
        .funct3     (funct3),
        .funct7     (funct7),
        .ALUcontrol (ALUcontrol)
    );

    // =========================================================================
    // Tasks
    // =========================================================================

    // -------------------------------------------------------------------------
    // check_main : verify all maincontrol outputs for a given opcode
    // -------------------------------------------------------------------------
    task check_main (
        input [6:0] opc,
        // expected outputs
        input exp_regWrite,
        input exp_memRead,
        input exp_memWrite,
        input exp_memtoReg,
        input exp_aluSrc,
        input [1:0] exp_alu_src_a,
        input [1:0] exp_aluOp,
        input [2:0] exp_immSel,
        input exp_branch,
        input exp_jump,
        input exp_jalr,
        input [127:0] label
    );
        opcode = opc;
        #1; // combinational settle

        if (regWrite  === exp_regWrite  &&
            memRead   === exp_memRead   &&
            memWrite  === exp_memWrite  &&
            memtoReg  === exp_memtoReg  &&
            aluSrc    === exp_aluSrc    &&
            alu_src_a === exp_alu_src_a &&
            aluOp     === exp_aluOp     &&
            immSel    === exp_immSel    &&
            branch    === exp_branch    &&
            jump      === exp_jump      &&
            jalr      === exp_jalr) begin
            $display("[PASS] maincontrol | %0s", label);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] maincontrol | %0s", label);
            if (regWrite  !== exp_regWrite)  $display("       regWrite  got=%b exp=%b", regWrite,  exp_regWrite);
            if (memRead   !== exp_memRead)   $display("       memRead   got=%b exp=%b", memRead,   exp_memRead);
            if (memWrite  !== exp_memWrite)  $display("       memWrite  got=%b exp=%b", memWrite,  exp_memWrite);
            if (memtoReg  !== exp_memtoReg)  $display("       memtoReg  got=%b exp=%b", memtoReg,  exp_memtoReg);
            if (aluSrc    !== exp_aluSrc)    $display("       aluSrc    got=%b exp=%b", aluSrc,    exp_aluSrc);
            if (alu_src_a !== exp_alu_src_a) $display("       alu_src_a got=%b exp=%b", alu_src_a, exp_alu_src_a);
            if (aluOp     !== exp_aluOp)     $display("       aluOp     got=%b exp=%b", aluOp,     exp_aluOp);
            if (immSel    !== exp_immSel)    $display("       immSel    got=%b exp=%b", immSel,    exp_immSel);
            if (branch    !== exp_branch)    $display("       branch    got=%b exp=%b", branch,    exp_branch);
            if (jump      !== exp_jump)      $display("       jump      got=%b exp=%b", jump,      exp_jump);
            if (jalr      !== exp_jalr)      $display("       jalr      got=%b exp=%b", jalr,      exp_jalr);
            fail_count = fail_count + 1;
        end
    endtask

    // -------------------------------------------------------------------------
    // check_alu : verify alucontrol output
    // -------------------------------------------------------------------------
    task check_alu (
        input [1:0]  op,
        input [2:0]  f3,
        input [6:0]  f7,
        input [3:0]  exp_ctrl,
        input [127:0] label
    );
        aluOp_in = op;
        funct3   = f3;
        funct7   = f7;
        #1;

        if (ALUcontrol === exp_ctrl) begin
            $display("[PASS] alucontrol  | %0s", label);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] alucontrol  | %0s | got=%04b exp=%04b", label, ALUcontrol, exp_ctrl);
            fail_count = fail_count + 1;
        end
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;

        // initialise alucontrol inputs to known state
        aluOp_in = 2'b00;
        funct3   = 3'b000;
        funct7   = 7'b000_0000;
        opcode   = 7'b000_0000;

        $display("============================================");
        $display("  Control Unit Testbench -- Start");
        $display("============================================");

        // ====================================================================
        // SECTION 1 : maincontrol ? one test per ISA opcode group
        // Format: check_main(opcode,
        //           regWrite, memRead, memWrite, memtoReg,
        //           aluSrc, alu_src_a, aluOp, immSel,
        //           branch, jump, jalr, "label")
        // ====================================================================
        $display("--- maincontrol: R-type ---");
        // ADD/SUB/AND/OR ? ? register-to-register
        // regWrite=1, no mem, aluSrc=0 (rs2), alu_src_a=00 (rs1), aluOp=10
        check_main(Rtype,
            1, 0, 0, 0,
            0, 2'b00, 2'b10, I_IMM,
            0, 0, 0,
            "R-type: rs1+rs2, aluOp=10, regWrite=1");

        $display("--- maincontrol: I-type ALU ---");
        // ADDI/SLTI/ORI/ANDI/XORI/SLLI/SRLI/SRAI
        // regWrite=1, aluSrc=1 (imm), aluOp=10, immSel=I
        check_main(Itype,
            1, 0, 0, 0,
            1, 2'b00, 2'b10, I_IMM,
            0, 0, 0,
            "I-type ALU: rs1+imm, aluOp=10, regWrite=1, immSel=I");

        $display("--- maincontrol: Load ---");
        // LW/LH/LB/LHU/LBU
        // regWrite=1, memRead=1, memtoReg=1, aluSrc=1, aluOp=00 (ADD), immSel=I
        check_main(Load,
            1, 1, 0, 1,
            1, 2'b00, 2'b00, I_IMM,
            0, 0, 0,
            "Load: addr=rs1+imm, memRead=1, memtoReg=1, aluOp=00");

        $display("--- maincontrol: Store ---");
        // SW/SH/SB
        // regWrite=0, memWrite=1, aluSrc=1, aluOp=00, immSel=S
        check_main(Store,
            0, 0, 1, 0,
            1, 2'b00, 2'b00, S_IMM,
            0, 0, 0,
            "Store: addr=rs1+imm, memWrite=1, aluOp=00, immSel=S");

        $display("--- maincontrol: Branch ---");
        // BEQ/BNE/BLT/BGE/BLTU/BGEU
        // regWrite=0, branch=1, aluOp=01 (SUB/compare), immSel=B
        check_main(Branch,
            0, 0, 0, 0,
            0, 2'b00, 2'b01, B_IMM,
            1, 0, 0,
            "Branch: compare rs1-rs2, branch=1, aluOp=01, immSel=B");

        $display("--- maincontrol: JAL ---");
        // jump=1, regWrite=1 (save PC+4), immSel=J
        check_main(JAL,
            1, 0, 0, 0,
            0, 2'b00, 2'b00, J_IMM,
            0, 1, 0,
            "JAL: jump=1, regWrite=1, immSel=J");

        $display("--- maincontrol: JALR ---");
        // jalr=1, regWrite=1, aluSrc=1 (imm), aluOp=00 (ADD for target), immSel=I
        check_main(JALR,
            1, 0, 0, 0,
            1, 2'b00, 2'b00, I_IMM,
            0, 0, 1,
            "JALR: jalr=1, regWrite=1, aluSrc=1, aluOp=00, immSel=I");

        $display("--- maincontrol: LUI ---");
        // alu_src_a=01 (force 0), aluSrc=1 (imm), regWrite=1, aluOp=00
        check_main(LUI,
            1, 0, 0, 0,
            1, 2'b01, 2'b00, U_IMM,
            0, 0, 0,
            "LUI: alu_src_a=01(zero), aluSrc=1, regWrite=1, immSel=U");

        $display("--- maincontrol: AUIPC ---");
        // alu_src_a=10 (PC), aluSrc=1 (imm), regWrite=1, aluOp=00
        check_main(AUIPC,
            1, 0, 0, 0,
            1, 2'b10, 2'b00, U_IMM,
            0, 0, 0,
            "AUIPC: alu_src_a=10(PC), aluSrc=1, regWrite=1, immSel=U");

        $display("--- maincontrol: Unknown opcode (default) ---");
        // All outputs must be 0 / safe defaults
        check_main(7'b0000000,
            0, 0, 0, 0,
            0, 2'b00, 2'b00, I_IMM,
            0, 0, 0,
            "Default opcode: all outputs at safe zero");

        check_main(7'b1111111,
            0, 0, 0, 0,
            0, 2'b00, 2'b00, I_IMM,
            0, 0, 0,
            "All-ones opcode: all outputs at safe zero");

        // ====================================================================
        // SECTION 2 : alucontrol
        // ====================================================================

        $display("--- alucontrol: aluOp=00 (Load/Store/JALR/LUI/AUIPC -> ADD) ---");
        // aluOp=00 always produces ADD regardless of funct3/funct7
        check_alu(2'b00, 3'b000, 7'b000_0000, ALU_ADD, "aluOp=00, f3=000, f7=0000000 -> ADD");
        check_alu(2'b00, 3'b111, 7'b010_0000, ALU_ADD, "aluOp=00, f3=111, f7=0100000 -> ADD (funct ignored)");
        check_alu(2'b00, 3'b001, 7'b111_1111, ALU_ADD, "aluOp=00, all funct bits 1  -> ADD (funct ignored)");

        $display("--- alucontrol: aluOp=01 (Branch -> SUB) ---");
        // aluOp=01 always produces SUB regardless of funct3/funct7
        check_alu(2'b01, 3'b000, 7'b000_0000, ALU_SUB, "aluOp=01, f3=000, f7=0000000 -> SUB (BEQ)");
        check_alu(2'b01, 3'b001, 7'b000_0000, ALU_SUB, "aluOp=01, f3=001, f7=0000000 -> SUB (BNE)");
        check_alu(2'b01, 3'b100, 7'b000_0000, ALU_SUB, "aluOp=01, f3=100, f7=0000000 -> SUB (BLT)");
        check_alu(2'b01, 3'b111, 7'b010_0000, ALU_SUB, "aluOp=01, f3=111, f7=0100000 -> SUB (funct ignored)");

        $display("--- alucontrol: aluOp=10, R-type / I-type operations ---");

        // ADD  : funct7[5]=0, funct3=000  {signal=0000}
        check_alu(2'b10, 3'b000, 7'b000_0000, ALU_ADD, "aluOp=10, ADD  (f7[5]=0, f3=000)");

        // SUB  : funct7[5]=1, funct3=000  {signal=1000}
        check_alu(2'b10, 3'b000, 7'b010_0000, ALU_SUB, "aluOp=10, SUB  (f7[5]=1, f3=000)");

        // AND  : funct7[5]=0, funct3=111  {signal=0111}
        check_alu(2'b10, 3'b111, 7'b000_0000, ALU_AND, "aluOp=10, AND  (f7[5]=0, f3=111)");

        // OR   : funct7[5]=0, funct3=110  {signal=0110}
        check_alu(2'b10, 3'b110, 7'b000_0000, ALU_OR,  "aluOp=10, OR   (f7[5]=0, f3=110)");

        // XOR  : funct7[5]=0, funct3=100  {signal=0100}
        check_alu(2'b10, 3'b100, 7'b000_0000, ALU_XOR, "aluOp=10, XOR  (f7[5]=0, f3=100)");

        // SLT  : funct7[5]=0, funct3=010  {signal=0010}
        check_alu(2'b10, 3'b010, 7'b000_0000, ALU_SLT, "aluOp=10, SLT  (f7[5]=0, f3=010)");

        // SLL  : funct7[5]=0, funct3=001  {signal=0001}
        check_alu(2'b10, 3'b001, 7'b000_0000, ALU_SLL, "aluOp=10, SLL  (f7[5]=0, f3=001)");

        // SRL  : funct7[5]=0, funct3=101  {signal=0101}
        check_alu(2'b10, 3'b101, 7'b000_0000, ALU_SRL, "aluOp=10, SRL  (f7[5]=0, f3=101)");

        // SRA  : funct7[5]=1, funct3=101  {signal=1101}
        check_alu(2'b10, 3'b101, 7'b010_0000, ALU_SRA, "aluOp=10, SRA  (f7[5]=1, f3=101)");

        $display("--- alucontrol: aluOp=10, I-type ALU (funct7[5] must be 0 for non-shift) ---");
        // For I-type ADDI/ANDI/ORI etc, funct7 field is part of the immediate.
        // alucontrol only uses funct7[5]; for ADDI (f3=000), funct7[5] should be 0.
        // Verifies ADDI (not SUB) path is taken when funct7[5]=0
        check_alu(2'b10, 3'b000, 7'b000_0000, ALU_ADD, "aluOp=10, ADDI (f7[5]=0, f3=000) -> ADD");

        // SRAI vs SRLI: only funct7[5] differs
        check_alu(2'b10, 3'b101, 7'b000_0000, ALU_SRL, "aluOp=10, SRLI (f7[5]=0, f3=101) -> SRL");
        check_alu(2'b10, 3'b101, 7'b010_0000, ALU_SRA, "aluOp=10, SRAI (f7[5]=1, f3=101) -> SRA");

        $display("--- alucontrol: aluOp=10, default (unrecognised signal -> ADD) ---");
        // {funct7[5]=1, funct3=001} = 4'b1001 ? no matching case -> default ADD
        check_alu(2'b10, 3'b001, 7'b010_0000, ALU_ADD, "aluOp=10, unrecognised signal=1001 -> default ADD");
        // {funct7[5]=1, funct3=110} = 4'b1110 ? no matching case
        check_alu(2'b10, 3'b110, 7'b010_0000, ALU_ADD, "aluOp=10, unrecognised signal=1110 -> default ADD");

        $display("--- alucontrol: aluOp=11 (undefined -> default ADD) ---");
        check_alu(2'b11, 3'b000, 7'b000_0000, ALU_ADD, "aluOp=11 undefined -> ADD");
        check_alu(2'b11, 3'b111, 7'b010_0000, ALU_ADD, "aluOp=11 undefined, all funct set -> ADD");

        // ====================================================================
        // SECTION 3 : Integration ? maincontrol drives alucontrol
        // Feed opcode into maincontrol, wire aluOp into alucontrol, verify
        // the combined ALUcontrol signal for key instruction types.
        // ====================================================================
        $display("--- Integration: maincontrol.aluOp -> alucontrol ---");

        // R-type ADD:  aluOp=10, funct3=000, funct7=0000000 -> ALU_ADD
        opcode   = Rtype; #1;
        aluOp_in = aluOp;
        funct3   = 3'b000; funct7 = 7'b000_0000; #1;
        if (ALUcontrol === ALU_ADD) begin
            $display("[PASS] Integration | R-type ADD:  aluOp=%02b -> ALUctrl=%04b (ADD)", aluOp, ALUcontrol);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Integration | R-type ADD:  got ALUctrl=%04b, exp=%04b", ALUcontrol, ALU_ADD);
            fail_count = fail_count + 1;
        end

        // R-type SUB:  aluOp=10, funct3=000, funct7=0100000 -> ALU_SUB
        aluOp_in = aluOp;
        funct3   = 3'b000; funct7 = 7'b010_0000; #1;
        if (ALUcontrol === ALU_SUB) begin
            $display("[PASS] Integration | R-type SUB:  aluOp=%02b -> ALUctrl=%04b (SUB)", aluOp, ALUcontrol);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Integration | R-type SUB:  got ALUctrl=%04b, exp=%04b", ALUcontrol, ALU_SUB);
            fail_count = fail_count + 1;
        end

        // Load:  aluOp=00 -> always ADD regardless of funct
        opcode   = Load; #1;
        aluOp_in = aluOp;
        funct3   = 3'b010; funct7 = 7'b000_0000; #1;  // LW
        if (ALUcontrol === ALU_ADD) begin
            $display("[PASS] Integration | Load  (LW):  aluOp=%02b -> ALUctrl=%04b (ADD)", aluOp, ALUcontrol);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Integration | Load  (LW):  got ALUctrl=%04b, exp=%04b", ALUcontrol, ALU_ADD);
            fail_count = fail_count + 1;
        end

        // Branch BEQ: aluOp=01 -> always SUB
        opcode   = Branch; #1;
        aluOp_in = aluOp;
        funct3   = 3'b000; funct7 = 7'b000_0000; #1;
        if (ALUcontrol === ALU_SUB) begin
            $display("[PASS] Integration | Branch BEQ:  aluOp=%02b -> ALUctrl=%04b (SUB)", aluOp, ALUcontrol);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Integration | Branch BEQ:  got ALUctrl=%04b, exp=%04b", ALUcontrol, ALU_SUB);
            fail_count = fail_count + 1;
        end

        // JALR: aluOp=00 -> ADD (rs1+imm for target)
        opcode   = JALR; #1;
        aluOp_in = aluOp;
        funct3   = 3'b000; funct7 = 7'b000_0000; #1;
        if (ALUcontrol === ALU_ADD) begin
            $display("[PASS] Integration | JALR:        aluOp=%02b -> ALUctrl=%04b (ADD)", aluOp, ALUcontrol);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Integration | JALR:        got ALUctrl=%04b, exp=%04b", ALUcontrol, ALU_ADD);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Summary
        // ====================================================================
        $display("============================================");
        $display("  Results: %0d PASSED  |  %0d FAILED", pass_count, fail_count);
        $display("============================================");
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED -- review above");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #50000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule

`default_nettype wire