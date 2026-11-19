# RISC-V GNU Toolchain Setup and Simulation Environment

## RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis

---

| Field | Details |
|---|---|
| **Document Type** | Toolchain Setup Guide |
| **Student ID** | 1602-23-735-108 |
| **Target Architecture** | RV32IMC / ILP32 |
| **Host OS** | Ubuntu 20.04 LTS / 22.04 LTS (Linux primary; Windows/macOS notes included) |

---

## 1. Overview — The RISC-V GNU Toolchain

The **RISC-V GNU Toolchain** is a cross-compilation suite that runs on a standard host machine (x86-64 Linux/Windows/macOS) and generates binaries for RISC-V target processors. For this project, we target **RV32IMC** (32-bit, Integer, Multiply/Divide, Compressed) with the **ILP32** ABI (int, long, and pointers are all 32-bit; no hardware floating point).

### 1.1 Toolchain Components

| Binary | Role |
|---|---|
| `riscv32-unknown-elf-gcc` | C compiler (cross-compiles to RV32 ELF) |
| `riscv32-unknown-elf-g++` | C++ compiler |
| `riscv32-unknown-elf-as` | Assembler |
| `riscv32-unknown-elf-ld` | Linker |
| `riscv32-unknown-elf-objcopy` | Object file format converter (ELF → binary/HEX) |
| `riscv32-unknown-elf-objdump` | Disassembler and object file analyser |
| `riscv32-unknown-elf-nm` | Symbol table lister |
| `riscv32-unknown-elf-size` | Section size reporter |
| `riscv32-unknown-elf-gdb` | GNU debugger (for JTAG / QEMU debugging) |

### 1.2 Why Build from Source?

Package managers (apt, brew) often provide `gcc-riscv64-unknown-elf` targeting 64-bit RISC-V. While it *can* produce 32-bit code with the right flags, it is cleaner to build the toolchain from source configured for `rv32imc` to avoid accidental 64-bit default behaviour and to get the most recent compiler optimisations.

### 1.3 ISA and ABI Flags

| Flag | Value | Meaning |
|---|---|---|
| `--with-arch` | `rv32imc` | Target ISA (RV32I + M + C extensions) |
| `--with-abi` | `ilp32` | ABI: 32-bit int/long/pointer, no FP registers |
| `-march=` | `rv32imc` | Per-compilation ISA flag |
| `-mabi=` | `ilp32` | Per-compilation ABI flag |

---

## 2. Linux Installation (Ubuntu / Debian)

### 2.1 Install Prerequisites

Open a terminal and install all build dependencies:

```bash
sudo apt-get update
sudo apt-get install -y \
    autoconf \
    automake \
    autotools-dev \
    curl \
    python3 \
    python3-pip \
    libmpc-dev \
    libmpfr-dev \
    libgmp-dev \
    gawk \
    build-essential \
    bison \
    flex \
    texinfo \
    gperf \
    libtool \
    patchutils \
    bc \
    zlib1g-dev \
    libexpat-dev \
    git \
    wget
```

Estimated download size: ~300 MB. Installation time: 5–10 minutes.

### 2.2 Clone the riscv-gnu-toolchain Repository

```bash
cd ~
git clone https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
```

> [!NOTE]
> The repository uses Git submodules for GCC, binutils, GDB, etc. These are large.
> The clone may take 10–30 minutes depending on your internet speed (total ~3–5 GB).

If the full clone is too slow, use a shallow clone:

```bash
git clone --depth=1 https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
git submodule update --init --recursive --depth=1
```

### 2.3 Configure for RV32IMC

```bash
./configure \
    --prefix=/opt/riscv \
    --with-arch=rv32imc \
    --with-abi=ilp32
```

| Configure Option | Meaning |
|---|---|
| `--prefix=/opt/riscv` | Install location; binaries go to `/opt/riscv/bin/` |
| `--with-arch=rv32imc` | Build the toolchain for RV32IMC target ISA |
| `--with-abi=ilp32` | Use ILP32 ABI (no hardware FP) |

> [!IMPORTANT]
> You need write permission to `/opt/riscv`. Either use `sudo mkdir -p /opt/riscv && sudo chown $USER /opt/riscv` or change `--prefix` to `$HOME/riscv` for a user-local install.

### 2.4 Build the Toolchain

```bash
# Use all available CPU cores for parallel build
make -j$(nproc)
```

