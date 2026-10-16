extends "res://tests/coast_expedition_test.gd"
const Yard:=preload("res://scripts/core/yard.gd")
const Farm:=preload("res://scripts/core/homestead.gd")
func editor() -> Node:
 var ui: Node=load("res://scripts/ui/yard_ui.gd").new();ui.world=world;world.add_child(ui);ui.open();await frames(5);return ui
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 root.get_node("Lang").set_language("nl",false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("village");p.position=Vector2(7.5,24.5)*32;p.set_physics_process(false)
 await tap(KEY_U)
 var guide: Node
 for n in get_nodes_in_group("home_ui"):
  if n.active:guide=n
 check(guide!=null,"actual U opens existing garden tools")
 if guide!=null:
  var entry: Button
  for b in guide.buttons:
   if b.text=="Erf inrichten":entry=b
  check(entry!=null,"yard editor is discoverable from existing tools")
  if entry!=null:await click(entry)
 var ui: Node
 for n in get_nodes_in_group("yard_ui"):
  if n.active:ui=n
 check(ui!=null,"native tools button opens yard plan")
 if ui==null:quit(1);return

 check(ui.active and gs.ui_owners.has("yard"),"native yard editor safely pauses gameplay")
 for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
  root.size=size;await frames(5)
  var rect:=Rect2(ui.panel.position,ui.panel.size*ui.panel.scale)
  check(Rect2(Vector2.ZERO,Vector2(size)).encloses(rect),"all yard controls fit "+str(size))
 root.size=Vector2i(1152,648);await frames()
 ui.choose(ui.ids.find("gravel"));ui.cursor=Vector2i(10,27);ui.refresh_detail()
 check(ui.reason_text=="","native editor indicates valid clear path")
 await click(ui.place_button)
 check(ui.draft.paths.has("10,27") and Yard.state().paths.is_empty(),"mouse placement changes draft only")
 ui.row_mode.button_pressed=true;ui.start=Vector2i(10,27);ui.cursor=Vector2i(13,27);ui.refresh_detail()
 check(ui.reason_text=="","straight row is valid across free front yard")
 ui.place();check(ui.draft.paths.size()==4,"whole row adds four connected cells")
 ui.cursor=Vector2i(13,28);ui.start=Vector2i(10,27);ui.refresh_detail()
 var before: Dictionary=ui.draft.duplicate(true);ui.place()
 check(ui.reason_text!="" and ui.draft==before,"diagonal row rejected without partial construction")
 await tap(JOY_BUTTON_RIGHT_SHOULDER,true)
 check(ui.plan.has_focus(),"controller right shoulder focuses plan")
 var at: Vector2i=ui.cursor;await tap(JOY_BUTTON_DPAD_LEFT,true)
 check(ui.cursor==at+Vector2i.LEFT,"controller dpad moves build cursor")
 await tap(JOY_BUTTON_LEFT_SHOULDER,true)
 check(ui.list.has_focus(),"controller left shoulder returns to parts list")
 await tap(JOY_BUTTON_B,true);await frames()
 check(not gs.ui_owners.has("yard") and Yard.state().paths.is_empty(),"controller cancel discards all draft placement")
 ui=await editor();ui.choose(ui.ids.find("gravel"));ui.cursor=Vector2i(10,27);ui.refresh_detail();ui.place();ui.apply();await frames()
 check(Yard.state().paths.has("10,27") and not gs.ui_owners.has("yard"),"apply saves draft and releases gameplay")
 # A horizontal and vertical gate use real collision and actual player movement.
 gs.yard=Yard.defaults();gs.yard.fences={"7,26":"gate_h","10,26":"gate_v"};Yard.sync(world)
 p.set_physics_process(true);p.position=Vector2(7.5,24.8)*32;await frames(20)
 await walk_to(Vector2(7.5,27.2)*32,200)
 var gate: Node
 for n in get_nodes_in_group("yard_fences"):
  if n.cell==Vector2i(7,26):gate=n
 check(gate!=null and gate.opened and gate.shape.disabled,"near gate automatically opens actual collider")
 await walk_to(Vector2(7.5,24.8)*32,200)
 p.position=Vector2(9.0,26.2)*32;await frames(10)
 await walk_to(Vector2(11.3,26.2)*32,200)
 p.position=Vector2(7.5,24.5)*32;await frames(30)
 for n in get_nodes_in_group("yard_fences"):check(not n.opened and not n.shape.disabled,"departed gate closes outside hysteresis range")
 # The editor is invalidated by a real map change.
 p.set_physics_process(false);ui=await editor();world.load_map("player_home","from_village");await frames(8)
 check(not gs.ui_owners.has("yard") and not gs.input_locked(),"forced departure releases paused editor")
 world.queue_free();await frames()
 print("YARD UI OK" if failures==0 else "YARD UI FAILED "+str(failures));quit(0 if failures==0 else 1)
