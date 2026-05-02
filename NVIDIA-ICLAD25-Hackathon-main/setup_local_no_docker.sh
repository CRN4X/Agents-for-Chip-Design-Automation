#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "[setup] Repo root: $ROOT_DIR"

if [[ ! -f "$ROOT_DIR/requirements.txt" || ! -d "$ROOT_DIR/my-agent" || ! -d "$ROOT_DIR/work" ]]; then
  echo "[setup] ERROR: This script must run from NVIDIA-ICLAD25-Hackathon-main repo root." >&2
  exit 1
fi

PYTHON_BIN="${PYTHON_BIN:-python3}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "[setup] ERROR: python3 not found in PATH." >&2
  exit 1
fi

ensure_iverilog() {
  if command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
    echo "[setup] Found Icarus Verilog: $(iverilog -V | head -n 1)"
    return 0
  fi

  echo "[setup] Icarus Verilog not found. Attempting install..."

  local uname_s
  uname_s="$(uname -s 2>/dev/null || echo unknown)"

  case "$uname_s" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install icarus-verilog
      else
        echo "[setup] ERROR: Homebrew is not installed. Install brew first, then run: brew install icarus-verilog" >&2
        return 1
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y iverilog
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y iverilog
      elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y iverilog
      elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm iverilog
      elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y iverilog
      else
        echo "[setup] ERROR: No supported package manager found for auto-install." >&2
        echo "[setup] Please install iverilog manually and rerun setup." >&2
        return 1
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      if command -v winget.exe >/dev/null 2>&1; then
        winget.exe install --id IcarusVerilog.IcarusVerilog -e --accept-package-agreements --accept-source-agreements
      elif command -v choco >/dev/null 2>&1; then
        choco install iverilog -y
      else
        echo "[setup] ERROR: Could not auto-install on Windows shell." >&2
        echo "[setup] Install Icarus Verilog manually (or via winget/choco), then rerun setup." >&2
        return 1
      fi
      ;;
    *)
      echo "[setup] ERROR: Unsupported OS for auto-install: $uname_s" >&2
      echo "[setup] Please install Icarus Verilog manually and rerun setup." >&2
      return 1
      ;;
  esac

  if command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
    echo "[setup] Icarus Verilog install complete: $(iverilog -V | head -n 1)"
    return 0
  fi

  echo "[setup] ERROR: Install attempted, but iverilog/vvp still not found in PATH." >&2
  echo "[setup] Open a new terminal (PATH refresh) and rerun setup." >&2
  return 1
}

if ! ensure_iverilog; then
  exit 1
fi

# Run Codex once during setup so first-time users can approve repo access
# immediately and avoid later permission friction.
# Set SKIP_CODEX_BOOTSTRAP=1 to disable this step (for CI or scripted runs).
bootstrap_codex_repo_access() {
  if [[ "${SKIP_CODEX_BOOTSTRAP:-0}" == "1" ]]; then
    echo "[setup] Skipping Codex bootstrap (SKIP_CODEX_BOOTSTRAP=1)."
    return 0
  fi

  if ! command -v codex >/dev/null 2>&1; then
    echo "[setup] Codex CLI not found in PATH. Skipping Codex bootstrap."
    return 0
  fi

  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "[setup] Non-interactive shell detected. Skipping Codex bootstrap."
    echo "[setup] Run 'codex' once from repo root to grant folder access."
    return 0
  fi

  echo "[setup] Launching Codex once so repo access can be approved."
  echo "[setup] Approve access if prompted, then exit Codex to continue setup."
  if ! codex; then
    echo "[setup] WARN: Codex exited with a non-zero status. Continuing setup." >&2
  fi
}

if [[ ! -d "$ROOT_DIR/agent_env" ]]; then
  echo "[setup] Creating virtual environment: agent_env"
  "$PYTHON_BIN" -m venv "$ROOT_DIR/agent_env"
else
  echo "[setup] Reusing existing virtual environment: agent_env"
fi

# shellcheck disable=SC1091
source "$ROOT_DIR/agent_env/bin/activate"

echo "[setup] Installing Python dependencies"
python3 -m pip install -r "$ROOT_DIR/requirements.txt"

if [[ ! -x "$ROOT_DIR/my-agent/link_harness_rtl_to_staged.sh" ]]; then
  echo "[setup] ERROR: missing executable my-agent/link_harness_rtl_to_staged.sh" >&2
  exit 1
fi

echo "[setup] Relinking harness rtl directories (symlink first, copy fallback)"
count_total=0
count_ok=0
count_fail=0
count_skip=0

shopt -s nullglob
for h in "$ROOT_DIR"/work/*/harness/*; do
  [[ -d "$h" ]] || continue
  ((count_total+=1))
  problem_name="$(basename "$(dirname "$(dirname "$h")")")"
  issue_id="$(basename "$h")"
  staged_rtl_issue="$ROOT_DIR/my-agent/agent_files/$problem_name/$issue_id/rtl"
  staged_rtl_legacy="$ROOT_DIR/my-agent/agent_files/$problem_name/rtl"
  if [[ ! -d "$staged_rtl_issue" && ! -d "$staged_rtl_legacy" ]]; then
    ((count_skip+=1))
    continue
  fi
  if "$ROOT_DIR/my-agent/link_harness_rtl_to_staged.sh" "$h" >/dev/null 2>&1; then
    ((count_ok+=1))
  else
    ((count_fail+=1))
    echo "[setup] WARN: failed to relink $h" >&2
  fi
done
shopt -u nullglob

echo "[setup] Initializing work/learnings.json"
if ! python3 "$ROOT_DIR/my-agent/init_learnings.py" >/dev/null 2>&1; then
  echo "[setup] WARN: could not initialize work/learnings.json (file may be open/locked)." >&2
fi

echo "[setup] Relink summary: total=$count_total ok=$count_ok skipped=$count_skip failed=$count_fail"
if [[ "$count_fail" -gt 0 ]]; then
  echo "[setup] ERROR: one or more harness relinks failed. Fix warnings above and rerun." >&2
  exit 2
fi

bootstrap_codex_repo_access

echo "[setup] Complete. Next steps:"
echo "  1) source agent_env/bin/activate"
echo "  2) codex (if not installed, install with -- npm install -g @openai/codex)"
echo "  3) Provide codex permission and exit using Ctrl+C"
echo "  4) python3 my-agent/agent.py -i <dataset_index>"
