#include <stdint.h>

// ============================================================================
// 1. MMIO 寄存器地址定义 (严格按照项目手册规范)
// ============================================================================
#define REG32(addr) (*(volatile uint32_t *)(addr))

// UART 寄存器
#define UART_BASE 0x40000000u
#define UART_TXDATA REG32(UART_BASE + 0x00u)
#define UART_STATUS REG32(UART_BASE + 0x04u)
#define UART_TX_READY 0x00000001u

// 定时器寄存器
#define TIMER_BASE 0x40000010u
#define TIMER_STATUS REG32(TIMER_BASE + 0x00u)
#define TIMER_TICK 0x00000001u

// ============================================================================
// 2. 硬件抽象层 (HAL)
// ============================================================================
// 发送单个字符 (轮询等待 TX Ready)
static void uart_putc(char c)
{
    while ((UART_STATUS & UART_TX_READY) == 0u)
        ;
    UART_TXDATA = (uint32_t)(uint8_t)c;
}

// 发送字符串
static void uart_puts(const char *str)
{
    while (*str)
    {
        uart_putc(*str++);
    }
}

// 检查定时器 Tick 标志位
static int timer_tick_pending(void)
{
    return (TIMER_STATUS & TIMER_TICK) != 0u;
}

// 清除定时器 Tick 标志位 (写 1 清零)
static void timer_clear_tick(void)
{
    TIMER_STATUS = TIMER_TICK;
}

// ============================================================================
// 3. 辅助函数
// ============================================================================
// 裸机环境下没有 printf，手写一个打印两位数字的函数 (如 09, 23)
static void print_2digits(uint8_t val)
{
    uart_putc('0' + (val / 10)); // 打印十位
    uart_putc('0' + (val % 10)); // 打印个位
}

// ============================================================================
// 4. 主函数 (Mission Clock 逻辑)
// ============================================================================
int main(void)
{
    // 初始时间设定为 00:00:00
    uint8_t hours = 0;
    uint8_t minutes = 0;
    uint8_t seconds = 0;

    // [Bonus] VT100 终端控制：启动时清屏并将光标移到左上角
    uart_puts("\033[2J\033[H");

    while (1)
    {
        // 1. 打印任务时钟 (使用 \r 回车符使光标回到行首，实现原地更新显示)
        uart_puts("\rMISSION CLOCK ");
        print_2digits(hours);
        uart_putc(':');
        print_2digits(minutes);
        uart_putc(':');
        print_2digits(seconds);

        // 2. 阻塞等待：直到定时器产生 1 秒的 Tick 事件
        while (!timer_tick_pending())
        {
            // 空循环等待
        }

        // 3. 清除中断/挂起标志位，为下一秒做准备
        timer_clear_tick();

        // 4. 处理时间进位逻辑
        seconds++;
        if (seconds >= 60)
        {
            seconds = 0;
            minutes++;
            if (minutes >= 60)
            {
                minutes = 0;
                hours++;
                if (hours >= 24)
                {
                    hours = 0;
                }
            }
        }
    }

    return 0; // 嵌入式系统理论上永远不会执行到这里
}