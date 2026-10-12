extends SceneTree
## Richtkruis, onafhankelijke richtingen, echte pijlen en onderbroken werkacties.

var failures := 0
var gs: Node
var controls: Node
var world: Node2D


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("  ok   " if ok else "  FAIL ", label)
	if not ok:
		failures += 1


func frames(n := 3) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _run() -> void:
	root.size = Vector2i(1152, 648)
	await process_frame
	gs = root.get_node("GameState")
	controls = root.get_node("Controls")
	gs.new_game()
	gs.in_game = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(10)
	world.fader.set_alpha(0.0)
	world.set_process(false)
	var player: Node2D = world.player
	player.global_position = Vector2(5.5, 14.5) * 32.0
	player.set_physics_process(false)
	var crosshair: CanvasLayer
	for child in player.get_children():
		if child.get_script() == load("res://scripts/ui/crosshair.gd"):
			crosshair = child
	check(crosshair != null and crosshair.canvas.mouse_filter == Control.MOUSE_FILTER_IGNORE, "richtkruis bestaat en blokkeert geen muisklikken")
	controls.mouse_aim_active = false
	player.facing = Vector2.LEFT
	player._update_aim()
	check(player.aim_position.is_equal_approx(player.global_position + Vector2(-90, 0)), "zonder muis of stick staat het richtkruis in de kijkrichting")

	# Rechterstick omhoog richten terwijl de linkerstick naar rechts loopt.
	var pad := InputEventJoypadMotion.new()
	pad.axis = JOY_AXIS_RIGHT_Y
	pad.axis_value = -1.0
	root.push_input(pad)
	Input.action_press("aim_up")
	Input.action_press("move_right")
	player.set_physics_process(true)
	var before: Vector2 = player.global_position
	await frames(5)
	Input.action_release("move_right")
	Input.action_release("aim_up")
	player.set_physics_process(false)
	check(player.global_position.x > before.x and player.facing.is_equal_approx(Vector2.RIGHT) and player.aim_direction.is_equal_approx(Vector2.UP) and player._direction_row() == 2, "lichaam loopt naar rechts terwijl de rechterstick omhoog richt")
	player._update_aim()
	check(player.facing.is_equal_approx(Vector2.RIGHT) and player.aim_direction.is_equal_approx(Vector2.UP), "loslaten rechterstick bewaart mikrichting en laatste looprichting afzonderlijk")
	world.hud._show_game_over()
	check(not world.hud.overlay_sub.text.contains("voor het menu"), "controller toont geen conflicterende Start-knop als pauzeknop na verlies")
	world.hud.overlay.visible = false
	gs.inventory = {"bow": 1, "arrow": 5}
	player.bow_cooldown = 0.0
	player._shoot()
	var arrows := get_nodes_in_group("arrows")
	if arrows.is_empty():
		for child in world.entities.get_children():
			if child.get_script() == load("res://scripts/entities/arrow.gd"):
				arrows.append(child)
	check(gs.count("arrow") == 4 and not arrows.is_empty() and arrows[-1].direction.is_equal_approx(Vector2.UP), "echte boogpijl volgt het richtkruis")
	var left := InputEventJoypadMotion.new()
	left.axis = JOY_AXIS_LEFT_X
	left.axis_value = -1.0
	check(controls.rebind("bow", "controller", left, false) == "", "boog kan aan een negatieve stickrichting gekoppeld worden")
	check(player._bow_pressed(left) and not player._bow_pressed(left), "negatieve richtingskoppeling vuurt precies eenmaal per haal")
	left.axis_value = 1.0
	check(not player._bow_pressed(left), "tegengestelde richting vuurt niet")
	left.axis_value = -1.0
	check(player._bow_pressed(left), "na loslaten werkt de negatieve richting opnieuw")
	controls.reset_bindings("controller", false)
	# Stoppen met verzamelen en mikken gebeuren binnen dezelfde actie, vóór
	# de eerste pijl/zwaardtreffer. De werkhouding kijkt juist de andere kant op.
	player.start_work_animation("mining", 1.35, player.global_position + Vector2(0, 20))
	player.bow_cooldown = 0.0
	var before_interrupt: int = gs.count("arrow")
	player._shoot()
	var interrupted_arrow: Node2D
	for child in world.entities.get_children():
		if child.get_script() == load("res://scripts/entities/arrow.gd"):
			interrupted_arrow = child
	check(not player.work_active and gs.count("arrow") == before_interrupt - 1 and interrupted_arrow != null and interrupted_arrow.direction.is_equal_approx(Vector2.UP), "eerste pijl na verzamelen volgt direct de opgeslagen stickrichting")
	player.start_work_animation("mining", 1.35, player.global_position + Vector2(0, 20))
	player.cooldown = 0.0
	player._attack()
	check(not player.work_active and player.attack_direction.is_equal_approx(Vector2.UP) and player.facing.is_equal_approx(Vector2.RIGHT), "eerste zwaardzwaai na verzamelen volgt de stickrichting zonder het lichaam te draaien")

	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(850, 320)
	mouse.global_position = mouse.position
	mouse.relative = Vector2(20, 0)
	Input.parse_input_event(mouse)
	await frames(1)
	player._update_aim()
	check(not controls.controller_active and controls.mouse_aim_active, "bewuste muisbeweging neemt richten over")
	var direction: Vector2 = (player.get_global_mouse_position() - player.global_position).normalized()
	check(player.aim_direction.is_equal_approx(direction) and player.facing.is_equal_approx(Vector2.RIGHT), "muisrichting houdt rekening met de wereldcamera zonder de looprichting te wijzigen")

	player.start_work_animation("mining", 1.35, player.global_position + Vector2(0, 20))
	check(player.work_active and player.work_facing.is_equal_approx(Vector2.DOWN) and player._direction_row() == 0 and player.facing.is_equal_approx(Vector2.RIGHT), "werkactie toont gereedschap bij de grondstof en onthoudt de laatste looprichting")
	player.start_work_animation("mining", 1.35, player.global_position - direction * 20.0)
	player.cooldown = 0.0
	player._attack()
	check(not player.work_active and player.attack_direction.is_equal_approx(direction) and player.facing.is_equal_approx(Vector2.RIGHT), "eerste zwaardzwaai onderbreekt werk en volgt het muismikpunt zonder de looprichting te wijzigen")
	player.start_work_animation("mining", 1.35, player.global_position - direction * 20.0)
	player.bow_cooldown = 0.0
	player._shoot()
	for child in world.entities.get_children():
		if child.get_script() == load("res://scripts/entities/arrow.gd"):
			interrupted_arrow = child
	check(not player.work_active and interrupted_arrow.direction.is_equal_approx(direction), "eerste pijl onderbreekt werk en volgt meteen het muismikpunt")
	player.start_work_animation("woodcutting", 1.1, player.global_position + Vector2(20, 0))
	player.roll_cooldown = 0.0
	player._roll()
	check(not player.work_active and player.roll_dir.is_equal_approx(Vector2.RIGHT), "ontwijken onderbreekt werk en volgt zonder loopinvoer de laatste looprichting")
	player.roll_timer = 0.0
	player.start_work_animation("foraging", 0.65, player.global_position + Vector2(0, 20))
	gs.set_ui("aim_test", true)
	await frames()
	check(not player.work_active and not crosshair.visible, "pauze annuleert werk en verbergt het richtkruis")
	gs.set_ui("aim_test", false)
	await frames()
	check(crosshair.visible, "richtkruis keert terug na het menu")
	await _test_opposite_aim(player)
	_test_equipment_combat(player)
	gs.inventory = {"potion": 1}
	gs.hp = 1
	player._drink()
	check(player.drink_anim > 0.0 and gs.hp > 1, "drankje speelt een korte drinkanimatie")
	world.queue_free()
	await frames()
	print("AIM ANIMATION OK" if failures == 0 else "AIM ANIMATION MISLUKT: %d" % failures)
	quit(0 if failures == 0 else 1)


