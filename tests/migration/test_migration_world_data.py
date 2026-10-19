"""Meaningful malformed wire and loaded-world identity/geometry checks."""
from __future__ import annotations

import copy
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import migration_world_data as world


def wire(value):
    """Small independent fixture writer; production data comes from real Godot."""
    if value is None:
        return {"kind": "nil"}
    if type(value) is bool:
        return {"kind": "bool", "value": value}
    if type(value) is int:
        return {"kind": "int", "value": str(value)}
    if type(value) is float:
        return {"kind": "float", "value": repr(value)}
    if type(value) is str:
        return {"kind": "string", "value": value}
    if type(value) is list:
        return {"kind": "array", "type": "Array", "values": [wire(item) for item in value]}
    if type(value) is dict:
        return {"kind": "dictionary", "entries": [[wire(key), wire(item)] for key, item in value.items()]}
    raise TypeError(value)


def vector(x=0.0, y=0.0, integer=False):
    return {"kind": "vector", "type": "Vector2i" if integer else "Vector2", "values": [wire(x), wire(y)]}


def transform(x=0.0, y=0.0):
    return {"kind": "transform2d", "x": vector(1.0, 0.0), "y": vector(0.0, 1.0), "origin": vector(x, y)}


def dictionary_nodes(entries):
    return {"kind": "dictionary", "entries": [[wire(key), value] for key, value in entries.items()]}


def native_tile_fixture():
    # Two variants deliberately prove the verifier reads actual atlas membership
    # rather than blindly assuming the current game's eight variants.
    tiles = []
    for x in range(3):
        for y in range(2):
            tiles.append(dictionary_nodes({"atlas": vector(x, y, True), "alternative": wire(0),
                "layers": wire([{"layer": 0, "collision_layer": 1, "collision_mask": 1, "polygons": []}])}))
    source = dictionary_nodes({"id": wire(0), "texture": {"kind": "resource_ref", "class": "CompressedTexture2D",
                                                           "path": "res://assets/native.png"},
                               "region_size": vector(32, 32, True),
                               "tiles": {"kind": "array", "type": "Array", "values": tiles}})
    return dictionary_nodes({"tile_size": vector(32, 32, True), "physics_layers": wire(1),
                             "sources": {"kind": "array", "type": "Array", "values": [source]}})


def native_geometry_snapshot():
    snapshot = minimal_snapshot()
    for cell in snapshot["terrain"]["cells"]:
        x, y = cell[:2]
        blend = (x * 7 + y * 13 + x * y) % 11
        cell[3] = 1 if blend < 1 else 2 if blend < 5 else 0
        cell[4] = (x * 17 + y * 31 + x * y * 3) % 2
    return snapshot


def minimal_reference():
    objects = [
        {"type": "chest", "pos": [3, 3], "contents": [["potion", 1]]},
        {"type": "enemy", "kind": "slime", "pos": [4, 3], "enabled": False},
    ]
    return {"maps": [{"id": "demo", "width": 6, "height": 6,
                     "object_slots": [
                         {"index": index, "type": obj["type"], "enabled": obj.get("enabled", True),
                          "authored_id": obj.get("id"), "legacy_slot_key": f"{obj['type']}:demo:{index}"}
                         for index, obj in enumerate(objects)],
                     "post_registry_legacy_resources": [
                         {"id": "demo:herb", "value": {"type": "profession_resource", "id": "demo:herb",
                                                         "kind": "herbs", "pos": [4, 4]}}],
                     "registry_snapshot": {"rows": ["......"] * 6, "spawns": {"start": [2, 2]},
                                           "objects": objects}}]}


def scene_node(address, parent, cls="Node2D"):
    return {"address": address, "parent": parent, "class": cls, "script": "", "groups": [],
            "localTransform": transform(), "globalTransform": transform(), "visible": True,
            "fields": wire({}), "omissions": []}


