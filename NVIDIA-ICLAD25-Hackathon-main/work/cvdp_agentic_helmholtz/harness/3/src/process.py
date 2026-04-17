import os
import re
import subprocess
import pytest      ##

# ----------------------------------------
# - Simulate
# ----------------------------------------

@pytest.mark.usefixtures(scope='session')
def test_simulate():

    cmd = "xrun -coverage all /src/*.sv /code/verif/helmholtz_top_module_tb.sv -covtest test -seed random -covoverwrite"
    assert(subprocess.run(cmd, shell=True)), "Simulation didn't ran correctly."

# ----------------------------------------
# - Generate Coverage
# ----------------------------------------

@pytest.mark.usefixtures(scope='test_simulate')
def test_coverage():

    cmd = "imc -load /code/rundir/cov_work/scope/test -exec /src/coverage.cmd"
    assert(subprocess.run(cmd, shell=True)), "Coverage merge didn't ran correctly."

# ----------------------------------------
# - Report
# ----------------------------------------
@pytest.mark.usefixtures(scope='test_coverage')
def test_report():
    metrics = {}
    try:
        with open("/code/rundir/coverage.log") as f:
            lines = f.readlines()
    except FileNotFoundError:
        raise FileNotFoundError("Couldn't find the coverage.log file.")

    # ----------------------------------------
    # - Evaluate Report
    # ----------------------------------------
    column = re.split(r'\s{2,}', lines[0].strip())
    for line in lines[2:]:
        info = re.split(r'\s{2,}', line.strip())
        inst = info[0].lstrip('|-')
        metrics [inst] = {column[i]: info[i].split('%')[0] for i in range(1, len(column))}
    print("Parsed Metrics:")
    print(metrics)

    # Ensure TARGET environment variable is set
    target = os.getenv("TARGET")
    if not target:
        raise ValueError("TARGET environment variable is not set.")
    target = float(target)

    # Check coverage for the DUT or specific key
    uut = "dut"  # Replace this with the DUT key you want to check
    if uut in metrics and "Overall Average" in metrics[uut]:
        assert float(metrics[uut]["Overall Average"]) >= target, "Didn't achieve the required coverage result."
    else:
        # Log available keys for debugging
        print(f"Available keys in metrics: {metrics.keys()}")
        assert False, f"Coverage data for '{uut}' is not available."
