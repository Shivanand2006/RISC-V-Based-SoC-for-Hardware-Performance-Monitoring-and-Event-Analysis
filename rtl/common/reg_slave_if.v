//=============================================================================
// File: reg_slave_if.v
// Description: Common bus-to-register adapter interface for memory-mapped IP cores.
//              Adapts standard synchronous memory bus to simple register interface.
// Standard: Synthesizable Verilog-2001
//=============================================================================

module reg_slave_if #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = 4
)(
    // Clock and Reset
    input  wire                  clk,
    input  wire                  rst_n,

    // Bus Slave Interface (Interconnect side)
    input  wire                  bus_req_i,
    input  wire                  bus_we_i,
    input  wire [ADDR_WIDTH-1:0] bus_addr_i,
    input  wire [DATA_WIDTH-1:0] bus_wdata_i,
    input  wire [STRB_WIDTH-1:0] bus_wstrb_i,
    output wire                  bus_ready_o,
    output wire [DATA_WIDTH-1:0] bus_rdata_o,
    output wire                  bus_err_o,

    // Common Register Interface (IP Core side)
    output wire                  reg_wr_en,
    output wire [ADDR_WIDTH-1:0] reg_waddr,
    output wire [DATA_WIDTH-1:0] reg_wdata,
    output wire [STRB_WIDTH-1:0] reg_wstrb,
    input  wire                  reg_werr,

    output wire                  reg_rd_en,
    output wire [ADDR_WIDTH-1:0] reg_raddr,
    input  wire [DATA_WIDTH-1:0] reg_rdata,
    input  wire                  reg_rerr
);

    // Track active request to ensure single-cycle pulse per transaction
    reg req_seen_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_seen_q <= 1'b0;
        end else begin
            if (bus_req_i && bus_ready_o) begin
                req_seen_q <= 1'b1;
            end else if (!bus_req_i) begin
                req_seen_q <= 1'b0;
            end
        end
    end

    wire req_pulse = bus_req_i & ~req_seen_q;

    // Register strobe pulses (1-cycle pulse per bus transaction)
    assign reg_wr_en = req_pulse & bus_we_i;
    assign reg_rd_en = req_pulse & ~bus_we_i;

    // Address and Data connections
    assign reg_waddr = bus_addr_i;
    assign reg_raddr = bus_addr_i;
    assign reg_wdata = bus_wdata_i;
    assign reg_wstrb = bus_wstrb_i;

    // Bus response signals
    assign bus_ready_o = bus_req_i;
    assign bus_rdata_o = reg_rdata;
    assign bus_err_o   = bus_we_i ? reg_werr : reg_rerr;

endmodule
