#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${RISCV_PREFIX:-riscv32-unknown-elf-}"
CC="${PREFIX}gcc"
OBJCOPY="${PREFIX}objcopy"
OBJDUMP="${PREFIX}objdump"
OUT="${ROOT}/ctests/soc_c_test"

command -v "${CC}" >/dev/null || { echo "Missing ${CC}; set RISCV_PREFIX to your RISC-V toolchain prefix." >&2; exit 1; }
command -v "${OBJCOPY}" >/dev/null || { echo "Missing ${OBJCOPY}." >&2; exit 1; }

echo "=== Building ${OUT}.c with ${CC} ==="
"${CC}" -march=rv32imc -mabi=ilp32 -O2 -ffreestanding -fno-builtin \
    -fno-pic -mno-relax -nostdlib -nostartfiles -static \
    -Wl,--build-id=none -Wl,-T,"${ROOT}/ctests/soc_c_test.ld" \
    "${ROOT}/ctests/soc_c_start.S" "${ROOT}/ctests/soc_c_test.c" \
    -o "${OUT}.elf"

"${OBJCOPY}" -O binary "${OUT}.elf" "${OUT}.bin"
"${OBJCOPY}" -O ihex "${OUT}.elf" "${OUT}.ihex"
if command -v "${OBJDUMP}" >/dev/null; then
    "${OBJDUMP}" -d "${OUT}.elf" > "${OUT}.dump"
fi

python3 "${ROOT}/ctests/ihex_to_memh.py" "${OUT}.ihex" "${OUT}.memh"
cp "${OUT}.memh" "${OUT}.hex"

echo "=== Built ${OUT}.elf, ${OUT}.ihex, ${OUT}.memh, and ${OUT}.hex successfully ==="
