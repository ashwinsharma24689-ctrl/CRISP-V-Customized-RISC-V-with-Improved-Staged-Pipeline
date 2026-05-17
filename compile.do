# ====================================================================
# compile.do  --  ModelSim / Questa compile + simulate script
# Usage:  vsim -do compile.do
#         or open in ModelSim GUI: File > Run Script...
# ====================================================================

# ----------------------------------------------------------------
# 1.  Create (or re-use) the working library
# ----------------------------------------------------------------
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# ----------------------------------------------------------------
# 2.  Compile order matters:
#       packages / primitives first, then modules, then testbenches
# ----------------------------------------------------------------

# -- Package / defines (no module, just `define macros) -----------
vlog -sv pipeline_pkg.v

# -- RTL source files ---------------------------------------------
vlog alu.v
vlog immediate_generator.v
vlog register.v
vlog Instructionmemory.v
vlog data_mem.v
vlog PC.v
vlog controlunit.v
vlog hazard_unit.v
vlog cputop.v
vlog cpu_pipeline.v

# -- Testbenches --------------------------------------------------
vlog test_bench_alu.v
vlog test_bench_immediate.v
vlog test_bench_register.v
vlog test_bench_data_mem.v
vlog test_bench_instruction_mem.v
vlog test_bench_pipeline.v
vlog test_bench_pipeline_hazzard.v
vlog test_bench_branch_jump.v
vlog test_bench_cpupipeline.v
vlog test_bench_hazard_unit.v     # T1 fix: was incorrectly skipped (module names differ)
vlog test_bench_controlunit.v     # T2 fix: was incorrectly skipped (not empty on disk)

# ----------------------------------------------------------------
# 3.  Helper proc: run one testbench and print a separator
# ----------------------------------------------------------------
proc run_tb {top} {
    puts "\n================================================================"
    puts "  RUNNING: $top"
    puts "================================================================"
    vsim -c $top -do "run -all; quit"
}

# ----------------------------------------------------------------
# 4.  Run all testbenches in dependency order
# ----------------------------------------------------------------
run_tb tb_alu
run_tb tb_immediate_generator
run_tb tb_register_file
run_tb tb_data_memory
run_tb tb_instruction_memory
run_tb tb_pipeline
run_tb tb_pipeline_hazards
run_tb tb_branch_jump
run_tb tb_cpu_pipeline
run_tb tb_hazard_unit        ;# T1 fix
run_tb tb_control_unit       ;# T2 fix

puts "\n================================================================"
puts "  ALL TESTBENCHES COMPLETE"
puts "================================================================"
