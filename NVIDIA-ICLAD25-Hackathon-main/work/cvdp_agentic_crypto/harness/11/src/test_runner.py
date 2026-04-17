import os
import pytest
import coverage
import random
import traceback

# Environment configuration
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))
cov_selections  = os.getenv("COV_SELECTIONS", "").split()
cov_thresholds  = [float(s) for s in os.getenv("COV_THRESHOLDS", "").split()]

def call_runner(cov_selection:tuple[str, float] = None):
    encoder_in = random.randint(0, 255)
    plusargs = [f'+encoder_in={encoder_in}']
    try:
        args = []
        if sim == "xcelium":
            args = ("-coverage all", " -covoverwrite", "-sv", "-covtest test", "-svseed random")

        coverage.coverage_report_clear()
        coverage.runner(
            wave=wave,
            toplevel=toplevel,
            plusargs=plusargs,
            module=module,
            src=verilog_sources,
            sim=sim,
            args=args,
            parameter={},
            cov_selection=cov_selection[0] if cov_selection else "",
        )
        coverage.coverage_report("assertion")
        if cov_selection:
            print(f'cov_selection[0]: {cov_selection[0]} cov_selection[1]: {cov_selection[1]}')
            coverage.coverage_report_check(cov_selection[1])
        else:
            coverage.coverage_report_check()
    except SystemExit:
        traceback.print_exc()
        raise SystemError("simulation failed due to assertion failed in your test")

@pytest.mark.parametrize("test", range(1))
def test_data(test):

    if len(cov_selections) == 0:
        # Run the simulation
        print("Calling runner without arguments")
        call_runner()
        return

    print("Identified special coverage selections")

    assert len(cov_selections) == len(cov_thresholds), "incompatible coverage selections and thresholds"

    for selection, threshold in zip(cov_selections, cov_thresholds):
        print(f"> Running selection: {selection}, for threshold: {threshold}")
        call_runner((selection, threshold))

