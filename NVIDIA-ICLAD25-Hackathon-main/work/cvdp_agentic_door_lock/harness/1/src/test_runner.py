import os
from pathlib import Path
from cocotb_tools.runner import get_runner
import pytest
import random

verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = os.getenv("WAVE")

def runner(PASSWORD_LENGTH, MAX_TRIALS):
    parameter = {
    "PASSWORD_LENGTH": PASSWORD_LENGTH,
    "MAX_TRIALS": MAX_TRIALS,
    }
    # Debug information
    print(f"[DEBUG] Running simulation with PASSWORD_LENGTH={PASSWORD_LENGTH} and MAX_TRIALS={MAX_TRIALS}")
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

# # Parametrize test for random parameters
@pytest.mark.parametrize("random_test", range(10))
def test_random_door_lock(random_test):
    PASSWORD_LENGTH = random.randint(4, 8)
    MAX_TRIALS = random.randint(4, 8)
    # Run the simulation with specified parameters
    runner(PASSWORD_LENGTH=PASSWORD_LENGTH, MAX_TRIALS=MAX_TRIALS)
