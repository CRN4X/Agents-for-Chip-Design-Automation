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

def runner(NBW_STR: int = 8, NS_EVT: int = 8, NBW_EVT: int = 3):

    parameter = {
        "NBW_STR": NBW_STR,
        "NS_EVT": NS_EVT,
        "NBW_EVT": NBW_EVT
    }

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

# Generate minimum and more random sizes
random_nbw_str  = [4] + [random.randint(5, 8) for _ in range(1)]
random_nbw_evt  = [2] + [random.randint(3, 5) for _ in range(1)]

@pytest.mark.parametrize("NBW_STR", random_nbw_str)
@pytest.mark.parametrize("NBW_EVT", random_nbw_evt)
def test_data(NBW_STR, NBW_EVT):
    NS_EVT  = 2**NBW_EVT
    # Run the simulation with specified parameters
    runner(NBW_STR=NBW_STR, NS_EVT=NS_EVT, NBW_EVT=NBW_EVT)