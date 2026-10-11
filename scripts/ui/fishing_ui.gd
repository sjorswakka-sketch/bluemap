extends CanvasLayer
## Het visspel. Wordt gestart door een visplek (scripts/entities/meer_visplek.gd) en zet het spel stil zolang het open is.
##
##   cast   de dobber vliegt het water in
##   wait   wachten op een beet (1 tot 3 seconden, willekeurig)
##   bite   BEET! Druk binnen 0,8 seconde op E, anders ontsnapt de vis
##   reel   binnenhalen: houd de vis in de groene zone (zie fishing_reel.gd)
##   result een kaartje met wat je gevangen hebt (of dat hij ontsnapt is)
##
## Esc, P of B (dodge) stopt altijd en geeft de besturing terug. E op het kaartje gooit opnieuw uit.
## Voor tests: `forced_catch` bepaalt welke vis bijt, `forced_wait` hoe lang je wacht en `rng.seed` de rest.

const Art := preload("res://scripts/core/art.gd")
const Items := preload("res://scripts/data/items.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")
const Util := preload("res://scripts/core/util.gd")
const Vis := preload("res://scripts/data/ext/meer_vis.gd")
const Logic := preload("res://scripts/data/ext/meer_logic.gd")
const Reel := preload("res://scripts/ui/fishing_reel.gd")

const CAST_TIME := 0.5
const BITE_WINDOW := 0.8 # zo lang heb je om op E te drukken als de dobber zakt
const RESULT_LOCK := 0.5 # het kaartje blijft even staan, zodat je er niet per ongeluk doorheen klikt
const ART_PIXEL := 4.0 # één pixel van de art is 4 pixels op het scherm (2x vergroot in de wereld, 2x camerazoom)
const HASPEL_INTERVAL := 0.36 # zo vaak klikt de haspel terwijl je binnenhaalt

# Indeling van het scherm (1152x648): rechts het binnenhaal-paneel, onderin de status, in het midden het kaartje.
const REEL_PANEL := Rect2(826, 120, 270, 400)
const BAR := Rect2(872, 190, 64, 280) # de balk waarin de vis en de zone bewegen
const PROGRESS := Rect2(962, 190, 26, 280) # de voortgangsbalk ernaast
const STATUS_PANEL := Rect2(326, 468, 500, 70) # boven de meldingen van de HUD, die onderin verschijnen
const RESULT_CARD := Rect2(346, 150, 460, 300)
const PANEL_COLOR := Color(0.05, 0.08, 0.18, 0.92)
const PANEL_BORDER := Color(0.45, 0.75, 1.0)
const LINE_COLOR := Color(0.92, 0.95, 1.0, 0.9)
const GOLD := Color(1.0, 0.88, 0.35)

var phase := "idle" # idle, cast, wait, bite, reel of result
var outcome := "" # bij result: gevangen, te_laat of ontsnapt
var catch_id := "" # de vis die bijt of die je gevangen hebt
var phase_time := 0.0
var wait_time := 0.0
var reel: RefCounted # fishing_reel.gd, alleen tijdens het binnenhalen
var spot: Node2D
var world: Node
var rng := RandomNumberGenerator.new()
var forced_catch := ""
var forced_wait := -1.0
var opened_frame := -1
var haspel_timer := 0.0
var root: Control


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	root.draw.connect(_draw_content)
	add_child(root)


func _exit_tree() -> void:
	GameState.set_ui("vissen", false)


## Begint met vissen bij deze visplek.
func start(new_spot: Node2D) -> void:
	if phase != "idle":
		return
	spot = new_spot
	world = Util.world(self)
	var to_spot: Vector2 = spot.global_position - world.player.global_position
	if to_spot.length() > 1.0:
		world.player.facing = to_spot.normalized() # de speler kijkt naar het water
	opened_frame = Engine.get_process_frames()
	root.visible = true
	GameState.set_ui("vissen", true)
	_cast()


func close() -> void:
	phase = "idle"
	reel = null
	root.visible = false
	GameState.set_ui("vissen", false)
	Sound.play("select", -6.0)


func _cast() -> void:
	phase = "cast"
	phase_time = 0.0
	Sound.play("dodge", -8.0, 1.4)


