#!/usr/bin/env python3
"""Verify the playable route's frozen rules, original art and native asset IDs.

This source-only contract never starts either engine or reads a player profile.
Actual Godot observations belong to the separate UUID-isolated recorders.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import math
from pathlib import Path
import re
import struct

from PIL import Image

from build_migration_player import document, canonical, no_links
from record_migration_route import validate_float64_bits
from verify_unity_package import ROUTE_DETAIL_CHECKS

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = "migration/phase-10/source-contracts.json"
SOURCE_PATHS = (
    "project.godot", "scripts/core/game_state.gd", "scripts/core/professions.gd",
    "scripts/core/progression.gd", "scripts/entities/chest.gd", "scripts/entities/route_npc.gd",
    "scripts/core/first_route.gd", "scripts/data/dialogue.gd", "scripts/data/npcs.gd",
    "scripts/data/quests.gd", "scripts/data/ext/beroepen.gd", "scripts/data/items.gd",
    "scripts/core/equipment.gd", "scripts/data/ext/uitrusting.gd",
    "scripts/entities/pickup.gd",
    "scripts/maps/village.gd", "scripts/maps/player_home.gd",
    "scripts/maps/forest_edge.gd", "scripts/maps/forest.gd",
)
ORACLE = "migration/phase-10/route-oracle.json"
RESOURCE = "unity/Assets/BlueMapRoute/Runtime/Model/Resources/BlueMapRouteOracle.json"
ART = "unity/Assets/BlueMapRoute/Runtime/Presentation/Resources/BlueMapRouteArt"
ASSETS = "unity/Assets/BlueMapRoute"
CASE_IDS = {
    "pim_accept", "pim_decline", "pim_cancel_unread", "bram_accept", "cat_wait_then_find",
    "cat_without_quest", "cat_panic", "cat_calm_interrupted", "pim_reward_once",
    "pim_reward_level", "pim_max_hearts", "chest_basic", "chest_owned_unique",
    "chest_partial_stack_refused", "chest_heart", "gather_active_cooldown",
    "gather_missing_tool", "gather_strong_tool", "gather_level_required", "gather_xp_cap",
    "rest_no_time_skip",
    "pickup_coin", "pickup_heart_full", "pickup_heart_hurt", "pickup_crystal", "pickup_item_full",
}
SOURCE_METHODS = {
    "scripts/core/game_state.gd::run_all", "scripts/core/game_state.gd::start_quest",
    "scripts/core/game_state.gd::finish_quest", "scripts/core/game_state.gd::full_rest",
    "scripts/core/professions.gd::gather", "scripts/entities/chest.gd::interact",
    "scripts/core/first_route.gd::npc_interact", "scripts/entities/route_npc.gd::update",
    "scripts/entities/pickup.gd::_collect",
}
MAPS = {"village", "player_home", "forest_edge", "forest"}
SAVE_FIELDS = {
    "version", "map", "pos", "hp", "coins", "inventory", "flags", "quests", "weapon", "visited_maps",
    "play_time", "kills", "meer", "day_time", "day_count", "kills_by", "rolls", "potions_drunk", "deaths",
    "boss_deaths", "talked", "achievements", "arena_records", "homestead", "coastal_storage", "stockroom",
    "personal_home", "yard", "professions", "hero_xp", "equipment", "appearance", "clothing", "ng_plus",
}


class RouteDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise RouteDataError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(root, name, *, binary=False):
    path = Path(root) / name
    no_links(path)
    require(path.is_file() and path.stat().st_size <= 32 * 1024 * 1024,
            "Missing/oversized phase-10 source: " + name)
    data = path.read_bytes()
    return data if binary else data.replace(b"\r\n", b"\n")


def oracle_coverage(value):
    require(value.get("schema") == "bluemap.route.source-oracle.v1", "Unknown route oracle schema")
    require(value.get("personalSavesUsed") is False, "Route oracle accessed existing saves")
    require(value.get("float64Encoding") == "ieee754-binary64-little-endian-hex",
            "Route oracle numeric observations are not exact")
    cases = value.get("cases")
    require(isinstance(cases, list) and all(isinstance(row, dict) for row in cases), "Missing route scenarios")
    ids = [row.get("id") for row in cases]
    require(len(ids) == len(set(ids)) and set(ids) == CASE_IDS, "Route scenario IDs are missing or duplicated")
    require(isinstance(value.get("sourceMethods"), list)
            and len(value["sourceMethods"]) == len(SOURCE_METHODS)
            and set(value["sourceMethods"]) == SOURCE_METHODS, "Route original method coverage is incomplete")
    catalogs = value.get("catalogs")
    required = {"resources", "skills", "items", "npcs", "dialogues", "quests", "gear", "slots", "bonusLimits"}
    require(isinstance(catalogs, dict) and set(catalogs) == required
            and all(isinstance(catalogs[name], dict) and catalogs[name]
                    for name in required), "Route original catalogs are incomplete")
    require(isinstance(value.get("newGame"), dict) and set(value["newGame"]) == SAVE_FIELDS,
            "Missing original new-game state fields")
    for row in cases:
        require(set(row) == {"id", "initial", "operations", "results", "expected", "expectedExact",
                             "dialogue", "choicesReady", "cat"}, "Route scenario fields are incomplete")
        require(all(isinstance(row[key], dict) for key in ("initial", "expected", "expectedExact", "cat"))
                and isinstance(row["operations"], list) and bool(row["operations"])
                and all(isinstance(op, list) and op and isinstance(op[0], str) for op in row["operations"])
                and isinstance(row["results"], list) and len(row["results"]) == len(row["operations"])
                and isinstance(row["dialogue"], str) and type(row["choicesReady"]) is bool,
                "Malformed route gameplay observations")
        require(all(SAVE_FIELDS <= set(row[key]) for key in ("initial", "expected", "expectedExact")),
                "Route state coverage omits original save fields")
    try:
        numeric = validate_float64_bits(cases)
    except (TypeError, ValueError, OverflowError) as error:
        raise RouteDataError("Invalid exact route numeric witness") from error
    require(numeric > 0, "Route exact numeric observations are missing")
    durations = value.get("durations")
    duration_ids = {"base", "worn_pack", "owned_not_worn", "negative_speed"}
    require(isinstance(durations, list) and len(durations) == len(duration_ids)
            and all(isinstance(row, dict) and isinstance(row.get("id"), str) for row in durations)
            and {row["id"] for row in durations} == duration_ids,
            "Original worn-gear duration coverage is incomplete")
    for row in durations:
        require(set(row) == {"id", "inventory", "equipment", "duration", "durationExact", "moveSpeed", "magnetRange"}
                and isinstance(row["inventory"], dict) and isinstance(row["equipment"], dict)
                and all(type(row[key]) in (int, float) and math.isfinite(row[key])
                        for key in ("duration", "moveSpeed", "magnetRange"))
                and isinstance(row["durationExact"], dict) and set(row["durationExact"]) == {"$f64"},
                "Malformed original worn-gear duration observation")
        try:
            encoded = bytes.fromhex(row["durationExact"]["$f64"])
        except (ValueError, TypeError) as error:
            raise RouteDataError("Invalid exact duration representation") from error
        # Godot's displayed JSON decimal can round one ULP even with full
        # precision. The authoritative value is the explicit binary64 witness.
        require(len(encoded) == 8 and math.isfinite(struct.unpack("<d", encoded)[0])
                and struct.unpack("<d", encoded)[0] > 0,
                "Invalid exact original duration numeric witness")
    return {"scenarios": len(cases), "originalMethods": len(SOURCE_METHODS), "exactNumericValues": numeric,
            "wornGearDurationCases": len(durations),
            "catalogEntries": {name: len(catalogs[name]) for name in sorted(required)}}


def route_art(root, baseline):
    index_path = ART + "/index.json"
    raw = read(root, index_path)
    value = document(raw, index_path)
    require(value.get("schemaVersion") == 1 and type(value["schemaVersion"]) is int
            and value.get("tilePixels") == 32 and value.get("alphaMode") == "premultiplied"
            and value.get("scenario") == "fresh_baseline" and value.get("clock") == 0
            and value.get("gameSaveAccessed") is False, "Original route art metadata is incomplete")
    source_files = value.get("sourceFiles")
    require(isinstance(source_files, dict) and bool(source_files), "Original route art source table is missing")
    for name, digest in source_files.items():
        require(isinstance(name, str) and name.startswith("res://"), "Unsafe route art source path")
        relative = name.removeprefix("res://")
        require(relative in baseline and sha(read(root, relative)) == digest == baseline[relative]["sha256"],
                "Original route drawing source differs from frozen baseline: " + relative)
    require(value.get("exporterSha256") == sha(read(root, "tools/migration_route_art.gd")),
            "Route drawing exporter identity changed")
    palettes = value.get("palettes")
    require(isinstance(palettes, dict) and set(palettes) == {"hair", "dye"}
            and all(isinstance(colors, list) and colors and all(isinstance(color, list) and len(color) == 4
                    and all(type(component) in (int, float) and math.isfinite(component)
                            and 0 <= component <= 1 for component in color) for color in colors)
                    for colors in palettes.values()), "Original appearance palettes are incomplete")
    rows, seen, names, maps = value.get("nodes"), set(), {"index.json"}, set()
    require(isinstance(rows, list) and bool(rows), "Original route drawing observations are missing")
    for row in rows:
        require(isinstance(row, dict) and row.get("mapId") in MAPS
                and isinstance(row.get("address"), str)
                and re.fullmatch(r"(?:ground|entities)/[0-9]+", row["address"]), "Unknown route drawing node")
        key = (row["mapId"], row["address"])
        require(key not in seen, "Duplicate original route drawing node")
        seen.add(key); maps.add(row["mapId"])
        filename = row.get("file", "")
        require(isinstance(filename, str) and re.fullmatch(r"node-[0-9a-f]{20}\.png", filename),
                "Unsafe route drawing filename")
        names.add(filename)
        data = read(root, ART + "/" + filename, binary=True)
        require(len(data) >= 33 and data[:8] == b"\x89PNG\r\n\x1a\n"
                and type(row.get("width")) is int and type(row.get("height")) is int
                and 0 < row["width"] <= 4096 and 0 < row["height"] <= 4096
                and struct.unpack_from(">II", data, 16) == (row["width"], row["height"])
                and type(row.get("bytes")) is int and row["bytes"] == len(data)
                and row.get("sha256") == sha(data), "Original route drawing pixels/size changed")
        with Image.open(io.BytesIO(data)) as image:
            require(image.format == "PNG" and image.size == (row["width"], row["height"])
                    and sha(image.convert("RGBA").tobytes()) == row.get("rgbaSha256"),
                    "Original route drawing RGBA pixels changed")
        require(row.get("script") in source_files and type(row.get("ground")) is bool
                and all(isinstance(row.get(key), list) and len(row[key]) == 2
                        and all(type(number) in (int, float) and math.isfinite(number)
                                for number in row[key]) for key in ("position", "offset")),
                "Original route drawing placement/source is incomplete")
    actual = {path.name for path in (Path(root) / ART).iterdir() if path.is_file() and path.suffix != ".meta"}
    require(actual == names and maps == MAPS, "Original route art file/map coverage differs")
    return {"indexPath": index_path, "sha256": sha(raw), "bytes": len(raw),
            "sourceScripts": len(source_files), "nodes": len(rows), "maps": sorted(maps)}


def asset_guids(root):
    base = Path(root) / ASSETS
    no_links(base)
    require(base.is_dir(), "Native route asset directory is missing")
    owners = [base, *sorted(path for path in base.rglob("*") if path.suffix != ".meta")]
    known, result = set(), []
    for owner in owners:
        no_links(owner)
        metadata = owner.with_name(owner.name + ".meta")
        text = read(root, metadata.relative_to(root).as_posix()).decode("utf-8-sig")
        matches = re.findall(r"^guid: ([0-9a-f]{32})$", text, re.M)
        require(len(matches) == 1 and len(re.findall(r"^guid:", text, re.M)) == 1 and matches[0] not in known,
                "Missing/duplicate route asset GUID: " + owner.relative_to(root).as_posix())
        require(("folderAsset: yes" in text) == owner.is_dir(), "Route folder metadata differs from its owner")
        known.add(matches[0]); result.append({"path": owner.relative_to(root).as_posix(), "guid": matches[0]})
    for metadata in base.rglob("*.meta"):
        require(metadata.with_suffix("").exists(), "Orphan route asset metadata")
    return result


def build_contract(root=ROOT):
    root = Path(root)
    baseline = document(read(root, "migration/reference/source-manifest.json"), "reference manifest")
    by_name = {row["path"]: row for row in baseline["files"]}
    anchors = []
    for name in SOURCE_PATHS:
        data, frozen = read(root, name), by_name[name]
        require(sha(data) == frozen["sha256"] and len(data) == frozen["bytes"],
                "Preserved route source changed: " + name)
        anchors.append({"path": name, "bytes": len(data), "sha256": sha(data), "gitBlob": frozen["git_blob"]})
    raw = read(root, ORACLE)
    coverage = oracle_coverage(document(raw, ORACLE))
    require(read(root, RESOURCE) == raw, "Native route oracle copy differs from original observations")
    return {"schema": "bluemap.route.source-contracts.v1", "phase": 10,
            "baselineCommit": baseline["commit"], "baselineTree": baseline["tree"],
            "textEncoding": "UTF-8; CRLF normalized to LF as in committed Git text",
            "tilePixels": 32, "sourceAnchors": anchors,
            "oracle": {"sourcePath": ORACLE, "resourcePath": RESOURCE, "sha256": sha(raw),
                       "bytes": len(raw), "coverage": coverage},
            "art": route_art(root, by_name), "assetGuids": asset_guids(root),
            "recorders": [{"path": name, "sha256": sha(read(root, name))} for name in
                          ("tools/migration_route_export.gd", "tools/record_migration_route.py",
                           "tools/migration_route_art.gd", "tools/record_migration_route_art.py")],
            "requiredNativeChecks": sorted(ROUTE_DETAIL_CHECKS), "enginesStarted": False, "personalSavesUsed": False}


def check(root=ROOT):
    contract = build_contract(root)
    require(read(Path(root), CONTRACT) == canonical(contract), "Stale/corrupt route source contracts")
    return contract


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    contract = check() if args.check else build_contract()
    if not args.check:
        target = ROOT / CONTRACT
        no_links(target); target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(canonical(contract))
    if args.report:
        no_links(args.report)
        require(not args.report.exists(), "Route report already exists")
        require(not args.report.resolve().is_relative_to(ROOT), "Route report belongs outside the checkout")
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(canonical({"success": True, **contract}))
    print("MIGRATION ROUTE DATA OK:", len(contract["sourceAnchors"]), "preserved sources,",
          contract["oracle"]["coverage"]["scenarios"], "original scenarios,", contract["art"]["nodes"], "original drawings")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit("MIGRATION ROUTE DATA FAILED: " + str(error))
