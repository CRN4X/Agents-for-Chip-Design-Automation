import os
import random
from cocotb_tools.runner import get_runner
import pytest

# Gather environment variables for simulation settings
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

# Define a runner function that takes the WIDTH parameter
def runner(DATA_WIDTH, ARRAY_SIZE):
    # Get the simulator runner for the specified simulator (e.g., icarus)
    runner = get_runner(sim)
    
    # Build the simulation environment with the randomized WIDTH parameter
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters={'DATA_WIDTH': DATA_WIDTH, 'ARRAY_SIZE' : ARRAY_SIZE},
        always=True,               # Build even if files have not changed
        clean=True,                # Clean previous builds
        waves=True,
        verbose=False,
        timescale=("1ns", "1ns"),  # Set timescale
        log_file="sim.log"         # Log the output of the simulation
    )
    
    # Run the test module
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=wave)

# Parametrize test for different WIDTH and SIGNED_EN
@pytest.mark.parametrize("DATA_WIDTH, ARRAY_SIZE", [(6, 5), (6,6), (16,10), (6,15), (32,15)]) 
#@pytest.mark.parametrize("DATA_WIDTH, ARRAY_SIZE", [(6, 5)]) 
def test_bst(DATA_WIDTH, ARRAY_SIZE):
    # Log the randomized WIDTH
    print(f'Running with: DATA_WIDTH = {DATA_WIDTH}, ARRAY_SIZE = {ARRAY_SIZE}')

    # Call the runner function with the randomized WIDTH
    runner(DATA_WIDTH,ARRAY_SIZE)