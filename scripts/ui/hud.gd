extends CanvasLayer
## Alles wat bovenop het spel getekend wordt: hartjes, tellers, opdracht, meldingen,
## kaartnaam, baasbalk en het game-over-scherm.

const Art := preload("res://scripts/core/art.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")
const Items := preload("res://scripts/data/items.gd")
const Progression := preload("res://scripts/core/progression.gd")
const Daynight := preload("res://scripts/core/daynight.gd")
const AchievementBanner := preload("res://scripts/ui/achievement_banner.gd")
const Opening := preload("res://scripts/core/opening.gd")

var hearts: Control
var stats: Control
var tracker_panel: PanelContainer
var tracker: Label
var toast_panel: PanelContainer
var toast_label: Label
var banner: Label
var boss_bar: Control
var clock: Control # zon of maan, en welk deel van de dag het is
var xp_bar: Control
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
var opening_hint: Label
var opening_quiet := false


func _ready() -> void:
	layer = 10
	_build_ui()
	_ignore_mouse(self)
	Controls.device_changed.connect(func(_pad: bool) -> void: _refresh_controls())
	Controls.bindings_changed.connect(_refresh_controls)
	GameState.progression_changed.connect(func() -> void: xp_bar.queue_redraw())
	GameState.hp_changed.connect(func() -> void: hearts.queue_redraw())
	GameState.items_changed.connect(func() -> void: stats.queue_redraw(); _refresh_tracker())
	GameState.quests_changed.connect(_refresh_tracker)
	GameState.toast.connect(_queue_toast)
	GameState.game_over.connect(_show_game_over)
	_refresh_tracker()
	if not Opening.quiet_hud():
		_queue_toast(tr("%s zwaard  ·  %s praten  ·  %s menu  ·  %s pauze en besturing") % [Controls.action_label("attack"), Controls.action_label("interact"), Controls.action_label("menu"), Controls.action_label("pause")])
	# Boog: de pijlenteller (met "[F]") staat in beeld zodra je een boog hebt, en bij het krijgen ervan komt een melding.
	had_bow = GameState.count("bow") > 0
	GameState.items_changed.connect(_check_bow)
	Lang.changed.connect(_on_language_changed)


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _refresh_controls() -> void:
	stats.queue_redraw()
	stamina_bar.queue_redraw()
	xp_bar.queue_redraw()
	if GameState.ended:
		_show_game_over()


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

	xp_bar = Control.new()
	xp_bar.position = Vector2(20, 194)
	xp_bar.size = Vector2(280, 38)
	xp_bar.draw.connect(_draw_xp)
	add_child(xp_bar)

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
	opening_hint = UiStyle.make_label("",18,Color(0.95,0.97,1))
	opening_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	opening_hint.offset_left = 24
	opening_hint.offset_right = -24
	opening_hint.offset_top = -34
	opening_hint.offset_bottom = -8
	opening_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening_hint.add_theme_color_override("font_outline_color",Color(0.04,0.07,0.12))
	opening_hint.add_theme_constant_override("outline_size",6)
	add_child(opening_hint)

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
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(850,0)
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
	var ratio: float = GameState.movement.stamina / GameState.movement.capacity()
	var tired: bool = GameState.movement.exhausted
	var label := tr("Even op adem komen...") if tired else tr("Uithouding  ·  %s") % Controls.action_label("sprint")
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
		[Items.ITEMS["potion"]["icon"], "%d [%s]" % [GameState.count("potion"), Controls.action_label("potion")], Color(1, 0.6, 0.7)],
		[Items.ITEMS[Items.WEAPONS[GameState.weapon]["item"]]["icon"], "", Color.WHITE, Items.sheet_of(Items.WEAPONS[GameState.weapon]["item"])],
	]
	if Opening.quiet_hud():
		entries = [entries[0]] if GameState.coins>0 else []
		if GameState.count("potion")>0:
			entries.append([Items.ITEMS["potion"]["icon"], "%d [%s]" % [GameState.count("potion"),Controls.action_label("potion")],Color(1,0.6,0.7)])
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
	return "%d [%s]" % [GameState.count("arrow"), Controls.action_label("bow")]


## De kleur van de pijlenteller: rood als je pijlen op zijn.
func arrow_color() -> Color:
	return Color(1, 0.45, 0.4) if GameState.count("arrow") == 0 else Color(1, 0.88, 0.6)


