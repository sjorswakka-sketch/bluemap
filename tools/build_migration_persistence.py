#!/usr/bin/env python3
"""Check frozen save/settings rules and native oracle copies without either engine.

The recorder fixtures are created from scratch under verified UUID user folders.
No personal save or configuration file is read by this source contract builder.
"""
from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
from pathlib import Path
import re

from record_migration_saves import validate_float64_bits
from verify_unity_package import PERSISTENCE_DETAIL_CHECKS

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = "migration/phase-09/source-contracts.json"
SOURCE_PATHS = (
    "project.godot", "scripts/core/game_state.gd", "scripts/core/world_atlas.gd",
    "scripts/core/equipment.gd", "scripts/core/appearance.gd", "scripts/core/professions.gd",
    "scripts/core/homestead.gd", "scripts/core/coastal_home.gd", "scripts/core/stockroom.gd",
    "scripts/core/personal_home.gd", "scripts/core/yard.gd", "scripts/core/progression.gd",
    "scripts/core/input_manager.gd", "scripts/core/lang.gd", "scripts/core/sound.gd",
)
ORACLES = {
    "save": ("migration/phase-09/save-oracle.json",
             "unity/Assets/BlueMapPersistence/Resources/BlueMapSaveOracle.json"),
    "settings": ("migration/phase-09/settings-oracle.json",
                 "unity/Assets/BlueMapPersistence/Runtime/Settings/Resources/BlueMapPersistenceSettingsOracle.json"),
}
SAVE_CASE_IDS = {
    "empty_old_save", "legacy_flags_presence", "explicit_visits_no_inference",
    "negative_day_and_fractionals", "unknown_future_fields", "nested_invalid_types",
    "farms_and_production", "house_invalid_overlap", "yard_invalid_crop_overlap",
    "records_talk_and_stats", "gear_clothing_appearance", "profession_cooldowns",
    "bounded_storage", "current_full_roundtrip",
    "house_valid_custom", "house_invalid_identifier", "yard_valid_paths", "yard_all_stations_stored",
    "raw_version_object", "numeric_conversion", "exact_day_boundary", "malformed_nested_values",
    "json_integer_precision_positive", "json_integer_precision_negative",
}
SETTINGS_CASE_IDS = {
    "missing", "full_defaults", "legacy_conflicts", "physical_and_modifiers", "explicit_empty",
    "invalid_arrays", "oversized_and_duplicate", "unknown_multiline", "malformed", "unsupported_locale",
}
SETTINGS_ACTION_IDS = {
    "homestead", "move_up", "move_down", "move_left", "move_right", "technique", "attack", "bow",
    "interact", "dodge", "sprint", "potion", "menu", "crafting", "quests", "map",
    "wereld_prestaties", "wereld_beestenboek", "pause", "restart", "mute", "fullscreen",
}


class PersistenceDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise PersistenceDataError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def no_links(path):
    require(not any(p.is_symlink() or (hasattr(p, "is_junction") and p.is_junction())
                    for p in (path, *path.parents)), "Persistence source path is a symlink/junction")


def read(root, name):
    path = root / name
    no_links(path)
    require(path.is_file() and path.stat().st_size <= 16 * 1024 * 1024,
            "Missing/oversized phase-9 source: " + name)
    return path.read_bytes().replace(b"\r\n", b"\n")


def document(data, name):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON key: " + name)
            result[key] = value
        return result
    def constant(value):
        raise PersistenceDataError("Nonfinite JSON number: " + name)
    try:
        result = json.loads(data, object_pairs_hook=unique, parse_constant=constant)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise PersistenceDataError("Malformed JSON: " + name) from error
    require(isinstance(result, dict), "Expected JSON object: " + name)
    return result


def canonical(value):
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode()


