extends "res://tools/migration_inventory_export.gd"
## Execute original progression/equipment/appearance/craft methods, never personal profiles.
const Hero=preload("res://scripts/core/progression.gd")
const Gear=preload("res://scripts/core/equipment.gd")
const Look=preload("res://scripts/core/appearance.gd")
const Looks=preload("res://scripts/data/ext/uiterlijk.gd")
const GearData=preload("res://scripts/data/ext/uitrusting.gd")
const ShopData=preload("res://scripts/data/shops.gd")
var progression_cases:Array=[]
func progression_op(o:Array)->Variant:
 match o[0]:
  "progress":return Hero.progress()
  "normalize_xp":return Hero.normalize(o[1])
  "threshold":return Hero.threshold(o[1])
  "level_for":return Hero.level_for(o[1])
  "add_xp":gs.add_hero_xp(int(o[1]));return Hero.progress()
  "kill":gs.register_kill(o[1]);return Hero.progress()
  "quest_xp":return Hero.quest_xp(o[1])
  "finish":gs.finish_quest(o[1]);return Hero.progress()
  "enemy_xp":return Hero.enemy_xp(o[1])
  "normalize_gear":return Gear.normalize(o[1],o[2])
  "normalize_owned":return Gear.normalize_owned(o[1])
  "equipped":return Gear.equipped(o[1])
  "owned_gear":return Gear.owned(o[1])
  "equip":return Gear.equip(o[1])
  "unequip":return Gear.unequip(o[1])
  "gear_reconcile":Gear.reconcile();return gs.equipment
  "bonus":return Gear.bonus(o[1])
  "preview":return Gear.preview_bonus(o[1],o[2])
  "comparison":return Gear.comparison_text(o[1])
  "stats_text":return Gear.stats_text(o[1])
  "stamina":gs.movement.stamina=float(o[1]);return gs.movement.stamina
  "energy":return {"stamina":gs.movement.stamina,"capacity":gs.movement.capacity()}
  "normalize_appearance":return Look.normalize_appearance(o[1])
  "normalize_clothing":return Look.normalize_clothing(o[1],o[2])
  "worn":return Look.worn(o[1])
  "owned_clothing":return Look.owned_in_slot(o[1])
  "gender":Look.set_gender(o[1]);return gs.appearance
  "hair":Look.set_hair(o[1]);return gs.appearance
  "hair_color":Look.set_hair_color(o[1]);return gs.appearance
  "eyes":Look.set_eyes(o[1]);return gs.appearance
  "eye_color":Look.set_eye_color(o[1]);return gs.appearance
  "wear":return Look.wear(o[1])
  "unwear":return Look.unwear(o[1])
  "dye":return Look.dye(o[1],o[2])
  "clothing_reconcile":Look.reconcile();return gs.clothing
  "craft_reason":return Prof.craft_reason(o[1])
  "craft":return Prof.craft(o[1])
  "weapon_cost":
   var page=load("res://scripts/ui/progression_page.gd").new();var result:Dictionary=page.weapon_upgrade();page.free();return result
  "weapon_allowed":return gs.check_all(Talks.get_talk("greta_%s"%o[1])["branch"][0]["if"])
  "weapon_actions":
   gs.run_all(Talks.get_talk("greta_%s_ask"%o[1])["choices"][0]["do"]);return gs.weapon
  "set_weapon":gs.set_weapon(o[1]);return gs.weapon
  "context":context(o[1],o[2],float(o[3]),o[4]);return Stock.nearby_kind()
  "take":gs.take(o[1],int(o[2]));return gs.count(o[1])
 return null
