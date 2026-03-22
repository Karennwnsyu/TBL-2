`timescale 1ns / 1ps

module tb_basic;

    // Fast simulation parameters
    localparam int unsigned CLK_HZ            = 1_000_000;
    localparam int unsigned UART_BAUD         = 100_000;
    localparam int unsigned TIMER_TICK_CYCLES = 10_000;
    localparam int unsigned CYCLES_PER_BIT    = CLK_HZ / UART_BAUD;

    logic clk;
    logic resetn;
    logic uart_rxd;
    logic uart_txd;

    // Vivado: set simulation run dir to project root (where `make` writes clock.mem)
    picorv32_soc_ref #(
        .CLK_HZ            (CLK_HZ),
        .UART_BAUD         (UART_BAUD),
        .TIMER_TICK_CYCLES (TIMER_TICK_CYCLES),
        .IMEM_HEX          ("clock.mem")
    ) uut (
        .clk        (clk),
        .resetn     (resetn),
        .uart_rxd   (uart_rxd),
        .uart_txd   (uart_txd)
    );

    // Clock generation (1 MHz)
    initial begin
        clk = 0;
        forever #500 clk = ~clk;
    end

    // UART RX monitoring task
    task uart_rx_monitor(input logic rx);
        logic [7:0] rx_byte;
        forever begin
            // Wait for start bit
            @(negedge rx);
            // Wait half bit period
            repeat (CYCLES_PER_BIT / 2) @(posedge clk);
            if (rx !== 0) continue; // False start

            // Sample 8 bits
            for (int i = 0; i < 8; i++) begin
                repeat (CYCLES_PER_BIT) @(posedge clk);
                rx_byte[i] = rx;
            end

            // Wait for stop bit
            repeat (CYCLES_PER_BIT) @(posedge clk);
            $write("%c", rx_byte);
        end
    endtask

    initial begin
        $dumpfile("tb_basic.vcd");
        $dumpvars(0, tb_basic);

        resetn   = 0;
        uart_rxd = 1;

        #2000;
        resetn = 1;

        // Start UART monitor in background
        fork
            uart_rx_monitor(uart_txd);
        join_none

        // Wait enough time for 3 seconds to elapse (3 * TIMER_TICK_CYCLES * 1000ns)
        // 1 tick = 10,000 cycles = 10ms in simulation time. So 3 ticks = 30ms.
        #40_000_000; 

        $display("\nSimulation finished.");
        $finish;
    end

endmodule
