extends "res://tools/migration_route_export.gd"
## Actual original inventory/storage entity methods, exclusively UUID isolated.
const Stock=preload("res://scripts/core/stockroom.gd")
const Coast=preload("res://scripts/core/coastal_home.gd")
const Maps=preload("res://scripts/maps/registry.gd")
class Store extends Node2D:
 var world:Node2D
 var obj:Dictionary={"role":"storage"}
var home:Store
var coast:Store
var inventory_cases:Array=[]
var chest_catalog:Array=[]
var pickup_catalog:Array=[]
var loaded_scene_loot:Array=[]
func ordered_input(value:Variant)->Variant:
 if value is float:return {"$f64":PackedFloat64Array([value]).to_byte_array().hex_encode()}
 if value is Dictionary:
  var pairs:Array=[]
  for key:Variant in value:pairs.append([str(key),ordered_input(value[key])])
  return {"$dict":pairs}
 if value is Array:
  var children:Array=[]
  for child:Variant in value:children.append(ordered_input(child))
  return children
 return value
func freeze_inventory(node:Node):
 node.set_process(false);node.set_physics_process(false);node.set_process_input(false);node.set_process_unhandled_input(false)
 for child:Node in node.get_children():freeze_inventory(child)
func loaded_loot():
 world.free();world=null
 var scenarios:Script=load("res://tools/migration_world_scenarios.gd")
 for scenario:Dictionary in scenarios.manifest():
  for map:String in scenario.maps:
   scenarios.configure(scenario.id);gs.map_id=map;gs.spawn_name="start";gs.use_load_pos=false
   seed(scenarios.FIXTURE_SEED+hash(scenario.id+":"+map))
   var actual:Node2D=load("res://scenes/main.tscn").instantiate();actual.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(actual);current_scene=actual;freeze_inventory(actual)
   await process_frame;freeze_inventory(actual);scenarios.project(actual);freeze_inventory(actual)
   await process_frame;freeze_inventory(actual);await process_frame;freeze_inventory(actual)
   var row:Dictionary={"map":map,"scenario":scenario.id,"chests":[],"pickups":[],"stores":[]}
   for node:Node in actual.entities.get_children():
    var script:Script=node.get_script();var path:String=script.resource_path if script!=null else ""
    var source:Array=[actual.entities.get_index(),node.get_index()]
    if path=="res://scripts/entities/chest.gd":row.chests.append({"uniqueKey":node.unique_key,"contents":_plain(node.contents),"position":_plain(node.position),"opened":node.opened,"sourceAddress":source})
    if path=="res://scripts/entities/pickup.gd":row.pickups.append({"uniqueKey":node.unique_key,"item":node.item,"position":_plain(node.position),"sourceAddress":source})
    if path=="res://scripts/entities/stock_chest.gd":row.stores.append({"kind":"home","position":_plain(node.position),"sourceAddress":source})
    if path=="res://scripts/entities/coastal_workstation.gd" and node.obj.role=="storage":row.stores.append({"kind":"coast","position":_plain(node.position),"sourceAddress":source})
   loaded_scene_loot.append(row);actual.free();await process_frame
func context(kind:String,map:String,distance:float,live:bool=true):
 gs.map_id=map;gs.in_game=live;world.player.position=Vector2(distance,0)
 home.remove_from_group("stock_chests");coast.remove_from_group("coastal_workstations")
 if kind=="home":home.add_to_group("stock_chests")
 if kind=="coast":coast.add_to_group("coastal_workstations")
