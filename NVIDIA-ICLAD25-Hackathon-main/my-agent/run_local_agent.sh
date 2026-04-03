#!/bin/sh
set -eu

# Usage:
#   ./run_local_agent.sh /path/to/harness/<issue_num>
# If no path is provided, current directory is used.

WORKSPACE_PATH="${1:-$(pwd)}"

if [ ! -d "$WORKSPACE_PATH" ]; then
  echo "Workspace does not exist: $WORKSPACE_PATH"
  exit 1
fi

if [ ! -f "$WORKSPACE_PATH/prompt.json" ]; then
  echo "Missing prompt.json in: $WORKSPACE_PATH"
  exit 1
fi

if [ ! -d "$WORKSPACE_PATH/rtl" ]; then
  echo "Missing rtl/ directory in: $WORKSPACE_PATH"
  exit 1
fi

export CVDP_WORKSPACE_ROOT="$WORKSPACE_PATH"

echo "Running agent locally with workspace: $CVDP_WORKSPACE_ROOT"
python3 "$(dirname "$0")/agent.py"
