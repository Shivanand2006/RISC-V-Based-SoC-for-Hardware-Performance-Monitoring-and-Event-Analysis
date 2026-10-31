# RISC-V SoC for Hardware Performance Monitoring and Event Analysis

A complete, synthesizable Verilog-2001 RISC-V system-on-chip featuring three dedicated memory-mapped Hardware Performance Monitoring (HPM) IPs:

1. **Cycle Counter**: 64-bit counter tracking enabled processor clock cycles with coherent shadow reads.
2. **Instruction Counter**: 64-bit counter tracking retired instructions from commit stage.
3. **Performance Event Counter**: 32-bit counter monitoring any of 8 selectable hardware events with sticky overflow, threshold compare, and interrupt generation.

---

## Repository Structure

```
.
├── AGENT_PROMPT.md                  # Project specification prompt
├── README.md                        # Project documentation and guide
├── testmap_soc.xlsx                 # Reference test plan format
├── testplan_soc_hpm.xlsx            # Master SoC HPM verification test plan (Excel)
├── doc/
│   ├── core_interface.md            # RISC-V core interfaces, bus protocols, and events
│   ├── memory_map.md                # System memory map and decoding rules
│   ├── register_map.md              # Register definitions for all IPs and peripherals
│   ├── testplan_soc_hpm.md          # Complete HPM SoC master test plan specification
│   └── verification_plan.md         # Test plan and verification coverage matrix
├── rtl/
│   ├── common/
│   │   └── reg_slave_if.v           # Bus-to-register adapter interface
│   ├── core/
│   │   ├── ahb_imem_adapter.v       # VeeR IFU AHB-Lite to IMEM adapter
│   │   ├── ahb_to_bus_adapter.v     # VeeR LSU AHB-Lite to System Bus adapter
│   │   └── veer_core_adapter.sv     # Top wrapper for CHIPS Alliance VeeR EL2 core
│   ├── cycle_counter/
│   │   ├── cycle_cnt_defines.vh     # Cycle counter register defines
│   │   └── cycle_cnt_top.v          # 64-bit Cycle Counter IP
│   ├── event_counter/
│   │   ├── event_cnt_defines.vh     # Event counter register defines
│   │   └── event_cnt_top.v          # 32-bit Performance Event Counter IP
│   ├── instr_counter/
│   │   ├── instr_cnt_defines.vh     # Instruction counter register defines
│   │   └── instr_cnt_top.v          # 64-bit Instruction Counter IP
│   ├── interconnect/
│   │   ├── bus_decoder.v            # Central address decoder and bus interconnect
│   │   └── interconnect_defines.vh  # Base addresses and mask definitions
│   ├── mem/
│   │   ├── dmem.v                   # 4KB Data RAM model (byte-writable)
│   │   └── imem.v                   # 4KB Instruction RAM model
│   ├── peripherals/
│   │   ├── gpio_defines.vh          # GPIO register defines
│   │   ├── gpio_top.v               # 8-bit GPIO peripheral
│   │   ├── timer_defines.vh         # Timer register defines
│   │   ├── timer_top.v              # 32-bit Timer peripheral
│   │   ├── uart_defines.vh          # UART register defines
│   │   └── uart_top.v               # 16550-compatible 8N1 UART
│   └── top/
│       └── soc_top.v                # Top-level SoC integration
├── run/
│   ├── cycle_cnt.f                  # File list for Cycle Counter unit test
│   ├── decoder.f                    # File list for Bus Decoder unit test
│   ├── event_cnt.f                  # File list for Event Counter unit test
│   ├── instr_cnt.f                  # File list for Instruction Counter unit test
│   ├── run_ip.sh                    # Automated regression runner script
│   ├── soc.f                        # File list for SoC top-level simulation (VeeR EL2 Core)
│   └── soc_veer.f                   # File list for SoC top-level simulation (VeeR EL2 Core)
└── tb/
    ├── common/
    │   └── bus_bfm.v                # Reusable Bus BFM tasks and assertion helpers
    ├── cycle_counter/
    │   └── tb_cycle_cnt.v           # Self-checking Cycle Counter testbench
    ├── event_counter/
    │   └── tb_event_cnt.v           # Self-checking Event Counter testbench
    ├── instr_counter/
    │   └── tb_instr_cnt.v           # Self-checking Instruction Counter testbench
    ├── interconnect/
    │   └── tb_bus_decoder.v         # Self-checking Bus Decoder testbench
    └── top/
        ├── tb_soc_top.v             # SoC top testbench with shadow cross-checks
        └── uart_monitor.v           # Passive 8N1 UART decoder and token watcher
```

---

## Memory Map

| Address Range | Size | Peripheral / Memory |
|---|---|---|
| `0x0000_0000 – 0x0000_0FFF` | 4 KB | Instruction Memory (IMEM) |
| `0x0000_1000 – 0x0000_1FFF` | 4 KB | Data Memory (DMEM) |
| `0x0000_2000 – 0x0000_20FF` | 256 B | UART (16550 subset) |
| `0x0000_2100 – 0x0000_21FF` | 256 B | 32-bit Timer |
| `0x0000_2200 – 0x0000_22FF` | 256 B | 8-bit GPIO |
| `0x0000_2300 – 0x0000_23FF` | 256 B | 64-bit Cycle Counter |
| `0x0000_2400 – 0x0000_24FF` | 256 B | 64-bit Instruction Counter |
| `0x0000_2500 – 0x0000_25FF` | 256 B | 32-bit Performance Event Counter |

---

## Performance Event Select Table

| `EVT_SEL` | Hardware Event | Core Signal Source |
|---|---|---|
| `0` | Data memory read accepted (Load) | `evt_load_o` |
| `1` | Data memory write accepted (Store) | `evt_store_o` |
| `2` | Instruction fetch request accepted | `evt_fetch_o` |
| `3` | Branch or Jump taken | `evt_branch_jump_o` |
| `4` | Pipeline stall or memory wait cycle | `evt_stall_bubble_o` |
| `5` | Exception or Trap taken | `evt_exception_o` |
| `6` | Timer interrupt tick event | `timer_tick` |
| `7` | UART frame transmit complete | `uart_tx_done` |

---

## Running Verification

Run unit tests and SoC simulation using the automated script:

```bash
# Run all unit testbenches and regression
./run/run_ip.sh all

# Or run individual IP testbenches:
./run/run_ip.sh cycle     # Cycle Counter unit test
./run/run_ip.sh instr     # Instruction Counter unit test
./run/run_ip.sh event     # Event Counter unit test
./run/run_ip.sh decoder   # Address Decoder unit test
./run/run_ip.sh soc       # SoC Top-level testbench (VeeR EL2 Core)
./run/run_ip.sh soc_veer  # SoC Top-level testbench (VeeR EL2 Core alias)
```

The script supports `SIMULATOR=iverilog` (default), `SIMULATOR=vcs`, `SIMULATOR=vsim`, or `SIMULATOR=verilator`.
