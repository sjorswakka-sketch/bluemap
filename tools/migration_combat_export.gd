extends "res://tools/migration_progression_export.gd"
## Unchanged original combat actions; only geometry/aim/lent-arrow fixture inputs are controlled.
var Actions:Script
var Styles:Script
const EnemyData=preload("res://scripts/data/enemies.gd")
var Arrow:Script
var Projectile:Script
class CombatWorld extends Node2D:
 var entities:=Node2D.new()
 var ground:=Node2D.new()
 var player:Node2D
 var TILE:=32
 var darkness:=0.0
 var map_data:Dictionary={"rows":["................","................","................"]}
 var hitstops:Array=[]
 func _init():add_child(entities);add_child(ground)
 func burst(_at:Vector2,_color:Color,_count:int):pass
 func ring(_at:Vector2,_radius:float,_color:Color):pass
 func damage_number(_at:Vector2,_text:String,_color:Color):pass
 func hitstop(amount:float):hitstops.append(amount)
 func shake(_amount:float):pass
 func is_solid(_at:Vector2)->bool:return false
class ProbeTarget extends Node2D:
 var id:=""
 var radius:=7.0
 var active:=true
 var dead:=false
 var air_height:=0.0
 var guard_broken:=0.0
 var state:="idle"
 var data:Dictionary={"behavior":"chase","boss":false}
 var aim_dir:=Vector2.DOWN
 var hits:Array=[]
 var breaks:=0
 func hurt(damage:int,direction:Vector2):hits.append({"damage":damage,"direction":[direction.x,direction.y]})
 func break_guard():breaks+=1;guard_broken=2;state="hb_rest" if data.behavior=="hb_root" else state
var arena_intercept:=false
var PlayerFixture:Script
var cp:Node2D
var cw:CombatWorld
var combat_cases:Array=[]
var actor_snapshots:Array=[]
func intercepted()->bool:return true
func player_snapshot()->Dictionary:
 var arrows:Array=[]
 for child:Node in cw.entities.get_children():
  if child.get_script()==Arrow:
   arrows.append({"position":_plain(child.position),"direction":_plain(child.direction),"damage":child.damage,"speed":child.speed,"maxRange":child.max_range,"precise":child.precise,"traveled":child.traveled,"state":child.state})
 var targets:Array=[]
 for child:Node in cw.entities.get_children():
  if child is ProbeTarget:targets.append({"id":child.id,"hits":child.hits.duplicate(true),"breaks":child.breaks,"state":child.state})
 return {"position":_plain(cp.position),"aim":_plain(cp.aim_direction),"attackDirection":_plain(cp.attack_direction),"bowDirection":_plain(cp.bow_direction),"attackTimer":cp.attack_timer,"cooldown":cp.cooldown,"bowCooldown":cp.bow_cooldown,"bowAnim":cp.bow_anim,"invulnerable":cp.invuln,"knockback":_plain(cp.knockback),"rollTimer":cp.roll_timer,"comboStep":cp.combo_step,"comboWindow":cp.combo_window,"comboSweep":cp.combo_sweep,"phase":cp.combat.phase,"elapsed":cp.combat.elapsed,"recovery":cp.combat.recovery,"hintTime":cp.combat.hint_time,"profile":cp.combat.profile.duplicate(true),"originMap":cp.combat.origin_map,"techniqueDirection":_plain(cp.combat.direction),"ranged":cp.combat.ranged,"noArrowsToast":cp.no_arrows_toast,"stamina":gs.movement.stamina,"regenDelay":gs.movement.regen_delay,"exhausted":gs.movement.exhausted,"ended":gs.ended,"damageSource":gs.last_damage_source,"damageLog":gs.damage_log.duplicate(true),"arrows":arrows,"targets":targets}