Build time: 30–60 minutes on a modern 8-core machine. Progress output will show GCC, binutils, and newlib being compiled.

For the newlib (bare-metal C library) variant (required for `elf` target):

```bash
make newlib -j$(nproc)
```

### 2.5 Add to PATH

Add the toolchain to your shell PATH permanently:

```bash
# For bash
echo 'export PATH="/opt/riscv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# For zsh
echo 'export PATH="/opt/riscv/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

## 3. Verifying the Installation

After building, verify that the core tools are available and report the correct version:

```bash
# Check GCC version and target
riscv32-unknown-elf-gcc --version
```

Expected output:
```
riscv32-unknown-elf-gcc (GCC) 13.2.0
Copyright (C) 2023 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.
```

```bash
# Check objdump
riscv32-unknown-elf-objdump --version

# Check object copy
riscv32-unknown-elf-objcopy --version

# Quick compile test
echo 'int main() { return 0; }' > /tmp/test.c
riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -o /tmp/test.elf /tmp/test.c
riscv32-unknown-elf-objdump -d /tmp/test.elf | head -20
```

If the last command shows RISC-V assembly instructions (e.g., `addi`, `jalr`), the toolchain is working correctly.

### 3.1 Alternative: Pre-built Toolchain

If building from source is not feasible, use pre-built binaries:

**SiFive Freedom Tools:**
```bash
# Download from: https://github.com/sifive/freedom-tools/releases
wget https://github.com/sifive/freedom-tools/releases/download/v2020.12.0/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14.tar.gz
tar xf riscv64-unknown-elf-toolchain-*.tar.gz
export PATH="$PWD/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14/bin:$PATH"
```

**Ubuntu apt (64-bit, works with -m32 flags):**
```bash
sudo apt-get install -y gcc-riscv64-unknown-elf
# Use: riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 ...
```

---

## 4. Compiling a Bare-Metal Program

### 4.1 Linker Script (`link.ld`)

The linker script defines the memory layout of the generated ELF. For this SoC:
- Text (code) starts at `0x0000_0000` (IMEM base)
- Data and BSS follow in DMEM at `0x0000_1000`

```ld
/* link.ld – Linker script for RISC-V HPM SoC */

MEMORY {
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    DMEM (rwx) : ORIGIN = 0x00001000, LENGTH = 4K
}

SECTIONS {
    .text : {
        KEEP(*(.text.entry))   /* crt0.S entry point must come first */
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
    } > IMEM

    .data : {
        _data_start = .;
        *(.data)
        *(.data.*)
        _data_end = .;
    } > DMEM

    .bss : {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        _bss_end = .;
    } > DMEM

    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);  /* Stack grows down from DMEM top */
}
```

### 4.2 Startup Code (`crt0.S`)

The C runtime startup file performs essential bare-metal initialisation before calling `main()`:

```asm
/* crt0.S – Bare-metal startup for RISC-V HPM SoC */
    .section .text.entry
    .global _start
    .type   _start, @function

_start:
    /* 1. Set up stack pointer to top of DMEM */
    la   sp, _stack_top

    /* 2. Zero out BSS section */
    la   t0, _bss_start
    la   t1, _bss_end
bss_clear_loop:
    bgeu t0, t1, bss_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    bss_clear_loop
bss_done:

    /* 3. Copy .data from IMEM LMA to DMEM VMA (if applicable) */
    /* (Skipped if data is linked directly in DMEM for simulation) */

    /* 4. Set up global pointer (gp) */
    .option push
    .option norelax
    la   gp, __global_pointer$
    .option pop

    /* 5. Call main */
    call main

    /* 6. Infinite loop on return (should never reach here) */
_halt:
    j    _halt

    .size _start, . - _start
```

### 4.3 Project Makefile

The firmware `Makefile` orchestrates compilation, linking, and hex generation:

```makefile
# Makefile for RISC-V HPM SoC Firmware
# sw/Makefile

CROSS   = riscv32-unknown-elf-
CC      = $(CROSS)gcc
AS      = $(CROSS)as
LD      = $(CROSS)ld
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump
SIZE    = $(CROSS)size

ARCH    = rv32imc
ABI     = ilp32
CFLAGS  = -march=$(ARCH) -mabi=$(ABI) -O2 -g \
           -Wall -Wextra \
           -fno-common -ffunction-sections -fdata-sections \
           -nostdlib -nostartfiles \
           -I./include
