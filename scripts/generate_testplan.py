#!/usr/bin/env python3
"""
generate_testplan.py
Generates the authoritative, fully corrected testplan_soc_hpm.xlsx for the
Hardware Performance Monitoring RISC-V SoC project.
Aligns with the reference format in testmap_soc.xlsx while preserving all 4 sheets:
  1. testplan_soc
  2. Summary
  3. Event Select Matrix
  4. Notes & Assumptions
"""

import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

def build_testplan():
    wb = openpyxl.Workbook()

    # Define color scheme and fonts
    font_family = "Arial"
    header_fill = PatternFill(start_color="1F497D", end_color="1F497D", fill_type="solid") # Dark Navy
    header_font = Font(name=font_family, size=10, bold=True, color="FFFFFF")
    
    section_fill = PatternFill(start_color="DCE6F1", end_color="DCE6F1", fill_type="solid") # Soft Ice Blue
    section_font = Font(name=font_family, size=10, bold=True, color="1F497D")

    total_fill = PatternFill(start_color="D9E1F2", end_color="D9E1F2", fill_type="solid")
    total_font = Font(name=font_family, size=10, bold=True, color="000000")

    regular_font = Font(name=font_family, size=9, bold=False, color="000000")
    bold_font = Font(name=font_family, size=9, bold=True, color="000000")
    title_font = Font(name=font_family, size=13, bold=True, color="1F497D")
    sub_font = Font(name=font_family, size=9, italic=True, color="595959")

    thin_border_side = Side(border_style="thin", color="D9D9D9")
    cell_border = Border(left=thin_border_side, right=thin_border_side, top=thin_border_side, bottom=thin_border_side)
    thick_bottom = Border(bottom=Side(border_style="medium", color="1F497D"))
    double_bottom = Border(top=thin_border_side, bottom=Side(border_style="double", color="1F497D"))

    align_center = Alignment(horizontal="center", vertical="center", wrap_text=True)
    align_left = Alignment(horizontal="left", vertical="center", wrap_text=True)
    align_left_nowrap = Alignment(horizontal="left", vertical="center", wrap_text=False)

    # -------------------------------------------------------------
    # SHEET 1: testplan_soc
    # -------------------------------------------------------------
    ws1 = wb.active
    ws1.title = "testplan_soc"
    ws1.views.sheetView[0].showGridLines = True

    headers1 = [
        "S.No",
        "Test Name",
        "Description",
        "C Portion (firmware/test/)",
        "SV Portion (tb/)",
        "Block",
        "Priority",
        "Status"
    ]
    ws1.append(headers1)
    for col_idx in range(1, len(headers1) + 1):
        cell = ws1.cell(1, col_idx)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = align_center
        cell.border = cell_border
    ws1.row_dimensions[1].height = 28

    # Test definitions: (sno, name, desc, c_portion, sv_portion, block, priority, status)
    tests = [
        # =========================================================
        # 1. boot & system (6 tests)
        # =========================================================
        (
            1,
            "BOOT_RESET_VECTOR",
            "Core issues its first instruction fetch from IMEM base 0x0000_0000 after reset release; confirms reset vector wiring (rst_vec = 32'h0000_0000).",
            "Not applicable (first code executed at 0x0000_0000)",
            "tb_soc_top.v — TC_SOC_01: monitor first accepted fetch address after rstn deassertion equals 32'h0000_0000",
            "boot & system", "P1", "Not Run"
        ),
        (
            2,
            "BOOT_IMEM_LOAD",
            "Firmware binary hex is loaded into IMEM via $readmemh before reset release; first 4 words in IMEM match program image header.",
            "Not applicable (firmware image loaded into memory)",
            "tb_soc_top.v — runtime $readmemh into u_imem.mem; hierarchical check compares first 4 words against hex file",
            "boot & system", "P1", "Not Run"
        ),
        (
            3,
            "BOOT_REG_RESET_VALUES",
            "Every HPM counter and peripheral register reads its documented architectural reset value after cold reset release (CTRL=0x0, STATUS=0x0, DIVISOR=434, LCR=0x03, LSR=0x60).",
            "test_boot.c / perf_app.c — Subtest 1: read all CSRs at boot; verify reset values over UART",
            "tb_soc_top.v / bus_bfm.v — bus_bfm read-and-compare against doc/register_map.md specified reset values",
            "boot & system", "P1", "Not Run"
        ),
        (
            4,
            "BOOT_NO_X_AFTER_RESET",
            "No X or Z logic states on system bus signals (m_addr, m_wdata, m_rdata), interrupt lines (irq_o, timer_tick), or uart_tx output after reset release.",
            "Not applicable",
            "tb_soc_top.v — $isunknown assertion monitors across all top-level output and bus signals for 100 cycles post-reset",
            "boot & system", "P2", "Not Run"
        ),
        (
            5,
            "BOOT_STACK_INIT",
            "C runtime startup code (crt0.S) sets SP to top of DMEM (0x0000_1FFC); first push and pop return correct data without bus error.",
            "crt0.S — la sp, _stack_top; verify first stack push and pop in DMEM address range",
            "tb_soc_top.v — monitor first DMEM write address falls inside 0x0000_1000 - 0x0000_1FFC",
            "boot & system", "P3", "Not Run"
        ),
        (
            6,
            "BOOT_UART_START_TOKEN",
            "Firmware prints boot start token '[BOOT] START' at 115200 baud; uart_monitor decodes frames, verifying core, IMEM, bus interconnect, and UART transmit path.",
            "perf_app.c / crt0.S — uart_puts(\"\\n[BOOT] START\\n\")",
            "uart_monitor.v — passive 8N1 serial monitor flags start token within timeout window",
            "boot & system", "P1", "Not Run"
        ),

        # =========================================================
        # 2. bus decoder / interconnect (17 tests)
        # =========================================================
        (
            7,
            "DEC_MAP_IMEM",
            "Bus access to range 0x0000_0000 - 0x0000_0FFF asserts sel_imem_o only; selects 4KB instruction memory window.",
            "perf_app.c — instruction fetch / load from IMEM window",
            "tb_bus_decoder.v — TC_DEC_01: address sweep across 0x0000_0000 - 0x0000_0FFF; verify only sel_imem_o asserts",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            8,
            "DEC_MAP_DMEM",
            "Bus access to range 0x0000_1000 - 0x0000_1FFF asserts sel_dmem_o only; selects 4KB data memory window.",
            "perf_app.c — load/store within stack/data memory window",
            "tb_bus_decoder.v — TC_DEC_02: address sweep across 0x0000_1000 - 0x0000_1FFF; verify only sel_dmem_o asserts",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            9,
            "DEC_MAP_UART",
            "Bus access to range 0x0000_2000 - 0x0000_20FF asserts sel_uart_o only; offset addr[7:0] routed to UART registers.",
            "perf_app.c — write to UART_BASE + 0x00 (THR)",
            "tb_bus_decoder.v — TC_DEC_03: verify sel_uart_o=1 and slave_offset == addr[7:0]",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            10,
            "DEC_MAP_TIMER",
            "Bus access to range 0x0000_2100 - 0x0000_21FF asserts sel_timer_o only; offset addr[7:0] routed to Timer registers.",
            "perf_app.c — write to TIMER_BASE + 0x00 (CTRL)",
            "tb_bus_decoder.v — TC_DEC_04: verify sel_timer_o=1 and slave_offset == addr[7:0]",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            11,
            "DEC_MAP_GPIO",
            "Bus access to range 0x0000_2200 - 0x0000_22FF asserts sel_gpio_o only; offset addr[7:0] routed to GPIO registers.",
            "perf_app.c — write to GPIO_BASE + 0x04 (OUT)",
            "tb_bus_decoder.v — TC_DEC_05: verify sel_gpio_o=1 and slave_offset == addr[7:0]",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            12,
            "DEC_MAP_CYCLE_CNT",
            "Bus access to range 0x0000_2300 - 0x0000_23FF asserts sel_cycle_cnt_o only; offset addr[7:0] routed to Cycle Counter.",
            "test_cycle.c — write to CYC_BASE + 0x00 (CTRL)",
            "tb_bus_decoder.v — TC_DEC_06: verify sel_cycle_cnt_o=1 and slave_offset == addr[7:0]",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            13,
            "DEC_MAP_INSTR_CNT",
            "Bus access to range 0x0000_2400 - 0x0000_24FF asserts sel_instr_cnt_o only; offset addr[7:0] routed to Instruction Counter.",
            "test_instr.c — write to INSTR_BASE + 0x00 (CTRL)",
            "tb_bus_decoder.v — TC_DEC_07: verify sel_instr_cnt_o=1 and slave_offset == addr[7:0]",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            14,
            "DEC_MAP_EVENT_CNT",
            "Bus access to range 0x0000_2500 - 0x0000_25FF asserts sel_event_cnt_o only; offset addr[7:0] routed to Event Counter.",
            "test_event.c — write to EVT_BASE + 0x00 (CTRL)",
            "tb_bus_decoder.v — TC_DEC_08: verify sel_event_cnt_o=1 and slave_offset == addr[7:0]",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            15,
            "DEC_REGION_BOUNDARIES",
            "Boundary address verification at exact transition edges (0x0FFF->IMEM, 0x1000->DMEM, 0x1FFF->DMEM, 0x2000->UART, 0x20FF->UART, 0x2100->Timer, 0x25FF->Event Cnt, 0x2600->Unmapped).",
            "perf_app.c — read/write probe on each boundary address",
            "tb_bus_decoder.v — probe edge addresses; confirm exact target selection and zero edge crosstalk",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            16,
            "DEC_ONE_HOT_SELECT",
            "Interconnect asserts at most one slave select line for any valid address; zero select lines asserted for unmapped addresses.",
            "Implicit in all peripheral accesses",
            "tb_bus_decoder.v — assertion $onehot0({sel_event_cnt_o, sel_instr_cnt_o, sel_cycle_cnt_o, sel_gpio_o, sel_timer_o, sel_uart_o, sel_dmem_o, sel_imem_o}) across 1000 random bus addresses",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            17,
            "DEC_UNMAPPED_READ",
            "Bus read to unmapped address (0x0000_2600, 0x0000_3000, 0xDEAD_0000, 0xFFFF_FFFC) completes in 1 cycle with m_ready_o=1, m_rdata_o=32'h0000_0000, and m_err_o=1.",
            "perf_app.c — load from 0x0000_2600 (verify CPU handles/survives error response)",
            "tb_bus_decoder.v — read unmapped space; verify single-cycle m_ready_o=1, m_err_o=1, m_rdata_o=32'h0",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            18,
            "DEC_UNMAPPED_WRITE",
            "Bus write to unmapped address completes in 1 cycle with m_ready_o=1 and m_err_o=1; does not corrupt any internal peripheral register.",
            "perf_app.c — store to 0x0000_3000",
            "tb_bus_decoder.v — write unmapped space; verify m_err_o=1 and no slave write strobes assert",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            19,
            "DEC_RDATA_MUX",
            "Central read data multiplexer routes active slave's rdata to master bus and masks all non-selected slave data buses to 0.",
            "perf_app.c — read distinct signature values from each peripheral in succession",
            "tb_bus_decoder.v — drive distinct patterns on each s*_rdata_i; verify m_rdata_o equals selected slave data",
            "bus decoder / interconnect", "P1", "Not Run"
        ),
        (
            20,
            "DEC_INTRA_WINDOW_HOLE",
            "Address within peripheral 256B page beyond implemented CSRs (0x2310-0x23FF, 0x2410-0x24FF, 0x2514-0x25FF) routes to IP; slave returns ready=1 and rdata=0 without hanging.",
            "perf_app.c — read offset 0x0000_2310",
            "tb_cycle_cnt.v / tb_bus_decoder.v — access unimplemented register offset; verify clean response ready=1, rdata=0, err=0",
            "bus decoder / interconnect", "P2", "Not Run"
        ),
        (
            21,
            "DEC_BYTE_STROBE_PASSTHRU",
            "Master byte write strobes m_wstrb_i[3:0] pass through to selected slave unchanged for byte, halfword, and word store operations.",
            "perf_app.c — byte stores (sb) to DMEM and peripheral registers",
            "tb_bus_decoder.v — sweep wstrb patterns 4'b0001 through 4'b1111; verify s_wstrb_o exactly mirrors m_wstrb_i",
            "bus decoder / interconnect", "P2", "Not Run"
        ),
        (
            22,
            "DEC_BACK_TO_BACK_SLAVES",
            "Consecutive bus accesses to different slaves with no idle cycle; decoder switches selects cleanly without collision or dropped cycles.",
            "Write UART THR then read Cycle Counter in consecutive instructions",
            "tb_bus_decoder.v — pipeline back-to-back requests across all 8 slaves; verify zero handshake stalls",
            "bus decoder / interconnect", "P2", "Not Run"
        ),
        (
            23,
            "DEC_NO_DEADLOCK",
            "Every slave access completes with ready=1 within bounded cycles; bus decoder never causes system bus deadlock or infinite wait states.",
            "Sustained loop reading and writing all peripherals",
            "tb_bus_decoder.v — watchdog timeout assertion confirms m_ready_o asserts within 16 clocks for all accesses",
            "bus decoder / interconnect", "P2", "Not Run"
        ),

        # =========================================================
        # 3. reg_slave_if (bus-to-register adapter) (5 tests)
        # =========================================================
        (
            24,
            "RSI_WRITE_PULSE",
            "Single-cycle bus write transaction generates exactly one-cycle active-high reg_we_o pulse with stable reg_wdata_o and reg_wstrb_o.",
            "Any peripheral register write",
            "tb_cycle_cnt.v (via reg_slave_if) — verify reg_we_o is asserted for exactly 1 clock cycle during write",
            "reg_slave_if (bus-to-register adapter)", "P1", "Not Run"
        ),
        (
            25,
            "RSI_READ_DATA_TIMING",
            "Read data reg_rdata_i from IP registers is captured and driven onto bus_rdata_o synchronously with bus_ready_o assertion.",
            "Any peripheral register read",
            "tb_cycle_cnt.v — verify bus_rdata_o holds valid data during the exact cycle bus_ready_o is high",
            "reg_slave_if (bus-to-register adapter)", "P1", "Not Run"
        ),
        (
            26,
            "RSI_WRITE_THEN_READ",
            "Back-to-back write followed by read of the same register offset returns the newly written value without stale pipeline data.",
            "test_event.c — write EVT_SEL=3, immediately read back EVT_SEL, assert readback == 3",
            "tb_event_cnt.v — back-to-back bus_write and bus_read via bus_bfm.v; verify data coherence",
            "reg_slave_if (bus-to-register adapter)", "P1", "Not Run"
        ),
        (
            27,
            "RSI_BYTE_LANES",
            "Partial byte strobes (4'b0001, 4'b0010, 4'b0100, 4'b1000) pass to reg_wstrb_o to permit byte-level register updates.",
            "sb instructions to peripheral control registers",
            "tb_common/bus_bfm.v — issue 8-bit and 16-bit writes; verify reg_wstrb_o lane masking in adapter",
            "reg_slave_if (bus-to-register adapter)", "P2", "Not Run"
        ),
        (
            28,
            "RSI_READ_NO_WRITE_SIDE_EFFECT",
            "Register read access generates reg_re_o pulse but keeps reg_we_o=0; never modifies writable register state.",
            "Repeated reads of CTRL and THRESH registers",
            "tb_cycle_cnt.v — monitor reg_we_o remains strictly 0 throughout all bus read cycles",
            "reg_slave_if (bus-to-register adapter)", "P2", "Not Run"
        ),

        # =========================================================
        # 4. cycle counter (13 tests)
        # =========================================================
        (
            29,
            "CYC_RESET_STATE",
            "After reset deassertion, CTRL=0x0000_0000, STATUS=0x0000_0000 (RUNNING=0), CNT_LO=0x0000_0000, and CNT_HI=0x0000_0000.",
            "test_cycle.c — read all 4 cycle counter registers at cold boot; assert all zero",
            "tb_cycle_cnt.v — TC_CYC_01: verify CTRL, STATUS, CNT_LO, CNT_HI reset values via bus_read",
            "cycle counter", "P1", "Not Run"
        ),
        (
            30,
            "CYC_ENABLE_COUNTS",
            "Writing CTRL.EN=1 (bit 0) sets STATUS.RUNNING=1; 64-bit cycle count increments by exactly 1 on every clock cycle.",
            "test_cycle.c — write CTRL.EN=1; execute 100 nops; read CNT_LO; verify count delta >= 100",
            "tb_cycle_cnt.v — TC_CYC_03: enable counter; run 100 clock cycles; verify count delta == 100",
            "cycle counter", "P1", "Not Run"
        ),
        (
            31,
            "CYC_DISABLE_HOLDS",
            "Clearing CTRL.EN=0 clears STATUS.RUNNING=0; counter freezes at current value; re-enabling resumes counting from frozen value.",
            "test_cycle.c — disable counter; read CNT_LO twice with delay; assert values identical; re-enable",
            "tb_cycle_cnt.v — TC_CYC_04: disable counter; advance 50 clocks; verify count remains frozen",
            "cycle counter", "P1", "Not Run"
        ),
        (
            32,
            "CYC_CLEAR",
            "Writing CTRL.CLEAR=1 (bit 1) clears all 64 bits of counter to 0 in 1 cycle; CLEAR bit is self-clearing (reads 0); CLEAR has priority over counting.",
            "test_cycle.c — write CTRL = (1<<1) | (1<<0); read CNT_LO immediately; assert count reset to low count",
            "tb_cycle_cnt.v — TC_CYC_05: assert CLEAR while enabled; verify count resets to 0 and CTRL[1] reads 0",
            "cycle counter", "P2", "Not Run"
        ),
        (
            33,
            "CYC_LO_HI_ACCESS",
            "64-bit counter is accessible as two independent 32-bit registers: CNT_LO at offset 0x08 and CNT_HI at offset 0x0C.",
            "test_cycle.c — read both CNT_LO and CNT_HI register offsets",
            "tb_cycle_cnt.v — verify bus read decoding for offsets 0x08 and 0x0C",
            "cycle counter", "P1", "Not Run"
        ),
        (
            34,
            "CYC_SHADOW_COHERENT",
            "Reading CNT_LO (offset 0x08) atomically latches upper 32 bits into CNT_HI shadow register; reading CNT_HI returns coherent snapshot even if lower 32 bits roll over.",
            "test_cycle.c — read CNT_LO then CNT_HI; verify 64-bit atomic consistency",
            "tb_cycle_cnt.v — TC_CYC_06: preload count to 0x0000_0000_FFFF_FFFF; read CNT_LO then CNT_HI; verify CNT_HI returns captured shadow 32'h0000_0000",
            "cycle counter", "P1", "Not Run"
        ),
        (
            35,
            "CYC_CARRY_32_TO_64",
            "Preload count to 0x0000_0000_FFFF_FFFE; advance clocks; verify carry propagation from count[31:0] to count[63:32] produces 0x0000_0001_0000_0000.",
            "Not practical in firmware (requires 2^32 cycles)",
            "tb_cycle_cnt.v — TC_CYC_07: preload via testbench hierarchy; step clock; verify carry into bit 32",
            "cycle counter", "P1", "Not Run"
        ),
        (
            36,
            "CYC_64BIT_WRAP",
            "Preload count to 0xFFFF_FFFF_FFFF_FFFF; advance clock; verify counter wraps cleanly to 0x0000_0000_0000_0000 with no lockup or stuck bits.",
            "Not practical in firmware",
            "tb_cycle_cnt.v — TC_CYC_08: preload 64-bit max value; step clock; verify clean wrap to zero",
            "cycle counter", "P3", "Not Run"
        ),
        (
            37,
            "CYC_WRITE_READONLY",
            "CNT_LO and CNT_HI registers are strictly Read-Only; bus writes to offsets 0x08 and 0x0C are ignored by hardware; counter value is not altered and bus returns OK.",
            "test_cycle.c — write 0xDEADBEEF to CNT_LO; read back; assert count not modified by write",
            "tb_cycle_cnt.v — TC_CYC_09: issue bus_write to 0x08 and 0x0C; verify count register values unaltered",
            "cycle counter", "P2", "Not Run"
        ),
        (
            38,
            "CYC_ENABLE_SINGLE_CYCLE",
            "Writing CTRL.EN=1 for exactly 1 clock cycle increments 64-bit counter by exactly 1 and holds.",
            "Shortest enable/disable instruction sequence",
            "tb_cycle_cnt.v — bus write EN=1 immediately followed by EN=0; verify count delta equals exactly 1",
            "cycle counter", "P2", "Not Run"
        ),
        (
            39,
            "CYC_RESET_MIDRUN",
            "Assert active-low reset while counter is actively incrementing; counter and control registers immediately reset to 0.",
            "System soft reset / reboot",
            "tb_cycle_cnt.v — pulse rstn low during active counting; verify immediate zero state",
            "cycle counter", "P2", "Not Run"
        ),
        (
            40,
            "CYC_BUS_TRAFFIC_NO_IMPACT",
            "Sustained bus traffic to other peripherals (Timer, UART, GPIO) does not affect cycle counter increment rate or cause dropped counts.",
            "perf_app.c — run heavy peripheral I/O while measuring elapsed cycles",
            "tb_soc_top.v — interleaved peripheral bus traffic; testbench shadow cycle counter strictly matches DUT counter",
            "cycle counter", "P2", "Not Run"
        ),
        (
            41,
            "CYC_COUNTS_DURING_STALL",
            "Cycle counter increments every processor clock cycle, including pipeline stalls, load-use interlocks, and memory wait cycles.",
            "perf_app.c — execute memory stall sequence; verify cycle count includes all stall cycles",
            "tb_soc_top.v — insert bus wait states (hready=0); verify cycle counter increments on each stalled clock",
            "cycle counter", "P1", "Not Run"
        ),

        # =========================================================
        # 5. instruction counter (12 tests)
        # =========================================================
        (
            42,
            "INSTR_RESET_STATE",
            "After reset deassertion, CTRL=0x0000_0000, STATUS=0x0000_0000 (RUNNING=0), CNT_LO=0x0000_0000, and CNT_HI=0x0000_0000.",
            "test_instr.c — read all 4 instruction counter registers at startup; assert all zero",
            "tb_instr_cnt.v — TC_INS_01: verify CTRL, STATUS, CNT_LO, CNT_HI reset values via bus_bfm.v",
            "instruction counter", "P1", "Not Run"
        ),
        (
            43,
            "INSTR_COUNT_RETIRED",
            "With CTRL.EN=1, counter increments by exactly 1 for every instr_retire_i pulse; straight-line retired instructions match count delta.",
            "test_instr.c — execute 50 NOP instructions between start and stop; verify count delta matches expected retired count",
            "tb_instr_cnt.v — TC_INS_03: pulse instr_retire_i 100 times; verify CNT_LO increments by exactly 100",
            "instruction counter", "P1", "Not Run"
        ),
        (
            44,
            "INSTR_NO_COUNT_ON_STALL",
            "Pipeline stalls, wait states, and bubble cycles (instr_retire_i=0) do not increment instruction counter even though clock runs.",
            "test_instr.c — run load-use stall sequence; verify instruction counter increments only for committed instructions",
            "tb_instr_cnt.v — TC_INS_04: run 50 clock cycles with instr_retire_i=0; verify count delta == 0",
            "instruction counter", "P1", "Not Run"
        ),
        (
            45,
            "INSTR_FLUSHED_NOT_COUNTED",
            "Instructions fetched but flushed by a taken branch, jump, or exception do not assert instr_retire_i and are never counted.",
            "test_instr.c — execute loop with branch mispredictions; verify count reflects architecturally committed instructions",
            "tb_soc_top.v — monitor VeeR trace_rv_i_valid_ip & ~trace_rv_i_exception_ip; verify flushed instructions do not pulse retire",
            "instruction counter", "P1", "Not Run"
        ),
        (
            46,
            "INSTR_ONE_PER_CYCLE_MAX",
            "Instruction counter increments at most by 1 per clock cycle (single-issue commit pipe); never double-increments.",
            "Consecutive single-cycle ALU instructions",
            "tb_instr_cnt.v — assertion confirms CNT_LO increment is <= 1 on every clock cycle",
            "instruction counter", "P2", "Not Run"
        ),
        (
            47,
            "INSTR_ENABLE_DISABLE",
            "Counter increments only while CTRL.EN=1; clearing EN=0 freezes count; pulses on instr_retire_i while disabled are ignored.",
            "test_instr.c — disable instruction counter; execute code; re-enable; assert count frozen during disabled window",
            "tb_instr_cnt.v — TC_INS_05: pulse instr_retire_i while EN=0; verify count remains unchanged",
            "instruction counter", "P1", "Not Run"
        ),
        (
            48,
            "INSTR_CLEAR",
            "Writing CTRL.CLEAR=1 (bit 1) clears 64-bit instruction counter to 0 in 1 cycle; CLEAR self-clears to 0; CLEAR has priority over simultaneous retire.",
            "test_instr.c — write CTRL = (1<<1) | (1<<0); verify count resets to 0 and resumes",
            "tb_instr_cnt.v — TC_INS_06: assert CLEAR and instr_retire_i simultaneously; verify count clears to 0",
            "instruction counter", "P2", "Not Run"
        ),
        (
            49,
            "INSTR_SHADOW_COHERENT",
            "Reading CNT_LO atomically latches upper 32 bits into CNT_HI shadow register; atomic 64-bit coherent read guaranteed across rollover.",
            "test_instr.c — read CNT_LO then CNT_HI; test 64-bit value coherence",
            "tb_instr_cnt.v — TC_INS_07: preload count to 0x0000_0000_FFFF_FFFF; read CNT_LO then CNT_HI while retiring; verify CNT_HI returns 0x0",
            "instruction counter", "P1", "Not Run"
        ),
        (
            50,
            "INSTR_CARRY_32_TO_64",
            "Preload count to 0x0000_0000_FFFF_FFFE; pulse instr_retire_i; verify carry propagation increments CNT_HI to 0x0000_0001.",
            "Not practical in firmware",
            "tb_instr_cnt.v — TC_INS_08: preload via TB; step retirement pulse; verify CNT_HI=1, CNT_LO=0",
            "instruction counter", "P1", "Not Run"
        ),
        (
            51,
            "INSTR_TRAP_COUNTING",
            "Trapped instructions (ECALL, illegal opcode) do not retire and do not increment instruction counter; MRET retirement increments counter.",
            "test_instr.c — execute ECALL trap and return; verify exact retired instruction count before/after",
            "tb_soc_top.v — monitor instr_retire_o during exception cycle (trace_rv_i_exception_ip=1); verify pulse is suppressed",
            "instruction counter", "P3", "Not Run"
        ),
        (
            52,
            "INSTR_WRITE_READONLY",
            "CNT_LO and CNT_HI are strictly Read-Only; bus writes to offsets 0x08 and 0x0C are ignored; register data remains unaffected.",
            "test_instr.c — write 0xA5A5A5A5 to CNT_LO; verify count not altered",
            "tb_instr_cnt.v — TC_INS_09: bus_write to 0x08 and 0x0C; verify count registers unchanged",
            "instruction counter", "P2", "Not Run"
        ),
        (
            53,
            "INSTR_RESET_MIDRUN",
            "Assert active-low reset while instructions are actively retiring; instruction counter clears to 0 and disables immediately.",
            "System reset recovery",
            "tb_instr_cnt.v — assert rstn low while pulsing instr_retire_i; verify immediate zero state",
            "instruction counter", "P2", "Not Run"
        ),

        # =========================================================
        # 6. performance event counter (28 tests)
        # =========================================================
        (
            54,
            "EVT_RESET_STATE",
            "After reset deassertion, CTRL=0x00, EVT_SEL=0x00, COUNT=0x0000_0000, THRESH=0x0000_0000, STATUS=0x00 (OVF=0, THRESH_HIT=0, RUNNING=0), and irq_o=0.",
            "test_event.c — read all Event Counter registers at startup; assert all 0",
            "tb_event_cnt.v — TC_EVT_01: verify reset defaults across all registers and irq_o",
            "performance event counter", "P1", "Not Run"
        ),
        (
            55,
            "EVT_SEL_RW",
            "EVT_SEL register (offset 0x04) accepts 3-bit event index (0-7) and reads back correctly; upper bits [31:3] read as 0.",
            "test_event.c — write values 0 through 7 to EVT_SEL; verify readback for each value",
            "tb_event_cnt.v — TC_EVT_02: sweep EVT_SEL values 0 to 7; write 0xFF and verify mask to 0x07",
            "performance event counter", "P1", "Not Run"
        ),
        (
            56,
            "EVT_SEL0_LOAD",
            "With EVT_SEL=0, counter increments only on data memory read accepted (evt_load_o); ignores all other 7 events.",
            "test_event.c — perform 50 loads from DMEM; read COUNT; verify delta == 50",
            "tb_event_cnt.v — TC_EVT_03: pulse events_i[0]; verify count increments; pulse other events; verify count holds",
            "performance event counter", "P1", "Not Run"
        ),
        (
            57,
            "EVT_SEL1_STORE",
            "With EVT_SEL=1, counter increments only on data memory write accepted (evt_store_o); ignores other events.",
            "test_event.c — perform 30 stores to DMEM; verify COUNT delta == 30",
            "tb_event_cnt.v — TC_EVT_04: pulse events_i[1]; verify count increments by 30",
            "performance event counter", "P1", "Not Run"
        ),
        (
            58,
            "EVT_SEL2_FETCH",
            "With EVT_SEL=2, counter increments only on instruction fetch request accepted (evt_fetch_o).",
            "test_event.c — straight-line instruction execution block; verify COUNT matches accepted fetch transactions",
            "tb_event_cnt.v — TC_EVT_05: pulse events_i[2]; verify count increments",
            "performance event counter", "P1", "Not Run"
        ),
        (
            59,
            "EVT_SEL3_BRANCH_JUMP",
            "With EVT_SEL=3, counter increments only on taken branch or jump (evt_branch_jump_o).",
            "test_event.c — loop with exactly 100 taken branches; verify COUNT delta == 100",
            "tb_event_cnt.v — TC_EVT_06: pulse events_i[3]; verify count increments by 100",
            "performance event counter", "P1", "Not Run"
        ),
        (
            60,
            "EVT_SEL4_STALL",
            "With EVT_SEL=4, counter increments only on pipeline stall or memory wait cycle (evt_stall_bubble_o).",
            "test_event.c — execute back-to-back load-use instructions causing pipeline stalls; verify stall count",
            "tb_event_cnt.v — TC_EVT_07: pulse events_i[4]; verify count increments",
            "performance event counter", "P1", "Not Run"
        ),
        (
            61,
            "EVT_SEL5_EXCEPTION",
            "With EVT_SEL=5, counter increments only on exception or trap taken (evt_exception_o).",
            "test_event.c — execute ECALL exception 8 times; verify COUNT == 8",
            "tb_event_cnt.v — TC_EVT_08: pulse events_i[5] 8 times; verify COUNT == 8",
            "performance event counter", "P1", "Not Run"
        ),
        (
            62,
            "EVT_SEL6_TIMER_TICK",
            "With EVT_SEL=6, counter increments only on hardware timer interrupt tick (timer_tick).",
            "test_event.c — program Timer for 5 expiries; verify COUNT == 5",
            "tb_event_cnt.v — TC_EVT_09: pulse events_i[6] 5 times; verify COUNT == 5",
            "performance event counter", "P1", "Not Run"
        ),
        (
            63,
            "EVT_SEL7_UART_TX_DONE",
            "With EVT_SEL=7, counter increments only on UART frame transmit complete (uart_tx_done).",
            "test_event.c — transmit 26 bytes (A-Z) over UART; verify COUNT == 26",
            "tb_event_cnt.v — TC_EVT_10: pulse events_i[7] 26 times; verify COUNT == 26",
            "performance event counter", "P1", "Not Run"
        ),
        (
            64,
            "EVT_SELECT_ISOLATION",
            "With one event selected, active pulses on all other 7 unselected event lines never change the count (strict multiplexer isolation).",
            "test_event.c — select Event 0; perform heavy branches and UART transfers; verify COUNT only tracks loads",
            "tb_event_cnt.v — select each event in turn; drive pulses on other 7 inputs; verify count remains strictly 0",
            "performance event counter", "P1", "Not Run"
        ),
        (
            65,
            "EVT_SEL_SWITCH_MIDRUN",
            "Switching EVT_SEL mid-run changes event source smoothly without losing counts or generating spurious counts on the transition cycle.",
            "test_event.c — switch EVT_SEL from 0 to 1 mid-test; verify each phase counts accurately",
            "tb_event_cnt.v — dynamically change EVT_SEL while driving active event inputs; verify seamless switch",
            "performance event counter", "P2", "Not Run"
        ),
        (
            66,
            "EVT_ENABLE_GATING",
            "Clearing CTRL.EN=0 stops counting immediately; setting CTRL.EN=1 enables counting; event pulses while disabled are discarded.",
            "test_event.c — disable counter; perform loads; assert COUNT does not advance; re-enable",
            "tb_event_cnt.v — pulse selected event with EN=0; verify count holds",
            "performance event counter", "P1", "Not Run"
        ),
        (
            67,
            "EVT_CONSECUTIVE_PULSES",
            "Selected event pulsed on back-to-back clock cycles; counter increments by 1 on every consecutive clock without missing pulses.",
            "Straight-line assembly load sequence (consecutive lw instructions)",
            "tb_event_cnt.v — drive selected event high for 10 consecutive clock cycles; verify COUNT increments by 10",
            "performance event counter", "P1", "Not Run"
        ),
        (
            68,
            "EVT_SIMULTANEOUS_EVENTS",
            "Multiple event lines high in the same clock cycle; counter increments by exactly 1 for the selected event and ignores unselected events.",
            "Simultaneous memory load and taken branch in program execution",
            "tb_event_cnt.v — drive events_i = 8'hFF; verify COUNT increments by exactly 1",
            "performance event counter", "P2", "Not Run"
        ),
        (
            69,
            "EVT_CLEAR",
            "Writing CTRL.CLEAR=1 (bit 1) zeroes COUNT, STATUS.OVF, and STATUS.THRESH_HIT in 1 cycle; CLEAR self-clears to 0; CLEAR has priority over counting.",
            "test_event.c — write CTRL.CLEAR=1; read COUNT and STATUS; verify all reset to 0",
            "tb_event_cnt.v — assert CLEAR while event pulses; verify counter resets to 0 and CLEAR self-clears",
            "performance event counter", "P2", "Not Run"
        ),
        (
            70,
            "EVT_COUNT_PRELOAD",
            "COUNT register at offset 0x08 is strictly Read-Only; writes to COUNT are ignored by hardware; counter value is unmodified and bus returns OK.",
            "test_event.c — write 0x12345678 to COUNT; read back and verify value is unchanged",
            "tb_event_cnt.v — issue bus_write to COUNT; verify hardware register is not modified",
            "performance event counter", "P1", "Not Run"
        ),
        (
            71,
            "EVT_OVERFLOW_STICKY",
            "Counter incrementing past 0xFFFF_FFFF wraps to 0 and sets sticky STATUS.OVF (bit 0); OVF remains 1 on subsequent events until cleared.",
            "Not practical in real-time firmware (requires 2^32 events)",
            "tb_event_cnt.v — TC_EVT_11: preload COUNT to 0xFFFF_FFFF via TB hierarchy; pulse event; verify COUNT=0 and STATUS.OVF=1",
            "performance event counter", "P1", "Not Run"
        ),
        (
            72,
            "EVT_OVERFLOW_CLEAR",
            "STATUS.OVF clears by writing 1 to STATUS[0] (W1C) or by writing CTRL.CLEAR=1; writing 0 to STATUS[0] leaves OVF unchanged.",
            "test_event.c — test W1C clear protocol on STATUS register",
            "tb_event_cnt.v — write STATUS=0x00 (verify OVF stays 1); write STATUS=0x01 (verify OVF clears to 0)",
            "performance event counter", "P1", "Not Run"
        ),
        (
            73,
            "EVT_THRESHOLD_RW",
            "THRESH register (offset 0x0C) accepts full 32-bit values (0x0000_0000 to 0xFFFF_FFFF) and reads back faithfully.",
            "test_event.c — write and readback test patterns in THRESH register",
            "tb_event_cnt.v — TC_EVT_12: write patterns (0x0, 0x1, 0xDEADBEEF, 0xFFFFFFFF) to THRESH; verify readback",
            "performance event counter", "P1", "Not Run"
        ),
        (
            74,
            "EVT_THRESHOLD_MATCH",
            "When THRESH != 0, counter reaching COUNT >= THRESH asserts sticky STATUS.THRESH_HIT (bit 1); remains asserted until cleared.",
            "test_event.c — set THRESH=20; execute 25 events; poll STATUS.THRESH_HIT; verify it asserts at count 20",
            "tb_event_cnt.v — TC_EVT_13: set THRESH=10; pulse 10 events; verify STATUS[1] asserts",
            "performance event counter", "P1", "Not Run"
        ),
        (
            75,
            "EVT_THRESHOLD_BOUNDARY",
            "When THRESH=0, threshold comparison is disabled (STATUS.THRESH_HIT never asserts); THRESH=1 matches on first event; THRESH=0xFFFFFFFF matches on max count.",
            "test_event.c — set THRESH=0; run events; verify THRESH_HIT remains 0",
            "tb_event_cnt.v — verify THRESH=0 never asserts hit flag across multiple event counts",
            "performance event counter", "P2", "Not Run"
        ),
        (
            76,
            "EVT_IRQ_ENABLE_MASK",
            "irq_o output asserts only when CTRL.IRQ_EN=1 (bit 2) AND either THRESH_HIT or OVF is asserted; when IRQ_EN=0, irq_o remains strictly 0.",
            "test_event.c — trigger threshold hit with IRQ_EN=0 (no interrupt); then set IRQ_EN=1 and verify interrupt asserts",
            "tb_event_cnt.v — check irq_o == (CTRL[2] & (STATUS[0] | STATUS[1]))",
            "performance event counter", "P1", "Not Run"
        ),
        (
            77,
            "EVT_IRQ_ON_THRESHOLD",
            "With IRQ_EN=1, counter reaching COUNT >= THRESH immediately asserts irq_o high.",
            "test_event.c — configure threshold interrupt; count events; verify processor trap handler entered",
            "tb_event_cnt.v — TC_EVT_14: monitor irq_o asserting on exact clock cycle threshold is reached",
            "performance event counter", "P1", "Not Run"
        ),
        (
            78,
            "EVT_IRQ_ON_OVERFLOW",
            "With IRQ_EN=1, counter overflow past 0xFFFFFFFF asserts irq_o high.",
            "Overflow interrupt handling test",
            "tb_event_cnt.v — trigger overflow with IRQ_EN=1; verify irq_o asserts synchronously with OVF",
            "performance event counter", "P1", "Not Run"
        ),
        (
            79,
            "EVT_IRQ_CLEAR",
            "Writing 1 to clear asserted status flag (THRESH_HIT or OVF) deasserts irq_o in the same cycle; stays low until next qualifying event.",
            "test_event.c — ISR writes STATUS = 0x02 to clear THRESH_HIT; verify interrupt deasserts and ISR exits cleanly",
            "tb_event_cnt.v — TC_EVT_15: write W1C to STATUS; verify irq_o drops to 0 immediately",
            "performance event counter", "P1", "Not Run"
        ),
        (
            80,
            "EVT_READ_DURING_EVENT",
            "Bus read of COUNT or STATUS in the exact cycle an event increments counter returns valid, coherent data without lost count or bus stall.",
            "test_event.c — read COUNT in a tight loop while events fire continuously",
            "tb_event_cnt.v — simultaneous bus read transaction and events_i[sel]=1; verify read data is valid and count advances",
            "performance event counter", "P2", "Not Run"
        ),
        (
            81,
            "EVT_RESET_MIDRUN",
            "Assert active-low reset while event counter is actively counting; verify all registers, flags, and irq_o return to 0 immediately.",
            "Reset recovery verification",
            "tb_event_cnt.v — assert reset mid-run; verify clean return to reset state",
            "performance event counter", "P2", "Not Run"
        ),

        # =========================================================
        # 7. core event sources (hooks) (8 tests)
        # =========================================================
        (
            82,
            "CORE_EVT_LOAD",
            "Core executes lb, lbu, lh, lhu, lw to DMEM; verify evt_load_o pulses for exactly 1 clock cycle upon transaction acceptance.",
            "perf_app.c — execute block of 20 loads",
            "tb_soc_top.v — monitor u_core.evt_load_o pulse width and count matching retired load instructions",
            "core event sources (hooks)", "P1", "Not Run"
        ),
        (
            83,
            "CORE_EVT_STORE",
            "Core executes sb, sh, sw to DMEM; verify evt_store_o pulses for exactly 1 clock cycle upon transaction acceptance.",
            "perf_app.c — execute block of 20 stores",
            "tb_soc_top.v — monitor u_core.evt_store_o count matching retired store instructions",
            "core event sources (hooks)", "P1", "Not Run"
        ),
        (
            84,
            "CORE_EVT_FETCH",
            "Core instruction fetch unit issues valid fetch request accepted by IMEM; verify evt_fetch_o pulses once per accepted fetch.",
            "Straight-line instruction execution",
            "tb_soc_top.v — monitor u_core.evt_fetch_o matching IMEM fetch handshakes",
            "core event sources (hooks)", "P1", "Not Run"
        ),
        (
            85,
            "CORE_EVT_BRANCH_JUMP",
            "Core executes taken beq, bne, blt, bge, bltu, bgeu, jal, jalr; verify evt_branch_jump_o pulses for each taken transfer; not-taken branches do not pulse.",
            "Alternating taken and not-taken branch loops",
            "tb_soc_top.v — check u_core.evt_branch_jump_o matches only branch-taken commits",
            "core event sources (hooks)", "P1", "Not Run"
        ),
        (
            86,
            "CORE_EVT_STALL",
            "Core pipeline stalls due to load-use hazard or bus wait state; verify evt_stall_bubble_o asserts for every stalled clock cycle.",
            "Execute consecutive load followed immediately by dependent ALU operation",
            "tb_soc_top.v — monitor u_core.evt_stall_bubble_o during load-use pipeline interlock",
            "core event sources (hooks)", "P1", "Not Run"
        ),
        (
            87,
            "CORE_EVT_EXCEPTION",
            "Core encounters ECALL, EBREAK, illegal instruction, or misaligned access; verify evt_exception_o pulses for 1 cycle upon trap vector entry.",
            "Software ECALL trap execution",
            "tb_soc_top.v — monitor u_core.evt_exception_o asserting synchronously with mcause trap entry",
            "core event sources (hooks)", "P1", "Not Run"
        ),
        (
            88,
            "CORE_EVT_TIMER_TICK_SOURCE",
            "Timer down-counter reaches 0 and asserts tick_o; verify 1-cycle pulse is routed directly to Event Counter input events_i[6].",
            "Configure Timer with reload value 1000",
            "tb_soc_top.v — verify hierarchical connection u_timer.tick_o == u_event_cnt.events_i[6]",
            "core event sources (hooks)", "P1", "Not Run"
        ),
        (
            89,
            "CORE_EVT_UART_DONE_SOURCE",
            "UART finishes serial transmission of stop bit and asserts tx_done_o; verify 1-cycle pulse is routed directly to Event Counter input events_i[7].",
            "Transmit single character over UART",
            "tb_soc_top.v — verify hierarchical connection u_uart.tx_done_o == u_event_cnt.events_i[7]",
            "core event sources (hooks)", "P1", "Not Run"
        ),

        # =========================================================
        # 8. RISC-V core and memories (12 tests)
        # =========================================================
        (
            90,
            "CORE_ALU_OPS",
            "Verify RV32I arithmetic and logical operations (add, sub, sll, slt, sltu, xor, srl, sra, or, and, and immediate variants) produce correct 32-bit results.",
            "perf_app.c — self-checking ALU regression test suite with corner patterns",
            "tb_soc_top.v — monitor register writebacks against architectural reference model",
            "RISC-V core and memories", "P1", "Not Run"
        ),
        (
            91,
            "CORE_LOAD_STORE_WIDTHS",
            "Verify byte, halfword, and word memory operations (lb, lbu, lh, lhu, lw, sb, sh, sw) perform correct sign-extension, zero-extension, and byte-lane masking.",
            "perf_app.c — write known word 0x12345678; read back as bytes and halfwords",
            "tb_soc_top.v — check DMEM byte write enables and returned data formatting",
            "RISC-V core and memories", "P1", "Not Run"
        ),
        (
            92,
            "CORE_BRANCH_CONDITIONS",
            "Verify branch condition evaluation across equal, not-equal, signed less-than, signed greater-equal, unsigned less-than, unsigned greater-equal (beq, bne, blt, bge, bltu, bgeu).",
            "perf_app.c — test all 6 conditional branch instructions with boundary operands",
            "tb_soc_top.v — verify PC redirection matches branch outcome",
            "RISC-V core and memories", "P1", "Not Run"
        ),
        (
            93,
            "CORE_LUI_AUIPC",
            "Verify lui loads upper 20 bits into destination register; auipc adds upper 20 bits to current instruction PC.",
            "Address calculation routines in firmware",
            "tb_soc_top.v — verify ALU result and register destination for upper immediate ops",
            "RISC-V core and memories", "P2", "Not Run"
        ),
        (
            94,
            "CORE_X0_HARDWIRED",
            "Architectural register x0 remains hardwired to zero; writes to x0 are discarded and reading x0 always returns 32'h0000_0000.",
            "asm(\"li x0, 0xDEADBEEF; add %0, x0, zero\" : \"=r\"(val)); assert val == 0",
            "tb_soc_top.v — verify core register file rf[0] == 32'h0",
            "RISC-V core and memories", "P2", "Not Run"
        ),
        (
            95,
            "CORE_CSR_BASIC",
            "Verify standard Machine-Mode CSRs (mstatus, mie, mtvec, mepc, mcause, mip) read and write as documented; unimplemented CSR reads return 0 or trap.",
            "Write and readback mtvec and mstatus.MIE",
            "tb_soc_top.v — verify CSR address decode and state update",
            "RISC-V core and memories", "P2", "Not Run"
        ),
        (
            96,
            "CORE_ILLEGAL_INSTRUCTION",
            "Core encountering undefined instruction opcode generates illegal instruction trap (mcause = 2), jumps to mtvec, and saves PC in mepc.",
            "Execute .word 0xFFFFFFFF in controlled trap test; trap handler records cause and advances mepc by 4",
            "tb_soc_top.v — monitor trap sequence and verify evt_exception_o pulse",
            "RISC-V core and memories", "P1", "Not Run"
        ),
        (
            97,
            "CORE_INTERRUPT_TAKEN",
            "External interrupt from Event Counter (irq_o) or Timer (timer_tick) with mstatus.MIE=1 traps to mtvec with mcause MSB=1; returns via mret.",
            "test_event.c — enable external interrupt in mie; configure threshold hit; verify ISR execution",
            "tb_soc_top.v — drive interrupt line; check trap entry timing and mret resumption",
            "RISC-V core and memories", "P2", "Not Run"
        ),
        (
            98,
            "IMEM_FETCH_ALL_WORDS",
            "IMEM 4KB address space (0x0000_0000 to 0x0000_0FFC) accessible for instruction fetching without wrap or unmapped bus errors.",
            "Linker script maps text segment across IMEM window",
            "tb_soc_top.v — verify instruction fetch address bounds within 0x000 - 0xFFC",
            "RISC-V core and memories", "P2", "Not Run"
        ),
        (
            99,
            "DMEM_WORD_READBACK",
            "Word write followed by read at boundary addresses (0x0000_1000, 0x0000_1800, 0x0000_1FFC) returns exact 32-bit written values.",
            "perf_app.c — write and readback patterns at bottom, middle, and top of DMEM",
            "tb_soc_top.v — monitor DMEM bus transactions and verify data integrity",
            "RISC-V core and memories", "P1", "Not Run"
        ),
        (
            100,
            "DMEM_BYTE_ENABLE",
            "Byte stores (sb) to individual byte offsets (0x1000, 0x1001, 0x1002, 0x1003) update only targeted byte lanes; other three bytes are unchanged.",
            "perf_app.c — write word 0xFFFFFFFF; write byte 0x00 to each lane; verify resulting word",
            "tb_soc_top.v — verify wstrb lane enables in dmem.v",
            "RISC-V core and memories", "P1", "Not Run"
        ),
        (
            101,
            "DMEM_BOUNDARY",
            "Store to 0x0000_1FFC accesses top of DMEM; store to 0x0000_2000 accesses UART; verify no aliasing between memory and peripheral spaces.",
            "Write distinct values to 0x1FFC and 0x2000; read back 0x1FFC and verify intact",
            "tb_bus_decoder.v — check boundary decode transition from DMEM to UART",
            "RISC-V core and memories", "P2", "Not Run"
        ),

        # =========================================================
        # 9. system timer (7 tests)
        # =========================================================
        (
            102,
            "TIMER_RESET_STATE",
            "After reset deassertion, CTRL=0x0000_0000 (timer disabled), RELOAD=0x0000_0000, COUNT=0x0000_0000, and tick_o=0.",
            "perf_app.c — read Timer registers at cold boot; assert all 0",
            "tb_soc_top.v / bus_bfm.v — verify Timer reset values",
            "system timer", "P1", "Not Run"
        ),
        (
            103,
            "TIMER_LOAD_RW",
            "RELOAD register (offset 0x04) accepts full 32-bit reload values (100, 50000, 0xDEADBEEF) and reads back correctly.",
            "perf_app.c — write and read back test reload values in TIMER_RELOAD",
            "tb_soc_top.v — verify register storage across 32-bit patterns",
            "system timer", "P1", "Not Run"
        ),
        (
            104,
            "TIMER_COUNT_ENABLE",
            "Writing CTRL.EN=1 enables down-counter; COUNT decrements once per clock cycle from RELOAD value towards 0.",
            "perf_app.c — start timer; read COUNT twice; verify second read < first read",
            "tb_soc_top.v — verify u_timer.count_reg decrements on every clock while EN=1",
            "system timer", "P1", "Not Run"
        ),
        (
            105,
            "TIMER_TICK_PULSE",
            "When COUNT reaches zero, tick_o pulses active-high for exactly 1 clock cycle; counter auto-reloads from RELOAD register.",
            "Not applicable (cycle-accurate pulse measurement)",
            "tb_soc_top.v — monitor u_timer.tick_o pulse width == 1 cycle; verify auto-reload to RELOAD",
            "system timer", "P1", "Not Run"
        ),
        (
            106,
            "TIMER_TICK_PERIOD",
            "Program reload value N; verify time between consecutive tick_o pulses equals exactly N+1 clock cycles over multiple periods.",
            "Poll timer tick event count or measure cycle counter elapsed between ticks",
            "tb_soc_top.v — assert time delta between consecutive ticks == N+1 cycles",
            "system timer", "P1", "Not Run"
        ),
        (
            107,
            "TIMER_DISABLE_HOLD",
            "Clearing CTRL.EN=0 freezes countdown immediately; re-enabling resumes counting from frozen value without losing ticks.",
            "perf_app.c — start timer, disable, delay, re-read count (verify equal), re-enable",
            "tb_soc_top.v — check count freezes when EN=0",
            "system timer", "P2", "Not Run"
        ),
        (
            108,
            "TIMER_TICK_TO_EVENT_CNT",
            "With EVT_SEL=6, each Timer tick_o pulse increments Event Counter COUNT; verify Event Counter matches total timer expiries.",
            "test_event.c — select Event 6; run Timer for 10 expiries; verify COUNT == 10",
            "tb_soc_top.v — verify event counter increments synchronously on each timer_tick",
            "system timer", "P1", "Not Run"
        ),

        # =========================================================
        # 10. UART (12 tests)
        # =========================================================
        (
            109,
            "UART_RESET_STATE",
            "After reset deassertion, LSR=0x0000_0060 (THRE=1, TEMT=1), LCR=0x0000_0003 (8N1), DIVISOR=434, and uart_tx idles HIGH.",
            "perf_app.c — read UART_LSR at boot; assert LSR & 0x60 == 0x60",
            "tb_soc_top.v — check UART reset values and verify uart_tx == 1",
            "UART", "P1", "Not Run"
        ),
        (
            110,
            "UART_BAUD_DIV_RW",
            "DIVISOR register (offset 0x08) is directly accessible; writes new baud divisor and reads back; default 434 gives 115200 baud at 50MHz.",
            "perf_app.c — write 217 (230400 baud) to DIVISOR; verify readback; restore 434",
            "tb_soc_top.v — verify divisor register write/readback without requiring DLAB",
            "UART", "P1", "Not Run"
        ),
        (
            111,
            "UART_TX_FRAME_FORMAT",
            "Transmit byte over UART; verify frame format consists of 1 start bit (0), 8 data bits (LSB first), and 1 stop bit (1) (8N1).",
            "uart_putc('A') (ASCII 0x41)",
            "uart_monitor.v — sample serial stream at mid-bit intervals; verify start bit, data bits 0x41, stop bit",
            "UART", "P1", "Not Run"
        ),
        (
            112,
            "UART_TX_BIT_TIMING",
            "Serial bit duration on uart_tx equals programmed divisor * clock period (434 * 20ns = 8.68us at 50MHz).",
            "Serial character transmission",
            "uart_monitor.v — measure bit period in simulation clocks; verify exactly matches DIVISOR",
            "UART", "P1", "Not Run"
        ),
        (
            113,
            "UART_TX_THRE_POLL",
            "Firmware polls LSR[5] (THRE); writes THR only when THRE=1; THRE clears upon write and asserts when byte moves to shift register.",
            "uart_putc() driver polling LSR bit 5 before storing to THR",
            "tb_soc_top.v — verify polling flow prevents data overwrite and transmits without loss",
            "UART", "P1", "Not Run"
        ),
        (
            114,
            "UART_TX_BACK_TO_BACK",
            "Transmit consecutive bytes with continuous THRE polling; verify back-to-back frames shift out with exactly 1 stop bit and no dropped characters.",
            "uart_puts(\"PASS\")",
            "uart_monitor.v — decode 4 contiguous frames; verify string matches \"PASS\"",
            "UART", "P1", "Not Run"
        ),
        (
            115,
            "UART_TEMT_DRAIN",
            "LSR[6] (TEMT) clears to 0 while transmission is active; asserts to 1 only after the last stop bit completes and transmitter is fully idle.",
            "perf_app.c — poll TEMT after printing message before resetting or checking counts",
            "tb_soc_top.v — verify TEMT transition matches serial frame completion",
            "UART", "P1", "Not Run"
        ),
        (
            116,
            "UART_TX_DONE_PULSE",
            "tx_done_o pulses active-high for exactly 1 clock cycle upon stop bit completion of each transmitted frame.",
            "Transmit 5 characters",
            "tb_soc_top.v — monitor u_uart.tx_done_o pulse width == 1 cycle and count == 5",
            "UART", "P1", "Not Run"
        ),
        (
            117,
            "UART_THR_WHEN_BUSY",
            "Write to THR while previous byte is still shifting; holding register buffers the byte; transfers to shifter once prior frame finishes.",
            "Rapid two-byte write when THRE=1",
            "tb_soc_top.v — check both bytes serialize correctly in sequence",
            "UART", "P2", "Not Run"
        ),
        (
            118,
            "UART_LSR_READONLY",
            "LSR register at offset 0x14 is Read-Only; writes to LSR are ignored; status bits reflect real transmitter hardware state.",
            "perf_app.c — attempt write 0x00 to LSR; read back and verify 0x60 remains",
            "tb_soc_top.v — bus write to LSR; verify status unaffected",
            "UART", "P2", "Not Run"
        ),
        (
            119,
            "UART_RX_PATH",
            "UART is configured as transmit-focused monitor peripheral; verify RBR read returns 0x00 and LSR[0] (data ready) remains 0.",
            "perf_app.c — read UART_RBR (offset 0x00); verify safe return value",
            "tb_soc_top.v — verify read from offset 0x00 completes with ready=1, rdata=0",
            "UART", "P3", "Not Run"
        ),
        (
            120,
            "UART_PASS_FAIL_TOKEN",
            "Firmware prints status strings '[PERF_TEST] PASS' or '[PERF_TEST] FAIL'; uart_monitor detects token and determines test status.",
            "perf_app.c — print '[PERF_TEST] PASS' upon successful completion of all checks",
            "uart_monitor.v — decode UART output; assert PASS token triggers simulation success; FAIL token triggers error",
            "UART", "P1", "Not Run"
        ),

        # =========================================================
        # 11. GPIO (7 tests)
        # =========================================================
        (
            121,
            "GPIO_RESET_STATE",
            "After reset deassertion, DIR=0x0000_0000 (all pins inputs), OUT=0x0000_0000, IN=0x0000_0000, and gpio_out_o=8'h00.",
            "perf_app.c — read GPIO_DIR and GPIO_OUT at startup; verify 0",
            "tb_soc_top.v — check GPIO register reset values and output pins == 0",
            "GPIO", "P1", "Not Run"
        ),
        (
            122,
            "GPIO_OUT_PATTERNS",
            "Set DIR=0xFF; write patterns 0xA5, 0x5A, 0xFF, 0x00 to OUT; verify gpio_out_o pins reflect exact written patterns.",
            "perf_app.c — output alternating patterns on GPIO pins",
            "tb_soc_top.v — check gpio_out_o == OUT[7:0]",
            "GPIO", "P1", "Not Run"
        ),
        (
            123,
            "GPIO_UPPER_BITS",
            "GPIO registers implement only lower 8 bits [7:0]; writing 0xFFFF_FFFF masks upper bits and reads back 0x0000_00FF.",
            "perf_app.c — write 0xFFFFFFFF to GPIO_DIR and GPIO_OUT; verify readback is 0x000000FF",
            "tb_soc_top.v — check upper 24 bits read as zero",
            "GPIO", "P2", "Not Run"
        ),
        (
            124,
            "GPIO_DIR_GATING",
            "Output pins driven by hardware gating gpio_out_o = OUT & DIR; verify unconfigured pin (DIR[i]=0) drives 0 regardless of OUT[i].",
            "perf_app.c — set DIR=0x0F, OUT=0xFF; verify pins output 0x0F",
            "tb_soc_top.v — assert gpio_out_o == (u_gpio.dir_reg & u_gpio.out_reg)",
            "GPIO", "P2", "Not Run"
        ),
        (
            125,
            "GPIO_IN_SYNC",
            "External input signals gpio_in_i pass through 2-flip-flop synchronizer into IN register (offset 0x08); verify valid readback after 2 clock cycles.",
            "perf_app.c — read GPIO_IN register",
            "tb_soc_top.v — drive external gpio_in_i = 8'h3C; advance 2 clocks; read GPIO_IN and assert 8'h3C",
            "GPIO", "P1", "Not Run"
        ),
        (
            126,
            "GPIO_IN_READONLY",
            "IN register (offset 0x08) is strictly Read-Only; writes to IN are ignored; value strictly mirrors synchronized input pins.",
            "Attempt write 0xAA to GPIO_IN; read back and verify value is not overwritten",
            "tb_soc_top.v — issue bus write to IN; verify internal register unaltered",
            "GPIO", "P2", "Not Run"
        ),
        (
            127,
            "GPIO_NO_ALIAS_INTO_OTHER_PERIPHERALS",
            "Writes to GPIO register space (0x0000_2200 - 0x0000_2208) do not affect UART, Timer, or HPM counter registers.",
            "perf_app.c — toggle GPIO while monitoring HPM counter status registers",
            "tb_soc_top.v — verify slave select isolation across peripheral boundary",
            "GPIO", "P3", "Not Run"
        ),

        # =========================================================
        # 12. SoC integration (HPM end-to-end) (14 tests)
        # =========================================================
        (
            128,
            "SOC_FIRMWARE_BOOT_TO_PASS",
            "Full SoC simulation executes crt0.S boot code, initializes stack, runs benchmark application, and prints '[PERF_TEST] PASS' with zero errors.",
            "Full firmware suite running from IMEM",
            "tb_soc_top.v + uart_monitor.v — monitor execution from reset release to PASS token",
            "SoC integration (HPM end-to-end)", "P1", "Not Run"
        ),
        (
            129,
            "SOC_MEASURE_LOOP_CYCLES_INSTR",
            "Enable Cycle Counter and Instruction Counter around a known 100-iteration arithmetic loop; verify hardware counter deltas match expected cycles and retired instructions.",
            "perf_app.c — start counters, run loop of 100 adds, stop counters, read deltas",
            "tb_soc_top.v — cross-check DUT counters against testbench shadow monitors",
            "SoC integration (HPM end-to-end)", "P1", "Not Run"
        ),
        (
            130,
            "SOC_CPI_CROSS_CHECK",
            "Compute CPI (Cycles / Instructions) for compute-bound vs memory-bound loops; verify compute loop achieves near-ideal CPI and memory loop reflects stall penalties.",
            "perf_app.c — compute ratio cycles * 100 / instructions; print result via UART",
            "tb_soc_top.v — verify hardware counter measurements match architectural timing model",
            "SoC integration (HPM end-to-end)", "P2", "Not Run"
        ),
        (
            131,
            "SOC_EVENT_LOAD_STORE_COUNTS",
            "Execute benchmark with exactly N loads and M stores; verify Event Counter programmed for EVT_SEL=0 (Loads) and EVT_SEL=1 (Stores) counts exactly N and M.",
            "test_event.c — array copy routine with known load and store count",
            "tb_soc_top.v — verify event counts match LSU bus activity monitor",
            "SoC integration (HPM end-to-end)", "P1", "Not Run"
        ),
        (
            132,
            "SOC_EVENT_BRANCH_COUNT",
            "Execute loop with known taken and not-taken branch counts; verify Event Counter programmed for EVT_SEL=3 counts exactly taken branches.",
            "test_event.c — conditional branch loop with deterministic branch history",
            "tb_soc_top.v — cross-check COUNT against testbench branch tracker",
            "SoC integration (HPM end-to-end)", "P1", "Not Run"
        ),
        (
            133,
            "SOC_EVENT_THRESHOLD_IRQ",
            "Program Event Counter THRESH=50, IRQ_EN=1; run events; verify irq_o triggers processor interrupt, ISR executes, clears status via W1C, and returns.",
            "test_event.c — interrupt service routine (trap_handler) clearing THRESH_HIT",
            "tb_soc_top.v — monitor interrupt handshake: irq_o assertion -> core trap entry -> W1C write -> irq_o deassertion",
            "SoC integration (HPM end-to-end)", "P1", "Not Run"
        ),
        (
            134,
            "SOC_EVENT_OVERFLOW_POLL",
            "Event Counter reaches overflow condition; verify firmware polling detects STATUS.OVF=1, clears bit via W1C, and confirms flag resets to 0.",
            "test_event.c — poll status register for overflow condition and perform W1C clear",
            "tb_soc_top.v — check polling sequence and W1C handshake",
            "SoC integration (HPM end-to-end)", "P2", "Not Run"
        ),
        (
            135,
            "SOC_ALL_COUNTERS_CONCURRENT",
            "Cycle Counter, Instruction Counter, and Event Counter enabled simultaneously while running complex workload; verify all 3 counters operate independently with zero crosstalk.",
            "perf_app.c — concurrent profiling of matrix multiplication algorithm",
            "tb_soc_top.v — cross-verify all 3 counters against parallel shadow counters throughout simulation",
            "SoC integration (HPM end-to-end)", "P1", "Not Run"
        ),
        (
            136,
            "SOC_HPM_READ_OVERHEAD",
            "Measure the instruction and cycle overhead of reading HPM registers (CNT_LO, CNT_HI); verify reading registers adds exactly the deterministic load instructions.",
            "perf_app.c — calibration loop subtracting counter read overhead from benchmark measurements",
            "tb_soc_top.v — track cycle latency of peripheral register reads",
            "SoC integration (HPM end-to-end)", "P3", "Not Run"
        ),
        (
            137,
            "SOC_TIMER_TICK_EVENT",
            "Configure Timer for periodic ticks; select EVT_SEL=6 on Event Counter; verify Event Counter accurately accumulates timer ticks while core executes independent workload.",
            "perf_app.c — start Timer, execute compute benchmark, verify accumulated timer ticks",
            "tb_soc_top.v — check Event Counter increments on every timer_tick",
            "SoC integration (HPM end-to-end)", "P2", "Not Run"
        ),
        (
            138,
            "SOC_UART_DONE_EVENT",
            "Configure Event Counter with EVT_SEL=7; transmit multi-byte string over UART; verify Event Counter accumulates exactly 1 count per transmitted character.",
            "perf_app.c — transmit 40-character banner; check COUNT == 40",
            "tb_soc_top.v — check Event Counter increments on every uart_tx_done pulse",
            "SoC integration (HPM end-to-end)", "P2", "Not Run"
        ),
        (
            139,
            "SOC_FULL_PERIPHERAL_SWEEP",
            "Single comprehensive test scenario actively driving UART, Timer, GPIO, and all three HPM counters concurrently; verify no bus contention or data corruption.",
            "perf_app.c — integrated system stress test exercising all memory-mapped peripherals",
            "tb_soc_top.v — monitors all peripheral interfaces simultaneously; assert zero bus errors",
            "SoC integration (HPM end-to-end)", "P1", "Not Run"
        ),
        (
            140,
            "SOC_RESET_MIDRUN_RECOVERY",
            "Assert reset in the middle of active SoC program execution; verify processor, interconnect, and all peripherals reset cleanly and reboot to PASS.",
            "Boot and self-test sequence",
            "tb_soc_top.v — assert rstn mid-simulation; wait 10 clocks; deassert rstn; verify clean re-execution and PASS token",
            "SoC integration (HPM end-to-end)", "P2", "Not Run"
        ),
        (
            141,
            "SOC_LONG_RUN_STABILITY",
            "Long-duration simulation (100,000+ clock cycles) exercising continuous counter increments, timer ticks, and UART transmissions; verify zero drift or leakage.",
            "Extended workload loop in perf_app.c",
            "tb_soc_top.v — continuous assertion checking over 100k+ cycles",
            "SoC integration (HPM end-to-end)", "P3", "Not Run"
        ),

        # =========================================================
        # 13. regression and tooling (3 tests)
        # =========================================================
        (
            142,
            "RUN_ALL_UNIT_TESTS",
            "Automated script run/run_ip.sh all executes all IP unit testbenches (tb_cycle_cnt.v, tb_instr_cnt.v, tb_event_cnt.v, tb_bus_decoder.v) and SoC testbench (tb_soc_top.v), returning exit code 0 on all PASS.",
            "Test firmware binaries",
            "Testbenches exit with $finish(0) on pass and $fatal / non-zero code on failure",
            "regression and tooling", "P2", "Not Run"
        ),
        (
            143,
            "RUN_MULTI_SIMULATOR",
            "Testbench filelists and compilation scripts support standard Verilog simulators (Icarus Verilog via iverilog -g2012, Synopsys VCS via vcs -sverilog, and Verilator).",
            "Compatible hexadecimal memory image",
            "IEEE 1800-2012 SystemVerilog and Verilog-2001 compatible testbench code with clean syntax",
            "regression and tooling", "P2", "Not Run"
        ),
        (
            144,
            "RUN_WAVE_DUMP",
            "Simulation run generates waveform dump (.vcd / .fsdb) with complete design hierarchy (u_soc_top, u_core, u_bus_decoder, u_cycle_cnt, u_instr_cnt, u_event_cnt, u_uart, u_timer, u_gpio) for waveform debug.",
            "Not applicable",
            "Testbench $dumpfile(\"soc_tb.vcd\"); $dumpvars(0, tb_soc_top); conditioned on +WAVE runtime argument",
            "regression and tooling", "P3", "Not Run"
        )
    ]

    current_block = ""
    row_num = 2

    for t in tests:
        sno, name, desc, c_portion, sv_portion, block, prio, status = t
        if block != current_block:
            # Add section header
            if row_num > 2:
                # Add blank row before section header
                ws1.append([None]*8)
                row_num += 1
            current_block = block
            sec_row = [None, f"== {current_block} ==", None, None, None, None, None, None]
            ws1.append(sec_row)
            for c_idx in range(1, 9):
                c = ws1.cell(row_num, c_idx)
                c.fill = section_fill
                c.font = section_font
                if c_idx == 2:
                    c.alignment = align_left_nowrap
            ws1.row_dimensions[row_num].height = 22
            row_num += 1

        row_data = [sno, name, desc, c_portion, sv_portion, block, prio, status]
        ws1.append(row_data)
        
        # Style data row
        ws1.cell(row_num, 1).alignment = align_center # S.No
        ws1.cell(row_num, 2).alignment = align_left_nowrap # Name
        ws1.cell(row_num, 3).alignment = align_left # Desc
        ws1.cell(row_num, 4).alignment = align_left # C
        ws1.cell(row_num, 5).alignment = align_left # SV
        ws1.cell(row_num, 6).alignment = align_left # Block
        ws1.cell(row_num, 7).alignment = align_center # Prio
        ws1.cell(row_num, 8).alignment = align_center # Status

        for c_idx in range(1, 9):
            c = ws1.cell(row_num, c_idx)
            c.font = regular_font
            c.border = cell_border
        
        ws1.row_dimensions[row_num].height = 36
        row_num += 1

    # Set column widths for sheet1
    col_widths1 = {
        "A": 7.0,
        "B": 34.0,
        "C": 80.0,
        "D": 60.0,
        "E": 75.0,
        "F": 28.0,
        "G": 10.0,
        "H": 12.0
    }
    for col_letter, width in col_widths1.items():
        ws1.column_dimensions[col_letter].width = width

    # -------------------------------------------------------------
    # SHEET 2: Summary
    # -------------------------------------------------------------
    ws2 = wb.create_sheet("Summary")
    ws2.views.sheetView[0].showGridLines = True

    ws2.cell(1, 1, "Test Plan Summary & Verification Coverage Matrix").font = title_font
    ws2.cell(2, 1, "Dynamic metrics synchronized with testplan_soc sheet").font = sub_font
    ws2.row_dimensions[1].height = 24
    ws2.row_dimensions[2].height = 18

    headers2 = ["Block", "Total", "P1", "Pass", "Fail", "Blocked", "Not Run", "Pass %"]
    ws2.append([]) # row 3 blank spacer
    ws2.append(headers2) # row 4
    for c_idx in range(1, len(headers2) + 1):
        cell = ws2.cell(4, c_idx)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = align_center
        cell.border = cell_border
    ws2.row_dimensions[4].height = 24

    blocks = [
        "boot & system",
        "bus decoder / interconnect",
        "reg_slave_if (bus-to-register adapter)",
        "cycle counter",
        "instruction counter",
        "performance event counter",
        "core event sources (hooks)",
        "RISC-V core and memories",
        "system timer",
        "UART",
        "GPIO",
        "SoC integration (HPM end-to-end)",
        "regression and tooling"
    ]

    r_start = 5
    for idx, b_name in enumerate(blocks):
        curr_r = r_start + idx
        row_cells = [
            b_name,
            f'=COUNTIF(testplan_soc!$F$2:$F$200,$A{curr_r})',
            f'=COUNTIFS(testplan_soc!$F$2:$F$200,$A{curr_r},testplan_soc!$G$2:$G$200,"P1")',
            f'=COUNTIFS(testplan_soc!$F$2:$F$200,$A{curr_r},testplan_soc!$H$2:$H$200,"Pass")',
            f'=COUNTIFS(testplan_soc!$F$2:$F$200,$A{curr_r},testplan_soc!$H$2:$H$200,"Fail")',
            f'=COUNTIFS(testplan_soc!$F$2:$F$200,$A{curr_r},testplan_soc!$H$2:$H$200,"Blocked")',
            f'=COUNTIFS(testplan_soc!$F$2:$F$200,$A{curr_r},testplan_soc!$H$2:$H$200,"Not Run")',
            f'=IFERROR(D{curr_r}/B{curr_r},0)'
        ]
        ws2.append(row_cells)
        ws2.row_dimensions[curr_r].height = 20
        for c_idx in range(1, 9):
            c = ws2.cell(curr_r, c_idx)
            c.font = regular_font
            c.border = cell_border
            if c_idx == 1:
                c.alignment = align_left
            else:
                c.alignment = align_center
            if c_idx == 8:
                c.number_format = '0.0%'

    # Total row
    tot_r = r_start + len(blocks)
    tot_cells = [
        "TOTAL",
        f'=SUM(B{r_start}:B{tot_r-1})',
        f'=SUM(C{r_start}:C{tot_r-1})',
        f'=SUM(D{r_start}:D{tot_r-1})',
        f'=SUM(E{r_start}:E{tot_r-1})',
        f'=SUM(F{r_start}:F{tot_r-1})',
        f'=SUM(G{r_start}:G{tot_r-1})',
        f'=IFERROR(D{tot_r}/B{tot_r},0)'
    ]
    ws2.append(tot_cells)
    ws2.row_dimensions[tot_r].height = 24
    for c_idx in range(1, 9):
        c = ws2.cell(tot_r, c_idx)
        c.fill = total_fill
        c.font = total_font
        c.border = double_bottom
        if c_idx == 1:
            c.alignment = align_left
        else:
            c.alignment = align_center
        if c_idx == 8:
            c.number_format = '0.0%'

    col_widths2 = {
        "A": 36.0,
        "B": 12.0,
        "C": 12.0,
        "D": 12.0,
        "E": 12.0,
        "F": 12.0,
        "G": 14.0,
        "H": 14.0
    }
    for col_letter, width in col_widths2.items():
        ws2.column_dimensions[col_letter].width = width

    # -------------------------------------------------------------
    # SHEET 3: Event Select Matrix
    # -------------------------------------------------------------
    ws3 = wb.create_sheet("Event Select Matrix")
    ws3.views.sheetView[0].showGridLines = True

    ws3.cell(1, 1, "Hardware Performance Monitoring Event Select Matrix (EVT_SEL)").font = title_font
    ws3.cell(2, 1, "Exact architectural mapping between EVT_SEL encoding, core signals, firmware stimulus, and checks").font = sub_font
    ws3.row_dimensions[1].height = 24
    ws3.row_dimensions[2].height = 18

    headers3 = [
        "EVT_SEL",
        "Hardware Event Name",
        "VeeR EL2 Core Source Signal",
        "Firmware Stimulus",
        "Expected Count",
        "Unit Test Reference",
        "SoC Integration Test"
    ]
    ws3.append([]) # row 3 blank
    ws3.append(headers3) # row 4
    for c_idx in range(1, len(headers3) + 1):
        cell = ws3.cell(4, c_idx)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = align_center
        cell.border = cell_border
    ws3.row_dimensions[4].height = 26

    matrix_rows = [
        (
            0,
            "Data memory read accepted (Load)",
            "lsu_htrans[1] & ~lsu_hwrite & lsu_hready\n(AHB LSU read handshake)",
            "50 loads from DMEM (lw in unrolled loop)",
            "50",
            "tb_event_cnt.v: TC_EVT_03 (EVT_SEL0_LOAD)",
            "tb_soc_top.v: SOC_EVENT_LOAD_STORE_COUNTS"
        ),
        (
            1,
            "Data memory write accepted (Store)",
            "lsu_htrans[1] & lsu_hwrite & lsu_hready\n(AHB LSU write handshake)",
            "30 stores to DMEM (sw in unrolled loop)",
            "30",
            "tb_event_cnt.v: TC_EVT_04 (EVT_SEL1_STORE)",
            "tb_soc_top.v: SOC_EVENT_LOAD_STORE_COUNTS"
        ),
        (
            2,
            "Instruction fetch accepted",
            "ifu_htrans[1] & ifu_hready\n(AHB IFU fetch handshake)",
            "Straight-line nop block of known length",
            "Exact fetch count from IMEM monitor",
            "tb_event_cnt.v: TC_EVT_05 (EVT_SEL2_FETCH)",
            "tb_soc_top.v: CORE_EVT_FETCH"
        ),
        (
            3,
            "Branch or Jump taken",
            "dec_tlu_perfcnt0\n(exu_pmu_i0_br_ataken & tlu_i0_commit_cmt)",
            "Loop with exactly 100 taken branches",
            "100",
            "tb_event_cnt.v: TC_EVT_06 (EVT_SEL3_BRANCH_JUMP)",
            "tb_soc_top.v: SOC_EVENT_BRANCH_COUNT"
        ),
        (
            4,
            "Pipeline stall or memory wait cycle",
            "(ifu_htrans[1] & ~ifu_hready) |\n(lsu_htrans[1] & ~lsu_hready)",
            "Load-use data hazard interlock sequence",
            "Exact stall cycles from pipeline monitor",
            "tb_event_cnt.v: TC_EVT_07 (EVT_SEL4_STALL)",
            "tb_soc_top.v: CORE_EVT_STALL"
        ),
        (
            5,
            "Exception or Trap taken",
            "trace_rv_i_exception_ip\n(Trap commit pulse on ECALL / Illegal)",
            "ECALL software trap executed 8 times",
            "8",
            "tb_event_cnt.v: TC_EVT_08 (EVT_SEL5_EXCEPTION)",
            "tb_soc_top.v: CORE_EVT_EXCEPTION"
        ),
        (
            6,
            "Timer interrupt tick event",
            "timer_tick\n(Direct pulse from System Timer tick_o)",
            "Timer programmed for 5 expiry periods",
            "5",
            "tb_event_cnt.v: TC_EVT_09 (EVT_SEL6_TIMER_TICK)",
            "tb_soc_top.v: SOC_TIMER_TICK_EVENT"
        ),
        (
            7,
            "UART frame transmit complete",
            "uart_tx_done\n(Direct pulse from UART tx_done_o)",
            "Transmit 26 ASCII characters ('A' through 'Z')",
            "26",
            "tb_event_cnt.v: TC_EVT_10 (EVT_SEL7_UART_TX_DONE)",
            "tb_soc_top.v: SOC_UART_DONE_EVENT"
        )
    ]

    r_start3 = 5
    for idx, m_row in enumerate(matrix_rows):
        curr_r = r_start3 + idx
        ws3.append(list(m_row))
        ws3.row_dimensions[curr_r].height = 42
        for c_idx in range(1, len(m_row) + 1):
            c = ws3.cell(curr_r, c_idx)
            c.font = regular_font
            c.border = cell_border
            if c_idx == 1 or c_idx == 5:
                c.alignment = align_center
            else:
                c.alignment = align_left

    col_widths3 = {
        "A": 10.0,
        "B": 30.0,
        "C": 44.0,
        "D": 36.0,
        "E": 20.0,
        "F": 34.0,
        "G": 34.0
    }
    for col_letter, width in col_widths3.items():
        ws3.column_dimensions[col_letter].width = width

    # -------------------------------------------------------------
    # SHEET 4: Notes & Assumptions
    # -------------------------------------------------------------
    ws4 = wb.create_sheet("Notes & Assumptions")
    ws4.views.sheetView[0].showGridLines = True

    ws4.cell(1, 1, "SoC Architecture & Verification Implementation Specifications").font = title_font
    ws4.cell(2, 1, "Authoritative rules, register protocols, priority logic, and environment conventions").font = sub_font
    ws4.row_dimensions[1].height = 24
    ws4.row_dimensions[2].height = 18

    headers4 = ["Section", "Specification Item", "Hardware Rule & Verification Contract"]
    ws4.append([]) # row 3 blank
    ws4.append(headers4) # row 4
    for c_idx in range(1, len(headers4) + 1):
        cell = ws4.cell(4, c_idx)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = align_center
        cell.border = cell_border
    ws4.row_dimensions[4].height = 24

    notes_data = [
        (
            "1. Architectural Memory Map",
            "Memory-Mapped Base Addresses",
            "All peripherals reside within the 0x0000_2xxx page (addr[31:12] == 20'h00002). Decoder windows: IMEM (0x0000_0000-0x0000_0FFF, 4KB), DMEM (0x0000_1000-0x0000_1FFF, 4KB), UART (0x0000_2000-0x0000_20FF, 256B), Timer (0x0000_2100-0x0000_21FF, 256B), GPIO (0x0000_2200-0x0000_22FF, 256B), Cycle Counter (0x0000_2300-0x0000_23FF, 256B), Instruction Counter (0x0000_2400-0x0000_24FF, 256B), Event Counter (0x0000_2500-0x0000_25FF, 256B). Unmapped accesses return single-cycle m_ready_o=1, m_rdata_o=32'h0, and m_err_o=1 without hanging the bus."
        ),
        (
            "2. Atomic 64-Bit Coherency",
            "Cycle & Instruction Counter Shadow Capture",
            "The 64-bit Cycle Counter and 64-bit Instruction Counter implement internal 32-bit shadow registers for CNT_HI. Reading the low word CNT_LO (offset 0x08) atomically latches the live upper 32 bits count[63:32] into the CNT_HI shadow register in the same clock cycle. Subsequent reading of CNT_HI (offset 0x0C) returns the shadowed value, guaranteeing atomic, coherent 64-bit snapshots even if count[31:0] rolls over during the read sequence."
        ),
        (
            "3. Register Access Rights",
            "Read-Only Protection on Counter Registers",
            "In all three HPM IP cores, the counter data registers (CNT_LO, CNT_HI, COUNT) are strictly Read-Only (RO). Bus writes to these offsets are safely acknowledged with ready=1 but hardware ignores write data, preventing accidental corruption of counter state. Similarly, UART LSR, Timer COUNT, and GPIO IN are strictly Read-Only."
        ),
        (
            "4. Priority Rules",
            "Synchronous Reset & Clear Priority",
            "Hardware priority logic is strictly defined across all IPs: (1) Active-low reset rstn has absolute priority over all operations. (2) Writing CTRL.CLEAR=1 has priority over simultaneous count increments (the counter clears to 0 and does not increment on that cycle). CLEAR is self-clearing and always reads 0. (3) In Event Counter, if a status flag (OVF or THRESH_HIT) occurs in the same cycle a W1C clear is written, the hardware event assertion takes priority, ensuring no lost events."
        ),
        (
            "5. Status & Interrupt Logic",
            "Event Counter W1C & Threshold Interrupt",
            "In Event Counter, STATUS bits OVF (bit 0) and THRESH_HIT (bit 1) are Write-1-to-Clear (W1C). Writing 1 clears the bit; writing 0 leaves it unchanged. THRESH register holds a 32-bit compare value; value 0 disables threshold comparison. When THRESH != 0 and COUNT >= THRESH, THRESH_HIT asserts sticky. When CTRL.IRQ_EN=1 (bit 2), irq_o asserts whenever (OVF | THRESH_HIT) is high. Clearing the status flag deasserts irq_o in the same cycle."
        ),
        (
            "6. Core Signal Sourcing",
            "CHIPS Alliance VeeR EL2 Core Integration",
            "The SoC integrates exclusively the CHIPS Alliance VeeR EL2 core (el2_veer_wrapper.sv) via veer_core_adapter.sv. instr_retire_o is derived as (trace_rv_i_valid_ip & ~trace_rv_i_exception_ip). Events 0-1 are tapped from LSU AHB transactions (lsu_htrans[1] & lsu_hready), Event 2 from IFU fetch (ifu_htrans[1] & ifu_hready), Event 3 from branch commit (dec_tlu_perfcnt0), Event 4 from bus wait states, Event 5 from trace exception (trace_rv_i_exception_ip), Event 6 from timer_tick, and Event 7 from uart_tx_done."
        ),
        (
            "7. Peripheral Features",
            "UART, Timer, and GPIO Architecture",
            "UART implements direct baud divisor access at offset 0x08 (default 434 for 115200 baud at 50MHz; no DLAB required), standard 16550 LCR (default 0x03 for 8N1), and LSR (0x60 default). Timer is a 32-bit reloadable down-counter pulsing tick_o for 1 clock cycle upon reaching zero and auto-reloading. GPIO features 8-bit DIR, 8-bit OUT (gated as OUT & DIR), and 8-bit IN synchronized through a 2-stage flip-flop synchronizer."
        ),
        (
            "8. Testbench Structure",
            "Deterministic Self-Checking Verification",
            "The verification suite uses self-checking testbenches: Unit testbenches (tb_cycle_cnt.v, tb_instr_cnt.v, tb_event_cnt.v, tb_bus_decoder.v) employ bus_bfm.v for deterministic stimulus, boundary checking, and register access. Top-level testbench (tb_soc_top.v) instantiates soc_top.v with passive uart_monitor.v (115200 baud 8N1 frame decoding), GPIO indicator monitors, and parallel hierarchical shadow counters cross-checking DUT behavior."
        ),
        (
            "9. Firmware Test Structure",
            "Modular C Verification Programs",
            "Firmware verification is divided into dedicated programs: test_cycle.c (cycle counter controls and shadow coherency), test_instr.c (instruction counter retirements and loop validation), test_event.c (all 8 event selections, threshold hit, W1C status, and interrupt handling), perf_app.c (comprehensive end-to-end SoC performance benchmarking, CPI cross-checks, and peripheral integration), supported by crt0.S for reset vector entry, stack initialization, and BSS clearing."
        ),
        (
            "10. Rollover Test Preload",
            "High-Cycle Preload Methodology",
            "Preloading counters for 32-bit carry propagation and 64-bit rollover tests uses direct testbench hierarchy deposit/force commands in unit testbenches (e.g. dut.preload_count), since running 2^32 clock cycles or instructions in simulation is practically infeasible. Firmware tests focus on functional deltas, threshold hits, and W1C protocols."
        )
    ]

    r_start4 = 5
    for idx, n_row in enumerate(notes_data):
        curr_r = r_start4 + idx
        ws4.append(list(n_row))
        ws4.row_dimensions[curr_r].height = 54
        for c_idx in range(1, len(n_row) + 1):
            c = ws4.cell(curr_r, c_idx)
            c.font = regular_font
            c.border = cell_border
            if c_idx == 1:
                c.font = bold_font
                c.alignment = align_left
            elif c_idx == 2:
                c.font = bold_font
                c.alignment = align_left
            else:
                c.alignment = align_left

    col_widths4 = {
        "A": 28.0,
        "B": 36.0,
        "C": 105.0
    }
    for col_letter, width in col_widths4.items():
        ws4.column_dimensions[col_letter].width = width

    # Save workbook
    output_path = "testplan_soc_hpm.xlsx"
    wb.save(output_path)
    print(f"Successfully generated updated and authoritative testplan: {output_path}")

if __name__ == "__main__":
    build_testplan()
