extends "res://tests/coast_expedition_test.gd"
const Farm:=preload("res://scripts/core/homestead.gd")
const Orchard:=preload("res://scripts/core/orchard.gd")
const Data:=preload("res://scripts/data/orchard_catalog.gd")
const Yard:=preload("res://scripts/core/yard.gd")
const Stock:=preload("res://scripts/core/stockroom.gd")
const Prof:=preload("res://scripts/core/professions.gd")
var watch:=false
var repeated:=false
func listener():
 if watch and Orchard.buy("carrot",1):repeated=true
func act(at: Vector2i,mode: String) -> bool:
 p.position=Vector2(at)*32+Vector2(-16,16)
 return Farm.act(at,mode,world)
func trees() -> Array:
 return get_nodes_in_group("orchard_trees").filter(func(n):return not n.is_queued_for_deletion())
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.get_node("Lang").set_language("nl",false);gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(10);p=world.player
 await enter("village","from_home");p.set_physics_process(false);p.position=Vector2(6.5,24.0)*32
 check(trees().is_empty() and Farm.state().cells.is_empty(),"new game keeps the existing open meadows completely empty")
 var old: Dictionary=gs.inventory.duplicate(true)
 check(Farm.starter() and Orchard.starter() and not Orchard.starter(),"old tool pack and new seed pack are separate one-time gifts")
 check(gs.count("or_apple_seed")==1 and gs.count("or_mint_seed")==2,"starter contains the documented tree and herb amounts")
 gs.give("hs_fertilizer",3,true)
 var near_station:=Vector2i(15,33)
 check(act(near_station,"soil") and not act(near_station,"mint"),"new tall herbs cannot overlap the visible default hive")
 var center:=Vector2i(9,34)
 check(act(center,"soil"),"existing hoe prepares orchard center")
 check(act(center,"apple"),"apple sapling accepts a genuinely clear three-by-three plot")
 await frames(3)
 check(trees().size()==1 and not world.spawn_fits(Vector2(center)*32+Vector2(16,16)),"actual apple trunk collider exists immediately")
 var invalid:=Vector2i(10,34);var before: Dictionary=Farm.state().cells.duplicate(true)
 check(not act(invalid,"soil") and not act(invalid,"channel") and Farm.state().cells==before,"tree crown cannot be filled with crops or hidden channels")
 var draft: Dictionary=Yard.state().duplicate(true);draft.extensions=["west"];draft.paths["10,34"]="gravel"
 check(Yard.layout_reason(draft,Farm.state().cells)!="","yard paths also respect tree canopy clearance")
 Farm.advance(400)
 check(Farm.state().cells["9,34"].growth==0,"dry sapling waits without losing growth or dying")
 for x in range(11,20):check(act(Vector2i(x,34),"channel"),"same connected channel system reaches orchard "+str(x))
 check(Farm.crop_watered(center,Farm.state().cells["9,34"]) and not Farm.watered(center),"tree roots accept connected water at two tiles")
 Farm.advance(240)
 check(Farm.harvest_reason(Farm.state().cells["9,34"])=="","first apple growth ripens on active irrigated time")
 check(act(center,"fertilize") and act(center,"harvest") and gs.count("or_apple")==6,"fertilizer adds two apples to first complete harvest")
 check(Farm.state().cells["9,34"].get("established",false) and Data.duration(Farm.state().cells["9,34"])==150,"mature tree remains established and uses faster subsequent crops")
 check(not act(center,"harvest"),"same tree cannot be harvested twice immediately")
 Farm.advance(150);check(act(center,"harvest") and gs.count("or_apple")==10,"next apple crop regrows without replanting and without repeat fertilizer")
 var kinds:=["carrot","pumpkin","mint","rosemary","berry"]
 for i in kinds.size():
  var at:=Vector2i(12+i,35)
  check(act(at,"soil") and act(at,kinds[i]),"real hoe and seeds plant "+kinds[i])
 var cells: Dictionary=Farm.state().cells
 gs.set_ui("orchard_test",true);gs._process(100)
 check(cells["12,35"].growth==0,"ordinary modal pauses the real crop clock")
 gs.set_ui("orchard_test",false);Farm.advance(140)
 check(kinds.all(func(k):return cells.values().any(func(e):return e.get("crop","")==k and float(e.growth)>=Data.duration(e))),"all five low crops use their own growth durations")
 var seeds_before: int=gs.count("or_carrot_seed")
 check(act(Vector2i(12,35),"harvest") and gs.count("or_carrot")==3 and gs.count("or_carrot_seed")==seeds_before+1 and not cells["12,35"].has("crop"),"annual crop returns seed and leaves reusable soil atomically")
 check(act(Vector2i(13,35),"fertilize") and act(Vector2i(13,35),"harvest") and gs.count("or_pumpkin")==3,"pumpkin has distinct fertilized yield and seed return")
 check(act(Vector2i(14,35),"harvest") and cells["14,35"].crop=="mint" and cells["14,35"].established,"harvested herb remains planted")
 check(act(Vector2i(15,35),"harvest") and act(Vector2i(16,35),"harvest") and gs.count("prof_berry")==3,"rosemary regrows and cultivated berries enter existing berry recipes")
 Farm.advance(65);check(act(Vector2i(14,35),"harvest"),"herb regrowth uses its own shorter duration")
 var moved:=Yard.state().duplicate(true);gs.yard.extensions=["east"];moved.extensions=["east"];moved.stations.hive=[28,32]
 p.position=Vector2(7.5,24.5)*32
 check(Yard.apply(moved,world),"existing movable hive can serve a new herb patch")
 cells["27,35"]={"kind":"soil","crop":"mint","growth":85.0,"fertilized":false};cells["28,35"]={"kind":"soil","crop":"rosemary","growth":110.0,"fertilized":false};cells["29,35"]={"kind":"soil","crop":"flower","growth":60.0,"fertilized":false}
 gs.homestead.honey=0;gs.homestead.honey_time=0
 check(Farm.flowers()==3,"ripe mint rosemary and flowers each count once at actual hive")
 Farm.advance(120);check(gs.homestead.honey==1,"new flowering herbs genuinely support honey production")
 p.position=Vector2(6.5,24.0)*32;gs.coins=50;gs.inventory.erase("or_carrot_seed")
 watch=true;gs.items_changed.connect(listener);check(Orchard.buy("carrot",5),"catalog can supply five seeds in one transaction");watch=false;gs.items_changed.disconnect(listener)
 check(not repeated and gs.count("or_carrot_seed")==5 and gs.coins==30,"reentrant purchase cannot duplicate seeds or overspend")
 old=gs.inventory.duplicate(true);gs.coins=0
 check(not Orchard.buy("apple",1) and gs.inventory==old,"unaffordable purchase does not change inventory")
 p.position=Vector2(31.5,39.5)*32;gs.coins=100
 check(not Orchard.buy("apple",1),"remote field selector cannot buy away from actual seed supply")
 gs.hp=gs.max_hp()-1
 check(Prof.use_item("or_carrot") and gs.hp==gs.max_hp(),"fresh carrot uses existing food system")
 gs.hp=gs.max_hp()-1;gs.movement.stamina=0
 check(Prof.use_item("or_apple") and gs.hp==gs.max_hp() and gs.movement.stamina==10,"apple restores health and stamina")
 for item in ["or_carrot","or_pumpkin","or_mint","or_rosemary","prof_herb","hs_honey"]:gs.give(item,6,true)
 check(Prof.craft_reason("or_stew")!="","warm food retains existing inn requirement")
 await enter("inn")
 check(Prof.craft("or_stew") and Prof.craft("or_tea"),"new vegetables and mint work at existing kitchen")
 check(not Prof.craft("or_balm"),"balm is restricted to the existing alchemy table")
 await enter("library")
 check(Prof.craft("or_balm") and gs.count("or_balm")==1,"own rosemary has a distinct alchemy application")
 await enter("village","from_home");p.set_physics_process(false);p.position=Vector2(7.5,24.5)*32
 var original: Dictionary=Farm.state().cells.duplicate(true);var yard: Dictionary=Yard.state().duplicate(true)
 gs.save_game(p.position);gs.homestead={}
 check(gs.load_game() and Farm.state().cells==original and Yard.state()==yard,"save/load retains all new growth established state original yard and irrigation")
 world.queue_free();await frames(5)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(8);p=world.player;p.set_physics_process(false)
 check(trees().size()==1 and not world.spawn_fits(Vector2(9.5,34.5)*32),"initial resume reconstructs real tree collision before play")
 check(act(center,"fill") and gs.count("or_apple_seed")==1,"deliberate removal returns sapling and opens crown space")
 await frames();check(trees().is_empty() and act(Vector2i(10,34),"soil"),"tree removal leaves no ghost trunk or reserved crown")
 gs.new_game();check(Farm.state().cells.is_empty() and not gs.flag("or_starter"),"new adventure resets planted orchard and its starter flag")
 world.queue_free();await frames()
 print("ORCHARD OK" if failures==0 else "ORCHARD FAILED "+str(failures));quit(0 if failures==0 else 1)
