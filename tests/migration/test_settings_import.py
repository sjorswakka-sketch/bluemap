"""Frozen original-engine ConfigFile expectations; native C# checks execute the safe parser and real input package."""
import base64
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_CASES = {'missing', 'full_defaults', 'legacy_conflicts', 'physical_and_modifiers', 'explicit_empty',
                  'invalid_arrays', 'oversized_and_duplicate', 'unknown_multiline', 'malformed', 'unsupported_locale'}


class SettingsImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.oracle = json.loads((ROOT / 'migration/phase-09/settings-oracle.json').read_text(encoding='utf-8'))
        cls.cases = {row['id']: row for row in cls.oracle['cases']}

    def test_exact_original_engine_and_artificial_fixture_contract(self):
        self.assertEqual(self.oracle['schema'], 'bluemap.settings-import.v1')
        self.assertEqual(self.oracle['engineVersion'], '4.4.1-stable (official)')
        self.assertIs(self.oracle['personalSavesUsed'], False)
        self.assertEqual(set(self.cases), EXPECTED_CASES)
        self.assertEqual(len(self.oracle['cases']), 10)
        for row in self.cases.values():
            self.assertEqual(set(row['documents']), {'settings', 'controls', 'meta', 'ng'})
            self.assertEqual(set(row['parseOk']), {'settings', 'controls', 'meta', 'ng'})
            for source in row['documents'].values():
                if source is not None:
                    base64.b64decode(source, validate=True).decode('utf-8')

    def test_oracle_identical_to_runtime_resource(self):
        self.assertEqual((ROOT / 'migration/phase-09/settings-oracle.json').read_bytes(),
                         (ROOT / 'unity/Assets/BlueMapPersistence/Runtime/Settings/Resources/BlueMapPersistenceSettingsOracle.json').read_bytes())

    def test_all_original_rebindable_actions_retained_per_case(self):
        source = json.loads((ROOT / 'migration/phase-08/input-oracle.json').read_text())
        expected = {row['id'] for row in source['defaults'] if row['rebindable']}
        for row in self.cases.values():
            self.assertEqual({action['id'] for action in row['bindings']}, expected)
            self.assertEqual(len(row['bindings']), 22)

    def bindings(self, case, action, category):
        rows = next(row['bindings'] for row in self.cases[case]['bindings'] if row['id'] == action)
        return [row for row in rows if row['category'] == category]

    def test_old_shortcuts_find_free_choices_without_rewriting_old_scheme(self):
        self.assertEqual([r['keyName'] for r in self.bindings('legacy_conflicts', 'attack', 'keyboard')], ['V'])
        self.assertEqual([r['keyName'] for r in self.bindings('legacy_conflicts', 'bow', 'keyboard')], ['U'])
        self.assertEqual([r['keyName'] for r in self.bindings('legacy_conflicts', 'technique', 'keyboard')], ['G'])
        self.assertEqual([r['keyName'] for r in self.bindings('legacy_conflicts', 'homestead', 'keyboard')], ['O'])
        # LT, RT and R3 already belong to other source actions: migration deliberately leaves the modifier empty.
        self.assertEqual(self.bindings('legacy_conflicts', 'technique', 'controller'), [])

    def test_physical_fallback_and_modifiers_are_preserved(self):
        attack, = self.bindings('physical_and_modifiers', 'attack', 'keyboard')
        bow, = self.bindings('physical_and_modifiers', 'bow', 'keyboard')
        self.assertEqual((attack['code'], attack['keyName'], attack['ctrl'], attack['shift']), (81, 'Q', True, True))
        self.assertEqual((bow['code'], bow['keyName'], bow['alt'], bow['meta']), (4194339, 'F8', True, True))
        raw = base64.b64decode(self.cases['physical_and_modifiers']['documents']['controls']).decode()
        self.assertIn('"keycode":81,"physical_keycode":0', raw)
        self.assertIn('Object(InputEventKey', raw)

    def test_deliberate_empty_and_duplicate_bindings_stay_intact(self):
        for action, category in [('attack', 'keyboard'), ('sprint', 'controller'), ('homestead', 'keyboard'), ('technique', 'controller')]:
            self.assertEqual(self.bindings('explicit_empty', action, category), [])
        duplicate = self.bindings('oversized_and_duplicate', 'bow', 'keyboard')
        self.assertEqual(len(duplicate), 2)
        self.assertEqual(duplicate[0], duplicate[1])
        self.assertNotEqual([r['keyName'] for r in self.bindings('oversized_and_duplicate', 'attack', 'keyboard')], ['Z'] * 9)

    def test_unknown_multiline_bytes_include_comments_crlf_unicode_and_constructor(self):
        raw = base64.b64decode(self.cases['unknown_multiline']['documents']['settings'])
        self.assertIn(b'; preserve this exact comment\r\n', raw)
        self.assertIn('🌱'.encode(), raw)
        self.assertIn(b'"kind": "literal"', raw)
        self.assertIn(b'Vector2(1.5, -2)', raw)
        self.assertTrue(all(self.cases['unknown_multiline']['parseOk'].values()))

    def test_malformed_files_are_original_failures_with_safe_defaults(self):
        self.assertTrue(all(not valid for valid in self.cases['malformed']['parseOk'].values()))
        self.assertEqual(self.cases['malformed']['locale'], 'nl')
        self.assertEqual(self.cases['malformed']['bindings'], self.cases['missing']['bindings'])
        self.assertEqual(self.cases['malformed']['ng'], self.cases['missing']['ng'])

    def test_achievements_use_presence_and_ng_uses_source_normalization(self):
        self.assertEqual(set(self.cases['full_defaults']['achievements']), {'explorer', 'first'})
        self.assertIn(b'explorer=false', base64.b64decode(self.cases['full_defaults']['documents']['meta']))
        self.assertEqual(self.cases['full_defaults']['ng']['hero_xp'], 2250)
        self.assertEqual(self.cases['unknown_multiline']['ng']['weapon'], 'wood')
        self.assertEqual(self.cases['unknown_multiline']['ng']['hero_xp'], 0)

    def test_language_and_audio_values_survive_supported_locale_aliases(self):
        for case in ['full_defaults', 'physical_and_modifiers', 'unknown_multiline']:
            self.assertEqual(self.cases[case]['locale'], 'en')
        self.assertEqual(self.cases['unsupported_locale']['locale'], 'nl')
        self.assertEqual(self.cases['full_defaults']['music'], .35)
        self.assertEqual(self.cases['full_defaults']['sfx'], .7)
        self.assertIs(self.cases['full_defaults']['muted'], True)

    def test_recorder_preserves_strict_isolation_and_source_fingerprint(self):
        recorder = (ROOT / 'tools/record_migration_settings.py').read_text()
        exporter = (ROOT / 'tools/migration_settings_export.gd').read_text()
        for anchor in ['uuid.uuid4()', 'Exact UUID isolation', 'fingerprint(ROOT) != before', 'for number in (1, 2)', "BLUEMAP_LANG='nl'", 'Never overwrite an existing oracle']:
            self.assertIn(anchor, recorder)
        for anchor in ['controls._load_bindings()', 'gs._load_meta()', 'gs.load_meta()', 'startup_locale()', 'scripts/core/sound.gd', 'Bluemap-Codex-Tests-']:
            self.assertIn(anchor, exporter)


if __name__ == '__main__':
    unittest.main()
