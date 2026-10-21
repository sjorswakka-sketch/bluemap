extends "res://tools/migration_inventory_export.gd"
## Invoke the original GameState, NPC and dialogue UI methods. No original method is copied/replaced.
const Content=preload("res://scripts/data/content.gd")
const Journey=preload("res://scripts/core/journey.gd")
const FirstRoute=preload("res://scripts/core/first_route.gd")
const Opening=preload("res://scripts/core/opening.gd")
const Living=preload("res://scripts/core/living_world.gd")
const Fish=preload("res://scripts/data/ext/meer_vis.gd")
const Books=preload("res://scripts/data/ext/meer_boeken.gd")
const Day=preload("res://scripts/core/daynight.gd")
class StoryPlayer extends DummyPlayer:
 var facing:=Vector2.DOWN
 var target:Node2D
class StoryWorld extends DummyWorld:
 func _init():
  player.free();player=StoryPlayer.new();add_child(player)
 func ring(_at:Vector2,_radius:float,_color:Color):pass
var box:CanvasLayer
var story_cases:Array=[]
var trace:Array=[]
var record_trace:=false
var object_cases:Array=[]
var stitch_context:Node
class StitchContext extends Node:
 var stitch:=0
var condition_rows:Array=[]
var action_rows:Array=[]
func emitted(kind:String,payload:Variant=null):
 if record_trace:trace.append({"kind":kind,"payload":_plain(payload)})
func connect_trace():
 for signal_name:String in ["hp_changed","items_changed","quests_changed","progression_changed","equipment_changed","appearance_changed","save_requested","ending_requested"]:
  gs.connect(signal_name,func():emitted(signal_name))
 gs.toast.connect(func(text:String):emitted("toast",text))
 gs.dialogue_requested.connect(func(id:String):emitted("dialogue_requested",id))
 gs.text_dialogue_requested.connect(func(speaker:String,lines:Array):emitted("text_dialogue_requested",{"speaker":speaker,"lines":lines}))
 gs.shop_requested.connect(func(id:String):emitted("shop_requested",id))
 gs.world_action.connect(func(action:Array):emitted("world_action",action))
func dialogue_view()->Dictionary:
 var available:Array=[]
 if box.active and box.node.has("choices") and not box.buttons.is_empty():
  for i:int in box.node.choices.size():
   var choice:Dictionary=box.node.choices[i]
   if not choice.has("if") or gs.check_all(choice["if"]):available.append(i)
 var choices:Array=[]
 for button:Button in box.buttons:choices.append(button.text)
 return {"id":box.story_id,"active":box.active,"fromData":box.from_data,"speaker":box.speaker_label.text,"lines":box.lines.duplicate(true),"choices":choices,"sourceIndices":available,"choicesReady":not box.buttons.is_empty(),"stamina":gs.movement.stamina}
