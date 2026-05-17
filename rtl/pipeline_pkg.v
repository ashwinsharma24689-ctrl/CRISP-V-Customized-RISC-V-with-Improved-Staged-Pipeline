// ====================================================================
// pipeline_pkg.vh
// Global defines for the 5-stage pipelined RISC-V CPU
//
// Extension bus layout [31:0] carried through every pipeline register:
//   [7:0]   – Macro Instruction Engine tag
//   [23:8]  – Security Module tag / authentication bits
//   [31:24] – Power Control hints (e.g. criticality, throttle level)
//
// To add a new module sideband:
//   1.  Widen EXT_TOTAL_W and assign a new field slice.
//   2.  Drive ext_in at the IF stage (or whichever boundary is appropriate).
//   3.  The pipeline register always-blocks already propagate ext unchanged;
//       the new module simply taps ext_out at the stage it needs.
// ====================================================================

`ifndef PIPELINE_PKG_VH
`define PIPELINE_PKG_VH

// ------------------------------------------------------------------
// Extension sideband widths
// ------------------------------------------------------------------
`define MACRO_EXT_W   8    // Macro Instruction Engine
`define SEC_EXT_W    16    // Security Module
`define PWR_EXT_W     8    // Power Control Module
`define EXT_TOTAL_W  32    // Total: keep power-of-2 for easy bus math

// Field slices within the extension bus [EXT_TOTAL_W-1 : 0]
`define EXT_MACRO   7:0    // bits [7:0]
`define EXT_SEC    23:8    // bits [23:8]
`define EXT_PWR    31:24   // bits [31:24]

// ------------------------------------------------------------------
// Forwarding select encoding (used in hazard_unit + cpu_pipeline)
// ------------------------------------------------------------------
`define FWD_NONE    2'b00  // No forwarding – use ID/EX register data
`define FWD_EX_MEM  2'b10  // Forward from EX/MEM ALU result
`define FWD_MEM_WB  2'b01  // Forward from MEM/WB write-back data

// ------------------------------------------------------------------
// ALU operand-A source (matches maincontrol alu_src_a encoding)
// ------------------------------------------------------------------
`define ASRC_RS1    2'b00  // rs1 (default)
`define ASRC_ZERO   2'b01  // 0  (LUI:  0 + imm)
`define ASRC_PC     2'b10  // PC (AUIPC: PC + imm)

// ------------------------------------------------------------------
// Opcode constants (for readability in future extension modules)
// ------------------------------------------------------------------
`define OP_RTYPE   7'b0110011
`define OP_ITYPE   7'b0010011
`define OP_LOAD    7'b0000011
`define OP_STORE   7'b0100011
`define OP_BRANCH  7'b1100011
`define OP_JAL     7'b1101111
`define OP_JALR    7'b1100111
`define OP_LUI     7'b0110111
`define OP_AUIPC   7'b0010111

// ------------------------------------------------------------------
// Pipeline stage IDs (for power-control clock-gating hooks)
// ------------------------------------------------------------------
`define STAGE_IF   3'd0
`define STAGE_ID   3'd1
`define STAGE_EX   3'd2
`define STAGE_MEM  3'd3
`define STAGE_WB   3'd4

// ------------------------------------------------------------------
// NOP instruction (ADDI x0, x0, 0 = 32'h0000_0013)
// Inserted as a bubble in pipeline registers on flush / stall.
// ------------------------------------------------------------------
`define NOP_INSTR  32'h0000_0013

`endif // PIPELINE_PKG_VH
