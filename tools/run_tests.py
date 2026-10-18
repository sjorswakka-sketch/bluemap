#!/usr/bin/env python3
"""Run Godot tests in a disposable project with a verified separate save directory.

Works on Windows, macOS and Linux. Requires only Python's standard library.
Usage: python tools/run_tests.py /path/to/godot [--tests movement_test professions_test]
"""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid


ERROR = re.compile(r"SCRIPT ERROR|Parse Error|\bFAIL |^ERROR: (?!\d+ resources still in use at exit \(run with --verbose for details\)\.)", re.MULTILINE)
SUCCESS = re.compile(r"^[A-Z][A-Z0-9 _-]* OK\s*$", re.MULTILINE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot", nargs="?", default="godot")
    parser.add_argument("--tests", nargs="+", help="Test filenames without .gd; default: all *_test.gd")
    parser.add_argument("--keep", action="store_true", help="Keep the temporary project and logs for diagnosis")
    parser.add_argument("--keep-going", action="store_true", help="Report all failing suites before returning failure")
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent
    engine = shutil.which(args.godot)
    if not engine:
        parser.error("Godot executable not found: " + args.godot)
    engine = str(Path(engine).resolve())
    available = {p.stem for p in (source / "tests").glob("*_test.gd")}
    order = [s for s in ("smoke_test", "playthrough_test") if s in available]
    order += sorted(available - set(order))
    if args.tests:
        if set(args.tests) - available:
            parser.error("Unknown tests: " + ", ".join(sorted(set(args.tests) - available)))
        order = list(dict.fromkeys(args.tests))
    if not order:
        parser.error("No tests found")

    task_dir = Path(tempfile.mkdtemp(prefix="bluemap-tests-"))
    project = task_dir / "project"
    token = "Bluemap-Codex-Tests-" + uuid.uuid4().hex
    user_dir = None
    failed = True
    print("Test copy:", project, flush=True)
    try:
        shutil.copytree(source, project, ignore=shutil.ignore_patterns(
            ".git", ".godot", ".testdata", "build", "dist", "__pycache__"))
        settings_path = project / "project.godot"
        settings = settings_path.read_text(encoding="utf-8")
        # Change only the disposable copy. Windows ignores XDG_DATA_HOME; a unique
        # project name with the standard user directory also works there.
        settings = re.sub(r'^config/name=.*$', 'config/name=' + json.dumps(token), settings, flags=re.MULTILINE)
        settings = re.sub(r'^config/use_custom_user_dir=.*\n?', '', settings, flags=re.MULTILINE)
        settings = settings.replace("[application]", "[application]\nconfig/use_custom_user_dir=false", 1)
        settings_path.write_text(settings, encoding="utf-8")
        probe = ('extends SceneTree\nfunc _initialize():\n'
                 '\tvar path := OS.get_user_data_dir()\n'
                 '\tprint("ISOLATED_USER_DIR=" + path)\n'
                 '\tquit(0 if path.replace("\\\\", "/").get_file() == ' + json.dumps(token) + ' else 1)\n')
        (project / "isolation_probe.gd").write_text(probe, encoding="utf-8")

        def run(label, arguments, timeout=240):
            try:
                # De tests controleren Nederlandse teksten: draai ze in het Nederlands (zie scripts/core/lang.gd).
                env = dict(os.environ, BLUEMAP_LANG=os.environ.get("BLUEMAP_LANG", "nl"))
                result = subprocess.run([engine, "--headless", "--path", str(project), *arguments],
                                        capture_output=True, text=True, encoding="utf-8", errors="replace",
                                        timeout=timeout, cwd=project, env=env)
                log = result.stdout + result.stderr
                code = result.returncode
            except subprocess.TimeoutExpired as exc:
                log = "TIMEOUT\n" + str(exc.stdout or "") + str(exc.stderr or "")
                code = 1
            (task_dir / (label + ".log")).write_text(log, encoding="utf-8")
            if code or ERROR.search(log):
                print("FAILED:", label, flush=True)
                print(log[-12000:], flush=True)
                return None
            return log

        if run("import", ["--editor", "--import"]) is None:
            return 1
        probe_log = run("isolation", ["-s", "res://isolation_probe.gd"])
        if probe_log is None:
            return 1
        match = re.search(r"^ISOLATED_USER_DIR=(.+)$", probe_log, re.MULTILINE)
        if not match or Path(match[1].strip()).name != token:
            print("Stopped: could not verify an isolated save directory.", flush=True)
            return 1
        user_dir = Path(match[1].strip())
        print("Verified separate save directory:", user_dir, flush=True)
        failed_suites = []
        for name in order:
            log = run(name, ["--fixed-fps", "60", "-s", "tests/" + name + ".gd"])
            if log is None or not SUCCESS.search(log):
                if log is not None:
                    print("FAILED (no completion marker):", name, flush=True)
                    print(log[-12000:], flush=True)
                if not args.keep_going:
                    return 1
                failed_suites.append(name)
                continue
            print("PASS", name, flush=True)
        if failed_suites:
            print("FAILED SUITES: " + ", ".join(failed_suites), flush=True)
            return 1
        print("ALLE TESTS GESLAAGD (%d)" % len(order), flush=True)
        failed = False
        return 0
    finally:
        if failed or args.keep:
            print("Project and logs retained:", task_dir, flush=True)
        else:
            shutil.rmtree(task_dir)
        # Only remove the exact, verified UUID directory created by this run.
        if user_dir is not None and user_dir.name == token and user_dir.exists():
            shutil.rmtree(user_dir)


if __name__ == "__main__":
    sys.exit(main())
