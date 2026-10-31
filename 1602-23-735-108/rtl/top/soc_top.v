//=============================================================================
// File: soc_top.v
// Description: Top-level RISC-V SoC integrating the processor core, instruction
//              and data memories, central address decoder, UART, Timer, GPIO,
//              and three dedicated Hardware Performance Monitor IPs:
//              1. Cycle Counter
//              2. Instruction Counter
//              3. Performance Event Counter
// Standard: Synthesizable Verilog-2001
//=============================================================================

module soc_top #(
    parameter HEX_FILE = ""
)(
    // Clock and Reset
    input  wire       clk,
    input  wire       rst_n,

    // UART serial interface
    input  wire       uart_rx,
    output wire       uart_tx,

    // GPIO pins
    input  wire [7:0] gpio_in,
    output wire [7:0] gpio_out
);

    //-------------------------------------------------------------------------
    // Core Signals
    //-------------------------------------------------------------------------
    wire        core_imem_req;
    wire [31:0] core_imem_addr;
    wire        core_imem_ready;
    wire [31:0] core_imem_rdata;

    wire        core_dmem_req;
    wire        core_dmem_we;
    wire [31:0] core_dmem_addr;
    wire [31:0] core_dmem_wdata;
    wire [3:0]  core_dmem_wstrb;
    wire        core_dmem_ready;
    wire [31:0] core_dmem_rdata;
    wire        core_dmem_err;

    wire        core_instr_retire;
    wire        core_evt_load;
    wire        core_evt_store;
    wire        core_evt_fetch;
    wire        core_evt_branch_jump;
    wire        core_evt_stall_bubble;
    wire        core_evt_exception;

    wire        timer_tick;
    wire        uart_tx_done;
    wire        uart_irq;
    wire        event_cnt_irq;

    // Events bus connected to Event Counter
    wire [7:0]  events;
    assign events[0] = core_evt_load;
    assign events[1] = core_evt_store;
    assign events[2] = core_evt_fetch;
    assign events[3] = core_evt_branch_jump;
    assign events[4] = core_evt_stall_bubble;
    assign events[5] = core_evt_exception;
    assign events[6] = timer_tick;
    assign events[7] = uart_tx_done;

    //-------------------------------------------------------------------------
    // Interconnect / Decoder Signals
    //-------------------------------------------------------------------------
    // IMEM Bus Port
    wire        imem_bus_req;
    wire        imem_bus_we;
    wire [11:0] imem_bus_addr;
    wire [31:0] imem_bus_wdata;
    wire [3:0]  imem_bus_wstrb;
    wire        imem_bus_ready;
    wire [31:0] imem_bus_rdata;
    wire        imem_bus_err;

    // DMEM Bus Port
    wire        dmem_bus_req;
    wire        dmem_bus_we;
    wire [11:0] dmem_bus_addr;
    wire [31:0] dmem_bus_wdata;
    wire [3:0]  dmem_bus_wstrb;
    wire        dmem_bus_ready;
    wire [31:0] dmem_bus_rdata;
    wire        dmem_bus_err;

    // UART Bus Port
    wire        uart_bus_req;
    wire        uart_bus_we;
    wire [7:0]  uart_bus_addr;
    wire [31:0] uart_bus_wdata;
    wire [3:0]  uart_bus_wstrb;
    wire        uart_bus_ready;
    wire [31:0] uart_bus_rdata;
    wire        uart_bus_err;

    // Timer Bus Port
    wire        timer_bus_req;
    wire        timer_bus_we;
    wire [7:0]  timer_bus_addr;
    wire [31:0] timer_bus_wdata;
    wire [3:0]  timer_bus_wstrb;
    wire        timer_bus_ready;
    wire [31:0] timer_bus_rdata;
    wire        timer_bus_err;

    // GPIO Bus Port
    wire        gpio_bus_req;
    wire        gpio_bus_we;
    wire [7:0]  gpio_bus_addr;
    wire [31:0] gpio_bus_wdata;
    wire [3:0]  gpio_bus_wstrb;
    wire        gpio_bus_ready;
    wire [31:0] gpio_bus_rdata;
    wire        gpio_bus_err;

    // Cycle Counter Bus Port
    wire        cycle_cnt_bus_req;
    wire        cycle_cnt_bus_we;
    wire [7:0]  cycle_cnt_bus_addr;
    wire [31:0] cycle_cnt_bus_wdata;
    wire [3:0]  cycle_cnt_bus_wstrb;
    wire        cycle_cnt_bus_ready;
    wire [31:0] cycle_cnt_bus_rdata;
    wire        cycle_cnt_bus_err;

    // Instruction Counter Bus Port
    wire        instr_cnt_bus_req;
    wire        instr_cnt_bus_we;
    wire [7:0]  instr_cnt_bus_addr;
    wire [31:0] instr_cnt_bus_wdata;
    wire [3:0]  instr_cnt_bus_wstrb;
    wire        instr_cnt_bus_ready;
    wire [31:0] instr_cnt_bus_rdata;
    wire        instr_cnt_bus_err;

    // Event Counter Bus Port
    wire        event_cnt_bus_req;
    wire        event_cnt_bus_we;
    wire [7:0]  event_cnt_bus_addr;
    wire [31:0] event_cnt_bus_wdata;
    wire [3:0]  event_cnt_bus_wstrb;
    wire        event_cnt_bus_ready;
    wire [31:0] event_cnt_bus_rdata;
    wire        event_cnt_bus_err;

    //-------------------------------------------------------------------------
    // Core Instance
    //-------------------------------------------------------------------------
    riscv_core #(
        .RESET_VEC          (32'h0000_0000)
    ) u_riscv_core (
        .clk                (clk),
        .rst_n              (rst_n),
        .imem_req_o         (core_imem_req),
        .imem_addr_o        (core_imem_addr),
        .imem_ready_i       (core_imem_ready),
        .imem_rdata_i       (core_imem_rdata),
        .dmem_req_o         (core_dmem_req),
        .dmem_we_o          (core_dmem_we),
        .dmem_addr_o        (core_dmem_addr),
        .dmem_wdata_o       (core_dmem_wdata),
        .dmem_wstrb_o       (core_dmem_wstrb),
        .dmem_ready_i       (core_dmem_ready),
        .dmem_rdata_i       (core_dmem_rdata),
        .dmem_err_i         (core_dmem_err),
        .instr_retire_o     (core_instr_retire),
        .evt_load_o         (core_evt_load),
        .evt_store_o        (core_evt_store),
        .evt_fetch_o        (core_evt_fetch),
        .evt_branch_jump_o  (core_evt_branch_jump),
        .evt_stall_bubble_o (core_evt_stall_bubble),
        .evt_exception_o    (core_evt_exception),
        .timer_irq_i        (timer_tick),
        .ext_irq_i          (event_cnt_irq),
        .uart_irq_i         (uart_irq)
    );

    //-------------------------------------------------------------------------
    // Instruction Memory Instance (4 KB)
    //-------------------------------------------------------------------------
    imem #(
        .MEM_SIZE_BYTES     (4096),
        .ADDR_WIDTH         (12),
        .HEX_FILE           (HEX_FILE)
    ) u_imem (
        .clk                (clk),
        .rst_n              (rst_n),
        .fetch_req_i        (core_imem_req),
        .fetch_addr_i       (core_imem_addr[11:0]),
        .fetch_rdata_o      (core_imem_rdata),
        .fetch_ready_o      (core_imem_ready),
        .bus_req_i          (imem_bus_req),
        .bus_we_i           (imem_bus_we),
        .bus_addr_i         (imem_bus_addr),
        .bus_wdata_i        (imem_bus_wdata),
        .bus_wstrb_i        (imem_bus_wstrb),
        .bus_ready_o        (imem_bus_ready),
        .bus_rdata_o        (imem_bus_rdata),
        .bus_err_o          (imem_bus_err)
    );

    //-------------------------------------------------------------------------
    // Data Memory Instance (4 KB)
    //-------------------------------------------------------------------------
    dmem #(
        .MEM_SIZE_BYTES     (4096),
        .ADDR_WIDTH         (12)
    ) u_dmem (
        .clk                (clk),
        .rst_n              (rst_n),
        .bus_req_i          (dmem_bus_req),
        .bus_we_i           (dmem_bus_we),
        .bus_addr_i         (dmem_bus_addr),
        .bus_wdata_i        (dmem_bus_wdata),
        .bus_wstrb_i        (dmem_bus_wstrb),
        .bus_ready_o        (dmem_bus_ready),
        .bus_rdata_o        (dmem_bus_rdata),
        .bus_err_o          (dmem_bus_err)
    );

    //-------------------------------------------------------------------------
    // Central Address Decoder / Interconnect Instance
    //-------------------------------------------------------------------------
    bus_decoder #(
        .ADDR_WIDTH         (32),
        .DATA_WIDTH         (32)
    ) u_bus_decoder (
        .clk                (clk),
        .rst_n              (rst_n),
        .m_req_i            (core_dmem_req),
        .m_we_i             (core_dmem_we),
        .m_addr_i           (core_dmem_addr),
        .m_wdata_i          (core_dmem_wdata),
        .m_wstrb_i          (core_dmem_wstrb),
        .m_ready_o          (core_dmem_ready),
        .m_rdata_o          (core_dmem_rdata),
        .m_err_o            (core_dmem_err),
        .imem_req_o         (imem_bus_req),
        .imem_we_o          (imem_bus_we),
        .imem_addr_o        (imem_bus_addr),
        .imem_wdata_o       (imem_bus_wdata),
        .imem_wstrb_o       (imem_bus_wstrb),
        .imem_ready_i       (imem_bus_ready),
        .imem_rdata_i       (imem_bus_rdata),
        .imem_err_i         (imem_bus_err),
        .dmem_req_o         (dmem_bus_req),
        .dmem_we_o          (dmem_bus_we),
        .dmem_addr_o        (dmem_bus_addr),
        .dmem_wdata_o       (dmem_bus_wdata),
        .dmem_wstrb_o       (dmem_bus_wstrb),
        .dmem_ready_i       (dmem_bus_ready),
        .dmem_rdata_i       (dmem_bus_rdata),
        .dmem_err_i         (dmem_bus_err),
        .uart_req_o         (uart_bus_req),
        .uart_we_o          (uart_bus_we),
        .uart_addr_o        (uart_bus_addr),
        .uart_wdata_o       (uart_bus_wdata),
        .uart_wstrb_o       (uart_bus_wstrb),
        .uart_ready_i       (uart_bus_ready),
        .uart_rdata_i       (uart_bus_rdata),
        .uart_err_i         (uart_bus_err),
        .timer_req_o        (timer_bus_req),
        .timer_we_o         (timer_bus_we),
        .timer_addr_o       (timer_bus_addr),
        .timer_wdata_o      (timer_bus_wdata),
        .timer_wstrb_o      (timer_bus_wstrb),
        .timer_ready_i      (timer_bus_ready),
        .timer_rdata_i      (timer_bus_rdata),
        .timer_err_i        (timer_bus_err),
        .gpio_req_o         (gpio_bus_req),
        .gpio_we_o          (gpio_bus_we),
        .gpio_addr_o        (gpio_bus_addr),
        .gpio_wdata_o       (gpio_bus_wdata),
        .gpio_wstrb_o       (gpio_bus_wstrb),
        .gpio_ready_i       (gpio_bus_ready),
        .gpio_rdata_i       (gpio_bus_rdata),
        .gpio_err_i         (gpio_bus_err),
        .cycle_cnt_req_o    (cycle_cnt_bus_req),
        .cycle_cnt_we_o     (cycle_cnt_bus_we),
        .cycle_cnt_addr_o   (cycle_cnt_bus_addr),
        .cycle_cnt_wdata_o  (cycle_cnt_bus_wdata),
        .cycle_cnt_wstrb_o  (cycle_cnt_bus_wstrb),
        .cycle_cnt_ready_i  (cycle_cnt_bus_ready),
        .cycle_cnt_rdata_i  (cycle_cnt_bus_rdata),
        .cycle_cnt_err_i    (cycle_cnt_bus_err),
        .instr_cnt_req_o    (instr_cnt_bus_req),
        .instr_cnt_we_o     (instr_cnt_bus_we),
        .instr_cnt_addr_o   (instr_cnt_bus_addr),
        .instr_cnt_wdata_o  (instr_cnt_bus_wdata),
        .instr_cnt_wstrb_o  (instr_cnt_bus_wstrb),
        .instr_cnt_ready_i  (instr_cnt_bus_ready),
        .instr_cnt_rdata_i  (instr_cnt_bus_rdata),
        .instr_cnt_err_i    (instr_cnt_bus_err),
        .event_cnt_req_o    (event_cnt_bus_req),
        .event_cnt_we_o     (event_cnt_bus_we),
        .event_cnt_addr_o   (event_cnt_bus_addr),
        .event_cnt_wdata_o  (event_cnt_bus_wdata),
        .event_cnt_wstrb_o  (event_cnt_bus_wstrb),
        .event_cnt_ready_i  (event_cnt_bus_ready),
        .event_cnt_rdata_i  (event_cnt_bus_rdata),
        .event_cnt_err_i    (event_cnt_bus_err)
    );

    //-------------------------------------------------------------------------
    // UART Peripheral Instance
    //-------------------------------------------------------------------------
    uart_top #(
        .ADDR_WIDTH         (8),
        .DATA_WIDTH         (32),
        .DEFAULT_DIVISOR    (16'd434)
    ) u_uart (
        .clk                (clk),
        .rst_n              (rst_n),
        .uart_rx            (uart_rx),
        .uart_tx            (uart_tx),
        .tx_done_o          (uart_tx_done),
        .irq_o              (uart_irq),
        .bus_req_i          (uart_bus_req),
        .bus_we_i           (uart_bus_we),
        .bus_addr_i         (uart_bus_addr),
        .bus_wdata_i        (uart_bus_wdata),
        .bus_wstrb_i        (uart_bus_wstrb),
        .bus_ready_o        (uart_bus_ready),
        .bus_rdata_o        (uart_bus_rdata),
        .bus_err_o          (uart_bus_err)
    );

    //-------------------------------------------------------------------------
    // Timer Peripheral Instance
    //-------------------------------------------------------------------------
    timer_top #(
        .ADDR_WIDTH         (8),
        .DATA_WIDTH         (32)
    ) u_timer (
        .clk                (clk),
        .rst_n              (rst_n),
        .tick_o             (timer_tick),
        .bus_req_i          (timer_bus_req),
        .bus_we_i           (timer_bus_we),
        .bus_addr_i         (timer_bus_addr),
        .bus_wdata_i        (timer_bus_wdata),
        .bus_wstrb_i        (timer_bus_wstrb),
        .bus_ready_o        (timer_bus_ready),
        .bus_rdata_o        (timer_bus_rdata),
        .bus_err_o          (timer_bus_err)
    );

    //-------------------------------------------------------------------------
    // GPIO Peripheral Instance
    //-------------------------------------------------------------------------
    gpio_top #(
        .ADDR_WIDTH         (8),
        .DATA_WIDTH         (32),
        .GPIO_WIDTH         (8)
    ) u_gpio (
        .clk                (clk),
        .rst_n              (rst_n),
        .gpio_in            (gpio_in),
        .gpio_out           (gpio_out),
        .bus_req_i          (gpio_bus_req),
        .bus_we_i           (gpio_bus_we),
        .bus_addr_i         (gpio_bus_addr),
        .bus_wdata_i        (gpio_bus_wdata),
        .bus_wstrb_i        (gpio_bus_wstrb),
        .bus_ready_o        (gpio_bus_ready),
        .bus_rdata_o        (gpio_bus_rdata),
        .bus_err_o          (gpio_bus_err)
    );

    //-------------------------------------------------------------------------
    // IP 1: Cycle Counter Instance (0x0000_2300)
    //-------------------------------------------------------------------------
    cycle_cnt_top #(
        .ADDR_WIDTH         (8),
        .DATA_WIDTH         (32)
    ) u_cycle_cnt (
        .clk                (clk),
        .rst_n              (rst_n),
        .bus_req_i          (cycle_cnt_bus_req),
        .bus_we_i           (cycle_cnt_bus_we),
        .bus_addr_i         (cycle_cnt_bus_addr),
        .bus_wdata_i        (cycle_cnt_bus_wdata),
        .bus_wstrb_i        (cycle_cnt_bus_wstrb),
        .bus_ready_o        (cycle_cnt_bus_ready),
        .bus_rdata_o        (cycle_cnt_bus_rdata),
        .bus_err_o          (cycle_cnt_bus_err)
    );

    //-------------------------------------------------------------------------
    // IP 2: Instruction Counter Instance (0x0000_2400)
    //-------------------------------------------------------------------------
    instr_cnt_top #(
        .ADDR_WIDTH         (8),
        .DATA_WIDTH         (32),
        .RETIRE_WIDTH       (1)
    ) u_instr_cnt (
        .clk                (clk),
        .rst_n              (rst_n),
        .instr_retire_i     (core_instr_retire),
        .bus_req_i          (instr_cnt_bus_req),
        .bus_we_i           (instr_cnt_bus_we),
        .bus_addr_i         (instr_cnt_bus_addr),
        .bus_wdata_i        (instr_cnt_bus_wdata),
        .bus_wstrb_i        (instr_cnt_bus_wstrb),
        .bus_ready_o        (instr_cnt_bus_ready),
        .bus_rdata_o        (instr_cnt_bus_rdata),
        .bus_err_o          (instr_cnt_bus_err)
    );

    //-------------------------------------------------------------------------
    // IP 3: Performance Event Counter Instance (0x0000_2500)
    //-------------------------------------------------------------------------
    event_cnt_top #(
        .ADDR_WIDTH         (8),
        .DATA_WIDTH         (32),
        .NUM_EVENTS         (8)
    ) u_event_cnt (
        .clk                (clk),
        .rst_n              (rst_n),
        .events_i           (events),
        .irq_o              (event_cnt_irq),
        .bus_req_i          (event_cnt_bus_req),
        .bus_we_i           (event_cnt_bus_we),
        .bus_addr_i         (event_cnt_bus_addr),
        .bus_wdata_i        (event_cnt_bus_wdata),
        .bus_wstrb_i        (event_cnt_bus_wstrb),
        .bus_ready_o        (event_cnt_bus_ready),
        .bus_rdata_o        (event_cnt_bus_rdata),
        .bus_err_o          (event_cnt_bus_err)
    );

endmodule
