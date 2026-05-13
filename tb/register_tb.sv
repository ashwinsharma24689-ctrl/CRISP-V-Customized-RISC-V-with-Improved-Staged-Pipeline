`timescale 1ns/1ps

module reg_array_tb;

    // -------------------------------------------------------------------------
    // DUT Port Signals
    // -------------------------------------------------------------------------
    logic        write_enable;
    logic        clk;
    logic        rst;
    logic [4:0]  sr1, sr2, wr;
    logic [31:0] wd;
    logic [31:0] rs1, rs2;

    // -------------------------------------------------------------------------
    // Test Tracking
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    reg_array dut (
        .sr1          (sr1),
        .sr2          (sr2),
        .rs1          (rs1),
        .rs2          (rs2),
        .wr           (wr),
        .wd           (wd),
        .write_enable (write_enable),
        .clk          (clk),
        .rst          (rst)
    );

    // -------------------------------------------------------------------------
    // Clock Generation ? 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Task: apply_reset
    // -------------------------------------------------------------------------
    task apply_reset();
        rst          = 1;
        write_enable = 0;
        sr1          = 5'd0;
        sr2          = 5'd0;
        wr           = 5'd0;
        wd           = 32'd0;
        @(posedge clk); #1;  // hold for one cycle
        @(posedge clk); #1;
        rst = 0;
    endtask

    // -------------------------------------------------------------------------
    // Task: write_reg
    // -------------------------------------------------------------------------
    task write_reg(input [4:0] addr, input [31:0] data);
        wr           = addr;
        wd           = data;
        write_enable = 1;
        @(posedge clk); #1;
        write_enable = 0;
    endtask

    // -------------------------------------------------------------------------
    // Task: check_read
    //   Reads sr1/sr2 and compares against expected values.
    //   The combinational outputs are valid immediately after signal assignment.
    // -------------------------------------------------------------------------
    task check_read(
        input [4:0]  addr1,
        input [4:0]  addr2,
        input [31:0] exp1,
        input [31:0] exp2,
        input string test_name
    );
        sr1 = addr1;
        sr2 = addr2;
        #1;  // allow combinational settle

        if (rs1 === exp1 && rs2 === exp2) begin
            $display("[PASS] %s | rs1=0x%08h (exp=0x%08h) | rs2=0x%08h (exp=0x%08h)",
                     test_name, rs1, exp1, rs2, exp2);
            pass_count++;
        end else begin
            $display("[FAIL] %s | rs1=0x%08h (exp=0x%08h) | rs2=0x%08h (exp=0x%08h)",
                     test_name, rs1, exp1, rs2, exp2);
            fail_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        $display("========================================");
        $display("  reg_array Testbench ? Start");
        $display("========================================");

        // ------------------------------------------------------------------
        // TEST 1: Reset clears all registers
        // ------------------------------------------------------------------
        apply_reset();
        for (int i = 0; i < 32; i++) begin
            sr1 = i[4:0];
            sr2 = i[4:0];
            #1;
            if (rs1 !== 32'd0) begin
                $display("[FAIL] Reset check: reg[%0d] = 0x%08h, expected 0x00000000", i, rs1);
                fail_count++;
            end else begin
                pass_count++;
            end
        end
        $display("[INFO] Reset test complete (%0d checks)", 32);

        // ------------------------------------------------------------------
        // TEST 2: x0 (register 0) always reads as zero even after write attempt
        // ------------------------------------------------------------------
        write_reg(5'd0, 32'hDEAD_BEEF);
        check_read(5'd0, 5'd0, 32'd0, 32'd0, "x0 hardwired-zero after write attempt");

        // ------------------------------------------------------------------
        // TEST 3: Basic write and read-back (registers 1?31)
        // ------------------------------------------------------------------
        for (int i = 1; i < 32; i++) begin
            write_reg(i[4:0], 32'hA000_0000 | i);
        end
        for (int i = 1; i < 32; i++) begin
            check_read(i[4:0], i[4:0],
                       32'hA000_0000 | i,
                       32'hA000_0000 | i,
                       $sformatf("Read-back reg[%0d]", i));
        end

        // ------------------------------------------------------------------
        // TEST 4: Simultaneous dual-port read (sr1 ? sr2)
        // ------------------------------------------------------------------
        write_reg(5'd5,  32'h1111_1111);
        write_reg(5'd10, 32'h2222_2222);
        check_read(5'd5, 5'd10, 32'h1111_1111, 32'h2222_2222, "Dual-port simultaneous read");

        // ------------------------------------------------------------------
        // TEST 5: Write with write_enable = 0 must NOT update the register
        // ------------------------------------------------------------------
        write_reg(5'd7, 32'hCCCC_CCCC);          // establish known value
        wr           = 5'd7;
        wd           = 32'hFFFF_FFFF;
        write_enable = 0;
        @(posedge clk); #1;
        check_read(5'd7, 5'd7, 32'hCCCC_CCCC, 32'hCCCC_CCCC, "WE=0 no-write guard");

        // ------------------------------------------------------------------
        // TEST 6: Overwrite an existing register value
        // ------------------------------------------------------------------
        write_reg(5'd15, 32'hAAAA_AAAA);
        check_read(5'd15, 5'd15, 32'hAAAA_AAAA, 32'hAAAA_AAAA, "Overwrite reg[15] first");
        write_reg(5'd15, 32'h5555_5555);
        check_read(5'd15, 5'd15, 32'h5555_5555, 32'h5555_5555, "Overwrite reg[15] second");

        // ------------------------------------------------------------------
        // TEST 7: Mid-operation reset clears registers
        // ------------------------------------------------------------------
        write_reg(5'd20, 32'hBEEF_CAFE);
        apply_reset();
        check_read(5'd20, 5'd20, 32'd0, 32'd0, "Post mid-op reset reg[20]");

        // ------------------------------------------------------------------
        // TEST 8: Write to highest register (x31)
        // ------------------------------------------------------------------
        write_reg(5'd31, 32'hFFFF_FFFF);
        check_read(5'd31, 5'd31, 32'hFFFF_FFFF, 32'hFFFF_FFFF, "Boundary write reg[31]");

        // ------------------------------------------------------------------
        // TEST 9: All registers hold independent values (no aliasing)
        // ------------------------------------------------------------------
        apply_reset();
        for (int i = 1; i < 32; i++)
            write_reg(i[4:0], i * 32'h0101_0101);

        for (int i = 1; i < 32; i++) begin
            check_read(i[4:0], i[4:0],
                       i * 32'h0101_0101,
                       i * 32'h0101_0101,
                       $sformatf("Independence check reg[%0d]", i));
        end

        // ------------------------------------------------------------------
        // TEST 10: x0 still returns 0 after all writes
        // ------------------------------------------------------------------
        check_read(5'd0, 5'd0, 32'd0, 32'd0, "x0 zero after bulk writes");

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("========================================");
        $display("  Results: %0d PASSED  |  %0d FAILED", pass_count, fail_count);
        $display("========================================");

        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED ? review above");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog ? prevents infinite simulation on stall
    // -------------------------------------------------------------------------
    initial begin
        #50000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
