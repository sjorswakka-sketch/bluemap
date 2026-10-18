extends SceneTree
const Maps:=preload("res://scripts/maps/registry.gd")
const Journey:=preload("res://scripts/core/journey.gd")
const Tiles:=preload("res://scripts/data/tiles.gd")
var gs: Node
var world: Node2D
var p: Node2D
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,text: String):
	print("  ok   " if ok else "  FAIL ",text)
	if not ok:failures+=1
func frames(n:=3):
	for i in n:await process_frame;await physics_frame
func release():
	for a in ["move_left","move_right","move_up","move_down"]:Input.action_release(a)
func walk_to(goal: Vector2,limit:=1000):
	var steps:=0
	for i in limit:
		var offset: Vector2=goal-p.position
		release()
		if offset.length()<4:break
		if absf(offset.x)>2:Input.action_press("move_right" if offset.x>0 else "move_left")
		if absf(offset.y)>2:Input.action_press("move_down" if offset.y>0 else "move_up")
		await physics_frame;steps+=1
	release();await frames(2)
	check(p.position.distance_to(goal)<8,"actual movement reaches "+str(goal/32))
	return steps
func route_to(goal: Vector2i) -> int:
	var grid:=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,world.map_size);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	for cell in world.solid_cells:grid.set_point_solid(cell)
	var path:=grid.get_id_path(Vector2i(p.position/32),goal)
	check(not path.is_empty(),"terrain connects arrival and "+str(goal))
	var steps:=0
	for cell in path:steps+=await walk_to(Vector2(cell)*32+Vector2(16,16))
	return steps
func enter(id: String,spawn:="start",at:=Vector2.INF):
	world.dialogue._close();world.menu_ui.close();world.load_map(id,spawn,at);await frames(7)
	p=world.player
	for n in get_nodes_in_group("enemies"):n.set_physics_process(false)
func voyage() -> Node:
	for n in get_nodes_in_group("coast_voyage"):
		if not n.is_queued_for_deletion():return n
	return null
func dock() -> Node2D:
	for n in get_nodes_in_group("coast_docks"):
		if not n.is_queued_for_deletion():return n
	return null
func tap(code: int,pad:=false):
	for down in [true,false]:
		if pad:
			var e:=InputEventJoypadButton.new();e.button_index=code;e.pressed=down;Input.parse_input_event(e)
		else:
			var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e)
		await frames(2)
