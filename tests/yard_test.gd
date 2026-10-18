extends "res://tests/coast_expedition_test.gd"
const Yard:=preload("res://scripts/core/yard.gd")
const Farm:=preload("res://scripts/core/homestead.gd")
const Stock:=preload("res://scripts/core/stockroom.gd")
var premature:=false
var watching:=false
func saved():
 if watching and Yard.state().owned.gravel!=32:premature=true
func unit(id: String) -> Node:
 for n in get_nodes_in_group("home_stations"):
  if Yard.unit_of(n.obj)==id:return n
 return null
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 root.get_node("Lang").set_language("nl",false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("village");p.set_physics_process(false);p.position=Vector2(7.5,24.5)*32
 var base:=Yard.defaults()
 check(Yard.layout_reason(base,{})=="","original four station positions valid without new map objects")
 check(world.map_size==Vector2i(40,44) and Farm.garden(Vector2i(30,35)),"same map size and full farming area available before expansions")
 var corrupt:=base.duplicate(true);corrupt.fences["10,27"]="unknown"
 check(not Yard.apply(corrupt,world),"malformed application cannot create an unknown collider")
 var draft:=base.duplicate(true);draft.stations.wine_a=[5,27]
 check(Yard.layout_reason(draft,{})=="","front yard has real room for a moved vat")
 gs.homestead=Farm.normalize({"jobs":{"wine_a":{"batches":2,"time":42}},"cells":{"18,35":{"kind":"soil","crop":"grape","growth":90,"fertilized":true},"19,35":{"kind":"channel"}}})
 var crops: Dictionary=gs.homestead.cells.duplicate(true)
 check(Yard.apply(draft,world),"valid station move applies")
 check(unit("wine_a").position==Vector2(5.5,27.5)*32 and gs.homestead.jobs.wine_a.time==42 and gs.homestead.cells==crops,"actual collider and machine move without resetting jobs or crops")
 p.position=Vector2(4.5,25.5)*32
 check(not Farm.near("wine","wine_a"),"old wine position cannot start or collect moved production")
 p.position=Vector2(5.5,26.5)*32
 check(Farm.near("wine","wine_a"),"moved wine unit remains usable")
 p.position=Vector2(7.5,24.5)*32;draft=Yard.state().duplicate(true);draft.stations.wine_a=[]
 check(Yard.apply(draft,world),"machine can be packed")
 check(not unit("wine_a").visible and unit("wine_a").collision_layer==0 and not unit("wine_a").is_in_group("interactable"),"packed machine has no ghost sprite interaction or collision")
 Farm.advance(60)
 check(gs.homestead.jobs.wine_a.time==90 and not Farm.collect("wine_a"),"packed wine matures but cannot be collected remotely")
 draft=Yard.state().duplicate(true);draft.stations.wine_a=[5,27]
 check(Yard.apply(draft,world),"same unique machine can be placed again")
 p.position=Vector2(5.5,26.5)*32
 check(Farm.collect("wine_a") and gs.count("hs_wine")==2 and not Farm.collect("wine_a"),"existing saved batch collects exactly once after unpacking")
 p.position=Vector2(7.5,24.5)*32
 draft=base.duplicate(true);draft.stations.wine_a=base.stations.wine_b.duplicate();draft.stations.wine_b=base.stations.wine_a.duplicate()
 check(Yard.normalize(draft).stations==draft.stations,"normalize validates swapped station positions together")
 gs.yard=base.duplicate(true);Yard.sync(world)
 draft=base.duplicate(true);draft.stations.hive=[]
 gs.homestead.honey=2;gs.homestead.honey_time=45
 check(Yard.apply(draft,world),"hive can be packed")
 Farm.advance(240)
 check(gs.homestead.honey==2 and gs.homestead.honey_time==45 and Farm.flowers()==0,"packed hive pauses honey without loss or magical flowers")
 draft=Yard.state().duplicate(true);draft.extensions=["east"];gs.yard.extensions=["east"];draft.stations.hive=[28,34]
 check(Yard.apply(draft,world),"hive can move to newly opened meadow")
 check(Farm.flowers()==0,"distant wild flowers do not feed moved bees")
 for at in [Vector2i(27,36),Vector2i(28,36),Vector2i(29,36)]:gs.homestead.cells[Yard.key(at)]={"kind":"soil","crop":"flower","growth":60.0}
 check(Farm.flowers()==3,"three mature flowers near moved hive really feed bees")
 Farm.advance(75)
 check(gs.homestead.honey==3 and gs.homestead.honey_time==0,"moved hive completes retained honey cycle")
 gs.yard=base.duplicate(true);Yard.sync(world);gs.homestead=Farm.normalize({})
 draft=base.duplicate(true);draft.paths["10,27"]="gravel"
 check(Yard.layout_reason(draft,{})=="" and Yard.apply(draft,world),"starter path places only on clear usable land")
 check(Yard.surface(Vector2i(10,27))=="path" and Tiles.movement_multiplier("path")==1.2,"new paths use existing comfortable path speed")
 check(Tiles.footstep_surface("yard_boards")=="wood" and Tiles.movement_multiplier("yard_boards")==1.2,"wooden garden paths have wood footsteps and matching speed")
 p.position=Vector2(10.5,27.2)*32
 check(p.ground_tile()=="path","actual player feet use placed path surface")
 check(Yard.blocks_work(Vector2i(10,27)),"farming cannot silently overwrite placed path")
 var bad:=draft.duplicate(true);bad.paths["18,35"]="gravel"
 check(Yard.layout_reason(bad,crops)!="","crop area cannot be covered by optional construction")
 bad=base.duplicate(true);bad.paths["20,31"]="gravel"
 check(Yard.layout_reason(bad,{})!="","garden path cannot become untested water bridge")
 bad=base.duplicate(true);bad.fences["9,27"]="fence_h"
 check(Yard.layout_reason(bad,{})!="","shared stock approach remains protected")
 bad=base.duplicate(true);bad.stations.hive=[30,35]
 check(Yard.layout_reason(bad,{})!="","building expansion is explicit even though farming was already available")
 # Open one field: a four-sided enclosure must have a gate.
 gs.yard=base.duplicate(true);gs.yard.extensions=["west"]
 bad=Yard.state().duplicate(true)
 for at in [Vector2i(8,34),Vector2i(9,33),Vector2i(10,34),Vector2i(9,35)]:bad.fences[Yard.key(at)]="fence_h"
 check(Yard.layout_reason(bad,{}).contains("af"),"whole-field connectivity rejects fence trap")
 bad.fences["9,35"]="gate_h"
 check(Yard.layout_reason(bad,{})=="","automatic gate restores access to enclosure")
 check(Yard.normalize(bad).fences==bad.fences,"saved enclosure restores all pieces including access gate")
 # Atomic material use reads the same nearby shared home store.
 p.position=Vector2(9.5,27.5)*32;gs.yard=base.duplicate(true);Yard.sync(world)
 Stock.state().home={"prof_stone":2};gs.inventory.erase("prof_stone")
 check(not Yard.make("gravel") and Stock.count("prof_stone")==2,"outdoor construction cannot consume indoor stock remotely")
 gs.give("prof_stone",2,true)
 watching=true;gs.save_requested.connect(saved);check(Yard.make("gravel"),"path pieces use carried materials outside");watching=false;gs.save_requested.disconnect(saved)
 check(not premature and Yard.state().owned.gravel==32 and Stock.count("prof_stone")==2 and gs.count("prof_stone")==0,"save occurs after both cost and owned parts are complete")
 var old: Dictionary=gs.yard.duplicate(true)
 check(not Yard.expand("east") and gs.yard==old,"missing expansion materials cause no partial mutation")
 gs.give("prof_log",20,true);gs.give("prof_stone",20,true)
 check(Yard.expand("west") and not Yard.expand("west"),"optional building right buys exactly once")
 check(gs.count("prof_log")==14 and gs.count("prof_stone")==14,"expansion takes stated materials once")
 gs.homestead.cells=crops
 var normalized:=Yard.normalize({"stations":{"wine_a":[999,1],"hive":[]},"paths":{"20,31":"bad","07,26":"gravel","18,35":"gravel"},"fences":{"what":"gate_h"},"extensions":["east","east","bogus"],"owned":{"gate":9999}},crops)
 check(normalized.extensions==["east"] and normalized.owned.gate==8 and normalized.paths.is_empty() and normalized.fences.is_empty(),"malformed data is bounded and cannot cover water crops or channels")
 check(gs.homestead.cells==crops,"repair never mutates farm data")
 gs.yard=Yard.state();var saved_yard: Dictionary=gs.yard.duplicate(true);gs.save_game(p.position);gs.yard={}
 check(gs.load_game() and gs.yard==saved_yard and gs.homestead.cells==crops,"real save/load retains yard rights stock and crops together")
 var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH));legacy.erase("yard")
 var file:=FileAccess.open(gs.SAVE_PATH,FileAccess.WRITE);file.store_string(JSON.stringify(legacy));file.close()
 check(gs.load_game() and gs.yard==Yard.defaults() and gs.homestead.cells==crops,"legacy save gets original stations and retains established farm")
 gs.new_game();check(Yard.state()==Yard.defaults(),"new adventure resets optional yard construction")
 world.queue_free();await frames()
 print("YARD OK" if failures==0 else "YARD FAILED "+str(failures));quit(0 if failures==0 else 1)
