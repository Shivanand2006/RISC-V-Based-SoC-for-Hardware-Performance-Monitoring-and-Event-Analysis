// -----------------------------------------------------------------------------
// tb_axi_uart_top.v  -  self-checking testbench for axi_uart_top
//
//  * 50 MHz clock (fixed_clk_i and axi_aclk_i share one net)
//  * uart_tx_o is looped back into uart_rx_i
//  * independent TX-line monitor decodes every frame and checks it against
//    the bytes written to THR (so TX is verified separately from RX)
//  * compile with -sverilog (uses string / $sformatf / automatic tasks)
//
//  Waves : sim/waves/tb_axi_uart_top.vcd   (always)
//          sim/waves/tb_axi_uart_top.fsdb  (only when compiled with +define+FSDB)
//  Run simv from the "files" directory so the relative path resolves.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_axi_uart_top;

  // ------------------------------------------------------------- parameters
  localparam CLK_T     = 20;     // ns -> 50 MHz
  localparam TMO_CYC   = 2000;   // AXI handshake timeout (clock cycles)
  localparam DIV_RESET = 27;     // baud divisor after reset (axi_uart.vh)

  // byte addresses (word index = addr[7:2])
  localparam [7:0] ADDR_THR = 8'h00;   // write, DLAB=0
  localparam [7:0] ADDR_RBR = 8'h00;   // read,  DLAB=0
  localparam [7:0] ADDR_IER = 8'h04;   // write, DLAB=0
  localparam [7:0] ADDR_DLL = 8'h04;   // write, DLAB=1 (baud divisor)
  localparam [7:0] ADDR_LCR = 8'h0C;
  localparam [7:0] ADDR_LSR = 8'h14;

  // ---------------------------------------------------------------- signals
  reg         clk = 1'b0;
  reg         rstn;

  reg  [3:0]  arid,  awid;
  reg  [7:0]  araddr, awaddr;
  reg         arvalid, awvalid, wvalid;
  reg         rready, bready;
  reg  [31:0] wdata;
  reg  [3:0]  wstrb;

  wire        arready, awready, wready, rvalid, bvalid;
  wire [3:0]  rid, bid;
  wire [31:0] rdata;
  wire [1:0]  rresp, bresp;
  wire        irq;
  wire        uart_tx;
  wire        uart_rx = uart_tx;      // loopback

  always #(CLK_T/2) clk = ~clk;

  // -------------------------------------------------------------------- DUT
  axi_uart_top dut (
    .fixed_clk_i      (clk),
    .axi_aclk_i       (clk),
    .axi_aresetn_i    (rstn),

    .axi_arid_i       (arid),
    .axi_araddr_i     (araddr),
    .axi_arvalid_i    (arvalid),
    .axi_arready_o    (arready),

    .axi_rid_o        (rid),
    .axi_rdata_o      (rdata),
    .axi_rresp_o      (rresp),
    .axi_rvalid_o     (rvalid),
    .axi_rready_i     (rready),

    .axi_awid_i       (awid),
    .axi_awaddr_i     (awaddr),
    .axi_awvalid_i    (awvalid),
    .axi_awready_o    (awready),

    .axi_wdata_i      (wdata),
    .axi_wstrb_i      (wstrb),
    .axi_wvalid_i     (wvalid),
    .axi_wready_o     (wready),

    .axi_bid_o        (bid),
    .axi_bresp_o      (bresp),
    .axi_bvalid_o     (bvalid),
    .axi_bready_i     (bready),

    .read_interrupt_o (irq),
    .uart_rx_i        (uart_rx),
    .uart_tx_o        (uart_tx)
  );

  // ------------------------------------------------------------ waveforms
  initial begin
    $dumpfile("sim/waves/tb_axi_uart_top.vcd");
    $dumpvars(0, tb_axi_uart_top);
