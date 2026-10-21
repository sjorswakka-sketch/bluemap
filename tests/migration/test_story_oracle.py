"""Guard genuine original story recordings against mirror/order/state/provenance corruption."""
import copy
import json
from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import record_migration_story as recorder

class StoryOracleTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.document=json.loads((ROOT/'migration/phase-15/story-oracle.json').read_text(encoding='utf-8'))
 def small(self):
  d=dict(self.document);d['cases']=[copy.deepcopy(d['cases'][0])];d.pop('objectCases',None)
  d['catalogs']={};d['catalogsExact']={};d['catalogsOrdered']={'$dict':[]};return d
 def test_actual_schema_engine_privacy(self):
  d=self.document;self.assertEqual(d['schema'],'bluemap.story.source-oracle.v1');self.assertEqual(d['engineVersion'],'4.4.1-stable (official)');self.assertIs(d['personalSavesUsed'],False)
 def test_full_native_resource_identical(self):self.assertEqual((ROOT/'migration/phase-15/story-oracle.json').read_bytes(),(ROOT/'unity/Assets/BlueMapStory/Runtime/Model/Resources/BlueMapStoryOracle.json').read_bytes())
 def test_complete_original_catalogs(self):
  c=self.document['catalogs'];self.assertEqual((len(c['dialogues']),len(c['npcs']),len(c['quests'])),(244,35,33));self.assertEqual((len(c['modules']),len(c['actionNames']),len(c['conditionNames']),len(c['formatNames'])),(37,36,33,11))
 def test_all_exact_mirrors_and_original_states(self):recorder.validate_document(self.document)
 def test_every_dialogue_original_callback(self):self.assertEqual({r['id'][14:] for r in self.document['cases'] if r['id'].startswith('dialogue-node-')},set(self.document['catalogs']['dialogues']))
 def test_every_original_choice_has_episode(self):
  ids={r['id'] for r in self.document['cases']}
  for name,node in self.document['catalogs']['dialogues'].items():
   for i in range(len(node.get('choices',[]))):self.assertIn('dialogue-choice-'+name+'-'+str(i),ids)
 def test_late_greta_workshop_choices_retained(self):
  for name in ('greta_max','greta_star','greta_star_again','greta_done'):self.assertEqual(self.document['catalogs']['dialogues'][name]['choices'][-1]['do'],[['wt_open','smith']])
 def test_every_original_npc_rule_has_episode(self):
  ids={r['id'] for r in self.document['cases']}
  for name,npc in self.document['catalogs']['npcs'].items():
   for i in range(len(npc['rules'])):self.assertIn('npc-rule-'+name+'-'+str(i),ids)
 def test_every_npc_fixture_selects_its_intended_rule(self):
  rows={r['id']:r for r in self.document['cases']}
  for name,npc in self.document['catalogs']['npcs'].items():
   for index,rule in enumerate(npc['rules']):
    row=rows['npc-rule-'+name+'-'+str(index)]
    self.assertEqual(row['observations'][0]['dialogue']['id'],rule['talk'],row['id'])
 def test_every_choice_fixture_reaches_its_original_choice(self):
  for row in self.document['cases']:
   if not row['id'].startswith('dialogue-choice-'):continue
   operation=row['operations'][-1];self.assertEqual(operation[0],'choose_source')
   self.assertIn(operation[1],row['observations'][-2]['dialogue']['sourceIndices'],row['id'])
   self.assertIs(row['results'][-1],True,row['id'])
 def test_negative_quest_none_fixtures_have_actual_contrast(self):
  rows={r['id']:r for r in self.document['cases']}
  for index,condition in enumerate(self.document['catalogs']['conditionOccurrences']):
   value=condition['value']
   if value[0]=='quest' and value[2]=='none':
    self.assertEqual(rows['condition-'+str(index)+'-false']['results'],[False,False])
    self.assertEqual(rows['condition-'+str(index)+'-true']['results'],[True,True])
 def test_small_gameplay_catalog_is_exact_source_subset(self):
  import hashlib
  source=(ROOT/'migration/phase-15/story-oracle.json').read_bytes()
  catalog=json.loads((ROOT/'unity/Assets/BlueMapStory/Runtime/Model/Resources/BlueMapStoryCatalog.json').read_text(encoding='utf-8'))
  self.assertEqual(set(catalog),{'schema','personalSavesUsed','sourceOracleSha256','catalogsOrdered'})
  self.assertEqual(catalog['schema'],'bluemap.story.catalog.v1');self.assertIs(catalog['personalSavesUsed'],False)
  self.assertEqual(catalog['sourceOracleSha256'],hashlib.sha256(source).hexdigest())
  self.assertEqual(catalog['catalogsOrdered'],self.document['catalogsOrdered'])
 def test_every_original_quest_and_step(self):
  ids={r['id'] for r in self.document['cases']}
  for name,q in self.document['catalogs']['quests'].items():
   self.assertIn('quest-lifecycle-'+name,ids)
   for i in range(len(q['steps'])):self.assertIn('quest-step-'+name+'-'+str(i),ids)
 def test_conditions_cover_both_source_fixtures(self):
  ids={r['id'] for r in self.document['cases']}
  for i in range(len(self.document['catalogs']['conditionOccurrences'])):
   for suffix in ('false','true'):self.assertIn('condition-'+str(i)+'-'+suffix,ids)
 def test_actual_object_callbacks_and_boundaries(self):
  ids={r['id'] for r in self.document['objectCases']}
  self.assertIn('opening-wheel-once',ids);self.assertIn('opening-grate-work-and-repeat',ids);self.assertIn('route-memorial-far-context',ids)
  for name in ('rf_echo_begin','rf_echo_mid','rf_echo_end'):self.assertIn('route-echo-'+name,ids)
 def test_actual_map_trigger_episodes(self):self.assertTrue(any(r['id'].startswith('world-trigger-temple-') for r in self.document['cases']))
 def test_source_methods_exist_in_original_files(self):
  import re
  for method in self.document['sourceMethods']:
   name,func=method.split('::');self.assertRegex((ROOT/name).read_text(encoding='utf-8'),r'func\s+'+re.escape(func)+r'\s*\(')
 def test_plain_initial_mutation_rejected(self):
  d=self.small();d['cases'][0]['initial']['hp']+=1
  with self.assertRaises(ValueError):recorder.normalize_exact_mirrors(d)
 def test_exact_initial_mutation_rejected(self):
  d=self.small();d['cases'][0]['initialExact']['hp']+=1
  with self.assertRaises(ValueError):recorder.normalize_exact_mirrors(d)
 def test_ordered_initial_mutation_rejected(self):
  d=self.small();d['cases'][0]['initialOrdered']['$dict'][0][1]=999
  with self.assertRaises(ValueError):recorder.normalize_exact_mirrors(d)
 def test_ordered_operation_mutation_rejected(self):
  d=self.small();d['cases'][0]['operationsOrdered'][0][1]='future_dialogue'
  with self.assertRaises(ValueError):recorder.normalize_exact_mirrors(d)
 def test_observation_plain_mutation_rejected(self):
  d=self.small();d['cases'][0]['observations'][0]['state']['hp']+=1
  with self.assertRaises(ValueError):recorder.normalize_exact_mirrors(d)
 def test_observation_exact_mutation_rejected(self):
  d=self.small();d['cases'][0]['observationsExact'][0]['state']['hp']+=1
  with self.assertRaises(ValueError):recorder.normalize_exact_mirrors(d)
 def test_observation_ordered_mutation_rejected(self):
  d=self.small();pairs=d['cases'][0]['observationsOrdered'][0]['$dict'];pairs[0][1]='corrupted'
  with self.assertRaises(ValueError):recorder.normalize_exact_mirrors(d)
 def test_missing_observation_rejected(self):
  d=self.small();d['cases'][0]['observations']=[];d['cases'][0]['observationsExact']=[];d['cases'][0]['observationsOrdered']=[]
  with self.assertRaises(ValueError):recorder.validate_document(d)
 def test_missing_original_saved_field_rejected(self):
  d=self.small();r=d['cases'][0]
  for k in ('initial','initialExact'):del r[k]['yard']
  r['initialOrdered']['$dict']=[p for p in r['initialOrdered']['$dict'] if p[0]!='yard']
  with self.assertRaises(ValueError):recorder.validate_document(d)
 def test_duplicate_case_identity_rejected(self):
  d=self.small();d['cases'].append(copy.deepcopy(d['cases'][0]))
  with self.assertRaises(ValueError):recorder.validate_document(d)
 def test_nonfinite_float64_witness_rejected(self):
  d=self.small();d['cases'][0]['initialExact']['day_time']={'$f64':'000000000000f87f'}
  with self.assertRaises(ValueError):recorder.validate_float64_bits(d)
 def test_unknown_large_nested_story_fields_retained(self):
  r=next(r for r in self.document['cases'] if r['id']=='future-story-fields-retained');self.assertEqual(r['expected']['flags']['future_story']['number'],9007199254740993);self.assertEqual(r['expected']['quests']['kat']['future_journal']['note'],'keep')
 def test_recorder_checks_original_methods_twice_and_uuid(self):
  source=(ROOT/'tools/record_migration_story.py').read_text();self.assertIn('for number in (1, 2)',source);self.assertIn('uuid.uuid4().hex',source);self.assertIn('sourceUnchanged',source);self.assertIn('fingerprint(ROOT) != before',source)

if __name__=='__main__':unittest.main()
