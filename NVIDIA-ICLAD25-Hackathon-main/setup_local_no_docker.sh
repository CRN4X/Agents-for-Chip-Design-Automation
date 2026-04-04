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

shopt -s nullglob
for h in "$ROOT_DIR"/work/*/harness/*; do
  [[ -d "$h" ]] || continue
  ((count_total+=1))
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

echo "[setup] Relink summary: total=$count_total ok=$count_ok failed=$count_fail"
if [[ "$count_fail" -gt 0 ]]; then
  echo "[setup] ERROR: one or more harness relinks failed. Fix warnings above and rerun." >&2
  exit 2
fi

echo "[setup] Complete. Next steps:"
echo "  1) source agent_env/bin/activate"
echo "  2) python3 my-agent/agent.py -i <dataset_index>"