func story_op(o:Array)->Variant:
 match o[0]:
  "trigger":
   var trigger:Node2D=load("res://scripts/entities/trigger.gd").new();trigger.process_mode=Node.PROCESS_MODE_DISABLED;trigger.world=world;trigger.player=world.player;trigger.rect=Rect2(-16,-16,32,32);trigger.conditions=o[1];trigger.once_flag=o[2];trigger.actions=o[3];world.player.position=Vector2.ZERO if o[4] else Vector2(80,0);world.add_child(trigger);trigger._process(0);trigger.free();return null
  "stitch_context":
   if is_instance_valid(stitch_context):stitch_context.free()
   stitch_context=StitchContext.new();stitch_context.stitch=int(o[1]);root.add_child(stitch_context);load("res://scripts/core/lake_supper.gd").pending=weakref(stitch_context);return null
  "language":root.get_node("Lang").set_language(o[1],false);return o[1]
  "hud_tracker":
   var hud:CanvasLayer=load("res://scripts/ui/hud.gd").new();hud.tracker=Label.new();hud.tracker_panel=PanelContainer.new();hud._refresh_tracker();var text:String=hud.tracker.text;hud.tracker.free();hud.tracker_panel.free();hud.free();return text
  "run":gs.run(o[1]);return null
  "run_all":gs.run_all(o[1]);return null
  "check":return gs.check(o[1])
  "check_all":return gs.check_all(o[1])
  "start":gs.start_quest(o[1]);return null
  "step":gs.set_quest_step(o[1],int(o[2]));return null
  "finish":gs.finish_quest(o[1]);return null
  "refresh":gs._refresh_quests();return null
  "state":return gs.quest_state(o[1])
  "quest_step":return gs.quest_step(o[1])
  "quest_text":return gs.quest_text(o[1])
  "tracked":return gs.tracked_text()
  "format":return gs.fmt(o[1])
  "enter":box.start(o[1]);return box.active
  "lines":box.story_id=o[1];box.start_text(o[2],o[3]);return box.active
  "finish_node":
   if not box.active or not box.buttons.is_empty():return false
   box._finish_node();return true
  "choose":
   if not box.active or o[1]<0 or o[1]>=box.buttons.size():return false
   box.buttons[o[1]].pressed.emit();return true
  "choose_source":
   if not box.active:return false
   var available:Array=[]
   for i:int in box.node.get("choices",[]).size():
    var c:Dictionary=box.node.choices[i]
    if not c.has("if") or gs.check_all(c["if"]):available.append(i)
   var at:int=available.find(int(o[1]))
   if at<0 or at>=box.buttons.size():return false
   box.buttons[at].pressed.emit();return true
  "close":box._close();return null
  "npc_variant":
   var npc:Node2D=load("res://scripts/entities/"+str(o[1])+".gd").new();npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.world=world
   if o[1]!="village_actor":npc.setup(o[2])
   if o[1] in ["supper_actor","village_actor"]:npc.role=str(o[3])
   world.add_child(npc);npc.interact();npc.free();return box.active
  "npc":
   var npc:Node2D=load("res://scripts/entities/npc.gd").new();npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.world=world;npc.setup(o[1]);npc.route_calm=float(o[2]) if o.size()>2 else 0;npc.route_panic=float(o[3]) if o.size()>3 else 0;world.add_child(npc);npc.interact();npc.free();return box.active
  "focus":return Journey.focus()
  "toggle_focus":return Journey.toggle(o[1])
  "target":return Journey.target(o[1])
  "route":return Journey.route_text(o[1])
  "compact_route":return Journey.compact_route(o[1])
  "detail":return Journey.detail(o[1])
  "preparation":return Journey.preparation(o[1])
  "stamina":gs.movement.stamina=float(o[1]);return gs.movement.stamina
  "set_field":gs.set("map_id" if o[1]=="map" else o[1],o[2]);return null
 return null
func story_case(id:String,overrides:Dictionary,operations:Array):
 record_trace=false
 if is_instance_valid(stitch_context):stitch_context.free()
 load("res://scripts/core/lake_supper.gd").pending=null
 box._close();box.node={};box.lines=[];box.speaker_label.text="";box.from_data=true;gs.new_game();gs.set_process(false);gs.load_pos=Vector2.ZERO;gs.meta_achievements={};root.get_node("Lang").set_language("nl",false)
 for k:String in overrides:gs.set("map_id" if k=="map" else k,overrides[k].duplicate(true) if overrides[k] is Dictionary or overrides[k] is Array else overrides[k])
 var before:=_snapshot();trace=[];record_trace=true;var results:Array=[];var observations:Array=[]
 for op:Array in operations:
  var result:Variant=story_op(op);results.append(_plain(result));observations.append({"state":_snapshot(),"dialogue":dialogue_view(),"events":trace.duplicate(true)})
 record_trace=false
 var after:=_snapshot()
 story_cases.append({"id":id,"initial":before,"initialExact":_exact(before),"initialOrdered":ordered_input(before),"operations":operations,"operationsExact":_exact(operations),"operationsOrdered":ordered_input(operations),"results":results,"resultsExact":_exact(results),"expected":after,"expectedExact":_exact(after),"observations":observations,"observationsExact":_exact(observations),"observationsOrdered":ordered_input(observations)})