func progression_case(id:String,overrides:Dictionary,operations:Array):
 gs.new_game();gs.set_process(false);gs.load_pos=Vector2.ZERO;gs.meta_achievements={};Stock.busy=false;Prof._busy=false;gs.movement.stamina=100.0;context("","village",0)
 for k:String in overrides:gs.set("map_id" if k=="map" else k,overrides[k].duplicate(true) if overrides[k] is Dictionary or overrides[k] is Array else overrides[k])
 var before:=_snapshot();var results:Array=[]
 for operation:Array in operations:results.append(_plain(progression_op(operation)))
 var after:=_snapshot()
 progression_cases.append({"id":id,"initial":before,"initialExact":_exact(before),"initialOrdered":ordered_input(before),"operations":operations,"operationsExact":_exact(operations),"operationsOrdered":ordered_input(operations),"results":results,"resultsExact":_exact(results),"expected":after,"expectedExact":_exact(after)})
func _run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe progression export");quit(1);return
 gs=root.get_node("GameState");gs.set_process(false);gs.meta_achievements={};gs.new_game();gs.load_pos=Vector2.ZERO
 world=DummyWorld.new();world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world);current_scene=world
 home=Store.new();home.world=world;world.add_child(home);coast=Store.new();coast.world=world;world.add_child(coast)
 var new_game:=_snapshot();var all_owned:Dictionary={};var upgrades:Dictionary={};var bonus_orders:Dictionary={}
 for id:String in GearData.ITEMS:all_owned[id]=1;bonus_orders[id]=GearData.ITEMS[id].get("bonuses",{}).keys()
 for id:String in Looks.ITEMS:all_owned[id]=1
 for id:String in Jobs.RECIPES:
  if Jobs.RECIPES[id].has("upgrade_from"):upgrades[id]=Jobs.RECIPES[id]
 var weapon_upgrades:Dictionary={}
 for pair:Array in [["wood","iron"],["iron","crystal"]]:
  var target:String=pair[1];var actions:Array=Talks.get_talk("greta_%s_ask"%target)["choices"][0]["do"];var cost:Dictionary={"from":pair[0],"target":target,"coins":0,"materials":{},"actions":actions,"speaker":"greta"}
  for action:Array in actions:
   if action[0]=="coins":cost.coins=-int(action[1])
   if action[0]=="take":cost.materials[action[1]]=int(action[2]) if action.size()>2 else 1
  weapon_upgrades[target]=cost
 weapon_upgrades.star={"from":"crystal","target":"star","kind":"guardian_reward","requiredFlag":"guardian_defeated","coins":0,"materials":{}}
 var catalogs:Dictionary={"gearSlots":Gear.SLOTS,"gear":GearData.ITEMS,"bonusLimits":Gear.BONUS_LIMITS,"clothingSlots":Looks.CLOTHING_SLOTS,"clothing":Looks.ITEMS,"hairM":Looks.HAIR_M,"hairV":Looks.HAIR_V,"hairColors":Looks.HAIR_COLORS,"eyeColors":Looks.EYE_COLORS,"eyes":Looks.EYES,"dyeColors":Looks.DYE_COLORS,"genders":Looks.GENDERS,"upgradeRecipes":upgrades,"weapons":Items.WEAPONS,"weaponUpgrades":weapon_upgrades,"skills":Jobs.SKILLS,"recipes":Jobs.RECIPES,"shops":ShopData.SHOPS,"dialogues":Talks.TALKS,"stationText":Jobs.TEXT,"enemyXp":Hero.ENEMY_XP,"quests":Quests.QUESTS}
 catalogs=_plain(catalogs)
 var orders:Dictionary={}
 for id:String in ["gearSlots","gear","bonusLimits","clothingSlots","clothing","hairM","hairV","eyes","genders","skills","upgradeRecipes","recipes","weapons"]:orders[id]=catalogs[id].keys()
 for n:int in range(-1,12):progression_case("hero-threshold-%d"%n,{},[["threshold",n],["level_for",Hero.threshold(n)]])
 for raw:Variant in [null,false,true,"2250",-100,-0.5,0,49.9,50,149,150,2249.99,2250,999999999999999999,1e30]:progression_case("hero-normalize-%d"%progression_cases.size(),{},[["normalize_xp",raw]])
 for level:int in range(1,11):
  for offset:int in [-1,0,1]:
   var xp:int=maxi(0,Hero.threshold(level)+offset)
   progression_case("hero-boundary-%d-%d"%[level,offset],{"hero_xp":xp,"coins":7},[["progress"],["add_xp",1],["add_xp",0],["add_xp",-1],["progress"]])
 progression_case("hero-multilevel-cap-repeat",{"coins":17},[["add_xp",900],["add_xp",999999999],["add_xp",50],["progress"]])
 progression_case("hero-import-level-does-not-reward",{"hero_xp":2250,"coins":3},[["progress"],["add_xp",10]])
 for kind:String in Hero.ENEMY_XP.keys()+["future_enemy"]:
  for map:String in ["forest","arena"]:progression_case("enemy-%s-%s"%[kind,map],{"map":map,"hero_xp":49},[["enemy_xp",kind],["kill",kind],["kill",kind]])
 for id:String in Quests.QUESTS:progression_case("quest-%s"%id,{"quests":{id:{"state":"active","step":0}},"hero_xp":49},[["quest_xp",id],["finish",id],["finish",id]])
 progression_case("quest-unknown",{},[["quest_xp","future_quest"],["finish","future_quest"]])
 var every_gear:Dictionary={}
 for id:String in GearData.ITEMS:
  var slot:String=Gear.slot_of(id);every_gear[slot]=id
  var ops:Array=[["owned_gear",slot],["stats_text",id],["comparison",id],["equip",id],["equip",id],["equipped",slot]]
  for stat:String in Gear.BONUS_LIMITS:ops.append(["bonus",stat]);ops.append(["preview",stat,id])
  ops.append(["energy"]);ops.append(["unequip",slot]);ops.append(["unequip",slot])
  progression_case("gear-owned-%s"%id,{"inventory":all_owned},ops)
  progression_case("gear-unowned-%s"%id,{},[["equip",id],["comparison",id],["equipped",slot]])
 var all_stats:Array=[]
 for stat:String in Gear.BONUS_LIMITS:all_stats.append(["bonus",stat])
 progression_case("gear-combined-caps",{"inventory":all_owned,"equipment":every_gear},all_stats)
 for id:String in GearData.ITEMS:
  var comparisons:Array=[["comparison",id]]
  for stat:String in Gear.BONUS_LIMITS:comparisons.append(["preview",stat,id])
  progression_case("gear-whole-set-preview-%s"%id,{"inventory":all_owned,"equipment":every_gear},comparisons)
 progression_case("gear-capacity-no-refill",{"inventory":all_owned},[["stamina",7.0],["equip","gear_bronze_helm"],["energy"],["stamina",130.0],["equip","gear_cloth_hood"],["energy"],["unequip","head"],["energy"]])
 progression_case("gear-normalize-invalid-owned",{},[["normalize_gear",{"head":"gear_bronze_helm","chest":"gear_bronze_helm","future":"gear_bronze_helm"},{"gear_bronze_helm":1.0}],["normalize_owned",{"gear_bronze_helm":1.5,"gear_cloth_hood":0.99,"future":1}],["normalize_gear",null,{}],["equip","boots"],["unequip","weapon"],["bonus","future"]])
 progression_case("gear-removal-reconcile",{"inventory":{"gear_bronze_helm":1},"equipment":{"head":"gear_bronze_helm"}},[["stamina",130.0],["take","gear_bronze_helm",1],["gear_reconcile"],["energy"]])
 for gender:String in Looks.GENDERS:
  for hair:String in Look.hair_styles(gender):progression_case("hair-%s"%hair,{},[["gender",gender],["hair",hair],["hair","future_hair"]])
 for i:int in range(-1,Looks.HAIR_COLORS.size()+1):progression_case("hair-color-%d"%i,{},[["hair_color",i]])
 for id:String in Looks.EYES:progression_case("eyes-%s"%id,{},[["eyes",id]])
 for i:int in range(-1,Looks.EYE_COLORS.size()+1):progression_case("eye-color-%d"%i,{},[["eye_color",i]])
 progression_case("appearance-invalid-input",{},[["normalize_appearance",null],["normalize_appearance",{"gender":"alien","hair":"v_lang","hair_color":999,"eyes":"future","eye_color":-1}],["gender","future"],["eyes","future"]])
 for id:String in Looks.ITEMS:
  var slot:String=Look.clothing_slot_of(id);var ops:Array=[["owned_clothing",slot],["wear",id],["wear",id],["worn",slot]]
  for i:int in range(-1,Looks.DYE_COLORS.size()+1):ops.append(["dye",slot,i])
  ops.append(["unwear",slot]);ops.append(["unwear",slot]);ops.append(["dye",slot,2])
  progression_case("clothing-owned-%s"%id,{"inventory":all_owned},ops)
  progression_case("clothing-unowned-%s"%id,{},[["wear",id],["worn",slot]])
 progression_case("clothing-invalid-normalization",{},[["normalize_clothing",{"hat":{"item":"cloth_beanie","dye":999},"top":{"item":"cloth_beanie","dye":-1}},all_owned],["normalize_clothing",null,all_owned],["unwear","future"],["owned_clothing","future"]])
 progression_case("appearance-preserve-extensions",{"appearance":{"gender":"m","hair":"m_kort","hair_color":2,"eyes":"rond","eye_color":0,"future_style":{"seed":9007199254740993,"palette":[0.15,true,"🌱"]}}},[["gender","v"],["hair_color",7],["eye_color",4]])
 var first_clothing:Dictionary={}
 for id:String in Looks.ITEMS:
  var slot:String=Look.clothing_slot_of(id)
  if not first_clothing.has(slot):first_clothing[slot]={"item":id,"dye":999,"future_trim":{"pattern":"keep"}}
 var cosmetic_ops:Array=[]
 for id:String in Looks.ITEMS:cosmetic_ops.append(["wear",id])
 for stat:String in Gear.BONUS_LIMITS:cosmetic_ops.append(["bonus",stat])
 cosmetic_ops.append(["clothing_reconcile"])
 progression_case("clothing-persist-slot-dye-no-gameplay-bonus",{"inventory":all_owned,"equipment":every_gear,"clothing":first_clothing},cosmetic_ops)
 progression_case("clothing-removal-reconcile",{"inventory":{"cloth_beanie":1},"clothing":{"hat":{"item":"cloth_beanie","dye":9}}},[["take","cloth_beanie",1],["clothing_reconcile"],["worn","hat"]])
 for id:String in upgrades:
  var recipe:Dictionary=upgrades[id];var inputs:Dictionary=recipe.inputs.duplicate();var skill:String=recipe.skill;var old:String=recipe.upgrade_from;var slot:String=Gear.slot_of(old);var valid:Dictionary={"map":recipe.get("station","forest"),"inventory":inputs,"flags":{recipe.unlock:true},"professions":{"xp":{skill:30},"cooldowns":{},"goal":id},"equipment":{slot:old}}
  progression_case("upgrade-worn-%s"%id,valid,[["craft_reason",id],["craft",id],["craft",id],["energy"]])
  var unworn:Dictionary=valid.duplicate(true);unworn.equipment={};progression_case("upgrade-unworn-%s"%id,unworn,[["craft",id]])
  var locked:Dictionary=valid.duplicate(true);locked.flags={};progression_case("upgrade-locked-%s"%id,locked,[["craft_reason",id],["craft",id]])
  var low:Dictionary=valid.duplicate(true);low.professions.xp[skill]=29;progression_case("upgrade-lowlevel-%s"%id,low,[["craft_reason",id],["craft",id]])
  if recipe.has("station"):
   var station:Dictionary=valid.duplicate(true);station.map="forest";progression_case("upgrade-station-%s"%id,station,[["craft_reason",id],["craft",id]])
  var missing:Dictionary=valid.duplicate(true);missing.inventory={};progression_case("upgrade-missing-%s"%id,missing,[["craft_reason",id],["craft",id]])
  var full:Dictionary=valid.duplicate(true);full.inventory[recipe.output]=1;progression_case("upgrade-full-%s"%id,full,[["craft_reason",id],["craft",id]])
  if not recipe.has("station"):
   for kind:String in ["home","coast"]:
    var local:Dictionary=valid.duplicate(true);local.map="player_home" if kind=="home" else "coast_workshop";local.inventory={old:1};var supplies:Dictionary=inputs.duplicate();supplies.erase(old)
    if kind=="home":local.stockroom={"home":supplies,"favorites":{},"sort":0}
    else:local.coastal_storage=supplies
    progression_case("upgrade-local-%s-%s"%[kind,id],local,[["context",kind,local.map,0.0,true],["craft",id]])
    progression_case("upgrade-remote-%s-%s"%[kind,id],local,[["context",kind,local.map,999.0,true],["craft_reason",id],["craft",id]])
 for from:String in Items.WEAPONS:progression_case("weapon-path-%s"%from,{"weapon":from},[["weapon_cost"]])
 for target:String in ["iron","crystal"]:
  var cost:Dictionary=weapon_upgrades[target]
  for shortage:String in ["none","coins","gel","shard"]:
   var bag:Dictionary=cost.materials.duplicate();var coins:int=cost.coins
   if shortage=="coins":coins-=1
   elif shortage!="none":bag[shortage]=maxi(0,int(bag.get(shortage,0))-1)
   progression_case("weapon-conditions-%s-%s"%[target,shortage],{"weapon":cost.from,"coins":coins,"inventory":bag},[["weapon_allowed",target]])
  progression_case("weapon-original-actions-%s"%target,{"weapon":cost.from,"coins":cost.coins+7,"inventory":cost.materials},[["weapon_actions",target]])
 progression_case("weapon-original-earned-opcode",{},[["set_weapon","star"]])
 var report:Dictionary={"schema":"bluemap.progression.source-oracle.v1","engineVersion":Engine.get_version_info().string,"personalSavesUsed":false,"float64Encoding":"ieee754-binary64-little-endian-hex","orderedInputEncoding":"dictionary-pairs-and-exact-f64-v1","catalogs":catalogs,"catalogsExact":_exact(catalogs),"catalogsOrdered":ordered_input(catalogs),"orders":orders,"bonusOrders":bonus_orders,"newGame":new_game,"cases":progression_cases,"sourceMethods":["scripts/core/progression.gd::normalize","scripts/core/progression.gd::threshold","scripts/core/progression.gd::level_for","scripts/core/progression.gd::progress","scripts/core/progression.gd::enemy_xp","scripts/core/progression.gd::quest_xp","scripts/core/game_state.gd::add_hero_xp","scripts/core/game_state.gd::register_kill","scripts/core/game_state.gd::finish_quest","scripts/core/game_state.gd::set_weapon","scripts/core/equipment.gd::normalize","scripts/core/equipment.gd::normalize_owned","scripts/core/equipment.gd::equip","scripts/core/equipment.gd::unequip","scripts/core/equipment.gd::reconcile","scripts/core/equipment.gd::bonus","scripts/core/equipment.gd::preview_bonus","scripts/core/equipment.gd::comparison_text","scripts/core/appearance.gd::normalize_appearance","scripts/core/appearance.gd::normalize_clothing","scripts/core/appearance.gd::set_gender","scripts/core/appearance.gd::wear","scripts/core/appearance.gd::dye","scripts/core/appearance.gd::reconcile","scripts/core/appearance.gd::set_hair","scripts/core/appearance.gd::set_hair_color","scripts/core/appearance.gd::set_eyes","scripts/core/appearance.gd::set_eye_color","scripts/core/appearance.gd::worn","scripts/core/appearance.gd::owned_in_slot","scripts/core/appearance.gd::unwear","scripts/core/equipment.gd::equipped","scripts/core/equipment.gd::owned","scripts/core/equipment.gd::stats_text","scripts/core/professions.gd::craft_reason","scripts/core/professions.gd::craft","scripts/core/craft_journal.gd::crafted","scripts/core/stockroom.gd::consume","scripts/ui/progression_page.gd::weapon_upgrade"]}
 var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(report,"",true,true)+"\n");f.close();print("MIGRATION PROGRESSION EXPORT OK "+str(progression_cases.size())+" CASES");quit(0)
