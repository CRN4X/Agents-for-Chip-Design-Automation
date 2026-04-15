import cocotb
import os
import pytest
import random
from cocotb_tools.runner import get_runner

# Environment configuration
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

def runner(NBW_IN: int = 7):
    # Simulation parameters
    parameter = {
        "NBW_IN": NBW_IN
    }

    # Debug information
    print(f"[DEBUG] Running simulation with NBW_IN={NBW_IN}")
    print(f"[DEBUG] Parameters: {parameter}")

    # Configure and run the simulation
    sim_runner = get_runner(sim)
    sim_runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameter,
        always=True,
        clean=True,
        waves=wave,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log"
    )

    # Run the test
    sim_runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)

# Generate default sizes (commented alternative with random values)
NBW_IN_vals    = [8] + [random.randint(8, 16) for _ in range(5)]

# Parametrize test for default data sizes
@pytest.mark.parametrize("NBW_IN", NBW_IN_vals)
@pytest.mark.parametrize("test", range(3))
def test_data(NBW_IN, test):
    # Run the simulation with specified parameters
    runner(NBW_IN=NBW_IN)