extends CharacterBody2D
## Een vijand. Het soort (kind) bepaalt de eigenschappen (scripts/data/enemies.gd) en het gedrag:
## chase (slijm), bat (vleermuis), archer (skelet), golem (minibaas) en king (eindbaas).

signal died

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Enemies := preload("res://scripts/data/enemies.gd")

var kind := "slime"
var data: Dictionary = {}
var world: Node
var unique_flag := "" # deze vlag wordt gezet als de vijand verslagen is (voor bazen)
var hp := 1
var max_hp := 1
var radius := 7.0
var active := true # bazen wachten tot ze geactiveerd worden
var player: Node2D
var knockback := Vector2.ZERO
var desired := Vector2.ZERO
var flash := 0.0
var touch_cooldown := 0.0
var anim := randf() * TAU
var t := 0.0
var state := "idle"
var state_time := randf_range(0.0, 1.0)
var aim_dir := Vector2.DOWN
var wander_dir := Vector2.ZERO
var wander_timer := 0.0
var strafe := 1.0
var air_height := 0.0
var hop_from := Vector2.ZERO
var hop_to := Vector2.ZERO
var hop_count := 0
var slam_ring := 0.0
var dead := false


func setup(enemy_kind: String, flag := "") -> void:
	kind = enemy_kind
	data = Enemies.info(kind)
	unique_flag = flag
	max_hp = data["hp"]
	hp = max_hp
	radius = data["radius"]
	active = not data.get("start_inactive", false)


func _ready() -> void:
	if data.is_empty():
		setup(kind)
	add_to_group("enemies")
	if data.get("boss", false):
		add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	shape.position = Vector2(0, _size_px() * 0.28)
	add_child(shape)


func _size_px() -> float:
	return float(data["cell"]) * float(data["scale"])


func activate() -> void:
	active = true


func _physics_process(delta: float) -> void:
	t += delta
	anim += delta * 5.0
	flash = maxf(flash - delta, 0.0)
	touch_cooldown = maxf(touch_cooldown - delta, 0.0)
	slam_ring = maxf(slam_ring - delta, 0.0)
	if player == null:
		player = Util.player(self)
	if dead or player == null or GameState.ended or not active:
		velocity = Vector2.ZERO
		queue_redraw()
		return

	state_time += delta
	desired = Vector2.ZERO
	match data["behavior"]:
		"chase":
			_ai_chase(delta)
		"bat":
			_ai_bat(delta)
		"archer":
			_ai_archer(delta)
		"golem":
			_ai_golem(delta)
		"king":
			_ai_king(delta)

	velocity = desired + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()

	var touch_range: float = radius + 9.0
	if kind == "king" and state == "hop":
		touch_range = 0.0 # in de lucht kan hij niemand raken
	if global_position.distance_to(player.global_position) < touch_range and touch_cooldown <= 0.0:
		touch_cooldown = 0.8
		player.hurt(global_position, data["damage"])
	queue_redraw()


func _to_player() -> Vector2:
	return player.global_position - global_position


func _wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.8, 2.0)
		wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
	desired = wander_dir * data["speed"]


# --- Gedrag ---------------------------------------------------------------------

func _ai_chase(delta: float) -> void:
	var to_player := _to_player()
	if to_player.length() < data["sight"]:
		desired = to_player.normalized() * data["chase_speed"]
	else:
		_wander(delta)


func _ai_bat(delta: float) -> void:
	var to_player := _to_player()
	match state:
		"idle":
			if to_player.length() > data["sight"]:
				_wander(delta)
			else:
				# Eromheen cirkelen tot de bat besluit aan te vallen.
				var around := to_player.orthogonal().normalized() * strafe
				desired = (around * 0.8 + to_player.normalized() * (0.3 if to_player.length() > 90.0 else -0.4)).normalized() * data["speed"]
				if state_time > randf_range(1.2, 2.2):
					state = "telegraph"
					state_time = 0.0
					aim_dir = to_player.normalized()
		"telegraph":
			aim_dir = to_player.normalized()
			if state_time > 0.35:
				state = "dash"
				state_time = 0.0
		"dash":
			desired = aim_dir * 210.0
			if state_time > 0.45:
				state = "retreat"
				state_time = 0.0
				strafe = -strafe
		"retreat":
			desired = -to_player.normalized() * data["speed"]
			if state_time > 0.7:
				state = "idle"
				state_time = 0.0


func _ai_archer(delta: float) -> void:
	var to_player := _to_player()
	var dist := to_player.length()
	match state:
		"idle":
			if dist > data["sight"]:
				_wander(delta)
				return
			if dist < 75.0:
				desired = -to_player.normalized() * data["speed"] * 1.4
			elif dist > 150.0:
				desired = to_player.normalized() * data["chase_speed"]
			else:
				desired = to_player.orthogonal().normalized() * strafe * data["speed"] * 0.8
				if randf() < 0.01:
					strafe = -strafe
			if state_time > 2.2:
				state = "aim"
				state_time = 0.0
		"aim":
			aim_dir = to_player.normalized()
			if state_time > 0.55:
				Sound.play("arrow", -4.0)
				world.spawn_projectile("arrow", global_position, aim_dir, 150.0, data["damage"])
				state = "idle"
				state_time = 0.0


