#!/bin/sh
set -eu

# One-shot local flow (no Docker):
# 1) Run agent locally
# 2) Point harness rtl to staged agent_files rtl
# 3) Run local cocotb/pytest harness
#
# Usage:
#   ./run_local_eval.sh /abs/path/to/work/<problem>/harness/<id>

HARNESS_PATH="${1:-}"
if [ -z "$HARNESS_PATH" ]; then
  echo "Usage: $0 /abs/path/to/work/<problem>/harness/<id>"
  exit 1
fi

# Normalize to absolute path to avoid pytest path issues after cd.
HARNESS_PATH=$(cd "$HARNESS_PATH" && pwd)

if [ ! -d "$HARNESS_PATH" ]; then
  echo "Harness path does not exist: $HARNESS_PATH"
  exit 1
fi

if [ ! -f "$HARNESS_PATH/prompt.json" ] || [ ! -d "$HARNESS_PATH/src" ]; then
  echo "Invalid harness folder (missing prompt.json or src/): $HARNESS_PATH"
  exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Pre-check local toolchain
if ! command -v iverilog >/dev/null 2>&1; then
  echo "Missing tool: iverilog (install via Homebrew: brew install icarus-verilog)"
  exit 1
fi
if ! command -v vvp >/dev/null 2>&1; then
  echo "Missing tool: vvp (comes with icarus-verilog)"
  exit 1
fi
if ! python3 -c "import pytest, cocotb, cocotb_tools.runner" >/dev/null 2>&1; then
  echo "Missing Python deps in current environment."
  echo "Activate venv and run: pip install -r requirements.txt"
  exit 1
fi

# Step 1: run local agent (creates/updates staged files in my-agent/agent_files/...)
"$SCRIPT_DIR/run_local_agent.sh" "$HARNESS_PATH"

# Step 2: point harness rtl -> staged rtl
"$SCRIPT_DIR/link_harness_rtl_to_staged.sh" "$HARNESS_PATH"

ENV_FILE="$HARNESS_PATH/src/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE"
  exit 1
fi

# Parse .env lines like: KEY = value
read_env_val() {
  key="$1"
  val=$(awk -F'=' -v k="$key" '
    $0 ~ /^[[:space:]]*#/ {next}
    NF >= 2 {
      lhs=$1; rhs=$0; sub(/^[^=]*=/, "", rhs)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", lhs)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", rhs)
      if (lhs == k) { print rhs; exit }
    }
  ' "$ENV_FILE")
  printf "%s" "$val"
}

VERILOG_SOURCES_RAW=$(read_env_val "VERILOG_SOURCES")
TOPLEVEL=$(read_env_val "TOPLEVEL")
MODULE=$(read_env_val "MODULE")
SIM=$(read_env_val "SIM")
TOPLEVEL_LANG=$(read_env_val "TOPLEVEL_LANG")
WAVE=$(read_env_val "WAVE")

if [ -z "$VERILOG_SOURCES_RAW" ] || [ -z "$TOPLEVEL" ] || [ -z "$MODULE" ]; then
  echo "Missing required variables in $ENV_FILE (VERILOG_SOURCES/TOPLEVEL/MODULE)."
  exit 1
fi

# Remap container paths -> local harness paths
VERILOG_SOURCES=$(printf "%s" "$VERILOG_SOURCES_RAW" | \
  sed "s#/code/rtl#$HARNESS_PATH/rtl#g" | \
  sed "s#/code/verif#$HARNESS_PATH/verif#g" | \
  sed "s#/code/src#$HARNESS_PATH/src#g")

export VERILOG_SOURCES
export TOPLEVEL
export MODULE
export SIM="${SIM:-icarus}"
export TOPLEVEL_LANG="${TOPLEVEL_LANG:-verilog}"
export WAVE="${WAVE:-true}"
export PYTHONPATH="$HARNESS_PATH/src${PYTHONPATH:+:$PYTHONPATH}"

mkdir -p "$HARNESS_PATH/rundir/harness/.cache"

echo "Running local harness eval"
echo "  HARNESS_PATH=$HARNESS_PATH"
echo "  TOPLEVEL=$TOPLEVEL"
echo "  MODULE=$MODULE"
echo "  SIM=$SIM"
echo "  VERILOG_SOURCES=$VERILOG_SOURCES"

cd "$HARNESS_PATH/rundir"
python3 -m pytest "$HARNESS_PATH/src/test_runner.py" -s -v -o cache_dir="$HARNESS_PATH/rundir/harness/.cache"
