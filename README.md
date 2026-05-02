# 32-bit Single-Cycle RISC-V Processor

A single-cycle RISC-V processor core implemented in Verilog, supporting the RV32I base integer instruction set.

---

## Overview

This processor executes one instruction per clock cycle. All stages — fetch, decode, execute, memory access, and writeback — are implemented as combinational logic, with only the PC and register file updating on the clock edge.

---

## File Structure

| File | Description |
|---|---|
| `cputop.v` | Top-level module connecting all components |
| `PC.v` | Program Counter with next-PC selection logic |
| `Instructionmemory.v` | 256-word instruction ROM |
| `register.v` | 32 × 32-bit register file (x0 hardwired to 0) |
| `immediate_generator.v` | Decodes all five RISC-V immediate formats |
| `controlunit.v` | Main control unit + ALU control unit |
| `alu.v` | ALU with Carry Select Adder (CSLA) |
| `data_memory.v` | 256-word data RAM |

---

## Supported Instructions

| Type | Instructions |
|---|---|
| R-type | ADD, SUB, AND, OR, XOR, SLT, SLL, SRL, SRA |
| I-type | ADDI, ANDI, ORI, XORI, SLTI, SLLI, SRLI, SRAI, LW, JALR |
| S-type | SW |
| B-type | BEQ |
| U-type | LUI, AUIPC |
| J-type | JAL |

---

## Datapath

```
PC → Instruction Memory → Decode → Register File
                                        ↓
                          Immediate Generator
                                        ↓
                    [ALU Src Mux] → ALU ← ALU Control
                                    ↓
                             Data Memory
                                    ↓
                          [Writeback Mux] → Register File
```

**PC next-address priority:** `JALR > JAL > Branch (if zero) > PC+4`

---

## ALU Design

The ALU uses a **Carry Select Adder (CSLA)** with a **Binary to Excess-1 Converter (BEC)** instead of a plain ripple-carry adder. The 32-bit adder is split into four 8-bit blocks, reducing the carry-propagation delay on the critical path.

Supported operations: ADD, SUB, AND, OR, XOR, SLT, SLL, SRL, SRA

Output flags: `zero`, `carry`, `overflow`, `borrow`, `sign`, `comp`

---

## Known Limitations

- **Single-cycle** — no pipelining; clock frequency is bounded by the longest instruction path (typically a load).
- `immSel` and `jalr` signals are not fully wired in `cputop.v` and need to be connected for complete functionality.
- Branch support is currently limited to BEQ (zero-flag based); other branch types (BNE, BLT, BGE, etc.) are not yet handled.
- Memory is word-addressed only; byte/halfword load-store (`LB`, `LH`, `SB`, `SH`) are not supported.
- Instruction and data memories are each limited to 256 words (1 KB).

---

## How to Simulate

Load your instruction program into `memory` inside `Instructionmemory.v`, then simulate with any Verilog simulator:

```bash
# Example using Icarus Verilog
iverilog -o cpu_sim cputop.v PC.v Instructionmemory.v register.v \
         immediate_generator.v controlunit.v alu.v data_memory.v testbench.v
vvp cpu_sim
```

---

## Future Improvements

- Wire up remaining control signals (`immSel`, `jalr`) in the top module
- Add support for remaining branch instructions (BNE, BLT, BGE, BLTU, BGEU)
- Add byte and halfword memory access
- Pipeline the design (IF / ID / EX / MEM / WB) for higher clock frequency
