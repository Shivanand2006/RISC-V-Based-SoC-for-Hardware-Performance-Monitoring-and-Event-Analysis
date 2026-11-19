//=============================================================================
// File: uart_top.v
// Description: UART peripheral (16550-style subset) with 8N1 TX/RX.
// Standard: Synthesizable Verilog-2001
//=============================================================================

`include "uart_defines.vh"

module uart_top #(
    parameter ADDR_WIDTH      = 8,
    parameter DATA_WIDTH      = 32,
    parameter STRB_WIDTH      = 4,
    parameter DEFAULT_DIVISOR = 16'd434 // ~115200 baud @ 50MHz
)(
    // Clock and Reset
    input  wire                  clk,
    input  wire                  rst_n,

    // Serial lines
    input  wire                  uart_rx,
    output wire                  uart_tx,

    // Status / Event outputs
    output wire                  tx_done_o, // 1-cycle pulse on TX complete (Event 7)
    output wire                  irq_o,     // UART interrupt

    // Bus Slave Interface
    input  wire                  bus_req_i,
    input  wire                  bus_we_i,
    input  wire [ADDR_WIDTH-1:0] bus_addr_i,
    input  wire [DATA_WIDTH-1:0] bus_wdata_i,
    input  wire [STRB_WIDTH-1:0] bus_wstrb_i,
    output wire                  bus_ready_o,
    output wire [DATA_WIDTH-1:0] bus_rdata_o,
    output wire                  bus_err_o
);

    // Internal register interface wires
    wire                  reg_wr_en;
    wire [ADDR_WIDTH-1:0] reg_waddr;
    wire [DATA_WIDTH-1:0] reg_wdata;
    wire [STRB_WIDTH-1:0] reg_wstrb;
    wire                  reg_werr;

    wire                  reg_rd_en;
    wire [ADDR_WIDTH-1:0] reg_raddr;
    reg  [DATA_WIDTH-1:0] reg_rdata;
    wire                  reg_rerr;

    // Instantiate common register slave adapter
    reg_slave_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) u_reg_slave_if (
        .clk        (clk),
        .rst_n      (rst_n),
        .bus_req_i  (bus_req_i),
        .bus_we_i   (bus_we_i),
        .bus_addr_i (bus_addr_i),
        .bus_wdata_i(bus_wdata_i),
        .bus_wstrb_i(bus_wstrb_i),
        .bus_ready_o(bus_ready_o),
        .bus_rdata_o(bus_rdata_o),
        .bus_err_o  (bus_err_o),
        .reg_wr_en  (reg_wr_en),
        .reg_waddr  (reg_waddr),
        .reg_wdata  (reg_wdata),
        .reg_wstrb  (reg_wstrb),
        .reg_werr   (reg_werr),
        .reg_rd_en  (reg_rd_en),
        .reg_raddr  (reg_raddr),
        .reg_rdata  (reg_rdata),
        .reg_rerr   (reg_rerr)
    );

    // Registers
    reg [7:0]  rbr_q;
    reg [7:0]  thr_q;
    reg [7:0]  ier_q;
    reg [15:0] divisor_q;
    reg [7:0]  lcr_q;
    reg        data_ready_q;
    reg        thre_q;
    reg        temt_q;

    // Address decode validity checks
    wire waddr_valid = (reg_waddr == `UART_REG_RBR_THR) ||
                       (reg_waddr == `UART_REG_IER)     ||
                       (reg_waddr == `UART_REG_DIVISOR) ||
                       (reg_waddr == `UART_REG_LCR)     ||
                       (reg_waddr == `UART_REG_LSR);

    wire raddr_valid = (reg_raddr == `UART_REG_RBR_THR) ||
                       (reg_raddr == `UART_REG_IER)     ||
                       (reg_raddr == `UART_REG_DIVISOR) ||
                       (reg_raddr == `UART_REG_LCR)     ||
                       (reg_raddr == `UART_REG_LSR);

    assign reg_werr = ~waddr_valid;
    assign reg_rerr = ~raddr_valid;

    // Combinational Read Logic
    always @(*) begin
        case (reg_raddr)
            `UART_REG_RBR_THR: begin
                reg_rdata = {24'd0, rbr_q};
            end
            `UART_REG_IER: begin
                reg_rdata = {24'd0, ier_q};
            end
            `UART_REG_DIVISOR: begin
                reg_rdata = {16'd0, divisor_q};
            end
            `UART_REG_LCR: begin
                reg_rdata = {24'd0, lcr_q};
            end
            `UART_REG_LSR: begin
                reg_rdata = {24'd0, 1'b0, temt_q, thre_q, 4'd0, data_ready_q};
            end
            default: begin
                reg_rdata = 32'd0;
            end
        endcase
    end

    // Interrupt output
    assign irq_o = (ier_q[`UART_IER_RX_BIT] & data_ready_q) |
                   (ier_q[`UART_IER_TX_BIT] & thre_q);

    //-------------------------------------------------------------------------
    // UART Transmitter
    //-------------------------------------------------------------------------
    reg [15:0] tx_baud_cnt;
    reg [3:0]  tx_bit_idx;
    reg [9:0]  tx_shift_reg;
    reg        tx_busy;
    reg        tx_done_pulse;

    assign uart_tx   = tx_busy ? tx_shift_reg[0] : 1'b1;
    assign tx_done_o = tx_done_pulse;

    //-------------------------------------------------------------------------
    // UART Receiver (2-stage synchronizer + sampling)
    //-------------------------------------------------------------------------
    reg [1:0]  rx_sync;
    wire       rx_in = rx_sync[1];
    reg [15:0] rx_baud_cnt;
    reg [3:0]  rx_bit_idx;
    reg [7:0]  rx_shift_reg;
    reg        rx_busy;

    //-------------------------------------------------------------------------
    // Main Sequential Block
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rbr_q         <= 8'd0;
            thr_q         <= 8'd0;
            ier_q         <= 8'd0;
            divisor_q     <= DEFAULT_DIVISOR;
            lcr_q         <= 8'h03; // 8 bits, 1 stop bit, no parity
            data_ready_q  <= 1'b0;
            thre_q        <= 1'b1;
            temt_q        <= 1'b1;
            tx_baud_cnt   <= 16'd0;
            tx_bit_idx    <= 4'd0;
            tx_shift_reg  <= 10'h3FF;
            tx_busy       <= 1'b0;
            tx_done_pulse <= 1'b0;
            rx_sync       <= 2'b11;
            rx_baud_cnt   <= 16'd0;
            rx_bit_idx    <= 4'd0;
            rx_shift_reg  <= 8'd0;
            rx_busy       <= 1'b0;
        end else begin
            tx_done_pulse <= 1'b0;
            rx_sync       <= {rx_sync[0], uart_rx};

            // Register Writes
            if (reg_wr_en) begin
                case (reg_waddr)
                    `UART_REG_RBR_THR: begin
                        thr_q  <= reg_wdata[7:0];
                        thre_q <= 1'b0;
                        temt_q <= 1'b0;
                    end
                    `UART_REG_IER: begin
                        ier_q <= reg_wdata[7:0];
                    end
                    `UART_REG_DIVISOR: begin
                        divisor_q <= reg_wdata[15:0];
                    end
                    `UART_REG_LCR: begin
                        lcr_q <= reg_wdata[7:0];
                    end
                    default: begin
                    end
                endcase
            end

            // Reading RBR clears DATA_READY flag
            if (reg_rd_en && (reg_raddr == `UART_REG_RBR_THR)) begin
                data_ready_q <= 1'b0;
            end

            // Transmitter FSM / Shift Logic
            if (!tx_busy) begin
                if (!thre_q) begin
                    // Load THR into shift register: start bit 0, 8 data bits, stop bit 1
                    tx_shift_reg <= {1'b1, thr_q, 1'b0};
                    tx_baud_cnt  <= (divisor_q > 16'd1) ? (divisor_q - 16'd1) : 16'd1;
                    tx_bit_idx   <= 4'd0;
                    tx_busy      <= 1'b1;
                    thre_q       <= 1'b1; // THR ready for next byte
                end
            end else begin
                if (tx_baud_cnt == 16'd0) begin
                    tx_baud_cnt <= (divisor_q > 16'd1) ? (divisor_q - 16'd1) : 16'd1;
                    tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};
                    if (tx_bit_idx == 4'd9) begin
                        tx_busy       <= 1'b0;
                        temt_q        <= thre_q;
                        tx_done_pulse <= 1'b1; // Pulse event on completion
                    end else begin
                        tx_bit_idx <= tx_bit_idx + 4'd1;
                    end
                end else begin
                    tx_baud_cnt <= tx_baud_cnt - 16'd1;
                end
            end

            // Receiver FSM / Shift Logic
            if (!rx_busy) begin
                // Falling edge detection (start bit)
                if (rx_in == 1'b0) begin
                    rx_busy     <= 1'b1;
                    rx_baud_cnt <= (divisor_q >> 1); // Sample at half-baud for start bit
                    rx_bit_idx  <= 4'd0;
                end
            end else begin
                if (rx_baud_cnt == 16'd0) begin
                    rx_baud_cnt <= (divisor_q > 16'd1) ? (divisor_q - 16'd1) : 16'd1;
                    if (rx_bit_idx == 4'd0) begin
                        // Check valid start bit
                        if (rx_in == 1'b0) begin
                            rx_bit_idx <= 4'd1;
                        end else begin
                            rx_busy <= 1'b0; // False start bit
                        end
                    end else if (rx_bit_idx <= 4'd8) begin
                        rx_shift_reg <= {rx_in, rx_shift_reg[7:1]};
                        rx_bit_idx   <= rx_bit_idx + 4'd1;
                    end else begin
                        // Stop bit
                        rbr_q        <= rx_shift_reg;
                        data_ready_q <= 1'b1;
                        rx_busy      <= 1'b0;
                    end
                end else begin
                    rx_baud_cnt <= rx_baud_cnt - 16'd1;
                end
            end
        end
    end

endmodule
