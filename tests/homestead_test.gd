extends "res://tests/coast_expedition_test.gd"
const Farm:=preload("res://scripts/core/homestead.gd")
var Fast: Script
func prop(role: String,unit:="") -> Node2D:
 for n in get_nodes_in_group("home_stations"):
  if not n.is_queued_for_deletion() and n.obj.role==role and (unit=="" or n.obj.get("unit","")==unit):return n
 return null
func ui() -> Node:
 for n in get_nodes_in_group("home_ui"):
  if not n.is_queued_for_deletion() and n.active:return n
 return null
func open(role: String,unit:=""):
 var n:=prop(role,unit);check(n!=null,"workplace exists "+role)
 if n==null:return
 p.position=n.position+Vector2(0,30);await frames(3);p._update_target();await tap(KEY_E)
 check(ui()!=null,"actual input opens "+role)
 if ui()==null:quit(1)
func close_ui():
 if ui()!=null:ui().close()
 await frames(3)
func tool(at: Vector2i,mode: String):
 p.position=Vector2(at)*32+Vector2(16,48);p.facing=Vector2.UP;Farm.mode=mode
 for n in get_nodes_in_group("homesteads"):
  if not n.is_queued_for_deletion():n.cooldown=0
 p._update_target();await tap(KEY_E);await frames(2)
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");Fast=load("res://scripts/core/fast_travel.gd");gs.new_game();gs.in_game=true
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(15);p=world.player;gs.set_process(false)
 check(gs.movement.can_sprint(),"sprint available in a new game")
 await enter("village","from_home");p.set_physics_process(false)
 check(world.map_size==Vector2i(40,44),"garden adds space beyond existing town")
 check(Maps.get_map("village").objects.filter(func(o):return o.type=="portal" and o.to=="lake")[0].pos==[19,26],"old lake exit keeps its exact location")
 await open("guide");ui().supply();check(gs.count("hs_hoe")==1 and gs.count("hs_seed")==8,"free one-time starter tools and seeds")
 var inventory: Dictionary=gs.inventory.duplicate(true);ui().supply();check(gs.inventory==inventory,"starter cannot duplicate")
 await close_ui()
 # The existing facade has a physical portal and a navigable interior.
 p.set_physics_process(true);p.position=Vector2(7.5,22.5)*32
 Input.action_press("move_up");await frames(50);release();await frames(40);p=world.player;p.set_physics_process(false)
 check(gs.map_id=="player_home" and world.spawn_fits(p.position),"walking through old southwest house enters real home")
 await open("bed");gs.hp=1;gs.movement.stamina=1;ui().rest();await frames(3)
 check(gs.hp==gs.max_hp() and gs.movement.stamina==gs.movement.capacity(),"home bed restores and saves")
 check(gs.load_game() and gs.map_id=="player_home","save resumes inside home")
 await enter("village","from_home");p.set_physics_process(false)
 var altar: Node2D
 for n in world.entities.get_children():
  if n.get_script()!=null and n.get_script().resource_path.ends_with("savepoint.gd") and Vector2i(n.position/32)==Vector2i(9,23):altar=n
 p.position=altar.position+Vector2(0,30);altar.interact()
 check(Fast.discovered_altars().any(func(a):return a.name=="Bij je eigen huis"),"home teleport joins normal discovered travel list")
 # Hold-to-work prepares an entire row using actual movement rather than repeated clicks.
 p.set_physics_process(true);p.position=Vector2(5.5,38.5)*32;p.facing=Vector2.RIGHT;Farm.mode="soil"
 Input.action_press("interact");await walk_to(Vector2(10.5,38.5)*32);Input.action_release("interact");p.set_physics_process(false)
 var worked:=0
 for x in range(6,11):
  if Farm.state().cells.get(str(x)+",38",{}).get("kind","")=="soil":worked+=1
 check(worked>=4,"holding interact and walking prepares consecutive cells without repeated presses")
 # Dry vines wait. A growing connected channel supplies a whole network.
 await tool(Vector2i(16,33),"soil");await tool(Vector2i(16,33),"grape")
 check(Farm.state().cells.get("16,33",{}).get("crop","")=="grape" and gs.count("hs_seed")==7,"actual native input tills and plants one cell")
 Farm.advance(100);check(Farm.state().cells["16,33"].growth==0,"dry crops wait without dying")
 for at in [Vector2i(19,33),Vector2i(18,33),Vector2i(17,33)]:await tool(at,"channel")
 check(Farm.watered(Vector2i(16,33)) and Farm.wet.size()==3,"water propagates from brook through extended channel")
 for x in [17,18,19]:check(world.spawn_fits(Vector2(x+.5,33.5)*32),"channel stays freely walkable "+str(x))
 p.set_physics_process(true);p.position=Vector2(16.5,33.5)*32
 await walk_to(Vector2(19.5,33.5)*32);p.set_physics_process(false)
 check(p.position.x>19*32,"actual movement crosses consecutive narrow canals")
 Farm.advance(40);check(Farm.state().cells["16,33"].growth==40,"connected irrigation advances crop")
 await tool(Vector2i(19,33),"fill");Farm.advance(20)
 check(not Farm.watered(Vector2i(16,33)) and Farm.state().cells["16,33"].growth==40,"disconnecting source stops downstream growth")
 await tool(Vector2i(19,33),"channel")
 # Existing living wildlife supplies magnetic manure; no kill is required.
 await enter("dorstvallei");p.set_physics_process(false)
 var animals: Array=get_nodes_in_group("enemies").filter(func(n):return n.data.behavior=="animal" and not n.is_queued_for_deletion())
 check(animals.size()>=2,"uses existing wildlife")
 for n in animals.slice(0,2):
  p.position=n.position;n._ai_animal(.1);await frames(50)
 check(gs.count("hs_manure")>=2,"living animal droppings use ordinary magnetic pickups")
 var drops: int=Farm.state().drops.size()
 for n in animals:n._ai_animal(.1)
 check(Farm.state().drops.size()<=drops,"saved cooldown prevents repeated drops on every AI tick")
 await enter("village");p.set_physics_process(false)
 await open("compost");var old: int=gs.count("hs_manure");ui().start("compost",1)
 check(gs.count("hs_manure")==old-2 and Farm.state().jobs.has("compost"),"manure is committed into one compost batch")
 var elapsed: float=Farm.state().jobs.compost.time;gs._process(40)
 check(Farm.state().jobs.compost.time==elapsed,"menus pause crop and production clock")
 await close_ui();Farm.advance(31);await open("compost");ui().collect("compost")
 check(gs.count("hs_fertilizer")==3 and not Farm.state().jobs.has("compost"),"compost gives exact output once")
 ui().collect("compost");check(gs.count("hs_fertilizer")==3,"repeated collect cannot duplicate fertilizer");await close_ui()
 await tool(Vector2i(16,33),"fertilize");Farm.advance(60)
 old=gs.count("hs_grape");await tool(Vector2i(16,33),"harvest")
 check(gs.count("hs_grape")==old+5 and Farm.state().cells["16,33"].growth==0 and not Farm.state().cells["16,33"].fertilized,"fertilizer improves one harvest and keeps perennial vine")
 await enter("forest");p.set_physics_process(false);await open("wild_grape");ui().grapes();await close_ui()
 check(gs.count("hs_grape")>=8,"wild and farmed grapes share usable inventory item")
 gs.hp=1;check(load("res://scripts/core/professions.gd").use_item("hs_grape") and gs.hp==2,"eating grapes restores HP through existing consumables")
 await enter("village");p.set_physics_process(false);await open("wine","wine_a");ui().start("wine_a",1);await close_ui();Farm.advance(91)
 await open("wine","wine_a");ui().collect("wine_a");await close_ui();check(gs.count("hs_wine")==1,"grapes become real wine via timed vat")
 await open("hive");ui().collect("hive");await close_ui();check(gs.count("hs_honey")>0,"nearby flowers support real honey output")
 # Remove natural flowers, then restore pollination using player-grown flowers.
 for at in Farm.FLOWERS:await tool(at,"soil")
 check(Farm.flowers()==0,"tilled natural flower patches stop counting for bees")
 Farm.state().honey=0;Farm.state().honey_time=0;Farm.advance(200)
 check(Farm.state().honey==0,"no flowers means no new honey")
 for at in [Vector2i(16,32),Vector2i(16,34),Vector2i(16,35)]:
  await tool(at,"soil");await tool(at,"flower")
 for at in [Vector2i(17,32),Vector2i(17,34),Vector2i(17,35)]:await tool(at,"channel")
 Farm.advance(61);check(Farm.flowers()>=3,"self-grown irrigated flowers become pollen sources")
 Farm.advance(120);check(Farm.state().honey>0,"honey resumes after grown flowers bloom")
 # Save connected topology, partial jobs and mature crops; no offline time bonus.
 await open("wine","wine_b");ui().start("wine_b",1);await close_ui();Farm.advance(20)
 gs.save_game(p.position);var farm: Dictionary=Farm.state().duplicate(true)
 var loaded: bool=gs.load_game()
 check(loaded and Farm.state()==farm,"save/load preserves complete interconnected farm without catch-up")
 check(Farm.watered(Vector2i(16,33)),"water network recomputed correctly after load")
 var normalized:=Farm.normalize({"cells":{"1,1":{"kind":"soil"},"16,33":{"kind":"soil","crop":"invalid"}},"honey":999,"jobs":{"unknown":{"time":900}}})
 check(normalized.cells.size()==1 and not normalized.cells["16,33"].has("crop") and normalized.honey==8 and normalized.jobs.is_empty(),"malformed farm data stays bounded and known")
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=size
   await tap(KEY_U);await frames(5)
   check(ui()!=null and Rect2(Vector2.ZERO,Vector2(size)).encloses(ui().panel.get_global_rect()),"tool panel fits "+locale+str(size))
   await close_ui()
 await tap(JOY_BUTTON_RIGHT_STICK,true);await frames(4)
 check(world.crafting_ui.active,"R3 retains existing profession menu")
 await tap(JOY_BUTTON_Y,true);await frames(4)
 check(ui()!=null and root.get_node("Controls").controller_active and ui().buttons[0].mouse_filter==Control.MOUSE_FILTER_IGNORE,"R3 then Y opens garden palette with exclusive controller UI")
 await tap(JOY_BUTTON_B,true);check(ui()==null and not gs.input_locked(),"B closes garden palette without affecting field")
 var previous_items: Dictionary=gs.inventory.duplicate(true)
 var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH));legacy.erase("homestead")
 var old_file:=FileAccess.open(gs.SAVE_PATH,FileAccess.WRITE);old_file.store_string(JSON.stringify(legacy));old_file.close()
 check(gs.load_game() and Farm.state().cells.is_empty() and gs.inventory==previous_items,"older save without farm field loads with inventory intact and empty garden")
 gs.new_game();check(Farm.state().cells.is_empty(),"new game clears farm state")
 world.queue_free();await frames();print("HOMESTEAD OK" if failures==0 else "HOMESTEAD FAILED "+str(failures));quit(0 if failures==0 else 1)
