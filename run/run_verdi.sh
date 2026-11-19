#!/usr/bin/env bash
#=============================================================================
# Script: run_verdi.sh
# Description: Compiles design with Synopsys VCS (-kdb -debug_access+all),
#              runs simulation to generate FSDB waveform, and launches Verdi.
# Usage: ./run/run_verdi.sh [soc|cycle|instr|event|decoder] [gui|batch]
#=============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"

# Set up VCS and Verdi environment if not already in PATH
if ! command -v vcs &> /dev/null || ! command -v verdi &> /dev/null; then
    export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-27021@14.139.1.126}"
    export VCS_HOME="${VCS_HOME:-/home/student/snps_tools_target/vcs/U-2023.03}"
    export VERDI_HOME="${VERDI_HOME:-/home/student/snps_tools_target/verdi/U-2023.03-SP1}"
    export PATH="${VCS_HOME}/bin:${VERDI_HOME}/bin:${PATH}"
fi

export DISPLAY="${DISPLAY:-:0}"
if [ -z "${XAUTHORITY}" ]; then
    AUTHF=$(ls -1t /run/user/$(id -u)/.mutter-Xwaylandauth.* 2>/dev/null | head -n 1 || true)
    if [ -n "${AUTHF}" ] && [ -f "${AUTHF}" ]; then
        export XAUTHORITY="${AUTHF}"
    fi
fi

TARGET="${1:-soc}"
MODE="${2:-gui}"

cd "${ROOT_DIR}"
mkdir -p "${BUILD_DIR}"

case "${TARGET}" in
    soc|soc_veer)
        FLIST="run/soc.f"
        TOP="tb_soc_top"
        FSDB="tb_soc_top.fsdb"
        EXTRA_SIM_ARGS="+firmware=${ROOT_DIR}/sw/perf_app.hex"
        ;;
    cycle|cycle_cnt)
        FLIST="run/cycle_cnt.f"
        TOP="tb_cycle_cnt"
        FSDB="tb_cycle_cnt.fsdb"
        EXTRA_SIM_ARGS=""
        ;;
    instr|instr_cnt)
        FLIST="run/instr_cnt.f"
        TOP="tb_instr_cnt"
        FSDB="tb_instr_cnt.fsdb"
        EXTRA_SIM_ARGS=""
        ;;
    event|event_cnt)
        FLIST="run/event_cnt.f"
        TOP="tb_event_cnt"
        FSDB="tb_event_cnt.fsdb"
        EXTRA_SIM_ARGS=""
        ;;
    decoder)
        FLIST="run/decoder.f"
        TOP="tb_bus_decoder"
        FSDB="tb_bus_decoder.fsdb"
        EXTRA_SIM_ARGS=""
        ;;
    *)
        echo "Usage: $0 [soc|cycle|instr|event|decoder] [gui|batch]"
        exit 1
        ;;
esac

SIM_BIN="${BUILD_DIR}/sim_${TARGET}"
DAIDIR="${BUILD_DIR}/sim_${TARGET}.daidir"

echo "=========================================================="
echo " 1. Compiling ${TARGET} with VCS (KDB + FSDB enabled)..."
echo "=========================================================="
vcs -full64 -sverilog +v2k -timescale=1ns/1ps \
    -kdb -debug_access+all \
    +define+FSDB \
    -top "${TOP}" \
    -f "${FLIST}" \
    -o "${SIM_BIN}" \
    -Mdir="${BUILD_DIR}/csrc_${TARGET}" \
    -l "${BUILD_DIR}/vcs_compile_${TARGET}.log"

echo ""
echo "=========================================================="
echo " 2. Running Simulation to generate FSDB waveform..."
echo "=========================================================="
"${SIM_BIN}" +fsdb+autoflush ${EXTRA_SIM_ARGS} -l "${BUILD_DIR}/sim_${TARGET}.log"

echo ""
echo "=========================================================="
echo " 3. Launching Verdi with ${FSDB}..."
echo "=========================================================="
if [ "${MODE}" = "gui" ]; then
    verdi -ssf "${FSDB}" -dbdir "${DAIDIR}" &
else
    echo "Batch mode requested. Waveform generated at: ${FSDB}"
    echo "To view later in Verdi, run:"
    echo "  verdi -ssf ${FSDB} -dbdir ${DAIDIR} &"
fi
