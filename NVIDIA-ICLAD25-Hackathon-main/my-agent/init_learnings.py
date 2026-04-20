#!/usr/bin/env python3

import argparse
import json
import os
import sys
from pathlib import Path
from typing import TextIO


CATEGORIES = [
    "Modify or Extend Existing RTL",
    "Integrate multiple modules into a top module",
    "Create new RTL from spec",
    "Debug/fix buggy RTL",
]

DIFFICULTIES = ("easy", "medium", "hard")


def infer_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def lock_file_handle(fh: TextIO, path: Path) -> None:
    if os.name == "nt":
        import msvcrt

        try:
            # Non-blocking lock while handle is held.
            msvcrt.locking(fh.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError as exc:
            raise RuntimeError(
                f"Could not lock {path}. It may be open in another application. "
                "Please close it and retry."
            ) from exc
        return

    import fcntl

    try:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as exc:
        raise RuntimeError(
            f"Could not lock {path}. It may be open in another application. "
            "Please close it and retry."
        ) from exc


def init_learnings_json(out_path: Path) -> int:
    out_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        with out_path.open("a+", encoding="utf-8") as fh:
            lock_file_handle(fh, out_path)
            fh.seek(0, os.SEEK_END)
            size = fh.tell()

            if size > 0:
                print(f"[init_learnings] {out_path} already exists; no changes made.")
                return 0

            payload = {
                category: {difficulty: "" for difficulty in DIFFICULTIES}
                for category in CATEGORIES
            }
            fh.seek(0)
            fh.write(json.dumps(payload, indent=2) + "\n")
            fh.truncate()
            fh.flush()
    except RuntimeError as exc:
        print(f"[init_learnings] ERROR: {exc}", file=sys.stderr)
        return 2
    except OSError as exc:
        print(f"[init_learnings] ERROR: Could not write {out_path}: {exc}", file=sys.stderr)
        return 1

    print(f"[init_learnings] Created {out_path}.")
    return 0


def main() -> None:
    repo_root = infer_repo_root()
    default_out = repo_root / "work" / "learnings.json"

    parser = argparse.ArgumentParser(
        description=(
            "Initialize work/learnings.json with 4 category keys, each containing "
            "easy/medium/hard blank learning buckets."
        )
    )
    parser.add_argument(
        "--output",
        default=str(default_out),
        help="Path to learnings.json (default: <repo_root>/work/learnings.json)",
    )
    args = parser.parse_args()

    out_path = Path(args.output).resolve()
    rc = init_learnings_json(out_path)
    sys.exit(rc)


if __name__ == "__main__":
    main()
