from cocotb.runner import get_runner
import os
import subprocess
import re

def runner(module, toplevel, src:list, plusargs:list =[], args:tuple = (), parameter:dict={},
           wave:bool = False, sim:str = "icarus", cov_selection:str = ""):
    runner = get_runner(sim)
    runner.build(
        sources=src,
        hdl_toplevel=toplevel,
        # Arguments
        parameters=parameter,
        # compiler args
        build_args=args,
        always=True,
        clean=True,
        waves=wave,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="build.log")

    extra_env: dict = {}
    if cov_selection:
        extra_env["SELECTION"] = cov_selection

    runner.test(hdl_toplevel=toplevel, test_module=module, waves=wave, plusargs=plusargs, log_file="sim.log",
                extra_env=extra_env)

def coverage_report(asrt_type:str):
    '''asrt_type: assertion, toggle, overall'''
    cmd = f"imc -load /code/rundir/sim_build/cov_work/scope/test -execcmd \"report -metrics {asrt_type} -all -aspect sim -assertionStatus -overwrite -text -out coverage.log\""
    assert(subprocess.run(cmd, shell=True)), "Coverage merge didn't ran correctly."

def coverage_report_clear():
    report_file="/code/rundir/coverage.log"
    if os.path.isfile(report_file):
        os.remove(report_file)

def coverage_report_check(cov_threshold:float = 100.0):

    metrics = {}

    with open("/code/rundir/coverage.log") as f:
        lines = f.readlines()

    # ----------------------------------------
    # - Evaluate Report
    # ----------------------------------------
    column = re.split(r'\s{2,}', lines[0].strip())
    print(f'column: {column}')
    for line in lines[2:]:
        match = re.match(r'^(.*?)\s+(\d+\.?\d*% \(\d+/\d+\))\s+(\d+% \(\d+/\d+/\d+\))', line.strip())
        if match:
            info = list(match.groups())
            print(f'info: {info}')
        else:
            info = re.split(r'\s{2,}', line.strip())
            print(f"no regular expression match, trying differently: {info}")

        inst = info[0].lstrip('|-')
        print(f'inst: {inst}')
        metrics [inst] = {column[i]: info[i].split('%')[0] for i in range(1, len(column))}

    print("Metrics:")
    print(metrics)
    target_inst = None
    for inst in metrics:
        if inst == " |--inst_poly_filter_assert":
            target_inst = inst
            break
    if "Overall Average" in metrics[os.getenv("TOPLEVEL")]:
        assert float(metrics[os.getenv("TOPLEVEL")]["Overall Average"]) >= float(os.getenv("TARGET")), "Didn't achieved the required coverage result."
    elif "Assertion" in metrics[os.getenv("TOPLEVEL")]:
        assert float(metrics[target_inst]["Assertion"]) >= cov_threshold, f"Didn't achieved the required coverage result (cov_threshold={cov_threshold})."
    elif "Toggle" in metrics[os.getenv("TOPLEVEL")]:
        assert float(metrics[os.getenv("TOPLEVEL")]["Toggle"]) >= float(os.getenv("TARGET")), "Didn't achieved the required coverage result."
    elif "Block" in metrics[os.getenv("TOPLEVEL")]:
        assert float(metrics[os.getenv("TOPLEVEL")]["Block"]) >= float(os.getenv("TARGET")), "Didn't achieved the required coverage result."
    else:
        assert False, "Couldn't find the required coverage result."

def save_vcd(wave:bool, toplevel:str, new_name:str):
    if wave:
        os.makedirs("vcd", exist_ok=True)
        os.rename(f'./sim_build/{toplevel}.fst', f'./vcd/{new_name}.fst')
