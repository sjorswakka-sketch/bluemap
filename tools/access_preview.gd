extends SceneTree
const Access:=preload("res://scripts/core/access_points.gd")
var world: Node2D
var gs: Node
func _initialize():run.call_deferred()
func frames(n:=12):
 for i in n:await process_frame
 RenderingServer.force_draw(false)
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 for i in 10:await process_frame
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.5
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(20)
 var cases: Array=[{"id":"home","map":"village","to":"player_home"},{"id":"smithy","map":"village","to":"smithy"},{"id":"temple_locked","map":"village","to":"temple"},{"id":"closed_home","map":"village","to":""},{"id":"home_exit","map":"player_home","to":"village"},{"id":"forest_edge","map":"forest_edge","to":"forest"}]
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
   for c: Dictionary in cases:
    world.load_map(c.map,"start");var player: Node2D=world.player;player.set_physics_process(false);player.camera.position_smoothing_enabled=false
    for n in get_nodes_in_group("enemies"):n.set_process(false);n.set_physics_process(false)
    var rect:=Rect2(31*32,21*32,32,32)
    if c.to!="":
     for portal in get_nodes_in_group("access_portals"):
      if not portal.is_queued_for_deletion() and portal.target_map==c.to:rect=portal.rect;break
    var center:=rect.get_center();var chosen:=false
    for at in [Vector2(center.x,rect.end.y+16),Vector2(center.x-32,rect.end.y+40),Vector2(center.x+32,rect.end.y+40),Vector2(center.x,rect.position.y-28),Vector2(rect.position.x-28,center.y),Vector2(rect.end.x+28,center.y)]:
     if not world.spawn_fits(at):continue
     player.position=at;player.facing=(center-at).normalized();player._update_target();await frames(3)
     var hint:=Access.nearby(world)
     if not hint.is_empty() and hint.rect==rect:chosen=true;break
    if not chosen:push_error("No actual entry hint for "+c.id);quit(1);return
    player.camera.reset_smoothing();world.fader.set_alpha(0);world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;await frames(15)
    root.get_texture().get_image().save_png("res://access_"+c.id+"_"+locale+str(size.x)+".png")
 world.queue_free();world=null;await frames(10);print("ACCESS PREVIEW OK");quit()
