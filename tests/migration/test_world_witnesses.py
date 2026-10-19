"""Synthetic semantic corruptions, no engine, real saves or reference edits."""
import copy
import json
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import check_world_witnesses as witness
from migration_world_data import WireDictionary, WireValue


def wire(value):
    if value is None:
        return {"kind": "nil"}
    if type(value) is bool:
        return {"kind": "bool", "value": value}
    if type(value) is int:
        return {"kind": "int", "value": str(value)}
    if type(value) is float:
        return {"kind": "float", "value": str(value)}
    if isinstance(value, str):
        return {"kind": "string", "value": value}
    if isinstance(value, WireValue):
        if value.type == "Transform2D":
            return {"kind": "transform2d", **{key: wire(item) for key, item in zip(("x", "y", "origin"), value.value)}}
        if value.type == "Color":
            return {"kind": "color", "rgba": [wire(float(item)) for item in value.value]}
        return {"kind": "vector", "type": value.type,
                "values": [wire(int(item) if value.type.endswith("i") else float(item)) for item in value.value]}
    if isinstance(value, (dict, WireDictionary)):
        entries = value.items()
        return {"kind": "dictionary", "entries": [[wire(key), wire(item)] for key, item in entries]}
    return {"kind": "array", "type": "Array", "values": [wire(item) for item in value]}


def node(script, fields, number=0, position=(0, 0)):
    transform = WireValue("Transform2D", (WireValue("Vector2", (1, 0)), WireValue("Vector2", (0, 1)), WireValue("Vector2", position)))
    return {"script": "res://scripts/entities/" + script, "fields": wire(fields), "address": ["entities", number],
            "globalTransform": wire(transform), "groups": [], "visible": True, "collision": {"layer": 1, "mask": 0}}


def snapshot(scenario, map_id, *, nodes=(), solids=(), rows=None, before=None, after=None, derived=None):
    return {"scenarioId": scenario, "mapId": map_id, "scene": list(nodes),
            "terrain": {"solidCells": list(solids), "cells": []}, "mapData": wire({"rows": rows or []}),
            "stateBefore": wire(before or {}), "stateAfter": wire(after or {}), "derived": wire(derived or {})}


def store(rows):
    return lambda scenario, map_id: witness._Snapshot(rows[scenario, map_id])


def mutate_field(record, name, value):
    for key, old in record["fields"]["entries"]:
        if key["value"] == name:
            old.clear()
            old.update(wire(value))
            return
    raise AssertionError("missing fixture field")


