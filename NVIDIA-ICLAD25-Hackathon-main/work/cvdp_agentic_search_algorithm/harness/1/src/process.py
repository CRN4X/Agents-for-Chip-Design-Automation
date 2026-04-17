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
    result = subprocess.run(cmd, shell=True)
    assert result.returncode == 0, "Simulation didn't run correctly."

# ----------------------------------------
# - Generate Coverage
# ----------------------------------------
@pytest.mark.usefixtures(scope='test_simulate')
def test_coverage():
    cmd = "imc -load /code/rundir/cov_work/scope/test -exec /src/coverage.cmd"
    result = subprocess.run(cmd, shell=True)
    assert result.returncode == 0, "Coverage merge didn't run correctly."

# ----------------------------------------
# - Report
# ----------------------------------------
@pytest.mark.usefixtures(scope='test_coverage')
def test_report():
    try:
        with open("/code/rundir/coverage.log") as f:
            lines = f.readlines()
    except FileNotFoundError:
        raise FileNotFoundError("Couldn't find the coverage.log file.")

    # Retrieve the target coverage and the top module name from the environment.
    target = float(os.getenv("TARGET"))
    top_module_name = os.getenv("TOP_MODULE", "linear_search_top_inst")
    
    metrics_list = []
    # Updated regex pattern to allow integer or float percentages.
    pattern = re.compile(
        r'^(?P<name>[\|\-\s\w]+)\s+(?P<avg>\d+(?:\.\d+)?)%\s+(?P<cov>\d+(?:\.\d+)?)%'
    )
    
    # Skip header lines (assuming first two lines are headers)
    for line in lines[2:]:
        line = line.strip()
        if not line:
            continue
        match = pattern.match(line)
        if not match:
            continue

        raw_name = match.group("name")
        avg_str  = match.group("avg")
        cov_str  = match.group("cov")

        # Determine hierarchy level by counting the '|' characters in the raw module name.
        level = raw_name.count('|')
        # Clean the module name by removing leading pipes, dashes, and spaces, then strip any extra whitespace.
        inst = re.sub(r'^[\|\-\s]+', '', raw_name).strip()

        metrics_list.append({
            "name": inst,
            "level": level,
            "average": float(avg_str),
            "covered": float(cov_str)
        })
    
    # Locate the top module in the parsed metrics list.
    top_index = None
    for i, entry in enumerate(metrics_list):
        if entry["name"] == top_module_name:
            top_index = i
            top_level = entry["level"]
            break
    assert top_index is not None, f"Top module '{top_module_name}' not found in coverage report."
    
    # Gather the top module and all its submodules.
    modules_to_check = []
    for entry in metrics_list[top_index:]:
        # Only include entries that are at the top module's level or deeper.
        if entry["level"] < top_level:
            break
        modules_to_check.append(entry)
    
    # Check that each module meets the target average coverage.
    for mod in modules_to_check:
        assert mod["average"] >= target, (
            f"Coverage for module '{mod['name']}' is {mod['average']}%, which is below the target of {target}%."
        )
