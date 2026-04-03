#!/bin/sh
set -eu

# Point harness rtl/ to staged agent_files/<problem>/rtl copy.
# Usage:
#   ./link_harness_rtl_to_staged.sh /abs/path/to/work/<problem>/harness/<id>
#   ./link_harness_rtl_to_staged.sh --restore /abs/path/to/work/<problem>/harness/<id>

restore_mode=0
if [ "${1:-}" = "--restore" ]; then
  restore_mode=1
  shift
fi

HARNESS_PATH="${1:-}"
if [ -z "$HARNESS_PATH" ]; then
  echo "Usage: $0 [--restore] /abs/path/to/harness/<id>"
  exit 1
fi

if [ ! -d "$HARNESS_PATH" ]; then
  echo "Harness path does not exist: $HARNESS_PATH"
  exit 1
fi

RTL_PATH="$HARNESS_PATH/rtl"
RTL_BACKUP_PATH="$HARNESS_PATH/rtl.orig"

if [ "$restore_mode" -eq 1 ]; then
  if [ -L "$RTL_PATH" ]; then
    rm "$RTL_PATH"
  fi
  if [ -d "$RTL_BACKUP_PATH" ]; then
    mv "$RTL_BACKUP_PATH" "$RTL_PATH"
    echo "Restored original harness rtl from: $RTL_BACKUP_PATH"
  else
    echo "No backup found at: $RTL_BACKUP_PATH"
    exit 1
  fi
  exit 0
fi

PROBLEM_NAME=$(echo "$HARNESS_PATH" | awk -F'/work/' '{print $2}' | awk -F'/' '{print $1}')
if [ -z "$PROBLEM_NAME" ]; then
  echo "Could not infer problem name from harness path: $HARNESS_PATH"
  exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STAGED_RTL_PATH="$SCRIPT_DIR/agent_files/$PROBLEM_NAME/rtl"

if [ ! -d "$STAGED_RTL_PATH" ]; then
  echo "Staged RTL path not found: $STAGED_RTL_PATH"
  echo "Run the agent once first to generate staged files."
  exit 1
fi

if [ -L "$RTL_PATH" ]; then
  rm "$RTL_PATH"
elif [ -d "$RTL_PATH" ]; then
  if [ ! -d "$RTL_BACKUP_PATH" ]; then
    mv "$RTL_PATH" "$RTL_BACKUP_PATH"
  else
    rm -rf "$RTL_PATH"
  fi
fi

ln -s "$STAGED_RTL_PATH" "$RTL_PATH"

echo "Harness rtl now points to staged rtl:"
echo "  $RTL_PATH -> $STAGED_RTL_PATH"
