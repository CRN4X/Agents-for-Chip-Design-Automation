import os
from pathlib import Path
from cocotb_tools.runner import get_runner
import pytest

verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = os.getenv("WAVE")

def test_runner(PRICE_WIDTH: int=4):
    
    parameter = {"PRICE_WIDTH":PRICE_WIDTH}
    # Debug information
    print(f"[DEBUG] Running simulation with PRICE_WIDTH={PRICE_WIDTH}")
    print(f"[DEBUG] Parameters: {parameter}")

    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,

        # Arguments
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        parameters=parameter,
        timescale=("1ns", "1ps"),
        log_file="sim.log")

    runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)

# Parametrize test for different PRICE_WIDTH
@pytest.mark.parametrize("PRICE_WIDTH", [4,5,8,12])

def test_sort(PRICE_WIDTH):
    # Run the simulation with specified parameters
    test_runner(PRICE_WIDTH=PRICE_WIDTH)
