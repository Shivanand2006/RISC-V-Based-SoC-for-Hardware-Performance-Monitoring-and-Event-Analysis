//=============================================================================
// File: gpio_top.v
// Description: 8-bit GPIO peripheral with configurable direction and 2-flop
//              input synchronizer.
// Standard: Synthesizable Verilog-2001
//=============================================================================

`include "gpio_defines.vh"

module gpio_top #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = 4,
    parameter GPIO_WIDTH = 8
)(
    // Clock and Reset
    input  wire                  clk,
    input  wire                  rst_n,

    // External GPIO pins
    input  wire [GPIO_WIDTH-1:0] gpio_in,
    output wire [GPIO_WIDTH-1:0] gpio_out,

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
    reg [GPIO_WIDTH-1:0] dir_q;
    reg [GPIO_WIDTH-1:0] out_q;
    reg [GPIO_WIDTH-1:0] in_sync1;
    reg [GPIO_WIDTH-1:0] in_sync2;

    // Output assignment
    assign gpio_out = out_q & dir_q;

    // Address decode validity checks
    wire waddr_valid = (reg_waddr == `GPIO_REG_DIR) ||
                       (reg_waddr == `GPIO_REG_OUT) ||
                       (reg_waddr == `GPIO_REG_IN);

    wire raddr_valid = (reg_raddr == `GPIO_REG_DIR) ||
                       (reg_raddr == `GPIO_REG_OUT) ||
                       (reg_raddr == `GPIO_REG_IN);

    assign reg_werr = ~waddr_valid;
    assign reg_rerr = ~raddr_valid;

    // Combinational Read Logic
    always @(*) begin
        case (reg_raddr)
            `GPIO_REG_DIR: begin
                reg_rdata = {24'd0, dir_q};
            end
            `GPIO_REG_OUT: begin
                reg_rdata = {24'd0, out_q};
            end
            `GPIO_REG_IN: begin
                reg_rdata = {24'd0, in_sync2};
            end
            default: begin
                reg_rdata = 32'd0;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dir_q    <= {GPIO_WIDTH{1'b0}};
            out_q    <= {GPIO_WIDTH{1'b0}};
            in_sync1 <= {GPIO_WIDTH{1'b0}};
            in_sync2 <= {GPIO_WIDTH{1'b0}};
        end else begin
            // 2-flop input synchronizer
            in_sync1 <= gpio_in;
            in_sync2 <= in_sync1;

            // Register writes
            if (reg_wr_en) begin
                case (reg_waddr)
                    `GPIO_REG_DIR: begin
                        dir_q <= reg_wdata[GPIO_WIDTH-1:0];
                    end
                    `GPIO_REG_OUT: begin
                        out_q <= reg_wdata[GPIO_WIDTH-1:0];
                    end
                    default: begin
                        // RO register
                    end
                endcase
            end
        end
    end

endmodule