def minimal_snapshot():
    reference = minimal_reference()["maps"][0]
    data = copy.deepcopy(reference["registry_snapshot"])
    data["objects"] += [copy.deepcopy(reference["post_registry_legacy_resources"][0]["value"])]
    slots = [{"index": index, "registryIndex": index if index < 2 else None,
              "appendOrder": 0 if index == 2 else None, "type": obj["type"],
              "legacySlotKey": f"{obj['type']}:demo:{index}",
              "enabled": obj.get("enabled", True), "conditionsPassed": True}
             for index, obj in enumerate(data["objects"])]
    scene = [scene_node(["entities"], None), scene_node(["ground"], None),
             scene_node(["entities", 0], ["entities"], "StaticBody2D"),
             scene_node(["entities", 0, 0], ["entities", 0], "CollisionShape2D")]
    scene[2]["collision"] = {"layer": 1, "mask": 0}
    scene[3]["shape"] = {"class": "RectangleShape2D", "disabled": False,
                         "parameters": {"kind": "dictionary", "entries": [[wire("size"), vector(22.0, 12.0)]]}}
    state = {"map_id": "demo", "play_time": 10.0, "ng_plus": 0, "flags": {}}
    return {"schema": world.SNAPSHOT_SCHEMA, "scenarioId": "fresh_baseline", "mapId": "demo",
            "stage": "loaded_projection", "units": {"tilePixels": 32, "yAxis": "down"},
            "mapData": wire(data), "stateBefore": wire(state), "stateAfter": wire(state), "slots": slots,
            "terrain": {"width": 6, "height": 6,
                        "cells": [[x, y, 0, 0, 0, 0] for y in range(6) for x in range(6)], "solidCells": []},
            "scene": scene, "tileSet": wire({"shared": "tile-set.json"}),
            "environment": wire({}), "derived": wire({"irrigation_wet": {}, "irrigation_flow": {},
                                                       "natural_water_sources": {}, "pollen_flowers": 0}),
            "arrivals": [{"name": "start", "nominal": vector(80.0, 80.0),
                          "resolved": vector(80.0, 80.0), "fits": True}], "projectionCalls": []}


class CanonicalWireFloatTests(unittest.TestCase):
    def test_windows_linux_decimal_spellings_have_one_bit_exact_form(self):
        for windows, linux in (("0.29999999999999999", "0.299999999999999989"),
                               ("0.73000001907348633", "0.730000019073486328")):
            with self.subTest(windows=windows, linux=linux):
                first = world.canonicalize_wire_floats({"kind": "float", "value": windows})
                second = world.canonicalize_wire_floats({"kind": "float", "value": linux})
                self.assertEqual(first, second)
                self.assertEqual(struct.pack(">d", float(first["value"])),
                                 struct.pack(">d", float(windows)))
                self.assertEqual(world.canonicalize_wire_floats(first), first)

    def test_adjacent_binary64_values_remain_distinct(self):
        first = world.canonicalize_wire_floats({"kind": "float", "value": "1.0"})
        second = world.canonicalize_wire_floats({"kind": "float", "value": "1.0000000000000002"})
        self.assertNotEqual(first, second)
        self.assertEqual(float(second["value"]), math.nextafter(1.0, math.inf))

    def test_negative_zero_keeps_its_sign(self):
        positive = world.canonicalize_wire_floats({"kind": "float", "value": "0.00000000000000000"})
        negative = world.canonicalize_wire_floats({"kind": "float", "value": "-0.00000000000000000"})
        self.assertEqual(positive["value"], "0.0")
        self.assertEqual(negative["value"], "-0.0")
        self.assertNotEqual(struct.pack(">d", float(positive["value"])),
                            struct.pack(">d", float(negative["value"])))

    def test_smallest_subnormal_and_maximum_finite_value_roundtrip(self):
        for text in ("4.94065645841246544e-324", "-4.94065645841246544e-324",
                     "1.7976931348623157081e+308", "-1.7976931348623157081e+308"):
            with self.subTest(number=text):
                result = world.canonicalize_wire_floats({"kind": "float", "value": text})
                self.assertEqual(struct.pack(">d", float(result["value"])), struct.pack(">d", float(text)))
                self.assertTrue(math.isfinite(float(result["value"])))
                self.assertNotEqual(float(result["value"]), 0)

    def test_other_types_strings_and_float_lookalikes_are_unchanged(self):
        original = {
            "integer": {"kind": "int", "value": "9223372036854775807"},
            "string": {"kind": "string", "value": "0.299999999999999989"},
            "stringName": {"kind": "string_name", "value": "0.299999999999999989"},
            "extra": {"kind": "float", "value": "0.299999999999999989", "note": "lookalike"},
            "native": {"kind": "float", "value": 0.3},
            "ordinary": [None, True, 9223372036854775807, 0.3, "0.299999999999999989"],
        }
        result = world.canonicalize_wire_floats(original)
        self.assertEqual(result, original)
        self.assertIsNot(result, original)
        self.assertIsNot(result["ordinary"], original["ordinary"])
        self.assertIs(type(result["ordinary"][2]), int)
        self.assertIs(type(result["ordinary"][3]), float)

    def test_nested_wire_keys_array_and_dictionary_order_and_input_survive(self):
        original = {"second": {"kind": "dictionary", "entries": [
            [{"kind": "float", "value": "0.299999999999999989"}, wire("first")],
            [wire("second"), {"kind": "array", "type": "PackedFloat64Array", "values": [
                {"value": "0.730000019073486328", "kind": "float"}, wire(2.0)]}]
        ]}, "first": 2}
        before = copy.deepcopy(original)
        result = world.canonicalize_wire_floats(original)
        self.assertEqual(original, before)
        self.assertEqual(list(result), ["second", "first"])
        entries = result["second"]["entries"]
        self.assertEqual(entries[0], [{"kind": "float", "value": "0.3"}, wire("first")])
        self.assertEqual(entries[1][0], wire("second"))
        self.assertEqual(list(entries[1][1]["values"][0]), ["value", "kind"])
        self.assertEqual(entries[1][1]["values"][0]["value"], "0.7300000190734863")
        self.assertEqual(entries[1][1]["values"][1], wire(2.0))

    def test_nonfinite_overflow_underflow_and_nondecimal_text_are_rejected(self):
        for text in ("NaN", "nan", "Infinity", "-Infinity", "1e999", "-1e999", "1e-999",
                     "0x1p0", "+0.3", "01.5"):
            with self.subTest(number=text), self.assertRaises(world.WorldDataError):
                world.canonicalize_wire_floats({"kind": "float", "value": text})

    def test_cycles_and_excessive_nesting_are_rejected(self):
        cycle = []
        cycle.append(cycle)
        with self.assertRaises(world.WorldDataError):
            world.canonicalize_wire_floats(cycle)
        nested = None
        for _ in range(world.MAX_DEPTH + 1):
            nested = [nested]
        with self.assertRaises(world.WorldDataError):
            world.canonicalize_wire_floats(nested)


