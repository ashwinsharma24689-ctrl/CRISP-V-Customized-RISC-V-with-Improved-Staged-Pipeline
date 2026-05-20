# CRISP-V — Customized RISC-V with Improved Staged Pipeline

A fully functional **32-bit 5-stage pipelined RISC-V processor** implemented in Verilog, supporting the complete **RV32I base integer instruction set**.

---

## Architecture Overview

```
IF  →  ID  →  EX  →  MEM  →  WB
```

| Stage | Description |
|-------|-------------|
| **IF** | Instruction Fetch — PC register, instruction memory |
| **ID** | Decode / Register Read — control unit, register file, immediate generator |
| **EX** | Execute — CSLA-based ALU, forwarding muxes, branch resolution |
| **MEM** | Memory Access — byte/halfword/word data memory |
| **WB** | Write-Back — register file write, link address for JAL/JALR |

---

## Features

- ✅ Full **RV32I** instruction set (R, I, S, B, U, J types)
- ✅ **5-stage pipeline** with proper register separation
- ✅ **Full forwarding** — EX/MEM→EX and MEM/WB→EX paths
- ✅ **Load-use hazard detection** with 1-cycle stall + bubble injection
- ✅ **Branch/jump flush** — predict-not-taken, 2-instruction flush on redirect
- ✅ **Carry-Select Adder (CSLA)** with Binary-to-Excess-1 Code (BEC) for fast addition
- ✅ **Byte-addressable data memory** — LB, LH, LW, LBU, LHU, SB, SH, SW
- ✅ **LUI / AUIPC** support via operand-A mux
- ✅ **Extension interfaces** — Power Control, Security Module, Macro Instruction Engine hooks
- ✅ **Comprehensive testbench suite** — 11 testbenches, 100% pass rate

---

## Repository Structure

```
CRISP-V/
├── rtl/                        # RTL source files
│   ├── cpu_pipeline.v          # Top-level 5-stage pipeline
│   ├── cputop.v                # Single-cycle reference CPU
│   ├── alu.v                   # ALU with CSLA (Carry-Select Adder)
│   ├── controlunit.v           # Main control + ALU control
│   ├── hazard_unit.v           # Hazard detection + forwarding unit
│   ├── data_mem.v              # Byte-addressable data memory
│   ├── Instructionmemory.v     # Instruction memory ($readmemh)
│   ├── register.v              # 32×32-bit register file
│   ├── immediate_generator.v   # 5-type immediate generator
│   ├── PC.v                    # Program counter
│   └── pipeline_pkg.v          # Global defines and parameters
│
├── tb/                         # Testbenches
│   ├── test_bench_alu.v
│   ├── test_bench_controlunit.v
│   ├── test_bench_data_mem.v
│   ├── test_bench_hazard_unit.v
│   ├── test_bench_immediate.v
│   ├── test_bench_instruction_mem.v
│   ├── test_bench_register.v
│   ├── test_bench_pipeline.v
│   ├── test_bench_pipeline_hazzard.v
│   ├── test_bench_branch_jump.v
│   └── test_bench_cpupipeline.v
│
├── outputs/                    # Simulation results
│   ├── unit_tests/             # Per-module terminal screenshots
│   ├── integration_tests/      # Pipeline integration screenshots
│   └── waveforms/              # GTKWave VCD files
│
├── program.hex                 # Default test program
├── run_all_tests.sh            # Linux/Mac test runner
├── run_all_tests.bat           # Windows test runner
└── README.md
```

---

## Instruction Support

| Type | Instructions |
|------|-------------|
| **R-type** | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| **I-type** | ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI |
| **Load** | LW, LH, LB, LHU, LBU |
| **Store** | SW, SH, SB |
| **Branch** | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| **Jump** | JAL, JALR |
| **Upper** | LUI, AUIPC |

---

## Hazard Handling

### Data Hazards — Full Forwarding
```
Producer in EX/MEM  →  forward to EX operand mux  (highest priority)
Producer in MEM/WB  →  forward to EX operand mux
Producer in WB      →  WB→ID bypass (write-before-read)
```

### Load-Use Hazard
```
lw  x1, 0(x2)       ← load in EX
add x3, x1, x4      ← needs x1 → 1-cycle stall inserted
```

### Control Hazards
```
branch/jump resolved at end of EX
→ IF/ID and ID/EX flushed (2 bubbles)
→ predict-not-taken strategy
```

---

## ALU Design — CSLA with BEC

The ALU uses a **Carry-Select Adder** divided into four 8-bit blocks. Each block (except block 0) pre-computes results for both Cin=0 and Cin=1 using a **Binary-to-Excess-1 Code (BEC)** converter instead of a second ripple-carry adder, reducing area while maintaining speed.

---

## Running the Tests

### Prerequisites
- [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` + `vvp`)
- [GTKWave](http://gtkwave.sourceforge.net/) (optional, for waveform viewing)

### Linux / Mac
```bash
chmod +x run_all_tests.sh
./run_all_tests.sh
```

### Windows
```bat
run_all_tests.bat
```

### Single testbench
```bash
iverilog -g2012 -o sim.vvp pipeline_pkg.v alu.v immediate_generator.v register.v \
  Instructionmemory.v data_mem.v PC.v controlunit.v hazard_unit.v \
  cpu_pipeline.v cputop.v test_bench_cpupipeline.v
vvp sim.vvp
```

---

## Test Results

| Testbench | Tests | Result |
|-----------|-------|--------|
| ALU | 24 | ✅ ALL PASS |
| Immediate Generator | 18 | ✅ ALL PASS |
| Register File | 8 | ✅ ALL PASS |
| Data Memory | 10 | ✅ ALL PASS |
| Instruction Memory | 12 | ✅ ALL PASS |
| Hazard Unit | 17 | ✅ ALL PASS |
| Control Unit | 21 | ✅ ALL PASS |
| Pipeline Basic | 5 | ✅ ALL PASS |
| Pipeline Hazards | 11 | ✅ ALL PASS |
| Branch & Jump | 16 | ✅ ALL PASS |
| CPU Pipeline Full | 13 | ✅ ALL PASS |

---

## Extension Interfaces

The pipeline exposes three extension ports for future modules:

| Interface | Port | Description |
|-----------|------|-------------|
| **Power Control** | `pwr_stall_req`, `pwr_stage_active` | Freeze pipeline; per-stage activity for clock gating |
| **Security Module** | `sec_tag_in`, `sec_fault` | Tag propagation through all pipeline registers |
| **Macro Engine** | `macro_valid`, `macro_instr`, `macro_stall_ack` | Inject synthetic instruction sequences |

---

## Tools Used

- **Verilog HDL** (IEEE 1364-2001 / SystemVerilog 2012 subset)
- **Icarus Verilog** — simulation
- **GTKWave** — waveform analysis

---

## License

MIT License — see [LICENSE](LICENSE) for details.
