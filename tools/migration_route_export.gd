extends SceneTree
## Execute original gameplay methods exclusively in the UUID-isolated reference project.
const Jobs=preload("res://scripts/data/ext/beroepen.gd")
const Prof=preload("res://scripts/core/professions.gd")
const Talks=preload("res://scripts/data/dialogue.gd")
const Npcs=preload("res://scripts/data/npcs.gd")
const Quests=preload("res://scripts/data/quests.gd")
const Items=preload("res://scripts/data/items.gd")
const CatRoute=preload("res://scripts/core/first_route.gd")
const CatUpdate=preload("res://scripts/entities/route_npc.gd")
class DummyCombat:
 var phase:=""
class DummyPlayer extends Node2D:
 var sprinting:=false
 var roll_timer:=0.0
 var attack_timer:=0.0
 var bow_anim:=0.0
 var velocity:=Vector2.ZERO
 var combat=DummyCombat.new()
class DummyWorld extends Node2D:
 var player=DummyPlayer.new()
 func _init():add_child(player)
 func burst(_at:Vector2,_color:Color,_count:int):pass
 func is_solid(_at:Vector2)->bool:return false
 func damage_number(_at:Vector2,_text:String,_color:Color):pass
 func shake(_value:float):pass
class DummyCat extends Node2D:
 var npc_id:="muis_bos"
 var route_calm:=0.0
 var route_panic:=0.0
 var route_wait:=false
 var world:Node2D
var gs:Node
var node_id:=""
var choices_ready:=false
var cases:Array=[]
var cat:DummyCat
var world:DummyWorld
func _initialize():_run.call_deferred()
func _plain(v:Variant)->Variant:
 if v is Vector2 or v is Vector2i:return [v.x,v.y]
 if v is Color:return [v.r,v.g,v.b,v.a]
 if v is Dictionary:
  var d:Dictionary={}
  for k:Variant in v:d[str(k)]=_plain(v[k])
  return d
 if v is Array:
  var a:Array=[]
  for x:Variant in v:a.append(_plain(x))
  return a
 return v
func _exact(v:Variant)->Variant:
 if v is float:return {"$f64":PackedFloat64Array([v]).to_byte_array().hex_encode()}
 if v is Dictionary:
  var d:Dictionary={}
  for k:Variant in v:d[str(k)]=_exact(v[k])
  return d
 if v is Array:
  var a:Array=[]
  for x:Variant in v:a.append(_exact(x))
  return a
 return v
func _snapshot()->Dictionary:
 var d:Dictionary={"version":1,"map":gs.map_id,"pos":[gs.load_pos.x,gs.load_pos.y]}
 for k:String in ["hp","coins","inventory","flags","quests","weapon","visited_maps","play_time","kills","meer","day_time","day_count","kills_by","rolls","potions_drunk","deaths","boss_deaths","arena_records","homestead","coastal_storage","stockroom","personal_home","yard","professions","hero_xp","equipment","appearance","clothing","ng_plus"]:d[k]=gs.get(k)
 d.talked=gs.talked.keys();d.achievements=gs.achievements.keys()
 return _plain(d)
func _talk(id:String)->bool:
 if gs.input_locked():return false
 gs.note_talked(id)
 if id=="muis_bos" and CatRoute.npc_interact(cat):return false
 for rule:Dictionary in Npcs.info(id).rules:
  if not rule.has("if") or gs.check_all(rule["if"]):node_id=rule.talk;choices_ready=false;return true
 return false
func _advance()->bool:
 if node_id=="" or choices_ready:return false
 var node:Dictionary=Talks.get_talk(node_id)
 if node.has("do"):gs.run_all(node.do)
 if node.has("choices"):choices_ready=true;return true
 if node.has("branch"):
  for branch:Dictionary in node.branch:
   if not branch.has("if") or gs.check_all(branch["if"]):node_id=branch.next;return true
 node_id=node.get("next","");return true
func _choose(index:int)->bool:
 if not choices_ready:return false
 var choices:Array=[]
 for choice:Dictionary in Talks.get_talk(node_id).choices:
  if not choice.has("if") or gs.check_all(choice["if"]):choices.append(choice)
 if index<0 or index>=choices.size():return false
 var selected:Dictionary=choices[index]
 if selected.has("do"):gs.run_all(selected.do)
 node_id=selected.get("next","");choices_ready=false;return true