func click(button: Button):
	var point:=button.get_global_rect().get_center()
	var m:=InputEventMouseMotion.new();m.position=point;m.global_position=point;m.relative=Vector2(5,0);Input.parse_input_event(m);await frames(2)
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(e);await frames(2)
func offer(accept:=true,pad:=false):
	await frames(3);await tap(JOY_BUTTON_A if pad else KEY_E,pad)
	check(world.dialogue.active,"actual dock interaction opens ferry conversation")
	for i in 5:
		if world.dialogue.buttons.is_empty():world.dialogue._advance();await frames(2)
	var buttons: Array=world.dialogue.buttons
	check(buttons.size()==2,"ferry offers free passage and a stay choice")
	if buttons.size()!=2:return
	buttons[0 if accept else 1].grab_focus();await tap(JOY_BUTTON_A if pad else KEY_ENTER,pad)
	if accept:
		var ui:=voyage();check(ui!=null and ui.active and not world.dialogue.active and gs.ui_owners.has("ce_voyage"),"passage opens after dialogue releases owner")
		if ui!=null:ui.set_process(false)
	else:check(not world.dialogue.active and not gs.input_locked(),"stay choice releases input")
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true
	var base: Dictionary=Maps.MAPS.lake.DATA.duplicate(true)
	for file in ["living_maps","regional_maps","combat_maps","craft_maps","space_maps","habitat_maps"]:load("res://scripts/data/"+file+".gd").enrich("lake",base)
	var actual:=Maps.get_map("lake")
	check(actual.objects.filter(func(o):return not o.get("trail_wildlife",false) and not o.get("id","").begins_with("trail:")).size()==base.objects.size()+2,"lake only gets one optional exit and one direction sign")
	for i in base.objects.size():check(actual.objects[i]==base.objects[i],"original lake object and save slot preserved "+str(i))
	for y in actual.rows.size():
		for x in actual.rows[y].length():
			if actual.rows[y][x]!=base.rows[y][x]:check(y in [8,9] and x>=(39 if y==8 else 40),"only east-edge connection terrain changes")
	check(Maps.get_map("forest_edge").objects.filter(func(o):return not o.get("trail_wildlife",false) and not o.get("id","").begins_with("trail:")).size()==5,"quiet Bosrand only adds a scenic waterfall")
	check(Journey.path("village","gull_island")==["village","lake","coast","gull_island"],"quest graph recognises ferry links as well as portals")
	check(Journey.path("gull_island","village")==["gull_island","coast","lake","village"],"route home is available without unlocks")
	check(Tiles.NAMES.slice(71,78)==["ce_sea","ce_sand","ce_dune","ce_grass","ce_cliff","ce_shore","ce_boardwalk"] and load("res://assets/tiles.png").get_width()==Tiles.NAMES.size()*16,"atlas has all legacy and seven new tiles")
	check(Tiles.footstep_surface("ce_sand")=="sand" and Tiles.footstep_surface("ce_boardwalk")=="wood" and Tiles.movement_multiplier("ce_sand")==0.92,"coastal terrain uses appropriate walking speed and sounds")
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
	await enter("lake","from_coast")
	p.position=Vector2(40.5,8.5)*32;await frames(3)
	for n in get_nodes_in_group("enemies"):n.set_physics_process(true)
	Input.action_press("move_right")
	for i in 90:
		await physics_frame
		if gs.map_id=="coast":break
	release();await frames(30)
	check(gs.map_id=="coast" and world.spawn_fits(p.position),"actual lake exit arrives on safe coastal floor")
	var shot: Node2D=load("res://scripts/entities/arrow.gd").new();shot.world=world;shot.position=Vector2(50.5,25.5)*32;shot.direction=Vector2.RIGHT;world.entities.add_child(shot);shot._advance(24)
	check(shot.state=="flying","existing arrows fly over coastal sea like other water");shot.queue_free()
	var hp: int=gs.hp
	var before_inventory: Dictionary=gs.inventory.duplicate(true)
	var before_coins: int=gs.coins
	var before_xp: int=gs.hero_xp
	var before_prof: Dictionary=gs.professions.duplicate(true)
	var start_time:=Time.get_ticks_usec()
	var steps:=await route_to(Vector2i(42,22))
	print("COAST WALK SECONDS=",steps/60.0," actual runtime ms=",(Time.get_ticks_usec()-start_time)/1000.0)
	check(steps/60.0>8 and steps/60.0<20,"coast crossing offers a short spacious walk")
	check(get_nodes_in_group("enemies").filter(func(n):return n.data.behavior!="animal").is_empty() and get_nodes_in_group("pickups").is_empty() and gs.hp==hp,"new coastal walk is quiet without invulnerability")
	await offer(false)
	await offer()
	var ui:=voyage();var old_elapsed: float=ui.elapsed
	for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
		root.size=size;await frames(3);ui.layout()
		check(Rect2(Vector2(0,0),Vector2(size)).encloses(ui.panel.get_global_rect()),"passage panel fits "+str(size))
	root.size=Vector2i(1152,648);await frames(3)
	await tap(JOY_BUTTON_B,true)
	check(gs.map_id=="coast" and not gs.ui_owners.has("ce_voyage") and not ui.active,"controller B cancels without leaving or consuming anything")
	await offer(true,true);ui=voyage();ui.device_changed(true)
	check(ui.arrive.mouse_filter==Control.MOUSE_FILTER_IGNORE,"pad mode ignores mouse on passage buttons")
	ui.arrive.grab_focus();await tap(JOY_BUTTON_A,true);await frames(65)
	check(gs.map_id=="gull_island" and world.spawn_fits(p.position) and not gs.input_locked(),"controller A skips short presentation and safely arrives")
	check(gs.coins==before_coins and gs.inventory==before_inventory and gs.hp==hp and gs.hero_xp==before_xp and gs.professions==before_prof,"free voyage neither consumes nor grants items health or XP")
	steps=await route_to(Vector2i(32,15));await tap(KEY_E);await frames()
	check(world.dialogue.active and gs.inventory==before_inventory,"optional viewpoint is scenery without a collect task")
	world.dialogue._close();await frames()
	# Sea collision is real: walk towards the water on a broad beach.
	p.position=Vector2(26.5,29.5)*32;await frames()
	Input.action_press("move_down")
	for i in 50:await physics_frame
	release();await frames()
	check(not world.is_solid(p.position+Vector2(0,8)) and p.position.y<31*32,"actual collision keeps the player out of sea")
	# Save on the new island, retaining old collections and completed-game progress.
	await route_to(Vector2i(8,22))
	gs.set_flag("chest:lake:26");gs.set_flag("pickup:forest:47");gs.set_flag("game_completed")
	var saved: Vector2=p.position;gs.save_game(saved);gs.flags.clear()
	check(gs.load_game() and gs.map_id=="gull_island" and gs.flag("chest:lake:26") and gs.flag("pickup:forest:47") and gs.flag("game_completed"),"actual save/load retains island position and old completed-game flags")
	world.queue_free();await frames(7);gs.in_game=true
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
	check(p.position.distance_to(saved)<1 and world.spawn_fits(p.position),"reload restores a safe island landing")
	await offer();ui=voyage();await click(ui.arrive);await frames(65)
	check(gs.map_id=="coast" and not gs.input_locked() and not root.get_node("Controls").controller_active,"native mouse click returns and switches input method")
	await route_to(Vector2i(5,17))
	Input.action_press("move_left")
	for i in 120:
		await physics_frame
		if gs.map_id=="lake":break
	release();await frames(30)
	check(gs.map_id=="lake" and world.spawn_fits(p.position),"actual west exit returns to unchanged lake route")
	await walk_to(Vector2(21.5,8.5)*32)
	check(gs.hp==hp and get_nodes_in_group("enemies").filter(func(n):return n.data.behavior!="animal").size()==4,"north lake return really remains safe with existing enemies active")
	# Forced unload of an uncommitted passage cannot strand a UI owner.
	await enter("coast","from_island");p.position=Vector2(42.5,22.5)*32;await offer();ui=voyage()
	world.load_map("lake","from_coast");await frames(8)
	check(not gs.ui_owners.has("ce_voyage") and not gs.input_locked(),"map change cancels incomplete trip and releases input")
	# Stale or repeated actions cannot create a second trip.
	await enter("coast","from_island");p.position=Vector2(42.5,22.5)*32
	var director:=voyage();director.offer(dock());world.dialogue._close();p.position=Vector2(5.5,17.5)*32;director.begin()
	check(not director.active,"stale distant departure rejected")
	# Automatic arrival also works, without any confirmation or skip key.
	p.position=Vector2(42.5,22.5)*32;await offer();ui=voyage();ui._process(2.3);ui.depart();await frames(65)
	check(gs.map_id=="gull_island" and not gs.input_locked(),"automatic crossing commits once and releases all ownership")
	# Existing old position at the newly appended lake sign is safely restored.
	await enter("lake","from_coast",Vector2(40.5,7.5)*32)
	check(world.spawn_fits(p.position),"old save at new wayfinding sign is moved to valid nearby floor")
	gs.new_game();check(not gs.flag("game_completed"),"new game still resets completion")
	world.queue_free();await frames()
	print("COAST EXPEDITION OK" if failures==0 else "COAST EXPEDITION FAILED "+str(failures));quit(0 if failures==0 else 1)
