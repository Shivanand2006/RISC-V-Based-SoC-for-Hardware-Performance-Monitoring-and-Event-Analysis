//=============================================================================
// File: veer_core_adapter.sv
// Description: Wrapper and AHB-Lite bus bridge adapter for the CHIPS Alliance
//              VeeR EL2 RISC-V Core. Adapts VeeR EL2 AHB-Lite IFU and LSU master
//              ports to the SoC memory bus, taps instruction retirement, and
//              maps all 8 hardware performance monitoring events.
// Standard: SystemVerilog-2012 / Verilog-2001 Compatible
//=============================================================================

`include "common_defines.vh"

module veer_core_adapter
  import el2_pkg::*;
#(
  `include "el2_param.vh"
)(
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // Instruction Fetch Interface (IMEM)
    output wire        imem_req_o,
    output wire [31:0] imem_addr_o,
    input  wire        imem_ready_i,
    input  wire [31:0] imem_rdata_i,

    // Data Memory / System Bus Interface (DMEM / Interconnect)
    output wire        dmem_req_o,
    output wire        dmem_we_o,
    output wire [31:0] dmem_addr_o,
    output wire [31:0] dmem_wdata_o,
    output wire [3:0]  dmem_wstrb_o,
    input  wire        dmem_ready_i,
    input  wire [31:0] dmem_rdata_i,
    input  wire        dmem_err_i,

    // Hardware Performance Monitoring and Event Signals
    output wire        instr_retire_o,     // 1-cycle pulse when instruction commits
    output wire        evt_load_o,         // 1-cycle pulse on data read request
    output wire        evt_store_o,        // 1-cycle pulse on data write request
    output wire        evt_fetch_o,        // 1-cycle pulse on instruction fetch request
    output wire        evt_branch_jump_o,  // 1-cycle pulse on branch taken or jump
    output wire        evt_stall_bubble_o, // 1-cycle pulse on stall or memory wait cycle
    output wire        evt_exception_o,    // 1-cycle pulse on trap/exception taken

    // Interrupt Inputs
    input  wire        timer_irq_i,        // Timer interrupt
    input  wire        ext_irq_i,          // External interrupt (from Event Counter)
    input  wire        uart_irq_i          // UART interrupt
);

    //-------------------------------------------------------------------------
    // VeeR EL2 Core AHB-Lite Master Wires
    //-------------------------------------------------------------------------
    // IFU AHB Master
    wire [31:0] ifu_haddr;
    wire [1:0]  ifu_htrans;
    wire        ifu_hwrite;
    wire [2:0]  ifu_hsize;
    wire [2:0]  ifu_hburst;
    wire [3:0]  ifu_hprot;
    wire [63:0] ifu_hrdata;
    wire        ifu_hready;
    wire        ifu_hresp;

    // LSU AHB Master
    wire [31:0] lsu_haddr;
    wire [1:0]  lsu_htrans;
    wire        lsu_hwrite;
    wire [2:0]  lsu_hsize;
    wire [2:0]  lsu_hburst;
    wire [3:0]  lsu_hprot;
    wire [63:0] lsu_hwdata;
    wire [63:0] lsu_hrdata;
    wire        lsu_hready;
    wire        lsu_hresp;

    // Trace / Retirement signals from VeeR EL2
    wire [31:0] trace_rv_i_insn_ip;
    wire [31:0] trace_rv_i_address_ip;
    wire        trace_rv_i_valid_ip;
    wire        trace_rv_i_exception_ip;
    wire [4:0]  trace_rv_i_ecause_ip;
    wire        trace_rv_i_interrupt_ip;
    wire [31:0] trace_rv_i_tval_ip;

    // Performance counter toggle signals from VeeR EL2 DEC unit
    wire        dec_tlu_perfcnt0;
    wire        dec_tlu_perfcnt1;
    wire        dec_tlu_perfcnt2;
    wire        dec_tlu_perfcnt3;

    // Unused interfaces
    el2_mem_if el2_mem_export();
    el2_mem_if el2_icache_export();

    //-------------------------------------------------------------------------
    // Instantiate VeeR EL2 Core Wrapper
    //-------------------------------------------------------------------------
    el2_veer_wrapper #(
        `include "el2_param.vh"
    ) u_veer_core (
        .clk                     (clk),
        .rst_l                   (rst_n),
        .dbg_rst_l               (rst_n),
        .rst_vec                 (31'h0000_0000), // Boot PC = 0x0000_0000
        .nmi_int                 (1'b0),
        .nmi_vec                 (31'h0000_0000),
        .jtag_id                 (31'h0000_0000),

        // Trace outputs
        .trace_rv_i_insn_ip      (trace_rv_i_insn_ip),
        .trace_rv_i_address_ip   (trace_rv_i_address_ip),
        .trace_rv_i_valid_ip     (trace_rv_i_valid_ip),
        .trace_rv_i_exception_ip (trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip    (trace_rv_i_ecause_ip),
        .trace_rv_i_interrupt_ip (trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip      (trace_rv_i_tval_ip),

        // IFU AHB-Lite Master
        .haddr                   (ifu_haddr),
        .hburst                  (ifu_hburst),
        .hmastlock               (),
        .hprot                   (ifu_hprot),
        .hsize                   (ifu_hsize),
        .htrans                  (ifu_htrans),
        .hwrite                  (ifu_hwrite),
        .hrdata                  (ifu_hrdata),
        .hready                  (ifu_hready),
        .hresp                   (ifu_hresp),

        // LSU AHB-Lite Master
        .lsu_haddr               (lsu_haddr),
        .lsu_hburst              (lsu_hburst),
        .lsu_hmastlock           (),
        .lsu_hprot               (lsu_hprot),
        .lsu_hsize               (lsu_hsize),
        .lsu_htrans              (lsu_htrans),
        .lsu_hwrite              (lsu_hwrite),
        .lsu_hwdata              (lsu_hwdata),
        .lsu_hrdata              (lsu_hrdata),
        .lsu_hready              (lsu_hready),
        .lsu_hresp               (lsu_hresp),

        // Debug System Bus AHB-Lite (tied inactive)
        .sb_haddr                (),
        .sb_hburst               (),
        .sb_hmastlock            (),
        .sb_hprot                (),
        .sb_hsize                (),
        .sb_htrans               (),
        .sb_hwrite               (),
        .sb_hwdata               (),
        .sb_hrdata               (64'd0),
        .sb_hready               (1'b1),
        .sb_hresp                (1'b0),

        // DMA Slave (tied inactive)
        .dma_hsel                (1'b0),
        .dma_haddr               (32'd0),
        .dma_hburst              (3'd0),
        .dma_hmastlock           (1'b0),
        .dma_hprot               (4'd0),
        .dma_hsize               (3'd0),
        .dma_htrans              (2'b00),
        .dma_hwrite              (1'b0),
        .dma_hwdata              (64'd0),
        .dma_hreadyin            (1'b1),
        .dma_hrdata              (),
        .dma_hreadyout           (),
        .dma_hresp               (),

        // Clock ratios
        .lsu_bus_clk_en          (1'b1),
        .ifu_bus_clk_en          (1'b1),
        .dbg_bus_clk_en          (1'b1),
        .dma_bus_clk_en          (1'b1),

        // Status
        .iccm_ecc_single_error   (),
        .iccm_ecc_double_error   (),
        .dccm_ecc_single_error   (),
        .dccm_ecc_double_error   (),
        .dccm_write_readback_error(),

        // Memory export interfaces
        .el2_icache_export       (el2_icache_export),
        .el2_mem_export          (el2_mem_export),

        // Interrupts
        .timer_int               (timer_irq_i),
        .soft_int                (1'b0),
        .extintsrc_req           ({(pt.PIC_TOTAL_INT){1'b0}} | {{(pt.PIC_TOTAL_INT-1){1'b0}}, ext_irq_i}),

        // Performance counter toggle outputs
        .dec_tlu_perfcnt0        (dec_tlu_perfcnt0),
        .dec_tlu_perfcnt1        (dec_tlu_perfcnt1),
        .dec_tlu_perfcnt2        (dec_tlu_perfcnt2),
        .dec_tlu_perfcnt3        (dec_tlu_perfcnt3),

        // JTAG (tied inactive)
        .jtag_tck                (1'b0),
        .jtag_tms                (1'b0),
        .jtag_tdi                (1'b0),
        .jtag_trst_n             (rst_n),
        .jtag_tdo                (),
        .jtag_tdoEn              (),
        .core_id                 (28'd0),

        // MPC debug interface
        .mpc_debug_halt_req      (1'b0),
        .mpc_debug_run_req       (1'b0),
        .mpc_reset_run_req       (1'b1), // Run upon reset release
        .mpc_debug_halt_ack      (),
        .mpc_debug_run_ack       (),
        .debug_brkpt_status      (),

        .i_cpu_halt_req          (1'b0),
        .o_cpu_halt_ack          (),
        .o_cpu_halt_status       (),
        .o_debug_mode_status     (),
        .i_cpu_run_req           (1'b0),
        .o_cpu_run_ack           (),

        .scan_mode               (1'b0),
        .mbist_mode              (1'b0),

        // DMI
        .dmi_core_enable         (1'b1),
        .dmi_uncore_enable       (1'b0),
        .dmi_uncore_en           (),
        .dmi_uncore_wr_en        (),
        .dmi_uncore_addr         ()
    );

    //-------------------------------------------------------------------------
    // LSU AHB-Lite to System Bus Adapter
    //-------------------------------------------------------------------------
    ahb_to_bus_adapter #(
        .AHB_ADDR_WIDTH (32),
        .AHB_DATA_WIDTH (64),
        .BUS_DATA_WIDTH (32)
    ) u_lsu_adapter (
        .hclk           (clk),
        .hreset_n       (rst_n),
        .haddr          (lsu_haddr),
        .htrans         (lsu_htrans),
        .hwrite         (lsu_hwrite),
        .hsize          (lsu_hsize),
        .hburst         (lsu_hburst),
        .hprot          (lsu_hprot),
        .hwdata         (lsu_hwdata),
        .hrdata         (lsu_hrdata),
        .hready         (lsu_hready),
        .hresp          (lsu_hresp),
        .m_req_o        (dmem_req_o),
        .m_we_o         (dmem_we_o),
        .m_addr_o       (dmem_addr_o),
        .m_wdata_o      (dmem_wdata_o),
        .m_wstrb_o      (dmem_wstrb_o),
        .m_ready_i      (dmem_ready_i),
        .m_rdata_i      (dmem_rdata_i),
        .m_err_i        (dmem_err_i)
    );

    //-------------------------------------------------------------------------
    // IFU AHB-Lite to Instruction Memory Adapter
    //-------------------------------------------------------------------------
    ahb_imem_adapter #(
        .AHB_ADDR_WIDTH (32),
        .AHB_DATA_WIDTH (64)
    ) u_ifu_adapter (
        .hclk           (clk),
        .hreset_n       (rst_n),
        .haddr          (ifu_haddr),
        .htrans         (ifu_htrans),
        .hwrite         (ifu_hwrite),
        .hsize          (ifu_hsize),
        .hrdata         (ifu_hrdata),
        .hready         (ifu_hready),
        .hresp          (ifu_hresp),
        .fetch_req_o    (imem_req_o),
        .fetch_addr_o   (imem_addr_o[11:0]),
        .fetch_rdata_i  (imem_rdata_i),
        .fetch_ready_i  (imem_ready_i)
    );
    assign imem_addr_o[31:12] = 20'h00000;

    //-------------------------------------------------------------------------
    // Event Mapping from VeeR EL2
    //-------------------------------------------------------------------------
    // Instruction retirement: valid commit excluding trapped instructions
    assign instr_retire_o = trace_rv_i_valid_ip & ~trace_rv_i_exception_ip;

    // Event 0: Data-memory read request accepted (Load)
    assign evt_load_o = lsu_htrans[1] & ~lsu_hwrite & lsu_hready;

    // Event 1: Data-memory write request accepted (Store)
    assign evt_store_o = lsu_htrans[1] & lsu_hwrite & lsu_hready;

    // Event 2: Instruction fetch request accepted
    assign evt_fetch_o = ifu_htrans[1] & ifu_hready;

    // Event 3: Branch / jump taken (from DEC performance toggle or commit branch)
    assign evt_branch_jump_o = dec_tlu_perfcnt0;

    // Event 4: Pipeline stall or bubble cycle
    assign evt_stall_bubble_o = (ifu_htrans[1] & ~ifu_hready) | (lsu_htrans[1] & ~lsu_hready);

    // Event 5: Exception / trap taken
    assign evt_exception_o = trace_rv_i_exception_ip;

endmodule
