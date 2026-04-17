import os
import re
from cocotb.runner import get_runner
import pytest
import subprocess

# Fetch environment variables for Verilog source setup
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = os.getenv("WAVE")

@pytest.mark.usefixtures(scope='session')
def test_simulate():

    runner = get_runner(sim)

    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        build_args=("-coverage", "all", "-covoverwrite", "-covtest", "test"),
        timescale=("1ns", "1ns"),
        log_file="build.log"
    )
    runner.test(hdl_toplevel=toplevel, test_module=module,waves=True)

# # ----------------------------------------
# # - Generate Coverage
# # ----------------------------------------

@pytest.mark.usefixtures(scope='test_simulate')
def test_coverage():

    cmd = "imc -load /code/rundir/sim_build/cov_work/scope/test -execcmd \"report -metrics assertion -all -aspect sim -assertionStatus -overwrite -text -out coverage.log\""
    # cmd = "imc -load /code/rundir/sim_build/cov_work/scope/test -execcmd \"report -metrics toggle -all -aspect sim -assertionStatus -text -out coverage.log\""
    # cmd = "imc -load /code/rundir/sim_build/cov_work/scope/test -execcmd \"report -metrics overall -all -aspect sim -assertionStatus -text -out coverage.log\""
    # cmd = "imc -load /code/rundir/sim_build/cov_work/scope/test -execcmd \"report -metrics assertion -all -aspect sim -assertionStatus -out coverage.log\""
    assert(subprocess.run(cmd, shell=True)), "Coverage merge didn't ran correctly."

# ----------------------------------------
# - Report
# ----------------------------------------

@pytest.mark.usefixtures(scope='test_coverage')
def test_report():

    metrics = {}

    with open("/code/rundir/coverage.log") as f:
        lines = f.readlines()

    # ----------------------------------------
    # - Evaluate Report
    # ----------------------------------------
    column = re.split(r'\s{2,}', lines[0].strip())
    for line in lines[2:]:
        info = re.split(r'\s{2,}', line.strip())
        inst = info[0].lstrip('|-')
        metrics [inst] = {column[i]: info[i].split('%')[0] for i in range(1, len(column))}

    print("Metrics:")
    print(metrics)

    if "Overall Average" in metrics[os.getenv("TOPLEVEL")]:
        assert float(metrics[os.getenv("TOPLEVEL")]["Overall Average"]) >= float(os.getenv("TARGET")), "Didn't achieved the required coverage result."
    elif "Assertion" in metrics[os.getenv("TOPLEVEL")]:
        assert float(metrics[os.getenv("TOPLEVEL")]["Assertion"]) >= 100.00, "Didn't achieved the required coverage result."
    elif "Toggle" in metrics[os.getenv("TOPLEVEL")]:
        assert float(metrics[os.getenv("TOPLEVEL")]["Toggle"]) >= float(os.getenv("TARGET")), "Didn't achieved the required coverage result."
    elif "Block" in metrics[os.getenv("TOPLEVEL")]:
        assert float(metrics[os.getenv("TOPLEVEL")]["Block"]) >= float(os.getenv("TARGET")), "Didn't achieved the required coverage result."
    else:
        assert False, "Couldn't find the required coverage result."

if __name__ == "__main__":
    test_simulate()