# PROMPT FOR AI CODING AGENT

Copy everything below the line into the agent.

---

## ROLE

You are a senior RTL design and verification engineer. Design, implement and verify, in synthesizable Verilog, a complete RISC-V based SoC for **Hardware Performance Monitoring and Event Analysis**. Deliver working RTL, self-checking testbenches, firmware, run scripts and documentation. Work step by step, compile and simulate everything you write, and fix every error before reporting.

## 1. PROJECT SUMMARY

A RISC-V processor core runs a small test application. Three dedicated memory-mapped performance-monitor IPs observe the processor in hardware:

| IP | Purpose |
|---|---|
| Cycle Counter | counts enabled clock cycles |
| Instruction Counter | counts retired instructions |
| Performance Event Counter | counts one software-selected processor/system event, with optional threshold interrupt |

The application clears and enables the counters, runs a known workload, reads the counters, and prints the results over UART. GPIO is a completion/status indicator. A Timer peripheral is also present.

The monitors run independently of the application. The CPU only touches them for control and status access, so measurement adds no software overhead.

## 2. INPUTS YOU MUST EXAMINE FIRST

1. **The provided RISC-V core RTL** (path: `<CORE_PATH>`). Before writing anything, read it and write `doc/core_interface.md` that lists:
   - the data-memory bus protocol (simple valid/ready, Wishbone, AXI-Lite, AHB-Lite, etc.), with every signal name, width and timing rule;
   - the instruction-fetch interface;
   - the reset polarity and clock;
   - the interrupt input(s);
   - any signal that indicates **instruction retirement / commit / valid-writeback**;
   - any signals usable as events: branch taken, load, store, stall, memory request, cache/bubble, exception.
2. If a signal I need does not exist, do not invent it. Pick the closest real signal, state the exact signal and file in the documentation, and flag the limitation.
3. If UART, Timer and GPIO IPs are provided (`<PERIPH_PATH>`), reuse them unchanged, and only write bus adapters if needed. If not provided, write simple memory-mapped versions (see section 5).

If the core bus is not a simple register bus, write one reusable **bus-to-register adapter** and keep the three monitor IPs on the simple register interface in section 4.

## 3. MEMORY MAP (preliminary, adapt only if the core's bus forces it)

| Address range | Module | Size |
|---|---|---|
| `0x0000_0000 – 0x0000_0FFF` | Instruction Memory | 4 KB |
| `0x0000_1000 – 0x0000_1FFF` | Data Memory | 4 KB |
| `0x0000_2000 – 0x0000_20FF` | UART | 256 B |
| `0x0000_2100 – 0x0000_21FF` | Timer | 256 B |
| `0x0000_2200 – 0x0000_22FF` | GPIO | 256 B |
| `0x0000_2300 – 0x0000_23FF` | Cycle Counter | 256 B |
| `0x0000_2400 – 0x0000_24FF` | Instruction Counter | 256 B |
| `0x0000_2500 – 0x0000_25FF` | Performance Event Counter | 256 B |

Rules:
- Implement a central **address decoder / interconnect** using these ranges. Each peripheral sees only its offset `addr[7:0]`.
- Access to an unmapped address must return a defined error response (or `0x0` data with an error flag, depending on the bus) and must never hang the core.
- If you change any range, update this table in `doc/memory_map.md` and in the C header, and say so in your final report.

## 4. COMMON REGISTER INTERFACE FOR THE THREE MONITOR IPs

Create one shared module `reg_slave_if.v` that adapts the system bus to this simple interface, and build the three IPs on it:

```
reg_wr_en   : 1-cycle pulse, write strobe
reg_waddr   : [7:0] byte offset
reg_wdata   : [31:0]
reg_wstrb   : [3:0]
reg_werr    : input, 1 = undefined offset
reg_rd_en   : 1-cycle pulse, read strobe (read side effects happen here)
reg_raddr   : [7:0] byte offset
reg_rdata   : input [31:0], combinational from the IP
reg_rerr    : input, 1 = undefined offset
```

General rules for all registers:
- 32-bit registers, word aligned, little-endian.
- Writes to read-only registers are accepted and ignored (no error).
- Access to any undefined offset returns an error response.
- Reserved bits read as 0; writes to them are ignored.
- Active-low asynchronous reset (`rst_n`), single clock `clk`, all registers reset to 0.
- Synthesizable Verilog-2001 style only: no latches, no `initial` in RTL, no delays, no tri-states.

## 5. IP SPECIFICATIONS

### 5.1 Cycle Counter (base `0x0000_2300`)

64-bit counter incrementing every clock cycle while enabled.

| Offset | Name | Access | Description |
|---|---|---|---|
| `0x00` | CTRL | R/W | bit0 `EN`; bit1 `CLEAR` (write 1 = counter returns to 0, self-clearing, reads 0) |
| `0x04` | STATUS | RO | bit0 `RUNNING` (mirrors EN) |
| `0x08` | CNT_LO | RO | count[31:0]. **Reading this register captures count[63:32] into a shadow register in the same cycle.** |
| `0x0C` | CNT_HI | RO | shadow of count[63:32] captured by the last CNT_LO read |

