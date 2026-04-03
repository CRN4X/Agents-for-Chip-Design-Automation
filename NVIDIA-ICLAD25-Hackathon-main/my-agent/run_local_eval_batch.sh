#!/bin/sh
set -eu

# Batch local eval for all harness problems (no Docker)
# Usage:
#   ./run_local_eval_batch.sh
#   ./run_local_eval_batch.sh /abs/path/to/repo
#   ./run_local_eval_batch.sh /abs/path/to/repo --limit 5
#   ./run_local_eval_batch.sh /abs/path/to/repo --harness /abs/path/to/work/<problem>/harness/<id>

REPO_ROOT="${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
LIMIT=0
TARGET_HARNESS=""
if [ $# -gt 0 ]; then
  shift
fi
while [ $# -gt 0 ]; do
  case "$1" in
    --limit)
      LIMIT="${2:-0}"
      shift 2
      ;;
    --harness)
      TARGET_HARNESS="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [repo_root] [--limit N] [--harness /abs/path/to/harness]"
      exit 1
      ;;
  esac
done
MY_AGENT_DIR="$REPO_ROOT/my-agent"
WORK_DIR="$REPO_ROOT/work"

if [ ! -d "$MY_AGENT_DIR" ] || [ ! -d "$WORK_DIR" ]; then
  echo "Invalid repo root: $REPO_ROOT"
  exit 1
fi

OUT_DIR="$MY_AGENT_DIR/batch_reports"
mkdir -p "$OUT_DIR"
TS=$(date +%Y%m%d_%H%M%S)
CSV="$OUT_DIR/local_eval_summary_$TS.csv"
LOG="$OUT_DIR/local_eval_batch_$TS.log"

if [ -n "$TARGET_HARNESS" ]; then
  TARGET_HARNESS=$(cd "$TARGET_HARNESS" && pwd)
fi

echo "problem,issue_id,harness_path,exit_code,status,duration_sec,first_error" > "$CSV"

echo "Batch run started at $(date)" | tee "$LOG"
echo "Repo root: $REPO_ROOT" | tee -a "$LOG"
if [ -n "$TARGET_HARNESS" ]; then
  echo "Target harness filter: $TARGET_HARNESS" | tee -a "$LOG"
fi

HARNESS_LIST=$(mktemp)
find "$WORK_DIR" -type f -name prompt.json > "$HARNESS_LIST"
while IFS= read -r prompt_file; do
  harness_path=$(cd "$(dirname "$prompt_file")" && pwd)
  if [ ! -f "$harness_path/src/test_runner.py" ]; then
    continue
  fi
  if [ -n "$TARGET_HARNESS" ] && [ "$harness_path" != "$TARGET_HARNESS" ]; then
    continue
  fi

  problem=$(echo "$harness_path" | awk -F'/work/' '{print $2}' | awk -F'/' '{print $1}')
  issue_id=$(basename "$harness_path")

  echo "\n=== Running $problem / $issue_id ===" | tee -a "$LOG"

  t_start=$(date +%s)
  set +e
  run_out=$(cd "$MY_AGENT_DIR" && ./run_local_eval.sh "$harness_path" 2>&1)
  rc=$?
  set -e
  t_end=$(date +%s)
  duration_sec=$((t_end - t_start))

  printf "%s\n" "$run_out" >> "$LOG"

  status="PASS"
  [ "$rc" -ne 0 ] && status="FAIL"

  sim_log="$harness_path/rundir/sim.log"
  first_error=""
  if [ -f "$sim_log" ]; then
    first_error=$(grep -m1 -E "error:|FAILED|AssertionError|Traceback" "$sim_log" || true)
  fi
  if [ -z "$first_error" ]; then
    first_error=$(printf "%s\n" "$run_out" | grep -m1 -E "FAILED|error|Traceback|No module named" || true)
  fi

  esc_error=$(printf '%s' "$first_error" | tr '\n' ' ' | sed 's/"/""/g')
  echo "$problem,$issue_id,$harness_path,$rc,$status,$duration_sec,\"$esc_error\"" >> "$CSV"

  echo "Result: $status (exit=$rc)" | tee -a "$LOG"
  if [ -n "$first_error" ]; then
    echo "First error: $first_error" | tee -a "$LOG"
  fi

  if [ "$LIMIT" -gt 0 ]; then
    LIMIT=$((LIMIT - 1))
    if [ "$LIMIT" -eq 0 ]; then
      break
    fi
  fi
done < "$HARNESS_LIST"
rm -f "$HARNESS_LIST"

