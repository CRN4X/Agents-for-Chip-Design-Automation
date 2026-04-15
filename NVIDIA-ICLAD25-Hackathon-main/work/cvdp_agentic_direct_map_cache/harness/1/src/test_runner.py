import os
from cocotb_tools.runner import get_runner
import pytest

verilog_sources = os.getenv("VERILOG_SOURCES").split()
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

def runner(CACHE_SIZE: int = 256,DATA_WIDTH: int = 16,TAG_WIDTH: int = 5,OFFSET_WIDTH: int = 3):
    parameter = {"CACHE_SIZE": CACHE_SIZE,"DATA_WIDTH":DATA_WIDTH,"TAG_WIDTH": TAG_WIDTH,"OFFSET_WIDTH":OFFSET_WIDTH}
    print(f"[DEBUG] Parameters: {parameter}")     

    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        # Arguments
        parameters=parameter,
        always=True,
        clean=True,
        waves=wave,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log")
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=wave)


@pytest.mark.parametrize("test", range(1))
@pytest.mark.parametrize("CACHE_SIZE", [64,256])
@pytest.mark.parametrize("DATA_WIDTH", [8,16])
@pytest.mark.parametrize("TAG_WIDTH", [3,5])
@pytest.mark.parametrize("OFFSET_WIDTH", [3,6])
def test_direct_cache(CACHE_SIZE,DATA_WIDTH,TAG_WIDTH,OFFSET_WIDTH, test):
    runner(CACHE_SIZE=CACHE_SIZE,DATA_WIDTH=DATA_WIDTH,TAG_WIDTH=TAG_WIDTH,OFFSET_WIDTH=OFFSET_WIDTH)
    
