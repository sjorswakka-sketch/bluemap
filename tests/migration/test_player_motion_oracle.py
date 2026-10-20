"""Guard original engine observations, exact numeric bytes and the Unity resource transfer."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from record_migration_player_motion import validate_float64_bits


class PlayerMotionOracleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = ROOT / 'migration/phase-08/motion-oracle.json'
        cls.raw = cls.path.read_bytes()
        cls.data = json.loads(cls.raw)

    def test_original_engine_and_isolation_contract(self):
        self.assertEqual(self.data['schema'], 'bluemap.player.motion.source-oracle.v1')
        self.assertEqual(self.data['engineVersion'], '4.4.1-stable (official)')
        self.assertIs(self.data['personalSavesUsed'], False)
        self.assertEqual(len(self.data['sourceHashes']), 5)
        for name, expected in self.data['sourceHashes'].items():
            self.assertEqual(hashlib.sha256((ROOT / name).read_bytes().replace(b'\r\n',b'\n')).hexdigest(), expected, name)

    def test_exact_original_byte_resource_copy(self):
        target = ROOT / 'unity/Assets/BlueMapPlayer/Resources/BlueMapPlayerMotionOracle.json'
        self.assertEqual(target.read_bytes(), self.raw)
        self.assertTrue(Path(str(target) + '.meta').is_file())

    def test_all_numeric_expectations_are_original_bytes(self):
        self.assertGreater(validate_float64_bits(self.data), 1000)
        self.assertEqual(self.data['float64Encoding'], 'ieee754-binary64-little-endian-hex')
        self.assertEqual(self.data['vectorEncoding'], 'ieee754-binary32-xy-little-endian-hex')

    def test_invalid_source_double_encodings_are_rejected(self):
        for malformed in ['', '000000000000000', '00000000000000000', '000000000000F03F',
                          '000000000000f07f', '000000000000f87f', 'not-an-encoding!']:
            with self.subTest(malformed=malformed):
                changed = copy.deepcopy(self.data)
                changed['stamina'][0]['before']['stamina'] = malformed
                with self.assertRaises(ValueError): validate_float64_bits(changed)

    def test_invalid_vector_encodings_are_rejected(self):
        for malformed in ['0000807f00000000', '0000c07f00000000', '0000803F00000000', '0000803f']:
            with self.subTest(malformed=malformed):
                changed = copy.deepcopy(self.data)
                changed['motions'][0]['direction'] = malformed
                with self.assertRaises(ValueError): validate_float64_bits(changed)

    def test_full_case_coverage_is_explicit(self):
        self.assertEqual({key:len(self.data[key]) for key in ('stamina','surfaces','equipment','motions','rolls')},
                         {'stamina':26,'surfaces':83,'equipment':8,'motions':15,'rolls':4})
        self.assertEqual(len({case['id'] for case in self.data['stamina']}), 26)
        self.assertEqual(len({case['tile'] for case in self.data['surfaces']}), 83)
        self.assertEqual(len({case['id'] for case in self.data['motions']}), 15)

    def test_terrain_and_equipment_cases_include_existing_special_surfaces(self):
        surfaces = {case['tile']:case for case in self.data['surfaces']}
        self.assertTrue({'yard_boards','bridge','mud','ce_boardwalk','ce_shore','snow_tufts','meer_reeds','unknown_future',''} <= surfaces.keys())
        self.assertEqual(surfaces['yard_boards']['footstep'], 'wood')
        self.assertEqual(surfaces['meer_reeds']['footstep'], '')
        self.assertEqual(surfaces['reed']['footstep'], 'grass')
        equipment = {row['id'] for row in self.data['equipment']}
        self.assertTrue({'scout_climber_speed_cap','heavy_armor_penalty','capacity_cap','regen_cap',
                         'unowned_equipment_no_bonus','owned_not_equipped_no_bonus'} <= equipment)

    def test_motion_source_oracle_retains_collision_distance_as_an_input(self):
        # Box2D receives the actual source result; the portable model never pretends a cast hit is known in advance.
        for row in self.data['motions']:
            self.assertGreaterEqual(struct.unpack('<d',bytes.fromhex(row['distance']))[0], 0)
        self.assertIn('Actual measured distance',self.data['physicsAdapter'])
        self.assertEqual(self.data['excludedPresentationMethods'],
                         ['ground_tile (explicit fixture)','_update_aim','_update_target','_update_shake'])


if __name__ == '__main__': unittest.main()
