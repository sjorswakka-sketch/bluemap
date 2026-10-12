extends SceneTree
## Bereikbaarheid, echte botsingen/projectielen, animatie en oude opslagposities.

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
var failures := 0
var world: Node2D
var gs: Node


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("  ok   " if ok else "  FAIL ", label)
	if not ok:
		failures += 1


func frames(count := 3) -> void:
	for i in count:
		await physics_frame
		await process_frame


func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * 32.0


func flood_from(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var pending: Array[Vector2i] = [start]
	while not pending.is_empty():
		var cell := pending.pop_front() as Vector2i
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if not seen.has(next) and not world.is_solid(cell_center(next)):
				seen[next] = true
				pending.append(next)
	return seen


func _run() -> void:
	gs = root.get_node("GameState")
	gs.new_game()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(10)
	world.fader.set_alpha(0.0)
	var fountains := get_nodes_in_group("fountains")
	check(fountains.size() == 1, "het dorp heeft één grote fontein")
	if fountains.is_empty():
		quit(1)
		return
	var fountain: StaticBody2D = fountains[0]
	var square := Rect2(Vector2(16, 11) * 32.0, Vector2(8, 6) * 32.0)
	check(fountain.position.is_equal_approx(square.get_center()), "fontein staat exact midden op het bestaande plein")
	check(fountain.footprint.size == Vector2i(2, 2), "bassin is tweemaal zo breed en diep als de oude put")
	check(world.map_data.rows[13][19] == ",", "oude puttegel is vervangen door bestrating onder het bassin")
	var collider: CollisionShape2D = fountain.get_child(0)
	check(collider.shape.size == Vector2(64, 64) and fountain.collision_layer == 1, "werkelijke botsingsvorm volgt de hele sokkel")
	for cell: Vector2i in [Vector2i(19, 13), Vector2i(20, 13), Vector2i(19, 14), Vector2i(20, 14)]:
		check(world.is_solid(cell_center(cell)), "speler/projectielen zien solide bassin op %s" % cell)
	var seen := flood_from(Vector2i(19, 9))
	for name: String in world.map_data.spawns:
		var spawn: Array = world.map_data.spawns[name]
		check(seen.has(Vector2i(spawn[0], spawn[1])), "bestaande startplek blijft bereikbaar: " + name)
	for cell: Vector2i in [Vector2i(18, 13), Vector2i(21, 13), Vector2i(19, 12), Vector2i(19, 15), Vector2i(22, 12)]:
		check(seen.has(cell), "rondom lopen en opslaan blijven mogelijk op %s" % cell)
	for object: Dictionary in world.map_data.objects:
		if object.type not in ["portal", "savepoint", "npc"]:
			continue
		var pos: Array = object.pos
		check(not world.is_solid(cell_center(Vector2i(pos[0], pos[1]))), "fontein blokkeert geen " + str(object.get("id", object.type)))
	var original: Dictionary = Maps.get_map("village")
	check(original.objects[6].type == "savepoint" and original.objects[6].pos == [22, 12] and original.objects[19].pos == [8, 15], "bestaande objectvolgorde en posities blijven intact")
	world.player.global_position = Vector2(640, 382)
	Input.action_press("move_down")
	await frames(45)
	Input.action_release("move_down")
	check(world.player.global_position.y > 390.0 and world.player.global_position.y < 402.0, "echte speler loopt naar het bassin maar niet door de steen")
	var arrow: Node2D = load("res://scripts/entities/arrow.gd").new()
	arrow.world = world
	arrow.position = Vector2(580, 448)
	arrow.direction = Vector2.RIGHT
	world.entities.add_child(arrow)
	arrow.launch(80.0)
	check(arrow.state == "stuck" and arrow.position.x <= 608.0, "pijl stopt tegen dezelfde stenen rand (%s, %s)" % [arrow.state, arrow.position])
	arrow.queue_free()
	var projectile: Node2D = load("res://scripts/entities/projectile.gd").new()
	projectile.world = world
	projectile.position = Vector2(598, 450)
	projectile.velocity = Vector2(120, 0)
	world.entities.add_child(projectile)
	projectile._process(0.15)
	check(projectile.is_queued_for_deletion(), "vijandprojectiel botst ook met het bassin")
	var first_frame: int = fountain.animation_frame
	await frames(12)
	check(fountain.animation_frame != first_frame, "waterstralen en kringetjes krijgen nieuwe animatiebeelden")
	gs.set_ui("fountain_test", true)
	var paused_clock: float = fountain.clock
	await frames(12)
	check(fountain.clock == paused_clock, "fontein pauzeert mee met het spel")
	gs.set_ui("fountain_test", false)
	await frames(12)
	check(fountain.clock != paused_clock, "fontein beweegt weer na pauze")
	# Deze tegel was vroeger vrij naast de put: een bestaande opslag mag hier niet vastlopen.
	var legacy := cell_center(Vector2i(20, 14)) - Vector2(0, 8)
	world.load_map("village", "start", legacy)
	await frames(4)
	var restored: Vector2 = world.player.global_position
	check(restored != legacy and not world.is_solid(restored + Vector2(0, 8)), "oude opslag binnen groter bassin wordt naar een vrije rand verplaatst")
	check(restored.distance_to(legacy) < 50.0, "herstelde opslag blijft vlak bij de oorspronkelijke positie")
	var direction := (restored + Vector2(0, 8) - Vector2(640, 448)).normalized()
	world.player.velocity = direction * 110.0
	world.player.set_physics_process(false)
	for i in 12:
		world.player.move_and_slide()
		await frames(1)
	check(world.player.global_position.distance_to(restored) > 12.0, "speler kan na herstellen werkelijk van de fontein weglopen")
	var untouched := Vector2(570, 445)
	check(world._safe_fountain_spawn(untouched) == untouched, "opslag buiten het nieuwe bassin verandert niet")
	world.load_map("forest", "from_village")
	await frames(4)
	check(get_nodes_in_group("fountains").is_empty(), "fontein en botsingsvorm verdwijnen bij verlaten van het dorp")
	world.load_map("village", "start")
	await frames(4)
	check(get_nodes_in_group("fountains").size() == 1, "terugkomst bouwt precies één fontein")
	world.queue_free()
	await frames()
	print("FOUNTAIN TEST OK" if failures == 0 else "FOUNTAIN TEST FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
