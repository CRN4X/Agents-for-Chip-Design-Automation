import subprocess


def run_sim():
    cmd = ["iverilog", "-o", "sim.out", "rtl/design.v", "tb/tb.v"]
    subprocess.run(cmd)

    result = subprocess.run(["vvp", "sim.out"], capture_output=True)
    return result.stdout.decode()


if __name__ == "__main__":
    print(run_sim())