func inventory_op(o:Array)->Variant:
 match o[0]:
  "room":return gs.room(o[1])
  "give":gs.give(o[1],int(o[2]),true);return gs.count(o[1])
  "take":gs.take(o[1],int(o[2]));return gs.count(o[1])
  "coins":gs.add_coins(int(o[1]));return gs.coins
  "stamina":gs.movement.stamina=float(o[1]);return gs.movement.stamina
  "use":return {"used":Prof.use_item(o[1]),"stamina":gs.movement.stamina}
  "full_text":return gs.full_text(o[1])
  "normalize_home":return Stock.normalize(o[1])
  "normalize_coast":return Coast.normalize(o[1])
  "stock_room":return Stock.room(o[1],o[2])
  "stock_movable":return Stock.movable(o[1],o[2],o[3])
  "stock_transfer":return Stock.transfer(o[1],int(o[2]),o[3],o[4])
  "stock_bulk":return Stock.bulk(o[1],o[2])
  "stock_consume":return Stock.consume(o[1])
  "stock_available":return Stock.available(o[1])
  "favorite":Stock.toggle_favorite(o[1]);return Stock.favorite(o[1])
  "sort":Stock.state().sort=int(o[1]);return Stock.state().sort
  "ids":return Stock.ids(o[1],o[2],int(o[3]),o[4])
  "context":context(o[1],o[2],float(o[3]),o[4]);return Stock.nearby_kind()
  "chest":return _op(o)
  "pickup":return _op(o)
  "magnet":
   var pickup:Node2D=load("res://scripts/entities/pickup.gd").new();pickup.process_mode=Node.PROCESS_MODE_DISABLED;pickup.world=world;pickup.item=o[1];pickup.position=Vector2(float(o[2]),0);pickup.t=0;pickup.age=float(o[3]);pickup.player=world.player;world.add_child(pickup)
   pickup._process(float(o[4]));var result:Dictionary={"position":_plain(pickup.position),"age":pickup.age,"collected":pickup.collected,"range":pickup.magnet_range()};pickup.free();return result
  "language":root.get_node("Lang").set_language(o[1],false);return o[1]
 return null
func inventory_case(id:String,overrides:Dictionary,operations:Array):
 gs.new_game();gs.set_process(false);gs.load_pos=Vector2.ZERO;gs.meta_achievements={};Stock.busy=false;Coast.busy=false;root.get_node("Lang").set_language("nl",false);context("","village",0)
 for k:String in overrides:gs.set("map_id" if k=="map" else k,overrides[k].duplicate(true) if overrides[k] is Dictionary or overrides[k] is Array else overrides[k])
 var before:=_snapshot();var results:Array=[]
 for operation:Array in operations:results.append(inventory_op(operation))
 var after:=_snapshot()
 inventory_cases.append({"id":id,"initial":before,"initialExact":_exact(before),"initialOrdered":ordered_input(before),"operations":operations,"operationsExact":_exact(operations),"operationsOrdered":ordered_input(operations),"results":_plain(results),"resultsExact":_exact(_plain(results)),"expected":after,"expectedExact":_exact(after)})
