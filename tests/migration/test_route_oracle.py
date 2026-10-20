"""Original route outcomes, exact gear witnesses and source-isolated recording contract."""
import json
import math
from pathlib import Path
import struct
import unittest

ROOT=Path(__file__).resolve().parents[2]
CASE_IDS={"pim_accept","pim_decline","pim_cancel_unread","bram_accept","cat_wait_then_find","cat_without_quest","cat_panic","cat_calm_interrupted","pim_reward_once","pim_reward_level","pim_max_hearts","chest_basic","chest_owned_unique","chest_partial_stack_refused","chest_heart","gather_active_cooldown","gather_missing_tool","gather_strong_tool","gather_level_required","gather_xp_cap","rest_no_time_skip","pickup_coin","pickup_heart_full","pickup_heart_hurt","pickup_crystal","pickup_item_full"}
SAVE_KEYS={"version","map","pos","hp","coins","inventory","flags","quests","weapon","visited_maps","play_time","kills","meer","day_time","day_count","kills_by","rolls","potions_drunk","deaths","boss_deaths","talked","achievements","arena_records","homestead","coastal_storage","stockroom","personal_home","yard","professions","hero_xp","equipment","appearance","clothing","ng_plus"}

class RouteOracleTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.source=ROOT/'migration/phase-10/route-oracle.json'
  cls.oracle=json.loads(cls.source.read_text(encoding='utf-8'))
  cls.cases={r['id']:r for r in cls.oracle['cases']}
 def test_exact_schema_and_artificial_source_contract(self):
  self.assertEqual(self.oracle['schema'],'bluemap.route.source-oracle.v1')
  self.assertEqual(self.oracle['engineVersion'],'4.4.1-stable (official)')
  self.assertIs(self.oracle['personalSavesUsed'],False)
  self.assertEqual(set(self.cases),CASE_IDS)
  self.assertEqual(len(self.oracle['cases']),26)
 def test_runtime_reference_is_byte_identical(self):
  self.assertEqual(self.source.read_bytes(),(ROOT/'unity/Assets/BlueMapRoute/Runtime/Model/Resources/BlueMapRouteOracle.json').read_bytes())
 def test_complete_new_game_and_every_route_case_preserve_34_fields(self):
  self.assertEqual(set(self.oracle['newGame']),SAVE_KEYS)
  self.assertTrue(self.oracle['newGame']['flags']['op_new_adventure'])
  for row in self.cases.values():
   self.assertEqual(set(row['initial']),SAVE_KEYS)
   self.assertEqual(set(row['expected']),SAVE_KEYS)
   self.assertEqual(len(row['operations']),len(row['results']))
 def test_existing_pim_cat_dialogue_and_optional_decline_remain(self):
  self.assertEqual(self.cases['pim_accept']['expected']['quests']['kat'],{'state':'active','step':0})
  self.assertEqual(self.cases['pim_decline']['expected']['quests'],{})
  self.assertEqual(self.cases['pim_cancel_unread']['expected']['quests'],{})
  self.assertEqual(self.cases['bram_accept']['expected']['inventory']['potion'],1)
 def test_cat_finding_requires_stillness_and_original_two_seconds(self):
  found=self.cases['cat_wait_then_find']
  self.assertTrue(found['expected']['flags']['cat_found'])
  self.assertEqual(found['expected']['quests']['kat']['step'],1)
  self.assertEqual(found['cat']['calm'],2)
  self.assertEqual(self.cases['cat_calm_interrupted']['cat'],{'calm':0.0,'panic':0.0,'waiting':False})
  self.assertEqual(self.cases['cat_panic']['cat']['panic'],1.25)
 def test_existing_quest_can_be_started_by_finding_cat(self):
  row=self.cases['cat_without_quest']['expected']
  self.assertTrue(row['flags']['cat_found'])
  self.assertEqual(row['quests']['kat'],{'state':'active','step':1})
 def test_original_rewards_and_hero_level_coins_once(self):
  first=self.cases['pim_reward_once']['expected']
  self.assertEqual(first['inventory']['heart_container'],1)
  self.assertEqual(first['hero_xp'],40)
  self.assertEqual(first['coins'],0)
  level=self.cases['pim_reward_level']['expected']
  self.assertEqual(level['hero_xp'],80)
  self.assertEqual(level['coins'],15)
  self.assertEqual(self.cases['pim_max_hearts']['expected']['inventory']['heart_container'],3)
 def test_chests_keep_unique_gear_and_aggregate_full_stacks_before_coins(self):
  owned=self.cases['chest_owned_unique']['expected']
  self.assertEqual(owned['inventory']['gear_bronze_helm'],1)
  self.assertEqual(owned['inventory']['potion'],2)
  self.assertEqual(owned['coins'],25)
  full=self.cases['chest_partial_stack_refused']
  self.assertEqual(full['results'],[False])
  self.assertEqual(full['initial'],full['expected'])
  once=self.cases['chest_basic']['expected']
  self.assertEqual(once['inventory']['potion'],1)
  self.assertEqual(once['coins'],25)
 def test_gathering_uses_active_clock_and_rechecks_tool_and_level(self):
  row=self.cases['gather_active_cooldown']
  self.assertEqual(row['results'],[True,False,True,True])
  self.assertEqual(row['expected']['inventory']['prof_branch'],4)
  self.assertEqual(row['expected']['professions']['cooldowns']['prof:village:twigs_west'],190.125)
  self.assertEqual(self.cases['gather_missing_tool']['results'],[False])
  self.assertEqual(self.cases['gather_level_required']['results'],[False])
  self.assertEqual(self.cases['gather_strong_tool']['expected']['inventory']['prof_log'],3)
  self.assertEqual(self.cases['gather_xp_cap']['expected']['professions']['xp']['foraging'],1350)
 def test_rest_fills_health_without_offline_time_or_extra_day(self):
  row=self.cases['rest_no_time_skip']
  self.assertEqual(row['expected']['hp'],7)
  for key in ['play_time','day_time','day_count']:
   self.assertEqual(row['initial'][key],row['expected'][key])
 def test_pickups_keep_full_health_and_full_stacks_available(self):
  self.assertEqual(self.cases['pickup_heart_full']['results'],[False])
  self.assertEqual(self.cases['pickup_heart_hurt']['expected']['hp'],3)
  self.assertEqual(self.cases['pickup_item_full']['results'],[False])
  self.assertEqual(self.cases['pickup_coin']['expected']['coins'],1)
  crystal=self.cases['pickup_crystal']['expected']
  self.assertEqual(crystal['inventory']['crystal_bos'],1)
  self.assertTrue(crystal['flags']['pickup:forest:7'])
 def test_gear_effects_require_correct_worn_slot_and_preserve_negative_speed(self):
  rows={r['id']:r for r in self.oracle['durations']}
  self.assertEqual(set(rows),{'base','worn_pack','owned_not_worn','negative_speed'})
  self.assertEqual(rows['base']['duration'],.65)
  self.assertAlmostEqual(rows['worn_pack']['duration'],.65*.75)
  self.assertEqual(rows['worn_pack']['durationExact']['$f64'],struct.pack('<d',.65*.75).hex())
  self.assertEqual(rows['worn_pack']['magnetRange'],10)
  self.assertEqual(rows['owned_not_worn']['duration'],.65)
  self.assertEqual(rows['negative_speed']['moveSpeed'],-.08)
 def test_exact_float_witnesses_are_finite_little_endian_binary64(self):
  def verify(v):
   if isinstance(v,dict):
    if set(v)=={'$f64'}:
     raw=bytes.fromhex(v['$f64']);self.assertEqual(len(raw),8);self.assertTrue(math.isfinite(struct.unpack('<d',raw)[0]));return 1
    return sum(verify(child) for child in v.values())
   if isinstance(v,list):return sum(verify(child) for child in v)
   return 0
  self.assertGreater(verify(self.oracle),100)
 def test_actual_source_methods_and_uuid_isolation_are_explicit(self):
  methods=set(self.oracle['sourceMethods'])
  self.assertIn('scripts/core/professions.gd::gather',methods)
  self.assertIn('scripts/entities/chest.gd::interact',methods)
  self.assertIn('scripts/entities/pickup.gd::_collect',methods)
  recorder=(ROOT/'tools/record_migration_route.py').read_text()
  exporter=(ROOT/'tools/migration_route_export.gd').read_text()
  for needle in ['uuid.uuid4()','Exact UUID isolation','fingerprint(ROOT) != before','for number in (1, 2)','Never overwrite an existing oracle']:
   self.assertIn(needle,recorder)
  for needle in ['Prof.gather(o[1],o[2])','chest.interact()','pickup._collect()','CatUpdate.update(cat','gs.run_all','Bluemap-Codex-Tests-']:
   self.assertIn(needle,exporter)

if __name__=='__main__':unittest.main()