func combat_op(o:Array)->Variant:
 match o[0]:
  "attack":
   Input.action_press("technique") if o[1] else Input.action_release("technique")
   if not gs.input_locked():cp._attack()
   Input.action_release("technique")
  "shoot":
   Input.action_press("technique") if o[1] else Input.action_release("technique")
   if not gs.input_locked():cp._shoot()
   Input.action_release("technique")
  "begin":cp.combat.begin(cp,o[1])
  "step":cp._physics_process(float(o[1]));cp.position=Vector2.ZERO
  "cancel":cp.combat.cancel()
  "stop":cp.stop_for_transition()
  "hurt":cp.hurt(Vector2(o[1][0],o[1][1]),int(o[2]),o[3])
  "profile":return Actions.effective_profile(o[1],o[2])
  "counter":return cp.combat.counter(cp)
  "block":return cp.combat.try_block(cp,Vector2(o[1][0],o[1][1]))
  "timer":cp.set(o[1],o[2])
  "clear":cp.fixture_clear=o[1]
  "lent":cp.fixture_lent=o[1]
  "stamina":gs.movement.stamina=float(o[1]);gs.movement.regen_delay=0.0;gs.movement.exhausted=o[2]
  "locked":gs.ui_owners={"combat-fixture":true} if o[1] else {}
  "map":gs.map_id=o[1]
  "take":gs.take(o[1],o[2])
  "equip":Gear.equip(o[1])
  "target":
   var target:=ProbeTarget.new();target.id=o[1];target.position=Vector2(o[2][0],o[2][1]);target.radius=float(o[3]);target.data={"behavior":o[4],"boss":o[6]};target.state=o[5];target.active=o[7];target.dead=o[8];target.air_height=float(o[9]);cw.entities.add_child(target);target.add_to_group("enemies")
  "arrow_can_hit":
   var target:=ProbeTarget.new();target.dead=o[1];target.active=o[2];target.air_height=float(o[3]);var arrow:Node2D=Arrow.new();var result:bool=arrow._can_be_hit(target);arrow.free();target.free();return result
  "arrow_armored":
   var target:=ProbeTarget.new();target.data={"behavior":o[1],"boss":false};target.state=o[2];target.guard_broken=float(o[4]);var arrow:Node2D=Arrow.new();arrow.precise=o[3];var result:bool=arrow._armored(target);arrow.free();target.free();return result
  "segment":
   var arrow:Node2D=Arrow.new();var result:float=arrow._segment_distance(Vector2(o[1][0],o[1][1]),Vector2(o[2][0],o[2][1]),Vector2(o[3][0],o[3][1]));arrow.free();return result
  "arrow_travel":
   var arrow:Node2D=Arrow.new();arrow.world=cw;arrow.position=Vector2(o[1][0],o[1][1]);arrow.direction=Vector2(o[2][0],o[2][1]);arrow.max_range=float(o[4]);cw.entities.add_child(arrow);arrow._advance(float(o[3]));var result:Dictionary={"position":_plain(arrow.position),"traveled":arrow.traveled,"state":arrow.state};arrow.free();return result
  "projectile_sword":
   var projectile:Node2D=Projectile.new();projectile.world=cw;projectile.position=Vector2(o[1][0],o[1][1]);cw.entities.add_child(projectile);projectile.sword_hit(Vector2(o[2][0],o[2][1]),Vector2(o[3][0],o[3][1]),float(o[4]));var result:bool=projectile.is_queued_for_deletion();cw.entities.remove_child(projectile);projectile.free();return result
  "ng_hp":return gs.ng_hp(o[1])
  "ng_coins":return gs.ng_coins(o[1])
  "guardian_finish":
   var guardian:Node2D=load("res://scripts/entities/guardian.gd").new();guardian.world=cw;guardian.obj={};cw.entities.add_child(guardian);guardian._finish();cw.entities.remove_child(guardian);guardian.free()
  "guardian_chest":
   var guardian:Node2D=load("res://scripts/entities/guardian.gd").new();guardian.world=cw;guardian.obj={"chest":[13,9]};var chest:Node=guardian._make_chest();var result:Dictionary={"contents":chest.contents,"key":chest.unique_key};chest.free();guardian.free();return result
 return null
