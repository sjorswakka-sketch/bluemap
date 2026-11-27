"""Phase 17 guards: professions, recipes, shops and fishing stay bound to the recorded Godot source."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))

import build_migration_professions as professions  # noqa: E402
import record_migration_professions as recorder  # noqa: E402
import verify_unity_package as package  # noqa: E402


def load_oracle() -> dict:
    return json.loads((ROOT / professions.ORACLE).read_bytes().decode('utf-8'))


class ProfessionsContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.oracle = load_oracle()
        cls.contract = professions.check(ROOT)

    def test_current_sources_match_the_recorded_contract(self) -> None:
        coverage = self.contract['coverage']
        self.assertEqual(self.contract['phase'], 17)
        self.assertEqual((coverage['cases'], coverage['recipes'], coverage['shops']), (1306, 52, 2))
        self.assertGreaterEqual(coverage['operations'], 5000)
        self.assertFalse(self.contract['personalSavesUsed'])

    def test_every_recipe_resource_and_shop_row_has_a_source_case(self) -> None:
        ids = {case['id'] for case in self.oracle['cases']}
        catalogs = self.oracle['catalogs']
        for recipe in catalogs['recipes']:
            self.assertIn('craft-valid-' + recipe, ids)
        for resource in catalogs['resources']:
            self.assertIn('gather-ready-' + resource, ids)
        rows = sum(len(shop['items']) for shop in catalogs['shops'].values())
        self.assertEqual(rows, self.contract['coverage']['shopRows'])
        self.assertEqual(len([name for name in ids if name.startswith('shop-buy-')]), rows)

    def test_recipe_order_is_the_source_insertion_order(self) -> None:
        ordered = [pair[0] for pair in dict(self.oracle['catalogsOrdered']['$dict'])['recipes']['$dict']]
        self.assertEqual(ordered, self.oracle['orders']['recipes'])
        self.assertEqual(ordered[:2], ['stone_axe', 'stone_pickaxe'])

    def test_runtime_catalog_is_small_and_derived(self) -> None:
        derived = professions.runtime_catalog(self.oracle)
        self.assertEqual((ROOT / professions.CATALOG_RESOURCE).read_bytes().replace(b'\r\n', b'\n'), derived)
        self.assertLess(len(derived), 400_000)
        self.assertNotIn(b'"cases"', derived)

    def test_generator_results_are_explicit_inputs(self) -> None:
        self.assertEqual(self.oracle['randomBoundary'], professions.RANDOM_BOUNDARY)
        rolls = [case for case in self.oracle['cases'] if case['id'].startswith('fish-roll-')]
        self.assertEqual(len(rolls), 96)
        for case in rolls:
            operation = case['operations'][0]
            draws = operation[5]
            self.assertIn(len(draws), (1, 2))
            self.assertTrue(all(isinstance(value, float) and 0.0 <= value < 1.0 for value in draws))
        reels = [case for case in self.oracle['cases'] if case['id'].startswith('reel-')]
        self.assertEqual({case['results'][0]['value'][-1]['state'] for case in reels}, {'gevangen', 'ontsnapt'})

    def test_fishing_sessions_cover_catch_escape_and_too_late(self) -> None:
        outcomes = set()
        for case in self.oracle['cases']:
            if case['id'].startswith('fishing-') and isinstance(case['results'][0]['value'], dict):
                for frame in case['results'][0]['value'].get('frames', []):
                    outcomes.add(frame['outcome'])
        self.assertLessEqual({'gevangen', 'ontsnapt', 'te_laat'}, outcomes)

    def test_lost_family_or_changed_identity_fails_closed(self) -> None:
        dropped = copy.deepcopy(self.oracle)
        dropped['cases'] = [case for case in dropped['cases'] if not case['id'].startswith('shop-')]
        with self.assertRaises(professions.ProfessionsDataError):
            professions.validate_oracle(dropped)
        personal = copy.deepcopy(self.oracle)
        personal['personalSavesUsed'] = True
        with self.assertRaises(professions.ProfessionsDataError):
            professions.validate_oracle(personal)
        boundary = copy.deepcopy(self.oracle)
        boundary['randomBoundary'] = 'engine-random'
        with self.assertRaises(professions.ProfessionsDataError):
            professions.validate_oracle(boundary)

    def test_changed_exact_number_fails_closed(self) -> None:
        changed = copy.deepcopy(self.oracle)
        case = next(row for row in changed['cases'] if row['id'] == 'gather-ready-copper')
        case['results'][2]['value'] = 1.36
        with self.assertRaises(professions.ProfessionsDataError):
            professions.validate_oracle(changed)

    def test_decimal_mirror_tolerates_one_final_digit_only(self) -> None:
        witness = {'$f64': '000000003b8ec93f'}
        document = {'float64Encoding': 'ieee754-binary64-little-endian-hex',
                    'orderedInputEncoding': 'dictionary-pairs-and-exact-f64-v1',
                    'catalogs': {}, 'catalogsExact': {}, 'catalogsOrdered': {'$dict': []},
                    'cases': [{'id': 'x', 'initial': {}, 'initialExact': {}, 'initialOrdered': {'$dict': []},
                               'operations': [[0.199653029441834]], 'operationsExact': [[witness]],
                               'operationsOrdered': [[witness]], 'results': [], 'resultsExact': [],
                               'expected': {}, 'expectedExact': {}}]}
        recorder.normalize_exact_mirrors(document)
        far = copy.deepcopy(document)
        far['cases'][0]['operations'] = [[0.199653029441840]]
        with self.assertRaises(ValueError):
            recorder.normalize_exact_mirrors(far)

    def test_tampered_unity_resource_or_source_is_detected(self) -> None:
        with tempfile.TemporaryDirectory(prefix='bluemap-professions-test-') as temporary:
            copy_root = Path(temporary)
            names = {professions.CONTRACT, professions.ORACLE, professions.SOURCE_MANIFEST, *professions.RECORDERS,
                     *self.contract['sources'], *self.contract['unityAssets']}
            for name in names:
                target = copy_root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, target)
            for folder in sorted({path.parent for path in (ROOT / professions.ASSETS).rglob('*')} | {ROOT / professions.ASSETS}):
                relative = folder.relative_to(ROOT).as_posix() + '.meta'
                shutil.copyfile(ROOT / relative, copy_root / relative)
            professions.check(copy_root)
            catalog = copy_root / professions.CATALOG_RESOURCE
            original = catalog.read_bytes()
            tampered = original.replace(b'potion', b'potiom', 1)
            self.assertNotEqual(tampered, original)
            catalog.write_bytes(tampered)
            with self.assertRaises(professions.ProfessionsDataError):
                professions.check(copy_root)
            catalog.write_bytes(original)
            source = copy_root / 'scripts/core/professions.gd'
            source.write_bytes(source.read_bytes() + b'\n# changed\n')
            with self.assertRaises(professions.ProfessionsDataError):
                professions.check(copy_root)

    def test_package_contract_names_the_native_checks(self) -> None:
        self.assertEqual(package.PREVIEW_VERSIONS[17], '0.13.0-phase17')
        self.assertIn('professions_model_source_equivalence', package.PROFESSIONS_DETAIL_CHECKS)
        runner = (ROOT / professions.ASSETS / 'Runtime/Probes/ProfessionsProbeRunner.cs').read_text(encoding='utf-8')
        checks = (ROOT / professions.ASSETS / 'Runtime/Model/ProfessionsModelChecks.cs').read_text(encoding='utf-8')
        for name in package.PROFESSIONS_DETAIL_CHECKS:
            self.assertIn('"' + name + '"', runner + checks, name)

    def test_shop_placeholder_is_gone(self) -> None:
        story = (ROOT / 'unity/Assets/BlueMapRoute/Runtime/Session/StoryRouteController.cs').read_text(encoding='utf-8')
        self.assertNotIn('handelsfase van de migratie', story)
        self.assertIn('pendingShop', story)


if __name__ == '__main__':
    unittest.main()
