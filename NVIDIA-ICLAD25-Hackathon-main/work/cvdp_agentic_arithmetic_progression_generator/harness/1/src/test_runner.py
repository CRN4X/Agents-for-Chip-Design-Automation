import os
from cocotb_tools.runner import get_runner
import pytest
import random

# Fetch environment variables for simulation setup
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

# Runner function
def runner(DATA_WIDTH: int=0, SEQUENCE_LENGTH: int=0, start_val: int=0, step_size: int=0, enable: int=0):
    # Plusargs to pass simulation parameters enable
    plusargs = [
        f'+start_val={start_val}', 
        f'+step_size={step_size}',
        f'+enable={enable}'
    ]
    
    parameters = {
        "DATA_WIDTH": DATA_WIDTH,
        "SEQUENCE_LENGTH": SEQUENCE_LENGTH
    }

    # Debug information
    print(f"[DEBUG] Running simulation with DATA_WIDTH={DATA_WIDTH}, SEQUENCE_LENGTH={SEQUENCE_LENGTH}")
    print(f"[DEBUG] Start Value: {start_val}, Step Size: {step_size}")
    print(f"[DEBUG] Parameters: {parameters}")
    
    # Configure the simulation runner
    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameters,
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log"
    )
    
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=wave, plusargs=plusargs)

# Pytest parameterization
@pytest.mark.parametrize("DATA_WIDTH", [random.randint(4, 32)])
@pytest.mark.parametrize("SEQUENCE_LENGTH", [0])
@pytest.mark.parametrize("test", range(5))  # Run 50 tests
def test_arithmetic_progression_generator(DATA_WIDTH, SEQUENCE_LENGTH,test):
    runner(DATA_WIDTH=DATA_WIDTH, SEQUENCE_LENGTH=SEQUENCE_LENGTH)
