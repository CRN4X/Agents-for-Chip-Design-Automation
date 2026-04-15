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

def runner(NBW_IN_DATA: int = 8, NS_IN: int = 2):
    # Simulation parameters
    parameter = {
        "NBW_IN_DATA": NBW_IN_DATA,
        "NS_IN": NS_IN
    }

    # Debug information
    print(f"[DEBUG] Running simulation with NBW_IN_DATA={NBW_IN_DATA}")
    print(f"[DEBUG] Running simulation with NS_IN      ={NS_IN}")
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

# Generate random values for testing
random_nbw_in_data = [3] + [random.randint(4, 10) for _ in range(2)] # Minimum 3
random_ns_data     = [2] + [random.randint(4, 10) for _ in range(2)] # Minimum 2 

# Parametrize test for different random data sizes
@pytest.mark.parametrize("NBW_IN_DATA", random_nbw_in_data)
@pytest.mark.parametrize("NS_IN",random_ns_data)
@pytest.mark.parametrize("test", range(5))
def test_data(NBW_IN_DATA, NS_IN, test):
    # Run the simulation with specified parameters
    runner(NBW_IN_DATA=NBW_IN_DATA, NS_IN=NS_IN)