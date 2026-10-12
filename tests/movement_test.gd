extends SceneTree
## Gebruik een geisoleerde Godot user://-map, net als bij de overige speltests.
## godot --headless --fixed-fps 60 --path . -s tests/movement_test.gd

const Movement := preload("res://scripts/core/movement.gd")
const Tiles := preload("res://scripts/data/tiles.gd")

class TestGround extends Node2D:
	var map_data: Dictionary = {}

var failures := 0
var gs: Node
var ground: Node2D
var player: CharacterBody2D
var steps: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("  ok   " if condition else "  FAIL ", label)
	if not condition:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func reset_surface(character: String) -> void:
	ground.map_data = {"rows": []}
	for y in 12:
		ground.map_data.rows.append(character.repeat(200))
	player.position = Vector2(64, 64)
	player.velocity = Vector2.ZERO
	player.knockback = Vector2.ZERO
	player.roll_timer = 0.0
	player.roll_cooldown = 0.0
	player.attack_timer = 0.0
	player.bow_anim = 0.0
	player.step_distance = 0.0
	steps.clear()
	gs.movement.reset()
	Input.action_release("move_right")
	Input.action_release("move_down")
	Input.action_release("sprint")


func travel_distance(character: String, sprint := false, diagonal := false) -> float:
	reset_surface(character)
	Input.action_press("move_right")
	if sprint:
		Input.action_press("sprint")
	if diagonal:
		Input.action_press("move_down")
	var start := player.position
	await frames(30)
	Input.action_release("move_right")
	Input.action_release("move_down")
	Input.action_release("sprint")
	return start.distance_to(player.position)


