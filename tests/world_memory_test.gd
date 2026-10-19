extends SceneTree
const Memory := preload("res://scripts/core/world_memory.gd")
const Daynight := preload("res://scripts/core/daynight.gd")
var gs: Node
var world: Node2D
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	print("  ok   " if ok else "  FAIL ",message)
	if not ok: failures += 1
func frames(n:=4) -> void:
	for i in n: await process_frame
func close() -> void:
	world.dialogue._close(); await frames()
func enter(map: String) -> void:
	await close()
	world.load_map(map,"start")
	await frames(8)
	world.player.invuln=999
	for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
func actors() -> Array:
	return get_nodes_in_group("memory_actors").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
func actor(role: String) -> Node2D:
	for n in actors():
		if n.role==role: return n
	return null
func director() -> Node:
	for n in get_nodes_in_group("world_memory"):
		if not n.is_queued_for_deletion(): return n
	return null
func use(n: Node2D,pad:=false) -> void:
	# Ada works at the water's edge: approaching every resident from the south
	# can place the player's feet inside water and let collision recovery push
	# them outside interaction range. Choose real free footing beside the actor.
	var approach:=Vector2.INF
	for offset in [Vector2(0,30),Vector2(-30,-8),Vector2(30,-8),Vector2(0,-30)]:
		var candidate: Vector2=n.position+offset
		if world.spawn_fits(candidate):
			approach=candidate
			break
	check(approach!=Vector2.INF,"free physical approach to resident or book")
	if approach==Vector2.INF: return
	world.player.position=approach
	if n is CharacterBody2D: n.wait=20
	await frames()
	check(world.spawn_fits(world.player.position),"resident interaction stays on free ground")
	world.player._update_target()
	check(world.player.target==n,"real target: "+str(n.role if n is CharacterBody2D else "book"))
	for down in [true,false]:
		if pad:
			var e:=InputEventJoypadButton.new();e.button_index=JOY_BUTTON_A;e.pressed=down;Input.parse_input_event(e)
		else:
			var e:=InputEventKey.new();e.keycode=KEY_E;e.physical_keycode=KEY_E;e.pressed=down;Input.parse_input_event(e)
		await frames(2)
	check(world.dialogue.active,"keyboard/controller opens resident or book")
func audit(n: Node2D) -> void:
	check(n.get_parent()==world.entities and n is CharacterBody2D,"foot collision and world y-sort: "+n.role)
	check(not world.is_solid(n.position),"resident is on free ground: "+n.role)
	for npc in get_nodes_in_group("npc"):
		if not npc.is_queued_for_deletion(): check(n.position.distance_to(npc.position)>32,"distinct from quest NPC: "+n.role)
	for rest in [false,true]:
		n.rest=rest
		for point: Array in n.route():
			var cell:=Vector2i(point[0],point[1])
			var d:=director()
			d.build_grid()
			check(not d.grid.is_point_solid(cell),"activity destination free: "+n.role+str(cell))
			check(not d.walk_path(n,cell).is_empty(),"walkable activity route: "+n.role+str(cell))
			# Player can approach from the real map entry; never block a single-tile path.
			var start:=Vector2i(world.map_data.spawns.start[0],world.map_data.spawns.start[1])
			var accessible:=false
			for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var end: Vector2i=cell+step
				if d.grid.is_in_boundsv(end) and not d.grid.is_point_solid(end) and not d.grid.get_id_path(start,end).is_empty(): accessible=true
			check(accessible,"activity reachable from entrance: "+n.role)
	n.rest=false
