extends Node2D
## De arenameester van het gevechtsveld: speelt een toernooi van begin tot eind.
##
## Wie zich bij Bruno heeft ingeschreven en door de deur komt, begint hier aan een rang. De poorten (de uitgang)
## sluiten, het publiek juicht en er komt ronde na ronde vijanden uit de poorten in de muur. Zijn ze allemaal
## verslagen, dan is er drie seconden rust en geeft het publiek je een hartje. Na de laatste ronde krijg je je
## beloning (Arena.complete). Word je verslagen of geef je op, dan eindigt het gevecht en word je in de hal gezet.
##
## Op de kaart: {"type": "arena_master", "pos": [12, 10], "field": [x0, y0, x1, y1], "exit": [x, y, breedte, hoogte],
##               "gates": [[x, y, dx, dy], ...]}  (poort in de muur en de richting waarin vijanden naar buiten komen)

const UiStyle := preload("res://scripts/core/ui_style.gd")
const Arena := preload("res://scripts/data/arena.gd")
const Enemies := preload("res://scripts/data/enemies.gd")

const TILE := 32.0
const INTRO_TIME := 3.2 # even wachten: de kaartnaam verdwijnt en het publiek warmt op
const REST_TIME := 3.0 # rust tussen twee rondes
const FIRST_SPAWN := 1.0 # na de gong duurt het even voor de eerste poort opengaat
const SPAWN_GAP := 0.45 # tussen twee vijanden
const WARN_TIME := 0.7 # het hek gaat omhoog, daarna komt de vijand naar buiten
const EMERGE_TIME := 0.4 # de vijand wordt zichtbaar en kan dan pas vechten
const SIGHT := 900.0 # vijanden in de arena zien je altijd (anders dwalen ze rond)
const FEET := 0.28 # de botsing van een vijand zit zo ver onder zijn midden (deel van zijn grootte, zoals in enemy.gd)
const WALL_GAP := 2.0 # zoveel ruimte tussen de voeten van een nieuwe vijand en de muur
const LOW_HP := 2 # zo weinig hartjes: het publiek gooit er eentje (een keer per ronde)
const DEFEAT_TIME := 1.8
const GATE_LIFT_TIME := 0.35 # hoe snel een hek omhoog en omlaag gaat
const GATE_HOLD_TIME := 0.9 # hoe lang het hek open blijft nadat er iemand door is
const HEART_FLIGHT := 0.8
const STATUS_SHIFT := -50.0
const DARK := Color(0.08, 0.06, 0.11)
const PHASES_ACTIVE := ["intro", "fight", "rest"]

var world: Node
var obj: Dictionary = {}
var key := ""

var phase := "idle" # idle, intro, fight, rest, done, defeat
var rank := ""
var rounds: Array = []
var round_index := -1
var timer := 0.0 # tot de volgende stap (begin, rust)
var run_time := 0.0 # sinds de eerste gong, zonder de tijd dat het spel stilstaat
var queue: Array = [] # vijanden die nog moeten komen: {kind, gate, delay}
var warnings: Array = [] # het hek gaat open, de vijand komt zo: {kind, gate, t, pos}
var foes: Array = [] # vijanden die er zijn
var emerging: Array = [] # vijanden die net uit de poort komen en nog niet kunnen vechten: {enemy, t}
var flying_hearts: Array = [] # hartjes die het publiek gooit: {heart, from, land, t}
var gates: Array = []
var field := Rect2()
var rng := RandomNumberGenerator.new()
var heart_thrown := false
var gate_lift: Dictionary = {} # poort -> hoe ver het hek omhoog is (0 tot 1)
var gate_hold: Dictionary = {} # poort -> hoe lang het hek nog open blijft
var cheer_cooldown := 0.0
var player: Node2D

var ui: CanvasLayer
var banner_box: VBoxContainer
var banner_title: Label
var banner_sub: Label
var banner_time := 0.0
var banner_total := 1.0
var status_panel: PanelContainer
var status: Label


