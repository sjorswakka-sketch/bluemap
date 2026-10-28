extends "res://tools/migration_story_export.gd"
## Execute the retained original social methods. No source gameplay method is replaced.
const Memory=preload("res://scripts/core/world_memory.gd")
const Supper=preload("res://scripts/core/lake_supper.gd")
var social_cases:Array=[]
var prop:Node2D
var kitchen:CanvasLayer
var village:Node2D
class SocialWorld extends StoryWorld:
 var map_size:=Vector2i(40,32)
 var map_data:Dictionary={}
 var solid_cells:Dictionary={}
 var entities:=Node2D.new()
 func _init():add_child(entities)
func social_view()->Dictionary:
 return {"object":null if not is_instance_valid(prop) else {"kind":prop.kind,"time":prop.time,"progress":prop.progress,"pulling":prop.pulling,"origin":_plain(prop.origin),"health":prop.health,"stitch":prop.stitch,"visible":prop.visible,"interactable":prop.is_in_group("interactable")},"kitchen":null if not is_instance_valid(kitchen) else {"active":kitchen.active,"dish":kitchen.dish,"stage":kitchen.stage,"working":kitchen.working,"elapsed":kitchen.elapsed,"result":kitchen.result},"village":null if not is_instance_valid(village) else {"time":village.time,"hammer":village.hammer_time,"drip":village.drip_time,"flowing":village.last_flowing,"gardener":village.gardener.bubble,"gardenerTime":village.gardener.bubble_time,"courier":village.courier.bubble,"courierTime":village.courier.bubble_time},"locked":gs.input_locked(),"player":_plain(world.player.position)}
func social_op(o:Array)->Variant:
 match o[0]:
  "dialogue_view":return dialogue_view()
  "enabled":return Memory.enabled(o[1])
  "name":return Memory.name_for(o[1])
  "introduction":return Memory.introduction(o[1])
  "activity":return Memory.activity(o[1],o[2])
  "connection":return Memory.connection(o[1])
  "lines":return Memory.lines(o[1],o[2])
  "meet":Memory.meet(o[1]);return null
  "news":return Memory.news()
  "memory_actor":
   world.map_data={"weather":o[2]};var actor:Node2D=load("res://scripts/entities/memory_actor.gd").new();actor.process_mode=Node.PROCESS_MODE_DISABLED;actor.world=world;actor.role=o[1];world.add_child(actor);actor.interact();actor.free();return null
  "memory_book":
   var book:Node2D=load("res://scripts/entities/memory_book.gd").new();book.process_mode=Node.PROCESS_MODE_DISABLED;book.world=world;world.add_child(book);book.interact();book.free();return null
  "resting":return Memory.resting(o[1])
  "phase":return Day.phase_at(float(o[1]))
  "raining":return Day.raining(o[1],int(o[2]),float(o[3]))
  "migrate":Living.migrate();return null
  "opening":return {"enabled":Opening.enabled(),"flowing":Opening.flowing(),"quiet":Opening.quiet_hud()}
  "village":
   world.map_data=Maps.get_map("village");world.map_size=Vector2i(world.map_data.rows[0].length(),world.map_data.rows.size());village=load("res://scripts/entities/village_opening.gd").new();village.process_mode=Node.PROCESS_MODE_DISABLED;village.world=world;world.add_child(village);return null
  "village_tick":village._process(float(o[1]));return null
  "sprint":
   if o[1]:Input.action_press("sprint")
   else:Input.action_release("sprint")
   return null
  "inputs":return Supper.inputs(o[1])
  "cook_reason":return Supper.cook_reason(o[1])
  "cook":return Supper.cook(o[1])
  "tracker":return Supper.tracker()
  "conversation":return Supper.conversation(o[1])
  "object":
   if is_instance_valid(prop):prop.free()
   prop=load("res://scripts/entities/supper_object.gd").new();prop.process_mode=Node.PROCESS_MODE_DISABLED;prop.world=world;prop.obj={"kind":o[1]};world.add_child(prop);return null
  "interact":prop.interact();return null
  "weave":prop.weave(o[1]);return null
  "share":prop.share(o[1]);return null
  "pending":Supper.pending=weakref(prop) if o[1] else null;return null
  "action":Supper.action(o[1]);return null
  "tick":prop._process(float(o[1]));return null
  "player":
   world.player.position=Vector2(float(o[1]),float(o[2]));world.player.sprinting=bool(o[3]) if o.size()>3 else false;return null
  "lock":gs.set_ui("social_fixture",o[1]);return null
  "kitchen":
   if not is_instance_valid(kitchen):kitchen=load("res://scripts/ui/supper_kitchen.gd").new();world.add_child(kitchen);kitchen.set_process(false)
   kitchen.open(prop);return null
  "select":kitchen.select_dish(o[1]);return null
  "prepare":kitchen.prepare_step();return null
  "kitchen_tick":kitchen._process(float(o[1]));return null
  "kitchen_close":kitchen.close();return null
  "free_source":prop.free();return null
  "xp":Prof.add_xp(o[1],int(o[2]));return null
 return story_op(o)