def oracle_coverage(kind, value):
    require(value.get("personalSavesUsed") is False, "Oracle accessed existing saves")
    cases = value.get("cases")
    require(isinstance(cases, list) and all(isinstance(case, dict) for case in cases),
            "Missing oracle cases")
    ids = [case.get("id") for case in cases]
    expected = SAVE_CASE_IDS if kind == "save" else SETTINGS_CASE_IDS
    require(all(isinstance(name, str) for name in ids) and len(ids) == len(set(ids))
            and set(ids) == expected, "Oracle scenario IDs are missing or duplicated")
    if kind == "save":
        require(value.get("schema") == "bluemap.persistence.save.source-oracle.v1", "Unknown save oracle schema")
        require(value.get("float64Encoding") == "ieee754-binary64-little-endian-hex",
                "Save numeric representation is not exact")
        corrupt = value.get("corrupt")
        require(isinstance(corrupt, list) and len(corrupt) == 6
                and all(isinstance(row, dict) and set(row) == {"inputJson", "accepted"}
                        and isinstance(row["inputJson"], str) and row["accepted"] is False for row in corrupt)
                and len({row["inputJson"] for row in corrupt}) == 6,
                "Corrupt-save coverage is incomplete")
        for case in cases:
            require(isinstance(case.get("inputJson"), str) and isinstance(case.get("expected"), dict)
                    and type(case.get("useLoadPosition")) is bool, "Save fixture payload is incomplete")
            document(case["inputJson"], "generated save fixture")
        numeric = validate_float64_bits(value)
        require(numeric > 0 and isinstance(value.get("rules"), dict) and bool(value["rules"]),
                "Save exact numeric/rule coverage is missing")
        return {"saveScenarios": len(cases), "corruptSaves": len(corrupt), "exactNumericValues": numeric}
    require(value.get("schema") == "bluemap.settings-import.v1", "Unknown settings oracle schema")
    source_documents = 0
    for case in cases:
        docs, parse_ok, bindings = case.get("documents"), case.get("parseOk"), case.get("bindings")
        require(isinstance(docs, dict) and set(docs) == {"settings", "controls", "meta", "ng"}
                and isinstance(parse_ok, dict) and set(parse_ok) == set(docs)
                and all(type(flag) is bool for flag in parse_ok.values()), "Settings documents are incomplete")
        for raw in docs.values():
            require(raw is None or isinstance(raw, str), "Settings fixture is not base64 text")
            if raw is not None:
                try:
                    binary = base64.b64decode(raw, validate=True)
                    binary.decode("utf-8")
                except (binascii.Error, UnicodeError) as error:
                    raise PersistenceDataError("Invalid base64 UTF-8 settings fixture") from error
                require(len(binary) <= 4 * 1024 * 1024, "Settings fixture exceeds size bound")
                source_documents += 1
        require(isinstance(bindings, list) and len(bindings) == len(SETTINGS_ACTION_IDS)
                and {row.get("id") for row in bindings if isinstance(row, dict)} == SETTINGS_ACTION_IDS
                and all(isinstance(row, dict) and isinstance(row.get("bindings"), list) for row in bindings),
                "Settings action binding coverage is incomplete")
    return {"settingsScenarios": len(cases), "actionsPerScenario": len(SETTINGS_ACTION_IDS),
            "fixtureDocuments": source_documents}


def persistence_asset_guids(root):
    base = root / "unity/Assets/BlueMapPersistence"
    no_links(base)
    require(base.is_dir(), "Persistence asset directory is missing")
    owners = [base, *sorted(path for path in base.rglob("*") if path.suffix != ".meta")]
    known, result = set(), []
    for owner in owners:
        no_links(owner)
        require(owner.is_file() or owner.is_dir(), "Unsupported persistence asset")
        metadata = owner.with_name(owner.name + ".meta")
        text = read(root, metadata.relative_to(root).as_posix()).decode("utf-8-sig")
        guids = re.findall(r"^guid: ([0-9a-f]{32})$", text, re.M)
        require(len(guids) == 1 and len(re.findall(r"^guid:", text, re.M)) == 1 and guids[0] not in known,
                "Missing/duplicate persistence asset GUID: " + owner.relative_to(root).as_posix())
        require(("folderAsset: yes" in text) == owner.is_dir(), "Persistence folder metadata differs from owner")
        known.add(guids[0])
        result.append({"path": owner.relative_to(root).as_posix(), "guid": guids[0]})
    for metadata in base.rglob("*.meta"):
        require(metadata.with_suffix("").exists(), "Orphan persistence asset metadata")
    return result


def build_contract(root=ROOT):
    root = Path(root)
    baseline = document(read(root, "migration/reference/source-manifest.json"), "reference source manifest")
    by_name = {row["path"]: row for row in baseline["files"]}
    anchors = []
    for name in SOURCE_PATHS:
        data, frozen = read(root, name), by_name[name]
        require(sha(data) == frozen["sha256"] and len(data) == frozen["bytes"],
                "Preserved persistence source changed: " + name)
        anchors.append({"path": name, "bytes": len(data), "sha256": sha(data), "gitBlob": frozen["git_blob"]})
    oracles = []
    for kind, (source, target) in ORACLES.items():
        data = read(root, source)
        value = document(data, source)
        coverage = oracle_coverage(kind, value)
        require(read(root, target) == data, "Native oracle copy differs from original observations: " + kind)
        if kind == "save":
            hashes = value.get("sourceHashes")
            require(hashes == {name: by_name[name]["sha256"] for name in SOURCE_PATHS[1:12]},
                    "Save source hashes differ from frozen original")
        oracles.append({"kind": kind, "sourcePath": source, "resourcePath": target,
                        "bytes": len(data), "sha256": sha(data), "coverage": coverage})
    return {"schema": "bluemap.persistence.source-contracts.v1", "phase": 9,
            "baselineCommit": baseline["commit"], "baselineTree": baseline["tree"],
            "textEncoding": "UTF-8; CRLF normalized to LF as in committed Git text",
            "sourceAnchors": anchors, "oracles": oracles, "assetGuids": persistence_asset_guids(root),
            "requiredNativeChecks": sorted(PERSISTENCE_DETAIL_CHECKS),
            "enginesStarted": False, "personalSavesUsed": False}


def check(root=ROOT):
    contract = build_contract(root)
    require(read(Path(root), CONTRACT) == canonical(contract), "Stale/corrupt persistence source contracts")
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
        require(not args.report.exists(), "Persistence report already exists")
        require(not args.report.resolve().is_relative_to(ROOT), "Persistence report must be external to checkout")
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(canonical({"success": True, **contract}))
    print("MIGRATION PERSISTENCE DATA OK:", len(contract["sourceAnchors"]), "preserved sources,",
          len(contract["oracles"]), "exact oracle copies,", len(contract["assetGuids"]), "stable asset GUIDs")


if __name__ == "__main__":
    try:
        main()
    except (PersistenceDataError, OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit("MIGRATION PERSISTENCE DATA FAILED: " + str(error))