class WorldWireTests(unittest.TestCase):
    def reject(self, node):
        with self.assertRaises(world.WorldDataError):
            world.validate_wire(node)

    def test_scalar_types_do_not_collapse(self):
        decoded = world.decode_wire(wire([None, True, 1, 1.0, "1"]))
        self.assertEqual([type(item) for item in decoded], [type(None), bool, int, float, str])

    def test_stringname_nodepath_and_math_are_data_only_sentinels(self):
        name = world.decode_wire({"kind": "string_name", "value": "name"})
        path = world.decode_wire({"kind": "node_path", "value": "../Body"})
        vec = world.decode_wire(vector(3, 4, True))
        self.assertEqual(name, world.WireValue("StringName", "name"))
        self.assertEqual(path.type, "NodePath")
        self.assertEqual(vec, world.WireValue("Vector2i", (3, 4)))

    def test_dictionary_order_and_typed_keys_survive(self):
        value = {"kind": "dictionary", "entries": [[wire(True), wire("bool")], [wire(1), wire("int")],
                                                    [wire(1.0), wire("float")], [vector(1, 2, True), wire("cell")]]}
        decoded = world.decode_wire(value)
        self.assertIsInstance(decoded, world.WireDictionary)
        self.assertEqual([type(key) for key, _ in decoded.entries], [bool, int, float, world.WireValue])
        self.assertEqual(decoded.get(True), "bool")
        self.assertEqual(decoded.get(1), "int")
        self.assertEqual(decoded.get(1.0), "float")

    def test_negative_zero_and_godot_decimal_float_text_are_preserved(self):
        self.assertEqual(world.decode_wire({"kind": "float", "value": "1.0000000000000002"}), 1.0000000000000002)
        self.assertLess(math.copysign(1, world.decode_wire({"kind": "float", "value": "-0.0"})), 0)
        self.assertIs(type(world.decode_wire({"kind": "float", "value": "1"})), float)

    def test_signed64_boundaries_are_exact(self):
        for number in (-(2 ** 63), 2 ** 63 - 1):
            self.assertEqual(world.decode_wire(wire(number)), number)
        self.reject(wire(2 ** 63))
        self.reject({"kind": "int", "value": "01"})
        self.reject({"kind": "int", "value": "-0"})

    def test_nonfinite_and_lossy_underflow_floats_are_rejected(self):
        for text in ("nan", "NaN", "Infinity", "1e999", "1e-999", "01.5", "+1.0"):
            with self.subTest(number=text):
                self.reject({"kind": "float", "value": text})

    def test_every_nested_value_must_be_typed(self):
        self.reject({"kind": "array", "type": "Array", "values": [1]})
        self.reject({"kind": "dictionary", "entries": [["id", wire(1)]]})

    def test_duplicate_semantic_float_keys_are_rejected(self):
        self.reject({"kind": "dictionary", "entries": [[{"kind": "float", "value": "1"}, wire("a")],
                                                         [{"kind": "float", "value": "1.0"}, wire("b")]]})

    def test_packed_array_type_and_bounds_are_checked(self):
        good = {"kind": "array", "type": "PackedByteArray", "values": [wire(0), wire(255)]}
        self.assertEqual(world.decode_wire(good), world.WireValue("PackedByteArray", (0, 255)))
        self.reject({**good, "values": [wire(256)]})
        self.reject({**good, "values": [wire(1.0)]})
        self.reject({"kind": "array", "values": []})

    def test_packed_vector_array_keeps_type(self):
        good = {"kind": "array", "type": "PackedVector2Array", "values": [vector(1.0, 2.0)]}
        self.assertEqual(world.decode_wire(good).value[0].type, "Vector2")
        self.reject({**good, "values": [vector(1, 2, True)]})

    def test_vector_and_rect_component_kinds_are_checked(self):
        self.reject(vector(1, 2, False))
        self.reject(vector(2 ** 31, 0, True))
        good = {"kind": "rect", "type": "Rect2i", "position": vector(1, 2, True), "size": vector(3, 4, True)}
        self.assertEqual(world.decode_wire(good).type, "Rect2i")
        self.reject({**good, "position": vector(1.0, 2.0)})

    def test_resource_paths_are_never_loaded_or_executed(self):
        good = {"kind": "resource_ref", "class": "GDScript", "path": "res://scripts/world.gd"}
        self.assertEqual(world.decode_wire(good).value, ("GDScript", "res://scripts/world.gd"))
        self.reject({**good, "path": "C:/Users/player/secret"})
        self.reject({**good, "path": "https://host/code"})
        self.reject({**good, "path": "res://../outside"})

    def test_node_refs_use_structural_addresses(self):
        for address in (["world"], ["autoload", "GameState"], ["entities", 1, 0],
                        ["ui", "ground", 1, 0], ["outside", "Node2D", ""]):
            self.assertEqual(world.decode_wire({"kind": "node_ref", "address": address}).type, "NodeReference")
        for address in (["entities", "@Node2D@9182"], ["entities", -1], ["RID", 9182]):
            self.reject({"kind": "node_ref", "address": address})

    def test_runtime_handles_have_explicit_nonexecutable_reasons(self):
        value = {"kind": "runtime_handle", "type": "Callable", "reason": "Callback excluded; rule source retained"}
        self.assertEqual(world.decode_wire(value).type, "RuntimeHandle")
        self.reject({**value, "reason": ""})
        self.reject({**value, "object_id": 1234})

    def test_cycles_depth_and_invalid_unicode_are_rejected(self):
        value = {"kind": "array", "type": "Array", "values": []}
        value["values"].append(value)
        self.reject(value)
        value = wire(None)
        for _ in range(world.MAX_DEPTH + 1):
            value = {"kind": "array", "type": "Array", "values": [value]}
        self.reject(value)
        self.reject({"kind": "string", "value": "\ud800"})


class LoadedSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.reference = minimal_reference()
        self.snapshot = minimal_snapshot()

    def reject(self):
        with self.assertRaises(world.WorldDataError):
            world.validate_snapshot(self.snapshot, self.reference)

    def test_complete_loaded_snapshot_validates_without_engine(self):
        report = world.validate_snapshot(self.snapshot, self.reference)
        self.assertTrue(report["success"])
        self.assertEqual((report["registrySlots"], report["appendedResources"], report["disabledSlots"]), (2, 1, 1))
        self.assertEqual(report["shapes"], 1)
        self.assertFalse(report["engineExecutedByVerifier"])

    def test_disabled_slot_cannot_be_removed_or_renumbered(self):
        self.snapshot["slots"].pop(1)
        self.reject()

    def test_appended_resource_keeps_exact_final_index_and_explicit_id(self):
        self.snapshot["slots"][-1]["index"] = 1
        self.reject()
        self.snapshot = minimal_snapshot()
        objects = next(pair[1] for pair in self.snapshot["mapData"]["entries"] if pair[0]["value"] == "objects")
        resource = objects["values"][-1]
        next(pair for pair in resource["entries"] if pair[0]["value"] == "id")[1] = wire("demo:renamed")
        self.reject()

    def test_generic_legacy_key_cannot_be_rebuilt_from_filtered_order(self):
        self.snapshot["slots"][-1]["legacySlotKey"] = "profession_resource:demo:1"
        self.reject()

    def test_full_tile_membership_and_bounds_are_checked(self):
        self.snapshot["terrain"]["cells"].pop()
        self.reject()
        self.snapshot = minimal_snapshot()
        self.snapshot["terrain"]["cells"][-1][0] = 6
        self.reject()

    def test_duplicate_native_tile_is_rejected(self):
        self.snapshot["terrain"]["cells"][-1] = self.snapshot["terrain"]["cells"][0][:]
        self.reject()

    def test_solid_cells_are_bounded_and_unique(self):
        self.snapshot["terrain"]["solidCells"] = [[0, 0], [0, 0]]
        self.reject()

    def test_nested_collision_geometry_is_retained(self):
        report = world.validate_snapshot(self.snapshot, self.reference)
        self.assertEqual(report["collisionBodies"], 1)
        self.assertEqual(report["shapes"], 1)
        self.snapshot["scene"][-1]["shape"]["parameters"] = wire({})
        self.reject()

    def test_duplicate_scene_address_or_missing_parent_is_rejected(self):
        self.snapshot["scene"].append(copy.deepcopy(self.snapshot["scene"][-1]))
        self.reject()
        self.snapshot = minimal_snapshot()
        self.snapshot["scene"][-1]["parent"] = ["ground"]
        self.reject()

    def test_negative_or_boolean_collision_layer_is_not_an_integer_mask(self):
        self.snapshot["scene"][2]["collision"]["layer"] = True
        self.reject()

    def test_missing_unsafe_or_solid_arrival_fails(self):
        self.snapshot["arrivals"][0]["fits"] = False
        self.reject()
        self.snapshot = minimal_snapshot()
        self.snapshot["terrain"]["solidCells"] = [[2, 2]]
        self.reject()
        self.snapshot = minimal_snapshot()
        self.snapshot["arrivals"] = []
        self.reject()

    def test_opening_arrival_offset_is_source_state_dependent(self):
        snapshot = minimal_snapshot()
        reference = minimal_reference()
        reference["maps"][0]["id"] = "village"
        for slot in reference["maps"][0]["object_slots"]:
            slot["legacy_slot_key"] = slot["legacy_slot_key"].replace(":demo:", ":village:")
        snapshot["mapId"] = "village"
        for slot in snapshot["slots"]:
            slot["legacySlotKey"] = slot["legacySlotKey"].replace(":demo:", ":village:")
        snapshot["stateBefore"] = snapshot["stateAfter"] = wire({"play_time": 0.0, "ng_plus": 0, "flags": {"op_new_adventure": True}})
        snapshot["arrivals"][0]["nominal"] = vector(80.0, 128.0)
        self.assertTrue(world.validate_snapshot(snapshot, reference)["success"])

    def test_shared_native_tile_set_reference_is_explicit(self):
        self.snapshot["tileSet"] = wire({"shared": "../private.json"})
        self.reject()

    def test_dynamic_role_ids_can_be_shared_by_spatial_instances(self):
        for index in (2, 3):
            self.snapshot["scene"][index]["fields"] = wire({"id": "rf_tracks"})
        self.assertTrue(world.validate_snapshot(self.snapshot, self.reference)["success"])

    def test_atmosphere_root_and_typed_lights_are_part_of_scene_capture(self):
        atmosphere = scene_node(["atmosphere"], None)
        atmosphere["light"] = wire({"enabled": True, "energy": 0.5})
        self.snapshot["scene"].append(atmosphere)
        self.assertTrue(world.validate_snapshot(self.snapshot, self.reference)["success"])
        self.snapshot["scene"][-1]["light"] = {"energy": 0.5}
        self.reject()

    def test_irrigation_membership_and_pollen_count_remain_typed(self):
        self.snapshot["derived"] = wire({"irrigation_wet": {}, "irrigation_flow": {},
                                          "natural_water_sources": {}, "pollen_flowers": True})
        self.reject()

    def test_projection_cannot_advance_active_play_time(self):
        self.snapshot["stateAfter"] = wire({"map_id": "demo", "play_time": 11.0, "ng_plus": 0, "flags": {}})
        self.reject()