func social_case(id:String,overrides:Dictionary,operations:Array):
 record_trace=false
 Input.action_release("sprint")
 if is_instance_valid(village):village.free()
 village=null
 for child:Node in world.entities.get_children():child.free()
 if is_instance_valid(kitchen):kitchen.free()
 kitchen=null
 if is_instance_valid(prop):prop.free()
 prop=null;Supper.pending=null;Supper.busy=false
 box._close();box.node={};box.lines=[];box.speaker_label.text="";box.from_data=true;gs.new_game();gs.set_process(false);gs.load_pos=Vector2.ZERO;gs.meta_achievements={};root.get_node("Lang").set_language("nl",false);gs.in_game=true
 world.player.position=Vector2(0,38);world.player.attack_timer=0;world.player.roll_timer=0;world.player.bow_anim=0;world.player.combat.phase="";world.player.sprinting=false
 for k:String in overrides:gs.set("map_id" if k=="map" else k,overrides[k].duplicate(true) if overrides[k] is Dictionary or overrides[k] is Array else overrides[k])
 var before:=_snapshot();trace=[];record_trace=true;var results:Array=[];var observations:Array=[]
 for op:Array in operations:
  results.append(_plain(social_op(op)));observations.append({"state":_snapshot(),"view":social_view(),"events":trace.duplicate(true)})
 record_trace=false
 var after:=_snapshot()
 social_cases.append({"id":id,"initial":before,"initialExact":_exact(before),"initialOrdered":ordered_input(before),"operations":operations,"operationsExact":_exact(operations),"operationsOrdered":ordered_input(operations),"results":results,"resultsExact":_exact(results),"expected":after,"expectedExact":_exact(after),"observations":observations,"observationsExact":_exact(observations),"observationsOrdered":ordered_input(observations)})