func axis(code: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	Input.parse_input_event(event)


func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _test_opposite_aim(player: Node2D) -> void:
	# Echte muis-/stickevents en echte vijanden: de speler loopt van zijn doel weg,
	# maar het zwaard en de pijl raken nog steeds aan de kant van het richtkruis.
	for use_pad in [false, true]:
		player.global_position = Vector2(8.5, 14.5) * 32.0
		player.camera.position_smoothing_enabled = false
		player.camera.reset_smoothing()
		player.roll_timer = 0.0
		player.knockback = Vector2.ZERO
		player.cancel_work_animation()
		gs.inventory = {"bow": 1, "arrow": 5}
		await frames(2)
		var device := "controller" if use_pad else "muis"
		if use_pad:
			axis(JOY_AXIS_RIGHT_Y, 0.0)
			axis(JOY_AXIS_RIGHT_X, -1.0)
			await frames()
			axis(JOY_AXIS_LEFT_X, 1.0)
		else:
			var mouse := InputEventMouseMotion.new()
			mouse.position = player.get_global_transform_with_canvas() * Vector2(-90, 0)
			mouse.global_position = mouse.position
			mouse.relative = Vector2(-20, 0)
			Input.parse_input_event(mouse)
			key(KEY_D, true)
		player.set_physics_process(true)
		var before: Vector2 = player.global_position
		await frames(4)
		check(player.global_position.x > before.x and player.facing.is_equal_approx(Vector2.RIGHT) and player._direction_row() == 2 and player.aim_direction.x < -0.99, device + ": rechts lopen kijkt rechts, ook met het richtkruis links")
		var shot_direction: Vector2 = player.aim_direction
		var aimed: Node2D = world.spawn_enemy("slime", player.global_position + shot_direction * 26.0)
		var behind: Node2D = world.spawn_enemy("slime", player.global_position - shot_direction * 26.0)
		aimed.set_physics_process(false)
		behind.set_physics_process(false)
		var original_hp: int = aimed.hp
		player.cooldown = 0.0
		player._attack()
		check(aimed.hp == original_hp - gs.damage() and behind.hp == original_hp and player.attack_direction.is_equal_approx(shot_direction), device + ": zwaard raakt de gerichte vijand achter de lopende speler")
		player.bow_cooldown = 0.0
		player._shoot()
		var arrow: Node2D
		for child in world.entities.get_children():
			if child.get_script() == load("res://scripts/entities/arrow.gd"):
				arrow = child
		check(arrow != null and arrow.direction.is_equal_approx(shot_direction) and player.bow_direction.is_equal_approx(shot_direction), device + ": echte pijl en boog wijzen naar het richtkruis")
		aimed.queue_free()
		behind.queue_free()
		await frames(2)
		check(player.attack_timer > 0.0 and player.bow_anim > 0.0 and player.facing.is_equal_approx(Vector2.RIGHT) and player._direction_row() == 2, device + ": lichaam blijft in looprichting tijdens zwaard- en booganimatie")
		if use_pad:
			axis(JOY_AXIS_LEFT_X, 0.0)
			axis(JOY_AXIS_LEFT_Y, -1.0)
		else:
			key(KEY_D, false)
			key(KEY_W, true)
		await frames(2)
		check(player.attack_timer > 0.0 and player.facing.is_equal_approx(Vector2.UP) and player._direction_row() == 1 and player.attack_direction.is_equal_approx(shot_direction) and player.bow_direction.is_equal_approx(shot_direction), device + ": draaien tijdens een aanval verandert het lichaam maar niet de gestarte zwaai of boog")
		if use_pad:
			axis(JOY_AXIS_LEFT_Y, 0.0)
			axis(JOY_AXIS_RIGHT_X, 0.0)
		else:
			key(KEY_W, false)
		await frames(3)
		check(not player.moving and player.facing.is_equal_approx(Vector2.UP) and player._direction_row() == 1 and player.aim_direction.x < -0.99, device + ": stilstaan bewaart de laatste looprichting onafhankelijk van mikken")
		player.set_physics_process(false)


func _test_equipment_combat(player: Node2D) -> void:
	var equipment: Script = load("res://scripts/core/equipment.gd")
	gs.give("gear_novice_gloves", 1, true)
	gs.give("gear_smith_gloves", 1, true)
	player.cooldown = 0.0
	player._attack()
	check(is_equal_approx(player.cooldown, player.ATTACK_COOLDOWN), "handschoenen in de tas veranderen de aanvalstijd niet")
	for option: Array in [["gear_novice_gloves", 0.92], ["gear_smith_gloves", 0.84]]:
		check(equipment.equip(option[0]), "handschoenen kunnen worden aangetrokken: " + option[0])
		player.cooldown = 0.0
		player._attack()
		check(is_equal_approx(player.cooldown, player.ATTACK_COOLDOWN * option[1]) and is_equal_approx(player.attack_timer, player.ATTACK_TIME), "aangetrokken handschoenen verkorten de echte wachttijd zonder de zwaai te versnellen")
	player._physics_process(0.30)
	player._attack()
	check(is_equal_approx(player.cooldown, player.ATTACK_COOLDOWN * 0.84), "smeedhandschoenen laten een volgende aanval al na 0,30 seconden toe")
	equipment.unequip("hands")
	player.cooldown = 0.0
	player._attack()
	check(is_equal_approx(player.cooldown, player.ATTACK_COOLDOWN), "handschoenen uitdoen herstelt de gewone wachttijd")
	gs.give("gear_iron_armor", 1, true)
	equipment.equip("gear_iron_armor")
	gs.hp = gs.max_hp()
	var before_hp: int = gs.hp
	player.invuln = 0.0
	player.hurt(player.global_position + Vector2.LEFT, 4, "armor_test")
	check(gs.hp == before_hp - 2 and gs.damage_log.get("armor_test", 0) == 2, "spelertreffer past harnas eenmaal toe en registreert de ontvangen schade")
	equipment.unequip("chest")
	player.knockback = Vector2.ZERO
