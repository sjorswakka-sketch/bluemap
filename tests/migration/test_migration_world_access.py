"""Reject incomplete access observations, changed original art and unstable IDs."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import build_migration_world_access as access


class WorldAccessSourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="BlueMap-World-Access-Data-Tests-")
        cls.addClassCleanup(temporary.cleanup)
        cls.root = Path(temporary.name)
        index = json.loads((ROOT / access.WORLD_INDEX).read_bytes())
        inventory = json.loads((ROOT / access.INVENTORY).read_bytes())
        art = json.loads((ROOT / access.ART / "index.json").read_bytes())
        names = {*access.SOURCE_PATHS, *access.RECORDERS, access.ORACLE, access.INVENTORY,
                 access.WORLD_INDEX, "migration/reference/source-manifest.json", access.ASSETS + ".meta",
                 *(row["base_source"].removeprefix("res://") for row in inventory["maps"]),
                 *(name.removeprefix("res://") for name in art["sourceFiles"]),
                 *("migration/world/" + row["path"] for row in index["snapshots"])}
        for name in names:
            target = cls.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / name).read_bytes())
        shutil.copytree(ROOT / access.ASSETS, cls.root / access.ASSETS)
        cls.contract = access.build_contract(cls.root)
        (cls.root / access.CONTRACT).write_bytes(access.canonical(cls.contract))

    def replace(self, name, data):
        path = self.root / name
        original = path.read_bytes()
        self.addCleanup(path.write_bytes, original)
        path.write_bytes(data)

    def oracle(self):
        return json.loads((self.root / access.ORACLE).read_bytes())

    def coverage(self, value):
        _, _, maps, keys = access.world_reference(self.root)
        return access.oracle_coverage(value, maps, keys)

    def test_gitless_full_world_contract_reads_no_engine_or_personal_profile(self):
        before = {p.relative_to(self.root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in self.root.rglob("*") if p.is_file()}
        result = access.check(self.root)
        self.assertEqual(result, self.contract)
        self.assertFalse(result["enginesStarted"])
        self.assertFalse(result["personalSavesUsed"])
        self.assertEqual(result["oracle"]["coverage"]["maps"], 37)
        self.assertEqual(result["oracle"]["coverage"]["snapshots"], 162)
        self.assertEqual(result["art"]["snapshots"], 158)
        self.assertEqual(len(result["art"]["maps"]), 37)
        self.assertEqual(before, {p.relative_to(self.root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in self.root.rglob("*") if p.is_file()})

    def test_original_area_or_access_source_cannot_be_refrozen(self):
        name = "scripts/entities/portal.gd"
        self.replace(name, (self.root / name).read_bytes() + b"\n# unintended access change\n")
        with self.assertRaisesRegex(access.WorldAccessDataError, "Preserved world-access source changed"):
            access.build_contract(self.root)

    def test_omitted_or_duplicate_world_snapshot_rejected(self):
        for change in ("missing", "duplicate", "foreign"):
            value = self.oracle()
            if change == "missing": value["snapshots"].pop()
            elif change == "duplicate": value["snapshots"][-1] = copy.deepcopy(value["snapshots"][0])
            else: value["snapshots"][0]["map"] = "invented_area"
            with self.subTest(change=change), self.assertRaisesRegex(access.WorldAccessDataError, "map/scenario coverage"):
                self.coverage(value)

    def test_private_save_access_and_missing_method_rejected(self):
        for change in ("personal", "fresh", "failures", "methods"):
            value = self.oracle()
            if change == "personal": value["personalSavesUsed"] = True
            elif change == "fresh": value["freshProcessRequired"] = False
            elif change == "failures": value["failures"] = ["source failed"]
            else: value["sourceMethods"].remove("world.safe_spawn_position")
            with self.subTest(change=change), self.assertRaises(access.WorldAccessDataError):
                self.coverage(value)

    def test_missing_gate_and_boat_edge_cases_rejected(self):
        for name in sorted(access.CASE_IDS):
            value = self.oracle()
            value["cases"] = [case for case in value["cases"] if case["id"] != name]
            with self.subTest(case=name), self.assertRaisesRegex(access.WorldAccessDataError, "behavior IDs"):
                self.coverage(value)

    def test_arrival_safety_and_all_original_state_fields_required(self):
        for change in ("arrivals", "probes", "resolved", "fits", "state"):
            value = self.oracle()
            row = value["snapshots"][0]
            if change == "arrivals": row["arrivals"] = []
            elif change == "probes": row["probes"] = []
            elif change == "resolved": row["arrivals"][0]["resolved"] = [1]
            elif change == "fits": row["arrivals"][0]["fits"] = 1
            else: row["state"].pop("personal_home")
            with self.subTest(change=change), self.assertRaises(access.WorldAccessDataError):
                self.coverage(value)

    def test_portal_dimensions_and_boolean_lock_observation_required(self):
        for change in ("target", "size", "available", "requires"):
            value = self.oracle()
            row = next(row for row in value["snapshots"] if row["portals"])["portals"][0]
            if change == "target": row["to"] = "invented_area"
            elif change == "size": row["rect"][1][0] = 0
            elif change == "available": row["available"] = 1
            else: row.pop("requires")
            with self.subTest(change=change), self.assertRaises(access.WorldAccessDataError):
                self.coverage(value)

    def test_native_observations_cannot_diverge(self):
        value = self.oracle()
        value["snapshots"][0]["state"]["coins"] += 1
        value["snapshots"][0]["stateExact"]["coins"] += 1
        self.replace(access.RESOURCE, access.canonical(value))
        with self.assertRaisesRegex(access.WorldAccessDataError, "Native world-access oracle differs"):
            access.check(self.root)

    def test_changed_matching_observations_still_require_contract_review(self):
        value = self.oracle()
        value["snapshots"][0]["state"]["coins"] += 1
        value["snapshots"][0]["stateExact"]["coins"] += 1
        for name in (access.ORACLE, access.RESOURCE):
            self.replace(name, access.canonical(value))
        with self.assertRaisesRegex(access.WorldAccessDataError, "Stale/corrupt world-access source contracts"):
            access.check(self.root)

    def test_authoritative_float_bits_ring_order_and_quests_are_required(self):
        for change in ("bits", "exact-state", "exact-operation", "ring", "quests"):
            value = self.oracle()
            if change == "bits":
                value["snapshots"][0]["stateExact"]["day_time"] = {"$f64": "000000000000f07f"}
            elif change == "exact-state": value["snapshots"][0].pop("stateExact")
            elif change == "exact-operation": value["cases"][0].pop("operationExact")
            elif change == "ring": value["rings"][0].pop()
            else: value["quests"] = {}
            with self.subTest(change=change), self.assertRaises(access.WorldAccessDataError):
                self.coverage(value)

    def test_native_asset_guid_is_stable_and_unique(self):
        rows = [row for row in self.contract["assetGuids"] if row["path"].endswith(".cs")]
        self.assertGreaterEqual(len(rows), 2)
        self.replace(rows[1]["path"] + ".meta", (self.root / (rows[0]["path"] + ".meta")).read_bytes())
        with self.assertRaisesRegex(access.WorldAccessDataError, "Missing/duplicate world-access asset GUID"):
            access.check(self.root)

    def test_original_world_png_is_verified(self):
        index = json.loads((self.root / access.ART / "index.json").read_bytes())
        name = access.ART + "/" + index["nodes"][0]["file"]
        data = bytearray((self.root / name).read_bytes()); data[-1] ^= 1
        self.replace(name, bytes(data))
        with self.assertRaises(access.WorldAccessDataError):
            access.check(self.root)

    def test_world_art_identity_placement_variants_and_pixels_are_verified(self):
        name = access.ART + "/index.json"
        original = json.loads((self.root / name).read_bytes())
        # Each mutation must fail even if its surrounding JSON remains valid.
        for change in ("duplicate", "position", "rgba", "exporter", "snapshots", "path"):
            value = copy.deepcopy(original)
            if change == "duplicate": value["nodes"].append(copy.deepcopy(value["nodes"][0]))
            elif change == "position": value["nodes"][0]["position"][0] += 32
            elif change == "rgba": value["nodes"][0]["rgbaSha256"] = "0" * 64
            elif change == "exporter": value["exporterSha256"] = "0" * 64
            elif change == "snapshots": value["snapshots"].pop()
            else: value["nodes"][0]["file"] = "../foreign.png"
            self.replace(name, access.canonical(value))
            with self.subTest(change=change), self.assertRaises(access.WorldAccessDataError):
                access.check(self.root)


if __name__ == "__main__":
    unittest.main()
