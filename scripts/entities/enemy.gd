extends CharacterBody2D
## Een vijand. Het soort (kind) bepaalt de eigenschappen (scripts/data/enemies.gd) en het gedrag:
## chase (slijm), bat (vleermuis), archer (skelet), mage (Magiër), spitter (Slijmspuwer),
## golem (minibaas) en king (eindbaas).

signal died

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const CombatAI := preload("res://scripts/entities/combat_enemy.gd")
const LivingAI := preload("res://scripts/entities/living_enemy.gd")
var guard_broken := 0.0
var defend_target: Node2D

const EchoAI := preload("res://scripts/entities/echo_enemy.gd")

const FIRST_DELAY := 1.2 # seconden tussen "hij ziet je" en de eerste teleport of spuugbeurt
const SPITTER_AFTER_HOP := 0.7 # na een hupje spuugt hij pas even later
const STUCK_WINDOW := 0.5 # elke zoveel seconden kijkt de Magiër of hij van zijn plek is gekomen...
const STUCK_DISTANCE := 10.0 # ...en anders zit hij vast (muur, hoek) en teleporteert hij weg
const LOOKAHEAD := 22.0 # zo ver vooruit kijken ze of er een muur aankomt
const SPOT_TRIES := 24 # pogingen om een vrije plek te vinden voor een teleport
const HOP_TURNS: Array[float] = [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5] # hoeken (radialen) waarin de Slijmspuwer wegspringt
const MAGE_ORB_HEIGHT := -14.0 # de bol ontstaat boven de handen van de Magiër
const MAGE_AIM := Vector2(0, 4) # de bol mikt op het midden van de speler
const HINT_DELAY := 3.5 # na de tip bij de eerste ontmoeting wacht hij even met aanvallen (de tip staat 3,2 s in beeld)
const SPITTER_CREEP := 0.8 # staat de speler verder dan 80% van zijn bereik, dan schuifelt de Slijmspuwer naar hem toe
const SOLID_LAYER := 1 # botsingslaag van muren en van vaste dingen zoals kisten, borden, poortjes en personages
const MAGE_COLOR := Color(0.85, 0.6, 1.0)
const SPIT_COLOR := Color(0.65, 0.95, 0.35)

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
var home_position := Vector2.ZERO
var patrol_radius := 0.0 # opt-in for ordinary outdoor spawns; bosses/trials stay unrestricted
var strafe := 1.0
var air_height := 0.0
var hop_from := Vector2.ZERO
var hop_to := Vector2.ZERO
var hop_count := 0
var slam_ring := 0.0
var dead := false
var hop_phase := 1
# Wilde dieren (gedrag "animal"): vreedzaam wild dat wegrent als je te dichtbij komt of het raakt
var panic := 0.0 # hoe lang het dier nog vlucht na een klap
var fleeing := false # rent het dier nu weg (voor het plaatje)
# Magiër en Slijmspuwer
var special_timer := FIRST_DELAY # tijd tot de volgende teleport (Magiër) of spuugbeurt (Slijmspuwer)
var hop_cooldown := 0.0 # de Slijmspuwer hupt niet meteen weer
var action_flash := 0.0 # korte tijd na een schot of spuugbeurt: toont het "actie"-plaatje
var stuck_time := 0.0 # hoe lang de Magiër al probeert te verplaatsen zonder ver te komen
var stuck_anchor := Vector2.ZERO # waar hij stond toen dat begon
var glow: PointLight2D # de Magiër geeft zelf licht in donkere gebieden


func setup(enemy_kind: String, flag := "") -> void:
	kind = enemy_kind
	data = Enemies.info(kind)
	unique_flag = flag
	max_hp = GameState.ng_hp(int(data["hp"])) # sterkere vijanden bij Nieuw spel+
	hp = max_hp
	radius = data["radius"]
	active = not data.get("start_inactive", false)


func _ready() -> void:
	if data.is_empty():
		setup(kind)
	add_to_group("enemies")
	home_position=global_position
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
	if kind=="king":
		var warning:=preload("res://scripts/entities/king_warning.gd").new()
		warning.king=weakref(self)
		world.ground.add_child(warning)

	if data["behavior"] == "mage" and world != null and world.darkness > 0.0:
		# In donkere gebieden is de Magiër zelf een lichtje (en zie je de aanloop goed).
		glow = PointLight2D.new()
		glow.texture = Art.light_texture()
		glow.texture_scale = 0.9
		glow.color = MAGE_COLOR
		glow.energy = 0.6
		add_child(glow)


