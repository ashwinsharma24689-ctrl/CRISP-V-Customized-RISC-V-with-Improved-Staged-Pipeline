`timescale 1ns/1ps

module immediate_generator_tb;

    // -------------------------------------------------------------------------
    // DUT Port Signals
    // -------------------------------------------------------------------------
    reg  [31:0] instruction;
    reg  [2:0]  immSel;
    wire [31:0] immOut;

    // -------------------------------------------------------------------------
    // Test Tracking
    // -------------------------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // -------------------------------------------------------------------------
    // localparams mirroring DUT
    // -------------------------------------------------------------------------
    localparam I_TYPE = 3'b000;
    localparam S_TYPE = 3'b001;
    localparam B_TYPE = 3'b010;
    localparam U_TYPE = 3'b011;
    localparam J_TYPE = 3'b100;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    immediate_generator dut (
        .instruction (instruction),
        .immSel      (immSel),
        .immOut      (immOut)
    );

    // -------------------------------------------------------------------------
    // Task: check
    // -------------------------------------------------------------------------
    task check(
        input [31:0] expected,
        input [63:0] test_id   // plain integer label
    );
        #1; // let combinational settle
        if (immOut === expected) begin
            $display("[PASS] Test %0d | immSel=%03b | instr=0x%08h | got=0x%08h",
                     test_id, immSel, instruction, immOut);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d | immSel=%03b | instr=0x%08h | got=0x%08h | exp=0x%08h",
                     test_id, immSel, instruction, immOut, expected);
            fail_count = fail_count + 1;
        end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        pass_count  = 0;
        fail_count  = 0;
        instruction = 32'd0;
        immSel      = 3'b000;

        $display("============================================");
        $display("  immediate_generator Testbench -- Start");
        $display("============================================");

        // ----------------------------------------------------------------
        // I-TYPE  immOut = { {20{inst[31]}}, inst[31:20] }
        // ----------------------------------------------------------------
        $display("--- I-TYPE ---");

        // Test 1: Positive immediate (+5)
        // inst[31:20] = 12'b000000000101, inst[31]=0 ? sign extend with 0s
        // immOut = 32'h0000_0005
        instruction = 32'b0000_0000_0101_00000_000_00000_0010011; // ADDI x0,x0,5
        immSel      = I_TYPE;
        check(32'h0000_0005, 1);

        // Test 2: Negative immediate (-1)
        // inst[31:20] = 12'hFFF, inst[31]=1 ? sign extend with 1s
        // immOut = 32'hFFFF_FFFF
        instruction = 32'b1111_1111_1111_00000_000_00000_0010011; // ADDI x0,x0,-1
        immSel      = I_TYPE;
        check(32'hFFFF_FFFF, 2);

        // Test 3: Max positive immediate (+2047)
        // inst[31:20] = 12'h7FF, inst[31]=0
        // immOut = 32'h0000_07FF
        instruction = 32'b0111_1111_1111_00000_000_00000_0010011;
        immSel      = I_TYPE;
        check(32'h0000_07FF, 3);

        // Test 4: Min negative immediate (-2048)
        // inst[31:20] = 12'h800, inst[31]=1
        // immOut = 32'hFFFF_F800
        instruction = 32'b1000_0000_0000_00000_000_00000_0010011;
        immSel      = I_TYPE;
        check(32'hFFFF_F800, 4);

        // Test 5: Zero immediate
        instruction = 32'b0000_0000_0000_00000_000_00000_0010011;
        immSel      = I_TYPE;
        check(32'h0000_0000, 5);

        // ----------------------------------------------------------------
        // S-TYPE  immOut = { {20{inst[31]}}, inst[31:25], inst[11:7] }
        // ----------------------------------------------------------------
        $display("--- S-TYPE ---");

        // Test 6: Positive offset (+5)
        // inst[31:25]=7'b000_0000, inst[11:7]=5'b00101
        // imm[11:5]=0000000, imm[4:0]=00101 ? 12'b0000_0000_0101 = +5
        // immOut = 32'h0000_0005
        instruction = 32'b0000000_00000_00000_010_00101_0100011; // SW, offset=5
        immSel      = S_TYPE;
        check(32'h0000_0005, 6);

        // Test 7: Negative offset (-1)
        // inst[31:25]=7'b111_1111, inst[11:7]=5'b11111
        // imm = 12'hFFF ? sign extended = 32'hFFFF_FFFF
        instruction = 32'b1111111_00000_00000_010_11111_0100011;
        immSel      = S_TYPE;
        check(32'hFFFF_FFFF, 7);

        // Test 8: Max positive S-type offset (+2047)
        // inst[31:25]=7'b011_1111, inst[11:7]=5'b11111
        // imm[11:5]=0111111, imm[4:0]=11111 ? 12'h7FF
        instruction = 32'b0111111_00000_00000_010_11111_0100011;
        immSel      = S_TYPE;
        check(32'h0000_07FF, 8);

        // Test 9: Bit-split correctness check ? upper and lower fields distinct
        // inst[31:25]=7'b000_0001, inst[11:7]=5'b00010
        // imm[11:5]=0000001, imm[4:0]=00010 ? 12'b0000_0010_0010 = 0x022
        instruction = 32'b0000001_00000_00000_010_00010_0100011;
        immSel      = S_TYPE;
        check(32'h0000_0022, 9);

        // ----------------------------------------------------------------
        // B-TYPE  immOut = { {19{inst[31]}}, inst[31], inst[7],
        //                    inst[30:25], inst[11:8], 1'b0 }
        // ----------------------------------------------------------------
        $display("--- B-TYPE ---");

        // Test 10: Branch offset +4 (imm=4)
        // imm[12]=0,imm[11]=0,imm[10:5]=000000,imm[4:1]=0010,imm[0]=0(tied)
        // inst[31]=0, inst[7]=0, inst[30:25]=000000, inst[11:8]=0010
        instruction = 32'b0000000_00000_00000_000_01000_1100011;
        immSel      = B_TYPE;
        check(32'h0000_0008, 10);  // note: imm[4:1]=0100 encodes +8? let's be precise

        // Test 11: Negative branch (-4)
        // imm = -4 = 32'hFFFF_FFFC
        // imm[12]=1,imm[11]=1,imm[10:5]=111111,imm[4:1]=1110,imm[0]=0
        // inst[31]=1,inst[7]=1,inst[30:25]=111111,inst[11:8]=1110
        instruction = 32'b1111111_00000_00000_000_11101_1100011;
        immSel      = B_TYPE;
        check(32'hFFFF_FFFC, 11);

        // Test 12: LSB of B-type is always 0 (instructions are 2-byte aligned)
        // Any B-type encoding must produce an even immediate
        instruction = 32'b0000000_00000_00000_000_00011_1100011;
        immSel      = B_TYPE;
        // imm[4:1]=0001 ? imm=0b0000_0000_0000_0010 = 2
        check(32'h0000_0002, 12);

        // Test 13: Max positive B-type (+4094)
        // imm[12]=0,imm[11]=1,imm[10:5]=111111,imm[4:1]=1111
        // inst[31]=0,inst[7]=1,inst[30:25]=111111,inst[11:8]=1111
        instruction = 32'b0111111_00000_00000_000_11111_1100011;
        immSel      = B_TYPE;
        check(32'h0000_0FFE, 13);

        // ----------------------------------------------------------------
        // U-TYPE  immOut = { inst[31:12], 12'b0 }
        // ----------------------------------------------------------------
        $display("--- U-TYPE ---");

        // Test 14: LUI with upper immediate = 0x12345
        // immOut = 32'h12345_000
        instruction = 32'h12345_037; // LUI x6, 0x12345
        immSel      = U_TYPE;
        check(32'h1234_5000, 14);

        // Test 15: All-ones upper immediate
        // immOut = 32'hFFFFF_000
        instruction = 32'hFFFFF_037;
        immSel      = U_TYPE;
        check(32'hFFFF_F000, 15);

        // Test 16: Lower 12 bits of instruction must be zeroed out in immOut
        // Even if lower bits are non-zero in instruction, immOut[11:0] = 0
        instruction = 32'hABCDE_FFF; // lower 12 = FFF, must be zeroed
        immSel      = U_TYPE;
        check(32'hABCDE_000, 16);

        // Test 17: Zero upper immediate
        instruction = 32'h0000_0037;
        immSel      = U_TYPE;
        check(32'h0000_0000, 17);

        // ----------------------------------------------------------------
        // J-TYPE  immOut = { {11{inst[31]}}, inst[31], inst[19:12],
        //                    inst[20], inst[30:21], 1'b0 }
        // ----------------------------------------------------------------
        $display("--- J-TYPE ---");

        // Test 18: JAL offset +4
        // imm[20]=0,imm[19:12]=00000000,imm[11]=0,imm[10:1]=0000000010,imm[0]=0
        // inst[31]=0,inst[19:12]=00000000,inst[20]=0,inst[30:21]=0000000010
        instruction = 32'b0_0000000010_0_00000000_00000_1101111;
        immSel      = J_TYPE;
        check(32'h0000_0004, 18);

        // Test 19: Negative J-type offset (-4)
        // imm=-4=32'hFFFF_FFFC
        // imm[20]=1,imm[19:12]=11111111,imm[11]=1,imm[10:1]=1111111110
        // inst[31]=1,inst[19:12]=11111111,inst[20]=1,inst[30:21]=1111111110
        instruction = 32'b1_1111111110_1_11111111_00000_1101111;
        immSel      = J_TYPE;
        check(32'hFFFF_FFFC, 19);

        // Test 20: LSB of J-type always 0 (PC-relative, 2-byte aligned)
        // imm[10:1]=0000000001 ? imm = 2
        instruction = 32'b0_0000000001_0_00000000_00000_1101111;
        immSel      = J_TYPE;
        check(32'h0000_0002, 20);

        // Test 21: J-type bit-scatter verification
        // imm[20]=0, imm[19:12]=10110100, imm[11]=1, imm[10:1]=0101010101
        // Expected immOut = 0x0_0_10110100_1_0101010101_0
        //                 = 0x00_B4_AA_A (let's compute)
        // imm = {0, 10110100, 1, 0101010101, 0}
        //     = 0_10110100_1_0101010101_0
        //     = 0b0_10110100_1_0101010101_0 (21 bits with bit0=0)
        // = 0x016955_4 ? compute carefully:
        // bit20=0, bits19-12=10110100=0xB4, bit11=1, bits10-1=0101010101=0x155, bit0=0
        // = 0b 0_10110100_1_0101010101_0
        // = 0x0_5A_AB_AA >> wait, let's just encode and check manually:
        // imm = 20'b0_10110100_1_0101010101 shifted left 1 = 21-bit
        // 0 | 1011_0100 | 1 | 0101_0101_01 | 0
        // = 0b0_1011_0100_1_0101_0101_010 = 0x16_95_A? 
        // Building from fields:
        // [20]    = 0          ? bit 20 = 0
        // [19:12] = 1011_0100  ? bits 19-12
        // [11]    = 1          ? bit 11
        // [10:1]  = 0101010101 ? bits 10-1
        // [0]     = 0 (tied)
        // Value = (0<<20)|(0xB4<<12)|(1<<11)|(0x155<<1)
        //       = 0 | 0xB4000 | 0x800 | 0x2AA
        //       = 0x000B_4000 + 0x0000_0800 + 0x0000_02AA
        //       = 0x000B_4AAA
        // inst encoding:
        // inst[31]    = imm[20] = 0
        // inst[30:21] = imm[10:1] = 0101010101
        // inst[20]    = imm[11]   = 1
        // inst[19:12] = imm[19:12]= 10110100
        // inst[11:7]  = rd (use 00000)
        // inst[6:0]   = 1101111
        instruction = 32'b0_0101010101_1_10110100_00000_1101111;
        immSel      = J_TYPE;
        check(32'h000B_4AAA, 21);

        // ----------------------------------------------------------------
        // DEFAULT ? unknown immSel must output 0
        // ----------------------------------------------------------------
        $display("--- DEFAULT ---");

        // Test 22: immSel = 3'b101 (undefined)
        instruction = 32'hFFFF_FFFF;
        immSel      = 3'b101;
        check(32'h0000_0000, 22);

        // Test 23: immSel = 3'b110 (undefined)
        instruction = 32'hDEAD_BEEF;
        immSel      = 3'b110;
        check(32'h0000_0000, 23);

        // Test 24: immSel = 3'b111 (undefined)
        instruction = 32'hAAAA_AAAA;
        immSel      = 3'b111;
        check(32'h0000_0000, 24);

        // ----------------------------------------------------------------
        // CROSS-CHECK ? switching immSel on same instruction
        // Verifies combinational re-evaluation on immSel change alone
        // ----------------------------------------------------------------
        $display("--- CROSS-CHECK (same instruction, changing immSel) ---");

        instruction = 32'hFFF0_00FF; // fixed instruction throughout

        // Test 25: I-type interpretation
        // inst[31:20] = 12'hFFF, inst[31]=1 ? immOut = 32'hFFFF_FFFF
        immSel = I_TYPE;
        check(32'hFFFF_FFFF, 25);

        // Test 26: U-type interpretation of same instruction
        // immOut = {inst[31:12], 12'b0} = {20'hFFF00, 12'b0} = 32'hFFF0_0000
        immSel = U_TYPE;
        check(32'hFFF0_0000, 26);

        // Test 27: S-type interpretation of same instruction
        // inst[31:25]=7'b1111111, inst[11:7]=5'b00000
        // imm = {1111111,00000} = 12'hFE0 ? sign extend (inst[31]=1)
        // immOut = 32'hFFFF_FFE0
        immSel = S_TYPE;
        check(32'hFFFF_FFE0, 27);

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
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
        #10000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