func _land() -> void:
	phase = "wait"
	phase_time = 0.0
	wait_time = forced_wait if forced_wait >= 0.0 else rng.randf_range(Vis.WAIT_MIN, Vis.WAIT_MAX)
	Sound.play("meer_plons")
	_splash(spot.global_position, 22.0, 8)


func _bite() -> void:
	phase = "bite"
	phase_time = 0.0
	catch_id = forced_catch if forced_catch != "" else Vis.roll(rng, bool(spot.get("deep")), Logic.pity())
	Sound.play("meer_beet")
	_splash(spot.global_position, 16.0, 4)


func _start_reel() -> void:
	phase = "reel"
	phase_time = 0.0
	haspel_timer = 0.0
	reel = Reel.new(rng, Vis.stats(catch_id))


func _finish(result: String) -> void:
	phase = "result"
	phase_time = 0.0
	outcome = result
	reel = null
	if result == "gevangen":
		GameState.give(catch_id, 1, true)
		Logic.record_catch(catch_id, bool(spot.get("deep")))
		Sound.play("meer_vangst")
		_splash(spot.global_position, 30.0, 14)
		if catch_id == Vis.GOLDEN:
			Sound.play("crystal", -2.0)
			GameState.toast.emit("Je hebt de Gouden Karper gevangen!")
	else:
		Sound.play("meer_ontsnapt")


func _splash(at: Vector2, radius: float, sparks: int) -> void:
	world.ring(at, radius, Color(1, 1, 1, 0.9))
	world.burst(at, Color(0.8, 0.92, 1.0), sparks)


func _process(delta: float) -> void:
	if phase == "idle":
		return
	phase_time += delta
	match phase:
		"cast":
			if phase_time >= CAST_TIME:
				_land()
		"wait":
			if phase_time >= wait_time:
				_bite()
		"bite":
			if phase_time >= BITE_WINDOW:
				_finish("te_laat")
		"reel":
			_update_reel(delta)
	root.queue_redraw()


func _update_reel(delta: float) -> void:
	reel.update(delta, Input.is_action_pressed("interact"))
	haspel_timer -= delta
	if reel.in_zone and haspel_timer <= 0.0:
		haspel_timer = HASPEL_INTERVAL
		Sound.play("meer_haspel", -9.0)
	if reel.state != "bezig":
		_finish(reel.state)


