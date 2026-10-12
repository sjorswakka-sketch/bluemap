extends CharacterBody2D
## De Vergeten Wachter: de oude bewaker van de Sterrenkaart, de geheime eindbaas van de Diepte (Het Hart van de Kaart).
##
## Heeft dezelfde publieke eigenschappen als enemy.gd (groepen "enemies" en "boss", `kind`, `data`, `hp`, `max_hp`,
## `radius`, `active`, `dead`, `hurt(damage, direction)`, `activate()` en het signaal `died`), zodat het zwaard van de
## speler en de baasbalk in de HUD hem gewoon kennen. De wereld maakt hem aan via OBJECTS in scripts/data/ext/diepte.gd:
##   {"type": "guardian", "pos": [13, 4], "pillars": [[7, 5], ...], "chest": [13, 9]}
##
## Het gevecht heeft drie fases (op 66% en 33% van zijn levens):
##   1  Storm: een rode baan laat zien waar hij heen stormt. Botst hij tegen een muur of pilaar, dan is hij duizelig.
##      Klap: een rode cirkel groeit, daarna slaat hij neer.
##   2  De pilaren schieten ringen scherven met gaten. Rode lijnen laten de paden zien. Rol door de scherven of
##      loop door een gat.
##   3  Woede: alles sneller, de pilaren schieten twee ringen na elkaar en zijn klap schiet scherven weg.
## Na elke aanval is hij even kwetsbaar. Tijdens het wakker worden en de fasewissel is hij beschermd.

signal died

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const ChestScript := preload("res://scripts/entities/chest.gd")
const PillarScript := preload("res://scripts/entities/guardian_pillar.gd")
const ShardScript := preload("res://scripts/entities/guardian_shard.gd")

const TILE := 32.0
const STARTED_FLAG := "guardian_started" # gezet door de trigger in Het Hart van de Kaart: het gevecht begint
const DEFEATED_FLAG := "guardian_defeated"
const CHEST_KEY := "chest:depths2:heart" # onthoudt dat de hartcontainer-kist is geopend
const REWARD_COINS := 500
const REWARD_WEAPON := "star"

const WAKE_TIME := 1.8 # brullen en opstaan (beschermd)
const SHIFT_TIME := 1.8 # fasewissel (beschermd)
const DEATH_TIME := 2.8 # uiteenvallen voor de beloning komt
const PHASE_LIMITS := [0.66, 0.33] # onder deze deelhoeveelheid van zijn levens begint fase 2 en 3
const MAX_CHARGE := 340.0 # zo ver stormt hij hooguit
const SLAM_RADIUS := 78.0
const SLAM_TRIGGER := 92.0 # staat de speler zo dichtbij, dan kiest hij een klap
const KEEP_AWAY := 104.0 # dichterbij dan dit loopt hij achteruit
const COME_CLOSER := 190.0 # verder weg dan dit loopt hij naar je toe
const FOOT := 14.0 # de voeten van de speler staan zoveel onder zijn midden (voor de rode vlakken op de grond)
const RING_SHARDS := 16 # scherven in een ring
const MIN_PILLAR_DISTANCE := 120.0 # een pilaar schiet nooit als je er zo dichtbij staat
const WARNING := Color(1.0, 0.25, 0.3)
const GLOW := Color(0.7, 0.45, 1.0)

