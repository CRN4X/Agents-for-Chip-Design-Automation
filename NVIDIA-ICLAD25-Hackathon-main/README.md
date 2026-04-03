# NVIDIA Debug Problem Set

This repository evaluates agentic RTL debugging/generation workflows on harnessed verification tasks.

## Repository Layout

- `dataset/`: benchmark problem metadata (`.jsonl`)
- `work/`: generated harnesses, run artifacts, and reports
- `my-agent/`: your local agent, scripts, staged editable RTL, and batch reports
- `examples/`: example baseline agent assets

## Prerequisites (Local No-Docker Flow)

- macOS/Linux shell
- `python3` available
- Icarus Verilog tools installed:
  - `iverilog`
  - `vvp`

On macOS, you can install Icarus with:

```bash
brew install icarus-verilog
```

## Setup

From repo root:

```bash
python3 -m venv agent_env
source agent_env/bin/activate
python3 -m pip install -r requirements.txt
```

Note: all local eval commands should be run with the virtual environment activated.

## Quick Start

### 1) Run a single harness locally

```bash
source agent_env/bin/activate
./my-agent/run_local_eval.sh <absolute_or_relative_harness_path>
```

Example:

```bash
./my-agent/run_local_eval.sh ./work/<problem_name>/harness/<id>
```

What this does:

1. Runs `my-agent/agent.py` in harness mode.
2. Links harness `rtl/` to staged editable RTL under `my-agent/agent_files/<problem_name>/rtl/`.
3. Runs local cocotb/pytest harness.

### 2) Iterative solve loop for one harness (Codex-driven)

Use this when you want automated retries + failure-context feedback.

```bash
source agent_env/bin/activate
python3 my-agent/agent.py --<dataset_index>
```

Examples:

```bash
python3 my-agent/agent.py --1
python3 my-agent/agent.py --index 1
```

Behavior summary:

- Resolves dataset entry by index.
- Runs Codex solve attempts (up to configured retry limit).
- Runs local eval between attempts.
- On failure, feeds `prompt.json`, `rundir/sim.log`, and `rundir/agent_report.json` context into next attempt.
- On completion, runs single-target batch reporting for that harness.

### 3) Run local batch eval/report

```bash
source agent_env/bin/activate
./my-agent/run_local_eval_batch.sh <repo_root>
```

Optional:

```bash
./my-agent/run_local_eval_batch.sh <repo_root> --limit 5
./my-agent/run_local_eval_batch.sh <repo_root> --harness ./work/<problem_name>/harness/<id>
```

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

Activate the repo virtual environment before running eval:

```bash
source agent_env/bin/activate
```

Then verify:

```bash
python3 -c "import pytest, cocotb, cocotb_tools.runner"
```

### `Missing tool: iverilog` or `vvp`

Install Icarus Verilog and confirm both executables are on `PATH`.

## Notes

- This README documents the current local no-Docker workflow used by `my-agent` scripts.
- If you also use Docker flows, keep Docker-specific docs in `my-agent/` scripts or a separate section to avoid mixing setup paths.
