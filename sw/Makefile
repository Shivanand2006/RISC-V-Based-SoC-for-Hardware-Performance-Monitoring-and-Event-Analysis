#=============================================================================
# File: Makefile
# Description: Bare-metal build system for SoC Firmware and Test Programs
#=============================================================================

CROSS_COMPILE ?= /opt/riscv/bin/riscv64-unknown-elf-
CC             = $(CROSS_COMPILE)gcc
OBJCOPY        = $(CROSS_COMPILE)objcopy
OBJDUMP        = $(CROSS_COMPILE)objdump

ARCH_FLAGS     = -march=rv32i -mabi=ilp32
CFLAGS         = $(ARCH_FLAGS) -O2 -nostdlib -ffreestanding -Wall -Wextra -I.
LDFLAGS        = -T link.ld -nostdlib -Wl,--build-id=none

TARGETS        = test_cycle test_instr test_event perf_app
HEX_FILES      = $(addsuffix .hex, $(TARGETS))
ELF_FILES      = $(addsuffix .elf, $(TARGETS))
BIN_FILES      = $(addsuffix .bin, $(TARGETS))
DUMP_FILES     = $(addsuffix .dump, $(TARGETS))

.PHONY: all clean

all: $(HEX_FILES) $(DUMP_FILES)

%.elf: %.c crt0.S link.ld perf_regs.h
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.S $< -o $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.hex: %.bin bin2hex.py
	python3 bin2hex.py $< > $@

%.dump: %.elf
	$(OBJDUMP) -d $< > $@

clean:
	rm -f $(ELF_FILES) $(BIN_FILES) $(HEX_FILES) $(DUMP_FILES)
