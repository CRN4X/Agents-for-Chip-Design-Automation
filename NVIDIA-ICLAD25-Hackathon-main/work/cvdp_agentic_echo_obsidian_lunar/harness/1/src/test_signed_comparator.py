import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_basic(dut):
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    dut.rst_n.value = 0
    dut.enable.value = 0
    dut.bypass.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)

    dut.enable.value = 1
    dut.a.value = 10
    dut.b.value = -10
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.gt.value == 1, f"Expected gt=1 for a=10, b=-10"

    dut.a.value = -20
    dut.b.value = -20
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.eq.value == 1, f"Expected eq=1 for a=-20, b=-20"

    dut.a.value = -30
    dut.b.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.lt.value == 1, f"Expected lt=1 for a=-30, b=1"

@cocotb.test()
async def test_random(dut):
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    dut.rst_n.value = 0
    dut.enable.value = 0
    dut.bypass.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)

    for _ in range(10):
        a_val = random.randint(-32768, 32767)
        b_val = random.randint(-32768, 32767)
        dut.a.value = a_val & 0xFFFF
        dut.b.value = b_val & 0xFFFF
        dut.bypass.value = random.getrandbits(1)
        dut.enable.value = random.getrandbits(1)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

@cocotb.test()
async def test_edge_cases(dut):
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    dut.rst_n.value = 0
    dut.enable.value = 0
    dut.bypass.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)

    pairs = [
        (-32768, 32767),
        (32767, -32768),
        (32767, 32767),
        (-32768, -32768),
        (0, 0),
    ]
    for (val_a, val_b) in pairs:
        dut.a.value = val_a & 0xFFFF
        dut.b.value = val_b & 0xFFFF
        dut.enable.value = 1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