func _ready() -> void:
	add_to_group("arena_master")
	position = Vector2.ZERO # we tekenen in kaartcoördinaten
	player = world.player
	gates = obj.get("gates", [])
	var f: Array = obj.get("field", [0, 0, 0, 0])
	field = Rect2(Vector2(f[0], f[1]) * TILE, Vector2(f[2] - f[0] + 1, f[3] - f[1] + 1) * TILE)
	rng.randomize()
	_build_ui()
	var signed_up := Arena.registered_rank()
	if signed_up != "":
		start_run(signed_up)


func _exit_tree() -> void:
	_release_run()


## Begint een toernooi: de poorten gaan dicht. De inschrijving blijft staan tot de eerste gong: als het spel
## in de tussentijd wordt afgesloten en je doorgaat vanaf de opslag, begin je gewoon weer vooraan en ben je niets kwijt.
func start_run(rank_id: String) -> void:
	rank = rank_id
	rounds = Arena.RANKS[rank]["rounds"]
	Arena.run_active = true
	Arena.run_owner = get_instance_id()
	GameState.defeat_handler = _on_defeat
	round_index = -1
	run_time = 0.0
	phase = "intro"
	timer = INTRO_TIME
	var info: Dictionary = Arena.RANKS[rank]
	_set_banner("%s-rang" % info["name"], "De poorten sluiten. %d rondes!" % rounds.size(), info["color"], INTRO_TIME)
	_hide_map_name.call_deferred() # onze banner vervangt de kaartnaam
	_cheer_crowd(0.6)
	Sound.play("arena_crowd", -6.0)
	Sound.play("slam", -5.0) # het hek voor de uitgang valt dicht
	world.shake(3.0)
	var exit_tiles: Array = obj.get("exit", [])
	if exit_tiles.size() == 4:
		var center := Vector2((float(exit_tiles[0]) + float(exit_tiles[2]) / 2.0) * TILE, (float(exit_tiles[1]) + float(exit_tiles[3]) / 2.0) * TILE)
		world.burst(center, Color(0.8, 0.7, 0.55), 14)
		world.ring(center, 40.0, Color(0.9, 0.8, 0.6))


func _hide_map_name() -> void:
	world.hud.banner_time = 0.0


## Opgeven (de gong): het gevecht stopt en je wordt in de hal gezet.
func forfeit() -> void:
	if phase in PHASES_ACTIVE:
		_lose("quit")


## Hoeveel vijanden er nog zijn of nog komen.
func foes_left() -> int:
	return queue.size() + warnings.size() + _alive().size()


func _process(delta: float) -> void:
	cheer_cooldown = maxf(cheer_cooldown - delta, 0.0)
	_update_gates(delta)
	_update_emerging(delta)
	_update_hearts(delta)
	_update_banner(delta)
	match phase:
		"intro":
			timer -= delta
			if timer <= 0.0:
				_start_round(0)
		"fight":
			run_time += delta
			_tick_spawns(delta)
			if not _check_round_end():
				_check_low_hp()
		"rest":
			run_time += delta
			timer -= delta
			if timer <= 0.0:
				_start_round(round_index + 1)
	_update_status()
	queue_redraw()


# --- Rondes -----------------------------------------------------------------------------------

func _start_round(index: int) -> void:
	GameState.set_flag(Arena.SIGNED_FLAG % rank, false) # de inschrijving is gebruikt
	round_index = index
	phase = "fight"
	heart_thrown = false
	var last := index == rounds.size() - 1
	var info: Dictionary = Arena.RANKS[rank]
	_set_banner("Ronde %d" % (index + 1), "Laatste ronde!" if last else "", info["color"], 2.4)
	Sound.play("arena_gong")
	_cheer_crowd(0.7)
	world.shake(2.5)
	var gong := get_tree().get_first_node_in_group("arena_gong")
	if gong != null:
		gong.strike()

	var kinds: Array = []
	for entry: Array in rounds[index]:
		for i in int(entry[1]):
			kinds.append(entry[0])
	_shuffle(kinds)
	var order: Array = range(gates.size())
	_shuffle(order)
	queue.clear()
	for i in kinds.size():
		queue.append({"kind": kinds[i], "gate": order[i % order.size()], "delay": FIRST_SPAWN + i * SPAWN_GAP, "t": 0.0, "pos": Vector2.ZERO})


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp


