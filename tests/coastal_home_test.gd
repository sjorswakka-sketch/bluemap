extends "res://tests/coast_expedition_test.gd"
var Home: Script
var Prof: Script
var Equipment: Script
func station(role: String) -> Node2D:
 var found: Node2D
 for n in get_nodes_in_group("coastal_workstations"):
  if not n.is_queued_for_deletion() and n.obj.role==role:
   if found==null or n.position.distance_to(p.position)<found.position.distance_to(p.position):found=n
 return found
func home_ui() -> Node:
 for n in get_nodes_in_group("coastal_home_ui"):
  if not n.is_queued_for_deletion() and n.active:return n
 return null
func open_station(role: String):
 var n:=station(role);check(n!=null,"station exists "+role)
 if n==null:return
 p.position=n.position+Vector2(0,28);await frames(4);await tap(KEY_E)
 check(home_ui()!=null and gs.ui_owners.has("coastal_home"),"actual input opens "+role)
func select(index:=0,pad:=false):
 if home_ui()==null:return
 home_ui().buttons[index].grab_focus();await tap(JOY_BUTTON_A if pad else KEY_ENTER,pad)
func close_home():
 if home_ui()!=null:await tap(JOY_BUTTON_B,true)
 await frames()
func resource(kind: String) -> Node2D:
 for n in get_nodes_in_group("profession_resources"):
  if not n.is_queued_for_deletion() and n.kind==kind:return n
 return null
func gather(kind: String):
 var n:=resource(kind);check(n!=null,"one regional source exists "+kind)
 if n==null:return
 var cell:=Vector2i(n.position/32)
 check(world.map_data.rows[cell.y][cell.x] not in [",","9"],"regional source stays off existing path "+kind)
 p.position=n.position+Vector2(0,27);await frames(4);await tap(KEY_E);await frames(100)
 check(gs.count(kind)>0 and Prof.remaining(n.resource_id)>0,"real work animation commits "+kind)
