import os
from cocotb.runner import get_runner

verilog_sources = os.getenv("VERILOG_SOURCES", "").split()
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = os.getenv("WAVE", "1")

build_clean     = os.getenv("BUILD_CLEAN", "1") == "1"
build_always    = os.getenv("BUILD_ALWAYS", "1") == "1"
build_verbose   = os.getenv("BUILD_VERBOSE", "1") == "1"
timescale_env   = os.getenv("TIMESCALE", "1ns,1ns").split(",")
log_file        = os.getenv("LOG_FILE", "build.log")

def test_runner():
    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        always=build_always,
        clean=build_clean,
        waves=(wave=="1"),
        verbose=build_verbose,
        timescale=(timescale_env[0], timescale_env[1]),
        log_file=log_file
    )
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=(wave=="1"))

if __name__ == "__main__":
    test_runner()
