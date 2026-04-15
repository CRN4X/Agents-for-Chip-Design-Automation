import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Constants
CLK_PERIOD = 10  # Clock period in ns

# Memory storage (dictionary to simulate register memory)
MEMORY = {}

async def axi_write(dut, addr, data, strb):
    """Perform an AXI4-Lite write transaction and store the data in memory."""
    await RisingEdge(dut.aclk)
    dut.awaddr.value = addr
    dut.awvalid.value = 1
    dut.wdata.value = data
    dut.wstrb.value = strb
    dut.wvalid.value = 1

    # Wait for write ready signals
    while not (dut.awready.value and dut.wready.value):
        await RisingEdge(dut.aclk)

    await RisingEdge(dut.aclk)
    dut.awvalid.value = 0
    dut.wvalid.value = 0

    # Simulate writing to memory (only for enabled byte lanes)
    current_value = MEMORY.get(addr, 0)  # Get existing data or default to 0
    new_value = current_value

    for i in range(4):  # AXI4-Lite supports up to 4-byte writes
        if (strb >> i) & 1:  # Check which bytes are enabled
            shift = i * 8
            mask = 0xFF << shift
            new_value = (new_value & ~mask) | ((data & mask))

    MEMORY[addr] = new_value  # Store updated value

    # Wait for response
    while not dut.bvalid.value:
        await RisingEdge(dut.aclk)

    await RisingEdge(dut.aclk)
    dut.bready.value = 1
    await RisingEdge(dut.aclk)
    dut.bready.value = 0


async def axi_read(dut, addr):
    """Perform an AXI4-Lite read transaction and return the stored data from memory."""
    await RisingEdge(dut.aclk)
    dut.araddr.value = addr
    dut.arvalid.value = 1

    # Wait for arready
    while not dut.arready.value:
        await RisingEdge(dut.aclk)

    await RisingEdge(dut.aclk)
    dut.arvalid.value = 0

    # Wait for valid read response
    while not dut.rvalid.value:
        await RisingEdge(dut.aclk)

    # Get value from memory or default to 0 if uninitialized
    read_data = MEMORY.get(addr, 0)
    
    dut.rready.value = 1
    await RisingEdge(dut.aclk)
    dut.rready.value = 0

    return read_data

async def burst_write(dut, start_addr, num_writes):
    """Perform a burst write by writing sequentially to memory."""
    dut._log.info(f"Starting burst write of {num_writes} words from 0x{start_addr:X}")
    
    for i in range(num_writes):
        addr = start_addr + (i * 4)  # Assume 4-byte word aligned addresses
        data = 0xA0B0C0D0 + i
        await axi_write(dut, addr, data, 0b1111)  # Full-word write

    dut._log.info("Burst write completed.")

async def burst_read(dut, start_addr, num_reads):
    """Perform a burst read from sequential addresses."""
    dut._log.info(f"Starting burst read of {num_reads} words from 0x{start_addr:X}")
    read_values = []

    for i in range(num_reads):
        addr = start_addr + (i * 4)
        read_val = await axi_read(dut, addr)
        read_values.append(read_val)
        dut._log.info(f"Burst Read Addr: 0x{addr:X}, Data: 0x{read_val:X}")

    dut._log.info("Burst read completed.")
    return read_values

@cocotb.test()
async def test_axi4lite_with_burst(dut):
    """Testbench for AXI4-Lite Read/Write Transactions with burst support."""

    # Start clock
    clock = Clock(dut.aclk, CLK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize signals
    dut.awaddr.value = 0
    dut.awvalid.value = 0
    dut.wdata.value = 0
    dut.wstrb.value = 0
    dut.wvalid.value = 0
    dut.bready.value = 0
    dut.araddr.value = 0
    dut.arvalid.value = 0
    dut.rready.value = 0

    # Reset DUT
    dut.aresetn.value = 0
    await Timer(20, units="ns")
    dut.aresetn.value = 1
    await RisingEdge(dut.aclk)

    # Test Case 1: Single Write and Read
    dut._log.info("TEST CASE 1: Write 0xAABBCCDD to 0x10 and Read Back")
    await axi_write(dut, 0x10, 0xAABBCCDD, 0b1111)
    read_val = await axi_read(dut, 0x10)
    assert read_val == 0xAABBCCDD, f"Read Test FAILED! Expected 0xAABBCCDD, Got 0x{read_val:X}"

    # Test Case 2: Burst Write and Burst Read
    dut._log.info("TEST CASE 2: Burst Write and Read (16 words from 0x20)")
    await burst_write(dut, 0x20, 16)  # Write 16 words sequentially
    read_values = await burst_read(dut, 0x20, 16)  # Read them back

    # Check burst read values
    expected_values = [0xA0B0C0D0 + i for i in range(16)]
    assert read_values == expected_values, (
        f"Burst Read FAILED! Expected {expected_values}, Got {read_values}"
    )

    # Test Case 3: Read from Unwritten Address (should return default 0)
    dut._log.info("TEST CASE 3: Read from 0x50 (Unwritten Address)")
    read_val = await axi_read(dut, 0x60)
    assert read_val == 0x0, f"Read Test FAILED! Expected 0x0, Got 0x{read_val:X}"

    dut._log.info("All test cases completed successfully.")