func _size_px() -> float:
	return float(data["cell"]) * float(data["scale"])


func activate() -> void:
	active = true


func _physics_process(delta: float) -> void:
	t += delta
	guard_broken = maxf(guard_broken - delta, 0.0)
	anim += delta * 5.0
	flash = maxf(flash - delta, 0.0)
	touch_cooldown = maxf(touch_cooldown - delta, 0.0)
	slam_ring = maxf(slam_ring - delta, 0.0)
	action_flash = maxf(action_flash - delta, 0.0)
	if player == null:
		player = Util.player(self)
	if dead or player == null or GameState.ended or not active:
		velocity = Vector2.ZERO
		queue_redraw()
		return

	state_time += delta
	desired = Vector2.ZERO
	match data["behavior"]:
		"cv_ram", "cv_slinger":
			CombatAI.update(self, delta)
		"rf_ambush", "rf_listen":
			preload("res://scripts/entities/route_enemy.gd").update(self,delta)
		"lw_guard", "lw_flank", "lw_support":
			LivingAI.update(self, delta)
		"echo_charge", "echo_volley":
			EchoAI.update(self, delta)
		"chase":
			_ai_chase(delta)
		"bat":
			_ai_bat(delta)
		"archer":
			_ai_archer(delta)
		"mage":
			_ai_mage(delta)
		"spitter":
			_ai_spitter(delta)
		"golem":
			_ai_golem(delta)
		"king":
			_ai_king(delta)
		"animal":
			_ai_animal(delta)

	velocity = desired + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()

	var touch_range: float = radius + 9.0
	if data["behavior"] in ["cv_ram","cv_slinger"] and state != "cv_charge": touch_range = 0.0
	if state in ["hop", "vanish", "appear"] or data["behavior"] == "animal":
		touch_range = 0.0 # in de lucht, als rookwolkje of als vreedzaam dier kan hij niemand raken
	if global_position.distance_to(player.global_position) < touch_range and touch_cooldown <= 0.0:
		touch_cooldown = 0.8
		player.hurt(global_position, data["damage"], data["name"])
	queue_redraw()


func _to_player() -> Vector2:
	return player.global_position - global_position


func _wander(delta: float) -> void:
	if patrol_radius>0 and global_position.distance_to(home_position)>patrol_radius*0.45:
		desired=_free_direction((home_position-global_position).normalized())*data["speed"]
		return
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.8, 2.0)
		wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
	desired = wander_dir * data["speed"]


# --- Gedrag ---------------------------------------------------------------------

func _ai_chase(delta: float) -> void:
	var to_player := _to_player()
	if to_player.length() < data["sight"] and (patrol_radius<=0 or home_position.distance_to(player.global_position)<patrol_radius):
		desired = to_player.normalized() * data["chase_speed"]
	else:
		_wander(delta)


## Vreedzaam wild: het draalt wat rond, maar schrikt en rent weg als je te dichtbij komt of het raakt.
## Een klap (ook een pijl uit de verte) zet `panic`: dan vlucht het nog even nadat je stopt met achtervolgen.
func _ai_animal(delta: float) -> void:
	panic = maxf(panic - delta, 0.0)
	var to_player := _to_player()
	fleeing = panic > 0.0 or to_player.length() < float(data.get("panic_range", 90.0))
	if fleeing:
		desired = -to_player.normalized() * float(data["chase_speed"])
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
				world.spawn_projectile("arrow", global_position, aim_dir, 150.0, data["damage"], data["name"] + " (pijl)")
				state = "idle"
				state_time = 0.0


# --- Magiër ---------------------------------------------------------------------------
# Houdt afstand, teleporteert elke paar seconden naar een plek vlak bij je en schiet na een duidelijke aanloop
# een trage arcane bol af. Toestanden: idle -> vanish (rookwolkje) -> appear -> cast (aanloop) -> idle.

