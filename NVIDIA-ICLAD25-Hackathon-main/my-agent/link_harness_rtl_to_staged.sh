#!/bin/sh
set -eu

# Point harness rtl/ to staged agent_files/<problem>/<issue>/rtl copy.
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
  elif [ -d "$RTL_PATH" ]; then
    # Handles fallback copy mode.
    rm -rf "$RTL_PATH"
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
ISSUE_ID=$(basename "$HARNESS_PATH")
STAGED_RTL_PATH_ISSUE="$SCRIPT_DIR/agent_files/$PROBLEM_NAME/$ISSUE_ID/rtl"
STAGED_RTL_PATH_LEGACY="$SCRIPT_DIR/agent_files/$PROBLEM_NAME/rtl"
STAGED_RTL_PATH=""

if [ -d "$STAGED_RTL_PATH_ISSUE" ]; then
  STAGED_RTL_PATH="$STAGED_RTL_PATH_ISSUE"
elif [ -d "$STAGED_RTL_PATH_LEGACY" ]; then
  STAGED_RTL_PATH="$STAGED_RTL_PATH_LEGACY"
fi

if [ -z "$STAGED_RTL_PATH" ]; then
  echo "Staged RTL path not found."
  echo "Tried:"
  echo "  $STAGED_RTL_PATH_ISSUE"
  echo "  $STAGED_RTL_PATH_LEGACY"
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

# Preferred path: symlink for speed and direct staged edits.
if ln -s "$STAGED_RTL_PATH" "$RTL_PATH" 2>/dev/null; then
  echo "Harness rtl now points to staged rtl (symlink mode):"
  echo "  $RTL_PATH -> $STAGED_RTL_PATH"
else
  # Fallback for environments where symlink creation is restricted (common on Windows).
  mkdir -p "$RTL_PATH"
  cp -R "$STAGED_RTL_PATH"/. "$RTL_PATH"/
  echo "Harness rtl now mirrors staged rtl (copy fallback mode):"
  echo "  copied: $STAGED_RTL_PATH -> $RTL_PATH"
fi
