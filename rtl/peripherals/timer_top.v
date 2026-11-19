//=============================================================================
// File: timer_top.v
// Description: 32-bit Memory-mapped Timer peripheral with reload and tick output.
// Standard: Synthesizable Verilog-2001
//=============================================================================

`include "timer_defines.vh"

module timer_top #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = 4
)(
    // Clock and Reset
    input  wire                  clk,
    input  wire                  rst_n,

    // Timer Tick output (1-cycle pulse at zero reload)
    output wire                  tick_o,

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
    reg        en_q;
    reg [31:0] reload_q;
    reg [31:0] count_q;
    reg        tick_q;

    assign tick_o = tick_q;

    // Address decode validity checks
    wire waddr_valid = (reg_waddr == `TIMER_REG_CTRL)   ||
                       (reg_waddr == `TIMER_REG_RELOAD) ||
                       (reg_waddr == `TIMER_REG_COUNT);

    wire raddr_valid = (reg_raddr == `TIMER_REG_CTRL)   ||
                       (reg_raddr == `TIMER_REG_RELOAD) ||
                       (reg_raddr == `TIMER_REG_COUNT);

    assign reg_werr = ~waddr_valid;
    assign reg_rerr = ~raddr_valid;

    // Combinational Read Logic
    always @(*) begin
        case (reg_raddr)
            `TIMER_REG_CTRL: begin
                reg_rdata = {31'd0, en_q};
            end
            `TIMER_REG_RELOAD: begin
                reg_rdata = reload_q;
            end
            `TIMER_REG_COUNT: begin
                reg_rdata = count_q;
            end
            default: begin
                reg_rdata = 32'd0;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_q     <= 1'b0;
            reload_q <= 32'd0;
            count_q  <= 32'd0;
            tick_q   <= 1'b0;
        end else begin
            // Register writes
            if (reg_wr_en) begin
                case (reg_waddr)
                    `TIMER_REG_CTRL: begin
                        en_q <= reg_wdata[`TIMER_CTRL_EN_BIT];
                    end
                    `TIMER_REG_RELOAD: begin
                        reload_q <= reg_wdata;
                        if (!en_q) begin
                            count_q <= reg_wdata;
                        end
                    end
                    default: begin
                        // RO register or ignored
                    end
                endcase
            end

            // Timer down-counter
            if (en_q) begin
                if (count_q == 32'd0) begin
                    count_q <= reload_q;
                    tick_q  <= 1'b1;
                end else begin
                    count_q <= count_q - 32'd1;
                    tick_q  <= 1'b0;
                end
            end else begin
                tick_q <= 1'b0;
            end
        end
    end

endmodule
