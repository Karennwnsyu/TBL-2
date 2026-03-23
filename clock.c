#include <stdint.h>

// --- 硬件寄存器定义 ---
#define REG32(addr) (*(volatile uint32_t *)(addr))
#define UART_BASE      0x40000000u
#define UART_TXDATA    REG32(UART_BASE + 0x00u)
#define UART_STATUS    REG32(UART_BASE + 0x04u)
#define UART_RXDATA    REG32(UART_BASE + 0x08u)
#define UART_TX_READY  0x00000001u
#define UART_RX_VALID  0x00000002u

#define TIMER_BASE     0x40000010u
#define TIMER_STATUS   REG32(TIMER_BASE + 0x00u)
#define TIMER_TICK     0x00000001u

// --- ANSI/VT100 转义码定义 ---
#define CLEAR_SCREEN  "\033[2J\033[H"   // 清屏并将光标移到左上角
#define COLOR_GREEN   "\033[1;32m"      // 高亮绿色
#define COLOR_CYAN    "\033[1;36m"      // 高亮青色
#define COLOR_RESET   "\033[0m"         // 恢复默认颜色
#define CURSOR_CLOCK  "\033[5;1H"       // 将光标绝对定位到第 5 行，第 1 列
#define CLEAR_LINE    "\033[K"          // 清除光标到行尾的内容

// --- 基础通信函数 ---
static void uart_putc(char c) {
    while ((UART_STATUS & UART_TX_READY) == 0u);
    UART_TXDATA = (uint32_t)(uint8_t)c;
}

static void uart_puts(const char *str) {
    while (*str) uart_putc(*str++);
}

static int timer_tick_pending(void) {
    return (TIMER_STATUS & TIMER_TICK) != 0u;
}

static void timer_clear_tick(void) {
    TIMER_STATUS = TIMER_TICK; 
}

static void print_2digits(uint8_t val) {
    uart_putc('0' + (val / 10));
    uart_putc('0' + (val % 10));
}

// --- 绘制静态的控制台框架 ---
static void draw_console_layout(void) {
    uart_puts(CLEAR_SCREEN);
    uart_puts(COLOR_GREEN);
    uart_puts("===================================\r\n");
    uart_puts(" Open-Source Space Shuttle Console \r\n");
    uart_puts("===================================\r\n");
    uart_puts(COLOR_RESET);
}

// --- 主循环 ---
int main(void) {
    uint8_t hours = 0;   
    uint8_t minutes = 57;
    uint8_t seconds = 0;
    uint8_t blink_flag = 1;

    // 1. 系统启动时绘制静态 UI
    draw_console_layout();

    while (1) {
        // 2. 定位到第 5 行原地刷新时钟 (避免屏幕滚动)
        uart_puts(CURSOR_CLOCK);
        uart_puts(COLOR_CYAN);
        uart_puts("MISSION CLOCK ");
        
        print_2digits(hours);
        uart_putc(blink_flag ? ':' : ' '); // 闪烁的冒号
        print_2digits(minutes);
        uart_putc(blink_flag ? ':' : ' ');
        print_2digits(seconds);
        
        uart_puts(CLEAR_LINE);
        uart_puts(COLOR_RESET);

        // 3. 轮询等待 1 秒，期间检查键盘输入
        while (!timer_tick_pending()) {
            if (UART_STATUS & UART_RX_VALID) {
                char cmd = UART_RXDATA; 
                // 按键调整时间
                if (cmd == 'h' || cmd == 'H') {
                    hours++; if (hours >= 24) hours = 0;
                } else if (cmd == 'm' || cmd == 'M') {
                    minutes++; if (minutes >= 60) minutes = 0;
                } else if (cmd == 's' || cmd == 'S') {
                    seconds++; if (seconds >= 60) seconds = 0;
                }
                
                // 按键后立刻提供视觉反馈（强制显示冒号）
                uart_puts(CURSOR_CLOCK);
                uart_puts(COLOR_CYAN);
                uart_puts("MISSION CLOCK ");
                print_2digits(hours); uart_putc(':');
                print_2digits(minutes); uart_putc(':');
                print_2digits(seconds);
                uart_puts(CLEAR_LINE);
                uart_puts(COLOR_RESET);
            }
        }
        
        timer_clear_tick();

        // 4. 冒号闪烁状态翻转
        blink_flag = !blink_flag;

        // 5. 自然时间进位
        seconds++;
        if (seconds >= 60) {
            seconds = 0;
            minutes++;
            if (minutes >= 60) {
                minutes = 0;
                hours++;
                if (hours >= 24) {
                    hours = 0;
                }
            }
        }
    }
    return 0;
}
