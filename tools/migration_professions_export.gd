extends "res://tools/migration_progression_export.gd"
## Execute the retained original profession, crafting, journal, shop and fishing methods.
## No source gameplay method is replaced. Random draws are recorded as explicit inputs:
## this export never claims an engine-independent random generator.
const Journal=preload("res://scripts/core/craft_journal.gd")
const Identity=preload("res://scripts/core/craft_identity.gd")
const Notes=preload("res://scripts/data/ext/craft_progression.gd")
const Forage=preload("res://scripts/core/forage_catalog.gd")
const Vis=preload("res://scripts/data/ext/meer_vis.gd")
var Lake:Script
const Reel=preload("res://scripts/ui/fishing_reel.gd")
const Orchard=preload("res://scripts/data/orchard_catalog.gd")
class ProfPlayer extends DummyPlayer:
 var facing:=Vector2.DOWN
 var target:Node2D
class ProfWorld extends DummyWorld:
 var fx_layer:=Node2D.new()
 func _init():
  player.free();player=ProfPlayer.new();add_child(player);add_child(fx_layer)
 func ring(_at:Vector2,_radius:float,_color:Color):pass
class Spot extends Node2D:
 var deep:=false
var profession_cases:Array=[]
var toasts:Array=[]
var shop_ui:CanvasLayer
var fishing:CanvasLayer
var spot:Spot
func reel_view(reel:RefCounted)->Dictionary:
 return {"zone":reel.zone_pos,"velocity":reel.zone_vel,"fish":reel.fish_pos,"target":reel.fish_target,"progress":reel.progress,"inZone":reel.in_zone,"state":reel.state,"elapsed":reel.elapsed,"retarget":reel._retarget_in}
func held(pattern:String,step:int,reel:RefCounted)->bool:
 match pattern:
  "track":return reel.fish_pos>reel.zone_pos
  "hold":return true
  "release":return false
  "pulse":return step%8<5
  "slow":return step%30<16
 return step%3==0
## Run the original reel with a seeded generator and return the exact draws it consumed.
func reel_draws(fish:String,generator_seed:int,pattern:String,steps:int,delta:float)->Array:
 var rng:=RandomNumberGenerator.new();rng.seed=generator_seed
 var twin:=RandomNumberGenerator.new();twin.seed=generator_seed;twin.state=rng.state
 var reel:RefCounted=Reel.new(rng,Vis.stats(fish));var draws:Array=[twin.randf_range(0.25,0.75)]
 assert(twin.state==rng.state and draws[0]==reel.fish_pos)
 for step:int in steps:
  var before:int=rng.state
  reel.update(delta,held(pattern,step,reel))
  if rng.state!=before:
   draws.append(twin.randf_range(0.5,1.4));draws.append(twin.randf_range(Reel.FISH_MARGIN,1.0-Reel.FISH_MARGIN))
   assert(twin.state==rng.state and draws.back()==reel.fish_target)
  if reel.state!="bezig":break
 return draws
func roll_draws(deep:bool,pity:int,golden:bool,generator_seed:int)->Array:
 var rng:=RandomNumberGenerator.new();rng.seed=generator_seed
 var twin:=RandomNumberGenerator.new();twin.seed=generator_seed;twin.state=rng.state
 var result:String=Vis.roll(rng,deep,pity,golden);var draws:Array=[]
 if deep and golden:draws.append(twin.randf())
 if result!=Vis.GOLDEN:draws.append(twin.randf())
 assert(twin.state==rng.state)
 return draws
func shop_rows(id:String)->Array:
 shop_ui.open(id);var rows:Array=[]
 for button:Button in shop_ui.list.get_children():
  if not button.is_queued_for_deletion():rows.append({"text":button.text,"disabled":button.disabled})
 shop_ui.close();return rows
