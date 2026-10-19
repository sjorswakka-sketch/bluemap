#!/usr/bin/env python3
"""Check migration source boundaries without starting either game engine.

The Godot reference is checked against its immutable Git objects AND the current
working tree. Unity checks validate source integrity, not C# compilation or a
Windows player run. No license, account, cache or player-save files are opened.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
BASELINE_COMMIT = "a8a988be27835dec979d2523a3a85a34385eac54"
BASELINE_TREE = "73ba02ea4db0a1c920360b6570f5209ccb970143"
EDITOR_VERSION = "6000.3.26f1"
EDITOR_REVISION = "de8167e7440c"
# These two files explain the coexistence of the engines. All other original
# files, including the Godot workflow, generators and tests, remain frozen.
GODOT_EDIT_ALLOWLIST = frozenset({".gitignore", "README.md"})
GUID_LINE = re.compile(r"^guid: ([0-9a-f]{32})$", re.MULTILINE)


class MigrationError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise MigrationError(message)


def json_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=json_object)
    except (ValueError, UnicodeError) as error:
        raise MigrationError(f"Invalid JSON: {path.name}") from error
    require(isinstance(value, dict), f"Expected JSON object: {path.name}")
    return value


def canonical_bytes(data: bytes, name: str) -> bytes:
    """Only normalize line endings for actual UTF-8 text; binaries stay exact."""
    text_suffixes = {".cfg", ".gd", ".godot", ".import", ".json", ".md", ".po", ".py",
                     ".sh", ".svg", ".tscn", ".txt", ".uid", ".yml", ".yaml"}
    if PurePosixPath(name).suffix.casefold() not in text_suffixes:
        return data
    if b"\0" in data:
        return data
    try:
        data.decode("utf-8")
    except UnicodeError:
        return data
    return data.replace(b"\r\n", b"\n")


def safe_relative(name: str) -> PurePosixPath:
    path = PurePosixPath(name)
    require(bool(name) and "\\" not in name and not path.is_absolute()
            and all(part not in {"", ".", ".."} for part in name.split("/"))
            and ":" not in name, f"Unsafe source path: {name}")
    return path


def git(root: Path, *args: str, data: bytes | None = None) -> bytes:
    result = subprocess.run(["git", *args], cwd=root, input=data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    require(result.returncode == 0, "Git reference unavailable: " + " ".join(args[:2]))
    return result.stdout


def read_baseline(root: Path, manifest: dict) -> dict[str, bytes]:
    require(manifest.get("schema") == 1 and manifest.get("commit") == BASELINE_COMMIT
            and manifest.get("tree") == BASELINE_TREE, "Frozen Godot reference identity changed")
    require(git(root, "rev-parse", BASELINE_COMMIT + "^{tree}").decode().strip() == BASELINE_TREE,
            "Frozen Godot tree differs")
    rows = [row.split(b"\t", 1) for row in
            git(root, "ls-tree", "-rz", "--full-tree", BASELINE_COMMIT).split(b"\0") if row]
    records = {}
    for metadata, name in rows:
        mode, kind, oid = metadata.decode().split()
        require(kind == "blob", "Unexpected non-file in frozen reference")
        records[name.decode("utf-8")] = (mode, oid)
    entries = manifest.get("files")
    require(isinstance(entries, list), "Frozen source manifest has no files")
    names = [entry.get("path") for entry in entries if isinstance(entry, dict)]
    require(len(names) == len(entries) == len(set(names))
            and set(names) == set(records) and manifest.get("file_count") == len(entries),
            "Frozen source manifest file set differs from its Git tree")
    ids = [records[name][1] for name in names]
    raw = git(root, "cat-file", "--batch", data=("\n".join(ids) + "\n").encode())
    cursor = 0
    blobs = {}
    for entry in entries:
        name = entry["path"]
        safe_relative(name)
        mode, oid = records[name]
        require(entry.get("mode") == mode and entry.get("git_blob") == oid,
                f"Frozen manifest Git identity changed: {name}")
        end = raw.find(b"\n", cursor)
        require(end >= cursor, "Incomplete Git batch header")
        header = raw[cursor:end].split()
        require(len(header) == 3 and header[:2] == [oid.encode(), b"blob"],
                "Git batch object mismatch")
        size = int(header[2])
        blob = raw[end + 1:end + 1 + size]
        cursor = end + size + 2
        require(len(blob) == size and entry.get("bytes") == size
                and hashlib.sha256(blob).hexdigest() == entry.get("sha256")
                and hashlib.sha1(b"blob " + str(size).encode() + b"\0" + blob).hexdigest() == oid,
                f"Frozen manifest content changed: {name}")
        blobs[name] = blob
    require(cursor == len(raw), "Unexpected Git batch data")
    return blobs


def validate_godot_worktree(root: Path, baseline: dict[str, bytes]) -> dict:
    checked = 0
    for name, blob in baseline.items():
        path = root.joinpath(*safe_relative(name).parts)
        require(path.is_file() and not path.is_symlink(), f"Godot source missing or linked: {name}")
        if name in GODOT_EDIT_ALLOWLIST:
            continue
        require(canonical_bytes(path.read_bytes(), name) == canonical_bytes(blob, name),
                f"Preserved Godot source changed: {name}")
        checked += 1
    return {"filesCompared": checked, "allowlist": sorted(GODOT_EDIT_ALLOWLIST),
            "comparison": "UTF-8 CRLF normalized; binary bytes exact"}


def validate_godot_index(manifest: dict, index: dict[str, tuple[str, str, str]]) -> None:
    """A staged deletion/edit must not be hidden by a restored working-tree file."""
    for entry in manifest["files"]:
        name = entry["path"]
        if name in GODOT_EDIT_ALLOWLIST:
            continue
        require(index.get(name) == (entry["mode"], entry["git_blob"], "0"),
                f"Preserved Godot index entry changed or missing: {name}")


def validate_editor(project: Path) -> None:
    version = (project / "ProjectSettings/ProjectVersion.txt").read_text(encoding="utf-8-sig")
    require(re.findall(r"^m_EditorVersion: (.+)$", version, re.MULTILINE) == [EDITOR_VERSION],
            "Unity Editor version differs from the agreed pin")
    require(re.findall(r"^m_EditorVersionWithRevision: (.+)$", version, re.MULTILINE)
            == [f"{EDITOR_VERSION} ({EDITOR_REVISION})"], "Unity Editor revision differs from the agreed pin")


def validate_packages(manifest: dict, lock: dict) -> dict:
    direct = manifest.get("dependencies")
    locked = lock.get("dependencies")
    require(isinstance(direct, dict) and bool(direct) and isinstance(locked, dict),
            "Unity package dependencies are missing")
    require(set(manifest) == {"dependencies"} and set(lock) == {"dependencies"},
            "Unexpected Unity package manifest settings")
    for name, entry in locked.items():
        require(name.startswith("com.unity.modules.") and isinstance(entry, dict)
                and entry.get("source") == "builtin" and entry.get("version") == "1.0.0",
                f"Only pinned built-in Unity modules are allowed: {name}")
        require(type(entry.get("depth")) is int and entry["depth"] >= 0
                and isinstance(entry.get("dependencies"), dict), f"Invalid Unity module lock: {name}")
        for dependency, version in entry["dependencies"].items():
            require(version == "1.0.0" and dependency in locked,
                    f"Missing or unpinned Unity module dependency: {name} -> {dependency}")
    for name, version in direct.items():
        require(version == "1.0.0" and name in locked and locked[name]["depth"] == 0,
                f"Manifest and lock differ for Unity module: {name}")
    require({name for name, entry in locked.items() if entry["depth"] == 0} == set(direct),
            "Direct Unity module set differs from its lock")
    reachable = set(direct)
    pending = list(direct)
    while pending:
        for name in locked[pending.pop()]["dependencies"]:
            if name not in reachable:
                reachable.add(name)
                pending.append(name)
    require(reachable == set(locked), "Unity lock contains unreachable modules")
    return {"directModules": len(direct), "lockedModules": len(locked),
            "externalDependencies": 0}


def validate_assets(project: Path) -> dict:
    assets = project / "Assets"
    require(assets.is_dir() and not assets.is_symlink(), "Unity Assets directory is missing or linked")
    paths = sorted(assets.rglob("*"))
    seen_paths = set()
    guids = {}
    metas = {}
    for path in paths:
        name = path.relative_to(project).as_posix()
        require(not path.is_symlink(), f"Unity asset link is not allowed: {name}")
        require(name.casefold() not in seen_paths, f"Unity asset case conflict: {name}")
        seen_paths.add(name.casefold())
        if path.suffix == ".meta":
            require(path.is_file(), f"Unity meta must be a file: {name}")
            owner = path.with_suffix("")
            require(owner.exists() and owner.suffix != ".meta", f"Orphan Unity meta: {name}")
            text = path.read_text(encoding="utf-8-sig")
            matches = GUID_LINE.findall(text)
            require(len(matches) == 1 and len(re.findall(r"^guid:", text, re.MULTILINE)) == 1,
                    f"Unity meta needs one valid GUID: {name}")
            guid = matches[0]
            require(guid not in guids, f"Duplicate Unity asset GUID: {name}")
            require(("folderAsset: yes" in text) == owner.is_dir(), f"Unity folder meta differs: {name}")
            guids[guid] = owner.relative_to(project).as_posix()
            metas[owner.relative_to(project).as_posix()] = guid
        else:
            require(path.is_file() or path.is_dir(), f"Unsupported Unity asset: {name}")
            require(path.with_name(path.name + ".meta").is_file(), f"Unity asset has no meta: {name}")
    settings = (project / "ProjectSettings/EditorBuildSettings.asset").read_text(encoding="utf-8-sig")
    scenes = re.findall(r"^\s*- enabled: ([01])\n\s+path: (.+)\n\s+guid: ([0-9a-f]{32})\s*$",
                        settings, re.MULTILINE)
    require(scenes and any(enabled == "1" for enabled, _, _ in scenes), "No enabled Unity build scene")
    require(len(scenes) == len(re.findall(r"^\s*- enabled:", settings, re.MULTILINE)),
            "Unrecognized Unity build scene declaration")
    require(len({name for _, name, _ in scenes}) == len(scenes), "Duplicate Unity build scene")
    for _, name, guid in scenes:
        path = safe_relative(name)
        require(path.parts[0] == "Assets" and path.suffix == ".unity" and
                project.joinpath(*path.parts).is_file() and metas.get(name) == guid,
                f"Unity build scene path/GUID does not resolve: {name}")
    return {"assetGuids": len(guids), "buildScenes": len(scenes)}


def validate_registered_sources(names: list[str]) -> dict:
    count = 0
    forbidden_directories = {"library", "temp", "obj", "logs", "usersettings", "build", "builds", ".vs"}
    forbidden_suffixes = {".log", ".dmp", ".crash", ".ulf", ".alf", ".lic", ".csproj", ".sln",
                          ".slnx", ".user", ".pidb", ".pdb", ".opendb"}
    for name in names:
        path = safe_relative(name)
        if path.parts[0].casefold() != "unity":
            continue
        count += 1
        require(path.parts[0] == "unity", "Unity project path has inconsistent case")
        require(not (set(part.casefold() for part in path.parts[1:-1]) & forbidden_directories)
                and path.suffix.casefold() not in forbidden_suffixes
                and not path.name.casefold().endswith(".vc.db"),
                f"Unity cache, build, local settings, log or license file is tracked: {name}")
    require(count > 0, "No registered Unity project sources")
    return {"registeredUnityFiles": count, "cacheBuildLicenseFiles": 0}


def check(root: Path) -> dict:
    manifest = read_json(root / "migration/reference/source-manifest.json")
    baseline = read_baseline(root, manifest)
    godot = validate_godot_worktree(root, baseline)
    index = {}
    for row in git(root, "ls-files", "--stage", "-z").split(b"\0"):
        if row:
            metadata, name = row.split(b"\t", 1)
            require(name.decode("utf-8") not in index, "Conflicted Git index entry")
            index[name.decode("utf-8")] = tuple(metadata.decode().split())
    validate_godot_index(manifest, index)
    godot["indexEntriesVerified"] = True
    project = root / "unity"
    require((project / ".gdignore").is_file(), "Unity project needs .gdignore to stay outside Godot imports")
    validate_editor(project)
    packages = validate_packages(read_json(project / "Packages/manifest.json"),
                                 read_json(project / "Packages/packages-lock.json"))
    assets = validate_assets(project)
    names = [name.decode("utf-8") for name in git(root, "ls-files", "-z").split(b"\0") if name]
    sources = validate_registered_sources(names)
    return {"schemaVersion": 1, "success": True, "scope": "source integrity only; no Unity compile or player run",
            "baselineCommit": BASELINE_COMMIT, "baselineTree": BASELINE_TREE, "godot": godot,
            "unity": {"editorVersion": EDITOR_VERSION, "editorRevision": EDITOR_REVISION,
                      **packages, **assets, **sources}, "playerSavesAccessed": False,
            "unityLicenseAccessed": False, "enginesStarted": False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check only (the default)")
    parser.add_argument("--output", type=Path, help="Optional compact JSON report")
    args = parser.parse_args()
    try:
        report = check(ROOT)
        print("MIGRATION SOURCE OK:", report["godot"]["filesCompared"], "Godot files preserved;",
              report["unity"]["assetGuids"], "Unity GUIDs; no engine or save access.")
    except (MigrationError, OSError, ValueError, KeyError, TypeError) as error:
        report = {"schemaVersion": 1, "success": False, "error": str(error)}
        print("MIGRATION SOURCE FAILED:", error, file=sys.stderr)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