func social_catalog()->Dictionary:
 var roles:Dictionary={};gs.flags={};gs.inventory={}
 for role:String in Memory.PLACES:
  var row:Dictionary=Memory.PLACES[role].duplicate(true);row.name=Memory.name_for(role);row.introduction=Memory.introduction(role);row.workText=Memory.activity(role,false);row.restText=Memory.activity(role,true);gs.flags={"wm_met_"+role:true};row.returnText=Memory.lines(role,"clear")[0];gs.flags={};row.connections=[Memory.connection(role)]
  var flags:Array= {"miner":["lw_workshop"],"gardener":["lw_bridge"],"hearth":["ra_rope"],"lamplighter":["ra_rope"],"carrier":["ra_archive_done","ra_exhibit_routes"],"reader":["ra_archive_done","ra_exhibit_routes"],"caravan":["ra_water_wild"],"courier":[]}[role]
  for flag:String in flags:gs.flags={flag:true};row.connections.append(Memory.connection(role))
  if role=="courier":gs.inventory={"gear_pg_pack_plus":1};row.connections.append(Memory.connection(role));gs.inventory={}
  gs.flags={};row.mapName=Maps.MAPS[row.map].DATA.name;roles[role]=row
 var cooldowns:Dictionary={}
 for map:String in Jobs.RESOURCE_PLACEMENTS:
  for obj:Dictionary in Jobs.resource_objects(map):cooldowns[obj.id]=float(Jobs.RESOURCES[obj.kind].cooldown)
 var legacy_cooldowns:Array=cooldowns.keys()
 for map:String in Maps.MAPS:
  for obj:Dictionary in Maps.get_map(map).objects:
   if obj.type=="profession_resource" and str(obj.get("id","")).begins_with("trail:") or obj.type=="profession_resource" and str(obj.get("id","")).begins_with("winter:") or obj.type=="profession_resource" and str(obj.get("id","")).begins_with("forestfood:"):
    cooldowns[obj.id]=Prof.dynamic_cooldown_limit(obj.id)
 var supper_objects:Dictionary={};var memory_books:Dictionary={}
 for map:String in Maps.MAPS:
  for spec:Dictionary in Maps.get_map(map).objects:
   if spec.type=="supper_object":
    if not supper_objects.has(map):supper_objects[map]=[]
    supper_objects[map].append(spec.duplicate(true))
   if spec.type=="memory_book":
    if not memory_books.has(map):memory_books[map]=[]
    memory_books[map].append(spec.duplicate(true))
 return {"roles":roles,"translations":translations(),"skills":Jobs.SKILLS,"recipes":Jobs.RECIPES.keys(),"cooldowns":cooldowns,"legacyCooldowns":legacy_cooldowns,"supperObjects":supper_objects,"memoryBooks":memory_books,"directors":await director_catalog(),"dishes":Supper.DISHES}
func director_catalog()->Array:
 var result:Array=[]
 for entry:Array in [["village",false],["lake",false],["inn",false],["inn",true]]:
  gs.new_game();gs.set_process(false);gs.map_id=entry[0];gs.in_game=true;gs.flags={"op_new_adventure":true,"ls_served":entry[1]};gs.use_load_pos=false;gs.spawn_name="start"
  var actual:Node2D=load("res://scenes/main.tscn").instantiate();actual.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(actual);current_scene=actual;freeze_inventory(actual)
  var row:Dictionary={"map":entry[0],"served":entry[1],"mapSize":_plain(actual.map_size),"actors":[],"objects":[],"grids":[]}
  for node:Node in actual.entities.get_children():
   var script:Script=node.get_script();var path:String=script.resource_path if script!=null else ""
   if path in ["res://scripts/entities/village_actor.gd","res://scripts/entities/supper_actor.gd","res://scripts/entities/memory_actor.gd"]:
    var actor:Dictionary={"script":path.trim_prefix("res://"),"role":node.role,"position":_plain(node.position),"name":Memory.name_for(node.role) if path.ends_with("memory_actor.gd") else node.actor_name(),"collisionLayer":node.collision_layer,"collisionMask":node.collision_mask}
    if "npc_id" in node:actor.npcId=node.npc_id
    row.actors.append(actor)
   if path in ["res://scripts/entities/supper_object.gd","res://scripts/entities/memory_book.gd"]:row.objects.append({"script":path.trim_prefix("res://"),"position":_plain(node.position),"spec":node.obj,"collisionLayer":node.collision_layer})
  for group:String in ["village_opening","lake_supper","world_memory"]:
   for node:Node in get_nodes_in_group(group):
    if not actual.is_ancestor_of(node):continue
    if group=="world_memory":node.build_grid()
    var blocked:Array=[]
    for y:int in actual.map_size.y:
     for x:int in actual.map_size.x:
      if node.grid.is_point_solid(Vector2i(x,y)):blocked.append([x,y])
    row.grids.append({"kind":group,"blocked":blocked,"cellSize":_plain(node.grid.cell_size),"offset":_plain(node.grid.offset),"diagonalMode":node.grid.diagonal_mode})
  result.append(row);actual.free();current_scene=world;await process_frame
 return result
