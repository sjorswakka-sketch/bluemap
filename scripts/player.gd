extends CharacterBody2D
## De speler: lopen (WASD/pijltjes), zwaard (spatie/J) en praten (E/Enter).

const DrawUtil := preload("res://scripts/draw_util.gd")
const Art := preload("res://scripts/art.gd")

const SPEED := 110.0
const ATTACK_TIME := 0.18
const ATTACK_COOLDOWN := 0.35
const ATTACK_RANGE := 34.0
const INVULN_TIME := 1.0
const INTERACT_RANGE := 44.0

var facing := Vector2.DOWN
var attack_timer := 0.0
var cooldown := 0.0
var invuln := 0.0
var knockback := Vector2.ZERO
var walk_time := 0.0
var moving := false
var camera: Camera2D


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


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not GameState.dialogue_open and not GameState.ended:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = dir != Vector2.ZERO
	if moving:
		facing = dir.normalized()
		walk_time += delta

	velocity = dir * SPEED + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

	attack_timer = maxf(attack_timer - delta, 0.0)
	cooldown = maxf(cooldown - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.dialogue_open or GameState.ended:
		return
	if event.is_action_pressed("attack"):
		_attack()
	elif event.is_action_pressed("interact"):
		_interact()


func _attack() -> void:
	if cooldown > 0.0:
		return
	attack_timer = ATTACK_TIME
	cooldown = ATTACK_COOLDOWN
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		var to_enemy := enemy.global_position - global_position
		if to_enemy.length() <= ATTACK_RANGE and facing.dot(to_enemy.normalized()) > 0.3:
			enemy.hurt(1, facing)


func _interact() -> void:
	var best: Node2D = null
	var best_dist := INTERACT_RANGE
	for npc: Node2D in get_tree().get_nodes_in_group("npc"):
		var d := npc.global_position.distance_to(global_position)
		if d < best_dist:
			best = npc
			best_dist = d
	if best:
		best.interact()


## Wordt aangeroepen door vijanden. `from_pos` bepaalt de richting van de terugslag.
func hurt(from_pos: Vector2) -> void:
	if invuln > 0.0 or GameState.ended:
		return
	GameState.hurt(1)
	invuln = INVULN_TIME
	knockback = (global_position - from_pos).normalized() * 260.0


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
	# Kolom 0 = stilstaan, kolom 1 en 2 = om en om een stap.
	var column := 1 + int(walk_time * 9.0) % 2 if moving else 0
	DrawUtil.sprite(self, Art.tex("player"), column, _direction_row())
	# Zwaardzwaai.
	if attack_timer > 0.0:
		var progress := 1.0 - attack_timer / ATTACK_TIME
		var angle := facing.angle() - 1.0 + progress * 2.0
		draw_arc(Vector2.ZERO, ATTACK_RANGE - 4.0, angle - 0.5, angle + 0.5, 10, Color(0.9, 0.95, 1.0, 0.9), 5.0)
		draw_line(Vector2.ZERO, Vector2.from_angle(angle) * (ATTACK_RANGE - 6.0), Color(0.85, 0.9, 1.0), 3.0)
