extends "res://tests/coast_expedition_test.gd"
const Adventure:=preload("res://scripts/core/coastal_adventures.gd")
func prop(role: String) -> Node2D:
 for n in get_nodes_in_group("coast_adventures"):
  if not n.is_queued_for_deletion() and n.obj.role==role:return n
 return null
func ui() -> Node:
 for n in get_nodes_in_group("adventure_ui"):
  if not n.is_queued_for_deletion() and n.active:return n
 return null
func open(role: String):
 var node:=prop(role);check(node!=null,"prop exists "+role)
 if node==null:return
 p.position=node.position+Vector2(0,28);await frames(4);await tap(KEY_E)
 check(ui()!=null and gs.ui_owners.has("adventure"),"actual interaction opens "+role)
func select(index:=0,pad:=false):
 if ui()==null:return
 ui().buttons[index].grab_focus();await tap(JOY_BUTTON_A if pad else KEY_ENTER,pad)
func close_ui():
 if ui()!=null:await tap(JOY_BUTTON_B,true)
 await frames(3)
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 # Appended objects preserve existing collection keys; all quiet maps stay enemy free.
 for id in ["coast","gull_island","tide_cove","river_mouth","harbor","headland"]:
  var old: Dictionary=Maps.MAPS[id].DATA.duplicate(true)
  for file in ["living_maps","regional_maps","combat_maps","craft_maps","space_maps","habitat_maps","coast_maps","coastal_region_maps"]:load("res://scripts/data/"+file+".gd").enrich(id,old)
  preload("res://scripts/data/route_repairs.gd").enrich(id,old)
  var data: Dictionary=Maps.get_map(id)
  for i in old.objects.size():check(data.objects[i]==old.objects[i],"legacy slot retained "+id+str(i))
  check(data.objects.filter(func(o: Dictionary) -> bool:return o.type=="enemy" and not o.get("trail_wildlife",false)).is_empty(),"no added outdoor enemies "+id)
 # Observe before accepting; wrong conclusions cost nothing and can be corrected.
 await enter("gull_island");await open("splinter");await select();await close_ui()
 await enter("river_mouth","from_coast");await open("silt");await select();await close_ui()
 check(Adventure.evidence() and not gs.quests.has("ad_message"),"evidence can precede quest without inventory quota")
 await enter("gull_island");await open("message");await close_ui()
 check(gs.quest_step("ad_message")==1,"known observations advance investigation")
 await enter("harbor");await open("record")
 var xp: int=gs.hero_xp;var coins: int=gs.coins;var inventory: Dictionary=gs.inventory.duplicate(true)
 await select(1);check(gs.hero_xp==xp and gs.coins==coins and gs.inventory==inventory and not gs.flag("ad_message_done"),"wrong deduction consumes nothing")
 await click(ui().buttons[0]);check(gs.flag("ad_message_done") and gs.hero_xp==xp+40,"correct deduction finishes once")
 ui().deduce(true);check(gs.hero_xp==xp+40,"repeated answer cannot farm experience")
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;await frames(3);ui().layout()
   check(Rect2(Vector2.ZERO,Vector2(size)).encloses(ui().panel.get_global_rect()),"adventure panel fits "+locale+str(size))
 root.get_node("Lang").set_language("nl",false);root.size=Vector2i(1152,648);await close_ui()
 # Navigation requires reading successive terrain clues, not just arriving at the finish.
 await enter("headland");await open("shelter");check(ui().buttons[0].disabled,"finish cannot skip navigation");await close_ui()
 await open("pilot");await select(0,true);await close_ui()
 await open("grass");check(ui().buttons[0].disabled,"waypoints cannot be read out of order");await close_ui()
 await open("rock");await select();await close_ui()
 await route_to(Vector2i(45,18));await open("grass");await select();await close_ui()
 await route_to(Vector2i(47,35));await open("shelter");await select();await close_ui()
 check(not prop("shelter").body.disabled,"restored windbreak has a real footprint")
 check(gs.flag("ad_pilot_done"),"landmark route restores visible resting shelter")
 # The grotto is a side exit with a real route both ways, not on the ordinary coast loop.
 await enter("river_mouth","from_coast");await route_to(Vector2i(16,12))
 check(not world.is_solid(Vector2(16.5,10.5)*32),"optional cave entrance has dry terrain")
 p.position=Vector2(16.5,11.8)*32;await frames(3);Input.action_press("move_up");await frames(50);release();await frames(40)
 check(gs.map_id=="tidal_hollow" and world.spawn_fits(p.position),"actual cave portal reaches safe arrival")
 for n in get_nodes_in_group("enemies"):n.set_physics_process(false)
 var hp: int=gs.hp
 p.invuln=0
 for n in get_nodes_in_group("enemies"):n.set_physics_process(true)
 await route_to(Vector2i(40,30));check(gs.hp==hp,"permanent southern crossing works before repair")
 var wheel:=prop("wheel");p.position=wheel.position+Vector2(0,42);await frames(3);Input.action_press("move_up");await frames(35);release()
 check(p.position.y>wheel.position.y+14,"actual movement stops at tide-wheel foot")
 await open("wheel");await select();await frames(20);await tap(JOY_BUTTON_B,true)
 check(not gs.flag("ad_wheel_done") and not p.work_active and not gs.input_locked(),"B cancels repair without partial commit")
 await open("wheel");await select();Input.action_press("move_right");await frames(3);release()
 check(not gs.flag("ad_wheel_done") and not gs.input_locked(),"movement cancels repair safely")
 await open("wheel");await select();world.load_map("harbor","start");await frames(8);p=world.player
 check(not gs.flag("ad_wheel_done") and not gs.input_locked() and not p.work_active,"forced map unload cancels repair and releases UI")
 await enter("tidal_hollow","start",Vector2(12.5,27.5)*32)
 check(world.spawn_fits(p.position) and p.position.distance_to(prop("wheel").position)>5,"old saved position inside new wheel moves to free floor")
 await open("wheel");await select();await frames(125)
 p=world.player;check(gs.flag("ad_wheel_done") and not gs.input_locked() and not world.is_solid(Vector2(29.5,14.5)*32),"completed repair persists and opens only short bridge")
 await open("sluice");await select(0,true);await frames(4)
 check(gs.flag("ad_pool") and gs.flag("ad_keeper_done") and gs.quest_state("ad_keeper")=="done","peaceful choice completes encounter without combat")
 check(get_nodes_in_group("enemies").filter(func(e: Node) -> bool:return e.kind=="ad_keeper").is_empty(),"peace does not spawn a hostile keeper")
 gs.set_flag("game_completed");gs.set_flag("chest:lake:26");gs.save_game(p.position);xp=gs.hero_xp
 check(gs.load_game() and gs.flag("ad_pool") and gs.flag("ad_wheel_done") and gs.flag("game_completed") and gs.flag("chest:lake:26"),"save retains new outcomes and old completed-game flags")
 await enter("tidal_hollow");await open("sluice");await close_ui();check(gs.hero_xp==xp,"revisiting outcome grants no repeated reward")
 await close_ui();await route_to(Vector2i(40,30));await route_to(Vector2i(4,30))
 p.position=Vector2(2.5,29.5)*32;await frames(3);Input.action_press("move_left");await frames(50);release();await frames(40)
 check(gs.map_id=="river_mouth" and gs.flag("ad_pool") and world.spawn_fits(p.position),"actual return portal stays open after story outcome")
 world.queue_free();await frames()
 print("COASTAL ADVENTURES OK" if failures==0 else "COASTAL ADVENTURES FAILED "+str(failures));quit(0 if failures==0 else 1)
