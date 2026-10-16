extends "res://tests/coast_expedition_test.gd"
const House:=preload("res://scripts/core/personal_home.gd")
const Stock:=preload("res://scripts/core/stockroom.gd")
const Catalog:=preload("res://scripts/data/house_catalog.gd")
var premature_save:=false
var watching:=false
func saved():
 if watching and int(House.state().owned.get("chair",0))<2:premature_save=true
func base(role: String) -> Node2D:
 for n in get_nodes_in_group("home_stations"):
  if not n.is_queued_for_deletion() and n.obj.role==role:return n
 return null
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.get_node("Lang").set_language("nl",false)
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("player_home");p.set_physics_process(false)
 check(House.layout_reason(House.state().layout,House.state().owned)=="","starter layout has connected open floor and usable bed")
 check(world.map_size==Vector2i(14,14) and world.map_data.objects.size()==7,"same room, original object order and storage slot")
 check(get_nodes_in_group("house_furniture").is_empty(),"starter furniture stock does not automatically fill room")
 var original: Dictionary=House.state().duplicate(true)
 var bad:=House.candidate(original.layout,"chair:1","chair",Vector2i(6,10),0)
 check(House.layout_reason(bad,original.owned)!="","door and arrival lane cannot be furnished")
 bad=House.candidate(original.layout,"chair:1","chair",Vector2i(10,5),0)
 check(House.layout_reason(bad,original.owned)!="","storage collision and approach protected")
 bad=House.candidate(original.layout,"shelf","shelf",Vector2i(11,2),0)
 check(House.layout_reason(bad,original.owned)!="","visual footprint cannot cross wall")
 bad=House.candidate(original.layout,"cabinet:1","cabinet",Vector2i(2,8),0)
 check(House.layout_reason(bad,original.owned)!="","unowned item cannot be spawned by placement")
 # Four individual chairs can enclose a free tile without overlapping; connectivity still rejects it.
 var ring: Dictionary=original.layout.duplicate(true);ring.bed.cell=[2,2]
 var owned: Dictionary=original.owned.duplicate();owned.chair=4
 var i:=1
 for at in [Vector2i(4,3),Vector2i(3,4),Vector2i(5,4),Vector2i(4,5)]:
  ring["chair:"+str(i)]={"kind":"chair","cell":[at.x,at.y],"tint":0};i+=1
 check(House.layout_reason(ring,owned).contains("hoek"),"whole-floor flood fill catches enclosed corner despite clear main lane")
 var draft: Dictionary=original.duplicate(true)
 draft.layout.bed.cell=[2,2];draft.layout.table.cell=[4,9];draft.floor=1;draft.wall=1;draft.light=1
 draft.layout=House.candidate(draft.layout,"chair:1","chair",Vector2i(4,10),1)
 draft.layout=House.candidate(draft.layout,"plant_leaf:1","plant_leaf",Vector2i(2,8),0)
 draft.layout=House.candidate(draft.layout,"lamp:1","lamp",Vector2i(10,9),2)
 check(House.layout_reason(draft.layout,original.owned)=="" and House.state()==original,"draft allows useful redesign without changing saved house")
 check(House.apply(draft,world),"entire valid draft commits atomically")
 await frames(5)
 check(base("bed").position==House.world_position(draft.layout.bed) and base("table").position==House.world_position(draft.layout.table),"existing functional bed and table move in actual world")
 check(not world.spawn_fits(base("bed").position) and world.spawn_fits(Vector2(3.5,4.5)*32),"real collision moves with furniture and frees previous floor")
 check(get_nodes_in_group("house_furniture").filter(func(n):return not n.is_queued_for_deletion()).size()==3,"only explicitly placed chair plant and lamp materialize")
 check(world.spawn_fits(Vector2(6.5,12.5)*32) and world.spawn_fits(Vector2(10.5,6.5)*32),"doorway and actual chest approach remain open")
 var lamp: Node
 for n in get_nodes_in_group("house_furniture"):
  if n.entry.kind=="lamp":lamp=n
 check(lamp!=null and lamp.lamp.enabled and lamp.lamp.color==Color("9dd0d0"),"placed light uses chosen quiet sea palette")
 draft=House.state().duplicate(true);draft.light=2;House.apply(draft,world);await frames()
 for n in get_nodes_in_group("house_furniture"):
  if n.entry.kind=="lamp":check(not n.lamp.enabled,"light off has real effect")
 # The same house stock supplies optional building without consuming personal gear or premature saving.
 p.position=Vector2(10.5,6.5)*32
 Stock.state().home={"prof_log":3,"prof_branch":3};gs.inventory.erase("prof_log");gs.inventory.erase("prof_branch")
 watching=true;gs.save_requested.connect(saved)
 check(House.make("chair"),"optional furniture can use nearby home stock")
 watching=false;gs.save_requested.disconnect(saved)
 check(not premature_save and House.state().owned.chair==2 and Stock.count("prof_log")==1 and Stock.count("prof_branch")==1,"cost and owned furniture are complete before saving")
 var before: Dictionary=Stock.state().home.duplicate()
 check(not House.make("cabinet") and Stock.state().home==before,"missing materials cause no partial loss")
 check(not House.make("trophy_forest"),"journey souvenir checks real discovery")
 gs.give("crystal_bos",1,true)
 check(House.make("trophy_forest") and gs.count("crystal_bos")==1 and not House.make("trophy_forest"),"earned souvenir is unique and never consumes quest crystal")
 gs.take("crystal_bos",1);gs.set_flag("gate_temple")
 check(House.unlocked("trophy_forest"),"delivered map crystals still count as a discovered forest memory")
 gs.set_flag("lw_bridge");check(House.make("trophy_swamp"),"repaired sluices unlock matching house memory")
 gs.set_flag("cw_raf_notes");check(House.make("trophy_coast"),"Raf memory uses actual coastal progress")
 gs.set_flag("hs_supplies");gs.save_game(p.position)
 check(gs.load_game() and House.state().floor==1 and House.state().wall==1 and House.state().layout.bed.cell==[2,2] and House.state().owned.chair==2 and Stock.count("prof_log")==1 and gs.flag("hs_supplies"),"save roundtrip retains interior, furniture stock and unrelated inventory")
 gs.in_game=true;await enter("village","from_home")
 check(get_nodes_in_group("house_furniture").is_empty() and not House.make("plant_leaf"),"interior furniture and building stay inside house")
 await enter("player_home");p.set_physics_process(false)
 check(base("bed").position==Vector2(2.5,3.5)*32 and world.spawn_fits(p.position),"revisit reconstructs furniture and safe entrance")
 var malformed:=House.normalize({"floor":1e100,"wall":-1,"light":"bad","owned":{"chair":1e100,"bed":0,"fake":9},"layout":{"bed":{"kind":"bed","cell":[NAN,2],"tint":0}}})
 check(malformed.floor==3 and malformed.wall==0 and malformed.light==0 and malformed.owned.chair==4 and malformed.owned.bed==1 and not malformed.owned.has("fake") and malformed.layout==Catalog.DEFAULT_LAYOUT,"foreign saves bounded before integer conversion and unsafe layouts recover to usable basics")
 # Old save shape lacks only the new field; other phase 2 data must survive.
 gs.save_game(p.position)
 var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH));legacy.erase("personal_home");legacy.pos=[112,98]
 var file:=FileAccess.open(gs.SAVE_PATH,FileAccess.WRITE);file.store_string(JSON.stringify(legacy));file.close()
 check(gs.load_game() and House.state().layout==Catalog.DEFAULT_LAYOUT and Stock.count("prof_log")==1 and gs.flag("lw_bridge"),"legacy save gets usable defaults and preserves storage and world progress")
 gs.in_game=true;await enter("player_home","start",gs.load_pos);p.set_physics_process(false)
 check(p.position.distance_to(Vector2(112,98))>20 and world.spawn_fits(p.position),"legacy position now inside a taller bed safely resumes on protected walkway")
 gs.new_game();check(House.state()==House.defaults(),"new adventure starts with only original free furniture")
 world.queue_free();await frames();print("PERSONAL HOME OK" if failures==0 else "PERSONAL HOME FAILED "+str(failures));quit(0 if failures==0 else 1)
