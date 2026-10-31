//=============================================================================
// File: imem.v
// Description: 4KB Instruction Memory model (1024 x 32-bit words).
//              Synchronous read, supports initialization via $readmemh with
//              optional +firmware=<file> runtime plusarg.
// Standard: Synthesizable Verilog-2001 (simulation preload support)
//=============================================================================

module imem #(
    parameter MEM_SIZE_BYTES = 4096,
    parameter ADDR_WIDTH     = 12,
    parameter DATA_WIDTH     = 32,
    parameter STRB_WIDTH     = 4,
    parameter HEX_FILE       = ""
)(
    // Clock and Reset
    input  wire                  clk,
    input  wire                  rst_n,

    // Instruction Fetch Port (from Core)
    input  wire                  fetch_req_i,
    input  wire [ADDR_WIDTH-1:0] fetch_addr_i,
    output wire [DATA_WIDTH-1:0] fetch_rdata_o,
    output wire                  fetch_ready_o,

    // Bus Slave Port (from Interconnect / Data bus)
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
    wire [ADDR_WIDTH-3:0] fetch_word_addr = fetch_addr_i[ADDR_WIDTH-1:2];
    wire [ADDR_WIDTH-3:0] bus_word_addr   = bus_addr_i[ADDR_WIDTH-1:2];

    // Synchronous read registers
    reg [DATA_WIDTH-1:0] fetch_rdata_q;
    reg [DATA_WIDTH-1:0] bus_rdata_q;
    reg                  fetch_ready_q;
    reg                  bus_ready_q;

    // Fetch port read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fetch_rdata_q <= {DATA_WIDTH{1'b0}};
            fetch_ready_q <= 1'b0;
        end else begin
            fetch_ready_q <= fetch_req_i;
            if (fetch_req_i) begin
                fetch_rdata_q <= mem[fetch_word_addr];
            end
        end
    end

    // Bus port read and write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_rdata_q <= {DATA_WIDTH{1'b0}};
            bus_ready_q <= 1'b0;
        end else begin
            bus_ready_q <= bus_req_i;
            if (bus_req_i) begin
                if (bus_we_i) begin
                    if (bus_wstrb_i[0]) mem[bus_word_addr][7:0]   <= bus_wdata_i[7:0];
                    if (bus_wstrb_i[1]) mem[bus_word_addr][15:8]  <= bus_wdata_i[15:8];
                    if (bus_wstrb_i[2]) mem[bus_word_addr][23:16] <= bus_wdata_i[23:16];
                    if (bus_wstrb_i[3]) mem[bus_word_addr][31:24] <= bus_wdata_i[31:24];
                end
                bus_rdata_q <= mem[bus_word_addr];
            end
        end
    end

    assign fetch_rdata_o = fetch_rdata_q;
    assign fetch_ready_o = fetch_ready_q;

    assign bus_rdata_o   = bus_rdata_q;
    assign bus_ready_o   = bus_ready_q;
    assign bus_err_o     = 1'b0;

    // Initialization via plusarg or parameter
    reg [1023:0] fw_filename;
    integer k;
    initial begin
        for (k = 0; k < NUM_WORDS; k = k + 1) begin
            mem[k] = 32'd0;
        end
        if ($value$plusargs("firmware=%s", fw_filename)) begin
            $readmemh(fw_filename, mem);
        end else if (HEX_FILE != "") begin
            $readmemh(HEX_FILE, mem);
        end
    end

endmodule
