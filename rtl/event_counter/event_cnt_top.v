//=============================================================================
// File: event_cnt_top.v
// Description: 32-bit Performance Event Counter IP with memory-mapped register
//              interface. Counts one software-selected processor/system event,
//              with sticky overflow and threshold interrupt generation.
// Standard: Synthesizable Verilog-2001
//=============================================================================

`include "event_cnt_defines.vh"

module event_cnt_top #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = 4,
    parameter NUM_EVENTS = 8
)(
    // Clock and Reset
    input  wire                  clk,
    input  wire                  rst_n,

    // Event input pulses from system/core
    input  wire [NUM_EVENTS-1:0] events_i,

    // Interrupt output
    output wire                  irq_o,

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
    reg        irq_en_q;
    reg [2:0]  evt_sel_q;
    reg [31:0] count_q;
    reg [31:0] thresh_q;
    reg        ovf_q;
    reg        thresh_hit_q;

    // Selected event multiplexing
    wire evt_pulse  = events_i[evt_sel_q];
    wire evt_active = en_q & evt_pulse;

    // Interrupt generation
    assign irq_o = irq_en_q & thresh_hit_q;

    // Address decode validity checks
    wire waddr_valid = (reg_waddr == `EVENT_CNT_REG_CTRL)    ||
                       (reg_waddr == `EVENT_CNT_REG_EVT_SEL) ||
                       (reg_waddr == `EVENT_CNT_REG_COUNT)   ||
                       (reg_waddr == `EVENT_CNT_REG_THRESH)  ||
                       (reg_waddr == `EVENT_CNT_REG_STATUS);

    wire raddr_valid = (reg_raddr == `EVENT_CNT_REG_CTRL)    ||
                       (reg_raddr == `EVENT_CNT_REG_EVT_SEL) ||
                       (reg_raddr == `EVENT_CNT_REG_COUNT)   ||
                       (reg_raddr == `EVENT_CNT_REG_THRESH)  ||
                       (reg_raddr == `EVENT_CNT_REG_STATUS);

    assign reg_werr = ~waddr_valid;
    assign reg_rerr = ~raddr_valid;

    // Combinational Read Logic
    always @(*) begin
        case (reg_raddr)
            `EVENT_CNT_REG_CTRL: begin
                reg_rdata = {29'd0, irq_en_q, 1'b0, en_q};
            end
            `EVENT_CNT_REG_EVT_SEL: begin
                reg_rdata = {29'd0, evt_sel_q};
            end
            `EVENT_CNT_REG_COUNT: begin
                reg_rdata = count_q;
            end
            `EVENT_CNT_REG_THRESH: begin
                reg_rdata = thresh_q;
            end
            `EVENT_CNT_REG_STATUS: begin
                reg_rdata = {29'd0, en_q, thresh_hit_q, ovf_q};
            end
            default: begin
                reg_rdata = 32'd0;
            end
        endcase
    end

    // Sequential Logic (Registers and Counters)
    wire ctrl_wr   = reg_wr_en && (reg_waddr == `EVENT_CNT_REG_CTRL);
    wire ctrl_clr  = ctrl_wr && reg_wdata[`EVENT_CNT_CTRL_CLR_BIT];

    wire status_wr = reg_wr_en && (reg_waddr == `EVENT_CNT_REG_STATUS);
    wire w1c_ovf   = status_wr && reg_wdata[`EVENT_CNT_STATUS_OVF_BIT];
    wire w1c_thrh  = status_wr && reg_wdata[`EVENT_CNT_STATUS_THRHIT_BIT];

    // Threshold check condition on event increment:
    // When incrementing, check if next count >= thresh (with thresh != 0)
    wire [31:0] next_count = count_q + 32'd1;
    wire hit_thresh = evt_active && (thresh_q != 32'd0) && (next_count >= thresh_q);
    wire hit_ovf    = evt_active && (count_q == 32'hFFFF_FFFF);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_q         <= 1'b0;
            irq_en_q     <= 1'b0;
            evt_sel_q    <= 3'd0;
            count_q      <= 32'd0;
            thresh_q     <= 32'd0;
            ovf_q        <= 1'b0;
            thresh_hit_q <= 1'b0;
        end else begin
            // CTRL Register Write
            if (ctrl_wr) begin
                en_q     <= reg_wdata[`EVENT_CNT_CTRL_EN_BIT];
                irq_en_q <= reg_wdata[`EVENT_CNT_CTRL_IRQEN_BIT];
            end

            // EVT_SEL Register Write
            if (reg_wr_en && (reg_waddr == `EVENT_CNT_REG_EVT_SEL)) begin
                evt_sel_q <= reg_wdata[2:0];
            end

            // THRESH Register Write
            if (reg_wr_en && (reg_waddr == `EVENT_CNT_REG_THRESH)) begin
                thresh_q <= reg_wdata;
            end

            // COUNT register update: CLEAR has priority over counting
            if (ctrl_clr) begin
                count_q <= 32'd0;
            end else if (evt_active) begin
                count_q <= next_count;
            end

            // OVF flag update:
            // CLEAR clears; simultaneous event wrap wins over W1C write
            if (ctrl_clr) begin
                ovf_q <= 1'b0;
            end else if (hit_ovf) begin
                ovf_q <= 1'b1;
            end else if (w1c_ovf) begin
                ovf_q <= 1'b0;
            end

            // THRESH_HIT flag update:
            // CLEAR clears; new event hit wins over simultaneous W1C write;
            // writing 1 clears it; re-arms on the next counted event.
            if (ctrl_clr) begin
                thresh_hit_q <= 1'b0;
            end else if (hit_thresh) begin
                thresh_hit_q <= 1'b1;
            end else if (w1c_thrh) begin
                thresh_hit_q <= 1'b0;
            end
        end
    end

`ifdef SIM
    // Backdoor preload hook for simulation testing
    task preload_count;
        input [31:0] val;
        begin
            count_q = val;
        end
    endtask
`endif

endmodule