## Tijden en snelheden per fase (index 0 = fase 1). Alles in seconden en pixels per seconde.
const PHASES := [
	{
		"idle": 0.28, "walk": 70.0, "charge_windup": 0.7, "charge_speed": 380.0, "recover": 0.58, "stun": 1.6,
		"slam_windup": 0.64, "slam_recover": 0.68, "chain": 0.4,
	},
	{
		"idle": 0.22, "walk": 80.0, "charge_windup": 0.6, "charge_speed": 410.0, "recover": 0.48, "stun": 1.4,
		"slam_windup": 0.56, "slam_recover": 0.58, "chain": 0.5,
		"volley_every": 2.9, "volley_pillars": 4, "volley_windup": 0.85, "shard_speed": 118.0, "rings": 1,
	},
	{
		"idle": 0.15, "walk": 94.0, "charge_windup": 0.52, "charge_speed": 450.0, "recover": 0.42, "stun": 1.1,
		"slam_windup": 0.46, "slam_recover": 0.5, "chain": 0.6,
		"volley_every": 2.1, "volley_pillars": 5, "volley_windup": 0.75, "shard_speed": 135.0, "rings": 2,
	},
]

var world: Node
var obj: Dictionary = {}
var key := "" # (de wereld vult dit in; de baas heeft het niet nodig)
var bar_range := 1200.0 # de baasbalk in de HUD is in de hele arena te zien (zie hud.gd)
var kind := "guardian"
var data: Dictionary = {}
var unique_flag := DEFEATED_FLAG
var hp := 1
var max_hp := 1
var radius := 20.0
var active := false
var dead := false
var player: Node2D
var knockback := Vector2.ZERO
var desired := Vector2.ZERO
var flash := 0.0
var touch_cooldown := 0.0
var t := 0.0
var anim := randf() * TAU
var state := "dormant" # dormant, waking, idle, charge_windup, charge_dash, stunned, recover, slam_windup, slam_recover, phase_shift, dying
var state_time := 0.0
var phase := 1
var shift_to := 1
var aim_dir := Vector2.DOWN
var dash_left := 0.0
var line_length := 0.0
var last_attack := ""
var repeat_count := 0
var volley_timer := 3.0
var burst_timer := 0.0
var slam_angles: Array[float] = [] # richtingen van de scherven die zijn klap in fase 3 wegschiet
var pillars: Array[Node2D] = []


func _ready() -> void:
	data = Enemies.info(kind)
	if GameState.flag(DEFEATED_FLAG):
		# Al verslagen: alleen de hartcontainer-kist staat nog klaar.
		var chest := _make_chest()
		if chest != null:
			get_parent().add_child.call_deferred(chest)
		queue_free()
		return
	max_hp = GameState.ng_hp(int(data["hp"]))
	hp = max_hp
	radius = data["radius"]
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	shape.position = Vector2(0, _size_px() * 0.28)
	add_child(shape)
	_spawn_pillars.call_deferred()


func _size_px() -> float:
	return float(data["cell"]) * float(data["scale"])


func _tile_center(tile: Array) -> Vector2:
	return Vector2(float(tile[0]) * TILE + TILE / 2.0, float(tile[1]) * TILE + TILE / 2.0)


func _spawn_pillars() -> void:
	if not is_inside_tree():
		return
	for tile: Array in obj.get("pillars", []):
		var pillar: Node2D = PillarScript.new()
		pillar.set("world", world)
		pillar.position = _tile_center(tile)
		get_parent().add_child(pillar)
		pillars.append(pillar)


## De hartcontainer-kist. Een kist die je al hebt geopend, blijft staan (open en leeg), zoals alle kisten.
## Heb je al alle hartjes (8), dan zitten er drankjes en munten in.
func _make_chest() -> StaticBody2D:
	if not obj.has("chest"):
		return null
	var chest: StaticBody2D = ChestScript.new()
	var room := GameState.room("heart_container") > 0
	chest.contents = [["heart_container", 1]] if room else [["potion", 2], ["coins", 100]]
	chest.unique_key = CHEST_KEY
	chest.world = world
	chest.position = _tile_center(obj["chest"])
	return chest


# --- Wakker worden en fases --------------------------------------------------------------------------------

## De baas begint te vechten. Wordt vanzelf aangeroepen zodra de vlag guardian_started gezet is.
func activate() -> void:
	if active or dead:
		return
	active = true
	_enter("waking")
	Sound.play("guardian_roar")
	Sound.play_music("guardian")
	world.shake(5.0)
	world.ring(global_position + Vector2(0, FOOT), 120.0, GLOW)
	volley_timer = 3.0


