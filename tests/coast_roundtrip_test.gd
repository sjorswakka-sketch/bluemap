extends "res://tests/tides_test.gd"
const HomeData:=preload("res://scripts/core/coastal_home.gd")
const Gear:=preload("res://scripts/core/equipment.gd")
func fixture(data: Dictionary):
 var file:=FileAccess.open(gs.SAVE_PATH,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
func rebuild_world():
 if is_instance_valid(world):world.queue_free();await frames(7)
 gs.in_game=true;world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(15);p=world.player
 for enemy in get_nodes_in_group("enemies"):enemy.set_physics_process(false)
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true
 root.size=Vector2i(1152,648);await rebuild_world()
 # A pre-coast version-one fixture, then its completed variant. No real player save.
 var old: Dictionary={"version":1,"map":"village","pos":[720,416],"hp":4,"coins":72,"inventory":{"potion":2,"boots":1,"ruin_key":1},"flags":{"met_greta":true,"met_mila":true,"gate_ruin":true,"chest:lake:26":true},"quests":{"main":{"state":"active","step":1}},"weapon":"iron","play_time":120.0,"kills":3}
 for completed in [false,true]:
  var data:=old.duplicate(true)
  if completed:
   data.flags["game_completed"]=true;data.flags["boss_defeated"]=true;data.quests.main={"state":"done","step":2}
  fixture(data);check(gs.load_game(),"pre-coast save loads completed="+str(completed));await rebuild_world()
  check(gs.flag("chest:lake:26") and gs.count("potion")==2 and gs.coins==72 and gs.weapon=="iron" and gs.coastal_storage.is_empty(),"legacy keys, items, weapon and optional storage preserved")
  check(not gs.flag("op_new_adventure") and gs.flag("game_completed")==completed,"legacy player keeps progression without a new opening")
  check(not Journey.path("village","coast_workshop").is_empty() and not Journey.path("coast_workshop","village").is_empty(),"free route connects old village and new return interior")
  # All advertised ferry choices, each followed by a real scene reload of its autosave.
  for route in [["coast","harbor"],["harbor","gull_island"],["gull_island","tide_cove"],["tide_cove","coast"]]:
   await enter(route[0]);clock(70)
   await open_station("routes");var ui:=routes()
   var choice: Dictionary={}
   for entry: Dictionary in station("routes").obj.routes:
    if entry.to==route[1]:choice=entry
   check(not choice.is_empty(),"actual route board offers "+str(route))
   if choice.is_empty():continue
   var inv: Dictionary=gs.inventory.duplicate(true);var hp: int=gs.hp;var money: int=gs.coins;var xp: int=gs.hero_xp
   ui.choose_route(choice);voyage().depart();await frames(65)
   check(gs.map_id==route[1] and world.spawn_fits(p.position) and not gs.input_locked(),"ferry commits safe arrival "+str(route))
   check(gs.inventory==inv and gs.hp==hp and gs.coins==money and gs.hero_xp==xp,"whole roundtrip costs and rewards nothing")
   var map: String=gs.map_id
   check(gs.load_game(),"ferry autosave really reloads");await rebuild_world()
   check(gs.map_id==map and world.spawn_fits(p.position) and gs.flag("game_completed")==completed and gs.flag("chest:lake:26"),"reload retains arrival and old completion state")
  await enter("smithy")
  var npc: Node2D
  for n in get_nodes_in_group("npc"):
   if n.npc_id=="greta":npc=n
  check(npc!=null,"Greta remains in her old workshop")
  p.position=npc.position+Vector2(0,28);await frames(4);await tap(KEY_E)
  check(world.dialogue.active,"returning from coast can still speak to Greta");world.dialogue._close();await frames()
 # Combined post-expansion save keeps independent consequences, furniture and gear.
 gs.new_game();gs.in_game=true
 await enter("coast_workshop")
 for item in ["cw_shelf","cw_lamp","cw_hook","td_line","gear_cw_anchor","gear_cw_fan"]:gs.give(item,1,true)
 for flag in ["game_completed","ad_message_done","ad_pilot_done","ad_wheel_done","ad_keeper_done","ad_pool","cw_raf_notes","pg_smith_notes","pg_focus_notes","lw_bridge","ra_spring","chest:lake:26"]:gs.set_flag(flag)
 gs.coastal_storage={"cw_reed":7};Gear.equip("gear_cw_anchor");HomeData.set_furniture("shelf",1);HomeData.set_furniture("lamp",2)
 gs.save_game(p.position);var inv: Dictionary=gs.inventory.duplicate(true)
 check(gs.load_game(),"combined coastal completion save loads");await rebuild_world()
 check(gs.map_id=="coast_workshop" and world.spawn_fits(p.position) and gs.coastal_storage=={"cw_reed":7} and gs.equipment.hands=="gear_cw_anchor" and gs.flag("cw_lamp_sea"),"resume retains actual workshop location, storage, loadout and furnishing")
 await enter("tidal_hollow")
 check(not world.is_solid(Vector2(29.5,14.5)*32) and gs.flag("ad_pool") and not gs.flag("ad_workwater"),"repaired bridge and chosen peaceful pool remain independent")
 await enter("harbor");await enter("headland");await enter("village")
 check(gs.inventory==inv and gs.flag("lw_bridge") and gs.flag("ra_spring") and gs.flag("chest:lake:26"),"coastal return leaves previous regions and collection IDs intact")
 # A line action may not commit into a newly occupied landing or without its tool.
 await enter("tide_cove");clock(70);await open_station("line")
 var line:=routes();var original: Vector2=p.position
 line.set_process(false);line.start_crossing();line._process(.4);gs.take("td_line",1);line._process(.1)
 check(not line.crossing and not gs.input_locked() and p.position.distance_to(original)<1,"removing borrowed tool cancels crossing safely")
 if line.active:line.close()
 gs.give("td_line",1,true);await open_station("line");line=routes();line.set_process(false);line.start_crossing()
 original=line.start
 var block:=StaticBody2D.new();block.collision_layer=1;block.position=line.landing+Vector2(0,8)
 var collision:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(40,40);collision.shape=box;block.add_child(collision);world.entities.add_child(block)
 line._process(1.2)
 check(not line.crossing and not gs.input_locked() and p.position.distance_to(original)<1 and gs.count("td_line")==1,"occupied landing rejects late commit without losing reusable tool")
 block.queue_free();line.set_process(true);await frames(4)
 # A real NG+ uses existing carryover policy, resets region stories and storage.
 check(gs.new_game_plus(),"completed save enables ordinary NG+")
 check(gs.count("gear_cw_anchor")==1 and gs.count("gear_cw_fan")==1 and gs.coastal_storage.is_empty() and not gs.flag("ad_pool") and not gs.flag("cw_lamp_sea"),"NG+ carries owned gear while resetting world and storage")
 world.queue_free();await frames(6)
 print("COAST ROUNDTRIP OK" if failures==0 else "COAST ROUNDTRIP FAILED "+str(failures));quit(0 if failures==0 else 1)
