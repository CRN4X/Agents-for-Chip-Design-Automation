# test_runner.py
# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

import os
import pytest
from cocotb.runner import get_runner

# Environment variables provided externally (e.g. via Makefile or CI config)
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")


@pytest.mark.tb
@pytest.mark.parametrize("DATA_WIDTH", [8, 16, 32])
def test_runner(DATA_WIDTH):

    runner = get_runner(sim)

    # Build step: pass the parameter to the simulator so that the Verilog code
    # uses the specified DATA_WIDTH. The specifics depend on the simulator.
    # The 'parameters' dict is supported in newer versions of cocotb-test/cocotb.
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters={"DATA_WIDTH": DATA_WIDTH},  
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        timescale=("1ns", "1ps"),
        log_file="sim.log"
    )

    # Run step: the specified top-level and test module are used.
    runner.test(
        hdl_toplevel=toplevel,
        test_module=module,
        waves=True
    )
