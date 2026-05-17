# 32-bit Pipelined RISC-V Processor

A 5-stage pipelined RISC-V processor core implemented in Verilog, supporting the full RV32I base integer instruction set.

---

## Overview

This processor implements a classic 5-stage pipeline — IF, ID, EX, MEM, WB — with full forwarding and hazard detection. Both a single-cycle reference design (`cputop.v`) and the pipelined core (`cpu_pipeline.v`) are included.

The pipelined core handles all RV32I data and control hazards:

- **EX/MEM → EX forwarding** — back-to-back ALU results forwarded without stalling
- **MEM/WB → EX forwarding** — two-instruction-gap forwarding
- **WB → ID bypass** — write-before-read forwarding on the register file
- **Load-use stall** — 1-cycle bubble inserted when a load result is consumed immediately
- **Branch/jump flush** — IF/ID and ID/EX flushed on any taken branch, JAL, or JALR (predict-not-taken, resolved in EX)

---

## File Structure

### RTL Source

| File | Description |
|---|---|
| `cpu_pipeline.v` | 5-stage pipelined core (top-level for synthesis) |
| `cputop.v` | Single-cycle reference implementation |
| `PC.v` | Program Counter with next-PC mux (single-cycle) |
| `Instructionmemory.v` | 256-word instruction ROM (`$readmemh`) |
| `register.v` | 32 × 32-bit register file (x0 hardwired to 0) |
| `immediate_generator.v` | All five RV32I immediate formats (I/S/B/U/J) |
| `controlunit.v` | Main control unit + ALU control unit |
| `alu.v` | 32-bit ALU with Carry Select Adder (CSLA) |
| `data_mem.v` | 1 KB data RAM with byte/halfword/word access |
| `hazard_unit.v` | Load-use detection + EX/MEM and MEM/WB forwarding |
| `pipeline_pkg.v` | Shared `define macros (forwarding codes, opcodes, NOP) |

### Testbenches

| File | Coverage |
|---|---|
| `test_bench_alu.v` | All ALU operations + CSLA carry-ripple |
| `test_bench_immediate.v` | All 5 immediate formats, walking-1 for B/J |
| `test_bench_register.v` | x0 guard, reset, write-enable, timing |
| `test_bench_data_mem.v` | Byte/HW/word access, OOB, timing |
| `test_bench_instruction_mem.v` | Sequential read, OOB, misaligned PC |
| `test_bench_controlunit.v` | All 9 opcodes × every control signal |
| `test_bench_hazard_unit.v` | 17 cases: load-use, forwarding priority, ext stall |
| `test_bench_pipeline.v` | Basic program smoke test |
| `test_bench_pipeline_hazzard.v` | EX/MEM fwd, MEM/WB fwd, load-use stall, branch flush |
| `test_bench_branch_jump.v` | All 6 branch types (taken + not-taken), JAL, JALR |
| `test_bench_cpupipeline.v` | Fibonacci, Factorial, call/return, bitwise sweep |

---

## Supported Instructions

| Type | Instructions |
|---|---|
| R-type | ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA |
| I-type (ALU) | ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI |
| I-type (Load) | LW, LH, LB, LHU, LBU |
| S-type | SW, SH, SB |
| B-type | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| U-type | LUI, AUIPC |
| J-type | JAL, JALR |

---

## Pipeline Datapath

```
  ┌─────┐   ┌──────────┐   ┌────────────────┐   ┌──────────┐   ┌────────┐
  │ IF  │──▶│  IF/ID   │──▶│      ID        │──▶│  ID/EX   │──▶│        │
  │     │   │ pc       │   │ control unit   │   │ ctrl sigs│   │        │
  │ PC  │   │ instr    │   │ register file  │   │ rs1_data │   │  EX    │
  │ +4  │   └──────────┘   │ imm generator  │   │ rs2_data │──▶│        │
  └─────┘                  └────────────────┘   │ imm      │   │  ALU   │
     ▲                            │              │ rd, rs1  │   │        │
     │                     hazard_unit           │ rs2      │   └───┬────┘
     │                      ├─ stall             └──────────┘       │
     │                      └─ fwd_a / fwd_b                    EX/MEM
     │                                                              │
     │         ┌──────────────────────────────────────────────┐    ▼
     │         │                  WB                          │  ┌────────┐
     │         │  JAL/JALR → pc+4                            │  │  MEM   │
     └─────────│  memtoReg → read_data    ◀── MEM/WB ◀───────│  │        │
               │  else     → alu_result                       │  │ DMEM   │
               └──────────────────────────────────────────────┘  └────────┘
