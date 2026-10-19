#!/usr/bin/env python3
"""Check concrete outcomes in frozen, loaded-world reference snapshots.

Run after migration_world_data's complete structural/source validation. This
adds semantic witnesses; it does not replace source pins, replay gameplay,
instantiate engine resources, or prove a Unity implementation equivalent.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import sys

from migration_world_data import decode_wire, WireDictionary, WireValue, WorldDataError


class WorldWitnessError(ValueError):
    pass


def _require(condition, message):
    if not condition:
        raise WorldWitnessError(message)


def _mapping(value):
    _require(isinstance(value, WireDictionary), "Witness requires a typed wire dictionary")
    return value


def _vector(value):
    _require(isinstance(value, WireValue) and value.type in {"Vector2", "Vector2i"}, "Witness requires a typed 2D vector")
    return tuple(value.value)


def _origin(node):
    transform = decode_wire(node["globalTransform"])
    _require(isinstance(transform, WireValue) and transform.type == "Transform2D", "Missing native transform")
    return _vector(transform.value[2])


def _near(left, right):
    return len(left) == len(right) and all(math.isclose(a, b, rel_tol=0, abs_tol=1e-5) for a, b in zip(left, right))


class _Snapshot:
    def __init__(self, value):
        self.value = value
        self.scenario = value["scenarioId"]
        self.map = value["mapId"]
        self._decoded = {}
        self._fields = {}

    def wire(self, name):
        if name not in self._decoded:
            self._decoded[name] = decode_wire(self.value[name])
        return self._decoded[name]

    def fields(self, node):
        key = id(node)
        if key not in self._fields:
            self._fields[key] = _mapping(decode_wire(node["fields"]))
        return self._fields[key]

    def nodes(self, script):
        path = "res://scripts/entities/" + script
        return [node for node in self.value["scene"] if node["script"] == path]

    def one(self, script, predicate=lambda fields: True):
        matches = [node for node in self.nodes(script) if predicate(self.fields(node))]
        _require(len(matches) == 1, f"{self.scenario}/{self.map}: expected one {script} witness, found {len(matches)}")
        return matches[0]

    def shapes(self, parent):
        address = parent["address"]
        return [node for node in self.value["scene"] if "shape" in node and
                len(node["address"]) > len(address) and node["address"][:len(address)] == address]

    def child_lights(self, parent):
        address = parent["address"]
        return [node for node in self.value["scene"] if "light" in node and
                len(node["address"]) > len(address) and node["address"][:len(address)] == address]

    def solids(self):
        return {tuple(cell) for cell in self.value["terrain"]["solidCells"]}


class _Store:
    def __init__(self, directory):
        self.directory = Path(directory)
        _require(self.directory.is_dir() and not self.directory.is_symlink(), "Witness directory is missing or is a symlink")
        self.cache = {}

    def __call__(self, scenario, map_id):
        _require(type(scenario) is str and type(map_id) is str and
                 re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,127}", scenario) is not None and
                 re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,127}", map_id) is not None,
                 "Unsafe witness snapshot identity")
        key = scenario, map_id
        if key not in self.cache:
            path = self.directory / "snapshots" / scenario / (map_id + ".json")
            _require(path.resolve().is_relative_to(self.directory.resolve()), "Witness path escapes export directory")
            _require(path.is_file() and not path.is_symlink(), f"Missing witness snapshot: {scenario}/{map_id}")
            _require(path.stat().st_size <= 128 * 1024 * 1024, "Witness snapshot exceeds size budget")
            value = json.loads(path.read_text(encoding="utf-8"))
            _require(value.get("scenarioId") == scenario and value.get("mapId") == map_id, "Witness snapshot identity mismatch")
            self.cache[key] = _Snapshot(value)
        return self.cache[key]


class _Checks:
    def __init__(self):
        self.records = []

    def __call__(self, condition, identifier, snapshot, detail):
        _require(condition, f"{identifier}: {snapshot.scenario}/{snapshot.map}: {detail}")
        self.records.append({"id": identifier, "scenario": snapshot.scenario, "map": snapshot.map,
                             "passed": True, "evidence": detail})


def _check_marsh(store, check):
    before = store("sluices_closed", "kruipmoeras")
    drained = store("marsh_drained", "kruipmoeras")
    after = store("marsh_bridge", "kruipmoeras")
    check((17, 16) in before.solids() and (32, 18) in before.solids(), "marsh_before_water", before, "Broken western span and flooded eastern bank are solid.")
    check((32, 18) not in drained.solids() and (17, 16) in drained.solids(), "marsh_drained_bank", drained, "Drainage opens eastern bank while the unrepaired western gap remains closed.")
    check(all((x, y) not in after.solids() for y in (16, 17) for x in range(15, 24)), "marsh_complete_bridge", after, "Both deck rows connect both landings, x15..23 inclusive.")
    rows = after.wire("mapData")["rows"]
    check(all(rows[y][16:23] == "=======" for y in (16, 17)), "marsh_bridge_tiles", after, "All seven authored bridge tiles in both rows are actual bridge terrain.")
    for scenario, west, east, level in (("sluices_closed", False, False, 1.0), ("sluices_west", True, False, .7),
                                        ("sluices_east", False, True, 1.0), ("sluices_both", True, True, .9)):
        snapshot = store(scenario, "kruipmoeras")
        flags = snapshot.wire("stateAfter")["flags"]
        water = snapshot.one("marsh_waterworks.gd")
        check(flags.get("lw_sluice_west", False) is west and flags.get("lw_sluice_east", False) is east and
              flags.get("lw_drained", False) is False and math.isclose(snapshot.fields(water)["level"], level, abs_tol=1e-6),
              "marsh_valve_projection", snapshot, "Unsolved valve combination and its source-defined water gauge remain distinct.")


def _check_tides(store, check):
    for scenario, state, flooded, held in (("tide_low", "low", False, False), ("tide_rising", "rising", False, False),
                                          ("tide_high", "high", True, False), ("tide_falling", "falling", True, False),
                                          ("tide_held", "high", False, True), ("tide_released", "high", True, False)):
        snapshot = store(scenario, "tide_cove")
        node = snapshot.one("tide_cove.gd")
        fields = snapshot.fields(node)
        check(fields["flooded"] is flooded and fields["held"] is held and fields["last_state"] == state,
              "tide_state_flags", snapshot, "Actual tide controller records expected stage, flood and occupied-bank hold.")
        bank = {(x, y) for y in (25, 26) for x in range(20, 32)}
        solids = snapshot.solids()
        rows = snapshot.wire("mapData")["rows"]
        check(all((cell in solids) is flooded for cell in bank) and
              all(rows[y][x] == ("8" if flooded else "4") for x, y in bank),
              "tide_bank_collision", snapshot, "All 24 bank cells agree with the flooded/dry native terrain state.")


def _check_restoration_resources(store, check):
    for scenario, map_id, expected in (
        ("mine_restored", "prismamine", {"lw_mine_iron": ("iron", (880, 176)), "lw_mine_copper": ("copper", (1104, 304))}),
        ("forest_restored", "dauwbos", {"lw_revealed_flower": ("dauwklauw", (1264, 1040))}),
        ("marsh_drained", "kruipmoeras", {"lw_shore_mint": ("watermunt", (976, 560))}),
    ):
        snapshot = store(scenario, map_id)
        baseline = store("fresh_baseline", map_id)
        nodes = {snapshot.fields(node).get("key"): node for node in snapshot.nodes("resource_node.gd")
                 if str(snapshot.fields(node).get("key", "")).startswith("lw_")}
        check(set(nodes) == set(expected), "restored_resource_ids", snapshot, "Only the exact source-authored dynamic resource IDs materialize.")
        for key, (kind, position) in expected.items():
            fields = snapshot.fields(nodes[key])
            check(fields.get("resource_id") == key and fields.get("kind") == kind and _near(_origin(nodes[key]), position),
                  "restored_resource_identity", snapshot, f"Resource {key} retains its kind, save key and authored position.")
        baseline_keys = {baseline.fields(node).get("key") for node in baseline.nodes("resource_node.gd")}
        check(not (set(expected) & baseline_keys), "restored_resource_absent_before", baseline, "Restoration rewards do not exist in a fresh world.")
    marsh = store("marsh_drained", "kruipmoeras")
    spot = marsh.one("meer_visplek.gd", lambda fields: fields.get("key") == "lw_marsh_fishing")
    check(_near(_origin(spot), (944, 496)), "restored_fishing_key", marsh, "Dynamic fishing spot retains lw_marsh_fishing and the source position.")


def _check_guardian(store, check):
    alive = store("guardian_alive", "depths2")
    guardian = alive.one("guardian.gd")
    pillars = alive.nodes("guardian_pillar.gd")
    authored = alive.fields(guardian)["obj"]["pillars"]
    check(len(pillars) == len(authored) == 6 and {_origin(node) for node in pillars} ==
          {(x * 32 + 16, y * 32 + 16) for x, y in authored}, "guardian_deferred_pillars", alive, "All six source-authored deferred pillar nodes are present at their exact positions.")
    for scenario, opened, contents in (("guardian_defeated", False, [["heart_container", 1]]),
                                       ("guardian_reward_opened", True, [["heart_container", 1]]),
                                       ("guardian_full_hearts", False, [["potion", 2], ["coins", 100]])):
        snapshot = store(scenario, "depths2")
        chest = snapshot.one("chest.gd", lambda fields: fields.get("unique_key") == "chest:depths2:heart")
        fields = snapshot.fields(chest)
        check(not snapshot.nodes("guardian.gd") and not snapshot.nodes("guardian_pillar.gd"), "guardian_absent_after_defeat", snapshot, "Defeated guardian and combat pillars are removed after deferred initialization.")
        check(fields.get("opened") is opened and fields.get("contents") == contents and _near(_origin(chest), (432, 304)),
              "guardian_reward_identity", snapshot, "Deferred reward retains chest:depths2:heart, opened state, source position and capacity-dependent contents.")


def _check_cat_and_library(store, check):
    for scenario, present in (("fresh_baseline", True), ("route_cat_home", False)):
        snapshot = store(scenario, "forest")
        cats = [node for node in snapshot.nodes("npc.gd") if snapshot.fields(node).get("npc_id") == "muis_bos"]
        check(len(cats) == int(present), "cat_exists_if", snapshot, "Forest cat exists before rescue and is absent after returning home.")
    before = store("fresh_baseline", "library")
    after = store("library_backroom", "library")
    cabinet = after.one("meer_kast.gd")
    cells = {_vector(cell) for cell in after.fields(cabinet)["cells"]}
    check(bool(cells) and all(cell in before.solids() and cell not in after.solids() for cell in cells),
          "library_backroom_collision", after, "Every authored cabinet tile becomes traversable library floor.")
    rows = after.wire("mapData")["rows"]
    before_tiles = {tuple(cell[:2]): cell[2:] for cell in before.value["terrain"]["cells"]}
    after_tiles = {tuple(cell[:2]): cell[2:] for cell in after.value["terrain"]["cells"]}
    check(after.fields(cabinet).get("opened") is True and all(rows[y][x] == "Q" and before_tiles[x, y] != after_tiles[x, y] for x, y in cells),
          "library_backroom_native_tiles", after, "Opened cabinet projects changed native floor tiles, not only a flag.")


def _station(snapshot, unit=None, role=None):
    return snapshot.one("home_station.gd", lambda fields: fields["obj"].get("unit") == unit if unit else fields["obj"].get("role") == role)


def _check_house_and_yard(store, check):
    base = store("fresh_baseline", "player_home")
    home = store("home_furnished", "player_home")
    furniture = home.nodes("house_furniture.gd")
    expected = {"chair": (144, 336), "plant_leaf": (80, 272), "lamp": (336, 336)}
    check(not base.nodes("house_furniture.gd") and len(furniture) == 3 and
          {home.fields(node)["entry"]["kind"] for node in furniture} == set(expected), "house_placed_furniture", home, "Exactly the three explicitly placed, owned furniture pieces appear.")
    for node in furniture:
        kind = home.fields(node)["entry"]["kind"]
        check(_near(_origin(node), expected[kind]) and node["collision"]["layer"] == 1 and
              any(shape["shape"]["disabled"] is False for shape in home.shapes(node)), "house_furniture_collision", home, f"Placed {kind} retains its intended position and real active collision.")
        if kind == "lamp":
            lights = home.child_lights(node)
            _require(len(lights) == 1, "house_saved_lamp: expected one native furniture light")
            light = decode_wire(lights[0]["light"])
            color = light["color"]
            check(light["enabled"] is True and isinstance(color, WireValue) and color.type == "Color" and
                  _near(color.value, (157 / 255, 208 / 255, 208 / 255, 1)) and
                  math.isclose(light["energy"], .22, abs_tol=1e-6), "house_saved_lamp", home,
                  "Placed house lamp uses the saved sea-light palette and zero-time source energy.")
    for role, position in (("bed", (80, 112)), ("table", (160, 304))):
        check(_near(_origin(_station(home, role=role)), position) and
              _origin(_station(base, role=role)) != position, "house_functional_station_moves", home, f"Original functional {role} moves with the redesigned saved layout.")
    moved = store("yard_moved", "village")
    wine = _station(moved, unit="wine_a")
    check(_near(_origin(wine), (176, 880)) and wine["visible"] is True and wine["collision"]["layer"] == 1,
          "yard_moved_station", moved, "The existing wine_a machine occupies its saved new tile with collision.")
    check(moved.wire("stateAfter")["homestead"]["jobs"]["wine_a"]["time"] == 42,
          "yard_batch_time_retained", moved, "Moving production retains its partial 42-second batch.")
    packed = store("yard_packed", "village")
    for unit in ("wine_a", "hive"):
        node = _station(packed, unit=unit)
        check(node["visible"] is False and node["collision"]["layer"] == 0 and "interactable" not in node["groups"],
              "yard_packed_station", packed, f"Packed {unit} has no visible art, collision or interaction group.")
    for scenario, opened in (("yard_gate_far", False), ("yard_gate_near", True)):
        snapshot = store(scenario, "village")
        gate = snapshot.one("yard_fence.gd")
        shapes = snapshot.shapes(gate)
        check(snapshot.fields(gate)["opened"] is opened and len(shapes) == 1 and shapes[0]["shape"]["disabled"] is opened,
              "yard_gate_proximity", snapshot, "Gate proximity changes the actual native collider, including deferred disabled state.")


def _coordinates(dictionary):
    return {_vector(key) for key, value in _mapping(dictionary).items() if value is True}


def _expected_wet(snapshot):
    cells = snapshot.wire("stateAfter")["homestead"]["cells"]
    channels = {tuple(map(int, key.split(","))) for key, entry in cells.items() if entry.get("kind") == "channel"}
    sources = _coordinates(snapshot.wire("derived")["natural_water_sources"])
    steps = ((1, 0), (-1, 0), (0, 1), (0, -1))
    wet = {at for at in channels if any((at[0] + dx, at[1] + dy) in sources for dx, dy in steps)}
    pending = list(wet)
    while pending:
        x, y = pending.pop()
        for dx, dy in steps:
            at = x + dx, y + dy
            if at in channels and at not in wet:
                wet.add(at)
                pending.append(at)
    return wet


def _check_farm(store, check):
    for scenario, connected in (("farm_dry", False), ("farm_irrigated", True), ("farm_disconnected", False)):
        snapshot = store(scenario, "village")
        wet = _coordinates(snapshot.wire("derived")["irrigation_wet"])
        check(wet == _expected_wet(snapshot) and bool(wet) is connected, "farm_channel_connectivity", snapshot, "Reported wet channels exactly match cardinal connections to natural water, including source disconnection.")
    growing = store("farm_irrigated", "village")
    check({(17, 33), (19, 33), (11, 34)} <= _coordinates(growing.wire("derived")["irrigation_wet"]),
          "farm_irrigation_reaches_orchard", growing, "Connected water reaches vine edge and apple root range through the full channel route.")
    tree = growing.one("orchard_tree.gd")
    shapes = growing.shapes(tree)
    check(_vector(growing.fields(tree)["cell"]) == (9, 34) and _near(_origin(tree), (304, 1104)) and
          tree["collision"]["layer"] == 1 and len(shapes) == 1 and shapes[0]["shape"]["disabled"] is False and
          _vector(decode_wire(shapes[0]["shape"]["parameters"])["size"]) == (10, 8),
          "farm_real_apple_trunk", growing, "Planted apple has a real source-sized trunk collider at its saved plot.")
    ready = store("farm_ready", "village")
    jobs = ready.wire("stateAfter")["homestead"]["jobs"]
    check(jobs["wine_a"]["time"] == 90 and jobs["wine_b"]["time"] == 20 and jobs["compost"]["time"] == 30 and
          jobs == ready.wire("stateBefore")["homestead"]["jobs"], "farm_ready_jobs_frozen", ready, "Ready/partial wine and compost retain exact saved active-play times; export does not grow or collect them.")
    for scenario, flowers in (("honey_no_flowers", 0), ("honey_grown_flowers", 3)):
        snapshot = store(scenario, "village")
        check(snapshot.wire("derived")["pollen_flowers"] == flowers, "honey_pollen_requirement", snapshot, "Pollen uses actual nearby mature plants: zero without flowers, three at the moved hive.")


def _check_saved_drop(store, check):
    snapshot = store("saved_manure", "forest")
    drops = snapshot.wire("stateAfter")["homestead"]["drops"]
    check(len(drops.entries) == 1, "manure_saved_journal", snapshot, "Synthetic journal contains one real animal-home drop identity.")
    for key, entry in drops.items():
        node = snapshot.one("pickup.gd", lambda fields: fields.get("item") == "hs_manure" and fields.get("unique_key") == "hs_drop:" + key)
        check(entry["map"] == "forest" and _near(_origin(node), entry["pos"]) and snapshot.fields(node).get("collected") is False,
              "manure_projected_pickup", snapshot, "Saved animal drop becomes exactly the matching uncollected magnetic pickup at its saved position.")


def _check_coastal_lamp(store, check):
    for scenario, enabled, color in (("fresh_baseline", False, (239 / 255, 210 / 255, 158 / 255, 1)),
                                      ("coastal_workshop", True, (131 / 255, 216 / 255, 221 / 255, 1))):
        snapshot = store(scenario, "coast_workshop")
        station = snapshot.one("coastal_workstation.gd", lambda fields: fields["obj"].get("role") == "lamp")
        lights = snapshot.child_lights(station)
        _require(len(lights) == 1, "coastal_lamp: expected one native PointLight2D")
        light = decode_wire(lights[0]["light"])
        actual_color = light["color"]
        check(light["enabled"] is enabled and isinstance(actual_color, WireValue) and actual_color.type == "Color" and
              _near(actual_color.value, color) and math.isclose(light["energy"], .32, abs_tol=1e-6),
              "coastal_saved_lamp", snapshot, "Native lamp enabled/color/energy agree with ownership and saved warm/sea-light settings.")


def check_world_witnesses(directory: Path) -> dict:
    """Verify targeted captured effects, after the complete world-data validator."""
    try:
        store, check = _Store(directory), _Checks()
        index = json.loads((Path(directory) / "index.json").read_text(encoding="utf-8"))
        _require(index.get("failures") == [], "World export reported failures")
        for record in index["snapshots"]:
            snapshot = store(record["scenarioId"], record["mapId"])
            before, after = snapshot.wire("stateBefore"), snapshot.wire("stateAfter")
            check(before["play_time"] == after["play_time"] and before["day_count"] == after["day_count"],
                  "all_profiles_frozen_clock", snapshot, "Loading/projecting this profile does not advance saved active time or day count.")
            before_farm, after_farm = before["homestead"], after["homestead"]
            check(before_farm.get("jobs", WireDictionary(())) == after_farm.get("jobs", WireDictionary(())),
                  "all_profiles_frozen_production", snapshot, "Partial/ready saved production jobs are not advanced or collected during projection.")
        for witness in (_check_marsh, _check_tides, _check_restoration_resources, _check_guardian,
                        _check_cat_and_library, _check_house_and_yard, _check_farm, _check_saved_drop, _check_coastal_lamp):
            witness(store, check)
        return {"schemaVersion": 1, "phase": 5, "success": True, "checks": check.records,
                "checkCount": len(check.records), "scenarioCount": len(index["scenarios"]),
                "snapshotCount": len(index["snapshots"]), "engineStarted": False, "personalSavesUsed": False,
                "scope": "Targeted semantic witnesses in captured Godot projections; requires separate complete world-data/source-pin validation. Not a gameplay replay or Unity equivalence proof."}
    except WorldWitnessError:
        raise
    except (OSError, ValueError, KeyError, TypeError, IndexError, AttributeError) as error:
        raise WorldWitnessError("Malformed or incomplete world witness data: " + str(error)) from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = check_world_witnesses(args.directory)
    if args.output:
        with args.output.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(report, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
    print(f"WORLD WITNESSES OK: {report['checkCount']} checks, {report['scenarioCount']} profiles, {report['snapshotCount']} snapshots")


if __name__ == "__main__":
    try:
        main()
    except (WorldWitnessError, OSError) as error:
        print("WORLD WITNESSES FAILED: " + str(error), file=sys.stderr)
        raise SystemExit(1)
