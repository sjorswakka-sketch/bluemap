extends "res://tools/migration_inventory_export.gd"
## Original actor/helper/projectile methods, with deterministic isolated fixture inputs.
const Foes=preload("res://scripts/data/enemies.gd")
var Projectile:Script
var Arrow:Script
var Pillar:Script
var Shard:Script
class Hero extends DummyPlayer:
 var light:=PointLight2D.new()
 var hits:Array=[]
 var knockback:=Vector2.ZERO
 func _init():add_child(light);light.enabled=true;light.energy=1
 func hurt(from:Vector2,damage:int,source:String):hits.append([from,damage,source])
class Arena extends Node2D:
 const TILE:=32.0
 var player:=Hero.new()
 var ground:=Node2D.new()
 var entities:=Node2D.new()
 var darkness:=0.0
 var map_data:Dictionary={"spawns":{},"objects":[],"rows":[]}
 var shots:Array=[]
 var drops:Array=[]
 var cover:=Rect2(-100,-100,1,1)
 func _init():
  add_child(ground);add_child(entities);entities.add_child(player)
  for i in 64:map_data.rows.append(".".repeat(64))
 func is_solid(at:Vector2)->bool:return cover.has_point(at)
 func clamp_to_map(at:Vector2)->Vector2:return at.clamp(Vector2(32,32),Vector2(2000,2000))
 func spawn_projectile(kind:String,at:Vector2,direction:Vector2,speed:float,damage:int,source:String):shots.append([kind,at,direction,speed,damage,source])
 func spawn_pickup(item:String,at:Vector2,_key:String="",_magnetic:bool=false):drops.append([item,at])
 func spawn_enemy(kind:String,at:Vector2,_flag:String=""):
  var foe=load("res://scripts/entities/guardian.gd").new() if kind=="guardian" else load("res://scripts/entities/enemy.gd").new();foe.world=self
  if kind!="guardian":foe.setup(kind)
  foe.position=at;entities.add_child(foe);foe.set_physics_process(false);return foe
 func burst(_at:Vector2,_color:Color,_count:int):pass
 func ring(_at:Vector2,_radius:float,_color:Color):pass
 func damage_number(_at:Vector2,_text:String,_color:Color):pass
 func shake(_value:float):pass
 func hitstop(_value:float):pass
var arena:Arena
var encounter_cases:Array=[]
var recorded_deaths:=0
var fixture_mode:=""
func actor_state(e:Node)->Dictionary:
 var result:Dictionary={}
 var properties:Array=[]
 for property:Dictionary in e.get_property_list():properties.append(property.name)
 for key:String in ["kind","hp","max_hp","state","state_time","active","dead","desired","aim_dir","knockback","guard_broken","panic","fleeing","air_height","hop_count","hop_cooldown","special_timer","ad_combo","ad_radius","habitat_length","habitat_traveled","habitat_hit","phase","shift_to","dash_left","line_length","last_attack","repeat_count","volley_timer"]:
  if key in properties:result[key]=e.get(key)
 result["shots"]=arena.shots.duplicate(true);result["hits"]=arena.player.hits.duplicate(true)
 if fixture_mode!="":
  var counts:Dictionary={}
  for drop:Array in arena.drops:counts[drop[0]]=int(counts.get(drop[0],0))+1
  result["drop_counts"]=counts;result["kill_events"]=recorded_deaths;result["unique_claimed"]=gs.flag("fixture_unique")
 return _plain(result)
func ai_step(e:Node,delta:float):
 if e.kind=="guardian":e._physics_process(delta);return
 e.state_time+=delta;e.desired=Vector2.ZERO
 match e.data.behavior:
  "cv_ram","cv_slinger":load("res://scripts/entities/combat_enemy.gd").update(e,delta)
  "rf_ambush","rf_listen":load("res://scripts/entities/route_enemy.gd").update(e,delta)
  "lw_guard","lw_flank","lw_support":load("res://scripts/entities/living_enemy.gd").update(e,delta)
  "echo_charge","echo_volley":load("res://scripts/entities/echo_enemy.gd").update(e,delta)
  "hb_root","hb_moth":load("res://scripts/entities/habitat_enemy.gd").update(e,delta)
  "ad_crab","ad_wisp","ad_keeper":load("res://scripts/entities/coastal_enemy.gd").update(e,delta)
  "chase":e._ai_chase(delta)
  "bat":e._ai_bat(delta)
  "archer":e._ai_archer(delta)
  "mage":e._ai_mage(delta)
  "spitter":e._ai_spitter(delta)
  "golem":e._ai_golem(delta)
  "king":e._ai_king(delta)
  "animal":e._ai_animal(delta)
