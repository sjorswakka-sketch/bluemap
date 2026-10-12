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
	check(player.global_position.x > before.x and player.facing.is_equal_approx(Vector2.UP), "lopen naar rechts en richten omhoog werken onafhankelijk")
	player._update_aim()
	check(player.facing.is_equal_approx(Vector2.UP), "loslaten rechterstick bewaart de gekozen richting")
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
	check(not player.work_active and player.facing.is_equal_approx(Vector2.UP), "eerste zwaardzwaai na verzamelen volgt direct de stickrichting")

	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(850, 320)
	mouse.global_position = mouse.position
	mouse.relative = Vector2(20, 0)
	root.push_input(mouse)
	player._update_aim()
	check(not controls.controller_active and controls.mouse_aim_active, "bewuste muisbeweging neemt richten over")
	var direction: Vector2 = (player.get_global_mouse_position() - player.global_position).normalized()
	check(player.facing.is_equal_approx(direction), "muisrichting houdt rekening met de wereldcamera")

	player.start_work_animation("mining", 1.35, player.global_position + Vector2(0, 20))
	check(player.work_active and player.facing.is_equal_approx(Vector2.DOWN), "werkactie toont gereedschap in de richting van de grondstof")
	player.start_work_animation("mining", 1.35, player.global_position - direction * 20.0)
	player.cooldown = 0.0
	player._attack()
	check(not player.work_active and player.facing.is_equal_approx(direction), "eerste zwaardzwaai onderbreekt werk en volgt meteen het muismikpunt")
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
	check(not player.work_active, "ontwijken onderbreekt de werkactie")
	player.roll_timer = 0.0
	player.start_work_animation("foraging", 0.65, player.global_position + Vector2(0, 20))
	gs.set_ui("aim_test", true)
	await frames()
	check(not player.work_active and not crosshair.visible, "pauze annuleert werk en verbergt het richtkruis")
	gs.set_ui("aim_test", false)
	await frames()
	check(crosshair.visible, "richtkruis keert terug na het menu")
	gs.inventory = {"potion": 1}
	gs.hp = 1
	player._drink()
	check(player.drink_anim > 0.0 and gs.hp > 1, "drankje speelt een korte drinkanimatie")
	world.queue_free()
	await frames()
	print("AIM ANIMATION OK" if failures == 0 else "AIM ANIMATION MISLUKT: %d" % failures)
	quit(0 if failures == 0 else 1)
