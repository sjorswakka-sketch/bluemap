extends SceneTree
## Echte spelobjecten, kaartverbindingen, aanvallen en eenmalige proefbeloning.
const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
var brain: Script
var failures := 0
var gs: Node
var world: Node2D

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("  ok   " if ok else "  FAIL ", message)
	if not ok:
		failures += 1

func frames(count := 3) -> void:
	for i in count:
		await process_frame
		await physics_frame

func reachable(map_id: String) -> Dictionary:
	var data: Dictionary = Maps.get_map(map_id)
	var rows: Array = data["rows"]
	var start := Vector2i(data["spawns"]["start"][0], data["spawns"]["start"][1])
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var blocked := {}
	for obj: Dictionary in data["objects"]:
		if obj["type"] in ["chest", "sign", "savepoint"]:
			blocked[Vector2i(obj["pos"][0], obj["pos"][1])] = true
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + direction
			if seen.has(next) or blocked.has(next) or next.y < 0 or next.y >= rows.size() or next.x < 0 or next.x >= rows[next.y].length():
				continue
			if not Tiles.is_solid_char(rows[next.y][next.x]):
				seen[next] = true
				queue.append(next)
	return seen

func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	brain = load("res://scripts/entities/echo_enemy.gd")
	gs.new_game()
	gs.in_game = true
	for map_id in ["prismamine", "resonance"]:
		var seen := reachable(map_id)
		var data: Dictionary = Maps.get_map(map_id)
		for spawn: Array in data["spawns"].values():
			check(seen.has(Vector2i(spawn[0], spawn[1])), map_id + ": elke aankomstplek bereikbaar")
		for obj: Dictionary in data["objects"]:
			if obj["type"] in ["portal", "echo_trial", "enemy", "chest", "savepoint", "sign"]:
				var at := Vector2i(obj["pos"][0], obj["pos"][1])
				var accessible := seen.has(at)
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					accessible = accessible or seen.has(at + direction)
				check(accessible, map_id + ": bereikbaar object " + obj["type"])
	for weapon in ["wood", "iron", "crystal", "star"]:
		gs.weapon = weapon
		check(gs.check(["echo_ready"]) == (weapon != "wood"), "doorgang ondersteunt " + weapon)
	gs.weapon = "iron"
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(8)
	world.load_map("resonance", "start")
	await frames()
	world.set_process(false)
	world.fader.set_alpha(0.0)
	var player: Node2D = world.player
	player.set_physics_process(false)
	player.global_position = Vector2(16.5, 12.5) * 32.0
	player.facing = Vector2.RIGHT
	root.get_node("Controls").mouse_aim_active = false
	root.get_node("Controls").controller_active = false
	gs.movement.reset()
	var side: Node2D = world.spawn_enemy("crystal_beetle", player.global_position + Vector2(0, -32))
	side.set_physics_process(false)
	var hp: int = side.hp
	for i in 2:
		player.cooldown = 0.0
		player._attack()
	check(side.hp == hp, "eerste twee slagen raken geen vijand opzij")
	player.cooldown = 0.0
	player._attack()
	check(player.combo_sweep and side.hp == hp - gs.damage(), "derde slag raakt de flank met de echte aanval")
	check(is_equal_approx(gs.movement.stamina, 82.0), "veeg kost precies 18 stamina")
	gs.movement.stamina = 10.0
	player.combo_step = 2
	player.cooldown = 0.0
	player._attack()
	check(not player.combo_sweep and gs.movement.stamina == 10.0, "zonder stamina blijft de gewone aanval beschikbaar")
	player.combo_window = 0.0
	player.cooldown = 0.0
	player._attack()
	check(player.combo_step == 1, "combo reset na de tijdslimiet")
	side.queue_free()
	await frames()
	# Een echte physicsmuur mag niet met het zwaard doorboord worden.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(6, 40)
	shape.shape = rectangle
	wall.add_child(shape)
	world.add_child(wall)
	wall.global_position = player.global_position + Vector2(16, 0)
	var behind_wall: Node2D = world.spawn_enemy("crystal_beetle", player.global_position + Vector2(32, 0))
	behind_wall.set_physics_process(false)
	await frames()
	hp = behind_wall.hp
	player.combo_window = 0.0
	player.cooldown = 0.0
	player._attack()
	check(behind_wall.hp == hp, "een echte muur blokkeert zwaardaanvallen")
	wall.queue_free()
	await frames()
	player.cooldown = 0.0
	player._attack()
	check(behind_wall.hp == hp - gs.damage(), "zonder muur raakt hetzelfde zwaarddoel wel")
	behind_wall.queue_free()
	await frames()
	var beetle: Node2D = world.spawn_enemy("crystal_beetle", player.global_position + Vector2(-120, 0))
	beetle.set_physics_process(false)
	beetle.player = player
	beetle.state_time = 1.4
	brain.update(beetle, 0.01)
	check(beetle.state == "echo_warn", "kever waarschuwt voor hij stormt")
	beetle.state_time = 0.5
	var fixed: Vector2 = beetle.aim_dir
	player.global_position += Vector2(0, 50)
	brain.update(beetle, 0.01)
	check(beetle.aim_dir == fixed, "waarschuwing vergrendelt zodat opzij ontwijken werkt")
	beetle.state_time = 0.71
	brain.update(beetle, 0.01)
	check(beetle.state == "echo_dash", "kever stormt pas na 0,7 seconde")
	beetle.state_time = 0.5
	brain.update(beetle, 0.01)
	check(beetle.state == "echo_rest" and beetle.desired == Vector2.ZERO, "kever heeft een echte herstelpauze")
	beetle.queue_free()
	var moth: Node2D = world.spawn_enemy("prism_moth", player.global_position + Vector2(130, 0))
	moth.set_physics_process(false)
	moth.player = player
	moth.state = "echo_warn"
	moth.state_time = 0.71
	moth.aim_dir = Vector2.LEFT
	brain.update(moth, 0.01)
	var sparks := get_nodes_in_group("breakable")
	check(sparks.size() == 3, "prismamot schiet precies drie vonken")
	for spark: Node in sparks:
		check(spark.kind == "prism_spark" and spark.turn == 0.0, "vonk volgt de getoonde richting zonder achtervolgen")
		spark.queue_free()
	moth.state = "echo_warn"
	moth.hurt(1, Vector2.LEFT)
	check(moth.state == "echo_rest", "zwaard onderbreekt het schieten")
	moth.queue_free()
	await frames(8)
	var trial: Node2D = get_first_node_in_group("echo_trials")
	trial.set_process(false)
	player.global_position = trial.global_position + Vector2(0, 32)
	trial.interact()
	check(trial.active and trial.countdown == 3.0, "proef start alleen door bewuste interactie, met waarschuwing")
	# Op een spawn blijven staan mag nooit plotseling contactschade opleveren.
	player.global_position = trial.SPAWNS[0]
	trial._spawn_wave()
	check(trial.wave == 0 and trial.foes.is_empty(), "bezette spawn wacht tot de speler wegloopt")
	player.global_position = trial.global_position + Vector2(0, 32)
	for wave in 3:
		trial._process(3.1)
		check(trial.wave == wave + 1 and trial.foes.size() == trial.WAVES[wave].size(), "golf heeft de juiste vijanden")
		for foe: Node2D in trial.foes:
			foe.dead = true
			foe.queue_free()
		await frames()
	var before: int = gs.coins
	trial._process(0.1)
	check(gs.flag("echo_trial_won") and gs.count("gear_crystal_amulet") == 1 and gs.coins == before + 120, "proef geeft de beloofde beloning")
	trial._finish()
	check(gs.coins == before + 120, "beloning kan niet tweemaal uitgekeerd worden")
	check(gs.load_game() and gs.flag("echo_trial_won"), "proef en beloning overleven opslaan en laden")
	world.load_map("prismamine", "start")
	await frames()
	check(gs.map_id == "prismamine", "na de proef blijft teruggaan mogelijk")
	world.queue_free()
	await frames()
	print("ECHO OK" if failures == 0 else "ECHO FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
