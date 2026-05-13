
`timescale 1ns/1ps

// =============================================================================
//  Testbench : alu (with embedded csla_32_bec / rca_8 / bec_8)
//  Covers every ALU operation, all flag outputs, and CSLA carry-chain corners.
// =============================================================================

module alu_tb;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [ 3:0] alu_control;

    logic [31:0] alu_result;
    logic        zero_flag;
    logic        comp_flag;
    logic        carry_flag;
    logic        sign_bit;
    logic        borrow;
    logic        overflow;

    // -------------------------------------------------------------------------
    // ALU control localparams
    // -------------------------------------------------------------------------
    localparam ADD = 4'b0000,
               SUB = 4'b1000,
               AND = 4'b0111,
               OR  = 4'b0110,
               XOR = 4'b0100,
               SLT = 4'b0010,
               SLL = 4'b0001,
               SRL = 4'b0101,
               SRA = 4'b1101;

    // -------------------------------------------------------------------------
    // Test tracking
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    alu dut (
        .operand_a  (operand_a),
        .operand_b  (operand_b),
        .alu_control(alu_control),
        .alu_result (alu_result),
        .zero_flag  (zero_flag),
        .comp_flag  (comp_flag),
        .carry_flag (carry_flag),
        .sign_bit   (sign_bit),
        .borrow     (borrow),
        .overflow   (overflow)
    );

    // =========================================================================
    // Tasks
    // =========================================================================

    // -------------------------------------------------------------------------
    // apply_op : drive inputs and wait for combinational settle
    // -------------------------------------------------------------------------
    task automatic apply_op(
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [ 3:0] ctrl
    );
        operand_a   = a;
        operand_b   = b;
        alu_control = ctrl;
        #2;
    endtask

    // -------------------------------------------------------------------------
    // check_result : verify alu_result + expected flags
    // exp_zero / carry / sign / borrow / overflow use 2-bit encoding:
    //   2'b0x = don't care,  2'b10 = expect 0,  2'b11 = expect 1
    // -------------------------------------------------------------------------
    task automatic check_result(
        input logic [31:0] exp_result,
        input logic [1:0]  exp_zero,
        input logic [1:0]  exp_carry,
        input logic [1:0]  exp_sign,
        input logic [1:0]  exp_borrow,
        input logic [1:0]  exp_overflow,
        input logic [1:0]  exp_comp,
        input string       label
    );
        logic fail;
        fail = 0;

        if (alu_result !== exp_result) begin
            $display("[FAIL] %s | result: got=0x%08h exp=0x%08h", label, alu_result, exp_result);
            fail = 1;
        end
        if (exp_zero[1]     && (zero_flag  !== exp_zero[0]))     begin
            $display("[FAIL] %s | zero_flag:  got=%b exp=%b",  label, zero_flag,  exp_zero[0]);     fail=1; end
        if (exp_carry[1]    && (carry_flag !== exp_carry[0]))    begin
            $display("[FAIL] %s | carry_flag: got=%b exp=%b",  label, carry_flag, exp_carry[0]);    fail=1; end
        if (exp_sign[1]     && (sign_bit   !== exp_sign[0]))     begin
            $display("[FAIL] %s | sign_bit:   got=%b exp=%b",  label, sign_bit,   exp_sign[0]);     fail=1; end
        if (exp_borrow[1]   && (borrow     !== exp_borrow[0]))   begin
            $display("[FAIL] %s | borrow:     got=%b exp=%b",  label, borrow,     exp_borrow[0]);   fail=1; end
        if (exp_overflow[1] && (overflow   !== exp_overflow[0])) begin
            $display("[FAIL] %s | overflow:   got=%b exp=%b",  label, overflow,   exp_overflow[0]); fail=1; end
        if (exp_comp[1]     && (comp_flag  !== exp_comp[0]))     begin
            $display("[FAIL] %s | comp_flag:  got=%b exp=%b",  label, comp_flag,  exp_comp[0]);     fail=1; end

        if (!fail) begin
            $display("[PASS] %s", label);
            pass_count++;
        end else begin
            fail_count++;
        end
    endtask

    // Shorthand: check only result (flags don't-care)
    // exp_zero/carry/sign/borrow/overflow/comp all 2'b00
    task automatic check_r(
        input logic [31:0] exp,
        input string       label
    );
        check_result(exp, 2'b00, 2'b00, 2'b00, 2'b00, 2'b00, 2'b00, label);
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        operand_a   = 0;
        operand_b   = 0;
        alu_control = ADD;

        $display("============================================");
        $display("  ALU Testbench -- Start");
        $display("============================================");

        // ====================================================================
        // ADD
        // ====================================================================
        $display("--- ADD ---");

        // 1. Basic add
        apply_op(32'h0000_0005, 32'h0000_0003, ADD);
        check_result(32'h0000_0008,
            2'b10, // zero=0
            2'b10, // carry=0
            2'b10, // sign=0
            2'b10, // borrow=0
            2'b10, // overflow=0
            2'b00,
            "ADD 5+3=8");

        // 2. Result = 0 ? zero_flag
        apply_op(32'h0000_0000, 32'h0000_0000, ADD);
        check_result(32'h0000_0000,
            2'b11, 2'b10, 2'b10, 2'b10, 2'b10, 2'b00,
            "ADD 0+0=0, zero_flag=1");

        // 3. Unsigned carry-out (wraps 32-bit)
        apply_op(32'hFFFF_FFFF, 32'h0000_0001, ADD);
        check_result(32'h0000_0000,
            2'b11, // zero=1 (result wraps to 0)
            2'b11, // carry=1
            2'b10, // sign=0
            2'b10, // borrow=0
            2'b10, // overflow=0 (unsigned overflow ? signed overflow here)
            2'b00,
            "ADD 0xFFFF_FFFF+1 -> carry=1, result=0");

        // 4. Signed positive overflow: large +ve + large +ve = negative result
        apply_op(32'h7FFF_FFFF, 32'h0000_0001, ADD);
        check_result(32'h8000_0000,
            2'b10, 2'b10, 2'b11, // sign=1 (MSB set)
            2'b10,
            2'b11, // overflow=1 (+ve + +ve = -ve)
            2'b00,
            "ADD overflow: 0x7FFFFFFF+1=0x80000000, overflow=1, sign=1");

        // 5. Signed negative overflow: large -ve + large -ve = positive
        apply_op(32'h8000_0000, 32'h8000_0000, ADD);
        check_result(32'h0000_0000,
            2'b11, 2'b11, 2'b10,
            2'b10,
            2'b11, // overflow=1 (-ve + -ve = +ve)
            2'b00,
            "ADD overflow: 0x80000000+0x80000000=0, carry=1, overflow=1");

        // 6. CSLA carry-chain: carry must propagate across all 4 eight-bit blocks
        apply_op(32'h0FFF_FFFF, 32'h0000_0001, ADD);
        check_result(32'h1000_0000, 2'b10, 2'b10, 2'b10, 2'b10, 2'b10, 2'b00,
            "ADD CSLA multi-block carry: 0x0FFFFFFF+1=0x10000000");

        apply_op(32'h00FF_FFFF, 32'h0000_0001, ADD);
        check_result(32'h0100_0000, 2'b10, 2'b10, 2'b10, 2'b10, 2'b10, 2'b00,
            "ADD CSLA block1->block2 carry: 0x00FFFFFF+1=0x01000000");

        apply_op(32'hFFFF_FF00, 32'h0000_00FF, ADD);
        check_result(32'hFFFF_FFFF, 2'b10, 2'b10, 2'b11, 2'b10, 2'b10, 2'b00,
            "ADD CSLA block0 carry: 0xFFFFFF00+0xFF=0xFFFFFFFF");

        // ====================================================================
        // SUB
        // ====================================================================
        $display("--- SUB ---");

        // 7. Basic subtract
        apply_op(32'h0000_000A, 32'h0000_0003, SUB);
        check_result(32'h0000_0007,
            2'b10, 2'b11, // carry=1 (no borrow)
            2'b10, 2'b10, // borrow=0
            2'b10, 2'b00,
            "SUB 10-3=7, carry=1(no borrow), borrow=0");

        // 8. Result = 0 ? zero_flag
        apply_op(32'h0000_0005, 32'h0000_0005, SUB);
        check_result(32'h0000_0000,
            2'b11, 2'b11, 2'b10, 2'b10, 2'b10, 2'b00,
            "SUB 5-5=0, zero_flag=1");

        // 9. Borrow (unsigned underflow): A < B
        apply_op(32'h0000_0003, 32'h0000_000A, SUB);
        check_result(32'hFFFF_FFF9,
            2'b10, 2'b10, // carry=0 (borrow occurred)
            2'b11, // sign=1
            2'b11, // borrow=1
            2'b10, 2'b00,
            "SUB 3-10=0xFFFFFFF9, borrow=1, carry=0, sign=1");

        // 10. Signed overflow: -ve minus +ve = +ve (wrong sign)
        apply_op(32'h8000_0000, 32'h0000_0001, SUB);
        check_result(32'h7FFF_FFFF,
            2'b10, 2'b11, 2'b10,
            2'b10,
            2'b11, // overflow=1
            2'b00,
            "SUB overflow: 0x80000000-1=0x7FFFFFFF, overflow=1");

        // 11. Signed overflow: +ve minus -ve = -ve (wrong sign)
        apply_op(32'h7FFF_FFFF, 32'h8000_0000, SUB);
        check_result(32'hFFFF_FFFF,
            2'b10, 2'b10, 2'b11,
            2'b11, // borrow=1
            2'b11, // overflow=1
            2'b00,
            "SUB overflow: 0x7FFFFFFF-0x80000000=0xFFFFFFFF, overflow=1, sign=1");

        // 12. CSLA carry-chain for subtraction (complement path)
        apply_op(32'h1000_0000, 32'h0000_0001, SUB);
        check_result(32'h0FFF_FFFF, 2'b10, 2'b11, 2'b10, 2'b10, 2'b10, 2'b00,
            "SUB CSLA multi-block borrow: 0x10000000-1=0x0FFFFFFF");

        // ====================================================================
        // AND
        // ====================================================================
        $display("--- AND ---");

        apply_op(32'hFFFF_FFFF, 32'h0F0F_0F0F, AND);
        check_r(32'h0F0F_0F0F, "AND all-ones & pattern = pattern");

        apply_op(32'hAAAA_AAAA, 32'h5555_5555, AND);
        check_result(32'h0000_0000, 2'b11, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00,
            "AND complementary masks = 0, zero_flag=1");

        apply_op(32'hFFFF_FFFF, 32'hFFFF_FFFF, AND);
        check_result(32'hFFFF_FFFF, 2'b10, 2'b00, 2'b11, 2'b00, 2'b00, 2'b00,
            "AND all-ones & all-ones = 0xFFFFFFFF, sign=1");

        // ====================================================================
        // OR
        // ====================================================================
        $display("--- OR ---");

        apply_op(32'hAAAA_AAAA, 32'h5555_5555, OR);
        check_result(32'hFFFF_FFFF, 2'b10, 2'b00, 2'b11, 2'b00, 2'b00, 2'b00,
            "OR complementary masks = 0xFFFFFFFF, sign=1");

        apply_op(32'h0000_0000, 32'h0000_0000, OR);
        check_result(32'h0000_0000, 2'b11, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00,
            "OR 0|0=0, zero_flag=1");

        apply_op(32'h1234_5678, 32'h0000_0000, OR);
        check_r(32'h1234_5678, "OR A|0=A");

        // ====================================================================
        // XOR
        // ====================================================================
        $display("--- XOR ---");

        apply_op(32'hFFFF_FFFF, 32'hFFFF_FFFF, XOR);
        check_result(32'h0000_0000, 2'b11, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00,
            "XOR A^A=0, zero_flag=1");

        apply_op(32'hAAAA_AAAA, 32'h5555_5555, XOR);
        check_result(32'hFFFF_FFFF, 2'b10, 2'b00, 2'b11, 2'b00, 2'b00, 2'b00,
            "XOR complementary masks = 0xFFFFFFFF, sign=1");

        apply_op(32'h1234_5678, 32'h0000_0000, XOR);
        check_r(32'h1234_5678, "XOR A^0=A (identity)");

        apply_op(32'hDEAD_BEEF, 32'hFFFF_FFFF, XOR);
        check_r(32'h2152_4110, "XOR A^all-ones = bitwise NOT");

        // ====================================================================
        // SLT ? signed less-than
        // ====================================================================
        $display("--- SLT ---");

        // 13. A < B (both positive)
        apply_op(32'h0000_0003, 32'h0000_000A, SLT);
        check_result(32'h0000_0001,
            2'b10, 2'b00, 2'b10, 2'b00, 2'b00,
            2'b11, // comp_flag=1
            "SLT 3<10 -> result=1, comp=1");

        // 14. A > B (both positive)
        apply_op(32'h0000_000A, 32'h0000_0003, SLT);
        check_result(32'h0000_0000,
            2'b11, 2'b00, 2'b10, 2'b00, 2'b00,
            2'b10, // comp_flag=0
            "SLT 10>3 -> result=0, comp=0, zero=1");

        // 15. A == B
        apply_op(32'h0000_0005, 32'h0000_0005, SLT);
        check_result(32'h0000_0000,
            2'b11, 2'b00, 2'b10, 2'b00, 2'b00,
            2'b10,
            "SLT A==B -> result=0, comp=0, zero=1");

        // 16. Negative A < positive B (different signs)
        apply_op(32'hFFFF_FFFF, 32'h0000_0001, SLT); // -1 < 1
        check_result(32'h0000_0001,
            2'b10, 2'b00, 2'b10, 2'b00, 2'b00,
            2'b11,
            "SLT -1 < +1 (diff signs) -> result=1, comp=1");

        // 17. Positive A > negative B (different signs)
        apply_op(32'h0000_0001, 32'hFFFF_FFFF, SLT); // 1 > -1
        check_result(32'h0000_0000,
            2'b11, 2'b00, 2'b10, 2'b00, 2'b00,
            2'b10,
            "SLT +1 > -1 (diff signs) -> result=0, comp=0");

        // 18. Both negative: -1 > -5
        apply_op(32'hFFFF_FFFF, 32'hFFFF_FFFB, SLT); // -1 > -5
        check_result(32'h0000_0000,
            2'b11, 2'b00, 2'b10, 2'b00, 2'b00,
            2'b10,
            "SLT -1 > -5 (same sign) -> result=0");

        // 19. Both negative: -5 < -1
        apply_op(32'hFFFF_FFFB, 32'hFFFF_FFFF, SLT); // -5 < -1
        check_result(32'h0000_0001,
            2'b10, 2'b00, 2'b10, 2'b00, 2'b00,
            2'b11,
            "SLT -5 < -1 (same sign) -> result=1");

        // 20. INT_MIN vs INT_MAX
        apply_op(32'h8000_0000, 32'h7FFF_FFFF, SLT); // most negative < most positive
        check_result(32'h0000_0001,
            2'b10, 2'b00, 2'b10, 2'b00, 2'b00,
            2'b11,
            "SLT INT_MIN < INT_MAX -> result=1");

        // ====================================================================
        // SLL ? shift left logical
        // ====================================================================
        $display("--- SLL ---");

        apply_op(32'h0000_0001, 32'h0000_0001, SLL);
        check_r(32'h0000_0002, "SLL 1<<1=2");

        apply_op(32'h0000_0001, 32'h0000_001F, SLL);
        check_result(32'h8000_0000, 2'b10, 2'b00, 2'b11, 2'b00, 2'b00, 2'b00,
            "SLL 1<<31=0x80000000, sign=1");

        apply_op(32'hFFFF_FFFF, 32'h0000_0001, SLL);
        check_r(32'hFFFF_FFFE, "SLL 0xFFFFFFFF<<1=0xFFFFFFFE (MSB drops)");

        // Only lower 5 bits of operand_b used for shift amount
        apply_op(32'h0000_0001, 32'h0000_0020, SLL); // shift by 32 ? only [4:0]=0
        check_r(32'h0000_0001, "SLL shift by 32 (b[4:0]=0) -> no shift");

        apply_op(32'h0000_0001, 32'h0000_0000, SLL);
        check_r(32'h0000_0001, "SLL shift by 0 -> unchanged");

        // ====================================================================
        // SRL ? shift right logical
        // ====================================================================
        $display("--- SRL ---");

        apply_op(32'h8000_0000, 32'h0000_0001, SRL);
        check_result(32'h4000_0000, 2'b10, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00,
            "SRL 0x80000000>>1=0x40000000, zero-fill MSB, sign=0");

        apply_op(32'hFFFF_FFFF, 32'h0000_0001, SRL);
        check_r(32'h7FFF_FFFF, "SRL 0xFFFFFFFF>>1=0x7FFFFFFF (logical, MSB=0)");

        apply_op(32'hFFFF_FFFF, 32'h0000_001F, SRL);
        check_result(32'h0000_0001, 2'b10, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00,
            "SRL 0xFFFFFFFF>>31=1");

        apply_op(32'h0000_0010, 32'h0000_0004, SRL);
        check_r(32'h0000_0001, "SRL 16>>4=1");

        apply_op(32'h0000_0001, 32'h0000_0020, SRL); // b[4:0]=0
        check_r(32'h0000_0001, "SRL shift by 32 (b[4:0]=0) -> no shift");

        // ====================================================================
        // SRA ? shift right arithmetic
        // ====================================================================
        $display("--- SRA ---");

        // Positive number: behaves same as SRL (sign bit = 0, fill with 0)
        apply_op(32'h4000_0000, 32'h0000_0001, SRA);
        check_result(32'h2000_0000, 2'b10, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00,
            "SRA +ve 0x40000000>>1=0x20000000, sign preserved");

        // Negative number: MSB fills with 1s
        apply_op(32'h8000_0000, 32'h0000_0001, SRA);
        check_result(32'hC000_0000, 2'b10, 2'b00, 2'b11, 2'b00, 2'b00, 2'b00,
            "SRA -ve 0x80000000>>1=0xC0000000, sign-fill MSB, sign=1");

        apply_op(32'hFFFF_FFFF, 32'h0000_0001, SRA);
        check_result(32'hFFFF_FFFF, 2'b10, 2'b00, 2'b11, 2'b00, 2'b00, 2'b00,
            "SRA -1>>1=-1 (all ones remain), sign=1");

        apply_op(32'hFFFF_FFFF, 32'h0000_001F, SRA);
        check_result(32'hFFFF_FFFF, 2'b10, 2'b00, 2'b11, 2'b00, 2'b00, 2'b00,
            "SRA -1>>31=-1 (sign-extend fills all)");

        // SRL vs SRA: same input, different behavior on negative
        apply_op(32'hF000_0000, 32'h0000_0004, SRL);
        check_r(32'h0F00_0000, "SRL 0xF0000000>>4=0x0F000000 (zero-fill)");
        apply_op(32'hF000_0000, 32'h0000_0004, SRA);
        check_r(32'hFF00_0000, "SRA 0xF0000000>>4=0xFF000000 (sign-fill)");

        // ====================================================================
        // FLAG: zero_flag across all operations
        // ====================================================================
        $display("--- zero_flag cross-op check ---");

        apply_op(32'h0000_0000, 32'h0000_0000, AND);
        check_result(32'h0, 2'b11, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00, "zero_flag: AND 0&0=0");

        apply_op(32'h0000_0000, 32'h0000_0000, OR);
        check_result(32'h0, 2'b11, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00, "zero_flag: OR 0|0=0");

        apply_op(32'h1234_5678, 32'h1234_5678, XOR);
        check_result(32'h0, 2'b11, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00, "zero_flag: XOR A^A=0");

        apply_op(32'h0000_0000, 32'h0000_0001, SLL);
        check_result(32'h0, 2'b11, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00, "zero_flag: SLL 0<<1=0");

        // ====================================================================
        // Default control (undefined encoding)
        // ====================================================================
        $display("--- Default ALU control ---");

        apply_op(32'hDEAD_BEEF, 32'h1234_5678, 4'b0011);
        check_result(32'h0000_0000, 2'b11, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00,
            "Default ctrl=0011: result=0, zero=1");

        apply_op(32'hFFFF_FFFF, 32'hFFFF_FFFF, 4'b1111);
        check_result(32'h0000_0000, 2'b11, 2'b00, 2'b10, 2'b00, 2'b00, 2'b00,
            "Default ctrl=1111: result=0, zero=1");

        // ====================================================================
        // CSLA corner cases ? exercise carry propagation across block boundaries
        // ====================================================================
        $display("--- CSLA structural corners ---");

        // Block 0 -> Block 1 boundary (bit 7 -> bit 8)
        apply_op(32'h0000_00FF, 32'h0000_0001, ADD);
        check_r(32'h0000_0100, "CSLA block0->1 carry: 0xFF+1=0x100");

        // Block 1 -> Block 2 boundary (bit 15 -> bit 16)
        apply_op(32'h0000_FFFF, 32'h0000_0001, ADD);
        check_r(32'h0001_0000, "CSLA block1->2 carry: 0xFFFF+1=0x10000");

        // Block 2 -> Block 3 boundary (bit 23 -> bit 24)
        apply_op(32'h00FF_FFFF, 32'h0000_0001, ADD);
        check_r(32'h0100_0000, "CSLA block2->3 carry: 0xFFFFFF+1=0x1000000");

        // Full 32-bit ripple through all blocks
        apply_op(32'hFFFF_FFFF, 32'h0000_0000, ADD);
        check_r(32'hFFFF_FFFF, "CSLA no carry: 0xFFFFFFFF+0=0xFFFFFFFF");

        apply_op(32'hFFFF_FFFE, 32'h0000_0001, ADD);
        check_r(32'hFFFF_FFFF, "CSLA sum at max: 0xFFFFFFFE+1=0xFFFFFFFF");

        // BEC path: verify BEC increment on sum1_c0 propagates correctly
        // When carry into block1=1, BEC adds 1 to sum computed with Cin=0
        apply_op(32'h0000_00FF, 32'h0000_FF01, ADD);
        check_r(32'h0001_0000, "CSLA BEC path: 0xFF+0xFF01=0x10000 (carry thru block0, BEC fires)");

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
        #100000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule