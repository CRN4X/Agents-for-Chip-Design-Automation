import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

async def reset_dut(dut):
    dut.clk.value = 0
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    dut.data_in.value = 0
    dut.accumulate_enable.value = 0
    dut.flush.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)

@cocotb.test()
async def test_basic(dut):
    """Basic scenario: accumulate a few values, then flush."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    dut.valid_in.value = 1
    dut.accumulate_enable.value = 1
    for val in [4, 8, 5, 7]:
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    dut.accumulate_enable.value = 0
    await RisingEdge(dut.clk)

    dut.flush.value = 1
    await RisingEdge(dut.clk)
    dut.flush.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_random(dut):
    """Random scenario: feed random inputs and flush."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(5):
        dut.data_in.value = random.getrandbits(dut.DATA_WIDTH.value)
        dut.valid_in.value = 1
        dut.accumulate_enable.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    dut.accumulate_enable.value = 0
    await RisingEdge(dut.clk)

    dut.flush.value = 1
    await RisingEdge(dut.clk)
    dut.flush.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_edge_cases(dut):
    """Edge scenario: feed near-maximum 32-bit values."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for val in [0xFFFFFF00, 0xFFFFFFFF, 1]:
        dut.valid_in.value = 1
        dut.accumulate_enable.value = 1
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    dut.accumulate_enable.value = 0
    await RisingEdge(dut.clk)

    dut.flush.value = 1
    await RisingEdge(dut.clk)
    dut.flush.value = 0
    await RisingEdge(dut.clk)
