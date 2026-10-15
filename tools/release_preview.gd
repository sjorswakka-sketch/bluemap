extends SceneTree
## Deterministic visual samples. Run through audit_adventure.py --preview.
var gs: Node
var world: Node2D
func _initialize():run.call_deferred()
func frames(n:=10):
 for i in n:await process_frame
 RenderingServer.force_draw(false)
func shot(label: String):
 root.get_texture().get_image().save_png("res://release_"+label+".png")
func view(id: String,at: Vector2):
 world.load_map(id,"start",at*32);world.player.set_physics_process(false);world.player.camera.position_smoothing_enabled=false
 for enemy in get_nodes_in_group("enemies"):enemy.set_physics_process(false)
 world.fader.set_alpha(0);await frames(15)
 world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;world.hud.banner.modulate.a=0;world.hud.toast_panel.modulate.a=0
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(10)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
 RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.set_process(false)
 gs.save_meta({"completed":true,"rounds":1,"weapon":"iron","hearts":0,"boots":false})
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;await frames(5)
   var title: Control=load("res://scenes/title.tscn").instantiate();root.add_child(title);title.t=2;await frames(12);title.set_process(false)
   shot("title_"+locale+str(size.x));title._open_controls();await frames(15);shot("controls_"+locale+str(size.x))
   title.queue_free();await frames(5)
  for size in [Vector2i(960,540),Vector2i(1600,900)]:
   root.size=size;await frames(5)
   var intro: Control=load("res://scenes/intro.tscn").instantiate();root.add_child(intro);intro.typed=9999;await frames(12);intro.set_process(false);shot("intro_"+locale+str(size.x));intro.queue_free();await frames(5)
   var ending: Control=load("res://scenes/ending.tscn").instantiate();root.add_child(ending);ending.page=7;ending.t=10;await frames(12);ending.set_process(false);shot("ending_stats_"+locale+str(size.x));ending.queue_free();await frames(5)
 gs.new_game();gs.in_game=true;gs.ng_plus=2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(20)
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;world.pause_menu.toggle();await frames(15);shot("pause_"+locale+str(size.x));world.pause_menu.toggle();await frames(4)
 root.size=Vector2i(1152,648);root.get_node("Lang").set_language("nl",false);gs.ng_plus=0
 for time in [.5,.9]:
  gs.day_time=time;gs.day_count=3
  for spec in [["village",Vector2(22.5,13.5)],["forest_edge",Vector2(14.5,10.5)],["river_mouth",Vector2(31.5,9.5)],["harbor",Vector2(53.5,24.5)],["headland",Vector2(58.5,13.5)],["coast_workshop",Vector2(15,11)]]:
   await view(spec[0],spec[1]);shot(spec[0]+str(time))
 gs.set_flag("ad_pilot_done");gs.set_flag("ad_message_done");gs.set_flag("ad_wheel_done");gs.set_flag("ad_keeper_done");gs.set_flag("ad_pool");gs.day_time=.5
 for spec in [["headland",Vector2(47.5,35.5)],["harbor",Vector2(51.5,32.5)],["tidal_hollow",Vector2(30,15)]]:
  await view(spec[0],spec[1]);shot("outcome_"+spec[0])
 await view("tide_cove",Vector2(18.5,25.5));gs.day_time=70.0/480.0
 var station: Node2D
 for n in get_nodes_in_group("tide_stations"):
  if not n.is_queued_for_deletion() and n.obj.role=="gauge":station=n
 world.player.position=station.position+Vector2(0,30);station.interact();await frames(15);shot("high_tide_routes")
 world.queue_free();world=null;await frames(8)
 print("RELEASE PREVIEW OK");quit()
