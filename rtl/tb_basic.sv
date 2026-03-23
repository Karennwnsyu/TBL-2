`timescale 1ns / 1ps

// Self-checking simulation for picorv32_soc_ref + clock.mem firmware (mission clock over UART).
// Run with simulation directory set so clock.mem is visible to $readmemh.

module tb_basic;

    // Accelerated timing: fast "seconds", fast UART bit times, still consistent ratios.
    localparam int unsigned CLK_HZ            = 1_000_000;
    localparam int unsigned UART_BAUD         = 100_000;
    localparam int unsigned TIMER_TICK_CYCLES = 10_000;
    localparam int unsigned CYCLES_PER_BIT    = CLK_HZ / UART_BAUD;

    // clk period #500 + #500 => 1000 ns; one DUT clk cycle = 1000 ns
    localparam int unsigned NS_PER_CLK = 1000;
    // One firmware "second" = TIMER_TICK_CYCLES clock cycles of the SoC
    localparam int unsigned NS_PER_TICK = TIMER_TICK_CYCLES * NS_PER_CLK;
    // Need >60 firmware seconds after boot to observe 00:00:00 -> 00:01:00
    localparam int unsigned TICKS_FOR_MINUTE_ROLLOVER = 72;

    logic clk;
    logic resetn;
    logic uart_rxd;
    logic uart_txd;

    string uart_log;

    // Return 1 if hay contains needle as a contiguous substring (ASCII).
    function bit str_contains(input string hay, input string needle);
        int i;
        int nlen;
        int hlen;
        nlen = needle.len();
        hlen = hay.len();
        if (nlen == 0 || hlen < nlen)
            return 0;
        for (i = 0; i <= hlen - nlen; i++) begin
            if (hay.substr(i, i + nlen - 1) == needle)
                return 1;
        end
        return 0;
    endfunction

    picorv32_soc_ref #(
        .CLK_HZ            (CLK_HZ),
        .UART_BAUD         (UART_BAUD),
        .TIMER_TICK_CYCLES (TIMER_TICK_CYCLES),
        .IMEM_HEX          ("clock.mem")
    ) dut (
        .clk      (clk),
        .resetn   (resetn),
        .uart_rxd (uart_rxd),
        .uart_txd (uart_txd)
    );

    // 1 MHz (simulation time)
    initial begin
        clk = 0;
        forever #500 clk = ~clk;
    end

    // 8N1 decoder: sync on start bit, sample mid-bit, LSB first, one stop bit.
    task uart_rx_monitor(input logic rx);
        logic [7:0] b;
        string      ch;
        integer     n;
        forever begin
            @(negedge rx);
            repeat (CYCLES_PER_BIT / 2) @(posedge clk);
            if (rx !== 1'b0)
                continue;

            for (n = 0; n < 8; n++) begin
                repeat (CYCLES_PER_BIT) @(posedge clk);
                b[n] = rx;
            end

            repeat (CYCLES_PER_BIT) @(posedge clk);
            ch = $sformatf("%c", b);
            uart_log = {uart_log, ch};
            $write("%c", b);
        end
    endtask

    initial begin
        uart_log = "";
        resetn   = 0;
        uart_rxd = 1;

        #2000;
        resetn = 1;

        fork
            uart_rx_monitor(uart_txd);
        join_none

        #(TICKS_FOR_MINUTE_ROLLOVER * NS_PER_TICK);

        $display("");
        if (!str_contains(uart_log, "MISSION CLOCK"))
            $fatal(1, "TB: expected substring MISSION CLOCK in UART log (check firmware / IMEM).");

        if (!str_contains(uart_log, "00:00:00"))
            $fatal(1, "TB: expected startup line containing 00:00:00 (firmware should start at 00:00:00).");

        if (!str_contains(uart_log, "00:01:00"))
            $fatal(1, "TB: expected 00:01:00 after simulated time (minute rollover / timer tick path).");

        $display("TB_PASS: mission clock UART self-check passed (MISSION CLOCK, 00:00:00, 00:01:00).");
        $finish;
    end

endmodule
