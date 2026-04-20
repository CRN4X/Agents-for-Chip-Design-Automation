import os
from cocotb_tools.runner import get_runner
import pytest

verilog_sources = os.getenv("VERILOG_SOURCES").split()
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

def runner(plusargs=[], parameter={}):
    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        # Arguments
        parameters=parameter,
        always=True,
        clean=True,
        waves=1,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log")
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=1,plusargs=plusargs)

@pytest.mark.parametrize("M", [2])
@pytest.mark.parametrize("TAPS", [2])
@pytest.mark.parametrize("COEFF_WIDTH", [16])
@pytest.mark.parametrize("DATA_WIDTH", [16])
@pytest.mark.parametrize("test", range(1))
def test_poly_decimator(M, TAPS, COEFF_WIDTH, DATA_WIDTH, test):
    runner(parameter={"M": M, "TAPS": TAPS, "COEFF_WIDTH": COEFF_WIDTH, "DATA_WIDTH": DATA_WIDTH})
