extends CharacterBody2D
## De speler: lopen (WASD/pijltjes), zwaard (spatie/J), rollen (Shift/K), praten en openen (E),
## drankje drinken (H).

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Items := preload("res://scripts/data/items.gd")

const SPEED := 110.0
const ROLL_SPEED := 235.0
const ROLL_TIME := 0.3
const ROLL_COOLDOWN := 0.7
const ROLL_SAFE_TIME := 0.24
const ATTACK_TIME := 0.18
const ATTACK_COOLDOWN := 0.35
const INVULN_TIME := 1.0
const INTERACT_RANGE := 40.0

var world: Node
var facing := Vector2.DOWN
var attack_timer := 0.0
var cooldown := 0.0
var invuln := 0.0
var knockback := Vector2.ZERO
var walk_time := 0.0
var moving := false
var roll_timer := 0.0
var roll_cooldown := 0.0
var roll_dir := Vector2.DOWN
var target: Node2D # het dichtstbijzijnde ding waar je mee kunt praten of dat je kunt openen
var camera: Camera2D
var light: PointLight2D
var shake_power := 0.0
var time := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	shape.position = Vector2(0, 8) # botsing bij de voeten
	add_child(shape)

	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	add_child(camera)

	light = PointLight2D.new()
	light.texture = Art.light_texture()
	light.texture_scale = 3.2
	light.energy = 1.0
	light.color = Color(1.0, 0.92, 0.75)
	light.enabled = false
	add_child(light)


func is_rolling() -> bool:
	return roll_timer > 0.0