func _ai_golem(delta: float) -> void:
	var to_player := _to_player()
	var enraged := hp * 2 < max_hp
	match state:
		"idle":
			if to_player.length() < data["sight"]:
				desired = to_player.normalized() * data["chase_speed"] * (1.4 if enraged else 1.0)
			else:
				_wander(delta)
			if to_player.length() < 66.0 and state_time > 1.2:
				state = "windup"
				state_time = 0.0
		"windup":
			if state_time > (0.65 if enraged else 0.9):
				_golem_slam(enraged)
				state = "recover"
				state_time = 0.0
		"recover":
			if state_time > 0.9:
				state = "idle"
				state_time = 0.0


func _golem_slam(enraged: bool) -> void:
	Sound.play("slam")
	world.shake(6.0)
	world.burst(global_position + Vector2(0, 14), Color(0.8, 0.85, 1.0), 14)
	world.ring(global_position + Vector2(0, 14), 56.0, Color(0.7, 0.85, 1.0))
	slam_ring = 0.3
	if global_position.distance_to(player.global_position) < 56.0:
		player.hurt(global_position, data["damage"])
	if enraged:
		for i in 6:
			world.spawn_projectile("rock", global_position, Vector2.from_angle(TAU * float(i) / 6.0 + 0.3), 95.0, 1)


# --- De Slijmkoning ---------------------------------------------------------------

func _king_phase() -> int:
	var ratio := float(hp) / float(max_hp)
	if ratio > 0.65:
		return 1
	if ratio > 0.3:
		return 2
	return 3


func _ai_king(_delta: float) -> void:
	var phase := _king_phase()
	var to_player := _to_player()
	match state:
		"idle":
			if state_time > (0.9 if phase == 1 else 0.6 if phase == 2 else 0.4):
				state = "crouch"
				state_time = 0.0
		"crouch":
			if state_time > (0.5 if phase < 3 else 0.35):
				state = "hop"
				state_time = 0.0
				hop_from = global_position
				hop_to = global_position + to_player + player.velocity * 0.35
				hop_to = world.clamp_to_map(hop_to)
		"hop":
			var duration := 0.8 if phase < 3 else 0.6
			var p := clampf(state_time / duration, 0.0, 1.0)
			air_height = sin(p * PI) * 52.0
			global_position = hop_from.lerp(hop_to, p)
			if p >= 1.0:
				air_height = 0.0
				_king_land(phase)
				state = "land"
				state_time = 0.0
		"land":
			if state_time > 0.5:
				state = "idle"
				state_time = 0.0


func _king_land(phase: int) -> void:
	hop_count += 1
	var shock := 64.0 if phase == 1 else 74.0 if phase == 2 else 86.0
	Sound.play("slam")
	world.shake(7.0)
	world.burst(global_position + Vector2(0, 30), Color(0.5, 0.95, 0.55), 16)
	world.ring(global_position + Vector2(0, 30), shock, Color(0.5, 0.95, 0.55))
	slam_ring = 0.35
	if global_position.distance_to(player.global_position) < shock:
		player.hurt(global_position, data["damage"])
	var minions := 0
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and enemy.kind == "slime":
			minions += 1
	if (phase == 1 and hop_count % 3 == 0) or (phase == 3 and hop_count % 2 == 0):
		if minions < 4:
			for i in 2:
				world.spawn_enemy("slime", world.clamp_to_map(global_position + Vector2.from_angle(randf() * TAU) * 60.0))
	if phase >= 2:
		var bullets := 3 if phase == 2 else 5
		var to_player := _to_player().normalized()
		for i in bullets:
			var spread := (float(i) - float(bullets - 1) / 2.0) * 0.3
			world.spawn_projectile("slimeball", global_position, to_player.rotated(spread), 115.0, 1)


# --- Schade en dood ---------------------------------------------------------------

## Wordt aangeroepen door het zwaard van de speler.
func hurt(damage: int, direction: Vector2) -> void:
	if dead or not active:
		return
	if kind == "king" and state == "hop":
		return # in de lucht
	hp -= damage
	knockback = direction.normalized() * float(data.get("knockback", 240.0))
	flash = 0.15
	world.damage_number(global_position + Vector2(0, -_size_px() * 0.35), str(damage), Color(1, 0.95, 0.6))
	world.burst(global_position, Color(1, 1, 1), 5)
	if hp <= 0:
		_die()
	else:
		Sound.play("hit", -2.0, randf_range(0.9, 1.1))


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	GameState.kills += 1
	Sound.play("die", -2.0, randf_range(0.9, 1.1))
	world.burst(global_position, Color(0.7, 1.0, 0.7), 16)
	if unique_flag != "":
		GameState.set_flag(unique_flag)
	for drop: Array in data["drops"]:
		if randf() < drop[1]:
			for i in int(drop[2]):
				world.spawn_pickup(drop[0], global_position + Vector2(randf_range(-12, 12), randf_range(-6, 12)), "", true)
	died.emit()
	if kind == "king":
		_king_defeated()
	else:
		queue_free()


