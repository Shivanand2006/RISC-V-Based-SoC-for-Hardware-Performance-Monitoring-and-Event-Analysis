//=============================================================================
// File: ahb_imem_adapter.v
// Description: AHB-Lite Instruction Fetch adapter for VeeR EL2 IFU.
//              Connects the 64-bit AHB-Lite IFU master interface to the
//              Instruction Memory (imem.v).
// Standard: Synthesizable Verilog-2001
//=============================================================================

module ahb_imem_adapter #(
    parameter AHB_ADDR_WIDTH = 32,
    parameter AHB_DATA_WIDTH = 64
)(
    // Clock and Reset
    input  wire                      hclk,
    input  wire                      hreset_n,

    // AHB-Lite Slave Interface (from VeeR Core IFU Master)
    input  wire [AHB_ADDR_WIDTH-1:0] haddr,
    input  wire [1:0]                htrans,
    input  wire                      hwrite,
    input  wire [2:0]                hsize,
    output wire [AHB_DATA_WIDTH-1:0] hrdata,
    output wire                      hready,
    output wire                      hresp,

    // IMEM Fetch Port Interface (to imem.v)
    output wire                      fetch_req_o,
    output wire [11:0]               fetch_addr_o,
    input  wire [31:0]               fetch_rdata_i,
    input  wire                      fetch_ready_i
);

    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    wire addr_phase_valid = (htrans == HTRANS_NONSEQ) || (htrans == HTRANS_SEQ);

    reg        active_q;
    reg [31:0] addr_q;

    always @(posedge hclk or negedge hreset_n) begin
        if (!hreset_n) begin
            active_q <= 1'b0;
            addr_q   <= 32'd0;
        end else begin
            if (hready) begin
                active_q <= addr_phase_valid;
                addr_q   <= haddr;
            end
        end
    end

    // Fetch request during address phase
    assign fetch_req_o  = addr_phase_valid;
    assign fetch_addr_o = haddr[11:0];

    // Data phase response
    assign hready = active_q ? fetch_ready_i : 1'b1;
    assign hresp  = 1'b0; // Always OKAY for mapped IMEM

    // Return instruction on both 32-bit lanes or word-selected
    assign hrdata = addr_q[2] ? {fetch_rdata_i, 32'd0} : {32'd0, fetch_rdata_i};

endmodule
