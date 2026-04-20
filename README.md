# NVIDIA CVDP Problem Set

This repository evaluates agentic RTL debugging/generation workflows on harnessed verification tasks.

## Prerequisites

- `python 3.12`
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

## Setup Instructions

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


## Problem Execution Commands

Solve 1 problem at a time in an iterative loop fashion (Codex-driven)

Features automated retries + failure-context feedback.

Before first run (if not done previously), execute `./setup_local_no_docker.sh` from repo root.

### macOS/Linux/Git Bash

```bash
cd NVIDIA-ICLAD25-Hackathon-main
source agent_env/bin/activate
python3 my-agent/agent.py --index <dataset_index_starts_from_1> --max-retries <1-17>
```

### Windows PowerShell

```powershell
cd NVIDIA-ICLAD25-Hackathon-main
.\agent_env\Scripts\Activate.ps1
python my-agent/agent.py --index <dataset_index_starts_from_1> --max-retries <1-17>
```

Command options:

- Index (required): `-i <dataset_index_starts_from_1>` or `--index <dataset_index_starts_from_1>`
- Index value starts from 1, which indicates first line in the jsnol file
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

## Input Description

- Dataset input file: `dataset/hackathon-agentic-obfuscated_final_corrected.jsonl`
- CLI input selects one dataset row: `--index/-i <N>` (problem index starts with 1)
- The selected row resolves to one harness folder: `work/<problem_name>/harness/<id>/`
- Main harness inputs used in each run:
  - `prompt.json` (problem/spec details passed to Codex)
  - `src/` and `verif/` (testbench and verification logic)
  - `src/.env` (TOPLEVEL, MODULE, VERILOG_SOURCES and sim settings)
  - `rtl/` (harness RTL path linked/copied to staged RTL workspace)

## Output Description

- Location of Updated Verilog Files: 
  - `/NVIDIA-ICLAD25-Hackathon-main/my-agent/agent_files/<problem_name>/<issue_id>/rtl/`: location of the verilog file(s) modified by the AI agent.
- Benchmark/report artifacts in `work/`:
  - `work/result.json`: summarized pass/fail results for evaluated targets in a compact machine-readable format.
  - `work/raw_result.json`: detailed per-run raw benchmark output (more granular execution data).
  - `work/report.json`: structured final report data intended for downstream reporting/analysis tools.
  - `work/report.txt`: human-readable text report with the benchmark summary.
- Learning memory output:
  - `work/learnings.json` (updated from InfoAgent category + one-line learning)
- Run logs:
  - `work/run.log` (full terminal/session log, overwritten each run)
  - `work/logs/run_<unix_timestamp>__<index>.log` (only when `--save_log/-s` is used)
- Per-harness runtime + feedback artifacts (used for next-attempt context):
  - `work/<problem_name>/harness/<id>/rundir/sim.log`
  - `work/<problem_name>/harness/<id>/rundir/agent_report.json`

## Expected Results (for Verification)

Successful verification means all of the following are true:
- Local eval command exits with code `0`
- Pytest/Cocotb summary shows all tests passed (no `FAIL`)
- Harness simulation log has no compile/elaboration/assertion failure
- Benchmark/report artifacts are refreshed under `work/`

Verification is considered failed if any of the following occurs:
- Local eval exits with non-zero code
- Any Cocotb/Pytest test fails, times out, or raises assertion errors
- `iverilog`/`vvp` compile or elaboration errors appear in `sim.log`

When verification fails, check logs in this order:
1. `work/run.log` for full pipeline context
2. `work/<problem_name>/harness/<id>/rundir/sim.log` for first simulation error
3. `work/<problem_name>/harness/<id>/rundir/agent_report.json` for agent-side notes
4. `work/logs/run_<unix_timestamp>__<index>.log` if `--save_log/-s` was used

Note: warnings (for example deprecation warnings) may appear during successful runs; pass/fail is determined by test summary and exit code.

## Brief Workflow Description

1. Run setup once, then run `python3 my-agent/agent.py -i <index>` (and optional flags).
2. The agent reads the selected row from the dataset JSONL and resolves the matching harness folder.
3. Codex receives prompt/context and updates only staged RTL under `my-agent/agent_files/<problem_name>/<issue_id>/rtl/`.
4. Local evaluation runs with Pytest + Cocotb using Icarus Verilog (`iverilog`/`vvp`).
5. If evaluation fails, failure context (`prompt.json`, `rundir/sim.log`, `rundir/agent_report.json`) is fed into the next attempt.
6. Retries continue until pass or retry/cycle limits are reached.
7. On completion, benchmark/report artifacts are refreshed in `work/`, and logs/learnings are updated.

## How To Add Hidden Test Cases

1. Add a new JSONL entry in:
- `dataset/hackathon-agentic-obfuscated_final_corrected.jsonl`

Example:
```json
{
  "id": "cvdp_agentic_demo_problem_1001",
  "categories": ["cid999", "medium"],
  "system_message": "You are an RTL fixing agent.",
  "prompt": "Debug/fix the target RTL module to satisfy the harness testbench."
}
```
`id` format must be `<problem_folder_name>_<harness_id>` and must map to:
- `work/<problem_folder_name>/harness/<harness_id>/`

2. Create/update the matching harness folder:
- `work/cvdp_agentic_demo_problem/harness/1001/`

