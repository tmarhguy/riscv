/*
 * IronCore UART Driver
 * Simple memory-mapped UART for bare-metal output
 */

#ifndef UART_H
#define UART_H

#include <stdint.h>

// UART base address (per memory map in PRD)
#define UART_BASE 0x10000000

// UART registers
#define UART_TX   (*(volatile uint8_t*)(UART_BASE + 0x00))

// Initialize UART (placeholder for now)
static inline void uart_init(void) {
    // No initialization needed for simple TX-only UART
}

// Send a single character
static inline void uart_putc(char c) {
    UART_TX = c;
}

// Send a string
static inline void uart_puts(const char* s) {
    while (*s) {
        uart_putc(*s++);
    }
}

// Print a 32-bit hex value
static inline void uart_put_hex_digit(uint8_t v) {
    if (v < 10) uart_putc('0' + v);
    else uart_putc('A' + (v - 10));
}

static inline void uart_put_hex(uint32_t val) {
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uart_put_hex_digit((val >> i) & 0xF);
    }
}

// Print a newline
static inline void uart_newline(void) {
    uart_putc('\r');
    uart_putc('\n');
}

#endif // UART_H
