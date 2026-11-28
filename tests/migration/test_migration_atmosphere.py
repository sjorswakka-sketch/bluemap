"""Phase 21 guards: the hour, atlas, travel, achievements and settings stay bound to the preserved sources."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))

import build_migration_atmosphere as atmosphere  # noqa: E402
import verify_unity_package as package  # noqa: E402


class AtmosphereContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = atmosphere.check(ROOT)
        cls.session = {name: (ROOT / name).read_text(encoding='utf-8') for name in atmosphere.CONTROLLERS}

    def test_current_sources_match_the_contract(self) -> None:
        self.assertEqual(self.contract['phase'], 21)
        self.assertFalse(self.contract['personalSavesUsed'])
        self.assertFalse(self.contract['recordedOracle'])
        self.assertEqual(self.contract['coverage']['sources'], len(atmosphere.SOURCE_PATHS))

    def test_package_contract_names_the_native_checks(self) -> None:
        self.assertEqual(package.PREVIEW_VERSIONS[21], '0.17.0-phase21')
        self.assertEqual(set(self.contract['coverage']['nativeChecks']), package.ATMOSPHERE_DETAIL_CHECKS)
        self.assertEqual(len(package.ATMOSPHERE_DETAIL_CHECKS), 15)

    def test_the_colours_of_the_day_equal_the_source(self) -> None:
        atmosphere.validate_day_keys(ROOT)
        self.assertEqual(atmosphere.DAY_KEYS[0][1:], atmosphere.DAY_KEYS[-1][1:])  # midnight wraps without a jump
        self.assertEqual([row[0] for row in atmosphere.DAY_KEYS], sorted(row[0] for row in atmosphere.DAY_KEYS))

    def test_achievements_come_from_the_portable_catalog(self) -> None:
        document = json.loads(atmosphere.achievements_catalog(ROOT).decode('utf-8'))
        rows = document['achievements']
        self.assertEqual(len(rows), 40)
        self.assertFalse(document['personalSavesUsed'])
        self.assertEqual((ROOT / atmosphere.ACHIEVEMENTS_RESOURCE).read_bytes().replace(b'\r\n', b'\n'),
                         atmosphere.achievements_catalog(ROOT))
        po = (ROOT / 'translations/en.po').read_text(encoding='utf-8')
        known = set(re.findall(r'^msgid "((?:[^"\\]|\\.)*)"', po, re.M))
        for row in rows:
            self.assertEqual(set(row), {'id', 'name', 'desc', 'if', 'secret'})
            self.assertIn(row['name'].replace('"', '\\"'), known, row['id'])

    def test_the_atlas_has_the_nineteen_regions(self) -> None:
        panel = (ROOT / atmosphere.ASSETS / 'Runtime/UI/WorldMapPanel.cs').read_text(encoding='utf-8')
        source = (ROOT / 'scripts/core/world_atlas.gd').read_text(encoding='utf-8')
        for region in ('village', 'forest', 'ijsdal', 'dorstvallei', 'steampeak'):
            self.assertIn('"' + region + '"', panel, region)
            self.assertIn('"' + region + '"', source, region)
        self.assertEqual(self.contract['coverage']['regions'], 19)

    def test_keys_and_pause_rows_are_wired(self) -> None:
        route = (ROOT / atmosphere.SESSION / 'RouteWorldController.cs').read_text(encoding='utf-8')
        for action in ('frame.Pressed("map")', 'frame.Pressed("wereld_prestaties")', 'frame.Pressed("wereld_beestenboek")'):
            self.assertIn(action, route)
        world = self.session[atmosphere.SESSION + 'WorldMapRouteController.cs']
        for member in ('ToggleLanguage', 'ToggleMute', 'StepVolume', 'TravelBlockedReason', 'DiscoveredAltars'):
            self.assertIn(member, world)

    def test_a_changed_source_fails_closed(self) -> None:
        stored = json.loads((ROOT / atmosphere.CONTRACT).read_text(encoding='utf-8'))
        changed = copy.deepcopy(stored)
        changed['sources']['scripts/core/daynight.gd'] = '0' * 64
        self.assertNotEqual(changed, atmosphere.build_contract(ROOT))


if __name__ == '__main__':
    unittest.main()