Behaviour: `CLEAR` has priority over counting. After reset the counter is disabled. A LO-then-HI read sequence must always give a coherent 64-bit value even though the counter keeps running.

### 5.2 Instruction Counter (base `0x0000_2400`)

64-bit counter. Input `instr_retire_i`. It increments by 1 on each cycle where `instr_retire_i = 1` and `EN = 1`. If the core can retire more than one instruction per cycle, make the input `[N-1:0]` and add the population count.

Register layout **identical to the Cycle Counter** (CTRL, STATUS, CNT_LO, CNT_HI at `0x00, 0x04, 0x08, 0x0C`), including the shadow-capture rule.

Connect `instr_retire_i` to the retirement/commit-valid signal found in section 2. Document exactly which signal this is and whether it also pulses for trapped or flushed instructions.

### 5.3 Performance Event Counter (base `0x0000_2500`)

32-bit counter that counts exactly one selected event.

| Offset | Name | Access | Description |
|---|---|---|---|
| `0x00` | CTRL | R/W | bit0 `EN`; bit1 `CLEAR` (W1 pulse: clears COUNT, OVF, THRESH_HIT); bit2 `IRQ_EN` |
| `0x04` | EVT_SEL | R/W | bits[2:0] selected event index |
| `0x08` | COUNT | RO | 32-bit event count |
| `0x0C` | THRESH | R/W | threshold; 0 disables the compare |
| `0x10` | STATUS | R/W1C | bit0 `OVF` (wrap past 0xFFFF_FFFF, sticky); bit1 `THRESH_HIT` (sticky); bit2 `RUNNING` (RO) |

Behaviour:
- Input `events_i[7:0]`, each a **1-cycle pulse** in the `clk` domain. `count` increments when `EN` and `events_i[EVT_SEL]`.
- `THRESH_HIT` is set by an increment that makes `COUNT >= THRESH` (when `THRESH != 0`). Writing 1 to the bit clears it, and it re-arms on the next counted event.
- A new event wins over a simultaneous W1C write of the same bit.
- Output `irq_o = IRQ_EN & THRESH_HIT`, wired to a core interrupt input if the core has one, otherwise left observable at the top level.

Event encoding (map each to a **real signal** of the provided core and document the mapping; if a listed event does not exist, replace it and update the table):

| `EVT_SEL` | Event |
|---|---|
| 0 | data-memory read request accepted (load) |
| 1 | data-memory write request accepted (store) |
| 2 | instruction fetch request accepted |
| 3 | branch / jump taken |
| 4 | pipeline stall or bubble cycle |
| 5 | exception / trap taken |
| 6 | timer interrupt event |
| 7 | UART transmit-complete or reserved (tie to 0) |

### 5.4 Timer, UART, GPIO (only if not provided)

- **Timer** (`0x0000_2100`): `0x00` EN, `0x04` RELOAD, `0x08` COUNT (RO). 32-bit down-counter; reloads and pulses `tick_o` for one cycle at zero.
- **UART** (`0x0000_2000`): 8N1 transmitter plus receiver, 16550-style subset. `0x00` THR/RBR, `0x04` IER, `0x08` baud divisor, `0x0C` LCR, `0x14` LSR (bit5 THRE, bit6 TEMT, bit0 DATA_READY). Default 115200 baud at the system clock.
- **GPIO** (`0x0000_2200`): `0x00` DIR, `0x04` OUT, `0x08` IN (2-flop synchronized). 8 bits.

## 6. TOP-LEVEL SOC

`soc_top.v` instantiates: the provided core, instruction memory, data memory, interconnect/decoder, UART, Timer, GPIO, Cycle Counter, Instruction Counter, Event Counter. Top-level ports: `clk`, `rst_n`, `uart_tx`, `uart_rx`, `gpio_in[7:0]`, `gpio_out[7:0]`.

- Instruction/data memories are synchronous-read RAM models; the instruction memory is loaded with `$readmemh` from a plusarg file path.
- Connect `instr_retire_i`, `events_i[7:0]` and the interrupt exactly as documented in section 2.
- The monitor IPs must **not** add any wait state that would alter the measured program's timing, so their register slave answers in a fixed small number of cycles and the core's accesses to them are the only added cost.

## 7. FIRMWARE (C, bare-metal, RV32I or whatever the core supports)

Provide `crt0.S`, `link.ld` and a Makefile that produces a hex file in the format the instruction-memory model reads (one 32-bit word per line). Provide `perf_regs.h` with every address and bit macro from sections 3 and 5.

Programs:
1. `test_cycle.c`: clear/enable, run a delay loop, read, verify the count is non-zero and increasing, verify hold when disabled, verify CLEAR, verify the coherent 64-bit read.
2. `test_instr.c`: run a loop of known instruction count and verify the instruction count is within the expected range; verify cycles >= instructions.
3. `test_event.c`: for each implemented event, run a stimulus that must generate it (e.g. N stores for event 1), and compare against the expected count. Test the threshold flag and interrupt.
4. `perf_app.c` (main demo): clear and enable all three counters, run a known computation (for example bubble sort of 16 words, or matrix multiply 4x4), disable the counters, read them, and print through UART:
   ```
   Cycles       : <decimal>
   Instructions : <decimal>
   Events (<name>): <decimal>
   CPI x100     : <decimal>
   PASS
   ```
   Then set `GPIO_OUT[0] = 1`. Print `FAIL` and set `GPIO_OUT[1] = 1` on any mismatch.

