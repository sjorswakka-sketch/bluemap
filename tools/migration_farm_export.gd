extends "res://tools/migration_home_export.gd"
## Execute the retained original farming, irrigation, orchard, production and water-type methods.
## No source gameplay method is replaced. The world's collision answer (spawn_fits), the stations
## within reach and the reachable house stock are explicit recorded inputs.
const Farm=preload("res://scripts/core/homestead.gd")
const Orchard=preload("res://scripts/core/orchard.gd")
const Crops=preload("res://scripts/data/orchard_catalog.gd")
const Feedback=preload("res://scripts/core/garden_feedback.gd")
const Water=preload("res://scripts/core/water_features.gd")
const WaterLayout=preload("res://scripts/data/water_layouts.gd")
var HomeUi:Script
class FarmWorld extends HomeWorld:
 var blocked:Dictionary={}
 func spawn_fits(at:Vector2)->bool:return not blocked.has(Vector2i((at/32).floor()))
class Station extends Node2D:
 var world:Node2D
 var obj:Dictionary={}
 func refresh_yard():pass
class Animal extends Node2D:
 var dead:=false
 var kind:=""
 var home_position:=Vector2.ZERO
var farm_cases:Array=[]
var stations:Array=[]
func set_near(pairs:Array):
 for node:Node in stations:world.remove_child(node);node.free()
 stations.clear()
 for pair:Array in pairs:
  var node:=Station.new();node.world=world;node.obj={"type":"home_station","role":pair[0]}
  if pair[1]!="":node.obj["unit"]=pair[1]
  node.position=world.player.position;world.add_child(node);node.add_to_group("home_stations");stations.append(node)
func stock_near(on:bool):
 home.remove_from_group("stock_chests")
 if on:home.add_to_group("stock_chests")
 home.position=world.player.position
func move_player(at:Vector2):
 world.player.position=at
 for node:Node2D in stations:node.position=at
 home.position=at
func stand(c:Vector2i):move_player(Vector2(c)*32+Vector2(16,16))
func rect_cells(r:Array)->Array:
 var out:Array=[]
 for y:int in range(int(r[1]),int(r[3])):
  for x:int in range(int(r[0]),int(r[2])):out.append(Vector2i(x,y))
 return out
func irrigation()->Dictionary:
 Farm.dirty=true;Farm.irrigate();var wet:Array=[];var flow:Array=[]
 for at:Vector2i in Farm.wet:wet.append([at.x,at.y])
 for at:Vector2i in Farm.flow:flow.append([at.x,at.y,Farm.flow[at].x,Farm.flow[at].y])
 return {"wet":wet,"flow":flow}
func water_feature_rows(id:String)->Array:
 var out:Array=[]
 for feature:Dictionary in Maps.get_map(id).get("water_features",[]):
  var spec:Dictionary=feature.properties.duplicate();spec.color=spec.color.to_html(false)
  var cells:Array=[]
  for at:Vector2i in feature.cells:cells.append([at.x,at.y])
  out.append({"kind":feature.kind,"count":feature.count,"north":[feature.north.x,feature.north.y],"properties":spec,"cells":cells,"bankRocks":feature.bank_rocks})
 return out
