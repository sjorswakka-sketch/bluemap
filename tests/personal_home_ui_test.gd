extends "res://tests/coast_expedition_test.gd"
const House:=preload("res://scripts/core/personal_home.gd")
func ui() -> Node:
 for n in get_nodes_in_group("house_ui"):
  if n.active and not n.is_queued_for_deletion():return n
 return null
func button_named(owner: Node,text: String) -> Button:
 for b in owner.find_children("*","Button",true,false):
  if b.text==text:return b
 return null
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.get_node("Lang").set_language("nl",false)
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("player_home");p.set_physics_process(false)
 var before: Dictionary=House.state().duplicate(true)
 await tap(KEY_U)
 check(ui()!=null and paused and gs.ui_owners.keys()==["personal_house"],"actual contextual U opens interior editor and pauses world")
 if ui()==null:quit(1);return
 var editor: Node=ui()
 await tap(JOY_BUTTON_RIGHT_SHOULDER,true)
 check(editor.plan.has_focus(),"controller shoulder selects actual floor plan")
 editor.cursor=Vector2i(4,9);await frames();await tap(JOY_BUTTON_A,true)
 check(editor.draft.layout.has("chair:1") and not House.state().layout.has("chair:1"),"native controller confirmation edits draft without spawning live prop")
 await tap(JOY_BUTTON_DPAD_RIGHT,true);await tap(JOY_BUTTON_A,true)
 check(editor.draft.layout["chair:1"].cell==[5,9],"D-pad moves existing chair footprint and A confirms")
 var axis:=InputEventJoypadMotion.new();axis.axis=JOY_AXIS_LEFT_X;axis.axis_value=-1;Input.parse_input_event(axis);await frames(32)
 axis.axis_value=0;Input.parse_input_event(axis);await frames()
 check(editor.cursor.x<5,"held controller stick repeats cursor movement")
 await tap(JOY_BUTTON_LEFT_SHOULDER,true);check(editor.list.has_focus(),"controller returns to catalog without being trapped in grid")
 await tap(JOY_BUTTON_B,true);check(ui()==null and House.state()==before and not gs.input_locked(),"cancel drops draft and leaves original room intact")
 await frames();await tap(KEY_U);editor=ui()
 editor.select_kind(editor.catalog_ids.find("plant_leaf"));editor.cursor=Vector2i(2,8);editor.refresh_detail()
 await click(editor.place_button)
 check(editor.draft.layout.has("plant_leaf:1") and not House.state().layout.has("plant_leaf:1"),"native mouse stages free starter plant")
 editor.tint.grab_focus();await tap(KEY_ENTER);await tap(KEY_DOWN);await tap(KEY_ENTER)
 check(editor.draft.layout["plant_leaf:1"].tint==1 and not House.state().layout.has("plant_leaf:1"),"native color choice recolors the draft without a second placement")
 editor.floors.grab_focus();await tap(KEY_ENTER);await tap(KEY_DOWN);await tap(KEY_ENTER)
 check(editor.draft.floor==1 and House.state().floor==0,"native popup previews chosen floor without committing")
 await click(button_named(editor,"Toepassen en opslaan"));await frames(5)
 check(ui()==null and House.state().floor==1 and House.state().layout.has("plant_leaf:1") and House.state().layout["plant_leaf:1"].tint==1 and not gs.input_locked(),"native Apply commits draft and releases modal owner")
 # Entry from the existing bed card also works for a controller without a garden binding.
 var bed: Node2D
 for n in get_nodes_in_group("home_stations"):
  if not n.is_queued_for_deletion() and n.obj.role=="bed":bed=n
 p.position=bed.position+Vector2(0,32);p.facing=Vector2.UP;p._update_target();await tap(JOY_BUTTON_A,true)
 var home: Node
 for n in get_nodes_in_group("home_ui"):
  if n.active and not n.is_queued_for_deletion():home=n
 check(home!=null,"controller interacts with real functional bed")
 if home!=null:
  button_named(home,"Je huis inrichten").grab_focus();await tap(JOY_BUTTON_A,true)
 check(ui()!=null and gs.ui_owners.keys()==["personal_house"],"bed card safely hands off to interior editor")
 if ui()!=null:
  editor=ui();editor.select_kind(editor.catalog_ids.find("plant_leaf"));editor.pack_button.grab_focus();await tap(JOY_BUTTON_A,true)
  check(not editor.draft.layout.has("plant_leaf:1") and House.state().owned.plant_leaf==1,"controller packing returns furniture to its separate stock without refund or destruction")
  button_named(editor,"Toepassen en opslaan").grab_focus();await tap(JOY_BUTTON_A,true);await frames()
  check(not House.state().layout.has("plant_leaf:1") and House.state().owned.plant_leaf==1,"applied packing removes real prop and retains ownership")
 await tap(KEY_U);editor=ui()
 await click(button_named(editor,"Beginindeling bekijken"))
 check(editor.draft.floor==0 and House.state().floor==1,"starter reset is a preview until Apply")
 await tap(KEY_ESCAPE);check(House.state().floor==1,"cancelled starter reset preserves actual decoration")
 await frames()
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size
   editor=load("res://scripts/ui/house_ui.gd").new();editor.world=world;world.add_child(editor);editor.open();editor.select_kind(editor.catalog_ids.find("trophy_swamp"));await frames(5)
   check(Rect2(Vector2.ZERO,Vector2(size)).encloses(editor.panel.get_global_rect()),"complete room editor fits "+locale+str(size))
   check(editor.panel.get_global_rect().encloses(editor.plan.get_global_rect()) and editor.panel.get_global_rect().encloses(editor.make_button.get_global_rect()),"plan and native controls stay inside panel "+locale+str(size))
   editor.close();await frames()
 root.get_node("Lang").set_language("nl",false);root.size=Vector2i(1152,648)
 await tap(KEY_U);editor=ui();world.load_map("village","from_home");await frames(8);p=world.player
 check(ui()==null and not gs.input_locked(),"forced area change drops uncommitted editor and releases input")
 world.queue_free();await frames();print("PERSONAL HOME UI OK" if failures==0 else "PERSONAL HOME UI FAILED "+str(failures));quit(0 if failures==0 else 1)
