import os
import re
import subprocess
import pytest

# ----------------------------------------
# - Simulate
# ----------------------------------------

@pytest.mark.usefixtures(scope='session')
def test_simulate():

    cmd = "xrun -coverage all /src/*.sv /code/verif/*.sv -covtest test -seed random -covoverwrite"
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

    with open("/code/rundir/coverage.log") as f:
        lines = f.readlines()

    # ----------------------------------------
    # - Evaluate Report
    # ----------------------------------------

    for line in lines[2:]:
        info = line.split()

        while len(info) < 3:
            info.append("0%")

        inst = re.sub(r'[\W]', '', info[0])

        try:
            avg = float(info[1].rstrip('%')) if '%' in info[1] else 0.0
            cov = float(info[2].rstrip('%')) if '%' in info[2] else 0.0
        except ValueError:
            avg = 0.0
            cov = 0.0

        # Store the metrics
        metrics[inst] = {
            "Average": avg,
            "Covered": cov
        }

    # Check if the required key exists in the metrics
    if "dut" not in metrics:
        raise KeyError("Metrics data for 'dut' is missing in the coverage log.")

    # Assert the average coverage for 'dut' is above the target
    target = float(os.getenv("TARGET", 85.0))  
    assert metrics["dut"]["Average"] >= target, f"Didn't achieve the required coverage result. Achieved: {metrics['dut']['Average']}, Target: {target}"
