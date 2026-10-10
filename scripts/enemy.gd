extends CharacterBody2D
## Een slijm: dwaalt rond, jaagt op de speler als die dichtbij komt en laat munten vallen.

const DrawUtil := preload("res://scripts/draw_util.gd")
const Art := preload("res://scripts/art.gd")

const WANDER_SPEED := 35.0
const CHASE_SPEED := 62.0
const SIGHT := 120.0
const MAX_HP := 3
const TOUCH_RANGE := 17.0

var hp := MAX_HP
var wander_dir := Vector2.ZERO
var wander_timer := 0.0
var knockback := Vector2.ZERO
var flash := 0.0
var touch_cooldown := 0.0
var anim := randf() * TAU
var player: Node2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	shape.position = Vector2(0, 8) # botsing onderin
	add_child(shape)


func _physics_process(delta: float) -> void:
	anim += delta * 5.0
	flash = maxf(flash - delta, 0.0)
	touch_cooldown = maxf(touch_cooldown - delta, 0.0)

	if player == null:
		player = get_tree().get_first_node_in_group("player")

	var dir := Vector2.ZERO
	var speed := WANDER_SPEED
	var to_player := Vector2.INF
	if player and not GameState.ended:
		to_player = player.global_position - global_position

	if to_player.length() < SIGHT:
		dir = to_player.normalized()
		speed = CHASE_SPEED
	else:
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(0.8, 2.0)
			wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
		dir = wander_dir

	velocity = dir * speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()

	if to_player.length() < TOUCH_RANGE and touch_cooldown <= 0.0:
		touch_cooldown = 0.8
		player.hurt(global_position)
	queue_redraw()


## Wordt aangeroepen door het zwaard van de speler.
func hurt(damage: int, direction: Vector2) -> void:
	hp -= damage
	knockback = direction.normalized() * 240.0
	flash = 0.15
	if hp <= 0:
		_die()
	else:
		Sound.play("hit", -2.0, randf_range(0.9, 1.1))


func _die() -> void:
	Sound.play("die", -2.0, randf_range(0.9, 1.1))
	var world := get_parent()
	world.spawn_pickup("coin", global_position)
	if randf() < 0.25:
		world.spawn_pickup("heart", global_position + Vector2(10, 4))
	queue_free()


func _draw() -> void:
	DrawUtil.ellipse(self, Vector2(0, 14), Vector2(10, 3.5), Color(0, 0, 0, 0.3))
	var chasing := player != null and player.global_position.distance_to(global_position) < SIGHT
	# slime.png: kolom 0-1 = rustig (twee frames), kolom 2-3 = boos.
	var column := int(anim * 0.6) % 2 + (2 if chasing else 0)
	var tint := Color(3, 3, 3) if flash > 0.0 else Color.WHITE # wit oplichten bij een klap
	DrawUtil.sprite(self, Art.tex("slime"), column, 0, Vector2.ZERO, Vector2i(16, 16), 2.0, tint)
