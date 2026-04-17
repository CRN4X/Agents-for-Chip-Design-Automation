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
cov_selections  = os.getenv("COV_SELECTIONS", "").split()
cov_thresholds  = [float(s) for s in os.getenv("COV_THRESHOLDS", "").split()]

def call_runner(parameter={}, cov_selection:tuple[str, float] = None):
    plusargs = {}
    try:
        args = []
        if sim == "xcelium":
            args = ("-coverage all", " -covoverwrite", "-sv", "-covtest test", "-svseed random")

        coverage.coverage_report_clear()
        coverage.runner(
            wave=wave,
            toplevel=toplevel,
            plusargs=[],
            module=module,
            src=verilog_sources,
            sim=sim,
            args=args,
            parameter=parameter,
            cov_selection=cov_selection[0] if cov_selection else "",
        )
        coverage.coverage_report("assertion")
        if cov_selection:
            print(f'cov_selection[0]: {cov_selection[0]} cov_selection[1]: {cov_selection[1]}')
            coverage.coverage_report_check(cov_selection[1])
        else:
            coverage.coverage_report_check()
    except SystemExit:
        raise SystemError("simulation failed due to assertion failed in your test")

@pytest.mark.parametrize("N", [2])
@pytest.mark.parametrize("TAPS", [2])
@pytest.mark.parametrize("COEFF_WIDTH", [16])
@pytest.mark.parametrize("DATA_WIDTH", [16])
@pytest.mark.parametrize("test", range(1))
def test_data(N, TAPS, COEFF_WIDTH, DATA_WIDTH, test):

    if len(cov_selections) == 0:
        # Run the simulation
        print("Calling runner without arguments")
        call_runner(parameter={"N": N, "TAPS": TAPS, "COEFF_WIDTH": COEFF_WIDTH, "DATA_WIDTH": DATA_WIDTH})
        return

    print("Identified special coverage selections")

    assert len(cov_selections) == len(cov_thresholds), "incompatible coverage selections and thresholds"

    for selection, threshold in zip(cov_selections, cov_thresholds):
        print(f"> Running selection: {selection}, for threshold: {threshold}")
        call_runner({"N": N, "TAPS": TAPS, "COEFF_WIDTH": COEFF_WIDTH, "DATA_WIDTH": DATA_WIDTH},(selection, threshold))

