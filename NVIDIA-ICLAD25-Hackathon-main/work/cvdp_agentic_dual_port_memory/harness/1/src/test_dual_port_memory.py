import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random

# Helper function to reset the DUT
async def reset_dut(dut):
    dut.we_a.value = 0
    dut.we_b.value = 0
    dut.addr_a.value = 0
    dut.addr_b.value = 0
    dut.data_in_a.value = 0
    dut.data_in_b.value = 0
    dut.data_out_a.value = 0
    dut.data_out_b.value = 0
    await RisingEdge(dut.clk)

# Helper function to perform a write operation on Port A
async def write_to_port_a(dut, addr, data):
    dut.we_a.value = 1
    dut.addr_a.value = addr
    dut.data_in_a.value = data
    await RisingEdge(dut.clk)  # Wait for the write to propagate
    dut.we_a.value = 0
    await RisingEdge(dut.clk)
    print(f"Wrote Data = {data} to Port A at Addr = {addr}")

# Helper function to perform a read operation on Port A
async def read_from_port_a(dut, addr, expected_data):
    dut.we_a.value = 0
    dut.addr_a.value = addr
    await RisingEdge(dut.clk)  # Wait for the read to propagate
    await RisingEdge(dut.clk)  # Extra clock to stabilize
    print(f"Reading from Port A at Addr = {addr}: Expected = {expected_data}, Got = {dut.data_out_a.value}")
    assert dut.data_out_a.value == expected_data, f"Port A failed to read {expected_data} at address {addr}, got {dut.data_out_a.value}"

# Helper function to perform a write operation on Port B
async def write_to_port_b(dut, addr, data):
    dut.we_b.value = 1
    dut.addr_b.value = addr
    dut.data_in_b.value = data
    await RisingEdge(dut.clk)  # Wait for the write to propagate
    dut.we_b.value = 0
    await RisingEdge(dut.clk)
    print(f"Wrote Data = {data} to Port B at Addr = {addr}")

# Helper function to perform a read operation on Port B
async def read_from_port_b(dut, addr, expected_data):
    dut.we_b.value = 0
    dut.addr_b.value = addr
    await RisingEdge(dut.clk)  # Wait for the read to propagate
    await RisingEdge(dut.clk)  # Extra clock to stabilize
    print(f"Reading from Port B at Addr = {addr}: Expected = {expected_data}, Got = {dut.data_out_b.value}")
    assert dut.data_out_b.value == expected_data, f"Port B failed to read {expected_data} at address {addr}, got {dut.data_out_b.value}"

@cocotb.test()
async def test_cvdp_true_dp_ram_ports_a_and_b(dut):
    """ Test the cvdp_true_dp_ram for both Port A and Port B ensuring RAW behavior """

    # Initialize clock and reset signals
    clock = Clock(dut.clk, 10, units="ns")  # Create a clock with a period of 10ns
    cocotb.start_soon(clock.start())  # Start the clock

    # Convert LogicObject parameters to integers
    addr_width = int(dut.ADDR_WIDTH.value)
    data_width = int(dut.DATA_WIDTH.value)

    # Test Case 1: Write and read from both Port A and Port B
    addr_a = random.randint(0, 2**addr_width - 1)
    data_a = random.randint(0, 2**data_width - 1)
    addr_b = random.randint(0, 2**addr_width - 1)

    # Ensure different addresses for A and B to avoid conflicts
    while addr_b == addr_a:
        addr_b = random.randint(0, 2**addr_width - 1)

    data_b = random.randint(0, 2**data_width - 1)

    # Write to both ports
    await write_to_port_a(dut, addr_a, data_a)
    await write_to_port_b(dut, addr_b, data_b)

    # Read from both ports
    await read_from_port_a(dut, addr_a, data_a)
    await read_from_port_b(dut, addr_b, data_b)

    # Test Case 2: Multiple writes and reads for both ports
    for _ in range(5):
        addr_a = random.randint(0, 2**addr_width - 1)
        data_a = random.randint(0, 2**data_width - 1)
        addr_b = random.randint(0, 2**addr_width - 1)
        
        # Ensure different addresses for A and B to avoid conflicts
        while addr_b == addr_a:
            addr_b = random.randint(0, 2**addr_width - 1)
        
        data_b = random.randint(0, 2**data_width - 1)

        # Write to both ports
        await write_to_port_a(dut, addr_a, data_a)
        await write_to_port_b(dut, addr_b, data_b)
        
        # Read from both ports
        await read_from_port_a(dut, addr_a, data_a)
        await read_from_port_b(dut, addr_b, data_b)

@cocotb.test()
async def test_true_dp_ram(dut):
    # Create a clock with a period of 10ns
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    await reset_dut(dut)
    await RisingEdge(dut.clk)

    # Chosen addresses and data for testing
    addr_a = 1  # Specific address for port A
    addr_b = 2  # Specific address for port B
    test_data_a = 0b1010  # Test data for port A
    test_data_b = 0b1100  # Test data for port B

    # Case 1: Write data to port A and read back from port B at the same address
    # Write to port A
    await write_to_port_a (dut, addr_a, test_data_a)
    await read_from_port_b(dut, addr_a, test_data_a)

    assert dut.data_out_b.value == test_data_a, f"Error: Expected {test_data_a}, but got {dut.data_out_b.value} from port B."

    # Case 2: Write data to port B and read back from port A at the same address
    # Write to port B
    await write_to_port_b (dut, addr_b, test_data_b)
    await read_from_port_a(dut, addr_b, test_data_b)

    assert dut.data_out_a.value == test_data_b, f"Error: Expected {test_data_b}, but got {dut.data_out_a.value} from port A."
