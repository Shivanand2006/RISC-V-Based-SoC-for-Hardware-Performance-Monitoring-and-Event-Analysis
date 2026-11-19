//=============================================================================
// File: bus_decoder.v
// Description: Central address decoder and bus interconnect for the RISC-V SoC.
//              Decodes 32-bit addresses into peripheral windows and maps lower
//              offset bits to each peripheral. Unmapped addresses return an
//              error response without hanging.
// Standard: Synthesizable Verilog-2001
//=============================================================================

`include "interconnect_defines.vh"

module bus_decoder #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = 4
)(
    // Clock and Reset
    input  wire                  clk,
    input  wire                  rst_n,

    // Master Interface (from Core)
    input  wire                  m_req_i,
    input  wire                  m_we_i,
    input  wire [ADDR_WIDTH-1:0] m_addr_i,
    input  wire [DATA_WIDTH-1:0] m_wdata_i,
    input  wire [STRB_WIDTH-1:0] m_wstrb_i,
    output reg                   m_ready_o,
    output reg  [DATA_WIDTH-1:0] m_rdata_o,
    output reg                   m_err_o,

    // Slave 0: Instruction Memory (0x0000_0000 - 0x0000_0FFF)
    output wire                  imem_req_o,
    output wire                  imem_we_o,
    output wire [11:0]           imem_addr_o,
    output wire [DATA_WIDTH-1:0] imem_wdata_o,
    output wire [STRB_WIDTH-1:0] imem_wstrb_o,
    input  wire                  imem_ready_i,
    input  wire [DATA_WIDTH-1:0] imem_rdata_i,
    input  wire                  imem_err_i,

    // Slave 1: Data Memory (0x0000_1000 - 0x0000_1FFF)
    output wire                  dmem_req_o,
    output wire                  dmem_we_o,
    output wire [11:0]           dmem_addr_o,
    output wire [DATA_WIDTH-1:0] dmem_wdata_o,
    output wire [STRB_WIDTH-1:0] dmem_wstrb_o,
    input  wire                  dmem_ready_i,
    input  wire [DATA_WIDTH-1:0] dmem_rdata_i,
    input  wire                  dmem_err_i,

    // Slave 2: UART (0x0000_2000 - 0x0000_20FF)
    output wire                  uart_req_o,
    output wire                  uart_we_o,
    output wire [7:0]            uart_addr_o,
    output wire [DATA_WIDTH-1:0] uart_wdata_o,
    output wire [STRB_WIDTH-1:0] uart_wstrb_o,
    input  wire                  uart_ready_i,
    input  wire [DATA_WIDTH-1:0] uart_rdata_i,
    input  wire                  uart_err_i,

    // Slave 3: Timer (0x0000_2100 - 0x0000_21FF)
    output wire                  timer_req_o,
    output wire                  timer_we_o,
    output wire [7:0]            timer_addr_o,
    output wire [DATA_WIDTH-1:0] timer_wdata_o,
    output wire [STRB_WIDTH-1:0] timer_wstrb_o,
    input  wire                  timer_ready_i,
    input  wire [DATA_WIDTH-1:0] timer_rdata_i,
    input  wire                  timer_err_i,

    // Slave 4: GPIO (0x0000_2200 - 0x0000_22FF)
    output wire                  gpio_req_o,
    output wire                  gpio_we_o,
    output wire [7:0]            gpio_addr_o,
    output wire [DATA_WIDTH-1:0] gpio_wdata_o,
    output wire [STRB_WIDTH-1:0] gpio_wstrb_o,
    input  wire                  gpio_ready_i,
    input  wire [DATA_WIDTH-1:0] gpio_rdata_i,
    input  wire                  gpio_err_i,

    // Slave 5: Cycle Counter (0x0000_2300 - 0x0000_23FF)
    output wire                  cycle_cnt_req_o,
    output wire                  cycle_cnt_we_o,
    output wire [7:0]            cycle_cnt_addr_o,
    output wire [DATA_WIDTH-1:0] cycle_cnt_wdata_o,
    output wire [STRB_WIDTH-1:0] cycle_cnt_wstrb_o,
    input  wire                  cycle_cnt_ready_i,
    input  wire [DATA_WIDTH-1:0] cycle_cnt_rdata_i,
    input  wire                  cycle_cnt_err_i,

    // Slave 6: Instruction Counter (0x0000_2400 - 0x0000_24FF)
    output wire                  instr_cnt_req_o,
    output wire                  instr_cnt_we_o,
    output wire [7:0]            instr_cnt_addr_o,
    output wire [DATA_WIDTH-1:0] instr_cnt_wdata_o,
    output wire [STRB_WIDTH-1:0] instr_cnt_wstrb_o,
    input  wire                  instr_cnt_ready_i,
    input  wire [DATA_WIDTH-1:0] instr_cnt_rdata_i,
    input  wire                  instr_cnt_err_i,

    // Slave 7: Performance Event Counter (0x0000_2500 - 0x0000_25FF)
    output wire                  event_cnt_req_o,
    output wire                  event_cnt_we_o,
    output wire [7:0]            event_cnt_addr_o,
    output wire [DATA_WIDTH-1:0] event_cnt_wdata_o,
    output wire [STRB_WIDTH-1:0] event_cnt_wstrb_o,
    input  wire                  event_cnt_ready_i,
    input  wire [DATA_WIDTH-1:0] event_cnt_rdata_i,
    input  wire                  event_cnt_err_i
);

    // Address decode hit wires
    wire hit_imem      = (m_addr_i[31:12] == 20'h00000);
    wire hit_dmem      = (m_addr_i[31:12] == 20'h00001);
    wire hit_periph_pg = (m_addr_i[31:12] == 20'h00002);

    wire hit_uart      = hit_periph_pg && (m_addr_i[11:8] == 4'h0);
    wire hit_timer     = hit_periph_pg && (m_addr_i[11:8] == 4'h1);
    wire hit_gpio      = hit_periph_pg && (m_addr_i[11:8] == 4'h2);
    wire hit_cycle_cnt = hit_periph_pg && (m_addr_i[11:8] == 4'h3);
    wire hit_instr_cnt = hit_periph_pg && (m_addr_i[11:8] == 4'h4);
    wire hit_event_cnt = hit_periph_pg && (m_addr_i[11:8] == 4'h5);

    wire hit_unmapped  = ~(hit_imem      |
                           hit_dmem      |
                           hit_uart      |
                           hit_timer     |
                           hit_gpio      |
                           hit_cycle_cnt |
                           hit_instr_cnt |
                           hit_event_cnt);

    // Slave Request signals
    assign imem_req_o      = m_req_i & hit_imem;
    assign dmem_req_o      = m_req_i & hit_dmem;
    assign uart_req_o      = m_req_i & hit_uart;
    assign timer_req_o     = m_req_i & hit_timer;
    assign gpio_req_o      = m_req_i & hit_gpio;
    assign cycle_cnt_req_o = m_req_i & hit_cycle_cnt;
    assign instr_cnt_req_o = m_req_i & hit_instr_cnt;
    assign event_cnt_req_o = m_req_i & hit_event_cnt;

    // Common write control and data broadcast
    assign imem_we_o      = m_we_i;
    assign dmem_we_o      = m_we_i;
    assign uart_we_o      = m_we_i;
    assign timer_we_o     = m_we_i;
    assign gpio_we_o      = m_we_i;
    assign cycle_cnt_we_o = m_we_i;
    assign instr_cnt_we_o = m_we_i;
    assign event_cnt_we_o = m_we_i;

    assign imem_wdata_o      = m_wdata_i;
    assign dmem_wdata_o      = m_wdata_i;
    assign uart_wdata_o      = m_wdata_i;
    assign timer_wdata_o     = m_wdata_i;
    assign gpio_wdata_o      = m_wdata_i;
    assign cycle_cnt_wdata_o = m_wdata_i;
    assign instr_cnt_wdata_o = m_wdata_i;
    assign event_cnt_wdata_o = m_wdata_i;

    assign imem_wstrb_o      = m_wstrb_i;
    assign dmem_wstrb_o      = m_wstrb_i;
    assign uart_wstrb_o      = m_wstrb_i;
    assign timer_wstrb_o     = m_wstrb_i;
    assign gpio_wstrb_o      = m_wstrb_i;
    assign cycle_cnt_wstrb_o = m_wstrb_i;
    assign instr_cnt_wstrb_o = m_wstrb_i;
    assign event_cnt_wstrb_o = m_wstrb_i;

    // Slave address routing: memories see 12-bit offsets, peripherals see 8-bit offsets
    assign imem_addr_o      = m_addr_i[11:0];
    assign dmem_addr_o      = m_addr_i[11:0];
    assign uart_addr_o      = m_addr_i[7:0];
    assign timer_addr_o     = m_addr_i[7:0];
    assign gpio_addr_o      = m_addr_i[7:0];
    assign cycle_cnt_addr_o = m_addr_i[7:0];
    assign instr_cnt_addr_o = m_addr_i[7:0];
    assign event_cnt_addr_o = m_addr_i[7:0];

    // Master Response Multiplexer
    always @(*) begin
        if (hit_imem) begin
            m_ready_o = imem_ready_i;
            m_rdata_o = imem_rdata_i;
            m_err_o   = imem_err_i;
        end else if (hit_dmem) begin
            m_ready_o = dmem_ready_i;
            m_rdata_o = dmem_rdata_i;
            m_err_o   = dmem_err_i;
        end else if (hit_uart) begin
            m_ready_o = uart_ready_i;
            m_rdata_o = uart_rdata_i;
            m_err_o   = uart_err_i;
        end else if (hit_timer) begin
            m_ready_o = timer_ready_i;
            m_rdata_o = timer_rdata_i;
            m_err_o   = timer_err_i;
        end else if (hit_gpio) begin
            m_ready_o = gpio_ready_i;
            m_rdata_o = gpio_rdata_i;
            m_err_o   = gpio_err_i;
        end else if (hit_cycle_cnt) begin
            m_ready_o = cycle_cnt_ready_i;
            m_rdata_o = cycle_cnt_rdata_i;
            m_err_o   = cycle_cnt_err_i;
        end else if (hit_instr_cnt) begin
            m_ready_o = instr_cnt_ready_i;
            m_rdata_o = instr_cnt_rdata_i;
            m_err_o   = instr_cnt_err_i;
        end else if (hit_event_cnt) begin
            m_ready_o = event_cnt_ready_i;
            m_rdata_o = event_cnt_rdata_i;
            m_err_o   = event_cnt_err_i;
        end else begin
            // Unmapped address: immediate completion with error response
            m_ready_o = m_req_i;
            m_rdata_o = 32'd0;
            m_err_o   = m_req_i; // 1 = error when requested
        end
    end

endmodule