func _enter(new_state: String) -> void:
	state = new_state
	state_time = 0.0


func _phase_for_hp() -> int:
	var ratio := float(hp) / float(max_hp)
	if ratio > PHASE_LIMITS[0]:
		return 1
	if ratio > PHASE_LIMITS[1]:
		return 2
	return 3


func _p() -> Dictionary:
	return PHASES[phase - 1]


func _begin_phase_shift(new_phase: int) -> void:
	shift_to = new_phase
	_enter("phase_shift")
	velocity = Vector2.ZERO
	for pillar: Node2D in pillars:
		if is_instance_valid(pillar):
			pillar.call("cancel")
	Sound.play("phase_shift")
	world.shake(7.0)
	world.ring(global_position + Vector2(0, FOOT), 150.0, GLOW)
	world.burst(global_position, GLOW, 22)
	# Een schokgolf duwt de speler weg (zonder schade), zodat je de baas niet kunt klemmen.
	if player and global_position.distance_to(player.global_position) < 110.0:
		player.knockback = (player.global_position - global_position).normalized() * 320.0


# --- Elke beeldje ---------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	t += delta
	anim += delta * 5.0
	flash = maxf(flash - delta, 0.0)
	touch_cooldown = maxf(touch_cooldown - delta, 0.0)
	if player == null:
		player = Util.player(self)
	if player == null or GameState.ended:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if not active:
		if GameState.flag(STARTED_FLAG):
			activate()
		queue_redraw()
		return

	state_time += delta
	desired = Vector2.ZERO
	match state:
		"waking":
			if state_time >= WAKE_TIME:
				_enter("idle")
		"idle":
			_step_idle()
		"charge_windup":
			_step_charge_windup()
		"charge_dash":
			desired = aim_dir * _p()["charge_speed"]
		"stunned":
			if state_time >= _p()["stun"]:
				_enter("idle")
		"recover":
			if state_time >= _p()["recover"]:
				_after_attack()
		"slam_windup":
			if state_time >= _p()["slam_windup"]:
				_slam()
		"slam_recover":
			if state_time >= _p()["slam_recover"]:
				_after_attack()
		"phase_shift":
			if state_time >= SHIFT_TIME:
				phase = shift_to
				volley_timer = 1.5
				_enter("idle")
		"dying":
			_step_dying(delta)
			queue_redraw()
			return
	_update_volleys(delta)

	var before := global_position
	velocity = desired + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()
	if state == "charge_dash":
		_step_dash(before)

	var touch_range := radius + 9.0
	if state in ["idle", "charge_windup", "charge_dash", "slam_windup"] and touch_cooldown <= 0.0 \
			and global_position.distance_to(player.global_position) < touch_range:
		touch_cooldown = 0.8
		if state == "charge_dash":
			player.hurt(global_position, 2, data["name"] + " (storm)")
		else:
			player.hurt(global_position, int(data["damage"]), data["name"])
	queue_redraw()


func _to_player() -> Vector2:
	return player.global_position - global_position


# --- Aanvallen --------------------------------------------------------------------------------------------------

func _step_idle() -> void:
	var to_player := _to_player()
	var distance := to_player.length()
	# Hij houdt afstand: loopt achteruit als je te dichtbij komt en naar je toe als je te ver weg bent.
	if distance < KEEP_AWAY:
		desired = -to_player.normalized() * float(_p()["walk"]) * 1.3
	elif distance > COME_CLOSER:
		desired = to_player.normalized() * float(_p()["walk"])
	if state_time >= _p()["idle"]:
		_choose_attack(distance)


## Na een aanval: soms meteen de volgende (een combinatie), anders even rondlopen.
func _after_attack() -> void:
	if randf() < float(_p()["chain"]):
		_choose_attack(_to_player().length())
	else:
		_enter("idle")