## The session mirrors the two accepted branches of fishing_ui._unhandled_input.
func fishing_session(deep:bool,generator_seed:int,forced_catch:String,forced_wait:float,steps_script:Array)->Dictionary:
 spot.deep=deep;spot.position=Vector2(40,0);world.player.position=Vector2.ZERO
 fishing.phase="idle";fishing.reel=null;fishing.outcome="";fishing.catch_id="";fishing.wait_time=0.0;fishing.phase_time=0.0;fishing.forced_catch=forced_catch;fishing.forced_wait=forced_wait
 fishing.rng.seed=generator_seed
 var twin:=RandomNumberGenerator.new();twin.seed=generator_seed;twin.state=fishing.rng.state
 var draws:Array=[];var frames:Array=[]
 fishing.start(spot)
 for index:int in steps_script.size():
  var row:Array=steps_script[index];var delta:float=row[0];var action:String=row[1];var before:String=fishing.phase;var state:int=fishing.rng.state
  var pity:int=Lake.pity();var golden:bool=Lake.golden_can_bite()
  if action=="hold":Input.action_press("interact")
  if action=="release":Input.action_release("interact")
  if action=="track":
   if fishing.reel!=null and fishing.reel.fish_pos>fishing.reel.zone_pos:Input.action_press("interact")
   else:Input.action_release("interact")
  if action=="press":
   if fishing.phase=="bite":fishing._start_reel()
   elif fishing.phase=="result" and fishing.phase_time>=fishing.RESULT_LOCK:fishing._cast()
  elif action=="close":fishing.close()
  else:fishing._process(delta)
  if fishing.rng.state!=state:
   if before=="cast":draws.append(twin.randf_range(Vis.WAIT_MIN,Vis.WAIT_MAX))
   elif before=="wait":
    if deep and golden:draws.append(twin.randf())
    if fishing.catch_id!=Vis.GOLDEN:draws.append(twin.randf())
   elif before=="bite":draws.append(twin.randf_range(0.25,0.75))
   else:
    draws.append(twin.randf_range(0.5,1.4));draws.append(twin.randf_range(Reel.FISH_MARGIN,1.0-Reel.FISH_MARGIN))
   assert(twin.state==fishing.rng.state)
  if fishing.phase!=before or index%30==0 or index==steps_script.size()-1:frames.append({"index":index,"phase":fishing.phase,"time":fishing.phase_time,"wait":fishing.wait_time,"catch":fishing.catch_id,"outcome":fishing.outcome,"locked":gs.input_locked(),"reel":null if fishing.reel==null else reel_view(fishing.reel)})
 Input.action_release("interact")
 if fishing.phase!="idle":fishing.close()
 return {"draws":draws,"frames":frames,"facing":_plain(world.player.facing)}
func professions_op(o:Array)->Variant:
 match o[0]:
  "normalize":return Prof.normalize(o[1],float(o[2]))
  "prof_threshold":return Prof.threshold(o[1])
  "skill":return {"xp":Prof.xp(o[1]),"level":Prof.level(o[1])}
  "skill_xp":Prof.add_xp(o[1],int(o[2]));return {"xp":Prof.xp(o[1]),"level":Prof.level(o[1])}
  "record_fish":Prof.record_fish(o[1]);return Prof.xp("fishing")
  "give":gs.give(o[1],int(o[2]),true);return gs.count(o[1])
  "clock":gs.play_time=float(o[1]);return gs.play_time
  "remaining":return Prof.remaining(o[1])
  "dynamic_limit":return Prof.dynamic_cooldown_limit(o[1])
  "gather_reason":return Prof.gather_reason(o[1],o[2])
  "gather_amount":return Prof.gather_amount(o[1])
  "gather_duration":return Prof.gather_duration(o[1])
  "gather_animation":return Prof.gather_animation(o[1])
  "gather_tool":return Prof.gather_tool(o[1])
  "gather":return Prof.gather(o[1],o[2])
  "goal":return Journal.goal()
  "toggle_goal":Journal.toggle_goal(o[1]);return Journal.goal()
  "learn":return Journal.learn(o[1])
  "recipes_for":return Journal.recipes_for(o[1])
  "source":return Journal.source(o[1])
  "recipe_text":return Journal.recipe_text(o[1])
  "uses_text":return Journal.uses_text(o[1])
  "ingredient_status":return Journal.ingredient_status(o[1])
  "identity":return {"title":Identity.title(o[1]),"intro":Identity.intro(o[1]),"tab":Identity.tab(o[1]),"accent":Identity.accent(o[1]).to_html(false)}
  "shop_rows":return shop_rows(o[1])
  "shop_buy":
   shop_ui.open(o[1]);var entry:Dictionary=ShopData.SHOPS[o[1]]["items"][int(o[2])]
   shop_ui._buy(entry,0);shop_ui.close();return {"coins":gs.coins,"count":gs.count(entry["item"])}
  "fish_price":return Vis.price(o[1],int(o[2]),o[3])
  "golden_chance":return Vis.golden_chance(int(o[1]))
  "golden_can_bite":return Lake.golden_can_bite()
  "price_now":return Lake.price_now(o[1])
  "sale_value":return Lake.sale_value()
  "sell_fish":return Lake.sell_fish()
  "record_catch":Lake.record_catch(o[1],o[2]);return gs.meer
  "fish_roll":
   var rng:=RandomNumberGenerator.new();rng.seed=int(o[4]);return Vis.roll(rng,o[1],int(o[2]),o[3])
  "reel":
   var rng:=RandomNumberGenerator.new();rng.seed=int(o[2]);var reel:RefCounted=Reel.new(rng,Vis.stats(o[1]));var views:Array=[reel_view(reel)]
   for step:int in int(o[4]):
    reel.update(float(o[5]),held(o[3],step,reel))
    if step%120==119 or reel.state!="bezig":views.append(reel_view(reel))
    if reel.state!="bezig":break
   return views
  "fishing":return fishing_session(o[1],int(o[2]),o[3],float(o[4]),o[5])
  "rod":
   fishing.phase="idle";spot.deep=o[1];var before:int=toasts.size()
   var plek:Node2D=load("res://scripts/entities/meer_visplek.gd").new();plek.world=world;plek.obj={"type":"meer_diepe_visplek" if o[1] else "meer_visplek"};plek.set_process(false);world.add_child(plek)
   plek.interact();var started:bool=world.get_node_or_null("Vissen")!=null and world.get_node("Vissen").phase!="idle"
   if started:world.get_node("Vissen").close()
   plek.interact();var repeated:int=toasts.size()-before
   if fishing.phase!="idle":fishing.close()
   plek.free()
   return {"started":started,"toastsAfterTwoTries":repeated}
 return progression_op(o)
