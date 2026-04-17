import os
import re
import subprocess
import pytest

# ----------------------------------------
# - Simulate
# ----------------------------------------

sim = f"xrun /src/*.sv /code/verif/*.sv -seed random"

def check_log(filename = "sim.log", expected = 0):

    # ----------------------------------------
    # - Check for errors in the log
    # ----------------------------------------

    with open(filename) as f:
        lines = f.readlines()

    errors = []
    for line in lines[3:]:
        errors.append(re.findall(r'*E', line))

    # ----------------------------------------
    # - Evaluate Report
    # ----------------------------------------

    assert len(errors) == expected, "Simulation ended with error."

@pytest.mark.usefixtures(scope='session')
def test_sanity():

    res = subprocess.run(f"{sim} -l /code/rundir/sanity.log", shell=True)
    assert(res.returncode == 0), "Simulation ended with error."

# ----------------------------------------
# - Generate Bug Simulations
# ----------------------------------------

@pytest.mark.usefixtures(scope='test_sanity')
def test_errors():

    num_bugs = int(os.getenv("NUM_BUGS"))

    for i in range(num_bugs):
        bug = f"-define BUG_{i}=1"
        cmd = f"{sim} {bug}"

        res = subprocess.run(f"{cmd} -l /code/rundir/bug_{i}.log", shell=True)
        assert(res.returncode != 0), "Simulation ended without error."
