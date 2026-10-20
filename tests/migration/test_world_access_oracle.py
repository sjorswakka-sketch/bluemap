"""Source observations for real area locks, safe arrivals, keys, tides and free boats."""
import json
import math
from pathlib import Path
import struct
import unittest

ROOT=Path(__file__).resolve().parents[2]
CASE_IDS={"world_legacy_migrations","world_migrations_idempotent","gate_no_key","gate_key","gate_open_not_interactable","conditions_fresh","conditions_iron_main","conditions_both_targets","boat_distance_0","boat_distance_6400","boat_distance_6401","boat_forged_target","seal_unearned","seal_earned_timing","tide_occupied_then_released"}
SAVE_KEYS={"version","map","pos","hp","coins","inventory","flags","quests","weapon","visited_maps","play_time","kills","meer","day_time","day_count","kills_by","rolls","potions_drunk","deaths","boss_deaths","talked","achievements","arena_records","homestead","coastal_storage","stockroom","personal_home","yard","professions","hero_xp","equipment","appearance","clothing","ng_plus"}

class WorldAccessOracleTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.path=ROOT/'migration/phase-11/world-access-oracle.json'
  cls.oracle=json.loads(cls.path.read_text(encoding='utf-8'))
  cls.cases={row['id']:row for row in cls.oracle['cases']}
  cls.fresh={row['map']:row for row in cls.oracle['snapshots'] if row['scenario']=='fresh_baseline'}
 def test_exact_loaded_source_coverage(self):
  self.assertEqual(self.oracle['schema'],'bluemap.world-access.source-oracle.v1')
  self.assertIs(self.oracle['personalSavesUsed'],False)
  self.assertIs(self.oracle['freshProcessRequired'],True)
  self.assertEqual(self.oracle['failures'],[])
  rows=self.oracle['snapshots']
  self.assertEqual(len(rows),162)
  self.assertEqual(len(self.fresh),37)
  self.assertEqual(len({r['scenario'] for r in rows}),59)
  self.assertEqual(sum(len(r['arrivals']) for r in rows),593)
  self.assertEqual(sum(len(r['probes']) for r in rows),1062)
  self.assertEqual(set(self.cases),CASE_IDS)
 def test_runtime_reference_has_identical_bytes(self):
  self.assertEqual(self.path.read_bytes(),(ROOT/'unity/Assets/BlueMapWorldAccess/Runtime/Model/Resources/BlueMapWorldAccessOracle.json').read_bytes())
 def test_every_snapshot_and_action_retains_all34_original_fields(self):
  for row in self.oracle['snapshots']:
   self.assertEqual(set(row['state']),SAVE_KEYS)
   self.assertEqual(set(row['stateExact']),SAVE_KEYS)
  for row in self.cases.values():
   for key in ['initial','expected','initialExact','expectedExact']:
    self.assertEqual(set(row[key]),SAVE_KEYS)
 def test_all_original_arrivals_are_safe_and_unique(self):
  for row in self.oracle['snapshots']:
   self.assertEqual(len(row['arrivals']),len({r['name'] for r in row['arrivals']}))
   for arrival in row['arrivals']:
    self.assertIs(arrival['fits'],True)
    self.assertTrue(all(math.isfinite(v) for v in arrival['resolved']))
 def test_every_area_has_a_source_connection_and_return_route(self):
  graph={key:set() for key in self.fresh}
  for map_id,row in self.fresh.items():
   graph[map_id].update(p['to'] for p in row['portals'])
   # The original coastal workshop has an interactive travel_link door instead of a portal.
   source=json.loads((ROOT/'migration/world/snapshots/fresh_baseline'/f'{map_id}.json').read_text())
   objects=next(value for key,value in source['mapData']['entries'] if key['value']=='objects')['values']
   for entry in objects:
    fields={key['value']:value for key,value in entry['entries']}
    if fields.get('travel_link',{}).get('value') is True and fields.get('enabled',{}).get('value',True):
     graph[map_id].add(fields['to']['value'])
   for boat in row['boats']:
    spec=boat['spec']
    graph[map_id].update(route['to'] for route in spec.get('routes',[]))
    if 'to' in spec:graph[map_id].add(spec['to'])
  for origin in graph:
   found={origin};pending=[origin]
   while pending:
    for target in graph[pending.pop()]:
     self.assertIn(target,graph)
     if target not in found:found.add(target);pending.append(target)
   self.assertEqual(found,set(graph),origin)
 def test_locks_remain_closed_without_earned_source_conditions(self):
  locked=[p for row in self.fresh.values() for p in row['portals'] if p['requires'] and not p['available']]
  self.assertGreaterEqual(len(locked),9)
  self.assertTrue(all(p['lockedText'] for p in locked))
  arena=next(p for p in self.fresh['village']['portals'] if p['to']=='arena_hall')
  self.assertFalse(arena['available'])
  depths=next(p for p in self.fresh['temple']['portals'] if p['to']=='depths1')
  self.assertEqual(depths['requires'],[['flag','game_completed'],['flag','diepte_opened']])
  self.assertFalse(depths['available'])
 def test_gate_consumes_only_one_existing_key_and_open_gate_leaves_interactables(self):
  missing=self.cases['gate_no_key'];self.assertFalse(missing['result']);self.assertEqual(missing['initial'],missing['expected'])
  opened=self.cases['gate_key'];self.assertTrue(opened['result']);self.assertEqual(opened['expected']['inventory']['ruin_key'],1);self.assertTrue(opened['expected']['flags']['gate_ruin'])
  twice=self.cases['gate_open_not_interactable'];self.assertFalse(twice['result']);self.assertEqual(twice['initial'],twice['expected'])
 def test_free_boats_have_source_distance_limit_and_do_not_change_items_or_hp(self):
  for case in ['boat_distance_0','boat_distance_6400']:
   self.assertTrue(self.cases[case]['result'])
  for case in ['boat_distance_6401','boat_forged_target']:
   self.assertFalse(self.cases[case]['result'])
  for case in ['boat_distance_0','boat_distance_6400','boat_distance_6401','boat_forged_target']:
   self.assertEqual(self.cases[case]['initial'],self.cases[case]['expected'])
 def test_seal_requires_earned_completion_and_actual_delay_before_original_quest(self):
  row=self.cases['seal_unearned'];self.assertEqual(row['result'],[False,False]);self.assertEqual(row['initial'],row['expected'])
  row=self.cases['seal_earned_timing'];self.assertEqual(row['result'],[[True,False],[True,False],[True,False],[True,True]])
  self.assertTrue(row['expected']['flags']['diepte_opened'])
  self.assertEqual(row['expected']['quests']['diepte'],{'state':'active','step':1})
 def test_tide_does_not_flood_an_occupied_bank(self):
  row=self.cases['tide_occupied_then_released'];self.assertEqual(row['result'],[[False,True],[True,False]])
  self.assertEqual(row['expected']['pos'],[1040,816])
 def test_legacy_migrations_only_restore_already_earned_world_changes(self):
  row=self.cases['world_legacy_migrations']
  for flag in ['lw_heat_west','lw_heat_east','lw_heat','lw_drained','lw_bridge','ra_spring','rf_memorial']:
   self.assertTrue(row['expected']['flags'][flag])
  self.assertFalse(row['expected']['flags']['lw_sluice_east'])
  for key in SAVE_KEYS-{'flags','quests'}:self.assertEqual(row['initial'][key],row['expected'][key])
  row=self.cases['world_migrations_idempotent'];self.assertEqual(row['initial'],row['expected'])
 def test_ring_order_is_original_and_complete_for_all_eight_search_radii(self):
  self.assertEqual(len(self.oracle['rings']),8)
  for radius,ring in enumerate(self.oracle['rings'],1):
   self.assertEqual(len(ring),radius*8)
   self.assertEqual(len({tuple(v) for v in ring}),len(ring))
   self.assertTrue(all(max(abs(v[0]),abs(v[1]))==radius for v in ring))
   self.assertEqual(ring[0],[0,radius])
 def test_exact_binary64_witnesses_are_complete_and_finite(self):
  def count(value):
   if isinstance(value,dict):
    if set(value)=={'$f64'}:
     raw=bytes.fromhex(value['$f64']);self.assertEqual(len(raw),8);self.assertTrue(math.isfinite(struct.unpack('<d',raw)[0]));return 1
    return sum(count(v) for v in value.values())
   if isinstance(value,list):return sum(count(v) for v in value)
   return 0
  self.assertEqual(count(self.oracle),1584)
 def test_recorder_uses_actual_source_methods_in_two_isolated_processes(self):
  self.assertEqual(len(self.oracle['sourceMethods']),16)
  recorder=(ROOT/'tools/record_migration_world_access.py').read_text()
  exporter=(ROOT/'tools/migration_world_access_export.gd').read_text()
  for needle in ['uuid.uuid4()','Exact UUID isolation','fingerprint(ROOT) != before','for number in (1, 2)','Never overwrite an existing oracle']:
   self.assertIn(needle,recorder)
  for needle in ['world.spawn_fits','world.safe_spawn_position','gate.interact()','seal._process(delta)','child.sync()','voyage.valid_source()','Bluemap-Codex-Tests-']:
   self.assertIn(needle,exporter)

if __name__=='__main__':unittest.main()
