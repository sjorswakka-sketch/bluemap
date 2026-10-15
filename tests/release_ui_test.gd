extends SceneTree
var gs: Node
var world: Node2D
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 print("  ok   " if ok else "  FAIL ",label)
 if not ok:failures+=1
func frames(n:=6):
 for i in n:await process_frame
func visible_controls(node: Node,viewport: Rect2):
 if node is ScrollContainer:return
 for child in node.get_children():
  if child is Control and child.is_visible_in_tree() and (child is Button or child is Label or child is Slider):
   var area: Rect2=child.get_global_rect()
   check(viewport.encloses(area),"visible control fits "+str(root.size)+" "+child.name+" "+str(area))
  visible_controls(child,viewport)
func click_at(point: Vector2):
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.relative=Vector2(5,0);Input.parse_input_event(motion);await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await frames(3)
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(10)
 gs=root.get_node("GameState");gs.new_game()
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs.save_meta({"completed":true,"rounds":1,"weapon":"iron","hearts":0,"boots":false})
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for dimensions in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=dimensions;await frames(5)
   check(root.size==dimensions,"actual requested window size")
   var title: Control=load("res://scenes/title.tscn").instantiate();root.add_child(title);await frames()
   check(title.ng_button.visible,"completed player sees NG+ button")
   visible_controls(title,Rect2(Vector2.ZERO,Vector2(dimensions)))
   var controls:=root.get_node("Controls")
   var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_DPAD_DOWN;event.pressed=true;Input.parse_input_event(event);await frames(2)
   event.pressed=false;Input.parse_input_event(event);await frames(2)
   check(controls.controller_active and title.get_viewport().gui_get_focus_owner()!=null,"controller retains actual title focus")
   await click_at(title.controls_button.get_global_rect().get_center())
   check(gs.ui_owners.has("controls") and not controls.controller_active,"actual mouse opens scaled title button after controller input")
   var bindings: Node=title.get_children().back()
   if gs.ui_owners.has("controls"):
    visible_controls(bindings.controls_root,Rect2(Vector2.ZERO,Vector2(dimensions)))
    var last: Button=bindings.binding_buttons[controls.ACTION_NAMES.keys().back()];last.grab_focus();await frames(8)
    check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(last.get_global_rect()),"last remapping action scrolls into view")
    bindings._close();await frames()
   title.queue_free();await frames()
 gs.new_game();gs.in_game=true;gs.ng_plus=2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(10)
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for dimensions in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=dimensions;world.pause_menu.toggle();await frames(10)
   visible_controls(world.pause_menu.root,Rect2(Vector2.ZERO,Vector2(dimensions)))
   var paused_time: float=gs.play_time
   await frames(10);check(gs.play_time==paused_time,"resized pause really pauses world clock")
   world.pause_menu.toggle();await frames(3)
 root.get_node("Lang").set_language("nl",false)
 world.queue_free();await frames()
 print("RELEASE UI OK" if failures==0 else "RELEASE UI FAILED "+str(failures));quit(0 if failures==0 else 1)
