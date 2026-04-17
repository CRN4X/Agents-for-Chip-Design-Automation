import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random


@cocotb.test()
async def test_helmholtz_top_module(dut):
    """Test the Helmholtz top module: calibration + audio processing.""" #

    clk_period = 10  # 100 MHz
    cocotb.start_soon(Clock(dut.clk, clk_period, units="ns").start())

    # Initialize inputs
    dut.rst.value = 1
    dut.calibrate.value = 0
    dut.mod_enable.value = 0
    dut.audio_in.value = 0
    dut.base_freq.value = 150
    dut.q_factor.value = 64

    await Timer(100, units="ns")
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    dut._log.info("Starting calibration...")

    # Trigger calibration
    dut.calibrate.value = 1

    timeout_cycles = 1000
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if dut.cal_done_flags.value == 0b111:
            dut._log.info("All resonators calibrated.")
            break
    else:
        raise cocotb.result.TestFailure("Calibration timeout!")

    dut.calibrate.value = 0
    dut.mod_enable.value = 1

    dut._log.info("Starting audio input pattern...")

    # Drive a test input pattern (square wave)
    for cycle in range(200):
        sample = 8000 if (cycle % 20 < 10) else -8000
        dut.audio_in.value = sample

        await RisingEdge(dut.clk)

        if cycle % 10 == 0:
            out_val = dut.audio_out.value.to_signed()
            dut._log.info(f"Cycle {cycle:03d} | Audio_in: {sample:6d} | Audio_out: {out_val:6d}")

    dut._log.info("Test complete ")
