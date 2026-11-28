"""Phase 22 guards: the ending, New Game+ and the way back to Godot stay bound to the sources and the return oracle."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))

import build_migration_completion as completion  # noqa: E402
import verify_unity_package as package  # noqa: E402


class CompletionContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = completion.check(ROOT)
        cls.oracle = completion.oracle(ROOT)

    def test_current_sources_match_the_contract(self) -> None:
        self.assertEqual(self.contract['phase'], 22)
        self.assertFalse(self.contract['personalSavesUsed'])
        self.assertTrue(self.contract['recordedOracle'])
        self.assertEqual(self.contract['coverage']['sources'], len(completion.SOURCE_PATHS))

    def test_package_contract_names_the_native_checks(self) -> None:
        self.assertEqual(package.PREVIEW_VERSIONS[22], '0.18.0-phase22')
        self.assertEqual(set(self.contract['coverage']['nativeChecks']), package.COMPLETION_DETAIL_CHECKS)
        self.assertEqual(len(package.COMPLETION_DETAIL_CHECKS), 62)

    def test_godot_loaded_every_save_unity_wrote(self) -> None:
        source = json.loads((ROOT / completion.SAVE_ORACLE).read_text(encoding='utf-8'))
        self.assertEqual([row['id'] for row in self.oracle['cases']], [case['id'] for case in source['cases']])
        for row in self.oracle['cases']:
            self.assertTrue(row['godotAccepted'] and row['godotStateEqualsOriginal'], row['id'])
            self.assertEqual(len(row['sha256']), 64)
        self.assertEqual((ROOT / completion.ORACLE_RESOURCE).read_bytes().replace(b'\r\n', b'\n'),
                         (ROOT / completion.ORACLE).read_bytes().replace(b'\r\n', b'\n'))

    def test_a_refused_return_fails_closed(self) -> None:
        changed = copy.deepcopy(self.oracle)
        changed['cases'][3]['godotStateEqualsOriginal'] = False
        target = ROOT / completion.ORACLE
        original = target.read_bytes()
        try:
            target.write_bytes(json.dumps(changed).encode('utf-8'))
            with self.assertRaises(completion.CompletionDataError):
                completion.oracle(ROOT)
        finally:
            target.write_bytes(original)
        self.assertEqual(completion.check(ROOT), self.contract)

    def test_the_exporter_never_writes_into_a_godot_folder(self) -> None:
        exporter = (ROOT / completion.ASSETS / 'Runtime/Export/LegacyProfileExporter.cs').read_text(encoding='utf-8')
        self.assertIn('PersistencePaths.Disjoint(PersistencePaths.LegacyDefault, target)', exporter)
        self.assertIn('FileMode.CreateNew', exporter)
        self.assertNotIn('FileMode.Create,', exporter)
        self.assertNotIn('File.WriteAllBytes', exporter)
        save = (ROOT / completion.ASSETS / 'Runtime/Export/LegacySaveExporter.cs').read_text(encoding='utf-8')
        self.assertNotIn('System.IO', save)  # builds bytes in memory only

    def test_new_game_plus_keeps_the_original_numbers(self) -> None:
        completion.validate_rules(ROOT)
        combat = (ROOT / 'unity/Assets/BlueMapCombat/Runtime/Model/CombatModel.cs').read_text(encoding='utf-8')
        self.assertIn('Math.Ceiling(hp*(1+.5*State.Get("ng_plus").AsInt64()))', combat)

    def test_all_86_suites_have_a_place(self) -> None:
        rows = completion.suites(ROOT)
        self.assertEqual(len(rows), 86)
        self.assertEqual(len({row['suite'] for row in rows}), 86)
        guide = (ROOT / completion.COVERAGE).read_text(encoding='utf-8')
        for row in rows:
            self.assertIn('`' + row['suite'] + '`', guide)
        self.assertIn('leeswijzer', guide)

    def test_frame_budget_and_session_are_enforced(self) -> None:
        identity = {'phase': 22}
        names = sorted(package.COMPLETION_DETAIL_CHECKS)
        good = {'schemaVersion': 1, 'identity': identity, 'success': True, 'gameSaveAccessed': False,
                'checks': [{'name': name, 'passed': True} for name in names],
                'frameMaps': ['a', 'b', 'c', 'd', 'e'], 'frameAverageMs': [5.0] * 5, 'frameSlowestMs': [9.0] * 5,
                'sessionMaps': 37, 'sessionSimulatedMinutes': 12.3, 'sessionErrors': 0, 'sessionMemoryGrowthMb': 4.0}
        package.validate_completion(good, identity)
        for key, value in (('frameAverageMs', [5.0, 5.0, 5.0, 5.0, 40.0]), ('sessionMaps', 36), ('sessionErrors', 1),
                           ('sessionSimulatedMinutes', 2.0), ('sessionMemoryGrowthMb', 500.0)):
            bad = dict(good, **{key: value})
            with self.assertRaises(package.PackageError, msg=key):
                package.validate_completion(bad, identity)


if __name__ == '__main__':
    unittest.main()