func _choose_attack(distance: float) -> void:
	var pick := "slam" if distance < SLAM_TRIGGER else "charge"
	# Niet steeds hetzelfde, dat is saai en voorspelbaar. (Een klap uit de verte heeft wel geen zin.)
	if pick == last_attack and repeat_count >= 2:
		var other := "charge" if pick == "slam" else "slam"
		if other == "charge" or distance < SLAM_TRIGGER * 1.6:
			pick = other
	repeat_count = repeat_count + 1 if pick == last_attack else 1
	last_attack = pick
	if pick == "charge":
		aim_dir = _to_player().normalized()
		line_length = _charge_length()
		_enter("charge_windup")
		Sound.play("guardian_charge")
	else:
		# In zijn woede schiet de klap ook een ring scherven weg. De rode lijnen laten alvast zien waar ze heen gaan.
		slam_angles.clear()
		if phase == 3:
			slam_angles = _ring_angles(randf() * TAU, 1)
		_enter("slam_windup")
		Sound.play("pillar_charge", -4.0)


## De baan van de storm: hij stopt tegen een muur of een pilaar.
func _charge_length() -> float:
	var feet := global_position + Vector2(0, _size_px() * 0.28)
	var length := 0.0
	while length < MAX_CHARGE:
		if world.is_solid(feet + aim_dir * (length + 16.0)):
			break
		length += 8.0
	for pillar: Node2D in pillars:
		if not is_instance_valid(pillar):
			continue
		var rel: Vector2 = pillar.global_position + Vector2(0, 8) - feet
		var along := rel.dot(aim_dir)
		if along > 0.0 and absf(rel.cross(aim_dir)) < 24.0:
			length = minf(length, along - 18.0)
	return clampf(length, 40.0, MAX_CHARGE)


func _step_charge_windup() -> void:
	var windup: float = _p()["charge_windup"]
	# Eerst volgt de rode baan jou, de laatste tijd ligt hij vast: één stap opzij of een rol en hij mist.
	if state_time < windup * 0.6:
		# Hij mikt een beetje vooruit: wie rechtdoor blijft rennen wordt geraakt.
		var player_velocity: Vector2 = player.velocity
		var lead := _to_player() + player_velocity * (windup - state_time) * 0.6
		aim_dir = aim_dir.lerp(lead.normalized(), 0.18).normalized()
		line_length = _charge_length()
	if state_time >= windup:
		dash_left = line_length
		_enter("charge_dash")
		world.shake(2.5)


func _step_dash(before: Vector2) -> void:
	dash_left -= global_position.distance_to(before)
	var crashed := false
	for i in get_slide_collision_count():
		if -get_slide_collision(i).get_normal().dot(aim_dir) > 0.5:
			crashed = true
	if crashed:
		_crash()
	elif dash_left <= 0.0:
		_enter("recover")


## Tegen een muur of pilaar geknald: even duizelig en dus kwetsbaar.
func _crash() -> void:
	_enter("stunned")
	Sound.play("slam")
	world.shake(8.0)
	world.burst(global_position + aim_dir * 22.0, Color(0.8, 0.85, 1.0), 16)
	world.ring(global_position + aim_dir * 22.0 + Vector2(0, FOOT), 60.0, GLOW)


func _slam() -> void:
	_enter("slam_recover")
	Sound.play("slam")
	world.shake(7.0)
	var center := global_position + Vector2(0, FOOT)
	world.burst(center, Color(0.8, 0.6, 1.0), 18)
	world.ring(center, SLAM_RADIUS, GLOW)
	world.ring(center, SLAM_RADIUS * 0.6, Color(1, 1, 1))
	if global_position.distance_to(player.global_position) < SLAM_RADIUS:
		player.hurt(global_position, int(data["slam_damage"]), data["name"] + " (klap)")
	if not slam_angles.is_empty():
		_shoot_ring(center, slam_angles, 110.0)
		slam_angles.clear()