func _king_defeated() -> void:
	# De minions verdwijnen, de baas ontploft in een vuurwerk en dan begint het einde.
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	world.shake(10.0)
	for i in 8:
		world.burst(global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30)), Color(0.5, 1.0, 0.6), 14)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.6)
	tween.tween_callback(func() -> void:
		GameState.run(["ending"])
		queue_free())


# --- Tekenen ------------------------------------------------------------------------

func _draw() -> void:
	var size := _size_px()
	var scale: float = data["scale"]
	var cell := Vector2i(int(data["cell"]), int(data["cell"]))
	var tint := Color(3, 3, 3) if flash > 0.0 else Color.WHITE
	var sheet := Art.tex(data["sheet"])
	var shadow: float = data["shadow"]
	var chasing: bool = player != null and active and _to_player().length() < float(data["sight"])

	match data["behavior"]:
		"chase":
			DrawUtil.ellipse(self, Vector2(0, size * 0.44), Vector2(shadow, shadow * 0.35), Color(0, 0, 0, 0.3))
			var column := int(anim * 0.6) % 2 + (2 if chasing else 0)
			DrawUtil.sprite(self, sheet, column, 0, Vector2.ZERO, cell, scale, tint)
		"bat":
			var hover := -6.0 + sin(t * 6.0) * 3.0
			DrawUtil.ellipse(self, Vector2(0, size * 0.44), Vector2(shadow, shadow * 0.35), Color(0, 0, 0, 0.25))
			var column := 2 if state == "dash" else int(t * 12.0) % 2
			if state == "telegraph" and int(t * 20.0) % 2 == 0:
				tint = Color(2.5, 1.2, 1.2)
			DrawUtil.sprite(self, sheet, column, 0, Vector2(0, hover), cell, scale, tint)
		"archer":
			DrawUtil.ellipse(self, Vector2(0, size * 0.44), Vector2(shadow, shadow * 0.35), Color(0, 0, 0, 0.3))
			var face := _to_player() if player else Vector2.DOWN
			var row := 0
			if absf(face.y) > absf(face.x):
				row = 0 if face.y > 0.0 else 1
			else:
				row = 2 if face.x > 0.0 else 3
			var column := 3 if state == "aim" else (1 + int(anim * 0.8) % 2 if desired != Vector2.ZERO else 0)
			DrawUtil.sprite(self, sheet, column, row, Vector2.ZERO, cell, scale, tint)
			if state == "aim":
				DrawUtil.prompt(self, Vector2(0, -size * 0.55), t, "!")
		"golem":
			DrawUtil.ellipse(self, Vector2(0, size * 0.44), Vector2(shadow, shadow * 0.35), Color(0, 0, 0, 0.3))
			var column := int(anim * 0.4) % 2
			if state == "windup":
				column = 2
			elif state == "recover" and state_time < 0.4:
				column = 3
			var offset := Vector2.ZERO
			if state == "windup":
				offset = Vector2(randf_range(-1.0, 1.0), 0.0) * 1.5
				draw_arc(Vector2(0, size * 0.3), 56.0 * clampf(state_time / 0.9, 0.0, 1.0), 0.0, TAU, 32, Color(1, 0.3, 0.3, 0.6), 3.0)
			DrawUtil.sprite(self, sheet, column, 0, offset, cell, scale, tint)
		"king":
			var lift := air_height
			DrawUtil.ellipse(self, Vector2(0, size * 0.44), Vector2(shadow * (1.0 - lift / 160.0), shadow * 0.35), Color(0, 0, 0, 0.3))
			var column := int(anim * 0.5) % 2
			if state == "crouch" or state == "land":
				column = 2
			elif state == "hop":
				column = 3
			if _king_phase() == 3 and active and int(t * 6.0) % 2 == 0 and flash <= 0.0:
				tint = Color(1.5, 0.8, 0.8)
			DrawUtil.sprite(self, sheet, column, 0, Vector2(0, -lift), cell, scale, tint)
			if state == "crouch":
				var shock := 64.0 if _king_phase() == 1 else 74.0 if _king_phase() == 2 else 86.0
				draw_arc(Vector2(0, size * 0.3), shock * 0.5, 0.0, TAU, 32, Color(1, 0.3, 0.3, 0.35), 3.0)
