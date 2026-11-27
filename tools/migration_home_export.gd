extends "res://tools/migration_progression_export.gd"
## Execute the retained original personal home and yard methods. No source gameplay method is replaced.
const House=preload("res://scripts/core/personal_home.gd")
const HouseData=preload("res://scripts/data/house_catalog.gd")
const Yard=preload("res://scripts/core/yard.gd")
const YardData=preload("res://scripts/data/yard_catalog.gd")
const Tiles=preload("res://scripts/data/tiles.gd")
class HomePlayer extends DummyPlayer:
 var facing:=Vector2.DOWN
 var target:Node2D
class HomeWorld extends DummyWorld:
 var entities:=Node2D.new()
 var map_data:Dictionary={}
 func _init():
  player.free();player=HomePlayer.new();add_child(player);add_child(entities)
var home_cases:Array=[]
var fixtures:Dictionary={}
## Large repeated inputs are named once; an operation refers to them as "@name".
func fx(value:Variant)->Variant:
 return fixtures[value] if value is String and fixtures.has(value) else value
func v(a:Array)->Vector2i:return Vector2i(int(a[0]),int(a[1]))
func rect_plain(r:Rect2i)->Array:return [r.position.x,r.position.y,r.size.x,r.size.y]
func clear_entities():
 for node:Node in world.entities.get_children():
  world.entities.remove_child(node);node.free()
func home_op(raw:Array)->Variant:
 var o:Array=raw.map(fx)
 match o[0]:
  "house_defaults":return House.defaults()
  "house_normalize":return House.normalize(o[1])
  "house_state":return House.state()
  "house_layout_reason":return House.layout_reason(o[1],o[2])
  "house_place":return House.layout_reason(House.candidate(o[1],o[2],o[3],v(o[4]),int(o[5])),o[6])
  "house_next_id":return House.next_id(o[1],o[2])
  "house_unlocked":return House.unlocked(o[1])
  "house_make_reason":return House.make_reason(o[1])
  "house_make":return House.make(o[1])
  "house_player_reason":return House.player_reason(o[1],Vector2(o[2][0],o[2][1]))
  "house_world_position":return House.world_position(o[1])
  "house_apply":
   world.player.position=Vector2(o[2][0],o[2][1]);var ok:bool=House.apply(o[1],world);clear_entities();return ok
  "yard_defaults":return Yard.defaults()
  "yard_normalize":return Yard.normalize(o[1],o[2])
  "yard_state":return Yard.state()
  "yard_place_reason":return Yard.place_reason(v(o[1]),o[2],o[3],o[4])
  "yard_used":return Yard.used(o[1],o[2])
  "yard_layout_reason":return Yard.layout_reason(o[1],o[2],o[3])
  "yard_station":
   var next:Dictionary=o[1].duplicate(true);next.stations[o[2]]=o[3];return Yard.layout_reason(next,o[4],o[5])
  "yard_piece":
   var next:Dictionary=o[1].duplicate(true);next["paths" if YardData.PIECES[o[2]].get("path",false) else "fences"][Yard.key(v(o[3]))]=o[2];return Yard.layout_reason(next,o[4],o[5])
  "yard_reach":return Yard.reachable(o[1]).size()
  "yard_blocks_work":return Yard.blocks_work(v(o[1]))
  "yard_surface":return Yard.surface(v(o[1]))
  "yard_material_reason":return Yard.material_reason(o[1])
  "yard_make":return Yard.make(o[1])
  "yard_expand":return Yard.expand(o[1])
  "yard_actor_reason":return Yard.actor_reason(o[1],Vector2(o[2][0],o[2][1]))
  "yard_schema_ok":return Yard.schema_ok(o[1])
  "yard_apply":
   world.player.position=Vector2(o[2][0],o[2][1]);var ok:bool=Yard.apply(o[1],world);clear_entities();return ok
  "transition":gs.transitioning=o[1];return gs.transitioning
 return progression_op(o)