# --- Pilaren en scherven -----------------------------------------------------------------------------------------

func _update_volleys(delta: float) -> void:
	if phase < 2 or state in ["waking", "phase_shift", "dying"]:
		return
	volley_timer -= delta
	if volley_timer <= 0.0:
		_start_volley()


func _start_volley() -> void:
	var p := _p()
	var ready_pillars: Array[Node2D] = []
	for pillar: Node2D in pillars:
		if is_instance_valid(pillar) and not pillar.call("is_busy") \
				and pillar.global_position.distance_to(player.global_position) >= MIN_PILLAR_DISTANCE:
			ready_pillars.append(pillar)
	if ready_pillars.is_empty():
		volley_timer = 0.5
		return
	ready_pillars.shuffle()
	for i in mini(int(p["volley_pillars"]), ready_pillars.size()):
		ready_pillars[i].call("begin_volley", _ring_angles(randf() * TAU, 2), TAU / float(RING_SHARDS),
			p["volley_windup"], p["shard_speed"], p["rings"])
	volley_timer = float(p["volley_every"])


## De richtingen van een ring scherven. `gaps` stukken van twee scherven ontbreken, zodat je erdoor kunt lopen.
func _ring_angles(start: float, gaps: int) -> Array[float]:
	var skip: Array[int] = []
	var first := randi() % RING_SHARDS
	for g in gaps:
		var at := posmod(first + g * RING_SHARDS / gaps + randi_range(-1, 1), RING_SHARDS) # posmod: zo wordt -1 de laatste scherf
		skip.append(at)
		skip.append(posmod(at + 1, RING_SHARDS))
	var angles: Array[float] = []
	for i in RING_SHARDS:
		if not skip.has(i):
			angles.append(start + TAU * float(i) / float(RING_SHARDS))
	return angles


func _shoot_ring(origin: Vector2, angles: Array[float], speed: float) -> void:
	Sound.play("shard_burst", -4.0)
	for angle in angles:
		var dir := Vector2.from_angle(angle)
		var shard: Node2D = ShardScript.new()
		shard.set("world", world)
		shard.set("velocity", dir * speed)
		shard.set("source", data["name"] + " (scherf)")
		shard.position = origin + dir * 24.0
		get_parent().add_child(shard)


# --- Schade en dood ------------------------------------------------------------------------------------------------

## Wordt aangeroepen door het zwaard van de speler.
func hurt(damage: int, direction: Vector2) -> void:
	if dead or not active:
		return
	if state == "waking" or state == "phase_shift":
		# Beschermd: er springen alleen een paar vonken af, en je ziet dat je klap niet telt.
		world.burst(global_position + direction.normalized() * 18.0, GLOW, 4)
		world.damage_number(global_position + Vector2(0, -_size_px() * 0.35), "Beschermd!", Color(0.75, 0.8, 0.95))
		Sound.play("hit", -10.0, 1.8)
		return
	hp -= damage
	flash = 0.15
	world.damage_number(global_position + Vector2(0, -_size_px() * 0.35), str(damage), Color(1, 0.95, 0.6))
	world.burst(global_position, Color(1, 1, 1), 5)
	if hp <= 0:
		_die()
		world.hitstop(0.09)
		return
	Sound.play("hit", -2.0, randf_range(0.8, 0.95))
	var new_phase := _phase_for_hp()
	if new_phase > phase:
		_begin_phase_shift(mini(new_phase, phase + 1)) # nooit een fase overslaan, ook niet bij een enorme klap
	world.hitstop(0.04)


