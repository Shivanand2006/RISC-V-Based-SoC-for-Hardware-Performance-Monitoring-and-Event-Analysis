#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
PROJ=..
RV_ROOT=${PROJ}/rtl/Cores-VeeR-EL2
VCS_HOME=${VCS_HOME:-/home/student/snps_tools_target/vcs/U-2023.03}
VERDI_HOME=${VERDI_HOME:-/home/student/snps_tools_target/verdi/U-2023.03-SP1}
VCS=${VCS:-${VCS_HOME}/bin/vcs}
SIMV=./simv_soc_ctest

export VCS_HOME VERDI_HOME
export PATH=${VCS_HOME}/bin:${VERDI_HOME}/bin:${PATH}
export LD_LIBRARY_PATH=${VCS_HOME}/linux64/lib:${VERDI_HOME}/share/PLI/VCS/LINUX64:${LD_LIBRARY_PATH:-}

build_image() {
    RISCV_PREFIX=${RISCV_PREFIX:-riscv32-unknown-elf-} \
        bash "${PROJ}/ctests/build_soc_c_test.sh"
}

compile() {
    echo "=== Compiling SoC with Synopsys VCS ==="
    "${VCS}" -full64 -sverilog \
        -timescale=1ns/1ps -debug_access+all -kdb \
        +define+DUMP_FSDB +define+FSDB \
        +define+SIMULATION \
        +incdir+${RV_ROOT}/design/include \
        +incdir+${RV_ROOT}/configs \
        +incdir+${PROJ}/rtl/cycle_counter \
        +incdir+${PROJ}/rtl/instr_counter \
        +incdir+${PROJ}/rtl/event_counter \
        +incdir+${PROJ}/rtl/interconnect \
        +incdir+${PROJ}/rtl/peripherals \
        -f run_ctest.f -top tb_soc_ctest -o "${SIMV}" \
        -l compile_ctest.log
}

simulate() {
    echo "=== Executing C-Test Simulation ==="
    "${SIMV}" -l sim_ctest.log +C_IMAGE=soc_c_test.hex +fsdb+autoflush
    grep -q 'SOC_CTEST_RESULT=PASS' sim_ctest.log || {
        echo '[FAIL] C-test did not report SOC_CTEST_RESULT=PASS; see sim_ctest.log.' >&2
        return 1
    }
    echo '[PASS] Standalone C-test execution confirmed: SOC_CTEST_RESULT=PASS'
}

mode=${1:-all}
case "${mode}" in
    build)    build_image ;;
    compile)  compile ;;
    sim)      simulate ;;
    all)      build_image; compile; simulate ;;
    *) echo "Usage: $0 [build|compile|sim|all]" >&2; exit 2 ;;
esac
