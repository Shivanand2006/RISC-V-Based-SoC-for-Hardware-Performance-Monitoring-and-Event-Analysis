#!/usr/bin/env bash
#=============================================================================
# Script: run_ip.sh
# Description: Automated simulation runner for IP blocks and SoC regression.
# Usage: ./run/run_ip.sh <cycle|instr|event|decoder|soc|all>
#=============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"

SIMULATOR="${SIMULATOR:-iverilog}" # Default to iverilog; supports vcs, vsim, verilator

TARGET="${1:-all}"

run_target() {
    local name="$1"
    local flist="${ROOT_DIR}/run/${name}.f"
    local log="${BUILD_DIR}/${name}.log"
    local sim_bin="${BUILD_DIR}/sim_${name}"

    mkdir -p "${BUILD_DIR}"
    echo "=========================================================="
    echo " Running Test: ${name} (Simulator: ${SIMULATOR})"
    echo "=========================================================="

    case "${SIMULATOR}" in
        iverilog)
            iverilog -g2001 -c "${flist}" -o "${sim_bin}" 2>&1 | tee "${log}"
            vvp "${sim_bin}" 2>&1 | tee -a "${log}"
            ;;
        vcs)
            vcs -full64 -sverilog +v2k -f "${flist}" -o "${sim_bin}" -l "${BUILD_DIR}/vcs_compile_${name}.log"
            "${sim_bin}" -l "${log}"
            ;;
        vsim|modelsim|questa)
            vlog -f "${flist}" -l "${BUILD_DIR}/vlog_${name}.log"
            vsim -c -do "run -all; quit" "tb_${name}" -l "${log}"
            ;;
        verilator)
            verilator --binary -f "${flist}" --top-module "tb_${name}" --prefix "Vtb_${name}" -Mdir "${BUILD_DIR}/obj_${name}"
            "${BUILD_DIR}/obj_${name}/Vtb_${name}" 2>&1 | tee "${log}"
            ;;
        *)
            echo "Error: Unknown simulator '${SIMULATOR}'. Supported: iverilog, vcs, vsim, verilator."
            exit 1
            ;;
    esac

    # Check for [FAIL] in simulation log
    if grep -q "\[FAIL\]" "${log}"; then
        echo ">>> Result: FAILED (${name})"
        return 1
    else
        echo ">>> Result: PASSED (${name})"
        return 0
    fi
}

FAILED_TESTS=()

execute_test() {
    local target_name="$1"
    if ! run_target "${target_name}"; then
        FAILED_TESTS+=("${target_name}")
    fi
}

cd "${ROOT_DIR}"

case "${TARGET}" in
    cycle)
        execute_test "cycle_cnt"
        ;;
    instr)
        execute_test "instr_cnt"
        ;;
    event)
        execute_test "event_cnt"
        ;;
    decoder)
        execute_test "decoder"
        ;;
    soc)
        execute_test "soc"
        ;;
    soc_veer)
        execute_test "soc_veer"
        ;;
    all)
        execute_test "cycle_cnt"
        execute_test "instr_cnt"
        execute_test "event_cnt"
        execute_test "decoder"
        execute_test "soc"
        ;;
    *)
        echo "Usage: $0 <cycle|instr|event|decoder|soc|soc_veer|all>"
        exit 1
        ;;
esac

echo ""
echo "=========================================================="
echo " Regression Summary"
echo "=========================================================="
if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo "All tests PASSED successfully."
    exit 0
else
    echo "The following tests FAILED: ${FAILED_TESTS[*]}"
    exit 1
fi
