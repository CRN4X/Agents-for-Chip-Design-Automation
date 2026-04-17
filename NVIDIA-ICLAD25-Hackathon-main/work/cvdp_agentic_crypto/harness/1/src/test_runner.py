import os
import pytest
import coverage
import random

# Environment configuration
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

def call_runner():
    encoder_in = random.randint(0, 255)
    plusargs = [f'+encoder_in={encoder_in}']
    try:
        args = []
        if sim == "xcelium":
            args = ("-coverage all", " -covoverwrite", "-sv", "-covtest test", "-svseed random")

        coverage.covt_report_clear()
        coverage.runner(
            wave=wave,
            toplevel=toplevel,
            plusargs=plusargs,
            module=module,
            src=verilog_sources,
            sim=sim,
            args=args,
            parameter={}
        )
        coverage.coverage_report("assertion")
        coverage.covt_report_check()
    except SystemExit:
        raise SystemError("simulation failed due to assertion failed in your test")

@pytest.mark.parametrize("test", range(1))
def test_data(test):
    # Run the simulation
    call_runner()
