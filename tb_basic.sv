`timescale 1ns / 1ps

module tb_basic;

    // =========================================================================
    // 1. 基础信号与时钟生成
    // =========================================================================
    logic clk;
    logic rst_n;

    // 模拟 50MHz 时钟 (周期 20ns)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // =========================================================================
    // 2. 模拟 CPU MMIO 总线信号
    // =========================================================================
    logic        mem_valid;
    logic        uart_mem_ready, timer_mem_ready;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wstrb;
    logic [31:0] uart_mem_rdata, timer_mem_rdata;

    // 物理引脚
    logic tx;
    logic rx = 1'b1; // RX 保持空闲高电平

    // =========================================================================
    // 3. 实例化被测模块 (DUT)
    // =========================================================================
    // 实例化 UART (为了仿真快点，波特率可以设高或者保持原样看波形)
    uart #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(115200)
    ) dut_uart (
        .clk(clk),
        .rst_n(rst_n),
        .mem_valid(mem_valid && (mem_addr[31:8] == 24'h400000)), // 地址解码匹配 UART 基址
        .mem_ready(uart_mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(uart_mem_rdata),
        .tx(tx),
        .rx(rx)
    );

    // 实例化 Timer 
    // 【关键】将 CLK_FREQ 设为极小值(例如 100)，这样每 100 个周期就会触发一次 tick，加速仿真！
    timer #(
        .CLK_FREQ(100) 
    ) dut_timer (
        .clk(clk),
        .rst_n(rst_n),
        .mem_valid(mem_valid && (mem_addr[31:8] == 24'h400000)), // 此处简化地址解码
        .mem_ready(timer_mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(timer_mem_rdata)
    );

    // =========================================================================
    // 4. 总线读写 Task (方便在 initial 块中调用)
    // =========================================================================
    task mmio_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            mem_valid <= 1'b1;
            mem_addr  <= addr;
            mem_wdata <= data;
            mem_wstrb <= 4'b1111; // 32位全写
            @(posedge clk);
            mem_valid <= 1'b0;
            mem_wstrb <= 4'b0000;
        end
    task end

    task mmio_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            mem_valid <= 1'b1;
            mem_addr  <= addr;
            mem_wstrb <= 4'b0000; // 0 表示读操作
            @(posedge clk);
            // 简单总线，下一周期出数据。根据地址判断取哪个模块的数据
            if (addr[7:0] == 8'h00 || addr[7:0] == 8'h04) begin
                // 这里为了简化 TB，直接根据具体测试场景读取
            end
            mem_valid <= 1'b0;
        end
    task end

    // =========================================================================
    // 5. 主测试流程 (Test Sequence)
    // =========================================================================
    logic [31:0] read_val;

    initial begin
        // 初始化信号
        mem_valid = 0;
        mem_addr  = 0;
        mem_wdata = 0;
        mem_wstrb = 0;
        rst_n     = 0;

        $display("=== 仿真开始 ===");

        // 复位系统 [cite: 389]
        #100;
        rst_n = 1;
        #50;

        $display("1. 测试 UART 发送字符 'M' (0x4D) ...");
        mmio_write(32'h4000_0000, 32'h0000_004D);
        
        // 等待一段时间让 UART 把数据串行发出去
        // 115200 波特率发一个字节大概需要 86us
        #100000; 

        $display("2. 测试 Timer Tick 行为 ...");
        // 等待几百个周期，让加速后的 Timer 触发 tick 
        #3000;
        
        $display("3. 测试 Timer 清除机制 ...");
        // 向 TIMER_STATUS[0] 写入 1 来清除 pending 标志
        mmio_write(32'h4000_0010, 32'h0000_0001);

        #500;
        $display("=== 基础仿真测试完成 ===");
        $finish;
    end

endmodule