func put_cond(f:Dictionary,c:Array,yes:bool=true):
 var id:String=str(c[0]);var amount:int=int(c[2]) if c.size()>2 and c[2] is int else 1
 if id in ["flag","no_flag"]:
  if not f.has("flags"):f.flags={}
  f.flags[str(c[1])]=yes if id=="flag" else not yes
 elif id in ["quest","step"]:
  if not f.has("quests"):f.quests={}
  f.quests[str(c[1])]={"state":("active" if id=="step" else str(c[2])) if yes else "none","step":int(c[2]) if id=="step" else 0}
 elif id in ["has","lacks"]:
  if not f.has("inventory"):f.inventory={}
  f.inventory[str(c[1])]=amount if yes==(id=="has") else maxi(0,amount-1)
 elif id=="coins":f.coins=int(c[1]) if yes else maxi(0,int(c[1])-1)
 elif id=="map":f.map=str(c[1]) if yes else "village"
 elif id=="weapon":f.weapon=str(c[1]) if yes else ("wood" if c[1]!="wood" else "iron")
 elif id=="crystals":
  if not f.has("inventory"):f.inventory={}
  for i:int in 3:f.inventory[["crystal_bos","crystal_ruine","crystal_grot"][i]]=1 if i<(int(c[1]) if yes else maxi(0,int(c[1])-1)) else 0
 elif id=="hurt":f.hp=2 if yes else 5
 elif id in ["kills","rolls","potions_drunk"]:f[id]=int(c[1]) if yes else maxi(0,int(c[1])-1)
 elif id in ["max_deaths","max_boss_deaths"]:f[id.trim_prefix("max_")]=int(c[1]) if yes else int(c[1])+1
 elif id=="kills_of":f.kills_by={str(c[1]):int(c[2]) if yes else maxi(0,int(c[2])-1)}
 elif id=="kinds_killed":
  f.kills_by={}
  for kind:String in c[1]:f.kills_by[kind]=1 if yes else 0
 elif id=="talked_to_all":
  f.talked={}
  if yes:
   for npc_id:String in c[1]:f.talked[npc_id]=true
 elif id=="finished_within":f.flags={"game_completed":yes};f.play_time=float(c[1])
 elif id=="chests_in":
  if not f.has("flags"):f.flags={}
  if yes:
   for map:String in c[1]:f.flags["chest:"+map+":0"]=true
 elif id=="any":
  for i:int in range(1,c.size()):put_cond(f,c[i],yes and i==1)
 elif id=="phase":f.day_time={"ochtend":0.15,"dag":0.3,"avond":0.6,"nacht":0.8}.get(str(c[1]),0.3) if yes else 0.94
 elif id=="echo_ready":f.weapon="iron" if yes else "wood"
 elif id=="boog_missing":
  if not f.has("flags"):f.flags={}
  for i:int in range(1,c.size()):f.flags[str(c[i])]=not yes
 elif id=="meer_vis":f.inventory={"meer_baars":1 if yes else 0}
 elif id=="meer_vol":f.meer={"verkocht":8 if yes else 7}
 elif id=="meer_boeken":
  if not f.has("inventory"):f.inventory={}
  for i:int in 3:f.inventory[["meer_boek_eiland","meer_boek_hut","meer_boek_sanne"][i]]=1 if i<(int(c[1]) if yes else maxi(0,int(c[1])-1)) else 0
 elif id=="meer_gelezen":
  if not f.has("flags"):f.flags={}
  var n:=0
  for book_id:String in Books.TEXTS:
   f.flags[Books.flag_name(book_id)]=n<(int(c[1]) if yes else maxi(0,int(c[1])-1));n+=1
 elif id=="arena_registered":f.flags={"arena_signed_bronze":yes}
 elif id=="arena_open":f.quests={"main":{"state":"active","step":0}};f.weapon="iron" if yes else "wood"
func fixture(conds:Array)->Dictionary:
 var f:Dictionary={}
 for c:Array in conds:put_cond(f,c)
 return f