## Het moment dat je de boog krijgt: vertel meteen hoe je schiet.
func _check_bow() -> void:
	var has_bow := GameState.count("bow") > 0
	if has_bow and not had_bow:
		_queue_toast(tr("Boog gekregen! Druk op %s om te schieten.") % Controls.action_label("bow"))
	had_bow = has_bow


func _refresh_tracker() -> void:
	var text := GameState.tracked_text()
	var route_text: String=preload("res://scripts/core/first_route.gd").tracker()
	if route_text!="": text=route_text
	var supper_text: String=preload("res://scripts/core/lake_supper.gd").tracker()
	if supper_text!="": text=supper_text
	var region_text: String=preload("res://scripts/core/regional_adventures.gd").tracker()
	if region_text!="": text=region_text
	if Opening.enabled() and GameState.quest_state("first_water")=="active" and GameState.map_id in ["village","smithy"]:
		text = GameState.quest_text("first_water")
	elif Opening.quiet_hud():
		text = tr("Volg het gesputter naar de fontein. Nelle kan je hulp gebruiken.")
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
	xp_bar.queue_redraw()
	clock_state = ""
	clock.queue_redraw()
	boss_bar.queue_redraw()


func refresh_opening() -> void:
	var quiet := Opening.quiet_hud()
	if quiet != opening_quiet:
		opening_quiet = quiet
		stats.queue_redraw()
	clock.visible = not quiet
	xp_bar.visible = not quiet or GameState.hero_xp>0
	stamina_bar.visible = not quiet or GameState.flag("op_sprint_seen") or GameState.movement.stamina<GameState.movement.capacity()
	stats.visible = not quiet or GameState.coins>0 or GameState.count("potion")>0
	opening_hint.visible = quiet and not GameState.input_locked() and toast_time<=0
	if quiet:
		if GameState.flag("op_water"):
			opening_hint.text = tr("Rennen: %s vasthouden   ·   Je spullen bekijken: %s") % [Controls.action_label("sprint"),Controls.action_label("menu")]
		elif GameState.count("op_rake")>0:
			opening_hint.text = tr("%s: gereedschap gebruiken bij het rooster. Blijf even staan tijdens het harken.") % Controls.action_label("interact")
		else:
			opening_hint.text = tr("Lopen: %s / %s / %s / %s   ·   Praten: %s") % [Controls.action_label("move_up"),Controls.action_label("move_left"),Controls.action_label("move_down"),Controls.action_label("move_right"),Controls.action_label("interact")]
	_refresh_tracker()


func _process(delta: float) -> void:
	refresh_opening()
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
	var has_save := GameState.has_save()
	var by := "" if GameState.last_damage_source == "" else tr("Verslagen door: %s") % damage_source_text(GameState.last_damage_source) + "\n"
	var restart_label: String = Controls.action_label("restart")
	var pause_label: String = Controls.action_label("pause")
	var menu_hint := "  ·  " + tr("%s voor het menu") % pause_label if pause_label != restart_label else ""
	overlay_sub.text = by + ((tr("Druk op %s om verder te gaan vanaf je laatste opslag") if has_save else tr("Druk op %s om opnieuw te beginnen")) % restart_label) + menu_hint
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


func xp_label() -> String:
	var hero := Progression.progress()
	return tr("Held %d · maximaal niveau") % hero["level"] if hero["max_level"] else tr("Held %d · %d/%d XP") % [hero["level"], hero["current"], hero["needed"]]


func _draw_xp() -> void:
	var hero := Progression.progress()
	var ratio := 1.0 if hero["max_level"] else float(hero["current"]) / maxi(int(hero["needed"]), 1)
	var font := ThemeDB.fallback_font
	xp_bar.draw_string_outline(font, Vector2(0, 15), xp_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.9))
	xp_bar.draw_string(font, Vector2(0, 15), xp_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.83, 0.88, 1.0))
	xp_bar.draw_rect(Rect2(0, 22, 222, 10), Color(0.02, 0.04, 0.09, 0.85))
	xp_bar.draw_rect(Rect2(2, 24, 218.0 * ratio, 6), Color(0.6, 0.67, 1.0))
	xp_bar.draw_rect(Rect2(0, 22, 222, 10), Color(0.7, 0.77, 1.0), false, 1.0)
