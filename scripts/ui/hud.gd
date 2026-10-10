extends CanvasLayer
## Alles wat bovenop het spel getekend wordt: hartjes, tellers, opdracht, meldingen,
## kaartnaam, baasbalk en het game-over-scherm.

const Art := preload("res://scripts/core/art.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")
const Items := preload("res://scripts/data/items.gd")

var hearts: Control
var stats: Control
var tracker_panel: PanelContainer
var tracker: Label
var toast_panel: PanelContainer
var toast_label: Label
var banner: Label
var boss_bar: Control
var overlay: ColorRect
var overlay_title: Label
var overlay_sub: Label

var toast_queue: Array[String] = []
var toast_time := 0.0
var banner_time := 0.0
var boss: Node2D = null


func _ready() -> void:
	layer = 10
	_build_ui()
	GameState.hp_changed.connect(func() -> void: hearts.queue_redraw())
	GameState.items_changed.connect(func() -> void: stats.queue_redraw(); _refresh_tracker())
	GameState.quests_changed.connect(_refresh_tracker)
	GameState.toast.connect(_queue_toast)
	GameState.game_over.connect(_show_game_over)
	_refresh_tracker()
	_queue_toast("WASD lopen  ·  SPATIE zwaard  ·  SHIFT rollen  ·  E praten  ·  I menu  ·  ESC pauze")


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
	overlay_title = UiStyle.make_label("Game over", 72, Color(1.0, 0.4, 0.4))
	center.add_child(overlay_title)
	overlay_sub = UiStyle.make_label("", 26)
	center.add_child(overlay_sub)


# --- Hartjes en tellers ----------------------------------------------------------------

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
		[Items.ITEMS[Items.WEAPONS[GameState.weapon]["item"]]["icon"], "", Color.WHITE],
	]
	for entry: Array in entries:
		stats.draw_texture_rect_region(items_tex, Rect2(Vector2(x, 2), Vector2(32, 32)), Rect2(Vector2(entry[0] * 16, 0), Vector2(16, 16)))
		x += 36.0
		if entry[1] != "":
			stats.draw_string_outline(font, Vector2(x, 26), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.9))
			stats.draw_string(font, Vector2(x, 26), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, entry[2])
			x += font.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 18.0


func _refresh_tracker() -> void:
	var text := GameState.tracked_text()
	tracker_panel.visible = text != ""
	tracker.text = text


# --- Meldingen en kaartnaam ----------------------------------------------------------------

func _queue_toast(text: String) -> void:
	toast_queue.append(text)


func show_banner(text: String) -> void:
	banner.text = text
	banner_time = 2.8


func _process(delta: float) -> void:
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

	_update_boss()


func _update_boss() -> void:
	boss = null
	var player := get_tree().get_first_node_in_group("player")
	for candidate: Node2D in get_tree().get_nodes_in_group("boss"):
		if candidate.active and not candidate.dead and player and candidate.global_position.distance_to(player.global_position) < 360.0:
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
	boss_bar.draw_string_outline(font, Vector2(0, 16), boss.data["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.9))
	boss_bar.draw_string(font, Vector2(0, 16), boss.data["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.85, 0.85))
	boss_bar.draw_rect(Rect2(0, 24, 340, 16), Color(0.05, 0.02, 0.05, 0.85))
	boss_bar.draw_rect(Rect2(2, 26, 336.0 * ratio, 12), Color(0.85, 0.2, 0.25))
	boss_bar.draw_rect(Rect2(2, 26, 336.0 * ratio, 4), Color(1, 0.5, 0.5, 0.7))
	boss_bar.draw_rect(Rect2(0, 24, 340, 16), Color(0.9, 0.8, 0.8), false, 2.0)


# --- Game over ---------------------------------------------------------------------------------

func _show_game_over() -> void:
	overlay_title.text = "Game over"
	var has_save := GameState.has_save()
	var by := "" if GameState.last_damage_source == "" else "Verslagen door: %s\n" % GameState.last_damage_source
	overlay_sub.text = by + ("Druk op R om verder te gaan vanaf je laatste opslag" if has_save else "Druk op R om opnieuw te beginnen") + "  ·  Esc voor het menu"
	overlay.visible = true
