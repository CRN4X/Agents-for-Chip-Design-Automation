import os
import random
import pytest
from cocotb_tools.runner import get_runner

# Environment configuration
verilog_sources = os.getenv("VERILOG_SOURCES", "").split()
sim = os.getenv("SIM", "icarus")
toplevel = os.getenv("TOPLEVEL", "")
module = os.getenv("MODULE", "")
wave = bool(os.getenv("WAVE"))


def runner(parameters=None):
    # Configure and run the simulation
    sim_runner = get_runner(sim)
    sim_runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameters or {},
        always=True,
        clean=True,
        waves=wave,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log",
    )

    # Run the test
    sim_runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)


def _event_array_params():
    random_nbw_rows = [2] + [random.randint(3, 4) for _ in range(1)]
    random_nbw_cols = [2] + [random.randint(3, 4) for _ in range(1)]
    random_nbw_str = [4] + [random.randint(5, 8) for _ in range(1)]
    random_nbw_evt = [2] + [random.randint(3, 4) for _ in range(1)]

    combos = []
    for nbw_rows in random_nbw_rows:
        for nbw_cols in random_nbw_cols:
            for nbw_str in random_nbw_str:
                for nbw_evt in random_nbw_evt:
                    combos.append(
                        {
                            "NS_ROWS": 2**nbw_rows,
                            "NS_COLS": 2**nbw_cols,
                            "NBW_COL": nbw_cols,
                            "NBW_STR": nbw_str,
                            "NS_EVT": 2**nbw_evt,
                            "NBW_EVT": nbw_evt,
                        }
                    )
    return combos


def _event_storage_params():
    random_nbw_str = [4] + [random.randint(5, 8) for _ in range(1)]
    random_nbw_evt = [2] + [random.randint(3, 5) for _ in range(1)]

    combos = []
    for nbw_str in random_nbw_str:
        for nbw_evt in random_nbw_evt:
            combos.append(
                {
                    "NBW_STR": nbw_str,
                    "NS_EVT": 2**nbw_evt,
                    "NBW_EVT": nbw_evt,
                }
            )
    return combos


def _selected_param_sets():
    if "event_array" in toplevel or "event_array" in module:
        return _event_array_params()
    if "event_storage" in toplevel or "event_storage" in module:
        return _event_storage_params()
    return [{}]


@pytest.mark.parametrize("params", _selected_param_sets())
def test_data(params):
    print(f"[DEBUG] Parameters: {params}")
    runner(parameters=params)
