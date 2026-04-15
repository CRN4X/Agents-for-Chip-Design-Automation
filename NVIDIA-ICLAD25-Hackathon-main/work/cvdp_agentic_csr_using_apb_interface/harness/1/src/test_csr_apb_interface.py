import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import harness_library as hrs_lb
import random

# Constants for register addresses
DATA_REG       = 0x10
CONTROL_REG    = 0x14
INTERRUPT_REG  = 0x18
ISR_REG        = 0x1C


async def write_register(dut, addr, data):
    """Function to write data to a register."""
    dut.pselx.value = 1
    dut.pwrite.value = 1
    dut.pwdata.value = data
    dut.paddr.value = addr
    await RisingEdge(dut.pclk)
    dut.penable.value = 1
    await RisingEdge(dut.pclk)
    dut.penable.value = 0
    dut.pselx.value = 0
    await ClockCycles(dut.pclk, 2)

async def read_register(dut, addr):
    """Function to read data from a register."""
    dut.pselx.value = 1
    dut.pwrite.value = 0
    dut.paddr.value = addr
    await RisingEdge(dut.pclk)
    dut.penable.value = 1
    await RisingEdge(dut.pclk)
    dut.penable.value = 0
    dut.pselx.value = 0
    await ClockCycles(dut.pclk, 2)
    return dut.prdata.value.integer

@cocotb.test()
async def test_csr_apb_interface(dut):
    # Start the clock with a period of 10ns
    cocotb.start_soon(Clock(dut.pclk, 10, units='ns').start())

    # Initialize the DUT signals
    await hrs_lb.dut_init(dut)

    # Apply reset to the DUT for 25ns, reset is active low
    await hrs_lb.reset_dut(dut.presetn, duration_ns=10, active=False)

    # Test Writing and Reading from DATA_REG
    data_to_write = random.randint(0, 0xFFFFFFFF)
    await write_register(dut, DATA_REG, data_to_write)
    data_read_back = await read_register(dut, DATA_REG)
    assert data_read_back == data_to_write, "DATA_REG read/write mismatch."
    dut._log.info(f"Writing and Reading from DATA_REG : data_read_back = {data_read_back}, data_to_write = {data_to_write}")

    # Test Writing and Reading from CONTROL_REG
    data_to_write = random.randint(0, 0xFFFFFFFF)
    await write_register(dut, CONTROL_REG, data_to_write)
    data_read_back = await read_register(dut, CONTROL_REG)
    assert data_read_back == data_to_write, "CONTROL_REG read/write mismatch."
    dut._log.info(f"Writing and Reading from CONTROL_REG : data_read_back = {data_read_back}, data_to_write = {data_to_write}")

    # Test Writing and Reading from INTERRUPT_REG
    data_to_write = random.randint(0, 0xFFFFFFFF)
    await write_register(dut, INTERRUPT_REG, data_to_write)
    data_read_back = await read_register(dut, INTERRUPT_REG)
    assert data_read_back == data_to_write, "INTERRUPT_REG read/write mismatch."
    dut._log.info(f"Writing and Reading from INTERRUPT_REG : data_read_back = {data_read_back}, data_to_write = {data_to_write}")
    # -------------------------------------
    # Test Case 5: Write-protected ISR_REG
    # -------------------------------------
    dut._log.info("Test Case 5: Write-protected ISR_REG")
    isr_write_value = 0xDEADBEEF
    dut.pselx.value = 1
    dut.pwrite.value = 1
    dut.pwdata.value = isr_write_value
    dut.paddr.value = ISR_REG
    await RisingEdge(dut.pclk)
    dut.penable.value = 1
    await RisingEdge(dut.pclk)
    dut.penable.value = 0
    dut.pselx.value = 0
    await ClockCycles(dut.pclk, 2)

    # Check for write protection error
    assert dut.pslverr.value == 1, "ISR_REG write did not cause an error as expected"
    dut._log.info("Write to ISR_REG correctly caused error (Write-Protected Register)")

    # -------------------------------------
    # Test Case 6: Read ISR_REG
    # -------------------------------------
    dut._log.info("Test Case 6: Read ISR_REG")
    dut.pselx.value = 1
    dut.pwrite.value = 0
    dut.paddr.value = ISR_REG
    await RisingEdge(dut.pclk)
    dut.penable.value = 1
    await RisingEdge(dut.pclk)
    dut.penable.value = 0
    dut.pselx.value = 0
    await ClockCycles(dut.pclk, 2)

    # Validate ISR_REG read
    isr_read_value = dut.prdata.value.integer
    expected_isr_value = 0  # Assuming ISR_REG initializes to 0
    assert isr_read_value == expected_isr_value, f"ISR_REG mismatch: read {isr_read_value}, expected {expected_isr_value}"
    dut._log.info(f"ISR_REG read successful: {isr_read_value}")

    # End simulation
    await ClockCycles(dut.pclk, 10)
    dut._log.info("All test cases passed!")