func _ai_mage(delta: float) -> void:
	var to_player := _to_player()
	var dist := to_player.length()
	special_timer -= delta
	match state:
		"idle":
			if dist > data["sight"]:
				# Hij ziet je niet: rondzweven, maar wel klaar om meteen te beginnen zodra je in zicht komt.
				_wander(delta)
				special_timer = FIRST_DELAY
				return
			_show_hint()
			var stuck := _mage_kite(to_player, dist, delta)
			if special_timer <= 0.0 or stuck:
				_mage_vanish()
		"vanish":
			if state_time >= data["vanish_time"]:
				_mage_appear()
		"appear":
			aim_dir = to_player.normalized()
			if state_time >= data["appear_time"]:
				state = "cast"
				state_time = 0.0
				Sound.play("mage_charge", -5.0)
		"cast":
			aim_dir = to_player.normalized()
			if state_time >= data["cast_time"]:
				_mage_shoot()
				state = "idle"
				state_time = 0.0
	_update_glow()


## Kiten: te dichtbij is wegzweven, te ver weg is naderen, daartussen rustig heen en weer.
## Geeft true als hij vastzit (hij wil weg of dichterbij, maar komt niet van zijn plek).
func _mage_kite(to_player: Vector2, dist: float, delta: float) -> bool:
	var keep: Array = data["keep_distance"]
	if dist < keep[0]:
		desired = _free_direction(-to_player.normalized()) * float(data["speed"]) * 1.3
	elif dist > keep[1]:
		desired = _free_direction(to_player.normalized()) * float(data["chase_speed"])
	else:
		desired = _free_direction(to_player.orthogonal().normalized() * strafe) * float(data["speed"]) * 0.5
		if randf() < 0.01:
			strafe = -strafe
	# Zit hij vast tegen een muur of in een hoek? Dan is wegteleporteren het enige wat helpt.
	if dist >= keep[0] and dist <= keep[1]:
		stuck_time = 0.0
		stuck_anchor = global_position
		return false
	stuck_time += delta
	if stuck_time < STUCK_WINDOW:
		return false
	var stuck := global_position.distance_to(stuck_anchor) < STUCK_DISTANCE
	stuck_time = 0.0
	stuck_anchor = global_position
	return stuck


func _mage_vanish() -> void:
	state = "vanish"
	state_time = 0.0
	special_timer = data["teleport_every"]
	stuck_time = 0.0
	stuck_anchor = global_position
	Sound.play("mage_teleport", -3.0)
	_smoke_puff()


func _mage_appear() -> void:
	var spot := _mage_pick_spot()
	if spot != Vector2.INF:
		global_position = spot
		knockback = Vector2.ZERO
	stuck_anchor = global_position
	_smoke_puff()
	state = "appear"
	state_time = 0.0


## Een plek 100-140 px van de speler waar de Magiër past (niet in of tegen een muur, niet op een kist of poortje) en
## waar zijn bol vrij zicht op de speler heeft: de bol ontstaat niet in een muur en vliegt nergens tegenaan.
## Geeft Vector2.INF als er geen plek is (bijvoorbeeld in een heel smalle gang): dan blijft hij staan.
func _mage_pick_spot() -> Vector2:
	var span: Array = data["teleport_range"]
	var target := player.global_position + MAGE_AIM
	var without_view := Vector2.INF
	for i in SPOT_TRIES:
		var spot: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(span[0], span[1])
		if not _fits_at(spot):
			continue
		var orb_start := spot + Vector2(0, MAGE_ORB_HEIGHT)
		if not world.is_solid(orb_start) and _clear_line(orb_start, target):
			return spot
		if without_view == Vector2.INF:
			without_view = spot
	return without_view


func _mage_shoot() -> void:
	var origin := global_position + Vector2(0, MAGE_ORB_HEIGHT)
	var direction := (player.global_position + MAGE_AIM - origin).normalized()
	Sound.play("mage_orb", -3.0)
	world.spawn_projectile("arcane_orb", origin, direction, data["orb_speed"], data["damage"], data["name"] + " (tovervonk)")
	world.burst(origin, MAGE_COLOR, 6)
	action_flash = 0.15


## Raak je hem tijdens de aanloop, dan mislukt de toverspreuk.
func _mage_interrupt() -> void:
	state = "idle"
	state_time = 0.0
	world.burst(global_position, MAGE_COLOR, 8)
	world.damage_number(global_position + Vector2(0, -_size_px() * 0.9), tr("Mislukt!"), MAGE_COLOR)


