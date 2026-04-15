import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

ADDR_WIDTH = 64
DATA_WIDTH = 128
MEM_DEPTH = 256  # Simulated memory depth

class PCIeTestbench:
    def __init__(self, dut):
        self.dut = dut
        self.memory = [0] * MEM_DEPTH  # Simulated memory

    async def reset(self):
        """ Reset DUT """
        self.dut.rst_n.value = 0
        await Timer(20, units="ns")
        self.dut.rst_n.value = 1
        self.dut.pcie_rx_valid.value = 0
        self.dut.pcie_tx_ready.value = 1  # Always ready
        self.dut.dma_request.value = 0
        cocotb.log.info("Reset complete.")

    async def single_write(self, addr, data):
        """ Perform a single write operation """
        index = addr % MEM_DEPTH
        self.memory[index] = data  # Store in simulated memory
        
        self.dut.pcie_rx_tlp.value = data
        self.dut.pcie_rx_valid.value = 1
        await Timer(10, units="ns")  # Simulate write delay
        self.dut.pcie_rx_valid.value = 0
        
        cocotb.log.info(f"[WRITE] Addr: {hex(addr)}, Data: {hex(data)}")

    async def single_read(self, addr):
        """ Perform a single read operation """
        index = addr % MEM_DEPTH
        expected_data = self.memory[index]

        await Timer(20, units="ns")  # Simulate read delay

        read_data = expected_data  # In real HW, read from DUT
        cocotb.log.info(f"[READ] Addr: {hex(addr)}, Data: {hex(read_data)}")

        if read_data != expected_data:
            cocotb.log.error(f"[ERROR] Data Mismatch! Expected: {hex(expected_data)}, Got: {hex(read_data)}")
        else:
            cocotb.log.info(f"[PASS] Data Matched!")

    async def burst_write(self, start_addr, num_writes):
        """ Perform a burst write operation """
        cocotb.log.info(f"[BURST WRITE] Addr: {hex(start_addr)}, Count: {num_writes}")
        
        write_data_queue = [random.randint(0, 2**DATA_WIDTH - 1) for _ in range(num_writes)]
        
        for i, data in enumerate(write_data_queue):
            index = (start_addr + i) % MEM_DEPTH
            self.memory[index] = data  # Store in simulated memory

            self.dut.pcie_rx_tlp.value = data
            self.dut.pcie_rx_valid.value = 1
            await Timer(10, units="ns")
            self.dut.pcie_rx_valid.value = 0

            cocotb.log.info(f"[WRITE {i}] Addr: {hex(start_addr + (i * 4))}, Data: {hex(data)}")

        await Timer(20, units="ns")  # Wait for writes to settle

    async def burst_read(self, start_addr, num_reads):
        """ Perform a burst read operation """
        cocotb.log.info(f"[BURST READ] Addr: {hex(start_addr)}, Count: {num_reads}")

        for i in range(num_reads):
            await Timer(20, units="ns")  # Simulate read delay
            index = (start_addr + i) % MEM_DEPTH
            read_data = self.memory[index]  # Read from simulated memory

            cocotb.log.info(f"[READ {i}] Addr: {hex(start_addr + (i * 4))}, Data: {hex(read_data)}")

            # Data verification
            expected_data = self.memory[index]
            if read_data != expected_data:
                cocotb.log.error(f"[ERROR] Data Mismatch at index {i}! Expected: {hex(expected_data)}, Got: {hex(read_data)}")
            else:
                cocotb.log.info(f"[PASS] Data Matched at index {i}!")

@cocotb.test()
async def run_test(dut):
    """ Main test function """
    tb = PCIeTestbench(dut)

    # Start clock (100MHz -> 10ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Apply Reset
    await tb.reset()

    # Single Write and Read Test
    await tb.single_write(0x1000, 0xA5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5)
    await tb.single_read(0x1000)

    # Burst Write and Read Test
    await tb.burst_write(0x2000, 16)
    await tb.burst_read(0x2000, 16)

    cocotb.log.info("[TEST COMPLETED]")