func _tick_spawns(delta: float) -> void:
	for entry in queue:
		entry["delay"] -= delta
	while not queue.is_empty() and queue[0]["delay"] <= 0.0:
		var entry: Dictionary = queue.pop_front()
		entry["pos"] = _spawn_point(entry["gate"], entry["kind"])
		warnings.append(entry)
		_open_gate(entry["gate"])
	for entry in warnings:
		entry["t"] += delta
	while not warnings.is_empty() and warnings[0]["t"] >= WARN_TIME:
		_emerge(warnings.pop_front())


## Waar een vijand uit een poort komt: het eerste stukje zand voor de poort, met een beetje spreiding langs de muur.
## Uit de onderste muur komt hij iets hoger tevoorschijn: zijn voeten (daar zit zijn botsing) moeten op het zand staan,
## ook bij een grote golem.
func _spawn_point(gate_index: int, kind: String) -> Vector2:
	var gate: Array = gates[gate_index]
	var out := Vector2(float(gate[2]), float(gate[3]))
	var pos := (Vector2(float(gate[0]), float(gate[1])) + out + Vector2(0.5, 0.5)) * TILE
	if out.y < 0.0:
		var info: Dictionary = Enemies.info(kind)
		var feet := float(info["cell"]) * float(info["scale"]) * FEET + float(info["radius"]) + WALL_GAP
		pos.y = minf(pos.y, float(gate[1]) * TILE - feet)
	var side := Vector2(absf(out.y), absf(out.x)) # langs de muur
	return pos + side * rng.randf_range(-8.0, 8.0)


func _emerge(entry: Dictionary) -> void:
	var pos: Vector2 = entry["pos"]
	var enemy: Node2D = world.spawn_enemy(entry["kind"], pos)
	enemy.data = enemy.data.duplicate(true) # los van de gedeelde gegevens, we passen dit ene exemplaar aan
	enemy.data["sight"] = SIGHT
	enemy.data["drops"] = [] # in de arena gaat het om de eer, niet om de buit
	enemy.active = false
	enemy.modulate.a = 0.0
	enemy.died.connect(_on_foe_died)
	foes.append(enemy)
	emerging.append({"enemy": enemy, "t": 0.0})
	world.burst(pos, Color(0.85, 0.72, 0.5), 10)
	world.ring(pos, 26.0, Color(1.0, 0.85, 0.55))
	if enemy.data.get("boss", false):
		Sound.play("boss", -4.0)
		Sound.play_music("boss")
		world.shake(4.0)


## De vijanden die uit de poort komen worden zichtbaar en kunnen daarna pas vechten (en geraakt worden).
func _update_emerging(delta: float) -> void:
	for entry in emerging:
		var enemy: Variant = entry["enemy"] # kan al weg zijn (opgeruimd)
		if not is_instance_valid(enemy):
			entry["t"] = EMERGE_TIME
			continue
		entry["t"] += delta
		enemy.modulate.a = clampf(entry["t"] / EMERGE_TIME, 0.0, 1.0)
		if entry["t"] >= EMERGE_TIME and not enemy.dead:
			enemy.active = true
	emerging = emerging.filter(func(entry: Dictionary) -> bool: return entry["t"] < EMERGE_TIME)


func _alive() -> Array:
	return foes.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not e.dead)


## Geeft true terug als de ronde voorbij is.
func _check_round_end() -> bool:
	foes = _alive()
	if not queue.is_empty() or not warnings.is_empty() or not foes.is_empty():
		return false
	_round_clear()
	return true