func learn_note(kind: String):
 for n in get_nodes_in_group("craft_notes"):
  if not n.is_queued_for_deletion() and n.obj.kind==kind:
   p.position=n.position+Vector2(0,28);await frames(4);await tap(KEY_E)
   check(world.dialogue.active,"actual note teaches coastal use "+kind);world.dialogue._close();await frames();return
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true
 Home=load("res://scripts/core/coastal_home.gd");Prof=load("res://scripts/core/professions.gd");Equipment=load("res://scripts/core/equipment.gd")
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 check(load("res://scripts/data/ext/beroepen.gd").SKILLS.size()==7,"existing seven professions retained")
 await enter("coast")
 var n:=resource("cw_driftwood");p.position=n.position+Vector2(0,27);await frames(4);await tap(KEY_E);await frames(85)
 check(gs.count("cw_driftwood")==0 and Prof.remaining(n.resource_id)==0,"missing axe does not award material or start cooldown")
 gs.give("prof_axe",1,true);gs.give("prof_pickaxe",1,true)
 await gather("cw_driftwood")
 await enter("river_mouth","from_coast");await gather("cw_reed")
 await open_station("line");check(home_ui().buttons[0].disabled,"shortcut explains and checks missing reusable tool");await close_home()
 await enter("tidal_hollow");await gather("cw_seaglass")
 await enter("headland");await gather("cw_saltleaf")
 check(gs.count("cw_driftwood")==6 and gs.count("cw_reed")==6 and gs.count("cw_seaglass")==6 and gs.count("cw_saltleaf")==4,"single visit to four sparse sources supplies initial plans")
 # Old-world ingredients are fixtures; their gathering and fishing already have dedicated tests.
 gs.give("prof_copper_bar",2,true);gs.give("prof_branch",2,true);gs.give("prof_herb",1,true);gs.give("gel",1,true);gs.give("meer_baars",1,true)
 var before: Dictionary=gs.inventory.duplicate(true)
 check(not Prof.craft("cw_hook") and gs.inventory==before,"locked or wrong-place craft consumes nothing")
 await enter("smithy");await learn_note("smith")
 check(Prof.craft("cw_anchor") and gs.count("gear_cw_anchor")==1,"Greta pattern and original smithing craft anchor gear")
 var xp: int=Prof.xp("smithing");before=gs.inventory.duplicate(true)
 check(not Prof.craft("cw_anchor") and gs.inventory==before and Prof.xp("smithing")==xp,"unique gear cap prevents repeated cost or XP")
 await enter("library");await learn_note("focus")
 check(Prof.craft("cw_fan") and Prof.craft("cw_lamp"),"Lena connects coast materials to existing alchemy")
 await enter("inn");check(Prof.craft("cw_broth"),"existing cooking uses lake fish and headland herb")
 gs.hp=2;gs.movement.stamina=20
 check(Prof.use_item("cw_broth") and gs.hp==4 and gs.movement.stamina==40,"coastal meal has real bounded effects")
 await enter("harbor")
 for npc in get_nodes_in_group("npc"):
  if npc.npc_id=="rg_raf":p.position=npc.position+Vector2(0,28);break
 await frames(4);await tap(KEY_E)
 check(gs.flag("cw_raf_notes") and world.dialogue.active,"Raf personally shares workshop patterns while keeping existing service")
 world.dialogue._close();await frames()
 await open_station("door");await select(0,true);await frames(70);p=world.player
 check(gs.map_id=="coast_workshop" and world.spawn_fits(p.position),"interactive door arrives safely in existing harbor building")
 check(Prof.craft("cw_hook") and Prof.craft("cw_shelf"),"Raf workbench makes reusable route tool and fixed furniture")
 check(gs.count("cw_driftwood")==0 and gs.count("cw_seaglass")==0,"all first plans fit one harvest without waiting for respawn")
 gs.professions["goal"]="pg_grip"
 await open_station("bench");home_ui().recipe("cw_anchor");await frames(7)
 check(world.crafting_ui.active and world.crafting_ui.selected_entry=="cw_anchor" and gs.professions.get("goal","")=="pg_grip","explicit recipe opens even with another pinned material goal")
 world.crafting_ui.close();gs.professions.erase("goal");await frames()
 # Safe furniture, local training capability, storage and crafted-goal navigation.
 await open_station("layout");await select();await frames()
 check(gs.flag("cw_shelf_placed") and gs.count("cw_shelf")==1,"placing fixed shelf preserves furniture ownership")
 await select(2,true);check(gs.flag("cw_lamp_on") and not gs.flag("cw_lamp_sea"),"warm light is an explicit controller choice")
 await select(3);check(gs.flag("cw_lamp_sea"),"alternate lamp color persists as a flag")
 await close_home()
 gs.give("cw_reed",12,true)
 await open_station("storage")
 var ui:=home_ui();ui.pick("cw_reed");await frames(3)
 var total: int=gs.count("cw_reed")+Home.count("cw_reed")
 ui.move(5);check(Home.count("cw_reed")==5 and gs.count("cw_reed")+Home.count("cw_reed")==total,"storage transfer conserves material exactly")
 ui.direction(false);ui.pick("cw_reed");ui.move(5);check(Home.count("cw_reed")==0 and gs.count("cw_reed")==total,"withdrawal conserves material and frees slot")
 check(not Home.transfer("ruin_key",1,true) and not Home.transfer("gear_cw_anchor",1,true),"quest keys and gear cannot be stored")
 before=gs.inventory.duplicate(true);check(not Home.transfer("cw_reed",100,true) and gs.inventory==before,"oversized transfer is atomic rejection")
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;await frames(3);ui.layout();check(Rect2(Vector2.ZERO,Vector2(size)).encloses(ui.panel.get_global_rect()),"storage fits "+locale+str(size))
 root.get_node("Lang").set_language("nl",false);root.size=Vector2i(1152,648);await frames(4)
 ui.direction(true);ui.pick("cw_reed");await frames(5)
 await click(ui.buttons.filter(func(b: Button) -> bool:return b.get_meta("action")=="move1")[0]);check(Home.count("cw_reed")==1,"native mouse commits selected storage action")
 await close_home()
 # Persistence, malformed old/foreign data and no refill from gear swapping.
 Equipment.equip("gear_cw_anchor");gs.movement.stamina=12;Equipment.equip("gear_cw_fan")
 check(gs.movement.stamina==12 and Equipment.bonus("armor")==0 and Equipment.bonus("harvest_time_reduction")==.15,"hand-slot tradeoff replaces bonuses without refilling stamina")
 gs.set_flag("game_completed");gs.set_flag("ad_pool");gs.set_flag("chest:lake:26");gs.save_game(p.position)
 check(gs.load_game() and Home.count("cw_reed")==1 and gs.flag("cw_shelf_placed") and gs.flag("cw_lamp_sea") and gs.flag("ad_pool") and gs.flag("chest:lake:26"),"real save retains storage, furniture, gear and old world outcomes")
 check(Home.normalize({"cw_reed":9999,"ruin_key":1,"cw_saltleaf":-4,"unknown":10})=={"cw_reed":99},"storage normalizer rejects unknown, quest and invalid data")
 gs.coastal_storage={}
 for item: String in load("res://scripts/data/items.gd").ITEMS:
  if item!="cw_reed" and Home.allowed(item) and gs.coastal_storage.size()<12:gs.coastal_storage[item]=1
 var unlisted:="cw_reed"

 check(gs.coastal_storage.size()==12 and Home.room(unlisted)==0,"full type capacity rejects a new material without loss")
 gs.coastal_storage={"cw_reed":98};gs.give("cw_reed",5,true)
 check(Home.movable("cw_reed",true)==1 and not Home.transfer("cw_reed",2,true),"per-material cap checked before committing")
 await open_station("storage");world.load_map("harbor","start");await frames(8);p=world.player
 check(not gs.ui_owners.has("coastal_home") and not gs.input_locked(),"forced map unload releases storage owner")
 await enter("river_mouth","from_coast");await open_station("line");await select();await frames(15);await tap(JOY_BUTTON_B,true)
 check(not gs.input_locked() and gs.count("cw_hook")==1,"line crossing cancels without consuming reusable tool")
 await open_station("line");var origin: Vector2=p.position;await select();await frames(90)
 check(gs.map_id=="river_mouth" and p.position.distance_to(origin)>350 and world.spawn_fits(p.position) and gs.count("cw_hook")==1,"tool opens actual safe river shortcut without consuming itself")
 origin=p.position;await open_station("line");await select();await frames(90)
 check(p.position.x<origin.x-350 and world.spawn_fits(p.position) and gs.count("cw_hook")==1,"same reusable tool works from the opposite bank")
 gs.new_game();check(gs.coastal_storage.is_empty() and not gs.flag("cw_shelf_placed"),"new game clears workshop state")
 world.queue_free();await frames();print("COASTAL HOME OK" if failures==0 else "COASTAL HOME FAILED "+str(failures));quit(0 if failures==0 else 1)
