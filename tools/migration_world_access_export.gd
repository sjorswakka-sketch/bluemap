extends "res://tools/migration_world_export.gd"
## Executes the unchanged original world/gates/portals/voyage methods in an isolated project.
var output_path:=""
var access_rows:Array=[]
var behavior:Array=[]
func plain(v:Variant)->Variant:
 if v is Vector2 or v is Vector2i:return [v.x,v.y]
 if v is Dictionary:
  var out:Dictionary={}
  for key:Variant in v:out[str(key)]=plain(v[key])
  return out
 if v is Array:
  var out:Array=[]
  for child:Variant in v:out.append(plain(child))
  return out
 return v
func exact(v:Variant)->Variant:
 if v is float:return {"$f64":PackedFloat64Array([v]).to_byte_array().hex_encode()}
 if v is Dictionary:
  var out:Dictionary={}
  for key:Variant in v:out[str(key)]=exact(v[key])
  return out
 if v is Array:
  var out:Array=[]
  for child:Variant in v:out.append(exact(child))
  return out
 return v
func save_state()->Dictionary:
 var out:Dictionary=state();out.map=out.map_id;out.erase("map_id");out.erase("spawn_name");out.pos=[world.player.position.x,world.player.position.y];out.version=1
 out.talked=gs.talked.keys();out.achievements=gs.achievements.keys()
 return plain(out)
func access_snapshot(scenario:Dictionary)->Dictionary:
 var portals:Array=[];var gates:Array=[];var boats:Array=[];var samples:Array=[];var arrivals:Array=[]
 for child:Node in world.entities.get_children():
  var path:=script_path(child)
  if path=="res://scripts/entities/portal.gd":portals.append({"to":child.target_map,"spawn":child.target_spawn,"rect":plain([child.rect.position,child.rect.size]),"requires":plain(child.conditions),"available":child.available(),"lockedText":child.locked_text})
  if path in ["res://scripts/entities/gate.gd","res://scripts/entities/diepte_gate.gd"]:gates.append({"id":child.gate_id,"blocked":child.blocked,"block_if":plain(child.block_if),"key":child.key_item,"position":plain(child.position)})
  if path in ["res://scripts/entities/coast_dock.gd","res://scripts/entities/tide_station.gd"]:boats.append({"position":plain(child.position),"spec":plain(child.obj)})
 for name:String in world.map_data.spawns:
  var at:Vector2=world._tile_center(world.map_data.spawns[name])
  if gs.map_id=="village" and name=="start" and gs.play_time<1 and preload("res://scripts/core/opening.gd").enabled():at+=Vector2(0,48)
  var before:Vector2=world._safe_fountain_spawn(preload("res://scripts/core/regional_adventures.gd").safe_position(gs.map_id,at))
  if gs.map_id=="player_home" and preload("res://scripts/core/personal_home.gd").player_reason(preload("res://scripts/core/personal_home.gd").state().layout,before)!="":before=Vector2(6.5,10.5)*32
  arrivals.append({"name":name,"nominal":plain(at),"prepared":plain(before),"resolved":plain(world.safe_spawn_position(before)),"fits":world.spawn_fits(world.safe_spawn_position(before))})
 var requested:Array[Vector2]=[Vector2(-5,-5),Vector2(0,0),Vector2(world.map_size)*32+Vector2(5,5),world.player.position]
 for portal:Dictionary in portals:requested.append(Vector2(portal.rect[0][0],portal.rect[0][1])+Vector2(portal.rect[1][0],portal.rect[1][1])*0.5)
 for gate:Dictionary in gates:requested.append(Vector2(gate.position[0],gate.position[1]))
 for at:Vector2 in requested:samples.append({"requested":plain(at),"fits":world.spawn_fits(at),"resolved":plain(world.safe_spawn_position(at))})
 return {"map":gs.map_id,"scenario":scenario.id,"state":save_state(),"stateExact":exact(save_state()),"portals":portals,"gates":gates,"boats":boats,"arrivals":arrivals,"probes":samples}
func add_case(id:String,initial:Dictionary,operation:Dictionary,result:Variant):
 behavior.append({"id":id,"initial":initial,"initialExact":exact(initial),"operation":operation,"operationExact":exact(operation),"result":plain(result),"resultExact":exact(plain(result)),"expected":save_state(),"expectedExact":exact(save_state())})