func professions_case(id:String,overrides:Dictionary,operations:Array):
 gs.new_game();gs.set_process(false);gs.load_pos=Vector2.ZERO;gs.meta_achievements={};Stock.busy=false;Prof._busy=false;gs.movement.stamina=100.0;context("","village",0)
 for owner:String in ["shop","vissen","crafting"]:gs.set_ui(owner,false)
 for k:String in overrides:gs.set("map_id" if k=="map" else k,overrides[k].duplicate(true) if overrides[k] is Dictionary or overrides[k] is Array else overrides[k])
 var before:=_snapshot();var results:Array=[]
 for operation:Array in operations:
  toasts.clear();var value:Variant=_plain(professions_op(operation))
  results.append({"value":value,"toasts":toasts.duplicate()})
 var after:=_snapshot()
 profession_cases.append({"id":id,"initial":before,"initialExact":_exact(before),"initialOrdered":ordered_input(before),"operations":operations,"operationsExact":_exact(operations),"operationsOrdered":ordered_input(operations),"results":results,"resultsExact":_exact(results),"expected":after,"expectedExact":_exact(after)})
func skill_xp(level:int)->int:return Prof.threshold(level)
func tool_bag(resource:Dictionary)->Dictionary:
 var bag:Dictionary={}
 if resource.has("tools"):bag[resource.tools[0]]=1
 return bag
