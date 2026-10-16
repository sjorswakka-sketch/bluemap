extends SceneTree
const Yard:=preload("res://scripts/core/yard.gd")
const Farm:=preload("res://scripts/core/homestead.gd")
var world: Node2D
var gs: Node
func _initialize():run.call_deferred()
func frames(n:=8):
 for i in n:await process_frame;await physics_frame
 RenderingServer.force_draw(false)
func shot(id: String):root.get_texture().get_image().save_png("res://yard_"+id+".png")
func clean():
 world.fader.set_alpha(0);world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;world.hud.toast_panel.modulate.a=0;world.hud.banner.modulate.a=0
func camera(at: Vector2,zoom: float):
 world.player.position=at*32;world.player.camera.position=Vector2.ZERO;world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE*zoom
 await frames(15);clean();await frames()
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1152,648)
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(20)
 world.load_map("village","from_home");world.player.set_physics_process(false);await frames(15)
 await camera(Vector2(19.5,29.5),.85);shot("original_overview")
 gs.yard.extensions=["west","east"];gs.yard.owned.boards=8;gs.yard.owned.stone=8
 var draft: Dictionary=Yard.state().duplicate(true);draft.stations.wine_a=[5,27];draft.stations.hive=[28,34]
 for x in range(9,17):draft.paths[str(x)+",27"]="gravel"
 for y in range(31,37):draft.paths["10,"+str(y)]="stone"
 for x in range(25,31):draft.paths[str(x)+",39"]="boards"
 for x in range(5,10):draft.fences[str(x)+",36"]="fence_h"
 draft.fences["7,36"]="gate_h"
 for y in range(33,36):draft.fences["5,"+str(y)]="fence_v"
 draft.fences["5,34"]="gate_v"
 for at in [Vector2i(27,36),Vector2i(28,36),Vector2i(29,36)]:gs.homestead.cells[Yard.key(at)]={"kind":"soil","crop":"flower","growth":60.0}
 for at in [Vector2i(7,34),Vector2i(8,34),Vector2i(7,35),Vector2i(8,35)]:gs.homestead.cells[Yard.key(at)]={"kind":"soil","crop":"grape","growth":90.0,"fertilized":false}
 for y in range(32,36):gs.homestead.cells["19,"+str(y)]={"kind":"channel"}
 Farm.dirty=true
 var reason:=Yard.layout_reason(draft,gs.homestead.cells)
 if reason!="" or not Yard.apply(draft,world):push_error("FAIL preview layout: "+reason);quit(1);return
 await camera(Vector2(19.5,29.5),.85);shot("expanded_overview")
 await camera(Vector2(7.5,28.0),1.5);shot("front_yard")
 await camera(Vector2(8.5,35.0),1.8);shot("west_gate_closed")
 await camera(Vector2(7.5,36.2),1.8);shot("west_gate_open")
 await camera(Vector2(28.5,35.5),1.6);shot("riverside_hive")
 world.player.position=Vector2(7.5,24.5)*32
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;await frames()
   var ui: Node=load("res://scripts/ui/yard_ui.gd").new();ui.world=world;world.add_child(ui);ui.open();await frames(12)
   ui.choose(ui.ids.find("stone"));ui.cursor=Vector2i(11,34);ui.refresh_detail();ui.plan.grab_focus();await frames(5);shot("editor_"+locale+str(size.x))
   ui.choose(ui.ids.find("hive"));ui.cursor=Vector2i(20,34);ui.refresh_detail();await frames(5);shot("blocked_"+locale+str(size.x))
   ui.choose(ui.ids.find("compost"));await frames(5);shot("rear_"+locale+str(size.x))
   ui.close();await frames()
 world.queue_free();world=null;await frames(10);print("YARD PREVIEW OK");quit()
