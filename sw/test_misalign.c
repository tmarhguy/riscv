/*
 * Misaligned Access Trap Test
 * Tests that misaligned loads and stores properly trap
 */

#include <stdint.h>

#define TOHOST_ADDR 0x80001000
#define CSR_MEPC    0x341
#define CSR_MCAUSE  0x342
#define CSR_MTVEC   0x305

#define EXC_LOAD_MISALIGN  4
#define EXC_STORE_MISALIGN 6

volatile uint32_t *tohost = (volatile uint32_t *)TOHOST_ADDR;
volatile uint32_t trap_count = 0;
volatile uint32_t last_cause = 0;
volatile uint32_t last_epc = 0;

// Trap handler (set via mtvec)
void trap_handler(void) __attribute__((interrupt));
void trap_handler(void) {
    uint32_t cause, epc;
    
    // Read mcause and mepc
    asm volatile("csrr %0, mcause" : "=r"(cause));
    asm volatile("csrr %0, mepc" : "=r"(epc));
    
    last_cause = cause;
    last_epc = epc;
    trap_count++;
    
    // Skip the faulting instruction (move to next instruction)
    epc += 4;
    asm volatile("csrw mepc, %0" :: "r"(epc));
}

int main(void) {
    uint32_t value;
    uint32_t *aligned_ptr = (uint32_t *)0x80000100;
    uint16_t *half_misaligned = (uint16_t *)0x80000101;  // Misaligned halfword
    uint32_t *word_misaligned = (uint32_t *)0x80000102;  // Misaligned word
    
    // Set trap handler
    asm volatile("la t0, trap_handler");
    asm volatile("csrw mtvec, t0");
    
    // Test 1: Aligned access (should work)
    *aligned_ptr = 0x12345678;
    value = *aligned_ptr;
    
    // Test 2: Misaligned halfword load (should trap)
    trap_count = 0;
    value = *half_misaligned;
    if (trap_count != 1 || last_cause != EXC_LOAD_MISALIGN) {
        *tohost = 0xBAD00001;  // Test failed
        while(1);
    }
    
    // Test 3: Misaligned halfword store (should trap)
    trap_count = 0;
    *half_misaligned = 0x1234;
    if (trap_count != 1 || last_cause != EXC_STORE_MISALIGN) {
        *tohost = 0xBAD00002;  // Test failed
        while(1);
    }
    
    // Test 4: Misaligned word load (should trap)
    trap_count = 0;
    value = *word_misaligned;
    if (trap_count != 1 || last_cause != EXC_LOAD_MISALIGN) {
        *tohost = 0xBAD00003;  // Test failed
        while(1);
    }
    
    // Test 5: Misaligned word store (should trap)
    trap_count = 0;
    *word_misaligned = 0xDEADBEEF;
    if (trap_count != 1 || last_cause != EXC_STORE_MISALIGN) {
        *tohost = 0xBAD00004;  // Test failed
        while(1);
    }
    
    // All tests passed!
    *tohost = 1;
    while(1);
    
    return 0;
}
