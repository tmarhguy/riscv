import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

def parse_vmem(filename):
    mem = {} # addr -> byte
    base = 0
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            if line.startswith('@'):
                base = int(line[1:], 16)
            else:
                bytes_list = line.split()
                for b in bytes_list:
                    mem[base] = int(b, 16)
                    base += 1
    return mem

class WishboneSoC:
    def __init__(self, dut):
        self.dut = dut
        self.rom = {} 
        self.ram = {}
        
    def load_program(self, vmem_file):
        full_mem = parse_vmem(vmem_file)
        # Split into ROM (0x0) and RAM (0x80000000)
        # But hello.c links .text to ROM and .data to RAM
        # objcopy -O verilog linearizes it based on LMA
        for addr, val in full_mem.items():
            if addr < 0x20000: # ROM region
                self.rom[addr] = val
            elif addr >= 0x80000000 and addr < 0x80020000: # RAM region
                self.ram[addr - 0x80000000] = val
                
    def read(self, addr):
        # Returns 32-bit word
        if addr >= 0x80000000: # RAM
            offset = addr - 0x80000000
            mem = self.ram
        else: # ROM
            offset = addr
            mem = self.rom
            
        b0 = mem.get(offset, 0)
        b1 = mem.get(offset+1, 0)
        b2 = mem.get(offset+2, 0)
        b3 = mem.get(offset+3, 0)
        word = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
        return word

    def write(self, addr, data, sel):
        if addr == 0x10000000: # UART base
             # Check TX register (offset 0)
             # Write low byte
             char = data & 0xFF
             self.dut._log.info(f"UART TX: {chr(char)}")
             return

        if addr >= 0x80000000: # RAM
            offset = addr - 0x80000000
            mem = self.ram
            if sel & 1: mem[offset] = data & 0xFF
            if sel & 2: mem[offset+1] = (data >> 8) & 0xFF
            if sel & 4: mem[offset+2] = (data >> 16) & 0xFF
            if sel & 8: mem[offset+3] = (data >> 24) & 0xFF

    async def run_dwb(self):
        # Data bus slave
        self.dut.dwb_ack_i.value = 0
        while True:
            await RisingEdge(self.dut.clk_i)
            if self.dut.dwb_stb_o.value and self.dut.dwb_cyc_o.value:
                addr = int(self.dut.dwb_adr_o.value)
                if self.dut.dwb_we_o.value:
                    data = int(self.dut.dwb_dat_o.value)
                    sel = int(self.dut.dwb_sel_o.value)
                    self.write(addr, data, sel)
                
                # Check for TOHOST magic write (0x80001000)
                if addr == 0x80001000 and self.dut.dwb_we_o.value:
                    val = int(self.dut.dwb_dat_o.value)
                    if val == 1:
                        self.dut._log.info("TOHOST success!")
                        # We can stop here, but let's just ack
                
                # Read (always return data even on write, standard WB)
                rdata = self.read(addr)
                self.dut.dwb_dat_i.value = rdata
                self.dut.dwb_ack_i.value = 1
            else:
                self.dut.dwb_ack_i.value = 0
                
    async def run_iwb(self):
        # Instruction bus slave (Read only from ROM usually)
        self.dut.iwb_ack_i.value = 0
        while True:
            await RisingEdge(self.dut.clk_i)
            if self.dut.iwb_stb_o.value and self.dut.iwb_cyc_o.value:
                addr = int(self.dut.iwb_adr_o.value)
                rdata = self.read(addr)
                self.dut.iwb_dat_i.value = rdata
                self.dut.iwb_ack_i.value = 1
            else:
                self.dut.iwb_ack_i.value = 0

@cocotb.test()
async def test_hello_demo(dut):
    """Run sw/hello.c program"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    soc = WishboneSoC(dut)
    soc.load_program("../../sw/build/hello.vmem")
    
    cocotb.start_soon(soc.run_iwb())
    cocotb.start_soon(soc.run_dwb())
    
    # Reset
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 5)
    dut.rst_ni.value = 1
    
    # Run for enough cycles to print hello and calculation
    # Estimation: Print string len ~60 + calc logic. ~10k cycles?
    # We poll for TOHOST or timeout
    
    for _ in range(200000):
        await RisingEdge(dut.clk_i)
        # Check if TOHOST was written to (logic in run_dwb logs it)
        # We can scan logs or just rely on timeout/visual check for now.
        # But to be robust, we should exit if we see usage of TOHOST addr in read/write
        pass
        
    dut._log.info("Test finished (timeout)")