LDFLAGS = -T link.ld -Wl,--gc-sections -Wl,-Map=$*.map

SRCS    = crt0.S
TESTS   = test_cycle test_instr test_event perf_app

.PHONY: all clean

all: $(TESTS:%=%.hex) $(TESTS:%=%.dis)

# Pattern rule: compile .c + crt0.S → ELF
%.elf: %.c crt0.S link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.S $< -o $@
	$(SIZE) $@

# ELF → flat binary
%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

# flat binary → Intel HEX (for $readmemh)
%.hex: %.bin
	python3 ../run/bin2hex.py $< $@ 4

# ELF → disassembly listing
%.dis: %.elf
	$(OBJDUMP) -D -M no-aliases $< > $@

clean:
	rm -f *.elf *.bin *.hex *.map *.dis
```

### 4.4 Compiling Individual Test Programs

```bash
cd sw/

# Compile cycle counter test
make test_cycle.hex

# Compile instruction counter test
make test_instr.hex

# Compile event counter test
make test_event.hex

# Compile integrated performance application
make perf_app.hex

# Compile all
make all
```

### 4.5 Example Compilation Command (Manual)

```bash
riscv32-unknown-elf-gcc \
    -march=rv32imc \
    -mabi=ilp32 \
    -O2 \
    -nostdlib \
    -nostartfiles \
    -T link.ld \
    -I include/ \
    -o test_cycle.elf \
    crt0.S test_cycle.c

# Check section sizes
riscv32-unknown-elf-size test_cycle.elf
```

Expected output:
```
   text    data     bss     dec     hex filename
    512       0       8     520     208 test_cycle.elf
```

---

## 5. Converting ELF to HEX for Simulation

Verilog simulation memories are initialised using `$readmemh`, which reads Intel HEX or plain hex-word files. The compilation pipeline produces `.hex` files.

### 5.1 Using `objcopy` to Get Binary

```bash
# Step 1: ELF → raw binary
riscv32-unknown-elf-objcopy -O binary test_cycle.elf test_cycle.bin

# Step 2: Inspect binary size
wc -c test_cycle.bin
```

### 5.2 Using `bin2hex.py`

The project includes a Python utility `run/bin2hex.py` that converts a raw binary into a plain hex-word file (one 32-bit word per line, little-endian bytes):

```python
#!/usr/bin/env python3
# run/bin2hex.py
# Usage: python3 bin2hex.py input.bin output.hex word_size_bytes

import sys, struct

def bin2hex(infile, outfile, word_bytes=4):
    with open(infile, 'rb') as f:
        data = f.read()
    # Pad to word boundary
    pad = (-len(data)) % word_bytes
    data += b'\x00' * pad
    with open(outfile, 'w') as f:
        for i in range(0, len(data), word_bytes):
            word = data[i:i+word_bytes]
            # Little-endian 32-bit word
            val = struct.unpack('<I', word)[0]
            f.write(f'{val:08x}\n')

if __name__ == '__main__':
    bin2hex(sys.argv[1], sys.argv[2], int(sys.argv[3]))
```

```bash
python3 run/bin2hex.py sw/test_cycle.bin sim_out/imem.hex 4
```

### 5.3 Memory Initialisation in Verilog

The `imem.v` module loads the hex file at simulation start:

```verilog
// imem.v
parameter MEM_DEPTH = 1024;  // 4KB / 4 bytes per word

reg [31:0] mem [0:MEM_DEPTH-1];

initial begin
    $readmemh("sim_out/imem.hex", mem);
end
```

### 5.4 Disassembly for Verification

Always generate a disassembly listing to verify the linker placed code correctly:

```bash
riscv32-unknown-elf-objdump -D -M no-aliases test_cycle.elf > test_cycle.dis
head -50 test_cycle.dis
```

Expected output showing code at address 0x0:
```
test_cycle.elf:     file format elf32-littleriscv

Disassembly of section .text:

00000000 <_start>:
   0:   00000117    auipc   sp,0x0
   4:   ...
```

---

## 6. Synopsys VCS Setup

Synopsys VCS is a commercial, industry-standard Verilog/SystemVerilog simulator. It is typically pre-installed in university server environments.

### 6.1 Environment Setup

```bash
# Source the VCS environment (path varies by institution)
source /tools/synopsys/vcs/setup.sh