func home_case(id:String,overrides:Dictionary,operations:Array):
 gs.new_game();gs.set_process(false);gs.load_pos=Vector2.ZERO;gs.meta_achievements={};gs.transitioning=false;Stock.busy=false;House.busy=false;Yard.busy=false;gs.movement.stamina=100.0;context("","village",0)
 for k:String in overrides:gs.set("map_id" if k=="map" else k,overrides[k].duplicate(true) if overrides[k] is Dictionary or overrides[k] is Array else overrides[k])
 var before:=_snapshot();var results:Array=[]
 for operation:Array in operations:results.append(_plain(home_op(operation)))
 var after:=_snapshot();gs.transitioning=false
 home_cases.append({"id":id,"initial":before,"initialExact":_exact(before),"initialOrdered":ordered_input(before),"operations":operations,"operationsExact":_exact(operations),"operationsOrdered":ordered_input(operations),"results":results,"resultsExact":_exact(results),"expected":after,"expectedExact":_exact(after)})
func _run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe home export");quit(1);return
 gs=root.get_node("GameState");gs.set_process(false);gs.meta_achievements={};gs.new_game();gs.load_pos=Vector2.ZERO
 root.get_node("Lang").set_language("nl",false)
 world=HomeWorld.new();world.process_mode=Node.PROCESS_MODE_DISABLED;world.add_to_group("world");world.player.add_to_group("player");root.add_child(world);current_scene=world
 home=Store.new();home.world=world;world.add_child(home);coast=Store.new();coast.world=world;world.add_child(coast)
 await process_frame
 var new_game:=_snapshot()
 # --- Catalogs ---
 var pieces:Dictionary={}
 for kind:String in HouseData.PIECES:
  var info:Dictionary=HouseData.PIECES[kind].duplicate(true);info.size=[info.size.x,info.size.y];pieces[kind]=info
 var fixed_house:Array=[]
 for r:Rect2i in House.FIXED:fixed_house.append(rect_plain(r))
 var house_catalog:Dictionary={"pieces":pieces,"floors":HouseData.FLOORS,"walls":HouseData.WALLS,"colors":HouseData.COLORS,"lights":HouseData.LIGHTS,"startOwned":HouseData.START_OWNED,"defaultLayout":HouseData.DEFAULT_LAYOUT,"room":rect_plain(House.ROOM),"fixed":fixed_house,"maxPieces":House.MAX_PIECES,"maxSolid":House.MAX_SOLID}
 var extensions:Dictionary={}
 for id:String in YardData.EXTENSIONS:
  var info:Dictionary=YardData.EXTENSIONS[id].duplicate(true);info.rect=rect_plain(info.rect);extensions[id]=info
 var base_plots:Array=[]
 for r:Rect2i in YardData.BASE_PLOTS:base_plots.append(rect_plain(r))
 var views:Array=[]
 for r:Rect2i in YardData.VIEWS:views.append(rect_plain(r))
 var rows:Array=Yard.map_data().rows;var solid_terrain:Dictionary={}
 for row:String in rows:
  for i in row.length():solid_terrain[row[i]]=Tiles.is_solid_name(Tiles.CHARS.get(row[i],"grass"))
 var fixed_yard:Array=[]
 for at:Vector2i in Yard.fixed():fixed_yard.append([at.x,at.y])
 var flowers:Array=[]
 for at:Vector2i in YardData.WILD_FLOWERS:flowers.append([at.x,at.y])
 var yard_catalog:Dictionary={"units":YardData.UNITS,"pieces":YardData.PIECES,"supplies":YardData.SUPPLIES,"owned":YardData.OWNED,"basePlots":base_plots,"extensions":extensions,"wildFlowers":flowers,"views":views,"viewNames":YardData.VIEW_NAMES,"maxPaths":Yard.MAX_PATHS,"maxFences":Yard.MAX_FENCES,"rows":rows,"solidTerrain":solid_terrain,"fixed":fixed_yard}
 var item_names:Dictionary={}
 for id:String in Items.ITEMS:item_names[id]=Items.info(id).name
 var catalogs:Dictionary=_plain({"house":house_catalog,"yard":yard_catalog,"itemNames":item_names})
 var orders:Dictionary={"pieces":catalogs.house.pieces.keys(),"units":catalogs.yard.units.keys(),"yardPieces":catalogs.yard.pieces.keys(),"supplies":catalogs.yard.supplies.keys(),"extensions":catalogs.yard.extensions.keys()}
 # --- Personal home ---
 var owned_all:Dictionary={}
 for kind:String in HouseData.PIECES:owned_all[kind]=int(HouseData.PIECES[kind].cap)
 var base_layout:Dictionary=HouseData.DEFAULT_LAYOUT.duplicate(true)
 fixtures["@base"]=base_layout;fixtures["@all"]=owned_all
 home_case("house-defaults",{},[["house_defaults"],["house_state"]])
 var raws:Array=[null,false,"x",[],{},{"floor":9,"wall":-3,"light":7.9,"owned":{"chair":99,"lamp":0,"future":4,"rug":"2"},"layout":null},
  {"floor":2,"wall":1,"light":1,"owned":{"chair":2},"layout":{"bed":{"kind":"bed","cell":[9,9],"tint":2},"table":{"kind":"table","cell":[2,2],"tint":1},"shelf":{"kind":"shelf","cell":[4,2],"tint":0},"chair:1":{"kind":"chair","cell":[2,3],"tint":1},"chair:2":{"kind":"chair","cell":[3,3],"tint":2.0}}},
  {"layout":{"bed":{"kind":"bed","cell":[3,3],"tint":0}}},{"layout":{"bed":{"kind":"bed","cell":[6,6],"tint":0},"table":{"kind":"table","cell":[4,8],"tint":0},"shelf":{"kind":"shelf","cell":[8,2],"tint":0}}},
  {"layout":"text","owned":[],"floor":"3"},{"owned":{"trophy_forest":1,"cabinet":2},"layout":{"bed":{"kind":"bed","cell":[3,3],"tint":0},"table":{"kind":"table","cell":[4,8],"tint":0},"shelf":{"kind":"shelf","cell":[8,2],"tint":0},"cabinet:2":{"kind":"cabinet","cell":[2,9],"tint":1},"trophy_forest:1":{"kind":"trophy_forest","cell":[11,11],"tint":0},"future_field":3}}]
 for index:int in raws.size():home_case("house-normalize-%d"%index,{},[["house_normalize",raws[index]]])
 home_case("house-legacy-state",{"personal_home":{"floor":3,"owned":{"lamp":2}}},[["house_state"]])
 for kind:String in HouseData.PIECES:
  var id:String=kind if HouseData.PIECES[kind].get("base",false) else kind+":1";var ops:Array=[]
  for y:int in range(1,13):
   for x:int in range(1,13):ops.append(["house_place","@base",id,kind,[x,y],(x+y)%3,"@all"])
  home_case("house-place-%s"%kind,{},ops)
 var crowded:Dictionary=base_layout.duplicate(true);crowded["cabinet:1"]={"kind":"cabinet","cell":[2,9],"tint":0};crowded["bench:1"]={"kind":"bench","cell":[9,10],"tint":1};crowded["lamp:1"]={"kind":"lamp","cell":[11,2],"tint":2}
 fixtures["@crowded"]=crowded
 for kind:String in ["chair","cabinet","lamp","bench","bed"]:
  var id:String=kind if HouseData.PIECES[kind].get("base",false) else kind+":2";var ops:Array=[]
  for y:int in range(2,12):
   for x:int in range(2,12):ops.append(["house_place","@crowded",id,kind,[x,y],0,"@all"])
  home_case("house-crowded-%s"%kind,{},ops)
 var many:Dictionary=base_layout.duplicate(true)
 for i:int in range(1,5):many["chair:%d"%i]={"kind":"chair","cell":[1+i*2,11],"tint":0};many["plant_leaf:%d"%i]={"kind":"plant_leaf","cell":[2,5+i],"tint":0}
 var solid_many:Dictionary=base_layout.duplicate(true)
 for i:int in range(1,3):solid_many["cabinet:%d"%i]={"kind":"cabinet","cell":[2+i*0,6+i*2-2],"tint":0}
 var broken:Array=[[many,owned_all],[many,HouseData.START_OWNED],[solid_many,owned_all],[{"bed":base_layout.bed,"table":base_layout.table},owned_all],[{},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair":{"kind":"chair","cell":[5,5],"tint":0}},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair:5":{"kind":"chair","cell":[5,5],"tint":0}},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair:0":{"kind":"chair","cell":[5,5],"tint":0}},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair:x":{"kind":"chair","cell":[5,5],"tint":0}},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair:1":{"kind":"future","cell":[5,5],"tint":0}},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair:1":{"kind":"chair","cell":[5.5,5],"tint":0}},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair:1":{"kind":"chair","cell":[5],"tint":0}},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair:1":{"kind":"chair","cell":"5,5","tint":0}},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair:1":{"kind":"chair","cell":[5,5],"tint":3}},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair:1":{"kind":"chair","cell":[5,5],"tint":1.5}},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"chair:1":"text"},owned_all],
  [{"bed":base_layout.bed,"table":base_layout.table,"shelf":base_layout.shelf,"bed:1":{"kind":"bed","cell":[9,9],"tint":0}},owned_all],
  [{"bed":{"kind":"table","cell":[3,3],"tint":0},"table":base_layout.table,"shelf":base_layout.shelf},owned_all],
  [base_layout,{}],[base_layout,{"bed":1,"table":1,"shelf":1}],[base_layout,owned_all]]
 for index:int in broken.size():home_case("house-layout-%d"%index,{},[["house_layout_reason",broken[index][0],broken[index][1]]])
 for kind:String in HouseData.PIECES:
  var two:Dictionary=base_layout.duplicate(true);two[kind+":1"]={"kind":kind,"cell":[5,5],"tint":0}
  home_case("house-next-id-%s"%kind,{"personal_home":{"owned":owned_all,"layout":base_layout,"floor":0,"wall":0,"light":0}},[["house_next_id",kind,base_layout],["house_next_id",kind,two],["house_next_id",kind,{}]])
  home_case("house-next-id-start-%s"%kind,{},[["house_next_id",kind,base_layout],["house_next_id",kind,two]])
 for kind:String in HouseData.PIECES.keys()+["future"]:
  var info:Dictionary=HouseData.PIECES.get(kind,{"cost":{}})
  home_case("house-make-away-%s"%kind,{"map":"village"},[["house_unlocked",kind],["house_make_reason",kind],["house_make",kind]])
  home_case("house-make-empty-%s"%kind,{"map":"player_home"},[["house_unlocked",kind],["house_make_reason",kind],["house_make",kind]])
  var bag:Dictionary={}
  for item:String in info.cost:bag[item]=int(info.cost[item])*6
  if info.has("item"):bag[info.item]=1
  var flags:Dictionary={}
  if info.has("flag"):flags[info.flag]=true
  var ops:Array=[["house_unlocked",kind]]
  for i:int in 6:ops.append(["house_make_reason",kind]);ops.append(["house_make",kind])
  ops.append(["house_state"])
  home_case("house-make-stocked-%s"%kind,{"map":"player_home","inventory":bag,"flags":flags},ops)
  if not info.cost.is_empty():
   home_case("house-make-chest-%s"%kind,{"map":"player_home","stockroom":{"home":info.cost.duplicate(),"favorites":{},"sort":0}},[["context","home","player_home",0.0,true],["house_make_reason",kind],["house_make",kind],["context","home","player_home",999.0,true],["house_make_reason",kind]])
 home_case("house-trophy-forest-temple",{"map":"player_home","flags":{"gate_temple":true}},[["house_unlocked","trophy_forest"],["house_make","trophy_forest"]])
 home_case("house-trophy-forest-completed",{"map":"player_home","flags":{"game_completed":true}},[["house_unlocked","trophy_forest"]])
 home_case("house-make-transition",{"map":"player_home","inventory":{"prof_log":9,"prof_branch":9}},[["transition",true],["house_make_reason","chair"],["house_make","chair"]])
 var placed:Dictionary=base_layout.duplicate(true);placed["chair:1"]={"kind":"chair","cell":[9,10],"tint":1};placed["lamp:1"]={"kind":"lamp","cell":[11,2],"tint":2}
 fixtures["@placed"]=placed
 var player_ops:Array=[]
 for y:int in range(48,400,24):
  for x:int in range(48,400,24):player_ops.append(["house_player_reason","@placed",[float(x),float(y)]])
 home_case("house-player-reason",{},player_ops)
 for entry:Dictionary in placed.values():home_case("house-world-position-%d"%home_cases.size(),{},[["house_world_position",entry]])
 var draft:Dictionary={"layout":placed,"floor":2,"wall":3,"light":1,"owned":{"chair":4}}
 home_case("house-apply-valid",{"map":"player_home"},[["house_apply",draft,[208.0,336.0]],["house_state"],["house_apply",draft,[208.0,336.0]]])
 home_case("house-apply-too-close",{"map":"player_home"},[["house_apply",draft,[300.0,330.0]],["house_state"]])
 home_case("house-apply-away",{"map":"village"},[["house_apply",draft,[208.0,336.0]]])
 home_case("house-apply-transition",{"map":"player_home"},[["transition",true],["house_apply",draft,[208.0,336.0]]])
 var unowned:Dictionary=draft.duplicate(true);unowned.layout["cabinet:1"]={"kind":"cabinet","cell":[2,9],"tint":0}
 home_case("house-apply-unowned",{"map":"player_home"},[["house_apply",unowned,[208.0,336.0]]])
 for key:String in ["layout","floor","wall","light"]:
  var missing:Dictionary=draft.duplicate(true);missing.erase(key);home_case("house-apply-missing-%s"%key,{"map":"player_home"},[["house_apply",missing,[208.0,336.0]]])
 home_case("house-apply-bad-layout",{"map":"player_home"},[["house_apply",{"layout":"x","floor":0,"wall":0,"light":0},[208.0,336.0]],["house_apply",{"layout":base_layout,"floor":9,"wall":-1,"light":5},[208.0,336.0]],["house_state"]])
 # --- Yard ---
 var yard:Dictionary=Yard.defaults();var both:Dictionary=yard.duplicate(true);both.extensions=["west","east"]
 for group:String in YardData.SUPPLIES:both.owned[group]=int(YardData.SUPPLIES[group].cap)
 var farm:Dictionary={"10,31":{"kind":"soil"},"11,31":{"kind":"channel"},"8,34":{"kind":"soil","crop":"apple","growth":10.0},"28,33":{"kind":"soil","crop":"grape","growth":5.0}}
 fixtures["@yard"]=yard;fixtures["@both"]=both;fixtures["@farm"]=farm
 home_case("yard-defaults",{},[["yard_defaults"],["yard_state"],["yard_reach",yard],["yard_reach",both]])
 for pair:Array in [["base","@yard",{}],["both","@both",{}],["farm","@both","@farm"]]:
  for solid:bool in [false,true]:
   var ops:Array=[]
   for y:int in range(-1,45):
    for x:int in range(-1,41):ops.append(["yard_place_reason",[x,y],pair[1],pair[2],solid])
   home_case("yard-place-%s-%s"%[pair[0],solid],{},ops)
 var cells:Array=[]
 for r:Rect2i in Yard.plots():
  for at:Vector2i in Yard.cells_in(r.grow(1)):
   if [at.x,at.y] not in cells:cells.append([at.x,at.y])
 for id:String in YardData.UNITS:
  for pair:Array in [["both","@both",{}],["farm","@both","@farm"],["base","@yard",{}]]:
   var ops:Array=[]
   for at:Array in cells:
    if pair[0]=="both" or (at[0]+at[1])%3==0:ops.append(["yard_station",pair[1],id,at,pair[2],"@yard"])
   ops.append(["yard_station",pair[1],id,[],pair[2],"@yard"])
   home_case("yard-station-%s-%s"%[id,pair[0]],{},ops)
 for kind:String in YardData.PIECES:
  for pair:Array in [["both","@both",{}],["farm","@both","@farm"]]:
   var ops:Array=[]
   for at:Array in cells:
    if pair[0]=="both" or (at[0]*3+at[1])%4==0:ops.append(["yard_piece",pair[1],kind,at,pair[2],"@yard"])
   home_case("yard-piece-%s-%s"%[kind,pair[0]],{},ops)
 var ring:Dictionary=both.duplicate(true)
 for x:int in range(6,11):ring.fences["%d,32"%x]="fence_h";ring.fences["%d,36"%x]="fence_h"
 for y:int in range(33,36):ring.fences["6,%d"%y]="fence_v";ring.fences["10,%d"%y]="fence_v"
 var gated:Dictionary=ring.duplicate(true);gated.fences["8,36"]="gate_h"
 var pathed:Dictionary=gated.duplicate(true);pathed.paths={"8,36":"gravel","8,37":"gravel","8,35":"stone","7,32":"boards"}
 var moved:Dictionary=both.duplicate(true);moved.stations.wine_a=[27,32];moved.stations.hive=[]
 var swapped:Dictionary=yard.duplicate(true);swapped.stations.wine_a=[12,25];swapped.stations.wine_b=[4,25]
 var close:Dictionary=both.duplicate(true);close.stations.wine_a=[9,25];close.stations.wine_b=[12,25]
 fixtures["@gated"]=gated
 var layouts:Dictionary={"default":yard,"both":both,"ring":ring,"gated":gated,"pathed":pathed,"moved":moved,"swapped":swapped,"close":close}
 var poor:Dictionary=gated.duplicate(true);poor.owned=YardData.OWNED.duplicate();layouts["poor"]=poor
 var too_many:Dictionary=both.duplicate(true)
 for i:int in 81:too_many.paths["%d,%d"%[4+i%14,29+i/14]]="gravel"
 layouts["too-many"]=too_many
 for name:String in layouts:
  var data:Dictionary=layouts[name];var ops:Array=[["yard_layout_reason",data,{},yard],["yard_layout_reason",data,farm,yard],["yard_layout_reason",data,{},{}],["yard_layout_reason",data,{},data],["yard_reach",data],["yard_schema_ok",data],["yard_normalize",data,{}],["yard_normalize",data,farm]]
  for group:String in YardData.SUPPLIES:ops.append(["yard_used",data,group])
  home_case("yard-layout-%s"%name,{},ops)
 var yard_raws:Array=[null,5,[],{},{"extensions":["west","west","future",3],"owned":{"gravel":999,"fence":-4,"gate":"2","stone":16.9},"stations":{"wine_a":[],"wine_b":[12.9,25],"compost":[99,3],"hive":"x"},"paths":{"5,26":"gravel","x":"gravel","5,27":"fence_h","05,28":"stone"},"fences":{"6,26":"fence_h","7,26":"gravel","8,26":7}},
  {"stations":{"wine_a":[5,25],"wine_b":[12,25],"compost":[7,15],"hive":[15,32]}},{"stations":{"wine_a":[20,20]}},{"paths":"x","fences":null,"stations":[],"owned":3,"extensions":{}}]
 for index:int in yard_raws.size():home_case("yard-normalize-%d"%index,{},[["yard_normalize",yard_raws[index],{}],["yard_normalize",yard_raws[index],farm]])
 var bad_schema:Array=[{"stations":{"wine_a":[4,25],"wine_b":[12,25],"compost":[7,15]},"paths":{},"fences":{}},{"stations":{"wine_a":[4.0,25],"wine_b":[12,25],"compost":[7,15],"hive":[15,32]},"paths":{},"fences":{}},{"stations":{"wine_a":[40,25],"wine_b":[12,25],"compost":[7,15],"hive":[15,32]},"paths":{},"fences":{}},{"stations":{"wine_a":[4,25,1],"wine_b":[12,25],"compost":[7,15],"hive":[15,32]},"paths":{},"fences":{}},{"stations":yard.stations,"paths":{"5,26":"fence_h"},"fences":{}},{"stations":yard.stations,"paths":{},"fences":{"05,26":"fence_h"}},{"stations":yard.stations,"paths":{"5,26":"gravel"},"fences":{"6,26":"gate_v"}}]
 for index:int in bad_schema.size():home_case("yard-schema-%d"%index,{},[["yard_schema_ok",bad_schema[index]]])
 var live:Dictionary={"yard":pathed,"map":"village"};var work_ops:Array=[]
 for at:Array in cells:work_ops.append(["yard_blocks_work",at]);work_ops.append(["yard_surface",at])
 home_case("yard-work-and-surface",live,work_ops)
 home_case("yard-work-moved",{"yard":moved,"map":"village"},work_ops.slice(0,400))
 var actor_ops:Array=[]
 for y:int in range(700,1200,20):
  for x:int in range(100,420,20):actor_ops.append(["yard_actor_reason","@gated",[float(x),float(y)]])
 home_case("yard-actor-reason",{},actor_ops)
 for group:String in YardData.SUPPLIES.keys()+["future"]:
  var info:Dictionary=YardData.SUPPLIES.get(group,{"cost":{},"amount":0,"cap":0});var bag:Dictionary={}
  for item:String in info.cost:bag[item]=int(info.cost[item])*40
  var ops:Array=[["yard_material_reason",info.cost]]
  for i:int in 18:ops.append(["yard_make",group])
  ops.append(["yard_state"])
  home_case("yard-make-stocked-%s"%group,{"map":"village","inventory":bag},ops)
  home_case("yard-make-empty-%s"%group,{"map":"village"},[["yard_material_reason",info.cost],["yard_make",group]])
  home_case("yard-make-away-%s"%group,{"map":"forest","inventory":bag},[["yard_material_reason",info.cost],["yard_make",group]])
  if not info.cost.is_empty():home_case("yard-make-chest-%s"%group,{"map":"village","stockroom":{"home":info.cost.duplicate(),"favorites":{},"sort":0}},[["context","home","village",0.0,true],["yard_make",group],["yard_make",group]])
 for id:String in YardData.EXTENSIONS.keys()+["future"]:
  var cost:Dictionary=YardData.EXTENSIONS.get(id,{"cost":{}}).cost
  home_case("yard-expand-%s"%id,{"map":"village","inventory":cost.duplicate()},[["yard_expand",id],["yard_expand",id],["yard_state"]])
  home_case("yard-expand-poor-%s"%id,{"map":"village"},[["yard_expand",id]])
  home_case("yard-expand-away-%s"%id,{"map":"player_home","inventory":cost.duplicate()},[["yard_expand",id]])
 var yard_draft:Dictionary={"stations":moved.stations,"paths":{"5,27":"gravel","6,27":"gravel"},"fences":{"12,27":"fence_h","13,27":"gate_h"}}
 var owner:Dictionary={"map":"village","yard":both}
 home_case("yard-apply-valid",owner,[["yard_apply",yard_draft,[240.0,720.0]],["yard_state"],["yard_apply",yard_draft,[240.0,720.0]]])
 home_case("yard-apply-too-close",owner,[["yard_apply",yard_draft,[400.0,872.0]],["yard_state"]])
 home_case("yard-apply-away",{"map":"forest","yard":both},[["yard_apply",yard_draft,[240.0,720.0]]])
 home_case("yard-apply-transition",owner,[["transition",true],["yard_apply",yard_draft,[240.0,720.0]]])
 home_case("yard-apply-unowned",{"map":"village"},[["yard_apply",{"stations":moved.stations,"paths":{},"fences":{}},[240.0,720.0]],["yard_apply",{"stations":yard.stations,"paths":{},"fences":ring.fences},[240.0,720.0]],["yard_state"]])
 home_case("yard-apply-farm",{"map":"village","yard":both,"homestead":{"cells":farm,"jobs":{},"animals":{},"drops":{}}},[["yard_apply",{"stations":both.stations,"paths":{"10,31":"gravel"},"fences":{}},[240.0,720.0]],["yard_apply",{"stations":both.stations,"paths":{"12,31":"gravel"},"fences":{}},[240.0,720.0]],["yard_state"]])
 for key:String in ["stations","paths","fences"]:
  var missing:Dictionary=yard_draft.duplicate(true);missing.erase(key);home_case("yard-apply-missing-%s"%key,owner,[["yard_apply",missing,[240.0,720.0]]])
 home_case("yard-apply-bad-schema",owner,[["yard_apply",bad_schema[1],[240.0,720.0]],["yard_apply",bad_schema[4],[240.0,720.0]],["yard_apply",ring,[240.0,720.0]]])
 var report:Dictionary={"schema":"bluemap.home.source-oracle.v1","engineVersion":Engine.get_version_info().string,"personalSavesUsed":false,"float64Encoding":"ieee754-binary64-little-endian-hex","orderedInputEncoding":"dictionary-pairs-and-exact-f64-v1","catalogs":catalogs,"catalogsExact":_exact(catalogs),"catalogsOrdered":ordered_input(catalogs),"orders":orders,"fixtures":_plain(fixtures),"fixturesOrdered":ordered_input(_plain(fixtures)),"newGame":new_game,"cases":home_cases,
  "sourceMethods":["scripts/core/personal_home.gd::defaults","scripts/core/personal_home.gd::number","scripts/core/personal_home.gd::normalize","scripts/core/personal_home.gd::state","scripts/core/personal_home.gd::rect","scripts/core/personal_home.gd::world_position","scripts/core/personal_home.gd::fixed_cells","scripts/core/personal_home.gd::reserved","scripts/core/personal_home.gd::layout_reason","scripts/core/personal_home.gd::candidate","scripts/core/personal_home.gd::next_id","scripts/core/personal_home.gd::unlocked","scripts/core/personal_home.gd::make_reason","scripts/core/personal_home.gd::make","scripts/core/personal_home.gd::player_reason","scripts/core/personal_home.gd::apply","scripts/core/personal_home.gd::sync","scripts/core/yard.gd::defaults","scripts/core/yard.gd::terrain","scripts/core/yard.gd::anchor","scripts/core/yard.gd::bounds","scripts/core/yard.gd::fixed","scripts/core/yard.gd::reserved","scripts/core/yard.gd::owned_cell","scripts/core/yard.gd::place_reason","scripts/core/yard.gd::used","scripts/core/yard.gd::walk_blocked","scripts/core/yard.gd::reachable","scripts/core/yard.gd::layout_reason","scripts/core/yard.gd::normalize","scripts/core/yard.gd::state","scripts/core/yard.gd::blocks_work","scripts/core/yard.gd::surface","scripts/core/yard.gd::material_reason","scripts/core/yard.gd::make","scripts/core/yard.gd::expand","scripts/core/yard.gd::actor_reason","scripts/core/yard.gd::schema_ok","scripts/core/yard.gd::apply","scripts/core/yard.gd::sync","scripts/core/stockroom.gd::consume","scripts/core/stockroom.gd::available","scripts/data/orchard_catalog.gd::tree_cover"]}
 var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(report,"",true,true)+"\n");f.close();print("MIGRATION HOME EXPORT OK "+str(home_cases.size())+" CASES");quit(0)