func _die() -> void:
	dead = true
	hp = 0
	remove_from_group("enemies")
	GameState.register_kill(kind)
	for pillar: Node2D in pillars:
		if is_instance_valid(pillar):
			pillar.call("cancel")
	_clear_shards()
	_enter("dying")
	burst_timer = 0.0
	velocity = Vector2.ZERO
	Sound.stop_music()
	Sound.play("guardian_die")
	world.shake(9.0)
	died.emit()


func _clear_shards() -> void:
	for shard: Node in get_tree().get_nodes_in_group("guardian_shards"):
		shard.queue_free()


func _step_dying(delta: float) -> void:
	burst_timer -= delta
	if burst_timer <= 0.0:
		burst_timer = 0.16
		world.burst(global_position + Vector2(randf_range(-34, 34), randf_range(-40, 30)), GLOW.lerp(Color.WHITE, randf() * 0.6), 10)
		world.shake(3.0)
	if state_time >= DEATH_TIME:
		_finish()


## De Wachter valt uiteen: fanfare, het Sterrenzwaard, munten, de hartcontainer-kist en het einde van de opdracht.
func _finish() -> void:
	var center := global_position
	world.burst(center, Color(1, 1, 1), 30)
	world.burst(center, GLOW, 30)
	world.ring(center + Vector2(0, FOOT), 140.0, Color(1, 1, 1))
	world.ring(center + Vector2(0, FOOT), 90.0, GLOW)
	world.shake(8.0)
	for pillar: Node2D in pillars:
		if is_instance_valid(pillar):
			world.burst(pillar.global_position + Vector2(0, -20), GLOW, 14)
			pillar.queue_free()
	Sound.play("star_fanfare")
	GameState.set_flag(DEFEATED_FLAG)
	GameState.add_coins(REWARD_COINS)
	GameState.toast.emit("Gevonden: %d munten" % REWARD_COINS)
	if GameState.weapon != REWARD_WEAPON:
		GameState.run(["weapon", REWARD_WEAPON])
	GameState.finish_quest("diepte")
	var chest := _make_chest()
	if chest != null:
		get_parent().add_child(chest)
		world.burst(chest.position + Vector2(0, -8), Color(1, 0.95, 0.6), 16)
	# Na de fanfare komt de rustige muziek van de Diepte terug.
	var tree := get_tree()
	tree.create_timer(6.0).timeout.connect(func() -> void:
		if GameState.map_id == "depths2" and GameState.in_game:
			Sound.play_music("depths"))
	queue_free()


# --- Tekenen -------------------------------------------------------------------------------------------------------

func _frame() -> int:
	match state:
		"dormant":
			return 6
		"waking":
			return 6 if state_time < WAKE_TIME * 0.35 else 7
		"charge_windup":
			return 2
		"charge_dash":
			return 3
		"stunned":
			return 6
		"slam_windup":
			return 4
		"slam_recover":
			return 5 if state_time < 0.4 else 0
		"phase_shift":
			return 7
		"dying":
			return 6 if int(state_time * 8.0) % 2 == 0 else 7
	return int(anim * 0.4) % 2


