"""Mutation tests for original progression rules, exact catalogs and durable proof binding."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import build_migration_progression as progression


def exact(value):
    if type(value) is float:
        return {'$f64': struct.pack('<d', value).hex()}
    if isinstance(value, dict):
        return {key: exact(child) for key, child in value.items()}
    if isinstance(value, list):
        return [exact(child) for child in value]
    return value


def ordered(value):
    if type(value) is float:
        return exact(value)
    if isinstance(value, dict):
        return {'$dict': [[key, ordered(child)] for key, child in value.items()]}
    if isinstance(value, list):
        return [ordered(child) for child in value]
    return value


def decimal_mirror(value):
    if type(value) is float:
        return float(format(value, '.15g'))
    if isinstance(value, dict):
        return {key: decimal_mirror(child) for key, child in value.items()}
    if isinstance(value, list):
        return [decimal_mirror(child) for child in value]
    return value


class ProgressionSourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix='BlueMap-Progression-Data-Tests-')
        cls.addClassCleanup(temporary.cleanup)
        cls.root = Path(temporary.name)
        original = json.loads((ROOT / progression.CONTRACT).read_bytes())
        names = {progression.ORACLE, progression.ASSETS + '.meta', *progression.RECORDERS,
                 *(row['path'] for row in original['sourceAnchors']),
                 *(row['path'] for row in original['frozenReferenceFiles'])}
        for name in names:
            target = cls.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / name).read_bytes())
        shutil.copytree(ROOT / progression.ASSETS, cls.root / progression.ASSETS)
        cls.reference = progression.original_references(cls.root)
        cls.contract = progression.build_contract(cls.root)
        (cls.root / progression.CONTRACT).write_bytes(progression.canonical(cls.contract))

    def replace(self, name, raw):
        target = self.root / name
        previous = target.read_bytes()
        self.addCleanup(target.write_bytes, previous)
        target.write_bytes(raw)

    def oracle(self):
        return json.loads((self.root / progression.ORACLE).read_bytes())

    def coverage(self, value):
        return progression.oracle_coverage(value, self.reference, self.root)

    def change_catalog(self, edit):
        value = self.oracle()
        catalogs = progression.decode_ordered_input(value['catalogsOrdered'])
        edit(catalogs)
        value['catalogs'], value['catalogsExact'], value['catalogsOrdered'] = decimal_mirror(catalogs), exact(catalogs), ordered(catalogs)
        return value

    def test_gitless_contract_preserves_sources_and_starts_neither_engine(self):
        before = {path.relative_to(self.root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                  for path in self.root.rglob('*') if path.is_file()}
        contract = progression.check(self.root)
        self.assertEqual(contract, self.contract)
        coverage = contract['oracle']['coverage']
        self.assertEqual((coverage['cases'], coverage['gear'], coverage['clothing'], coverage['hairStyles']), (442, 24, 24, 90))
        self.assertEqual((coverage['gearSlots'], coverage['clothingSlots'], coverage['weapons']), (5, 5, 4))
        self.assertEqual((coverage['gearUpgradeRecipes'], coverage['weaponUpgradeRoutes']), (3, 3))
        self.assertEqual(coverage['exactFloat64Values'], 6580)
        self.assertFalse(contract['enginesStarted'])
        self.assertFalse(contract['personalSavesUsed'])
        self.assertEqual(before, {path.relative_to(self.root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                                  for path in self.root.rglob('*') if path.is_file()})

    def test_original_progression_equipment_layers_and_greta_sources_cannot_be_refrozen(self):
        for name in ('scripts/core/progression.gd', 'scripts/core/character_layers.gd', 'scripts/data/dialogue.gd'):
            with self.subTest(source=name):
                previous = (self.root / name).read_bytes()
                (self.root / name).write_bytes(previous + b'\n# unintended change\n')
                try:
                    with self.assertRaisesRegex(progression.ProgressionDataError, 'Preserved progression source changed'):
                        progression.build_contract(self.root)
                finally:
                    (self.root / name).write_bytes(previous)

    def test_catalog_bindings_reject_coherent_false_gear_clothes_and_palette_mirrors(self):
        edits = {
            'gear-id': lambda c: c['gear'].pop('gear_bronze_helm'),
            'gear-bonus': lambda c: c['gear']['gear_bronze_helm']['bonuses'].update(stamina_max=31.0),
            'cosmetic-bonus': lambda c: c['clothing'][next(iter(c['clothing']))].update(bonuses={'armor': 10.0}),
            'hair': lambda c: c['hairM'].pop('m_kort'),
            'color': lambda c: c['hairColors'][0]['color'].__setitem__(0, 0.5),
            'weapon': lambda c: c['weapons']['wood'].update(damage=99),
            'upgrade-cost': lambda c: c['weaponUpgrades']['iron'].update(coins=0),
            'recipe': lambda c: c['upgradeRecipes'].pop('pg_pack_plus'),
        }
        for label, edit in edits.items():
            with self.subTest(change=label), self.assertRaisesRegex(progression.ProgressionDataError, 'catalog values'):
                self.coverage(self.change_catalog(edit))

    def test_source_orders_cannot_be_replaced_by_consistent_sorted_catalogs(self):
        value = self.change_catalog(lambda c: c.update(gearSlots=dict(sorted(c['gearSlots'].items()))))
        value['orders']['gearSlots'] = list(sorted(value['orders']['gearSlots']))
        with self.assertRaisesRegex(progression.ProgressionDataError, 'dictionary order'):
            self.coverage(value)

    def test_gear_bonus_order_is_bound_to_actual_source_declarations(self):
        key = 'gear_bastion_coat'
        value = self.change_catalog(lambda c: c['gear'][key].update(bonuses=dict(reversed(list(c['gear'][key]['bonuses'].items())))))
        value['bonusOrders'][key].reverse()
        with self.assertRaisesRegex(progression.ProgressionDataError, 'dictionary order'):
            self.coverage(value)

    def test_missing_duplicate_or_invented_behavior_cases_are_rejected(self):
        names = ('hero-multilevel-cap-repeat', 'gear-capacity-no-refill', 'appearance-preserve-extensions',
                 'upgrade-local-home-pg_pack_plus', 'weapon-conditions-crystal-shard')
        for name in names:
            value = self.oracle()
            value['cases'] = [row for row in value['cases'] if row['id'] != name]
            with self.subTest(case=name), self.assertRaisesRegex(progression.ProgressionDataError, 'case families'):
                self.coverage(value)
        for duplicate in (True, False):
            value = self.oracle()
            if duplicate:
                value['cases'].append(copy.deepcopy(value['cases'][0]))
            else:
                value['cases'][0]['id'] = 'invented_case'
            with self.assertRaisesRegex(progression.ProgressionDataError, 'case families'):
                self.coverage(value)

    def test_exact_float_bits_and_lossless_ordered_input_are_mandatory(self):
        for kind in ('infinity', 'catalog-order-missing', 'duplicate-key', 'case-order-missing'):
            value = self.oracle()
            if kind == 'infinity':
                value['cases'][0]['initialExact']['day_time'] = {'$f64': '000000000000f07f'}
            elif kind == 'catalog-order-missing':
                value.pop('catalogsOrdered')
            elif kind == 'duplicate-key':
                value['catalogsOrdered']['$dict'].append(copy.deepcopy(value['catalogsOrdered']['$dict'][0]))
            else:
                value['cases'][0].pop('initialOrdered')
            with self.subTest(change=kind), self.assertRaises(progression.ProgressionDataError):
                self.coverage(value)

    def test_all34_save_fields_and_results_are_preserved(self):
        for kind in ('new-game', 'initial', 'result'):
            value = self.oracle()
            if kind == 'new-game':
                value['newGame'].pop('coastal_storage')
            elif kind == 'initial':
                value['cases'][0]['initial'].pop('hero_xp')
            else:
                value['cases'][0]['results'].pop()
            with self.subTest(change=kind), self.assertRaises(progression.ProgressionDataError):
                self.coverage(value)

    def test_original_new_game_defaults_are_independently_retained(self):
        value = self.oracle()
        value['newGame']['coins'] += 1
        with self.assertRaisesRegex(progression.ProgressionDataError, 'new-game defaults'):
            self.coverage(value)

    def test_native_oracle_must_match_original_observations_byte_for_byte(self):
        self.replace(progression.RESOURCE, (self.root / progression.RESOURCE).read_bytes() + b'\n')
        with self.assertRaisesRegex(progression.ProgressionDataError, 'Native progression oracle differs'):
            progression.build_contract(self.root)

    def test_changed_matching_observations_still_require_review(self):
        value = self.oracle()
        value['cases'][0]['expected']['coins'] += 1
        value['cases'][0]['expectedExact']['coins'] += 1
        for name in (progression.ORACLE, progression.RESOURCE):
            self.replace(name, progression.canonical(value))
        with self.assertRaisesRegex(progression.ProgressionDataError, 'Stale/corrupt progression'):
            progression.check(self.root)

    def test_recorder_changes_require_explicit_contract_review(self):
        name = 'tools/record_migration_progression.py'
        self.replace(name, (self.root / name).read_bytes() + b'\n# comparison change\n')
        with self.assertRaisesRegex(progression.ProgressionDataError, 'Stale/corrupt progression'):
            progression.check(self.root)

    def test_previous_original_world_and_catalog_references_cannot_be_refrozen(self):
        for name in ('migration/world/index.json', 'migration/portable/catalogs/gear.json'):
            previous = (self.root / name).read_bytes()
            (self.root / name).write_bytes(previous + b'\n')
            try:
                with self.subTest(source=name), self.assertRaisesRegex(progression.ProgressionDataError, 'reference changed|catalog changed'):
                    progression.build_contract(self.root)
            finally:
                (self.root / name).write_bytes(previous)

    def test_asset_guids_must_be_unique_and_match_existing_owners(self):
        rows = [row for row in self.contract['assetGuids'] if row['path'].endswith('.cs')]
        self.assertGreaterEqual(len(rows), 2)
        self.replace(rows[1]['path'] + '.meta', (self.root / (rows[0]['path'] + '.meta')).read_bytes())
        with self.assertRaisesRegex(progression.ProgressionDataError, 'duplicate progression asset GUID'):
            progression.check(self.root)

    def test_privacy_encoding_and_original_method_coverage_are_required(self):
        for kind in ('personal', 'encoding', 'method', 'foreign-method'):
            value = self.oracle()
            if kind == 'personal': value['personalSavesUsed'] = True
            elif kind == 'encoding': value['float64Encoding'] = 'approximate'
            elif kind == 'method': value['sourceMethods'].pop()
            else: value['sourceMethods'].append('scripts/core/appearance.gd::invented')
            with self.subTest(change=kind), self.assertRaises(progression.ProgressionDataError):
                self.coverage(value)


if __name__ == '__main__':
    unittest.main()
