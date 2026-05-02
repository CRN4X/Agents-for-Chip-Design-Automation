#!/usr/bin/env python3

# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

"""Codex-driven local solver orchestrator.

Modes:
1) Orchestrator mode: `python3 my-agent/agent.py -i 1`
   - Picks the Nth problem from dataset JSONL
   - Runs Codex CLI + local eval loop (default 8 retries, configurable up to 17)
   - Runs local batch benchmark to refresh result/report artifacts

2) Harness mode (no args): called by run_local_eval.sh
   - No-op agent that only writes a minimal agent_report.json
"""

import json
import os
import re
import subprocess
import sys
import time
import shlex
import shutil
from pathlib import Path
from typing import Dict, List, Optional, TextIO, Tuple
from init_learnings import init_learnings_json

INFO_CATEGORIES = [
    "Modify or Extend Existing RTL",
    "Integrate multiple modules into a top module",
    "Create new RTL from spec",
    "Debug/fix buggy RTL",
]

LEARNING_DIFFICULTIES = ("easy", "medium", "hard")
DEFAULT_LEARNING_DIFFICULTY = "medium"
LEARNING_LINE_CAPS = {
    "easy": 4,
    "medium": 8,
    "hard": 17,
}
CODEX_TIMEOUT_SEC = 1200  # 20 minutes per Codex attempt
CODEX_TIMEOUT_MINUTES = CODEX_TIMEOUT_SEC // 60
CODEX_TIMEOUT_BACKOFF_SEC = 10
MAX_SOLVE_RUN_CYCLES = 2  # If max retries are exhausted, start one fresh run cycle


def _log_timestamp() -> str:
    return time.strftime("%d_%b_%Y_%H_%M_%S").lower()


def log(msg: str) -> None:
    print(f"\n[{_log_timestamp()}] [agent.py] {msg}", flush=True)


def log_codex(msg: str) -> None:
    print(f"\n[{_log_timestamp()}] [codex] {msg}", flush=True)


class TeeStream:
    def __init__(self, console_stream: TextIO, log_stream: TextIO) -> None:
        self.console_stream = console_stream
        self.log_stream = log_stream

    def write(self, data: str) -> int:
        n = self.console_stream.write(data)
        self.log_stream.write(data)
        return n

    def flush(self) -> None:
        self.console_stream.flush()
        self.log_stream.flush()

    def isatty(self) -> bool:
        return bool(getattr(self.console_stream, "isatty", lambda: False)())


