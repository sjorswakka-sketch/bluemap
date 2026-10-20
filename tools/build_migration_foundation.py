#!/usr/bin/env python3
"""Owned, offline foundation package: exact frozen phase-4/5 bytes in gzip.

The package is reference data, not a save importer or executed game scripts.
Writes only BlueMapFoundation/Resources and never opens personal saves.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = "unity/Assets/BlueMapFoundation/Resources/BlueMapFoundation"
ANCHORS = {
    "migration/world/index.json": "d986a9a8ad3a03e2c5a5b9fb98e0622dbca76f950f52d35d756f611410af4743",
    "migration/portable/manifest.json": "0dd2d3ea38a30cde9ce449d460c4be6fef84d4023d883f96c88cc1e4a79d12ab",
    "migration/phase-05/runtime-identities.json": "78e174b9862238a66c57165e3f517aa0f660435d388cb40866fa81a9a8b0639a",
}


class FoundationError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise FoundationError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe_name(name):
    require(isinstance(name, str) and bool(re.fullmatch(r"[a-zA-Z0-9_./-]+", name))
            and not PurePosixPath(name).is_absolute() and ".." not in name.split("/")
            and PurePosixPath(name).as_posix() == name
            and name.endswith(".json"), "Unsafe foundation document path")
    return name


def no_links(path):
    require(not any(p.is_symlink() or (hasattr(p, "is_junction") and p.is_junction())
                    for p in (path, *path.parents)), "Foundation path is a symlink/junction")


def read(root, name, *, normalize_git_text=True):
    safe_name(name)
    path = root / name
    no_links(path)
    require(path.is_file() and path.stat().st_size <= 128 * 1024 * 1024, "Missing/oversized foundation source")
    data = path.read_bytes()
    return data.replace(b"\r\n", b"\n") if normalize_git_text else data


def json_document(data, name):
    """Do not let JSON silently discard duplicate keys or accept NaN/Infinity."""
    def object_pairs(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON key in foundation source: " + name)
            result[key] = value
        return result
    def invalid_constant(value):
        raise FoundationError("Nonfinite JSON number in foundation source: " + name)
    try:
        return json.loads(data, object_pairs_hook=object_pairs, parse_constant=invalid_constant)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise FoundationError("Malformed JSON foundation source: " + name) from error


def canonical(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + "\n").encode("utf-8")


def guid(unity_path):
    return sha(("bluemap-foundation:" + unity_path).encode())[:32]


def meta(unity_path, folder=False):
    return ("fileFormatVersion: 2\nguid: " + guid(unity_path) + "\n"
            + ("folderAsset: yes\n" if folder else "") + "DefaultImporter:\n  externalObjects: {}\n"
            "  userData: \n  assetBundleName: \n  assetBundleVariant: \n").encode()


def compress(data):
    # Fix the gzip OS byte as well as mtime; Python/zlib versions must not invent provenance.
    result = bytearray(gzip.compress(data, compresslevel=9, mtime=0))
    result[9] = 255
    return bytes(result)


def build_documents(root=ROOT):
    root = Path(root)
    source = {}
    for name, checksum in ANCHORS.items():
        data = read(root, name)
        require(sha(data) == checksum, "Frozen foundation anchor changed: " + name)
        source[name] = data
    world = json_document(source["migration/world/index.json"], "world index")
    portable = json_document(source["migration/portable/manifest.json"], "portable manifest")
    require(isinstance(world, dict) and isinstance(portable, dict), "Invalid foundation source manifests")
    require(all(isinstance(world.get(key), list) for key in ("shared", "snapshots", "scenarios"))
            and isinstance(portable.get("documents"), list), "Invalid foundation document lists")
    require(world["units"] == {"tilePixels": 32, "yAxis": "down"}, "World scale changed")
    require(len(world["snapshots"]) == 162 and len(world["scenarios"]) == 59, "World coverage changed")
    inputs = []
    for prefix, rows in (("migration/world/", world["shared"] + world["snapshots"]),
                         ("migration/portable/", portable["documents"])):
        for row in rows:
            require(isinstance(row, dict) and isinstance(row.get("path"), str), "Invalid foundation source descriptor")
            safe_name(row["path"])
            inputs.append((prefix + row["path"], row))
    for name, row in inputs:
        require(name not in source, "Duplicate foundation source document: " + name)
        require(isinstance(row.get("bytes"), int) and not isinstance(row["bytes"], bool)
                and row["bytes"] > 0 and isinstance(row.get("sha256"), str)
                and bool(re.fullmatch(r"[0-9a-f]{64}", row["sha256"])), "Invalid foundation source descriptor")
        data = read(root, name)
        require(len(data) == row["bytes"] and sha(data) == row["sha256"], "Corrupt frozen foundation source: " + name)
        source[name] = data
    docs, descriptors = {}, []
    for name, data in sorted(source.items()):
        relative = name.removeprefix("migration/").removesuffix(".json")
        resource = "BlueMapFoundation/" + relative
        target = RESOURCE + "/" + relative + ".bytes"
        packed = compress(data)
        docs[target] = packed
        docs[target + ".meta"] = meta(target.removeprefix("unity/"))
        descriptors.append({"sourcePath": name, "resourcePath": resource, "bytes": len(data),
                            "sha256": sha(data), "gzipBytes": len(packed), "gzipSha256": sha(packed)})
    manifest = {"schema": "bluemap.foundation.package.v1", "phase": 7,
                "baselineCommit": world["baselineCommit"], "baselineTree": world["baselineTree"],
                "tilePixels": 32, "sourceYAxis": "down", "unityYAxis": "up", "maps": 37,
                "snapshots": 162, "scenarios": 59, "sourceFiles": len(source),
                "maxDocumentBytes": 128 * 1024 * 1024, "documents": descriptors,
                "scope": "Immutable source snapshots; rules and gameplay are ported explicitly by subsystem."}
    # This file belongs to the original-Godot oracle recorder. Copy its bytes, not
    # a reserialized or newline-normalized interpretation of its observations.
    oracle = read(root, "migration/phase-07/state-oracle.json", normalize_git_text=False)
    require(isinstance(json_document(oracle, "state oracle"), dict), "Invalid foundation state oracle")
    oracle_target = RESOURCE + "/state-oracle.json"
    docs[oracle_target] = oracle
    docs[oracle_target + ".meta"] = meta(oracle_target.removeprefix("unity/"))
    manifest["stateOracle"] = {"sourcePath": "migration/phase-07/state-oracle.json", "resourcePath": "BlueMapFoundation/state-oracle", "bytes": len(oracle), "sha256": sha(oracle)}
    docs[RESOURCE + "/manifest.json"] = canonical(manifest)
    docs[RESOURCE + "/manifest.json.meta"] = meta((RESOURCE + "/manifest.json").removeprefix("unity/"))
    # The World folder belongs to this exporter; State/Session remain separate owners.
    folders = set()
    for name in tuple(docs):
        parent = PurePosixPath(name).parent
        while str(parent).startswith("unity/Assets/BlueMapFoundation/Resources"):
            folders.add(str(parent)); parent = parent.parent
    for name in sorted(folders):
        docs[name + ".meta"] = meta(name.removeprefix("unity/"), folder=True)
    return docs, manifest


def apply(root, docs, write=False):
    root = Path(root)
    # Validate every destination before the first write.
    for name in docs:
        require((name.startswith(RESOURCE + "/") or name == RESOURCE + ".meta"
                 or name == "unity/Assets/BlueMapFoundation/Resources.meta")
                and PurePosixPath(name).as_posix() == name and ".." not in name.split("/"), "Unexpected export target")
        no_links(root / name)
        require(not (root / name).is_dir(), "Foundation output is a directory: " + name)
        require(all(not p.exists() or p.is_dir() for p in (root / name).parents), "Foundation output parent is not a directory")
    package = root / RESOURCE
    no_links(package)
    require(not package.exists() or package.is_dir(), "Foundation resource root is not a directory")
    expected_folders = {str(parent) for name in docs for parent in PurePosixPath(name).parents}
    existing = set()
    for path in package.rglob("*"):
        no_links(path)
        name = path.relative_to(root).as_posix()
        if path.is_dir():
            require(name in expected_folders, "Unexpected extra directory in foundation resources")
        else:
            existing.add(name)
    require(not (existing - set(docs)), "Unexpected extra files in foundation resources")
    for name, data in docs.items():
        path = root / name
        if write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        else:
            require(path.is_file(), "Missing foundation output: " + name)
            actual = path.read_bytes()
            if path.suffix in {".json", ".meta"} and name != RESOURCE + "/state-oracle.json":
                actual = actual.replace(b"\r\n", b"\n")
            require(actual == data, "Stale/corrupt foundation output: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--write", action="store_true")
    action.add_argument("--check", action="store_true")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    docs, manifest = build_documents(args.root)
    apply(args.root, docs, args.write)
    report = {"status": "success", "schema": manifest["schema"], "files": len(docs),
              "maps": 37, "snapshots": 162, "scenarios": 59, "sourceFiles": manifest["sourceFiles"],
              "sourceBytes": sum(x["bytes"] for x in manifest["documents"]),
              "gzipBytes": sum(x["gzipBytes"] for x in manifest["documents"]),
              "manifestSha256": sha(docs[RESOURCE + "/manifest.json"])}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(canonical(report))
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