func census(v:Variant,path:String):
 if v is Dictionary:
  for key:Variant in v:
   if str(key) in ["if","advance_if","requires","exists_if","block_if","open_if","conditions"] and v[key] is Array:
    for c:Array in v[key]:
     if not condition_rows.any(func(r):return r.value==c):condition_rows.append({"path":path+"/"+str(key),"value":c})
   if str(key)=="do" and v[key] is Array:
    for a:Array in v[key]:action_rows.append({"path":path+"/do","value":a})
   census(v[key],path+"/"+str(key))
 elif v is Array:
  for i:int in v.size():census(v[i],path+"/"+str(i))
func translations()->Dictionary:
 var result:Dictionary={}
 for locale:String in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false);var data:Dictionary={};var translation:Translation=TranslationServer.get_translation_object(locale)
  if translation!=null:
   for message:StringName in translation.get_message_list():data[str(message)]=str(translation.get_message(message))
  for pair:Array in [["%d vis","%d vissen"],["%d munt","%d munten"]]:
   data[pair[0]]=TranslationServer.translate_plural(pair[0],pair[1],1);data[pair[1]]=TranslationServer.translate_plural(pair[0],pair[1],2)
  result[locale]=data
 root.get_node("Lang").set_language("nl",false);return result
func supper_texts()->Dictionary:
 var result:Dictionary={};var supper:Script=load("res://scripts/core/lake_supper.gd");var old:Dictionary=gs.flags.duplicate(true);gs.flags={}
 for role:String in ["joris","bo","nelle"]:result[role]=supper.conversation(role)
 for flag:String in ["op_water","cat_found","rf_memorial"]:
  gs.flags={flag:true};result[flag]=supper.conversation("")
 gs.flags=old;return result
func object_case(id:String,map:String,spec:Dictionary,overrides:Dictionary,operations:Array):
 record_trace=false
 if is_instance_valid(stitch_context):stitch_context.free()
 load("res://scripts/core/lake_supper.gd").pending=null
 box._close();box.node={};box.lines=[];box.speaker_label.text="";box.from_data=true;gs.new_game();gs.set_process(false);gs.load_pos=Vector2.ZERO;gs.meta_achievements={};gs.map_id=map;world.player.position=Vector2(0,38);world.player.attack_timer=0;world.player.roll_timer=0;world.player.sprinting=false
 for k:String in overrides:gs.set("map_id" if k=="map" else k,overrides[k].duplicate(true) if overrides[k] is Dictionary or overrides[k] is Array else overrides[k])
 var path:String="res://scripts/entities/opening_device.gd" if spec.type=="opening_device" else "res://scripts/entities/route_object.gd"
 var actor:Node2D=load(path).new();actor.process_mode=Node.PROCESS_MODE_DISABLED;actor.world=world
 if spec.type=="opening_device":actor.kind=spec.kind
 else:actor.obj=spec
 world.add_child(actor)
 var before:=_snapshot();trace=[];record_trace=true;var observations:Array=[]
 for op:Array in operations:
  match op[0]:
   "interact":actor.interact()
   "tick":actor._process(float(op[1]))
   "action":gs.run(op[1])
   "player":world.player.position=Vector2(float(op[1]),float(op[2]));world.player.attack_timer=float(op[3]) if op.size()>3 else 0
   "close":box._close()
  var transient:Dictionary={"working":actor.working,"progress":actor.progress} if spec.type=="opening_device" else {"listening":actor.listening,"progress":actor.progress,"pulse":actor.pulse}
  observations.append({"state":_snapshot(),"dialogue":dialogue_view(),"events":trace.duplicate(true),"actor":transient})
 record_trace=false
 var after:=_snapshot();actor.free()
 object_cases.append({"id":id,"map":map,"spec":spec,"initial":before,"initialExact":_exact(before),"initialOrdered":ordered_input(before),"operations":operations,"operationsExact":_exact(operations),"operationsOrdered":ordered_input(operations),"results":[],"resultsExact":[],"expected":after,"expectedExact":_exact(after),"observations":observations,"observationsExact":_exact(observations),"observationsOrdered":ordered_input(observations)})