## Eenmalig een tip als je deze soort vijand voor het eerst tegenkomt (de vlag wordt mee opgeslagen).
## Zijn eerste aanval komt pas als de tip weer weg is: de tip staat onderin beeld en mag de aanloop niet verbergen.
func _show_hint() -> void:
	var hint: String = data.get("hint", "")
	var seen_flag := "vijanden_hint_" + kind
	if hint != "" and not GameState.flag(seen_flag):
		GameState.set_flag(seen_flag)
		GameState.toast.emit(tr(hint))
		special_timer = maxf(special_timer, HINT_DELAY)


func _smoke_puff() -> void:
	world.burst(global_position, Color(0.8, 0.72, 1.0), 12)
	world.ring(global_position, 28.0, MAGE_COLOR)


func _update_glow() -> void:
	if glow == null:
		return
	var charge := clampf(state_time / float(data["cast_time"]), 0.0, 1.0) if state == "cast" else 0.0
	glow.energy = 0.6 + charge * 0.7


# --- Slijmspuwer ------------------------------------------------------------------------
# Staat bijna stil en spuugt een waaier van slijmballen zodra je dichtbij komt. Wordt het hem te gezellig
# (dichterbij dan flee_range), dan hupt hij weg. Toestanden: idle -> windup -> idle, of idle -> hop -> idle.

func _ai_spitter(delta: float) -> void:
	var to_player := _to_player()
	var dist := to_player.length()
	special_timer -= delta
	hop_cooldown = maxf(hop_cooldown - delta, 0.0)
	match state:
		"idle":
			if dist > data["spit_range"]:
				_wander(delta)
				special_timer = FIRST_DELAY # pas als je dichtbij komt begint hij te spuwen
				return
			_show_hint()
			if dist > float(data["spit_range"]) * SPITTER_CREEP:
				# Aan de rand van zijn bereik schuifelt hij naar je toe, anders duwt het spugen hem langzaam weg.
				desired = _free_direction(to_player.normalized()) * float(data["speed"])
			else:
				_wander(delta)
			if dist < data["flee_range"] and hop_cooldown <= 0.0:
				_spitter_hop(to_player, dist)
			elif special_timer <= 0.0:
				state = "windup"
				state_time = 0.0
				special_timer = data["spit_every"]
				aim_dir = to_player.normalized()
		"windup":
			# Richten tot vlak voor het spuwen, zodat je nog kunt uitwijken.
			if state_time < data["windup"] - 0.15:
				aim_dir = to_player.normalized()
			if state_time >= data["windup"]:
				_spitter_spit()
				state = "idle"
				state_time = 0.0
		"hop":
			var p := clampf(state_time / float(data["hop_time"]), 0.0, 1.0)
			air_height = sin(p * PI) * 14.0
			global_position = hop_from.lerp(hop_to, p)
			if p >= 1.0:
				air_height = 0.0
				world.burst(global_position + Vector2(0, 10), SPIT_COLOR, 6)
				hop_cooldown = data["hop_cooldown"]
				special_timer = maxf(special_timer, SPITTER_AFTER_HOP)
				state = "idle"
				state_time = 0.0


func _spitter_spit() -> void:
	var mouth := global_position + Vector2(0, 6)
	Sound.play("spitter_spit", 0.0, randf_range(0.95, 1.05))
	var fan: int = data["fan"]
	for i in fan:
		var spread := (float(i) - float(fan - 1) / 2.0) * float(data["fan_spread"])
		world.spawn_projectile("slimeball", mouth, aim_dir.rotated(spread), data["ball_speed"], data["damage"], data["name"] + " (slijmbal)")
	world.burst(mouth, SPIT_COLOR, 8)
	knockback = -aim_dir * 90.0 # een beetje terugslag
	action_flash = 0.2


## Hupt van de speler weg naar een vrije plek (nooit door of in een muur). Lukt dat niet, dan blijft hij staan.
func _spitter_hop(to_player: Vector2, dist: float) -> void:
	var away := -to_player.normalized()
	# Eerst recht weg en ver, daarna steeds schuiner en korter.
	for shrink: float in [1.0, 0.8, 0.6, 0.45]:
		for turn: float in HOP_TURNS:
			var spot: Vector2 = global_position + away.rotated(turn) * float(data["hop_distance"]) * shrink
			if spot.distance_to(player.global_position) > dist + 15.0 and _fits_at(spot) and _body_clear(global_position, spot):
				hop_from = global_position
				hop_to = spot
				hop_count += 1
				state = "hop"
				state_time = 0.0
				Sound.play("spitter_hop", -3.0, randf_range(0.95, 1.1))
				return
	hop_cooldown = 0.5 # geen plek: even niet opnieuw proberen


