#!/usr/bin/env python3
"""Validate loaded Godot world projections and their world-only Variant wire v2.

Everything here is data. No resource, script, node reference or runtime handle
is instantiated, evaluated, loaded by an engine, or converted into a real save.
The earlier reference-inventory codec remains a separate format.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
import math
from pathlib import Path
import re
import sys


MAX_DEPTH = 96
MAX_WIRE_NODES = 2_000_000
MAX_STRING = 1_000_000
MAX_JSON_BYTES = 128 * 1024 * 1024
MAX_TOTAL_BYTES = 2 * 1024 * 1024 * 1024
MAX_SNAPSHOTS = 4096
MAX_SCENE_NODES = 100000
INT_TEXT = re.compile(r"(?:0|-?[1-9][0-9]*)\Z")
FLOAT_TEXT = re.compile(r"-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?\Z")
IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]{0,127}\Z")
SAFE_ID = re.compile(r"[a-z0-9][a-z0-9_-]{0,127}\Z")
VECTOR_DIMENSIONS = {"Vector2": 2, "Vector2i": 2, "Vector3": 3, "Vector3i": 3,
                     "Vector4": 4, "Vector4i": 4}
ARRAY_TYPES = {"Array", "PackedByteArray", "PackedInt32Array", "PackedInt64Array",
               "PackedFloat32Array", "PackedFloat64Array", "PackedStringArray",
               "PackedVector2Array", "PackedVector3Array", "PackedVector4Array", "PackedColorArray"}
SNAPSHOT_SCHEMA = "bluemap.migration.world-snapshot.v1"
INDEX_SCHEMA = "bluemap.migration.world-index.v1"
BASELINE_COMMIT = "a8a988be27835dec979d2523a3a85a34385eac54"
BASELINE_TREE = "73ba02ea4db0a1c920360b6570f5209ccb970143"
EXPORTER_SOURCES = ("res://tools/migration_world_export.gd", "res://tools/migration_world_scenarios.gd")


class WorldDataError(ValueError):
    pass


def require(ok: bool, message: str) -> None:
    if not ok:
        raise WorldDataError(message)


def _canonical(value: object) -> bytes:
    try:
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"),
                          allow_nan=False).encode("utf-8")
    except (TypeError, ValueError, UnicodeError) as error:
        raise WorldDataError("Nonportable JSON value") from error


def _string(value: object, limit: int = MAX_STRING) -> str:
    require(type(value) is str and len(value) <= limit and "\0" not in value,
            "Expected a bounded UTF-8 string")
    try:
        value.encode("utf-8")
    except UnicodeError as error:
        raise WorldDataError("String has an invalid Unicode surrogate") from error
    return value


def _shape(value: object, fields: set[str]) -> None:
    require(type(value) is dict and set(value) == fields, "Invalid world wire node fields")


def _integer(value: object) -> int:
    text = _string(value, 20)
    require(INT_TEXT.fullmatch(text) is not None, "Wire integer is not canonical decimal text")
    number = int(text)
    require(-(2 ** 63) <= number < 2 ** 63, "Wire integer exceeds Godot signed64 range")
    return number


def _floating(value: object) -> float:
    text = _string(value, 128)
    require(FLOAT_TEXT.fullmatch(text) is not None, "Wire float is not Godot JSON number text")
    number = float(text)
    require(math.isfinite(number), "Wire float is not finite")
    require(number != 0 or not any(char in "123456789" for char in text.split("e")[0].split("E")[0]),
            "Wire float underflow would lose nonzero source data")
    return number


def _address(value: object) -> tuple:
    require(type(value) is list and 0 < len(value) <= MAX_DEPTH, "Invalid structural node address")
    root = value[0]
    require(type(root) is str, "Node address root must be semantic text")
    if root == "world":
        require(len(value) == 1, "World node reference has extra address parts")
    elif root == "autoload":
        require(len(value) == 2 and type(value[1]) is str and IDENTIFIER.fullmatch(value[1]) is not None,
                "Invalid autoload node reference")
    elif root == "outside":
        require(len(value) == 3 and type(value[1]) is str and IDENTIFIER.fullmatch(value[1]) is not None,
                "Outside node reference must use class/script provenance")
        _resource_path(value[2])
    elif root == "ui":
        # UI provenance retains the spatial root name when an excluded
        # CanvasLayer/Control branch is referenced from captured script data.
        ordinals = value[2:] if len(value) > 1 and type(value[1]) is str and value[1] in {"entities", "ground", "atmosphere"} else value[1:]
        require(all(type(part) is int and 0 <= part < MAX_SCENE_NODES for part in ordinals),
                "UI references require structural ordinals")
    else:
        require(root in {"entities", "ground", "atmosphere", "ui"} and
                all(type(part) is int and 0 <= part < MAX_SCENE_NODES for part in value[1:]),
                "Node references require numeric structural ordinals, never engine IDs/names")
    return tuple(value)


def _resource_path(value: object) -> str:
    text = _string(value, 4096)
    require(text == "" or text.startswith(("res://", "uid://")),
            "Resource references are data-only res:// or uid:// paths")
    require("\\" not in text and not any(part == ".." for part in text.split("/")),
            "Unsafe resource reference path")
    return text


@dataclass(frozen=True)
class WireValue:
    """An engine type tag and immutable data, never a constructed engine object."""
    type: str
    value: object


@dataclass(frozen=True)
class WireDictionary:
    """Ordered typed keys; Python dict would collapse bool/int/float identities."""
    entries: tuple

    def items(self):
        return iter(self.entries)

    def get(self, key, default=None):
        for entry_key, value in self.entries:
            comparable = entry_key.value if isinstance(entry_key, WireValue) and entry_key.type == "StringName" else entry_key
            if type(comparable) is type(key) and comparable == key:
                return value
        return default

    def __getitem__(self, key):
        marker = object()
        value = self.get(key, marker)
        if value is marker:
            raise KeyError(key)
        return value

    def __contains__(self, key):
        marker = object()
        return self.get(key, marker) is not marker


def _wire_key(value: dict) -> bytes:
    """Typed equality token, normalizing alternate finite decimal spellings."""
    if value["kind"] == "float":
        number = _floating(value["value"])
        return _canonical(["float", (0.0 if number == 0 else number).hex()])
    if value["kind"] == "vector":
        return _canonical(["vector", value["type"], [_wire_key(item).decode("utf-8") for item in value["values"]]])
    return _canonical(value)


def validate_wire(value: object) -> None:
    """Strict world wire v2, with type tags at every nested Variant boundary."""
    active = set()
    count = 0

    def visit(node: object, depth: int) -> None:
        nonlocal count
        count += 1
        require(depth <= MAX_DEPTH and count <= MAX_WIRE_NODES, "World wire depth/node budget exceeded")
        require(type(node) is dict and type(node.get("kind")) is str, "Every world wire value needs a kind")
        identity = id(node)
        require(identity not in active, "World wire values cannot contain cycles")
        active.add(identity)
        try:
            kind = node["kind"]
            if kind == "nil":
                _shape(node, {"kind"})
            elif kind in {"bool", "int", "float", "string", "string_name", "node_path"}:
                _shape(node, {"kind", "value"})
                if kind == "bool":
                    require(type(node["value"]) is bool, "Wire bool must be a bool")
                elif kind == "int":
                    _integer(node["value"])
                elif kind == "float":
                    _floating(node["value"])
                else:
                    _string(node["value"])
            elif kind == "array":
                _shape(node, {"kind", "type", "values"})
                require(type(node["type"]) is str and node["type"] in ARRAY_TYPES and type(node["values"]) is list,
                        "World array needs a supported explicit type")
                for child in node["values"]:
                    visit(child, depth + 1)
                    element_kind = child["kind"]
                    array_type = node["type"]
                    if array_type in {"PackedByteArray", "PackedInt32Array", "PackedInt64Array"}:
                        require(element_kind == "int", "Packed integer array has the wrong element type")
                        number = _integer(child["value"])
                        if array_type == "PackedByteArray":
                            require(0 <= number <= 255, "Packed byte outside 0..255")
                        elif array_type == "PackedInt32Array":
                            require(-(2 ** 31) <= number < 2 ** 31, "PackedInt32Array component out of range")
                    elif array_type in {"PackedFloat32Array", "PackedFloat64Array"}:
                        require(element_kind == "float", "Packed float array has the wrong element type")
                        if array_type == "PackedFloat32Array":
                            require(abs(_floating(child["value"])) <= 3.4028234663852886e38,
                                    "PackedFloat32Array component out of range")
                    elif array_type == "PackedStringArray":
                        require(element_kind == "string", "Packed string array has the wrong element type")
                    elif array_type in {"PackedVector2Array", "PackedVector3Array", "PackedVector4Array"}:
                        require(element_kind == "vector" and child["type"] == array_type[6:-5],
                                "Packed vector array has the wrong element type")
                    elif array_type == "PackedColorArray":
                        require(element_kind == "color", "Packed color array has the wrong element type")
            elif kind == "dictionary":
                _shape(node, {"kind", "entries"})
                require(type(node["entries"]) is list, "Dictionary requires ordered wire key/value pairs")
                seen = set()
                for pair in node["entries"]:
                    require(type(pair) is list and len(pair) == 2, "Invalid world dictionary pair")
                    visit(pair[0], depth + 1)
                    visit(pair[1], depth + 1)
                    key = _wire_key(pair[0])
                    require(key not in seen, "Duplicate typed world dictionary key")
                    seen.add(key)
            elif kind == "vector":
                _shape(node, {"kind", "type", "values"})
                require(type(node["type"]) is str and node["type"] in VECTOR_DIMENSIONS and type(node["values"]) is list and
                        len(node["values"]) == VECTOR_DIMENSIONS[node["type"]], "Invalid world vector dimensions")
                integer = node["type"].endswith("i")
                for child in node["values"]:
                    visit(child, depth + 1)
                    require(child["kind"] == ("int" if integer else "float"), "Vector numeric kind was lost")
                    if integer:
                        number = _integer(child["value"])
                        require(-(2 ** 31) <= number < 2 ** 31, "Vector integer exceeds signed32 range")
            elif kind == "rect":
                _shape(node, {"kind", "type", "position", "size"})
                require(type(node["type"]) is str and node["type"] in {"Rect2", "Rect2i"}, "Invalid rect type")
                vector_type = "Vector2i" if node["type"] == "Rect2i" else "Vector2"
                for field in ("position", "size"):
                    visit(node[field], depth + 1)
                    require(node[field].get("kind") == "vector" and node[field].get("type") == vector_type,
                            "Rect components must preserve vector type")
            elif kind == "color":
                _shape(node, {"kind", "rgba"})
                require(type(node["rgba"]) is list and len(node["rgba"]) == 4, "Color needs four channels")
                for channel in node["rgba"]:
                    visit(channel, depth + 1)
                    require(channel["kind"] == "float", "Color channels must preserve float type")
            elif kind == "transform2d":
                _shape(node, {"kind", "x", "y", "origin"})
                for field in ("x", "y", "origin"):
                    visit(node[field], depth + 1)
                    require(node[field].get("kind") == "vector" and node[field].get("type") == "Vector2",
                            "Transform2D requires Vector2 basis/origin")
            elif kind == "resource_ref":
                _shape(node, {"kind", "class", "path"})
                require(type(node["class"]) is str and IDENTIFIER.fullmatch(node["class"]) is not None,
                        "Invalid resource class provenance")
                _resource_path(node["path"])
            elif kind == "node_ref":
                _shape(node, {"kind", "address"})
                _address(node["address"])
            elif kind == "runtime_handle":
                _shape(node, {"kind", "type", "reason"})
                require(type(node["type"]) is str and IDENTIFIER.fullmatch(node["type"]) is not None,
                        "Runtime handle requires a stable type, never a serialized object/id")
                require(bool(_string(node["reason"], 1024).strip()), "Runtime handle needs an explicit omission reason")
            else:
                raise WorldDataError("Unknown world wire kind: " + kind)
        finally:
            active.remove(identity)

    visit(value, 0)


def decode_wire(value: object):
    """Return ordered data and typed sentinels; this never creates engine types."""
    validate_wire(value)

    def visit(node):
        kind = node["kind"]
        if kind == "nil":
            return None
        if kind == "bool":
            return node["value"]
        if kind == "int":
            return _integer(node["value"])
        if kind == "float":
            return _floating(node["value"])
        if kind == "string":
            return node["value"]
        if kind in {"string_name", "node_path"}:
            return WireValue("StringName" if kind == "string_name" else "NodePath", node["value"])
        if kind == "array":
            values = [visit(child) for child in node["values"]]
            return values if node["type"] == "Array" else WireValue(node["type"], tuple(values))
        if kind == "dictionary":
            return WireDictionary(tuple((visit(key), visit(item)) for key, item in node["entries"]))
        if kind == "vector":
            return WireValue(node["type"], tuple(visit(child) for child in node["values"]))
        if kind == "rect":
            return WireValue(node["type"], (visit(node["position"]), visit(node["size"])))
        if kind == "color":
            return WireValue("Color", tuple(visit(child) for child in node["rgba"]))
        if kind == "transform2d":
            return WireValue("Transform2D", tuple(visit(node[field]) for field in ("x", "y", "origin")))
        if kind == "resource_ref":
            return WireValue("ResourceReference", (node["class"], node["path"]))
        if kind == "node_ref":
            return WireValue("NodeReference", tuple(node["address"]))
        return WireValue("RuntimeHandle", (node["type"], node["reason"]))

    return visit(value)


def _map(value: object, label: str) -> WireDictionary:
    require(isinstance(value, WireDictionary), label + " must be an ordered wire dictionary")
    return value


def _sequence(value: object, label: str) -> list | tuple:
    if isinstance(value, WireValue) and value.type in ARRAY_TYPES:
        return value.value
    require(type(value) is list, label + " must be a wire array")
    return value


def _vector(value: object, label: str, integer: bool = False) -> tuple:
    require(isinstance(value, WireValue) and value.type == ("Vector2i" if integer else "Vector2"),
            label + " must preserve its vector type")
    return value.value


def _reference_maps(registry_maps: object) -> dict:
    rows = registry_maps.get("maps") if isinstance(registry_maps, dict) and "maps" in registry_maps else registry_maps
    if isinstance(rows, list):
        require(all(isinstance(row, dict) and type(row.get("id")) is str for row in rows),
                "Malformed frozen map rows")
        result = {row["id"]: row for row in rows}
        require(len(result) == len(rows), "Duplicate frozen map ID")
        return result
    require(isinstance(rows, dict), "Expected frozen map inventory")
    return rows


def _wire_handles(node: dict) -> int:
    total = int(node.get("kind") == "runtime_handle")
    for value in node.values():
        if type(value) is dict:
            total += _wire_handles(value)
        elif type(value) is list:
            for child in value:
                if type(child) is dict:
                    total += _wire_handles(child)
                elif type(child) is list:
                    total += sum(_wire_handles(item) for item in child if type(item) is dict)
    return total


def validate_snapshot(snapshot: dict, registry_maps: dict) -> dict:
    """Validate final slot identity, complete native geometry and source arrivals."""
    required = {"schema", "scenarioId", "mapId", "stage", "mapData", "stateBefore", "stateAfter", "slots",
                "terrain", "scene", "environment", "derived", "arrivals", "tileSet", "projectionCalls", "units"}
    require(type(snapshot) is dict and required <= set(snapshot), "Loaded world snapshot is incomplete")
    require(snapshot["schema"] == SNAPSHOT_SCHEMA and snapshot["stage"] == "loaded_projection",
            "Wrong world snapshot schema or capture stage")
    for field in ("scenarioId", "mapId"):
        require(type(snapshot[field]) is str and SAFE_ID.fullmatch(snapshot[field]) is not None,
                "Invalid world scenario/map identity")
    maps = _reference_maps(registry_maps)
    require(snapshot["mapId"] in maps, "World snapshot references an unknown map")
    reference, map_id = maps[snapshot["mapId"]], snapshot["mapId"]
    require(snapshot["units"] == {"tilePixels": 32, "yAxis": "down"} and
            type(snapshot["units"]["tilePixels"]) is int, "World scale/axis contract changed")
    data = _map(decode_wire(snapshot["mapData"]), "mapData")
    before = _map(decode_wire(snapshot["stateBefore"]), "stateBefore")
    after = _map(decode_wire(snapshot["stateAfter"]), "stateAfter")
    require(type(before.get("play_time")) in {int, float} and
            type(before.get("play_time")) is type(after.get("play_time")) and
            before.get("play_time") == after.get("play_time"), "World projection advanced active play time")
    _map(decode_wire(snapshot["environment"]), "environment")
    derived = _map(decode_wire(snapshot["derived"]), "derived world state")
    for field in ("irrigation_wet", "irrigation_flow", "natural_water_sources"):
        _map(derived.get(field), field)
    require(type(derived.get("pollen_flowers")) is int and derived["pollen_flowers"] >= 0,
            "Derived flower support count must remain a nonnegative integer")
    tile_set = _map(decode_wire(snapshot["tileSet"]), "tileSet reference")
    require(tile_set.get("shared") == "tile-set.json", "Snapshot must reference the indexed native tile set")
    rows = _sequence(data.get("rows"), "map rows")
    width, height = reference["width"], reference["height"]
    require(type(width) is int and type(height) is int and width > 0 and height > 0 and width * height <= 1_000_000,
            "Frozen map dimensions are invalid")
    require(len(rows) == height and all(type(row) is str and len(row) == width for row in rows),
            "Loaded world rows differ from the complete map dimensions")
    objects = _sequence(data.get("objects"), "final objects")
    original_slots, appended = reference["object_slots"], reference["post_registry_legacy_resources"]
    slots = snapshot["slots"]
    require(type(slots) is list and len(slots) == len(objects) == len(original_slots) + len(appended),
            "Final object array must retain every registry slot and appended resource")
    disabled_count = 0
    for index, (slot, spec) in enumerate(zip(slots, objects)):
        spec = _map(spec, "final object spec")
        require(type(slot) is dict and {"index", "registryIndex", "appendOrder", "type", "legacySlotKey",
                                      "enabled", "conditionsPassed"} <= set(slot), "Final slot metadata is incomplete")
        kind = spec.get("type")
        require(type(slot["index"]) is int and slot["index"] == index and type(kind) is str and
                slot["type"] == kind and slot["legacySlotKey"] == f"{kind}:{map_id}:{index}",
                "Final legacy object index/type/key changed")
        require(type(slot["enabled"]) is bool and type(slot["conditionsPassed"]) is bool and
                slot["enabled"] is spec.get("enabled", True), "Final slot enabled/condition state is invalid")
        if index < len(original_slots):
            original = original_slots[index]
            require(type(slot["registryIndex"]) is int and slot["registryIndex"] == index and
                    slot["appendOrder"] is None and kind == original["type"] and
                    spec.get("id") == original["authored_id"] and slot["enabled"] is original["enabled"] and
                    slot["legacySlotKey"] == original["legacy_slot_key"],
                    "Registry object was deleted, filtered, renumbered or reidentified")
        else:
            offset = index - len(original_slots)
            resource = appended[offset]
            require(slot["registryIndex"] is None and type(slot["appendOrder"]) is int and
                    slot["appendOrder"] == offset and spec.get("id") == resource["id"] and
                    kind == "profession_resource" and spec.get("kind") == resource["value"]["kind"],
                    "Appended resource order/explicit cooldown ID changed")
        disabled_count += not slot["enabled"]
    terrain = snapshot["terrain"]
    require(type(terrain) is dict and {"width", "height", "cells", "solidCells"} <= set(terrain) and
            type(terrain["width"]) is int and type(terrain["height"]) is int and
            (terrain["width"], terrain["height"]) == (width, height), "Native terrain dimensions changed")
    cells, solids = terrain["cells"], terrain["solidCells"]
    require(type(cells) is list and len(cells) == width * height and type(solids) is list,
            "Native tile capture is incomplete")
    seen = set()
    for cell in cells:
        require(type(cell) is list and len(cell) == 6 and all(type(item) is int for item in cell),
                "Native cells need six exact integer coordinates/IDs")
        x, y, source, atlas_x, atlas_y, alternative = cell
        require(0 <= x < width and 0 <= y < height and min(source, atlas_x, atlas_y, alternative) >= 0,
                "Native tile coordinate/source/atlas is out of bounds")
        require((x, y) not in seen, "Duplicate native tile coordinate")
        seen.add((x, y))
    solid_set = set()
    for cell in solids:
        require(type(cell) is list and len(cell) == 2 and all(type(item) is int for item in cell) and
                0 <= cell[0] < width and 0 <= cell[1] < height, "Solid cell is outside the world")
        require(tuple(cell) not in solid_set, "Duplicate solid cell")
        solid_set.add(tuple(cell))
    scene = snapshot["scene"]
    require(type(scene) is list and 0 < len(scene) <= MAX_SCENE_NODES, "Spatial scene capture is empty or oversized")
    addresses, collisions, shape_count, handles = set(), 0, 0, 0
    for node in scene:
        fields = {"address", "parent", "class", "script", "groups", "localTransform", "globalTransform",
                  "visible", "fields", "omissions"}
        require(type(node) is dict and fields <= set(node), "Spatial scene node is incomplete")
        address = _address(node["address"])
        require(address[0] in {"entities", "ground", "atmosphere"} and address not in addresses,
                "Spatial node address is duplicated or outside the map roots")
        addresses.add(address)
        require(type(node["class"]) is str and IDENTIFIER.fullmatch(node["class"]) is not None,
                "Node class is not stable provenance")
        _resource_path(node["script"])
        require(type(node["visible"]) is bool and type(node["groups"]) is list and
                all(type(group) is str and group and len(group) <= 128 for group in node["groups"]) and
                len(set(node["groups"])) == len(node["groups"]), "Invalid node visibility/group capture")
        for transform in ("localTransform", "globalTransform"):
            decoded = decode_wire(node[transform])
            require(decoded is None or isinstance(decoded, WireValue) and decoded.type == "Transform2D",
                    "Spatial transform must retain Transform2D type or explicit nil")
        _map(decode_wire(node["fields"]), "node fields")
        for optional_wire in ("native", "sprite", "light"):
            if optional_wire in node:
                _map(decode_wire(node[optional_wire]), optional_wire + " node values")
        handles += _wire_handles(node["fields"])
        require(type(node["omissions"]) is list and all(type(reason) in {str, dict} for reason in node["omissions"]),
                "Transient field omissions need explicit data-only reasons")
        for omission in node["omissions"]:
            require(bool(omission.strip()) if type(omission) is str else bool(omission.get("reason")),
                    "A transient omission lacks its reason")
        if "collision" in node:
            collision = node["collision"]
            require(type(collision) is dict and {"layer", "mask"} <= set(collision) and
                    all(type(collision[field]) is int and 0 <= collision[field] < 2 ** 32
                        for field in ("layer", "mask")), "Invalid native collision layer/mask")
            collisions += 1
        if "shape" in node:
            shape = node["shape"]
            require(type(shape) is dict and {"class", "disabled", "parameters"} <= set(shape) and
                    type(shape["class"]) is str and IDENTIFIER.fullmatch(shape["class"]) is not None and
                    type(shape["disabled"]) is bool, "Invalid native collider shape capture")
            parameters = _map(decode_wire(shape["parameters"]), "shape parameters")
            if shape["class"] in {"RectangleShape2D", "CircleShape2D", "CapsuleShape2D"}:
                if shape["class"] == "RectangleShape2D":
                    size = _vector(parameters.get("size"), "rectangle size")
                    require(all(value > 0 for value in size), "Rectangle collider size must be positive")
                else:
                    require(type(parameters.get("radius")) is float and parameters["radius"] > 0,
                            "Circle/capsule collider radius must be a positive native float")
                    if shape["class"] == "CapsuleShape2D":
                        require(type(parameters.get("height")) is float and parameters["height"] > 0,
                                "Capsule collider height must be positive")
            elif shape["class"] == "SegmentShape2D":
                _vector(parameters.get("a"), "segment a")
                _vector(parameters.get("b"), "segment b")
            elif shape["class"] in {"ConvexPolygonShape2D", "ConcavePolygonShape2D", "CollisionPolygon2D"}:
                field = {"ConvexPolygonShape2D": "points", "ConcavePolygonShape2D": "segments",
                         "CollisionPolygon2D": "polygon"}[shape["class"]]
                points = parameters.get(field)
                require(isinstance(points, WireValue) and points.type == "PackedVector2Array" and
                        len(points.value) >= (2 if shape["class"] == "ConcavePolygonShape2D" else 3),
                        "Native collider polygon is incomplete")
                for point in points.value:
                    _vector(point, "collider polygon point")
                if shape["class"] == "ConcavePolygonShape2D":
                    require(len(points.value) % 2 == 0, "Concave collider segments must be pairs")
                if shape["class"] == "CollisionPolygon2D":
                    require(type(parameters.get("build_mode")) is int and parameters["build_mode"] in {0, 1},
                            "Invalid native polygon build mode")
            elif shape["class"] == "WorldBoundaryShape2D":
                _vector(parameters.get("normal"), "world boundary normal")
                require(type(parameters.get("distance")) is float, "Boundary distance must retain float kind")
            elif shape["class"] == "SeparationRayShape2D":
                require(type(parameters.get("length")) is float and parameters["length"] > 0 and
                        type(parameters.get("slide_on_slope")) is bool, "Invalid separation ray geometry")
            else:
                raise WorldDataError("Unsupported native collider shape geometry")
            if "oneWay" in shape:
                require(type(shape["oneWay"]) is bool, "One-way collision setting must be a bool")
            if "oneWayMargin" in shape:
                require(type(shape["oneWayMargin"]) in {int, float} and
                        math.isfinite(shape["oneWayMargin"]) and shape["oneWayMargin"] >= 0,
                        "One-way collision margin must be finite and nonnegative")
            shape_count += 1
    for node in scene:
        address = tuple(node["address"])
        parent = node["parent"]
        if parent is None:
            require(len(address) <= 2, "Nested spatial node lost its parent")
        else:
            parent_address = _address(parent)
            require(parent_address in addresses and tuple(address[:-1]) == parent_address,
                    "Spatial node parent does not match its structural address")
    spawns = _map(data.get("spawns"), "map spawns")
    arrivals = snapshot["arrivals"]
    require(type(arrivals) is list and len(arrivals) == len(spawns.entries), "Safe arrivals omit authored spawn IDs")
    arrival_names = set()
    for arrival in arrivals:
        require(type(arrival) is dict and {"name", "nominal", "resolved", "fits"} <= set(arrival) and
                type(arrival["name"]) is str and arrival["name"] not in arrival_names and
                arrival["name"] in spawns and arrival["fits"] is True, "An authored arrival is missing, duplicate or unsafe")
        arrival_names.add(arrival["name"])
        nominal = _vector(decode_wire(arrival["nominal"]), "nominal arrival")
        resolved = _vector(decode_wire(arrival["resolved"]), "resolved arrival")
        tile = _sequence(spawns[arrival["name"]], "spawn tile")
        expected_nominal = tuple(float(value) * 32 + 16 for value in tile) if len(tile) == 2 else ()
        flags = after.get("flags")
        opening = isinstance(flags, WireDictionary) and flags.get("op_new_adventure") is True and after.get("ng_plus") == 0
        if map_id == "village" and arrival["name"] == "start" and after.get("play_time", 0) < 1 and opening:
            expected_nominal = (expected_nominal[0], expected_nominal[1] + 48)
        require(len(tile) == 2 and nominal == expected_nominal,
                "Arrival nominal position no longer matches its authored tile")
        require(0 <= resolved[0] < width * 32 and 0 <= resolved[1] < height * 32,
                "Safe resolved arrival is outside map bounds")
        # Mirror the native tile-foot sample contract; colliders are separately
        # recorded, while fits is the actual source world's collision proof.
        foot = (resolved[0], resolved[1] + 8)
        for dx, dy in ((0, 0), (8, 0), (-8, 0), (0, 8), (0, -8), (6, 6), (-6, 6), (6, -6), (-6, -6)):
            cell = (math.floor((foot[0] + dx) / 32), math.floor((foot[1] + dy) / 32))
            require(0 <= cell[0] < width and 0 <= cell[1] < height and cell not in solid_set,
                    "Native resolved arrival overlaps solid terrain")
    calls = snapshot["projectionCalls"]
    require(type(calls) is list, "Projection call audit is missing")
    for call in calls:
        require(type(call) is dict and {"script", "method"} <= set(call), "Malformed projection call provenance")
        _resource_path(call["script"])
        require(type(call["method"]) is str and IDENTIFIER.fullmatch(call["method"]) is not None,
                "Projection method must remain a data-only identifier")
    return {"schemaVersion": 1, "success": True, "scenarioId": snapshot["scenarioId"], "mapId": map_id,
            "registrySlots": len(original_slots), "appendedResources": len(appended), "finalSlots": len(slots),
            "disabledSlots": disabled_count, "tiles": len(cells), "solidCells": len(solid_set),
            "sceneNodes": len(scene), "collisionBodies": collisions, "shapes": shape_count,
            "safeArrivals": len(arrivals), "runtimeHandles": handles,
            "playerSavesUsed": False, "engineExecutedByVerifier": False}


def _unique_json(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key in world export")
        result[key] = value
    return result


def canonical_wire_bytes(path: Path) -> bytes:
    """Git text checkouts may use CRLF; escaped source-string bytes stay exact."""
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 2 * MAX_JSON_BYTES,
            "World JSON is missing, symlinked or oversized")
    data = path.read_bytes().replace(b"\r\n", b"\n")
    require(len(data) <= MAX_JSON_BYTES, "Canonical world JSON exceeds the byte limit")
    return data


def _read_json(path: Path) -> dict:
    try:
        value = json.loads(canonical_wire_bytes(path).decode("utf-8"), object_pairs_hook=_unique_json,
                           parse_float=_finite_json_float,
                           parse_constant=lambda _: (_ for _ in ()).throw(WorldDataError("Nonfinite JSON number")))
    except (UnicodeError, json.JSONDecodeError, RecursionError) as error:
        raise WorldDataError("Invalid world JSON: " + path.name) from error
    require(type(value) is dict, "World JSON root must be an object")
    return value


def _finite_json_float(text: str) -> float:
    value = float(text)
    require(math.isfinite(value), "Nonfinite JSON number")
    return value


def _safe_file(root: Path, name: object) -> Path:
    name = _string(name, 1024)
    parts = name.split("/")
    require(name and not any(ord(char) < 32 or char in '\\:<>"|?*' for char in name) and
            all(part and part not in {".", ".."} and not part.endswith((" ", ".")) for part in parts),
            "World index has an unsafe relative file path")
    path = root.joinpath(*parts)
    require(not any(part.is_symlink() for part in [path, *path.parents]) and path.resolve().is_relative_to(root.resolve()),
            "World index escapes its export directory or follows a symlink")
    return path


def _validate_export_file_set(directory: Path, expected: set[str]) -> None:
    """Every physical payload file is indexed; links/special files never hide."""
    require(directory.is_dir() and not directory.is_symlink(), "Export root must be an ordinary directory")
    actual = set()
    for path in directory.rglob("*"):
        require(not path.is_symlink() and not (hasattr(path, "is_junction") and path.is_junction()),
                "World export cannot contain symlinked files/directories or junctions")
        if path.is_file():
            actual.add(path.relative_to(directory).as_posix())
        else:
            require(path.is_dir(), "World export contains a special non-file payload")
    require(actual == expected, "World export has missing or unindexed physical files")


def _reference_root(root: Path) -> Path:
    root = Path(root)
    return root if (root / "maps-inventory.json").is_file() else root / "migration/reference"


def _coverage_contract(reference: Path, maps: dict) -> tuple[dict, Path]:
    repository = reference.parents[1]
    path = repository / "migration/world-coverage.json"
    contract = _read_json(path)
    require(contract.get("schema") == "bluemap.world.coverage.v1" and contract.get("phase") == 5 and
            contract.get("personalSavesUsed") is False and contract.get("unityRuntimeImplemented") is False,
            "World coverage contract is missing or claims the wrong scope")
    require(type(contract.get("requiredMapIds")) is list and
            set(contract["requiredMapIds"]) == set(_reference_maps(maps)) and
            type(contract.get("requiredScenarios")) is list and bool(contract["requiredScenarios"]),
            "Coverage contract has incomplete map/scenario witnesses")
    return contract, path


def _validate_index_provenance(index: dict, repository: Path) -> None:
    require(index.get("valueEncoding") == "bluemap.world.variant.v2" and
            index.get("baselineCommit") == BASELINE_COMMIT and index.get("baselineTree") == BASELINE_TREE,
            "World index has a different wire format or Godot baseline")
    sources = index.get("exporterSources")
    require(type(sources) is dict and set(sources) == set(EXPORTER_SOURCES),
            "World index does not identify its complete exporter/fixture source")
    for source, digest in sources.items():
        path = repository / source[6:]
        require(path.is_file() and not path.is_symlink() and type(digest) is str and
                re.fullmatch(r"[0-9a-f]{64}", digest) is not None and
                hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest() == digest,
                "World exporter source differs from the captured source fingerprint: " + source)


def _validated_reference_inputs(repository: Path):
    # Reuse the complete phase4 anchors: four canonical inventory hashes plus
    # every preserved original handler file. No Godot/Unity or Git is started.
    from build_migration_data import inputs
    try:
        return inputs(repository)
    except (ValueError, OSError) as error:
        raise WorldDataError("Frozen phase4 reference/source verification failed: " + str(error)) from error


def _native_tiles(value: dict) -> dict:
    """Read the actual exported atlas definitions, including their real polygons."""
    data = _map(decode_wire(value), "shared tile set")
    tile_size = _vector(data.get("tile_size"), "native tile size", integer=True)
    require(tile_size == (32, 32), "Native tile set differs from the world scale")
    physics_layers = data.get("physics_layers")
    require(type(physics_layers) is int and 0 < physics_layers <= 32, "Invalid native physics layer count")
    sources = _sequence(data.get("sources"), "native tile sources")
    require(0 < len(sources) <= 128, "Native tile sources are missing or oversized")
    seen_sources, result = set(), {}
    for source in sources:
        source = _map(source, "tile source")
        source_id = source.get("id")
        require(type(source_id) is int and source_id >= 0 and source_id not in seen_sources,
                "Duplicate or invalid native tile source")
        seen_sources.add(source_id)
        region_size = _vector(source.get("region_size"), "atlas region size", integer=True)
        require(all(size > 0 for size in region_size), "Invalid native atlas region dimensions")
        texture = source.get("texture")
        require(isinstance(texture, WireValue) and texture.type == "ResourceReference",
                "Tile atlas texture reference is missing")
        for tile in _sequence(source.get("tiles"), "atlas tiles"):
            tile = _map(tile, "atlas tile")
            atlas = _vector(tile.get("atlas"), "native atlas coordinate", integer=True)
            alternative = tile.get("alternative")
            require(all(coordinate >= 0 for coordinate in atlas) and type(alternative) is int and alternative >= 0,
                    "Invalid native atlas coordinate/alternative")
            key = (source_id, atlas[0], atlas[1], alternative)
            require(key not in result, "Duplicate native atlas tile definition")
            layers, seen_layers, polygon_count = _sequence(tile.get("layers"), "tile physics layers"), set(), 0
            for layer in layers:
                layer = _map(layer, "tile physics layer")
                index = layer.get("layer")
                require(type(index) is int and 0 <= index < physics_layers and index not in seen_layers,
                        "Missing or duplicate native tile physics layer")
                seen_layers.add(index)
                for field in ("collision_layer", "collision_mask"):
                    require(type(layer.get(field)) is int and 0 <= layer[field] < 2 ** 32,
                            "Invalid native tile collision layer/mask")
                for polygon in _sequence(layer.get("polygons"), "tile polygons"):
                    polygon = _map(polygon, "tile polygon")
                    points = polygon.get("points")
                    require(isinstance(points, WireValue) and points.type == "PackedVector2Array" and
                            len(points.value) >= 3, "Native tile polygon points are incomplete")
                    for point in points.value:
                        coordinates = _vector(point, "native polygon point")
                        require(all(abs(number) <= 1_000_000 for number in coordinates), "Unbounded native tile polygon")
                    require(type(polygon.get("one_way")) is bool and
                            type(polygon.get("one_way_margin")) is float and polygon["one_way_margin"] >= 0,
                            "Native tile one-way collision metadata is invalid")
                    polygon_count += 1
            require(seen_layers == set(range(physics_layers)), "Native tile omits a physics layer")
            result[key] = {"polygons": polygon_count, "regionSize": region_size}
    require(bool(result), "Shared native tile set is empty")
    memberships = {}
    for source, x, y, alternative in result:
        memberships.setdefault((source, x, alternative), []).append(y)
    for (source, x, _, alternative), definition in result.items():
        definition["variants"] = sorted(memberships[source, x, alternative])
    return result


def _tile_reference(content: dict) -> dict:
    catalogs = content.get("catalogs", {})
    require(type(catalogs.get("tile_types")) is dict and type(catalogs.get("solid_tile_types")) is dict,
            "Frozen tile identity catalogs are missing")
    names = {}
    for entry in catalogs["tile_types"]["entries"]:
        index = entry.get("value", {}).get("source_index")
        require(type(index) is int and index >= 0 and index not in names, "Invalid frozen tile index")
        names[index] = entry["id"]
    require(set(names) == set(range(len(names))), "Frozen tile indices are not contiguous")
    solid_names = {entry["id"] for entry in catalogs["solid_tile_types"]["entries"]}
    declarations = [entry for entry in content.get("declarations", [])
                    if entry.get("source", {}).get("path") == "res://scripts/data/tiles.gd" and
                    entry.get("source", {}).get("constant") == "CHARS"]
    require(len(declarations) == 1 and type(declarations[0].get("value")) is dict,
            "Frozen tile character mapping is missing")
    return {"names": names, "solid": solid_names, "chars": declarations[0]["value"]}


def _validate_native_geometry(snapshot: dict, native_tiles: dict, tile_reference: dict) -> None:
    """Compare captured cells with actual atlas definitions and frozen tile rules."""
    map_data = _map(decode_wire(snapshot["mapData"]), "loaded map")
    rows = _sequence(map_data.get("rows"), "loaded rows")
    expected_solid = set()
    for x, y, source, atlas_x, atlas_y, alternative in snapshot["terrain"]["cells"]:
        definition = native_tiles.get((source, atlas_x, atlas_y, alternative))
        require(definition is not None, "Native cell references an uncaptured atlas tile/alternative")
        name = tile_reference["names"].get(atlas_x)
        require(name is not None, "Native atlas index has no preserved tile identity")
        # The exact source mapping is retained in the reference and rule source.
        # These coordinate choices are the current renderer's deterministic
        # identity transform, not a guessed variant count or a new terrain rule.
        expected_name = tile_reference["chars"].get(rows[y][x], "grass")
        blend = (x * 7 + y * 13 + x * y) % 11
        if expected_name == "grass":
            expected_name = "grass_flowers" if blend < 1 else "grass_tufts" if blend < 5 else "grass"
        elif expected_name == "snow" and blend < 3:
            expected_name = "snow_tufts"
        elif expected_name == "dune_sand" and blend < 3:
            expected_name = "dune_tufts"
        elif expected_name == "marsh_grass" and blend < 3:
            expected_name = "marsh_tufts"
        require(name == expected_name, "Actual native atlas tile disagrees with loaded terrain rows")
        variants = definition["variants"]
        require(variants == list(range(len(variants))) and bool(variants), "Native atlas variant membership is incomplete")
        expected_variant = (x * 17 + y * 31 + x * y * 3) % len(variants)
        require(atlas_y == expected_variant, "Native atlas coordinate differs from the frozen renderer mapping")
        require(bool(definition["polygons"]) == (name in tile_reference["solid"]),
                "Actual native collision polygons disagree with tile solidity")
        if definition["polygons"]:
            expected_solid.add((x, y))
    fountains = map_data.get("fountains", [])
    for fountain in _sequence(fountains, "fountain footprints"):
        fountain = _map(fountain, "fountain")
        pos, size = _sequence(fountain.get("pos"), "fountain tile"), _sequence(fountain.get("size", [2, 2]), "fountain size")
        require(len(pos) == len(size) == 2 and all(type(number) is int for number in [*pos, *size]),
                "Invalid fountain footprint")
        for y in range(pos[1], pos[1] + size[1]):
            for x in range(pos[0], pos[0] + size[0]):
                expected_solid.add((x, y))
    for node in snapshot["scene"]:
        if node["script"] != "res://scripts/entities/region_landmark.gd":
            continue
        fields = _map(decode_wire(node["fields"]), "landmark fields")
        cells = fields.get("cells")
        require(isinstance(cells, WireValue) and cells.type == "Rect2i", "Native landmark footprint is missing")
        position = _vector(cells.value[0], "landmark cell origin", integer=True)
        size = _vector(cells.value[1], "landmark cell size", integer=True)
        require(all(number > 0 for number in size), "Native landmark footprint is empty")
        for y in range(position[1], position[1] + size[1]):
            for x in range(position[0], position[0] + size[0]):
                expected_solid.add((x, y))
    require(expected_solid == {tuple(cell) for cell in snapshot["terrain"]["solidCells"]},
            "Actual solid-cell membership differs from native tiles, fountains and landmark footprints")


def validate_world_export(directory: Path, reference_root: Path) -> dict:
    """Validate every indexed snapshot against the frozen map identity inventory."""
    directory = Path(directory)
    require(directory.is_dir() and not any(path.is_symlink() for path in [directory, *directory.parents]),
            "World export directory must be an ordinary local directory")
    index = _read_json(directory / "index.json")
    require(index.get("schema") == INDEX_SCHEMA and type(index.get("scenarios")) is list and
            type(index.get("snapshots")) is list, "Wrong world export index schema")
    reference = _reference_root(reference_root)
    repository = reference.parents[1]
    _validate_index_provenance(index, repository)
    content, maps, _save = _validated_reference_inputs(repository)
    map_lookup = _reference_maps(maps)
    require(len(map_lookup) == 37 and maps.get("map_count") == 37, "Complete export requires all 37 frozen maps")
    require(index.get("failures", []) == [], "World exporter reported failed captures")
    shared = index.get("shared")
    require(type(shared) is list and len(shared) == 1 and type(shared[0]) is dict and
            {"path", "sha256", "bytes"} <= set(shared[0]) and shared[0]["path"] == "tile-set.json",
            "World export requires exactly one indexed native tile set")
    shared = shared[0]
    shared_path = _safe_file(directory, shared["path"])
    require(type(shared["bytes"]) is int and 0 < shared["bytes"] <= MAX_JSON_BYTES and
            shared_path.is_file() and shared_path.stat().st_size <= 2 * shared["bytes"] and
            type(shared["sha256"]) is str and re.fullmatch(r"[0-9a-f]{64}", shared["sha256"]) is not None and
            len(canonical_wire_bytes(shared_path)) == shared["bytes"] and
            hashlib.sha256(canonical_wire_bytes(shared_path)).hexdigest() == shared["sha256"],
            "Shared tile set size/checksum differs from index")
    native_tiles = _native_tiles(_read_json(shared_path))
    tile_reference = _tile_reference(content)
    coverage, coverage_path = _coverage_contract(reference, maps)
    safe_calls = {(owner, entry["function"]) for entry in coverage.get("safeProjections", [])
                  for owner in entry.get("ownerScripts", [entry["path"]])}
    scenarios, expected_pairs = {}, set()
    baseline_ids = []
    for scenario in index["scenarios"]:
        require(type(scenario) is dict and type(scenario.get("id")) is str and
                SAFE_ID.fullmatch(scenario["id"]) is not None and type(scenario.get("maps")) is list,
                "Malformed world scenario descriptor")
        scenario_id, scenario_maps = scenario["id"], scenario["maps"]
        require(scenario_id not in scenarios and 0 < len(scenario_maps) == len(set(scenario_maps)) and
                all(type(map_id) is str and map_id in map_lookup for map_id in scenario_maps),
                "Duplicate scenario or invalid scenario map coverage")
        require(scenario.get("offlineGrowth") is False and scenario.get("personalSavesUsed") is False,
                "World scenarios must explicitly exclude personal saves and offline growth")
        scenarios[scenario_id] = scenario
        expected_pairs.update((scenario_id, map_id) for map_id in scenario_maps)
        if scenario.get("baseline") is True or scenario_id in {"baseline", "fresh_baseline"}:
            require(set(scenario_maps) == set(map_lookup), "Fresh baseline must cover all 37 maps")
            baseline_ids.append(scenario_id)
    require(len(baseline_ids) == 1 and 0 < len(index["snapshots"]) <= MAX_SNAPSHOTS,
            "World export needs exactly one complete fresh baseline")
    require(set(coverage["requiredScenarios"]) <= set(scenarios), "World export omits required state witnesses")
    summaries, seen_pairs, seen_paths, total_bytes = [], set(), set(), 0
    baseline_totals = {"registrySlots": 0, "appendedResources": 0, "disabledSlots": 0, "tiles": 0}
    for entry in index["snapshots"]:
        require(type(entry) is dict and {"scenarioId", "mapId", "path", "sha256", "bytes"} <= set(entry),
                "World snapshot index record is incomplete")
        pair = (entry["scenarioId"], entry["mapId"])
        require(pair in expected_pairs and pair not in seen_pairs, "Unexpected or duplicate scenario/map snapshot")
        seen_pairs.add(pair)
        expected_path = f"snapshots/{pair[0]}/{pair[1]}.json"
        require(entry["path"] == expected_path and expected_path not in seen_paths,
                "World snapshot path does not match its identities")
        seen_paths.add(expected_path)
        path = _safe_file(directory, entry["path"])
        require(type(entry["bytes"]) is int and 0 < entry["bytes"] <= MAX_JSON_BYTES and
                path.is_file() and path.stat().st_size <= 2 * entry["bytes"] and
                len(canonical_wire_bytes(path)) == entry["bytes"], "World snapshot byte count differs")
        total_bytes += entry["bytes"]
        require(total_bytes <= MAX_TOTAL_BYTES and type(entry["sha256"]) is str and
                re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]) is not None and
                hashlib.sha256(canonical_wire_bytes(path)).hexdigest() == entry["sha256"], "World snapshot checksum differs")
        snapshot = _read_json(path)
        require((snapshot.get("scenarioId"), snapshot.get("mapId")) == pair, "Snapshot identity differs from index")
        try:
            summary = validate_snapshot(snapshot, maps)
            _validate_native_geometry(snapshot, native_tiles, tile_reference)
        except WorldDataError as error:
            raise WorldDataError(f"{pair[0]}/{pair[1]}: {error}") from error
        for call in snapshot["projectionCalls"]:
            require((call["script"], call["method"]) in safe_calls and
                    call.get("timeAdvanced") == 0 and type(call.get("timeAdvanced")) in {int, float} and
                    type(call.get("reason")) is str and bool(call["reason"].strip()),
                    "Projection call is not an explicitly explained zero-time source whitelist entry")
        summaries.append(summary)
        if pair[0] == baseline_ids[0]:
            for field in baseline_totals:
                baseline_totals[field] += summary[field]
    require(seen_pairs == expected_pairs, "World export omits scenario/map snapshots")
    require(baseline_totals["registrySlots"] == 905 and baseline_totals["appendedResources"] == 75 and
            baseline_totals["disabledSlots"] == 10 and baseline_totals["tiles"] == 49758,
            "Fresh baseline does not preserve the complete frozen world totals")
    _validate_export_file_set(directory, seen_paths | {"index.json", "tile-set.json"})
    return {"schemaVersion": 1, "success": True, "phase": 5, "scenarios": len(scenarios),
            "snapshots": len(summaries), "baselineScenario": baseline_ids[0], "baseline": baseline_totals,
            "safeArrivals": sum(row["safeArrivals"] for row in summaries),
            "sceneNodes": sum(row["sceneNodes"] for row in summaries),
            "collisionBodies": sum(row["collisionBodies"] for row in summaries),
            "shapes": sum(row["shapes"] for row in summaries), "bytes": total_bytes,
            "nativeAtlasTiles": len(native_tiles),
            "coverageContract": {"file": "migration/world-coverage.json",
                                 "sha256": hashlib.sha256(_canonical(coverage)).hexdigest(),
                                 "requiredScenarios": len(coverage["requiredScenarios"])},
            "engineExecutedByVerifier": False, "playerSavesUsed": False,
            "snapshotSummaries": summaries}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--reference-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = validate_world_export(args.directory, args.reference_root)
    if args.output:
        require(not args.output.exists(), "World verification output already exists")
        args.output.write_bytes(_canonical(report) + b"\n")
    print(json.dumps({key: value for key, value in report.items() if key != "snapshotSummaries"}, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (WorldDataError, OSError) as error:
        print(f"WORLD DATA FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
