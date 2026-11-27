"""Phase 18 guards: the house and yard designers stay bound to the recorded Godot source."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))

import build_migration_home as home  # noqa: E402
import verify_unity_package as package  # noqa: E402


class HomeContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.oracle = json.loads((ROOT / home.ORACLE).read_bytes().decode('utf-8'))
        cls.contract = home.check(ROOT)
        cls.cases = {case['id']: case for case in cls.oracle['cases']}

    def test_current_sources_match_the_recorded_contract(self) -> None:
        coverage = self.contract['coverage']
        self.assertEqual(self.contract['phase'], 18)
        self.assertEqual((coverage['cases'], coverage['furniture'], coverage['yardPieces'], coverage['workStations']), (249, 13, 7, 4))
        self.assertGreater(coverage['operations'], 25000)
        self.assertFalse(self.contract['personalSavesUsed'])

    def test_every_room_cell_is_tried_for_every_piece(self) -> None:
        for piece in self.oracle['catalogs']['house']['pieces']:
            operations = self.cases['house-place-' + piece]['operations']
            cells = {tuple(operation[4]) for operation in operations}
            self.assertEqual(len(cells), 144, piece)
            self.assertTrue({(x, y) for x in range(2, 12) for y in range(2, 12)} <= cells)

    def test_placement_sweeps_reach_every_kind_of_refusal(self) -> None:
        house = {result for name, case in self.cases.items() if name.startswith(('house-place', 'house-crowded', 'house-layout'))
                 for result in case['results'] if isinstance(result, str)}
        yard = {result for name, case in self.cases.items() if name.startswith(('yard-place', 'yard-station', 'yard-piece', 'yard-layout'))
                for result in case['results'] if isinstance(result, str)}
        self.assertIn('', house)
        self.assertIn('', yard)
        self.assertGreaterEqual(len(house), 12)
        self.assertGreaterEqual(len(yard), 9)

    def test_a_refused_design_is_never_saved(self) -> None:
        for name in ('house-apply-too-close', 'house-apply-away', 'house-apply-unowned', 'yard-apply-too-close', 'yard-apply-away'):
            case = self.cases[name]
            self.assertIs(case['results'][0], False, name)
        self.assertEqual(self.cases['house-apply-away']['initial']['personal_home'], self.cases['house-apply-away']['expected']['personal_home'])
        self.assertEqual(self.cases['yard-apply-away']['initial']['yard'], self.cases['yard-apply-away']['expected']['yard'])
        self.assertIs(self.cases['house-apply-valid']['results'][0], True)
        self.assertIs(self.cases['yard-apply-valid']['results'][0], True)

    def test_named_fixtures_resolve_and_stay_small(self) -> None:
        fixtures = self.oracle['fixtures']
        self.assertEqual(set(fixtures), {'@base', '@all', '@crowded', '@placed', '@yard', '@both', '@farm', '@gated'})
        used = {argument for case in self.oracle['cases'] for operation in case['operations'] for argument in operation
                if isinstance(argument, str) and argument.startswith('@')}
        self.assertEqual(used, set(fixtures))

    def test_runtime_catalog_is_small_and_derived(self) -> None:
        derived = home.runtime_catalog(self.oracle)
        self.assertEqual((ROOT / home.CATALOG_RESOURCE).read_bytes().replace(b'\r\n', b'\n'), derived)
        self.assertLess(len(derived), 100_000)
        self.assertNotIn(b'"cases"', derived)

    def test_lost_family_or_changed_identity_fails_closed(self) -> None:
        dropped = copy.deepcopy(self.oracle)
        dropped['cases'] = [case for case in dropped['cases'] if not case['id'].startswith('yard-apply')]
        with self.assertRaises(home.HomeDataError):
            home.validate_oracle(dropped)
        personal = copy.deepcopy(self.oracle)
        personal['personalSavesUsed'] = True
        with self.assertRaises(home.HomeDataError):
            home.validate_oracle(personal)
        missing = copy.deepcopy(self.oracle)
        missing['cases'] = [case for case in missing['cases'] if case['id'] != 'house-place-lamp']
        with self.assertRaises(home.HomeDataError):
            home.validate_oracle(missing)

    def test_package_contract_names_the_native_checks(self) -> None:
        self.assertEqual(package.PREVIEW_VERSIONS[18], '0.14.0-phase18')
        runner = (ROOT / home.ASSETS / 'Runtime/Probes/HomeProbeRunner.cs').read_text(encoding='utf-8')
        checks = (ROOT / home.ASSETS / 'Runtime/Model/HomeModelChecks.cs').read_text(encoding='utf-8')
        for name in package.HOME_DETAIL_CHECKS:
            self.assertIn('"' + name + '"', runner + checks, name)

    def test_every_phase_pin_names_the_same_phase(self) -> None:
        probe = (ROOT / 'unity/Assets/BlueMapProbe/Runtime/Phase2Probe.cs').read_text(encoding='utf-8')
        hud = (ROOT / 'unity/Assets/BlueMapRoute/Runtime/UI/RouteHUD.cs').read_text(encoding='utf-8')
        builder = (ROOT / 'tools/build_unity_probe.py').read_text(encoding='utf-8')
        phase = max(package.PREVIEW_VERSIONS)
        version = package.PREVIEW_VERSIONS[phase]
        self.assertIn('phase != %d)' % phase, probe)
        self.assertIn('previewVersion != "%s"' % version, probe)
        self.assertIn('fase %d"' % phase, hud)
        self.assertIn('PREVIEW_VERSION = "%s"\nPHASE = %d' % (version, phase), builder.replace('\r\n', '\n'))

    def test_station_placeholder_is_gone(self) -> None:
        controller = (ROOT / 'unity/Assets/BlueMapRoute/Runtime/Session/RouteWorldController.cs').read_text(encoding='utf-8')
        self.assertNotIn('Uitbreiden volgt later in het migratieplan', controller)
        self.assertIn('InteractHomeStation', controller)


if __name__ == '__main__':
    unittest.main()