if [ -n "$TARGET_HARNESS" ] && [ "$(wc -l < "$CSV")" -le 1 ]; then
  echo "No matching harness executed for --harness $TARGET_HARNESS" | tee -a "$LOG"
  exit 1
fi

# Generate Docker-like benchmark artifacts from the local batch run:
# - work/result.json
# - work/raw_result.json
# - work/report.json (+ report.txt via reporter)
python3 - "$REPO_ROOT" "$CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
csv_path = Path(sys.argv[2])
sys.path.insert(0, str(repo_root))
work_dir = repo_root / "work"
dataset_path = repo_root / "dataset" / "hackathon-agentic-obfuscated_final_corrected.jsonl"
result_path = work_dir / "result.json"
raw_result_path = work_dir / "raw_result.json"

rows = []
with csv_path.open(newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        rows.append(row)

# Build category/difficulty lookup from dataset IDs.
id_to_meta = {}
probnum_to_meta = {}
if dataset_path.exists():
    with dataset_path.open(encoding="utf-8") as f:
        for line in f:
            obj = json.loads(line)
            rid = obj.get("id", "")
            cats = obj.get("categories", [])
            cid = None
            diff = None
            for c in cats:
                if isinstance(c, str) and c.startswith("cid"):
                    cid = c
                elif c in ("easy", "medium", "hard"):
                    diff = c
            if not (cid and diff and "_" in rid):
                continue
            id_to_meta[rid] = (cid, diff)
            problem, issue = rid.rsplit("_", 1)
            try:
                probnum_to_meta[(problem, int(issue))] = (cid, diff)
            except ValueError:
                pass

# Keep benchmark metadata shape stable for non-dataset edge cases.
old_raw = {}
if raw_result_path.exists():
    try:
        old_raw = json.loads(raw_result_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        old_raw = {}

results = []
raw_logs = {}
for row in rows:
    problem = row.get("problem", "")
    issue_id = str(row.get("issue_id", ""))
    harness_path = row.get("harness_path", "")
    status = (row.get("status") or "").upper()
    exit_code = int(row.get("exit_code") or 1)
    duration = float(row.get("duration_sec") or 0.0)
    first_error = row.get("first_error", "")

    key = f"{problem}_{issue_id}"

    meta = id_to_meta.get(key)
    if meta is None:
        try:
            meta = probnum_to_meta.get((problem, int(issue_id)))
        except ValueError:
            meta = None
    if meta is None and key in old_raw:
        cat = old_raw[key].get("category")
        diff = old_raw[key].get("difficulty")
        if cat and diff:
            meta = (cat, diff)
    if meta is None:
        meta = ("cid000", "medium")
    cid, diff = meta

    sim_log = str(Path(harness_path) / "rundir" / "sim.log") if harness_path else ""
    is_pass = status == "PASS" and exit_code == 0
    result_code = 0 if is_pass else 1

    results.append(
        {
            "problem": problem,
            "issue_id": issue_id,
            "harness_path": harness_path,
            "status": "PASS" if is_pass else "FAIL",
            "exit_code": 0 if is_pass else exit_code,
            "first_error": first_error,
        }
    )

    raw_logs[key] = {
        "category": cid,
        "difficulty": diff,
        "tests": [
            {
                "result": result_code,
                "log": sim_log,
                "error_msg": None if is_pass else first_error,
                "execution": duration,
                "pid": 0,
            }
        ],
        "errors": 0 if is_pass else 1,
    }

result_obj = {
    "source_csv": str(csv_path),
    "count": len(results),
    "results": results,
}
result_path.write_text(json.dumps(result_obj, indent=2) + "\n", encoding="utf-8")
raw_result_path.write_text(json.dumps(raw_logs, indent=2) + "\n", encoding="utf-8")

from src import report  # noqa: E402

rpt = report.Report(
    raw_logs,
    prefix=str(work_dir),
    dataset_path="./dataset/hackathon-agentic-obfuscated_final_corrected.jsonl",
    golden_mode=False,
    disable_patch=False,
    model_agent="my-hw-agent",
    force_agentic=False,
    force_agentic_include_golden=False,
    force_agentic_include_harness=False,
    force_copilot=False,
    copilot_refine=None,
)
rpt.report_categories()
print(f"Wrote {result_path}")
print(f"Wrote {raw_result_path}")
print(f"Wrote {work_dir / 'report.json'}")
PY

echo "\nBatch complete." | tee -a "$LOG"
echo "Summary CSV: $CSV" | tee -a "$LOG"
echo "Full log: $LOG" | tee -a "$LOG"
echo "Benchmark artifacts: $WORK_DIR/result.json, $WORK_DIR/raw_result.json, $WORK_DIR/report.json" | tee -a "$LOG"
