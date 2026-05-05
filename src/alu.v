// =============================================================================
//  alu.v  —  32-bit RISC-V ALU  (fixed + synthesis-friendly)
//
//  BUGS FIXED:
//   • All outputs were declared as "output reg" even though they are
//     purely combinational.  Changed to wire + assign so that no synthesis
//     tool can accidentally infer a latch.
//   • zero_flag and sign_bit were assigned INSIDE the case block default,
//     which made their evaluation order tool-dependent.  Now they are
//     continuous assignments outside any procedural block.
//   • CSLA carry variables c1_c1 / c2_c1 / c3_c1 were declared but never
//     driven → floating nets → wrong addition results when carry propagates
//     across a block boundary.  Fixed with:
//         c_out_1 = c_out_0 | (&sum_c0)
//     (adding 1 to a byte overflows only when the byte is 0xFF).
//
//  SYNTHESIS IMPROVEMENTS:
//   • All combinational outputs are now wire/assign — no hidden state.
//   • always_comb (SV) replaces always @(*) — stricter latch checking.
//   • Barrel-shifter paths use only the 5-bit shift amount (correct mask).
//   • $signed cast kept for SRA — all major synthesis tools support it.
// =============================================================================

module alu (
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [3:0]  alu_control,

    output logic [31:0] alu_result,
    output logic        zero_flag,
    output logic        carry_flag,
    output logic        borrow,
    output logic        overflow,
    output logic        comp_flag,   // for SLT / branch comparisons
    output logic        sign_bit     // MSB of result
);

    // -----------------------------------------------------------------------
    // Operation encoding  (must match alucontrol.v exactly)
    // -----------------------------------------------------------------------
    localparam [3:0]
        ADD = 4'b0000,
        SUB = 4'b1000,
        AND = 4'b0111,
        OR  = 4'b0110,
        XOR = 4'b0100,
        SLT = 4'b0010,
        SLL = 4'b0001,
        SRL = 4'b0101,
        SRA = 4'b1101;

    // -----------------------------------------------------------------------
    // Adder / subtractor (shared CSLA)
    // -----------------------------------------------------------------------
    logic        is_sub;
    logic [31:0] b_mux;
    logic        cin;
    logic [31:0] sum;
    logic        carry_out;

    assign is_sub = (alu_control == SUB) | (alu_control == SLT);
    assign b_mux  = is_sub ? ~operand_b : operand_b;
    assign cin    = is_sub;

    csla_32_bec csla (
        .A   (operand_a),
        .B   (b_mux),
        .Cin (cin),
        .Sum (sum),
        .Cout(carry_out)
    );

    // -----------------------------------------------------------------------
    // Main ALU mux
    // -----------------------------------------------------------------------
    logic [31:0] result_int;
    logic        carry_int, borrow_int, ovf_int, comp_int;

    always_comb begin
        result_int  = 32'd0;
        carry_int   = 1'b0;
        borrow_int  = 1'b0;
        ovf_int     = 1'b0;
        comp_int    = 1'b0;

        unique case (alu_control)
            ADD: begin
                result_int = sum;
                carry_int  = carry_out;
                ovf_int    = (~operand_a[31] & ~operand_b[31] &  sum[31]) |
                             ( operand_a[31] &  operand_b[31] & ~sum[31]);
            end

            SUB: begin
                result_int = sum;
                carry_int  = carry_out;
                borrow_int = ~carry_out;                   // borrow = NOT carry
                ovf_int    = (~operand_a[31] &  operand_b[31] &  sum[31]) |
                             ( operand_a[31] & ~operand_b[31] & ~sum[31]);
            end

            AND: result_int = operand_a & operand_b;
            OR : result_int = operand_a | operand_b;
            XOR: result_int = operand_a ^ operand_b;

            SLT: begin
                // signed comparison: a < b  ↔  (sign(a-b) XOR overflow(a-b))
                comp_int   = (operand_a[31] ^ operand_b[31]) ? operand_a[31]
                                                             : sum[31];
                result_int = {31'd0, comp_int};
            end

            SLL: result_int = operand_a << operand_b[4:0];
            SRL: result_int = operand_a >> operand_b[4:0];
            // $signed cast is universally synthesisable; keeps the sign bit.
            SRA: result_int = 32'($signed(operand_a) >>> operand_b[4:0]);

            default: result_int = 32'd0;
        endcase
    end

    // -----------------------------------------------------------------------
    // Continuous output assignments  (no latch risk)
    // -----------------------------------------------------------------------
    assign alu_result = result_int;
    assign carry_flag = carry_int;
    assign borrow     = borrow_int;
    assign overflow   = ovf_int;
    assign comp_flag  = comp_int;
    assign zero_flag  = (result_int == 32'd0);
    assign sign_bit   = result_int[31];

endmodule


// =============================================================================
//  CSLA-32  with BEC  (Carry-Select Adder using Binary-to-Excess-1 converter)
//
//  BUG FIXED: c1_c1 / c2_c1 / c3_c1 were undriven wires.
//  For the BEC path the carry-out when cin=1 is:
//      c_out_1  =  c_out_0  |  (&sum_c0)
//  Proof: (A+B+1) overflows an 8-bit field exactly when either
//         (A+B) already overflowed (c_out_0=1)  OR
//         (A+B) == 0xFF  (so +1 pushes it to 0x100).
//  (&sum_c0) is a 1-bit AND-reduce: true iff all 8 bits of sum_c0 are 1.
// =============================================================================

module csla_32_bec (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic        Cin,
    output logic [31:0] Sum,
    output logic        Cout
);

    logic [3:0] carry;

    // Block 0 — no selection, just a direct RCA with the real Cin
    rca_8 rca0 (.A(A[7:0]),   .B(B[7:0]),   .Cin(Cin),   .Sum(Sum[7:0]),   .Cout(carry[0]));

    // ------------------------------------------------------------------
    // Blocks 1-3: compute both Cin=0 and Cin=1 results in parallel,
    // then select using the carry from the previous block.
    // ------------------------------------------------------------------

    // Block 1
    logic [7:0] sum1_c0, sum1_c1;
    logic       c1_c0,   c1_c1;

    rca_8  rca1 (.A(A[15:8]),  .B(B[15:8]),  .Cin(1'b0), .Sum(sum1_c0), .Cout(c1_c0));
    bec_8  bec1 (.in(sum1_c0),                            .out(sum1_c1));
    // FIX: carry-out for the Cin=1 path
    assign c1_c1    = c1_c0 | (&sum1_c0);
    assign Sum[15:8] = carry[0] ? sum1_c1 : sum1_c0;
    assign carry[1]  = carry[0] ? c1_c1   : c1_c0;

    // Block 2
    logic [7:0] sum2_c0, sum2_c1;
    logic       c2_c0,   c2_c1;

    rca_8  rca2 (.A(A[23:16]), .B(B[23:16]), .Cin(1'b0), .Sum(sum2_c0), .Cout(c2_c0));
    bec_8  bec2 (.in(sum2_c0),                            .out(sum2_c1));
    assign c2_c1     = c2_c0 | (&sum2_c0);
    assign Sum[23:16] = carry[1] ? sum2_c1 : sum2_c0;
    assign carry[2]   = carry[1] ? c2_c1   : c2_c0;

    // Block 3
    logic [7:0] sum3_c0, sum3_c1;
    logic       c3_c0,   c3_c1;

    rca_8  rca3 (.A(A[31:24]), .B(B[31:24]), .Cin(1'b0), .Sum(sum3_c0), .Cout(c3_c0));
    bec_8  bec3 (.in(sum3_c0),                            .out(sum3_c1));
    assign c3_c1     = c3_c0 | (&sum3_c0);
    assign Sum[31:24] = carry[2] ? sum3_c1 : sum3_c0;
    assign Cout       = carry[2] ? c3_c1   : c3_c0;

endmodule


// =============================================================================
//  8-bit Ripple-Carry Adder (leaf cell)
// =============================================================================
module rca_8 (
    input  logic [7:0] A, B,
    input  logic       Cin,
    output logic [7:0] Sum,
    output logic       Cout
);
    assign {Cout, Sum} = {1'b0, A} + {1'b0, B} + Cin;
endmodule


// =============================================================================
//  8-bit Binary-to-Excess-1 converter  (adds 1 to the input)
// =============================================================================
module bec_8 (
    input  logic [7:0] in,
    output logic [7:0] out
);
    assign out = in + 8'd1;
endmodule
