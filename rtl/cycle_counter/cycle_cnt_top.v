//=============================================================================
// File: cycle_cnt_top.v
// Description: 64-bit Cycle Counter IP with memory-mapped register interface.
//              Counts enabled clock cycles, supports coherent 64-bit shadow read.
// Standard: Synthesizable Verilog-2001
//=============================================================================

`include "cycle_cnt_defines.vh"

module cycle_cnt_top #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = 4
)(
    // Clock and Reset
    input  wire                  clk,
    input  wire                  rst_n,

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
    reg [63:0] count_q;
    reg [31:0] shadow_hi_q;

    // Address decode validity checks
    wire waddr_valid = (reg_waddr == `CYCLE_CNT_REG_CTRL)   ||
                       (reg_waddr == `CYCLE_CNT_REG_STATUS) ||
                       (reg_waddr == `CYCLE_CNT_REG_CNT_LO) ||
                       (reg_waddr == `CYCLE_CNT_REG_CNT_HI);

    wire raddr_valid = (reg_raddr == `CYCLE_CNT_REG_CTRL)   ||
                       (reg_raddr == `CYCLE_CNT_REG_STATUS) ||
                       (reg_raddr == `CYCLE_CNT_REG_CNT_LO) ||
                       (reg_raddr == `CYCLE_CNT_REG_CNT_HI);

    assign reg_werr = ~waddr_valid;
    assign reg_rerr = ~raddr_valid;

    // Combinational Read Logic
    always @(*) begin
        case (reg_raddr)
            `CYCLE_CNT_REG_CTRL: begin
                reg_rdata = {30'd0, 1'b0, en_q};
            end
            `CYCLE_CNT_REG_STATUS: begin
                reg_rdata = {31'd0, en_q};
            end
            `CYCLE_CNT_REG_CNT_LO: begin
                reg_rdata = count_q[31:0];
            end
            `CYCLE_CNT_REG_CNT_HI: begin
                reg_rdata = shadow_hi_q;
            end
            default: begin
                reg_rdata = 32'd0;
            end
        endcase
    end

    // Sequential Logic (Registers and Counter)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_q        <= 1'b0;
            count_q     <= 64'd0;
            shadow_hi_q <= 32'd0;
        end else begin
            // CTRL Register Write
            if (reg_wr_en && (reg_waddr == `CYCLE_CNT_REG_CTRL)) begin
                en_q <= reg_wdata[`CYCLE_CNT_CTRL_EN_BIT];
            end

            // Shadow Register capture on CNT_LO read
            if (reg_rd_en && (reg_raddr == `CYCLE_CNT_REG_CNT_LO)) begin
                shadow_hi_q <= count_q[63:32];
            end

            // Counter Update: CLEAR has priority over counting
            if (reg_wr_en && (reg_waddr == `CYCLE_CNT_REG_CTRL) && reg_wdata[`CYCLE_CNT_CTRL_CLR_BIT]) begin
                count_q <= 64'd0;
            end else if (en_q) begin
                count_q <= count_q + 64'd1;
            end
        end
    end

`ifdef SIM
    // Backdoor preload hook for simulation testing of 64-bit carry
    task preload_count;
        input [63:0] val;
        begin
            count_q = val;
        end
    endtask
`endif

endmodule
