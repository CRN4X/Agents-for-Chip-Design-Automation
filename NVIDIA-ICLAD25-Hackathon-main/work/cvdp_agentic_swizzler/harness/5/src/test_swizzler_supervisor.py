import os
os.environ["COCOTB_RESOLVE_X"] = "0"

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_basic(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.bypass.value = 0
    dut.data_in.value = int("55" * 4, 16)
    mapping = (3 << (3*3)) | (2 << (2*3)) | (1 << (1*3)) | (0 << (0*3))
    dut.swizzle_map_flat.value = mapping
    dut.operation_mode.value = 0
    # Wait several clock cycles for pipelined state machine to update
    for _ in range(5):
        await RisingEdge(dut.clk)
    value_str = dut.final_data_out.value.binstr.replace("x", "0")
    sw_out = int(value_str, 2)
    checksum = 0
    for i in range(4):
        lane = (sw_out >> (i*8)) & 0xFF
        checksum ^= lane
    expected_top = 0 if (checksum == int(dut.EXPECTED_CHECKSUM.value)) else 1
    assert int(dut.top_error.value) == expected_top, f"Basic test failed: checksum={hex(checksum)} EXPECTED={hex(int(dut.EXPECTED_CHECKSUM.value))} top_error={dut.top_error.value}"
    dut._log.info(f"Basic test passed: final_data_out={hex(sw_out)} checksum={hex(checksum)} top_error={dut.top_error.value}")

@cocotb.test()
async def test_random(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for i in range(10):
        dut.bypass.value = random.randint(0,1)
        data = 0
        for j in range(4):
            data = (data << 8) | random.randint(0,255)
        dut.data_in.value = data
        mapping = 0
        for j in range(4):
            mapping |= (random.randint(0,3) << (j*3))
        dut.swizzle_map_flat.value = mapping
        dut.operation_mode.value = random.randint(0,3)
        await Timer(40, units="ns")
        # Wait an extra cycle for state machine update
        await RisingEdge(dut.clk)
        value_str = dut.final_data_out.value.binstr.replace("x", "0")
        sw_out = int(value_str, 2)
        checksum = 0
        for j in range(4):
            lane = (sw_out >> (j*8)) & 0xFF
            checksum ^= lane
        exp_top = 0 if (checksum == int(dut.EXPECTED_CHECKSUM.value)) else 1
        assert int(dut.top_error.value) == exp_top, f"Random test iteration {i} failed: checksum={hex(checksum)} EXPECTED={hex(int(dut.EXPECTED_CHECKSUM.value))} top_error={dut.top_error.value}"
        dut._log.info(f"Random test iteration {i} passed: final_data_out={hex(sw_out)} checksum={hex(checksum)} top_error={dut.top_error.value}")

@cocotb.test()
async def test_edge(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.bypass.value = 0
    dut.data_in.value = int("AA" * 4, 16)
    mapping = (3 << (3*3)) | (3 << (2*3)) | (2 << (1*3)) | (4 << (0*3))
    dut.swizzle_map_flat.value = mapping
    dut.operation_mode.value = 0
    await Timer(40, units="ns")
    # Wait an extra cycle for update
    await RisingEdge(dut.clk)
    assert int(dut.top_error.value) == 1, f"Edge test failed: expected top_error=1, got {dut.top_error.value}"
    dut._log.info(f"Edge test passed: final_data_out={hex(int(dut.final_data_out.value))} top_error={dut.top_error.value}")
