extends CanvasLayer
## Alles wat bovenop het spel getekend wordt: hartjes, tellers, opdracht, meldingen,
## kaartnaam, baasbalk en het game-over-scherm.

const Art := preload("res://scripts/core/art.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")
const Items := preload("res://scripts/data/items.gd")
const Daynight := preload("res://scripts/core/daynight.gd")
const AchievementBanner := preload("res://scripts/ui/achievement_banner.gd")

var hearts: Control
var stats: Control
var tracker_panel: PanelContainer
var tracker: Label
var toast_panel: PanelContainer
var toast_label: Label
var banner: Label
var boss_bar: Control
var clock: Control # zon of maan, en welk deel van de dag het is
var stamina_bar: Control
var achievement_banner: CanvasLayer # de melding "Prestatie behaald!"
var clock_state := ""
var overlay: ColorRect
var overlay_title: Label
var overlay_sub: Label

var toast_queue: Array[String] = []
var toast_time := 0.0
var banner_time := 0.0
var banner_text := Callable() # geeft de tekst van de banner in de huidige taal (zie show_banner)
var boss: Node2D = null
var had_bow := false # om te zien wanneer je de boog voor het eerst krijgt


func _ready() -> void:
	layer = 10
	_build_ui()
	GameState.hp_changed.connect(func() -> void: hearts.queue_redraw())
	GameState.items_changed.connect(func() -> void: stats.queue_redraw(); _refresh_tracker())
	GameState.quests_changed.connect(_refresh_tracker)
	GameState.toast.connect(_queue_toast)
	GameState.game_over.connect(_show_game_over)
	_refresh_tracker()
	_queue_toast(tr("WASD lopen  ·  SPATIE zwaard  ·  SHIFT rollen  ·  E praten  ·  I menu  ·  ESC pauze"))
	_queue_toast(tr("CTRL / L3 vasthouden: rennen  ·  C / R3: beroepen en maken  ·  Paden geven extra snelheid"))
	# Boog: de pijlenteller (met "[F]") staat in beeld zodra je een boog hebt, en bij het krijgen ervan komt een melding.
	had_bow = GameState.count("bow") > 0
	GameState.items_changed.connect(_check_bow)
	Lang.changed.connect(_on_language_changed)


func _build_ui() -> void:
	hearts = Control.new()
	hearts.position = Vector2(20, 14)
	hearts.size = Vector2(560, 40)
	hearts.draw.connect(_draw_hearts)
	add_child(hearts)

	stats = Control.new()
	stats.position = Vector2(20, 58)
	stats.size = Vector2(500, 36)
	stats.draw.connect(_draw_stats)
	add_child(stats)

	clock = Control.new()
	clock.position = Vector2(20, 100)
	clock.size = Vector2(300, 36)
	clock.draw.connect(_draw_clock)
	add_child(clock)

	stamina_bar = Control.new()
	stamina_bar.position = Vector2(20, 146)
	stamina_bar.size = Vector2(280, 38)
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_bar.draw.connect(_draw_stamina)
	add_child(stamina_bar)

	tracker_panel = PanelContainer.new()
	tracker_panel.anchor_left = 1.0
	tracker_panel.anchor_right = 1.0
	tracker_panel.offset_left = -400.0
	tracker_panel.offset_right = -16.0
	tracker_panel.offset_top = 14.0
	var box := UiStyle.flat(Color(0.05, 0.08, 0.18, 0.7), Color(0.35, 0.55, 0.9, 0.8), 2)
	tracker_panel.add_theme_stylebox_override("panel", box)
	add_child(tracker_panel)
	tracker = Label.new()
	tracker.add_theme_font_size_override("font_size", 18)
	tracker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tracker.custom_minimum_size = Vector2(340, 0)
	tracker_panel.add_child(tracker)

	toast_panel = PanelContainer.new()
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.anchor_top = 1.0
	toast_panel.anchor_bottom = 1.0
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_panel.offset_top = -50.0
	toast_panel.offset_bottom = -50.0
	toast_panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.04, 0.06, 0.14, 0.85), Color(0.5, 0.75, 1.0, 0.8), 2))
	toast_panel.modulate.a = 0.0
	add_child(toast_panel)
	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", 22)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)

	banner = UiStyle.make_label("", 52, Color(0.85, 0.95, 1.0))
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.offset_top = 120.0
	banner.offset_left = 0.0
	banner.offset_right = 0.0
	banner.modulate.a = 0.0
	add_child(banner)

	achievement_banner = AchievementBanner.new()
	add_child(achievement_banner)

	boss_bar = Control.new()
	boss_bar.position = Vector2(406, 16)
	boss_bar.size = Vector2(340, 44)
	boss_bar.draw.connect(_draw_boss_bar)
	boss_bar.visible = false
	add_child(boss_bar)

	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.visible = false
	add_child(overlay)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(center)
	overlay_title = UiStyle.make_label(tr("Game over"), 72, Color(1.0, 0.4, 0.4))
	center.add_child(overlay_title)
	overlay_sub = UiStyle.make_label("", 26)
	center.add_child(overlay_sub)