func run() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"): quit(1); return
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world
	await frames(15)
	check(Memory.news().size()==2,"new game book explains restoration without announcing imaginary residents")
	for map: String in ["prismamine","mistgarden","ijsdal","kruipmoeras","dorstvallei","reedvault","ridgepass"]:
		await enter(map)
		check(actors().is_empty(),"no resident before restoration: "+map)
		for role: String in Memory.PLACES:
			if Memory.PLACES[role].map==map: gs.set_flag(Memory.PLACES[role].flag)
		await frames(8)
		for n in actors(): audit(n)
		var count:=actors().size()
		for i in 20: director().refresh()
		check(actors().size()==count,"repeated refresh never duplicates residents: "+map)
		gs.day_time=0.4
		for n in actors():
			var role: String=n.role
			var first:=Memory.lines(role,world.map_data.get("weather",""))
			var before: int=gs.hero_xp
			await use(n,role.length()%2==0)
			check(gs.flag("wm_met_"+role),"meeting is remembered: "+role)
			var at: Vector2=n.position
			await frames(12)
			check(n.position==at,"conversation pauses walking: "+role)
			await close()
			check(Memory.lines(role,world.map_data.get("weather","")).front()!=first.front(),"revisit acknowledges meeting: "+role)
			Memory.meet(role);Memory.meet(role)
			check(gs.hero_xp==before,"meetings have no repeatable XP or item rewards")
			world.player.position=world.map_data.spawns.start[0]*Vector2.RIGHT*32+Vector2(16,world.map_data.spawns.start[1]*32+16)
		gs.day_time=0.83
		await frames(4)
		for n in actors(): check(n.rest,"evening switches resident activity: "+n.role)
		gs.day_time=0.25
		await frames(4)
	check(Memory.news().size()==9,"book includes eight unlocked residents")
	# Rain uses the same deterministic weather as the atmosphere and save.
	var wet_day:=0
	for day in 30:
		if Daynight.raining("random",day,0.25): wet_day=day;break
	gs.day_count=wet_day;gs.day_time=0.25
	check(Memory.resting("random"),"rain changes outdoor work without a time gate")
	await enter("mistgarden");await frames(4)
	check(actor("gardener").rest,"gardener responds to actual rainy slot")
	gs.day_time=0.4
	await enter("dorstvallei")
	gs.set_flag("ra_water_wild",true)
	check(actor("caravan").route()==[[19,13]] and Memory.connection("caravan").contains("wild"),"wild-water choice keeps traveller off animal bank")
	gs.set_flag("ra_water_wild",false);gs.set_flag("ra_water_caravan",true)
	check(actor("caravan").route()==[[24,14]],"caravan choice uses shade at traveller halt")
	audit(actor("caravan"))
	gs.set_flag("ra_exhibit_routes",true)
	var routes:=Memory.connection("reader")
	gs.set_flag("ra_exhibit_routes",false)
	check(Memory.connection("reader")!=routes,"archive exhibition choice changes current conversation")
	# Book is reachable, keyboard and controller work, old meal and bed are preserved.
	await enter("inn")
	var book: Node2D=get_nodes_in_group("memory_books")[0]
	check(not world.is_solid(book.position),"book placed on free inn floor")
	for pad in [false,true]:
		await use(book,pad);await close()
	var saved: Dictionary=gs.flags.duplicate()
	var before: int=gs.hero_xp
	gs.save_game(world.player.position);gs.flags.clear()
	check(gs.load_game() and gs.flags==saved and gs.hero_xp==before,"actual save/load keeps restoration and meetings without rewards")
	await enter("ijsdal")
	check(actors().size()==2 and gs.flag("wm_met_hearth") and gs.flag("wm_met_lamplighter"),"residents return after loading")
	# Walk through their physical route and verify that targeting alone never freezes them.
	gs.day_time=0.25
	var moving:=actor("hearth")
	world.player.position=Vector2(15.5,12.5)*32
	moving.wait=0;moving.index=1;moving.path.clear()
	var initial:=moving.position
	world.player.target=moving
	for i in 100: await physics_frame
	check(moving.position.distance_to(initial)>8,"resident really walks while merely targeted")
	check(not world.is_solid(moving.position),"walking remains off house walls")
	var d:=director()
	var destination:=Vector2i(11,12)
	world.player.position=(Vector2(destination)+Vector2(0.5,0.5))*32
	check(d.walk_path(moving,destination).is_empty(),"resident waits for player occupying destination")
	world.player.position=Vector2(15.5,12.5)*32
	check(not d.walk_path(moving,destination).is_empty(),"old player occupancy is removed when raster rebuilds")
	gs.new_game();gs.start_quest("warmte");gs.finish_quest("warmte")
	before=gs.hero_xp
	await enter("ijsdal")
	check(actors().size()==2 and gs.hero_xp==before,"old completed quest gains residents without another reward")
	gs.new_game();await enter("ijsdal")
	check(actors().is_empty() and not gs.flag("wm_met_hearth"),"new game removes residents and remembered visits")
	world.queue_free();await frames()
	print("WORLD MEMORY OK" if failures==0 else "WORLD MEMORY FAILED: %d" % failures)
	quit(0 if failures==0 else 1)
