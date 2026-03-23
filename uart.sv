`timescale 1ns / 1ps

module uart #(
    parameter CLK_HZ    = 62_500_000, // 从顶层继承的 62.5MHz 系统时钟
    parameter UART_BAUD = 115200      // 波特率
)(
    input  logic        clk,
    input  logic        rst_n,

    // PicoRV32 MMIO 总线接口
    input  logic        mem_valid,
    output logic        mem_ready,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata,

    // 物理引脚
    output logic        tx,
    input  logic        rx
);

    // 计算每个 bit 需要的时钟周期数 (62.5MHz / 115200 ≈ 542)
    localparam CLK_PER_BIT = CLK_HZ / UART_BAUD;
    
    localparam ADDR_TXDATA = 8'h00;
    localparam ADDR_STATUS = 8'h04;

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } tx_state_t;

    tx_state_t tx_state;
    
    logic [31:0] clk_count;
    logic [2:0]  bit_index;
    logic [7:0]  tx_shift_reg;
    logic        tx_ready;
    logic        start_tx;

    assign tx_ready = (tx_state == IDLE);

    // 总线读写控制
    logic is_read;
    logic is_write;
    logic [7:0] offset;

    assign offset   = mem_addr[7:0];
    assign is_read  = mem_valid && (mem_wstrb == 4'b0000);
    assign is_write = mem_valid && (mem_wstrb != 4'b0000);

    // 直接响应握手
    assign mem_ready = mem_valid;

    // 写 TXDATA 触发发送
    assign start_tx = is_write && (offset == ADDR_TXDATA) && tx_ready;

    // 读 STATUS 寄存器
    always_comb begin
        mem_rdata = 32'h0;
        if (is_read && (offset == ADDR_STATUS)) begin
            mem_rdata[0] = tx_ready;
        end
    end

    // 状态机
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state     <= IDLE;
            clk_count    <= 0;
            bit_index    <= 0;
            tx_shift_reg <= 8'h0;
            tx           <= 1'b1;
        end else begin
            case (tx_state)
                IDLE: begin
                    tx        <= 1'b1;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (start_tx) begin
                        tx_shift_reg <= mem_wdata[7:0];
                        tx_state     <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;
                    if (clk_count < CLK_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        tx_state  <= DATA;
                    end
                end

                DATA: begin
                    tx <= tx_shift_reg[bit_index];
                    if (clk_count < CLK_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            tx_state <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (clk_count < CLK_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        tx_state  <= IDLE;
                    end
                end
                
                default: tx_state <= IDLE;
            endcase
        end
    end

endmodule
