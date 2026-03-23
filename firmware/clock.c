#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))

#define UART_BASE     0x40000000u
#define UART_TXDATA   REG32(UART_BASE + 0x00u)
#define UART_STATUS   REG32(UART_BASE + 0x04u)
#define UART_TX_READY 0x00000001u

#define TIMER_BASE    0x40000010u
#define TIMER_STATUS  REG32(TIMER_BASE + 0x00u)
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

static const char HOUR_PAIR[] =
    "000102030405060708091011121314151617181920212223";
static const char MS_PAIR[] =
    "000102030405060708091011121314151617181920212223242526272829"
    "303132333435363738394041424344454647484950515253545556575859";

static const char SPIN[] = "|/-\\";

static void uart_put_hh(unsigned h) {
    unsigned i = h << 1;
    uart_putc(HOUR_PAIR[i]);
    uart_putc(HOUR_PAIR[i + 1u]);
}

static void uart_put_pair(unsigned v) {
    unsigned i = v << 1;
    uart_putc(MS_PAIR[i]);
    uart_putc(MS_PAIR[i + 1u]);
}

// Row 3: in-place time (cyan); EL clears any longer previous line.
static void ui_time_line(int h, int m, int s) {
    uart_puts("\033[3;1H\033[1;36m");
    uart_put_hh((unsigned)h);
    uart_putc(':');
    uart_put_pair((unsigned)m);
    uart_putc(':');
    uart_put_pair((unsigned)s);
    uart_puts("\033[0m\033[K");
}

// Row 4: status (yellow) + spinner index via (sec & 3), no div/mod.
static void ui_status_line(unsigned sec) {
    uart_puts("\033[4;1H\033[1;33mSTATUS: RUNNING\033[0m ");
    uart_putc(SPIN[sec & 3u]);
    uart_puts(" \033[K");
}

static void ui_init(void) {
    uart_puts("\033[2J\033[H");
    uart_puts("\033[1;32mRISC-V MISSION CLOCK\033[0m\r\n\r\n");
}

int main(void) {
    int hours   = 0;
    int minutes = 0;
    int seconds = 0;

    ui_init();
    ui_time_line(hours, minutes, seconds);
    ui_status_line((unsigned)seconds);

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

            ui_time_line(hours, minutes, seconds);
            ui_status_line((unsigned)seconds);
        }
    }
}
