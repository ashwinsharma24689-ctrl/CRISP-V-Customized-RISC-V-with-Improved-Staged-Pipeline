module alu(
    input  [31:0] operand_a,
    input  [31:0] operand_b,
    input  [3:0]  alu_control,

    output reg [31:0] alu_result,
    output reg zero_flag,
    output reg comp_flag,
    output reg carry_flag,
    output reg sign_bit,
    output reg borrow,
    output reg overflow
);

// ALU operations
localparam ADD=4'b0010, SUB=4'b0110, AND=4'b0000, OR=4'b0001, XOR=4'b0011, SLT=4'b0111, SLL=4'b1000, SRL=4'b1001, SRA=4'b1010;

// ---------- Shared Adder Inputs ----------
wire is_sub = (alu_control == SUB) || (alu_control == SLT);
wire [31:0] b_mux = is_sub ? ~operand_b : operand_b;
wire cin = is_sub ? 1'b1 : 1'b0;

// ---------- CSLA Outputs ----------
wire [31:0] sum;
wire carry_out;

//  CSLA instance
csla_32_bec csla (
    .A   (operand_a),
    .B   (b_mux),
    .Cin (cin),
    .Sum (sum),
    .Cout(carry_out)
);

always @(*) begin
    alu_result = 32'd0;
    carry_flag = 1'b0;
    borrow     = 1'b0;
    overflow   = 1'b0;
    comp_flag  = 1'b0;

    case (alu_control)

        ADD: begin
            alu_result = sum;
            carry_flag = carry_out;

            overflow = (~operand_a[31] & ~operand_b[31] & sum[31]) |
                       ( operand_a[31] &  operand_b[31] & ~sum[31]);
        end

        SUB: begin
            alu_result = sum;
            carry_flag = carry_out;
            borrow     = ~carry_out;

            overflow = (~operand_a[31] & operand_b[31] & sum[31]) |
                       ( operand_a[31] & ~operand_b[31] & ~sum[31]);
        end

        AND: alu_result = operand_a & operand_b;
        OR : alu_result = operand_a | operand_b;
        XOR: alu_result = operand_a ^ operand_b;

        SLT: begin
            comp_flag = (operand_a[31] != operand_b[31]) ? operand_a[31] : sum[31];
            alu_result = {31'd0, comp_flag};
        end

        SLL: alu_result = operand_a << operand_b[4:0];
        SRL: alu_result = operand_a >> operand_b[4:0];
        SRA: alu_result = $signed(operand_a) >>> operand_b[4:0];

        default: alu_result = 32'd0;
    endcase

    zero_flag = (alu_result == 32'd0);
    sign_bit  = alu_result[31];

end

endmodule

module csla_32_bec (
    input  [31:0] A,
    input  [31:0] B,
    input         Cin,
    output [31:0] Sum,
    output        Cout
);

wire [3:0] carry;

// Block 0 (no selection needed)
rca_8 rca0 (A[7:0], B[7:0], Cin, Sum[7:0], carry[0]);

// Block 1
wire [7:0] sum1_c0, sum1_c1;
wire c1_c0, c1_c1;

rca_8 rca1_0 (A[15:8], B[15:8], 1'b0, sum1_c0, c1_c0);
bec_8 bec1   (sum1_c0, sum1_c1);

assign Sum[15:8] = carry[0] ? sum1_c1 : sum1_c0;
assign carry[1]  = carry[0] ? c1_c1   : c1_c0;

// Block 2
wire [7:0] sum2_c0, sum2_c1;
wire c2_c0, c2_c1;

rca_8 rca2_0 (A[23:16], B[23:16], 1'b0, sum2_c0, c2_c0);
bec_8 bec2   (sum2_c0, sum2_c1);

assign Sum[23:16] = carry[1] ? sum2_c1 : sum2_c0;
assign carry[2]   = carry[1] ? c2_c1   : c2_c0;

// Block 3
wire [7:0] sum3_c0, sum3_c1;
wire c3_c0, c3_c1;

rca_8 rca3_0 (A[31:24], B[31:24], 1'b0, sum3_c0, c3_c0);
bec_8 bec3   (sum3_c0, sum3_c1);

assign Sum[31:24] = carry[2] ? sum3_c1 : sum3_c0;
assign Cout       = carry[2] ? c3_c1   : c3_c0;

endmodule

module rca_8 (
    input  [7:0] A, B,
    input        Cin,
    output [7:0] Sum,
    output       Cout
);
assign {Cout, Sum} = A + B + Cin;
endmodule

module bec_8 (
    input  [7:0] in,
    output [7:0] out
);
assign out = in + 1'b1;
endmodule

