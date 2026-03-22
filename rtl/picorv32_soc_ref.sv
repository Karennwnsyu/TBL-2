`timescale 1ns / 1ps

module picorv32_soc_ref #(
    parameter int unsigned CLK_HZ            = 125_000_000,
    parameter int unsigned UART_BAUD         = 115_200,
    parameter int unsigned TIMER_TICK_CYCLES = 125_000_000,
    parameter string       IMEM_HEX          = "clock.mem",
    parameter logic [31:0] DMEM_BASE_ADDR    = 32'h0001_0000,
    parameter int unsigned DMEM_BYTES        = 8192,
    parameter int unsigned IMEM_WORDS        = 4096,
    parameter logic [31:0] UART_BASE       = 32'h4000_0000,
    parameter logic [31:0] TIMER_BASE      = 32'h4000_0010
) (
    input  logic        clk,
    input  logic        resetn,
    input  logic        uart_rxd,
    output logic        uart_txd
);

    localparam logic [31:0] STACKADDR   = DMEM_BASE_ADDR + DMEM_BYTES;
    localparam logic [31:0] IMEM_BYTES  = IMEM_WORDS * 4;
    localparam logic [31:0] UART_BYTES  = 32'd16;
    localparam logic [31:0] TIMER_BYTES = 32'd16;

    logic        trap;
    logic        mem_valid;
    logic        mem_instr;
    logic        mem_ready;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wstrb;
    logic [31:0] mem_rdata;

    logic [31:0] imem_rdata;
    logic [31:0] dmem_rdata;
    logic        imem_ready;
    logic        dmem_ready;

    logic [31:0] uart_rdata;
    logic        uart_ready;
    logic [31:0] timer_rdata;
    logic        timer_ready;

    logic        mem_we;
    logic        imem_hit;
    logic        dmem_hit;
    logic        uart_hit;
    logic        timer_hit;
    logic        invalid_ready;

    assign mem_we   = |mem_wstrb;
    assign imem_hit = (mem_addr < IMEM_BYTES) && !mem_we;
    assign dmem_hit = (mem_addr >= DMEM_BASE_ADDR) &&
                      (mem_addr < (DMEM_BASE_ADDR + DMEM_BYTES));
    assign uart_hit = (mem_addr >= UART_BASE) &&
                      (mem_addr < (UART_BASE + UART_BYTES));
    assign timer_hit = (mem_addr >= TIMER_BASE) &&
                       (mem_addr < (TIMER_BASE + TIMER_BYTES));

    picorv32 #(
        .ENABLE_COUNTERS    (1'b0),
        .ENABLE_COUNTERS64  (1'b0),
        .ENABLE_IRQ         (1'b0),
        .ENABLE_IRQ_TIMER   (1'b0),
        .ENABLE_MUL         (1'b0),
        .ENABLE_FAST_MUL    (1'b0),
        .ENABLE_DIV         (1'b0),
        .COMPRESSED_ISA     (1'b0),
        .REGS_INIT_ZERO     (1'b1),
        .PROGADDR_RESET     (32'h0000_0000),
        .PROGADDR_IRQ       (32'h0000_0010),
        .STACKADDR          (STACKADDR)
    ) u_cpu (
        .clk          (clk),
        .resetn       (resetn),
        .trap         (trap),
        .mem_valid    (mem_valid),
        .mem_instr    (mem_instr),
        .mem_ready    (mem_ready),
        .mem_addr     (mem_addr),
        .mem_wdata    (mem_wdata),
        .mem_wstrb    (mem_wstrb),
        .mem_rdata    (mem_rdata),
        .mem_la_read  (),
        .mem_la_write (),
        .mem_la_addr  (),
        .mem_la_wdata (),
        .mem_la_wstrb (),
        .pcpi_valid   (),
        .pcpi_insn    (),
        .pcpi_rs1     (),
        .pcpi_rs2     (),
        .pcpi_wr      (1'b0),
        .pcpi_rd      (32'd0),
        .pcpi_wait    (1'b0),
        .pcpi_ready   (1'b0),
        .irq          (32'd0),
        .eoi          ()
    );

    imem #(
        .WORDS   (IMEM_WORDS),
        .MEMFILE (IMEM_HEX)
    ) u_imem (
        .addr  (mem_addr),
        .rdata (imem_rdata)
    );

    dmem #(
        .BASE_ADDR (DMEM_BASE_ADDR),
        .BYTES     (DMEM_BYTES)
    ) u_dmem (
        .clk   (clk),
        .valid (mem_valid),
        .we    (mem_we),
        .be    (mem_wstrb),
        .addr  (mem_addr),
        .wdata (mem_wdata),
        .rdata (dmem_rdata),
        .ready (dmem_ready)
    );

    uart #(
        .CLK_HZ (CLK_HZ),
        .BAUD   (UART_BAUD)
    ) u_uart (
        .clk       (clk),
        .rst       (!resetn),
        .bus_valid (mem_valid && uart_hit),
        .bus_we    (mem_we),
        .bus_addr  (mem_addr),
        .bus_wdata (mem_wdata),
        .bus_rdata (uart_rdata),
        .bus_ready (uart_ready),
        .rx        (uart_rxd),
        .tx        (uart_txd)
    );

    timer #(
        .DEFAULT_PERIOD_CYCLES (TIMER_TICK_CYCLES),
        .BASE_ADDR             (TIMER_BASE)
    ) u_timer (
        .clk       (clk),
        .rst       (!resetn),
        .bus_valid (mem_valid && timer_hit),
        .bus_we    (mem_we),
        .bus_addr  (mem_addr),
        .bus_wdata (mem_wdata),
        .bus_rdata (timer_rdata),
        .bus_ready (timer_ready)
    );

    assign imem_ready = mem_valid && imem_hit;
    assign invalid_ready = mem_valid &&
        !(imem_hit || dmem_hit || uart_hit || timer_hit);

    assign mem_ready = imem_ready | dmem_ready | uart_ready | timer_ready |
        invalid_ready;

    assign mem_rdata = imem_ready  ? imem_rdata  :
                       dmem_ready  ? dmem_rdata  :
                       uart_ready  ? uart_rdata  :
                       timer_ready ? timer_rdata :
                       32'd0;

endmodule
