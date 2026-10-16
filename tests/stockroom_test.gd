extends "res://tests/coast_expedition_test.gd"
const Stock:=preload("res://scripts/core/stockroom.gd")
const Farm:=preload("res://scripts/core/homestead.gd")
const Prof:=preload("res://scripts/core/professions.gd")
const Items:=preload("res://scripts/data/items.gd")
var reentered:=false
var watch_recipe:=false
var partial_saved:=false
func saved_recipe():
 if watch_recipe and gs.count("prof_pickaxe")==0:partial_saved=true
func chest_node() -> Node2D:
 for n in get_nodes_in_group("stock_chests"):
  if not n.is_queued_for_deletion():return n
 return null
func reenter():
 if Stock.busy:reentered=Stock.transfer("hs_grape",1,false,"home")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.get_node("Lang").set_language("nl",false)
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 check(Stock.state().home.is_empty() and not Stock.favorite("potion"),"old/new empty state has safe defaults")
 var clean:=Stock.normalize({"home":{"hs_grape":1e100,"ruin_key":1,"prof_axe":1,"unknown":9,"potion":-1,"gel":.5},"favorites":{"potion":true,"unknown":true},"sort":88})
 check(clean.home=={"hs_grape":999} and clean.favorites=={"potion":true} and clean.sort==3,"foreign state bounded and permanent gear excluded")
 check(not Stock.transfer("hs_grape",1,true,"home") and not Stock.transfer("potion",1,true,""),"no remote or invalid store transfer")
 await enter("player_home");p.set_physics_process(false)
 var home:=chest_node();check(home!=null and Vector2i(home.position/32)==Vector2i(10,5),"one compact indoor chest at intended unused place")
 p.position=home.position+Vector2(0,34);await frames(3)
 check(world.spawn_fits(p.position) and Stock.nearby_kind()=="home","chest approach safe and local materials enabled")
 gs.give("hs_grape",15,true);gs.give("prof_branch",8,true);gs.give("prof_stone",8,true)
 gs.give("potion",3,true);gs.give("prof_axe",1,true)
 var total: int=gs.count("hs_grape")
 check(Stock.transfer("hs_grape",10,true,"home") and gs.count("hs_grape")==5 and Stock.count("hs_grape")==10,"deposit exact quantity without loss")
 check(not Stock.transfer("hs_grape",6,true,"home") and gs.count("hs_grape")+Stock.count("hs_grape")==total,"oversized transfer rejected atomically")
 check(not Stock.transfer("prof_axe",1,true,"home"),"tools and bonuses remain usable in bag")
 Stock.toggle_favorite("prof_stone")
 check(Stock.bulk(false,"home")==8 and gs.count("prof_stone")==8 and gs.count("potion")==3,"material bulk skips favorites and consumables")
 gs.give("hs_grape",2,true);var moved:=Stock.bulk(true,"home")
 check(moved==7 and gs.count("hs_grape")==0 and gs.count("prof_stone")==8,"quick stack fills existing types only")
 gs.items_changed.connect(reenter)
 check(Stock.transfer("hs_grape",1,false,"home") and not reentered,"reentrant listener cannot duplicate a transfer")
 gs.items_changed.disconnect(reenter)
 check(Prof.craft("hs_seeds") and gs.count("hs_seed")==2 and gs.count("hs_grape")==0 and Stock.count("hs_grape")==16,"recipe uses bag first without consuming stored grape unnecessarily")
 watch_recipe=true;gs.save_requested.connect(saved_recipe)
 check(Prof.craft("stone_pickaxe") and gs.count("prof_pickaxe")==1 and Stock.count("prof_branch")==6 and gs.count("prof_stone")==6,"mixed bag/storage recipe consumes exactly its own ingredients")
 watch_recipe=false;gs.save_requested.disconnect(saved_recipe)
 check(not partial_saved,"craft only requests saving after its output exists")
 var before: Dictionary=Stock.state().home.duplicate()
 check(not Prof.craft("copper_bar") and Stock.state().home==before,"storage cannot bypass required workshop")
 var ids:=Stock.ids(gs.inventory,"Vuursteen",1,true)
 check(ids==["prof_stone"],"search category and favorite filters combine")
 Stock.state().sort=3
 check(Stock.ids({"potion":2,"hs_grape":8})==["hs_grape","potion"],"count sorting orders actual amounts")
 Stock.state().sort=2;Stock.toggle_favorite("hs_grape");gs.save_game(p.position)
 check(gs.load_game() and Stock.count("hs_grape")==16 and Stock.favorite("hs_grape") and Stock.state().sort==2,"save roundtrip keeps quantities favorites and order")
 gs.in_game=true
 await enter("forest");p.set_physics_process(false);before=Stock.state().home.duplicate()
 gs.inventory.erase("hs_grape")
 check(Stock.available("hs_grape")==0 and not Prof.craft("hs_seeds") and Stock.state().home==before,"distant home stock visible but cannot feed recipe")
 await enter("village","from_home");p.set_physics_process(false)
 home=chest_node();check(Vector2i(home.position/32)==Vector2i(9,26),"yard chest sits beside path outside garden")
 check(world.map_data.rows[26][9]=="." and world.map_data.rows[26][7]=="," and world.map_size==Vector2i(40,44),"no extra terrain or path footprint")
 for unit in ["wine_a","wine_b"]:
  var vat: Node2D
  for n in get_nodes_in_group("home_stations"):
   if not n.is_queued_for_deletion() and n.obj.get("unit","")==unit:vat=n
  p.position=vat.position+Vector2(0,24);await frames()
  check(Stock.nearby_kind()=="home" and Farm.start_job(unit,1),"both real wine vats accept nearby stock "+unit)
 check(Stock.count("hs_grape")==10 and gs.count("hs_grape")==0,"six stored grapes committed exactly into two jobs")
 p.position=Vector2(7.5,16.4)*32;gs.inventory.erase("hs_manure");Stock.state().home.hs_manure=4
 check(not Farm.start_job("compost",1),"distant compost pile cannot consume yard storage")
 # Capacity never destroys excess; a full store still accepts a partial existing stack.
 p.position=home.position+Vector2(0,34);Stock.state().home={}
 for id: String in Items.ITEMS:
  if Stock.allowed(id) and id!="hs_grape" and Stock.state().home.size()<48:Stock.state().home[id]=1
 check(Stock.state().home.size()==48 and Stock.room("hs_grape","home")==0,"48-type limit bounds home storage")
 Stock.state().home={"hs_grape":998};Stock.toggle_favorite("hs_grape");gs.give("hs_grape",5,true)
 check(Stock.bulk(true,"home")==1 and Stock.count("hs_grape")==999 and gs.count("hs_grape")==4,"quick stack leaves overflow safely in bag")
 # Ammunition is useful stock, but withdrawing still respects its actual bag cap.
 Stock.state().home.arrow=10;gs.give("arrow",39,true)
 check(not Stock.transfer("arrow",2,false,"home") and Stock.transfer("arrow",1,false,"home"),"withdrawal checks actual ammunition destination cap")
 check(gs.count("arrow")==40 and Stock.count("arrow")==9,"capped bag conserves the remaining stored ammunition")
 await enter("coast_workshop");p.set_physics_process(false);gs.set_flag("cw_raf_notes")
 var station: Node2D
 for n in get_nodes_in_group("coastal_workstations"):
  if not n.is_queued_for_deletion() and n.obj.role=="storage":station=n
 p.position=station.position+Vector2(0,28);gs.coastal_storage={"cw_driftwood":2,"prof_branch":2};gs.inventory.erase("cw_driftwood");gs.inventory.erase("prof_branch")
 check(Stock.nearby_kind()=="coast" and Prof.craft("cw_shelf") and gs.count("cw_shelf")==1 and gs.coastal_storage.is_empty(),"existing harbor store supplies local workshop without changing its capacity")
 gs.new_game()
 check(Stock.state().home.is_empty() and Stock.state().favorites.is_empty(),"new game clears stock without inheritance")
 world.queue_free();await frames();print("STOCKROOM OK" if failures==0 else "STOCKROOM FAILED "+str(failures));quit(0 if failures==0 else 1)
