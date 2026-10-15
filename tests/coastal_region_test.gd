extends "res://tests/coast_expedition_test.gd"
const Region:=preload("res://scripts/core/coastal_region.gd")
func atlas() -> Node:
	for ui in get_nodes_in_group("coast_atlas"):
		if not ui.is_queued_for_deletion():return ui
	return null
func routes() -> Node:
	for ui in get_nodes_in_group("coast_routes"):
		if not ui.is_queued_for_deletion():return ui
	return null
func resident(id: String) -> Node:
	for npc in get_nodes_in_group("npc"):
		if not npc.is_queued_for_deletion() and npc.npc_id==id:return npc
	return null
func safe_route(goal: Vector2i) -> int:
	var grid:=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,world.map_size);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	for cell in world.solid_cells:grid.set_point_solid(cell)
	for body in world.entities.get_children():
		if body!=p and body is PhysicsBody2D and not body.is_queued_for_deletion() and body.collision_layer&1:grid.set_point_solid(Vector2i(body.position/32))
	var path:=grid.get_id_path(Vector2i(p.position/32),goal)
	check(not path.is_empty(),"physical route connects to "+str(goal))
	var steps:=0
	for cell in path:steps+=await walk_to(Vector2(cell)*32+Vector2(16,16))
	return steps
func cross(from: String,at: Vector2,to: String,action: String):
	var old: String=gs.map_id;p.position=at*32;await frames(4);Input.action_press(action)
	for i in 100:
		await physics_frame
		if gs.map_id==to:break
	release();await frames(40)
	check(old==from and gs.map_id==to and world.spawn_fits(p.position),"real transition "+from+" -> "+to)
