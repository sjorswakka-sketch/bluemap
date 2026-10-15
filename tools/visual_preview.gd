extends SceneTree
const Maps:=preload("res://scripts/maps/registry.gd")
var world: Node2D
var gs: Node
var report: Dictionary={}
func _initialize():run.call_deferred()
func frames(n:=8):
	for i in n:await process_frame
	RenderingServer.force_draw(false)
func shot(id: String):root.get_texture().get_image().save_png("res://visual_"+id+".png")
func enter(id: String,at:=Vector2.INF,zoom:=2.0,night:=false):
	gs.day_count=0;gs.day_time=.85 if night else .2
	world.load_map(id,"start",at*32 if at!=Vector2.INF else Vector2.INF)
	world.player.set_physics_process(false);world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE*zoom
	for n in get_nodes_in_group("enemies"):n.set_physics_process(false);n.set_process(false)
	world.player._update_target();world.fader.set_alpha(0);await frames(15)
	world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;world.hud.toast_panel.modulate.a=0;world.hud.banner.modulate.a=0;world.hud.opening_hint.hide()
	await frames(5)
func profile(label: String):
	var samples: Array[float]=[]
	for i in 90:
		var start:=Time.get_ticks_usec();await frames(1);samples.append((Time.get_ticks_usec()-start)/1000.0)
	samples.sort();report[label]={"median_wall_ms":samples[45],"p95_wall_ms":samples[85],"frames":90}
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1152,648)
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(20)
	for id: String in Maps.MAPS:
		await enter(id,Vector2.INF,1.0);shot(id+"_wide")
		await enter(id);shot(id+"_near")
	for spec in [["plaza","village",Vector2(20,14)],["smith","village",Vector2(10,10)],["home","village",Vector2(8,20)],["garden","village",Vector2(15,35)],["woods","forest",Vector2(12,12)],["river","village",Vector2(20,31)]]:
		for size in [Vector2i(960,540),Vector2i(1600,900)]:
			root.size=size;await enter(spec[1],spec[2]);shot(spec[0]+str(size.x))
	root.size=Vector2i(1152,648)
	for spec in [["plaza","village",Vector2(20,14)],["home","village",Vector2(8,20)],["river","village",Vector2(20,31)],["forest","forest",Vector2(12,12)]]:
		await enter(spec[1],spec[2],2,true);shot(spec[0]+"_night")
	for id in ["village","forest","coast","cave"]:
		await enter(id);await profile(id);shot(id+"_animation_a");await frames(24);shot(id+"_animation_b")
	report["note"]="Native Windows OpenGL, same camera and 90 forced draws per scene; wall times are diagnostics including event-loop waits, not an FPS guarantee."
	var out:=FileAccess.open("res://visual_profile.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	world.queue_free();world=null;await frames(10);print("VISUAL PREVIEW OK");quit()
