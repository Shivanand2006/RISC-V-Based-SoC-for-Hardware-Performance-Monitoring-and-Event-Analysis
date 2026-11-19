#!/usr/bin/env bash
# ==============================================================================
# Script: run.sh
# Purpose: Compiles and executes UVM testbench with Synopsys VCS and launches Verdi
# ==============================================================================
set -e

TB_NAME=${1:-tb_soc_uvm}
TEST_NAME=${2:-soc_top_base_test}

mkdir -p ../build

echo "=== Compiling UVM Testbench ${TB_NAME} with Synopsys VCS ==="
vcs -full64 -sverilog -ntb_opts uvm-1.2 +v2k -kdb -debug_access+all \
    +define+FSDB \
    -f run.f \
    -top ${TB_NAME} \
    -o ../build/${TB_NAME}_sim

echo "=== Running UVM Simulation with +UVM_TESTNAME=${TEST_NAME} ==="
../build/${TB_NAME}_sim +UVM_TESTNAME=${TEST_NAME} +fsdb+autoflush -l ../build/${TB_NAME}.log

echo "=== Simulation Complete. Log: ../build/${TB_NAME}.log ==="