func _run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe professions export");quit(1);return
 gs=root.get_node("GameState");gs.set_process(false);gs.meta_achievements={};gs.new_game();gs.load_pos=Vector2.ZERO
 root.get_node("Lang").set_language("nl",false)
 Lake=load("res://scripts/data/ext/meer_logic.gd")
 world=ProfWorld.new();world.process_mode=Node.PROCESS_MODE_DISABLED;world.add_to_group("world");world.player.add_to_group("player");root.add_child(world);current_scene=world
 home=Store.new();home.world=world;world.add_child(home);coast=Store.new();coast.world=world;world.add_child(coast)
 gs.toast.connect(func(text:String):toasts.append(text))
 shop_ui=load("res://scripts/ui/shop_ui.gd").new();shop_ui.set_process(false);root.add_child(shop_ui)
 spot=Spot.new();world.add_child(spot)
 fishing=load("res://scripts/ui/fishing_ui.gd").new();fishing.name="Vissen";fishing.set_process(false);fishing.set_process_unhandled_input(false);world.add_child(fishing)
 await process_frame
 var new_game:=_snapshot()
 Forage.build()
 var map_names:Dictionary={};var map_resources:Dictionary={};var dynamic_limits:Dictionary={}
 for map_id:String in Maps.MAPS:
  map_names[map_id]=Maps.MAPS[map_id].DATA.name
  var rows:Array=[]
  for obj:Dictionary in Maps.get_map(map_id).objects:
   if obj.type!="profession_resource":continue
   rows.append({"id":str(obj.get("id","")),"kind":str(obj.get("kind","")),"pos":obj.pos,"enabled":obj.get("enabled",true)})
   var rid:String=str(obj.get("id",""))
   if rid.begins_with("trail:") or rid.begins_with("winter:") or rid.begins_with("forestfood:"):dynamic_limits[rid]=Prof.dynamic_cooldown_limit(rid)
  map_resources[map_id]=rows
 var placements:Dictionary={}
 for map_id:String in Jobs.RESOURCE_PLACEMENTS:placements[map_id]=Jobs.resource_objects(map_id)
 var orchard_outputs:Dictionary={}
 for id:String in Orchard.NAMES:orchard_outputs[id]={"name":Orchard.NAMES[id],"output":Orchard.CROPS[id].output}
 var item_names:Dictionary={}
 for id:String in Items.ITEMS:item_names[id]=Items.info(id)
 var fishing_data:Dictionary={"catches":Vis.CATCHES,"golden":Vis.GOLDEN,"goldenStats":Vis.GOLDEN_STATS,"goldenChance":Vis.GOLDEN_CHANCE,"goldenPity":Vis.GOLDEN_PITY,"goldenMaxChance":Vis.GOLDEN_MAX_CHANCE,"fullPriceFish":Vis.FULL_PRICE_FISH,"capBonus":Vis.CAP_BONUS,"waitMin":Vis.WAIT_MIN,"waitMax":Vis.WAIT_MAX,"fishIds":Vis.fish_ids(),"castTime":fishing.CAST_TIME,"biteWindow":fishing.BITE_WINDOW,"resultLock":fishing.RESULT_LOCK,"haspelInterval":fishing.HASPEL_INTERVAL,
  "reel":{"startProgress":Reel.START_PROGRESS,"drainTime":Reel.DRAIN_TIME,"lift":Reel.LIFT,"gravity":Reel.GRAVITY,"drag":Reel.DRAG,"bounce":Reel.BOUNCE,"fishSpeed":Reel.FISH_SPEED,"fishMargin":Reel.FISH_MARGIN,"tireTime":Reel.TIRE_TIME,"tired":Reel.TIRED}}
 var catalogs:Dictionary={"skills":Jobs.SKILLS,"text":Jobs.TEXT,"recipes":Jobs.RECIPES,"resources":Jobs.RESOURCES,"placements":placements,"mapResources":map_resources,"dynamicLimits":dynamic_limits,"notes":Notes.NOTES,"shops":ShopData.SHOPS,"consumables":Prof.CONSUMABLES,"items":item_names,"mapNames":map_names,"foragePlaces":Forage._places,"orchard":orchard_outputs,"fishing":fishing_data,"colors":Identity.COLORS,"icons":Identity.ICONS,"harvestRange":40.0,"maxLevel":Prof.MAX_LEVEL,"maxXp":Prof.MAX_XP}
 catalogs=_plain(catalogs)
 var orders:Dictionary={}
 for id:String in ["skills","recipes","resources","placements","notes","shops","mapNames","orchard"]:orders[id]=catalogs[id].keys()
 # --- Skill thresholds, experience and normalization ---
 for n:int in range(-1,13):professions_case("threshold-%d"%n,{},[["prof_threshold",n]])
 for skill:String in Jobs.SKILLS:
  for level:int in range(1,11):
   for offset:int in [-1,0,1]:
    professions_case("skill-%s-%d-%d"%[skill,level,offset],{"professions":{"xp":{skill:maxi(0,Prof.threshold(level)+offset)},"cooldowns":{}}},[["skill",skill],["skill_xp",skill,1],["skill_xp",skill,0],["skill_xp",skill,-4],["skill",skill]])
  professions_case("skill-cap-%s"%skill,{},[["skill_xp",skill,400],["skill_xp",skill,999999999],["skill_xp",skill,5],["skill",skill]])
 professions_case("skill-unknown",{},[["skill_xp","future_skill",50],["skill","future_skill"]])
 professions_case("skill-legacy-empty",{"professions":{}},[["skill","mining"],["skill_xp","mining",31],["remaining","village:twigs_west"]])
 for fish:String in ["meer_baars","meer_snoek","meer_gouden_karper","meer_laars","potion"]:professions_case("record-fish-%s"%fish,{},[["record_fish",fish],["record_fish",fish]])
 var first_dynamic:String="" if dynamic_limits.is_empty() else dynamic_limits.keys()[0]
 var raw_cases:Array=[null,false,"text",[],{},{"xp":null,"cooldowns":null,"goal":7},{"goal":"stone_axe","xp":{"mining":-5,"foraging":99999,"cooking":12.9,"fishing":"12","smithing":true,"future":4},"cooldowns":{"village:twigs_west":50.0,"village:flint_west":99999.0,"forest:copper_west":9,"future:node":80.0,"cave:iron_entry":"80"}},{"goal":"future_recipe","xp":{"alchemy":1350,"woodcutting":1351},"cooldowns":{first_dynamic:5000.0,"trail:future:1":50.0,"winter:nowhere":90.0,"forestfood":20.0}}]
 for index:int in raw_cases.size():
  for clock:float in [0.0,10.0,60.5]:professions_case("normalize-%d-%d"%[index,int(clock)],{},[["normalize",raw_cases[index],clock]])
 for id:String in dynamic_limits.keys().slice(0,12)+["trail:future:1","winter:village","forestfood:x:y","trail","village:twigs_west"]:professions_case("dynamic-limit-%d"%profession_cases.size(),{},[["dynamic_limit",id]])
 # --- Every gathering resource ---
 for kind:String in Jobs.RESOURCES:
  var resource:Dictionary=Jobs.RESOURCES[kind];var skill:String=resource.skill;var level:int=int(resource.get("level",1));var rid:String="oracle:"+kind
  var ready:Dictionary={"map":"forest","inventory":tool_bag(resource),"professions":{"xp":{skill:Prof.threshold(level)},"cooldowns":{}},"play_time":100.0}
  professions_case("gather-ready-%s"%kind,ready,[["gather_tool",kind],["gather_amount",kind],["gather_duration",kind],["gather_animation",kind],["gather_reason",kind,rid],["gather",kind,rid],["remaining",rid],["gather_reason",kind,rid],["gather",kind,rid],["clock",100.0+float(resource.cooldown)-0.25],["remaining",rid],["gather_reason",kind,rid],["clock",100.0+float(resource.cooldown)],["gather_reason",kind,rid],["gather",kind,rid],["skill",skill]])
  if resource.has("tools"):
   var none:Dictionary=ready.duplicate(true);none.inventory={};professions_case("gather-no-tool-%s"%kind,none,[["gather_tool",kind],["gather_reason",kind,rid],["gather",kind,rid]])
   for tool:String in resource.tools:
    var owned:Dictionary=ready.duplicate(true);owned.inventory={tool:1};professions_case("gather-tool-%s-%s"%[kind,tool],owned,[["gather_tool",kind],["gather_reason",kind,rid],["gather",kind,rid]])
   var both:Dictionary=ready.duplicate(true)
   for tool:String in resource.tools:both.inventory[tool]=1
   professions_case("gather-all-tools-%s"%kind,both,[["gather_tool",kind],["gather_amount",kind],["gather",kind,rid]])
  if level>1:
   var low:Dictionary=ready.duplicate(true);low.professions.xp[skill]=Prof.threshold(level)-1;professions_case("gather-low-level-%s"%kind,low,[["gather_reason",kind,rid],["gather",kind,rid]])
  if int(Items.info(resource.item).get("max",0))>0:
   var full:Dictionary=ready.duplicate(true);full.inventory[resource.item]=int(Items.info(resource.item).max);professions_case("gather-full-%s"%kind,full,[["gather_reason",kind,rid],["gather",kind,rid]])
 professions_case("gather-unknown",{},[["gather_reason","future_kind","x"],["gather","future_kind","x"],["gather_duration","future_kind"],["gather_animation","future_kind"],["gather_tool","future_kind"]])
 professions_case("gather-iron-axe-bonus",{"inventory":{"prof_iron_axe":1},"professions":{"xp":{"woodcutting":Prof.threshold(4)},"cooldowns":{}}},[["gather_amount","stump"],["gather_tool","stump"],["gather","stump","forest:birch_west"],["gather_amount","branches"]])
 for id:String in GearData.ITEMS:
  if float(GearData.ITEMS[id].get("bonuses",{}).get("harvest_time_reduction",0.0))!=0.0:
   var ops:Array=[["equip",id]]
   for kind:String in Jobs.RESOURCES:ops.append(["gather_duration",kind])
   professions_case("gather-duration-gear-%s"%id,{"inventory":{id:1}},ops)
 for map_id:String in Jobs.RESOURCE_PLACEMENTS:
  var ops:Array=[]
  for obj:Dictionary in Jobs.resource_objects(map_id):ops.append(["gather",obj.kind,obj.id]);ops.append(["remaining",obj.id])
  var everything:Dictionary={"prof_axe":1,"prof_iron_axe":1,"prof_pickaxe":1,"prof_copper_pickaxe":1};var xp:Dictionary={}
  for skill:String in Jobs.SKILLS:xp[skill]=Prof.MAX_XP
  for kind:String in Jobs.RESOURCES:
   for tool:String in Jobs.RESOURCES[kind].get("tools",[]):everything[tool]=1
  professions_case("gather-map-%s"%map_id,{"map":map_id,"inventory":everything,"professions":{"xp":xp,"cooldowns":{}},"play_time":33.5},ops)
 # --- Every recipe ---
 for id:String in Jobs.RECIPES:
  var recipe:Dictionary=Jobs.RECIPES[id];var skill:String=recipe.skill;var station:String=recipe.get("station","")
  var valid:Dictionary={"map":station if station!="" else "forest","inventory":recipe.inputs.duplicate(),"professions":{"xp":{skill:Prof.threshold(int(recipe.level))},"cooldowns":{},"goal":id}}
  if recipe.has("unlock"):valid.flags={recipe.unlock:true}
  professions_case("craft-valid-%s"%id,valid,[["recipe_text",id],["ingredient_status",id],["craft_reason",id],["craft",id],["goal"],["skill",skill],["craft_reason",id],["craft",id]])
  var twice:Dictionary=valid.duplicate(true)
  for item:String in recipe.inputs:twice.inventory[item]=int(recipe.inputs[item])*2+1
  twice.professions.erase("goal");professions_case("craft-twice-%s"%id,twice,[["craft",id],["craft",id],["craft",id]])
  if recipe.has("unlock"):
   var locked:Dictionary=valid.duplicate(true);locked.flags={};professions_case("craft-locked-%s"%id,locked,[["recipe_text",id],["craft_reason",id],["craft",id]])
  if int(recipe.level)>1:
   var low:Dictionary=valid.duplicate(true);low.professions.xp[skill]=Prof.threshold(int(recipe.level))-1;professions_case("craft-low-level-%s"%id,low,[["craft_reason",id],["craft",id]])
  if station!="":
   var away:Dictionary=valid.duplicate(true);away.map="forest";professions_case("craft-station-%s"%id,away,[["craft_reason",id],["craft",id]])
  for item:String in recipe.inputs:
   var missing:Dictionary=valid.duplicate(true);missing.inventory[item]=int(recipe.inputs[item])-1
   professions_case("craft-missing-%s-%s"%[id,item],missing,[["recipe_text",id],["craft_reason",id],["craft",id]])
  if int(Items.info(recipe.output).get("max",0))>0 and not recipe.inputs.has(recipe.output):
   var full:Dictionary=valid.duplicate(true);full.inventory[recipe.output]=int(Items.info(recipe.output).max);professions_case("craft-full-%s"%id,full,[["craft_reason",id],["craft",id]])
  if station=="":
   for kind:String in ["home","coast"]:
    var local:Dictionary=valid.duplicate(true);local.map="player_home" if kind=="home" else "coast_workshop";local.inventory={}
    var supplies:Dictionary={}
    for item:String in recipe.inputs:
     if Stock.allowed(item) and (kind=="home" or Items.info(item).get("type","")=="material"):supplies[item]=int(recipe.inputs[item])
     else:local.inventory[item]=int(recipe.inputs[item])
    if kind=="home":local.stockroom={"home":supplies,"favorites":{},"sort":0}
    else:local.coastal_storage=supplies
    professions_case("craft-store-%s-%s"%[kind,id],local,[["context",kind,local.map,0.0,true],["recipe_text",id],["craft",id]])
    professions_case("craft-store-remote-%s-%s"%[kind,id],local,[["context",kind,local.map,999.0,true],["craft_reason",id],["craft",id]])
 professions_case("craft-unknown",{},[["craft_reason","future_recipe"],["craft","future_recipe"],["recipe_text","future_recipe"],["toggle_goal","future_recipe"]])
 # --- Journal, notes and sources ---
 var inputs_seen:Dictionary={};var outputs_seen:Dictionary={}
 for id:String in Jobs.RECIPES:
  outputs_seen[Jobs.RECIPES[id].output]=true
  for item:String in Jobs.RECIPES[id].inputs:inputs_seen[item]=true
 for item:String in inputs_seen:
  for map_id:String in ["village","forest","kruipmoeras"]:professions_case("source-%s-%s"%[item,map_id],{"map":map_id},[["source",item],["uses_text",item]])
 for item:String in outputs_seen:professions_case("recipes-for-%s"%item,{},[["recipes_for",item],["source",item],["uses_text",item]])
 for item:String in ["gel","meer_baars","jacht_vlees","jacht_huid","moeras_huid","shard","hs_honey","future_item","potion","or_carrot_seed","or_carrot","or_apple"]:
  if Items.ITEMS.has(item) or item=="future_item":professions_case("source-special-%s"%item,{},[["source",item]] if Items.ITEMS.has(item) else [["uses_text",item],["recipes_for",item]])
 for id:String in Jobs.RECIPES.keys().slice(0,6):professions_case("goal-%s"%id,{},[["goal"],["toggle_goal",id],["toggle_goal",id],["toggle_goal",id],["toggle_goal",Jobs.RECIPES.keys()[7]],["goal"]])
 professions_case("goal-invalid-saved",{"professions":{"xp":{},"cooldowns":{},"goal":"future"}},[["goal"]])
 for kind:String in Notes.NOTES.keys()+["future_note"]:professions_case("learn-%s"%kind,{},[["learn",kind],["learn",kind]])
 for skill:String in Jobs.SKILLS.keys()+["","tools","guide","supplies","compost","wine","hive","bed","wild_grape","future"]:professions_case("identity-%s"%skill,{},[["identity",skill]])
 # --- Every shop row ---
 for shop_id:String in ShopData.SHOPS:
  var shop:Dictionary=ShopData.SHOPS[shop_id];var everything:Dictionary={"bow":1}
  professions_case("shop-rows-new-%s"%shop_id,{"coins":0},[["shop_rows",shop_id]])
  professions_case("shop-rows-bow-%s"%shop_id,{"inventory":{"bow":1,"arrow":38}},[["shop_rows",shop_id]])
  for index:int in shop["items"].size():
   var entry:Dictionary=shop["items"][index];var price:int=entry.price;var bag:Dictionary={}
   for cond:Array in entry.get("if",[]):
    if cond[0]=="has":bag[cond[1]]=1
   everything[entry.item]=1
   professions_case("shop-buy-%s-%d"%[shop_id,index],{"coins":price*2+3,"inventory":bag},[["shop_buy",shop_id,index],["shop_buy",shop_id,index],["shop_buy",shop_id,index],["shop_rows",shop_id]])
   professions_case("shop-poor-%s-%d"%[shop_id,index],{"coins":price-1,"inventory":bag},[["shop_buy",shop_id,index]])
   if entry.has("if"):professions_case("shop-hidden-%s-%d"%[shop_id,index],{"coins":price},[["shop_buy",shop_id,index]])
   var cap:int=int(Items.info(entry.item).get("max",0))
   if cap>1:
    for have:int in [cap,cap-1,cap-int(entry.get("amount",1))]:
     var near:Dictionary=bag.duplicate();near[entry.item]=have;professions_case("shop-room-%s-%d-%d"%[shop_id,index,have],{"coins":price,"inventory":near},[["shop_buy",shop_id,index]])
  professions_case("shop-rows-owned-%s"%shop_id,{"inventory":everything},[["shop_rows",shop_id]])
 # --- Fishing: catch table, prices, records and the original reel ---
 for pity:int in range(0,21):professions_case("golden-chance-%d"%pity,{},[["golden_chance",pity]])
 for fish:String in Vis.CATCHES:
  for nth:int in [0,1,7,8,9,40]:
   for cap:bool in [false,true]:professions_case("fish-price-%s-%d-%s"%[fish,nth,cap],{},[["fish_price",fish,nth,cap]])
 for fish:String in Vis.CATCHES.keys()+[Vis.GOLDEN]:
  for deep:bool in [false,true]:professions_case("record-catch-%s-%s"%[fish,deep],{"meer":{"pech":3,"gevangen":2}},[["record_catch",fish,deep],["record_catch",fish,deep],["skill","fishing"]])
 professions_case("golden-can-bite",{},[["golden_can_bite"],["give","meer_gouden_karper",1],["golden_can_bite"]])
 professions_case("golden-quest-done",{"quests":{"meer_karper":{"state":"done","step":0}}},[["golden_can_bite"]])
 for sold:int in [0,6,8]:
  for cap:bool in [false,true]:
   var bag:Dictionary={"meer_baars":3,"meer_snoek":2,"meer_laars":1,"meer_gouden_karper":1}
   if cap:bag.fishers_cap=1
   professions_case("sell-fish-%d-%s"%[sold,cap],{"inventory":bag,"meer":{"verkocht":sold},"coins":5},[["price_now","meer_baars"],["price_now","meer_snoek"],["sale_value"],["sell_fish"],["sell_fish"],["sale_value"]])
 for generator_seed:int in range(1,25):
  for deep:bool in [false,true]:
   for golden:bool in [false,true]:
    var pity:int=generator_seed%17
    professions_case("fish-roll-%d-%s-%s"%[generator_seed,deep,golden],{},[["fish_roll",deep,pity,golden,generator_seed,roll_draws(deep,pity,golden,generator_seed)]])
 var reel_number:=0
 for fish:String in Vis.CATCHES.keys()+[Vis.GOLDEN]:
  for pattern:String in ["track","hold","release","pulse","tap"]:
   for delta:float in [1.0/60.0,0.05]:
    reel_number+=1;var generator_seed:int=1000+reel_number;var steps:int=int(70.0/delta)
    professions_case("reel-%s-%s-%d"%[fish,pattern,reel_number],{},[["reel",fish,generator_seed,pattern,steps,delta,reel_draws(fish,generator_seed,pattern,steps,delta)]])
 # --- Fishing sessions through the original interface phases ---
 var catch_script:Array=[[0.25,""],[0.25,""],[0.3,""],[0.3,""],[0.5,""],[0.1,"press"]]
 for step:int in 900:catch_script.append([1.0/60.0,"track"])
 catch_script.append([0.2,"press"]);catch_script.append([0.35,""]);catch_script.append([0.0,"press"]);catch_script.append([0.3,""])
 var session_number:=0
 for deep:bool in [false,true]:
  for forced:String in ["","meer_baars","meer_snoek","meer_laars","meer_gouden_karper"]:
   session_number+=1
   professions_case("fishing-session-%s-%s"%[deep,forced if forced!="" else "rolled"],{"inventory":{"fishing_rod":1},"meer":{"pech":4}},[["fishing",deep,500+session_number,forced,0.6 if forced!="" else -1.0,catch_script],["skill","fishing"]])
 professions_case("fishing-too-late",{"inventory":{"fishing_rod":1}},[["fishing",false,77,"meer_baars",0.2,[[0.5,""],[0.2,""],[0.79,""],[0.02,""],[0.4,"press"],[0.2,""],[0.1,"press"],[0.6,""]]]])
 professions_case("fishing-escape",{"inventory":{"fishing_rod":1}},[["fishing",true,78,"meer_snoek",0.1,[[0.5,""],[0.1,""],[0.0,"press"]]+range(400).map(func(_i):return [0.05,""])]])
 professions_case("fishing-close-midway",{"inventory":{"fishing_rod":1}},[["fishing",false,79,"",-1.0,[[0.5,""],[0.4,""],[0.0,"close"]]]])
 professions_case("fishing-needs-rod",{},[["rod",false]])
 professions_case("fishing-with-rod",{"inventory":{"fishing_rod":1}},[["rod",true]])
 var report:Dictionary={"schema":"bluemap.professions.source-oracle.v1","engineVersion":Engine.get_version_info().string,"personalSavesUsed":false,"float64Encoding":"ieee754-binary64-little-endian-hex","orderedInputEncoding":"dictionary-pairs-and-exact-f64-v1","randomBoundary":"recorded-generator-results-are-explicit-inputs","catalogs":catalogs,"catalogsExact":_exact(catalogs),"catalogsOrdered":ordered_input(catalogs),"orders":orders,"newGame":new_game,"cases":profession_cases,
  "sourceMethods":["scripts/core/professions.gd::normalize","scripts/core/professions.gd::dynamic_cooldown_limit","scripts/core/professions.gd::threshold","scripts/core/professions.gd::xp","scripts/core/professions.gd::level","scripts/core/professions.gd::add_xp","scripts/core/professions.gd::record_fish","scripts/core/professions.gd::craft_reason","scripts/core/professions.gd::craft","scripts/core/professions.gd::remaining","scripts/core/professions.gd::gather_reason","scripts/core/professions.gd::gather_amount","scripts/core/professions.gd::gather_duration","scripts/core/professions.gd::gather_animation","scripts/core/professions.gd::gather_tool","scripts/core/professions.gd::gather","scripts/core/craft_journal.gd::goal","scripts/core/craft_journal.gd::toggle_goal","scripts/core/craft_journal.gd::crafted","scripts/core/craft_journal.gd::learn","scripts/core/craft_journal.gd::recipes_for","scripts/core/craft_journal.gd::source","scripts/core/craft_journal.gd::recipe_text","scripts/core/craft_journal.gd::uses_text","scripts/core/craft_journal.gd::ingredient_status","scripts/core/craft_identity.gd::title","scripts/core/craft_identity.gd::intro","scripts/core/craft_identity.gd::tab","scripts/core/craft_identity.gd::accent","scripts/core/forage_catalog.gd::source","scripts/core/stockroom.gd::consume","scripts/core/stockroom.gd::available","scripts/core/living_world.gd::lantern_made","scripts/ui/shop_ui.gd::open","scripts/ui/shop_ui.gd::_populate","scripts/ui/shop_ui.gd::_label","scripts/ui/shop_ui.gd::_buy","scripts/ui/shop_ui.gd::_no_room_text","scripts/data/ext/meer_vis.gd::roll","scripts/data/ext/meer_vis.gd::price","scripts/data/ext/meer_vis.gd::golden_chance","scripts/data/ext/meer_vis.gd::stats","scripts/data/ext/meer_logic.gd::golden_can_bite","scripts/data/ext/meer_logic.gd::record_catch","scripts/data/ext/meer_logic.gd::price_now","scripts/data/ext/meer_logic.gd::sale_value","scripts/data/ext/meer_logic.gd::sell_fish","scripts/ui/fishing_reel.gd::_init","scripts/ui/fishing_reel.gd::update","scripts/ui/fishing_ui.gd::start","scripts/ui/fishing_ui.gd::_cast","scripts/ui/fishing_ui.gd::_land","scripts/ui/fishing_ui.gd::_bite","scripts/ui/fishing_ui.gd::_start_reel","scripts/ui/fishing_ui.gd::_finish","scripts/ui/fishing_ui.gd::_process","scripts/ui/fishing_ui.gd::_update_reel","scripts/ui/fishing_ui.gd::close","scripts/entities/meer_visplek.gd::interact"]}
 var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(report,"",true,true)+"\n");f.close();print("MIGRATION PROFESSIONS EXPORT OK "+str(profession_cases.size())+" CASES");quit(0)
