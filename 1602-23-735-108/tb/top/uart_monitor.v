//=============================================================================
// File: uart_monitor.v
// Description: Passive 8N1 UART receiver monitor for simulation testbenches.
//              Decodes the serial stream, prints characters in real-time to the
//              simulator console, and detects "PASS" or "FAIL" tokens.
// Standard: Verilog-2001 Testbench
//=============================================================================

`timescale 1ns/1ps

module uart_monitor #(
    parameter BAUD_RATE  = 115200,
    parameter CLK_FREQ_HZ = 50_000_000
)(
    input wire clk,
    input wire rst_n,
    input wire uart_tx_pin,

    output reg pass_seen,
    output reg fail_seen
);

    localparam BIT_PERIOD_NS = 1_000_000_000 / BAUD_RATE;
    localparam HALF_PERIOD_NS = BIT_PERIOD_NS / 2;

    reg [7:0]  rx_char;
    reg [31:0] shift_token; // Holds last 4 characters for "PASS" / "FAIL" detection

    initial begin
        pass_seen   = 1'b0;
        fail_seen   = 1'b0;
        shift_token = 32'd0;
    end

    // Monitor serial stream on uart_tx_pin
    always @(negedge uart_tx_pin) begin
        if (rst_n) begin
            // Wait for middle of start bit
            #(HALF_PERIOD_NS);
            if (uart_tx_pin == 1'b0) begin
                // Sample 8 data bits
                #(BIT_PERIOD_NS); rx_char[0] = uart_tx_pin;
                #(BIT_PERIOD_NS); rx_char[1] = uart_tx_pin;
                #(BIT_PERIOD_NS); rx_char[2] = uart_tx_pin;
                #(BIT_PERIOD_NS); rx_char[3] = uart_tx_pin;
                #(BIT_PERIOD_NS); rx_char[4] = uart_tx_pin;
                #(BIT_PERIOD_NS); rx_char[5] = uart_tx_pin;
                #(BIT_PERIOD_NS); rx_char[6] = uart_tx_pin;
                #(BIT_PERIOD_NS); rx_char[7] = uart_tx_pin;

                // Stop bit wait
                #(BIT_PERIOD_NS);

                // Print received character in console
                $write("%c", rx_char);
                $fflush();

                // Shift token register: "PASS" = 0x50415353, "FAIL" = 0x4641494C
                shift_token = {shift_token[23:0], rx_char};

                if (shift_token == "PASS") begin
                    pass_seen <= 1'b1;
                end
                if (shift_token == "FAIL") begin
                    fail_seen <= 1'b1;
                end
            end
        end
    end

endmodule
