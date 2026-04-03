#!/usr/bin/env python3
"""Iteratively build and run benchmark with capped retries."""

import argparse
import json
import subprocess
import sys
from pathlib import Path


def run_cmd(cmd, cwd):
    print(f"\n$ {' '.join(cmd)}")
    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=1,
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        print(line, end="")
    return proc.wait()


def load_json(path):
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def extract_test_status(report_json, target_id=None):
    if not report_json:
        return None
    details = report_json.get("test_details", {})
    passing = details.get("passing_tests", [])
    failing = details.get("failing_tests", [])

    if target_id:
        for t in passing:
            if t.get("test_id") == target_id:
                return {"passed": True, "entry": t}
        for t in failing:
            if t.get("test_id") == target_id:
                return {"passed": False, "entry": t}
        return None

    if failing:
        return {"passed": False, "entry": failing[0]}
    if passing:
        return {"passed": True, "entry": passing[0]}
    return None


def tail_file(path, lines=40):
    p = Path(path)
    if not p.exists():
        return f"[missing] {path}"
    content = p.read_text(encoding="utf-8", errors="ignore").splitlines()
    return "\n".join(content[-lines:])


def issue_num_from_test_id(test_id):
    parts = test_id.split("_")
    return parts[-1] if parts else None


def wire_nvidia_logs_to_next_attempt(entry, harness_tail, agent_tail, attempt):
    """Bridge NVIDIA logs into mounted rundir for next attempt's agent context."""
    log_path = entry.get("log")
    test_id = entry.get("test_id", "")
    if not log_path:
        return

    p = Path(log_path)
    if len(p.parents) < 2:
        return

    problem_dir = p.parents[1]  # .../work/<problem>
    issue_num = issue_num_from_test_id(test_id)
    if not issue_num:
        return

    rundir = problem_dir / "harness" / issue_num / "rundir"
    rundir.mkdir(parents=True, exist_ok=True)
    out_file = rundir / "nvidia_logs_context.txt"
    payload = [
        f"attempt={attempt}",
        f"test_id={test_id}",
        "=== harness_report_tail ===",
        harness_tail,
        "=== agent_report_tail ===",
        agent_tail,
    ]
    out_file.write_text("\n".join(payload) + "\n", encoding="utf-8")
    print(f"Wired NVIDIA logs for next attempt: {out_file}")


def main():
    parser = argparse.ArgumentParser(description="Loop benchmark runs with auto stop.")
    parser.add_argument("--repo", default="..", help="Path to benchmark repo root")
    parser.add_argument("--dataset", default="./dataset/hackathon-agentic-obfuscated_final_corrected.jsonl")
    parser.add_argument("--agent", default="my-hw-agent")
    parser.add_argument("--id", dest="issue_id", default=None)
    parser.add_argument("--max-attempts", type=int, default=8)
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    agent_dir = repo / "my-agent"
    report_path = repo / "work" / "report.json"

    for attempt in range(1, args.max_attempts + 1):
        print(f"\n========== Attempt {attempt}/{args.max_attempts} ==========")

        rc = run_cmd(["./build_agent.sh"], cwd=agent_dir)
        if rc != 0:
            print(f"Build failed on attempt {attempt}.")
            print("I give up.")
            return 1

        prev_report_mtime = report_path.stat().st_mtime if report_path.exists() else None

        cmd = [
            sys.executable,
            "run_benchmark.py",
            "-f",
            args.dataset,
            "-l",
            "-g",
            args.agent,
        ]
        if args.issue_id:
            cmd += ["-i", args.issue_id]

        rc = run_cmd(cmd, cwd=repo)
        new_report_mtime = report_path.stat().st_mtime if report_path.exists() else None
        report_updated = (
            new_report_mtime is not None and
            (prev_report_mtime is None or new_report_mtime > prev_report_mtime)
        )
        if rc != 0 and not report_updated:
            print(f"Benchmark command failed on attempt {attempt} before report generation.")
            continue

        report_json = load_json(report_path)
        status = extract_test_status(report_json, args.issue_id)
        if not status:
            print("Could not parse status from report.json; continuing.")
            continue

        entry = status["entry"]
        log_path = entry.get("log")
        print(f"Status: {'PASS' if status['passed'] else 'FAIL'}")
        if log_path:
            print("\n--- Harness log tail ---")
            harness_tail = tail_file(log_path, lines=60)
            print(harness_tail)
            agent_log = str(log_path).replace(".txt", "_agent.txt")
            print("\n--- Agent log tail ---")
            agent_tail = tail_file(agent_log, lines=60)
            print(agent_tail)
            if not status["passed"]:
                wire_nvidia_logs_to_next_attempt(entry, harness_tail, agent_tail, attempt)

        if status["passed"]:
            print("\nSolved before max attempts.")
            return 0

    print(f"\nReached max attempts ({args.max_attempts}). I give up.")
    return 2


if __name__ == "__main__":
    sys.exit(main())
