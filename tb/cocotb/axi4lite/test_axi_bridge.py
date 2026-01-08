"""
AXI4-Lite Bridge Testbench
Tests the instruction and data memory AXI4-Lite bridges
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.types import LogicArray
import random


class AXI4LiteReadSlave:
    """Simple AXI4-Lite read-only slave (for instruction memory)"""
    
    def __init__(self, dut, prefix="m_axi"):
        self.dut = dut
        self.arvalid = getattr(dut, f"{prefix}_arvalid")
        self.arready = getattr(dut, f"{prefix}_arready")
        self.araddr = getattr(dut, f"{prefix}_araddr")
        
        self.rvalid = getattr(dut, f"{prefix}_rvalid")
        self.rready = getattr(dut, f"{prefix}_rready")
        self.rdata = getattr(dut, f"{prefix}_rdata")
        self.rresp = getattr(dut, f"{prefix}_rresp")
        
        self.memory = {}
        self.latency = 0  # Cycles of latency
        
    def set_memory(self, addr, data):
        """Set memory contents"""
        self.memory[addr & 0xFFFFFFFC] = data & 0xFFFFFFFF
        
    async def run(self):
        """Run the slave responder"""
        while True:
            await RisingEdge(self.dut.clk_i)
            
            # Default: not ready, not valid
            self.arready.value = 0
            self.rvalid.value = 0
            
            # Address phase
            if self.arvalid.value == 1:
                # Accept address with optional latency
                if random.random() > 0.3:  # 70% chance to accept immediately
                    self.arready.value = 1
                    addr = int(self.araddr.value)
                    
                    # Wait latency cycles
                    for _ in range(self.latency):
                        await RisingEdge(self.dut.clk_i)
                    
                    # Provide data
                    self.rvalid.value = 1
                    if addr in self.memory:
                        self.rdata.value = self.memory[addr]
                        self.rresp.value = 0  # OKAY
                    else:
                        self.rdata.value = 0xDEADBEEF
                        self.rresp.value = 0  # OKAY (or could be SLVERR)
                    
                    # Wait for ready
                    while True:
                        await RisingEdge(self.dut.clk_i)
                        if self.rready.value == 1:
                            self.rvalid.value = 0
                            break


class AXI4LiteFullSlave:
    """Full AXI4-Lite slave (read/write for data memory)"""
    
    def __init__(self, dut, prefix="m_axi"):
        self.dut = dut
        # Write channels
        self.awvalid = getattr(dut, f"{prefix}_awvalid")
        self.awready = getattr(dut, f"{prefix}_awready")
        self.awaddr = getattr(dut, f"{prefix}_awaddr")
        
        self.wvalid = getattr(dut, f"{prefix}_wvalid")
        self.wready = getattr(dut, f"{prefix}_wready")
        self.wdata = getattr(dut, f"{prefix}_wdata")
        self.wstrb = getattr(dut, f"{prefix}_wstrb")
        
        self.bvalid = getattr(dut, f"{prefix}_bvalid")
        self.bready = getattr(dut, f"{prefix}_bready")
        self.bresp = getattr(dut, f"{prefix}_bresp")
        
        # Read channels
        self.arvalid = getattr(dut, f"{prefix}_arvalid")
        self.arready = getattr(dut, f"{prefix}_arready")
        self.araddr = getattr(dut, f"{prefix}_araddr")
        
        self.rvalid = getattr(dut, f"{prefix}_rvalid")
        self.rready = getattr(dut, f"{prefix}_rready")
        self.rdata = getattr(dut, f"{prefix}_rdata")
        self.rresp = getattr(dut, f"{prefix}_rresp")
        
        self.memory = bytearray(4096)  # 4KB memory
        
    async def run(self):
        """Run the slave responder"""
        cocotb.start_soon(self._handle_writes())
        cocotb.start_soon(self._handle_reads())
        
    async def _handle_writes(self):
        """Handle write transactions"""
        while True:
            await RisingEdge(self.dut.clk_i)
            self.awready.value = 0
            self.wready.value = 0
            self.bvalid.value = 0
            
            # Wait for write address
            if self.awvalid.value == 1:
                self.awready.value = 1
                addr = int(self.awaddr.value) & 0xFFF
                
                # Wait for write data
                await RisingEdge(self.dut.clk_i)
                while self.wvalid.value != 1:
                    await RisingEdge(self.dut.clk_i)
                
                self.wready.value = 1
                wdata = int(self.wdata.value)
                wstrb = int(self.wstrb.value)
                
                # Apply byte enables
                for i in range(4):
                    if wstrb & (1 << i):
                        self.memory[addr + i] = (wdata >> (i * 8)) & 0xFF
                
                # Send write response
                await RisingEdge(self.dut.clk_i)
                self.bvalid.value = 1
                self.bresp.value = 0  # OKAY
                
                while self.bready.value != 1:
                    await RisingEdge(self.dut.clk_i)
                    
    async def _handle_reads(self):
        """Handle read transactions"""
        while True:
            await RisingEdge(self.dut.clk_i)
            self.arready.value = 0
            self.rvalid.value = 0
            
            # Wait for read address
            if self.arvalid.value == 1:
                self.arready.value = 1
                addr = int(self.araddr.value) & 0xFFF
                
                # Provide read data
                await RisingEdge(self.dut.clk_i)
                self.rvalid.value = 1
                rdata = 0
                for i in range(4):
                    rdata |= self.memory[addr + i] << (i * 8)
                self.rdata.value = rdata
                self.rresp.value = 0  # OKAY
                
                while self.rready.value != 1:
                    await RisingEdge(self.dut.clk_i)


@cocotb.test()
async def test_imem_basic_read(dut):
    """Test basic instruction memory read"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_ni.value = 0
    dut.fetch_req_i.value = 0
    dut.fetch_addr_i.value = 0
    await Timer(50, units="ns")
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)
    
    # Create AXI slave
    slave = AXI4LiteReadSlave(dut)
    slave.set_memory(0x1000, 0x12345678)
    cocotb.start_soon(slave.run())
    
    # Request instruction
    dut.fetch_req_i.value = 1
    dut.fetch_addr_i.value = 0x1000
    await RisingEdge(dut.clk_i)
    dut.fetch_req_i.value = 0
    
    # Wait for response
    for _ in range(20):
        await RisingEdge(dut.clk_i)
        if dut.fetch_valid_o.value == 1:
            assert int(dut.fetch_data_o.value) == 0x12345678, \
                f"Expected 0x12345678, got 0x{int(dut.fetch_data_o.value):08x}"
            break
    else:
        assert False, "Timeout waiting for fetch_valid_o"
    
    dut._log.info("✓ Basic instruction read passed")


