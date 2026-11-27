"""Phase 19 guards: the garden, production and water types stay bound to the recorded Godot source."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))

import build_migration_farm as farm  # noqa: E402
import verify_unity_package as package  # noqa: E402


class FarmContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.oracle = json.loads((ROOT / farm.ORACLE).read_bytes().decode('utf-8'))
        cls.contract = farm.check(ROOT)
        cls.cases = {case['id']: case for case in cls.oracle['cases']}

    def results(self, name: str, operation: str) -> list:
        case = self.cases[name]
        return [result for step, result in zip(case['operations'], case['results']) if step[0] == operation]

    def test_current_sources_match_the_recorded_contract(self) -> None:
        coverage = self.contract['coverage']
        self.assertEqual(self.contract['phase'], 19)
        self.assertEqual((coverage['cases'], coverage['crops'], coverage['jobs'], coverage['waterTypes'], coverage['waterMaps']), (297, 8, 3, 10, 37))
        self.assertGreater(coverage['operations'], 2500)
        self.assertFalse(self.contract['personalSavesUsed'])

    def test_every_crop_completes_its_whole_life(self) -> None:
        for crop, info in self.oracle['catalogs']['farm']['crops'].items():
            acts = self.results('life-' + crop, 'act')
            # Flowers stay in bloom for the bees: they are sown and restored, never harvested or fertilized.
            self.assertGreaterEqual(sum(1 for value in acts if value is True), 3 if crop == 'flower' else 5, crop)
            state = self.results('life-' + crop, 'farm_state')[-1]
            self.assertNotIn('26,34' if crop == 'apple' else '25,34', state['cells'], crop)
            # A dry crop never grows and never withers; water lets the same plant finish.
            dry = self.cases['life-dry-' + crop]
            texts = self.results('life-dry-' + crop, 'cell_text')
            self.assertIn('verdort niet', texts[0], crop)
            self.assertIs([r for s, r in zip(dry['operations'], dry['results']) if s[0] == 'act' and s[2] == 'harvest'][0], False, crop)
            if crop != 'flower':
                self.assertIn('Rijp om te oogsten', texts[1], crop)
            self.assertGreater(info['seconds'], 0)

    def test_growth_needs_active_time_and_never_overshoots(self) -> None:
        for name in ('advance-field', 'advance-field-moved', 'advance-jobs'):
            case = self.cases[name]
            states = self.results(name, 'farm_state')
            steps = [step[1] for step in case['operations'] if step[0] == 'advance']
            self.assertEqual(states[0], states[1], 'zero and negative time change nothing: ' + name)
            self.assertIn(0.0, steps)
            crops = self.oracle['catalogs']['farm']['crops']
            for cell in states[-1]['cells'].values():
                if 'crop' in cell:
                    info = crops[cell['crop']]
                    limit = info.get('regrow', info['seconds']) if cell.get('established') else info['seconds']
                    self.assertLessEqual(cell['growth'], limit)
            for job, row in states[-1]['jobs'].items():
                self.assertLessEqual(row['time'], self.oracle['catalogs']['farm']['jobs'][job]['seconds'])
            self.assertLessEqual(states[-1]['honey'], 8)

    def test_irrigation_reaches_only_connected_channels(self) -> None:
        sources = {tuple(cell) for cell in self.oracle['catalogs']['farm']['sources']}
        for name in ('irrigation-line', 'irrigation-west', 'irrigation-north', 'irrigation-island', 'irrigation-ring', 'irrigation-field'):
            result = self.results(name, 'irrigation')[0]
            wet = {tuple(cell) for cell in result['wet']}
            self.assertEqual(len(wet), len(result['wet']), name)
            for x, y, from_x, from_y in result['flow']:
                self.assertEqual(abs(x - from_x) + abs(y - from_y), 1, name)
                self.assertTrue((from_x, from_y) in wet or (from_x, from_y) in sources, name)
        island = self.results('irrigation-island', 'irrigation')[0]
        self.assertEqual(island['wet'], [])
        self.assertTrue(self.results('irrigation-line', 'irrigation')[0]['wet'])

    def test_work_feedback_covers_every_refusal(self) -> None:
        reasons = set()
        for name, case in self.cases.items():
            if not name.startswith('status-'):
                continue
            for step, result in zip(case['operations'], case['results']):
                if step[0] == 'sweep_status':
                    reasons.update(result)
                elif step[0] == 'status':
                    reasons.add(result['reason'])
        self.assertIn('', reasons)
        self.assertGreaterEqual(len(reasons), 22)
        # Garden produce has no bag limit in the source, so a full-bag refusal cannot occur and is not expected.
        for text in ('Kom iets dichterbij.', 'Werk binnen je eigen tuin.', 'Haal eerst je gratis tuinhak bij het tuinbord.',
                     'Bewerk eerst de grond.', 'Dit gewas is nog niet rijp.', 'Deze grond is al hersteld.'):
            self.assertIn(text, reasons)
        self.assertFalse(any(text.startswith('Maak ruimte') for text in reasons))

    def test_production_costs_and_yields(self) -> None:
        jobs = self.oracle['catalogs']['farm']['jobs']
        self.assertEqual({name: (row['cost'], row['yield'], row['seconds']) for name, row in jobs.items()},
                         {'compost': (2, 3, 30.0), 'wine_a': (3, 1, 90.0), 'wine_b': (3, 1, 90.0)})
        for job in jobs:
            starts = self.results('job-' + job, 'start_job')
            self.assertEqual(starts[:6], [False, False, False, False, True, False], job)
            collects = self.results('job-' + job, 'collect')
            self.assertEqual(collects[:2], [False, False], job)
            self.assertEqual(collects.index(True), 2 if job == 'compost' else 3, job)
            self.assertEqual(self.results('job-away-' + job, 'start_job'), [False], job)
            self.assertEqual(self.results('job-wrong-station-' + job, 'start_job'), [False], job)
            # Ingredients in the reachable house stock count; out of reach they do not.
            self.assertEqual(self.results('job-chest-' + job, 'start_job'), [False, False, True, False], job)
        self.assertEqual(self.results('job-hive', 'collect')[-1], True)

    def test_a_refused_purchase_or_harvest_takes_nothing(self) -> None:
        for name in ('buy-none', 'buy-away'):
            case = self.cases[name]
            self.assertEqual(case['initial']['coins'], case['expected']['coins'], name)
            self.assertEqual(case['initial']['inventory'], case['expected']['inventory'], name)
            self.assertFalse(any(self.results(name, 'buy')), name)
        self.assertTrue(any(self.results('buy-rich', 'buy')))
        self.assertEqual(self.results('harvest-all-forest', 'harvest_all'), [0, 0, 0, 0])
        self.assertEqual(self.results('harvest-all-village', 'harvest_all')[0], 0)
        self.assertGreater(self.results('harvest-all-village', 'harvest_all')[1], 0)

    def test_water_types_keep_their_meaning(self) -> None:
        types = self.oracle['catalogs']['water']['types']
        self.assertEqual({kind for kind, spec in types.items() if spec['irrigates']}, {'river', 'puddle', 'stream', 'lake', 'canal', 'pool'})
        self.assertEqual({kind for kind, spec in types.items() if not spec['fresh']}, {'sea', 'geyser'})
        kinds = {name[len('water-describe-'):]: [feature['kind'] for feature in case['results'][0]]
                 for name, case in self.cases.items() if name.startswith('water-describe-')}
        self.assertEqual(len(kinds), 37)
        self.assertEqual(kinds['village'], ['canal'])
        self.assertIn('hot_spring', kinds['ijsdal'])
        self.assertIn('geyser', kinds['sunwell'])
        self.assertEqual(set(kinds['kruipmoeras']), {'marsh'})
        mouth = self.cases['water-describe-river_mouth']['results'][0][0]['properties']
        self.assertFalse(mouth['fresh'] or mouth['irrigates'])
        for name, case in self.cases.items():
            if name.startswith('water-describe-'):
                for feature in case['results'][0]:
                    self.assertEqual(feature['count'], len(feature['cells']))
                    self.assertEqual(feature['north'], min(feature['cells'], key=lambda cell: (cell[1], cell[0])))

    def test_runtime_catalog_is_small_and_derived(self) -> None:
        derived = farm.runtime_catalog(self.oracle)
        self.assertEqual((ROOT / farm.CATALOG_RESOURCE).read_bytes().replace(b'\r\n', b'\n'), derived)
        self.assertLess(len(derived), 120_000)
        self.assertNotIn(b'"cases"', derived)

    def test_lost_family_or_changed_identity_fails_closed(self) -> None:
        dropped = copy.deepcopy(self.oracle)
        dropped['cases'] = [case for case in dropped['cases'] if not case['id'].startswith('irrigation-')]
        with self.assertRaises(farm.FarmDataError):
            farm.validate_oracle(dropped)
        personal = copy.deepcopy(self.oracle)
        personal['personalSavesUsed'] = True
        with self.assertRaises(farm.FarmDataError):
            farm.validate_oracle(personal)
        missing = copy.deepcopy(self.oracle)
        missing['cases'] = [case for case in missing['cases'] if case['id'] != 'life-dry-apple']
        with self.assertRaises(farm.FarmDataError):
            farm.validate_oracle(missing)

    def test_package_contract_names_the_native_checks(self) -> None:
        self.assertEqual(package.PREVIEW_VERSIONS[19], '0.15.0-phase19')
        runner = (ROOT / farm.ASSETS / 'Runtime/Probes/FarmProbeRunner.cs').read_text(encoding='utf-8')
        checks = (ROOT / farm.ASSETS / 'Runtime/Model/FarmModelChecks.cs').read_text(encoding='utf-8')
        for name in package.FARM_DETAIL_CHECKS:
            self.assertIn('"' + name + '"', runner + checks, name)
        self.assertEqual(len(package.FARM_DETAIL_CHECKS), 20)

    def test_station_placeholders_are_gone(self) -> None:
        home = (ROOT / 'unity/Assets/BlueMapRoute/Runtime/Session/HomeRouteController.cs').read_text(encoding='utf-8')
        controller = (ROOT / farm.ROUTE_CONTROLLER).read_text(encoding='utf-8')
        self.assertNotIn('volgende migratiefase', home)
        self.assertNotIn('next migration phase', home)
        for hook in ('InteractGardenStation', 'FlushFarmTime', 'RefreshGardenWorld', 'WorkGarden'):
            self.assertIn(hook, controller)


if __name__ == '__main__':
    unittest.main()