# --- Hulpjes voor kiten en hupjes ---------------------------------------------------------

## De plek van het botsingsrondje (de voeten) voor een vijand die op `pos` staat.
func _feet(pos: Vector2) -> Vector2:
	return pos + Vector2(0, _size_px() * 0.28)


## Past een vijand op `pos` zonder een muur of iets anders vasts (kist, bord, poortje, personage) te raken?
## `margin` is de ruimte die hij minstens rondom wil hebben.
func _fits_at(pos: Vector2, margin := 2.0) -> bool:
	if world.is_solid(pos):
		return false
	var reach := radius + margin
	var feet := _feet(pos)
	for offset: Vector2 in [Vector2.ZERO, Vector2(reach, 0), Vector2(-reach, 0), Vector2(0, reach), Vector2(0, -reach),
			Vector2(reach, reach) * 0.7, Vector2(-reach, reach) * 0.7, Vector2(reach, -reach) * 0.7, Vector2(-reach, -reach) * 0.7]:
		if world.is_solid(feet + offset):
			return false
	var circle := CircleShape2D.new()
	circle.radius = reach
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, feet)
	query.collision_mask = SOLID_LAYER
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Ligt er niets vasts tussen `from` en `to`: geen muur, maar ook geen kist, poortje of personage?
func _clear_line(from: Vector2, to: Vector2) -> bool:
	var steps := int(from.distance_to(to) / 8.0)
	for i in range(1, steps + 1):
		if world.is_solid(from.lerp(to, float(i) / float(steps))):
			return false
	var query := PhysicsRayQueryParameters2D.create(from, to, SOLID_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Past een vijand overal langs de rechte lijn van `from` naar `to` (hij schuurt niet langs een hoek en springt niet
## over een kist of poortje)?
func _body_clear(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(int(from.distance_to(to) / 8.0), 1)
	for i in range(1, steps + 1):
		if not _fits_at(from.lerp(to, float(i) / float(steps)), 0.0):
			return false
	return true


## De richting die het dichtst bij `dir` ligt en niet tegen een muur aan loopt (zo glijdt hij langs muren).
func _free_direction(dir: Vector2) -> Vector2:
	for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var candidate := dir.rotated(turn)
		if not world.is_solid(_feet(global_position) + candidate * LOOKAHEAD):
			return candidate
	return Vector2.ZERO


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
		player.hurt(global_position, int(data.get("slam_damage", data["damage"])), data["name"] + " (klap)")
	if enraged:
		for i in 6:
			world.spawn_projectile("rock", global_position, Vector2.from_angle(TAU * float(i) / 6.0 + 0.3), 95.0, 1, data["name"] + " (steen)")


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
	match state:
		"idle":
			if state_time > (0.9 if phase == 1 else 0.6 if phase == 2 else 0.4):
				hop_phase=phase
				hop_to=_king_destination(player.global_position+player.velocity*0.2)
				state = "crouch"
				state_time = 0.0
		"crouch":
			if state_time > king_charge_time():
				state = "hop"
				state_time = 0.0
				hop_from = global_position
		"hop":
			var duration := king_hop_time()
			var p := clampf(state_time / duration, 0.0, 1.0)
			air_height = sin(p * PI) * 52.0
			global_position = hop_from.lerp(hop_to, p)
			if p >= 1.0:
				air_height = 0.0
				_king_land(hop_phase)
				state = "land"
				state_time = 0.0
		"land":
			if state_time > 0.65:
				state = "idle"
				state_time = 0.0

func king_charge_time() -> float:
	return 0.65 if hop_phase==1 else 0.6 if hop_phase==2 else 0.5

func king_hop_time() -> float:
	return 0.8 if hop_phase<3 else 0.6

func king_shock() -> float:
	return 64.0 if hop_phase==1 else 74.0 if hop_phase==2 else 86.0

func _king_destination(proposed: Vector2) -> Vector2:
	var goal: Vector2=world.clamp_to_map(proposed)
	if _fits_at(goal):return goal
	for radius in range(1,5):
		for i in 8:
			var candidate:=goal+Vector2.from_angle(i*TAU/8)*radius*24
			if _fits_at(candidate):return candidate
	return global_position


func _king_land(phase: int) -> void:
	hop_count += 1
	var shock := 64.0 if phase == 1 else 74.0 if phase == 2 else 86.0
	Sound.play("slam")
	world.shake(7.0)
	world.burst(global_position + Vector2(0, 30), Color(0.5, 0.95, 0.55), 16)
	world.ring(global_position, shock, Color(0.5, 0.95, 0.55))
	slam_ring = 0.35
	if global_position.distance_to(player.global_position) < shock:
		player.hurt(global_position, 1 if phase == 1 else int(data.get("slam_damage", 2)), data["name"] + " (landing)")
	var minions := 0
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and enemy.kind == "slime_mini":
			minions += 1
	if (phase == 1 and hop_count % 4 == 0) or (phase == 3 and hop_count % 3 == 0):
		if minions < 3:
			for i in 2:
				world.spawn_enemy("slime_mini", world.clamp_to_map(global_position + Vector2.from_angle(randf() * TAU) * 60.0))
	if phase >= 2:
		var bullets := 3 if phase == 2 else 5
		var to_player := _to_player().normalized()
		for i in bullets:
			var spread := (float(i) - float(bullets - 1) / 2.0) * 0.3
			world.spawn_projectile("slimeball", global_position, to_player.rotated(spread), 115.0, 1, data["name"] + " (slijmbal)")


# --- Schade en dood ---------------------------------------------------------------

## Wordt aangeroepen door het zwaard van de speler.
func hurt(damage: int, direction: Vector2) -> void:
	if dead or not active:
		return
	if kind == "king" and state == "hop":
		return # in de lucht
	if LivingAI.blocks(self, direction):
		world.ring(global_position, 18, Color(0.7, 0.9, 1))
		Sound.play("hit", -10.0, 1.5)
		return
	if data["behavior"] == "lw_support":
		state = "idle"
		state_time = 0.0
	if data["behavior"] in ["rf_ambush","rf_listen"]:
		state="rf_rest"
		state_time=0
	if data["behavior"] in ["cv_ram","cv_slinger"]:
		CombatAI.transition(self,"cv_rest")
	hp -= damage
	knockback = direction.normalized() * float(data.get("knockback", 240.0))
	flash = 0.15
	if data["behavior"] == "animal":
		panic = 5.0 # een geraakt dier vlucht, ook als de pijl van ver kwam
	if data["behavior"] == "mage" and (state == "appear" or state == "cast"):
		_mage_interrupt()
	if data["behavior"] == "echo_volley" and state == "echo_warn":
		state = "echo_rest"
		state_time = 0.0
	world.damage_number(global_position + Vector2(0, -_size_px() * 0.35), str(damage), Color(1, 0.95, 0.6))
	world.burst(global_position, Color(1, 1, 1), 5)
	if hp <= 0:
		_die()
		world.hitstop(0.07)
	else:
		Sound.play("hit", -2.0, randf_range(0.9, 1.1))
		world.hitstop(0.035)


func break_guard() -> void:
	if data["behavior"] != "lw_guard": return
	guard_broken = 1.8
	world.ring(global_position, 32, Color(1, 0.7, 0.3))
	Sound.play("hit", -3.0, 0.65)


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	if not has_meta("practice"): GameState.register_kill(kind)
	Sound.play("die", -2.0, randf_range(0.9, 1.1))
	world.burst(global_position, data.get("death_color", Color(0.7, 1.0, 0.7)), 16)
	if unique_flag != "":
		GameState.set_flag(unique_flag)
	for drop: Array in ([] if has_meta("practice") else data["drops"]):
		if randf() < drop[1]:
			var amount := GameState.ng_coins(int(drop[2])) if drop[0] == "coin" else int(drop[2]) # Nieuw spel+: meer munten
			for i in amount:
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
		"cv_ram", "cv_slinger":
			CombatAI.draw(self,sheet,tint)
		"rf_ambush", "rf_listen":
			preload("res://scripts/entities/route_enemy.gd").draw(self,sheet,tint)
		"lw_guard", "lw_flank", "lw_support":
			LivingAI.draw(self, sheet, tint)
		"echo_charge", "echo_volley":
			EchoAI.draw(self, sheet, tint)
		"animal":
			# Wild dier: twee stapplaatjes, twee vluchtplaatjes (het kijkt naar rechts, net als de slijmen)
			DrawUtil.ellipse(self, Vector2(0, size * 0.44), Vector2(shadow, shadow * 0.35), Color(0, 0, 0, 0.3))
			var column := int(anim * 0.9) % 2 + (2 if fleeing else 0)
			DrawUtil.sprite(self, sheet, column, 0, Vector2.ZERO, cell, scale, tint)
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
		"mage":
			var hover := -5.0 + sin(t * 3.0) * 2.0
			var puffing := state == "vanish" or state == "appear"
			DrawUtil.ellipse(self, Vector2(0, size * 0.44), Vector2(shadow * (0.6 if puffing else 1.0), shadow * 0.3), Color(0, 0, 0, 0.2))
			var column := int(t * 2.2) % 2
			var sprite_scale := scale
			if puffing:
				# Het wolkje zwelt aan en vervaagt bij het verdwijnen en krimpt weer bij het verschijnen.
				var p := clampf(state_time / float(data["vanish_time" if state == "vanish" else "appear_time"]), 0.0, 1.0)
				column = 3
				hover = -2.0
				sprite_scale = scale * ((1.0 + 0.4 * p) if state == "vanish" else (1.4 - 0.4 * p))
				tint.a = (1.0 - 0.5 * p) if state == "vanish" else (0.5 + 0.5 * p)
			elif state == "cast" or action_flash > 0.0:
				column = 2 # handen omhoog, ook nog heel even na het schot
			DrawUtil.sprite(self, sheet, column, 0, Vector2(0, hover), cell, sprite_scale, tint)
			if state == "cast":
				_draw_mage_charge(hover)
		"spitter":
			DrawUtil.ellipse(self, Vector2(0, size * 0.44), Vector2(shadow * (1.0 - air_height / 40.0), shadow * 0.35), Color(0, 0, 0, 0.3))
			var column := int(anim * 0.6) % 2
			var offset := Vector2(0, -air_height)
			var sprite_scale := scale
			if state == "windup":
				# Hij blaast zich op en trilt: nu komt er een waaier aan.
				var p := clampf(state_time / float(data["windup"]), 0.0, 1.0)
				column = 2
				offset.x = randf_range(-1.0, 1.0) * p * 1.5
				sprite_scale = scale * (1.0 + 0.12 * p)
				_draw_fan_hint(p)
			elif state == "hop":
				column = 4
			elif action_flash > 0.0:
				column = 3
			DrawUtil.sprite(self, sheet, column, 0, offset, cell, sprite_scale, tint)
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


## De aanloop van de Magiër: zijn handen gloeien en boven zijn hoofd groeit een bol.
func _draw_mage_charge(hover: float) -> void:
	var p := clampf(state_time / float(data["cast_time"]), 0.0, 1.0)
	var pulse := 0.6 + 0.4 * sin(t * 40.0)
	for side: float in [-1.0, 1.0]:
		draw_circle(Vector2(side * 11.0, -12.0 + hover), 5.0 + 3.0 * p, Color(1.0, 0.6, 1.0, (0.25 + 0.3 * p) * pulse))
	var center := Vector2(0, MAGE_ORB_HEIGHT - 8.0 + hover)
	var radius_now := 2.0 + 6.0 * p
	draw_circle(center, radius_now + 3.0, Color(MAGE_COLOR, 0.25))
	draw_circle(center, radius_now, Color(0.75, 0.5, 1.0, 0.9))
	draw_circle(center, radius_now * 0.5, Color(1, 1, 1, 0.95))
	for i in 4:
		var angle := t * 9.0 + TAU * float(i) / 4.0
		draw_rect(Rect2(center + Vector2.from_angle(angle) * (radius_now + 4.0) - Vector2(1, 1), Vector2(2, 2)), Color(1, 0.8, 1, 0.9))


## Streepjes laten zien waar de slijmballen heen gaan. Tijdens de aanloop worden ze langer en feller, en met hun
## donkere rand zie je ze ook goed op gras.
func _draw_fan_hint(progress: float) -> void:
	var fan: int = data["fan"]
	var alpha := 0.5 + 0.5 * progress
	var tip := 26.0 + 16.0 * progress
	for i in fan:
		var direction := aim_dir.rotated((float(i) - float(fan - 1) / 2.0) * float(data["fan_spread"]))
		var from := Vector2(0, 6) + direction * 16.0
		var to := Vector2(0, 6) + direction * tip
		draw_line(from, to, Color(0.1, 0.2, 0.05, 0.6 * alpha), 4.0)
		draw_line(from, to, Color(1.0, 1.0, 0.7, alpha), 2.0)
