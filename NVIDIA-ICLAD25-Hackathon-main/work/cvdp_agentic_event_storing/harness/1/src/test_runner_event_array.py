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

def runner(NS_ROWS: int = 4, NS_COLS: int = 4, NBW_COL: int = 2, NBW_STR: int = 8, NS_EVT: int = 8, NBW_EVT: int = 3):

    parameter = {
        "NS_ROWS": NS_ROWS,
        "NS_COLS": NS_COLS,
        "NBW_COL": NBW_COL,
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
random_nbw_rows = [2] + [random.randint(3, 4)]
random_nbw_cols = [2] + [random.randint(3, 4)]
random_nbw_str  = [4] + [random.randint(5, 6)]
random_nbw_evt  = [2] + [random.randint(3, 4)]

@pytest.mark.parametrize("NBW_ROWS", random_nbw_rows)
@pytest.mark.parametrize("NBW_COLS", random_nbw_cols)
@pytest.mark.parametrize("NBW_STR", random_nbw_str)
@pytest.mark.parametrize("NBW_EVT", random_nbw_evt)
def test_data(NBW_ROWS, NBW_COLS, NBW_STR, NBW_EVT):
    NS_COLS = 2**NBW_COLS
    NS_ROWS = 2**NBW_ROWS
    NS_EVT  = 2**NBW_EVT
    # Run the simulation with specified parameters
    runner(NS_ROWS=NS_ROWS, NS_COLS=NS_COLS, NBW_COL=NBW_COLS, NBW_STR=NBW_STR, NS_EVT=NS_EVT, NBW_EVT=NBW_EVT)
