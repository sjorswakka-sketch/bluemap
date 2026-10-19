#!/usr/bin/env python3
"""Verify the downloaded Godot recovery files without starting the game or reading saves."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
COMMIT = "a8a988be27835dec979d2523a3a85a34385eac54"
TREE = "73ba02ea4db0a1c920360b6570f5209ccb970143"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recovery", type=Path)
    args = parser.parse_args()
    recovery = args.recovery.resolve()
    manifest = json.loads((recovery / "recovery-manifest.json").read_text(encoding="utf-8"))
    assert manifest["commit"] == COMMIT and manifest["tree"] == TREE
    for entry in manifest["files"]:
        path = recovery / entry["name"]
        assert path.parent == recovery, "Unsafe recovery manifest filename"
        data = path.read_bytes()
        assert len(data) == entry["bytes"], entry["name"]
        assert hashlib.sha256(data).hexdigest() == entry["sha256"], entry["name"]
    source = json.loads((ROOT / "migration/reference/source-manifest.json").read_text(encoding="utf-8"))
    prefix = "BluemapQuest-godot-0.34.0-source/"
    with zipfile.ZipFile(recovery / "BluemapQuest-godot-0.34.0-source.zip") as archive:
        assert archive.testzip() is None
        files = {entry.filename for entry in archive.infolist() if not entry.is_dir()}
        assert files == {prefix + entry["path"] for entry in source["files"]}
        for entry in source["files"]:
            data = archive.read(prefix + entry["path"])
            assert len(data) == entry["bytes"]
            assert hashlib.sha256(data).hexdigest() == entry["sha256"], entry["path"]
    with zipfile.ZipFile(recovery / "BluemapQuest-v0.34.0-preview-windows.zip") as archive:
        assert archive.testzip() is None
        assert {e.filename for e in archive.infolist() if not e.is_dir()} == {
            "BluemapQuest/BluemapQuest.exe", "BluemapQuest/LEESMIJ.txt"}
        exe = archive.read("BluemapQuest/BluemapQuest.exe")
        assert len(exe) == 105581440
        assert hashlib.sha256(exe).hexdigest() == "5a8eea99e9da3192f31462c5916a9fecd71b0f491b31fc5577e878cf2eed0ff0"
        assert exe[:2] == b"MZ"
        offset = struct.unpack_from("<I", exe, 0x3c)[0]
        assert exe[offset:offset + 4] == b"PE\0\0"
        assert struct.unpack_from("<H", exe, offset + 4)[0] == 0x8664
        original = next(entry for entry in source["files"] if entry["path"] == "distribution/LEESMIJ.txt")
        assert hashlib.sha256(archive.read("BluemapQuest/LEESMIJ.txt")).hexdigest() == original["sha256"]
    bundle = recovery / "BluemapQuest-godot-0.34.0-history.bundle"
    with tempfile.TemporaryDirectory(prefix="bluemap-recovery-proof-") as temporary:
        checkout = Path(temporary) / "restored"
        subprocess.run(["git", "clone", "--no-checkout", "--branch", "codex/unity-migration",
                        str(bundle), str(checkout)], check=True, capture_output=True)
        def git(*arguments):
            return subprocess.check_output(["git", *arguments], cwd=checkout).decode().strip()
        assert git("rev-parse", "HEAD") == COMMIT
        assert git("rev-parse", "HEAD^{tree}") == TREE
        subprocess.run(["git", "fsck", "--full"], cwd=checkout, check=True, capture_output=True)
    print("GODOT RECOVERY OK: all hashes, 1734 source blobs, Windows ZIP/PE/x64, offline Git clone and object integrity")


if __name__ == "__main__":
    main()
