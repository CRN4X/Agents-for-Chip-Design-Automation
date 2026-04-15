import os
from cocotb_tools.runner import get_runner
import pytest

verilog_sources = os.getenv("VERILOG_SOURCES").split()
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

def runner(BIT_WIDTH: int = 8,REFERENCE_COUNT: int =4 ):

    parameter = {
        "BIT_WIDTH": BIT_WIDTH,"REFERENCE_COUNT" : REFERENCE_COUNT,
    }
  
    print(f"[DEBUG] Parameters: {parameter}")
    
    runner = get_runner(sim)
    runner.build(
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
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=wave)


@pytest.mark.parametrize("test", range(1))
@pytest.mark.parametrize("BIT_WIDTH", [4, 10, 3, 20])
@pytest.mark.parametrize("REFERENCE_COUNT", [4,8])
def test_min_distance(test, BIT_WIDTH,REFERENCE_COUNT):
    runner(BIT_WIDTH=BIT_WIDTH, REFERENCE_COUNT=REFERENCE_COUNT)