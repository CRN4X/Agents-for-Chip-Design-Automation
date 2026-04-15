import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# Helper to reset the DUT
async def reset_dut(dut):
    dut.we.value = 0
    dut.addr_a.value = 0
    dut.addr_b.value = 0
    dut.data_in.value = 0
    await RisingEdge(dut.clk)

# Write operation using Port A
async def write_data(dut, addr, data):
    dut.addr_a.value = addr
    dut.data_in.value = data
    dut.we.value = 1
    await RisingEdge(dut.clk)
    dut.we.value = 0
    await RisingEdge(dut.clk)
    dut._log.info(f"Wrote {data} at address {addr}")

# Read operation using Port B (non-corrupt read)
async def read_data(dut, addr, expected_data):
    dut.addr_b.value = addr
    dut.we.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    actual = dut.data_out.value.to_unsigned()
    ecc_flag = dut.ecc_error.value.to_unsigned()
    dut._log.info(f"Read from {addr}: got {actual}, expected {expected_data}, ECC error = {ecc_flag}")
    assert actual == expected_data, f"Mismatch! Got {actual}, expected {expected_data}"
    assert ecc_flag == 0, f"Unexpected ECC error at addr {addr}"

# ECC check helper with optional corruption expectation
async def read_data_ecc_check(dut, addr, expected_data, expect_ecc_error=False):
    dut.addr_b.value = addr
    dut.we.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    actual = dut.data_out.value.to_unsigned()
    ecc_flag = dut.ecc_error.value.to_unsigned()
    dut._log.info(f"[ECC Check] Read {actual} from addr {addr}, ECC error = {ecc_flag}")

    if not expect_ecc_error:
        assert actual == expected_data, f"Expected {expected_data}, got {actual} at addr {addr}"
    else:
        dut._log.info(f"ECC error expected. Data read = {actual}, original = {expected_data}")
    
    assert ecc_flag == int(expect_ecc_error), f"ECC error flag mismatch at addr {addr}"

@cocotb.test()
async def test_dual_port_ecc_ram(dut):
    """ ECC-enabled Dual-Port RAM test including error injection """

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    addr_width = int(dut.ADDR_WIDTH.value)
    data_width = int(dut.DATA_WIDTH.value)

    # Test: Multiple valid writes and reads
    for _ in range(5):
        addr = random.randint(0, 2**addr_width - 1)
        data = random.randint(0, 2**data_width - 1)
        await write_data(dut, addr, data)
        await read_data(dut, addr, data)

    # Test: Inject ECC error by bit-flipping memory
    corrupt_addr = 3
    valid_data = 0b1010
    await write_data(dut, corrupt_addr, valid_data)

    # Simulate a memory bit-flip by forcing ram_data[corrupt_addr]
    if hasattr(dut, 'ram_data'):
        await Timer(1, units='ns')  # Let previous write finish
        original_value = dut.ram_data[corrupt_addr].value.to_unsigned()
        corrupted_value = original_value ^ 0b0001  # Flip LSB
        dut.ram_data[corrupt_addr].value = corrupted_value
        await read_data_ecc_check(dut, corrupt_addr, valid_data, expect_ecc_error=True)
    else:
        dut._log.warning("Simulator does not allow direct RAM corruption.")
