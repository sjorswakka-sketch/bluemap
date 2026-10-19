"""Source and witness coverage; never run Godot, Unity, or player saves."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PRODUCERS = {"map_load", "legacy_migrations", "first_route", "access", "resources", "tides",
             "coastal_adventures", "water", "living_geometry", "landmarks", "opening", "supper",
             "memory", "home", "yard", "farm", "library", "gates", "guardian", "entity_existence",
             "regional", "atmosphere", "temporal_encounters", "coastal_workshop"}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def function_body(path, function):
    text = path.read_text(encoding="utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
    lines = text.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines)
              if re.match(r"^(?:static )?func " + re.escape(function) + r"\(", line)]
    if len(starts) != 1:
        raise ValueError("Missing or ambiguous original function")
    start = starts[0]
    end = start + 1
    while end < len(lines):
        line = lines[end]
        if line.strip() and not line[0].isspace() and not line.startswith("#"):
            break
        end += 1
    return text, "".join(lines[start:end]).rstrip() + "\n", start + 1


def check_contract(contract, root=ROOT):
    if contract.get("schema") != "bluemap.world.coverage.v1" or contract.get("phase") != 5:
        raise ValueError("Unsupported world coverage schema")
    if contract.get("baselineCommit") != "a8a988be27835dec979d2523a3a85a34385eac54":
        raise ValueError("Coverage baseline changed")
    content = load(root / "migration/reference/content-inventory.json")
    maps = load(root / "migration/reference/maps-inventory.json")
    source_hashes = {row["path"]: row["sha256"] for row in content["source_files"]}
    producer_rows = contract.get("producers", [])
    producer_ids = [row["id"] for row in producer_rows]
    if len(set(producer_ids)) != len(producer_ids) or set(producer_ids) != PRODUCERS:
        raise ValueError("Missing, duplicate or unreviewed producer family")
    required = {scenario for row in producer_rows for scenario in row["requiredScenarios"]}
    if set(contract.get("requiredScenarios", [])) != required:
        raise ValueError("Required witness union changed")
    scenario_text = (root / "tools/migration_world_scenarios.gd").read_text(encoding="utf-8")
    available = re.findall(r'_descriptor\("([^"]+)"', scenario_text)
    if len(available) != len(set(available)) or not required <= set(available):
        raise ValueError("Missing or duplicate scenario witness")
    if set(contract.get("requiredMapIds", [])) != {row["id"] for row in maps["maps"]}:
        raise ValueError("A registered map is not covered")

    def verify_anchor(anchor):
        name = anchor["path"]
        if name not in source_hashes:
            raise ValueError("Anchor has no preserved original source authority")
        text, body, line = function_body(root / name[6:], anchor["function"])
        if hashlib.sha256(text.encode()).hexdigest() != source_hashes[name]:
            raise ValueError("Original source changed outside frozen authority")
        if anchor["sourceSha256LF"] != source_hashes[name] or anchor["bodySha256LF"] != hashlib.sha256(body.encode()).hexdigest():
            raise ValueError("Original function or full-file anchor differs")
        if anchor["line"] != line or anchor["endLine"] != line + len(body.splitlines()) - 1:
            raise ValueError("Source location differs")

    for producer in producer_rows:
        if not producer.get("requiredScenarios") or not producer.get("requiredProperties") or not producer.get("sourceAnchors"):
            raise ValueError("Producer is missing source, properties or witness")
        for anchor in producer["sourceAnchors"]:
            verify_anchor(anchor)
    _, world_body, _ = function_body(root / "scripts/world.gd", "load_map")
    expected_hooks = set(re.findall(r'(?:preload|load)\("(res://scripts/[^\"]+)"\)', world_body))
    world_source = (root / "scripts/world.gd").read_text(encoding="utf-8")
    for alias, path in re.findall(r'^const (\w+)\s*:?=\s*preload\("(res://scripts/[^\"]+)"\)', world_source, re.M):
        if re.search(r"\b" + re.escape(alias) + r"\b", world_body):
            expected_hooks.add(path)
    hooks = contract.get("loadMapHooks", [])
    if len(hooks) != len(expected_hooks) or {row["path"] for row in hooks} != expected_hooks:
        raise ValueError("An original world.load_map hook is missing or unreviewed")
    for row in hooks:
        verify_anchor(row["sourceAnchor"])
        if row["sourceAnchor"]["path"] != row["path"] or not set(row["requiredScenarios"]) <= required:
            raise ValueError("Load hook has missing source or witness")
        called = {method for path, method in re.findall(
            r'(?:preload|load)\("(res://scripts/[^\"]+)"\)\.(\w+)\(', world_body) if path == row["path"]}
        called.discard("new")
        if called and row["sourceAnchor"]["function"] not in called | {"_ready"}:
            raise ValueError("Load hook anchor is not an actual called entrypoint")
    _, registry, _ = function_body(root / "scripts/maps/registry.gd", "get_map")
    expected_registry = set(re.findall(r'preload\("(res://scripts/[^\"]+)"\)\.(\w+)\(', registry))
    registry_rows = contract.get("registryHooks", [])
    if len(registry_rows) != len(expected_registry) or {(r["path"], r["function"]) for r in registry_rows} != expected_registry:
        raise ValueError("A registry preparer or enricher is missing")
    for row in registry_rows:
        verify_anchor(row["sourceAnchor"])
    handlers = contract.get("objectHandlers", [])
    expected_types = {entry["id"] for entry in content["catalogs"]["object_types"]["entries"]}
    if len(handlers) != len(expected_types) or {row["type"] for row in handlers} != expected_types:
        raise ValueError("An original object handler is missing")
    for row in handlers:
        verify_anchor(row["sourceAnchor"])
        if row["sourceAnchor"]["path"] != row["path"]:
            raise ValueError("Object handler authority does not match")
    for row in contract.get("safeProjections", []):
        verify_anchor(row["sourceAnchor"])
        if row["path"] != row["sourceAnchor"]["path"] or row["function"] != row["sourceAnchor"]["function"]:
            raise ValueError("Projection authority does not match")
    if contract.get("unityRuntimeImplemented") is not False or contract.get("personalSavesUsed") is not False:
        raise ValueError("Coverage claims unsupported execution")


class WorldCoverageContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = load(ROOT / "migration/world-coverage.json")

    def test_all_original_load_hooks_producers_sources_and_witnesses_are_present(self):
        check_contract(self.contract)

    def test_removing_runtime_hook_is_detected(self):
        changed = deepcopy(self.contract)
        changed["loadMapHooks"].pop()
        with self.assertRaisesRegex(ValueError, "load_map hook"):
            check_contract(changed)

    def test_removing_producer_family_is_detected(self):
        changed = deepcopy(self.contract)
        changed["producers"] = [p for p in changed["producers"] if p["id"] != "guardian"]
        with self.assertRaisesRegex(ValueError, "producer family"):
            check_contract(changed)

    def test_missing_scenario_witness_is_detected(self):
        changed = deepcopy(self.contract)
        changed["producers"][0]["requiredScenarios"].append("unavailable_runtime_state")
        changed["requiredScenarios"].append("unavailable_runtime_state")
        with self.assertRaisesRegex(ValueError, "scenario witness"):
            check_contract(changed)

    def test_missing_derived_world_property_is_detected(self):
        changed = deepcopy(self.contract)
        changed["producers"][0]["requiredProperties"] = []
        with self.assertRaisesRegex(ValueError, "properties or witness"):
            check_contract(changed)

    def test_changed_function_anchor_is_detected(self):
        changed = deepcopy(self.contract)
        changed["producers"][0]["sourceAnchors"][0]["bodySha256LF"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "anchor differs"):
            check_contract(changed)

    def test_missing_object_handler_is_detected(self):
        changed = deepcopy(self.contract)
        changed["objectHandlers"].pop()
        with self.assertRaisesRegex(ValueError, "object handler"):
            check_contract(changed)

    def test_missing_registry_enricher_is_detected(self):
        changed = deepcopy(self.contract)
        changed["registryHooks"].pop()
        with self.assertRaisesRegex(ValueError, "enricher"):
            check_contract(changed)

    def test_claiming_unity_execution_is_detected(self):
        changed = deepcopy(self.contract)
        changed["unityRuntimeImplemented"] = True
        with self.assertRaisesRegex(ValueError, "unsupported execution"):
            check_contract(changed)

    def test_helper_function_cannot_replace_actual_preparer_anchor(self):
        changed = deepcopy(self.contract)
        hook = next(row for row in changed["loadMapHooks"]
                    if row["path"] == "res://scripts/core/coastal_adventures.gd")
        text, body, line = function_body(ROOT / "scripts/core/coastal_adventures.gd", "gs")
        hook["sourceAnchor"].update(function="gs", line=line,
                                    endLine=line + len(body.splitlines()) - 1,
                                    bodySha256LF=hashlib.sha256(body.encode()).hexdigest())
        with self.assertRaisesRegex(ValueError, "actual called entrypoint"):
            check_contract(changed)


if __name__ == "__main__":
    unittest.main()