@cocotb.test()
async def test_dmem_write_read(dut):
    """Test data memory write and read"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_ni.value = 0
    dut.mem_req_i.value = 0
    await Timer(50, units="ns")
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)
    
    # Create AXI slave
    slave = AXI4LiteFullSlave(dut)
    cocotb.start_soon(slave.run())
    
    # Write test
    dut.mem_req_i.value = 1
    dut.mem_we_i.value = 1
    dut.mem_addr_i.value = 0x100
    dut.mem_wdata_i.value = 0xABCDEF00
    dut.mem_be_i.value = 0xF  # All bytes
    await RisingEdge(dut.clk_i)
    dut.mem_req_i.value = 0
    
    # Wait for completion
    for _ in range(20):
        await RisingEdge(dut.clk_i)
        if dut.mem_valid_o.value == 1:
            break
    else:
        assert False, "Write timeout"
    
    # Read test
    dut.mem_req_i.value = 1
    dut.mem_we_i.value = 0
    dut.mem_addr_i.value = 0x100
    await RisingEdge(dut.clk_i)
    dut.mem_req_i.value = 0
    
    # Wait for read data
    for _ in range(20):
        await RisingEdge(dut.clk_i)
        if dut.mem_valid_o.value == 1:
            assert int(dut.mem_rdata_o.value) == 0xABCDEF00, \
                f"Expected 0xABCDEF00, got 0x{int(dut.mem_rdata_o.value):08x}"
            break
    else:
        assert False, "Read timeout"
    
    dut._log.info("✓ Write/Read test passed")


@cocotb.test()
async def test_dmem_byte_enables(dut):
    """Test byte enable functionality"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_ni.value = 0
    dut.mem_req_i.value = 0
    await Timer(50, units="ns")
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)
    
    # Create AXI slave
    slave = AXI4LiteFullSlave(dut)
    cocotb.start_soon(slave.run())
    
    # Write with partial byte enables
    dut.mem_req_i.value = 1
    dut.mem_we_i.value = 1
    dut.mem_addr_i.value = 0x200
    dut.mem_wdata_i.value = 0x11223344
    dut.mem_be_i.value = 0b0011  # Only lower 2 bytes
    await RisingEdge(dut.clk_i)
    dut.mem_req_i.value = 0
    
    # Wait for completion
    for _ in range(20):
        await RisingEdge(dut.clk_i)
        if dut.mem_valid_o.value == 1:
            break
    
    # Read back
    dut.mem_req_i.value = 1
    dut.mem_we_i.value = 0
    dut.mem_addr_i.value = 0x200
    await RisingEdge(dut.clk_i)
    dut.mem_req_i.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk_i)
        if dut.mem_valid_o.value == 1:
            rdata = int(dut.mem_rdata_o.value)
            # Only lower 2 bytes should be written
            assert (rdata & 0xFFFF) == 0x3344, \
                f"Expected lower bytes 0x3344, got 0x{rdata & 0xFFFF:04x}"
            break
    
    dut._log.info("✓ Byte enable test passed")
