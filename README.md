# NVIDIA Debug Problem Set

This repository evaluates agentic RTL debugging/generation workflows on harnessed verification tasks.

## Repository Layout

- `dataset/`: benchmark problem metadata (`.jsonl`)
- `work/`: generated harnesses, run artifacts, and reports
- `my-agent/`: your local agent, scripts, staged editable RTL, and batch reports
- `examples/`: example baseline agent assets

## Prerequisites (Local No-Docker Flow)

- `python3`
- Icarus Verilog tools:
  - `iverilog`
  - `vvp`

### macOS

```bash
brew install icarus-verilog
```

### Linux (Ubuntu/Debian)

```bash
sudo apt-get update
sudo apt-get install -y iverilog
```

### Windows (No WSL)

- Install **Python 3** and ensure `python`/`python3` is on PATH.
- Install **Git for Windows** (includes Git Bash).
- Install **Icarus Verilog for Windows** and ensure `iverilog` and `vvp` are on PATH.

## Setup

Run from repo root: `NVIDIA-ICLAD25-Hackathon-main` (first `cd` into this folder).

### macOS/Linux/Git Bash

```bash
cd NVIDIA-ICLAD25-Hackathon-main
./setup_local_no_docker.sh
```

### Windows PowerShell (Git Bash recommended for setup script)

```powershell
cd NVIDIA-ICLAD25-Hackathon-main
bash .\setup_local_no_docker.sh
```

The setup script does all of the following:
- creates/reuses `agent_env`
- installs Python dependencies
- relinks all harness `rtl` paths (symlink first, copy fallback)
- initializes `work/learnings.json`


## Problem Execution

Solve 1 problem at a time Iterative loop (Codex-driven)

Features automated retries + failure-context feedback.

Before first run on a new machine, execute `./setup_local_no_docker.sh` from repo root (if not done previously).

### macOS/Linux/Git Bash

```bash
cd NVIDIA-ICLAD25-Hackathon-main
source agent_env/bin/activate
python3 my-agent/agent.py --index <dataset_index> --max-retries <1-17>
```

### Windows PowerShell

```powershell
cd NVIDIA-ICLAD25-Hackathon-main
.\agent_env\Scripts\Activate.ps1
python my-agent/agent.py --index <dataset_index> --max-retries <1-17>
```

Command options:

- Index (required): `-i <dataset_index>` or `--index <dataset_index>`
- Retries (optional): `-r <N>` or `--max-retries <N>`
- Default retries: `8`
- Maximum retries: `17`

Examples:

```bash
python3 my-agent/agent.py -i 1  # default retries (8) are used
python3 my-agent/agent.py --index 1 --max-retries 12
python3 my-agent/agent.py -i 1 -r 17  # 17 is the maximum retry limit
```

Behavior summary:

- Resolves dataset entry by index.
- Runs Codex solve attempts (up to configured retry limit).
- Runs local eval between attempts.
- On failure, feeds `prompt.json`, `rundir/sim.log`, and `rundir/agent_report.json` context into next attempt.
- On completion, runs single-target batch reporting for that harness.

## Key Output Artifacts

After local batch flow, the following are produced under `work/`:

- `work/result.json`
- `work/raw_result.json`
- `work/report.json`
- `work/report.txt`
- `work/run.log` (full terminal/session output from `python3 my-agent/agent.py ...`; overwritten each new run)

Per-harness runtime artifacts are under each harness `rundir/` folder, including:

- `sim.log`
- `agent_report.json`

## RTL Editing Rules (Important)

For local no-Docker flow:

- Edit only staged RTL in:
  - `my-agent/agent_files/<problem_name>/rtl/`
- Do **not** modify:
  - `before/rtl` originals
- Preserve module names, ports, and expected file paths unless explicitly required.

## Troubleshooting

### `Missing Python deps in current environment`

Activate the virtual environment first, then verify:

```bash
python3 -c "import pytest, cocotb, cocotb_tools.runner"
```

Windows PowerShell equivalent:

```powershell
python -c "import pytest, cocotb, cocotb_tools.runner"
```

### `Missing tool: iverilog` or `vvp`

Install Icarus Verilog and confirm both executables are on PATH.

- macOS:

```bash
brew install icarus-verilog
```

- Linux (Ubuntu/Debian):

```bash
sudo apt-get update
sudo apt-get install -y iverilog
```

- Windows PowerShell (with winget):

```powershell
winget search iverilog
winget install IcarusVerilog.IcarusVerilog
```

If `winget` package ID differs on your machine, install from the official Icarus Verilog Windows installer and then reopen terminal.

Verify install:

```bash
iverilog -V
vvp -V
```

### `run.log` file

- `work/run.log` contains full terminal output for each `agent.py` run and is overwritten on the next run.
- If a run fails before execution starts with a `run.log`/lock message, close `work/run.log` in any editor/viewer and retry.
- If Codex does not respond within 8 minutes, `agent.py` times out that attempt, applies a short backoff, and quits with a clear Codex timeout message.
- For detailed diagnostics, inspect the entire `run.log` file and check for any errors


### Invoking `Codex` via agent.py

- If getting permision error, `Codex` cannot write to the directory, then close terminal
- Open a new terminal, just type `codex`, give the approval and then Ctrl + C
- Now run the virtual env command followed by the python run agent command to get the results
