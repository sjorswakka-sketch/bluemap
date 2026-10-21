"""Adversarial source-contract checks independent of the C# combat implementation."""
import copy
import json
from pathlib import Path
import struct
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import build_migration_combat as combat
from record_migration_inventory_state import decode_ordered_input


def exact(value):
    if type(value) is float:
        return {'$f64': struct.pack('<d', value).hex()}
    if type(value) is dict:
        return {key: exact(child) for key, child in value.items()}
    if type(value) is list:
        return [exact(child) for child in value]
    return value


def ordered(value):
    if type(value) is dict:
        return {'$dict': [[key, ordered(child)] for key, child in value.items()]}
    if type(value) is list:
        return [ordered(child) for child in value]
    return exact(value)


def display_mirror(value):
    if type(value) is float:
        return float(format(value, '.15g'))
    if type(value) is dict:
        return {key: display_mirror(child) for key, child in value.items()}
    if type(value) is list:
        return [display_mirror(child) for child in value]
    return value


class CombatSourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference = combat.original_references(ROOT)
        cls.original = json.loads((ROOT / combat.ORACLES['combat'][0]).read_bytes())

    def setUp(self):
        self.value = copy.deepcopy(self.original)

    def reject(self, match=None):
        with self.assertRaisesRegex((ValueError, KeyError, TypeError), match or '.'):
            combat.combat_coverage(self.value, self.reference, ROOT)

    def catalog(self, edit):
        value = decode_ordered_input(self.value['catalogsOrdered'])
        edit(value)
        self.value.update(catalogs=display_mirror(value), catalogsExact=exact(value), catalogsOrdered=ordered(value))

    def case_field(self, case, field, value):
        case[field], case[field + 'Exact'] = display_mirror(value), exact(value)
        if field + 'Ordered' in case:
            case[field + 'Ordered'] = ordered(value)

    def test_complete_original_catalogs_constants_and_loaded_actors(self):
        result = combat.combat_coverage(self.value, self.reference, ROOT)
        self.assertEqual(result['enemies'], 35)
        self.assertEqual(result['weapons'], 4)
        self.assertEqual((result['loadedActorSnapshots'], result['loadedActors']), (162, 733))
        self.assertTrue(result['dictionaryInputOrderPreserved'])

    def test_missing_enemy_is_rejected_even_with_all_mirrors_updated(self):
        self.catalog(lambda c: c['enemies'].pop('slime'))
        self.reject('catalog')

    def test_invented_enemy_is_rejected_even_with_all_mirrors_updated(self):
        self.catalog(lambda c: c['enemies'].update(invented=copy.deepcopy(c['enemies']['slime'])))
        self.reject('catalog')

    def test_enemy_damage_and_drops_are_original_values(self):
        def edit(c):
            c['enemies']['slime']['damage'] = 99
            c['enemies']['slime']['drops'][0][2] = 1000
        self.catalog(edit)
        self.reject('catalog')

    def test_freely_changed_bow_cost_is_rejected(self):
        self.catalog(lambda c: c['bowTechnique'].update(cost=0.0))
        self.reject('bow/style')

    def test_equipment_cannot_gain_an_invented_combat_bonus(self):
        def edit(c):
            next(iter(c['gear'].values())).setdefault('bonuses', {})['free_arrows'] = 999
        self.catalog(edit)
        self.reject('catalog')

    def test_guardian_rewards_and_phase_constants_are_source_bound(self):
        self.catalog(lambda c: c['guardian'].update(REWARD_COINS=501))
        self.reject('constants')

    def test_player_cooldowns_are_source_bound(self):
        self.catalog(lambda c: c['player'].update(ATTACK_COOLDOWN=0.01))
        self.reject('constants')

    def test_original_projectile_traits_are_source_bound(self):
        self.catalog(lambda c: c['projectileTraits'].update(free_projectile={'life': 999.0}))
        self.reject('projectile')

    def test_original_enemy_dictionary_order_is_independent_of_json_sorting(self):
        def edit(c):
            c['enemies'] = dict(reversed(list(c['enemies'].items())))
        self.catalog(edit)
        self.reject('insertion order')

    def test_original_coastal_style_costs_are_not_invented(self):
        self.catalog(lambda c: c['coastalProfiles']['cw_fan'].update(arrows=0))
        self.reject('bow/style')

    def test_arrow_terrain_rules_are_complete(self):
        self.catalog(lambda c: c['arrowOverTiles'].append('stone'))
        self.reject('terrain')

    def test_every_original_actor_and_source_address_must_remain(self):
        def edit(c):
            next(row for row in c['loadedActors'] if row['actors'])['actors'].pop()
        self.catalog(edit)
        self.reject('actor coverage')

    def test_actor_placement_cannot_shift_coherently(self):
        def edit(c):
            next(row for row in c['loadedActors'] if row['actors'])['actors'][0]['position'][0] += 32.0
        self.catalog(edit)
        self.reject('actor coverage')

    def test_every_weapon_and_boundary_case_family_is_required(self):
        self.value['cases'] = self.value['cases'][1:]
        self.reject('families')

    def test_duplicate_or_invented_case_ids_are_rejected(self):
        self.value['cases'][-1]['id'] = self.value['cases'][0]['id']
        self.reject('duplicate')

    def test_original_save_fields_cannot_be_lost_with_updated_mirrors(self):
        case = self.value['cases'][0]
        for field in ('initial', 'expected'):
            value = decode_ordered_input(case[field + 'Ordered']) if field == 'initial' else copy.deepcopy(case[field])
            value.pop('inventory')
            self.case_field(case, field, value)
        self.reject('save fields')

    def test_unknown_nested_field_and_large_integer_are_preserved(self):
        case = next(row for row in self.value['cases'] if row['id'] == 'future-profile-fields-retained')
        for field in ('initial', 'expected'):
            value = decode_ordered_input(case['initialOrdered']) if field == 'initial' else copy.deepcopy(case[field])
            value['flags']['future_combat']['large'] = 9007199254740992
            self.case_field(case, field, value)
        self.reject('Future combat profile')

    def test_transient_mirror_cannot_disagree_with_exact_values(self):
        case = self.value['cases'][0]
        case['initialPlayer']['stamina'] = 99.0
        self.reject('mirror|float')

    def test_ordered_transient_input_is_validated(self):
        self.value['cases'][0]['transientOrdered'] = {'$dict': [['invented', True]]}
        self.reject('Ordered|ordered')


class EncounterSourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference = combat.original_references(ROOT)
        cls.original = json.loads((ROOT / combat.ORACLES['encounter'][0]).read_bytes())

    def setUp(self):
        self.value = copy.deepcopy(self.original)

    def reject(self, match='.'):
        with self.assertRaisesRegex((ValueError, KeyError, TypeError), match):
            combat.encounter_coverage(self.value, self.reference, ROOT)

    def case(self, name):
        return next(row for row in self.value['cases'] if row['id'] == name)

    def field(self, case, name, value):
        case[name], case[name + 'Exact'] = display_mirror(value), exact(value)
        if name + 'Ordered' in case:
            case[name + 'Ordered'] = ordered(value)

    def test_all_source_species_ai_deaths_projectiles_and_guardian_components(self):
        result = combat.encounter_coverage(self.value, self.reference, ROOT)
        self.assertEqual((result['cases'], result['enemies'], result['behaviorFamilies']), (208, 35, 22))
        self.assertEqual(result['components'], ['guardian', 'pillar', 'shard'])

    def test_coherently_altered_species_damage_is_rejected(self):
        value = decode_ordered_input(self.value['catalogsOrdered'])
        value['enemies']['slime']['damage'] = 999
        self.value.update(catalogs=display_mirror(value), catalogsExact=exact(value), catalogsOrdered=ordered(value))
        self.reject('species')

    def test_every_species_requires_lethal_and_practice_observations(self):
        self.value['cases'] = [row for row in self.value['cases'] if row['id'] != 'death-slime']
        self.reject('families')

    def test_guardian_phase_and_shard_source_episodes_are_required(self):
        self.value['cases'] = [row for row in self.value['cases'] if row['id'] != 'projectile-flight-guardian_shard']
        self.reject('families')

    def test_extra_or_reordered_ai_episodes_are_rejected(self):
        self.value['cases'][0], self.value['cases'][1] = self.value['cases'][1], self.value['cases'][0]
        self.reject('reordered')

    def test_controlled_drop_policy_is_explicit(self):
        self.value.pop('fixturePolicy', None)
        self.reject('fixture polic')

    def test_actor_fixture_is_exact_and_ordered(self):
        self.case('acquire-animal')['fixture']['wander_timer'] = 0.0
        self.reject('mirror|float')

    def test_random_wandering_cannot_replace_controlled_fixture_inputs(self):
        case = self.case('acquire-animal')
        fixture = decode_ordered_input(case['fixtureOrdered'])
        fixture['wander_timer'] = 0.0
        self.field(case, 'fixture', fixture)
        self.reject('random wandering')

    def test_coherent_death_drop_inflation_is_rejected(self):
        case = self.case('death-slime')
        for name in ('expected', 'results'):
            value = copy.deepcopy(case[name])
            for row in value if name == 'results' else [value]:
                row['drop_counts']['coin'] += 1
            self.field(case, name, value)
        self.reject('drop counts')

    def test_practice_cannot_grant_loot(self):
        case = self.case('practice-slime')
        for name in ('expected', 'results'):
            value = copy.deepcopy(case[name])
            for row in value if name == 'results' else [value]:
                row['drop_counts']['coin'] = 1
            self.field(case, name, value)
        self.reject('drop counts')

    def test_second_lethal_hit_cannot_claim_a_second_reward(self):
        case = self.case('death-slime')
        value = copy.deepcopy(case['results'])
        value[0]['unique_claimed'] = False
        self.field(case, 'results', value)
        self.reject('Repeated lethal')

    def test_source_unique_flag_cannot_be_omitted_coherently(self):
        case = self.case('death-slime')
        for name in ('expected', 'results'):
            value = copy.deepcopy(case[name])
            for row in value if name == 'results' else [value]:
                row['unique_claimed'] = False
            self.field(case, name, value)
        self.reject('unique claim')


if __name__ == '__main__':
    unittest.main()
