#!/usr/bin/env python3
"""Inventory canonical Git blobs at the frozen Godot commit, never player saves.

Run with --check to compare the committed manifest without rewriting it.
Works from any checkout that contains the reference commit; requires Git and Python.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parent.parent
COMMIT = "a8a988be27835dec979d2523a3a85a34385eac54"
TREE = "73ba02ea4db0a1c920360b6570f5209ccb970143"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def inventory():
    assert git("rev-parse", COMMIT + "^{tree}").decode().strip() == TREE
    entries = []
    records = git("ls-tree", "-rz", "--full-tree", COMMIT).split(b"\0")
    # One cat-file process avoids spawning a process for every asset.
    parsed = [record.split(b"\t", 1) for record in records if record]
    objects = [meta.split()[2] for meta, _ in parsed]
    raw = subprocess.run(["git", "cat-file", "--batch"], cwd=ROOT,
                         input=b"\n".join(objects) + b"\n", check=True,
                         stdout=subprocess.PIPE).stdout
    cursor = 0
    for (meta, path), expected_sha in zip(parsed, objects):
        mode, kind, sha = meta.decode().split()
        if kind != "blob":
            raise ValueError("Uninventoried non-blob object: " + path.decode())
        end = raw.index(b"\n", cursor)
        header_sha, header_kind, size = raw[cursor:end].split()
        size = int(size)
        assert header_sha == expected_sha and header_kind == b"blob"
        data = raw[end + 1:end + 1 + size]
        cursor = end + 2 + size
        assert hashlib.sha1(b"blob " + str(size).encode() + b"\0" + data).hexdigest() == sha
        name = path.decode("utf-8")
        entry = {"path": name, "mode": mode, "git_blob": sha, "bytes": size,
                 "sha256": hashlib.sha256(data).hexdigest()}
        if name.endswith(".png") and data.startswith(b"\x89PNG\r\n\x1a\n"):
            entry["pixels"] = list(struct.unpack(">II", data[16:24]))
        entries.append(entry)
    assert cursor == len(raw)
    entries.sort(key=lambda entry: entry["path"])
    suffixes = Counter(Path(entry["path"]).suffix or "(none)" for entry in entries)
    tests = [entry["path"] for entry in entries
             if entry["path"].startswith("tests/") and entry["path"].endswith("_test.gd")]
    assets = [entry["path"] for entry in entries
              if Path(entry["path"]).suffix in (".png", ".svg", ".wav", ".ogg", ".mp3", ".ttf", ".otf")]
    generators = [entry["path"] for entry in entries
                  if entry["path"].startswith("tools/") and entry["path"].endswith(".py")]
    return {"schema": 1, "scope": "Every canonical tracked blob in the frozen Godot Git tree; no user files or generated .godot cache",
            "commit": COMMIT, "tree": TREE, "file_count": len(entries),
            "total_blob_bytes": sum(entry["bytes"] for entry in entries),
            "extensions": dict(sorted(suffixes.items())), "asset_paths": assets,
            "python_tool_paths": generators, "test_suite_paths": tests, "files": entries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    target = ROOT / "migration/reference/source-manifest.json"
    text = json.dumps(inventory(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if target.read_text(encoding="utf-8") != text:
            raise SystemExit("Frozen source manifest differs from canonical Git objects")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8", newline="\n")
    data = json.loads(text)
    print("GODOT REFERENCE OK:", data["file_count"], "files,",
          len(data["asset_paths"]), "assets,", len(data["test_suite_paths"]), "test suites")


if __name__ == "__main__":
    main()