func _op(o:Array)->Variant:
 match o[0]:
  "talk":return _talk(o[1])
  "advance":return _advance()
  "choose":return _choose(o[1])
  "close":node_id="";choices_ready=false;return true
  "cat_tick":
   world.player.position=cat.position+Vector2(o[2],0);world.player.velocity=Vector2(o[3],0);world.player.sprinting=o[4]
   CatUpdate.update(cat,float(o[1]));return true
  "gather":return Prof.gather(o[1],o[2])
  "time":gs.play_time=float(o[1]);return true
  "rest":gs.full_rest();return true
  "chest":
   var chest:StaticBody2D=load("res://scripts/entities/chest.gd").new();chest.process_mode=Node.PROCESS_MODE_DISABLED;chest.world=world;chest.unique_key=o[1];chest.contents=o[2];root.add_child(chest);chest.interact();var opened:bool=chest.opened;chest.free();return opened
  "pickup":
   var pickup:Node2D=load("res://scripts/entities/pickup.gd").new();pickup.process_mode=Node.PROCESS_MODE_DISABLED;pickup.world=world;pickup.item=o[1];pickup.unique_key=o[2];root.add_child(pickup);pickup._collect();var collected:bool=pickup.collected;pickup.free();return collected
  "give":gs.give(o[1],int(o[2]),true);return true
  "set_flag":gs.set_flag(o[1]);return true
 return false
func _case(id:String,overrides:Dictionary,operations:Array):
 gs.new_game();gs.set_process(false);gs.load_pos=Vector2.ZERO;gs.meta_achievements={};node_id="";choices_ready=false
 cat.route_calm=0;cat.route_panic=0;cat.route_wait=false;cat.position=Vector2.ZERO
 for k:String in overrides:gs.set("map_id" if k=="map" else k,overrides[k].duplicate(true) if overrides[k] is Dictionary or overrides[k] is Array else overrides[k])
 var before:=_snapshot();var results:Array=[]
 for o:Array in operations:results.append(_op(o))
 cases.append({"id":id,"initial":before,"operations":operations,"results":results,"expected":_snapshot(),"expectedExact":_exact(_snapshot()),"dialogue":node_id,"choicesReady":choices_ready,"cat":{"calm":cat.route_calm,"panic":cat.route_panic,"waiting":cat.route_wait}})
