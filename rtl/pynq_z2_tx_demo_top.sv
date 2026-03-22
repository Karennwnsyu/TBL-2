`timescale 1ns / 1ps

module pynq_z2_tx_demo_top #(
    parameter string IMEM_HEX = "clock.mem"
) (
    input  logic       clk_125mhz,
    input  logic       uart_rxd,
    output logic       uart_txd
);

    localparam int unsigned SOC_CLK_HZ = 62_500_000;

    logic [15:0] por_counter   = 16'd0;
    logic        por_done      = 1'b0;

    logic        pll_locked;
    logic        pll_clkfb;
    logic        pll_clkfb_buf;
    logic        soc_clk_unbuf;
    logic        soc_clk;

    logic        pll_locked_meta = 1'b0;
    logic        pll_locked_sync = 1'b0;
    logic        pll_lock_seen   = 1'b0;

    logic        rst_req;
    logic [3:0]  reset_sync = 4'b0000;
    logic        resetn;

    logic        pll_drop_latched = 1'b0;

    // Board-level heartbeat and startup qualification in the raw 125 MHz domain.
    always_ff @(posedge clk_125mhz) begin

        if (!por_done) begin
            por_counter <= por_counter + 1'b1;
            if (&por_counter)
                por_done <= 1'b1;
        end

        pll_locked_meta <= pll_locked;
        pll_locked_sync <= pll_locked_meta;

        // Use LOCKED only to qualify startup. After we have seen a stable lock once,
        // do not keep feeding live LOCKED back into the SoC reset request; otherwise
        // tiny lock glitches can asynchronously reset the whole system at runtime.
        if (pll_locked_sync)
            pll_lock_seen <= 1'b1;

        // Debug aid: remember if LOCKED ever drops after initial startup.
        if (pll_lock_seen && !pll_locked_sync)
            pll_drop_latched <= 1'b1;
    end

    // 7-series-compatible PLL: 125 MHz in -> 62.5 MHz out.
    PLLE2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(8.000),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT(8),
        .CLKFBOUT_PHASE(0.0),
        .CLKOUT0_DIVIDE(16),
        .CLKOUT0_PHASE(0.0),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .REF_JITTER1(0.010)
    ) u_soc_pll (
        .CLKIN1   (clk_125mhz),
        .CLKFBIN  (pll_clkfb_buf),
        .RST      (1'b0),
        .PWRDWN   (1'b0),
        .CLKFBOUT (pll_clkfb),
        .CLKOUT0  (soc_clk_unbuf),
        .CLKOUT1  (),
        .CLKOUT2  (),
        .CLKOUT3  (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .LOCKED   (pll_locked)
    );

    BUFG u_soc_clk_fb_bufg (
        .I(pll_clkfb),
        .O(pll_clkfb_buf)
    );

    BUFG u_soc_clk_bufg (
        .I(soc_clk_unbuf),
        .O(soc_clk)
    );

    // Reset during initial POR, or before the PLL has been seen locked.
    // Note: we intentionally do NOT keep OR-ing in live ~pll_locked after startup.
    assign rst_req = ~por_done | ~pll_lock_seen;

    // Asynchronous assert, synchronous release into the SoC clock domain.
    always_ff @(posedge soc_clk or posedge rst_req) begin
        if (rst_req) begin
            reset_sync   <= 4'b0000;
        end else begin
            reset_sync <= {reset_sync[2:0], 1'b1};
        end
    end

    assign resetn = reset_sync[3];

    picorv32_soc_ref #(
        .CLK_HZ            (SOC_CLK_HZ),
        .UART_BAUD         (115_200),
        .TIMER_TICK_CYCLES (SOC_CLK_HZ),
        .IMEM_HEX          (IMEM_HEX)
    ) u_soc (
        .clk            (soc_clk),
        .resetn         (resetn),
        .uart_rxd       (uart_rxd),
        .uart_txd       (uart_txd)
    );

endmodule