func probe_migrations():
 Scenarios.configure("legacy_completed");gs.map_id="coast"
 var before:=save_state()
 for path:String in ["living_world","regional_adventures","first_route"]:load("res://scripts/core/"+path+".gd").migrate()
 add_case("world_legacy_migrations",before,{"kind":"migrations"},true)
 before=save_state()
 for path:String in ["living_world","regional_adventures","first_route"]:load("res://scripts/core/"+path+".gd").migrate()
 add_case("world_migrations_idempotent",before,{"kind":"migrations"},true)
func probe_behaviors():
 # State is reset between every case; only original entity methods perform mutations.
 for has_key:bool in [false,true]:
  Scenarios.configure("fresh_baseline");gs.map_id="forest";gs.inventory={"ruin_key":2} if has_key else {}
  var gate:Node=load("res://scripts/entities/gate.gd").new();gate.gate_id="ruin";gate.key_item="ruin_key";gate.block_if=[["no_flag","gate_ruin"]];root.add_child(gate)
  var before:=save_state();gate.interact();gate._refresh(true)
  add_case("gate_key" if has_key else "gate_no_key",before,{"kind":"gate","fields":{"gate_id":"ruin","key_item":"ruin_key","block_if":[["no_flag","gate_ruin"]]}},not gate.blocked)
  gate.free()
 Scenarios.configure("fresh_baseline");gs.map_id="forest";gs.flags.gate_ruin=true;gs.inventory={"ruin_key":1}
 var gate:Node=load("res://scripts/entities/gate.gd").new();gate.gate_id="ruin";gate.key_item="ruin_key";gate.block_if=[["no_flag","gate_ruin"]];root.add_child(gate)
 var before:=save_state()
 # The source removes open gates from interactables. A direct second method call would still consume a key; normal selection never calls it.
 add_case("gate_open_not_interactable",before,{"kind":"gate_visibility","fields":{"gate_id":"ruin","key_item":"ruin_key","block_if":[["no_flag","gate_ruin"]]}},gate.is_in_group("interactable"));gate.free()
 var condition_sets:Array=[{"id":"conditions_fresh","weapon":"wood","flags":{},"quests":{}},{"id":"conditions_iron_main","weapon":"iron","flags":{"boog_bos_a":true,"arena_signed_bronze":true},"quests":{"main":{"state":"active","step":0}}},{"id":"conditions_both_targets","weapon":"crystal","flags":{"boog_bos_a":true,"boog_bos_b":true},"quests":{"main":{"state":"done","step":2}}}]
 for spec:Dictionary in condition_sets:
  Scenarios.configure("fresh_baseline");gs.weapon=spec.weapon;gs.flags=spec.flags;gs.quests=spec.quests
  var conditions:Array=[["boog_missing","boog_bos_a","boog_bos_b"],["echo_ready"],["arena_open"],["arena_registered"],["arena_fight"],["arena_free"]]
  var result:Array=[]
  for condition:Array in conditions:result.append(gs.check(condition))
  add_case(spec.id,save_state(),{"kind":"conditions","conditions":conditions},result)
 # Original free voyage source eligibility, including distance and route membership.
 Scenarios.configure("fresh_baseline");gs.map_id="coast";gs.transitioning=false;gs.ended=false
 var voyage:Node=get_first_node_in_group("coast_voyage")
 for dock:Node in world.entities.get_children():
  if script_path(dock)!="res://scripts/entities/coast_dock.gd":continue
  voyage.source=weakref(dock);voyage.from_map="coast";voyage.target=dock.obj.to;voyage.spawn=dock.obj.spawn
  for distance:float in [0.0,64.0,64.01]:
   world.player.position=dock.position+Vector2(distance,0)
   add_case("boat_distance_"+str(int(distance*100)),save_state(),{"kind":"boat","sourceMap":"coast","sourcePosition":plain(dock.position),"playerPosition":plain(world.player.position),"spec":plain(dock.obj),"to":voyage.target,"spawn":voyage.spawn},voyage.valid_source())
  world.player.position=dock.position;voyage.target="temple"
  add_case("boat_forged_target",save_state(),{"kind":"boat","sourceMap":"coast","sourcePosition":plain(dock.position),"playerPosition":plain(world.player.position),"spec":plain(dock.obj),"to":"temple","spawn":voyage.spawn},voyage.valid_source())
  break