Do not use the C library (`printf`, `malloc`); implement small `uart_putc/uart_print/uart_print_dec/uart_print_hex` helpers.

## 8. VERIFICATION (self-checking, Verilog)

Provide testbenches that print `[PASS]` / `[FAIL]` per test case with a final summary and exit code, and never rely on waveform inspection.

**Unit testbenches** (one per monitor IP) driving the IP through its bus using a reusable BFM task library (`bus_write`, `bus_read`):
- Cycle/Instruction counter: reset defaults; EN/CLEAR; count increments only when enabled; instruction counter ignores cycles without `instr_retire_i`; CLEAR priority over counting; coherent 64-bit read while counting; counter above 32 bits (force a value near `0xFFFF_FFFF` by adding a `+define+SIM` backdoor preload or running long enough) to prove the carry into CNT_HI; write to RO register ignored with OKAY; undefined offset returns error on read and write.
- Event counter: each of 8 event selects counts only its own pulse; changing EVT_SEL; THRESH compare, sticky and re-arm; W1C vs simultaneous event priority; OVF; IRQ_EN gating of `irq_o`; CLEAR clears all; threshold 0 disables compare.
- Address decoder: every mapped window selects exactly one peripheral at its first and last address, the byte after each window is not selected, and unmapped addresses return the error response without hanging.

**SoC testbench** `tb_soc_top.v`:
- clock/reset, load firmware by `+firmware=<hex>` plusarg;
- passive UART monitor that decodes 8N1 and prints characters, and sets `pass_seen` / `fail_seen` on the tokens `PASS` / `FAIL`;
- GPIO monitor;
- global timeout watchdog;
- end-of-test cross-checks using hierarchical references: cycle count > instruction count > 0, and event counts match an independent testbench-side counter that watches the same signals.

Add a coverage list of what each test checks in `doc/verification_plan.md`.

## 9. REPOSITORY LAYOUT

```
rtl/common/reg_slave_if.v
rtl/cycle_counter/   cycle_cnt_top.v  cycle_cnt_defines.vh
rtl/instr_counter/   instr_cnt_top.v  instr_cnt_defines.vh
rtl/event_counter/   event_cnt_top.v  event_cnt_defines.vh
rtl/interconnect/    bus_decoder.v    (plus any adapter)
rtl/mem/             imem.v dmem.v
rtl/top/             soc_top.v
rtl/peripherals/     (only if not provided)
tb/common/           bus_bfm.v
tb/<ip>/             one testbench per IP and decoder
tb/top/              tb_soc_top.v  uart_monitor.v
sw/                  crt0.S link.ld Makefile perf_regs.h test_*.c perf_app.c
run/                 *.f file lists, run_ip.sh
doc/                 core_interface.md memory_map.md register_map.md verification_plan.md
README.md
```

## 10. TOOLS AND RUN SCRIPTS

Target simulator: `<VCS | Questa/ModelSim | Icarus Verilog | Verilator>`. Provide `run/run_ip.sh <cycle|instr|event|decoder|soc|all>` that compiles with the matching `.f` file list, runs, writes logs under `build/`, and returns a non-zero exit code when any `[FAIL]` appears. Do not hardcode license servers or absolute paths; use environment variables.

## 11. QUALITY RULES

- One module per file. File name equals module name.
- Parameterise widths; no magic numbers; every address and bit in a `.vh` defines file.
- No latches, no combinational loops, no unintended X propagation after reset. Use non-blocking assignments in clocked blocks and blocking in combinational blocks.
- Every register and port commented. Header comment in each file with description and register map.
- Do not copy third-party IP into the repository without keeping its licence header.
- Never fabricate simulation output or claim a test passed without running it. If you cannot run something, say exactly which step you could not run.

## 12. WORKFLOW

1. Read the core and write `core_interface.md`; stop and ask me if the retirement signal or the bus protocol cannot be determined.
2. Write `reg_slave_if.v`, the three IPs and their unit testbenches; get them passing.
3. Write the decoder, memories and top; run the decoder testbench.
4. Write the firmware and SoC testbench; get `perf_app` printing results and `PASS`.
5. Run the full regression with `run_ip.sh all` and fix every failure.
6. Write the README and docs.

## 13. FINAL REPORT (required)

Return:
1. the file tree;
2. the final memory map and register maps (note every difference from this prompt);
3. the exact core signals used for instruction retirement and for each of the 8 events;
4. the regression summary (test name, PASS/FAIL, cycles) from your real run, plus the UART output of `perf_app`;
5. known limitations and anything left unverified.

Acceptance criteria: all unit and SoC tests pass in one clean run; the UART prints non-zero cycle, instruction and event counts with cycles >= instructions; the report in section 13 is complete.