func _round_clear() -> void:
	if round_index >= rounds.size() - 1:
		_victory()
		return
	phase = "rest"
	timer = REST_TIME
	_clear_projectiles() # een pijl die nog onderweg is mag je in de rust niet meer raken
	_set_banner("Ronde %d gehaald!" % (round_index + 1), "Even rust...", Color(0.6, 1.0, 0.7), REST_TIME)
	Sound.play("arena_crowd", -3.0)
	_cheer_crowd(1.0)
	if GameState.hp < GameState.max_hp():
		GameState.heal(1)
		Sound.play("heart", -3.0)
		world.damage_number(player.global_position + Vector2(0, -18), "+", Color(1.0, 0.5, 0.65))
		world.burst(player.global_position, Color(1.0, 0.5, 0.65), 10)


func _on_foe_died() -> void:
	_cheer_crowd(0.25)
	if cheer_cooldown <= 0.0:
		cheer_cooldown = 0.6
		Sound.play("arena_cheer", -8.0, rng.randf_range(0.9, 1.1))


# --- Het publiek ---------------------------------------------------------------------------------

func _cheer_crowd(strength: float) -> void:
	var crowd := get_tree().get_first_node_in_group("arena_crowd")
	if crowd != null:
		crowd.cheer(strength)


## Het publiek gooit een hartje als het slecht gaat: een keer per ronde.
func _check_low_hp() -> void:
	if heart_thrown or GameState.hp > LOW_HP or GameState.hp <= 0:
		return
	heart_thrown = true
	var crowd := get_tree().get_first_node_in_group("arena_crowd")
	if crowd == null:
		return
	var from: Vector2 = crowd.seat_near(player.global_position)
	var heart: Node2D = world.spawn_pickup("heart", from)
	heart.set_process(false) # tijdens de vlucht doet het hartje niets
	flying_hearts.append({"heart": heart, "from": from, "land": _landing_spot(player.global_position), "t": 0.0})
	_cheer_crowd(0.6)
	Sound.play("arena_cheer", -4.0)
	GameState.toast.emit("Het publiek gooit een hartje!")


## Het hartje vliegt in een boog van de tribune naar het zand.
func _update_hearts(delta: float) -> void:
	for entry in flying_hearts:
		var heart: Variant = entry["heart"] # kan al weg zijn (opgepakt of opgeruimd)
		if not is_instance_valid(heart):
			entry["t"] = HEART_FLIGHT
			continue
		entry["t"] += delta
		var progress := clampf(entry["t"] / HEART_FLIGHT, 0.0, 1.0)
		heart.global_position = (entry["from"] as Vector2).lerp(entry["land"], progress) + Vector2(0, -sin(progress * PI) * 48.0)
		if progress >= 1.0:
			heart.set_process(true)
	flying_hearts = flying_hearts.filter(func(entry: Dictionary) -> bool: return entry["t"] < HEART_FLIGHT)


## Een plek op het zand, een stukje van de speler af, in de richting van het midden van het veld.
func _landing_spot(from: Vector2) -> Vector2:
	var to_center := field.get_center() - from
	var direction := to_center.normalized() if to_center.length() > 24.0 else Vector2.from_angle(rng.randf() * TAU)
	var spot := from + direction * 90.0
	var margin := TILE * 1.5
	return Vector2(clampf(spot.x, field.position.x + margin, field.end.x - margin),
		clampf(spot.y, field.position.y + margin, field.end.y - margin))


# --- Winnen en verliezen -----------------------------------------------------------------------------

func _victory() -> void:
	phase = "done"
	var info: Dictionary = Arena.RANKS[rank]
	var result := Arena.complete(rank, run_time)
	_release_run()
	_clear_projectiles() # een pijl of steen die nog vliegt kan je na de overwinning niet meer raken
	world.autosave() # de beloning is binnen, ook als je het spel nu afsluit
	var shown := "Nieuw record: %s" if result["record"] and not result["first_time"] else "Tijd: %s"
	_set_banner("%s gehaald!" % info["name"], shown % Arena.format_time(run_time), info["color"], 6.0)
	Sound.play("arena_fanfare")
	Sound.play("arena_crowd")
	Sound.play_music("arena")
	_cheer_crowd(1.0)
	for i in 6:
		world.burst(player.global_position + Vector2.from_angle(float(i) * TAU / 6.0) * 40.0, Color(1.0, 0.85, 0.35), 14)
	world.ring(player.global_position, 70.0, info["color"])
	world.shake(3.0)


