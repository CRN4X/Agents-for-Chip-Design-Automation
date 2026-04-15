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

def test_runner(WIDTH: int=4,CHECK_MODE: int=0,POLY_LENGTH:int=31,POLY_TAP: int=3):
    
    parameter = {"WIDTH":WIDTH, "CHECK_MODE":CHECK_MODE, "POLY_LENGTH":POLY_LENGTH, "POLY_TAP":POLY_TAP}
    # Debug information
    print(f"[DEBUG] Running simulation with WIDTH={WIDTH}, CHECK_MODE={CHECK_MODE}, POLY_LENGTH={POLY_LENGTH}, POLY_TAP={POLY_TAP}")
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

# Parametrize test for different WIDTH,CHECK_MODE,POLY_LENGTH,POLY_TAP
@pytest.mark.parametrize("WIDTH", [4,5,8,12])
@pytest.mark.parametrize("CHECK_MODE", [0,1])
@pytest.mark.parametrize("POLY_LENGTH", [7,23,31])
@pytest.mark.parametrize("POLY_TAP", [1,3,5])

def test_sort(WIDTH,CHECK_MODE,POLY_LENGTH,POLY_TAP):
    # Run the simulation with specified parameters
    test_runner(WIDTH=WIDTH,CHECK_MODE=CHECK_MODE,POLY_LENGTH=POLY_LENGTH,POLY_TAP=POLY_TAP)
