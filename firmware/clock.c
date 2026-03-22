#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))

#define UART_BASE     0x40000000u
#define UART_TXDATA   REG32(UART_BASE + 0x00u)
#define UART_STATUS   REG32(UART_BASE + 0x04u)
#define UART_TX_READY 0x00000001u

#define TIMER_BASE    0x40000010u
#define TIMER_STATUS  REG32(TIMER_BASE + 0x00u)
#define TIMER_VALUE   REG32(TIMER_BASE + 0x04u)
#define TIMER_TICK    0x00000001u

static void uart_putc(char c) {
    while ((UART_STATUS & UART_TX_READY) == 0u);
    UART_TXDATA = (uint32_t)(uint8_t)c;
}

static void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

static int timer_tick_pending(void) {
    return (TIMER_STATUS & TIMER_TICK) != 0u;
}

static void timer_clear_tick(void) {
    TIMER_STATUS = TIMER_TICK; // write-1-to-clear
}

static void print_time(int h, int m, int s) {
    char buf[32];
    
    // Format "MISSION CLOCK HH:MM:SS\r"
    // Using simple modulo / division since standard library might be stripped or too big
    buf[0] = 'M'; buf[1] = 'I'; buf[2] = 'S'; buf[3] = 'S'; buf[4] = 'I';
    buf[5] = 'O'; buf[6] = 'N'; buf[7] = ' '; buf[8] = 'C'; buf[9] = 'L';
    buf[10] = 'O'; buf[11] = 'C'; buf[12] = 'K'; buf[13] = ' ';
    
    buf[14] = '0' + (h / 10);
    buf[15] = '0' + (h % 10);
    buf[16] = ':';
    buf[17] = '0' + (m / 10);
    buf[18] = '0' + (m % 10);
    buf[19] = ':';
    buf[20] = '0' + (s / 10);
    buf[21] = '0' + (s % 10);
    buf[22] = '\r';
    buf[23] = '\0';
    
    uart_puts(buf);
}

int main(void) {
    int hours = 0;
    int minutes = 0;
    int seconds = 0;

    // Optional VT100: Clear screen and reset cursor on boot
    uart_puts("\033[2J\033[H");
    
    print_time(hours, minutes, seconds);

    while (1) {
        if (timer_tick_pending()) {
            timer_clear_tick();
            
            seconds++;
            if (seconds == 60) {
                seconds = 0;
                minutes++;
                if (minutes == 60) {
                    minutes = 0;
                    hours++;
                    if (hours == 24) {
                        hours = 0;
                    }
                }
            }
            
            print_time(hours, minutes, seconds);
        }
    }
    
    return 0;
}