# --- Hartjes en tellers ----------------------------------------------------------------

func _draw_stamina() -> void:
	var font := ThemeDB.fallback_font
	var ratio: float = GameState.movement.stamina / GameState.movement.MAX_STAMINA
	var tired: bool = GameState.movement.exhausted
	var label := "Even op adem komen..." if tired else "Uithouding  ·  Ctrl / L3"
	var color := Color(1.0, 0.57, 0.3) if tired else Color(0.4, 0.88, 0.7)
	stamina_bar.draw_string_outline(font, Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.9))
	stamina_bar.draw_string(font, Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.92, 0.98, 0.95))
	stamina_bar.draw_rect(Rect2(0, 22, 222, 12), Color(0.02, 0.06, 0.09, 0.85))
	stamina_bar.draw_rect(Rect2(2, 24, 218.0 * ratio, 8), color)
	stamina_bar.draw_rect(Rect2(0, 22, 222, 12), Color(0.65, 0.86, 0.8), false, 1.0)


func _draw_hearts() -> void:
	# ui_heart.png: vakje 0 = vol hartje, vakje 1 = leeg hartje (13x12 pixels, hier 3x vergroot).
	var cell := Vector2(13, 12)
	for i in GameState.max_hp():
		var frame := 0 if i < GameState.hp else 1
		hearts.draw_texture_rect_region(Art.tex("ui_heart"), Rect2(Vector2(i * 44, 0), cell * 3.0),
			Rect2(Vector2(frame * cell.x, 0), cell))


func _draw_stats() -> void:
	var items_tex := Art.tex("items")
	var font := ThemeDB.fallback_font
	var x := 0.0
	var entries := [
		[Items.ITEMS["coin"]["icon"], str(GameState.coins), Color(1, 0.9, 0.4)],
		[Items.ITEMS["crystal_bos"]["icon"], "%d/3" % (3 if GameState.flag("gate_temple") else GameState.crystal_count()), Color(0.6, 0.85, 1.0)],
		[Items.ITEMS["potion"]["icon"], "%d [H]" % GameState.count("potion"), Color(1, 0.6, 0.7)],
		[Items.ITEMS[Items.WEAPONS[GameState.weapon]["item"]]["icon"], "", Color.WHITE, Items.sheet_of(Items.WEAPONS[GameState.weapon]["item"])],
	]
	if GameState.count("bow") > 0: # de pijlenteller
		entries.append([Items.ITEMS["arrow"]["icon"], arrow_text(), arrow_color(), Items.sheet_of("arrow")])
	for entry: Array in entries:
		var icons: Texture2D = Art.tex(entry[3]) if entry.size() > 3 else items_tex # een eigen plaatje (naam) voor uitbreidingen
		stats.draw_texture_rect_region(icons, Rect2(Vector2(x, 2), Vector2(32, 32)), Rect2(Vector2(entry[0] * 16, 0), Vector2(16, 16)))
		x += 36.0
		if entry[1] != "":
			stats.draw_string_outline(font, Vector2(x, 26), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.9))
			stats.draw_string(font, Vector2(x, 26), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, entry[2])
			x += font.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 18.0