func interact_resident(id: String,pad:=false):
	p.position=resident(id).position+Vector2(0,32);await frames(5);await tap(JOY_BUTTON_A if pad else KEY_E,pad)
	check(world.dialogue.active,"native interaction opens "+id)
	for i in 5:
		if world.dialogue.buttons.is_empty():world.dialogue._advance();await frames(2)
	check(world.dialogue.buttons.size()==2,"resident offers useful service and quiet departure")
	world.dialogue.buttons[0].grab_focus();await tap(JOY_BUTTON_A if pad else KEY_ENTER,pad);await frames(3)
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true
	check(Region.IDS.size()==6,"coast region now has six connected places")
	for id in ["coast","gull_island","tide_cove"]:
		var before: Dictionary=Maps.MAPS[id].DATA.duplicate(true);load("res://scripts/data/coast_maps.gd").enrich(id,before)
		var after:=Maps.get_map(id)
		for i in before.objects.size():
			var a: Dictionary=before.objects[i];var b: Dictionary=after.objects[i]
			if a.type=="tide_station" and a.get("role","")=="routes":check(a.pos==b.pos and b.routes.slice(0,a.routes.size())==a.routes,"existing board retains position and all previous destinations")
			else:check(a==b,"existing coastal object/save slot retained "+id+str(i))
		for y in before.rows.size():
			for x in before.rows[y].length():
				if before.rows[y][x]!=after.rows[y][x]:check(id=="coast" and x in [14,15] and y<18,"only optional northern coast connection terrain changes")
	check(Region.walk_path("coast","headland")==["coast","river_mouth","harbor","headland"],"permanent high land route connects river, haven and cape")
	check(Region.walk_path("gull_island","tide_cove")==["gull_island","tide_cove"] and Region.walk_path("gull_island","headland").is_empty(),"atlas distinguishes island walking from required ferry")
	check(Journey.path("coast","harbor")==["coast","harbor"] and Journey.path("headland","village")==["headland","harbor","coast","lake","village"],"ferry shortcut and full home route are real graph links")
	for id in ["river_mouth","harbor","headland"]:
		var data:=Maps.get_map(id);var floor:=0
		for row: String in data.rows:
			for x in row.length():
				if not Tiles.is_solid_name(Tiles.name_for(row[x],x,0)):floor+=1
		print("REGION FLOOR ",id,"=",floor)
		check(floor>1400 and data.objects.filter(func(o: Dictionary)->bool:return o.type in ["enemy","pickup","chest"]).is_empty(),"new landscape has breathing space without reward or enemy density: "+id)
	check(Maps.get_map("harbor").objects.filter(func(o: Dictionary)->bool:return o.type=="npc").size()==2,"working quay has exactly two residents")
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
	var hp: int=gs.hp;var inventory: Dictionary=gs.inventory.duplicate(true);var coins: int=gs.coins;var xp: int=gs.hero_xp
	await enter("coast","from_estuary");await cross("coast",Vector2(14.5,3.5),"river_mouth","move_up")
	await safe_route(Vector2i(13,42))
	await tap(KEY_E);check(world.dialogue.active,"riverside return sign is supported and actually readable from dry floor");world.dialogue._close()
	await safe_route(Vector2i(14,42))
	var river_steps:=await safe_route(Vector2i(72,18))
	check(gs.hp==hp,"real estuary walk is peaceful without extra invulnerability")
	await cross("river_mouth",Vector2(72.5,18.5),"harbor","move_right")
	var harbor_steps:=await safe_route(Vector2i(40,28))
	check(gs.hp==hp and get_nodes_in_group("npc").size()==2,"quiet approach reaches only the small working quay")
	await interact_resident("rg_ise",true)
	check(routes().active and not world.dialogue.active and not atlas().active,"ferry resident opens working destination selector after releasing dialogue")
	for size in [Vector2i(960,540),Vector2i(1600,900)]:
		root.size=size;await frames(3);routes().layout();check(Rect2(Vector2.ZERO,Vector2(size)).encloses(routes().panel.get_global_rect()),"expanded ferry menu fits "+str(size))
	await tap(JOY_BUTTON_B,true)
	await interact_resident("rg_raf")
	check(atlas().active and not world.dialogue.active,"net maker opens a useful regional map without a collect quest")
	var ui:=atlas()
	for locale in ["nl","en"]:
		root.get_node("Lang").set_language(locale,false)
		for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
			root.size=size
			for id: String in Region.IDS:
				ui.select(id);await frames(2);ui.layout()
				check(Rect2(Vector2.ZERO,Vector2(size)).encloses(ui.panel.get_global_rect()),"region overview and explanation fit "+locale+str(size)+id)
	root.size=Vector2i(1152,648);root.get_node("Lang").set_language("nl",false);await frames(5);ui.layout()
	ui.select("coast");check(ui.detail.text.contains("Korter met de veer") and ui.detail.text.contains("Te voet"),"atlas explains both land route and selected ferry shortcut")
	await click(ui.buttons[3]);check(ui.selected=="headland" and gs.map_id=="harbor","native map click only selects destination information")
	await tap(JOY_BUTTON_A,true);ui.device_changed(true);check(ui.back.mouse_filter==Control.MOUSE_FILTER_IGNORE,"atlas obeys exclusive controller navigation")
	await tap(JOY_BUTTON_B,true);check(not gs.input_locked(),"controller closes atlas cleanly")
	var cape_approach:=await safe_route(Vector2i(70,14));await cross("harbor",Vector2(70.5,14.5),"headland","move_right")
	var cape_steps:=await safe_route(Vector2i(54,20))
	var tower: Node2D
	for n in get_nodes_in_group("region_landmarks"):
		if not n.is_queued_for_deletion() and n.obj.frame==0:tower=n
	check(tower!=null and tower.cells.size==Vector2i(3,2) and world.is_solid(tower.position),"lighthouse has actual footprint and collision")
	p.position=tower.position+Vector2(0,32);await frames(5);await tap(KEY_E);check(world.dialogue.active,"lighthouse is working scenery, no false repair objective");world.dialogue._close()
	gs.day_time=.85;await frames(5);check(tower.lamp.energy>0,"lighthouse lens really lights at night")
	gs.set_flag("game_completed");gs.set_flag("chest:lake:26");var saved: Vector2=p.position;gs.save_game(saved)
	check(gs.load_game() and gs.map_id=="headland" and gs.flag("game_completed") and gs.flag("chest:lake:26"),"real cape save retains original completion and collection flags")
	world.queue_free();await frames(6);gs.in_game=true;world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(14);p=world.player
	check(p.position.distance_to(saved)<1 and world.spawn_fits(p.position),"cape reload is on safe dry terrain")
	await safe_route(Vector2i(4,28));await cross("headland",Vector2(4.5,28.5),"harbor","move_left")
	await safe_route(Vector2i(3,18));await cross("harbor",Vector2(3.5,18.5),"river_mouth","move_left")
	await safe_route(Vector2i(14,42));await cross("river_mouth",Vector2(14.5,42.5),"coast","move_down")
	check(gs.hp==hp and gs.inventory==inventory and gs.coins==coins and gs.hero_xp==xp,"complete outward and return walk consumes or grants no resources")
	print("REGION WALK SECONDS river=",river_steps/60.0," harbor=",harbor_steps/60.0," harbor_to_cape=",cape_approach/60.0," cape=",cape_steps/60.0)
	# New ferry destination, actual controls, then safe arrival at the quay.
	p.position=Vector2(40.5,22.5)*32;await frames(5);await tap(KEY_E)
	check(routes().active,"existing coast board opens extended destinations")
	routes().buttons[2].grab_focus();await tap(KEY_ENTER);await frames(3)
	check(voyage().active and voyage().target=="harbor","added harbor destination uses original cancellable voyage")
	voyage().depart();await frames(65);check(gs.map_id=="harbor" and world.spawn_fits(p.position),"new ferry really arrives on harbor planks")
	# Old saves inside a newly introduced building must be resolved before playing.
	await enter("harbor","start",Vector2(39.5,24.5)*32);check(world.spawn_fits(p.position),"restoring a building overlap chooses real free floor")
	p.position=Vector2(34.5,27.5)*32;await frames(3)
	for chart in get_nodes_in_group("region_charts"):
		if not chart.is_queued_for_deletion():atlas().open(chart);break
	check(atlas().active,"standalone regional chart works")
	world.load_map("lake","from_coast");await frames(8);check(not gs.ui_owners.has("rg_atlas") and not gs.input_locked(),"forced map unload releases atlas owner")
	world.queue_free();await frames();print("COASTAL REGION OK" if failures==0 else "COASTAL REGION FAILED "+str(failures));quit(0 if failures==0 else 1)
