"""Resident source contracts reject missing transients, reordered signals and false provenance."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import build_migration_residents as residents
import record_migration_resident_motion as motion
import record_migration_resident_social as social


class ResidentCatalogContractTests(unittest.TestCase):
    def setUp(self):
        self.ordered = {'$dict': [['roles', {'$dict': [['gardener', {'$dict': [['frame', 1]]}]]}]]}
        self.digest = 'a' * 64
        self.value = {'schema': 'bluemap.resident-social.catalog.v1', 'sourceOracleSha256': self.digest,
                      'personalSavesUsed': False, 'catalogsOrdered': copy.deepcopy(self.ordered)}

    def test_runtime_catalog_is_exact_lossless_original_projection(self):
        residents.validate_runtime_catalog(self.value, self.ordered, self.digest)

    def test_runtime_catalog_wrong_full_oracle_is_rejected(self):
        self.value['sourceOracleSha256'] = 'b' * 64
        with self.assertRaisesRegex(residents.ResidentsDataError, 'hash'):
            residents.validate_runtime_catalog(self.value, self.ordered, self.digest)

    def test_runtime_catalog_cannot_reorder_original_pairs(self):
        self.value['catalogsOrdered']['$dict'].append(['invented_role', {'$dict': []}])
        with self.assertRaisesRegex(residents.ResidentsDataError, 'projection'):
            residents.validate_runtime_catalog(self.value, self.ordered, self.digest)

    def test_runtime_catalog_personal_save_or_extra_fields_rejected(self):
        for field, value in (('personalSavesUsed', True), ('claimedCompleteGame', True)):
            altered = copy.deepcopy(self.value); altered[field] = value
            with self.subTest(field=field), self.assertRaisesRegex(residents.ResidentsDataError, 'privacy'):
                residents.validate_runtime_catalog(altered, self.ordered, self.digest)

    def test_eight_roles_and_two_dishes_come_from_original_code(self):
        original = residents.original_catalogs(ROOT)
        self.assertEqual(set(original['places']), {'miner', 'gardener', 'hearth', 'lamplighter',
                                                   'carrier', 'caravan', 'reader', 'courier'})
        self.assertEqual(original['dishes'], ['ls_chowder', 'ls_broth'])
        self.assertEqual(original['places']['courier']['map'], 'ridgepass')

    def test_motion_catalog_cannot_change_route_places(self):
        source = {'places': residents.original_catalogs(ROOT)['places']}
        value = {'schema': 'bluemap.resident-motion.catalog.v1', 'catalog': copy.deepcopy(source)}
        residents.validate_motion_catalog(value, source)
        value['catalog']['places']['courier']['map'] = 'village'
        with self.assertRaisesRegex(residents.ResidentsDataError, 'projection'):
            residents.validate_motion_catalog(value, source)

    def test_unfrozen_callback_contract_cannot_generate_green_evidence(self):
        with patch.object(residents, 'RESIDENTS_DETAIL_CHECKS', set()):
            with self.assertRaisesRegex(residents.ResidentsDataError, 'not frozen'):
                residents.build_contract(ROOT)

    def test_invented_original_method_is_rejected(self):
        with self.assertRaisesRegex(residents.ResidentsDataError, 'Unverified'):
            residents.source_methods(ROOT, ['scripts/core/world_memory.gd::invented_reward'], set())

    def test_duplicate_source_method_is_rejected(self):
        method = 'scripts/core/world_memory.gd::news'
        with self.assertRaisesRegex(residents.ResidentsDataError, 'duplicated'):
            residents.source_methods(ROOT, [method, method], {method})


class ResidentObservationContractTests(unittest.TestCase):
    def setUp(self):
        state = {key: 0 for key in residents.SAVE_FIELDS}
        self.row = {key: {} for key in residents.CASE_FIELDS}
        self.row.update(id='signal-order', initial=copy.deepcopy(state), expected=copy.deepcopy(state),
                        operations=[['meet', 'gardener'], ['meet', 'gardener']], results=[None, None],
                        observations=[{'state': copy.deepcopy(state), 'view': {'object': None}, 'events': ['changed']},
                                      {'state': copy.deepcopy(state), 'view': {'object': None}, 'events': ['changed', 'changed']}])

    def validate(self):
        residents.validate_social_observations([self.row], [self.row])

    def test_full_state_transients_and_ordered_consequences_are_required(self):
        self.validate()

    def test_missing_per_step_observation_is_rejected(self):
        self.row['observations'].pop()
        with self.assertRaisesRegex(residents.ResidentsDataError, 'per-operation'):
            self.validate()

    def test_cumulative_events_cannot_be_reordered_or_replaced(self):
        self.row['observations'][1]['events'] = ['different', 'changed']
        with self.assertRaisesRegex(residents.ResidentsDataError, 'signal ordering'):
            self.validate()

    def test_final_state_must_match_last_real_observation(self):
        self.row['observations'][-1]['state']['coins'] = 1
        with self.assertRaisesRegex(residents.ResidentsDataError, 'final observation'):
            self.validate()

    def test_actuator_view_cannot_be_omitted(self):
        del self.row['observations'][0]['view']
        with self.assertRaisesRegex(residents.ResidentsDataError, 'actuator'):
            self.validate()

    def test_any_of_34_original_fields_cannot_disappear(self):
        del self.row['observations'][0]['state']['professions']
        with self.assertRaisesRegex(residents.ResidentsDataError, 'state/event'):
            self.validate()


class ResidentExactNumericTests(unittest.TestCase):
    def test_float32_vectors_and_float64_scalars_remain_distinct(self):
        value = {'position': {'$v2': '0000803f00000040'}, 'wait': {'$f64': '000000000000f03f'}}
        self.assertEqual(motion.validate_numeric_witnesses(value), 3)
        self.assertEqual(residents.motion_plain(value), {'position': [1., 2.], 'wait': 1.})

    def test_untagged_float_and_malformed_or_nonfinite_bits_rejected(self):
        for value in (1.5, {'$f64': 'bad'}, {'$v2': '0000807f00000000'},
                      {'$f64': '000000000000f87f'}, {'$f64': '000000000000f03f', 'guess': 1}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                motion.validate_numeric_witnesses(value)

    def test_duplicate_or_unsafe_case_identity_rejected(self):
        for rows in ([{'id': 'same'}, {'id': 'same'}], [{'id': 'pose (1, 2)'}], [{'id': ''}]):
            with self.subTest(rows=rows), self.assertRaisesRegex(residents.ResidentsDataError, 'identity'):
                residents.case_ids(rows)


class OriginalResidentOracleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.motion_raw = (ROOT / residents.MOTION_ORACLE).read_bytes()
        cls.motion = json.loads(cls.motion_raw)
        cls.social_raw = (ROOT / residents.SOCIAL_ORACLE).read_bytes()
        cls.social = json.loads(cls.social_raw)

    def test_original_recordings_are_identical_to_native_resources(self):
        self.assertEqual(self.motion_raw, (ROOT / residents.MOTION_RESOURCE).read_bytes())
        self.assertEqual(self.social_raw, (ROOT / residents.SOCIAL_RESOURCE).read_bytes())

    def test_real_motion_all_families_and_external_boundary_policy(self):
        summary = residents.motion_coverage(self.motion, residents.original_catalogs(ROOT), ROOT)
        self.assertEqual(set(summary['families']), motion.FAMILIES)
        self.assertTrue(summary['randomDrawsAreExternalInputs'])
        self.assertTrue(summary['collisionResolutionIsExternalInput'])

    def test_motion_cannot_drop_a_decision_family(self):
        value = dict(self.motion)
        value['cases'] = [row for row in self.motion['cases'] if row['kind'] != 'safe']
        with self.assertRaises(ValueError):
            motion.validate_document(value)

    def test_motion_cannot_drop_a_pause_branch(self):
        value = dict(self.motion)
        value['cases'] = [row for row in self.motion['cases'] if row['id'] != 'step_memory_locked']
        with self.assertRaisesRegex(ValueError, 'branch'):
            motion.validate_document(value)

    def test_actual_social_state_order_and_locales(self):
        summary = residents.social_coverage(self.social, residents.original_catalogs(ROOT), ROOT)
        self.assertEqual(summary['roles'], 8)
        self.assertEqual(len(summary['saveFields']), 34)
        self.assertTrue(summary['dictionaryInputOrderPreserved'])

    def test_gameplay_catalog_binds_actual_full_recording(self):
        catalog = json.loads((ROOT / residents.SOCIAL_CATALOG).read_bytes())
        residents.validate_runtime_catalog(catalog, self.social['catalogsOrdered'], hashlib.sha256(self.social_raw).hexdigest())

    def test_motion_gameplay_catalog_is_exact_original_subset(self):
        catalog = json.loads((ROOT / residents.MOTION_CATALOG).read_bytes())
        residents.validate_motion_catalog(catalog, self.motion['catalog'])

    def test_social_plain_observation_cannot_disagree_with_exact_witness(self):
        value = dict(self.social); value['cases'] = [copy.deepcopy(self.social['cases'][0])]
        value['cases'][0]['observations'][0]['state']['coins'] += 1
        with self.assertRaises(ValueError):
            social.validate_document(value)

    def test_social_ordered_operation_mutation_rejected(self):
        value = dict(self.social); value['cases'] = [copy.deepcopy(self.social['cases'][0])]
        value['cases'][0]['operationsOrdered'][0][0] = 'invented_resident_reward'
        with self.assertRaises(ValueError):
            social.validate_document(value)


if __name__ == '__main__':
    unittest.main()
