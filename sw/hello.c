/*
 * IronCore Demo Program
 * Simple "Hello World" for bare-metal RV32IM
 */

#include "uart.h"

int main(void) {
    uart_init();

    uart_puts("Hello IronCore!\r\n");
    uart_puts("RV32IM 5-Stage Pipeline\r\n");
    uart_puts("========================\r\n");

    // Signal test start
#define TOHOST_ADDR 0x80001000
    volatile uint32_t *tohost = (volatile uint32_t *)TOHOST_ADDR;

    // Test some basic operations
    volatile uint32_t a = 42;
    volatile uint32_t b = 8;
    volatile uint32_t sum = a + b;

    uart_puts("42 + 8 = ");
    uart_put_hex(sum);
    uart_newline();

    // Test multiplication (M extension)
    volatile uint32_t product = a * b;
    uart_puts("42 * 8 = ");
    uart_put_hex(product);
    uart_newline();

    // Test division (M extension)
    volatile uint32_t quotient = product / a;
    uart_puts("336 / 42 = ");
    uart_put_hex(quotient);
    uart_newline();

    uart_puts("\r\nTests complete!\r\n");

    // Signal success to testbench
    *tohost = 1;

    // Infinite loop to keep simulator happy until it detects TOHOST write
    while (1) {
    }

    return 0;
}
