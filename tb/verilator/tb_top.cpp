// IronCore Verilator Testbench
// Simple C++ testbench for command-line simulation

#include <verilated.h>
#include <verilated_fst_c.h>
#include "Vironcore_top.h"

#include <memory>
#include <iostream>
#include <cstdint>
#include <vector>

class Memory {
public:
    std::vector<uint8_t> data;
    size_t size;

    Memory(size_t sz) : size(sz), data(sz, 0) {}

    void write_word(uint32_t addr, uint32_t val) {
        addr &= 0xFFFFFFFC;  // Word align
        if (addr + 3 < size) {
            data[addr + 0] = val & 0xFF;
            data[addr + 1] = (val >> 8) & 0xFF;
            data[addr + 2] = (val >> 16) & 0xFF;
            data[addr + 3] = (val >> 24) & 0xFF;
        }
    }

    uint32_t read_word(uint32_t addr) {
        addr &= 0xFFFFFFFC;
        if (addr + 3 < size) {
            return data[addr + 0] |
                   (data[addr + 1] << 8) |
                   (data[addr + 2] << 16) |
                   (data[addr + 3] << 24);
        }
        return 0;
    }

    void write_byte(uint32_t addr, uint8_t val, uint8_t sel) {
        if (addr < size && (sel & 0x1)) data[addr] = val;
        if (addr + 1 < size && (sel & 0x2)) data[addr + 1] = (val >> 8) & 0xFF;
        if (addr + 2 < size && (sel & 0x4)) data[addr + 2] = (val >> 16) & 0xFF;
        if (addr + 3 < size && (sel & 0x8)) data[addr + 3] = (val >> 24) & 0xFF;
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    // Create DUT
    auto dut = std::make_unique<Vironcore_top>();

    // Create trace
    Verilated::traceEverOn(true);
    auto trace = std::make_unique<VerilatedFstC>();
    dut->trace(trace.get(), 99);
    trace->open("waves/ironcore.fst");

    // Create memories
    Memory imem(64 * 1024);  // 64KB instruction memory
    Memory dmem(64 * 1024);  // 64KB data memory

    // Load test program (simple NOPs for now)
    uint32_t nop = 0x00000013;  // addi x0, x0, 0
    for (int i = 0; i < 256; i += 4) {
        imem.write_word(i, nop);
    }

    // Simple test program
    imem.write_word(0x00, 0x02A00093);  // addi x1, x0, 42
    imem.write_word(0x04, 0x00808113);  // addi x2, x1, 8
    imem.write_word(0x08, 0x00000013);  // nop
    imem.write_word(0x0C, 0x00000013);  // nop

    // Simulation parameters
    uint64_t sim_time = 0;
    uint64_t max_time = 10000;  // cycles
    int iwb_wait = 0;
    int dwb_wait = 0;

    // Reset
    dut->rst_ni = 0;
    dut->clk_i = 0;
    dut->iwb_dat_i = 0;
    dut->iwb_ack_i = 0;
    dut->dwb_dat_i = 0;
    dut->dwb_ack_i = 0;

    // Reset for a few cycles
    for (int i = 0; i < 10; i++) {
        dut->clk_i = 0;
        dut->eval();
        trace->dump(sim_time++);
        dut->clk_i = 1;
        dut->eval();
        trace->dump(sim_time++);
    }
    dut->rst_ni = 1;

    // Main simulation loop
    while (sim_time < max_time * 2) {
        // Negative edge
        dut->clk_i = 0;
        dut->eval();
        trace->dump(sim_time++);

        // Positive edge
        dut->clk_i = 1;

        // Instruction memory Wishbone interface
        if (dut->iwb_cyc_o && dut->iwb_stb_o) {
            uint32_t addr = dut->iwb_adr_o;
            dut->iwb_dat_i = imem.read_word(addr);
            dut->iwb_ack_i = 1;
        } else {
            dut->iwb_ack_i = 0;
        }

        // Data memory Wishbone interface
        if (dut->dwb_cyc_o && dut->dwb_stb_o) {
            uint32_t addr = dut->dwb_adr_o;
            if (dut->dwb_we_o) {
                // Write
                uint32_t data = dut->dwb_dat_o;
                uint8_t sel = dut->dwb_sel_o;
                for (int i = 0; i < 4; i++) {
                    if (sel & (1 << i)) {
                        dmem.data[addr + i] = (data >> (i * 8)) & 0xFF;
                    }
                }
            }
            dut->dwb_dat_i = dmem.read_word(addr);
            dut->dwb_ack_i = 1;
        } else {
            dut->dwb_ack_i = 0;
        }

        dut->eval();
        trace->dump(sim_time++);
    }

    // Cleanup
    trace->close();
    dut->final();

    std::cout << "Simulation completed: " << sim_time / 2 << " cycles" << std::endl;
    return 0;
}