func _physics_process(delta: float) -> void:
	time += delta
	var dir := Vector2.ZERO
	if not GameState.input_locked():
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = dir != Vector2.ZERO

	if roll_timer > 0.0:
		velocity = roll_dir * ROLL_SPEED
	else:
		if moving:
			facing = dir.normalized()
			walk_time += delta
		velocity = dir * SPEED * GameState.speed_multiplier() + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

	roll_timer = maxf(roll_timer - delta, 0.0)
	roll_cooldown = maxf(roll_cooldown - delta, 0.0)
	attack_timer = maxf(attack_timer - delta, 0.0)
	cooldown = maxf(cooldown - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)

	_update_target()
	_update_shake(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.input_locked():
		return
	if event.is_action_pressed("attack"):
		_attack()
	elif event.is_action_pressed("dodge"):
		_roll()
	elif event.is_action_pressed("interact"):
		if target and is_instance_valid(target):
			target.interact()
	elif event.is_action_pressed("potion"):
		_drink()


func _roll() -> void:
	if roll_cooldown > 0.0 or roll_timer > 0.0:
		return
	attack_timer = 0.0 # rollen onderbreekt een zwaardzwaai
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	roll_dir = dir.normalized() if dir != Vector2.ZERO else facing
	facing = roll_dir
	roll_timer = ROLL_TIME
	roll_cooldown = ROLL_COOLDOWN
	Sound.play("dodge", -3.0, randf_range(0.95, 1.05))


func _attack() -> void:
	if cooldown > 0.0 or roll_timer > 0.0:
		return
	attack_timer = ATTACK_TIME
	cooldown = ATTACK_COOLDOWN
	Sound.play("swing", -4.0, randf_range(0.92, 1.08))
	var reach := GameState.reach()
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		var to_enemy := enemy.global_position - global_position
		var margin: float = enemy.radius
		if to_enemy.length() <= reach + margin and facing.dot(to_enemy.normalized()) > 0.2:
			enemy.hurt(GameState.damage(), facing)
	# Wat je kunt stukslaan (zoals de tovervonk van een Magiër) bepaalt zelf of je zwaard het raakt.
	for thing: Node in get_tree().get_nodes_in_group("breakable"):
		thing.sword_hit(global_position, facing, reach)


func _drink() -> void:
	if GameState.use_potion():
		Sound.play("drink")
		if world:
			world.damage_number(global_position + Vector2(0, -18), "+", Color(0.5, 1.0, 0.6))
			world.burst(global_position, Color(0.5, 1.0, 0.6), 10)
	elif GameState.count("potion") > 0:
		GameState.toast.emit("Je hebt al alle hartjes.")
	else:
		GameState.toast.emit("Je hebt geen helddrank.")


func _update_target() -> void:
	target = null
	if GameState.input_locked():
		return
	var best := INTERACT_RANGE
	for node: Node2D in get_tree().get_nodes_in_group("interactable"):
		var d := node.global_position.distance_to(global_position)
		if d < best:
			best = d
			target = node


## Wordt aangeroepen door vijanden en projectielen.
func hurt(from_pos: Vector2, amount: int = 1, source := "") -> void:
	if invuln > 0.0 or GameState.ended or (roll_timer > ROLL_TIME - ROLL_SAFE_TIME):
		return
	GameState.last_damage_source = source
	GameState.damage_log[source] = int(GameState.damage_log.get(source, 0)) + amount
	GameState.hurt(amount)
	Sound.play("hurt")
	invuln = INVULN_TIME
	knockback = (global_position - from_pos).normalized() * 260.0
	shake(5.0)
	if world:
		world.hitstop(0.07)


func shake(power: float) -> void:
	shake_power = maxf(shake_power, power)


func _update_shake(delta: float) -> void:
	if shake_power > 0.05:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_power
		shake_power = move_toward(shake_power, 0.0, 24.0 * delta)
	else:
		camera.offset = Vector2.ZERO


func set_lit(on: bool) -> void:
	light.enabled = on


## Rij in player.png: 0 = naar beneden, 1 = omhoog, 2 = rechts, 3 = links.
func _direction_row() -> int:
	if absf(facing.y) > absf(facing.x):
		return 0 if facing.y > 0.0 else 1
	return 2 if facing.x > 0.0 else 3


func _draw() -> void:
	# Knipperen als we net geraakt zijn.
	if invuln > 0.0 and int(invuln * 12.0) % 2 == 0:
		return
	DrawUtil.ellipse(self, Vector2(0, 14), Vector2(9, 3.5), Color(0, 0, 0, 0.3))
	var column := 1 + int(walk_time * 9.0) % 2 if moving else 0
	var tint := Color(1, 1, 1, 0.8) if roll_timer > ROLL_TIME - ROLL_SAFE_TIME else Color.WHITE
	if roll_timer > 0.0:
		# Rollen: het hele poppetje draait een rondje.
		var progress := 1.0 - roll_timer / ROLL_TIME
		draw_set_transform(Vector2(0, 4), progress * TAU * signf(roll_dir.x if roll_dir.x != 0.0 else 1.0), Vector2.ONE)
		DrawUtil.sprite(self, Art.tex("player"), 1, _direction_row(), Vector2(0, -4), Vector2i(16, 16), 2.0, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		DrawUtil.sprite(self, Art.tex("player"), column, _direction_row(), Vector2.ZERO, Vector2i(16, 16), 2.0, tint)
	if attack_timer > 0.0:
		_draw_sword()
	if target and is_instance_valid(target) and not GameState.input_locked():
		pass # het bolletje wordt door het ding zelf getekend


func _draw_sword() -> void:
	var weapon: Dictionary = Items.WEAPONS[GameState.weapon]
	var reach: float = weapon["reach"]
	var color: Color = weapon["color"]
	var progress := 1.0 - attack_timer / ATTACK_TIME
	var angle := facing.angle() - 1.0 + progress * 2.0
	draw_arc(Vector2.ZERO, reach - 4.0, angle - 0.55, angle + 0.55, 10, Color(color, 0.55), 6.0)
	var hilt := Vector2.from_angle(angle) * 8.0
	var tip := Vector2.from_angle(angle) * (reach - 6.0)
	draw_line(Vector2.ZERO, hilt, Color(0.45, 0.3, 0.15), 4.0)
	draw_line(hilt, tip, color, 4.0)
	draw_line(hilt, tip, Color(1, 1, 1, 0.7), 1.5)
	draw_line(hilt + Vector2.from_angle(angle + PI / 2.0) * 4.0, hilt + Vector2.from_angle(angle - PI / 2.0) * 4.0,
		Color(0.9, 0.75, 0.3), 3.0)
