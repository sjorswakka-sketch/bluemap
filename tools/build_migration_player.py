#!/usr/bin/env python3
"""Check phase-8 source contracts and oracle copies without starting either engine.

The two recorders own their original-engine observations and Resource copies.
This tool records their content identities and the frozen source anchors, then
checks those same bytes, coverage and stable Unity GUIDs on every platform.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

from record_migration_player_motion import validate_float64_bits
from verify_unity_package import PLAYER_DETAIL_CHECKS

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = "migration/phase-08/source-contracts.json"
SOURCE_PATHS = (
    "project.godot", "scripts/core/input_manager.gd", "scripts/entities/player.gd",
    "scripts/ui/crosshair.gd", "scripts/core/movement.gd", "scripts/core/game_state.gd",
    "scripts/core/equipment.gd", "scripts/data/tiles.gd",
)
ORACLES = {
    "input": ("migration/phase-08/input-oracle.json",
              "unity/Assets/BlueMapPlayer/Runtime/Input/Resources/BlueMapPlayerInputOracle.json"),
    "motion": ("migration/phase-08/motion-oracle.json",
               "unity/Assets/BlueMapPlayer/Resources/BlueMapPlayerMotionOracle.json"),
}


class PlayerDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise PlayerDataError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def no_links(path):
    require(not any(p.is_symlink() or (hasattr(p, "is_junction") and p.is_junction())
                    for p in (path, *path.parents)), "Player source path is a symlink/junction")


def read(root, name):
    path = root / name
    no_links(path)
    require(path.is_file() and path.stat().st_size <= 16 * 1024 * 1024,
            "Missing/oversized phase-8 source: " + name)
    # Git text checkouts may use CRLF. The real disposable build always uses
    # canonical Git blob bytes; LF hashes therefore agree with Linux CI.
    return path.read_bytes().replace(b"\r\n", b"\n")


def document(data, name):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON key: " + name)
            result[key] = value
        return result
    def constant(value):
        raise PlayerDataError("Nonfinite JSON number: " + name)
    try:
        result = json.loads(data, object_pairs_hook=unique, parse_constant=constant)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise PlayerDataError("Malformed JSON: " + name) from error
    require(isinstance(result, dict), "Expected JSON object: " + name)
    return result


def canonical(value):
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode()


def oracle_coverage(kind, value):
    require(value.get("personalSavesUsed") is False, "Oracle accessed existing saves")
    if kind == "motion":
        require(value.get("schema") == "bluemap.player.motion.source-oracle.v1", "Unknown motion oracle schema")
        counts = {key: len(value.get(key, [])) for key in ("stamina", "surfaces", "equipment", "motions", "rolls")}
        require(counts == {"stamina": 26, "surfaces": 83, "equipment": 8, "motions": 15, "rolls": 4}
                and isinstance(value.get("transition"), dict), "Motion oracle coverage is incomplete")
        counts["exactNumericValues"] = validate_float64_bits(value)
        counts["transitions"] = 1
        return counts
    require(value.get("schema") == "bluemap.player-input.v1", "Unknown input oracle schema")
    defaults, vectors = value.get("defaults"), value.get("vectors")
    require(isinstance(defaults, list) and len(defaults) == 36 and isinstance(vectors, list) and len(vectors) == 16,
            "Input oracle coverage is incomplete")
    ids = [row.get("id") for row in defaults if isinstance(row, dict)]
    require(len(ids) == 36 and len(set(ids)) == 36 and all(isinstance(name, str) and name for name in ids),
            "Input action IDs are missing or duplicated")
    require(all(isinstance(row.get("bindings"), list) for row in defaults), "Input action bindings are missing")
    bindings = sum(len(row["bindings"]) for row in defaults)
    require(bindings == 86, "Input source binding coverage is incomplete")
    require(all(isinstance(row, dict) and set(row) == {"raw", "deadzone", "expected"}
                and isinstance(row["raw"], list) and len(row["raw"]) == 2
                and isinstance(row["expected"], list) and len(row["expected"]) == 2 for row in vectors),
            "Malformed circular deadzone oracle vector")
    return {"actions": len(defaults), "bindings": bindings, "circularDeadzoneVectors": len(vectors)}


def player_asset_guids(root):
    base = root / "unity/Assets/BlueMapPlayer"
    no_links(base)
    require(base.is_dir(), "Player asset directory is missing")
    owners = [base, *sorted(path for path in base.rglob("*") if path.suffix != ".meta")]
    known, result = set(), []
    for owner in owners:
        no_links(owner)
        require(owner.is_file() or owner.is_dir(), "Unsupported player asset")
        metadata = owner.with_name(owner.name + ".meta")
        text = read(root, metadata.relative_to(root).as_posix()).decode("utf-8-sig")
        guids = re.findall(r"^guid: ([0-9a-f]{32})$", text, re.M)
        require(len(guids) == 1 and len(re.findall(r"^guid:", text, re.M)) == 1 and guids[0] not in known,
                "Missing/duplicate player asset GUID: " + owner.relative_to(root).as_posix())
        require(("folderAsset: yes" in text) == owner.is_dir(), "Player folder metadata differs from owner")
        known.add(guids[0])
        result.append({"path": owner.relative_to(root).as_posix(), "guid": guids[0]})
    for metadata in base.rglob("*.meta"):
        require(metadata.with_suffix("").exists(), "Orphan player asset metadata")
    return result


def build_contract(root=ROOT):
    root = Path(root)
    baseline = document(read(root, "migration/reference/source-manifest.json"), "reference source manifest")
    by_name = {row["path"]: row for row in baseline["files"]}
    anchors = []
    for name in SOURCE_PATHS:
        data, frozen = read(root, name), by_name[name]
        require(sha(data) == frozen["sha256"] and len(data) == frozen["bytes"],
                "Preserved player source changed: " + name)
        anchors.append({"path": name, "bytes": len(data), "sha256": sha(data), "gitBlob": frozen["git_blob"]})
    oracles = []
    for kind, (source, target) in ORACLES.items():
        data = read(root, source)
        coverage = oracle_coverage(kind, document(data, source))
        require(read(root, target) == data, "Native oracle copy differs from original observations: " + kind)
        oracles.append({"kind": kind, "sourcePath": source, "resourcePath": target,
                        "bytes": len(data), "sha256": sha(data), "coverage": coverage})
    return {"schema": "bluemap.player.source-contracts.v1", "phase": 8,
            "baselineCommit": baseline["commit"], "baselineTree": baseline["tree"],
            "textEncoding": "UTF-8; CRLF normalized to LF as in committed Git text",
            "tilePixels": 32, "sourceYAxis": "down", "unityYAxis": "up",
            "sourceAnchors": anchors, "oracles": oracles, "assetGuids": player_asset_guids(root),
            "requiredNativeChecks": sorted(PLAYER_DETAIL_CHECKS),
            "enginesStarted": False, "personalSavesUsed": False}


def check(root=ROOT):
    contract = build_contract(root)
    require(read(Path(root), CONTRACT) == canonical(contract), "Stale/corrupt player source contracts")
    return contract


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    contract = check() if args.check else build_contract()
    if not args.check:
        target = ROOT / CONTRACT
        no_links(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(canonical(contract))
    if args.report:
        no_links(args.report)
        require(not args.report.exists(), "Player report already exists")
        require(not args.report.resolve().is_relative_to(ROOT), "Player report must be external to checkout")
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(canonical({"success": True, **contract}))
    print("MIGRATION PLAYER DATA OK:", len(contract["sourceAnchors"]), "preserved sources,",
          len(contract["oracles"]), "exact oracle copies,", len(contract["assetGuids"]), "stable asset GUIDs")


if __name__ == "__main__":
    try:
        main()
    except (PlayerDataError, OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit("MIGRATION PLAYER DATA FAILED: " + str(error))