# Or add to ~/.bashrc:
export VCS_HOME=/tools/synopsys/vcs/current
export PATH=$VCS_HOME/bin:$PATH
export LM_LICENSE_FILE=27000@license-server.university.edu

# Verify
vcs -version
```

### 6.2 Key VCS Flags Used in This Project

| Flag | Purpose |
|---|---|
| `-full64` | 64-bit simulation mode |
| `-sverilog` | Enable SystemVerilog parsing |
| `+v2k` | Verilog-2001 mode |
| `-debug_access+all` | Enable full debug access for Verdi |
| `-kdb` | Generate Verdi KDB (Knowledge Database) |
| `+fsdb+delta` | Enable FSDB waveform with delta cycles |
| `-timescale=1ns/1ps` | Simulation timescale |
| `-l sim.log` | Redirect log to file |

---

## 7. Synopsys Verdi Setup

Verdi is Synopsys's debug and waveform analysis platform, used to view FSDB waveform files generated by VCS.

### 7.1 Environment Setup

```bash
source /tools/synopsys/verdi/setup.sh

# Or manually:
export VERDI_HOME=/tools/synopsys/verdi/current
export PATH=$VERDI_HOME/bin:$PATH

# Verify
verdi -version
```

### 7.2 Opening a Waveform

```bash
# Launch Verdi with the compiled design and FSDB waveform
verdi -ssf sim_out/tb_soc_top.fsdb \
      -dbdir simv.daidir \
      -workMode hardwareDebug &
```

### 7.3 Key Verdi Features Used

- **Signal search**: Find any RTL signal by hierarchical path
- **Schematic view**: Visualise connectivity from RTL
- **Waveform annotation**: Compare expected vs actual values
- **nTrace**: Source code cross-probing (click waveform → go to RTL line)

---

## 8. Running Simulation

### 8.1 `run_ip.sh` Script

The `run/run_ip.sh` script is the primary entry point for unit-level IP testbenches:

```bash
#!/bin/bash
# run/run_ip.sh – Compile and simulate a specific IP testbench
#
# Usage:
#   ./run/run_ip.sh cycle       → runs tb_cycle_cnt
#   ./run/run_ip.sh instr       → runs tb_instr_cnt
#   ./run/run_ip.sh event       → runs tb_event_cnt
#   ./run/run_ip.sh bus         → runs tb_bus_decoder
#   ./run/run_ip.sh soc         → runs tb_soc_top

IP=$1

case $IP in
    cycle) TB="tb/tb_cycle_cnt.v";    RTL="rtl/cycle_cnt_top.v rtl/reg_slave_if.v" ;;
    instr) TB="tb/tb_instr_cnt.v";    RTL="rtl/instr_cnt_top.v rtl/reg_slave_if.v" ;;
    event) TB="tb/tb_event_cnt.v";    RTL="rtl/event_cnt_top.v rtl/reg_slave_if.v" ;;
    bus)   TB="tb/tb_bus_decoder.v";  RTL="rtl/bus_decoder.v"                       ;;
    soc)   TB="tb/tb_soc_top.v";      RTL="rtl/soc_top.v rtl/bus_decoder.v \
                                            rtl/veer_core_adapter.sv \
                                            rtl/cycle_cnt_top.v rtl/instr_cnt_top.v \
                                            rtl/event_cnt_top.v rtl/reg_slave_if.v \
                                            rtl/uart_top.v rtl/timer_top.v \
                                            rtl/gpio_top.v rtl/imem.v rtl/dmem.v"  ;;
    *)     echo "ERROR: Unknown IP '$IP'"; exit 1 ;;
esac

mkdir -p sim_out

echo "============================================================"
echo " Compiling: $TB"
echo "============================================================"

vcs -full64 \
    +v2k \
    -sverilog \
    -timescale=1ns/1ps \
    -debug_access+all \
    -kdb \
    -o sim_out/simv_${IP} \
    -l sim_out/compile_${IP}.log \
    ${RTL} ${TB}

if [ $? -ne 0 ]; then
    echo "COMPILATION FAILED. Check sim_out/compile_${IP}.log"
    exit 1
fi

echo "============================================================"
echo " Simulating: $IP"
echo "============================================================"

