extends SceneTree
const Farm:=preload("res://scripts/core/homestead.gd")
var world: Node2D
var gs: Node
func _initialize():run.call_deferred()
func frames(n:=12):
 for i in n:await process_frame
 RenderingServer.force_draw(false)
func shot(id: String):root.get_texture().get_image().save_png("res://home_"+id+".png")
func view(map: String,at: Vector2,zoom:=2.0):
 world.load_map(map,"start",at*32);world.player.set_physics_process(false);world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE*zoom
 for n in get_nodes_in_group("enemies"):n.set_physics_process(false)
 world.fader.set_alpha(0);await frames(15);world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.toast_panel.modulate.a=0;world.hud.banner_time=0;world.hud.banner.modulate.a=0;await frames(3)
func station(role: String) -> Node2D:
 for n in get_nodes_in_group("home_stations"):
  if not n.is_queued_for_deletion() and n.obj.role==role:return n
 return null
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 for i in 10:await process_frame
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.5
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(20)
 await view("village",Vector2(8,20),1);shot("home_exterior")
 await view("village",Vector2(20,32),.7);shot("garden_before")
 await view("player_home",Vector2(7,7),2);shot("interior")
 await view("village",Vector2(36,24));shot("brook_pool")
 await view("forest_edge",Vector2(30.5,20));shot("forest_fall")
 await view("forest_edge",Vector2(16.5,7));shot("forest_spring")
 await view("forest",Vector2(7.5,7.5));shot("wild_grapes")
 for x in range(5,20):Farm.state().cells[Farm.key(Vector2i(x,33))]={"kind":"channel"}
 for y in [32,34]:
  for x in range(5,18):
   if Vector2i(x,y)==Vector2i(15,32):continue
   Farm.state().cells[Farm.key(Vector2i(x,y))]={"kind":"soil","crop":"flower" if x in [14,15,16] else "grape","growth":90.0 if y==32 else 45.0,"fertilized":x%3==0}
 Farm.dirty=true
 await view("village",Vector2(12,34),1);Farm.mode="harvest";await frames();shot("garden_irrigated")
 gs.day_time=.9;await view("village",Vector2(12,34),1);shot("garden_night");gs.day_time=.5
 gs.give("hs_hoe",1,true);gs.give("hs_seed",8,true);gs.give("hs_fertilizer",4,true)
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;await view("village",Vector2(7,24))
   for role in ["tools","guide","compost","wine","hive"]:
    var n:=station(role) if role!="tools" else null
    if n!=null:world.player.position=n.position+Vector2(0,30)
    var ui: CanvasLayer=load("res://scripts/ui/home_ui.gd").new();ui.world=world;world.add_child(ui);ui.open(n);await frames(15);shot(role+"_"+locale+str(size.x));ui.close();await frames(3)
   world.crafting_ui.open();await frames(15);shot("crafting_"+locale+str(size.x));world.crafting_ui.close();await frames(3)
 world.queue_free();world=null;await frames(10);print("HOMESTEAD PREVIEW OK");quit()
