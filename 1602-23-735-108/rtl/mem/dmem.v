//=============================================================================
// File: dmem.v
// Description: 4KB Data Memory model (1024 x 32-bit words).
//              Byte-writable with wstrb[3:0], synchronous read.
// Standard: Synthesizable Verilog-2001
//=============================================================================

module dmem #(
    parameter MEM_SIZE_BYTES = 4096,
    parameter ADDR_WIDTH     = 12,
    parameter DATA_WIDTH     = 32,
    parameter STRB_WIDTH     = 4
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

    localparam NUM_WORDS = MEM_SIZE_BYTES / 4;

    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:NUM_WORDS-1];

    // Word address calculation (word-aligned)
    wire [ADDR_WIDTH-3:0] word_addr = bus_addr_i[ADDR_WIDTH-1:2];

    reg [DATA_WIDTH-1:0] bus_rdata_q;
    reg                  bus_ready_q;

    // Synchronous memory read and write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_rdata_q <= {DATA_WIDTH{1'b0}};
            bus_ready_q <= 1'b0;
        end else begin
            bus_ready_q <= bus_req_i;
            if (bus_req_i) begin
                if (bus_we_i) begin
                    if (bus_wstrb_i[0]) mem[word_addr][7:0]   <= bus_wdata_i[7:0];
                    if (bus_wstrb_i[1]) mem[word_addr][15:8]  <= bus_wdata_i[15:8];
                    if (bus_wstrb_i[2]) mem[word_addr][23:16] <= bus_wdata_i[23:16];
                    if (bus_wstrb_i[3]) mem[word_addr][31:24] <= bus_wdata_i[31:24];
                end
                bus_rdata_q <= mem[word_addr];
            end
        end
    end

    assign bus_rdata_o = bus_rdata_q;
    assign bus_ready_o = bus_ready_q;
    assign bus_err_o   = 1'b0;

    // Optional zero initialization for simulation
    integer k;
    initial begin
        for (k = 0; k < NUM_WORDS; k = k + 1) begin
            mem[k] = 32'd0;
        end
    end

endmodule
