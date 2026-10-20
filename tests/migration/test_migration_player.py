"""Missing source observations, altered copies and metadata must fail before build."""
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
import build_migration_player as player


class PlayerSourceContractTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="BlueMap-Player-Data-Tests-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in (*player.SOURCE_PATHS, "migration/reference/source-manifest.json",
                     *(pair[0] for pair in player.ORACLES.values()), "unity/Assets/BlueMapPlayer.meta"):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / name).read_bytes())
        shutil.copytree(ROOT / "unity/Assets/BlueMapPlayer", self.root / "unity/Assets/BlueMapPlayer")
        self.contract = player.build_contract(self.root)
        (self.root / player.CONTRACT).write_bytes(player.canonical(self.contract))

    def test_checked_source_archive_needs_neither_git_nor_engine(self):
        before = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        checked = player.check(self.root)
        self.assertEqual(checked, self.contract)
        self.assertFalse(checked["enginesStarted"])
        self.assertFalse(checked["personalSavesUsed"])
        self.assertEqual(before, {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()})
        counts = {entry["kind"]: entry["coverage"] for entry in checked["oracles"]}
        self.assertEqual(counts["input"], {"actions": 36, "bindings": 86, "circularDeadzoneVectors": 16})
        self.assertEqual(counts["motion"]["motions"], 15)
        self.assertGreater(counts["motion"]["exactNumericValues"], 0)

    def test_changed_original_source_cannot_be_silently_refrozen(self):
        source = self.root / "scripts/entities/player.gd"
        source.write_bytes(source.read_bytes() + b"\n# unintended change\n")
        with self.assertRaisesRegex(player.PlayerDataError, "Preserved player source changed"):
            player.build_contract(self.root)

    def test_altered_native_copy_is_rejected(self):
        target = self.root / player.ORACLES["input"][1]
        data = json.loads(target.read_bytes())
        data["switchDeadzone"] = 0.9
        target.write_bytes(player.canonical(data))
        with self.assertRaisesRegex(player.PlayerDataError, "Native oracle copy differs"):
            player.check(self.root)

    def test_matching_altered_source_and_copy_still_disagree_with_frozen_contract(self):
        source, target = (self.root / name for name in player.ORACLES["input"])
        data = json.loads(source.read_bytes())
        data["switchDeadzone"] = 0.9
        source.write_bytes(player.canonical(data)); target.write_bytes(player.canonical(data))
        with self.assertRaisesRegex(player.PlayerDataError, "Stale/corrupt player source contracts"):
            player.check(self.root)

    def test_missing_source_cases_cannot_be_replaced_by_duplicate_ids(self):
        data = json.loads((self.root / player.ORACLES["input"][0]).read_bytes())
        data["defaults"][-1] = copy.deepcopy(data["defaults"][0])
        with self.assertRaisesRegex(player.PlayerDataError, "IDs are missing or duplicated"):
            player.oracle_coverage("input", data)

    def test_missing_bindings_or_vectors_are_not_coverage(self):
        original = json.loads((self.root / player.ORACLES["input"][0]).read_bytes())
        for change in ("bindings", "vectors"):
            data = copy.deepcopy(original)
            if change == "bindings":
                next(row for row in data["defaults"] if row["bindings"])["bindings"].pop()
            else:
                data["vectors"].pop()
            with self.subTest(change=change), self.assertRaisesRegex(player.PlayerDataError, "coverage is incomplete"):
                player.oracle_coverage("input", data)

    def test_duplicate_json_keys_and_nonfinite_numbers_are_rejected(self):
        for data in (b'{"a":1,"a":2}', b'{"value":NaN}', b'{"value":Infinity}'):
            with self.subTest(data=data), self.assertRaises(player.PlayerDataError):
                player.document(data, "untrusted oracle fixture")

    def test_duplicate_player_guid_is_rejected(self):
        rows = [row for row in self.contract["assetGuids"] if row["path"].endswith(".cs")]
        first, second = (self.root / (row["path"] + ".meta") for row in rows[:2])
        second.write_bytes(first.read_bytes())
        with self.assertRaisesRegex(player.PlayerDataError, "Missing/duplicate player asset GUID"):
            player.check(self.root)

    def test_missing_player_metadata_is_rejected(self):
        target = self.root / (self.contract["assetGuids"][-1]["path"] + ".meta")
        target.unlink()
        with self.assertRaisesRegex(player.PlayerDataError, "Missing/oversized phase-8 source"):
            player.check(self.root)


if __name__ == "__main__":
    unittest.main()