## De haak in GameState.hurt: als je in de arena op 0 hartjes komt is dat geen game over.
func _on_defeat() -> bool:
	if phase == "defeat":
		return true # we zijn al bezig
	if phase in PHASES_ACTIVE:
		_lose("defeat")
		return true
	return false


## Het gevecht is voorbij omdat je verslagen bent ("defeat") of opgegeven hebt ("quit"). Na een korte pauze sta je
## in de hal, helemaal beter. Alles wat tijdelijk aanstond (inschrijving, poorten, handler, invoer) gaat weer uit.
func _lose(reason: String) -> void:
	phase = "defeat"
	GameState.set_flag(Arena.SIGNED_FLAG % rank, false) # de inschrijving is gebruikt, ook als je opgeeft voor de eerste gong
	GameState.transitioning = true # tot we in de hal staan kan niemand iets doen
	var lost := reason == "defeat"
	_set_banner("Verslagen!" if lost else "Opgegeven", "Bruno vangt je op in de hal." if lost else "Geen schande!", Color(1.0, 0.45, 0.4), DEFEAT_TIME + 0.4)
	Sound.play("arena_defeat" if lost else "arena_gong")
	_clear_field()
	await get_tree().create_timer(DEFEAT_TIME).timeout
	await world.fader.fade_out(0.4)
	# Vanaf hier mag er niets meer op een `await` wachten: load_map ruimt deze arenameester op.
	GameState.full_heal()
	GameState.set_flag("arena_just_lost" if lost else "arena_just_quit")
	_release_run()
	world.player.invuln = 0.0
	world.player.knockback = Vector2.ZERO
	world.load_map("arena_hall", "from_arena")
	world.autosave()
	GameState.transitioning = false
	world.fader.fade_in(0.4)


## Alle vijanden en alles wat ze afgeschoten hebben verdwijnt in een wolkje.
func _clear_field() -> void:
	queue.clear()
	warnings.clear()
	foes.clear()
	emerging.clear()
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		enemy.remove_from_group("enemies")
		enemy.remove_from_group("boss")
		world.burst(enemy.global_position, Color(0.9, 0.9, 0.95), 8)
		enemy.queue_free()
	_clear_projectiles()


func _clear_projectiles() -> void:
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with("projectile.gd"):
			world.burst(child.global_position, Color(0.9, 0.9, 0.9), 4)
			child.queue_free()


## Het toernooi is voorbij: de poorten gaan open en het verlies wordt niet meer door ons afgehandeld.
func _release_run() -> void:
	if Arena.run_owner == get_instance_id(): # niet als een nieuwe arenameester het toernooi al heeft overgenomen
		Arena.run_active = false
		Arena.run_owner = 0
	if GameState.defeat_handler == _on_defeat:
		GameState.defeat_handler = Callable()


# --- Poorten ------------------------------------------------------------------------------------------

func _open_gate(index: int) -> void:
	if not gate_lift.has(index):
		gate_lift[index] = 0.0
		Sound.play("arena_gate", -7.0)
		var gate: Array = gates[index]
		world.burst(Vector2((float(gate[0]) + 0.5) * TILE, (float(gate[1]) + 0.5) * TILE), Color(0.8, 0.7, 0.55), 8)
	gate_hold[index] = GATE_HOLD_TIME


func _update_gates(delta: float) -> void:
	for index: int in gate_lift.keys():
		var hold: float = gate_hold.get(index, 0.0) - delta
		gate_hold[index] = hold
		var lift: float = move_toward(gate_lift[index], 1.0 if hold > 0.0 else 0.0, delta / GATE_LIFT_TIME)
		if lift <= 0.0 and hold <= 0.0:
			gate_lift.erase(index)
			gate_hold.erase(index)
		else:
			gate_lift[index] = lift