class WorldWitnessTests(unittest.TestCase):
    def marsh_fixture(self):
        result = {}
        levels = [("sluices_closed", False, False, 1.0), ("sluices_west", True, False, .7),
                  ("sluices_east", False, True, 1.0), ("sluices_both", True, True, .9)]
        for scenario, west, east, level in levels:
            result[scenario, "kruipmoeras"] = snapshot(scenario, "kruipmoeras", solids=[[17, 16], [32, 18]],
                nodes=[node("marsh_waterworks.gd", {"level": level})],
                after={"flags": {"lw_sluice_west": west, "lw_sluice_east": east}})
        result["marsh_drained", "kruipmoeras"] = snapshot("marsh_drained", "kruipmoeras", solids=[[17, 16]])
        rows = ["U" * 40 for _ in range(30)]
        rows[16] = rows[17] = "U" * 16 + "=" * 7 + "U" * 17
        result["marsh_bridge", "kruipmoeras"] = snapshot("marsh_bridge", "kruipmoeras", rows=rows)
        return result

    def tide_fixture(self):
        result = {}
        for scenario, state, flooded, held in [("tide_low", "low", False, False), ("tide_rising", "rising", False, False),
             ("tide_high", "high", True, False), ("tide_falling", "falling", True, False),
             ("tide_held", "high", False, True), ("tide_released", "high", True, False)]:
            rows = ["4" * 34 for _ in range(28)]
            if flooded:
                for y in (25, 26):rows[y] = rows[y][:20] + "8" * 12 + rows[y][32:]
            solids = [[x, y] for y in (25, 26) for x in range(20, 32)] if flooded else []
            result[scenario, "tide_cove"] = snapshot(scenario, "tide_cove", rows=rows, solids=solids,
                nodes=[node("tide_cove.gd", {"flooded": flooded, "held": held, "last_state": state})])
        return result

    def guardian_fixture(self):
        pillars = [[7, 5], [19, 5], [4, 9], [22, 9], [8, 14], [18, 14]]
        nodes = [node("guardian.gd", {"obj": {"pillars": pillars}})]
        nodes.extend(node("guardian_pillar.gd", {}, index + 1, (x * 32 + 16, y * 32 + 16)) for index, (x, y) in enumerate(pillars))
        result = {("guardian_alive", "depths2"): snapshot("guardian_alive", "depths2", nodes=nodes)}
        for scenario, opened, contents in [("guardian_defeated", False, [["heart_container", 1]]),
             ("guardian_reward_opened", True, [["heart_container", 1]]),
             ("guardian_full_hearts", False, [["potion", 2], ["coins", 100]])]:
            result[scenario, "depths2"] = snapshot(scenario, "depths2", nodes=[node("chest.gd",
                {"unique_key": "chest:depths2:heart", "opened": opened, "contents": contents}, position=(432, 304))])
        return result

    def farm_fixture(self):
        cells = {f"{x},34": {"kind": "channel"} for x in range(11, 20)}
        cells.update({"19,33": {"kind": "channel"}, "17,33": {"kind": "channel"}})
        sources = WireDictionary(((WireValue("Vector2i", (20, 33)), True), (WireValue("Vector2i", (20, 34)), True)))
        wet = WireDictionary(tuple((WireValue("Vector2i", tuple(map(int, key.split(",")))), True) for key in cells))
        tree = node("orchard_tree.gd", {"cell": WireValue("Vector2i", (9, 34))}, position=(304, 1104))
        shape = node("", {}, number=0)
        shape["address"] = ["entities", 0, 0]
        shape["shape"] = {"disabled": False, "parameters": wire({"size": WireValue("Vector2", (10, 8))})}
        result = {}
        for scenario in ("farm_dry", "farm_irrigated", "farm_disconnected"):
            channel_cells = copy.deepcopy(cells) if scenario != "farm_dry" else {}
            if scenario == "farm_disconnected":
                channel_cells.pop("19,33");channel_cells.pop("19,34")
            result[scenario, "village"] = snapshot(scenario, "village", nodes=[tree, shape],
                after={"homestead": {"cells": channel_cells}},
                derived={"natural_water_sources": sources, "irrigation_wet": wet if scenario == "farm_irrigated" else {}})
        jobs = {"wine_a": {"time": 90}, "wine_b": {"time": 20}, "compost": {"time": 30}}
        result["farm_ready", "village"] = snapshot("farm_ready", "village", before={"homestead": {"jobs": jobs}}, after={"homestead": {"jobs": jobs}})
        for scenario, count in (("honey_no_flowers", 0), ("honey_grown_flowers", 3)):
            result[scenario, "village"] = snapshot(scenario, "village", derived={"pollen_flowers": count})
        return result

    def manure_fixture(self):
        key = "forest:trail_fox:21,3:600000"
        return {("saved_manure", "forest"): snapshot("saved_manure", "forest",
            after={"homestead": {"drops": {key: {"map": "forest", "pos": [688, 112]}}}},
            nodes=[node("pickup.gd", {"item": "hs_manure", "unique_key": "hs_drop:" + key, "collected": False}, position=(688, 112))])}

    def test_bridge_witness_rejects_remaining_gap_and_wrong_art(self):
        clean = self.marsh_fixture()
        witness._check_marsh(store(clean), witness._Checks())
        damaged = copy.deepcopy(clean)
        damaged["marsh_bridge", "kruipmoeras"]["terrain"]["solidCells"].append([22, 17])
        with self.assertRaisesRegex(witness.WorldWitnessError, "marsh_complete_bridge"):
            witness._check_marsh(store(damaged), witness._Checks())
        damaged = copy.deepcopy(clean)
        rows = damaged["marsh_bridge", "kruipmoeras"]["mapData"]["entries"][0][1]["values"]
        rows[16]["value"] = rows[16]["value"][:20] + "U" + rows[16]["value"][21:]
        with self.assertRaisesRegex(witness.WorldWitnessError, "marsh_bridge_tiles"):
            witness._check_marsh(store(damaged), witness._Checks())

    def test_tide_witness_rejects_wrong_hold_and_single_wrong_collision_cell(self):
        clean = self.tide_fixture()
        witness._check_tides(store(clean), witness._Checks())
        damaged = copy.deepcopy(clean)
        mutate_field(damaged["tide_held", "tide_cove"]["scene"][0], "held", False)
        with self.assertRaisesRegex(witness.WorldWitnessError, "tide_state_flags"):
            witness._check_tides(store(damaged), witness._Checks())
        damaged = copy.deepcopy(clean)
        damaged["tide_high", "tide_cove"]["terrain"]["solidCells"].pop()
        with self.assertRaisesRegex(witness.WorldWitnessError, "tide_bank_collision"):
            witness._check_tides(store(damaged), witness._Checks())

    def test_guardian_witness_rejects_changed_reward_save_key(self):
        clean = self.guardian_fixture()
        witness._check_guardian(store(clean), witness._Checks())
        damaged = copy.deepcopy(clean)
        mutate_field(damaged["guardian_defeated", "depths2"]["scene"][0], "unique_key", "chest:depths2:wrong")
        with self.assertRaisesRegex(witness.WorldWitnessError, "expected one chest"):
            witness._check_guardian(store(damaged), witness._Checks())

    def test_disconnected_irrigation_rejects_fictitious_wet_channel(self):
        clean = self.farm_fixture()
        witness._check_farm(store(clean), witness._Checks())
        damaged = copy.deepcopy(clean)
        derived = witness.decode_wire(damaged["farm_disconnected", "village"]["derived"])
        damaged["farm_disconnected", "village"]["derived"] = wire(dict(derived.items()) | {
            "irrigation_wet": WireDictionary(((WireValue("Vector2i", (18, 34)), True),))})
        with self.assertRaisesRegex(witness.WorldWitnessError, "farm_channel_connectivity"):
            witness._check_farm(store(damaged), witness._Checks())

    def test_saved_manure_requires_matching_drop_key_and_position(self):
        clean = self.manure_fixture()
        witness._check_saved_drop(store(clean), witness._Checks())
        damaged = copy.deepcopy(clean)
        mutate_field(damaged["saved_manure", "forest"]["scene"][0], "unique_key", "hs_drop:wrong")
        with self.assertRaisesRegex(witness.WorldWitnessError, "expected one pickup"):
            witness._check_saved_drop(store(damaged), witness._Checks())

    def test_typed_vector_key_is_not_replaced_by_a_text_key(self):
        with self.assertRaisesRegex(witness.WorldWitnessError, "typed 2D vector"):
            witness._coordinates(WireDictionary((("18,34", True),)))

    def test_optional_checked_in_full_export(self):
        target = Path(os.environ.get("BLUEMAP_WORLD_WITNESSES", ROOT / "migration/world"))
        if not (target / "index.json").is_file():
            self.skipTest("No checked-in full world export yet; root validates actual export separately")
        report = witness.check_world_witnesses(target)
        self.assertTrue(report["success"])
        self.assertGreaterEqual(report["scenarioCount"], 59)
        self.assertFalse(report["engineStarted"])
        self.assertNotIn(str(target), json.dumps(report))


if __name__ == "__main__":
    unittest.main()