def lock_log_file(log_file: TextIO, log_path: Path) -> None:
    if os.name == "nt":
        import msvcrt

        try:
            # Non-blocking lock of first byte while file handle is held.
            msvcrt.locking(log_file.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError as exc:
            raise RuntimeError(
                f"Could not lock {log_path}. It may be open in another application. "
                "Close the file and retry."
            ) from exc
        return

    import fcntl

    try:
        fcntl.flock(log_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as exc:
        raise RuntimeError(
            f"Could not lock {log_path}. It may be open in another application. "
            "Close the file and retry."
        ) from exc


def start_run_log(repo_root: Path) -> Tuple[TextIO, TextIO, TextIO]:
    work_dir = repo_root / "work"
    log_path = work_dir / "run.log"
    try:
        work_dir.mkdir(parents=True, exist_ok=True)
        log_file = log_path.open("w", encoding="utf-8")
    except OSError as exc:
        raise RuntimeError(
            f"Could not open {log_path} for writing. Check folder permissions and retry."
        ) from exc

    try:
        lock_log_file(log_file, log_path)
    except RuntimeError:
        log_file.close()
        raise

    orig_stdout = sys.stdout
    orig_stderr = sys.stderr
    sys.stdout = TeeStream(orig_stdout, log_file)
    sys.stderr = TeeStream(orig_stderr, log_file)
    log(f"Logging terminal output to: {log_path}")
    return log_file, orig_stdout, orig_stderr


def stop_run_log(log_file: TextIO, orig_stdout: TextIO, orig_stderr: TextIO) -> None:
    sys.stdout = orig_stdout
    sys.stderr = orig_stderr
    log_file.close()


def archive_run_log(repo_root: Path, idx: int) -> Path:
    run_log_path = repo_root / "work" / "run.log"
    if not run_log_path.exists():
        raise RuntimeError(f"Run log not found at {run_log_path}")

    logs_dir = repo_root / "work" / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    ts = int(time.time())
    archive_path = logs_dir / f"run_{ts}__{idx}.log"
    archive_path.write_text(run_log_path.read_text(encoding="utf-8"), encoding="utf-8")
    return archive_path


def run_cmd(
    cmd: List[str],
    cwd: Path,
    stdin_text: Optional[str] = None,
    stream_stdout: bool = False,
) -> subprocess.CompletedProcess:
    if not stream_stdout:
        return subprocess.run(
            cmd,
            cwd=str(cwd),
            text=True,
            input=stdin_text,
            capture_output=True,
            check=False,
        )

    proc = subprocess.Popen(
        cmd,
        cwd=str(cwd),
        text=True,
        stdin=subprocess.PIPE if stdin_text is not None else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=1,
    )
    assert proc.stdout is not None
    if stdin_text is not None and proc.stdin is not None:
        proc.stdin.write(stdin_text)
        proc.stdin.close()

    out_lines: List[str] = []
    for line in proc.stdout:
        print(line, end="", flush=True)
        out_lines.append(line)
    rc = proc.wait()
    return subprocess.CompletedProcess(cmd, rc, "".join(out_lines), "")


def print_usage() -> None:
    print(
        "Usage:\n"
        "  python3 my-agent/agent.py                                     (harness no-op mode)\n"
        "  python3 my-agent/agent.py -i <index> [--max-retries N] [--save_log]\n"
        "  python3 my-agent/agent.py --index <index> [--max-retries N] [--save_log]\n\n"
        "Options:\n"
        "  --index, -i <index>       1-based dataset index\n"
        "  --max-retries, -r N       Retry limit for Codex solve loop (default: 8, max: 17)\n"
        "  --save_log, -s            Archive work/run.log to work/logs/run_<unix>__<index>.log\n",
        file=sys.stderr,
    )


def parse_cli(argv: List[str]) -> Tuple[Optional[int], int, bool]:
    default_retries = 8
    max_allowed_retries = 17

    if len(argv) <= 1:
        return None, default_retries, False

    idx: Optional[int] = None
    max_retries = default_retries
    save_log = False
    i = 1
    while i < len(argv):
        token = argv[i]

        if token in ("--help", "-h"):
            print_usage()
            sys.exit(0)

        if token in ("--max-retries", "-r"):
            if i + 1 >= len(argv):
                raise ValueError("Missing value for --max-retries.")
            value_token = argv[i + 1]
            if not value_token.isdigit():
                raise ValueError(f"Invalid --max-retries value: {value_token}. Expected a positive integer.")
            max_retries = int(value_token)
            i += 2
            continue

        if token.startswith("--max-retries="):
            value_token = token.split("=", 1)[1]
            if not value_token.isdigit():
                raise ValueError(f"Invalid --max-retries value: {value_token}. Expected a positive integer.")
            max_retries = int(value_token)
            i += 1
            continue

        if token in ("--save_log", "-s"):
            save_log = True
            i += 1
            continue

        # Supports: --index 1, -i 1
        if idx is None:
            if token in ("--index", "-i"):
                if i + 1 >= len(argv):
                    raise ValueError(f"Missing value for {token}.")
                idx_token = argv[i + 1]
                if not idx_token.isdigit():
                    raise ValueError(f"Invalid index value: {idx_token}. Expected a positive integer.")
                idx = int(idx_token)
                i += 2
                continue

        raise ValueError(f"Unexpected argument: {token}")

    if max_retries < 1:
        raise ValueError(f"Invalid --max-retries: {max_retries}. Minimum allowed value is 1.")
    if max_retries > max_allowed_retries:
        raise ValueError(
            f"Invalid --max-retries: {max_retries}. Maximum allowed value is {max_allowed_retries}."
        )

    if idx is None:
        raise ValueError("Missing required index. Use --index <N> or -i <N>.")

    return idx, max_retries, save_log


def infer_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def infer_harness_mode_workspace() -> Optional[Path]:
    import os

    env_root = Path.cwd().resolve()
    ws_env = os.environ.get("CVDP_WORKSPACE_ROOT")
    if ws_env:
        p = Path(ws_env).resolve()
        if p.exists():
            return p
    if (env_root / "prompt.json").exists() and (env_root / "rundir").exists():
        return env_root
    return None


def write_harness_noop_report(workspace: Path) -> None:
    rundir = workspace / "rundir"
    rundir.mkdir(parents=True, exist_ok=True)
    report = {
        "agent": "my-hw-agent",
        "mode": "harness_noop",
        "status": "success",
        "message": "No-op in harness mode; external Codex loop performs edits.",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    (rundir / "agent_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    log(f"Wrote no-op agent report: {rundir / 'agent_report.json'}")


def load_dataset_entries(dataset_path: Path) -> List[Dict]:
    entries: List[Dict] = []
    with dataset_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            entries.append(json.loads(line))
    return entries


def split_problem_and_issue(dataset_id: str) -> Tuple[str, str]:
    problem, issue = dataset_id.rsplit("_", 1)
    return problem, issue


def normalize_difficulty(value: object) -> str:
    text = str(value).strip().lower()
    if text in LEARNING_DIFFICULTIES:
        return text
    return DEFAULT_LEARNING_DIFFICULTY


def infer_entry_difficulty(entry: Dict) -> str:
    categories = entry.get("categories")
    if isinstance(categories, list):
        for token in categories:
            norm = normalize_difficulty(token)
            if norm in LEARNING_DIFFICULTIES and str(token).strip().lower() == norm:
                return norm
    return DEFAULT_LEARNING_DIFFICULTY


def resolve_harness_path(repo_root: Path, problem: str, issue: str) -> Path:
    exact = repo_root / "work" / problem / "harness" / issue
    if exact.exists():
        return exact

    # Handle zero-padded mismatch (e.g., dataset has 0681 but dir is 681).
    harness_dir = repo_root / "work" / problem / "harness"
    if not harness_dir.exists():
        raise FileNotFoundError(f"Missing harness dir: {harness_dir}")
    if issue.isdigit():
        issue_num = int(issue)
        for p in harness_dir.iterdir():
            if p.is_dir() and p.name.isdigit() and int(p.name) == issue_num:
                return p
    raise FileNotFoundError(f"Cannot resolve harness path for {problem}_{issue}")


def reset_staged_rtl_from_original(repo_root: Path, harness_path: Path, problem: str) -> Tuple[Path, Path]:
    source_candidates = [
        harness_path / "before" / "rtl",
        harness_path / "rtl.orig",
    ]
    source_rtl: Optional[Path] = None
    for candidate in source_candidates:
        if candidate.exists() and candidate.is_dir():
            source_rtl = candidate
            break

    if source_rtl is None:
        rtl_path = harness_path / "rtl"
        if rtl_path.exists() and rtl_path.is_dir() and not rtl_path.is_symlink():
            source_rtl = rtl_path
        elif rtl_path.is_symlink():
            # Fallback: if the harness rtl is a symlink, use its target as
            # read-only baseline when before/rtl and rtl.orig are unavailable.
            try:
                rtl_target = rtl_path.resolve(strict=True)
            except FileNotFoundError:
                rtl_target = None
            if rtl_target is not None and rtl_target.exists() and rtl_target.is_dir():
                source_rtl = rtl_target

    if source_rtl is None:
        raise FileNotFoundError(
            "Could not find original RTL source. Tried: "
            f"{harness_path / 'before' / 'rtl'}, {harness_path / 'rtl.orig'}, "
            f"non-symlink {harness_path / 'rtl'}, and symlink target of {harness_path / 'rtl'}"
        )

    issue = harness_path.name
    staged_rtl = repo_root / "my-agent" / "agent_files" / problem / issue / "rtl"
    staged_parent = staged_rtl.parent
    staged_parent.mkdir(parents=True, exist_ok=True)
    if staged_rtl.exists() or staged_rtl.is_symlink():
        if staged_rtl.is_symlink() or staged_rtl.is_file():
            staged_rtl.unlink()
        else:
            shutil.rmtree(staged_rtl)
    shutil.copytree(source_rtl, staged_rtl)
    return source_rtl, staged_rtl


def extract_first_error_from_sim_log(sim_log: Path) -> str:
    if not sim_log.exists():
        return "sim.log missing"
    patterns = ("error:", "FAILED", "AssertionError", "Traceback", "No module named")
    for line in sim_log.read_text(encoding="utf-8", errors="ignore").splitlines():
        if any(p in line for p in patterns):
            return line.strip()
    return "no explicit error line found in sim.log"


def read_tail(path: Path, lines: int = 80) -> str:
    if not path.exists():
        return f"[missing] {path}"
    content = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    return "\n".join(content[-lines:])


def read_agents_md(repo_root: Path) -> str:
    agents_path = repo_root / "my-agent" / "AGENTS.md"
    if not agents_path.exists():
        return ""
    return agents_path.read_text(encoding="utf-8", errors="ignore")


def read_learnings_json(repo_root: Path) -> str:
    learnings_path = repo_root / "work" / "learnings.json"
    if not learnings_path.exists():
        return ""
    return learnings_path.read_text(encoding="utf-8", errors="ignore")


def extract_info_payload(text: str) -> Optional[Dict[str, str]]:
    decoder = json.JSONDecoder()
    i = 0
    matches: List[Dict[str, str]] = []
    while i < len(text):
        if text[i] != "{":
            i += 1
            continue
        try:
            obj, end = decoder.raw_decode(text, i)
        except json.JSONDecodeError:
            i += 1
            continue
        i = end
        if not isinstance(obj, dict):
            continue
        if "problem_category" in obj and "learning" in obj:
            matches.append(obj)

    if not matches:
        return None
    obj = matches[-1]
    category = str(obj.get("problem_category", "")).strip()
    learning = str(obj.get("learning", "")).strip()
    if not category or not learning:
        return None
    return {"problem_category": category, "learning": learning}


def _empty_learning_doc() -> Dict[str, Dict[str, str]]:
    return {
        category: {difficulty: "" for difficulty in LEARNING_DIFFICULTIES}
        for category in INFO_CATEGORIES
    }


def update_learnings_json(repo_root: Path, problem_category: str, problem_difficulty: str, learning: str) -> None:
    if problem_category not in INFO_CATEGORIES:
        raise RuntimeError(
            f"Invalid InfoAgent category: {problem_category}. Must be one of: {', '.join(INFO_CATEGORIES)}"
        )
    if problem_difficulty not in LEARNING_DIFFICULTIES:
        raise RuntimeError(
            f"Invalid learning difficulty: {problem_difficulty}. Must be one of: {', '.join(LEARNING_DIFFICULTIES)}"
        )

    learnings_path = repo_root / "work" / "learnings.json"
    if not learnings_path.exists():
        rc = init_learnings_json(learnings_path)
        if rc != 0:
            raise RuntimeError(f"Unable to initialize {learnings_path}.")

    with learnings_path.open("r+", encoding="utf-8") as fh:
        lock_log_file(fh, learnings_path)
        raw = fh.read().strip()
        if raw:
            try:
                doc = json.loads(raw)
            except json.JSONDecodeError as exc:
                raise RuntimeError(f"{learnings_path} is not valid JSON: {exc}") from exc
            if not isinstance(doc, dict):
                raise RuntimeError(f"{learnings_path} JSON root must be an object.")
        else:
            doc = _empty_learning_doc()

        for cat in INFO_CATEGORIES:
            raw_bucket = doc.get(cat, {})
            if isinstance(raw_bucket, str):
                # Backward compatibility: migrate old flat schema into medium bucket.
                migrated_bucket = {
                    "easy": "",
                    "medium": raw_bucket.strip(),
                    "hard": "",
                }
                doc[cat] = migrated_bucket
                continue
            if not isinstance(raw_bucket, dict):
                raw_bucket = {}

            normalized_bucket: Dict[str, str] = {}
            for difficulty in LEARNING_DIFFICULTIES:
                value = raw_bucket.get(difficulty, "")
                normalized_bucket[difficulty] = str(value).strip() if value else ""
            doc[cat] = normalized_bucket

        existing_learning = str(doc[problem_category].get(problem_difficulty, "")).strip()

        def normalize_lines(text: str) -> List[str]:
            lines = [ln.strip() for ln in text.replace("\r\n", "\n").replace("\r", "\n").split("\n")]
            lines = [ln for ln in lines if ln]
            if lines:
                return lines
            collapsed = " ".join(text.split()).strip()
            return [collapsed] if collapsed else []

        line_cap = LEARNING_LINE_CAPS[problem_difficulty]
        existing_lines = normalize_lines(existing_learning)
        new_lines = normalize_lines(learning)

        def dedupe_keep_order(lines: List[str]) -> List[str]:
            deduped_lines: List[str] = []
            for ln in lines:
                if ln not in deduped_lines:
                    deduped_lines.append(ln)
            return deduped_lines

        existing_deduped = dedupe_keep_order(existing_lines)
        incoming_deduped = dedupe_keep_order(new_lines)

        # Preferred policy:
        # 1) Keep appending crucial new points while bucket is below cap.
        # 2) Only compress once bucket is full and a new unique learning arrives.
        if len(existing_deduped) < line_cap:
            merged = dedupe_keep_order(existing_deduped + incoming_deduped)
            if len(merged) > line_cap:
                merged = merged[:line_cap]
        else:
            unique_new = [ln for ln in incoming_deduped if ln not in existing_deduped]
            if not unique_new:
                merged = existing_deduped
            elif len(incoming_deduped) > 1:
                # Treat multi-line incoming learning as an explicit compressed summary.
                merged = dedupe_keep_order(incoming_deduped)[:line_cap]
            else:
                # Fallback if only one new line is provided while full:
                # keep most recent points by rotating window.
                merged = dedupe_keep_order(existing_deduped + unique_new)
                if len(merged) > line_cap:
                    merged = merged[-line_cap:]

        doc[problem_category][problem_difficulty] = "\n".join(merged)

        fh.seek(0)
        fh.write(json.dumps(doc, indent=2) + "\n")
        fh.truncate()


def build_codex_prompt(
    harness_path: Path,
    attempt: int,
    max_retries: int,
    problem_difficulty: str,
    fail_context: str,
    agents_md_text: str,
    include_agents_md: bool,
    learnings_text: str,
    include_learnings: bool,
) -> str:
    agents_block = ""
    if include_agents_md and agents_md_text:
        agents_block = f"""Follow these AGENTS.md instructions:
{agents_md_text}

Important:
- Do not echo or print AGENTS.md contents in your response.

"""

    learnings_block = ""
    if include_learnings and learnings_text:
        learnings_block = f"""Use existing learnings context from work/learnings.json:
{learnings_text}

Important:
- Do not echo or print learnings.json contents in your response.

"""

    staged_problem = harness_path.parts[-3]
    staged_issue = harness_path.name
    line_cap = LEARNING_LINE_CAPS[problem_difficulty]
    base = f"""Work on this harness iteratively:
{harness_path}

{agents_block}
{learnings_block}

Rules:
- Run ./my-agent/run_local_eval.sh "{harness_path}"
- If failing, read:
  - {harness_path}/prompt.json
  - {harness_path}/rundir/sim.log
  - {harness_path}/rundir/agent_report.json
- Edit ONLY files under:
  my-agent/agent_files/{staged_problem}/{staged_issue}/rtl/
- Do not modify before/ originals.
- Keep edits minimal, compile-safe first.
- Use sim.log first-error lines as primary guidance.
- Target dataset difficulty: {problem_difficulty}.
- InfoAgent learning format:
  - Use the selected `problem_category` and target difficulty `{problem_difficulty}` bucket in `work/learnings.json`.
  - Store only crucial, reusable points that materially helped solve the problem.
  - If bucket has room (< {line_cap} lines): append only important new points.
  - If bucket is full ({line_cap} lines) and you have new insight: return a compressed merged summary within {line_cap} lines.
  - Do not fill the line budget unless needed.

Attempt: {attempt}/{max_retries}
"""
    if fail_context:
        return base + "\nPrevious failure context:\n" + fail_context + "\n"
    return base


def run_codex_once(repo_root: Path, prompt: str) -> subprocess.CompletedProcess:
    log_codex("Invoking codex exec")
    cmd = ["codex", "exec", "-", "--skip-git-repo-check", "-C", str(repo_root)]
    proc = subprocess.Popen(
        cmd,
        cwd=str(repo_root),
        text=True,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=1,
    )

    assert proc.stdout is not None
    assert proc.stdin is not None
    proc.stdin.write(prompt)
    proc.stdin.close()

    start = time.time()
    out_lines: List[str] = []

    # Stream output live while enforcing timeout.
    import select

    timed_out = False
    emitted_stream_banner = False

    def _handle_stream_line(raw_line: str) -> None:
        nonlocal emitted_stream_banner
        if raw_line.strip() == "codex":
            if not emitted_stream_banner:
                log_codex("Stream output started")
                emitted_stream_banner = True
            return
        print(raw_line, end="", flush=True)

    while True:
        if proc.poll() is not None:
            # Drain any buffered remaining output.
            rest = proc.stdout.read()
            if rest:
                for part in rest.splitlines(True):
                    _handle_stream_line(part)
                out_lines.append(rest)
            break

        if (time.time() - start) > CODEX_TIMEOUT_SEC:
            timed_out = True
            proc.kill()
            break

        ready, _, _ = select.select([proc.stdout], [], [], 0.2)
        if ready:
            line = proc.stdout.readline()
            if line:
                _handle_stream_line(line)
                out_lines.append(line)

    if timed_out:
        # Use 124 as timeout sentinel return code.
        return subprocess.CompletedProcess(cmd, 124, "".join(out_lines), "")

    rc = proc.wait()
    return subprocess.CompletedProcess(cmd, rc, "".join(out_lines), "")


def run_local_eval(repo_root: Path, harness_path: Path) -> subprocess.CompletedProcess:
    shell_path = _resolve_shell_path()
    cmd = [
        shell_path,
        "-lc",
        f". {shlex.quote(str(repo_root / 'agent_env' / 'bin' / 'activate'))} && "
        f"./my-agent/run_local_eval.sh {shlex.quote(str(harness_path))}",
    ]
    return run_cmd(cmd, cwd=repo_root)


def run_post_benchmark(
    repo_root: Path,
    harness_path: Path,
    pipeline_start_epoch: int,
) -> subprocess.CompletedProcess:
    shell_path = _resolve_shell_path()
    cmd = [
        shell_path,
        "-lc",
        f". {shlex.quote(str(repo_root / 'agent_env' / 'bin' / 'activate'))} && "
        f"export AGENT_PIPELINE_START_EPOCH={pipeline_start_epoch} && "
        f"./my-agent/run_local_eval_batch.sh {shlex.quote(str(repo_root))} --harness {shlex.quote(str(harness_path))}",
    ]
    return run_cmd(cmd, cwd=repo_root)


def _resolve_shell_path() -> str:
    env_shell = os.environ.get("SHELL", "")
    if env_shell and Path(env_shell).is_file() and os.access(env_shell, os.X_OK):
        return env_shell

    for shell_name in ("zsh", "bash", "sh"):
        resolved = shutil.which(shell_name)
        if resolved:
            return resolved
    return "/bin/sh"


def ensure_local_eval_env(repo_root: Path) -> bool:
    cmd = [
        str(repo_root / "agent_env" / "bin" / "python"),
        "-c",
        "import pytest, cocotb, cocotb_tools.runner; print('ok')",
    ]
    cp = run_cmd(cmd, cwd=repo_root)
    return cp.returncode == 0


def solve_problem(
    repo_root: Path,
    harness_path: Path,
    problem_difficulty: str,
    max_retries: int = 8,
) -> bool:
    if not ensure_local_eval_env(repo_root):
        log("Environment precheck failed: agent_env is missing pytest/cocotb deps.")
        return False

    fail_context = ""
    agents_md_text = read_agents_md(repo_root)
    if agents_md_text:
        log("Loaded AGENTS.md instructions for Codex context.")
    else:
        log("AGENTS.md not found; proceeding without extra agent instructions.")
    learnings_text = read_learnings_json(repo_root)
    if learnings_text:
        log("Loaded learnings.json context for first attempt.")
    else:
        log("learnings.json not found or empty; continuing without learning context.")
    for attempt in range(1, max_retries + 1):
        log(f"Step 1/2: Codex solve attempt {attempt}/{max_retries}")
        prompt = build_codex_prompt(
            harness_path,
            attempt,
            max_retries,
            problem_difficulty,
            fail_context,
            agents_md_text,
            include_agents_md=(attempt == 1),
            learnings_text=learnings_text,
            include_learnings=(attempt == 1),
        )
        codex = run_codex_once(repo_root, prompt)
        log(f"Codex exit code: {codex.returncode}")
        if codex.returncode == 124:
            log(
                f"Codex timed out after {CODEX_TIMEOUT_MINUTES} minutes. "
                f"Backing off for {CODEX_TIMEOUT_BACKOFF_SEC} seconds and moving to next attempt."
            )
            time.sleep(CODEX_TIMEOUT_BACKOFF_SEC)
            codex_tail = "\n".join((codex.stdout or "").splitlines()[-40:])
            fail_context = (
                f"codex_return_code=124\n"
                f"first_error=codex_timeout_{CODEX_TIMEOUT_MINUTES}m\n"
                f"codex_output_tail:\n{codex_tail}\n"
            )
            continue
        if codex.returncode != 0:
            log("Codex invocation failed; continuing to eval to capture concrete failure.")

        info_payload = extract_info_payload(codex.stdout or "")
        if info_payload is None:
            log("InfoAgent JSON not found in Codex output for this attempt.")
        elif info_payload["problem_category"] not in INFO_CATEGORIES:
            log(
                "InfoAgent JSON had invalid category; skipping learning update for this attempt: "
                f"{info_payload['problem_category']}"
            )
        else:
            try:
                update_learnings_json(
                    repo_root,
                    info_payload["problem_category"],
                    problem_difficulty,
                    info_payload["learning"],
                )
                log(
                    "Updated work/learnings.json from InfoAgent output: "
                    f"{info_payload['problem_category']} ({problem_difficulty})"
                )
            except RuntimeError as exc:
                print(
                    f"[Write Permission Error] Could not update learnings.json. {exc}. "
                    "If learnings.json is open, close it and retry.",
                    file=sys.stderr,
                )
                sys.exit(2)

        log("Step 2/2: Running local eval")
        ev = run_local_eval(repo_root, harness_path)
        log(f"Eval exit code: {ev.returncode}")
        if ev.stdout.strip():
            log("Eval output (tail):")
            print("\n".join(ev.stdout.splitlines()[-25:]), flush=True)

        if ev.returncode == 0:
            return True

        sim_log = harness_path / "rundir" / "sim.log"
        agent_report = harness_path / "rundir" / "agent_report.json"
        eval_tail = "\n".join((ev.stdout or "").splitlines()[-40:])
        if "Missing Python deps in current environment." in (ev.stdout or ""):
            fail_context = (
                f"eval_return_code={ev.returncode}\n"
                "first_error=environment_python_deps_missing\n"
                f"eval_output_tail:\n{eval_tail}\n"
            )
        else:
            first_error = extract_first_error_from_sim_log(sim_log)
            fail_context = (
                f"eval_return_code={ev.returncode}\n"
                f"first_error={first_error}\n"
                f"sim_log_tail:\n{read_tail(sim_log, 80)}\n\n"
                f"agent_report_tail:\n{read_tail(agent_report, 80)}\n"
            )
        log("Attempt failed; prepared failure context for next Codex retry.")

    log(f"Max retries reached ({max_retries}); final status FAIL.")
    return False


def main() -> None:
    try:
        idx, max_retries, save_log = parse_cli(sys.argv)
    except ValueError as exc:
        print(f"[Usage Error] Invalid command arguments. {exc}", file=sys.stderr)
        print_usage()
        sys.exit(2)
    repo_root = infer_repo_root()

    # Harness mode (invoked by run_local_eval.sh): no args means no-op report only.
    if idx is None:
        workspace = infer_harness_mode_workspace()
        if workspace is not None:
            log("Harness mode detected (no index argument).")
            write_harness_noop_report(workspace)
            log("Harness mode complete.")
            return
        print_usage()
        sys.exit(2)

    try:
        log_file, orig_stdout, orig_stderr = start_run_log(repo_root)
    except RuntimeError as exc:
        print(f"[Write Permission Error] Could not create/update work/run.log file. {exc}", file=sys.stderr)
        sys.exit(2)

    try:
        _main_orchestrator(idx, max_retries, repo_root)
    finally:
        stop_run_log(log_file, orig_stdout, orig_stderr)
        if save_log and idx is not None:
            try:
                archived = archive_run_log(repo_root, idx)
                log(f"Archived run.log to: {archived}")
            except RuntimeError as exc:
                print(f"[Write Permission Error] Could not archive run.log to work/logs/. {exc}", file=sys.stderr)
            except OSError as exc:
                print(f"[Write Permission Error] Could not archive run.log to work/logs/. {exc}", file=sys.stderr)


def _main_orchestrator(idx: int, max_retries: int, repo_root: Path) -> None:
    pipeline_start_epoch = int(time.time())
    log("Step 0: Initializing learnings file")
    learnings_path = repo_root / "work" / "learnings.json"
    init_rc = init_learnings_json(learnings_path)
    if init_rc != 0:
        print(
            f"[Write Permission Error] Could not initialize {learnings_path}. ",
            "If the file is open, close it and retry.",
            file=sys.stderr,
        )
        sys.exit(init_rc)

    dataset_path = repo_root / "dataset" / "hackathon-agentic-obfuscated_final_corrected.jsonl"
    if not dataset_path.exists():
        print(f"[Input File Error] Dataset file not found: {dataset_path}", file=sys.stderr)
        sys.exit(1)

    log("Step A: Loading dataset entries")
    entries = load_dataset_entries(dataset_path)
    if not entries:
        print(f"[Input File Error] Dataset file is empty: {dataset_path}", file=sys.stderr)
        sys.exit(1)
    if idx < 1 or idx > len(entries):
        print(f"[Input Value Error] Index out of range: {idx}. Valid range: 1..{len(entries)}", file=sys.stderr)
        sys.exit(1)

    entry = entries[idx - 1]
    entry_id = entry.get("id", "")
    problem_difficulty = infer_entry_difficulty(entry)
    if "_" not in entry_id:
        print(f"[Input Format Error] Invalid dataset id format: {entry_id}. Expected <problem_name>_<harness_id>.", file=sys.stderr)
        sys.exit(1)

    problem, issue = split_problem_and_issue(entry_id)
    try:
        harness_path = resolve_harness_path(repo_root, problem, issue)
    except FileNotFoundError as exc:
        print(f"[Harness Error] Could not find the harness folder for this dataset id. {exc}", file=sys.stderr)
        sys.exit(1)
    log(f"Selected dataset index {idx}: {entry_id}")
    log(f"Selected dataset difficulty: {problem_difficulty}")
    log(f"Resolved harness path: {harness_path}")
    try:
        source_rtl, staged_rtl = reset_staged_rtl_from_original(repo_root, harness_path, problem)
    except (OSError, FileNotFoundError) as exc:
        print(f"[RTL Reset Error] Could not reset staged RTL from original source. {exc}", file=sys.stderr)
        sys.exit(1)
    log(
        "Reset staged RTL from original source: "
        f"{source_rtl} -> {staged_rtl}"
    )

    solved = False
    for run_cycle in range(1, MAX_SOLVE_RUN_CYCLES + 1):
        log(
            f"Run cycle {run_cycle}/{MAX_SOLVE_RUN_CYCLES}: "
            f"using max retries {max_retries}"
        )
        solved = solve_problem(
            repo_root,
            harness_path,
            problem_difficulty=problem_difficulty,
            max_retries=max_retries,
        )
        if solved:
            break
        if run_cycle < MAX_SOLVE_RUN_CYCLES:
            log(
                f"Run cycle {run_cycle} reached max retries ({max_retries}) without PASS; "
                "starting a fresh run cycle."
            )

    log("Step B: Running single-target local benchmark/report pipeline")
    bench = run_post_benchmark(repo_root, harness_path, pipeline_start_epoch)
    log(f"Benchmark pipeline exit code: {bench.returncode}")
    if bench.stdout.strip():
        log("Benchmark output (tail):")
        print("\n".join(bench.stdout.splitlines()[-30:]), flush=True)
    if bench.returncode != 0:
        print("[Permission Error] Could not generate final report files.", file=sys.stderr)
        sys.exit(1)

    final_status = "PASS" if solved else "FAIL"
    log(f"Step C: Complete. Target problem final status: {final_status}")
    sys.exit(0 if solved else 3)


if __name__ == "__main__":
    main()
