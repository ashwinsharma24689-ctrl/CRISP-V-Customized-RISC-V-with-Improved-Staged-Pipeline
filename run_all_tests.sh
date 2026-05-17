#!/bin/bash
# ====================================================================
# run_all_tests.sh
# Compiles and runs all testbenches using Icarus Verilog (iverilog).
#
# Install Icarus Verilog (free, no limits):
#   Windows: https://bleyer.org/icarus/  (iverilog-v11-20201123-x64_setup.exe)
#            OR via MSYS2: pacman -S mingw-w64-x86_64-iverilog
#   Linux:   sudo apt install iverilog
#   Mac:     brew install icarus-verilog
#
# Usage (from the folder containing all .v files):
#   bash run_all_tests.sh
# ====================================================================

PASS=0
FAIL=0
ERRORS=()

# Common RTL sources (compiled into every testbench)
RTL="pipeline_pkg.v alu.v immediate_generator.v register.v \
     Instructionmemory.v data_mem.v PC.v controlunit.v \
     hazard_unit.v cpu_pipeline.v cputop.v"

run_tb() {
    local TB_NAME=$1
    local TB_FILE=$2
    local OUT="sim_${TB_NAME}"

    echo ""
    echo "================================================================"
    echo "  RUNNING: ${TB_NAME}"
    echo "================================================================"

    # Compile
    iverilog -g2012 -Wall -Wno-timescale \
        -o "${OUT}" \
        ${RTL} "${TB_FILE}" 2>&1

    if [ $? -ne 0 ]; then
        echo "*** COMPILE ERROR: ${TB_FILE} ***"
        ERRORS+=("${TB_NAME}: compile error")
        FAIL=$((FAIL+1))
        return
    fi

    # Run and capture output
    OUTPUT=$(vvp "${OUT}" 2>&1)
    echo "$OUTPUT"

    # Count pass/fail from output
    P=$(echo "$OUTPUT" | grep -c "^PASS")
    F=$(echo "$OUTPUT" | grep -c "^FAIL")
    PASS=$((PASS+P))
    FAIL=$((FAIL+F))

    # Check for simulator errors
    if echo "$OUTPUT" | grep -q "ERROR\|error\|Fatal"; then
        ERRORS+=("${TB_NAME}: runtime error")
    fi

    rm -f "${OUT}"
}

echo "================================================================"
echo "  RISC-V CPU PIPELINE TEST SUITE"
echo "  Using: $(iverilog -V 2>&1 | head -1)"
echo "================================================================"

# ---- Unit tests (no pipeline dependency) ---------------------------
run_tb "ALU"               "test_bench_alu.v"
run_tb "ImmediateGen"      "test_bench_immediate.v"
run_tb "RegisterFile"      "test_bench_register.v"
run_tb "DataMemory"        "test_bench_data_mem.v"
run_tb "InstructionMemory" "test_bench_instruction_mem.v"
run_tb "HazardUnit"        "test_bench_hazard_unit.v"
run_tb "ControlUnit"       "test_bench_controlunit.v"

# ---- Pipeline integration tests ------------------------------------
run_tb "Pipeline_Basic"    "test_bench_pipeline.v"
run_tb "Pipeline_Hazards"  "test_bench_pipeline_hazzard.v"
run_tb "Branch_Jump"       "test_bench_branch_jump.v"
run_tb "CPU_Pipeline_Full" "test_bench_cpupipeline.v"

# ---- Summary -------------------------------------------------------
echo ""
echo "================================================================"
echo "  FINAL SUMMARY"
echo "  PASS: ${PASS}   FAIL: ${FAIL}"
if [ ${#ERRORS[@]} -gt 0 ]; then
    echo "  ERRORS:"
    for e in "${ERRORS[@]}"; do echo "    - $e"; done
fi
if [ ${FAIL} -eq 0 ] && [ ${#ERRORS[@]} -eq 0 ]; then
    echo "  ALL TESTS PASSED"
fi
echo "================================================================"
