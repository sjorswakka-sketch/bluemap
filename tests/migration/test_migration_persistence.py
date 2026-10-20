"""Reject altered save/settings observations, missing cases and Unity metadata."""
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
import build_migration_persistence as persistence


class PersistenceSourceContractTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="BlueMap-Persistence-Data-Tests-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in (*persistence.SOURCE_PATHS, "migration/reference/source-manifest.json",
                     *(pair[0] for pair in persistence.ORACLES.values()), "unity/Assets/BlueMapPersistence.meta"):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / name).read_bytes())
        shutil.copytree(ROOT / "unity/Assets/BlueMapPersistence", self.root / "unity/Assets/BlueMapPersistence")
        self.contract = persistence.build_contract(self.root)
        (self.root / persistence.CONTRACT).write_bytes(persistence.canonical(self.contract))

    def oracle(self, kind):
        return json.loads((self.root / persistence.ORACLES[kind][0]).read_bytes())

    def test_gitless_source_archive_checks_without_engines_or_personal_storage(self):
        before = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        checked = persistence.check(self.root)
        self.assertEqual(checked, self.contract)
        self.assertFalse(checked["enginesStarted"])
        self.assertFalse(checked["personalSavesUsed"])
        counts = {entry["kind"]: entry["coverage"] for entry in checked["oracles"]}
        self.assertEqual(counts["save"]["saveScenarios"], 22)
        self.assertEqual(counts["save"]["corruptSaves"], 6)
        self.assertGreater(counts["save"]["exactNumericValues"], 0)
        self.assertEqual(counts["settings"]["settingsScenarios"], 10)
        self.assertEqual(counts["settings"]["actionsPerScenario"], 22)
        self.assertEqual(before, {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()})

    def test_changed_original_save_code_cannot_be_silently_refrozen(self):
        source = self.root / "scripts/core/game_state.gd"
        source.write_bytes(source.read_bytes() + b"\n# unintended save change\n")
        with self.assertRaisesRegex(persistence.PersistenceDataError, "Preserved persistence source changed"):
            persistence.build_contract(self.root)

    def test_altered_native_oracle_copy_is_rejected(self):
        target = self.root / persistence.ORACLES["settings"][1]
        data = json.loads(target.read_bytes())
        data["cases"][0]["locale"] = "fr"
        target.write_bytes(persistence.canonical(data))
        with self.assertRaisesRegex(persistence.PersistenceDataError, "Native oracle copy differs"):
            persistence.check(self.root)

    def test_matching_changed_observations_and_native_copy_still_disagree_with_frozen_contract(self):
        source, target = (self.root / name for name in persistence.ORACLES["settings"])
        data = json.loads(source.read_bytes())
        data["cases"][0]["locale"] = "fr"
        source.write_bytes(persistence.canonical(data)); target.write_bytes(persistence.canonical(data))
        with self.assertRaisesRegex(persistence.PersistenceDataError, "Stale/corrupt persistence source contracts"):
            persistence.check(self.root)

    def test_duplicate_cases_cannot_replace_missing_old_format_scenarios(self):
        for kind in ("save", "settings"):
            data = self.oracle(kind)
            data["cases"][-1] = copy.deepcopy(data["cases"][0])
            with self.subTest(kind=kind), self.assertRaisesRegex(persistence.PersistenceDataError, "IDs are missing or duplicated"):
                persistence.oracle_coverage(kind, data)

    def test_oracle_that_used_personal_saves_is_never_accepted(self):
        for kind in ("save", "settings"):
            data = self.oracle(kind)
            data["personalSavesUsed"] = True
            with self.subTest(kind=kind), self.assertRaisesRegex(persistence.PersistenceDataError, "accessed existing saves"):
                persistence.oracle_coverage(kind, data)

    def test_corrupt_save_acceptance_or_missing_corrupt_case_is_rejected(self):
        original = self.oracle("save")
        for change in ("accepted", "missing", "duplicate"):
            data = copy.deepcopy(original)
            if change == "accepted": data["corrupt"][0]["accepted"] = True
            elif change == "missing": data["corrupt"].pop()
            else: data["corrupt"][-1] = copy.deepcopy(data["corrupt"][0])
            with self.subTest(change=change), self.assertRaisesRegex(persistence.PersistenceDataError, "Corrupt-save coverage"):
                persistence.oracle_coverage("save", data)

    def test_malformed_generated_save_payload_is_rejected(self):
        data = self.oracle("save")
        data["cases"][0]["inputJson"] = '{"coins":1,"coins":2}'
        with self.assertRaisesRegex(persistence.PersistenceDataError, "Duplicate JSON key"):
            persistence.oracle_coverage("save", data)

    def test_settings_source_document_requires_bounded_valid_base64_utf8(self):
        original = self.oracle("settings")
        for bad in ("not base64!", "/w==", 123):
            data = copy.deepcopy(original)
            data["cases"][0]["documents"]["controls"] = bad
            with self.subTest(bad=bad), self.assertRaises(persistence.PersistenceDataError):
                persistence.oracle_coverage("settings", data)

    def test_settings_scenarios_each_require_all_action_ids(self):
        original = self.oracle("settings")
        for change in ("missing", "duplicate"):
            data = copy.deepcopy(original)
            bindings = data["cases"][0]["bindings"]
            if change == "missing": bindings.pop()
            else: bindings[-1] = copy.deepcopy(bindings[0])
            with self.subTest(change=change), self.assertRaisesRegex(persistence.PersistenceDataError, "binding coverage"):
                persistence.oracle_coverage("settings", data)

    def test_duplicate_json_keys_and_nonfinite_numbers_are_rejected(self):
        for raw in (b'{"a":1,"a":2}', b'{"value":NaN}', b'{"value":Infinity}'):
            with self.subTest(raw=raw), self.assertRaises(persistence.PersistenceDataError):
                persistence.document(raw, "untrusted fixture")

    def test_duplicate_persistence_guid_is_rejected(self):
        rows = [row for row in self.contract["assetGuids"] if row["path"].endswith(".cs")]
        first, second = (self.root / (row["path"] + ".meta") for row in rows[:2])
        second.write_bytes(first.read_bytes())
        with self.assertRaisesRegex(persistence.PersistenceDataError, "Missing/duplicate persistence asset GUID"):
            persistence.check(self.root)

    def test_missing_asset_metadata_is_rejected(self):
        target = self.root / (self.contract["assetGuids"][-1]["path"] + ".meta")
        target.unlink()
        with self.assertRaisesRegex(persistence.PersistenceDataError, "Missing/oversized phase-9 source"):
            persistence.check(self.root)


if __name__ == "__main__":
    unittest.main()