func _draw() -> void:
	for index: int in gate_lift:
		_draw_gate(gates[index], gate_lift[index])
	for entry in warnings:
		var progress: float = clampf(entry["t"] / WARN_TIME, 0.0, 1.0)
		var pos: Vector2 = entry["pos"]
		draw_circle(pos + Vector2(0, 8), 10.0 + progress * 8.0, Color(1.0, 0.4, 0.25, 0.12 + progress * 0.2))
		draw_arc(pos + Vector2(0, 8), 6.0 + progress * 14.0, 0.0, TAU, 24, Color(1.0, 0.55, 0.3, 0.9), 2.0)


## Het gat in de muur met het hek dat omhoog schuift (lift 0 = dicht, 1 = helemaal open).
func _draw_gate(gate: Array, lift: float) -> void:
	var origin := Vector2(float(gate[0]), float(gate[1])) * TILE
	var opening := PackedVector2Array()
	for i in 11:
		var angle := PI + PI * float(i) / 10.0
		opening.append(origin + Vector2(15.0 + cos(angle) * 11.0, 12.0 + sin(angle) * 10.0))
	opening.append(origin + Vector2(26.0, 32.0))
	opening.append(origin + Vector2(4.0, 32.0))
	draw_colored_polygon(opening, DARK)
	var bottom := 6.0 + 26.0 * (1.0 - lift)
	if bottom > 7.0:
		for x in [8.0, 14.0, 20.0]:
			draw_line(origin + Vector2(x, 4.0), origin + Vector2(x, bottom), Color(0.45, 0.48, 0.58), 2.0)
		draw_line(origin + Vector2(6.0, bottom), origin + Vector2(24.0, bottom), Color(0.27, 0.29, 0.36), 3.0)


# --- Beeld: banner en tellertje ---------------------------------------------------------------------

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 9
	add_child(ui)
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.anchor_left = 0.0
	banner_box.anchor_right = 1.0
	banner_box.offset_left = 0.0
	banner_box.offset_right = 0.0
	banner_box.offset_top = 140.0 # boven de speler (die midden in beeld staat)
	banner_box.modulate.a = 0.0
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(banner_box)
	banner_title = UiStyle.make_label("", 64, Color.WHITE)
	banner_box.add_child(banner_title)
	banner_sub = UiStyle.make_label("", 28, Color(0.9, 0.95, 1.0))
	banner_box.add_child(banner_sub)

	status_panel = PanelContainer.new()
	status_panel.anchor_left = 0.5
	status_panel.anchor_right = 0.5
	status_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status_panel.offset_left = STATUS_SHIFT # een stukje naar links, zodat de opdracht rechtsboven vrij blijft
	status_panel.offset_right = STATUS_SHIFT
	status_panel.offset_top = 70.0
	status_panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.12, 0.08, 0.04, 0.78), Color(0.9, 0.7, 0.3, 0.9), 2))
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.visible = false
	ui.add_child(status_panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 18)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_panel.add_child(status)


func _set_banner(title: String, sub: String, color: Color, duration: float) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	banner_sub.visible = sub != ""
	banner_time = duration
	banner_total = duration


func _update_banner(delta: float) -> void:
	if banner_time > 0.0:
		banner_time -= delta
		banner_box.modulate.a = clampf(minf(banner_time, banner_total - banner_time) * 3.0, 0.0, 1.0)
	else:
		banner_box.modulate.a = 0.0


func _update_status() -> void:
	status_panel.visible = phase in PHASES_ACTIVE and round_index >= 0
	if not status_panel.visible:
		return
	status.text = "%s · Ronde %d/%d · Vijanden %d · %s" % [
		Arena.RANKS[rank]["name"], round_index + 1, rounds.size(), foes_left(), Arena.format_time(run_time)]
