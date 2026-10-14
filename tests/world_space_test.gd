extends SceneTree
const Maps:=preload("res://scripts/maps/registry.gd")
const Journey:=preload("res://scripts/core/journey.gd")
var gs: Node
var world: Node2D
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,text: String):
	print("  ok   " if ok else "  FAIL ",text)
	if not ok:failures+=1
func frames(n:=4):
	for i in n:await process_frame
func enter(map: String,spawn: String="start"):
	world.dialogue._close();world.menu_ui.close();world.load_map(map,spawn)
	await frames(6)
func release():
	for a in ["move_left","move_right","move_up","move_down"]:Input.action_release(a)
func walk_to(goal: Vector2) -> int:
	var steps:=0
	for i in 1500:
		var offset: Vector2=goal-world.player.position
		release()
		if offset.length()<4:break
		if absf(offset.x)>2:Input.action_press("move_right" if offset.x>0 else "move_left")
		if absf(offset.y)>2:Input.action_press("move_down" if offset.y>0 else "move_up")
		await physics_frame;steps+=1
	release();await frames(2)
	check(world.player.position.distance_to(goal)<7,"actual movement reaches "+str(goal/32))
	return steps
func edge_path(reverse:=false) -> int:
	var grid:=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,world.map_size)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	for cell in world.solid_cells:grid.set_point_solid(cell)
	var end:=Vector2i(3,13) if reverse else Vector2i(40,10)
	var path:=grid.get_id_path(Vector2i(world.player.position/32),end)
	check(not path.is_empty(),"quiet transition has connected terrain in both directions")
	var steps:=0
	for cell in path:steps+=await walk_to(Vector2(cell)*32+Vector2(16,16))
	return steps
func portal(to: String):
	for p in world.entities.get_children():
		if "target_map" in p and p.target_map==to:
			world.player.position=p.rect.get_center()+Vector2(0,64)
			await frames(3)
			world.player.position=p.rect.get_center()
			await frames(85)
			check(gs.map_id==to,"actual portal enters "+to)
			return
	check(false,"missing portal to "+to)
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world
	await frames(15)
	check(Journey.path("village","forest")==["village","forest_edge","forest"],"quest graph uses the actual new transition")
	check(Journey.path("forest","village")==["forest","forest_edge","village"],"return route stays connected")
	gs.start_quest("main");Journey.toggle("main")
	check(Journey.route_text("main").contains("Bosrand"),"quest route names the next real area")
	for id in ["village","forest","lake"]:
		var original: Array=Maps.MAPS[id].DATA.objects
		var actual: Array=Maps.get_map(id).objects
		for index in original.size():
			if original[index].type in ["chest","pickup"]:
				check(actual[index]==original[index],"saved object slot unchanged: "+id+str(index))
	await portal("forest_edge")
	check(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("pickups").is_empty(),"quiet area has no enemies or loot")
	check(world.map_data.objects.size()==4,"only two exits and two directional signs, no new activities")
	var hp: int=gs.hp
	var steps:=await edge_path()
	print("EDGE WALK SECONDS=",steps/60.0)
	check(steps/60.0>=8 and steps/60.0<16,"transition is a short pause, not a long compulsory detour")
	check(gs.hp==hp and world.player.knockback==Vector2.ZERO,"quiet crossing needs no combat")
	await portal("forest")
	check(get_nodes_in_group("enemies").size()==18,"forest has eighteen enemies instead of twenty-six")
	for foe in get_nodes_in_group("enemies"):
		check(not world.is_solid(foe.position+Vector2(0,8)),"retained enemy stands on floor: "+foe.kind)
	world.player.invuln=0
	await walk_to(Vector2(15.5,17.5)*32)
	check(gs.hp==hp and world.player.knockback==Vector2.ZERO,"west entrance/altar stretch really passes without attacks")
	for foe in get_nodes_in_group("enemies"):foe.set_physics_process(false)
	var test_foe: Node2D=world.spawn_enemy("slime",Vector2(12.5,17.5)*32)
	test_foe.set_physics_process(false);test_foe.player=world.player;test_foe.patrol_radius=160;test_foe.hp=2
	world.player.position=test_foe.home_position+Vector2(60,0);test_foe._ai_chase(0.1)
	check(test_foe.desired.x>0,"ordinary slime still engages inside its territory")
	test_foe.position=test_foe.home_position+Vector2(100,0)
	world.player.position=test_foe.home_position+Vector2(180,0);test_foe._ai_chase(0.1)
	check(test_foe.desired.x<0 and test_foe.hp==2,"slime returns home without healing when pulled out of territory")
	test_foe.patrol_radius=0;test_foe._ai_chase(0.1)
	check(test_foe.desired.x>0,"unconfigured trial/boss spawns retain original chase rules")
	test_foe.queue_free()
	await enter("forest_edge","from_forest")
	steps=await edge_path(true)
	check(gs.hp==hp,"reverse quiet crossing remains safe")
	gs.set_flag("chest:forest:4");gs.set_flag("pickup:forest:47")
	var saved_at: Vector2=world.player.position
	gs.save_game(saved_at);gs.flags.clear()
	check(gs.load_game() and gs.map_id=="forest_edge","new area survives actual save/load")
	world.queue_free();await frames(6)
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world
	await frames(15)
	check(world.player.position.distance_to(saved_at)<1 and gs.flag("chest:forest:4") and gs.flag("pickup:forest:47"),"loading preserves position and old collection flags")
	await portal("village")
	check(world.spawn_fits(world.player.position),"return arrives on free floor")
	await enter("forest")
	for n in get_nodes_in_group("interactable"):
		if "unique_key" in n and n.unique_key=="chest:forest:4":check(n.opened,"old opened chest remains opened")
	for n in get_nodes_in_group("pickups"):check(n.unique_key!="pickup:forest:47","old collected potion stays absent")
	await enter("lake")
	check(get_nodes_in_group("enemies").size()==4 and world.map_data.objects.size()==Maps.get_map("lake").objects.size()+4,"lake layout/activity count preserved")
	world.queue_free();await frames()
	print("WORLD SPACE OK" if failures==0 else "WORLD SPACE FAILED: %d"%failures)
	quit(0 if failures==0 else 1)
