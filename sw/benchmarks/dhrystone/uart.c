#include <stdint.h>

#define UART_TX_ADDR 0x10000000

void uart_putc(char c) {
    volatile char *uart = (volatile char *)UART_TX_ADDR;
    *uart = c;
}

void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

void uart_put_hex(uint64_t val) {
    const char hex[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 60; i >= 0; i -= 4) {
        uart_putc(hex[(val >> i) & 0xF]);
    }
}

// 32-bit version for compatibility if needed, but 64-bit covers both
void uart_put_hex32(uint32_t val) {
    uart_put_hex((uint64_t)val);
}

void uart_newline(void) {
    uart_putc('\r');
    uart_putc('\n');
}
