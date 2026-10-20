#!/usr/bin/env python3
"""Freeze all original area access observations, drawing placements and Unity IDs.

This portable check starts neither engine and never opens a player profile.
The separate recorders execute the preserved Godot methods in isolated copies.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import math
from pathlib import Path
import re

from PIL import Image

from build_migration_player import canonical, document, no_links
from build_migration_route import SAVE_FIELDS
from record_migration_world_access import validate_float64_bits
from verify_unity_package import WORLD_ACCESS_DETAIL_CHECKS

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = "migration/phase-11/source-contracts.json"
ORACLE = "migration/phase-11/world-access-oracle.json"
RESOURCE = "unity/Assets/BlueMapWorldAccess/Runtime/Model/Resources/BlueMapWorldAccessOracle.json"
ART = "unity/Assets/BlueMapWorldAccess/Presentation/Resources/BlueMapWorldArt"
ASSETS = "unity/Assets/BlueMapWorldAccess"
WORLD_INDEX = "migration/world/index.json"
INVENTORY = "migration/reference/maps-inventory.json"
SOURCE_PATHS = (
    "project.godot", "scripts/world.gd", "scripts/maps/registry.gd", "scripts/core/game_state.gd",
    "scripts/entities/gate.gd", "scripts/entities/portal.gd", "scripts/entities/diepte_gate.gd",
    "scripts/entities/diepte_seal.gd", "scripts/core/access_points.gd", "scripts/core/fast_travel.gd",
    "scripts/core/tides.gd", "scripts/entities/tide_cove.gd", "scripts/entities/living_scenery.gd",
    "scripts/entities/meer_kast.gd", "scripts/ui/coast_voyage.gd", "scripts/ui/coast_routes.gd",
    "scripts/data/arena.gd", "scripts/data/ext/boog.gd", "scripts/data/ext/echo.gd", "scripts/data/quests.gd",
    "scripts/core/regional_adventures.gd", "scripts/core/personal_home.gd", "scripts/core/opening.gd",
    "scripts/core/living_world.gd", "scripts/core/first_route.gd",
    "scripts/data/house_catalog.gd", "scripts/entities/house_furniture.gd", "scripts/entities/home_station.gd",
    "scripts/entities/coastal_workstation.gd", "scripts/ui/coastal_home_ui.gd", "scripts/data/coastal_craft_maps.gd",
)
RECORDERS = ("tools/migration_world_access_export.gd", "tools/record_migration_world_access.py",
             "tools/migration_world_art.gd", "tools/record_migration_world_art.py")
CASE_IDS = {
    "gate_no_key", "gate_key", "gate_open_not_interactable", "conditions_fresh",
    "conditions_iron_main", "conditions_both_targets", "boat_distance_0", "boat_distance_6400",
    "boat_distance_6401", "boat_forged_target",
    "seal_unearned", "seal_earned_timing", "tide_occupied_then_released",
    "world_legacy_migrations", "world_migrations_idempotent",
}
SOURCE_METHODS = {
    "world.spawn_fits", "world.safe_spawn_position", "portal.available", "gate.interact",
    "gate._refresh", "GameState.check", "coast_voyage.valid_source", "living_scenery.refresh",
    "tide_cove.sync", "meer_kast._clear_cells",
    "diepte_seal._process", "diepte_seal._open", "fast_travel._ring",
    "living_world.migrate", "regional_adventures.migrate", "first_route.migrate",
}


class WorldAccessDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise WorldAccessDataError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(root, name, *, binary=False):
    require(isinstance(name, str) and not name.startswith(("/", "\\"))
            and ".." not in name.split("/") and "\\" not in name, "Unsafe world-access source path")
    path = Path(root) / name
    no_links(path)
    require(path.is_file() and path.stat().st_size <= 64 * 1024 * 1024,
            "Missing/oversized phase-11 source: " + name)
    raw = path.read_bytes()
    return raw if binary else raw.replace(b"\r\n", b"\n")


def vector(value):
    return isinstance(value, list) and len(value) == 2 and all(
        type(number) in (int, float) and math.isfinite(number) for number in value)


def exact_shape(plain, exact):
    if isinstance(exact, dict) and set(exact) == {"$f64"}:
        return type(plain) in (int, float) and math.isfinite(plain)
    if isinstance(plain, dict):
        return isinstance(exact, dict) and set(plain) == set(exact) and all(
            exact_shape(value, exact[key]) for key, value in plain.items())
    if isinstance(plain, list):
        return isinstance(exact, list) and len(plain) == len(exact) and all(
            exact_shape(value, encoded) for value, encoded in zip(plain, exact))
    # Godot's displayed JSON decimal can round one ULP. Explicit bit witnesses
    # remain authoritative, so compare structure here and native values there.
    return type(plain) is type(exact) and plain == exact and type(plain) is not float


def world_reference(root):
    index = document(read(root, WORLD_INDEX), WORLD_INDEX)
    inventory = document(read(root, INVENTORY), INVENTORY)
    maps = {row["id"] for row in inventory["maps"]}
    require(len(maps) == len(inventory["maps"]) == inventory["map_count"] == 37,
            "Frozen original map registry coverage differs")
    descriptors = index.get("snapshots")
    require(isinstance(descriptors, list) and len(descriptors) == 162,
            "Frozen original world state coverage differs")
    keys = {(row["mapId"], row["scenarioId"]) for row in descriptors}
    require(len(keys) == len(descriptors) and {key[0] for key in keys} == maps,
            "Duplicate or missing original world snapshots")
    return index, inventory, maps, keys


def oracle_coverage(value, maps, snapshot_keys):
    require(value.get("schema") == "bluemap.world-access.source-oracle.v1"
            and value.get("tilePixels") == 32 and value.get("personalSavesUsed") is False
            and value.get("freshProcessRequired") is True and value.get("failures") == [],
            "World-access oracle identity/isolation is incomplete")
    rows = value.get("snapshots")
    require(isinstance(rows, list) and all(isinstance(row, dict) for row in rows),
            "World-access observations are missing")
    keys = [(row.get("map"), row.get("scenario")) for row in rows]
    require(len(keys) == len(set(keys)) and set(keys) == snapshot_keys,
            "World-access map/scenario coverage is missing or duplicated")
    totals = {name: 0 for name in ("portals", "gates", "boats", "arrivals", "probes")}
    exact_count = 0
    for row in rows:
        require(set(row) == {"map", "scenario", "state", "stateExact", *totals}
                and isinstance(row["state"], dict) and SAVE_FIELDS <= set(row["state"])
                and row["state"]["map"] == row["map"], "Incomplete original world state observations")
        require(exact_shape(row["state"], row["stateExact"]), "Original exact world state structure differs")
        try:
            count = validate_float64_bits(row["stateExact"])
        except (ValueError, TypeError, OverflowError) as error:
            raise WorldAccessDataError("Invalid exact world state numeric witness") from error
        require(count > 0, "Original exact world state numbers missing")
        exact_count += count
        for name in totals:
            require(isinstance(row[name], list) and all(isinstance(item, dict) for item in row[name]),
                    "Malformed original world-access observations")
            totals[name] += len(row[name])
        require(bool(row["arrivals"]) and bool(row["probes"]), "Original arrival/collision observations missing")
        arrivals = [item.get("name") for item in row["arrivals"]]
        require(all(isinstance(name, str) and name for name in arrivals)
                and len(arrivals) == len(set(arrivals)), "Duplicate original arrival names")
        for item in row["arrivals"]:
            require(set(item) == {"name", "nominal", "prepared", "resolved", "fits"}
                    and all(vector(item[key]) for key in ("nominal", "prepared", "resolved"))
                    and type(item["fits"]) is bool, "Malformed original safe arrival")
        for item in row["probes"]:
            require(set(item) == {"requested", "fits", "resolved"} and vector(item["requested"])
                    and vector(item["resolved"]) and type(item["fits"]) is bool,
                    "Malformed original collision probe")
        for item in row["portals"]:
            require(set(item) == {"to", "spawn", "rect", "requires", "available", "lockedText"}
                    and item["to"] in maps and isinstance(item["spawn"], str) and item["spawn"]
                    and isinstance(item["rect"], list) and len(item["rect"]) == 2
                    and all(vector(v) for v in item["rect"]) and all(n > 0 for n in item["rect"][1])
                    and isinstance(item["requires"], list) and type(item["available"]) is bool
                    and isinstance(item["lockedText"], str), "Malformed original portal condition/placement")
        for item in row["gates"]:
            require(set(item) == {"id", "blocked", "block_if", "key", "position"}
                    and isinstance(item["id"], str) and isinstance(item["key"], str)
                    and type(item["blocked"]) is bool and isinstance(item["block_if"], list)
                    and vector(item["position"]), "Malformed original keyed gate")
        for item in row["boats"]:
            require(set(item) == {"position", "spec"} and vector(item["position"])
                    and isinstance(item["spec"], dict), "Malformed original boat source")
    cases = value.get("cases")
    require(isinstance(cases, list) and all(isinstance(row, dict) for row in cases),
            "Original access behavior cases are missing")
    ids = [row.get("id") for row in cases]
    require(len(ids) == len(set(ids)) and CASE_IDS == set(ids),
            "Original access behavior IDs are missing or duplicated")
    for row in cases:
        require(set(row) == {"id", "initial", "initialExact", "operation", "operationExact",
                             "result", "resultExact", "expected", "expectedExact"}
                and isinstance(row["initial"], dict) and isinstance(row["expected"], dict)
                and SAVE_FIELDS <= set(row["initial"]) and SAVE_FIELDS <= set(row["expected"])
                and isinstance(row["operation"], dict) and isinstance(row["operation"].get("kind"), str),
                "Incomplete original gate/voyage behavior case")
        for name in ("initial", "operation", "result", "expected"):
            require(exact_shape(row[name], row[name + "Exact"]), "Original exact access case structure differs")
            try:
                exact_count += validate_float64_bits(row[name + "Exact"])
            except (ValueError, TypeError, OverflowError) as error:
                raise WorldAccessDataError("Invalid exact access case numeric witness") from error
    methods = value.get("sourceMethods")
    require(isinstance(methods, list) and all(isinstance(name, str) for name in methods)
            and len(methods) == len(set(methods)) and SOURCE_METHODS == set(methods),
            "Original world-access method coverage is incomplete")
    rings = value.get("rings")
    require(isinstance(rings, list) and len(rings) == 8, "Original safe-spawn ring observations missing")
    for radius, ring in enumerate(rings, 1):
        require(isinstance(ring, list) and len(ring) == 8 * radius and all(vector(v) for v in ring)
                and len({tuple(v) for v in ring}) == len(ring)
                and all(type(n) is int and abs(n) <= radius for v in ring for n in v)
                and all(max(abs(n) for n in v) == radius for v in ring),
                "Original safe-spawn ring is malformed")
    quests = value.get("quests")
    require(isinstance(quests, dict) and quests and all(isinstance(row, dict) for row in quests.values()),
            "Original quest progression metadata missing")
    return {"maps": len(maps), "snapshots": len(rows), "behaviorCases": len(cases),
            "caseIds": sorted(ids), "originalMethods": sorted(methods), "safeSpawnRings": len(rings),
            "quests": len(quests), "exactNumericValues": exact_count, **totals}


def world_art(root, baseline, index, maps, snapshot_keys):
    raw = read(root, ART + "/index.json")
    value = document(raw, ART + "/index.json")
    require(type(value.get("schemaVersion")) is int and value["schemaVersion"] == 1
            and value.get("tilePixels") == 32 and value.get("alphaMode") == "premultiplied"
            and value.get("clock") == 0 and value.get("gameSaveAccessed") is False,
            "Original world drawing identity/isolation is incomplete")
    expected = snapshot_keys - {(name, "fresh_baseline") for name in ("village", "player_home", "forest_edge", "forest")}
    descriptors = value.get("snapshots")
    require(isinstance(descriptors, list) and all(isinstance(row, dict) for row in descriptors),
            "Original drawing snapshot table is missing")
    keys = [(row.get("mapId"), row.get("scenarioId")) for row in descriptors]
    require(len(keys) == len(set(keys)) and set(keys) == expected,
            "Original world drawing state variants are missing or duplicated")
    sources = value.get("sourceFiles")
    require(isinstance(sources, dict) and bool(sources), "Original world drawing sources missing")
    for name, digest in sources.items():
        require(isinstance(name, str) and name.startswith("res://"), "Unsafe original drawing source")
        relative = name.removeprefix("res://")
        frozen = baseline.get(relative, {}).get("sha256", index.get("exporterSources", {}).get(name))
        require(frozen is not None and digest == frozen == sha(read(root, relative)),
                "Original world drawing source differs from frozen reference: " + relative)
    require(value.get("exporterSha256") == sha(read(root, "tools/migration_world_art.gd")),
            "World drawing exporter identity changed")
    palettes = value.get("palettes")
    require(isinstance(palettes, dict) and set(palettes) == {"hair", "dye"}
            and all(isinstance(colors, list) and colors and all(isinstance(color, list) and len(color) == 4
                    and all(type(n) in (int, float) and math.isfinite(n) and 0 <= n <= 1 for n in color)
                    for color in colors) for colors in palettes.values()), "Original appearance palettes missing")
    snapshot_rows = {(row["mapId"], row["scenarioId"]): row for row in index["snapshots"]}
    scenes, textures, identities, observed_maps, node_counts = {}, {}, set(), set(), {}
    rows = value.get("nodes")
    require(isinstance(rows, list) and rows, "Original world drawing nodes missing")
    for row in rows:
        require(isinstance(row, dict) and (row.get("mapId"), row.get("scenarioId")) in expected
                and isinstance(row.get("address"), str)
                and re.fullmatch(r"(?:ground|entities)/[0-9]+", row["address"]), "Unknown original world drawing node")
        key = (row["mapId"], row["scenarioId"])
        identity = (*key, row["address"])
        require(identity not in identities, "Duplicate original world drawing address")
        identities.add(identity); observed_maps.add(row["mapId"])
        node_counts[key] = node_counts.get(key, 0) + 1
        if key not in scenes:
            descriptor = snapshot_rows[key]
            source = read(root, "migration/world/" + descriptor["path"])
            require(sha(source) == descriptor["sha256"] and len(source) == descriptor["bytes"],
                    "Frozen original world snapshot changed")
            scene = document(source, descriptor["path"])["scene"]
            scenes[key] = {"/".join(str(part) for part in node["address"]): node for node in scene}
        original = scenes[key].get(row["address"])
        require(original is not None and original["script"] == row.get("script")
                and row.get("script") in sources and vector(row.get("position"))
                and vector(row.get("offset")) and type(row.get("ground")) is bool,
                "Original world drawing source/address/placement incomplete")
        position = [float(component["value"]) for component in original["globalTransform"]["origin"]["values"]]
        require(row["position"] == position, "Original world drawing object moved")
        filename = row.get("file", "")
        require(isinstance(filename, str) and re.fullmatch(r"node-[0-9a-f]{20}\.png", filename),
                "Unsafe world drawing filename")
        require(type(row.get("width")) is int and type(row.get("height")) is int
                and 0 < row["width"] <= 4096 and 0 < row["height"] <= 4096,
                "Invalid original world drawing dimensions")
        if filename not in textures:
            png = read(root, ART + "/" + filename, binary=True)
            require(len(png) >= 33 and png[:8] == b"\x89PNG\r\n\x1a\n", "Original world drawing is not PNG")
            with Image.open(io.BytesIO(png)) as image:
                require(image.format == "PNG", "Original world drawing is not PNG")
                textures[filename] = (len(png), sha(png), image.size, sha(image.convert("RGBA").tobytes()))
        size, digest, dimensions, rgba = textures[filename]
        require(row.get("bytes") == size and row.get("sha256") == digest
                and dimensions == (row["width"], row["height"]) and row.get("rgbaSha256") == rgba,
                "Original world drawing pixels/hash/dimensions changed")
    files = {path.name for path in (Path(root) / ART).iterdir() if path.is_file() and path.suffix != ".meta"}
    require(files == {"index.json", *textures} and observed_maps == maps,
            "Original world drawing file/map coverage differs")
    require(all(type(row.get("drawNodes")) is int and row["drawNodes"] == node_counts.get(
                    (row["mapId"], row["scenarioId"]), 0) for row in descriptors),
            "Original world drawing snapshot counts differ")
    return {"indexPath": ART + "/index.json", "bytes": len(raw), "sha256": sha(raw),
            "sourceScripts": len(sources), "snapshots": len(descriptors), "nodes": len(rows),
            "textures": len(textures), "maps": sorted(observed_maps)}


def asset_guids(root):
    base = Path(root) / ASSETS
    no_links(base)
    require(base.is_dir(), "Native world-access assets missing")
    owners = [base, *sorted(path for path in base.rglob("*") if path.suffix != ".meta")]
    known, rows = set(), []
    for owner in owners:
        no_links(owner)
        meta = owner.with_name(owner.name + ".meta")
        text = read(root, meta.relative_to(root).as_posix()).decode("utf-8-sig")
        matches = re.findall(r"^guid: ([0-9a-f]{32})$", text, re.M)
        require(len(matches) == 1 and len(re.findall(r"^guid:", text, re.M)) == 1 and matches[0] not in known,
                "Missing/duplicate world-access asset GUID: " + owner.relative_to(root).as_posix())
        require(("folderAsset: yes" in text) == owner.is_dir(), "World-access folder metadata differs from owner")
        known.add(matches[0]); rows.append({"path": owner.relative_to(root).as_posix(), "guid": matches[0]})
    for meta in base.rglob("*.meta"):
        require(meta.with_suffix("").exists(), "Orphan world-access asset metadata")
    return rows


def build_contract(root=ROOT):
    root = Path(root)
    baseline = document(read(root, "migration/reference/source-manifest.json"), "original reference")
    by_name = {row["path"]: row for row in baseline["files"]}
    index, inventory, maps, keys = world_reference(root)
    paths = sorted({*SOURCE_PATHS, *(row["base_source"].removeprefix("res://") for row in inventory["maps"])})
    anchors = []
    for name in paths:
        frozen, data = by_name[name], read(root, name)
        require(sha(data) == frozen["sha256"] and len(data) == frozen["bytes"],
                "Preserved world-access source changed: " + name)
        anchors.append({"path": name, "bytes": len(data), "sha256": sha(data), "gitBlob": frozen["git_blob"]})
    raw = read(root, ORACLE)
    coverage = oracle_coverage(document(raw, ORACLE), maps, keys)
    require(read(root, RESOURCE) == raw, "Native world-access oracle differs from original observations")
    return {"schema": "bluemap.world-access.source-contracts.v1", "phase": 11,
            "baselineCommit": baseline["commit"], "baselineTree": baseline["tree"],
            "textEncoding": "UTF-8; CRLF normalized to LF as in committed Git text", "tilePixels": 32,
            "sourceAnchors": anchors, "oracle": {"sourcePath": ORACLE, "resourcePath": RESOURCE,
            "bytes": len(raw), "sha256": sha(raw), "coverage": coverage},
            "art": world_art(root, by_name, index, maps, keys), "assetGuids": asset_guids(root),
            "recorders": [{"path": name, "sha256": sha(read(root, name))} for name in RECORDERS],
            "requiredNativeChecks": sorted(WORLD_ACCESS_DETAIL_CHECKS),
            "enginesStarted": False, "personalSavesUsed": False}


def check(root=ROOT):
    contract = build_contract(root)
    require(read(Path(root), CONTRACT) == canonical(contract), "Stale/corrupt world-access source contracts")
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
        require(not args.report.exists(), "World-access report already exists")
        require(not args.report.resolve().is_relative_to(ROOT), "World-access report belongs outside checkout")
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(canonical({"success": True, **contract}))
    print("MIGRATION WORLD ACCESS DATA OK:", len(contract["sourceAnchors"]), "preserved sources,",
          contract["oracle"]["coverage"]["snapshots"], "observed states,", contract["art"]["nodes"], "drawings")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit("MIGRATION WORLD ACCESS DATA FAILED: " + str(error))
