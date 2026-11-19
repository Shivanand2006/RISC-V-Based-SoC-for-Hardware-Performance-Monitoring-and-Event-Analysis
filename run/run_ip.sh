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

# Set up VCS environment if available and not yet in PATH
if ! command -v vcs &> /dev/null; then
    export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-27021@14.139.1.126}"
    export VCS_HOME="${VCS_HOME:-/home/student/snps_tools_target/vcs/U-2023.03}"
    export VERDI_HOME="${VERDI_HOME:-/home/student/snps_tools_target/verdi/U-2023.03-SP1}"
    if [ -d "${VCS_HOME}/bin" ]; then
        export PATH="${VCS_HOME}/bin:${VERDI_HOME}/bin:${PATH}"
    fi
fi

SIMULATOR="${SIMULATOR:-vcs}" # Default to vcs; supports iverilog, vcs, vsim, verilator

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
            local extra_vcs_compile=""
            local extra_sim_args=""
            if [ "${name}" = "soc" ]; then
                extra_vcs_compile="-top tb_soc_top"
                if [ ! -f "${ROOT_DIR}/sw/perf_app.hex" ]; then
                    echo "Building bare-metal firmware..."
                    make -C "${ROOT_DIR}/sw" all
                fi
                extra_sim_args="+firmware=${ROOT_DIR}/sw/perf_app.hex"
            fi

            vcs -full64 -sverilog +v2k -timescale=1ns/1ps -kdb -debug_access+all +define+FSDB ${extra_vcs_compile} -f "${flist}" -o "${sim_bin}" -l "${BUILD_DIR}/vcs_compile_${name}.log" || {
                echo "Error: VCS Compilation failed for ${name}. See ${BUILD_DIR}/vcs_compile_${name}.log"
                return 1
            }
            "${sim_bin}" +fsdb+autoflush ${extra_sim_args} -l "${log}" || {
                echo "Error: Simulation execution failed for ${name}."
                return 1
            }
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