func _draw() -> void:
	if data.is_empty():
		return
	var size := _size_px()
	var shadow: float = data["shadow"]
	DrawUtil.ellipse(self, Vector2(0, size * 0.44), Vector2(shadow, shadow * 0.35), Color(0, 0, 0, 0.3))

	# Aankondigingen op de grond, onder de baas.
	if state == "charge_windup":
		_draw_charge_lane()
	elif state == "slam_windup":
		var progress := clampf(state_time / float(_p()["slam_windup"]), 0.0, 1.0)
		var center := Vector2(0, FOOT)
		draw_circle(center, SLAM_RADIUS * progress, Color(WARNING, 0.1 + progress * 0.28))
		draw_arc(center, SLAM_RADIUS, 0.0, TAU, 40, Color(WARNING, 0.35 + progress * 0.5), 3.0)
		for angle in slam_angles:
			var dir := Vector2.from_angle(angle)
			draw_line(center + dir * SLAM_RADIUS, center + dir * (SLAM_RADIUS + 90.0), Color(WARNING, 0.2 + progress * 0.5), 2.0)
	elif state == "waking":
		var wake := clampf(state_time / WAKE_TIME, 0.0, 1.0)
		draw_circle(Vector2(0, FOOT), 40.0 + wake * 70.0, Color(GLOW, 0.2 * (1.0 - wake)))
	elif state == "phase_shift":
		var pulse := 0.5 + 0.5 * sin(state_time * 14.0)
		draw_circle(Vector2(0, FOOT), 64.0 + pulse * 6.0, Color(GLOW, 0.14 + pulse * 0.1))
		draw_arc(Vector2(0, FOOT), 60.0, 0.0, TAU, 40, Color(GLOW, 0.8), 3.0)

	var tint := Color.WHITE
	if state == "dormant":
		tint = Color(0.55, 0.55, 0.7)
	elif flash > 0.0:
		tint = Color(3, 3, 3)
	elif phase == 3 and active and not dead:
		var rage := 0.5 + 0.5 * sin(t * 7.0)
		tint = Color(1.0 + rage * 0.5, 1.0 - rage * 0.25, 1.0 - rage * 0.25)
	var offset := Vector2.ZERO
	if state == "charge_windup":
		offset = Vector2(randf_range(-1.0, 1.0), 0.0) * 2.0
	elif state == "stunned" or state == "dying":
		offset = Vector2(randf_range(-1.0, 1.0), 0.0) * 1.5
	DrawUtil.sprite(self, Art.tex("guardian"), _frame(), 0, offset, Vector2i(int(data["cell"]), int(data["cell"])), float(data["scale"]), tint)
	if state == "stunned":
		_draw_dizzy()


## Een rode baan op de grond: zo breed als de baas, zo lang als de storm.
func _draw_charge_lane() -> void:
	var windup: float = _p()["charge_windup"]
	var progress := clampf(state_time / windup, 0.0, 1.0)
	var locked := state_time >= windup * 0.6
	var half := radius + 9.0
	var from := Vector2(0, FOOT)
	var to := from + aim_dir * line_length
	var side := aim_dir.orthogonal() * half
	var alpha := 0.12 + progress * 0.3
	if locked and int(state_time * 16.0) % 2 == 0:
		alpha += 0.2
	draw_colored_polygon(PackedVector2Array([from + side, to + side, to - side, from - side]), Color(WARNING, alpha))
	draw_line(from + side, to + side, Color(WARNING, 0.5 + progress * 0.4), 2.0)
	draw_line(from - side, to - side, Color(WARNING, 0.5 + progress * 0.4), 2.0)
	draw_line(from, to, Color(1.0, 0.6, 0.6, 0.5 + progress * 0.4), 3.0 if locked else 1.5)
	# pijlpunten die laten zien welke kant hij op gaat
	var step := 44.0
	var at := step
	while at < line_length:
		var p := from + aim_dir * at
		draw_line(p - aim_dir * 8.0 + aim_dir.orthogonal() * 8.0, p, Color(1.0, 0.6, 0.6, 0.6), 2.0)
		draw_line(p - aim_dir * 8.0 - aim_dir.orthogonal() * 8.0, p, Color(1.0, 0.6, 0.6, 0.6), 2.0)
		at += step


## Sterretjes rond zijn hoofd als hij duizelig is.
func _draw_dizzy() -> void:
	for i in 3:
		var angle := t * 4.0 + TAU * float(i) / 3.0
		var p := Vector2(cos(angle) * 26.0, -_size_px() * 0.42 + sin(angle) * 6.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(1.5, -1.5), p + Vector2(5, 0),
			p + Vector2(1.5, 1.5), p + Vector2(0, 5), p + Vector2(-1.5, 1.5), p + Vector2(-5, 0), p + Vector2(-1.5, -1.5)]),
			Color(1.0, 0.95, 0.6))