func actor_case(id:String,kind:String,overrides:Dictionary,ops:Array):
 overrides=overrides.duplicate(true)
 if kind!="guardian":overrides["wander_timer"]=5.0;overrides["wander_dir"]=Vector2.ZERO
 fixture_mode=str(overrides.get("mode",""));recorded_deaths=0
 gs.new_game();gs.set_process(false);gs.map_id="forest";gs.flags["vijanden_hint_"+kind]=true
 arena=Arena.new();root.add_child(arena);arena.player.position=Vector2(550,500);arena.player.add_to_group("player")
 seed(142041);var e=arena.spawn_enemy(kind,Vector2(500,500));e.player=arena.player;e.state_time=0;e.anim=0;e.t=0;e.data=e.data.duplicate(true)
 for key:String in overrides:
  if key=="mode":
   e.died.connect(func():recorded_deaths+=1)
   e.unique_flag="fixture_unique"
   if overrides[key]=="practice":e.set_meta("practice",true)
   var controlled:Array=[]
   for drop:Array in e.data.drops:controlled.append([drop[0],1.0,drop[2]])
   e.data["drops"]=controlled
  elif key=="player":arena.player.position=Vector2(overrides[key][0],overrides[key][1])
  elif key=="noisy":arena.player.sprinting=overrides[key]
  elif key=="cover":arena.cover=Rect2(Vector2(overrides[key][0],overrides[key][1]),Vector2(overrides[key][2],overrides[key][3]))
  else:e.set(key,overrides[key])
 var initial:Dictionary=actor_state(e);var results:Array=[]
 for op:Array in ops:
  match op[0]:
   "ai":ai_step(e,float(op[1]))
   "hurt":e.hurt(int(op[1]),Vector2(op[2][0],op[2][1]))
   "break_guard":e.break_guard()
  results.append(actor_state(e))
 encounter_cases.append({"id":id,"kind":kind,"fixture":_plain(overrides),"fixtureExact":_exact(_plain(overrides)),"fixtureOrdered":ordered_input(_plain(overrides)),"initial":initial,"initialExact":_exact(initial),"initialOrdered":ordered_input(initial),"operations":ops,"operationsExact":_exact(ops),"operationsOrdered":ordered_input(ops),"results":results,"resultsExact":_exact(results),"expected":actor_state(e),"expectedExact":_exact(actor_state(e))})
 arena.free();arena=null
func projectile_case(id:String,kind:String,cover:Rect2,player_at:Vector2,ops:Array):
 gs.new_game();gs.set_process(false);arena=Arena.new();root.add_child(arena);arena.cover=cover;arena.player.position=player_at
 var projectile=Arrow.new() if kind=="player_arrow" else Shard.new() if kind=="guardian_shard" else Projectile.new();projectile.world=arena;projectile.position=Vector2(500,500)
 if kind=="player_arrow":projectile.direction=Vector2.RIGHT
 else:
  if kind!="guardian_shard":projectile.kind=kind
  projectile.velocity=Vector2(150,0);projectile.player=arena.player;projectile.source="fixture"
 arena.entities.add_child(projectile);projectile.set_process(false);projectile.set_physics_process(false)
 var initial:Dictionary={"position":[500,500],"age":0.0,"dead":false};var results:Array=[]
 for op:Array in ops:
  if op[0]=="step":
   if kind=="player_arrow":projectile._physics_process(float(op[1]))
   else:projectile._process(float(op[1]))
  elif op[0]=="launch":projectile.launch(float(op[1]))
  elif op[0]=="sword":projectile.sword_hit(Vector2(op[1][0],op[1][1]),Vector2(op[2][0],op[2][1]),float(op[3]))
  results.append(_plain({"position":projectile.position,"dead":projectile.is_queued_for_deletion(),"state":projectile.state if kind=="player_arrow" else "flying","age":0.0 if kind=="player_arrow" else projectile.age,"traveled":projectile.traveled if kind=="player_arrow" else 0.0,"hits":arena.player.hits}))
 var fixture:Dictionary={"cover":[cover.position.x,cover.position.y,cover.size.x,cover.size.y],"player":[player_at.x,player_at.y]}
 encounter_cases.append({"id":id,"kind":kind,"projectile":true,"fixture":fixture,"fixtureExact":_exact(fixture),"fixtureOrdered":ordered_input(fixture),"initial":initial,"initialExact":_exact(initial),"initialOrdered":ordered_input(initial),"operations":ops,"operationsExact":_exact(ops),"operationsOrdered":ordered_input(ops),"results":results,"resultsExact":_exact(results),"expected":results.back(),"expectedExact":_exact(results.back())})
 arena.free();arena=null
func pillar_state(p:Node)->Dictionary:
 var shards:Array=[]
 for child:Node in arena.entities.get_children():
  if child.get_script()==Shard:shards.append([child.position,child.velocity,child.damage])
 return _plain({"angles":p.angles,"windup":p.windup,"windup_total":p.windup_total,"rings_left":p.rings_left,"ring_wait":p.ring_wait,"shard_speed":p.shard_speed,"charging":p.charging,"flash":p.flash,"shards":shards})