sim_out/simv_${IP} \
    -l sim_out/sim_${IP}.log \
    +fsdb+delta \
    +define+DUMP_FSDB \
    -ucli -do "fsdbDumpfile sim_out/tb_${IP}.fsdb; \
               fsdbDumpvars 0 tb; \
               run; \
               exit"

echo "============================================================"
echo " Done. Log: sim_out/sim_${IP}.log"
echo " Waveform: sim_out/tb_${IP}.fsdb"
echo "============================================================"
```

### 8.2 Running IP-Level Testbenches

```bash
# Navigate to project root
cd RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis/

# Make script executable
chmod +x run/run_ip.sh

# Run Cycle Counter testbench
./run/run_ip.sh cycle

# Run Instruction Counter testbench
./run/run_ip.sh instr

# Run Event Counter testbench
./run/run_ip.sh event

# Run Bus Decoder testbench
./run/run_ip.sh bus

# Run full SoC testbench
./run/run_ip.sh soc
```

### 8.3 Expected Simulation Output

A passing testbench prints:

```
============================================================
 Compiling: tb/tb_cycle_cnt.v
============================================================
...VCS compile messages...

============================================================
 Simulating: cycle
============================================================
[  0 ns] RESET asserted
[ 10 ns] RESET released
[ 20 ns] TEST: Enable cycle counter
[ 30 ns] TEST: Counter running...
[100 ns] TEST: Disable counter – elapsed = 7 cycles (expected 7) PASS
[110 ns] TEST: Clear counter
[120 ns] TEST: Counter = 0 after clear PASS
[200 ns] TEST: 64-bit shadow read – CNT_HI coherent PASS
[200 ns] ===========================
[200 ns]  ALL TESTS PASSED
[200 ns] ===========================
$finish called at 200 ns

============================================================
 Done. Log: sim_out/sim_cycle.log
 Waveform: sim_out/tb_cycle.fsdb
============================================================
```

### 8.4 Viewing Waveforms in Verdi

```bash
verdi -ssf sim_out/tb_cycle.fsdb \
      -dbdir sim_out/simv_cycle.daidir \
      -workMode hardwareDebug &
```

In the Verdi GUI:
1. Navigate the design hierarchy in the left panel.
2. Select signals of interest (`cnt_lo_int`, `cnt_hi_int`, `shadow_hi`, `ctrl_enable`).
3. Click "Add to waveform" (or press `Ctrl+W`).
4. Use zoom and cursor tools to measure timing relationships.

### 8.5 Firmware Compile + Simulation Flow (End-to-End)

```bash
# Step 1: Compile firmware
cd sw/
make test_cycle.hex
cp test_cycle.hex ../sim_out/imem.hex
cd ..

# Step 2: Run SoC simulation (loads imem.hex automatically)
./run/run_ip.sh soc

# Step 3: Check UART output in log (perf_app.c prints results via UART)
grep "CPI\|PASS\|FAIL" sim_out/sim_soc.log
```

---

## 9. Windows Installation Notes

For Windows users who cannot use a Linux server, two options are available:

### 9.1 Windows Subsystem for Linux (WSL2) — Recommended

```powershell
# Install WSL2 (PowerShell, Admin)
wsl --install -d Ubuntu-22.04
# Restart when prompted, then continue in WSL terminal
# Follow the Linux installation steps above exactly
```

### 9.2 Pre-built Windows Binaries

Download from **https://xpack.github.io/riscv-none-elf-gcc/releases/**:

```powershell
# Extract to C:\riscv-toolchain\
# Add C:\riscv-toolchain\bin to System PATH via:
# Control Panel → System → Advanced → Environment Variables
# Then in cmd.exe:
riscv-none-elf-gcc --version
```

> [!WARNING]
> Synopsys VCS and Verdi are Linux-only tools. For Windows simulation, use **Icarus Verilog** (`iverilog`) + **GTKWave** as an open-source alternative.

### 9.3 Icarus Verilog Alternative

```bash
# Install
sudo apt-get install -y iverilog gtkwave

# Compile and simulate (cycle counter example)
iverilog -g2001 \
    -o sim_out/tb_cycle \
    -I rtl/ \
    rtl/reg_slave_if.v \
    rtl/cycle_cnt_top.v \
    tb/tb_cycle_cnt.v

# Run simulation (generates VCD)
vvp sim_out/tb_cycle +dump_vcd

# View waveform
gtkwave sim_out/tb_cycle.vcd &
```

---

*End of RISC-V Toolchain Setup Guide*