func _run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe route export");quit(1);return
 gs=root.get_node("GameState");gs.set_process(false);gs.meta_achievements={};gs.new_game();gs.load_pos=Vector2.ZERO
 var baseline:=_snapshot()
 world=DummyWorld.new();world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world);cat=DummyCat.new();cat.world=world;world.add_child(cat)
 var accepted:Dictionary={"quests":{"kat":{"state":"active","step":0}}}
 _case("pim_accept",{},[["talk","pim"],["advance"],["choose",0],["advance"],["talk","pim"],["advance"]])
 _case("pim_decline",{},[["talk","pim"],["advance"],["choose",1]])
 _case("pim_cancel_unread",{},[["talk","pim"],["close"]])
 _case("bram_accept",{},[["talk","bram"],["advance"],["advance"],["choose",0],["advance"],["talk","bram"],["advance"]])
 _case("cat_wait_then_find",accepted,[["talk","muis_bos"],["cat_tick",1.0,32,0,false],["cat_tick",1.0,32,0,false],["talk","muis_bos"],["advance"]])
 _case("cat_without_quest",{},[["talk","muis_bos"],["cat_tick",2.0,32,0,false],["talk","muis_bos"],["advance"]])
 _case("cat_panic",accepted,[["cat_tick",0.25,60,0,true],["talk","muis_bos"],["cat_tick",1.0,150,0,false]])
 _case("cat_calm_interrupted",accepted,[["talk","muis_bos"],["cat_tick",1.0,32,0,false],["cat_tick",0.1,32,6,false]])
 _case("pim_reward_once",{"flags":{"cat_found":true},"quests":{"kat":{"state":"active","step":1}}},[["talk","pim"],["advance"],["talk","pim"],["advance"]])
 _case("pim_reward_level",{"hero_xp":40,"flags":{"cat_found":true},"quests":{"kat":{"state":"active","step":1}}},[["talk","pim"],["advance"]])
 _case("pim_max_hearts",{"inventory":{"heart_container":3},"flags":{"cat_found":true},"quests":{"kat":{"state":"active","step":1}}},[["talk","pim"],["advance"]])
 _case("chest_basic",{},[["chest","chest:forest:fixture",[["potion",1],["coins",25]]],["chest","chest:forest:fixture",[["potion",1],["coins",25]]]])
 _case("chest_owned_unique",{"inventory":{"gear_bronze_helm":1}},[["chest","chest:fixture",[["gear_bronze_helm",1],["coins",25],["potion",2]]]])
 _case("chest_partial_stack_refused",{"inventory":{"arrow":39}},[["chest","chest:fixture",[["arrow",1],["arrow",1],["coins",25]]]])
 _case("chest_heart",{"hp":2},[["chest","chest:fixture",[["heart_container",1],["coins",5]]]])
 _case("gather_active_cooldown",{"play_time":10.125},[["gather","branches","prof:village:twigs_west"],["gather","branches","prof:village:twigs_west"],["time",100.125],["gather","branches","prof:village:twigs_west"]])
 _case("gather_missing_tool",{},[["gather","stump","prof:forest:birch_west"]])
 _case("gather_strong_tool",{"inventory":{"prof_iron_axe":1}},[["gather","stump","prof:forest:birch_west"]])
 _case("gather_level_required",{},[["gather","mushrooms","prof:forest:mushrooms_west"]])
 _case("gather_xp_cap",{"professions":{"xp":{"foraging":1349},"cooldowns":{}}},[["gather","herbs","prof:forest:herbs_west"]])
 _case("rest_no_time_skip",{"hp":2,"day_time":0.75,"day_count":7,"play_time":91.25,"inventory":{"heart_container":2}},[["rest"]])
 _case("pickup_coin",{},[["pickup","coin",""]])
 _case("pickup_heart_full",{},[["pickup","heart",""]])
 _case("pickup_heart_hurt",{"hp":2},[["pickup","heart",""]])
 _case("pickup_crystal",{},[["pickup","crystal_bos","pickup:forest:7"]])
 _case("pickup_item_full",{"inventory":{"arrow":40}},[["pickup","arrow",""]])
 var durations:Array=[]
 for fixture:Dictionary in [{"id":"base","inventory":{},"equipment":{}},{"id":"worn_pack","inventory":{"gear_pg_pack_plus":1},"equipment":{"chest":"gear_pg_pack_plus"}},{"id":"owned_not_worn","inventory":{"gear_pg_pack_plus":1},"equipment":{}},{"id":"negative_speed","inventory":{"gear_bastion_coat":1},"equipment":{"chest":"gear_bastion_coat"}}]:
  gs.new_game();gs.inventory=fixture.inventory;gs.equipment=fixture.equipment
  var d:Dictionary=fixture.duplicate(true);d["duration"]=Prof.gather_duration("branches");d["durationExact"]=_exact(d.duration);d["moveSpeed"]=preload("res://scripts/core/equipment.gd").bonus("move_speed");d["magnetRange"]=preload("res://scripts/core/equipment.gd").bonus("magnet_range");durations.append(d)
 var catalogs:Dictionary={"resources":Jobs.RESOURCES,"skills":Jobs.SKILLS,"items":Items.ITEMS,"npcs":Npcs.NPCS,"dialogues":Talks.TALKS,"quests":Quests.QUESTS,"gear":preload("res://scripts/data/ext/uitrusting.gd").ITEMS,"slots":preload("res://scripts/core/equipment.gd").SLOTS,"bonusLimits":preload("res://scripts/core/equipment.gd").BONUS_LIMITS}
 var report:Dictionary={"schema":"bluemap.route.source-oracle.v1","engineVersion":Engine.get_version_info().string,"float64Encoding":"ieee754-binary64-little-endian-hex","personalSavesUsed":false,"newGame":baseline,"catalogs":_plain(catalogs),"cases":cases,"durations":durations,"sourceMethods":["scripts/core/game_state.gd::run_all","scripts/core/game_state.gd::start_quest","scripts/core/game_state.gd::finish_quest","scripts/core/game_state.gd::full_rest","scripts/core/professions.gd::gather","scripts/entities/chest.gd::interact","scripts/entities/pickup.gd::_collect","scripts/core/first_route.gd::npc_interact","scripts/entities/route_npc.gd::update"]}
 var file:=FileAccess.open(out,FileAccess.WRITE)
 if file==null:push_error("Cannot write route oracle");quit(1);return
 file.store_string(JSON.stringify(report,"",true,true)+"\n");file.close();print("MIGRATION ROUTE EXPORT OK");quit(0)
