#!/usr/bin/env python3
"""Run LihFolk's existing Luau checker with the current platform's shell."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECKER_DIR = ROOT / "hooks" / "scripts"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run the LihFolk Luau static checker.")
    parser.add_argument("--scan", action="store_true", help="Scan the supplied file or folder (defaults to the current directory).")
    parser.add_argument("paths", nargs="*", help="Luau files or project folders to scan.")
    args = parser.parse_args(argv)
    if not args.scan:
        parser.error("--scan is required")
    paths = args.paths or ["."]

    if os.name == "nt":
        checker = CHECKER_DIR / "lihfolk-check.ps1"
        shell = shutil.which("pwsh") or shutil.which("powershell")
        if not checker.is_file() or not shell:
            print("LihFolk Windows checker or PowerShell was not found.", file=sys.stderr)
            return 2
        command = [shell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(checker), "-Scan", *paths]
    else:
        checker = CHECKER_DIR / "lihfolk-check.sh"
        shell = shutil.which("sh")
        if not checker.is_file() or not shell:
            print("LihFolk POSIX checker or sh was not found.", file=sys.stderr)
            return 2
        command = [shell, str(checker), "--scan", *paths]

    environment = os.environ.copy()
    environment["CLAUDE_PROJECT_DIR"] = str(Path.cwd())
    try:
        result = subprocess.run(command, cwd=Path.cwd(), env=environment, check=False)
    except OSError as exc:
        print(f"Could not start the LihFolk checker: {exc}", file=sys.stderr)
        return 2
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