## De tekst bij de pijlenteller ("12 [F]"), of niets zolang je geen boog hebt.
func arrow_text() -> String:
	if GameState.count("bow") <= 0:
		return ""
	return "%d [F]" % GameState.count("arrow")


## De kleur van de pijlenteller: rood als je pijlen op zijn.
func arrow_color() -> Color:
	return Color(1, 0.45, 0.4) if GameState.count("arrow") == 0 else Color(1, 0.88, 0.6)


## Het moment dat je de boog krijgt: vertel meteen hoe je schiet.
func _check_bow() -> void:
	var has_bow := GameState.count("bow") > 0
	if has_bow and not had_bow:
		_queue_toast(tr("Boog gekregen! Druk op F om te schieten."))
	had_bow = has_bow


func _refresh_tracker() -> void:
	var text := GameState.tracked_text()
	tracker_panel.visible = text != ""
	tracker.text = text


# --- Meldingen en kaartnaam ----------------------------------------------------------------

func _queue_toast(text: String) -> void:
	toast_queue.append(text)


## Grote tekst midden bovenin: de naam van een gebied, of "Goedemorgen!". `text_of` geeft de tekst in de huidige taal,
## bijvoorbeeld func() -> String: return tr("Goedemorgen!"). Zo verandert de banner meteen mee als je in het pauzemenu
## een andere taal kiest terwijl hij in beeld is.
func show_banner(text_of: Callable) -> void:
	banner_text = text_of
	banner.text = text_of.call()
	banner_time = 2.8


## De taal is gewisseld (pauzemenu): alles wat in beeld staat opnieuw invullen. Een melding die al in beeld is blijft
## in de oude taal staan tot hij verdwijnt; nieuwe meldingen komen in de nieuwe taal.
func _on_language_changed(_locale: String) -> void:
	_refresh_tracker()
	if banner_text.is_valid():
		banner.text = banner_text.call()
	overlay_title.text = tr("Game over")
	if overlay.visible:
		_show_game_over()
	stats.queue_redraw()
	clock_state = ""
	clock.queue_redraw()
	boss_bar.queue_redraw()


func _process(delta: float) -> void:
	stamina_bar.queue_redraw()
	# Meldingen komen een voor een, en wachten tot een gesprek klaar is.
	if toast_time > 0.0:
		toast_time -= delta
		toast_panel.modulate.a = clampf(toast_time * 2.0, 0.0, 1.0) if toast_time < 0.5 else 1.0
	elif not toast_queue.is_empty() and not GameState.dialogue_open:
		toast_label.text = toast_queue.pop_front()
		toast_time = 3.2
		toast_panel.modulate.a = 1.0
	else:
		toast_panel.modulate.a = 0.0

	if banner_time > 0.0:
		banner_time -= delta
		banner.modulate.a = clampf(minf(banner_time, 2.8 - banner_time) * 2.5, 0.0, 1.0)
	else:
		banner.modulate.a = 0.0

	_update_clock()
	_update_boss()


func _update_boss() -> void:
	boss = null
	var player := get_tree().get_first_node_in_group("player")
	for candidate: Node2D in get_tree().get_nodes_in_group("boss"):
		# Een baas kan met `bar_range` zeggen dat zijn balk vanaf verder weg te zien is (een grote arena).
		var show_range: float = float(candidate.get("bar_range")) if candidate.get("bar_range") != null else 360.0
		if candidate.active and not candidate.dead and player and candidate.global_position.distance_to(player.global_position) < show_range:
			boss = candidate
			break
	boss_bar.visible = boss != null
	if boss:
		boss_bar.queue_redraw()


