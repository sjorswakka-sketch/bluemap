extends SceneTree
const House:=preload("res://scripts/core/personal_home.gd")
var world: Node2D
var gs: Node
func _initialize():run.call_deferred()
func frames(n:=8):
 for i in n:await process_frame
 RenderingServer.force_draw(false)
func shot(id: String):root.get_texture().get_image().save_png("res://personal_house_"+id+".png")
func clean():
 world.fader.set_alpha(0);world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;world.hud.toast_panel.modulate.a=0;world.hud.banner.modulate.a=0
func enter():
 world.load_map("player_home","start",Vector2(6.5,10.5)*32);world.player.set_physics_process(false);world.player.camera.position=Vector2.ZERO;world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2(1.4,1.4)
 var view: Vector2=Vector2(root.size)/world.player.camera.zoom
 var pad: Vector2=(view-Vector2(world.map_size)*32).max(Vector2.ZERO)/2
 world.player.camera.limit_left=-int(pad.x);world.player.camera.limit_right=world.map_size.x*32+int(pad.x)
 world.player.camera.limit_top=-int(pad.y);world.player.camera.limit_bottom=world.map_size.y*32+int(pad.y)
 await frames(15);clean();await frames()
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1152,648)
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(20)
 await enter();shot("starter")
 var draft: Dictionary=House.state().duplicate(true)
 draft.layout.bed.cell=[2,2];draft.layout.table.cell=[4,9];draft.layout["rug:1"].cell=[3,6]
 draft.layout=House.candidate(draft.layout,"chair:1","chair",Vector2i(4,10),1)
 draft.layout=House.candidate(draft.layout,"plant_leaf:1","plant_leaf",Vector2i(2,8),0)
 draft.layout=House.candidate(draft.layout,"lamp:1","lamp",Vector2i(10,9),2)
 for style in range(4):
  draft.floor=style;draft.wall=style;draft.light=style%3
  if not House.apply(draft,world):push_error("FAIL preview house layout");quit(1);return
  await frames(15);clean();await frames();shot("room_"+str(style))
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;await frames()
   var ui: CanvasLayer=load("res://scripts/ui/house_ui.gd").new();ui.world=world;world.add_child(ui);ui.open();await frames(12);shot("editor_"+locale+str(size.x))
   ui.select_kind(ui.catalog_ids.find("shelf"));ui.cursor=Vector2i(6,9);ui.refresh_detail();ui.plan.grab_focus();await frames(8);shot("blocked_"+locale+str(size.x))
   ui.select_kind(ui.catalog_ids.find("trophy_swamp"));await frames(8);shot("memory_"+locale+str(size.x));ui.close();await frames()
 world.queue_free();world=null;await frames(10);print("PERSONAL HOUSE PREVIEW OK");quit()
