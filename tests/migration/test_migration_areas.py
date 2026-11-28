"""Phase 20 guards: the special areas stay bound to the preserved sources and their native checks."""
from __future__ import annotations

from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))

import build_migration_areas as areas  # noqa: E402
import verify_unity_package as package  # noqa: E402


class AreasContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = areas.check(ROOT)
        cls.session = {name: (ROOT / name).read_text(encoding='utf-8') for name in areas.CONTROLLERS}

    def test_current_sources_match_the_contract(self) -> None:
        self.assertEqual(self.contract['phase'], 20)
        self.assertFalse(self.contract['personalSavesUsed'])
        self.assertFalse(self.contract['recordedOracle'])
        self.assertEqual(self.contract['coverage']['sources'], len(areas.SOURCE_PATHS))

    def test_package_contract_names_the_native_checks(self) -> None:
        self.assertEqual(package.PREVIEW_VERSIONS[20], '0.16.0-phase20')
        self.assertEqual(set(self.contract['coverage']['nativeChecks']), package.AREAS_DETAIL_CHECKS)
        self.assertEqual(len(package.AREAS_DETAIL_CHECKS), 19)

    def test_every_conversation_action_has_an_owner(self) -> None:
        story = (ROOT / areas.SESSION / 'StoryRouteController.cs').read_text(encoding='utf-8')
        handled = ''.join(self.session.values())
        for action in areas.EXTERNAL_ACTIONS:
            self.assertRegex(handled, r'(case |==)"' + action + '"', action)
        # The fallback notice remains for unknown future actions only, after every owner had its turn.
        fallback = story.index('Deze activiteit wordt aangesloten')
        for handler in ('HandleAreaExternal', 'HandleArenaExternal', 'HandleServiceExternal'):
            self.assertLess(story.index(handler + '('), fallback, handler)

    def test_original_rules_are_kept(self) -> None:
        arena = self.session[areas.SESSION + 'ArenaRouteController.cs']
        for constant in ('ArenaIntro=3.2', 'ArenaRest=3.0', 'ArenaFirstSpawn=1.0', 'ArenaSpawnGap=.45', 'ArenaWarn=.7', 'ArenaEmerge=.4', 'ArenaDefeatTime=1.8'):
            self.assertIn(constant, arena)
        objects = self.session[areas.SESSION + 'AreasRouteController.cs']
        # Hot spring: fifteen quiet seconds, no hostile creature within 200 px; heat: six seconds per sip.
        for rule in ('HotSpringRest<15', '<200', 'RegionHeat>=6', 'RegionExposure>=0.65', 'work.Elapsed<20', 'AddCoins(120)'):
            self.assertIn(rule, objects)
        bow = self.session[areas.SESSION + 'BowRouteController.cs']
        for rule in ('rangeReady=3', 'rangeEnd=2.5', 'HitAge>1.6'):
            self.assertIn(rule, bow)

    def test_no_dutch_text_without_translation(self) -> None:
        po = (ROOT / 'translations/en.po').read_text(encoding='utf-8')
        known = set(re.findall(r'^msgid(?:_plural)? "((?:[^"\\]|\\.)*)"', po, re.M))
        for name, text in self.session.items():
            text = re.sub(r'T\("(?:[^"\\]|\\.)*","(?:[^"\\]|\\.)*"\)', '', text)
            text = re.sub(r'///.*', '', text)
            for literal in re.findall(r'"((?:[^"\\]|\\.)*)"', text):
                if len(literal) >= 9 and re.search(r'[a-zé] [a-zé]', literal):
                    self.assertIn(literal, known, name)

    def test_a_changed_source_fails_closed(self) -> None:
        import copy
        import json
        stored = json.loads((ROOT / areas.CONTRACT).read_text(encoding='utf-8'))
        changed = copy.deepcopy(stored)
        changed['sources']['scripts/entities/arena_master.gd'] = '0' * 64
        self.assertNotEqual(changed, areas.build_contract(ROOT))


if __name__ == '__main__':
    unittest.main()