func farm_op(raw:Array)->Variant:
 var o:Array=raw.map(fx)
 match o[0]:
  "player":move_player(Vector2(o[1][0],o[1][1]));return null
  "stand":stand(v(o[1]));return null
  "near":set_near(o[1]);return stations.size()
  "stock":stock_near(o[1]);return Stock.nearby_kind()
  "blocked":
   world.blocked.clear()
   for c:Array in o[1]:world.blocked[v(c)]=true
   return world.blocked.size()
  "map":gs.map_id=o[1];return gs.map_id
  "play_time":gs.play_time=float(o[1]);return gs.play_time
  "ui":gs.set_ui("migration",o[1]);return gs.input_locked()
  "ended":gs.ended=o[1];return gs.input_locked()
  "flag":gs.set_flag(o[1],o[2]);return gs.flag(o[1])
  "give":gs.give(o[1],int(o[2]),true);return gs.count(o[1])
  "take":gs.take(o[1],int(o[2]));return gs.count(o[1])
  "homestead":gs.homestead=o[1].duplicate(true);Farm.dirty=true;return null
  "farm_normalize":return Farm.normalize(o[1])
  "farm_state":return Farm.state()
  "farm_cell":return Farm.cell(o[1])
  "garden":return Farm.garden(v(o[1]))
  "irrigation":return irrigation()
  "watered":return Farm.watered(v(o[1]))
  "crop_watered":return Farm.crop_watered(v(o[1]),o[2])
  "flowers":return Farm.flowers()
  "advance":Farm.advance(float(o[1]));return [Farm.state().honey,Farm.state().honey_time]
  "status":return Farm.work_status(v(o[1]),o[2],world)
  "act":return Farm.act(v(o[1]),o[2],world)
  "harvest_reason":return Farm.harvest_reason(o[1])
  "harvest_all":return Farm.harvest_all()
  "start_job":return Farm.start_job(o[1],int(o[2]))
  "collect":return Farm.collect(o[1])
  "starter":return Farm.starter()
  "wild_grapes":return Farm.wild_grapes()
  "animal":
   var animal:=Animal.new();animal.kind=o[1];animal.home_position=Vector2(o[2][0],o[2][1]);animal.position=Vector2(o[3][0],o[3][1]);animal.dead=o[4]
   if o[5]:animal.set_meta("practice",true)
   Farm.animal_drop(animal);animal.free();return Farm.state().drops.size()
  "trees":
   var n:=0
   for node:Node in get_nodes_in_group("orchard_trees"):
    if node.world==world and not node.is_queued_for_deletion():n+=1
   return n
  "duration":return Crops.duration(o[1])
  "amount":return Crops.amount(o[1])
  "supply_reason":return Orchard.supply_reason()
  "or_starter":return Orchard.starter()
  "buy_reason":return Orchard.buy_reason(o[1],int(o[2]))
  "buy":return Orchard.buy(o[1],int(o[2]))
  "canopy_reason":return Orchard.canopy_reason(v(o[1]),world,o[2])
  "patch_reason":return Orchard.patch_reason(v(o[1]))
  "cell_text":Farm.irrigate();return Feedback.cell_text(v(o[1]))
  "guide_step":return Feedback.guide_step()
  "guide_text":return Feedback.guide_text()
  "sweep_status":
   var out:Array=[]
   for c:Vector2i in rect_cells(o[2]):stand(c);out.append(Farm.work_status(c,o[1],world).reason)
   return out
  "sweep_act":
   var out:Array=[]
   for c:Vector2i in rect_cells(o[2]):stand(c);out.append(Farm.act(c,o[1],world))
   return out
  "sweep_text":
   var out:Array=[];Farm.irrigate()
   for c:Vector2i in rect_cells(o[1]):out.append(Feedback.cell_text(c))
   return out
  "sweep_watered":
   var out:Array=[]
   for c:Vector2i in rect_cells(o[1]):out.append(Farm.watered(c))
   return out
  "sweep_canopy":
   var out:Array=[]
   for c:Vector2i in rect_cells(o[1]):out.append(Orchard.canopy_reason(c,world,o[2]))
   return out
  "sweep_patch":
   var out:Array=[]
   for c:Vector2i in rect_cells(o[1]):out.append(Orchard.patch_reason(c))
   return out
  "sweep_flowers":
   var out:Array=[]
   for c:Vector2i in rect_cells(o[1]):out.append(Yard.flower_count_at(c,o[2]))
   return out
  "sweep_cover":
   var out:Array=[]
   for c:Vector2i in rect_cells(o[1]):out.append(Crops.tree_cover(c,o[2]))
   return out
  "water_describe":return water_feature_rows(o[1])
  "water_properties":
   var spec:Dictionary=Water.properties(o[1],o[2]);spec.color=spec.color.to_html(false);return spec
  "water_irrigates":return Water.irrigates(o[1])
  "water_sweep":
   var out:Array=[];gs.map_id=o[1];world.map_data=Maps.get_map(o[1]);var rows:Array=world.map_data.rows;var step:int=int(o[2])
   for y:int in range(8,rows.size()*32,step):
    for x:int in range(8,rows[0].length()*32,step):
     world.player.position=Vector2(x,y);var near:Dictionary=Water.nearest(world,float(o[3]))
     if not near.is_empty():out.append([x,y,near.kind,near.at.x,near.at.y,near.distance])
   world.map_data=Yard.map_data();return out
  "water_context":
   gs.map_id=o[1];world.map_data=Maps.get_map(o[1]);world.player.position=Vector2(o[2][0],o[2][1]);var info:Dictionary=Water.context(world)
   world.map_data=Yard.map_data()
   if info.is_empty():return {}
   return {"title":info.title,"detail":info.detail,"locked":info.locked,"rect":[info.rect.position.x,info.rect.position.y,info.rect.size.x,info.rect.size.y]}
 return home_op(o)
func farm_case(id:String,overrides:Dictionary,operations:Array):
 gs.new_game();gs.set_process(false);gs.load_pos=Vector2.ZERO;gs.meta_achievements={};gs.transitioning=false;gs.ended=false;gs.ui_owners.clear()
 Stock.busy=false;House.busy=false;Yard.busy=false;Farm.busy=false;Orchard.busy=false;gs.movement.stamina=100.0;context("","village",0)
 clear_entities();set_near([]);world.blocked.clear();world.map_data=Yard.map_data();move_player(Vector2.ZERO);stock_near(false)
 for k:String in overrides:gs.set("map_id" if k=="map" else k,overrides[k].duplicate(true) if overrides[k] is Dictionary or overrides[k] is Array else overrides[k])
 Farm.reset()
 var before:=_snapshot();var results:Array=[]
 for operation:Array in operations:results.append(_plain(farm_op(operation)))
 var after:=_snapshot();gs.transitioning=false;gs.ended=false;gs.ui_owners.clear();clear_entities();set_near([])
 farm_cases.append({"id":id,"initial":before,"initialExact":_exact(before),"initialOrdered":ordered_input(before),"operations":operations,"operationsExact":_exact(operations),"operationsOrdered":ordered_input(operations),"results":results,"resultsExact":_exact(results),"expected":after,"expectedExact":_exact(after)})