func _run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe inventory export");quit(1);return
 gs=root.get_node("GameState");gs.set_process(false);gs.meta_achievements={};gs.new_game();gs.load_pos=Vector2.ZERO
 world=DummyWorld.new();world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world);current_scene=world
 home=Store.new();home.world=world;world.add_child(home);coast=Store.new();coast.world=world;world.add_child(coast)
 var baseline:=_snapshot()
 for id:String in Items.ITEMS:
  var cap:int=Items.info(id).get("max",0)
  if cap>0:inventory_case("bag_cap_"+id,{"inventory":{id:maxi(0,cap-1)}},[["room",id],["give",id,4],["room",id],["give",id,1],["take",id,1],["room",id]])
 inventory_case("bag_unlimited_and_unknown",{"inventory":{"future_stack":9007199254740993}},[["give","prof_branch",1000001],["room","prof_branch"],["give","future_stack",2],["take","prof_branch",3]])
 inventory_case("coins_clamp",{"coins":2},[["coins",-9],["coins",15]])
 inventory_case("take_reconciles_gear",{"inventory":{"gear_bastion_coat":1},"equipment":{"chest":"gear_bastion_coat"}},[["take","gear_bastion_coat",1]])
 inventory_case("take_reconciles_clothing",{"inventory":{"cloth_shirt":1},"clothing":{"top":{"item":"cloth_shirt","dye":2}}},[["take","cloth_shirt",1]])
 inventory_case("heart_container_heals",{"hp":2},[["give","heart_container",1],["give","heart_container",4]])
 for id:String in Prof.CONSUMABLES:
  inventory_case("use_hurt_"+id,{"hp":2,"inventory":{id:2}},[["stamina",30.0],["use",id]])
  inventory_case("use_full_"+id,{"inventory":{id:2}},[["use",id]])
 inventory_case("use_missing_or_tool",{},[["use","hs_grape"],["use","prof_pickaxe"]])
 inventory_case("full_text_owned",{"inventory":{"gear_bastion_coat":1,"heart_container":3,"arrow":40}},[["full_text","gear_bastion_coat"],["full_text","heart_container"],["full_text","arrow"],["full_text","prof_branch"]])
 # Export canonical original object indices; no synthesized reward identifiers.
 for map:String in Maps.MAPS:
  var data:Dictionary=Maps.get_map(map)
  for index:int in data.objects.size():
   var obj:Dictionary=data.objects[index];var key:String="%s:%s:%d" % [obj.type,map,index]
   if obj.type=="chest":
    chest_catalog.append({"map":map,"index":index,"uniqueKey":key,"spec":_plain(obj)})
    inventory_case("original_chest_"+map+"_"+str(index),{},[["chest",key,obj.contents],["chest",key,obj.contents]])
   if obj.type=="pickup":pickup_catalog.append({"map":map,"index":index,"uniqueKey":key if obj.get("unique",false) else "","spec":_plain(obj)})
 inventory_case("chest_owned_coat",{"inventory":{"gear_bastion_coat":1},"equipment":{"chest":"gear_bastion_coat"}},[["chest","chest:probe:owned",[["gear_bastion_coat",1],["coins",75]]]])
 inventory_case("chest_aggregate_refused",{"inventory":{"arrow":25}},[["chest","chest:probe:aggregate",[["arrow",10],["coins",25],["arrow",10]]]])
 inventory_case("chest_aggregate_exact_fit",{"inventory":{"arrow":20}},[["chest","chest:probe:aggregate",[["arrow",10],["coins",25],["arrow",10]]]])
 inventory_case("chest_hearts_capped",{"inventory":{"heart_container":3}},[["chest","chest:probe:hearts",[["heart_container",1],["coins",7]]]])
 inventory_case("chest_owned_only",{"inventory":{"gear_bronze_helm":1}},[["chest","chest:probe:only",[["gear_bronze_helm",1]]]])
 for item:String in ["coin","heart","arrow","potion","prof_branch","hs_grape","crystal_bos","ruin_key","gear_bronze_helm"]:
  inventory_case("pickup_"+item,{"hp":2},[["pickup",item,"pickup:probe:"+item]])
 inventory_case("pickup_heart_full",{},[["pickup","heart",""]])
 inventory_case("pickup_arrow_full",{"inventory":{"arrow":40}},[["pickup","arrow",""]])
 for item:String in ["coin","heart","arrow","prof_branch","hs_grape"]:
  inventory_case("magnet_"+item,{"hp":2},[["magnet",item,50.0,0.3,0.1]])
 inventory_case("magnet_full_heart_remains",{},[["magnet","heart",30.0,0.3,0.1]])
 inventory_case("magnet_full_ammo_remains",{"inventory":{"arrow":40}},[["magnet","arrow",30.0,0.3,0.1]])
 inventory_case("magnet_outside_range",{},[["magnet","coin",54.0,0.3,0.1]])
 inventory_case("magnet_no_early_collection",{},[["magnet","coin",10.0,0.0,0.1]])
 inventory_case("magnet_owned_not_worn",{"inventory":{"gear_pg_pack_plus":1}},[["magnet","coin",65.0,0.3,0.1]])
 inventory_case("magnet_worn_pack",{"inventory":{"gear_pg_pack_plus":1},"equipment":{"chest":"gear_pg_pack_plus"}},[["magnet","coin",65.0,0.3,0.1]])
 var invalid:Dictionary={"home":{"prof_branch":1200,"potion":2.9,"arrow":0,"gear_bastion_coat":1,"future_stack":3,"hs_grape":true},"favorites":{"prof_branch":true,"gear_bastion_coat":true,"future_stack":true,"potion":false},"sort":7.9}
 inventory_case("normalize_invalid_home",{},[["normalize_home",invalid],["normalize_home",[]],["normalize_home",{"home":{"prof_branch":-1,"gel":4},"sort":-8}]])
 inventory_case("normalize_invalid_coast",{},[["normalize_coast",{"gel":1000,"prof_branch":2.9,"potion":1,"future_stack":2,"shard":0}],["normalize_coast",null]])
 var many:Dictionary={};var materials:Dictionary={}
 for id:String in Items.ITEMS:
  if Stock.allowed(id):many[id]=3
  if Coast.allowed(id):materials[id]=3
 inventory_case("normalize_home_slot_limit",{},[["normalize_home",{"home":many}]])
 inventory_case("normalize_coast_slot_limit",{},[["normalize_coast",materials]])
 for point:Dictionary in [{"id":"home","kind":"home","map":"player_home","reach":176.0},{"id":"village","kind":"home","map":"village","reach":176.0},{"id":"coast","kind":"coast","map":"coast_workshop","reach":96.0}]:
  for distance:float in [point.reach,point.reach+0.01]:
   inventory_case("reach_"+point.id+"_"+str(int(distance*100)),{"inventory":{"prof_branch":5}},[["context",point.kind,point.map,distance,true],["stock_transfer","prof_branch",1,true,point.kind]])
 inventory_case("storage_wrong_map",{"inventory":{"prof_branch":5}},[["context","home","forest",0,true],["stock_transfer","prof_branch",1,true,"home"]])
 inventory_case("storage_not_in_game",{"inventory":{"prof_branch":5}},[["context","home","player_home",0,false],["stock_transfer","prof_branch",1,true,"home"]])
 inventory_case("home_transfer_roundtrip",{"inventory":{"prof_branch":30,"potion":6,"gear_bronze_helm":1,"ruin_key":1}},[["context","home","player_home",0,true],["stock_transfer","prof_branch",10,true,"home"],["stock_transfer","potion",6,true,"home"],["stock_transfer","prof_branch",2,false,"home"],["stock_transfer","gear_bronze_helm",1,true,"home"],["stock_transfer","ruin_key",1,true,"home"],["stock_transfer","prof_branch",0,true,"home"],["stock_transfer","prof_branch",99,true,"home"]])
 inventory_case("home_cap_and_partial",{"inventory":{"prof_branch":20},"stockroom":{"home":{"prof_branch":995},"favorites":{},"sort":0}},[["context","home","player_home",0,true],["stock_movable","prof_branch",true,"home"],["stock_transfer","prof_branch",5,true,"home"],["stock_transfer","prof_branch",4,true,"home"],["stock_room","prof_branch","home"]])
 inventory_case("withdraw_ammo_limit",{"inventory":{"arrow":38},"stockroom":{"home":{"arrow":10},"favorites":{},"sort":0}},[["context","home","player_home",0,true],["stock_transfer","arrow",3,false,"home"],["stock_transfer","arrow",2,false,"home"],["stock_transfer","arrow",1,false,"home"]])
 inventory_case("coast_material_only",{"inventory":{"prof_branch":110,"potion":3,"arrow":5}},[["context","coast","coast_workshop",0,true],["stock_transfer","potion",1,true,"coast"],["stock_transfer","arrow",1,true,"coast"],["stock_transfer","prof_branch",100,true,"coast"],["stock_transfer","prof_branch",99,true,"coast"],["stock_transfer","prof_branch",1,false,"coast"]])
 var twelve:Dictionary={}
 for id:String in materials:
  if twelve.size()<12:twelve[id]=1
 inventory_case("coast_twelve_species",{"inventory":{"prof_branch":5},"coastal_storage":twelve},[["context","coast","coast_workshop",0,true],["stock_room","prof_branch","coast"],["stock_transfer","prof_branch",1,true,"coast"]])
 inventory_case("bulk_existing_skip_favorites",{"inventory":{"prof_branch":9,"gel":6,"potion":4,"arrow":7,"gear_bronze_helm":1},"stockroom":{"home":{"prof_branch":2,"potion":1,"arrow":3},"favorites":{"prof_branch":true},"sort":0}},[["context","home","player_home",0,true],["stock_bulk",true,"home"]])
 inventory_case("bulk_materials_only",{"inventory":{"prof_branch":9,"gel":6,"potion":4,"arrow":7,"gear_bronze_helm":1},"stockroom":{"home":{},"favorites":{"prof_branch":true},"sort":0}},[["context","home","player_home",0,true],["stock_bulk",false,"home"]])
 inventory_case("consume_bag_then_home",{"inventory":{"prof_branch":2},"stockroom":{"home":{"prof_branch":7,"gel":5},"favorites":{},"sort":0}},[["context","home","player_home",0,true],["stock_available","prof_branch"],["stock_consume",{"prof_branch":5,"gel":2}]])
 inventory_case("consume_preflight_no_loss",{"inventory":{"prof_branch":2},"stockroom":{"home":{"prof_branch":7},"favorites":{},"sort":0}},[["context","home","player_home",0,true],["stock_consume",{"prof_branch":5,"gel":2}]])
 inventory_case("consume_no_remote_supply",{"inventory":{"prof_branch":2},"stockroom":{"home":{"prof_branch":7},"favorites":{},"sort":0}},[["context","home","player_home",200,true],["stock_available","prof_branch"],["stock_consume",{"prof_branch":5}]])
 var listing:Dictionary={"potion":3,"prof_branch":8,"hs_grape":2,"or_apple":1,"arrow":14,"gear_bronze_helm":1,"ruin_key":1,"future_stack":3,"gel":6,"hs_seed_grape":4}
 inventory_case("favorites_toggle_known_only",{},[["favorite","prof_branch"],["favorite","prof_branch"],["favorite","gear_bronze_helm"],["favorite","future_stack"]])
 for language:String in ["nl","en"]:
  for order:int in range(4):
   var ops:Array=[["language",language],["sort",order],["ids",listing,"",0,false],["ids",listing,"  GRAPE  " if language=="en" else "  DRUIF  ",0,false],["ids",listing,"prof_",0,false],["favorite","prof_branch"],["ids",listing,"",0,true]]
   for filter:int in range(1,6):ops.append(["ids",listing,"",filter,false])
   inventory_case("query_"+language+"_sort_"+str(order),{},ops)
 var names:Dictionary={}
 for language:String in ["nl","en"]:
  root.get_node("Lang").set_language(language,false);var localized:Dictionary={}
  for id:String in Items.ITEMS:localized[id]=TranslationServer.translate(Items.info(id).name)
  names[language]=localized
 await loaded_loot()
 var report:Dictionary={"schema":"bluemap.inventory-state.source-oracle.v1","engineVersion":Engine.get_version_info().string,"float64Encoding":"ieee754-binary64-little-endian-hex","orderedInputEncoding":"dictionary-pairs-and-exact-f64-v1","personalSavesUsed":false,"newGame":baseline,"catalogs":{"items":_plain(Items.ITEMS),"quests":_plain(Quests.QUESTS),"gear":_plain(preload("res://scripts/data/ext/uitrusting.gd").ITEMS),"bonusLimits":_plain(preload("res://scripts/core/equipment.gd").BONUS_LIMITS),"consumables":Prof.CONSUMABLES,"professionsDefaults":Prof.normalize({}),"names":names},"chests":chest_catalog,"pickups":pickup_catalog,"loadedSceneLoot":loaded_scene_loot,"cases":inventory_cases,"sourceMethods":["scripts/core/game_state.gd::room","scripts/core/game_state.gd::give","scripts/core/game_state.gd::take","scripts/core/game_state.gd::add_coins","scripts/core/game_state.gd::full_text","scripts/core/game_state.gd::_refresh_quests","scripts/core/game_state.gd::use_potion","scripts/core/professions.gd::use_reason","scripts/core/professions.gd::use_item","scripts/entities/chest.gd::interact","scripts/entities/pickup.gd::_collect","scripts/entities/pickup.gd::_process","scripts/entities/pickup.gd::magnet_range","scripts/core/stockroom.gd::normalize","scripts/core/stockroom.gd::nearby_kind","scripts/core/stockroom.gd::room","scripts/core/stockroom.gd::movable","scripts/core/stockroom.gd::transfer","scripts/core/stockroom.gd::bulk","scripts/core/stockroom.gd::consume","scripts/core/stockroom.gd::ids","scripts/core/stockroom.gd::toggle_favorite","scripts/core/coastal_home.gd::normalize","scripts/maps/registry.gd::get_map","scripts/world.gd::load_map","tools/migration_world_scenarios.gd::project"]}
 var file:=FileAccess.open(out,FileAccess.WRITE)
 if file==null:push_error("Cannot write inventory oracle");quit(1);return
 file.store_string(JSON.stringify(report,"",true,true)+"\n");file.close();print("MIGRATION INVENTORY EXPORT OK "+str(inventory_cases.size())+" CASES");quit(0)
