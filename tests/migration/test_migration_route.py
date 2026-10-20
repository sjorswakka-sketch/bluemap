"""Reject changed gameplay observations, source drawings and route identities."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import build_migration_route as route


class RouteSourceContractTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="BlueMap-Route-Data-Tests-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        art = json.loads((ROOT / route.ART / "index.json").read_bytes())
        names = {*route.SOURCE_PATHS, "migration/reference/source-manifest.json", route.ORACLE,
                 route.ASSETS + ".meta", "tools/migration_route_export.gd", "tools/record_migration_route.py",
                 "tools/migration_route_art.gd", "tools/record_migration_route_art.py",
                 *(name.removeprefix("res://") for name in art["sourceFiles"])}
        for name in names:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / name).read_bytes())
        shutil.copytree(ROOT / route.ASSETS, self.root / route.ASSETS)
        self.contract = route.build_contract(self.root)
        (self.root / route.CONTRACT).write_bytes(route.canonical(self.contract))

    def oracle(self):
        return json.loads((self.root / route.ORACLE).read_bytes())

    def test_gitless_route_source_checks_start_no_engine_or_personal_storage(self):
        before = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        contract = route.check(self.root)
        self.assertEqual(contract, self.contract)
        self.assertFalse(contract["enginesStarted"])
        self.assertFalse(contract["personalSavesUsed"])
        self.assertEqual(contract["oracle"]["coverage"]["scenarios"], 26)
        self.assertEqual(contract["oracle"]["coverage"]["wornGearDurationCases"], 4)
        self.assertGreater(contract["oracle"]["coverage"]["exactNumericValues"], 0)
        self.assertEqual(contract["art"]["maps"], sorted(route.MAPS))
        self.assertEqual(before, {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()})

    def test_original_gameplay_source_cannot_be_silently_refrozen(self):
        path = self.root / "scripts/core/first_route.gd"
        path.write_bytes(path.read_bytes() + b"\n# unintended route change\n")
        with self.assertRaisesRegex(route.RouteDataError, "Preserved route source changed"):
            route.build_contract(self.root)

    def test_original_drawing_source_cannot_be_silently_refrozen(self):
        index = json.loads((self.root / route.ART / "index.json").read_bytes())
        relative = next(iter(index["sourceFiles"])).removeprefix("res://")
        path = self.root / relative
        path.write_bytes(path.read_bytes() + b"\n# unintended drawing change\n")
        with self.assertRaises(route.RouteDataError):
            route.build_contract(self.root)

    def test_changed_native_oracle_copy_rejected(self):
        value = self.oracle()
        value["cases"][0]["expected"]["coins"] += 1
        (self.root / route.RESOURCE).write_bytes(route.canonical(value))
        with self.assertRaisesRegex(route.RouteDataError, "Native route oracle copy differs"):
            route.check(self.root)

    def test_changed_matching_oracles_disagree_with_frozen_contract(self):
        value = self.oracle()
        value["cases"][0]["expected"]["coins"] += 1
        for name in (route.RESOURCE, route.ORACLE):
            (self.root / name).write_bytes(route.canonical(value))
        with self.assertRaisesRegex(route.RouteDataError, "Stale/corrupt route source contracts"):
            route.check(self.root)

    def test_missing_or_duplicate_route_scenario_rejected(self):
        for change in ("missing", "duplicate"):
            value = self.oracle()
            if change == "missing": value["cases"].pop()
            else: value["cases"][-1] = copy.deepcopy(value["cases"][0])
            with self.subTest(change=change), self.assertRaisesRegex(route.RouteDataError, "IDs are missing or duplicated"):
                route.oracle_coverage(value)

    def test_personal_save_or_missing_original_method_rejected(self):
        for change in ("save", "method", "catalog", "state", "results", "numeric"):
            value = self.oracle()
            if change == "save": value["personalSavesUsed"] = True
            elif change == "method": value["sourceMethods"].pop()
            elif change == "catalog": value["catalogs"]["quests"] = {}
            elif change == "state": value["cases"][0]["initial"].pop("personal_home")
            elif change == "results": value["cases"][0]["results"].pop()
            else: value["float64Encoding"] = "rounded"
            with self.subTest(change=change), self.assertRaises(route.RouteDataError):
                route.oracle_coverage(value)

    def test_modified_source_png_rejected(self):
        index = json.loads((self.root / route.ART / "index.json").read_bytes())
        path = self.root / route.ART / index["nodes"][0]["file"]
        data = bytearray(path.read_bytes()); data[-1] ^= 1; path.write_bytes(data)
        with self.assertRaisesRegex(route.RouteDataError, "drawing pixels/size changed"):
            route.check(self.root)

    def test_original_worn_gear_duration_and_exact_bits_cannot_be_dropped(self):
        for change in ("missing", "duplicate", "nonfinite", "malformed"):
            value = self.oracle()
            if change == "missing": value["durations"].pop()
            elif change == "duplicate": value["durations"][-1] = copy.deepcopy(value["durations"][0])
            elif change == "nonfinite": value["durations"][0]["durationExact"]["$f64"] = "000000000000f07f"
            else: value["durations"][0]["durationExact"]["$f64"] = "ff"
            with self.subTest(change=change), self.assertRaises(route.RouteDataError):
                route.oracle_coverage(value)

    def test_duplicate_node_and_unsafe_art_path_rejected(self):
        path = self.root / route.ART / "index.json"
        original = json.loads(path.read_bytes())
        for change in ("duplicate", "path", "placement", "source", "exporter", "map"):
            value = copy.deepcopy(original)
            if change == "duplicate": value["nodes"].append(copy.deepcopy(value["nodes"][0]))
            elif change == "path": value["nodes"][0]["file"] = "../other.png"
            elif change == "placement": value["nodes"][0]["position"] = [12]
            elif change == "source": value["nodes"][0]["script"] = "res://not-original.gd"
            elif change == "exporter": value["exporterSha256"] = "0" * 64
            else: value["nodes"][0]["mapId"] = "foreign"
            path.write_bytes(route.canonical(value))
            with self.subTest(change=change), self.assertRaises(route.RouteDataError):
                route.check(self.root)

    def test_decoded_pixel_hash_and_original_appearance_palettes_are_required(self):
        path = self.root / route.ART / "index.json"
        original = json.loads(path.read_bytes())
        for change in ("rgba", "palette"):
            value = copy.deepcopy(original)
            if change == "rgba": value["nodes"][0]["rgbaSha256"] = "0" * 64
            else: value["palettes"]["hair"][0] = [1, 1]
            path.write_bytes(route.canonical(value))
            with self.subTest(change=change), self.assertRaises(route.RouteDataError):
                route.check(self.root)

    def test_duplicate_native_route_guid_rejected(self):
        rows = [row for row in self.contract["assetGuids"] if row["path"].endswith(".cs")]
        first, second = (self.root / (row["path"] + ".meta") for row in rows[:2])
        second.write_bytes(first.read_bytes())
        with self.assertRaisesRegex(route.RouteDataError, "Missing/duplicate route asset GUID"):
            route.check(self.root)


if __name__ == "__main__":
    unittest.main()