func _draw_boss_bar() -> void:
	if boss == null:
		return
	var font := ThemeDB.fallback_font
	var ratio := clampf(float(boss.hp) / float(boss.max_hp), 0.0, 1.0)
	var boss_name := tr(boss.data["name"])
	boss_bar.draw_string_outline(font, Vector2(0, 16), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.9))
	boss_bar.draw_string(font, Vector2(0, 16), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.85, 0.85))
	boss_bar.draw_rect(Rect2(0, 24, 340, 16), Color(0.05, 0.02, 0.05, 0.85))
	boss_bar.draw_rect(Rect2(2, 26, 336.0 * ratio, 12), Color(0.85, 0.2, 0.25))
	boss_bar.draw_rect(Rect2(2, 26, 336.0 * ratio, 4), Color(1, 0.5, 0.5, 0.7))
	boss_bar.draw_rect(Rect2(0, 24, 340, 16), Color(0.9, 0.8, 0.8), false, 2.0)


# --- Game over ---------------------------------------------------------------------------------

func _show_game_over() -> void:
	overlay_title.text = tr("Game over")
	# Vertalers: op het game-over-scherm; %s is wie je versloeg, bijvoorbeeld "Kristalgolem (klap)"
	var by := "" if GameState.last_damage_source == "" else tr("Verslagen door: %s") % damage_source_text(GameState.last_damage_source) + "\n"
	if GameState.has_save():
		overlay_sub.text = by + tr("Druk op R om verder te gaan vanaf je laatste opslag  ·  Esc voor het menu")
	else:
		overlay_sub.text = by + tr("Druk op R om opnieuw te beginnen  ·  Esc voor het menu")
	overlay.visible = true


## Wie je versloeg, in de taal van de speler. De bron van de schade (player.hurt) is de Nederlandse naam van de vijand,
## soms met de aanval erachter: "Kristalgolem (klap)". Naam en aanval worden los vertaald; de aanvallen staan in
## Enemies.ATTACKS (met de context "aanval", want "klap" of "steen" kan los ook iets anders betekenen).
static func damage_source_text(source: String) -> String:
	var open := source.rfind(" (")
	if open > 0 and source.ends_with(")"):
		var attack := source.substr(open + 2, source.length() - open - 3)
		# Vertalers: naam van een vijand en (tussen haakjes) zijn aanval, bijvoorbeeld "Kristalgolem (klap)"
		return TranslationServer.translate("%s (%s)") % [TranslationServer.translate(source.substr(0, open)),
			TranslationServer.translate(attack, "aanval")]
	return TranslationServer.translate(source)


# --- Dag en nacht ------------------------------------------------------------------------------

func _update_clock() -> void:
	var state := "%s %s" % [Daynight.icon_frame(GameState.day_time), _clock_label()]
	if state != clock_state:
		clock_state = state
		clock.queue_redraw()


func _clock_label() -> String:
	var label := Daynight.phase_label(GameState.day_time)
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.atmosphere != null and world.atmosphere.rain_level > 0.3:
		# Vertalers: het dagdeel bij de klok als het regent: "Avond  ·  regen"
		label = tr("%s  ·  regen") % label
	return label


func _draw_clock() -> void:
	var font := ThemeDB.fallback_font
	var frame := Daynight.icon_frame(GameState.day_time)
	clock.draw_texture_rect_region(Art.tex("wereld_ui"), Rect2(Vector2(0, 2), Vector2(32, 32)), Rect2(Vector2(frame * 16, 0), Vector2(16, 16)))
	var label := _clock_label()
	clock.draw_string_outline(font, Vector2(38, 25), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.9))
	clock.draw_string(font, Vector2(38, 25), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.97, 1.0))
