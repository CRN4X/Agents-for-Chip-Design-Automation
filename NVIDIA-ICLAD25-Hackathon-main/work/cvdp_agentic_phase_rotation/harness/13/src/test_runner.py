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

def runner(NBW_REF: int = 7, NBW_TH: int = 7, NBW_IN: int = 7, NBW_OUT: int = 8):
    # Simulation parameters
    parameter = {
        "NBW_REF": NBW_REF,
        "NBW_TH": NBW_TH,
        "NBW_IN": NBW_IN,
        "NBW_OUT": NBW_OUT
    }

    # Debug information
    print(f"[DEBUG] Running simulation with NBW_REF={NBW_REF}, NBW_TH={NBW_TH}")
    print(f"[DEBUG] Running simulation with NBW_IN={NBW_IN}, NBW_OUT={NBW_OUT}")
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

# Gerar valores relacionados
NBW_REF_vals = [7] + [random.randint(8, 16) for _ in range(7)]
NBW_TH_vals  = [7] + [random.randint(8, 16) for _ in range(7)]
NBW_IN_vals  = [7] + [random.randint(8, 16) for _ in range(7)]
NBW_OUT_vals = [ref + 1 if ref > th else th + 1 for th, ref in zip(NBW_TH_vals, NBW_REF_vals)]

# Agrupar os parâmetros relacionados como tuplas
test_configs = list(zip(NBW_REF_vals, NBW_TH_vals, NBW_IN_vals, NBW_OUT_vals))

# Parametrize com tupla
@pytest.mark.parametrize("NBW_REF, NBW_TH, NBW_IN, NBW_OUT", test_configs)
@pytest.mark.parametrize("test", range(7))
def test_data(NBW_REF, NBW_TH, NBW_IN, NBW_OUT, test):
    runner(NBW_REF=NBW_REF, NBW_TH=NBW_TH, NBW_IN=NBW_IN, NBW_OUT=NBW_OUT)