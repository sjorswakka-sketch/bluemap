#!/usr/bin/env python3
"""Inventory actual loaded-world identities after whole-world validation.

The Python API assumes validate_world_export has already accepted this directory;
it independently verifies snapshot checksums and frozen phase-4 input authority.
The CLI performs the whole validation first. No engine, node, resource or save is
created. Runtime occurrences are structural addresses, never new persistent IDs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

from migration_data_codec import canonical_bytes
from migration_world_data import (_read_json, _safe_file, canonical_wire_bytes, decode_wire,
                                  WireValue, validate_world_export)

LIVING_RESOURCES = {
    "lw_mine_iron": ("prismamine", [880.0, 176.0], "iron"),
    "lw_mine_copper": ("prismamine", [1104.0, 304.0], "copper"),
    "lw_shore_mint": ("kruipmoeras", [976.0, 560.0], "watermunt"),
    "lw_revealed_flower": ("dauwbos", [1264.0, 1040.0], "dauwklauw"),
}


class RuntimeIdentityError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise RuntimeIdentityError(message)


def field_nodes(value):
    require(type(value) is dict and value.get("kind") == "dictionary", "Expected world field dictionary")
    result = {}
    for pair in value.get("entries", []):
        require(type(pair) is list and len(pair) == 2 and pair[0].get("kind") in {"string", "string_name"},
                "Identity field names must be strings")
        name = pair[0]["value"]
        require(name not in result, "Duplicate identity field name")
        result[name] = pair[1]
    return result


def scalar(value):
    decoded = decode_wire(value)
    if isinstance(decoded, WireValue) and decoded.type == "StringName":
        return decoded.value
    return decoded


def point(value):
    require(type(value) is dict and value.get("kind") == "transform2d", "Node lacks its actual global transform")
    vector = scalar(value["origin"])
    require(isinstance(vector, WireValue) and vector.type == "Vector2", "Node position needs Vector2")
    return list(vector.value)


def object_fields(snapshot):
    value = field_nodes(snapshot["mapData"]).get("objects")
    require(type(value) is dict and value.get("kind") == "array" and value.get("type") == "Array",
            "Loaded map object array is missing")
    return [field_nodes(item) for item in value["values"]]


def expected_slots(reference_maps):
    """Final indices are assigned only to registry objects and actual append order."""
    result = {}
    for map_row in reference_maps["maps"]:
        map_id = map_row["id"]
        rows = []
        registry = map_row["registry_snapshot"]["objects"]
        for index, obj in enumerate(registry):
            rows.append({"namespace": ["map_runtime_slot", map_id], "id": index, "index": index,
                         "type": obj["type"], "registryIndex": index, "appendOrder": None,
                         "legacySlotKey": f"{obj['type']}:{map_id}:{index}",
                         "enabled": obj.get("enabled", True),
                         "candidateKeyOnly": True, "origin": "phase4_registry_slot",
                         "resourceId": obj.get("id") if obj["type"] == "profession_resource" else None,
                         "source": {"namespace": ["map_registry_slot", map_id], "id": index}})
        for order, entry in enumerate(map_row["post_registry_legacy_resources"]):
            obj = entry["value"]
            index = len(registry) + order
            rows.append({"namespace": ["map_runtime_slot", map_id], "id": index, "index": index,
                         "type": obj["type"], "registryIndex": None, "appendOrder": order,
                         "legacySlotKey": f"{obj['type']}:{map_id}:{index}",
                         "enabled": obj.get("enabled", True),
                         "candidateKeyOnly": True, "origin": "phase4_post_registry_append",
                         "resourceId": entry["id"],
                         "source": {"namespace": ["profession_cooldown"], "id": entry["id"]}})
        result[map_id] = rows
    return result


def check_slots(snapshot, expected):
    slots = snapshot["slots"]
    objects = object_fields(snapshot)
    require(len(slots) == len(objects) == len(expected), "Final object array length changed")
    for actual, obj, fixed in zip(slots, objects, expected):
        for key in ("index", "registryIndex", "appendOrder", "type", "legacySlotKey", "enabled"):
            require(actual.get(key) == fixed[key] and type(actual.get(key)) is type(fixed[key]),
                    "Changed final object index or legacy key: " + fixed["legacySlotKey"])
        require(scalar(obj["type"]) == fixed["type"], "Object type changed its preserved slot")
        if fixed["resourceId"] is not None:
            require("id" in obj and scalar(obj["id"]) == fixed["resourceId"],
                    "Resource array was reordered or its explicit ID changed")
    return objects


def collect_runtime_identities(snapshots, reference_maps, phase4_identity, runtime_resources=None):
    """Pure collector used by the checked API and synthetic corruption tests."""
    slots_by_map = expected_slots(reference_maps)
    runtime_resources = LIVING_RESOURCES if runtime_resources is None else runtime_resources
    slot_lookup = {row["legacySlotKey"]: row for rows in slots_by_map.values() for row in rows}
    resource_reference = {row["id"]: row for row in phase4_identity["resourceInstances"]}
    altar_reference = {row["id"]: row for m in phase4_identity["maps"] for row in m["altars"]}
    groups, resource_signatures, resource_seen, snapshot_keys = {}, {}, set(), set()
    baseline_maps, baseline_resources, altars, actual_resources = set(), set(), set(), set()
    extra_fishing = set()

    def add(namespace, identifier, role, occurrence, **metadata):
        require(type(identifier) in (str, int) and not (type(identifier) is str and not identifier),
                "Identity must be an exact nonempty string or integer")
        key = (tuple(namespace), type(identifier).__name__, identifier, role)
        if key not in groups:
            groups[key] = {"namespace": namespace, "id": identifier, "idType": type(identifier).__name__,
                           "role": role, "occurrences": [], **metadata}
        groups[key]["occurrences"].append(occurrence)

    for snapshot in snapshots:
        scenario, map_id = snapshot["scenarioId"], snapshot["mapId"]
        require((scenario, map_id) not in snapshot_keys and map_id in slots_by_map, "Duplicate or unknown runtime snapshot")
        snapshot_keys.add((scenario, map_id))
        objects = check_slots(snapshot, slots_by_map[map_id])
        if scenario == "fresh_baseline":
            baseline_maps.add(map_id)
        for node in snapshot["scene"]:
            fields = field_nodes(node["fields"])
            script, address = node["script"], node["address"]
            require(type(address) is list and address and address[0] in {"entities", "ground", "atmosphere"}
                    and all(type(part) is int and part >= 0 for part in address[1:]), "Identity occurrence needs a structural address")
            position = point(node["globalTransform"])
            occurrence = {"scenarioId": scenario, "mapId": map_id, "address": address, "script": script,
                          "positionPixels": position, "objectArrayIndex": None,
                          "origin": "runtime_node_outside_object_array"}
            generic_key = scalar(fields["key"]) if "key" in fields else ""
            if type(generic_key) is str and generic_key in slot_lookup:
                slot = slot_lookup[generic_key]
                require(slot["namespace"][1] == map_id, "Object candidate key refers to another map")
                occurrence.update(objectArrayIndex=slot["index"], origin=slot["origin"])
            if "resource_id" in fields:
                require(script == "res://scripts/entities/resource_node.gd",
                        "Profession cooldown identity appeared on a different handler")
                identifier = scalar(fields["resource_id"])
                require(type(identifier) is str and bool(identifier), "Resource has no explicit cooldown ID")
                kind = scalar(fields["kind"])
                signature = (map_id, script, tuple(position), kind)
                same_snapshot = (scenario, map_id, identifier)
                require(same_snapshot not in resource_seen, "Duplicate explicit resource ID in one loaded map")
                resource_seen.add(same_snapshot)
                require(identifier not in resource_signatures or resource_signatures[identifier] == signature,
                        "Explicit resource ID refers to distinct logical map nodes")
                resource_signatures[identifier] = signature
                actual_resources.add(identifier)
                if scenario == "fresh_baseline":baseline_resources.add(identifier)
                ref = resource_reference.get(identifier)
                resource_occurrence = dict(occurrence, field="resource_id")
                if ref is not None:
                    require(ref["mapId"] == map_id, "Resource changed its source map")
                    fixed = next((s for s in slots_by_map[map_id] if s["resourceId"] == identifier), None)
                    require(fixed is not None, "Resource has no final object-array slot")
                    obj = objects[fixed["index"]]
                    pos = scalar(obj["pos"])
                    require(position == [float(pos[0]) * 32 + 16, float(pos[1]) * 32 + 16]
                            and scalar(obj["kind"]) == kind,
                            "Resource identity differs from its physical object-array slot")
                    resource_occurrence.update(objectArrayIndex=fixed["index"], origin=fixed["origin"])
                else:
                    require(identifier in runtime_resources,
                            "Unknown or renamed runtime-only resource ID: " + identifier)
                    expected_map, expected_position, expected_kind = runtime_resources[identifier]
                    require(map_id == expected_map and position == expected_position and kind == expected_kind,
                            "Runtime-only resource differs from its authored producer")
                    require(occurrence["objectArrayIndex"] is None,
                            "Runtime-only resource was assigned an invented array index")
                add(["profession_cooldown"], identifier, "saved_profession_cooldown", resource_occurrence)
            for field in ("unique_key", "unique_flag", "once_flag", "gate_id", "npc_id", "id", "key"):
                if field not in fields:continue
                identifier = scalar(fields[field])
                if identifier == "" or identifier is None:continue
                require(type(identifier) in (str, int), "Non-scalar runtime identity field")
                current = dict(occurrence, field=field)
                if field == "unique_key":
                    require(type(identifier) is str, "Saved object key must remain a string")
                    if identifier in slot_lookup:
                        fixed = slot_lookup[identifier]
                        require(fixed["namespace"][1] == map_id and fixed["type"] in {"chest", "pickup"},
                                "Saved object flag points to the wrong map/type")
                        require(script == "res://scripts/entities/" + fixed["type"] + ".gd",
                                "Saved object flag appeared on a different handler")
                        obj = objects[fixed["index"]]
                        pos = scalar(obj["pos"])
                        require(position == [float(pos[0]) * 32 + 16, float(pos[1]) * 32 + 16],
                                "Saved object flag was renamed to another physical slot")
                        current.update(objectArrayIndex=fixed["index"], origin=fixed["origin"])
                    elif identifier == "chest:depths2:heart":
                        require(map_id == "depths2" and script == "res://scripts/entities/chest.gd",
                                "Guardian reward key used by another map/handler")
                        guardians = [obj for obj in objects if scalar(obj["type"]) == "guardian"]
                        require(len(guardians) == 1 and "chest" in guardians[0], "Guardian reward has no source object")
                        pos = scalar(guardians[0]["chest"])
                        require(position == [float(pos[0]) * 32 + 16, float(pos[1]) * 32 + 16],
                                "Guardian reward moved away from its authored chest tile")
                    elif identifier.startswith("hs_drop:"):
                        require(script == "res://scripts/entities/pickup.gd", "Saved manure key used by another handler")
                        homestead = field_nodes(field_nodes(snapshot["stateAfter"])["homestead"])
                        drops = field_nodes(homestead["drops"])
                        drop_id = identifier[len("hs_drop:"):]
                        require(drop_id in drops, "Saved manure key is absent from the captured drop journal")
                        drop = field_nodes(drops[drop_id])
                        require(scalar(drop["map"]) == map_id and scalar(drop["pos"]) == position
                                and scalar(fields["item"]) == "hs_manure",
                                "Saved manure key differs from the captured drop journal")
                    else:
                        raise RuntimeIdentityError("Unknown or renamed saved object flag: " + identifier)
                    add(["legacy_object_flag"], identifier, "saved_object_collection_flag", current)
                elif field in {"unique_flag", "once_flag"}:
                    require(type(identifier) is str, "Saved story flag must remain a string")
                    add(["story_flag"], identifier, "saved_story_flag", current)
                elif field == "gate_id":
                    key_item = scalar(fields["key_item"]) if "key_item" in fields else ""
                    add(["gate", map_id], identifier, "logical_gate_id", current,
                        derivedKeyUseFlag={"namespace": ["story_flag"], "id": "gate_" + str(identifier),
                                           "usedWhenKeyItemNonempty": bool(key_item)})
                elif field == "npc_id":
                    add(["npc_conversation"], identifier, "conversation_or_talked_identity", current)
                elif field == "id":
                    add(["runtime_logical_id", script], identifier, "logical_id_not_unique_or_implicitly_saved", current)
                else:
                    if script == "res://scripts/entities/meer_visplek.gd":
                        add(["fishing_spot_candidate", map_id], identifier, "handler_key_not_claimed_saved", current)
                        if identifier == "lw_marsh_fishing":extra_fishing.add(identifier)
                    else:
                        add(["handler_key_candidate", script], identifier, "handler_dependent_not_universal_persistence", current)
            if script == "res://scripts/entities/savepoint.gd":
                x, y = int(position[0] / 32), int(position[1] / 32)
                identifier = f"altaar_{map_id}_{x}_{y}"
                require(identifier in altar_reference and altar_reference[identifier]["mapId"] == map_id,
                        "Runtime altar coordinate key differs from the phase4 authority")
                altars.add(identifier)
                add(["altar_discovery"], identifier, "saved_altar_coordinate_flag", dict(occurrence, field="discovery_key()"))
    require(baseline_maps == set(slots_by_map), "Final slot map needs every fresh baseline map")
    require(baseline_resources == set(resource_reference), "Baseline resource membership differs from phase4 identities")
    require(altars == set(altar_reference), "Runtime altar membership differs from phase4 identities")
    records = sorted(groups.values(), key=lambda row: (tuple(row["namespace"]), row["idType"], str(row["id"]), row["role"]))
    return {"schema": "bluemap.migration.runtime-identities.v1", "phase": 5,
            "scope": "Actual loaded snapshot identities and exact final object-array indices; no Unity runtime or save conversion",
            "maps": [{"mapId": map_id, "slots": rows} for map_id, rows in sorted(slots_by_map.items())],
            "identities": records,
            "coverage": {"maps": len(slots_by_map), "snapshots": len(snapshot_keys),
                         "registrySlots": sum(s["registryIndex"] is not None for rows in slots_by_map.values() for s in rows),
                         "appendedSlots": sum(s["appendOrder"] is not None for rows in slots_by_map.values() for s in rows),
                         "finalArraySlots": sum(map(len, slots_by_map.values())),
                         "baselineResourceIds": len(baseline_resources), "runtimeResourceIds": len(actual_resources),
                         "runtimeOnlyResourceIds": sorted(actual_resources - set(resource_reference)),
                         "altarCoordinateKeys": len(altars), "additionalFishingKeys": sorted(extra_fishing),
                         "identityRecords": len(records), "identityOccurrences": sum(len(r["occurrences"]) for r in records)},
            "identityRules": ["Namespace arrays and exact typed IDs; no translated names or engine instance IDs",
                              "Repeated profiles may describe the same resource; two distinct map nodes may not share its cooldown ID",
                              "Logical IDs such as three rf_tracks deliberately need not be unique",
                              "Generic handler key fields are candidates, never blanket persistence claims",
                              "Runtime-only nodes have no invented object-array index"],
            "unityRuntimeImplemented": False, "saveConverterImplemented": False, "personalSavesUsed": False}


def build_runtime_identities(directory, reference_root):
    from build_migration_data import inputs
    from migration_identity import validate_identity_registry
    directory, repository = Path(directory), Path(reference_root)
    if (repository / "maps-inventory.json").is_file():repository = repository.parents[1]
    content, maps, save = inputs(repository)
    identity = _read_json(repository / "migration/contracts/identity.json")
    validate_identity_registry(identity, content, maps, save)
    index = _read_json(directory / "index.json")
    require(index.get("schema") == "bluemap.migration.world-index.v1" and index.get("failures") == [],
            "Runtime identity input needs a successful world index")

    def snapshots():
        for entry in index["snapshots"]:
            expected = f"snapshots/{entry['scenarioId']}/{entry['mapId']}.json"
            require(entry["path"] == expected, "Snapshot identity and path differ")
            path = _safe_file(directory, expected)
            data = canonical_wire_bytes(path)
            require(len(data) == entry["bytes"] and hashlib.sha256(data).hexdigest() == entry["sha256"],
                    "Snapshot checksum differs before identity inventory")
            snapshot = _read_json(path)
            require((snapshot["scenarioId"], snapshot["mapId"]) == (entry["scenarioId"], entry["mapId"]),
                    "Snapshot identity differs from its index")
            yield snapshot

    result = collect_runtime_identities(snapshots(), maps, identity)
    require(set(result["coverage"]["runtimeOnlyResourceIds"]) == set(LIVING_RESOURCES),
            "World profiles did not witness all four authored living resources")
    result["baselineCommit"] = "a8a988be27835dec979d2523a3a85a34385eac54"
    result["phase4IdentitySha256LF"] = hashlib.sha256((repository / "migration/contracts/identity.json").read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    result["worldIndexSha256LF"] = hashlib.sha256(canonical_wire_bytes(directory / "index.json")).hexdigest()
    result["sourceAnchors"] = source_anchors(repository, content)
    return result


def source_anchors(repository, content):
    """Retain exact original rule provenance; never execute those algorithms."""
    methods = {"scripts/world.gd": ["load_map"],
               "scripts/entities/resource_node.gd": ["_ready"],
               "scripts/core/professions.gd": ["gather"],
               "scripts/entities/living_scenery.gd": ["resource", "refresh"],
               "scripts/entities/savepoint.gd": ["discovery_key"],
               "scripts/core/fast_travel.gd": ["altar_key"],
               "scripts/entities/guardian.gd": ["_make_chest"],
               "scripts/entities/homestead.gd": ["_process"],
               "scripts/entities/gate.gd": ["interact"],
               "scripts/entities/npc.gd": ["interact"],
               "scripts/entities/chest.gd": ["interact"],
               "scripts/entities/pickup.gd": ["_collect"]}
    authority = {r["path"]: r["sha256"] for r in content["source_files"]}
    result = []
    for path, functions in methods.items():
        text = (repository / path).read_text(encoding="utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
        full_hash = hashlib.sha256(text.encode()).hexdigest()
        require(authority.get("res://" + path) == full_hash, "Identity rule source differs from preserved authority")
        lines = text.splitlines(keepends=True)
        for function in functions:
            starts = [i for i, line in enumerate(lines) if re.match(r"^(?:static )?func " + re.escape(function) + r"\(", line)]
            require(len(starts) == 1, "Identity rule function is missing or ambiguous")
            start = starts[0]
            end = start + 1
            while end < len(lines) and (not lines[end].strip() or lines[end][0].isspace() or lines[end].startswith("#")):
                end += 1
            body = "".join(lines[start:end]).rstrip() + "\n"
            result.append({"path": "res://" + path, "function": function, "line": start + 1,
                           "endLine": start + len(body.splitlines()), "sourceSha256LF": full_hash,
                           "bodySha256LF": hashlib.sha256(body.encode()).hexdigest()})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--reference-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        require(not args.output.exists() and not any(p.is_symlink() for p in [args.output, *args.output.parents]),
                "Output must be a new ordinary file; existing reports are never overwritten")
        validate_world_export(args.directory, args.reference_root)
        result = build_runtime_identities(args.directory, args.reference_root)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("xb") as stream:stream.write(canonical_bytes(result))
        print("RUNTIME IDENTITIES OK:", result["coverage"])
        return 0
    except (ValueError, OSError, KeyError, TypeError) as error:
        print("RUNTIME IDENTITIES FAILED:", error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
