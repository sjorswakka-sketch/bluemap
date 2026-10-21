#!/usr/bin/env python3
"""Bind original inventory/storage observations and loaded loot to frozen source.

This portable verifier starts neither engine and never reads a player profile.
The separate recorder executes actual Godot methods in verified UUID storage.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re

from build_migration_player import canonical, document, no_links
from build_migration_route import SAVE_FIELDS
from migration_data_codec import decode
from migration_world_data import decode_wire, WireDictionary, WireValue
from record_migration_inventory_state import normalize_exact_mirrors, validate_float64_bits
from verify_unity_package import INVENTORY_DETAIL_CHECKS

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = "migration/phase-12/source-contracts.json"
ORACLE = "migration/phase-12/inventory-state-oracle.json"
RESOURCE = "unity/Assets/BlueMapInventory/Runtime/Model/Resources/BlueMapInventoryOracle.json"
ASSETS = "unity/Assets/BlueMapInventory"
REGISTRY = "migration/reference/maps-inventory.json"
WORLD_INDEX = "migration/world/index.json"
ITEMS = "migration/portable/catalogs/items.json"
QUESTS = "migration/portable/catalogs/quests.json"
RECORDERS = ("tools/migration_inventory_export.gd", "tools/record_migration_inventory_state.py",
             "tools/migration_route_export.gd", "tools/migration_world_scenarios.gd")
SOURCE_PATHS = (
    "project.godot", "scenes/main.tscn", "scripts/world.gd", "scripts/maps/registry.gd",
    "scripts/core/game_state.gd", "scripts/core/stockroom.gd", "scripts/core/coastal_home.gd",
    "scripts/core/equipment.gd", "scripts/core/professions.gd", "scripts/core/movement.gd",
    "scripts/core/lang.gd", "scripts/entities/chest.gd", "scripts/entities/pickup.gd",
    "scripts/entities/stock_chest.gd", "scripts/entities/coastal_workstation.gd",
    "scripts/ui/stock_ui.gd", "scripts/ui/coastal_home_ui.gd", "scripts/ui/item_receipts.gd",
    "translations/en.po",
)
SOURCE_METHODS = {
    "scripts/core/game_state.gd::room", "scripts/core/game_state.gd::give",
    "scripts/core/game_state.gd::take", "scripts/core/game_state.gd::add_coins",
    "scripts/core/game_state.gd::full_text", "scripts/core/game_state.gd::_refresh_quests",
    "scripts/core/game_state.gd::use_potion", "scripts/core/professions.gd::use_reason",
    "scripts/core/professions.gd::use_item", "scripts/entities/chest.gd::interact",
    "scripts/entities/pickup.gd::_collect", "scripts/entities/pickup.gd::_process",
    "scripts/entities/pickup.gd::magnet_range", "scripts/core/stockroom.gd::normalize",
    "scripts/core/stockroom.gd::nearby_kind", "scripts/core/stockroom.gd::room",
    "scripts/core/stockroom.gd::movable", "scripts/core/stockroom.gd::transfer",
    "scripts/core/stockroom.gd::bulk", "scripts/core/stockroom.gd::consume",
    "scripts/core/stockroom.gd::ids", "scripts/core/stockroom.gd::toggle_favorite",
    "scripts/core/coastal_home.gd::normalize", "scripts/maps/registry.gd::get_map",
    "scripts/world.gd::load_map", "tools/migration_world_scenarios.gd::project",
}
BASE_CASE_IDS = {
    "bag_unlimited_and_unknown", "coins_clamp", "take_reconciles_gear", "take_reconciles_clothing",
    "heart_container_heals", "use_missing_or_tool", "full_text_owned", "chest_owned_coat",
    "chest_aggregate_refused", "chest_aggregate_exact_fit", "chest_hearts_capped", "chest_owned_only",
    "pickup_heart_full", "pickup_arrow_full", "magnet_full_heart_remains", "magnet_full_ammo_remains",
    "magnet_outside_range", "magnet_no_early_collection", "magnet_owned_not_worn", "magnet_worn_pack",
    "normalize_invalid_home", "normalize_invalid_coast", "normalize_home_slot_limit",
    "normalize_coast_slot_limit", "storage_wrong_map", "storage_not_in_game",
    "home_transfer_roundtrip", "home_cap_and_partial", "withdraw_ammo_limit", "coast_material_only",
    "coast_twelve_species", "bulk_existing_skip_favorites", "bulk_materials_only",
    "consume_bag_then_home", "consume_preflight_no_loss", "consume_no_remote_supply",
    "favorites_toggle_known_only", "reach_home_17600", "reach_home_17601",
    "reach_village_17600", "reach_village_17601", "reach_coast_9600", "reach_coast_9601",
    *("query_" + language + "_sort_" + str(order) for language in ("nl", "en") for order in range(4)),
    *("pickup_" + name for name in ("coin", "heart", "arrow", "potion", "prof_branch", "hs_grape",
                                   "crystal_bos", "ruin_key", "gear_bronze_helm")),
    *("magnet_" + name for name in ("coin", "heart", "arrow", "prof_branch", "hs_grape")),
}
_SCENE_PROJECTIONS = {}


class InventoryDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise InventoryDataError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(root, name):
    require(isinstance(name, str) and name and not name.startswith(("/", "\\"))
            and "\\" not in name and ".." not in name.split("/"), "Unsafe inventory source path")
    path = Path(root) / name
    no_links(path)
    require(path.is_file() and path.stat().st_size <= 64 * 1024 * 1024,
            "Missing/oversized phase-12 source: " + name)
    return path.read_bytes().replace(b"\r\n", b"\n")


def vector(value):
    return isinstance(value, list) and len(value) == 2 and all(
        type(number) in (int, float) and math.isfinite(number) for number in value)


def plain_wire(value):
    if isinstance(value, WireDictionary):
        return {key: plain_wire(child) for key, child in value.items()}
    if isinstance(value, WireValue):
        require(value.type in ("Vector2", "Vector2i"), "Unexpected typed loot value")
        return list(value.value)
    if isinstance(value, list):
        return [plain_wire(child) for child in value]
    return value


def scene_projection(raw):
    digest = sha(raw)
    if digest in _SCENE_PROJECTIONS:
        return _SCENE_PROJECTIONS[digest]
    scene = document(raw, "frozen original scene").get("scene")
    require(isinstance(scene, list), "Original loaded scene missing")
    result = {"chests": [], "pickups": [], "stores": []}
    scripts = {"res://scripts/entities/chest.gd", "res://scripts/entities/pickup.gd",
               "res://scripts/entities/stock_chest.gd", "res://scripts/entities/coastal_workstation.gd"}
    for node in scene:
        script = node.get("script")
        if script not in scripts:
            continue
        fields = decode_wire(node["fields"])
        if script.endswith("coastal_workstation.gd") and fields.get("obj").get("role") != "storage":
            continue
        address = node["address"]
        require(isinstance(address, list) and len(address) == 2 and address[0] == "entities"
                and type(address[1]) is int and address[1] >= 0, "Original loot node address is incomplete")
        position = [float(part["value"]) for part in node["localTransform"]["origin"]["values"]]
        row = {"position": position, "sourceAddress": [1, address[1]]}
        if script.endswith("/chest.gd"):
            row.update(uniqueKey=fields.get("unique_key"), contents=plain_wire(fields.get("contents")),
                       opened=fields.get("opened"))
            result["chests"].append(row)
        elif script.endswith("/pickup.gd"):
            row.update(uniqueKey=fields.get("unique_key"), item=fields.get("item"))
            result["pickups"].append(row)
        else:
            row.update(kind="home" if script.endswith("/stock_chest.gd") else "coast")
            result["stores"].append(row)
    if len(_SCENE_PROJECTIONS) >= 162:
        _SCENE_PROJECTIONS.clear()
    _SCENE_PROJECTIONS[digest] = result
    return result


def original_references(root):
    registry_raw = read(root, REGISTRY)
    registry = document(registry_raw, REGISTRY)
    maps = registry.get("maps")
    require(isinstance(maps, list) and len(maps) == registry.get("map_count") == 37
            and len({row["id"] for row in maps}) == 37, "Original map registry coverage differs")
    expected = {"chests": [], "pickups": []}
    for row in maps:
        for index, spec in enumerate(row["registry_snapshot"]["objects"]):
            if spec["type"] not in ("chest", "pickup"):
                continue
            key = spec["type"] + ":" + row["id"] + ":" + str(index)
            expected[spec["type"] + "s"].append({"map": row["id"], "index": index, "spec": spec,
                "uniqueKey": key if spec["type"] == "chest" or spec.get("unique", False) else ""})
    items_raw = read(root, ITEMS)
    items = decode(document(items_raw, ITEMS))
    require(isinstance(items, dict) and items.get("count") == len(items.get("entries", [])),
            "Original item inventory is incomplete")
    item_entries = {row["id"]: row["value"] for row in items["entries"]}
    require(len(item_entries) == len(items["entries"]), "Duplicate original item ID")
    quests_raw = read(root, QUESTS)
    quests = decode(document(quests_raw, QUESTS))
    require(isinstance(quests, dict) and quests.get("count") == len(quests.get("entries", [])),
            "Original quest inventory is incomplete")
    quest_ids = {row["id"] for row in quests["entries"]}
    require(len(quest_ids) == len(quests["entries"]), "Duplicate original quest ID")
    profession_source = read(root, "scripts/core/professions.gd").decode("utf-8")
    declaration = re.search(r"^const BASE_CONSUMABLES\s*:?=\s*(\[[^\n]+\])", profession_source, re.M)
    require(declaration is not None, "Original base consumable declaration missing")
    base_consumables = json.loads(declaration[1])
    require(isinstance(base_consumables, list) and all(isinstance(name, str) for name in base_consumables),
            "Invalid original consumable declaration")
    consumables = set(base_consumables) | {row["id"] for row in items["entries"]
        if row["value"].get("type") == "use" and any(source.get("path") ==
            "res://scripts/data/ext/forest_food_species.gd" for source in row["sources"])}
    index_raw = read(root, WORLD_INDEX)
    index = document(index_raw, WORLD_INDEX)
    rows = index.get("snapshots")
    require(isinstance(rows, list) and len(rows) == 162
            and len({(row["mapId"], row["scenarioId"]) for row in rows}) == 162,
            "Original world snapshots missing or duplicated")
    scenes, snapshots = {}, []
    for row in rows:
        raw = read(root, "migration/world/" + row["path"])
        require(sha(raw) == row["sha256"] and len(raw) == row["bytes"], "Frozen original loot scene changed")
        key = (row["mapId"], row["scenarioId"])
        scenes[key] = {"map": key[0], "scenario": key[1], **scene_projection(raw)}
        snapshots.append({key: row[key] for key in ("mapId", "scenarioId", "path", "bytes", "sha256")})
    return {"maps": maps, "items": item_entries, "quests": quest_ids, "consumables": consumables,
            **expected, "scenes": scenes,
            "hashes": [{"path": name, "bytes": len(raw), "sha256": sha(raw)}
                       for name, raw in ((REGISTRY, registry_raw), (ITEMS, items_raw),
                                         (QUESTS, quests_raw), (WORLD_INDEX, index_raw))],
            "snapshots": snapshots}


def oracle_coverage(value, reference):
    require(value.get("schema") == "bluemap.inventory-state.source-oracle.v1"
            and value.get("personalSavesUsed") is False
            and value.get("float64Encoding") == "ieee754-binary64-little-endian-hex"
            and value.get("orderedInputEncoding") == "dictionary-pairs-and-exact-f64-v1",
            "Inventory oracle identity, isolation or numeric/order encoding differs")
    require(isinstance(value.get("newGame"), dict) and set(value["newGame"]) == SAVE_FIELDS,
            "Original new-game fields are incomplete")
    catalogs = value.get("catalogs")
    require(isinstance(catalogs, dict) and set(catalogs) ==
            {"items", "quests", "gear", "bonusLimits", "names", "consumables", "professionsDefaults"}
            and all(isinstance(catalogs[name], dict) and catalogs[name]
                    for name in catalogs if name != "consumables")
            and isinstance(catalogs["consumables"], list) and catalogs["consumables"]
            and all(isinstance(name, str) for name in catalogs["consumables"])
            and len(catalogs["consumables"]) == len(set(catalogs["consumables"])),
            "Original inventory catalogs are incomplete")
    require(set(catalogs["items"]) == set(reference["items"]), "Original item IDs missing or invented")
    require(set(catalogs["quests"]) == reference["quests"], "Original quest IDs missing or invented")
    require(set(catalogs["consumables"]) == reference["consumables"],
            "Original consumable IDs missing or invented")
    for item_id, item in catalogs["items"].items():
        frozen = reference["items"][item_id]
        require(isinstance(item, dict) and all(item.get(key) == frozen.get(key)
                and type(item.get(key)) is type(frozen.get(key)) for key in ("name", "type", "max", "icon", "sheet")),
                "Original item identity, limit or icon differs: " + item_id)
    require(set(catalogs["names"]) == {"nl", "en"} and all(
            isinstance(names, dict) and set(names) == set(reference["items"])
            and all(isinstance(name, str) and name for name in names.values())
            for names in catalogs["names"].values()), "Original NL/EN item names incomplete")
    require(all(item in catalogs["items"] for item in catalogs["consumables"]), "Unknown source consumable")
    for kind in ("chests", "pickups"):
        rows = value.get(kind)
        require(isinstance(rows, list) and all(isinstance(row, dict) for row in rows),
                "Original canonical loot missing")
        require(canonical(sorted(rows, key=lambda r: (r["map"], r["index"]))) ==
                canonical(sorted(reference[kind], key=lambda r: (r["map"], r["index"]))),
                "Original canonical " + kind + " coverage or rewards differ")
    methods = value.get("sourceMethods")
    require(isinstance(methods, list) and all(isinstance(name, str) for name in methods)
            and len(methods) == len(set(methods))
            and set(methods) == SOURCE_METHODS, "Original inventory source method coverage differs")
    cases = value.get("cases")
    require(isinstance(cases, list) and all(isinstance(row, dict) for row in cases), "Missing inventory cases")
    ids = [row.get("id") for row in cases]
    require(all(isinstance(name, str) and re.fullmatch(r"[a-z0-9_]{1,100}", name) for name in ids),
            "Invalid inventory behavior case ID")
    expected = {*BASE_CASE_IDS,
                *("bag_cap_" + key for key, item in catalogs["items"].items() if item.get("max", 0) > 0),
                *("original_chest_" + row["map"] + "_" + str(row["index"]) for row in reference["chests"]),
                *(prefix + key for prefix in ("use_hurt_", "use_full_") for key in catalogs["consumables"])}
    require(len(ids) == len(set(ids)) and set(ids) == expected,
            "Inventory behavior case IDs missing, duplicated or invented")
    for row in cases:
        require(set(row) == {"id", "initial", "initialExact", "initialOrdered", "operations",
                            "operationsExact", "operationsOrdered", "results", "resultsExact",
                            "expected", "expectedExact"}, "Incomplete exact/ordered inventory case")
        require(isinstance(row["initial"], dict) and isinstance(row["expected"], dict)
                and SAVE_FIELDS <= set(row["initial"]) and SAVE_FIELDS <= set(row["expected"]),
                "Inventory case lost original save fields")
        require(isinstance(row["operations"], list) and row["operations"]
                and isinstance(row["results"], list) and len(row["operations"]) == len(row["results"])
                and all(isinstance(op, list) and op and isinstance(op[0], str) for op in row["operations"]),
                "Inventory operation/result observations incomplete")
    try:
        normalize_exact_mirrors(value)
        exact_count = validate_float64_bits(value)
    except (TypeError, ValueError, OverflowError) as error:
        raise InventoryDataError("Invalid exact or ordered inventory observations: " + str(error)) from error
    loaded = value.get("loadedSceneLoot")
    require(isinstance(loaded, list) and all(isinstance(row, dict) for row in loaded),
            "Original loaded loot observations missing")
    keys = [(row.get("map"), row.get("scenario")) for row in loaded]
    require(len(keys) == len(set(keys)) and set(keys) == set(reference["scenes"]),
            "Original loaded loot map/scenario coverage differs")
    for key, row in zip(keys, loaded):
        require(canonical(row) == canonical(reference["scenes"][key]),
                "Original loaded loot address, position, rewards or storage differ: " + "/".join(key))
    return {"items": len(catalogs["items"]), "quests": len(catalogs["quests"]),
            "consumables": len(catalogs["consumables"]), "cases": len(cases),
            "caseIds": sorted(ids), "methods": sorted(methods), "maps": len(reference["maps"]),
            "canonicalChests": len(value["chests"]), "canonicalPickups": len(value["pickups"]),
            "loadedSnapshots": len(loaded), "loadedChests": sum(len(r["chests"]) for r in loaded),
            "loadedPickups": sum(len(r["pickups"]) for r in loaded),
            "loadedStores": sum(len(r["stores"]) for r in loaded),
            "exactFloat64Values": exact_count, "dictionaryInputOrderPreserved": True}


def asset_guids(root):
    base = Path(root) / ASSETS
    no_links(base)
    require(base.is_dir(), "Native inventory assets missing")
    owners = [base, *sorted(path for path in base.rglob("*") if path.suffix != ".meta")]
    known, rows = set(), []
    for owner in owners:
        no_links(owner)
        text = read(root, owner.with_name(owner.name + ".meta").relative_to(root).as_posix()).decode("utf-8-sig")
        found = re.findall(r"^guid: ([0-9a-f]{32})$", text, re.M)
        require(len(found) == 1 and len(re.findall(r"^guid:", text, re.M)) == 1 and found[0] not in known,
                "Missing/duplicate inventory asset GUID: " + owner.relative_to(root).as_posix())
        require(("folderAsset: yes" in text) == owner.is_dir(), "Inventory folder metadata differs from owner")
        known.add(found[0]); rows.append({"path": owner.relative_to(root).as_posix(), "guid": found[0]})
    require(all(meta.with_suffix("").exists() for meta in base.rglob("*.meta")), "Orphan inventory metadata")
    return rows


def build_contract(root=ROOT):
    root = Path(root)
    manifest = document(read(root, "migration/reference/source-manifest.json"), "original source manifest")
    baseline = {row["path"]: row for row in manifest["files"]}
    reference = original_references(root)
    paths = sorted({*SOURCE_PATHS, *(row["base_source"].removeprefix("res://") for row in reference["maps"]),
                    *(name for name in baseline if name.startswith("scripts/data/") and name.endswith(".gd"))})
    anchors = []
    for name in paths:
        frozen, raw = baseline[name], read(root, name)
        require(sha(raw) == frozen["sha256"] and len(raw) == frozen["bytes"],
                "Preserved inventory source changed: " + name)
        anchors.append({"path": name, "bytes": len(raw), "sha256": sha(raw), "gitBlob": frozen["git_blob"]})
    raw = read(root, ORACLE)
    coverage = oracle_coverage(document(raw, ORACLE), reference)
    require(read(root, RESOURCE) == raw, "Native inventory oracle differs from original observations")
    return {"schema": "bluemap.inventory-state.source-contracts.v1", "phase": 12,
            "baselineCommit": manifest["commit"], "baselineTree": manifest["tree"],
            "textEncoding": "UTF-8; CRLF normalized to LF as in committed Git text",
            "sourceAnchors": anchors, "oracle": {"sourcePath": ORACLE, "resourcePath": RESOURCE,
            "bytes": len(raw), "sha256": sha(raw), "coverage": coverage},
            "frozenReferenceFiles": reference["hashes"], "worldSnapshots": reference["snapshots"],
            "recorders": [{"path": name, "sha256": sha(read(root, name))} for name in RECORDERS],
            "assetGuids": asset_guids(root), "requiredNativeChecks": sorted(INVENTORY_DETAIL_CHECKS),
            "enginesStarted": False, "personalSavesUsed": False}


def check(root=ROOT):
    contract = build_contract(root)
    require(read(Path(root), CONTRACT) == canonical(contract), "Stale/corrupt inventory source contracts")
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
        require(not args.report.exists(), "Inventory report already exists")
        require(not args.report.resolve().is_relative_to(ROOT), "Inventory report belongs outside checkout")
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(canonical({"success": True, **contract}))
    print("MIGRATION INVENTORY DATA OK:", len(contract["sourceAnchors"]), "preserved sources,",
          contract["oracle"]["coverage"]["items"], "items,", contract["oracle"]["coverage"]["cases"], "cases")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit("MIGRATION INVENTORY DATA FAILED: " + str(error))
