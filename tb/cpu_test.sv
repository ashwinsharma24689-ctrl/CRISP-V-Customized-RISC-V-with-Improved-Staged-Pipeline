// ============================================================================
//  tb_riscv_cpu.sv ? Comprehensive Verification Suite
//  RISC-V Single-Cycle CPU
//
//  Structure
//  ?????????
//  PART A ? Unit tests  (each module exercised in isolation)
//    A1 : Immediate Generator
//    A2 : ALU  (using alu.v localparams directly)
//    A3 : ALU-Control encoding cross-check  ? exposes BUG-1
//    A4 : Register File
//    A5 : Data Memory
//    A6 : Main Control signals
//
//  PART B ? CPU Integration tests  (full-chip programs)
//    B1 : ADDI  (I-type)
//    B2 : R-Type  ADD / SUB / AND / OR / XOR / SLT
//    B3 : Shifts  SLLI / SRLI / SRAI
//    B4 : Load / Store  SW + LW
//    B5 : Branch  BEQ (taken + not-taken)
//    B6 : JAL
//    B7 : JALR
//    B8 : LUI
//    B9 : x0 hardwired to zero
//    B10: Sequential dependency  (no pipeline hazards expected)
//
//  Known design bugs flagged in the summary:
//    BUG-1  alucontrol constants ? alu.v localparams ? wrong ALU op
//    BUG-2  cputop.v: maincontrol ports immSel & jalr not wired
//    BUG-3  PC.v: branch condition is "branch && zero" only (BEQ only)
//    BUG-4  AUIPC: rs1_data used instead of PC
// ============================================================================
`timescale 1ns / 1ps

module tb_riscv_cpu;

    // ??????????????????????????????????????????????????????????????????????
    // 1.  CLOCK  &  RESET
    // ??????????????????????????????????????????????????????????????????????
    logic clk = 0;
    logic reset;
    always #5 clk = ~clk;   // 100 MHz  (10 ns period)

    // ??????????????????????????????????????????????????????????????????????
    // 2.  CPU DUT
    // ??????????????????????????????????????????????????????????????????????
    cpu dut ( .clk(clk), .reset(reset) );

    // ??????????????????????????????????????????????????????????????????????
    // 3.  UNIT-TEST SUB-DUTs
    // ??????????????????????????????????????????????????????????????????????

    // --- A2 / A3 : ALU + ALU-Control ---
    logic [31:0] u_a, u_b, u_res;
    logic [3:0]  u_alu_ctrl;
    logic        u_zero, u_comp, u_carry, u_sign, u_borrow, u_ovf;

    alu u_alu (
        .operand_a  (u_a),
        .operand_b  (u_b),
        .alu_control(u_alu_ctrl),
        .alu_result (u_res),
        .zero_flag  (u_zero),
        .comp_flag  (u_comp),
        .carry_flag (u_carry),
        .sign_bit   (u_sign),
        .borrow     (u_borrow),
        .overflow   (u_ovf)
    );

    logic [1:0] u_aluOp;
    logic [2:0] u_f3;
    logic [6:0] u_f7;
    logic [3:0] u_aluctrl_out;

    alucontrol u_aluctrl (
        .aluOp     (u_aluOp),
        .funct3    (u_f3),
        .funct7    (u_f7),
        .ALUcontrol(u_aluctrl_out)
    );

    // --- A1 : Immediate Generator ---
    logic [31:0] u_instr, u_imm;
    logic [2:0]  u_immsel;

    immediate_generator u_immgen (
        .instruction(u_instr),
        .immSel     (u_immsel),
        .immOut     (u_imm)
    );

    // --- A4 : Register File ---
    logic        rf_wen, rf_clk, rf_rst;
    logic [4:0]  rf_sr1, rf_sr2, rf_wr;
    logic [31:0] rf_wd, rf_rs1, rf_rs2;

    reg_array u_rf (
        .sr1         (rf_sr1),
        .sr2         (rf_sr2),
        .wr          (rf_wr),
        .wd          (rf_wd),
        .write_enable(rf_wen),
        .clk         (rf_clk),
        .rst         (rf_rst),
        .rs1         (rf_rs1),
        .rs2         (rf_rs2)
    );

    always #5 rf_clk = ~rf_clk;   // independent clock for RF unit test

    // --- A5 : Data Memory ---
    logic        dm_clk, dm_rd_en, dm_wr_en;
    logic [31:0] dm_addr, dm_wdata, dm_rdata;

    datamemory u_dmem (
        .clk      (dm_clk),
        .memRead  (dm_rd_en),
        .memWrite (dm_wr_en),
        .address  (dm_addr),
        .writeData(dm_wdata),
        .readData (dm_rdata)
    );

    always #5 dm_clk = ~dm_clk;

    // --- A6 : Main Control ---
    logic [6:0] mc_opcode;
    logic       mc_regWrite, mc_memRead, mc_memWrite, mc_memtoReg;
    logic       mc_aluSrc, mc_branch, mc_jump, mc_jalr;
    logic [1:0] mc_aluOp;
    logic [2:0] mc_immSel;

    maincontrol u_mc (
        .opcode  (mc_opcode),
        .regWrite(mc_regWrite),
        .memRead (mc_memRead),
        .memWrite(mc_memWrite),
        .memtoReg(mc_memtoReg),
        .aluSrc  (mc_aluSrc),
        .branch  (mc_branch),
        .jump    (mc_jump),
        .jalr    (mc_jalr),
        .aluOp   (mc_aluOp),
        .immSel  (mc_immSel)
    );

    // ??????????????????????????????????????????????????????????????????????
    // 4.  SCOREBOARD
    // ??????????????????????????????????????????????????????????????????????
    int pass_cnt = 0, fail_cnt = 0;

    // Generic value checker
    task automatic chk (
        input logic [31:0] got,
        input logic [31:0] exp,
        input string       lbl
    );
        if (got === exp) begin
            $display("   PASS | %-52s | 0x%08h", lbl, got);
            pass_cnt++;
        end else begin
            $display("   FAIL | %-52s | got 0x%08h  exp 0x%08h", lbl, got, exp);
            fail_cnt++;
        end
    endtask

    // Register file checker (through CPU hierarchical path)
    task automatic chk_reg (
        input [4:0]  rn,
        input [31:0] exp,
        input string lbl
    );
        chk(dut.RF.register_array[rn], exp, lbl);
    endtask

    // Data memory checker (through CPU hierarchical path, word index)
    task automatic chk_dmem (
        input int    widx,
        input [31:0] exp,
        input string lbl
    );
        chk(dut.DMEM.memory[widx], exp, lbl);
    endtask

    // Section header
    task automatic hdr (input string s);
        $display("\n ??? %s", s);
    endtask

    // ??????????????????????????????????????????????????????????????????????
    // 5.  CPU HELPER TASKS
    // ??????????????????????????????????????????????????????????????????????

    // Fill instruction memory with NOPs (ADDI x0, x0, 0)
    task automatic clear_imem ();
        for (int i = 0; i < 256; i++)
            dut.IMEM.memory[i] = 32'h0000_0013;
    endtask

    // Load program from array into instruction memory starting at index 0
    task automatic write_imem (input [31:0] prog []);
        foreach (prog[i])
            dut.IMEM.memory[i] = prog[i];
    endtask

    // Assert reset for 2 cycles, release, then run n more cycles
    task automatic rst_run (input int n);
        reset = 1;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;
        repeat (n) @(posedge clk);
        #1;   // let combinational outputs settle
    endtask

    // ??????????????????????????????????????????????????????????????????????
    // MAIN TEST SEQUENCE
    // ??????????????????????????????????????????????????????????????????????
    initial begin
        $dumpfile("tb_riscv_cpu.vcd");
        $dumpvars(0, tb_riscv_cpu);

        rf_clk = 0; dm_clk = 0;
        rf_rst = 1; rf_wen = 0;
        dm_rd_en = 0; dm_wr_en = 0;
        reset = 1;

        $display("");
        $display("????????????????????????????????????????????????????????????????");
        $display("?       RISC-V Single-Cycle CPU ? Verification Suite          ?");
        $display("????????????????????????????????????????????????????????????????");

        // ==================================================================
        //  PART A ? UNIT TESTS
        // ==================================================================
        $display("\n????????????????????????????????????????????????????????????????");
        $display("?                PART A ? Module Unit Tests                   ?");
        $display("????????????????????????????????????????????????????????????????");

        // ------------------------------------------------------------------
        // A1 : Immediate Generator
        //      Instruction encodings tested match the immediate they carry.
        // ------------------------------------------------------------------
        hdr("A1: Immediate Generator");

        // I-type  (immSel=000)
        // ADDI x1, x0, 5 ? imm = +5
        u_instr = 32'h0050_0093; u_immsel = 3'b000; #2;
        chk(u_imm, 32'd5,          "I-type  ADDI x1,x0,5       ? imm = 5");

        // ADDI x1, x0, -1 ? imm = 0xFFFF_FFFF
        u_instr = 32'hFFF0_0093; u_immsel = 3'b000; #2;
        chk(u_imm, 32'hFFFF_FFFF,  "I-type  ADDI x1,x0,-1      ? imm = 0xFFFFFFFF");

        // ADDI x1, x0, -256 ? imm = 0xFFFF_FF00
        u_instr = 32'hF000_0093; u_immsel = 3'b000; #2;
        chk(u_imm, 32'hFFFF_FF00,  "I-type  ADDI x1,x0,-256    ? imm = 0xFFFFFF00");

        // S-type  (immSel=001)
        // SW x1, 4(x0) ? imm = 4
        // encoding: 0000000_00001_00000_010_00100_0100011 = 0x0010_2223
        u_instr = 32'h0010_2223; u_immsel = 3'b001; #2;
        chk(u_imm, 32'd4,          "S-type  SW x1,4(x0)        ? imm = 4");

        // SW x2, -4(x0) ? imm = -4 = 0xFFFF_FFFC
        // imm[11:5]=1111111, imm[4:0]=11100
        // 1111111_00010_00000_010_11100_0100011 = 0xFE20_2E23
        u_instr = 32'hFE20_2E23; u_immsel = 3'b001; #2;
        chk(u_imm, 32'hFFFF_FFFC, "S-type  SW x2,-4(x0)       ? imm = -4");

        // B-type  (immSel=010)
        // BEQ x1, x2, +8 ? imm = 8
        // encoding: 0_000000_00010_00001_000_0100_0_1100011 = 0x0020_8463
        u_instr = 32'h0020_8463; u_immsel = 3'b010; #2;
        chk(u_imm, 32'd8,          "B-type  BEQ x1,x2,+8       ? imm = 8");

        // BNE x1, x2, -8 ? imm = -8 = 0xFFFF_FFF8
        // offset=-8: imm[12]=1,imm[11]=1,imm[10:5]=111111,imm[4:1]=1100
        // 1_111111_00010_00001_001_1100_1_1100011 = 0xFE20_9CE3
        u_instr = 32'hFE20_9CE3; u_immsel = 3'b010; #2;
        chk(u_imm, 32'hFFFF_FFF8, "B-type  BNE x1,x2,-8       ? imm = -8");

        // U-type  (immSel=011)
        // LUI x1, 1 ? imm = 0x0000_1000
        u_instr = 32'h0000_10B7; u_immsel = 3'b011; #2;
        chk(u_imm, 32'h0000_1000, "U-type  LUI x1,1           ? imm = 0x00001000");

        // LUI x2, 0xDEADB ? imm = 0xDEAD_B000
        u_instr = 32'hDEAD_B137; u_immsel = 3'b011; #2;
        chk(u_imm, 32'hDEAD_B000, "U-type  LUI x2,0xDEADB     ? imm = 0xDEADB000");

        // J-type  (immSel=100)
        // JAL x1, +8 ? imm = 8
        // encoding: 0_0000001_00_0_00000000_00001_1101111 = 0x0080_00EF
        u_instr = 32'h0080_00EF; u_immsel = 3'b100; #2;
        chk(u_imm, 32'd8,          "J-type  JAL x1,+8          ? imm = 8");

        // JAL x1, -4 ? imm = -4 = 0xFFFF_FFFC
        // imm=-4: [20]=1,[19:12]=11111111,[11]=1,[10:1]=1111111110
        // 1_1111111110_1_11111111_00001_1101111 = 0xFFDFF0EF
        u_instr = 32'hFFDF_F0EF; u_immsel = 3'b100; #2;
        chk(u_imm, 32'hFFFF_FFFC, "J-type  JAL x1,-4          ? imm = -4");

        // ------------------------------------------------------------------
        // A2 : ALU  (using alu.v localparams  ? direct control-code test)
        //      ADD=0000, SUB=1000, AND=0111, OR=0110, XOR=0100,
        //      SLT=0010, SLL=0001, SRL=0101, SRA=1101
        // ------------------------------------------------------------------
        hdr("A2: ALU ? direct control-code tests (using alu.v encoding)");

        // ADD
        u_a = 32'd15;          u_b = 32'd10;          u_alu_ctrl = 4'b0000; #2;
        chk(u_res, 32'd25,          "ALU ADD  15+10                  = 25");

        u_a = 32'h7FFF_FFFF;   u_b = 32'd1;           u_alu_ctrl = 4'b0000; #2;
        chk(u_res, 32'h8000_0000,   "ALU ADD  0x7FFFFFFF+1 (overflow)= 0x80000000");
        chk({31'd0, u_ovf}, 32'd1,  "ALU ADD  overflow flag set");
        chk({31'd0, u_carry}, 32'd0,"ALU ADD  carry flag clear");

        // SUB
        u_a = 32'd15;          u_b = 32'd10;          u_alu_ctrl = 4'b1000; #2;
        chk(u_res, 32'd5,           "ALU SUB  15-10                  = 5");
        chk({31'd0, u_borrow}, 32'd0,"ALU SUB  no borrow");

        u_a = 32'd5;           u_b = 32'd5;            u_alu_ctrl = 4'b1000; #2;
        chk(u_res, 32'd0,           "ALU SUB  5-5                    = 0");
        chk({31'd0, u_zero}, 32'd1, "ALU SUB  zero flag set");

        u_a = 32'd3;           u_b = 32'd10;           u_alu_ctrl = 4'b1000; #2;
        chk(u_res, 32'hFFFF_FFF9,   "ALU SUB  3-10 (borrow)          = -7");
        chk({31'd0, u_borrow}, 32'd1,"ALU SUB  borrow flag set");

        // AND
        u_a = 32'hF0F0_F0F0; u_b = 32'h0F0F_0F0F; u_alu_ctrl = 4'b0111; #2;
        chk(u_res, 32'h0000_0000,  "ALU AND  0xF0F0F0F0 & 0x0F0F0F0F = 0");

        u_a = 32'hFFFF_FFFF; u_b = 32'hA5A5_A5A5; u_alu_ctrl = 4'b0111; #2;
        chk(u_res, 32'hA5A5_A5A5, "ALU AND  0xFFFFFFFF & 0xA5A5A5A5 = 0xA5A5A5A5");

        // OR
        u_a = 32'hF0F0_F0F0; u_b = 32'h0F0F_0F0F; u_alu_ctrl = 4'b0110; #2;
        chk(u_res, 32'hFFFF_FFFF, "ALU OR   0xF0F0F0F0 | 0x0F0F0F0F = 0xFFFFFFFF");

        u_a = 32'h0000_0000; u_b = 32'h0000_0000; u_alu_ctrl = 4'b0110; #2;
        chk(u_res, 32'h0000_0000, "ALU OR   0 | 0                    = 0");

        // XOR
        u_a = 32'hAAAA_AAAA; u_b = 32'h5555_5555; u_alu_ctrl = 4'b0100; #2;
        chk(u_res, 32'hFFFF_FFFF, "ALU XOR  0xAAAAAAAA ^ 0x55555555  = 0xFFFFFFFF");

        u_a = 32'hDEAD_BEEF; u_b = 32'hDEAD_BEEF; u_alu_ctrl = 4'b0100; #2;
        chk(u_res, 32'h0000_0000, "ALU XOR  X ^ X                   = 0");
        chk({31'd0,u_zero}, 32'd1, "ALU XOR  zero flag set on X^X");

        // SLT  (signed less-than)
        u_a = 32'd5;           u_b = 32'd10;           u_alu_ctrl = 4'b0010; #2;
        chk(u_res, 32'd1,          "ALU SLT  5 < 10                 = 1");

        u_a = 32'd10;          u_b = 32'd5;            u_alu_ctrl = 4'b0010; #2;
        chk(u_res, 32'd0,          "ALU SLT  10 < 5                 = 0");

        u_a = 32'hFFFF_FFFF; u_b = 32'd0;             u_alu_ctrl = 4'b0010; #2;
        chk(u_res, 32'd1,          "ALU SLT  -1 < 0 (signed)        = 1");

        u_a = 32'd1;           u_b = 32'hFFFF_FFFF;   u_alu_ctrl = 4'b0010; #2;
        chk(u_res, 32'd0,          "ALU SLT  1 < -1 (signed)        = 0");

        // SLL
        u_a = 32'd1;           u_b = 32'd4;            u_alu_ctrl = 4'b0001; #2;
        chk(u_res, 32'd16,         "ALU SLL  1 << 4                 = 16");

        u_a = 32'h0000_0001; u_b = 32'd31;             u_alu_ctrl = 4'b0001; #2;
        chk(u_res, 32'h8000_0000,  "ALU SLL  1 << 31                = 0x80000000");

        // SRL
        u_a = 32'h8000_0000; u_b = 32'd1;             u_alu_ctrl = 4'b0101; #2;
        chk(u_res, 32'h4000_0000,  "ALU SRL  0x80000000 >> 1        = 0x40000000");

        u_a = 32'hFFFF_FFFF; u_b = 32'd4;             u_alu_ctrl = 4'b0101; #2;
        chk(u_res, 32'h0FFF_FFFF,  "ALU SRL  0xFFFFFFFF >> 4        = 0x0FFFFFFF");

        // SRA
        u_a = 32'h8000_0000; u_b = 32'd1;             u_alu_ctrl = 4'b1101; #2;
        chk(u_res, 32'hC000_0000,  "ALU SRA  0x80000000 >>> 1       = 0xC0000000");

        u_a = 32'hFFFF_FFFF; u_b = 32'd4;             u_alu_ctrl = 4'b1101; #2;
        chk(u_res, 32'hFFFF_FFFF,  "ALU SRA  0xFFFFFFFF >>> 4       = 0xFFFFFFFF");

        // ------------------------------------------------------------------
        // A3 : ALU Control ? encoding cross-check
        //      Checks whether alucontrol's outputs match alu.v localparams.
        //      *** This section will FAIL if BUG-1 is present. ***
        // ------------------------------------------------------------------
        hdr("A3: ALU Control ? encoding verification against alu.v localparams");
        $display("       (FAIL here indicates BUG-1: encoding mismatch)");

        //  aluOp=10 (R-type / I-type) ? expected alu.v encoding
        u_aluOp = 2'b10; u_f7 = 7'h00;
        u_f3 = 3'b000; #2; chk({28'd0,u_aluctrl_out},{28'd0,4'b0000},"ALUctrl R-ADD  signal=0000 ? expect 4'b0000");
        u_f3 = 3'b000; u_f7 = 7'h20; #2; chk({28'd0,u_aluctrl_out},{28'd0,4'b1000},"ALUctrl R-SUB  signal=1000 ? expect 4'b1000");
        u_f7 = 7'h00;
        u_f3 = 3'b111; #2; chk({28'd0,u_aluctrl_out},{28'd0,4'b0111},"ALUctrl R-AND  signal=0111 ? expect 4'b0111");
        u_f3 = 3'b110; #2; chk({28'd0,u_aluctrl_out},{28'd0,4'b0110},"ALUctrl R-OR   signal=0110 ? expect 4'b0110");
        u_f3 = 3'b100; #2; chk({28'd0,u_aluctrl_out},{28'd0,4'b0100},"ALUctrl R-XOR  signal=0100 ? expect 4'b0100");
        u_f3 = 3'b010; #2; chk({28'd0,u_aluctrl_out},{28'd0,4'b0010},"ALUctrl R-SLT  signal=0010 ? expect 4'b0010");
        u_f3 = 3'b001; #2; chk({28'd0,u_aluctrl_out},{28'd0,4'b0001},"ALUctrl R-SLL  signal=0001 ? expect 4'b0001");
        u_f3 = 3'b101; #2; chk({28'd0,u_aluctrl_out},{28'd0,4'b0101},"ALUctrl R-SRL  signal=0101 ? expect 4'b0101");
        u_f3 = 3'b101; u_f7 = 7'h20; #2; chk({28'd0,u_aluctrl_out},{28'd0,4'b1101},"ALUctrl R-SRA  signal=1101 ? expect 4'b1101");

        //  aluOp=00  (Load / Store ? ADD)
        u_aluOp = 2'b00; u_f3 = 3'bxxx; u_f7 = 7'bxxxxxxx; #2;
        chk({28'd0,u_aluctrl_out},{28'd0,4'b0000},"ALUctrl Load/Store  aluOp=00 ? expect 4'b0000 (ADD)");

        //  aluOp=01  (Branch ? SUB, checks zero flag)
        u_aluOp = 2'b01; u_f3 = 3'bxxx; u_f7 = 7'bxxxxxxx; #2;
        chk({28'd0,u_aluctrl_out},{28'd0,4'b1000},"ALUctrl Branch      aluOp=01 ? expect 4'b1000 (SUB)");

        // ------------------------------------------------------------------
        // A4 : Register File
        // ------------------------------------------------------------------
        hdr("A4: Register File");

        // Reset
        rf_rst = 1; @(posedge rf_clk); @(negedge rf_clk); rf_rst = 0;

        // Write x1 = 0xDEAD_BEEF
        rf_wr = 5'd1; rf_wd = 32'hDEAD_BEEF; rf_wen = 1;
        @(posedge rf_clk); @(negedge rf_clk); rf_wen = 0;
        rf_sr1 = 5'd1; rf_sr2 = 5'd0; #2;
        chk(rf_rs1, 32'hDEAD_BEEF, "RF write x1=0xDEADBEEF, read back rs1");

        // Write x2 = 42
        rf_wr = 5'd2; rf_wd = 32'd42; rf_wen = 1;
        @(posedge rf_clk); @(negedge rf_clk); rf_wen = 0;
        rf_sr1 = 5'd1; rf_sr2 = 5'd2; #2;
        chk(rf_rs1, 32'hDEAD_BEEF, "RF simultaneous read rs1=x1=0xDEADBEEF");
        chk(rf_rs2, 32'd42,         "RF simultaneous read rs2=x2=42");

        // x0 must always read as 0
        rf_wr = 5'd0; rf_wd = 32'hFFFF_FFFF; rf_wen = 1;
        @(posedge rf_clk); @(negedge rf_clk); rf_wen = 0;
        rf_sr1 = 5'd0; #2;
        chk(rf_rs1, 32'd0,          "RF x0 hardwired to 0 (write ignored)");

        // ------------------------------------------------------------------
        // A5 : Data Memory
        // ------------------------------------------------------------------
        hdr("A5: Data Memory ? word-aligned SW / LW");

        dm_wr_en = 1; dm_rd_en = 0;
        dm_addr = 32'h0000_0000; dm_wdata = 32'hCAFE_BABE;
        @(posedge dm_clk); @(negedge dm_clk);
        dm_addr = 32'h0000_0004; dm_wdata = 32'h1234_5678;
        @(posedge dm_clk); @(negedge dm_clk);
        dm_wr_en = 0;

        dm_rd_en = 1;
        dm_addr = 32'h0000_0000; #2;
        chk(dm_rdata, 32'hCAFE_BABE, "DMEM write 0xCAFEBABE @ addr 0, read back");
        dm_addr = 32'h0000_0004; #2;
        chk(dm_rdata, 32'h1234_5678, "DMEM write 0x12345678 @ addr 4, read back");

        // Out-of-range read must return 0
        dm_addr = 32'hFFFF_FFFF; #2;
        chk(dm_rdata, 32'd0,         "DMEM out-of-range read      ? 0");
        dm_rd_en = 0;

        // ------------------------------------------------------------------
        // A6 : Main Control
        // ------------------------------------------------------------------
        hdr("A6: Main Control ? control signal verification");

        //  R-type
        mc_opcode = 7'b011_0011; #2;
        chk({27'd0, mc_regWrite, mc_memRead, mc_memWrite, mc_aluSrc, mc_branch},
             32'b0_0001_0000_0, "MainCtrl R-type: regWrite=1 others=0");
        chk({30'd0, mc_aluOp}, 32'd2, "MainCtrl R-type: aluOp=10");

        //  I-type (ADDI)
        mc_opcode = 7'b001_0011; #2;
        chk({27'd0, mc_regWrite, mc_memRead, mc_memWrite, mc_aluSrc, mc_branch},
             32'b0_0001_0010_0, "MainCtrl I-type: regWrite=1 aluSrc=1");

        //  Load
        mc_opcode = 7'b000_0011; #2;
        chk({27'd0, mc_regWrite, mc_memRead, mc_memtoReg, mc_aluSrc, mc_branch},
             32'b0_0001_1110_0, "MainCtrl Load: regW memR memtoReg aluSrc all set");

        //  Store
        mc_opcode = 7'b010_0011; #2;
        chk({28'd0, mc_memWrite, mc_aluSrc, mc_regWrite, mc_branch},
             32'b0_0000_0110_0, "MainCtrl Store: memWrite=1 aluSrc=1");

        //  Branch
        mc_opcode = 7'b110_0011; #2;
        chk({29'd0, mc_branch, mc_jump, mc_jalr},
             32'b0_0000_0001_00, "MainCtrl Branch: branch=1");
        chk({30'd0, mc_aluOp}, 32'd1, "MainCtrl Branch: aluOp=01");

        //  JAL
        mc_opcode = 7'b110_1111; #2;
        chk({29'd0, mc_jump, mc_regWrite, mc_jalr},
             32'b0_0000_0001_10, "MainCtrl JAL: jump=1 regWrite=1");

        //  JALR
        mc_opcode = 7'b110_0111; #2;
        chk({29'd0, mc_jalr, mc_regWrite, mc_aluSrc},
             32'b0_0000_0001_11, "MainCtrl JALR: jalr=1 regWrite=1 aluSrc=1");

        //  LUI
        mc_opcode = 7'b011_0111; #2;
        chk({29'd0, mc_regWrite, mc_aluSrc, mc_branch},
             32'b0_0000_0001_10, "MainCtrl LUI: regWrite=1 aluSrc=1");
        chk({29'd0, mc_immSel},
             {29'd0, 3'b011},    "MainCtrl LUI: immSel=011 (U-type)");

        // ==================================================================
        //  PART B ? INTEGRATION TESTS
        // ==================================================================
        $display("\n????????????????????????????????????????????????????????????????");
        $display("?              PART B ? CPU Integration Tests                 ?");
        $display("????????????????????????????????????????????????????????????????");
        $display("  NOTE: BUG-1 (alucontrol encoding) and BUG-2 (immSel/jalr");
        $display("  not wired in cputop) will cause many integration tests to");
        $display("  FAIL. Fix those bugs first to make these tests pass.");

        // ------------------------------------------------------------------
        // B1 : I-Type  ADDI
        //
        //  Instruction encodings (all verified manually):
        //    32'h0050_0093  ?  ADDI x1, x0,  5
        //    32'h00A0_0113  ?  ADDI x2, x0, 10
        //    32'hFFF0_0193  ?  ADDI x3, x0, -1
        //    32'h0040_8213  ?  ADDI x4, x1,  4
        // ------------------------------------------------------------------
        hdr("B1: I-Type ? ADDI");
        clear_imem();
        write_imem('{
            32'h0050_0093,   // 0: ADDI x1, x0,  5   ? x1 = 5
            32'h00A0_0113,   // 1: ADDI x2, x0, 10   ? x2 = 10
            32'hFFF0_0193,   // 2: ADDI x3, x0, -1   ? x3 = 0xFFFF_FFFF
            32'h0040_8213    // 3: ADDI x4, x1,  4   ? x4 = 9
        });
        rst_run(8);
        chk_reg(1, 32'd5,          "ADDI x1 = 5");
        chk_reg(2, 32'd10,         "ADDI x2 = 10");
        chk_reg(3, 32'hFFFF_FFFF,  "ADDI x3 = -1  (0xFFFFFFFF)");
        chk_reg(4, 32'd9,          "ADDI x4 = x1+4 = 9");

        // ------------------------------------------------------------------
        // B2 : R-Type  ADD / SUB / AND / OR / XOR / SLT
        //
        //    32'h0020_81B3  ?  ADD  x3,  x1, x2
        //    32'h4020_8233  ?  SUB  x4,  x1, x2
        //    32'h0020_F2B3  ?  AND  x5,  x1, x2
        //    32'h0020_E333  ?  OR   x6,  x1, x2
        //    32'h0020_C3B3  ?  XOR  x7,  x1, x2
        //    32'h0020_A433  ?  SLT  x8,  x1, x2  (x1<x2 ? 1)
        //    32'h0011_24B3  ?  SLT  x9,  x2, x1  (x2<x1 ? 0)
        // ------------------------------------------------------------------
        hdr("B2: R-Type ? ADD / SUB / AND / OR / XOR / SLT");
        clear_imem();
        write_imem('{
            32'h0050_0093,   // 0: ADDI x1, x0,  5   ? x1=5
            32'h00A0_0113,   // 1: ADDI x2, x0, 10   ? x2=10
            32'h0020_81B3,   // 2: ADD  x3, x1, x2   ? x3=15
            32'h4020_8233,   // 3: SUB  x4, x1, x2   ? x4=-5   (0xFFFFFFFB)
            32'h0020_F2B3,   // 4: AND  x5, x1, x2   ? x5=0    (0101&1010)
            32'h0020_E333,   // 5: OR   x6, x1, x2   ? x6=15   (0101|1010)
            32'h0020_C3B3,   // 6: XOR  x7, x1, x2   ? x7=15   (0101^1010)
            32'h0020_A433,   // 7: SLT  x8, x1, x2   ? x8=1    (5<10)
            32'h0011_24B3    // 8: SLT  x9, x2, x1   ? x9=0    (10<5 false)
        });
        rst_run(15);
        chk_reg( 3, 32'd15,        "ADD  x3 = x1+x2 = 15");
        chk_reg( 4, 32'hFFFF_FFFB, "SUB  x4 = x1-x2 = -5");
        chk_reg( 5, 32'd0,         "AND  x5 = 0101 & 1010 = 0");
        chk_reg( 6, 32'd15,        "OR   x6 = 0101 | 1010 = 15");
        chk_reg( 7, 32'd15,        "XOR  x7 = 0101 ^ 1010 = 15");
        chk_reg( 8, 32'd1,         "SLT  x8 = (5 < 10) = 1");
        chk_reg( 9, 32'd0,         "SLT  x9 = (10 < 5) = 0");

        // ------------------------------------------------------------------
        // B3 : Shifts  SLLI / SRLI / SRAI
        //
        //    32'h0020_9113  ?  SLLI x2, x1,  2   (I-type shift)
        //    32'h0041_D213  ?  SRLI x4, x3,  4
        //    32'h4041_D293  ?  SRAI x5, x3,  4   (funct7[5]=1)
        // ------------------------------------------------------------------
        hdr("B3: Shifts ? SLLI / SRLI / SRAI");
        clear_imem();
        write_imem('{
            32'h0010_0093,   // 0: ADDI x1, x0,  1   ? x1 = 1
            32'h0020_9113,   // 1: SLLI x2, x1,  2   ? x2 = 4
            32'hFFF0_0193,   // 2: ADDI x3, x0, -1   ? x3 = 0xFFFFFFFF
            32'h0041_D213,   // 3: SRLI x4, x3,  4   ? x4 = 0x0FFFFFFF
            32'h4041_D293    // 4: SRAI x5, x3,  4   ? x5 = 0xFFFFFFFF (sign extended)
        });
        rst_run(10);
        chk_reg(1, 32'd1,          "ADDI x1 = 1");
        chk_reg(2, 32'd4,          "SLLI x2 = x1 <<  2 = 4");
        chk_reg(3, 32'hFFFF_FFFF,  "ADDI x3 = -1");
        chk_reg(4, 32'h0FFF_FFFF,  "SRLI x4 = x3 >>  4 = 0x0FFFFFFF");
        chk_reg(5, 32'hFFFF_FFFF,  "SRAI x5 = x3 >>> 4 = 0xFFFFFFFF (sign-extended)");

        // ------------------------------------------------------------------
        // B4 : Load / Store  SW + LW
        //
        //    32'h02A0_0093  ?  ADDI x1, x0, 42      x1=42
        //    32'h0640_0113  ?  ADDI x2, x0, 100     x2=100
        //    32'h0010_2023  ?  SW   x1, 0(x0)       mem[0]=42
        //    32'h0020_2223  ?  SW   x2, 4(x0)       mem[1]=100
        //    32'h0000_2183  ?  LW   x3, 0(x0)       x3=42
        //    32'h0040_2203  ?  LW   x4, 4(x0)       x4=100
        // ------------------------------------------------------------------
        hdr("B4: Load/Store ? SW / LW");
        clear_imem();
        write_imem('{
            32'h02A0_0093,   // 0: ADDI x1, x0,  42   ? x1=42
            32'h0640_0113,   // 1: ADDI x2, x0, 100   ? x2=100
            32'h0010_2023,   // 2: SW   x1,  0(x0)    ? mem[0]=42
            32'h0020_2223,   // 3: SW   x2,  4(x0)    ? mem[1]=100
            32'h0000_2183,   // 4: LW   x3,  0(x0)    ? x3=42
            32'h0040_2203    // 5: LW   x4,  4(x0)    ? x4=100
        });
        rst_run(14);
        chk_dmem(0, 32'd42,  "SW: mem[0] = 42");
        chk_dmem(1, 32'd100, "SW: mem[1] = 100");
        chk_reg (3, 32'd42,  "LW x3 from mem[0] = 42");
        chk_reg (4, 32'd100, "LW x4 from mem[1] = 100");

        // ------------------------------------------------------------------
        // B5a : Branch BEQ ? taken  (x1 == x2)
        //
        //  PC layout:
        //    PC= 0  ADDI x1,x0,5
        //    PC= 4  ADDI x2,x0,5
        //    PC= 8  BEQ  x1,x2,+8    ? branch target = PC+8 = 16
        //    PC=12  ADDI x3,x0,255   ? MUST be skipped
        //    PC=16  ADDI x4,x0,119   ? executed at target
        //
        //    BEQ x1,x2,+8 encoding: 0000_0000_0010_0000_1000_0100_0110_0011
        //                         = 0x0020_8463
        // ------------------------------------------------------------------
        hdr("B5a: BEQ ? taken (x1 == x2)");
        clear_imem();
        write_imem('{
            32'h0050_0093,   // 0 (PC= 0): ADDI x1, x0,  5
            32'h0050_0113,   // 1 (PC= 4): ADDI x2, x0,  5
            32'h0020_8463,   // 2 (PC= 8): BEQ  x1, x2, +8   ? target PC=16
            32'h0FF0_0193,   // 3 (PC=12): ADDI x3, x0,255   [MUST BE SKIPPED]
            32'h0770_0213,   // 4 (PC=16): ADDI x4, x0,119
            32'h0000_0013    // 5: NOP
        });
        rst_run(10);
        chk_reg(3, 32'd0,   "BEQ taken: x3 skipped (must remain 0)");
        chk_reg(4, 32'd119, "BEQ taken: x4 = 119 at branch target");

        // ------------------------------------------------------------------
        // B5b : Branch BEQ ? not taken  (x1 != x2)
        // ------------------------------------------------------------------
        hdr("B5b: BEQ ? not taken (x1 != x2)");
        clear_imem();
        write_imem('{
            32'h0050_0093,   // 0: ADDI x1, x0,  5
            32'h00A0_0113,   // 1: ADDI x2, x0, 10
            32'h0020_8463,   // 2: BEQ  x1, x2, +8   [not taken: 5?10]
            32'h0FF0_0193,   // 3: ADDI x3, x0, 255  [must execute]
            32'h0770_0213,   // 4: ADDI x4, x0, 119
            32'h0000_0013    // 5: NOP
        });
        rst_run(10);
        chk_reg(3, 32'd255, "BEQ not taken: x3 = 255 (not skipped)");
        chk_reg(4, 32'd119, "BEQ not taken: x4 = 119");

        // ------------------------------------------------------------------
        // B6 : JAL ? Jump and Link
        //
        //  PC layout:
        //    PC=0  JAL x1, +8   ? rd=x1=4 (PC+4), target PC=8
        //    PC=4  ADDI x2,x0,0xAA  [MUST be skipped]
        //    PC=8  ADDI x3,x0,0x55  [target ? must execute]
        //
        //  JAL x1,+8 encoding: 0x0080_00EF
        //    [31]=0 [30:21]=0000000100 [20]=0 [19:12]=00000000 [11:7]=00001
        // ------------------------------------------------------------------
        hdr("B6: JAL ? Jump and Link");
        clear_imem();
        write_imem('{
            32'h0080_00EF,   // 0 (PC=0): JAL x1, +8   ? x1=4, target=8
            32'h0AA0_0113,   // 1 (PC=4): ADDI x2,x0,0xAA  [SKIPPED]
            32'h0550_0193,   // 2 (PC=8): ADDI x3,x0,0x55  [TARGET]
            32'h0000_0013    // 3: NOP
        });
        rst_run(8);
        chk_reg(1, 32'd4,   "JAL: x1 = return addr (PC+4 = 4)");
        chk_reg(2, 32'd0,   "JAL: x2 skipped (must remain 0)");
        chk_reg(3, 32'h55,  "JAL: x3 = 0x55 at jump target");

        // ------------------------------------------------------------------
        // B7 : JALR ? Jump and Link Register
        //
        //  PC layout:
        //    PC= 0  ADDI x1, x0, 12   ? x1=12 (jump target)
        //    PC= 4  JALR x1, x1, 0    ? x1=8 (return addr PC+4), jump to 12
        //    PC= 8  ADDI x4, x0,0xBB  [MUST be skipped]
        //    PC=12  ADDI x5, x0,0xCC  [TARGET ? must execute]
        //
        //  JALR x1,x1,0 encoding: 0x0000_80E7
        //    Note: rd and rs1 both x1; single-cycle reads x1 BEFORE write,
        //    so jump target = old_x1+0 = 12. New x1 = PC+4 = 8.
        // ------------------------------------------------------------------
        hdr("B7: JALR ? Jump and Link Register");
        clear_imem();
        write_imem('{
            32'h00C0_0093,   // 0 (PC= 0): ADDI x1, x0, 12
            32'h0000_80E7,   // 1 (PC= 4): JALR x1, x1,  0  ? x1=8, jump to 12
            32'h0BB0_0213,   // 2 (PC= 8): ADDI x4, x0, 0xBB  [SKIPPED]
            32'h0CC0_0293    // 3 (PC=12): ADDI x5, x0, 0xCC  [TARGET]
        });
        rst_run(10);
        chk_reg(1, 32'd8,   "JALR: x1 = return addr (PC+4 = 8)");
        chk_reg(4, 32'd0,   "JALR: x4 skipped (must remain 0)");
        chk_reg(5, 32'hCC,  "JALR: x5 = 0xCC at jump target");

        // ------------------------------------------------------------------
        // B8 : LUI ? Load Upper Immediate
        //
        //    LUI x1, 1       ? x1 = 0x0000_1000
        //    LUI x2, 0xDEADB ? x2 = 0xDEAD_B000
        //
        //  Encoding:  000010B7 = 0_0000_0000_0001_0_0001_0110_111
        //             DEADB137 = 1_1010_1011_1100_1_1011_0001_0111
        // ------------------------------------------------------------------
        hdr("B8: LUI ? Load Upper Immediate");
        clear_imem();
        write_imem('{
            32'h0000_10B7,   // 0: LUI x1,     1   ? x1 = 0x0000_1000
            32'hDEAD_B137    // 1: LUI x2, 0xDEADB ? x2 = 0xDEAD_B000
        });
        rst_run(6);
        chk_reg(1, 32'h0000_1000, "LUI x1 = 0x00001000");
        chk_reg(2, 32'hDEAD_B000, "LUI x2 = 0xDEADB000");

        // ------------------------------------------------------------------
        // B9 : x0 hardwired to zero
        //    ADDI x0, x0, 5 attempts to write x0; register file must ignore.
        //    Encoding: 000000000101_00000_000_00000_0010011 = 0x0050_0013
        // ------------------------------------------------------------------
        hdr("B9: x0 register hardwired to zero");
        clear_imem();
        dut.IMEM.memory[0] = 32'h0050_0013;  // ADDI x0, x0, 5  (rd=x0 ? ignored)
        rst_run(4);
        chk_reg(0, 32'd0, "x0 = 0 after attempted write with ADDI x0,x0,5");

        // ------------------------------------------------------------------
        // B10 : Sequential data dependency
        //       Single-cycle has no hazards ? each instruction sees the
        //       register value written by the previous instruction.
        //
        //    ADDI x1, x0, 1    ? x1 = 1
        //    ADDI x2, x1, 1    ? x2 = x1+1 = 2
        //    ADD  x3, x2, x1   ? x3 = x2+x1 = 3
        //    ADD  x4, x1, x2   ? x4 = x1+x2 = 3
        // ------------------------------------------------------------------
        hdr("B10: Sequential dependency (single-cycle ? no hazards expected)");
        clear_imem();
        write_imem('{
            32'h0010_0093,   // 0: ADDI x1, x0, 1    ? x1=1
            32'h0010_8113,   // 1: ADDI x2, x1, 1    ? x2=2
            32'h0011_01B3,   // 2: ADD  x3, x2, x1   ? x3=3
            32'h0020_8233    // 3: ADD  x4, x1, x2   ? x4=3
        });
        rst_run(10);
        chk_reg(1, 32'd1, "SEQ: x1 = 1");
        chk_reg(2, 32'd2, "SEQ: x2 = x1+1 = 2");
        chk_reg(3, 32'd3, "SEQ: x3 = x2+x1 = 3");
        chk_reg(4, 32'd3, "SEQ: x4 = x1+x2 = 3");

        // ==================================================================
        //  FINAL SUMMARY
        // ==================================================================
        $display("");
        $display("????????????????????????????????????????????????????????????????");
        $display("?                    TEST SUMMARY                             ?");
        $display("????????????????????????????????????????????????????????????????");
        $display("?  Total : %-4d    PASS : %-4d    FAIL : %-4d                  ?",
                  pass_cnt+fail_cnt, pass_cnt, fail_cnt);
        $display("????????????????????????????????????????????????????????????????");

        if (fail_cnt == 0) begin
            $display("?   ?  ALL TESTS PASSED  ?                                   ?");
        end else begin
            $display("?  ?  FAILURES DETECTED ? design bugs to fix:                ?");
            $display("????????????????????????????????????????????????????????????????");
            $display("?  BUG-1 ? alucontrol.v  constants clash with alu.v           ?");
            $display("?        ? alucontrol defines:                                ?");
            $display("?        ?   ADD=0010  SUB=0110  AND=0000  OR=0001            ?");
            $display("?        ?   XOR=0011  SLT=0111  SLL=1000  SRL=1001 SRA=1010 ?");
            $display("?        ? alu.v expects:                                     ?");
            $display("?        ?   ADD=0000  SUB=1000  AND=0111  OR=0110            ?");
            $display("?        ?   XOR=0100  SLT=0010  SLL=0001  SRL=0101 SRA=1101 ?");
            $display("?        ? Fix: make alucontrol localparams match alu.v.      ?");
            $display("????????????????????????????????????????????????????????????????");
            $display("?  BUG-2 ? cputop.v: maincontrol ports immSel and jalr are   ?");
            $display("?        ? declared as wires but NOT connected.               ?");
            $display("?        ? Consequence: immediate generator always sees       ?");
            $display("?        ? immSel=Z ? default case ? imm=0.  Every           ?");
            $display("?        ? I-type / S-type / B-type / J-type / U-type        ?");
            $display("?        ? instruction loads the wrong immediate.             ?");
            $display("?        ? JALR is also broken (jalr signal = Z = 0).        ?");
            $display("?        ? Fix: connect .immSel(immSel) and .jalr(jalr)      ?");
            $display("?        ?      in the maincontrol instantiation.            ?");
            $display("????????????????????????????????????????????????????????????????");
            $display("?  BUG-3 ? PC.v: branch condition is (branch && zero) only.  ?");
            $display("?        ? Supports BEQ but not BNE, BLT, BGE, BLTU, BGEU.  ?");
            $display("?        ? Fix: qualify the branch with funct3 forwarded     ?");
            $display("?        ?      from the instruction decode stage.            ?");
            $display("????????????????????????????????????????????????????????????????");
            $display("?  BUG-4 ? AUIPC: cputop routes rs1_data to ALU operand_a.  ?");
            $display("?        ? AUIPC needs PC as operand_a, not register data.   ?");
            $display("?        ? Fix: add a mux on ALU operand_a selecting pc      ?");
            $display("?        ?      when opcode=AUIPC.                           ?");
        end

        $display("????????????????????????????????????????????????????????????????");
        $display("");
        $finish;
    end

    // Simulation watchdog ? prevents infinite loops in case of design hang
    initial begin
        #500_000;
        $display("[WATCHDOG] Simulation exceeded time limit ? check for hangs.");
        $finish;
    end

endmodule
// ============================================================================
//  END OF TESTBENCH
// ============================================================================
