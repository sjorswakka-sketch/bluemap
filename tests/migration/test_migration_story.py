"""Independent original story graph and dispatcher contract guards."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import build_migration_story as story


class StoryGraphContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = story.original_references(ROOT)

    def setUp(self):
        self.value = copy.deepcopy(self.original)

    def census(self):
        original = self.value['census']
        return story.story_census(self.value['catalogs'], self.value['maps'], original['modules'],
                                  original['baseActions'], original['baseConditions'])

    def test_all_original_catalogs_modules_and_maps_remain(self):
        census = self.census()
        self.assertEqual(census['catalogCounts'], {'dialogues': 244, 'npcs': 35, 'quests': 33})
        self.assertEqual(census['mapCount'], 37)
        self.assertEqual(len(census['modules']), 37)
        self.assertEqual((len(census['actionNames']), len(census['conditionNames']), len(census['formatNames'])), (36, 33, 11))

    def test_no_silent_unknown_dialogue_action(self):
        self.value['catalogs']['dialogues']['king_intro']['do'] = [['invented_reward', 999]]
        with self.assertRaisesRegex(story.StoryDataError, 'action'):
            self.census()

    def test_unknown_map_trigger_action_is_rejected(self):
        self.value['maps']['temple']['objects'][11]['do'].append(['fake_completion'])
        with self.assertRaisesRegex(story.StoryDataError, 'action'):
            self.census()

    def test_unknown_npc_condition_is_rejected(self):
        self.value['catalogs']['npcs']['bram']['rules'][0]['if'] = [['fake_ready']]
        with self.assertRaisesRegex(story.StoryDataError, 'condition'):
            self.census()

    def test_unknown_quest_condition_is_rejected(self):
        self.value['catalogs']['quests']['main']['steps'][0]['advance_if'] = [['fake_objective']]
        with self.assertRaisesRegex(story.StoryDataError, 'condition'):
            self.census()

    def test_map_gate_block_conditions_are_censused(self):
        row = self.value['maps']['arena']['objects'][2]
        self.assertIn('block_if', row)
        row['block_if'] = [['fake_gate']]
        with self.assertRaisesRegex(story.StoryDataError, 'condition'):
            self.census()

    def test_bookcase_open_conditions_are_censused(self):
        self.value['maps']['library']['objects'].append({'type': 'test', 'open_if': [['fake_books']]})
        with self.assertRaisesRegex(story.StoryDataError, 'condition'):
            self.census()

    def test_any_checks_all_nested_alternatives(self):
        row = self.value['catalogs']['dialogues']['king_intro']
        row['if'] = [['any', ['flag', 'known'], ['any', ['coins', 1], ['invented_branch']]]]
        with self.assertRaisesRegex(story.StoryDataError, 'condition'):
            self.census()

    def test_unknown_dialogue_next_is_rejected(self):
        self.value['catalogs']['dialogues']['king_intro']['next'] = 'missing_ending'
        with self.assertRaisesRegex(story.StoryDataError, 'dialogue edge'):
            self.census()

    def test_unknown_talk_action_reference_is_rejected(self):
        self.value['maps']['temple']['objects'][11]['do'][0] = ['talk', 'missing_king_intro']
        with self.assertRaisesRegex(story.StoryDataError, 'action dialogue'):
            self.census()

    def test_unknown_action_quest_is_rejected(self):
        self.value['catalogs']['dialogues']['king_intro']['do'] = [['finish_quest', 'invented_quest']]
        with self.assertRaisesRegex(story.StoryDataError, 'action quest'):
            self.census()

    def test_unknown_condition_quest_is_rejected(self):
        self.value['catalogs']['dialogues']['king_intro']['if'] = [['quest', 'invented_quest', 'done']]
        with self.assertRaisesRegex(story.StoryDataError, 'condition quest'):
            self.census()

    def test_unknown_reward_item_is_rejected(self):
        self.value['catalogs']['dialogues']['king_intro']['do'] = [['give', 'fake_reward']]
        with self.assertRaisesRegex(story.StoryDataError, 'action item'):
            self.census()

    def test_unknown_required_item_is_rejected(self):
        self.value['catalogs']['dialogues']['king_intro']['if'] = [['has', 'fake_requirement']]
        with self.assertRaisesRegex(story.StoryDataError, 'condition item'):
            self.census()

    def test_unknown_weapon_reward_is_rejected(self):
        self.value['catalogs']['dialogues']['king_intro']['do'] = [['weapon', 'fake_weapon']]
        with self.assertRaisesRegex(story.StoryDataError, 'action weapon'):
            self.census()

    def test_unknown_map_npc_is_rejected(self):
        self.value['maps']['village']['objects'].append({'type': 'npc', 'id': 'fake_quest_giver'})
        with self.assertRaisesRegex(story.StoryDataError, 'map NPC'):
            self.census()

    def test_unknown_text_token_is_rejected(self):
        self.value['catalogs']['dialogues']['king_intro']['lines'].append('Reward: {invented_reward}')
        with self.assertRaisesRegex(story.StoryDataError, 'formatting'):
            self.census()

    def test_original_greta_getter_enrichment_remains(self):
        for key in ('greta_max', 'greta_star', 'greta_star_again', 'greta_done'):
            choices = self.value['catalogs']['dialogues'][key]['choices']
            self.assertEqual(choices[0], {'text': 'Niets, bedankt.'})
            self.assertEqual(choices[1]['do'], [['wt_open', 'smith']])

    def test_actual_temple_trigger_has_intro_then_boss_action(self):
        actions = self.value['maps']['temple']['objects'][11]['do']
        self.assertEqual(actions, [['talk', 'king_intro'], ['boss_start']])
        census = self.census()
        self.assertTrue(any(row['value'] == ['boss_start'] and row['location'].startswith('maps/temple/')
                            for row in census['actions']))

    def test_declaration_comments_and_trailing_comma_do_not_invent_names(self):
        source = 'const ACTIONS: Array = ["one", # comment\n"two",]\n'
        self.assertEqual(story.declared_array(source, 'ACTIONS'), ['one', 'two'])

    def test_duplicate_declared_actions_are_rejected(self):
        with self.assertRaisesRegex(story.StoryDataError, 'declared'):
            story.declared_array('const ACTIONS := ["one", "one"]\n', 'ACTIONS')


class StoryTraversalAndBoundedCatalogTests(unittest.TestCase):
    def setUp(self):
        self.catalogs = {'dialogues': {'intro': {'choices': [{'text': 'Yes'}]}},
                         'npcs': {'npc': {'rules': [{'talk': 'intro'}]}}}
        self.cases = [
            {'id': 'dialogue-choice-intro-0', 'results': [True], 'operations': [['choose', 0]]},
            {'id': 'npc-rule-npc-0', 'observations': [{'dialogue': {'id': 'intro'}}], 'operations': []},
            {'id': 'condition-0-false', 'operations': [['check', ['quest', 'q', 'none']]], 'results': [False]},
            {'id': 'condition-0-true', 'operations': [['check', ['quest', 'q', 'none']]], 'results': [True]},
        ]
        self.ordered = {'$dict': [['dialogues', {'$dict': [['intro', {'$dict': []}]]}]]}
        self.digest = 'a' * 64
        self.runtime = {'schema': 'bluemap.story.catalog.v1', 'sourceOracleSha256': self.digest,
                        'personalSavesUsed': False, 'catalogsOrdered': copy.deepcopy(self.ordered)}

    def test_coverage_requires_actual_choices_npc_targets_and_negative_context(self):
        result = story.semantic_traversal_coverage(self.cases, self.catalogs)
        self.assertEqual((result['actualDialogueChoiceTraversals'], result['actualNpcRuleTraversals'],
                          result['questNoneConditionContrastPairs']), (1, 1, 1))

    def test_attempted_but_unselected_choice_is_not_coverage(self):
        self.cases[0]['results'][-1] = False
        with self.assertRaisesRegex(story.StoryDataError, 'choice'):
            story.semantic_traversal_coverage(self.cases, self.catalogs)

    def test_npc_fixture_shadowed_by_prior_rule_is_rejected(self):
        self.cases[1]['observations'][0]['dialogue']['id'] = 'other_greeting'
        with self.assertRaisesRegex(story.StoryDataError, 'shadowed'):
            story.semantic_traversal_coverage(self.cases, self.catalogs)

    def test_duplicate_true_quest_none_fixture_is_not_a_negative_case(self):
        self.cases[2]['results'][0] = True
        with self.assertRaisesRegex(story.StoryDataError, 'contrast'):
            story.semantic_traversal_coverage(self.cases, self.catalogs)

    def test_small_runtime_catalog_is_the_exact_lossless_projection(self):
        story.validate_runtime_catalog(self.runtime, self.ordered, self.digest)

    def test_runtime_catalog_must_name_the_correct_full_oracle(self):
        self.runtime['sourceOracleSha256'] = 'b' * 64
        with self.assertRaisesRegex(story.StoryDataError, 'hash'):
            story.validate_runtime_catalog(self.runtime, self.ordered, self.digest)

    def test_runtime_catalog_cannot_change_a_value_or_dictionary_order(self):
        self.runtime['catalogsOrdered']['$dict'].append(['invented_dialogues', {'$dict': []}])
        with self.assertRaisesRegex(story.StoryDataError, 'projection'):
            story.validate_runtime_catalog(self.runtime, self.ordered, self.digest)

    def test_runtime_catalog_privacy_and_extra_fields_fail_closed(self):
        self.runtime['personalSavesUsed'] = True
        with self.assertRaisesRegex(story.StoryDataError, 'privacy'):
            story.validate_runtime_catalog(self.runtime, self.ordered, self.digest)


if __name__ == '__main__':
    unittest.main()
