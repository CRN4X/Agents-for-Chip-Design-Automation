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

    # Search for line starting with '|--uart_top'
    for line in lines:
        if re.match(r'\|\-\-uart_top\s+', line):
            # Extract the Overall Average percentage
            match = re.search(r'\|\-\-uart_top\s+([0-9.]+)%\s+([0-9.]+%)', line)
            if match:
                avg = float(match.group(1))  # Overall Average
                cov = float(match.group(2).replace('%', ''))  # Overall Covered
                metrics["uart_top"] = {
                    "Average": avg,
                    "Covered": cov
                }
            break  # Found the line, break the loop

    assert "uart_top" in metrics, "uart_top coverage data not found."
    assert metrics["uart_top"]["Average"] >= float(os.getenv("TARGET", "50")), "Didn't achieve the required coverage result."
