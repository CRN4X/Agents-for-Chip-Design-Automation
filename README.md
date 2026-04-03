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

Run from repo root.

### macOS/Linux/Git Bash

```bash
python3 -m venv agent_env
source agent_env/bin/activate
python3 -m pip install -r requirements.txt
```

### Windows PowerShell

```powershell
python -m venv agent_env
.\agent_env\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

## Quick Start

Iterative solve loop for one harness (Codex-driven)

Use this when you want automated retries + failure-context feedback.

#### macOS/Linux/Git Bash

```bash
source agent_env/bin/activate
python3 my-agent/agent.py --<dataset_index>
```

#### Windows PowerShell

```powershell
.\agent_env\Scripts\Activate.ps1
python my-agent/agent.py --<dataset_index>
```

Examples:

```text
--1
--index 1
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

Install Icarus Verilog and ensure both executables are available on PATH.
