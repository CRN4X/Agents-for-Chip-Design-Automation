import cocotb
import os
import pytest
import random
import math
from cocotb_tools.runner import get_runner

# Environment configuration
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))


def runner(NBW_DATA_IN: int, NS_DATA_IN: int, NBI_DATA_IN: int, NBW_ENERGY: int, NBW_PILOT_POS: int, NBW_TH_PROC: int):
    parameters = {
        "NBW_DATA_IN":    NBW_DATA_IN,
        "NS":             NS_DATA_IN,
        "NBI_DATA_IN":    NBI_DATA_IN,
        "NBW_ENERGY":     NBW_ENERGY,
        "NBW_PILOT_POS":  NBW_PILOT_POS,
        "NBW_TH_PROC":    NBW_TH_PROC,
        "NS_PROC":        23,
        "NS_PROC_OVERLAP":22
    }

    # Debug information
    print(f"[DEBUG] Running simulation with:")
    for k, v in parameters.items():
        print(f"  {k} = {v}")

    # Configure and run the simulation
    sim_runner = get_runner(sim)
    sim_runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameters,
        always=True,
        clean=True,
        waves=wave,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log"
    )

    # Run the test
    sim_runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)


# Generate valid parameter combinations
def generate_param_combinations():
    combinations = []

    for ns in range(32, 65, 2):  # NS: 32 to 64, step 2
        nbw_pilot_pos = int(math.ceil(math.log2(ns)))

        for nbw in range(3, 9):  # NBW_DATA_IN: at least 3
            nbi = nbw - 2  # NBI = NBW - 2
            if nbi < 1:
                continue

            nbw_th_faw = nbw + 2
            nbw_energy = nbw_th_faw

            combinations.append((nbw, ns, nbi, nbw_energy, nbw_pilot_pos, nbw_th_faw))

    return combinations


# Generate and limit number of tests
N_TESTS = 5
valid_param_combinations = generate_param_combinations()
limited_param_combinations = valid_param_combinations[:N_TESTS]  # Change [:3] to run more/less


# Parametrize using valid (NBW_DATA_IN, NS_DATA_IN, NBI_DATA_IN, NBW_ENERGY, ...) tuples
@pytest.mark.parametrize("NBW_DATA_IN, NS_DATA_IN, NBI_DATA_IN, NBW_ENERGY, NBW_PILOT_POS, NBW_TH_PROC", limited_param_combinations)
@pytest.mark.parametrize("test", range(3))
def test_data(NBW_DATA_IN, NS_DATA_IN, NBI_DATA_IN, NBW_ENERGY, NBW_PILOT_POS, NBW_TH_PROC, test):
    runner(
        NBW_DATA_IN=NBW_DATA_IN,
        NS_DATA_IN=NS_DATA_IN,
        NBI_DATA_IN=NBI_DATA_IN,
        NBW_ENERGY=NBW_ENERGY,
        NBW_PILOT_POS=NBW_PILOT_POS,
        NBW_TH_PROC=NBW_TH_PROC
    )