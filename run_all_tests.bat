@echo off
REM ====================================================================
REM run_all_tests.bat
REM Runs all testbenches using Icarus Verilog on Windows.
REM
REM Install: https://bleyer.org/icarus/
REM After install, iverilog.exe will be in C:\iverilog\bin\
REM Add that folder to your PATH, or edit the line below.
REM ====================================================================

SET PASS=0
SET FAIL=0

SET RTL=pipeline_pkg.v alu.v immediate_generator.v register.v Instructionmemory.v data_mem.v PC.v controlunit.v hazard_unit.v cpu_pipeline.v cputop.v

echo ================================================================
echo   RISC-V CPU PIPELINE TEST SUITE
echo ================================================================

call :run_tb tb_alu                  test_bench_alu.v
call :run_tb tb_immediate_generator  test_bench_immediate.v
call :run_tb tb_register_file        test_bench_register.v
call :run_tb tb_data_memory          test_bench_data_mem.v
call :run_tb tb_instruction_memory   test_bench_instruction_mem.v
call :run_tb tb_hazard_unit          test_bench_hazard_unit.v
call :run_tb tb_control_unit         test_bench_controlunit.v
call :run_tb tb_pipeline             test_bench_pipeline.v
call :run_tb tb_pipeline_hazards     test_bench_pipeline_hazzard.v
call :run_tb tb_branch_jump          test_bench_branch_jump.v
call :run_tb tb_cpu_pipeline         test_bench_cpupipeline.v

echo.
echo ================================================================
echo   ALL TESTBENCHES COMPLETE
echo ================================================================
goto :eof

:run_tb
echo.
echo ================================================================
echo   RUNNING: %1
echo ================================================================
iverilog -g2012 -o sim_%1.vvp %RTL% %2
if errorlevel 1 (
    echo *** COMPILE ERROR for %2 ***
    goto :eof
)
vvp sim_%1.vvp
del sim_%1.vvp 2>nul
goto :eof