func combat_case(id:String,overrides:Dictionary,operations:Array,transient:Dictionary={}):
 gs.new_game();gs.set_process(false);gs.load_pos=Vector2.ZERO;gs.meta_achievements={};gs.in_game=true;gs.save_is_ours=false;gs.defeat_handler=Callable();gs.ui_owners={}
 for k:String in overrides:gs.set("map_id" if k=="map" else k,overrides[k].duplicate(true) if overrides[k] is Dictionary or overrides[k] is Array else overrides[k])
 cw=CombatWorld.new();cw.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(cw);current_scene=cw;cp=PlayerFixture.new();cp.world=cw;cw.player=cp;cw.add_child(cp);cp.set_process(false);cp.set_physics_process(false)
 gs.movement.stamina=100;gs.movement.regen_delay=0;gs.movement.exhausted=false
 for key:String in transient:
  if key=="arenaIntercept":gs.defeat_handler=intercepted
  else:cp.set(key,transient[key])
 var before:=_snapshot();var initial_player:=player_snapshot();var results:Array=[]
 for op:Array in operations:
  var value:Variant=combat_op(op);freeze_inventory(cw);results.append({"value":_plain(value),"player":player_snapshot()})
 var after:=_snapshot();var plain_ops:Array=_plain(operations)
 combat_cases.append({"id":id,"initial":before,"initialExact":_exact(before),"initialOrdered":ordered_input(before),"transient":_plain(transient),"transientExact":_exact(_plain(transient)),"transientOrdered":ordered_input(_plain(transient)),"initialPlayer":initial_player,"initialPlayerExact":_exact(initial_player),"initialPlayerOrdered":ordered_input(initial_player),"operations":plain_ops,"operationsExact":_exact(plain_ops),"operationsOrdered":ordered_input(plain_ops),"results":_plain(results),"resultsExact":_exact(_plain(results)),"expected":after,"expectedExact":_exact(after)})
 cw.free();cp=null;cw=null
func plain_constants(path:String)->Dictionary:
 var result:Dictionary={};var values:Dictionary=load(path).get_script_constant_map()
 for key:String in values:
  if not values[key] is Object:result[key]=_plain(values[key])
 return result
func loaded_actor_data():
 var scenarios:Script=load("res://tools/migration_world_scenarios.gd")
 for scenario:Dictionary in scenarios.manifest():
  for map:String in scenario.maps:
   scenarios.configure(scenario.id);gs.map_id=map;gs.spawn_name="start";gs.use_load_pos=false
   seed(scenarios.FIXTURE_SEED+hash(scenario.id+":"+map))
   var actual:Node2D=load("res://scenes/main.tscn").instantiate();actual.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(actual);current_scene=actual;freeze_inventory(actual)
   await process_frame;freeze_inventory(actual);scenarios.project(actual);freeze_inventory(actual);await process_frame;freeze_inventory(actual);await process_frame;freeze_inventory(actual)
   var row:Dictionary={"map":map,"scenario":scenario.id,"actors":[]}
   for node:Node in actual.entities.get_children():
    var script:Script=node.get_script();var path:String=script.resource_path if script!=null else ""
    if path in ["res://scripts/entities/enemy.gd","res://scripts/entities/guardian.gd"]:
     row.actors.append({"script":path,"kind":node.kind,"uniqueFlag":node.unique_flag,"position":_plain(node.position),"hp":node.hp,"maxHp":node.max_hp,"radius":node.radius,"active":node.active,"data":_plain(node.data),"obj":_plain(node.obj) if path.ends_with("guardian.gd") else {},"practice":node.has_meta("practice"),"sourceAddress":[actual.entities.get_index(),node.get_index()]})
   actor_snapshots.append(row);actual.free();await process_frame
