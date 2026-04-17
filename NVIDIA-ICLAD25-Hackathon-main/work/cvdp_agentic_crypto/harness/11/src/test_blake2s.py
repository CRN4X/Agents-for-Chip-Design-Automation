
import cocotb
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.triggers import FallingEdge
import harness_library as hrs_lb
import os
import inspect


@cocotb.test()
async def test_read_block_addresses(dut):
    if os.getenv("SELECTION") != 'read_block_address':
        return

    cocotb.log.setLevel("DEBUG")
    cocotb.log.info(f"Starting {inspect.currentframe().f_code.co_name}...")

    await hrs_lb.dut_init(dut)
    await cocotb.start(Clock(dut.clk, hrs_lb.CLK_PERIOD, units=hrs_lb.CLK_TIME_UNIT).start(start_high=False))

    await hrs_lb.init_sim(dut)
    await hrs_lb.reset_dut(dut)

    for i in range(0, 16):
        word = await hrs_lb.read_word(dut, hrs_lb.ADDR_BLOCK0 + i)
        assert word == 0

    cocotb.log.info("All tests passed.")

@cocotb.test()
async def test_read_block_len_address(dut):
    if os.getenv("SELECTION") != 'read_block_len_address':
        return

    cocotb.log.setLevel("DEBUG")
    cocotb.log.info(f"Starting {inspect.currentframe().f_code.co_name}...")

    await hrs_lb.dut_init(dut)
    await cocotb.start(Clock(dut.clk, hrs_lb.CLK_PERIOD, units=hrs_lb.CLK_TIME_UNIT).start(start_high=False))

    await hrs_lb.init_sim(dut)
    await hrs_lb.reset_dut(dut)

    block_len = await hrs_lb.read_word(dut, hrs_lb.ADDR_BLOCKLEN)
    assert block_len.integer == 0

    cocotb.log.info("All tests passed.")

@cocotb.test()
async def test_read_ctrl_address(dut):
    if os.getenv("SELECTION") != 'read_ctrl_address':
        return

    cocotb.log.setLevel("DEBUG")
    cocotb.log.info(f"Starting {inspect.currentframe().f_code.co_name}...")

    await hrs_lb.dut_init(dut)
    await cocotb.start(Clock(dut.clk, hrs_lb.CLK_PERIOD, units=hrs_lb.CLK_TIME_UNIT).start(start_high=False))

    await hrs_lb.init_sim(dut)
    await hrs_lb.reset_dut(dut)

    ctrl = await hrs_lb.read_word(dut, hrs_lb.ADDR_CTRL)
    assert ctrl.integer == 0

    cocotb.log.info("All tests passed.")
