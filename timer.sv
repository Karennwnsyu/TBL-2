`timescale 1ns / 1ps

module timer #(
    // 系统时钟频率，决定了 1 秒钟需要计数多少次
    // PYNQ-Z2 常用 50MHz
    parameter CLK_FREQ = 50_000_000 
)(
    input  logic        clk,
    input  logic        rst_n,

    // CPU MMIO 总线接口 (与 UART 模块保持一致)
    input  logic        mem_valid,
    output logic        mem_ready,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata
);

    // =========================================================================
    // 寄存器地址偏移定义
    // (基地址 0x4000_0010 已经在顶层互联中剥离)
    // =========================================================================
    localparam ADDR_STATUS = 8'h00;
    localparam ADDR_VALUE  = 8'h04;

    // =========================================================================
    // 内部寄存器与计数逻辑
    // =========================================================================
    logic [31:0] sec_counter;
    logic        tick_pending;

    // 1秒钟到达的标志
    logic tick_event;
    assign tick_event = (sec_counter == CLK_FREQ - 1);

    // 计数器逻辑：不断循环计数，达到 1 秒频率时清零
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_counter <= 32'h0;
        end else begin
            if (tick_event) begin
                sec_counter <= 32'h0;
            end else begin
                sec_counter <= sec_counter + 1;
            end
        end
    end

    // =========================================================================
    // MMIO 总线读写逻辑
    // =========================================================================
    logic is_read;
    logic is_write;
    logic [7:0] offset;

    assign offset   = mem_addr[7:0];
    assign is_read  = mem_valid && (mem_wstrb == 4'b0000);
    assign is_write = mem_valid && (mem_wstrb != 4'b0000);

    // 简单总线，1个周期内直接准备好响应
    assign mem_ready = mem_valid;

    // 状态机处理 tick_pending 标志位
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_pending <= 1'b0;
        end else begin
            // 硬件置位：达到1秒时，硬件自动将 pending 置为 1
            if (tick_event) begin
                tick_pending <= 1'b1;
            end 
            // 软件清零 (Write-1-to-Clear)：
            // 如果 CPU 写入 STATUS 寄存器，并且 bit 0 是 1，则清零
            else if (is_write && (offset == ADDR_STATUS) && mem_wdata[0]) begin
                tick_pending <= 1'b0;
            end
        end
    end

    // 总线读数据通路
    always_comb begin
        mem_rdata = 32'h0; // 默认输出 0
        if (is_read) begin
            case (offset)
                ADDR_STATUS: mem_rdata[0] = tick_pending; // 读 bit [0] 获取状态
                ADDR_VALUE:  mem_rdata    = sec_counter;  // (可选功能) 读当前计数值，方便仿真调试
                default:     mem_rdata    = 32'h0;
            endcase
        end
    end

endmodule