class WorldFileBoundaryTests(unittest.TestCase):
    def test_all_physical_files_must_be_indexed_even_when_not_json(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-World-Tests-") as temporary:
            root = Path(temporary)
            (root / "index.json").write_text("{}", encoding="utf-8")
            world._validate_export_file_set(root, {"index.json"})
            for filename in ("private.log", "unexpected.txt", "unlisted.bin"):
                path = root / filename
                path.write_bytes(b"unexpected payload")
                with self.subTest(filename=filename), self.assertRaises(world.WorldDataError):
                    world._validate_export_file_set(root, {"index.json"})
                path.unlink()

    def test_symlinked_files_and_directories_cannot_hide_outside_json_scan(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-World-Tests-") as temporary:
            base = Path(temporary)
            root, outside = base / "world", base / "outside"
            root.mkdir()
            outside.mkdir()
            (root / "index.json").write_text("{}", encoding="utf-8")
            target = outside / "data.bin"
            target.write_bytes(b"owned isolated test fixture")
            for name, destination, is_directory in (("linked.bin", target, False), ("linked-directory", outside, True)):
                link = root / name
                try:
                    os.symlink(destination, link, target_is_directory=is_directory)
                except (OSError, NotImplementedError) as error:
                    self.skipTest("This host cannot create test-owned symbolic links: " + str(error))
                try:
                    with self.subTest(kind=name), self.assertRaises(world.WorldDataError):
                        world._validate_export_file_set(root, {"index.json"})
                finally:
                    link.unlink()

    def test_index_provenance_identifies_exact_exporter_sources(self):
        index = {"valueEncoding": "bluemap.world.variant.v2", "baselineCommit": world.BASELINE_COMMIT,
                 "baselineTree": world.BASELINE_TREE,
                 "exporterSources": {source: hashlib.sha256((ROOT / source[6:]).read_bytes().replace(b'\r\n', b'\n')).hexdigest()
                                     for source in world.EXPORTER_SOURCES}}
        world._validate_index_provenance(index, ROOT)
        index["exporterSources"][world.EXPORTER_SOURCES[0]] = "0" * 64
        with self.assertRaises(world.WorldDataError):
            world._validate_index_provenance(index, ROOT)

    def test_index_cannot_claim_another_baseline_or_wire_version(self):
        for field, value in (("baselineCommit", "0" * 40), ("valueEncoding", "bluemap.portable.variant.v1")):
            with self.subTest(field=field):
                index = {"valueEncoding": "bluemap.world.variant.v2", "baselineCommit": world.BASELINE_COMMIT,
                         "baselineTree": world.BASELINE_TREE, "exporterSources": {}}
                index[field] = value
                with self.assertRaises(world.WorldDataError):
                    world._validate_index_provenance(index, ROOT)

    def test_changed_phase4_reference_is_rejected_without_touching_real_inputs(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-World-Tests-") as temporary:
            root = Path(temporary)
            reference = root / "migration/reference"
            reference.mkdir(parents=True)
            for name in ("content-inventory.json", "maps-inventory.json", "save-contract.json", "source-manifest.json"):
                (reference / name).write_bytes((ROOT / "migration/reference" / name).read_bytes())
            content = json.loads((reference / "content-inventory.json").read_text(encoding="utf-8"))
            content["source_version"] = "changed synthetic reference"
            (reference / "content-inventory.json").write_text(json.dumps(content), encoding="utf-8")
            with self.assertRaisesRegex(world.WorldDataError, "Frozen phase4 reference"):
                world._validated_reference_inputs(root)

    def test_traversal_and_windows_ambiguous_paths_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-World-Tests-") as temporary:
            root = Path(temporary)
            for path in ("../escape.json", "/absolute.json", "C:/outside.json", "snapshots\\escape.json",
                         "snapshots/./escape.json", "snapshots/trailing. /escape.json"):
                with self.subTest(path=path), self.assertRaises(world.WorldDataError):
                    world._safe_file(root, path)

    def test_duplicate_json_keys_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-World-Tests-") as temporary:
            path = Path(temporary) / "bad.json"
            path.write_text('{"schema":1,"schema":2}', encoding="utf-8")
            with self.assertRaises(world.WorldDataError):
                world._read_json(path)

    def test_windows_crlf_checkout_keeps_the_same_wire_bytes_and_strings(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-World-Tests-") as temporary:
            path = Path(temporary) / "wire.json"
            value = wire({"text": "an escaped\r\nsource string", "value": 1.0})
            lf = json.dumps(value, ensure_ascii=False, indent=2).encode("utf-8") + b"\n"
            path.write_bytes(lf.replace(b"\n", b"\r\n"))
            self.assertEqual(world.canonical_wire_bytes(path), lf)
            self.assertEqual(hashlib.sha256(world.canonical_wire_bytes(path)).digest(), hashlib.sha256(lf).digest())
            decoded = world.decode_wire(world._read_json(path))
            self.assertEqual(decoded["text"], "an escaped\r\nsource string")

    def test_overflowing_json_metadata_is_not_accepted_as_infinity(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-World-Tests-") as temporary:
            path = Path(temporary) / "bad.json"
            path.write_text('{"seed":1e999}', encoding="utf-8")
            with self.assertRaises(world.WorldDataError):
                world._read_json(path)

    def test_optional_current_real_export(self):
        # Root supplies this only after running the real isolated Godot export.
        # Synthetic fixtures above never masquerade as a complete world export.
        fixture = ROOT / "migration/world/index.json"
        if not fixture.is_file():
            self.skipTest("Complete source-engine world export not yet supplied")
        report = world.validate_world_export(fixture.parent, ROOT)
        self.assertEqual(report["baseline"]["registrySlots"], 905)
        self.assertEqual(report["baseline"]["appendedResources"], 75)


class NativeAtlasTests(unittest.TestCase):
    def setUp(self):
        self.native = world._native_tiles(native_tile_fixture())
        self.tile_reference = {"names": {0: "grass", 1: "grass_flowers", 2: "grass_tufts"},
                               "solid": set(), "chars": {".": "grass"}}
        self.snapshot = native_geometry_snapshot()

    def test_actual_native_atlas_membership_drives_validation(self):
        self.assertEqual(len(self.native), 6)
        world._validate_native_geometry(self.snapshot, self.native, self.tile_reference)

    def test_cell_cannot_reference_a_missing_actual_atlas_tile(self):
        self.snapshot["terrain"]["cells"][0][3] = 999
        with self.assertRaises(world.WorldDataError):
            world._validate_native_geometry(self.snapshot, self.native, self.tile_reference)

    def test_native_variant_mapping_is_checked(self):
        self.snapshot["terrain"]["cells"][0][4] = 1
        with self.assertRaises(world.WorldDataError):
            world._validate_native_geometry(self.snapshot, self.native, self.tile_reference)

    def test_actual_tile_polygons_must_match_terrain_solidity(self):
        self.native[0, 1, 0, 0]["polygons"] = 1
        with self.assertRaises(world.WorldDataError):
            world._validate_native_geometry(self.snapshot, self.native, self.tile_reference)

    def test_ghost_solid_cells_are_rejected(self):
        self.snapshot["terrain"]["solidCells"] = [[0, 0]]
        with self.assertRaises(world.WorldDataError):
            world._validate_native_geometry(self.snapshot, self.native, self.tile_reference)

    def test_landmark_additional_solid_cells_have_actual_rect_provenance(self):
        landmark = scene_node(["entities", 1], ["entities"], "StaticBody2D")
        landmark["script"] = "res://scripts/entities/region_landmark.gd"
        landmark["fields"] = dictionary_nodes({"cells": {"kind": "rect", "type": "Rect2i",
            "position": vector(4, 4, True), "size": vector(2, 1, True)}})
        self.snapshot["scene"].append(landmark)
        self.snapshot["terrain"]["solidCells"] = [[4, 4], [5, 4]]
        world._validate_native_geometry(self.snapshot, self.native, self.tile_reference)
        self.snapshot["terrain"]["solidCells"].append([5, 5])
        with self.assertRaises(world.WorldDataError):
            world._validate_native_geometry(self.snapshot, self.native, self.tile_reference)


if __name__ == "__main__":
    unittest.main()