func probe_seals():
 var seal:Node=null
 for child:Node in world.entities.get_children():
  if script_path(child)=="res://scripts/entities/diepte_seal.gd":seal=child;break
 require(seal!=null,"Original temple seal missing")
 if seal==null:return
 var center:Vector2=seal.global_position+seal._center_offset();world.player.position=center
 var before:=save_state();seal._process(10.0)
 add_case("seal_unearned",before,{"kind":"seal","center":plain(center),"playerPosition":plain(center),"deltas":[10.0]},[seal.breaking,gs.flag("diepte_opened")])
 gs.flags.game_completed=true;before=save_state()
 var results:Array=[]
 for delta:float in [0.01,0.9,0.89,0.02]:seal._process(delta);results.append([seal.breaking,gs.flag("diepte_opened")])
 add_case("seal_earned_timing",before,{"kind":"seal","center":plain(center),"playerPosition":plain(center),"deltas":[0.01,0.9,0.89,0.02]},results)
func probe_tide():
 for child:Node in world.ground.get_children():
  if script_path(child)!="res://scripts/entities/tide_cove.gd":continue
  world.player.position=Vector2(25.5,25.5)*32;var before:=save_state();var states:Array=[]
  gs.day_time=70.0/480.0;child.sync();states.append([child.flooded,child.held])
  world.player.position=Vector2(32.5,25.5)*32;child.sync();states.append([child.flooded,child.held])
  add_case("tide_occupied_then_released",before,{"kind":"tide","dayTime":gs.day_time,"positions":[[816,816],[1040,816]]},states);break
func _run()->void:
 for i:int in OS.get_cmdline_user_args().size():
  if OS.get_cmdline_user_args()[i]=="--output" and i+1<OS.get_cmdline_user_args().size():output_path=OS.get_cmdline_user_args()[i+1]
 require(OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"),"Unverified isolated profile")
 require(output_path!="","Output path required")
 if not failures.is_empty():quit(1);return
 root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.set_process(false)
 for scenario:Dictionary in Scenarios.manifest():
  for map_id:String in scenario.maps:
   Scenarios.configure(scenario.id);gs.map_id=map_id;gs.spawn_name="start";gs.use_load_pos=false
   seed(Scenarios.FIXTURE_SEED+hash(scenario.id+":"+map_id))
   world=load("res://scenes/main.tscn").instantiate();world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world);current_scene=world;_freeze(world)
   await process_frame;_freeze(world);Scenarios.project(world);_freeze(world);await process_frame;_freeze(world);await process_frame;_freeze(world)
   access_rows.append(access_snapshot(scenario))
   if scenario.id=="fresh_baseline" and map_id=="coast":probe_migrations();probe_behaviors()
   if scenario.id=="fresh_baseline" and map_id=="temple":probe_seals()
   if scenario.id=="tide_low":probe_tide()
   world.free();world=null;await process_frame
 var source_methods:Array=["world.spawn_fits","world.safe_spawn_position","portal.available","gate.interact","gate._refresh","GameState.check","coast_voyage.valid_source","living_scenery.refresh","tide_cove.sync","meer_kast._clear_cells","diepte_seal._process","diepte_seal._open","fast_travel._ring","living_world.migrate","regional_adventures.migrate","first_route.migrate"]
 var rings:Array=[]
 for radius:int in range(1,9):rings.append(plain(load("res://scripts/core/fast_travel.gd")._ring(radius)))
 write_json(output_path,{"rings":rings,"quests":plain(preload("res://scripts/data/quests.gd").QUESTS),"schema":"bluemap.world-access.source-oracle.v1","tilePixels":32,"personalSavesUsed":false,"freshProcessRequired":true,"snapshots":access_rows,"cases":behavior,"sourceMethods":source_methods,"failures":failures})
 print("MIGRATION WORLD ACCESS EXPORT OK" if failures.is_empty() else "MIGRATION WORLD ACCESS EXPORT FAILED");quit(0 if failures.is_empty() else 1)