func _run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe farm export");quit(1);return
 gs=root.get_node("GameState");gs.set_process(false);gs.meta_achievements={};gs.new_game();gs.load_pos=Vector2.ZERO
 root.get_node("Lang").set_language("nl",false)
 world=FarmWorld.new();world.process_mode=Node.PROCESS_MODE_DISABLED;world.add_to_group("world");world.player.add_to_group("player");root.add_child(world);current_scene=world
 home=Store.new();home.world=world;world.add_child(home);coast=Store.new();coast.world=world;world.add_child(coast)
 await process_frame
 var new_game:=_snapshot()
 # --- Catalogs ---
 HomeUi=load("res://scripts/ui/home_ui.gd")
 var sources:Array=[]
 for at:Vector2i in Farm.sources:sources.append([at.x,at.y])
 var mode_names:Dictionary={};var tool_modes:Array=["soil","channel","grape","flower","fertilize","harvest","fill",""]
 for mode:String in tool_modes+Crops.NAMES.keys():mode_names[mode]=HomeUi.mode_name(mode)
 var station_names:Dictionary={}
 for role:String in ["compost","wine","hive","bed","wild_grape","supplies","guide"]:station_names[role]=HomeUi.station_name(role)
 var crop_names:Dictionary={}
 for crop:String in Crops.CROPS:crop_names[crop]=Feedback.crop_name(crop)
 var farm_catalog:Dictionary={"crops":Crops.CROPS,"names":Crops.NAMES,"notes":Crops.NOTES,"prices":Crops.PRICES,"starter":Crops.STARTER,"groups":Crops.GROUPS,"jobs":Farm.JOBS,"sources":sources,"garden":[4,29,31,12],"gardenGap":[20,21],"toolModes":tool_modes,"seedBook":["carrot","pumpkin","mint","rosemary","apple","berry","grape","flower"],"modeNames":mode_names,"stationNames":station_names,"cropNames":crop_names,"pack":{"hs_hoe":1,"hs_seed":8,"hs_flower_seed":4}}
 var types:Dictionary={}
 for kind:String in Water.TYPES:
  var spec:Dictionary=Water.TYPES[kind].duplicate();spec.color=spec.color.to_html(false);types[kind]=spec
 var water_maps:Dictionary={};var map_ids:Array=Maps.MAPS.keys();map_ids.sort()
 for id:String in map_ids:
  var data:Dictionary=Maps.get_map(id);var hints:Array=WaterLayout.FEATURES.get(id,[]).duplicate(true);hints.append_array(data.get("water_hints",[]).duplicate(true))
  water_maps[id]={"rows":data.rows,"hints":hints}
 var water_catalog:Dictionary={"types":types,"estuaryDetail":Water.ESTUARY_DETAIL,"maps":water_maps,"seaMaps":["coast","gull_island","tide_cove","harbor","headland","tidal_hollow"]}
 var catalogs:Dictionary=_plain({"farm":farm_catalog,"water":water_catalog})
 var orders:Dictionary={"crops":catalogs.farm.crops.keys(),"jobs":catalogs.farm.jobs.keys(),"waterTypes":catalogs.water.types.keys(),"maps":map_ids}
 # --- Shared inputs ---
 var bag:Dictionary={"hs_hoe":1,"hs_fertilizer":20}
 for crop:String in Crops.CROPS:bag[Crops.CROPS[crop].seed]=20
 var field:Dictionary={
  "22,33":{"kind":"channel"},"23,33":{"kind":"channel"},"24,33":{"kind":"channel"},"25,33":{"kind":"channel"},
  "27,36":{"kind":"channel"},"28,36":{"kind":"channel"},
  "23,34":{"kind":"soil"},
  "24,34":{"kind":"soil","crop":"grape","growth":90.0,"fertilized":true},
  "25,34":{"kind":"soil","crop":"grape","growth":40.0,"fertilized":false},
  "26,33":{"kind":"soil","crop":"flower","growth":60.0,"fertilized":false},
  "24,32":{"kind":"soil","crop":"carrot","growth":70.0,"fertilized":true},
  "23,32":{"kind":"soil","crop":"pumpkin","growth":10.0,"fertilized":false},
  "25,32":{"kind":"soil","crop":"mint","growth":85.0,"fertilized":false},
  "22,32":{"kind":"soil","crop":"rosemary","growth":80.0,"fertilized":false,"established":true},
  "28,35":{"kind":"soil","crop":"berry","growth":0.0,"fertilized":false},
  "30,33":{"kind":"soil","crop":"apple","growth":240.0,"fertilized":false},
  "26,30":{"kind":"soil","crop":"apple","growth":100.0,"fertilized":true,"established":true},
  "32,29":{"kind":"soil","crop":"grape","growth":0.0,"fertilized":false},
  "10,31":{"kind":"soil"},"11,31":{"kind":"channel"},
  "8,34":{"kind":"soil","crop":"apple","growth":10.0,"fertilized":false},
  "15,34":{"kind":"soil","crop":"flower","growth":60.0,"fertilized":false},
  "16,33":{"kind":"soil","crop":"mint","growth":85.0,"fertilized":false},
  "14,33":{"kind":"soil","crop":"rosemary","growth":20.0,"fertilized":false}}
 var grown:Dictionary={"cells":field,"jobs":{},"animal_due":{},"drops":{},"wild_due":0.0,"honey":0,"honey_time":0.0}
 fixtures["@field"]=field;fixtures["@grown"]=grown;fixtures["@bag"]=bag
 var yard:Dictionary=Yard.defaults();var both:Dictionary=yard.duplicate(true);both.extensions=["west","east"]
 for group:String in YardData.SUPPLIES:both.owned[group]=int(YardData.SUPPLIES[group].cap)
 var moved:Dictionary=both.duplicate(true);moved.stations.wine_a=[27,32];moved.stations.hive=[9,37];moved.stations.compost=[];moved.paths={"12,33":"gravel","12,34":"stone","30,36":"boards"};moved.fences={"13,36":"fence_h","14,36":"gate_h"}
 fixtures["@yard"]=yard;fixtures["@moved"]=moved
 var garden:Array=[3,28,36,42];var east:Array=[22,29,35,41];var all_near:Array=[["guide",""],["supplies",""],["compost",""],["wine","wine_a"],["wine","wine_b"],["hive","hive"],["wild_grape",""]]
 var actions:Array=["soil","channel","fertilize","harvest","fill","","bogus"]+Crops.CROPS.keys()
 # --- Saved state ---
 farm_case("farm-defaults",{},[["farm_state"],["flowers"],["irrigation"],["guide_step"],["guide_text"]])
 var long_id:String="x".repeat(141);var many_due:Dictionary={};var many_drops:Dictionary={}
 for i:int in 140:many_due["forest:rabbit:%d,%d"%[i,i]]=float(i);many_drops["d%d"%i]={"map":"forest","pos":[float(i),2.5]}
 var raws:Array=[null,false,7,"x",[],{},
  {"cells":{"22,33":{"kind":"channel","crop":"grape"},"23,34":{"kind":"soil","crop":"grape","growth":999.0,"fertilized":true},"24,34":{"kind":"soil","crop":"mint","growth":70.0,"established":true,"fertilized":true},"25,34":{"kind":"soil","crop":"grape","growth":-4,"established":true},"26,34":{"kind":"soil","crop":"future","growth":3.0},"27,34":{"kind":"soil","crop":7},"28,34":{"kind":"path"},"29,34":"soil","20,33":{"kind":"soil"},"3,33":{"kind":"soil"},"05,30":{"kind":"soil"},"6.5,30":{"kind":"soil"},"x7,30":{"kind":"channel"},"-8,30":{"kind":"soil"},"9,30,1":{"kind":"soil"},"30":{"kind":"soil"},"10, 30":{"kind":"soil","crop":"apple","growth":"12"},"11,30":{"kind":"soil","crop":"carrot","growth":70,"established":true},"12,30":{"kind":"soil","crop":"apple","growth":200.0,"established":true,"fertilized":false,"future":3}},
   "jobs":{"compost":{"batches":0,"time":-3},"wine_a":{"batches":99.9,"time":1000},"wine_b":"x","future":{"batches":2,"time":1.0}},
   "animal_due":{"forest:rabbit:3,4":1000.0,"lake:duck:1,1":-5,long_id:3.0,"b":"x"},
   "drops":{"forest:rabbit:3,4:1200":{"map":"forest","pos":[100.5,-20]},"bad-map":{"map":3,"pos":[1,2]},"bad-pos":{"map":"forest","pos":[1]},"text-pos":{"map":"forest","pos":["1",2]},"huge":{"map":"lake","pos":[99999,10000.5]},long_id:{"map":"forest","pos":[1,2]},"plain":4},
   "wild_due":500.0,"honey":12.7,"honey_time":130.5,"future":true},
  {"cells":"x","jobs":[],"animal_due":null,"drops":7,"wild_due":"3","honey":"2","honey_time":null},
  {"cells":{},"jobs":{"wine_b":{"batches":3,"time":45.5},"compost":{"batches":"2","time":"x"},"wine_a":{}},"wild_due":-9,"honey":-2,"honey_time":-1.0},
  {"animal_due":many_due,"drops":many_drops,"honey":3,"honey_time":119.99},grown]
 for index:int in raws.size():
  farm_case("farm-normalize-%d"%index,{"play_time":50.0},[["farm_normalize",raws[index]]])
  farm_case("farm-normalize-late-%d"%index,{"play_time":4000.25},[["farm_normalize",raws[index]]])
 farm_case("farm-legacy-state",{"homestead":{"jobs":{"compost":{"batches":2,"time":5.0}}}},[["farm_state"],["flowers"]])
 var cell_ops:Array=[]
 for text:String in ["5,30","05,30"," 6,31","6.5,30","x7,30","-8,30","9,30,1","30","","a,b","1e3,2","--4,5","4-,5","12,-34","7,3.9","+3,+4"]:cell_ops.append(["farm_cell",text])
 farm_case("farm-cell-parse",{},cell_ops)
 var garden_ops:Array=[]
 for c:Vector2i in rect_cells([2,27,37,43]):garden_ops.append(["garden",[c.x,c.y]])
 farm_case("farm-garden-area",{},garden_ops)
 # --- Irrigation ---
 var nets:Dictionary={"empty":{},"field":field}
 var line:Dictionary={}
 for x:int in range(22,35):line["%d,35"%x]={"kind":"channel"}
 for y:int in range(36,41):line["34,%d"%y]={"kind":"channel"}
 line["30,34"]={"kind":"channel"};line["30,33"]={"kind":"channel"};line["29,39"]={"kind":"channel"};line["28,39"]={"kind":"channel"}
 nets["line"]=line
 var west:Dictionary={}
 for x:int in range(4,20):west["%d,33"%x]={"kind":"channel"}
 for y:int in range(29,41):west["9,%d"%y]={"kind":"channel"}
 west["5,36"]={"kind":"channel"};west["6,36"]={"kind":"channel"};west["12,38"]={"kind":"soil"};west["13,38"]={"kind":"channel"}
 nets["west"]=west
 var north:Dictionary={}
 for x:int in range(22,35,2):
  for y:int in range(29,34):north["%d,%d"%[x,y]]={"kind":"channel"}
 nets["north"]=north
 var island:Dictionary={"26,36":{"kind":"channel"},"27,36":{"kind":"channel"},"26,37":{"kind":"channel"},"12,36":{"kind":"channel"}}
 nets["island"]=island
 var ring:Dictionary={}
 for x:int in range(23,29):ring["%d,31"%x]={"kind":"channel"};ring["%d,35"%x]={"kind":"channel"}
 for y:int in range(31,36):ring["23,%d"%y]={"kind":"channel"};ring["28,%d"%y]={"kind":"channel"}
 ring["22,33"]={"kind":"channel"}
 nets["ring"]=ring
 for name:String in nets:
  var state:Dictionary={"cells":nets[name],"jobs":{},"animal_due":{},"drops":{},"wild_due":0.0,"honey":0,"honey_time":0.0}
  var ops:Array=[["irrigation"],["sweep_watered",garden]]
  for at:Array in [[26,30],[30,33],[8,34],[24,35],[33,31],[11,35],[6,38],[26,38]]:ops.append(["crop_watered",at,{"kind":"soil","crop":"apple","growth":0.0}]);ops.append(["crop_watered",at,{"kind":"soil","crop":"grape","growth":0.0}])
  ops.append(["sweep_text",garden])
  farm_case("irrigation-%s"%name,{"homestead":state},ops)
 # --- Work feedback on every garden tile ---
 var tilled_cells:Dictionary={}
 for c:Vector2i in rect_cells(garden):
  if Farm.garden(c) and Yard.terrain(c)=="." and (c.x+c.y*3)%11!=0:tilled_cells[Farm.key(c)]={"kind":"soil"}
 for x:int in range(22,35):tilled_cells["%d,36"%x]={"kind":"channel"}
 var tilled:Dictionary={"cells":tilled_cells,"jobs":{},"animal_due":{},"drops":{},"wild_due":0.0,"honey":0,"honey_time":0.0}
 var states:Dictionary={"empty":{},"field":grown,"tilled":tilled}
 for name:String in states:
  for layout:String in ["@yard","@moved"]:
   for action:String in actions:
    farm_case("status-%s-%s-%s"%[name,layout.substr(1),action],{"homestead":states[name],"yard":fixtures[layout],"inventory":bag},[["sweep_status",action,garden]])
 farm_case("status-no-hoe",{"homestead":grown},[["sweep_status","soil",east],["sweep_status","harvest",east]])
 farm_case("status-no-seed",{"homestead":grown,"inventory":{"hs_hoe":1}},[["sweep_status","grape",east],["sweep_status","apple",east],["sweep_status","fertilize",east],["sweep_status","fill",east]])
 farm_case("status-away",{"homestead":grown,"inventory":bag,"map":"forest"},[["sweep_status","soil",[22,32,26,35]]])
 var reach_ops:Array=[]
 for offset:Array in [[0,0],[68,0],[69,0],[0,-68],[48,48],[49,49],[-40,55],[200,0]]:reach_ops.append(["player",[24*32+16+offset[0],36*32+16+offset[1]]]);reach_ops.append(["status",[24,36],"soil"])
 farm_case("status-reach",{"inventory":bag},reach_ops)
 var obstacles:Array=[[24,36],[25,36],[30,33],[29,32],[26,30],[23,34],[22,33]]
 var blocked_ops:Array=[["blocked",obstacles]]
 for action:String in ["soil","channel","grape","apple","harvest","fill","fertilize"]:blocked_ops.append(["sweep_status",action,east])
 farm_case("status-blocked",{"homestead":grown,"inventory":bag},blocked_ops)
 var full_bag:Dictionary=bag.duplicate();full_bag["hs_grape"]=99;full_bag["or_carrot"]=98;full_bag["or_apple"]=97;full_bag["or_carrot_seed"]=99;full_bag["or_apple_seed"]=99;full_bag["hs_seed"]=99;full_bag["or_mint"]=99
 farm_case("status-full-bag",{"homestead":grown,"inventory":full_bag},[["sweep_status","harvest",east],["sweep_status","fill",east],["sweep_status","harvest",[4,29,18,41]],["sweep_status","fill",[4,29,18,41]]])
 farm_case("status-locked",{"homestead":grown,"inventory":bag},[["ui",true],["stand",[24,36]],["status",[24,36],"soil"],["act",[24,36],"soil"],["ui",false],["ended",true],["act",[24,36],"soil"],["ended",false],["transition",true],["act",[24,36],"soil"],["transition",false],["act",[24,36],"soil"],["farm_state"]])
 # --- Working the garden ---
 for action:String in ["soil","channel","harvest","fill","fertilize","grape","apple","carrot","mint"]:
  farm_case("act-sweep-%s"%action,{"homestead":grown,"inventory":bag},[["sweep_act",action,east],["farm_state"],["irrigation"],["trees"]])
  farm_case("act-sweep-west-%s"%action,{"homestead":grown,"inventory":bag,"yard":moved},[["sweep_act",action,[4,29,20,41]],["farm_state"],["irrigation"],["trees"]])
 farm_case("act-sweep-empty-soil",{"inventory":bag},[["sweep_act","soil",garden],["sweep_act","channel",garden],["farm_state"],["sweep_act","fill",garden],["farm_state"]])
 farm_case("act-sweep-empty-channel",{"inventory":bag},[["sweep_act","channel",garden],["irrigation"],["sweep_watered",garden],["sweep_act","soil",garden]])
 for crop:String in Crops.CROPS:
  var info:Dictionary=Crops.CROPS[crop];var at:Array=[26,34] if crop=="apple" else [25,34];var ops:Array=[["sweep_act","channel",[22,34,25,35]],["irrigation"],["stand",at],["act",at,crop],["act",at,"soil"],["status",at,crop],["act",at,crop],["act",at,crop],["cell_text",at],["trees"],["farm_state"]]
  ops.append_array([["advance",float(info.seconds)*0.5],["cell_text",at],["status",at,"harvest"],["act",at,"harvest"],["act",at,"fertilize"],["act",at,"fertilize"],["cell_text",at],["advance",float(info.seconds)*0.5-0.25],["act",at,"harvest"],["advance",0.25],["cell_text",at],["status",at,"harvest"],["act",at,"harvest"],["act",at,"harvest"],["cell_text",at],["farm_state"]])
  ops.append_array([["act",at,crop],["advance",float(info.get("regrow",info.seconds))],["cell_text",at],["act",at,"harvest"],["advance",1000.0],["act",at,"fertilize"],["act",at,"harvest"],["farm_state"],["status",at,"fill"],["act",at,"fill"],["act",at,"fill"],["act",at,"fill"],["trees"],["farm_state"]])
  farm_case("life-%s"%crop,{"inventory":bag},ops)
  farm_case("life-dry-%s"%crop,{"inventory":bag},[["stand",at],["act",at,"soil"],["act",at,crop],["advance",500.0],["cell_text",at],["act",at,"harvest"],["sweep_act","channel",[22,34,25,35]],["stand",at],["advance",500.0],["cell_text",at],["act",at,"harvest"],["trees"],["farm_state"]])
  var tight:Dictionary=bag.duplicate();tight[info.output]=99-int(info.yield);tight[info.seed]=99 if info.output!=info.seed else tight[info.output]
  farm_case("life-tight-%s"%crop,{"inventory":tight,"homestead":{"cells":{"26,37":{"kind":"soil","crop":crop,"growth":float(info.seconds),"fertilized":true},"25,37":{"kind":"soil","crop":crop,"growth":float(info.seconds),"fertilized":false}},"jobs":{},"animal_due":{},"drops":{},"wild_due":0.0,"honey":0,"honey_time":0.0}},[["stand",[26,37]],["harvest_reason",{"kind":"soil","crop":crop,"growth":float(info.seconds),"fertilized":true}],["act",[26,37],"harvest"],["act",[25,37],"harvest"],["act",[26,37],"fill"],["act",[25,37],"fill"],["take",info.output,5],["take",info.seed,3],["act",[26,37],"harvest"],["act",[26,37],"fill"],["farm_state"]])
 var reason_ops:Array=[]
 for entry:Variant in [{},{"kind":"soil"},{"kind":"soil","crop":"flower","growth":60.0},{"kind":"soil","crop":"grape","growth":89.999},{"kind":"soil","crop":"grape","growth":90.0},{"kind":"soil","crop":"mint","growth":65.0,"established":true},{"kind":"soil","crop":"mint","growth":65.0},{"kind":"soil","crop":"future","growth":1.0}]:
  reason_ops.append(["harvest_reason",entry])
  if entry.has("crop") and entry.crop!="future":reason_ops.append(["duration",entry]);reason_ops.append(["amount",entry]);reason_ops.append(["amount",{"crop":entry.crop,"fertilized":true}])
 farm_case("harvest-reasons",{},reason_ops)
 farm_case("apple-orchard",{"inventory":bag},[["stand",[26,37]],["act",[26,37],"soil"],["act",[26,37],"apple"],["trees"],["sweep_status","soil",[24,35,29,40]],["sweep_status","channel",[24,35,29,40]],["stand",[29,37]],["act",[29,37],"soil"],["status",[29,37],"apple"],["act",[29,37],"apple"],["stand",[30,37]],["act",[30,37],"soil"],["act",[30,37],"apple"],["trees"],["act",[27,37],"soil"],["act",[26,37],"fill"],["trees"],["farm_state"]])
 var orchard_cells:Dictionary={}
 for i:int in 12:orchard_cells["%d,%d"%[23+(i%4)*3,30+(i/4)*3]]={"kind":"soil","crop":"apple","growth":0.0,"fertilized":false}
 fixtures["@orchard"]=orchard_cells
 farm_case("apple-limit",{"inventory":bag,"homestead":{"cells":orchard_cells,"jobs":{},"animal_due":{},"drops":{},"wild_due":0.0,"honey":0,"honey_time":0.0}},[["stand",[8,37]],["act",[8,37],"soil"],["status",[8,37],"apple"],["act",[8,37],"apple"],["sweep_canopy",[22,29,35,41],"@orchard"],["sweep_cover",[21,28,36,42],"@orchard"]])
 for layout:String in ["@yard","@moved"]:
  farm_case("canopy-%s"%layout.substr(1),{"yard":fixtures[layout],"homestead":grown},[["sweep_canopy",garden,{}],["sweep_canopy",garden,"@field"],["sweep_patch",garden],["sweep_cover",garden,"@field"],["blocked",obstacles],["sweep_canopy",east,{}]])
 # --- Active time ---
 var steps:Array=[0.0,-3.0,0.016666666666666666,0.5,10.0,29.5,60.0,100.0,400.0]
 var time_ops:Array=[]
 for delta:float in steps:time_ops.append(["advance",delta]);time_ops.append(["farm_state"])
 time_ops.append(["sweep_text",east]);time_ops.append(["flowers"])
 farm_case("advance-field",{"homestead":grown},time_ops)
 farm_case("advance-field-moved",{"homestead":grown,"yard":moved},time_ops)
 var busy_farm:Dictionary=grown.duplicate(true);busy_farm.jobs={"compost":{"batches":2,"time":0.0},"wine_a":{"batches":20,"time":89.5},"wine_b":{"batches":1,"time":90.0}};busy_farm.honey=7;busy_farm.honey_time=119.0
 farm_case("advance-jobs",{"homestead":busy_farm},time_ops)
 var honey_ops:Array=[["flowers"]]
 for i:int in 12:honey_ops.append(["advance",119.5])
 honey_ops.append(["farm_state"]);honey_ops.append(["advance",5000.0]);honey_ops.append(["farm_state"])
 farm_case("honey-wild-flowers",{},honey_ops)
 farm_case("honey-covered",{"homestead":{"cells":{"14,34":{"kind":"soil"},"16,34":{"kind":"channel"}},"jobs":{},"animal_due":{},"drops":{},"wild_due":0.0,"honey":2,"honey_time":50.0}},honey_ops)
 farm_case("honey-stored-hive",{"yard":moved,"homestead":grown},honey_ops)
 var hive_far:Dictionary=both.duplicate(true);hive_far.stations.hive=[30,38]
 farm_case("honey-far-hive",{"yard":hive_far,"homestead":grown},honey_ops)
 farm_case("honey-full",{"homestead":{"cells":{},"jobs":{},"animal_due":{},"drops":{},"wild_due":0.0,"honey":8,"honey_time":77.0}},[["advance",1.0],["farm_state"]])
 for layout:String in ["@yard","@moved"]:
  farm_case("flower-count-%s"%layout.substr(1),{"yard":fixtures[layout]},[["sweep_flowers",[2,24,37,43],{}],["sweep_flowers",[2,24,37,43],"@field"],["sweep_flowers",[-2,-2,1,1],"@field"]])
 # --- Harvest everything ---
 for map:String in ["village","player_home","forest"]:
  farm_case("harvest-all-%s"%map,{"homestead":grown,"map":map},[["harvest_all"],["near",[["guide",""]]],["harvest_all"],["harvest_all"],["farm_state"],["advance",1000.0],["harvest_all"],["farm_state"]])
 farm_case("harvest-all-full",{"homestead":grown,"inventory":full_bag},[["near",[["guide",""]]],["harvest_all"],["farm_state"]])
 farm_case("harvest-all-supplies",{"homestead":grown},[["near",[["supplies",""]]],["harvest_all"],["near",[["wine","wine_a"]]],["harvest_all"]])
 # --- Production ---
 var stocked:Dictionary={"hs_manure":50,"hs_grape":70}
 for id:String in Farm.JOBS.keys()+["hive","future"]:
  var station:Array=["compost",""] if id=="compost" else ["hive","hive"] if id=="hive" else ["wine",id]
  var ops:Array=[["start_job",id,1],["near",[station]],["start_job",id,0],["start_job",id,21],["start_job",id,-1],["start_job",id,3],["start_job",id,1],["farm_state"],["collect",id],["advance",29.0],["collect",id],["advance",1.0],["collect",id],["advance",60.0],["collect",id],["collect",id],["farm_state"],["start_job",id,20],["advance",500.0],["collect",id],["start_job",id,20],["farm_state"]]
  farm_case("job-%s"%id,{"inventory":stocked},ops)
  farm_case("job-poor-%s"%id,{"inventory":{"hs_manure":1,"hs_grape":2}},[["near",[station]],["start_job",id,1],["give","hs_manure",1],["give","hs_grape",1],["start_job",id,2],["start_job",id,1],["farm_state"]])
  farm_case("job-away-%s"%id,{"inventory":stocked,"map":"player_home"},[["near",[station]],["start_job",id,1],["collect",id]])
  farm_case("job-wrong-station-%s"%id,{"inventory":stocked},[["near",[["guide",""],["wine","wine_b" if id=="wine_a" else "wine_a"],["hive","hive"] if id!="hive" else ["compost",""]]],["start_job",id,1],["collect",id]])
  farm_case("job-chest-%s"%id,{"inventory":{"hs_manure":1,"hs_grape":1},"stockroom":{"home":{"hs_manure":30,"hs_grape":40},"favorites":{},"sort":0}},[["near",[station]],["start_job",id,2],["stock",true],["start_job",id,21],["start_job",id,10],["farm_state"],["stock",false],["start_job",id,1]])
  var done:Dictionary={"cells":{},"jobs":{"compost":{"batches":20,"time":30.0},"wine_a":{"batches":20,"time":90.0},"wine_b":{"batches":3,"time":89.99}},"animal_due":{},"drops":{},"wild_due":0.0,"honey":8,"honey_time":0.0}
  farm_case("job-collect-full-%s"%id,{"homestead":done,"inventory":{"hs_fertilizer":50,"hs_wine":81,"hs_honey":92}},[["near",[station]],["collect",id],["take","hs_fertilizer",11],["take","hs_wine",2],["take","hs_honey",1],["collect",id],["collect",id],["farm_state"]])
  farm_case("job-collect-locked-%s"%id,{"homestead":done},[["near",[station]],["map","forest"],["collect",id],["map","village"],["collect",id]])
 # --- Supplies, seeds and wild grapes ---
 for map:String in ["village","player_home","forest"]:
  farm_case("starter-%s"%map,{"map":map},[["supply_reason"],["starter"],["or_starter"],["near",[["guide",""]]],["supply_reason"],["starter"],["starter"],["or_starter"],["or_starter"],["near",[["supplies",""]]],["supply_reason"],["near",[["compost",""]]],["supply_reason"]])
 farm_case("starter-supplies",{"map":"player_home"},[["near",[["supplies",""]]],["starter"],["or_starter"]])
 farm_case("starter-full",{"inventory":{"hs_seed":92,"or_apple_seed":99}},[["near",[["guide",""]]],["starter"],["or_starter"],["take","hs_seed",1],["take","or_apple_seed",1],["starter"],["or_starter"]])
 farm_case("starter-ended",{},[["near",[["guide",""]]],["ended",true],["supply_reason"],["or_starter"],["ended",false],["transition",true],["supply_reason"],["or_starter"],["transition",false],["or_starter"]])
 var buy_ops:Array=[["near",[["guide",""]]]]
 for crop:String in Crops.PRICES.keys()+["future"]:
  for n:int in [1,5,0,2,-1]:buy_ops.append(["buy_reason",crop,n]);buy_ops.append(["buy",crop,n])
 farm_case("buy-rich",{"coins":900},buy_ops)
 farm_case("buy-poor",{"coins":17},buy_ops)
 farm_case("buy-none",{"coins":0},buy_ops)
 farm_case("buy-away",{"coins":900},buy_ops.slice(1))
 farm_case("buy-full",{"coins":900,"inventory":{"or_apple_seed":96,"hs_seed":99,"or_mint_seed":95}},buy_ops)
 farm_case("wild-grapes",{"map":"forest","play_time":10.0},[["wild_grapes"],["near",[["wild_grape",""]]],["wild_grapes"],["wild_grapes"],["play_time",129.9],["wild_grapes"],["play_time",130.0],["wild_grapes"],["farm_state"],["map","village"],["play_time",999.0],["wild_grapes"]])
 farm_case("wild-grapes-full",{"map":"forest","inventory":{"hs_grape":97}},[["near",[["wild_grape",""]]],["wild_grapes"],["take","hs_grape",1],["wild_grapes"],["farm_state"]])
 var drop_ops:Array=[["animal","rabbit",[100.0,200.0],[110.5,205.25],false,false],["animal","rabbit",[100.0,200.0],[130.0,205.0],false,false],["animal","rabbit",[131.0,200.0],[130.0,205.0],false,false],["animal","duck",[100.0,200.0],[90.0,205.0],true,false],["animal","duck",[100.0,200.0],[90.0,205.0],false,true],["animal","trail_moth",[100.0,200.0],[90.0,205.0],false,false],["animal","trail_gull",[100.0,200.0],[90.0,205.0],false,false],["animal","deer",[-40.0,-70.0],[5.0,5.0],false,false],["farm_state"],["play_time",99.999],["animal","rabbit",[100.0,200.0],[1.0,2.0],false,false],["play_time",100.0],["animal","rabbit",[100.0,200.0],[1.0,2.0],false,false],["farm_state"]]
 farm_case("animal-drops",{"map":"forest","play_time":10.0},drop_ops)
 var crowd_ops:Array=[]
 for i:int in 70:crowd_ops.append(["animal","rabbit",[float(i*32),64.0],[float(i),3.0],false,false])
 crowd_ops.append(["farm_state"])
 farm_case("animal-drops-limit",{"map":"lake","play_time":3.5},crowd_ops)
 var dropped:Dictionary={"cells":{},"jobs":{},"animal_due":{"forest:rabbit:3,6":100.0},"drops":{"forest:rabbit:3,6:10000":{"map":"forest","pos":[110.5,205.25]},"lake:duck:1,1:500":{"map":"lake","pos":[40.0,40.0]}},"wild_due":0.0,"honey":0,"honey_time":0.0}
 farm_case("animal-drop-collected",{"homestead":dropped,"flags":{"hs_drop:lake:duck:1,1:500":true,"other":true}},[["advance",0.0],["farm_state"],["advance",0.5],["farm_state"],["flag","hs_drop:forest:rabbit:3,6:10000",true],["advance",0.5],["farm_state"]])
 # --- Garden guide ---
 farm_case("guide-steps",{},[["guide_step"],["guide_text"],["near",[["guide",""]]],["starter"],["guide_text"],["stand",[23,36]],["act",[23,36],"soil"],["guide_step"],["guide_text"],["act",[22,36],"channel"],["guide_step"],["guide_text"],["act",[23,36],"grape"],["guide_step"],["guide_text"],["advance",90.0],["act",[23,36],"harvest"],["guide_step"],["guide_text"],["farm_state"]])
 farm_case("guide-wet-soil-first",{"inventory":bag},[["stand",[23,29]],["act",[23,29],"soil"],["guide_step"],["act",[23,29],"flower"],["guide_step"],["act",[24,29],"soil"],["act",[24,29],"grape"],["guide_step"]])
 # --- Water types ---
 var type_ops:Array=[]
 for kind:String in Water.TYPES:
  type_ops.append(["water_irrigates",kind])
  for id:String in ["village","river_mouth","coast"]:type_ops.append(["water_properties",kind,id])
 type_ops.append(["water_irrigates","future"])
 farm_case("water-types",{},type_ops)
 for id:String in map_ids:farm_case("water-describe-%s"%id,{},[["water_describe",id]])
 for id:String in ["village","forest","forest_edge","ijsdal","sunwell","ridgepass","river_mouth","coast","lake","kruipmoeras","steampeak","dauwbos"]:
  var first:Array=[]
  for feature:Dictionary in Maps.get_map(id).get("water_features",[]):
   var at:Vector2i=feature.north;first.append(["water_context",id,[at.x*32+16.0,at.y*32-20.0]]);first.append(["water_context",id,[at.x*32-30.0,at.y*32+16.0]]);first.append(["water_context",id,[at.x*32+16.0,at.y*32-60.0]])
  farm_case("water-near-%s"%id,{},[["water_sweep",id,24,56.0],["water_sweep",id,40,76.0]]+first.slice(0,24))
 var report:Dictionary={"schema":"bluemap.farm.source-oracle.v1","engineVersion":Engine.get_version_info().string,"personalSavesUsed":false,"float64Encoding":"ieee754-binary64-little-endian-hex","orderedInputEncoding":"dictionary-pairs-and-exact-f64-v1","catalogs":catalogs,"catalogsExact":_exact(catalogs),"catalogsOrdered":ordered_input(catalogs),"orders":orders,"fixtures":_plain(fixtures),"fixturesOrdered":ordered_input(_plain(fixtures)),"newGame":new_game,"cases":farm_cases,
  "sourceMethods":["scripts/core/homestead.gd::key","scripts/core/homestead.gd::cell","scripts/core/homestead.gd::garden","scripts/core/homestead.gd::normalize","scripts/core/homestead.gd::number","scripts/core/homestead.gd::state","scripts/core/homestead.gd::irrigate","scripts/core/homestead.gd::watered","scripts/core/homestead.gd::flowers","scripts/core/homestead.gd::advance","scripts/core/homestead.gd::near","scripts/core/homestead.gd::starter","scripts/core/homestead.gd::act","scripts/core/homestead.gd::crop_watered","scripts/core/homestead.gd::harvest_reason","scripts/core/homestead.gd::harvest_cell","scripts/core/homestead.gd::harvest_all","scripts/core/homestead.gd::start_job","scripts/core/homestead.gd::collect","scripts/core/homestead.gd::animal_drop","scripts/core/homestead.gd::wild_grapes","scripts/core/homestead.gd::work_status",
   "scripts/core/orchard.gd::canopy_reason","scripts/core/orchard.gd::patch_reason","scripts/core/orchard.gd::supply_reason","scripts/core/orchard.gd::starter","scripts/core/orchard.gd::buy_reason","scripts/core/orchard.gd::buy","scripts/core/orchard.gd::sync",
   "scripts/data/orchard_catalog.gd::tree_cover","scripts/data/orchard_catalog.gd::duration","scripts/data/orchard_catalog.gd::amount",
   "scripts/core/garden_feedback.gd::crop_name","scripts/core/garden_feedback.gd::status","scripts/core/garden_feedback.gd::cell_text","scripts/core/garden_feedback.gd::guide_step","scripts/core/garden_feedback.gd::guide_text",
   "scripts/core/yard.gd::flower_count_at","scripts/core/yard.gd::blocks_work","scripts/core/yard.gd::anchor","scripts/core/stockroom.gd::consume","scripts/core/stockroom.gd::available",
   "scripts/core/water_features.gd::properties","scripts/core/water_features.gd::wet","scripts/core/water_features.gd::components","scripts/core/water_features.gd::enrich","scripts/core/water_features.gd::describe","scripts/core/water_features.gd::nearest","scripts/core/water_features.gd::context","scripts/core/water_features.gd::irrigates",
   "scripts/ui/home_ui.gd::mode_name","scripts/ui/home_ui.gd::station_name"]}
 var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(report,"",true,true)+"\n");f.close();print("MIGRATION FARM EXPORT OK "+str(farm_cases.size())+" CASES");quit(0)