```

**Next-PC priority (EX stage):** `JALR > JAL > branch taken > PC+4`

---

## ALU Design

The ALU uses a **Carry Select Adder (CSLA)** with a **Binary-to-Excess-1 Converter (BEC)** in place of a plain ripple-carry adder. The 32-bit adder is split into four 8-bit blocks; each upper block pre-computes both Cin=0 and Cin=1 results in parallel, then selects with a single mux once the carry from the previous block arrives. This cuts the carry-propagation delay from O(32) to O(8) gate stages on the critical path.

**Operations:** ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA

**Output flags:** `zero`, `carry`, `overflow`, `borrow`, `sign`, `comp`

---

## Extension Interfaces (cpu_pipeline.v)

The pipeline carries a 32-bit sideband bus through every stage register (defined in `pipeline_pkg.v`), providing hook points for three optional modules:

| Interface | Port(s) | Purpose |
|---|---|---|
| Power Control | `pwr_stall_req`, `pwr_stage_active` | Freeze all 5 stages cleanly; one-hot active-stage monitor for clock gating |
| Security Module | `sec_tag_in`, `sec_fault` | Tag propagated through pipeline for authentication; fault signal for violation handling |
| Macro Instruction Engine | `macro_valid`, `macro_instr`, `macro_stall_ack` | Inject synthetic instruction words; CPU freezes PC while engine streams micro-ops |

---

## Memory

Both memories are synchronous-write, combinational-read.

| | Instruction ROM | Data RAM |
|---|---|---|
| Size | 256 words (1 KB) | 256 words (1 KB) |
| Initialisation | `$readmemh("program.hex")` | Zero on reset |
| Access width | Word only | Byte, halfword, word (via `funct3`) |
| Out-of-bounds | Returns NOP (`0x00000013`) | Returns `0` |

`program.hex` format — one 32-bit hex opcode per line, no prefix:

```
00500093
00300113
002081B3
```

---

## How to Simulate

### ModelSim / Questa (recommended)

```bash
vsim -do compile.do
```

`compile.do` compiles all RTL and testbenches in dependency order and runs every testbench automatically.

### Icarus Verilog

```bash
# Run a single testbench, e.g. the pipeline hazard suite
iverilog -g2012 -o sim \
  pipeline_pkg.v alu.v immediate_generator.v register.v \
  Instructionmemory.v data_mem.v controlunit.v hazard_unit.v \
  cpu_pipeline.v test_bench_pipeline_hazzard.v
vvp sim
```

---

## Testbench Results (expected)

All 11 testbenches pass with zero failures on a clean build:

```
tb_alu                  25 / 25  passed
tb_immediate_generator  21 / 21  passed
tb_register_file         9 /  9  passed
tb_data_memory          14 / 14  passed
tb_instruction_memory   13 / 13  passed
tb_control_unit         29 / 29  passed
tb_hazard_unit          17 / 17  passed
tb_pipeline              5 /  5  expected values
tb_pipeline_hazards     11 / 11  passed
tb_branch_jump          28 / 28  passed
tb_cpu_pipeline         19 / 19  passed
```

---

## Known Limitations

- **Predict-not-taken branches** — a taken branch flushes 2 instructions (2-cycle penalty). A branch predictor would eliminate this.
- **No FENCE / ECALL / EBREAK / CSR** — these hit the default case and execute as NOPs. The design covers RV32I user-mode integer instructions only.
- **Single-ported memories** — structural hazards between simultaneous instruction fetch and data memory access are not possible in this implementation (separate instruction ROM and data RAM).
- **No exception / interrupt handling** — a trap unit would need to be added for a production core.

---

## Repository Structure

```
.
├── rtl/
│   ├── cpu_pipeline.v        # Pipelined core
│   ├── cputop.v              # Single-cycle reference
│   ├── alu.v
│   ├── controlunit.v
│   ├── data_mem.v
│   ├── hazard_unit.v
│   ├── immediate_generator.v
│   ├── Instructionmemory.v
│   ├── PC.v
│   ├── pipeline_pkg.v
│   └── register.v
├── tB/
│   ├── test_bench_alu.v
│   ├── test_bench_branch_jump.v
│   ├── test_bench_controlunit.v
│   ├── test_bench_cpupipeline.v
│   ├── test_bench_data_mem.v
│   ├── test_bench_hazard_unit.v
│   ├── test_bench_immediate.v
│   ├── test_bench_instruction_mem.v
│   ├── test_bench_pipeline.v
│   └── test_bench_pipeline_hazzard.v
├── program.hex               # Default test program
├── compile.do                # ModelSim build + run script
└── README.md
```