3. Add harness verification inputs:
- Target harness path: `work/cvdp_agentic_demo_problem/harness/1001/`
- Add hidden test files in `src/` (file name must match `test_*.py` for pytest auto-discovery):
  - `work/cvdp_agentic_demo_problem/harness/1001/src/test_hidden_case1.py`
  - `work/cvdp_agentic_demo_problem/harness/1001/src/test_hidden_case2.py` (optional)
- Add optional helper files in `verif/` (if tests need support assets):
  - `work/cvdp_agentic_demo_problem/harness/1001/verif/reference_model.py`
  - `work/cvdp_agentic_demo_problem/harness/1001/verif/test_vectors.json`
  - `work/cvdp_agentic_demo_problem/harness/1001/verif/golden_outputs.csv`
  - `work/cvdp_agentic_demo_problem/harness/1001/verif/scoreboard_utils.py`
- Set simulation config in `src/.env`:
  - `work/cvdp_agentic_demo_problem/harness/1001/src/.env`

Example `.env`:
```env
VERILOG_SOURCES = /code/rtl/my_module.sv
TOPLEVEL        = my_module
MODULE          = test_hidden_case1
SIM             = icarus
TOPLEVEL_LANG   = verilog
PYTHONPATH      = /src
WAVE            = true
```

4. Run the new case by index:
```bash
python3 my-agent/agent.py -i <new_index>
```

5. Check verification outputs:
- `work/run.log`: full run trace (agent attempts, eval calls, command output, high-level errors).
- `work/<problem_folder_name>/harness/<harness_id>/rundir/sim.log`: simulator/test-level failures (compile, elaboration, runtime, assertions).
- `work/result.json`: structured final run status summary.
- `work/report.json`: report-format benchmark/result summary.


## Architeture Block Diagram

  ```mermaid

  flowchart TD
      A["User CLI<br/>python3 my-agent/agent.py --index N --max-retries R"] --> B["Main Controller<br/>NVIDIA-ICLAD25-Hackathon-main/my-agent/agent.py"]

      subgraph INPUT["Task Selection"]
          C["Read Dataset Row<br/>dataset/hackathon-agentic-obfuscated_final_corrected.jsonl"]
          D["Resolve Harness Path<br/>work/problem_name/harness/id/"]
          C --> D
      end

      B --> C
      B --> L1["Write Run Logs<br/>work/run.log"]

      subgraph PLAN["Planner and Role Routing"]
          E["Load Planning Policy<br/>my-agent/AGENTS.md"]
          F["HeadAgent<br/>Classify and Route"]
          G["InfoAgent<br/>Category + one-line learning JSON"]
          H1["FixRTL"]
          H2["SpecRTL"]
          H3["CompleteRTL"]
          H4["IntegrateRTL"]
          E --> F
          F --> G
          F --> H1
          F --> H2
          F --> H3
          F --> H4
          G --> M1["Update Learning Memory<br/>work/learnings.json"]
      end

      D --> E

      subgraph EXEC["Executor: Codex + Staged RTL"]
          I["Run codex exec<br/>from agent.py"]
          J["Edit Only Staged RTL<br/>my-agent/agent_files/problem_name/issue_id/rtl/"]
          K["Keep before/rtl Unmodified<br/>Harness rtl linked/copied to staged RTL"]
          I --> J --> K
      end

      H1 --> I
      H2 --> I
      H3 --> I
      H4 --> I

      subgraph EVAL["Evaluation Layer (Automated)"]
          N["run_local_eval.sh<br/>my-agent/run_local_eval.sh"]
          O["Tool and Dependency Checks<br/>iverilog, vvp, pytest, cocotb"]
          P["Relink Harness RTL<br/>my-agent/link_harness_rtl_to_staged.sh"]
          Q["Run Test Runner<br/>work/problem_name/harness/id/src/test_runner.py"]
          R["Debug Artifact<br/>work/problem_name/harness/id/rundir/sim.log"]
          N --> O --> P --> Q --> R
      end

      K --> N

      S{"Eval PASS?"}
      Q --> S

      subgraph FB["Feedback Loop (Core Agentic)"]
          T["Extract Failure Context in agent.py<br/>first error from sim.log<br/>eval output tail<br/>rundir/agent_report.json tail"]
          U["Inject Failure Context<br/>into next attempt prompt"]
          T --> U
      end

      S -- No --> T
      U --> I

      subgraph REPORT["Reporting Layer"]
          V["run_local_eval_batch.sh --harness path<br/>my-agent/run_local_eval_batch.sh"]
          W1["work/result.json"]
          W2["work/raw_result.json"]
          W3["work/report.json"]
          W4["work/report.txt"]
          V --> W1
          V --> W2
          V --> W3
          V --> W4
      end

      S -- Yes --> V
      S -- Retry Exhausted --> V

  ```


## Troubleshooting (if necessary)

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
- If Codex does not respond within 20 minutes, `agent.py` times out that attempt, applies a short backoff, and continues to the next new attempt.
- For detailed diagnostics, inspect the entire `run.log` file and check for any errors


### Invoking `Codex` via agent.py

- If getting permision error, `Codex` cannot write to the directory, then close terminal
- Open a new terminal, just type `codex`, give the approval and then Ctrl + C
- Now run the virtual env command followed by the python run agent command to get the results
