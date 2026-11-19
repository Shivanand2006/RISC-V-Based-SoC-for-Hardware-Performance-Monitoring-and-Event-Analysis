// =============================================================================
// File        : hpm_soc_if.sv
// Description : SystemVerilog interface for HPM SoC – top-level bus,
//               event inputs, instr_retire, GPIO, and UART signals.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef HPM_SOC_IF_SV
`define HPM_SOC_IF_SV

interface hpm_soc_if (input logic clk, input logic rst_n);

  // ---------------------------------------------------------------------------
  // Bus Master Interface Signals
  // ---------------------------------------------------------------------------
  logic        bus_req;
  logic        bus_we;
  logic [31:0] bus_addr;
  logic [31:0] bus_wdata;
  logic [3:0]  bus_wstrb;
  logic        bus_ready;
  logic [31:0] bus_rdata;
  logic        bus_err;

  // ---------------------------------------------------------------------------
  // HPM Event Inputs (8 events)
  // ---------------------------------------------------------------------------
  logic        load_event;        // Event 0: Load
  logic        store_event;       // Event 1: Store
  logic        fetch_event;       // Event 2: Fetch
  logic        branch_jump_event; // Event 3: Branch/Jump
  logic        stall_event;       // Event 4: Stall
  logic        exception_event;   // Event 5: Exception
  logic        timer_tick_event;  // Event 6: Timer Tick
  logic        uart_tx_done_event;// Event 7: UART TX Done

  // Convenience packed event vector
  logic [7:0]  events_in;

  assign events_in = {uart_tx_done_event, timer_tick_event, exception_event,
                      stall_event, branch_jump_event, fetch_event,
                      store_event, load_event};

  // ---------------------------------------------------------------------------
  // Instruction Retire Signal
  // ---------------------------------------------------------------------------
  logic        instr_retire;

  // ---------------------------------------------------------------------------
  // GPIO Signals
  // ---------------------------------------------------------------------------
  logic [7:0]  gpio_in;
  logic [7:0]  gpio_out;

  // ---------------------------------------------------------------------------
  // UART Signals
  // ---------------------------------------------------------------------------
  logic        uart_tx;
  logic        uart_rx;

  // ---------------------------------------------------------------------------
  // IRQ output from Event Counter
  // ---------------------------------------------------------------------------
  logic        irq_o;

  // ---------------------------------------------------------------------------
  // Clocking Block – synchronous sampling with 1-step input delay
  // ---------------------------------------------------------------------------
  clocking cb @(posedge clk);
    default input #1step output #1ns;

    // Bus signals
    output bus_req;
    output bus_we;
    output bus_addr;
    output bus_wdata;
    output bus_wstrb;
    input  bus_ready;
    input  bus_rdata;
    input  bus_err;

    // Event inputs (driven by testbench)
    output load_event;
    output store_event;
    output fetch_event;
    output branch_jump_event;
    output stall_event;
    output exception_event;
    output timer_tick_event;
    output uart_tx_done_event;

    // Instruction retire
    output instr_retire;

    // GPIO
    output gpio_in;
    input  gpio_out;

    // UART
    input  uart_tx;
    output uart_rx;

    // IRQ
    input  irq_o;
  endclocking : cb

  // ---------------------------------------------------------------------------
  // Modport: Master (Driver side – testbench drives bus as master)
  // ---------------------------------------------------------------------------
  modport master (
    clocking cb,
    input  clk,
    input  rst_n,
    output bus_req,
    output bus_we,
    output bus_addr,
    output bus_wdata,
    output bus_wstrb,
    input  bus_ready,
    input  bus_rdata,
    input  bus_err,
    output load_event,
    output store_event,
    output fetch_event,
    output branch_jump_event,
    output stall_event,
    output exception_event,
    output timer_tick_event,
    output uart_tx_done_event,
    output instr_retire,
    output gpio_in,
    input  gpio_out,
    input  uart_tx,
    output uart_rx,
    input  irq_o
  );

  // ---------------------------------------------------------------------------
  // Modport: Slave (DUT side – for connecting DUT ports)
  // ---------------------------------------------------------------------------
  modport slave (
    input  clk,
    input  rst_n,
    input  bus_req,
    input  bus_we,
    input  bus_addr,
    input  bus_wdata,
    input  bus_wstrb,
    output bus_ready,
    output bus_rdata,
    output bus_err,
    input  load_event,
    input  store_event,
    input  fetch_event,
    input  branch_jump_event,
    input  stall_event,
    input  exception_event,
    input  timer_tick_event,
    input  uart_tx_done_event,
    input  instr_retire,
    input  gpio_in,
    output gpio_out,
    output uart_tx,
    input  uart_rx,
    output irq_o
  );

  // ---------------------------------------------------------------------------
  // Modport: Monitor (passive observation – all signals are inputs)
  // ---------------------------------------------------------------------------
  modport monitor (
    clocking cb,
    input  clk,
    input  rst_n,
    input  bus_req,
    input  bus_we,
    input  bus_addr,
    input  bus_wdata,
    input  bus_wstrb,
    input  bus_ready,
    input  bus_rdata,
    input  bus_err,
    input  load_event,
    input  store_event,
    input  fetch_event,
    input  branch_jump_event,
    input  stall_event,
    input  exception_event,
    input  timer_tick_event,
    input  uart_tx_done_event,
    input  instr_retire,
    input  gpio_in,
    input  gpio_out,
    input  uart_tx,
    input  uart_rx,
    input  irq_o
  );

endinterface : hpm_soc_if

`endif // HPM_SOC_IF_SV
