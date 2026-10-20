"""Guard the real source save observations and their exact native resource transfer."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from record_migration_saves import validate_float64_bits


class SaveSourceOracleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = (ROOT / 'migration/phase-09/save-oracle.json').read_bytes()
        cls.data = json.loads(cls.raw)

    def test_exact_source_engine_and_unchanged_original_files(self):
        self.assertEqual(self.data['schema'], 'bluemap.persistence.save.source-oracle.v1')
        self.assertEqual(self.data['engineVersion'], '4.4.1-stable (official)')
        self.assertIs(self.data['personalSavesUsed'], False)
        self.assertEqual(len(self.data['sourceHashes']), 11)
        for name, expected in self.data['sourceHashes'].items():
            self.assertEqual(hashlib.sha256((ROOT / name).read_bytes().replace(b'\r\n',b'\n')).hexdigest(), expected, name)

    def test_original_bytes_are_shipped_without_reformatting(self):
        path = ROOT / 'unity/Assets/BlueMapPersistence/Resources/BlueMapSaveOracle.json'
        self.assertEqual(path.read_bytes(), self.raw)
        self.assertTrue(Path(str(path)+'.meta').is_file())

    def test_every_current_save_field_is_observed_in_every_case(self):
        expected = {'version','map','pos','hp','coins','inventory','flags','quests','weapon','visited_maps',
                    'play_time','kills','meer','day_time','day_count','kills_by','rolls','potions_drunk','deaths',
                    'boss_deaths','talked','achievements','arena_records','homestead','coastal_storage','stockroom',
                    'personal_home','yard','professions','hero_xp','equipment','appearance','clothing','ng_plus'}
        self.assertEqual(len(expected),34)
        self.assertEqual(len(self.data['cases']),24)
        for case in self.data['cases']:
            self.assertEqual(set(case['expected']), expected, case['id'])
            self.assertIsInstance(json.loads(case['inputJson']),dict)
            self.assertIs(case['useLoadPosition'],True)

    def test_positive_negative_and_old_state_coverage(self):
        cases = {case['id']:case for case in self.data['cases']}
        self.assertEqual(len(cases),24)
        self.assertTrue({'empty_old_save','legacy_flags_presence','explicit_visits_no_inference',
                         'farms_and_production','house_valid_custom','house_invalid_overlap',
                         'house_invalid_identifier','yard_valid_paths','yard_all_stations_stored',
                         'yard_invalid_crop_overlap','gear_clothing_appearance','bounded_storage',
                         'profession_cooldowns','unknown_future_fields','raw_version_object',
                         'current_full_roundtrip','numeric_conversion','exact_day_boundary',
                         'json_integer_precision_positive','json_integer_precision_negative'} <= cases.keys())
        legacy=cases['legacy_flags_presence']['expected']
        self.assertIs(legacy['flags']['golem_ruins'],True)
        self.assertNotIn('ruins',legacy['visited_maps'])
        self.assertEqual(legacy['kills_by']['golem'],2)
        self.assertFalse(any(row['accepted'] for row in self.data['corrupt']))
        self.assertEqual(len(self.data['corrupt']),6)

    def test_exact_original_float64_encodings(self):
        self.assertEqual(self.data['float64Encoding'],'ieee754-binary64-little-endian-hex')
        self.assertGreater(validate_float64_bits(self.data),100)
        for invalid in ['','000000000000000','000000000000f07f','000000000000F03F']:
            changed=copy.deepcopy(self.data)
            changed['cases'][0]['expected']['day_time']['$f64']=invalid
            with self.subTest(invalid=invalid),self.assertRaises(ValueError):validate_float64_bits(changed)

    def test_authored_rules_are_available_without_original_runtime(self):
        rules=self.data['rules']
        self.assertEqual(len(rules['maps']),37)
        self.assertEqual(len(rules['yardRows']),44)
        self.assertEqual(len(rules['homePieces']),13)
        self.assertEqual(len(rules['crops']),8)
        self.assertEqual(len(rules['skills']),7)
        self.assertEqual(len(rules['gearSlots']),5)
        self.assertEqual(len(rules['clothingSlots']),5)
        self.assertGreater(len(rules['atlasEvidence']),50)
        self.assertGreater(len(rules['yardBaseReach']),200)
        self.assertGreater(len(rules['resourceLimits']),100)


if __name__ == '__main__':
    unittest.main()