func _run() -> void:
	gs = root.get_node("GameState")
	gs.new_game()
	gs.in_game = true
	var meter := Movement.new()
	check(is_equal_approx(meter.sprint_multiplier(1.0 / 60.0), 1.5), "sprint is 50 procent sneller")
	meter.advance(5.0, true)
	check(meter.stamina == 0.0 and meter.exhausted and not meter.can_sprint(), "vijf seconden rennen put de balk uit")
	meter.advance(0.8, false)
	check(meter.stamina == 0.0, "herstel wacht 0,8 seconde")
	meter.advance(0.5, false)
	check(is_equal_approx(meter.stamina, 12.5) and meter.exhausted, "uitputting blijft tot 25 energie")
	meter.advance(0.5, false)
	check(is_equal_approx(meter.stamina, 25.0) and meter.can_sprint(), "vanaf 25 energie kun je weer rennen")
	meter.advance(100.0, false)
	check(meter.stamina == Movement.MAX_STAMINA, "herstel komt nooit boven de maximumwaarde")
	meter.advance(100.0, true)
	check(meter.stamina == 0.0, "ook lange stappen maken energie nooit negatief")
	check(meter.restore(60.0) and meter.stamina == 60.0 and meter.can_sprint(), "kruidentonic herstelt energie en uitputting")
	meter.restore(1000.0)
	check(not meter.restore(60.0) and meter.stamina == 100.0, "drankje wordt niet verspild aan een volle balk")
	meter.stamina = 1.0
	check(is_equal_approx(meter.sprint_multiplier(1.0), 1.025), "laatste beetje energie levert alleen betaalde sprinttijd")
	check(Tiles.name_at([","], Vector2(-1, 8)) == "", "buiten de kaart klinkt geen ongeldige ondergrond")
	check(Tiles.footstep_surface("grass_flowers") == "grass" and Tiles.footstep_surface("grass_tufts") == "grass", "alle grasvarianten klinken als gras")
	check(Tiles.footstep_surface("arena_sand") == "sand" and Tiles.movement_multiplier("arena_sand") == 0.92, "arena en strand hebben hetzelfde zandgedrag")
	var sprint_key := false
	var sprint_stick := false
	for event in InputMap.action_get_events("sprint"):
		if event is InputEventKey and event.physical_keycode == KEY_CTRL:
			sprint_key = true
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_STICK:
			sprint_stick = true
	check(sprint_key and sprint_stick, "Ctrl en L3 zijn beide aan rennen gekoppeld")
	var dodge_unchanged := false
	for event in InputMap.action_get_events("dodge"):
		if event is InputEventKey and event.physical_keycode == KEY_SHIFT:
			dodge_unchanged = true
	check(dodge_unchanged, "Shift blijft rollen")
	for surface in ["grass", "path", "sand", "wood", "stone", "cloth"]:
		check(root.get_node("Sound").streams.has("step_" + surface), "geluid geladen: " + surface)

	ground = TestGround.new()
	root.add_child(ground)
	player = load("res://scripts/entities/player.gd").new()
	player.world = ground
	ground.add_child(player)
	player.footstep.connect(func(surface: String) -> void: steps.append(surface))
	reset_surface(".")
	await frames(2)
	var grass: float = await travel_distance(".")
	check(absf(grass - 55.0) < 2.0, "echt lopen op gras behoudt 110 pixels per seconde")
	check(not steps.is_empty() and steps.all(func(s: String) -> bool: return s == "grass"), "bewegende voeten spelen grasgeluid")
	var path: float = await travel_distance(",")
	check(absf(path / grass - 1.2) < 0.02, "echt lopen op pad is 20 procent sneller dan gras")
	check(not steps.is_empty() and steps.all(func(s: String) -> bool: return s == "path"), "bewegende voeten spelen padgeluid")
	var sand: float = await travel_distance("s")
	check(absf(sand / grass - 0.92) < 0.02 and path > sand, "echt lopen op zand is 8 procent langzamer")
	check(not steps.is_empty() and steps.all(func(s: String) -> bool: return s == "sand"), "bewegende voeten spelen zandgeluid")
	var run: float = await travel_distance(".", true)
	check(absf(run / grass - 1.5) < 0.02 and absf(gs.movement.stamina - 90.0) < 0.7, "echt rennen versnelt 50 procent en verbruikt energie")
	var diagonal: float = await travel_distance(".", true, true)
	check(absf(diagonal - run) < 2.0, "diagonaal rennen geeft geen extra snelheid")
	for pair in [["w", "wood"], ["c", "stone"], ["%", "cloth"]]:
		await travel_distance(pair[0])
		check(not steps.is_empty() and steps.all(func(s: String) -> bool: return s == pair[1]), "echte ondergrond klinkt als " + pair[1])

	reset_surface(".")
	Input.action_press("sprint")
	await frames(90)
	check(steps.is_empty() and gs.movement.stamina == 100.0, "stilstaan met Ctrl geeft geen stappen of energieverbruik")
	Input.action_press("move_right")
	await frames(30)
	var energy: float = gs.movement.stamina
	var position_before := player.position
	var steps_before := steps.size()
	gs.set_ui("movement_test", true)
	await frames(60)
	check(player.position == position_before and gs.movement.stamina == energy and steps.size() == steps_before, "pauze bevriest lopen, voetstappen en energie")
	gs.set_ui("movement_test", false)
	gs.transitioning = true
	await frames(60)
	check(player.position == position_before and gs.movement.stamina == energy and steps.size() == steps_before, "kaartovergang bevriest lopen, voetstappen en energie")
	gs.transitioning = false
	reset_surface(".")
	Input.action_press("move_right")
	Input.action_press("sprint")
	player._roll()
	await frames(10)
	check(steps.is_empty() and gs.movement.stamina == 100.0 and is_equal_approx(player.velocity.length(), 235.0), "rollen houdt eigen snelheid en verbruikt geen sprintenergie")
	reset_surface(".")
	player.attack_timer = 1.0
	Input.action_press("move_right")
	Input.action_press("sprint")
	await frames(10)
	check(gs.movement.stamina == 100.0 and is_equal_approx(player.velocity.length(), 110.0), "een aanval krijgt geen sprintbonus")

	reset_surface(".")
	var wall := StaticBody2D.new()
	wall.position = Vector2(160, 64)
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(16, 600)
	collider.shape = box
	wall.add_child(collider)
	ground.add_child(wall)
	Input.action_press("move_right")
	Input.action_press("sprint")
	await frames(90)
	steps_before = steps.size()
	energy = gs.movement.stamina
	position_before = player.position
	await frames(90)
	check(player.position.distance_to(position_before) < 0.1 and steps.size() == steps_before, "tegen een muur blijven duwen maakt geen voetstappen")
	check(gs.movement.stamina >= energy and not player.sprinting, "tegen een muur rennen verbruikt geen energie")
	reset_surface(".")
	ground.queue_free()
	await frames(2)

	var world: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(2)
	gs.movement.advance(2.0, true)
	energy = gs.movement.stamina
	world.load_map("forest", "start")
	check(gs.movement.stamina == energy, "echte kaartwissel vult energie niet bij")
	check(world.hud.stamina_bar.visible and world.hud.stamina_bar.size.y > 0.0, "de uithoudingsbalk staat zichtbaar in de HUD")
	world.queue_free()
	await frames(2)
	gs.new_game()
	check(gs.movement.stamina == 100.0 and not gs.movement.exhausted, "nieuw spel begint met volle energie")
	print("MOVEMENT OK" if failures == 0 else "MOVEMENT FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
