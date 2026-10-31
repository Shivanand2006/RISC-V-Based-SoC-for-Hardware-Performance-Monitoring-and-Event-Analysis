//=============================================================================
// File: ahb_to_bus_adapter.v
// Description: AHB-Lite to simple system bus bridge adapter.
//              Adapts the VeeR EL2 LSU AHB-Lite Master interface to the standard
//              memory-mapped system bus used by the interconnect and decoder.
// Standard: Synthesizable Verilog-2001
//=============================================================================

module ahb_to_bus_adapter #(
    parameter AHB_ADDR_WIDTH = 32,
    parameter AHB_DATA_WIDTH = 64,
    parameter BUS_DATA_WIDTH = 32
)(
    // Clock and Reset
    input  wire                      hclk,
    input  wire                      hreset_n,

    // AHB-Lite Slave Interface (from VeeR Core LSU Master)
    input  wire [AHB_ADDR_WIDTH-1:0] haddr,
    input  wire [1:0]                htrans,
    input  wire                      hwrite,
    input  wire [2:0]                hsize,
    input  wire [2:0]                hburst,
    input  wire [3:0]                hprot,
    input  wire [AHB_DATA_WIDTH-1:0] hwdata,
    output reg  [AHB_DATA_WIDTH-1:0] hrdata,
    output reg                       hready,
    output reg                       hresp,

    // Simple System Bus Master Interface (to bus_decoder)
    output reg                       m_req_o,
    output reg                       m_we_o,
    output reg  [31:0]               m_addr_o,
    output reg  [31:0]               m_wdata_o,
    output reg  [3:0]                m_wstrb_o,
    input  wire                      m_ready_i,
    input  wire [31:0]               m_rdata_i,
    input  wire                      m_err_i
);

    // AHB transfer types
    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_BUSY   = 2'b01;
    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    // Registered address phase state
    reg        phase_data_q;
    reg [31:0] addr_q;
    reg        we_q;
    reg [2:0]  size_q;

    // Detect valid address phase
    wire addr_phase_valid = (htrans == HTRANS_NONSEQ) || (htrans == HTRANS_SEQ);

    // Strobe decode logic
    reg [3:0] strobe_calc;
    always @(*) begin
        case (size_q)
            3'b000: begin // Byte
                strobe_calc = 4'b0001 << addr_q[1:0];
            end
            3'b001: begin // Halfword
                strobe_calc = addr_q[1] ? 4'b1100 : 4'b0011;
            end
            3'b010: begin // Word
                strobe_calc = 4'b1111;
            end
            default: begin
                strobe_calc = 4'b1111;
            end
        endcase
    end

    // Sequential Tracking of Address and Data Phase
    always @(posedge hclk or negedge hreset_n) begin
        if (!hreset_n) begin
            phase_data_q <= 1'b0;
            addr_q       <= 32'd0;
            we_q         <= 1'b0;
            size_q       <= 3'd0;
        end else begin
            if (hready) begin
                if (addr_phase_valid) begin
                    phase_data_q <= 1'b1;
                    addr_q       <= haddr;
                    we_q         <= hwrite;
                    size_q       <= hsize;
                end else begin
                    phase_data_q <= 1'b0;
                end
            end
        end
    end

    // Drive System Bus Master signals during Data Phase
    always @(*) begin
        if (phase_data_q) begin
            m_req_o   = 1'b1;
            m_we_o    = we_q;
            m_addr_o  = addr_q;
            m_wstrb_o = we_q ? strobe_calc : 4'b0000;
            m_wdata_o = addr_q[2] ? hwdata[63:32] : hwdata[31:0];

            hready    = m_ready_i;
            hresp     = m_err_i;
            hrdata    = addr_q[2] ? {m_rdata_i, 32'd0} : {32'd0, m_rdata_i};
        end else begin
            m_req_o   = 1'b0;
            m_we_o    = 1'b0;
            m_addr_o  = 32'd0;
            m_wstrb_o = 4'b0000;
            m_wdata_o = 32'd0;

            hready    = 1'b1; // Ready when idle
            hresp     = 1'b0;
            hrdata    = 64'd0;
        end
    end

endmodule