func _unhandled_input(event: InputEvent) -> void:
	if phase == "idle" or Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("dodge"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if phase == "bite":
			_start_reel()
		elif phase == "result" and phase_time >= RESULT_LOCK:
			_cast()


# --- Tekenen ---------------------------------------------------------------------------------------

func _screen(world_pos: Vector2) -> Vector2:
	return root.get_viewport().get_canvas_transform() * world_pos


func _rod_tip() -> Vector2:
	var player: Node2D = world.player
	return player.global_position + player.facing * 12.0 + Vector2(0, -6)


func _bobber_world() -> Vector2:
	var tip := _rod_tip()
	var target: Vector2 = spot.global_position
	match phase:
		"cast":
			var f := clampf(phase_time / CAST_TIME, 0.0, 1.0)
			return tip.lerp(target, f) + Vector2(0, -sin(f * PI) * 40.0)
		"wait":
			return target + Vector2(0, sin(phase_time * 3.0) * 1.5)
		"bite":
			return target + Vector2(sin(phase_time * 50.0) * 2.0, 3.0)
		"reel":
			# Hoe voller de balk, hoe dichter de dobber bij jou komt.
			return target.lerp(tip, maxf(reel.progress - Reel.START_PROGRESS, 0.0) * 0.8)
	return target


func _text(pos: Vector2, text: String, size: int, color := Color.WHITE, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := ThemeDB.fallback_font
	root.draw_string_outline(font, pos, text, align, width, size, 5, Color(0, 0, 0, 0.9))
	root.draw_string(font, pos, text, align, width, size, color)


func _panel(rect: Rect2) -> void:
	root.draw_style_box(UiStyle.flat(PANEL_COLOR, PANEL_BORDER, 3), rect)


func _draw_content() -> void:
	if phase == "idle":
		return
	if phase != "result":
		_draw_line_and_bobber()
	match phase:
		"cast":
			_draw_status("Je gooit uit...", "")
		"wait":
			_draw_status("Wacht op een beet" + ".".repeat(1 + int(phase_time * 2.0) % 3), "Esc: stoppen")
		"bite":
			_draw_bite()
		"reel":
			_draw_reel()
		"result":
			_draw_result()


func _draw_line_and_bobber() -> void:
	var tip := _screen(_rod_tip())
	var bobber := _screen(_bobber_world())
	var sag := 12.0 if phase in ["cast", "reel"] else 26.0
	var points := PackedVector2Array()
	for i in 15:
		var f := float(i) / 14.0
		points.append(tip.lerp(bobber, f) + Vector2(0, sin(f * PI) * sag))
	root.draw_polyline(points, LINE_COLOR, 2.0)
	# Kringetjes rond de dobber zodra hij in het water ligt
	if phase in ["wait", "bite", "reel"]:
		root.draw_set_transform(bobber + Vector2(0, 8), 0.0, Vector2(1.0, 0.5))
		for i in 2:
			var ring := fmod(phase_time * 0.8 + i * 0.5, 1.0)
			root.draw_arc(Vector2.ZERO, 10.0 + ring * 34.0, 0.0, TAU, 28, Color(1, 1, 1, (1.0 - ring) * 0.7), 3.0)
		root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var dipped := phase == "bite" and int(phase_time * 14.0) % 2 == 1
	root.draw_texture_rect_region(Art.tex("meer_ui"), Rect2(bobber - Vector2(8.0, 10.0) * ART_PIXEL, Vector2(16, 16) * ART_PIXEL),
		Rect2(Vector2(16 if dipped else 0, 0), Vector2(16, 16)))


func _draw_status(line: String, hint: String) -> void:
	var rect := STATUS_PANEL
	_panel(rect)
	_text(Vector2(rect.position.x, rect.position.y + 34), line, 26, Color.WHITE, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if hint != "":
		_text(Vector2(rect.position.x, rect.position.y + 58), hint, 16, Color(1, 1, 1, 0.6), rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_bite() -> void:
	# Een uitroepteken boven het hoofd van de speler en een balk die leegloopt: nu snel!
	var head := _screen(world.player.global_position) + Vector2(-32, -140 + sin(phase_time * 30.0) * 4.0)
	root.draw_texture_rect_region(Art.tex("meer_ui"), Rect2(head, Vector2(16, 16) * ART_PIXEL), Rect2(Vector2(32, 0), Vector2(16, 16)))
	_draw_status("BEET!  Druk snel op E!", "")
	var left := clampf(1.0 - phase_time / BITE_WINDOW, 0.0, 1.0)
	root.draw_rect(Rect2(STATUS_PANEL.position + Vector2(10, STATUS_PANEL.size.y - 14), Vector2((STATUS_PANEL.size.x - 20.0) * left, 8)), Color(1.0, 0.45, 0.35))


func _draw_reel() -> void:
	var panel := REEL_PANEL
	_panel(panel)
	_text(Vector2(panel.position.x, 160), "Binnenhalen!", 26, GOLD, panel.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# De balk met de groene zone en de vis
	root.draw_rect(BAR, Color(0.07, 0.13, 0.3))
	for i in range(1, 10):
		root.draw_line(Vector2(BAR.position.x, BAR.position.y + BAR.size.y * i / 10.0),
			Vector2(BAR.position.x + 10, BAR.position.y + BAR.size.y * i / 10.0), Color(0.3, 0.45, 0.7), 2.0)
	var zone_h: float = reel.zone_size * BAR.size.y
	var zone_y: float = BAR.position.y + BAR.size.y * (1.0 - reel.zone_pos) - zone_h / 2.0
	var zone := Rect2(BAR.position.x + 4, zone_y, BAR.size.x - 8, zone_h)
	root.draw_rect(zone, Color(0.3, 0.9, 0.45, 0.9 if reel.in_zone else 0.6))
	root.draw_rect(zone, Color(0.8, 1.0, 0.85), false, 3.0)
	root.draw_rect(BAR, Color(0.45, 0.75, 1.0), false, 3.0)
	var fish_y: float = BAR.position.y + BAR.size.y * (1.0 - reel.fish_pos)
	var wiggle := sin(phase_time * 14.0) * 2.0
	var icon: int = int(Items.info(catch_id)["icon"])
	root.draw_texture_rect_region(Art.tex(Items.sheet_of(catch_id)), Rect2(BAR.position.x + 16 + wiggle, fish_y - 16, 32, 32),
		Rect2(Vector2(icon * 16, 0), Vector2(16, 16)))
	# De voortgangsbalk: vult zich als de vis in de zone zit
	root.draw_rect(PROGRESS, Color(0.07, 0.13, 0.3))
	var filled: float = PROGRESS.size.y * reel.progress
	var fill_color := Color(0.3, 0.9, 0.45) if reel.in_zone else Color(0.95, 0.55, 0.3)
	root.draw_rect(Rect2(PROGRESS.position.x, PROGRESS.position.y + PROGRESS.size.y - filled, PROGRESS.size.x, filled), fill_color)
	root.draw_rect(PROGRESS, Color(0.45, 0.75, 1.0), false, 3.0)
	_text(Vector2(panel.position.x, 498), "Houd E ingedrukt: omhoog", 16, Color(1, 1, 1, 0.75), panel.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_status("Houd de vis in het groen!", "Laat E los om te zakken  ·  Esc: stoppen")


func _draw_result() -> void:
	var card := RESULT_CARD
	_panel(card)
	var info := Items.info(catch_id)
	match outcome:
		"gevangen":
			_text(Vector2(card.position.x, 196), "Gevangen!", 34, GOLD, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			var icon: int = int(info["icon"])
			var bob := sin(phase_time * 5.0) * 4.0
			root.draw_texture_rect_region(Art.tex(Items.sheet_of(catch_id)), Rect2(card.position.x + card.size.x / 2.0 - 48, 214 + bob, 96, 96),
				Rect2(Vector2(icon * 16, 0), Vector2(16, 16)))
			_text(Vector2(card.position.x, 346), info["name"], 28, Color.WHITE, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			_text(Vector2(card.position.x, 378), _catch_note(), 18, Color(0.85, 0.93, 1.0), card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			if catch_id == Vis.GOLDEN:
				_draw_sparkles(card)
		"te_laat":
			_text(Vector2(card.position.x, 250), "Te laat!", 34, Color(1.0, 0.55, 0.45), card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			_text(Vector2(card.position.x, 296), "De vis is ontsnapt.", 22, Color.WHITE, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			_text(Vector2(card.position.x, 330), "Druk sneller op E als de dobber zakt.", 18, Color(0.85, 0.93, 1.0), card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_:
			_text(Vector2(card.position.x, 250), "Hij is ontsnapt!", 34, Color(1.0, 0.55, 0.45), card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			_text(Vector2(card.position.x, 296), "De lijn werd te slap.", 22, Color.WHITE, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			_text(Vector2(card.position.x, 330), "Houd de vis in de groene zone.", 18, Color(0.85, 0.93, 1.0), card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(card.position.x, 428), "E: nog een keer   ·   Esc: stoppen", 18, Color(1, 1, 1, 0.65), card.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Een zinnetje bij de vangst.
func _catch_note() -> String:
	match catch_id:
		Vis.GOLDEN:
			if GameState.quest_state("meer_karper") == "active":
				return "Breng hem naar Visser Joris!"
			return "Zo zeldzaam! Joris zal er raar van opkijken."
		"meer_laars":
			return "Joris verzamelt ze. Waarde: 1 munt."
	return "Waarde: %d munten" % int(Vis.stats(catch_id)["sell"])


func _draw_sparkles(card: Rect2) -> void:
	for i in 8:
		var phase_i := fmod(phase_time * 1.3 + i * 0.37, 1.0)
		var angle := float(i) * 0.9 + 0.5
		var centre := Vector2(card.position.x + card.size.x / 2.0, 262.0)
		var at := centre + Vector2.from_angle(angle) * (70.0 + phase_i * 50.0)
		var size := sin(phase_i * PI) * 8.0
		root.draw_rect(Rect2(at - Vector2(size, 2) / 2.0, Vector2(size, 3)), Color(1, 0.95, 0.6))
		root.draw_rect(Rect2(at - Vector2(2, size) / 2.0, Vector2(3, size)), Color(1, 0.95, 0.6))
