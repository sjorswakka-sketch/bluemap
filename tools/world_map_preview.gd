extends SceneTree
## Run only in the verified UUID project made by run_tests.py; screenshots contain no real save data.
## --state=fresh|sparse|legacy|all --lang=nl|en --view=960x540|1152x648 --output=absolute.png --controller
const Atlas:=preload("res://scripts/core/world_atlas.gd")
func _initialize() -> void:
	_preview.call_deferred()

func _preview() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):
		push_error("Atlas preview requires a verified disposable project.");quit(1);return
	var options: Dictionary={"state":"sparse","lang":"nl","view":"1152x648","output":"user://atlas-preview.png"}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and "=" in argument:
			var pair:=argument.trim_prefix("--").split("=",true,1);options[pair[0]]=pair[1]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	TranslationServer.set_locale(options.lang)
	var dimensions: PackedStringArray=options.view.split("x")
	root.size=Vector2i(int(dimensions[0]),int(dimensions[1]))
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var gs: Node=root.get_node("GameState");gs.new_game();gs.in_game=true
	var world: Node2D=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world
	for i in 6:await process_frame
	match str(options.state):
		"all":
			for id: String in Atlas.Maps.MAPS:gs.record_map_visit(id)
			world.load_map("player_home","start")
		"legacy":
			gs.visited_maps=Atlas.restore_visits({"map":"library","flags":{"golem_cave":true,"altaar_ijsdal_25_12":true,"wm_met_hearth":true},"talked":["meer_lena"]})
			world.load_map("library","start")
		"sparse":
			for id: String in ["forest_edge","forest","lake","smithy","player_home"]:gs.record_map_visit(id)
			world.load_map("player_home","start")
	for i in 6:await process_frame
	var menu: Node=world.menu_ui
	menu.open(menu.TAB_MAP);menu._toggle_atlas()
	if "--controller" in OS.get_cmdline_user_args():
		root.get_node("Controls").controller_active=true
		menu.atlas_page.confirm()
		if menu.atlas_page.selected_region=="village":
			for i in 9:menu.atlas_page.navigate("ui_down")
	for i in 24:await process_frame
	RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image()
	var error:=image.save_png(str(options.output))
	print("ATLAS_PREVIEW="+str(options.output)+" result="+str(error))
	quit(0 if error==OK else 1)
