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
    while ((UART_STATUS & UART_TX_READY) == 0u)
        ;
    UART_TXDATA = (uint32_t)(uint8_t)c;
}

static void uart_puts(const char *s) {
    while (*s)
        uart_putc(*s++);
}

static int timer_tick_pending(void) {
    return (TIMER_STATUS & TIMER_TICK) != 0u;
}

static void timer_clear_tick(void) {
    TIMER_STATUS = TIMER_TICK;
}

// 0..99 -> two digits, no compiler div/mod helpers (freestanding -nostdlib)
static void uart_put2digits(unsigned v) {
    unsigned tens = 0;
    unsigned u    = v;
    while (u >= 10u) {
        u -= 10u;
        tens++;
    }
    uart_putc((char)('0' + tens));
    uart_putc((char)('0' + u));
}

static void print_time(int h, int m, int s) {
    uart_puts("MISSION CLOCK ");
    uart_put2digits((unsigned)h);
    uart_putc(':');
    uart_put2digits((unsigned)m);
    uart_putc(':');
    uart_put2digits((unsigned)s);
    uart_puts("\r");
}

int main(void) {
    int hours   = 0;
    int minutes = 0;
    int seconds = 0;

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
                    if (hours == 24)
                        hours = 0;
                }
            }

            print_time(hours, minutes, seconds);
        }
    }
}
