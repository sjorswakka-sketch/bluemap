extends "res://tests/homestead_test.gd"
const Feedback:=preload("res://scripts/core/garden_feedback.gd")
func field() -> Node2D:
 for n in get_nodes_in_group("homesteads"):
  if not n.is_queued_for_deletion():return n
 return null
func press_key(down: bool):
 var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=down;Input.parse_input_event(event);await frames(2)
func place(at: Vector2i):
 p.position=Vector2(at)*32+Vector2(16,48);p.facing=Vector2.UP;p._update_target();field().cooldown=0
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(15);p=world.player
 await enter("village");p.set_physics_process(false)
 check(not gs.flag("hs_garden_help"),"garden guide is opt-in")
 check(Feedback.guide_text().contains("gratis hak"),"help explains the free starter before asking for field work")
 place(Vector2i(16,33))
 check(not Farm.work_status(Vector2i(16,33),"soil",world).ok,"preview explains missing hoe without changing anything")
 gs.give("hs_hoe",1,true);gs.give("hs_seed",12,true);gs.give("hs_flower_seed",6,true);gs.give("hs_fertilizer",3,true)
 check(Farm.work_status(Vector2i(16,33),"soil",world).ok,"valid preview uses actual editable terrain")
 var before: Dictionary=gs.inventory.duplicate(true)
 check(not Farm.act(Vector2i(20,33),"soil",world) and not Farm.act(Vector2i(18,31),"channel",world) and gs.inventory==before,"water and bridge cannot be edited or consume supplies")
 await tool(Vector2i(16,33),"soil")
 check(Feedback.guide_step()==1,"optional guide recognises worked ground")
 await tool(Vector2i(16,33),"grape")
 check(Feedback.cell_text(Vector2i(16,33)).contains("Wacht op water"),"dry crop feedback explains safe waiting")
 Farm.advance(200);check(Farm.state().cells["16,33"].growth==0,"dry grapes never decay or advance")
 for at in [Vector2i(19,33),Vector2i(18,33),Vector2i(17,33)]:await tool(at,"channel")
 check(Farm.wet.size()==3 and Farm.flow[Vector2i(17,33)]==Vector2i(18,33),"connected water has a source-directed flow path")
 check(Feedback.guide_step()==3 and Feedback.cell_text(Vector2i(16,33)).contains("Groeit"),"guide and growth text follow the actual wet plant")
 for at in [Vector2i(17,34),Vector2i(18,34),Vector2i(19,34)]:await tool(at,"channel")
 await tool(Vector2i(19,33),"fill")
 check(Farm.watered(Vector2i(16,33)),"alternate source route keeps looped field irrigated")
 await tool(Vector2i(19,34),"fill")
 check(not Farm.watered(Vector2i(16,33)) and Feedback.cell_text(Vector2i(17,33)).contains("Droog kanaal"),"both severed sources dry a branch with clear feedback")
 await tool(Vector2i(19,34),"channel");Farm.advance(45)
 var growth: float=Farm.state().cells["16,33"].growth
 gs.set_ui("garden_probe",true);gs._process(70)
 check(Farm.state().cells["16,33"].growth==growth,"a menu pauses the real growth clock")
 gs.set_ui("garden_probe",false)
 await tool(Vector2i(16,33),"fertilize");Farm.advance(45)
 check(Feedback.cell_text(Vector2i(16,33)).contains("Rijp") and Feedback.cell_text(Vector2i(16,33)).contains("5 druiven"),"maturity and fertilized yield are visible before harvest")
 await tool(Vector2i(16,33),"harvest")
 check(gs.count("hs_grape")==5 and Feedback.guide_step()==4,"first harvest completes optional help and gives the actual improved yield")
 # Native held input bridges only short, reachable gaps along a row.
 p.position=Vector2(5.5,39.5)*32;p.facing=Vector2.RIGHT;p._update_target();Farm.mode="soil";field().cooldown=0
 await press_key(true)
 p.position=Vector2(7.5,39.5)*32;field().cooldown=0;field().work()
 check(["6,39","7,39","8,39"].all(func(id):return Farm.state().cells.has(id)),"short frame gaps prepare every reachable tile in a straight row")
 p.position=Vector2(14.5,39.5)*32;field().cooldown=0;field().work()
 check(not Farm.state().cells.has("10,39") and Farm.state().cells.has("15,39"),"a distant reposition never works an intervening row")
 await press_key(false)
 # Erasing is one deliberate tile per fresh press, even while walking with E held.
 p.position=Vector2(5.5,39.5)*32;p.facing=Vector2.RIGHT;Farm.mode="fill";field().cooldown=0
 await press_key(true);p.position=Vector2(6.5,39.5)*32;field().cooldown=0;field().work()
 check(not Farm.state().cells.has("6,39") and Farm.state().cells.has("7,39"),"holding restore cannot erase the next tile")
 await press_key(false);field().cooldown=0;await press_key(true);await press_key(false)
 check(not Farm.state().cells.has("7,39"),"a fresh restore press edits the next chosen tile")
 # Native controller focus navigates both columns and never edits on menu confirmation.
 place(Vector2i(10,36));Farm.mode="soil"
 await tap(KEY_U);await frames(3)
 check(ui()!=null and ui().tool_grid.columns==2,"real shortcut opens compact two-column palette")
 var at: Vector2=p.position
 await tap(JOY_BUTTON_DPAD_RIGHT,true)
 check(root.gui_get_focus_owner()==ui().buttons[1] and p.position==at,"controller right moves to channel without moving player")
 await tap(JOY_BUTTON_DPAD_DOWN,true)
 check(root.gui_get_focus_owner()==ui().buttons[3],"controller down follows the same column")
 await tap(JOY_BUTTON_A,true);await frames(25)
 check(ui()==null and Farm.mode=="flower" and not Farm.state().cells.has("10,36"),"confirm selects tool without leaking an edit into the field")
 # A held action is cancelled through a modal and an input-device handover.
 Farm.mode="soil";field().cooldown=0;place(Vector2i(10,36));Input.action_press("interact");await frames(3)
 gs.set_ui("garden_probe",true);await frames(3);place(Vector2i(11,36));gs.set_ui("garden_probe",false);field().cooldown=0;await frames(15)
 check(not Farm.state().cells.has("11,36"),"holding across a modal requires a fresh press")
 Input.action_release("interact");await frames(2);Input.action_press("interact");field().cooldown=0;await frames(2)
 place(Vector2i(12,36));field().device_changed(false);field().cooldown=0;await frames(12)
 check(not Farm.state().cells.has("12,36"),"device handover cancels held field work")
 Input.action_release("interact");await frames(3)
 # Existing station interaction takes precedence even while a garden mode is selected.
 var hive: Node2D=prop("hive");p.position=hive.position+Vector2(0,30);p._update_target()
 check(p.target==hive,"existing station stays the interaction target")
 await tap(KEY_E);check(ui()!=null and ui().source.get_ref()==hive,"interact opens nearby hive instead of working through it");await close_ui()
 # Quiet HUD and tutorial survive saves, and fit the actual small and large windows.
 gs.set_flag("hs_garden_help");place(Vector2i(16,33));Farm.mode="grape"
 gs.save_game(p.position);check(gs.load_game() and gs.flag("hs_garden_help") and gs.flag("hs_intro_harvest"),"help choice and completion survive real save/load")
 Farm.mode="grape"
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=size
   world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;await frames(6)
   var f:=field()
   check(f.panel.visible and Rect2(Vector2.ZERO,Vector2(size)).encloses(f.panel.get_global_rect()),"field status fits "+locale+str(size))
   var actor_screen: Vector2=p.get_global_transform_with_canvas().origin
   check(not f.panel.get_global_rect().intersects(Rect2(actor_screen-Vector2(40,40),Vector2(80,80))),"field feedback leaves the character clear "+locale+str(size))
   await tap(KEY_U);await frames(5)
   check(ui()!=null and Rect2(Vector2.ZERO,Vector2(size)).encloses(ui().panel.get_global_rect()) and ui().panel.scale.x>=.88,"readable palette fits "+locale+str(size))
   await close_ui()
 gs.set_flag("hs_garden_help",false);Farm.mode="";await frames(4)
 check(not field().panel.visible,"putting tools away restores a quiet field")
 world.queue_free();await frames(5);print("GARDEN PHASE1 OK" if failures==0 else "GARDEN PHASE1 FAILED "+str(failures));quit(0 if failures==0 else 1)
