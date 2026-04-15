# test_runner.py

import os
from cocotb.runner import get_runner
import pytest
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Fetch environment variables
verilog_sources = os.getenv("VERILOG_SOURCES", "").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG", "verilog")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")

def runner(in_width, out_width):
    """
    Runs the cocotb simulation with the specified IN_WIDTH and OUT_WIDTH parameters.

    Args:
        in_width (int): The IN_WIDTH value to test.
        out_width (int): The OUT_WIDTH value to test.
    """
    logger.info(f"Starting simulation with IN_WIDTH = {in_width}")
    logger.info(f"Starting simulation with OUT_WIDTH = {out_width}")

    # Initialize the simulator runner
    runner = get_runner(sim)

    # Build the simulation with the specified IN_WIDTH and OUT_WIDTH parameters
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters={"IN_WIDTH": in_width, "OUT_WIDTH": out_width},
        # Simulator Arguments
        always=True,
        clean=True,
        waves=True,        # Disable waveform generation for faster runs
        verbose=True,      # Set to True for detailed simulator logs
        timescale=("1ns", "1ps"),
        log_file=f"sim_{toplevel}.log"
    )

    # Run the simulation
    runner.test(
        hdl_toplevel=toplevel,
        test_module=module,
        waves=True
    )

    logger.info(f"Completed simulation with IN_WIDTH and OUT_WIDTH = {in_width, out_width}")

@pytest.mark.parametrize("in_width, out_width", [(16, 32)])  # Add desired IN_WIDTH and OUT_WIDTH values here
def test_cvdp_agentic_spi_complex_mult(in_width, out_width):
    """
    Pytest function to run cocotb simulations with different IN_WIDTH and OUT_WIDTH parameters.

    Args:
        in_width (int): The IN_WIDTH value to test.
        out_width (int): The OUT_WIDTH value to test.
    """
    try:
        runner(in_width, out_width)
    except Exception as e:
        logger.error(f"Simulation failed for IN_WIDTH and OUT_WIDTH = {in_width, out_width}: {e}")
        # Using assert False to report failure without halting other tests
        assert False, f"Simulation failed for IN_WIDTH and OUT_WIDTH = {in_width, out_width}: {e}"