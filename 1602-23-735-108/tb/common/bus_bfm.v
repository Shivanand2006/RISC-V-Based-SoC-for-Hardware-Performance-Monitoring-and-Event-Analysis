//=============================================================================
// File: bus_bfm.v
// Description: Reusable Bus Master Bus Functional Model (BFM) tasks for
//              unit testbenches. Supports write, read, assertions, and reporting.
// Standard: Verilog-2001 Testbench
//=============================================================================

`ifndef BUS_BFM_V
`define BUS_BFM_V

module bus_bfm;
    // Helper task to check and assert equality
    task assert_eq32;
        input [31:0] actual;
        input [31:0] expected;
        input [255:0] test_name;
        inout integer fail_cnt;
        begin
            if (actual === expected) begin
                $display("  [PASS] %0s: expected 0x%08h, got 0x%08h", test_name, expected, actual);
            end else begin
                $display("  [FAIL] %0s: expected 0x%08h, got 0x%08h", test_name, expected, actual);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // Helper task to check and assert 1-bit flags
    task assert_eq1;
        input actual;
        input expected;
        input [255:0] test_name;
        inout integer fail_cnt;
        begin
            if (actual === expected) begin
                $display("  [PASS] %0s: expected %b, got %b", test_name, expected, actual);
            end else begin
                $display("  [FAIL] %0s: expected %b, got %b", test_name, expected, actual);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask
endmodule

`endif // BUS_BFM_V
