#!/usr/bin/env python3
"""Freeze stable identities from the existing Godot reference inventories.

This is an identity contract, not a runtime world export or a save converter.
Namespaces are structured arrays; IDs are kept byte-for-byte, never generated
from translated labels, hashes, scene names, filtered slots, or joined strings.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
SCHEMA = "bluemap.migration.identity.v1"
SCOPE = "registry_identity_contract_not_phase5_runtime_export"


class IdentityError(ValueError):
    pass


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise IdentityError(message)


def _canonical(value: object) -> bytes:
    try:
        return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
                          allow_nan=False).encode("utf-8")
    except (ValueError, TypeError, UnicodeError) as error:
        raise IdentityError("Identity input must contain finite, portable JSON values") from error


def _digest(value: object) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


def _id(value: object, context: str) -> str:
    _require(isinstance(value, str) and bool(value) and "\0" not in value,
             f"Missing or invalid string identity: {context}")
    return value


def _index(value: object, context: str) -> int:
    _require(type(value) is int and value >= 0, f"Invalid preserved index: {context}")
    return value


def _entry_index(entry: dict) -> int | None:
    indices = []
    if "source_index" in entry:
        indices.append(_index(entry["source_index"], "catalog source_index"))
    value = entry.get("value")
    if isinstance(value, dict) and "source_index" in value:
        indices.append(_index(value["source_index"], "catalog value.source_index"))
    _require(not indices or all(index == indices[0] for index in indices),
             "Catalog entry contains inconsistent original indices")
    return indices[0] if indices else None


def _resource_family(resource_id: str) -> str:
    for family in ("trail", "winter", "forestfood"):
        if resource_id.startswith(family + ":"):
            return family
    return "explicit_legacy_or_custom"


def build_identity_registry(content: dict, maps: dict, save_contract: dict) -> dict:
    """Build a deterministic, namespaced registry without loading an engine/save."""
    _require(isinstance(content, dict) and isinstance(maps, dict) and isinstance(save_contract, dict),
             "Identity inputs must be JSON objects")
    input_digests = {"content": _digest(content), "maps": _digest(maps),
                     "saveContract": _digest(save_contract)}
    _require(content.get("schema") == "bluemap.migration.content-inventory.v1" and
             maps.get("schema") == "bluemap.migration.maps-inventory.v1",
             "Unsupported source inventory schema")
    _require(content.get("failures") == [] and maps.get("not_phase5_runtime_export") is True,
             "Reference inventories failed or misrepresent their registry-only scope")
    _require(content.get("source_fingerprint") == maps.get("source_fingerprint") and
             re.fullmatch(r"[0-9a-f]{64}", str(content.get("source_fingerprint", ""))) is not None,
             "Content and map inventories have different source fingerprints")
    _require(save_contract.get("contract_version") == 1, "Unsupported save contract version")
    catalogs = content.get("catalogs")
    _require(isinstance(catalogs, dict) and bool(catalogs), "Catalog identity inventory is missing")
    catalog_result, ordered_catalogs = {}, []
    catalog_id_sets = {}
    total_catalog_entries = 0
    for name, catalog in catalogs.items():
        _id(name, "catalog namespace")
        _require(isinstance(catalog, dict) and isinstance(catalog.get("entries"), list),
                 f"Malformed catalog: {name}")
        entries = catalog["entries"]
        _require(type(catalog.get("count")) is int and catalog["count"] == len(entries),
                 f"Catalog count differs from its identities: {name}")
        seen, records, indices = set(), [], []
        for entry in entries:
            _require(isinstance(entry, dict), f"Malformed entry in {name}")
            entry_id = _id(entry.get("id"), name)
            _require(entry_id not in seen, f"Duplicate identity in catalog {name}: {entry_id}")
            seen.add(entry_id)
            _require(isinstance(entry.get("sources"), list) and bool(entry["sources"]),
                     f"Missing identity provenance: {name}/{entry_id}")
            record = {"namespace": ["catalog", name], "id": entry_id,
                      "sources": copy.deepcopy(entry["sources"]), "entryFingerprint": _digest(entry)}
            source_index = _entry_index(entry)
            if source_index is not None:
                record["sourceIndex"] = source_index
            indices.append(source_index)
            records.append(record)
        if any(index is not None for index in indices):
            _require(all(index is not None for index in indices) and
                     sorted(indices) == list(range(len(entries))),
                     f"Catalog indices were removed, duplicated or renumbered: {name}")
            by_index = sorted(records, key=lambda item: item["sourceIndex"])
            ordered_catalogs.append({"namespace": ["catalog", name],
                                     "identityKind": catalog.get("identity", "source_array_index"),
                                     "entries": [{"index": item["sourceIndex"], "id": item["id"],
                                                  "entryFingerprint": item["entryFingerprint"]}
                                                 for item in by_index]})
        if catalog.get("identity") == "ordered_palette_index":
            _require(all(item["id"] == str(item.get("sourceIndex")) for item in records),
                     f"Palette identity differs from the saved original index: {name}")
        catalog_result[name], catalog_id_sets[name] = records, seen
        total_catalog_entries += len(records)

    declarations, declaration_seen = [], set()
    raw_declarations = content.get("declarations")
    _require(isinstance(raw_declarations, list), "Source declaration identities are missing")
    for declaration in raw_declarations:
        _require(isinstance(declaration, dict) and isinstance(declaration.get("source"), dict),
                 "Malformed source declaration")
        source = declaration["source"]
        path, constant = _id(source.get("path"), "declaration source"), _id(source.get("constant"), "constant")
        namespace = ["declaration", path, constant]
        key = (path, constant)
        _require(key not in declaration_seen, "Duplicate source declaration namespace")
        declaration_seen.add(key)
        kind, ids, value = declaration.get("kind"), declaration.get("ids"), declaration.get("value")
        _require(isinstance(ids, list), "Declaration identity order is missing")
        records = []
        if kind == "ordered_array":
            _require(isinstance(value, list) and len(value) == len(ids), "Ordered declaration length changed")
            for index, (declared, element) in enumerate(zip(ids, value)):
                _require(isinstance(declared, dict) and type(declared.get("index")) is int and
                         declared["index"] == index and _canonical(declared.get("value")) == _canonical(element),
                         "Ordered declaration has a changed or renumbered source index")
                records.append({"namespace": namespace, "id": index, "sourceIndex": index,
                                "value": copy.deepcopy(element), "valueFingerprint": _digest(element)})
        elif kind == "dictionary":
            _require(isinstance(value, dict) and len(ids) == len(value) and
                     len(set(_id(item, "declaration key") for item in ids)) == len(ids) and
                     set(ids) == set(value), "Declaration keys are missing or duplicated")
            for order, entry_id in enumerate(ids):
                records.append({"namespace": namespace, "id": entry_id, "sourceOrder": order,
                                "valueFingerprint": _digest(value[entry_id])})
        else:
            raise IdentityError("Unsupported source declaration identity kind")
        declarations.append({"namespace": namespace, "kind": kind, "source": copy.deepcopy(source),
                             "entries": records, "declarationFingerprint": _digest(declaration)})

    modules = content.get("modules")
    _require(isinstance(modules, list), "Content module order is missing")
    module_paths = set()
    for index, module in enumerate(modules):
        _require(isinstance(module, dict) and type(module.get("index")) is int and
                 module["index"] == index, "Content module order was renumbered")
        module_path = _id(module.get("path"), "module path")
        _require(module_path not in module_paths, "Content module appears twice")
        module_paths.add(module_path)

    map_rows = maps.get("maps")
    _require(isinstance(map_rows, list) and type(maps.get("map_count")) is int and
             maps["map_count"] == len(map_rows), "Map inventory count differs from map identities")
    map_ids = [_id(item.get("id"), "map") for item in map_rows if isinstance(item, dict)]
    _require(len(map_ids) == len(map_rows) and len(set(map_ids)) == len(map_ids), "Duplicate or malformed map ID")
    _require(set(map_ids) == catalog_id_sets.get("maps"), "Map catalog and map identity inventory disagree")
    _require(save_contract.get("baseline", {}).get("map_count") == len(map_rows),
             "Save contract map count does not match inventory")
    map_records, resource_instances = [], []
    cooldown_ids, altar_keys = set(), set()
    slot_count = disabled_count = appended_count = altar_count = 0
    authored_count = 0

    def add_resource(resource_id: str, obj: dict, map_id: str, origin: str,
                     index: int | None, source: object) -> None:
        _require(resource_id not in cooldown_ids, f"Duplicate global profession cooldown ID: {resource_id}")
        cooldown_ids.add(resource_id)
        _require(obj.get("type") == "profession_resource" and obj.get("id") == resource_id,
                 "Profession resource ID/type differs from its recorded identity")
        kind = _id(obj.get("kind"), "resource kind")
        _require(kind in catalog_id_sets.get("resources", set()), "Unknown profession resource kind")
        resource_instances.append({"namespace": ["profession_cooldown"], "id": resource_id,
                                   "mapId": map_id, "origin": origin, "kind": kind,
                                   "family": _resource_family(resource_id), "registryIndex": index,
                                   "finalRuntimeIndex": None, "source": copy.deepcopy(source),
                                   "objectFingerprint": _digest(obj)})

    for map_row in map_rows:
        map_id = map_row["id"]
        snapshot, slots = map_row.get("registry_snapshot"), map_row.get("object_slots")
        _require(isinstance(snapshot, dict) and isinstance(snapshot.get("objects"), list) and
                 isinstance(slots, list) and len(slots) == len(snapshot["objects"]),
                 f"Map slot array differs from its complete registry objects: {map_id}")
        objects = snapshot["objects"]
        _require(map_row.get("name") == snapshot.get("name") and isinstance(map_row.get("name"), str),
                 "Map display name differs from reference snapshot")
        base_source = _id(map_row.get("base_source"), "map base source")
        spawns = snapshot.get("spawns")
        _require(isinstance(spawns, dict), "Map spawn identity scope is missing")
        slot_records, map_altars, authored_ids = [], [], set()
        for index, (slot, obj) in enumerate(zip(slots, objects)):
            _require(isinstance(slot, dict) and isinstance(obj, dict), "Malformed map object slot")
            _require(type(slot.get("index")) is int and slot["index"] == index,
                     "Map object slots were reordered, filtered, removed or renumbered")
            kind = _id(obj.get("type"), "object type")
            _require(kind in catalog_id_sets.get("object_types", set()), "Unknown map object type")
            enabled = obj.get("enabled", True)
            _require(type(enabled) is bool and type(slot.get("enabled")) is bool and
                     enabled == slot["enabled"], "Disabled slot state changed")
            authored_id = obj.get("id")
            _require(slot.get("authored_id") == authored_id and slot.get("type") == kind,
                     "Slot identity differs from its original object")
            if authored_id is not None:
                _id(authored_id, "authored object ID")
                _require((kind, authored_id) not in authored_ids, "Duplicate authored object ID in its map/type scope")
                authored_ids.add((kind, authored_id))
                authored_count += 1
            legacy_key = f"{kind}:{map_id}:{index}"
            _require(slot.get("legacy_slot_key") == legacy_key, "Legacy type:map:index key changed")
            source = slot.get("source")
            _require(isinstance(source, dict) and type(source.get("object_index")) is int and
                     source["object_index"] == index and source.get("base_map") == base_source,
                     "Slot provenance no longer describes the original array position")
            record = {"namespace": ["map_registry_slot", map_id], "id": index, "index": index,
                      "type": kind, "enabled": enabled, "authoredId": authored_id,
                      "authoredIdNamespace": ["map_object", map_id, kind] if authored_id is not None else None,
                      "legacySlotKey": legacy_key, "legacyKeyRole": "candidate_object_key_not_universal_persistence",
                      "finalRuntimeIndex": None, "source": copy.deepcopy(source),
                      "objectFingerprint": _digest(obj)}
            slot_records.append(record)
            slot_count += 1
            disabled_count += not enabled
            if kind == "profession_resource":
                _require(authored_id is not None, "Registry resource has no explicit cooldown identity")
                add_resource(authored_id, obj, map_id, "registry", index, source)
            if kind == "savepoint":
                pos = obj.get("pos")
                _require(isinstance(pos, list) and len(pos) == 2 and
                         all(type(coordinate) is int for coordinate in pos), "Altar needs exact tile coordinates")
                discovery_key = f"altaar_{map_id}_{pos[0]}_{pos[1]}"
                _require(discovery_key not in altar_keys, "Duplicate altar discovery key")
                altar_keys.add(discovery_key)
                requested_spawn = obj.get("spawn", "altar")
                _id(requested_spawn, "altar spawn")
                map_altars.append({"namespace": ["altar_discovery"], "id": discovery_key,
                                   "mapId": map_id, "tile": copy.deepcopy(pos), "registryIndex": index,
                                   "legacyDiscoveryKey": discovery_key, "enabled": enabled,
                                   "name": obj.get("name", map_row["name"]), "requestedSpawn": requested_spawn,
                                   "travelSpawn": requested_spawn if requested_spawn in spawns else "start",
                                   "arrivalTile": copy.deepcopy(spawns.get(requested_spawn)),
                                   "arrivalStatus": "authored_spawn" if requested_spawn in spawns else
                                                    "nearest_free_tile_requires_phase5_runtime_validation",
                                   "source": {"keyFunction": "scripts/core/fast_travel.gd:altar_key",
                                              "runtimeUse": "scripts/entities/savepoint.gd:discovery_key"}})
                altar_count += 1
        appended = map_row.get("post_registry_legacy_resources")
        _require(isinstance(appended, list), "Appended legacy resource identities are missing")
        appended_records = []
        for append_order, resource in enumerate(appended):
            _require(isinstance(resource, dict) and isinstance(resource.get("value"), dict) and
                     isinstance(resource.get("source"), dict), "Malformed appended resource")
            resource_id = _id(resource.get("id"), "appended resource ID")
            add_resource(resource_id, resource["value"], map_id, "post_registry_legacy_append",
                         None, resource["source"])
            appended_records.append({"namespace": ["profession_cooldown"], "id": resource_id,
                                     "appendOrder": append_order, "registryIndex": None,
                                     "finalRuntimeIndex": None, "source": copy.deepcopy(resource["source"]),
                                     "objectFingerprint": _digest(resource["value"])})
            appended_count += 1
        map_records.append({"namespace": ["catalog", "maps"], "id": map_id,
                            "name": map_row["name"], "baseSource": base_source,
                            "registrySnapshotFingerprint": _digest(snapshot), "slots": slot_records,
                            "spawns": [{"namespace": ["map_spawn", map_id], "id": _id(name, "spawn"),
                                        "tile": copy.deepcopy(tile)} for name, tile in spawns.items()],
                            "postRegistryResources": appended_records, "altars": map_altars})
    _require(maps.get("registry_object_slots") == slot_count and
             maps.get("legacy_resource_count") == appended_count,
             "Map aggregate counts differ from preserved slots/resources")

    savegame = save_contract.get("savegame")
    _require(isinstance(savegame, dict) and isinstance(savegame.get("fields"), dict),
             "Savegame field contract is missing")
    _require(type(savegame.get("field_count")) is int and
             savegame["field_count"] == len(savegame["fields"]), "Save field count differs from contract")
    storage = save_contract.get("storage")
    _require(isinstance(storage, dict) and isinstance(storage.get("files"), list), "Save file scope is missing")
    save_files = storage["files"]
    _require(len(set(_id(name, "save filename") for name in save_files)) == len(save_files),
             "Duplicate save/config filename")
    sidecars = save_contract.get("sidecar_files")
    _require(isinstance(sidecars, dict) and set(save_files) == {"savegame.json"} | set(sidecars),
             "Save/config files disagree with their contracts")
    save_scopes = [{"namespace": ["save_file"], "id": name, "rawBytesMustSurvive": True}
                   for name in save_files]
    save_scopes.append({"namespace": ["save_fields", "savegame.json"],
                        "entries": [{"id": name, "contractFingerprint": _digest(spec)}
                                    for name, spec in savegame["fields"].items()]})
    for filename, contract in sidecars.items():
        _require(isinstance(contract, dict), "Malformed sidecar field contract")
        sections = contract.get("sections")
        _require(isinstance(sections, (list, dict)), "Sidecar sections are missing")
        for section in sections:
            _id(section, "configuration section")
            scope = {"namespace": ["config_section", filename, section], "preserveUnknownRawKeys": True}
            if filename == "controls.cfg":
                actions = contract.get("action_ids")
                _require(isinstance(actions, list) and len(set(actions)) == len(actions),
                         "Control action IDs are missing or duplicated")
                scope["entries"] = [{"id": _id(action, "input action")} for action in actions]
                scope["engineCodesRequireTranslation"] = True
            elif isinstance(sections, dict) and isinstance(sections[section], dict):
                spec = sections[section]
                if filename == "meta.cfg" and section == "achievements":
                    scope["dynamicKeyCatalog"] = "achievements"
                    scope["entries"] = [{"id": item["id"]} for item in catalogs["achievements"]["entries"]]
                else:
                    scope["entries"] = [{"id": name, "contractFingerprint": _digest(value)}
                                        for name, value in spec.items()]
            else:
                raise IdentityError("Unsupported sidecar identity scope")
            save_scopes.append(scope)

    identity_rules = save_contract.get("identity_rules")
    _require(isinstance(identity_rules, list), "Legacy identity rules are missing")
    rules_seen = set()
    for rule in identity_rules:
        _require(isinstance(rule, dict), "Malformed legacy key rule")
        kind = _id(rule.get("kind"), "legacy key rule")
        _require(kind not in rules_seen, "Duplicate legacy key rule")
        rules_seen.add(kind)
    _require({"generic_map_object", "final_object_array", "altar", "legacy_resource",
              "trail_resource", "winter_resource", "forest_food_resource", "runtime_living_resource",
              "animal_manure", "farm_or_yard_cell", "home_furniture", "quest_focus", "other_content"} <= rules_seen,
             "A persistence key family is absent from the identity contract")
    coverage = {
        "catalogs": len(catalogs), "catalogEntries": total_catalog_entries,
        "orderedCatalogs": len(ordered_catalogs), "declarations": len(declarations),
        "declarationEntries": sum(len(row["entries"]) for row in declarations),
        "modules": len(modules), "maps": len(map_records), "registrySlots": slot_count,
        "disabledSlots": disabled_count, "authoredObjectIds": authored_count,
        "registryResourceInstances": len(resource_instances) - appended_count,
        "postRegistryResourceInstances": appended_count, "resourceInstances": len(resource_instances),
        "altars": altar_count, "saveFiles": len(save_files), "saveRootFields": len(savegame["fields"]),
        "saveScopes": len(save_scopes), "legacyKeyFamilies": len(identity_rules),
        "finalRuntimeIndicesAssigned": 0, "runtimeOnlyResourceMembershipComplete": False,
    }
    return {
        "schema": SCHEMA, "schemaVersion": 1, "phase": 4, "scope": SCOPE,
        "notPhase5RuntimeExport": True, "inputDigests": input_digests,
        "provenance": {"sourceFingerprint": content["source_fingerprint"],
                       "gameVersion": content.get("source_version"),
                       "godotBaselineCommit": save_contract.get("baseline", {}).get("commit"),
                       "sourceFilesFingerprint": _digest(content.get("source_files"))},
        "namespaceRules": {"encoding": "Separate namespace array and exact typed id; never delimiter concatenation",
                           "sameIdAcrossCatalogs": "allowed; catalog namespace distinguishes identities",
                           "professionCooldownIds": "globally unique exact strings, including map/prefix characters",
                           "displayNamesAreIds": False, "disabledSlotsRetained": True,
                           "unknownSaveData": "Preserve original bytes and unknown fields; no converter in phase4"},
        "catalogs": catalog_result, "orderedCatalogs": ordered_catalogs,
        "declarations": declarations, "moduleOrder": copy.deepcopy(modules),
        "maps": map_records, "resourceInstances": resource_instances,
        "saveScopes": save_scopes, "legacyKeyRules": copy.deepcopy(identity_rules),
        "normalizerIdentityScopes": copy.deepcopy(save_contract.get("normalizers", {})),
        "coverage": coverage,
        "limitations": [
            "Registry slots retain their exact source indices but are not certified final world.load_map indices.",
            "Post-registry resource append order is preserved; no final runtime index is invented.",
            "Runtime-only living scenery resources, spawned actors and state-dependent membership need phase5 export.",
            "Generic type:map:index strings are candidate object keys; individual handlers decide actual persistence.",
            "Altar arrival safety, runtime transforms, conditional spawn state and coordinates need phase5 validation.",
            "Unknown save keys and original ConfigFile/InputEvent bytes remain raw; no save import is implemented.",
        ],
    }


def _difference(actual: object, expected: object, path: str = "registry") -> str:
    if type(actual) is not type(expected):
        return path + " (type)"
    if isinstance(expected, dict):
        if set(actual) != set(expected):
            return path + " (keys)"
        for key in expected:
            found = _difference(actual[key], expected[key], path + "/" + str(key))
            if found:
                return found
    elif isinstance(expected, list):
        if len(actual) != len(expected):
            return path + " (length)"
        for index, (left, right) in enumerate(zip(actual, expected)):
            found = _difference(left, right, path + "/" + str(index))
            if found:
                return found
    elif actual != expected:
        return path
    return ""


def validate_identity_registry(registry: dict, content: dict, maps: dict, save_contract: dict) -> dict:
    """Require complete agreement with the frozen inventories, including order."""
    expected = build_identity_registry(content, maps, save_contract)
    _canonical(registry)
    difference = _difference(registry, expected)
    _require(not difference, "Identity registry differs from frozen reference at " + difference)
    return {"schemaVersion": 1, "success": True, "phase": 4, "scope": SCOPE,
            "registryFingerprint": _digest(registry), "coverage": copy.deepcopy(expected["coverage"]),
            "finalRuntimeIndicesAssigned": 0, "engineExecuted": False, "playerSavesUsed": False}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--content", type=Path, default=ROOT / "migration/reference/content-inventory.json")
    parser.add_argument("--maps", type=Path, default=ROOT / "migration/reference/maps-inventory.json")
    parser.add_argument("--save-contract", type=Path, default=ROOT / "migration/reference/save-contract.json")
    parser.add_argument("--output", type=Path, default=ROOT / "migration/contracts/identity.json")
    parser.add_argument("--check", action="store_true", help="Verify existing registry without writing it")
    args = parser.parse_args()
    content, maps, save_contract = [json.loads(path.read_text(encoding="utf-8-sig"))
                                    for path in (args.content, args.maps, args.save_contract)]
    if args.check:
        registry = json.loads(args.output.read_text(encoding="utf-8-sig"))
    else:
        registry = build_identity_registry(content, maps, save_contract)
        _require(not args.output.exists(), "Identity output already exists; never silently replace its reference")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(registry, indent=2, ensure_ascii=False, allow_nan=False) + "\n",
                               encoding="utf-8")
    summary = validate_identity_registry(registry, content, maps, save_contract)
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (IdentityError, OSError, json.JSONDecodeError) as error:
        print(f"MIGRATION IDENTITY FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
