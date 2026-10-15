extends CharacterBody2D
## De speler: lopen (WASD/pijltjes), zwaard (spatie/J), boog (F/L), rollen (Shift/K), praten en openen (E),
## drankje drinken (H), rennen (Ctrl vasthouden / linker stick indrukken).
## Equipment is altijd zichtbaar op het character.

signal footstep(surface: String)

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const AppearanceDraw := preload("res://scripts/core/appearance_draw.gd")
const Art := preload("res://scripts/core/art.gd")
const Items := preload("res://scripts/data/items.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const ArrowScript := preload("res://scripts/entities/arrow.gd")
const CrosshairScript := preload("res://scripts/ui/crosshair.gd")

const SPEED := 110.0
const ROLL_SPEED := 235.0
const ROLL_TIME := 0.3
const ROLL_COOLDOWN := 0.7
const ROLL_SAFE_TIME := 0.24
const ATTACK_TIME := 0.18
const ATTACK_COOLDOWN := 0.35
const INVULN_TIME := 1.0
const INTERACT_RANGE := 40.0
const FOOT_OFFSET := Vector2(0, 8)
const STEP_DISTANCE := 22.0

var world: Node
var facing := Vector2.DOWN
var aim_direction := Vector2.DOWN
var attack_direction := Vector2.DOWN
var bow_direction := Vector2.DOWN
var work_facing := Vector2.DOWN
var attack_timer := 0.0
var cooldown := 0.0
var invuln := 0.0
var knockback := Vector2.ZERO
var walk_time := 0.0
var moving := false
var sprinting := false
var step_distance := 0.0
var roll_timer := 0.0
var roll_cooldown := 0.0
var roll_dir := Vector2.DOWN
var target: Node2D
var camera: Camera2D
var light: PointLight2D
var shake_power := 0.0
var time := 0.0
var aim_position := Vector2.ZERO
var stick_aim := Vector2.ZERO
var work_active := false
var work_kind := ""
var work_elapsed := 0.0
var work_duration := 1.0
var drink_anim := 0.0
var combo_step := 0
var combo_window := 0.0
var combo_sweep := false
var combat := preload("res://scripts/entities/combat_actions.gd").new()

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	shape.position = Vector2(0, 8)
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
	_refresh_controls()
	Controls.bindings_changed.connect(_refresh_controls)
	Controls.device_changed.connect(_device_changed)
	var crosshair := CrosshairScript.new()
	crosshair.player = self
	add_child(crosshair)
	aim_position = global_position + facing * 90.0

func _refresh_controls() -> void:
	trigger_axis = -1
	trigger_sign = 1.0
	trigger_down = false
	for event in Controls.binding_events("bow", "controller"):
		if event is InputEventJoypadMotion:
			trigger_axis = event.axis
			trigger_sign = signf(event.axis_value)

func _device_changed(_controller: bool) -> void:
	combat.cancel()
	trigger_down = false
	stick_aim = Vector2.ZERO

func is_rolling() -> bool:
	return roll_timer > 0.0

func _physics_process(delta: float) -> void:
	combat.update(self, delta)
	time += delta
	combo_window = maxf(combo_window - delta, 0.0)
	if combo_window <= 0.0:
		combo_step = 0
	var dir := Vector2.ZERO
	var locked := GameState.input_locked()
	if not locked:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = dir != Vector2.ZERO
	if moving or locked:
		cancel_work_animation()
	if work_active:
		work_elapsed = minf(work_elapsed + delta, work_duration)
	drink_anim = maxf(drink_anim - delta, 0.0)
	var rolling := roll_timer > 0.0
	var pushed := knockback.length_squared() > 1.0
	var tile_name := ground_tile()
	var wants_sprint: bool = moving and not locked and not rolling and not pushed \
		and attack_timer <= 0.0 and bow_anim <= 0.0 and Input.is_action_pressed("sprint") \
		and GameState.movement.can_sprint() and not combat.busy()
	var run_multiplier: float = GameState.movement.sprint_multiplier(delta) if wants_sprint else 1.0
	if rolling:
		velocity = roll_dir * ROLL_SPEED
	else:
		if moving:
			facing = dir.normalized()
		velocity = dir * SPEED * GameState.speed_multiplier() * Tiles.movement_multiplier(tile_name) * run_multiplier + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	var before := global_position
	if combat.phase in ["prepare","guard","counter"]:
		velocity *= 0.35
		sprinting = false
	move_and_slide()
	var distance := (global_position - before).length()
	var walking := moving and not locked and not rolling and not pushed and distance > 4.0 * delta
	sprinting = wants_sprint and walking
	if not locked:
		GameState.movement.advance(delta, sprinting)
	if walking:
		walk_time += distance / SPEED
	_update_footsteps(distance, walking, ground_tile())
	roll_timer = maxf(roll_timer - delta, 0.0)
	roll_cooldown = maxf(roll_cooldown - delta, 0.0)
	attack_timer = maxf(attack_timer - delta, 0.0)
	cooldown = maxf(cooldown - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	bow_cooldown = maxf(bow_cooldown - delta, 0.0)
	bow_anim = maxf(bow_anim - delta, 0.0)
	no_arrows_toast = maxf(no_arrows_toast - delta, 0.0)
	_update_aim()
	_update_target()
	_update_shake(delta)
	queue_redraw()

func ground_tile() -> String:
	if not is_instance_valid(world):
		return ""
	return Tiles.name_at(world.map_data.get("rows", []), global_position + FOOT_OFFSET)

func _update_footsteps(distance: float, walking: bool, tile_name: String) -> void:
	var surface := Tiles.footstep_surface(tile_name)
	if not walking or surface == "":
		step_distance = 0.0
		return
	step_distance += distance
	if step_distance >= STEP_DISTANCE:
		step_distance = fmod(step_distance, STEP_DISTANCE)
		Sound.play("step_" + surface, -13.0 if sprinting else -17.0, randf_range(0.94, 1.06))
		footstep.emit(surface)

func _unhandled_input(event: InputEvent) -> void:
	if not Controls.allows_event(event) or event.is_echo():
		return
	var bow_pressed := _bow_pressed(event)
	if GameState.input_locked():
		return
	_update_aim()
	if bow_pressed:
		_shoot()
	elif event.is_action_pressed("attack"):
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
	cancel_work_animation()
	attack_timer = 0.0
	combo_step = 0
	combo_window = 0.0
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	roll_dir = dir.normalized() if dir != Vector2.ZERO else facing
	facing = roll_dir
	combat.cancel()
	roll_timer = ROLL_TIME
	roll_cooldown = ROLL_COOLDOWN
	GameState.note_roll()
	Sound.play("dodge", -3.0, randf_range(0.95, 1.05))

func _attack() -> void:
	if combat.counter(self):return
	if combat.busy(): return
	if Input.is_action_pressed("technique"):
		combat.begin(self, false)
		return
	if cooldown > 0.0 or roll_timer > 0.0:
		return
	cancel_work_animation()
	_update_aim()
	attack_direction = aim_direction
	combo_step = combo_step % 3 + 1 if combo_window > 0.0 else 1
	combo_window = 0.9
	combo_sweep = combo_step == 3 and GameState.movement.spend(18.0)
	attack_timer = ATTACK_TIME
	cooldown = ATTACK_COOLDOWN * GameState.attack_cooldown_multiplier()
	Sound.play("swing", -4.0, randf_range(0.92, 1.08))
	var reach := GameState.reach() + (8.0 if combo_sweep else 0.0)
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		var to_enemy := enemy.global_position - global_position
		var margin: float = enemy.radius
		if to_enemy.length() <= reach + margin and attack_direction.dot(to_enemy.normalized()) > (-0.35 if combo_sweep else 0.2) and _attack_clear(enemy.global_position):
			if combo_sweep and GameState.flag("lw_workshop") and enemy.has_method("break_guard"):
				enemy.break_guard()
			enemy.hurt(GameState.damage(), attack_direction)
	for thing: Node in get_tree().get_nodes_in_group("breakable"):
		if _attack_clear(thing.global_position):
			thing.sword_hit(global_position, attack_direction, reach)

func _attack_clear(target_position: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

const BOW_COOLDOWN := 0.4
const BOW_ANIM_TIME := 0.25
const NO_ARROWS_TOAST_TIME := 3.4
const ARROW_START := 12.0
const ARROW_HEIGHT := Vector2(0, 4)

var bow_cooldown := 0.0
var bow_anim := 0.0
var no_arrows_toast := 0.0
var trigger_axis := -1
var trigger_sign := 1.0
var trigger_down := false

func _bow_pressed(event: InputEvent) -> bool:
	if Controls.controller_active and event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == trigger_axis:
		var down := (event as InputEventJoypadMotion).axis_value * trigger_sign >= InputMap.action_get_deadzone("bow")
		var fresh := down and not trigger_down
		trigger_down = down
		return fresh
	return event.is_action_pressed("bow")

func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED:
		trigger_down = _trigger_held()
	elif what == NOTIFICATION_PAUSED:
		cancel_work_animation()
		combat.cancel()

func _trigger_held() -> bool:
	if trigger_axis < 0 or not Controls.controller_active:
		return false
	var device: int = Controls.controller_device
	return device in Input.get_connected_joypads() and Input.get_joy_axis(device, trigger_axis as JoyAxis) * trigger_sign >= InputMap.action_get_deadzone("bow")

func _lent_arrow() -> bool:
	var shooting_range: Node = get_tree().get_first_node_in_group("boog_range")
	return shooting_range != null and shooting_range.lends_arrows()

func _shoot(allow_technique := true, precise := false, locked_direction := Vector2.ZERO) -> void:
	if allow_technique and combat.busy(): return
	if allow_technique and Input.is_action_pressed("technique"):
		combat.begin(self, true)
		return
	if world == null or bow_cooldown > 0.0 or roll_timer > 0.0:
		return
	if GameState.count("bow") <= 0:
		if no_arrows_toast <= 0.0:
			no_arrows_toast = NO_ARROWS_TOAST_TIME
			GameState.toast.emit(tr("Je hebt een boog nodig. Tobias verkoopt er een."))
			Sound.play("error", -5.0)
		return
	cancel_work_animation()
	_update_aim()
	bow_cooldown = 0.8 if precise else BOW_COOLDOWN
	var lent := _lent_arrow()
	if GameState.count("arrow") <= 0 and not lent:
		Sound.play("error", -3.0)
		if no_arrows_toast <= 0.0:
			no_arrows_toast = NO_ARROWS_TOAST_TIME
			GameState.toast.emit(tr("Geen pijlen!"))
		return
	if not lent:
		GameState.take("arrow")
	bow_anim = BOW_ANIM_TIME
	bow_direction = locked_direction if precise else aim_direction
	var arrow: Node2D = ArrowScript.new()
	arrow.world = world
	arrow.direction = bow_direction
	arrow.precise = precise
	if precise:
		arrow.damage = 3
		arrow.speed = 420.0
		arrow.max_range = 400.0
	arrow.position = global_position + ARROW_HEIGHT
	world.entities.add_child(arrow)
	arrow.launch(ARROW_START)
	Sound.play("boog_twang", -3.0, randf_range(0.95, 1.05))
	world.burst(arrow.position, Color(1, 1, 1, 0.8), 3)

func _drink() -> void:
	if GameState.use_potion():
		cancel_work_animation()
		drink_anim = 0.6
		Sound.play("drink")
		if world:
			world.damage_number(global_position + Vector2(0, -18), "+", Color(0.5, 1.0, 0.6))
			world.burst(global_position, Color(0.5, 1.0, 0.6), 10)
	elif GameState.count("potion") > 0:
		GameState.toast.emit(tr("Je hebt al alle hartjes."))
	else:
		GameState.toast.emit(tr("Je hebt geen helddrank."))

func _update_target() -> void:
	target = null
	if GameState.input_locked():
		return
	var best := INF
	for node: Node2D in get_tree().get_nodes_in_group("interactable"):
		var d := node.global_position.distance_to(global_position)
		if d >= INTERACT_RANGE:
			continue
		var direction := (node.global_position - global_position).normalized()
		var aiming: bool = Controls.mouse_aim_active or (Controls.controller_active and stick_aim != Vector2.ZERO)
		var score := d + ((1.0 - aim_direction.dot(direction)) * 16.0 if aiming else 0.0)
		if score < best:
			best = score
			target = node

func _update_aim() -> void:
	if GameState.input_locked():
		return
	aim_direction = facing
	if Controls.controller_active:
		var stick: Vector2 = Controls.aim_vector()
		if stick.length_squared() > 0.01:
			stick_aim = stick.normalized()
		elif Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
			# Rechterstick neutraal en de linkerstick stuurt op dit moment: het richtkruis
			# laat los en de mikrichting volgt de nieuwe looprichting weer. Verse invoer
			# lezen (niet `moving`): die is tussen physics frames verouderd. Stilstaan
			# bewaart de mikrichting, zodat je stil kunt mikken en dan pas schieten.
			stick_aim = Vector2.ZERO
		if stick_aim != Vector2.ZERO:
			aim_direction = stick_aim
		aim_position = global_position + aim_direction * 90.0
	elif Controls.mouse_aim_active:
		aim_position = get_global_mouse_position()
		var direction := aim_position - global_position
		if direction.length_squared() > 16.0:
			aim_direction = direction.normalized()
	else:
		aim_position = global_position + aim_direction * 90.0

func start_work_animation(kind: String, duration: float, target_position: Vector2) -> void:
	work_kind = kind
	work_duration = maxf(duration, 0.01)
	work_elapsed = 0.0
	work_active = true
	work_facing = (target_position - global_position).normalized()
	if work_facing == Vector2.ZERO:
		work_facing = facing

func cancel_work_animation() -> void:
	work_active = false

func is_working() -> bool:
	return work_active

func hurt(from_pos: Vector2, amount: int = 1, source := "") -> void:
	if invuln > 0.0 or GameState.ended or (roll_timer > ROLL_TIME - ROLL_SAFE_TIME):
		return
	if combat.try_block(self,from_pos):return
	cancel_work_animation()
	combat.cancel()
	GameState.last_damage_source = source
	GameState.damage_log[source] = int(GameState.damage_log.get(source, 0)) + GameState.damage_after_armor(amount)
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

func set_lit(on: bool, energy := 1.0, scale := 3.2) -> void:
	light.enabled = on
	light.energy = energy
	light.texture_scale = scale

func _direction_row() -> int:
	var body_direction := work_facing if work_active else facing
	if absf(body_direction.y) > absf(body_direction.x):
		return 0 if body_direction.y > 0.0 else 1
	return 2 if body_direction.x > 0.0 else 3

func _draw() -> void:
	if invuln > 0.0 and int(invuln * 12.0) % 2 == 0:
		return
	DrawUtil.ellipse(self, Vector2(0, 14), Vector2(9, 3.5), Color(0, 0, 0, 0.3))
	var column := 1 + int(walk_time * 9.0) % 2 if moving else 0
	var tint := Color(1, 1, 1, 0.8) if roll_timer > ROLL_TIME - ROLL_SAFE_TIME else Color.WHITE
	if roll_timer > 0.0:
		var progress := 1.0 - roll_timer / ROLL_TIME
		draw_set_transform(Vector2(0, 4), progress * TAU * signf(roll_dir.x if roll_dir.x != 0.0 else 1.0), Vector2.ONE)
		var roll_origin := Vector2(0, -4) - Vector2(16, 16)
		AppearanceDraw.behind(self, roll_origin, 2.0, _direction_row(), GameState.clothing)
		DrawUtil.sprite(self, Art.tex("player"), 1, _direction_row(), Vector2(0, -4), Vector2i(16, 16), 2.0, tint)
		AppearanceDraw.front(self, roll_origin, 2.0, _direction_row(), 1, GameState.appearance, GameState.clothing)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var bob := sin(time * 2.4) * 0.55 if not moving else sin(walk_time * 18.0) * (1.6 if sprinting else 0.6)
		var lean := attack_direction * sin((1.0 - attack_timer / ATTACK_TIME) * PI) * 3.0 if attack_timer > 0.0 else Vector2.ZERO
		if work_active:
			bob = sin(work_elapsed * TAU * 3.0) * 1.5
		var origin := Vector2(0, bob) + lean - Vector2(16, 16)
		AppearanceDraw.behind(self, origin, 2.0, _direction_row(), GameState.clothing)
		DrawUtil.sprite(self, Art.tex("player"), column, _direction_row(), Vector2(0, bob) + lean, Vector2i(16, 16), 2.0, tint)
		AppearanceDraw.front(self, origin, 2.0, _direction_row(), column, GameState.appearance, GameState.clothing)
	_draw_equipped_gear()
	combat.draw(self)
	if sprinting:
		for i in 3:
			var phase := fmod(walk_time * 5.0 + i * 0.33, 1.0)
			draw_circle(Vector2(0, 12) - velocity.normalized() * (8.0 + phase * 13.0), 1.0 + phase, Color(0.85, 0.83, 0.68, (1.0 - phase) * 0.3))
	if work_active:
		_draw_work()
	if drink_anim > 0.0:
		var hand := Vector2(7, -5 + sin(drink_anim * PI / 0.6) * -3.0)
		draw_rect(Rect2(hand - Vector2(2, 3), Vector2(5, 7)), Color(0.95, 0.3, 0.5))
		draw_line(hand + Vector2(0, -5), hand + Vector2(2, -5), Color(0.9, 0.9, 1), 2.0)
	if attack_timer > 0.0:
		_draw_sword()
	if bow_anim > 0.0:
		_draw_bow()
	if target and is_instance_valid(target) and not GameState.input_locked():
		pass

func _draw_equipped_gear() -> void:
	var equipment: Script = preload("res://scripts/core/equipment.gd")
	var hands: String=equipment.equipped("hands")
	if hands in ["gear_cw_anchor","gear_cw_fan"]:
		var color:=Color("8bbcc7") if hands=="gear_cw_anchor" else Color("b8bd88")
		for x in [-11,9]:draw_rect(Rect2(x,3,4,5),color)
		if hands=="gear_cw_anchor":draw_arc(Vector2(-10,6),5,0,PI,8,Color("d6e0ca"),1)
	var chest: String = equipment.equipped("chest")
	if chest.begins_with("gear_pg_pack"):
		if _direction_row() == 1:
			draw_rect(Rect2(-7,-4,14,15),Color(0.69,0.53,0.31))
			for y in [0,4,8]: draw_line(Vector2(-6,y),Vector2(6,y),Color(0.88,0.72,0.44),1)
		else:
			draw_line(Vector2(-6,-3),Vector2(-4,9),Color(0.78,0.68,0.4),2)
			draw_line(Vector2(6,-3),Vector2(4,9),Color(0.78,0.68,0.4),2)
	if equipment.equipped("hands").begins_with("gear_pg_grip"):
		draw_rect(Rect2(-12,3,4,4),Color(0.9,0.72,0.4))
		draw_rect(Rect2(8,3,4,4),Color(0.9,0.72,0.4))
	if equipment.equipped("neck").begins_with("gear_pg_focus") and _direction_row() != 1:
		draw_circle(Vector2(0,4),2.5,Color(0.5,0.85,0.9))
	var weapon_id: String = str(GameState.get("weapon"))
	if weapon_id != "" and weapon_id != "null":
		var side := Vector2(10, 2) if facing.x >= 0 else Vector2(-10, 2)
		draw_line(side, side + Vector2(0, 8), Color(0.7, 0.7, 0.75), 2.0)
		draw_line(side + Vector2(0, 8), side + Vector2(3, 10), Color(0.9, 0.85, 0.4), 2.0)
	if GameState.count("bow") > 0:
		var side := Vector2(-8, 0) if facing.x >= 0 else Vector2(8, 0)
		draw_arc(side, 6.0, 0.4, PI - 0.4, 8, Color(0.6, 0.4, 0.2), 2.0)

func _draw_work() -> void:
	var phase := fmod(work_elapsed * 3.0, 1.0)
	var angle := work_facing.angle() - 0.95 + sin(phase * PI) * 1.8
	var hand := Vector2.from_angle(angle) * 8.0 + Vector2(0, 3)
	if work_kind == "foraging":
		draw_circle(hand + work_facing * sin(phase * PI) * 6.0, 2.5, Color(1, 0.77, 0.57))
	else:
		var tip := hand + Vector2.from_angle(angle) * 17.0
		var side := Vector2.from_angle(angle).orthogonal()
		draw_line(hand, tip, Color(0.45, 0.28, 0.13), 3.0)
		if work_kind == "repair":
			draw_arc(tip,5,angle+0.6,angle+TAU-0.6,12,Color("b7d0d0"),3)
		elif work_kind == "mining":
			draw_line(tip - side * 8.0, tip + side * 8.0, Color(0.7, 0.8, 0.86), 3.0)
		else:
			draw_colored_polygon(PackedVector2Array([tip - side * 2.0, tip + side * 8.0 - work_facing * 4.0, tip + side * 8.0 + work_facing * 4.0]), Color(0.72, 0.8, 0.85))
	var progress := clampf(work_elapsed / work_duration, 0.0, 1.0)
	draw_rect(Rect2(-14, -25, 28, 4), Color(0.03, 0.07, 0.1, 0.9))
	draw_rect(Rect2(-13, -24, 26.0 * progress, 2), Color(0.5, 0.92, 0.7))

func _draw_bow() -> void:
	var progress := 1.0 - bow_anim / BOW_ANIM_TIME
	var forward := bow_direction
	var sideways := forward.orthogonal()
	var grip := ARROW_HEIGHT + forward * 11.0
	var wood := Color(0.72, 0.5, 0.26)
	var points := PackedVector2Array()
	for i in 9:
		var s := float(i) / 8.0 * 2.0 - 1.0
		points.append(grip + sideways * s * 10.0 - forward * s * s * 5.0 + forward * 5.0)
	draw_polyline(points, Color(0.2, 0.12, 0.06), 5.0)
	draw_polyline(points, wood, 3.0)
	var wobble := sin(progress * 22.0) * (1.0 - progress) * 4.0
	var string_mid := grip + forward * wobble
	draw_line(points[0], string_mid, Color(1, 1, 1, 0.9), 1.0)
	draw_line(string_mid, points[8], Color(1, 1, 1, 0.9), 1.0)

func _draw_sword() -> void:
	var weapon: Dictionary = Items.WEAPONS[GameState.weapon]
	var reach: float = weapon["reach"]
	var color: Color = weapon["color"]
	var progress := 1.0 - attack_timer / ATTACK_TIME
	var arc := 3.8 if combo_sweep else 2.0
	var angle := attack_direction.angle() - arc * 0.5 + progress * arc
	if combo_sweep:
		reach += 8.0
		color = Color(0.5, 0.95, 1.0)
	draw_arc(Vector2.ZERO, reach - 4.0, angle - 0.55, angle + 0.55, 10, Color(color, 0.55), 6.0)
	var hilt := Vector2.from_angle(angle) * 8.0
	var tip := Vector2.from_angle(angle) * (reach - 6.0)
	draw_line(Vector2.ZERO, hilt, Color(0.45, 0.3, 0.15), 4.0)
	draw_line(hilt, tip, color, 4.0)
	draw_line(hilt, tip, Color(1, 1, 1, 0.7), 1.5)
	draw_line(hilt + Vector2.from_angle(angle + PI / 2.0) * 4.0, hilt + Vector2.from_angle(angle - PI / 2.0) * 4.0,
		Color(0.9, 0.75, 0.3), 3.0)
	if weapon.get("sparkle", false):
		_draw_sword_sparkles(angle, reach, progress)


## Sterretjes langs de zwaai van een bijzonder zwaard (het Sterrenzwaard).
func _draw_sword_sparkles(angle: float, reach: float, progress: float) -> void:
	for i in 4:
		var spread := angle - 0.55 + (progress * 0.5 + float(i) * 0.25) * 1.1
		var p := Vector2.from_angle(spread) * (reach - 2.0 - float(i) * 6.0)
		var size := 2.0 + float((i + int(progress * 4.0)) % 3)
		draw_line(p - Vector2(size, 0), p + Vector2(size, 0), Color(1, 1, 1, 0.9), 1.5)
		draw_line(p - Vector2(0, size), p + Vector2(0, size), Color(1, 1, 1, 0.9), 1.5)
