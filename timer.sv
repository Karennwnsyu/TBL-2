`timescale 1ns / 1ps

module timer #(
    parameter CLK_HZ = 62_500_000 // 顶层传下来的 62.5MHz
)(
    input  logic        clk,
    input  logic        rst_n,

    // PicoRV32 MMIO 总线接口
    input  logic        mem_valid,
    output logic        mem_ready,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata
);

    localparam ADDR_STATUS = 8'h00;
    localparam ADDR_VALUE  = 8'h04;

    logic [31:0] sec_counter;
    logic        tick_pending;

    // 当计数值达到 CLK_HZ - 1 时，说明刚好过去了 1 秒钟
    logic tick_event;
    assign tick_event = (sec_counter == CLK_HZ - 1);

    // 1秒钟计数器
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

    // 总线读写控制
    logic is_read;
    logic is_write;
    logic [7:0] offset;

    assign offset   = mem_addr[7:0];
    assign is_read  = mem_valid && (mem_wstrb == 4'b0000);
    assign is_write = mem_valid && (mem_wstrb != 4'b0000);

    // 直接响应握手
    assign mem_ready = mem_valid;

    // 处理 tick_pending 标志位
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_pending <= 1'b0;
        end else begin
            // 硬件自动置位
            if (tick_event) begin
                tick_pending <= 1'b1;
            end 
            // 固件通过向 STATUS[0] 写入 1 来清零 (Write-1-to-Clear)
            else if (is_write && (offset == ADDR_STATUS) && mem_wdata[0]) begin
                tick_pending <= 1'b0;
            end
        end
    end

    // 总线读数据
    always_comb begin
        mem_rdata = 32'h0;
        if (is_read) begin
            case (offset)
                ADDR_STATUS: mem_rdata[0] = tick_pending;
                ADDR_VALUE:  mem_rdata    = sec_counter; 
                default:     mem_rdata    = 32'h0;
            endcase
        end
    end

endmodule