`ifdef FSDB
    $fsdbDumpfile("sim/waves/tb_axi_uart_top.fsdb");
    $fsdbDumpvars(0, tb_axi_uart_top, "+all");
`endif
  end

  // ------------------------------------------------------ bookkeeping vars
  integer pass_cnt = 0;
  integer fail_cnt = 0;

  integer cur_div  = DIV_RESET;   // divisor the DUT is currently using
  reg     cfg_parity = 1'b0;      // mirrors LCR[3] for the TX monitor
  reg     mon_en   = 1'b0;
  reg     mon_busy = 1'b0;
  reg     last_parity;

  reg [7:0] exp_q [0:63];         // bytes written to THR, in order
  integer   exp_wr = 0;
  integer   exp_rd = 0;

  // scratch variables for the main sequence
  reg [31:0] v;
  reg        okp;
  reg        par0, par1;
  integer    k;
  reg [7:0]  burst [0:3];

  // ------------------------------------------------------------ checker
  task automatic chk(input cond, input string msg);
    begin
      if (cond) begin
        pass_cnt = pass_cnt + 1;
        $display("[PASS] %s", msg);
      end else begin
        fail_cnt = fail_cnt + 1;
        $display("[FAIL] %s   @ %t", msg, $time);
      end
    end
  endtask

  task wait_cycles(input integer n);
    begin
      repeat (n) @(posedge clk);
    end
  endtask

  task settle;   // let the last frame finish completely
    begin
      wait_cycles(3 * (cur_div + 1));
    end
  endtask

  // ------------------------------------------------- raw AXI-lite master
  // This DUT presents awready/wready/bvalid (and arready/rvalid/rdata) for a
  // single cycle while the master is holding the request, so the handshake
  // and the response are sampled on the same clock edge.
  task axi_write(input [7:0] addr, input [31:0] data,
                 output [1:0] resp, output ok);
    integer t;
    reg     done;
    begin
      ok = 1'b0; resp = 2'bxx; done = 1'b0; t = 0;
      @(posedge clk);
      awid <= 4'h1;  awaddr <= addr;  awvalid <= 1'b1;
      wdata <= data; wstrb  <= 4'hF;  wvalid  <= 1'b1;
      while (!done) begin
        @(posedge clk);
        if (awready === 1'b1 && wready === 1'b1) begin
          done = 1'b1;
          ok   = (bvalid === 1'b1);
          resp = bresp;
        end else begin
          t = t + 1;
          if (t > TMO_CYC) done = 1'b1;      // timeout -> ok stays 0
        end
      end
      awvalid <= 1'b0;
      wvalid  <= 1'b0;
    end
  endtask

  task axi_read(input [7:0] addr, output [31:0] data,
                output [1:0] resp, output ok);
    integer t;
    reg     done;
    begin
      ok = 1'b0; data = 32'hx; resp = 2'bxx; done = 1'b0; t = 0;
      @(posedge clk);
      arid <= 4'h2;  araddr <= addr;  arvalid <= 1'b1;
      while (!done) begin
        @(posedge clk);
        if (arready === 1'b1 && rvalid === 1'b1) begin
          done = 1'b1;
          ok   = 1'b1;
          data = rdata;
          resp = rresp;
        end else begin
          t = t + 1;
          if (t > TMO_CYC) done = 1'b1;
        end
      end
      arvalid <= 1'b0;
    end
  endtask

  // ------------------------------------------ checked register accessors
  task wr(input [7:0] addr, input [31:0] data, input string what);
    reg [1:0] r;
    reg       ok;
    begin
      axi_write(addr, data, r, ok);
      $display("[AXI WR] addr=0x%02h data=0x%08h resp=%0d  (%s) @ %t",
               addr, data, r, what, $time);
      chk(ok && (r === 2'b00), {"AXI write OKAY: ", what});
    end
  endtask

  task rd(input [7:0] addr, output [31:0] data, input string what);
    reg [1:0] r;
    reg       ok;
    begin
      axi_read(addr, data, r, ok);
      $display("[AXI RD] addr=0x%02h data=0x%08h resp=%0d  (%s) @ %t",
               addr, data, r, what, $time);
      chk(ok && (r === 2'b00), {"AXI read OKAY: ", what});
    end
  endtask

  task set_lcr(input [7:0] val, input string what);
    begin
      wr(ADDR_LCR, {24'h0, val}, what);
      cfg_parity = val[3];
    end
  endtask

  // DLAB=1 -> write divisor -> DLAB=0 (leaves LCR = 8N1)
  task set_baud(input [15:0] div);
    begin
      wr(ADDR_LCR, 32'h0000_0080, "LCR: DLAB=1");
      wr(ADDR_DLL, {16'h0, div},  $sformatf("DLL divisor = %0d", div));
      wr(ADDR_LCR, 32'h0000_0000, "LCR: DLAB=0, 8N1");
      cfg_parity = 1'b0;
      cur_div    = div;
    end
  endtask

  task send_byte(input [7:0] b);
    begin
      exp_q[exp_wr % 64] = b;
      exp_wr = exp_wr + 1;
      wr(ADDR_THR, {24'h0, b}, $sformatf("THR <= 0x%02h", b));
    end
  endtask

  // poll LSR[0] (data ready) - quiet, no PASS spam
  task poll_dr(input integer max_polls, output ok);
    reg [31:0] lsr;
    reg [1:0]  r;
    reg        rok;
    integer    i;
    begin
      ok = 1'b0; i = 0;
      while (!ok && i < max_polls) begin
        axi_read(ADDR_LSR, lsr, r, rok);
        if (rok && lsr[0] === 1'b1) ok = 1'b1;
        i = i + 1;
      end
    end
  endtask

  task wait_irq(input integer max_cycles, output ok);
    integer c;
    begin
      ok = 1'b0; c = 0;
      while (!ok && c < max_cycles) begin
        @(posedge clk);
        if (irq === 1'b1) ok = 1'b1;
        c = c + 1;
      end
    end
  endtask

  task recv_check(input [7:0] expv, input string what);
    reg        got;
    reg [31:0] d;
    begin
      poll_dr(1000, got);
      chk(got, {"data ready before timeout: ", what});
      if (got) begin
        rd(ADDR_RBR, d, {"RBR: ", what});
        chk(d[7:0] === expv,
            $sformatf("RBR = 0x%02h, expected 0x%02h  (%s)", d[7:0], expv, what));
      end
    end
  endtask

  // -------------------------------------------- independent TX-line monitor
  // Decodes start / 8 data / [parity] / stop straight from uart_tx_o,
  // sampling at mid-bit, and compares with the bytes written to THR.
  real      bit_t;
  reg [7:0] mon_data;
  integer   mon_i;

  always @(negedge uart_tx) begin
    if (mon_en && !mon_busy) begin
      mon_busy = 1'b1;
      bit_t    = (cur_div + 1) * CLK_T;          // TX bit = divisor+1 clocks
      #(bit_t/2.0);                              // middle of start bit
      chk(uart_tx === 1'b0, "TX monitor: start bit low");
      for (mon_i = 0; mon_i < 8; mon_i = mon_i + 1) begin
        #(bit_t);
        mon_data[mon_i] = uart_tx;               // LSB first
      end
      if (cfg_parity) begin
        #(bit_t);
        last_parity = uart_tx;
      end
      #(bit_t);
      chk(uart_tx === 1'b1, "TX monitor: stop bit high");
      if (exp_rd < exp_wr) begin
        chk(mon_data === exp_q[exp_rd % 64],
            $sformatf("TX monitor: frame 0x%02h, expected 0x%02h",
                      mon_data, exp_q[exp_rd % 64]));
        exp_rd = exp_rd + 1;
      end else begin
        chk(1'b0, "TX monitor: frame seen but nothing was written to THR");
      end
      mon_busy = 1'b0;
    end
  end

  always @(posedge irq) $display("[IRQ]  read_interrupt_o ASSERTED   @ %t", $time);
  always @(negedge irq) $display("[IRQ]  read_interrupt_o DEASSERTED @ %t", $time);

  // ------------------------------------------------------------ watchdog
  initial begin
    #2_000_000;   // 2 ms
    $display("[FAIL] watchdog timeout - simulation hung");
    $finish;
  end

  // ------------------------------------------------------------ main test
  initial begin
    $timeformat(-9, 0, " ns", 8);

    rstn    = 1'b0;
    arid    = 4'h0;  awid    = 4'h0;
    araddr  = 8'h00; awaddr  = 8'h00;
    arvalid = 1'b0;  awvalid = 1'b0;  wvalid = 1'b0;
    wdata   = 32'h0; wstrb   = 4'h0;
    rready  = 1'b1;  bready  = 1'b1;   // always ready to accept responses

    burst[0] = 8'h55;  burst[1] = 8'h41;   // 'U' 'A'
    burst[2] = 8'h52;  burst[3] = 8'h54;   // 'R' 'T'

    wait_cycles(5);
    rstn <= 1'b1;
    wait_cycles(10);
    mon_en = 1'b1;

    // ---------------------------------------------------------- TEST 0
    $display("\n=== TEST 0: reset release ===");
    chk(irq === 1'b0,     "IRQ low after reset");
    chk(uart_tx === 1'b1, "uart_tx idle-high after reset");

    // ---------------------------------------------------------- TEST 1
    $display("\n=== TEST 1: LCR = 0x00 (8N1) ===");
    set_lcr(8'h00, "LCR = 8N1");

    // ---------------------------------------------------------- TEST 2
    $display("\n=== TEST 2: IER[0] = 1 (enable RX interrupt / data-ready) ===");
    wr(ADDR_IER, 32'h1, "IER = 1");

    // ---------------------------------------------------------- TEST 3
    $display("\n=== TEST 3: LSR after reset (THRE=1, TEMT=1, DR=0) ===");
    rd(ADDR_LSR, v, "LSR");
    chk(v[5] === 1'b1, $sformatf("LSR.THRE = 1 (LSR=0x%08h)", v));
    chk(v[6] === 1'b1, $sformatf("LSR.TEMT = 1 (LSR=0x%08h)", v));
    chk(v[0] === 1'b0, $sformatf("LSR.DR   = 0 (LSR=0x%08h)", v));

    // ---------------------------------------------------------- TEST 4
    $display("\n=== TEST 4: RBR read on empty FIFO returns 0 ===");
    rd(ADDR_RBR, v, "RBR (empty)");
    chk(v[7:0] === 8'h00, "empty RBR = 0x00");

    // ---------------------------------------------------------- TEST 5
    $display("\n=== TEST 5: single byte loopback 'H' + interrupt ===");
    chk(irq === 1'b0, "IRQ low before TX");
    send_byte(8'h48);
    wait_irq(1000, okp);
    chk(okp, "read_interrupt_o asserted after loopback RX");
    rd(ADDR_RBR, v, "RBR");
    chk(v[7:0] === 8'h48, $sformatf("RBR = 0x%02h, expected 0x48 ('H')", v[7:0]));
    wait_cycles(4);
    chk(irq === 1'b0, "IRQ deasserted after FIFO emptied");
    settle;

    // ---------------------------------------------------------- TEST 6
    $display("\n=== TEST 6: two back-to-back bytes 'H','i' ===");
    send_byte(8'h48);
    send_byte(8'h69);
    recv_check(8'h48, "first byte  'H'");
    recv_check(8'h69, "second byte 'i'");   // waits for 2nd frame to arrive
    settle;

    // ---------------------------------------------------------- TEST 7
    $display("\n=== TEST 7: baud divisor change via DLAB (27 -> 20 -> 27) ===");
    set_baud(16'd20);
    send_byte(8'hA5);
    recv_check(8'hA5, "0xA5 @ divisor 20");
    settle;
    set_baud(16'd27);
    send_byte(8'h3C);
    recv_check(8'h3C, "0x3C @ divisor 27 (restored)");
    settle;

    // ---------------------------------------------------------- TEST 8
    $display("\n=== TEST 8: parity enabled (LCR[3]=1), both LCR[4] modes ===");
    set_lcr(8'h08, "LCR: parity on, mode bit = 0");
    send_byte(8'h55);
    recv_check(8'h55, "0x55 with parity, mode 0");
    settle;
    par0 = last_parity;
    set_lcr(8'h18, "LCR: parity on, mode bit = 1");
    send_byte(8'h55);
    recv_check(8'h55, "0x55 with parity, mode 1");
    settle;
    par1 = last_parity;
    $display("[INFO] parity bit on wire for 0x55: mode0=%b mode1=%b", par0, par1);
    chk((par0 !== par1) && (par0 !== 1'bx) && (par1 !== 1'bx),
        "parity bit differs between the two LCR[4] modes");

    // ---------------------------------------------------------- TEST 9
    $display("\n=== TEST 9: two stop bits (LCR[2]=1) ===");
    set_lcr(8'h04, "LCR: 2 stop bits");
    send_byte(8'hC3);
    recv_check(8'hC3, "0xC3 with 2 stop bits");
    settle;
    set_lcr(8'h00, "LCR = 8N1");

    // ---------------------------------------------------------- TEST 10
    $display("\n=== TEST 10: burst 'U','A','R','T' through the TX FIFO ===");
    for (k = 0; k < 4; k = k + 1) send_byte(burst[k]);
    for (k = 0; k < 4; k = k + 1)
      recv_check(burst[k], $sformatf("burst byte %0d", k));
    settle;

    // ---------------------------------------------------------- TEST 11
    $display("\n=== TEST 11: final LSR (idle, everything read) ===");
    rd(ADDR_LSR, v, "LSR");
    chk(v[5] === 1'b1 && v[6] === 1'b1, $sformatf("THRE/TEMT = 1 (LSR=0x%08h)", v));
    chk(v[0] === 1'b0,                  "DR = 0, RX FIFO empty");
    chk(exp_rd == exp_wr,
        $sformatf("TX monitor saw every byte written (%0d of %0d)", exp_rd, exp_wr));

    // ---------------------------------------------------------- summary
    $display("\n========================================");
    if (fail_cnt == 0)
      $display("[RESULT] ALL CHECKS PASSED (%0d)", pass_cnt);
    else
      $display("[RESULT] %0d CHECK(S) FAILED, %0d passed", fail_cnt, pass_cnt);
    $display("========================================\n");
    $finish;
  end

endmodule
