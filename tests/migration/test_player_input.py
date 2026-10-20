"""Lossless source input/deadzone contract and pinned package checks; native events run in Unity."""
import json
import math
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PlayerInputContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.oracle = json.loads((ROOT / 'migration/phase-08/input-oracle.json').read_text(encoding='utf-8-sig'))
        cls.actions = {row['id']: row for row in cls.oracle['defaults']}

    def test_exact_original_action_coverage(self):
        source = (ROOT / 'scripts/core/input_manager.gd').read_text(encoding='utf-8')
        block = source.split('const ACTION_NAMES := {', 1)[1].split('\n}', 1)[0]
        source_ids = set(re.findall(r'"([a-z_]+)"\s*:', block))
        self.assertEqual({key for key, value in self.actions.items() if value['rebindable']}, source_ids)
        self.assertEqual(len(source_ids), 22)
        self.assertEqual(len(self.actions), 36)
        self.assertEqual(sum(len(row['bindings']) for row in self.actions.values()), 86)

    def test_exact_defaults_are_available_as_unity_resource(self):
        original = ROOT / 'migration/phase-08/input-oracle.json'
        resource = ROOT / 'unity/Assets/BlueMapPlayer/Runtime/Input/Resources/BlueMapPlayerInputOracle.json'
        self.assertEqual(original.read_bytes(), resource.read_bytes())

    def test_original_sprint_and_roll_keys_are_not_silently_swapped(self):
        sprint = self.actions['sprint']['bindings']
        roll = self.actions['dodge']['bindings']
        self.assertEqual([(r['code'], r['keyName']) for r in sprint if r['kind'] == 'key'], [(4194326, 'Ctrl')])
        self.assertEqual([(r['code'], r['keyName']) for r in roll if r['kind'] == 'key'], [(4194325, 'Shift'), (75, 'K')])
        self.assertEqual([r['code'] for r in sprint if r['kind'] == 'button'], [7])
        self.assertEqual([r['code'] for r in roll if r['kind'] == 'button'], [1])

    def test_source_axis_numbering_and_mouse_combat_are_preserved(self):
        for name, code, direction in [('aim_left', 2, -1), ('aim_right', 2, 1), ('aim_up', 3, -1), ('aim_down', 3, 1)]:
            row, = self.actions[name]['bindings']
            self.assertEqual((row['kind'], row['category'], row['code'], row['direction']), ('axis', 'controller', code, direction))
        self.assertIn(('mouse', 1), [(r['kind'], r['code']) for r in self.actions['attack']['bindings']])
        self.assertIn(('mouse', 2), [(r['kind'], r['code']) for r in self.actions['bow']['bindings']])
        self.assertEqual(self.actions['homestead']['bindings'][0]['keyName'], 'U')
        self.assertFalse(any(r['category'] == 'controller' for r in self.actions['homestead']['bindings']))

    def test_original_threshold_constants(self):
        source = (ROOT / 'scripts/core/input_manager.gd').read_text(encoding='utf-8')
        for oracle_key, constant in [('switchDeadzone', 'SWITCH_DEADZONE'), ('aimDeadzone', 'AIM_DEADZONE')]:
            value = float(re.search(r'const ' + constant + r'\s*:=\s*([\d.]+)', source).group(1))
            self.assertEqual(self.oracle[oracle_key], value)
        self.assertEqual(self.oracle['mouseSwitchPixels'], 3)
        self.assertIn('_mouse_distance(event) >= 3.0', source)

    def test_real_engine_vectors_match_circular_deadzone_contract(self):
        self.assertEqual(len(self.oracle['vectors']), 16)
        for case in self.oracle['vectors']:
            x, y = case['raw']; deadzone = case['deadzone']; length = math.hypot(x, y)
            if length <= deadzone:
                expected = [0, 0]
            elif length > 1:
                expected = [x / length, y / length]
            else:
                scale = (length - deadzone) / (1 - deadzone) / length
                expected = [x * scale, y * scale]
            for original, computed in zip(case['expected'], expected):
                # Godot Vector2 is Float32; this bound is below one micro-pixel/unit.
                self.assertAlmostEqual(original, computed, delta=0.00000012)

    def test_all_source_binding_kinds_and_modifiers_remain_explicit(self):
        kinds = set()
        for action in self.actions.values():
            self.assertGreater(action['deadzone'], 0)
            self.assertLess(action['deadzone'], 1)
            for row in action['bindings']:
                kinds.add(row['kind'])
                self.assertIn(row['direction'], [-1, 1])
                self.assertEqual(row['category'], 'controller' if row['kind'] in ['axis', 'button'] else 'keyboard')
                for name in ['shift', 'ctrl', 'alt', 'meta']:
                    self.assertIs(type(row[name]), bool)
        self.assertEqual(kinds, {'key', 'mouse', 'axis', 'button'})
        self.assertTrue(self.actions['ui_focus_prev']['bindings'][0]['shift'])

    def test_released_engine_and_no_personal_saves(self):
        self.assertEqual(self.oracle['schema'], 'bluemap.player-input.v1')
        self.assertEqual(self.oracle['engineVersion'], '4.4.1-stable (official)')
        self.assertIs(self.oracle['personalSavesUsed'], False)

    def test_input_package_exactly_pinned_and_transitives_locked(self):
        manifest = json.loads((ROOT / 'unity/Packages/manifest.json').read_text(encoding='utf-8'))
        lock = json.loads((ROOT / 'unity/Packages/packages-lock.json').read_text(encoding='utf-8'))['dependencies']
        self.assertEqual(manifest['dependencies']['com.unity.inputsystem'], '1.20.1')
        package = lock['com.unity.inputsystem']
        self.assertEqual(package, {'version': '1.20.1', 'depth': 0, 'source': 'registry',
                                  'dependencies': {'com.unity.modules.uielements': '1.0.0'}, 'url': 'https://packages.unity.com'})
        for dependency in package['dependencies']:
            self.assertIn(dependency, lock)
            for transitive in lock[dependency]['dependencies']:
                self.assertIn(transitive, lock)


if __name__ == '__main__':
    unittest.main()