func _run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i:int in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe story export");quit(1);return
 gs=root.get_node("GameState");gs.set_process(false);gs.meta_achievements={};gs.new_game();gs.load_pos=Vector2.ZERO
 world=StoryWorld.new();world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world);current_scene=world
 box=load("res://tools/migration_story_dialogue_fixture.gd").new();root.add_child(box);connect_trace()
 var baseline:=_snapshot();var talks:Dictionary={}
 for id:String in Talks.TALKS:talks[id]=Talks.get_talk(id)
 var modules:Array=[]
 for m:Script in Content.MODULES:
  var constants:Dictionary=m.get_script_constant_map();modules.append({"path":m.resource_path.trim_prefix("res://"),"conditions":constants.get("CONDITIONS",[]),"actions":constants.get("ACTIONS",[]),"formats":constants.get("FORMATS",[])})
 var maps:Dictionary={}
 for id:String in Maps.MAPS:maps[id]=Maps.get_map(id)
 var catalogs:Dictionary={"quests":Quests.QUESTS,"dialogues":talks,"npcs":Npcs.NPCS,"items":Items.ITEMS,"weapons":Items.WEAPONS,"modules":modules,"conditionNames":["flag","no_flag","quest","step","has","lacks","coins","map","weapon","crystals","hurt"]+Content.condition_names(),"actionNames":["start_quest","quest_step","finish_quest","set_flag","clear_flag","give","take","coins","heal","weapon","toast","sound","shop","save","ending","sell_all","talk","boss_start","music","lock_arena"]+Content.action_names(),"formatNames":["crystals","gel","shards","coins"]+Content.format_names(),"translations":translations(),"supperLines":supper_texts(),"journeyTargets":Journey.TARGETS,"maps":maps,"fish":Fish.CATCHES,"fishOrder":Fish.fish_ids(),"fishFullPrice":Fish.FULL_PRICE_FISH,"fishCapBonus":Fish.CAP_BONUS,"bookTexts":Books.TEXTS,"arenaRanks":load("res://scripts/data/arena.gd").RANKS,"arenaOrder":load("res://scripts/data/arena.gd").ORDER}
 census(talks,"dialogues");census(Npcs.NPCS,"npcs");census(Quests.QUESTS,"quests");census(maps,"maps")
 catalogs.conditionOccurrences=condition_rows;catalogs.actionOccurrences=action_rows
 for id:String in talks:
  story_case("dialogue-node-"+id,{},[["enter",id],["finish_node"]])
  for i:int in talks[id].get("choices",[]).size():
   var choice:Dictionary=talks[id].choices[i];var f:=fixture(choice.get("if",[]))
   story_case("dialogue-choice-"+id+"-"+str(i),f,[["enter",id],["finish_node"],["choose_source",i]])
  for i:int in talks[id].get("branch",[]).size():
   var branch:Dictionary=talks[id].branch[i];var f:Dictionary={}
   for j:int in i:
    var previous:Dictionary=talks[id].branch[j]
    if previous.has("if") and not previous["if"].is_empty():put_cond(f,previous["if"][0],false)
   for c:Array in branch.get("if",[]):put_cond(f,c)
   story_case("dialogue-branch-"+id+"-"+str(i),f,[["enter",id],["finish_node"]])
 for id:String in Npcs.NPCS:
  var rules:Array=Npcs.info(id).rules
  for i:int in rules.size():
   var f:Dictionary={}
   for j:int in i:
    var previous:Dictionary=rules[j]
    if previous.has("if") and not previous["if"].is_empty():put_cond(f,previous["if"][0],false)
   for c:Array in rules[i].get("if",[]):put_cond(f,c)
   story_case("npc-rule-"+id+"-"+str(i),f,[["npc",id,2.0,0.0],["close"]])
 for id:String in Quests.QUESTS:
  story_case("quest-lifecycle-"+id,{},[["state",id],["quest_step",id],["start",id],["start",id],["quest_text",id],["finish",id],["finish",id],["state",id],["quest_step",id]])
  var steps:Array=Quests.info(id).steps
  for i:int in steps.size():
   var f:=fixture(steps[i].get("advance_if",[]));if not f.has("quests"):f.quests={}
   f.quests[id]={"state":"active","step":i}
   story_case("quest-step-"+id+"-"+str(i),f,[["refresh"],["quest_text",id],["target",id],["detail",id],["toggle_focus",id],["focus"],["tracked"],["toggle_focus",id]])
 for i:int in condition_rows.size():
  var c:Array=condition_rows[i].value
  for yes:bool in [false,true]:
   var f:Dictionary={};put_cond(f,c,yes);story_case("condition-"+str(i)+"-"+str(yes),f,[["check",c],["check_all",[c]]])
 for id:String in maps:story_case("preparation-"+id,{"map":id},[["preparation",id]])
 story_case("actions-ordered-core",{"inventory":{"gel":8,"potion":2},"hp":2},[["run_all",[["start_quest","kat"],["set_flag","cat_found"],["quest_step","kat",1],["give","heart_container"],["take","gel",3],["coins",40],["coins",-100],["heal"],["weapon","iron"],["toast","Verhaaltekst"],["sound","quest"],["shop","tobias"],["save"],["music","village"],["lock_arena"],["boss_start"],["ending"]]],["finish","kat"],["finish","kat"]])
 story_case("sell-all-original",{"inventory":{"gel":5,"future_item":3}},[["run",["sell_all","gel"]],["run",["sell_all","gel"]]])
 story_case("fish-sale-price-boundary",{"inventory":{"meer_snoek":2,"meer_baars":3,"meer_laars":1,"fishers_cap":1},"meer":{"verkocht":7,"future":{"keep":9007199254740993}}},[["format","{boeken} {visgeld}"],["run",["meer_verkoop"]],["run",["meer_verkoop"]]])
 story_case("arena-register-cancel",{"coins":100},[["run",["arena_enter","bronze"]],["run",["arena_enter","silver"]],["run",["arena_cancel"]],["run",["arena_cancel"]],["format","{arena_title} {arena_best_bronze}"]])
 story_case("opening-greta-reaction",{"quests":{"first_water":{"state":"active","step":2}},"flags":{"op_new_adventure":true,"op_water":true}},[["npc","greta",0.0,0.0],["close"],["npc","greta",0.0,0.0]])
 story_case("first-route-bram-homecoming",{"flags":{"rf_memorial":true,"rf_echo_end":true}},[["npc","bram",0.0,0.0],["close"],["npc","bram",0.0,0.0]])
 for id:String in ["mira","olav","stien"]:story_case("living-npc-reaction-"+id,{"flags":{"lw_forest":true,"lw_heat":true,"lw_bridge":true},"quests":{"dauw":{"state":"done","step":2},"mistbloemen":{"state":"done","step":1},"veenbessen":{"state":"done","step":1}}},[["npc",id,0.0,0.0]])
 story_case("future-story-fields-retained",{"flags":{"future_story":{"number":9007199254740993,"exact":0.15,"nested":["🌿",true]}},"quests":{"kat":{"state":"active","step":0,"future_journal":{"note":"keep","float":0.7}}}},[["run",["set_flag","cat_found"]],["finish","kat"],["run",["clear_flag","cat_found"]]])
 for id:String in ["rg_raf","rg_ise"]:
  story_case("npc-coast-resident-"+id,{"map":"harbor"},[["npc_variant","coast_resident",id],["close"],["npc_variant","coast_resident",id]])
 for role:String in ["joris","bo","nelle"]:
  for bits:int in 8:
   story_case("npc-supper-inn-"+role+"-"+str(bits),{"map":"inn","flags":{"op_water":bool(bits&1),"cat_found":bool(bits&2),"rf_memorial":bool(bits&4)}},[["npc_variant","supper_actor","meer_joris",role]])
  story_case("npc-supper-lake-"+role,{"map":"lake"},[["npc_variant","supper_actor","meer_joris",role]])
 for role:String in ["gardener","courier"]:
  for bits:int in 16:
   story_case("npc-village-"+role+"-"+str(bits),{"map":"village","flags":{"op_new_adventure":bool(bits&1),"op_water":bool(bits&2),"ls_served":bool(bits&4)},"inventory":{"op_rake":1 if bits&8 else 0}},[["npc_variant","village_actor","",role],["close"],["npc_variant","village_actor","",role]])
 story_case("npc-village-newgameplus",{"ng_plus":1},[["npc_variant","village_actor","","gardener"]])
 story_case("format-real-pending-stitches",{},[["stitch_context",0],["format","{ls_stitch}"],["stitch_context",1],["format","{ls_stitch}"],["stitch_context",2],["format","{ls_stitch}"]])
 for locale:String in ["nl","en"]:
  for map:String in maps:
   # Keep only relevant simultaneous quests; all33 quest graphs are independently exercised above.
   var active_quests:Dictionary={"main":{"state":"active","step":0}}
   var local:String={"village":"first_water","smithy":"first_water","ruins":"rf_memory","cave":"rf_echo","forest":"kat","lake":"ls_supper","inn":"ls_supper","dorstvallei":"cactusvijgen","sunwell":"cactusvijgen","ridgepass":"ra_ridge","reedvault":"ra_archive"}.get(map,"")
   if local!="":active_quests[local]={"state":"active","step":0}
   story_case("journey-language-"+locale+"-"+map,{"map":map,"quests":active_quests,"flags":{"op_new_adventure":true,"ls_cooked":true}},[["language",locale],["hud_tracker"],["toggle_focus","main"],["hud_tracker"],["route","main"],["preparation",map],["format","{crystals} {gel} {shards} {coins} {boeken} {visgeld} {arena_title} {arena_best_bronze} {ls_stitch}"]])
 # Real original trigger nodes cover the catalog-external boss/talk opcodes and once-gates.
 for map:String in maps:
  for index:int in maps[map].objects.size():
   var obj:Dictionary=maps[map].objects[index]
   if obj.type=="trigger":
    var f:=fixture(obj.get("conditions",[]));f.map=map
    story_case("world-trigger-"+map+"-"+str(index),f,[["trigger",obj.get("conditions",[]),obj.get("once",""),obj.do,false],["trigger",obj.get("conditions",[]),obj.get("once",""),obj.do,true],["close"],["trigger",obj.get("conditions",[]),obj.get("once",""),obj.do,true]])
 object_case("opening-grate-without-rake","village",{"type":"opening_device","kind":"grate"},{},[["interact"]])
 object_case("opening-grate-work-and-repeat","village",{"type":"opening_device","kind":"grate"},{"inventory":{"op_rake":1}},[["interact"],["tick",1.59],["tick",0.01],["interact"]])
 object_case("opening-grate-movement-cancel","village",{"type":"opening_device","kind":"grate"},{"inventory":{"op_rake":1}},[["interact"],["tick",0.8],["player",8.01,38.0],["tick",0.8]])
 object_case("opening-grate-attack-cancel","village",{"type":"opening_device","kind":"grate"},{"inventory":{"op_rake":1}},[["interact"],["player",0.0,38.0,0.1],["tick",1.6]])
 object_case("opening-wheel-locked","village",{"type":"opening_device","kind":"wheel"},{},[["interact"]])
 object_case("opening-wheel-once","village",{"type":"opening_device","kind":"wheel"},{"flags":{"op_grate":true},"inventory":{"op_rake":1}},[["interact"],["interact"]])
 for kind:String in ["track","relief","journal"]:
  object_case("route-investigate-"+kind,"forest" if kind=="track" else "ruins",{"type":"route_object","kind":kind,"id":"rf_tracks" if kind=="track" else "rf_"+kind},{},[["interact"],["close"],["interact"]])
 for choice:String in ["guard","guide"]:
  object_case("route-memorial-"+choice,"ruins",{"type":"route_object","kind":"memorial","id":"rf_memorial"},{"flags":{"rf_relief":true,"rf_journal":true},"quests":{"medaillon":{"state":"done","step":1}}},[["interact"],["action",["rf_choose",choice]],["action",["rf_choose",choice]]])
 object_case("route-memorial-far-context","ruins",{"type":"route_object","kind":"memorial","id":"rf_memorial"},{"flags":{"rf_relief":true,"rf_journal":true},"quests":{"medaillon":{"state":"done","step":1}}},[["interact"],["player",64.01,0.0],["action",["rf_choose","guard"]],["player",64.0,0.0],["action",["rf_choose","guard"]]])
 for id:String in ["rf_echo_begin","rf_echo_mid","rf_echo_end"]:
  object_case("route-echo-"+id,"cave",{"type":"route_object","kind":"bowl","id":id},{"flags":{"rf_echo_begin":id!="rf_echo_begin","rf_echo_mid":id=="rf_echo_end"}},[["interact"],["tick",1.49],["tick",0.01],["interact"],["tick",1.5]])
 object_case("route-echo-noisy-cancel","cave",{"type":"route_object","kind":"bowl","id":"rf_echo_begin"},{},[["interact"],["player",0.0,38.0,0.1],["tick",1.5]])
 object_case("route-echo-wrong-order","cave",{"type":"route_object","kind":"bowl","id":"rf_echo_end"},{},[["interact"]])
 var report:Dictionary={"schema":"bluemap.story.source-oracle.v1","engineVersion":Engine.get_version_info().string,"personalSavesUsed":false,"float64Encoding":"ieee754-binary64-little-endian-hex","orderedInputEncoding":"dictionary-pairs-and-exact-f64-v1","catalogs":_plain(catalogs),"catalogsExact":_exact(_plain(catalogs)),"catalogsOrdered":ordered_input(_plain(catalogs)),"newGame":baseline,"cases":story_cases,"objectCases":object_cases,"sourceMethods":["scripts/entities/village_actor.gd::interact","scripts/entities/coast_resident.gd::interact","scripts/entities/supper_actor.gd::interact","scripts/core/lake_supper.gd::stitch","scripts/core/lake_supper.gd::conversation","scripts/entities/trigger.gd::_process","scripts/entities/opening_device.gd::interact","scripts/entities/opening_device.gd::_process","scripts/entities/route_object.gd::interact","scripts/entities/route_object.gd::remember","scripts/entities/route_object.gd::_process","scripts/core/first_route.gd::choose","scripts/ui/hud.gd::_refresh_tracker","scripts/core/game_state.gd::run","scripts/core/game_state.gd::run_all","scripts/core/game_state.gd::check","scripts/core/game_state.gd::check_all","scripts/core/game_state.gd::start_quest","scripts/core/game_state.gd::set_quest_step","scripts/core/game_state.gd::finish_quest","scripts/core/game_state.gd::_refresh_quests","scripts/core/game_state.gd::quest_text","scripts/core/game_state.gd::tracked_text","scripts/core/game_state.gd::fmt","scripts/entities/npc.gd::interact","scripts/ui/dialogue_box.gd::start","scripts/ui/dialogue_box.gd::_finish_node","scripts/ui/dialogue_box.gd::_choose","scripts/ui/dialogue_box.gd::_show_choices","scripts/data/dialogue.gd::get_talk","scripts/data/content.gd::check_condition","scripts/data/content.gd::run_action","scripts/data/content.gd::format_text","scripts/core/journey.gd::focus","scripts/core/journey.gd::toggle","scripts/core/journey.gd::target","scripts/core/journey.gd::route_text","scripts/core/journey.gd::detail","scripts/core/journey.gd::preparation","scripts/core/journey.gd::tracker"]}
 var file:=FileAccess.open(out,FileAccess.WRITE);file.store_string(JSON.stringify(report,"",true,true)+"\n");file.close();print("MIGRATION STORY EXPORT OK "+str(story_cases.size())+" CASES");quit(0)
