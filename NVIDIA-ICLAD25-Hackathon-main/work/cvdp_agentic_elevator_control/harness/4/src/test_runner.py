import os
from pathlib import Path
from cocotb_tools.runner import get_runner
import pytest
import re
import logging

# List from Files
verilog_sources = os.getenv("VERILOG_SOURCES").split()
    
    # Language of Top Level File
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")

def test_runner(FLOOR: int=8):

    ## Note: To reduce the sim time, design is passed with SIMULATION define to have door open time of 0.05 ms
    ##Note: Harness if not intended to test for various DOOR OPEN TIME.
    ##      It only test for multiple floors.

    # Parameterize the test
    parameter_defines = {
        "N": FLOOR,
    }
    print(f"script: N={FLOOR}")
    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,

        # Arguments
        parameters=parameter_defines,
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        timescale=("1ns", "1ps"),
        log_file="sim.log",
        defines={"SIMULATION": None}

    )

    plusargs = [f"+N={FLOOR}"]
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=True, plusargs=plusargs)



@pytest.mark.parametrize("FLOOR", [8,5,10])
def test_elevator_control_system(FLOOR):
    """Parameterized test for elevator control system"""

    print(f"Runner script: N={FLOOR}")
    test_runner(FLOOR=FLOOR)