func _run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i:int in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe resident social export");quit(1);return
 gs=root.get_node("GameState");gs.set_process(false);gs.meta_achievements={};gs.new_game();gs.load_pos=Vector2.ZERO
 world=SocialWorld.new();world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world);current_scene=world
 box=load("res://tools/migration_story_dialogue_fixture.gd").new();root.add_child(box);connect_trace()
 var baseline:=_snapshot();var catalogs:Dictionary=await social_catalog()
 for locale:String in ["nl","en"]:
  social_case("memory-book-"+locale,{"map":"inn","flags":{"lw_mine":true,"ra_archive_done":true}},[["language",locale],["player",40.01,0.0],["memory_book"],["player",40.0,0.0],["memory_book"],["close"],["lock",true],["memory_book"],["lock",false]])
  for role:String in Memory.PLACES:social_case("memory-actor-"+locale+"-"+role,{},[["language",locale],["player",40.01,0.0],["memory_actor",role,"rain"],["player",40.0,0.0],["memory_actor",role,"rain"],["close"],["memory_actor",role,"clear"],["close"]])
  social_case("village-director-"+locale,{},[["language",locale],["village"],["player",560.0,368.0],["village_tick",0.1],["sprint",true],["village_tick",0.2],["sprint",false],["set_field","flags",{"op_new_adventure":true,"op_water":true,"op_greeting":true}],["village_tick",1.8],["language","en"],["village_tick",3.5]])
 for locale:String in ["nl","en"]:
  for role:String in Memory.PLACES:
   social_case("memory-"+locale+"-"+role,{},[["language",locale],["enabled",role],["name",role],["introduction",role],["activity",role,false],["activity",role,true],["connection",role],["lines",role,"clear"],["meet",role],["meet",role],["lines",role,"rain"],["news"]])
   for flag:String in ["lw_workshop","lw_bridge","ra_rope","ra_archive_done","ra_exhibit_routes","ra_water_wild"]:social_case("connection-"+locale+"-"+role+"-"+flag,{"flags":{flag:true},"inventory":{"gear_pg_pack_plus":1}},[["language",locale],["connection",role]])
  var all:Dictionary={}
  for role:String in Memory.PLACES:all[Memory.PLACES[role].flag]=true
  var ops:Array=[["language",locale],["news"]]
  for role:String in Memory.PLACES:ops.append(["enabled",role]);ops.append(["meet",role])
  ops.append(["news"]);social_case("memory-all-"+locale,{"flags":all},ops)
 for day:int in [0,1,17,9007199254740993]:
  for t:float in [-0.2,0.0,0.12,0.16999999999999998,0.17,0.3,0.5199999999999999,0.52,0.72,0.78,0.95,1.15]:
   var ops:Array=[["phase",t]]
   for weather:String in ["clear","rain","random","heat","snow"]:ops.append(["raining",weather,day,t]);ops.append(["resting",weather])
   social_case("clock-"+str(day)+"-"+PackedFloat64Array([t]).to_byte_array().hex_encode(),{"day_count":day,"day_time":t},ops)
 for qstate:String in ["none","active","done"]:
  for revision:bool in [false,true]:social_case("legacy-"+qstate+"-"+str(revision),{"quests":{} if qstate=="none" else {"warmte":{"state":qstate,"step":2},"wilgentwijgen":{"state":qstate,"step":3}},"flags":{"lw_revision_1":revision,"future":{"keep":9007199254740993}}},[["migrate"],["migrate"],["news"]])
 for bits:int in 16:social_case("opening-"+str(bits),{"flags":{"op_new_adventure":bool(bits&1),"op_water":bool(bits&2),"op_greta":bool(bits&4)},"ng_plus":1 if bits&8 else 0},[["opening"]])
 for locale:String in ["nl","en"]:
  for dish:String in ["ls_chowder","ls_broth","invalid"]:
   social_case("cook-gates-"+locale+"-"+dish,{},[["language",locale],["inputs",dish],["cook_reason",dish],["cook",dish],["set_field","map","inn"],["cook_reason",dish],["cook",dish],["set_field","flags",{"ls_basket":true}],["cook_reason",dish],["cook",dish]])
  social_case("basket-"+locale,{"map":"lake","inventory":{"fishing_rod":1}},[["language",locale],["object","basket"],["interact"],["tick",0.9],["player",9.0,38.0],["tick",0.9],["player",0.0,38.0],["interact"],["tick",1.79],["tick",0.010000000000000009],["interact"],["tick",2.0]])
  social_case("basket-no-rod-"+locale,{"map":"lake"},[["language",locale],["object","basket"],["interact"]])
  social_case("net-"+locale,{"map":"lake"},[["language",locale],["object","net"],["weave","under"],["weave","over"],["weave","over"],["pending",true],["player",66.01,0.0],["action",["ls_weave","over"]],["player",66.0,0.0],["action",["ls_weave","over"]],["action",["ls_weave","under"]],["action",["ls_weave","over"]],["weave","over"]])
  for dish:String in Supper.DISHES:
   var steps:Array=[["language",locale],["object","stove"],["kitchen"],["select",dish],["prepare"],["kitchen_tick",0.45],["kitchen_close"],["kitchen"],["select",dish]]
   for i:int in 3:steps.append(["prepare"]);steps.append(["kitchen_tick",0.9])
   steps.append_array([["kitchen_close"],["object","table"],["share",dish],["share",dish],["conversation","joris"],["conversation","bo"],["conversation","nelle"],["tracker"]]);social_case("meal-"+locale+"-"+dish,{"map":"inn","flags":{"ls_basket":true,"op_water":true,"cat_found":true,"rf_memorial":true},"inventory":{"ls_crate":1}},steps)
   social_case("repeat-cook-"+locale+"-"+dish,{"map":"inn","flags":{"ls_basket":true,"ls_served":true},"inventory":{"meer_baars":4,"prof_herb":2,"prof_berry":4}},[["language",locale],["cook",dish],["cook",dish],["tracker"]])
  social_case("kitchen-context-"+locale,{"map":"inn","flags":{"ls_basket":true},"inventory":{"ls_crate":1}},[["language",locale],["object","stove"],["kitchen"],["select","ls_chowder"],["prepare"],["player",66.01,0.0],["kitchen_tick",1.0],["player",66.0,0.0],["kitchen"],["prepare"],["free_source"],["kitchen_tick",1.0]])
  social_case("basket-noisy-"+locale,{"map":"lake","inventory":{"fishing_rod":1}},[["language",locale],["object","basket"],["interact"],["player",0.0,38.0,true],["tick",2.0],["player",0.0,38.0],["interact"],["lock",true],["tick",2.0],["lock",false]])
  social_case("net-dialogue-"+locale,{"map":"lake"},[["language",locale],["object","net"],["interact"],["dialogue_view"],["finish_node"],["choose_source",0],["dialogue_view"],["finish_node"],["choose_source",1],["dialogue_view"],["finish_node"],["choose_source",0],["dialogue_view"],["close"],["interact"],["close"]])
  for dish:String in Supper.DISHES:social_case("share-dialogue-"+locale+"-"+dish,{"map":"inn","flags":{"ls_cooked":true},"inventory":{dish:2}},[["language",locale],["object","table"],["interact"],["dialogue_view"],["finish_node"],["choose_source",0 if dish=="ls_chowder" else 1],["dialogue_view"],["interact"],["close"]])
  social_case("net-xp-level-"+locale,{"professions":{"xp":{"fishing":29,"cooking":29},"cooldowns":{},"future":{"keep":9007199254740993}}},[["language",locale],["object","net"],["weave","over"],["weave","under"],["weave","over"],["xp","cooking",12],["xp","fishing",2000],["xp","fishing",1],["xp","invalid",3]])
 var cooldown_keys:Array=catalogs.cooldowns.keys()
 social_case("profession-normalize-on-first-xp",{"professions":{"xp":{"fishing":29.9,"cooking":-1,"future":7},"goal":"unknown","future":{"keep":9007199254740993}}},[["xp","fishing",8],["xp","cooking",12]])
 social_case("profession-normalize-cooldown-order",{"play_time":10.0,"professions":{"cooldowns":{str(cooldown_keys[-1]):999999.0,str(cooldown_keys[0]):999999.0,"future:unknown":99.0},"goal":"ls_broth"}},[["xp","fishing",8]])
 social_case("recovery-tracker",{"map":"inn","flags":{"ls_cooked":true},"quests":{"ls_supper":{"state":"active","step":2}}},[["tracker"],["set_field","map","lake"],["tracker"],["set_field","map","forest"],["tracker"]])
 var methods:Array=["scripts/entities/world_memory.gd::build_grid","scripts/entities/supper_actor.gd::actor_name","scripts/entities/village_actor.gd::actor_name","scripts/entities/supper_object.gd::_ready","scripts/entities/memory_book.gd::_ready","scripts/world.gd::_ready","scripts/world.gd::load_map","scripts/entities/village_opening.gd::_ready","scripts/entities/lake_supper.gd::_ready","scripts/entities/lake_supper.gd::refresh","scripts/entities/village_opening.gd::_process","scripts/entities/memory_book.gd::interact","scripts/entities/memory_actor.gd::interact","scripts/core/world_memory.gd::enabled","scripts/core/world_memory.gd::resting","scripts/core/world_memory.gd::name_for","scripts/core/world_memory.gd::introduction","scripts/core/world_memory.gd::activity","scripts/core/world_memory.gd::connection","scripts/core/world_memory.gd::lines","scripts/core/world_memory.gd::meet","scripts/core/world_memory.gd::news","scripts/core/daynight.gd::phase_at","scripts/core/daynight.gd::raining","scripts/core/living_world.gd::migrate","scripts/core/opening.gd::enabled","scripts/core/opening.gd::flowing","scripts/core/opening.gd::quiet_hud","scripts/core/lake_supper.gd::inputs","scripts/core/lake_supper.gd::cook_reason","scripts/core/lake_supper.gd::cook","scripts/core/lake_supper.gd::tracker","scripts/core/lake_supper.gd::conversation","scripts/core/lake_supper.gd::action","scripts/entities/supper_object.gd::interact","scripts/entities/supper_object.gd::weave","scripts/entities/supper_object.gd::share","scripts/entities/supper_object.gd::_process","scripts/ui/supper_kitchen.gd::open","scripts/ui/supper_kitchen.gd::select_dish","scripts/ui/supper_kitchen.gd::prepare_step","scripts/ui/supper_kitchen.gd::_process","scripts/ui/supper_kitchen.gd::close","scripts/core/professions.gd::add_xp"]
 var report:Dictionary={"schema":"bluemap.resident-social.source-oracle.v1","engineVersion":Engine.get_version_info().string,"personalSavesUsed":false,"float64Encoding":"ieee754-binary64-little-endian-hex","orderedInputEncoding":"dictionary-pairs-and-exact-f64-v1","catalogs":_plain(catalogs),"catalogsExact":_exact(_plain(catalogs)),"catalogsOrdered":ordered_input(_plain(catalogs)),"newGame":baseline,"cases":social_cases,"sourceMethods":methods}
 var file:=FileAccess.open(out,FileAccess.WRITE);file.store_string(JSON.stringify(report,"",true,true)+"\n");file.close();print("MIGRATION RESIDENT SOCIAL EXPORT OK "+str(social_cases.size())+" CASES");quit(0)