func pillar_case(id:String,ops:Array):
 gs.new_game();gs.set_process(false);arena=Arena.new();root.add_child(arena)
 var p=Pillar.new();p.world=arena;p.position=Vector2(500,500);arena.entities.add_child(p);p.set_process(false)
 var initial:Dictionary=pillar_state(p);var results:Array=[]
 for op:Array in ops:
  match op[0]:
   "begin":
    var angles:Array[float]=[]
    for angle:float in op[1]:angles.append(angle)
    p.begin_volley(angles,float(op[2]),float(op[3]),float(op[4]),int(op[5]))
   "step":p._process(float(op[1]))
   "cancel":p.cancel()
  results.append(pillar_state(p))
 var fixture:Dictionary={}
 encounter_cases.append({"id":id,"kind":"guardian_pillar","component":"pillar","fixture":fixture,"fixtureExact":_exact(fixture),"fixtureOrdered":ordered_input(fixture),"initial":initial,"initialExact":_exact(initial),"initialOrdered":ordered_input(initial),"operations":ops,"operationsExact":_exact(ops),"operationsOrdered":ordered_input(ops),"results":results,"resultsExact":_exact(results),"expected":results.back(),"expectedExact":_exact(results.back())})
 arena.free();arena=null
func _run():
 var output:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():output=args[i+1]
 if output=="" or FileAccess.file_exists(output) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe encounter export");quit(1);return
 gs=root.get_node("GameState");gs.set_process(false)
 Projectile=load("res://scripts/entities/projectile.gd");Arrow=load("res://scripts/entities/arrow.gd");Pillar=load("res://scripts/entities/guardian_pillar.gd");Shard=load("res://scripts/entities/guardian_shard.gd")
 for kind:String in Foes.ENEMIES:
  if kind=="guardian":continue
  actor_case("hurt-"+kind,kind,{"active":true},[["hurt",1,[1,0]]])
  actor_case("inactive-"+kind,kind,{"active":false},[["hurt",1,[1,0]]])
  actor_case("death-"+kind,kind,{"active":true,"guard_broken":2.0,"mode":"lethal"},[["hurt",1000,[1,0]],["hurt",1000,[1,0]]])
  actor_case("practice-"+kind,kind,{"active":true,"guard_broken":2.0,"mode":"practice"},[["hurt",1000,[1,0]]])
 for kind:String in ["slime","slime_blue","slime_red","slime_mini"]:actor_case("chase-"+kind,kind,{},[["ai",0.1]])
 var families:Dictionary={}
 for kind:String in Foes.ENEMIES:
  var behavior:String=Foes.ENEMIES[kind].behavior
  if behavior=="guardian" or families.has(behavior):continue
  families[behavior]=kind
 for behavior:String in families:
  var kind:String=families[behavior]
  var ov:Dictionary={"state_time":3.0,"player":[550,500]}
  if behavior.begins_with("ad_"):ov["player"]=[550,500]
  if behavior=="hb_moth":ov["state"]="hb_moth_warn";ov["habitat_length"]=60.0;ov["habitat_origin"]=Vector2(500,508)
  actor_case("acquire-"+behavior,kind,ov,[["ai",0.01]])
 for row:Array in [["bat","telegraph",0.36],["skeleton","aim",0.56],["slime_spitter","windup",1.1],["mage","cast",2.0],["golem","windup",1.0]]:
  actor_case("commit-"+row[0],row[0],{"state":row[1],"aim_dir":Vector2.RIGHT},[["ai",row[2]]])
 for behavior:String in families:
  if behavior not in ["cv_ram","cv_slinger","rf_ambush","rf_listen","lw_flank","echo_charge","echo_volley","hb_root","hb_moth","ad_crab","ad_wisp","ad_keeper"]:continue
  var warned:String="cv_warn" if behavior.begins_with("cv_") else "rf_warn" if behavior.begins_with("rf_") else "lw_warn" if behavior=="lw_flank" else "echo_warn" if behavior.begins_with("echo_") else "hb_root_warn" if behavior=="hb_root" else "hb_moth_warn" if behavior=="hb_moth" else "ad_warn"
  actor_case("commit-"+behavior,families[behavior],{"state":warned,"aim_dir":Vector2.RIGHT,"habitat_origin":Vector2(500,508),"habitat_length":60.0,"ad_origin":Vector2(500,500)},[["ai",1.2]])
 actor_case("guard-front","lw_warden",{"aim_dir":Vector2.RIGHT},[["hurt",1,[-1,0]],["break_guard"],["hurt",1,[-1,0]]])
 actor_case("guardian-protected-waking","guardian",{"active":true,"state":"waking"},[["hurt",5,[1,0]],["ai",1.81]])
 actor_case("guardian-protected-shift","guardian",{"active":true,"state":"phase_shift","shift_to":2},[["hurt",5,[1,0]],["ai",1.81]])
 actor_case("guardian-charge-lock","guardian",{"active":true,"state":"charge_windup","state_time":0.5,"aim_dir":Vector2.RIGHT,"line_length":160.0},[["ai",0.21]])
 actor_case("guardian-slam","guardian",{"active":true,"state":"slam_windup"},[["ai",0.65]])
 actor_case("guardian-next-phase","guardian",{"active":true,"state":"idle","hp":2},[["hurt",1,[1,0]]])
 actor_case("guardian-recover","guardian",{"active":true,"state":"stunned"},[["ai",1.61]])
 for kind:String in ["arrow","rock","slimeball","arcane_orb","prism_spark","cv_thorn","guardian_shard"]:
  projectile_case("projectile-flight-"+kind,kind,Rect2(-100,-100,1,1),Vector2(700,500),[["step",0.02],["step",0.02]])
  projectile_case("projectile-wall-"+kind,kind,Rect2(501,490,30,20),Vector2(700,500),[["step",0.02]])
  if kind in Projectile.TRAITS:projectile_case("projectile-sword-"+kind,kind,Rect2(-100,-100,1,1),Vector2(700,500),[["sword",[480,500],[1,0],34.0]])
 projectile_case("arrow-launch-cover","player_arrow",Rect2(504,490,20,20),Vector2(700,500),[["launch",12.0]])
 projectile_case("arrow-flight-range","player_arrow",Rect2(-100,-100,1,1),Vector2(1500,1500),[["step",0.025],["step",0.025]])
 pillar_case("pillar-single-ring",[["begin",[0.0,PI/2],PI/8,0.85,118.0,1],["step",0.4],["step",0.46]])
 pillar_case("pillar-rage-two-rings",[["begin",[0.0,PI/2],PI/8,0.75,135.0,2],["step",0.76],["step",0.71]])
 pillar_case("pillar-cancel",[["begin",[0.0,PI/2],PI/8,0.75,135.0,2],["step",0.4],["cancel"],["step",1.0]])
 var catalogs:Dictionary={"enemies":_plain(Foes.ENEMIES),"projectileTraits":_plain(Projectile.TRAITS)}
 var report:Dictionary={"schema":"bluemap.encounter.source-oracle.v1","engineVersion":Engine.get_version_info().string,"personalSavesUsed":false,"float64Encoding":"ieee754-binary64-little-endian-hex","orderedInputEncoding":"dictionary-pairs-and-exact-f64-v1","catalogs":catalogs,"catalogsExact":_exact(catalogs),"catalogsOrdered":ordered_input(catalogs),"cases":encounter_cases,"families":families,"fixturePolicy":{"wander":"Explicit zero wander_dir and five-second wander_timer isolate AI decisions from RNG; original _wander still executes.","lethalDrops":"Original drop ids and amounts with chance1 fixture data; original _die and callbacks execute unchanged. Positions remain source-generated; per-item counts are compared.","practice":"Original practice metadata suppresses kills and drops while retaining died and unique flag."},"sourceMethods":["scripts/entities/enemy.gd::_die","scripts/entities/enemy.gd::_wander","scripts/entities/enemy.gd::hurt","scripts/entities/enemy.gd::break_guard","scripts/entities/enemy.gd::_ai_chase","scripts/entities/enemy.gd::_ai_bat","scripts/entities/enemy.gd::_ai_archer","scripts/entities/enemy.gd::_ai_mage","scripts/entities/enemy.gd::_ai_spitter","scripts/entities/enemy.gd::_ai_golem","scripts/entities/enemy.gd::_ai_king","scripts/entities/enemy.gd::_ai_animal","scripts/entities/combat_enemy.gd::update","scripts/entities/route_enemy.gd::update","scripts/entities/living_enemy.gd::update","scripts/entities/habitat_enemy.gd::update","scripts/entities/echo_enemy.gd::update","scripts/entities/coastal_enemy.gd::update","scripts/entities/projectile.gd::_process","scripts/entities/projectile.gd::sword_hit","scripts/entities/arrow.gd::_physics_process","scripts/entities/arrow.gd::launch","scripts/entities/guardian.gd::hurt","scripts/entities/guardian.gd::_physics_process","scripts/entities/guardian_shard.gd::_process"]}
 report.sourceMethods.append_array(["scripts/entities/guardian_pillar.gd::begin_volley","scripts/entities/guardian_pillar.gd::_process","scripts/entities/guardian_pillar.gd::cancel"])
 var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"",true,true)+"\n");file.close();print("MIGRATION ENCOUNTER EXPORT OK "+str(encounter_cases.size())+" CASES");quit(0)
