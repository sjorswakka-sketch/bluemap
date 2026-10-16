extends "res://tests/coast_expedition_test.gd"
const Farm:=preload("res://scripts/core/homestead.gd")
func seed_ui() -> Node:
 for n in get_nodes_in_group("orchard_ui"):
  if not n.is_queued_for_deletion() and n.active:return n
 return null
func open_book():
 await tap(KEY_U);await frames()
 var guide: Node
 for n in get_nodes_in_group("home_ui"):
  if n.active:guide=n
 check(guide!=null,"native U opens garden tool palette")
 if guide!=null:
  var entry: Button
  for b in guide.buttons:
   if b.text=="Zaden en boomgaard":entry=b
  check(entry!=null,"new seed book is discoverable through actual tool buttons")
  if entry!=null:await click(entry)
 await frames(4);return seed_ui()
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.get_node("Lang").set_language("nl",false);gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(10);p=world.player
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1152,648)
 await enter("village","from_home");p.set_physics_process(false);p.position=Vector2(6.5,24.0)*32;Farm.starter()
 var ui: Node=await open_book()
 check(ui!=null and gs.ui_owners.has("orchard") and not gs.ui_owners.has("homestead"),"seed book takes exactly one modal owner")
 if ui==null:quit(1);return
 await click(ui.starter_button)
 check(gs.flag("or_starter") and gs.count("or_apple_seed")==1 and ui.starter_button.disabled,"native free pack button grants and disables once")
 ui.choose(4);await tap(JOY_BUTTON_RIGHT_SHOULDER,true)
 check(ui.plant_button.has_focus(),"controller shoulder reaches planting action")
 await tap(JOY_BUTTON_A,true);await frames(25)
 check(seed_ui()==null and Farm.mode=="apple" and Farm.state().cells.is_empty() and not gs.input_locked(),"controller selection chooses tree tool without leaking a planting action")
 p.position=Vector2(8.5,34.5)*32;p.facing=Vector2.RIGHT;p._update_target()
 check(Farm.act(Vector2i(9,34),"soil",world),"tree tool can use existing prepared ground")
 for n in get_nodes_in_group("homesteads"):n.cooldown=0;n.waiting_release=false
 await tap(KEY_E);await frames()
 check(Farm.state().cells.get("9,34",{}).get("crop","")=="apple","real interact key plants selected tree through existing held-input system")
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;await frames()
   ui=load("res://scripts/ui/orchard_ui.gd").new();ui.world=world;world.add_child(ui);ui.open();await frames(8)
   check(Rect2(Vector2.ZERO,Vector2(size)).encloses(Rect2(ui.panel.position,ui.panel.size*ui.panel.scale)) and ui.panel.scale.x>=.85,"readable seed catalog fits "+locale+str(size))
   for i in range(8):
    ui.choose(i);await frames(2);check(ui.title.text!="" and ui.description.text!="","each crop has a real growth card and application")
   await tap(JOY_BUTTON_B,true);await frames()
   check(seed_ui()==null and not gs.input_locked(),"controller B closes seed book cleanly")
 root.get_node("Lang").set_language("nl",false);root.size=Vector2i(1152,648);p.position=Vector2(6.5,24.0)*32
 ui=await open_book();gs.coins=50;ui.choose(0);await click(ui.buy_five)
 check(gs.count("or_carrot_seed")==7 and gs.coins==30,"native buy-five button has the exact quantity and coin cost")
 world.load_map("player_home","start");await frames(8)
 check(seed_ui()==null and not gs.ui_owners.has("orchard"),"forced move between two supported maps still cancels old seed menu")
 world.queue_free();await frames()
 print("ORCHARD UI OK" if failures==0 else "ORCHARD UI FAILED "+str(failures));quit(0 if failures==0 else 1)
