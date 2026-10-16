extends SceneTree
var world: Node2D
var gs: Node
const Stock:=preload("res://scripts/core/stockroom.gd")
func _initialize():run.call_deferred()
func frames(n:=8):
 for i in n:await process_frame
 RenderingServer.force_draw(false)
func shot(id: String):root.get_texture().get_image().save_png("res://storage_"+id+".png")
func clean():
 world.fader.set_alpha(0);world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;world.hud.toast_panel.modulate.a=0;world.hud.banner.modulate.a=0
func enter(id: String,at: Vector2,zoom:=2.0):
 world.load_map(id,"start",at*32);world.player.set_physics_process(false);world.player.camera.position=Vector2.ZERO;world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE*zoom
 for n in get_nodes_in_group("enemies"):n.set_process(false);n.set_physics_process(false)
 await frames(15);clean();await frames(3)
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1152,648)
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(20)
 for id in ["hs_grape","hs_seed","hs_fertilizer","hs_honey","prof_branch","prof_stone","prof_copper_ore","prof_log","prof_herb","potion","prof_axe","cw_seaglass"]:gs.give(id,24 if id!="prof_axe" else 1,true)
 Stock.state().home={"hs_grape":72,"hs_seed":38,"hs_fertilizer":30,"hs_honey":6,"prof_branch":98,"prof_stone":54,"cw_seaglass":8,"prof_log":16,"prof_herb":29}
 Stock.state().favorites={"hs_grape":true,"potion":true}
 await enter("village",Vector2(9.5,27.5));shot("yard")
 await enter("player_home",Vector2(10.5,6.5));shot("indoor")
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;await enter("player_home",Vector2(10.5,6.5))
   var ui: CanvasLayer=load("res://scripts/ui/stock_ui.gd").new();ui.world=world;world.add_child(ui);ui.open()
   ui.select_item(ui.bag_ids.find("hs_grape"),true);await frames(12);shot("ledger_"+locale+str(size.x))
   ui.select_item(ui.bag_ids.find("prof_axe"),true);await frames(5);shot("tool_"+locale+str(size.x))
   ui.toggle_keyboard();await frames(8);shot("letters_"+locale+str(size.x));ui.close();await frames(4)
   await enter("forest",Vector2(15,12))
   ui=load("res://scripts/ui/stock_ui.gd").new();ui.world=world;world.add_child(ui);ui.open();ui.select_item(ui.chest_ids.find("hs_seed"),false);await frames(8);shot("remote_"+locale+str(size.x));ui.close();await frames(4)
 root.size=Vector2i(1152,648);root.get_node("Lang").set_language("nl",false)
 await enter("village",Vector2(4.5,26.2))
 var ui: CanvasLayer=load("res://scripts/ui/home_ui.gd").new();ui.world=world;world.add_child(ui)
 for n in get_nodes_in_group("home_stations"):
  if not n.is_queued_for_deletion() and n.obj.get("unit","")=="wine_a":ui.open(n)
 await frames(10);shot("wine");ui.close();await frames()
 await enter("player_home",Vector2(10.5,6.5));world.menu_ui.open(0);await frames(15);shot("bag");world.menu_ui.close()
 world.queue_free();world=null;await frames(10);print("STORAGE PREVIEW OK");quit()
