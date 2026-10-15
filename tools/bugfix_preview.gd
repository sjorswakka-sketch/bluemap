extends SceneTree
var world: Node2D
var gs: Node
func _initialize():run.call_deferred()
func frames(n:=10):
	for i in n:await process_frame
	RenderingServer.force_draw(false)
func shot(id: String):root.get_texture().get_image().save_png("res://bugfix_"+id+".png")
func clean():
	world.fader.set_alpha(0);world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;world.hud.toast_panel.modulate.a=0;world.hud.banner.modulate.a=0
func enter(id: String,position: Vector2,zoom:=1.5):
	world.load_map(id,"start",position*32);world.player.set_physics_process(false);world.player.camera.position=Vector2.ZERO;world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE*zoom
	for n in get_nodes_in_group("enemies"):n.set_process(false);n.set_physics_process(false)
	await frames(15);clean();await frames(3)
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1152,648)
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(20)
	for state in ["high","west_open","both_open","drained","bridge"]:
		gs.flags["lw_sluice_west"]=state!="high";gs.flags["lw_sluice_east"]=state=="both_open";gs.flags["lw_drained"]=state in ["drained","bridge"];gs.flags["lw_bridge"]=state=="bridge"
		await enter("kruipmoeras",Vector2(25,16));world.player.position=Vector2(15.5,18.5)*32;world.player.camera.position=Vector2(9.5,-2.5)*32;await frames(12);clean();shot("swamp_"+state)
		if state=="bridge":
			for sluice in [Vector2(17.5,11.5),Vector2(35.5,18.5)]:
				world.player.position=sluice*32+Vector2(0,52);world.player.facing=Vector2.UP;world.player._update_target();world.player.camera.zoom=Vector2(2,2);await frames(12);shot("sluice_"+str(sluice.x))
	for locale in ["nl","en"]:
		root.get_node("Lang").set_language(locale,false)
		for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
			root.size=size;await enter("village",Vector2(19.5,40.5),2)
			world.player.facing=Vector2.DOWN;world.player.target=null;clean();world.hud.item_receipts.entries.clear();world.hud.item_receipts.rebuild()
			for id in ["potion","hs_grape","hs_fertilizer","hs_seed"]:gs.give(id,3)
			world.hud._queue_toast("System notice");await frames(8);world.player.target=null;world.hud._refresh_access();shot("receipts_"+locale+str(size.x))
			world.hud.item_receipts.entries.clear();world.hud.item_receipts.rebuild()
	root.size=Vector2i(1152,648);await enter("village",Vector2(19,34),1);shot("south_route")
	world.queue_free();world=null;await frames(10);print("BUGFIX PREVIEW OK");quit()
