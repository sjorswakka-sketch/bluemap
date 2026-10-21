"""Reject missing inventory rules, changed original loot, unsafe IDs and stale proofs."""
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
import build_migration_inventory_state as inventory


class InventorySourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="BlueMap-Inventory-Data-Tests-")
        cls.addClassCleanup(temporary.cleanup)
        cls.root = Path(temporary.name)
        original = json.loads((ROOT / inventory.CONTRACT).read_bytes())
        names = {inventory.ORACLE, inventory.REGISTRY, inventory.ITEMS, inventory.QUESTS,
                 inventory.WORLD_INDEX, "migration/reference/source-manifest.json",
                 inventory.ASSETS + ".meta", *inventory.RECORDERS,
                 *(row["path"] for row in original["sourceAnchors"]),
                 *("migration/world/" + row["path"] for row in original["worldSnapshots"])}
        for name in names:
            target = cls.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / name).read_bytes())
        shutil.copytree(ROOT / inventory.ASSETS, cls.root / inventory.ASSETS)
        cls.reference = inventory.original_references(cls.root)
        cls.contract = inventory.build_contract(cls.root)
        (cls.root / inventory.CONTRACT).write_bytes(inventory.canonical(cls.contract))

    def replace(self, name, data):
        path = self.root / name
        original = path.read_bytes()
        self.addCleanup(path.write_bytes, original)
        path.write_bytes(data)

    def oracle(self):
        return json.loads((self.root / inventory.ORACLE).read_bytes())

    def coverage(self, value):
        return inventory.oracle_coverage(value, self.reference)

    def test_gitless_complete_contract_reads_no_engine_or_personal_profile(self):
        before = {p.relative_to(self.root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in self.root.rglob("*") if p.is_file()}
        result = inventory.check(self.root)
        self.assertEqual(result, self.contract)
        self.assertFalse(result["enginesStarted"])
        self.assertFalse(result["personalSavesUsed"])
        coverage = result["oracle"]["coverage"]
        self.assertEqual((coverage["items"], coverage["quests"], coverage["consumables"]), (226, 33, 71))
        self.assertEqual((coverage["maps"], coverage["loadedSnapshots"], coverage["cases"]), (37, 162, 304))
        self.assertEqual((coverage["canonicalChests"], coverage["canonicalPickups"]), (33, 73))
        self.assertTrue(coverage["dictionaryInputOrderPreserved"])
        self.assertEqual(before, {p.relative_to(self.root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in self.root.rglob("*") if p.is_file()})

    def test_original_inventory_source_cannot_be_refrozen(self):
        name = "scripts/core/stockroom.gd"
        self.replace(name, (self.root / name).read_bytes() + b"\n# unintended storage change\n")
        with self.assertRaisesRegex(inventory.InventoryDataError, "Preserved inventory source changed"):
            inventory.build_contract(self.root)

    def test_changed_recorder_requires_explicit_contract_review(self):
        name = "tools/record_migration_inventory_state.py"
        self.replace(name, (self.root / name).read_bytes() + b"\n# source comparison changed\n")
        with self.assertRaisesRegex(inventory.InventoryDataError, "Stale/corrupt inventory"):
            inventory.check(self.root)

    def test_all_original_item_limits_icons_quests_consumables_and_languages_required(self):
        for change in ("item", "limit", "icon", "quest", "food", "language", "name"):
            value = self.oracle()
            catalogs = value["catalogs"]
            if change == "item": catalogs["items"].pop(next(iter(catalogs["items"])))
            elif change == "limit": catalogs["items"]["arrow"]["max"] += 1
            elif change == "icon": catalogs["items"]["arrow"]["icon"] += 1
            elif change == "quest": catalogs["quests"].pop(next(iter(catalogs["quests"])))
            elif change == "food": catalogs["consumables"].pop()
            elif change == "language": catalogs["names"].pop("en")
            else: catalogs["names"]["en"].pop("arrow")
            with self.subTest(change=change), self.assertRaises(inventory.InventoryDataError):
                self.coverage(value)

    def test_missing_or_duplicate_original_behavior_families_rejected(self):
        original = self.oracle()
        names = ("home_transfer_roundtrip", "coast_material_only", "consume_preflight_no_loss",
                 "use_hurt_potion", "bag_cap_arrow",
                 next(row["id"] for row in original["cases"] if row["id"].startswith("original_chest_")))
        for name in names:
            value = copy.deepcopy(original)
            value["cases"] = [row for row in value["cases"] if row["id"] != name]
            with self.subTest(case=name), self.assertRaisesRegex(inventory.InventoryDataError, "behavior case IDs"):
                self.coverage(value)
        for change in ("duplicate", "foreign"):
            value = copy.deepcopy(original)
            if change == "duplicate": value["cases"].append(copy.deepcopy(value["cases"][0]))
            else: value["cases"][0]["id"] = "invented_case"
            with self.subTest(change=change), self.assertRaisesRegex(inventory.InventoryDataError, "behavior case IDs"):
                self.coverage(value)

    def test_float_bits_ordered_inputs_and_all34_state_fields_required(self):
        for change in ("bits", "initial-order", "operation-order", "duplicate-key", "state-field", "results"):
            value = self.oracle()
            row = value["cases"][0]
            if change == "bits": row["initialExact"]["day_time"] = {"$f64": "000000000000f07f"}
            elif change == "initial-order": row.pop("initialOrdered")
            elif change == "operation-order": row.pop("operationsOrdered")
            elif change == "duplicate-key": row["initialOrdered"]["$dict"].append(copy.deepcopy(row["initialOrdered"]["$dict"][0]))
            elif change == "state-field": row["initial"].pop("coastal_storage")
            else: row["results"].pop()
            with self.subTest(change=change), self.assertRaises(inventory.InventoryDataError):
                self.coverage(value)

    def test_every_loaded_original_map_and_state_variant_required(self):
        for change in ("missing", "duplicate", "foreign"):
            value = self.oracle()
            rows = value["loadedSceneLoot"]
            if change == "missing": rows.pop()
            elif change == "duplicate": rows[-1] = copy.deepcopy(rows[0])
            else: rows[0]["scenario"] = "invented_state"
            with self.subTest(change=change), self.assertRaisesRegex(inventory.InventoryDataError, "map/scenario"):
                self.coverage(value)

    def test_original_loaded_loot_address_position_reward_and_opened_state_bound(self):
        for change in ("address", "position", "reward", "opened", "missing", "store"):
            value = self.oracle()
            row = next(row for row in value["loadedSceneLoot"] if row["chests"])
            chest = row["chests"][0]
            if change == "address": chest["sourceAddress"][0] = 0
            elif change == "position": chest["position"][0] += 1
            elif change == "reward": chest["contents"][0][1] += 1
            elif change == "opened": chest["opened"] = not chest["opened"]
            elif change == "missing": row["chests"].pop()
            else:
                store = next(row["stores"][0] for row in value["loadedSceneLoot"] if row["stores"])
                store["kind"] = "invented_store"
            with self.subTest(change=change), self.assertRaisesRegex(inventory.InventoryDataError, "loaded loot address"):
                self.coverage(value)

    def test_canonical_registry_chests_and_pickup_unique_keys_remain_exact(self):
        for change in ("chest", "reward", "pickup"):
            value = self.oracle()
            if change == "chest": value["chests"].pop()
            elif change == "reward": value["chests"][0]["spec"]["contents"][0][1] += 1
            else: value["pickups"][0]["uniqueKey"] = "forged_claim"
            with self.subTest(change=change), self.assertRaisesRegex(inventory.InventoryDataError, "canonical"):
                self.coverage(value)

    def test_native_inventory_oracle_cannot_diverge(self):
        value = self.oracle()
        value["newGame"]["coins"] += 1
        self.replace(inventory.RESOURCE, inventory.canonical(value))
        with self.assertRaisesRegex(inventory.InventoryDataError, "Native inventory oracle differs"):
            inventory.check(self.root)

    def test_changed_matching_observations_still_require_contract_review(self):
        value = self.oracle()
        value["newGame"]["coins"] += 1
        for name in (inventory.ORACLE, inventory.RESOURCE):
            self.replace(name, inventory.canonical(value))
        with self.assertRaisesRegex(inventory.InventoryDataError, "Stale/corrupt inventory"):
            inventory.check(self.root)

    def test_inventory_asset_guids_are_stable_and_unique(self):
        rows = [row for row in self.contract["assetGuids"] if row["path"].endswith(".cs")]
        self.assertGreaterEqual(len(rows), 2)
        self.replace(rows[1]["path"] + ".meta", (self.root / (rows[0]["path"] + ".meta")).read_bytes())
        with self.assertRaisesRegex(inventory.InventoryDataError, "Missing/duplicate inventory asset GUID"):
            inventory.check(self.root)

    def test_frozen_original_scene_cannot_change_after_projection_cache(self):
        row = self.contract["worldSnapshots"][0]
        name = "migration/world/" + row["path"]
        self.replace(name, (self.root / name).read_bytes() + b"\n")
        with self.assertRaisesRegex(inventory.InventoryDataError, "Frozen original loot scene changed"):
            inventory.build_contract(self.root)

    def test_personal_saves_and_missing_original_methods_rejected(self):
        for change in ("personal", "method", "encoding", "ordered"):
            value = self.oracle()
            if change == "personal": value["personalSavesUsed"] = True
            elif change == "method": value["sourceMethods"].pop()
            elif change == "encoding": value["float64Encoding"] = "approximate"
            else: value.pop("orderedInputEncoding")
            with self.subTest(change=change), self.assertRaises(inventory.InventoryDataError):
                self.coverage(value)


if __name__ == "__main__":
    unittest.main()