func _run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe combat export");quit(1);return
 Actions=load("res://scripts/entities/combat_actions.gd");Styles=load("res://scripts/entities/coastal_styles.gd");Arrow=load("res://scripts/entities/arrow.gd");Projectile=load("res://scripts/entities/projectile.gd");PlayerFixture=load("res://tools/migration_combat_player_fixture.gd")
 if not PlayerFixture.can_instantiate():push_error("Original combat fixture did not compile");quit(1);return
 gs=root.get_node("GameState");gs.set_process(false);gs.new_game();gs.load_pos=Vector2.ZERO;gs.meta_achievements={};root.get_node("Lang").set_language("nl",false)
 var new_game:=_snapshot();var all_gear:Dictionary={}
 for id:String in GearData.ITEMS:all_gear[id]=1
 for weapon:String in Items.WEAPONS:
  combat_case("sword-combo-%s"%weapon,{"weapon":weapon,"inventory":all_gear},[["target","front",[30,0],7.0,"chase","idle",false,true,false,0.0],["timer","aim_direction",Vector2.RIGHT],["attack",false],["step",0.35],["attack",false],["step",0.35],["attack",false],["step",0.9],["attack",false]])
  for bow:bool in [false,true]:
   combat_case("technique-profile-%s-%s"%[weapon,bow],{"weapon":weapon},[["profile",weapon,bow]])
   combat_case("technique-release-%s-%s"%[weapon,bow],{"weapon":weapon,"inventory":{"bow":1,"arrow":8}},[["target","front",[0,35],7.0,"chase","idle",false,true,false,0.0],["begin",bow],["step",0.1],["step",0.7],["step",0.2],["step",0.5]])
 for energy:float in [0.0,17.99,18.0,18.001,100.0]:combat_case("sweep-stamina-%s"%energy,{},[["stamina",energy,false],["attack",false],["step",0.35],["attack",false],["step",0.35],["stamina",energy,false],["attack",false]])
 for exhausted:bool in [false,true]:combat_case("technique-exhaustion-%s"%exhausted,{"inventory":{"bow":1,"arrow":5}},[["stamina",16.0,exhausted],["begin",false],["begin",false],["step",0.2]])
 for hand:String in ["gear_cw_anchor","gear_cw_fan","gear_pg_grip_plus"]:
  for bow:bool in [false,true]:
   for arrows:int in [0,2,3,8]:
    combat_case("style-%s-%s-%s"%[hand,bow,arrows],{"inventory":{"bow":1,"arrow":arrows,hand:1,"gear_pg_focus_plus":1},"equipment":{"hands":hand,"neck":"gear_pg_focus_plus"}},[["profile","wood",bow],["begin",bow],["step",0.12],["block",[0,20]],["attack",false],["step",0.55],["step",0.7]])
 for armor:String in ["","gear_iron_armor","gear_leather_armor"]:
  for amount:int in [-1,0,1,2,3,8]:
   var armor_owned:Dictionary={} if armor=="" else {armor:1};var worn:Dictionary={} if armor=="" else {"chest":armor}
   combat_case("hurt-%s-%s"%[armor,amount],{"inventory":armor_owned,"equipment":worn},[["hurt",[10,0],amount,"Slijm"],["hurt",[0,10],amount,"Opnieuw"]])
 for inv:float in [0.0,0.0001,1.0]:combat_case("invulnerability-%s"%inv,{},[["hurt",[0,10],1,"Pijl"]],{"invuln":inv})
 for roll:float in [0.0,0.059999,0.06,0.060001,0.3]:combat_case("roll-safe-%s"%roll,{},[["hurt",[0,10],1,"Steen"]],{"roll_timer":roll})
 for boss:int in [0,1,2]:combat_case("death-counter-%s"%boss,{"hp":1,"flags":{"boss_started":boss>0,"boss_defeated":boss==2}},[["hurt",[10,0],8,"De Slijmkoning"],["timer","invuln",0.0],["hurt",[10,0],8,"Opnieuw"]])
 combat_case("arena-intercepts-death",{"map":"arena","hp":1},[["hurt",[1,0],2,"Arena"]],{"arenaIntercept":true})
 combat_case("ordinary-bow-missing",{},[["shoot",false],["shoot",false],["step",3.4],["shoot",false]])
 for arrows:int in [0,1,3]:combat_case("ordinary-bow-%s"%arrows,{"inventory":{"bow":1,"arrow":arrows}},[["shoot",false],["shoot",false],["step",0.4],["shoot",false]])
 combat_case("lent-arrows",{"inventory":{"bow":1}},[["lent",true],["shoot",false],["step",0.4],["begin",true],["step",0.7]])
 combat_case("precision-recheck-ammo",{"inventory":{"bow":1,"arrow":1}},[["begin",true],["take","arrow",1],["step",0.7]])
 combat_case("technique-map-cancel",{"inventory":{"bow":1,"arrow":3}},[["begin",true],["map","forest"],["step",1.0]])
 combat_case("technique-menu-cancel",{"inventory":{"bow":1,"arrow":3}},[["begin",true],["locked",true],["step",0.7]])
 combat_case("technique-device-cancel",{"inventory":{"bow":1,"arrow":3}},[["begin",true],["cancel"],["step",0.7]])
 combat_case("style-removal-cancel",{"inventory":{"gear_cw_fan":1,"bow":1,"arrow":3},"equipment":{"hands":"gear_cw_fan"}},[["begin",true],["take","gear_cw_fan",1],["step",0.7]])
 combat_case("cover-blocks-sword",{},[["target","front",[0,20],7.0,"chase","idle",false,true,false,0.0],["clear",false],["attack",false]])
 for angle:Array in [[0,0],[0,20],[0,-20],[20,0],[0,41],[0,42]]:combat_case("sword-geometry-%s"%combat_cases.size(),{},[["target","target",angle,7.0,"chase","idle",false,true,false,0.0],["attack",false]])
 for dead:bool in [false,true]:
  for active:bool in [false,true]:
   for height:float in [0.0,4.0,4.001]:combat_case("arrow-target-%s"%combat_cases.size(),{},[["arrow_can_hit",dead,active,height]])
 for behavior:String in ["chase","golem","hb_root"]:
  for state:String in ["idle","windup","recover","hb_root_warn","hb_rest"]:
   for precise:bool in [false,true]:combat_case("arrow-armor-%s"%combat_cases.size(),{},[["arrow_armored",behavior,state,precise,0.0]])
 for distance:float in [1.0,8.0,8.1,12.0,33.0,280.0,300.0]:combat_case("arrow-flight-%s"%distance,{},[["arrow_travel",[0,4],[1,0],distance,280.0]])
 for at:Array in [[0,0],[10,0],[45,0],[44.001,0],[0,35],[-10,0]]:combat_case("breakable-geometry-%s"%combat_cases.size(),{},[["projectile_sword",at,[0,0],[1,0],34.0]])
 for ng:int in [0,1,2,9]:
  for amount:int in [1,3,22,60,180]:combat_case("new-game-plus-%s-%s"%[ng,amount],{"ng_plus":ng},[["ng_hp",amount],["ng_coins",amount]])
 for hearts:int in [0,3]:combat_case("guardian-chest-%s"%hearts,{"inventory":{"heart_container":hearts}},[["guardian_chest"]])
 for quest:String in ["none","active","done"]:
  var quests:Dictionary={} if quest=="none" else {"diepte":{"state":quest,"step":0}}
  combat_case("guardian-earned-reward-%s"%quest,{"map":"depths2","quests":quests,"weapon":"crystal","hero_xp":49,"coins":7},[["guardian_finish"]])
 # Actual boundary episodes for committed directions, gear reductions, guard timing and rejected starts.
 for hand:String in ["gear_novice_gloves","gear_smith_gloves","gear_pg_grip","gear_pg_grip_plus"]:
  for weapon:String in Items.WEAPONS:
   combat_case("gear-combat-%s-%s"%[hand,weapon],{"weapon":weapon,"inventory":{hand:1,"bow":1,"arrow":3,"gear_pg_focus_plus":1},"equipment":{"hands":hand,"neck":"gear_pg_focus_plus"}},[["attack",false],["step",0.35],["begin",true],["step",0.49],["step",0.2]])
 for elapsed:float in [0.319999,0.32,0.320001]:
  combat_case("anchor-window-%s"%elapsed,{"inventory":{"gear_cw_anchor":1},"equipment":{"hands":"gear_cw_anchor"}},[["begin",false],["step",0.12],["step",elapsed],["block",[0,20]],["counter"]])
 for source:Array in [[0,0],[20,0],[0,-20],[0,20],[17.3205,10.0]]:
  combat_case("anchor-angle-%s"%combat_cases.size(),{"inventory":{"gear_cw_anchor":1},"equipment":{"hands":"gear_cw_anchor"}},[["begin",false],["step",0.12],["block",source],["hurt",source,2,"Guard edge"]])
 for field:String in ["cooldown","bow_cooldown","roll_timer"]:
  combat_case("rejected-start-%s"%field,{"inventory":{"bow":1,"arrow":3}},[["timer",field,0.001],["begin",false],["begin",true]])
 combat_case("committed-aim-stops-at-transition",{"inventory":{"bow":1,"arrow":4}},[["timer","aim_direction",Vector2.RIGHT],["begin",true],["timer","aim_direction",Vector2.LEFT],["step",0.65],["stop"]])
 combat_case("future-profile-fields-retained",{"flags":{"future_combat":{"large":9007199254740993,"nested":[null,true,"🌿"]}}},[["attack",false],["hurt",[1,0],1,"Unknown save"],["step",1.0]])
 for geometry:Array in [[[0,0],[0,0],[0,0]],[[5,4],[0,0],[10,0]],[[15,4],[0,0],[10,0]],[[-3,4],[0,0],[10,0]],[[1.25,7.75],[-2.5,3.5],[8.25,4.125]]]:
  combat_case("segment-distance-%s"%combat_cases.size(),{},[["segment",geometry[0],geometry[1],geometry[2]]])
 var ai:Dictionary={}
 for name:String in ["combat_enemy","living_enemy","coastal_enemy","habitat_enemy","route_enemy","echo_enemy","guardian_pillar","guardian_shard"]:ai[name]=plain_constants("res://scripts/entities/%s.gd"%name)
 var styles:Dictionary={}
 gs.inventory={"gear_cw_anchor":1};gs.equipment={"hands":"gear_cw_anchor"};styles.cw_anchor=Styles.profile(false)
 gs.inventory={"gear_cw_fan":1};gs.equipment={"hands":"gear_cw_fan"};styles.cw_fan=Styles.profile(true)
 await loaded_actor_data()
 var catalogs:Dictionary=_plain({"enemies":EnemyData.ENEMIES,"weapons":Items.WEAPONS,"gear":GearData.ITEMS,"techniques":Actions.PROFILES,"bowTechnique":{"name":"Precisieschot","cost":20.0,"windup":0.65},"coastalProfiles":styles,"player":plain_constants("res://scripts/entities/player.gd"),"arrow":plain_constants("res://scripts/entities/arrow.gd"),"projectile":plain_constants("res://scripts/entities/projectile.gd"),"guardian":plain_constants("res://scripts/entities/guardian.gd"),"aiConstants":ai,"loadedActors":actor_snapshots,"enemyOrder":EnemyData.ENEMIES.keys(),"projectileTraits":Projectile.TRAITS,"arrowOverTiles":Arrow.over_tiles()})
 var report:Dictionary={"schema":"bluemap.combat.source-oracle.v1","engineVersion":Engine.get_version_info().string,"personalSavesUsed":false,"float64Encoding":"ieee754-binary64-little-endian-hex","orderedInputEncoding":"dictionary-pairs-and-exact-f64-v1","fixturePolicy":"Geometry/aim/lent-arrow are controlled external inputs; original combat and physics methods remain unmodified.","catalogs":catalogs,"catalogsExact":_exact(catalogs),"catalogsOrdered":ordered_input(catalogs),"newGame":new_game,"cases":combat_cases,"sourceMethods":["scripts/entities/player.gd::_attack","scripts/entities/player.gd::_shoot","scripts/entities/player.gd::hurt","scripts/entities/player.gd::_physics_process","scripts/entities/player.gd::stop_for_transition","scripts/entities/combat_actions.gd::effective_profile","scripts/entities/combat_actions.gd::begin","scripts/entities/combat_actions.gd::update","scripts/entities/combat_actions.gd::cancel","scripts/entities/coastal_styles.gd::block","scripts/entities/coastal_styles.gd::counter","scripts/entities/coastal_styles.gd::release_fan","scripts/entities/arrow.gd::_advance","scripts/entities/arrow.gd::_can_be_hit","scripts/entities/arrow.gd::_armored","scripts/entities/projectile.gd::sword_hit","scripts/entities/guardian.gd::_finish","scripts/entities/guardian.gd::_make_chest","scripts/core/game_state.gd::hurt","scripts/core/game_state.gd::_record_death","scripts/core/game_state.gd::ng_hp","scripts/core/game_state.gd::ng_coins"]}
 var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(report,"",true,true)+"\n");f.close();print("MIGRATION COMBAT EXPORT OK "+str(combat_cases.size())+" CASES");quit(0)
