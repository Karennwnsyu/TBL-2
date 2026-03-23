`timescale 1ns / 1ps

module uart #(
    // 请根据你们顶层 SoC 的实际系统时钟频率修改此参数
    // PYNQ-Z2 常用 50MHz 或 100MHz 
    parameter CLK_FREQ  = 50_000_000, 
    parameter BAUD_RATE = 115200
)(
    input  logic        clk,
    input  logic        rst_n,

    // CPU MMIO 总线接口 (匹配 PicoRV32 常用接口)
    input  logic        mem_valid,
    output logic        mem_ready,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata,

    // UART 物理引脚
    output logic        tx,
    input  logic        rx     // 基础要求中仅需 TX，RX 留作扩展接口
);

    // =========================================================================
    // 波特率生成器参数
    // =========================================================================
    localparam CLK_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // =========================================================================
    // 寄存器地址偏移定义
    // (顶层互联模块已剥离了 0x4000_0000 基地址，此处只需处理低位偏移)
    // =========================================================================
    localparam ADDR_TXDATA = 8'h00;
    localparam ADDR_STATUS = 8'h04;

    // =========================================================================
    // TX 状态机与内部信号
    // =========================================================================
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } tx_state_t;

    tx_state_t tx_state, tx_next;
    
    logic [31:0] clk_count;
    logic [2:0]  bit_index;
    logic [7:0]  tx_shift_reg;
    logic        tx_ready;
    logic        start_tx;

    // 当前系统是否允许接受新的发送请求
    assign tx_ready = (tx_state == IDLE);

    // =========================================================================
    // MMIO 总线读写逻辑
    // =========================================================================
    logic is_read;
    logic is_write;
    logic [7:0] offset;

    assign offset   = mem_addr[7:0];
    assign is_read  = mem_valid && (mem_wstrb == 4'b0000);
    assign is_write = mem_valid && (mem_wstrb != 4'b0000);

    // 握手响应：在这个简化的设计中，我们可以在 1 个周期内响应
    assign mem_ready = mem_valid;

    // 写操作逻辑：向 TXDATA 写入数据时触发发送
    assign start_tx = is_write && (offset == ADDR_TXDATA) && tx_ready;

    // 读操作逻辑：读取 STATUS 寄存器
    always_comb begin
        mem_rdata = 32'h0;
        if (is_read && (offset == ADDR_STATUS)) begin
            mem_rdata[0] = tx_ready; // bit [0] = tx_ready (1 = 可发送, 0 = 忙碌)
        end
    end

    // =========================================================================
    // UART TX 发送逻辑 (115200 8-N-1)
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state     <= IDLE;
            clk_count    <= 0;
            bit_index    <= 0;
            tx_shift_reg <= 8'h0;
            tx           <= 1'b1; // UART 空闲时保持高电平
        end else begin
            case (tx_state)
                IDLE: begin
                    tx        <= 1'b1;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (start_tx) begin
                        tx_shift_reg <= mem_wdata[7:0]; // 捕获要发送的数据
                        tx_state     <= START;
                    end
                end

                START: begin
                    tx <= 1'b0; // 发送起始位 (0)
                    if (clk_count < CLK_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        tx_state  <= DATA;
                    end
                end

                DATA: begin
                    tx <= tx_shift_reg[bit_index]; // 逐位发送数据
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
                    tx <= 1'b1; // 发送停止位 (1)
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