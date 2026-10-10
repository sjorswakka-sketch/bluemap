extends CanvasLayer
## Alles wat bovenop het spel getekend wordt: hartjes, tellers, dialoog en eindschermen.

const Art := preload("res://scripts/art.gd")

var hearts: Control
var items_label: Label
var quest_label: Label
var toast_label: Label
var toast_timer := 0.0

var dialogue_panel: PanelContainer
var speaker_label: Label
var text_label: Label
var hint_label: Label

var overlay: ColorRect
var overlay_title: Label
var overlay_sub: Label

var lines: Array = []
var line_idx := 0
var on_done := Callable()
var opened_frame := -1
var shown_chars := 0.0


func _ready() -> void:
	layer = 10
	_build_ui()
	GameState.hp_changed.connect(func(_hp: int, _max_hp: int) -> void: hearts.queue_redraw())
	GameState.items_changed.connect(_refresh_labels)
	GameState.toast.connect(_show_toast)
	GameState.dialogue_requested.connect(_open_dialogue)
	GameState.game_over.connect(_show_game_over)
	GameState.victory.connect(_show_victory)
	_refresh_labels()
	_show_toast("WASD/pijltjes = lopen  ·  SPATIE = zwaard  ·  E = praten", 6.0)


func _build_ui() -> void:
	hearts = Control.new()
	hearts.position = Vector2(20, 16)
	hearts.size = Vector2(300, 36)
	hearts.draw.connect(_draw_hearts)
	add_child(hearts)

	items_label = _make_label(22, Vector2(20, 56))
	quest_label = _make_label(20, Vector2(20, 88))

	toast_label = _make_label(24, Vector2(0, 20))
	toast_label.anchor_left = 0.0
	toast_label.anchor_right = 1.0
	toast_label.offset_left = 0.0
	toast_label.offset_right = 0.0
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0

	# Dialoogvenster onderaan.
	dialogue_panel = PanelContainer.new()
	dialogue_panel.anchor_left = 0.0
	dialogue_panel.anchor_right = 1.0
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.offset_left = 60.0
	dialogue_panel.offset_right = -60.0
	dialogue_panel.offset_top = -190.0
	dialogue_panel.offset_bottom = -30.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.22, 0.94)
	style.border_color = Color(0.45, 0.75, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	dialogue_panel.add_theme_stylebox_override("panel", style)
	dialogue_panel.visible = false
	add_child(dialogue_panel)

	var box := VBoxContainer.new()
	dialogue_panel.add_child(box)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 22)
	speaker_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	box.add_child(speaker_label)
	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 24)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text_label)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.modulate = Color(1, 1, 1, 0.6)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint_label)

	# Eindscherm (game over / gewonnen).
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.visible = false
	add_child(overlay)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(center)
	overlay_title = Label.new()
	overlay_title.add_theme_font_size_override("font_size", 64)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(overlay_title)
	overlay_sub = Label.new()
	overlay_sub.add_theme_font_size_override("font_size", 26)
	overlay_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(overlay_sub)


func _make_label(size: int, pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label


func _draw_hearts() -> void:
	# ui_heart.png: vakje 0 = vol hartje, vakje 1 = leeg hartje (13x12 pixels, hier 3x vergroot).
	var cell := Vector2(13, 12)
	for i in GameState.MAX_HP:
		var frame := 0 if i < GameState.hp else 1
		hearts.draw_texture_rect_region(Art.tex("ui_heart"), Rect2(Vector2(i * 44, 0), cell * 3.0),
			Rect2(Vector2(frame * cell.x, 0), cell))


func _refresh_labels() -> void:
	items_label.text = "◆ Kristallen: %d/%d     ● Munten: %d" % [
		GameState.crystals, GameState.CRYSTALS_NEEDED, GameState.coins]
	if GameState.quest_done:
		quest_label.text = "Opdracht voltooid!"
	elif not GameState.quest_started:
		quest_label.text = "Opdracht: praat met Oudste Bram (links in het dorp)"
	elif GameState.crystals >= GameState.CRYSTALS_NEEDED:
		quest_label.text = "Opdracht: breng de kristallen naar Bram"
	else:
		quest_label.text = "Opdracht: vind de blauwe kristallen"


func _show_toast(text: String, seconds: float = 3.0) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	toast_timer = seconds


func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		toast_label.modulate.a = clampf(toast_timer, 0.0, 1.0)
	if GameState.dialogue_open and text_label.visible_characters < text_label.text.length():
		shown_chars += delta * 60.0
		text_label.visible_characters = int(shown_chars)


# --- Dialoog -----------------------------------------------------------------

func _open_dialogue(speaker: String, new_lines: Array, done: Callable) -> void:
	lines = new_lines
	line_idx = 0
	on_done = done
	speaker_label.text = speaker
	GameState.dialogue_open = true
	dialogue_panel.visible = true
	# Dezelfde toetsdruk die het gesprek opende mag het niet meteen doorklikken.
	opened_frame = Engine.get_process_frames()
	_show_line()


func _show_line() -> void:
	text_label.text = lines[line_idx]
	text_label.visible_characters = 0
	shown_chars = 0.0
	hint_label.text = "E / spatie  ▼" if line_idx < lines.size() - 1 else "E / spatie  ✓"


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.dialogue_open or Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		if text_label.visible_characters < text_label.text.length():
			text_label.visible_characters = -1 # alles in één keer tonen
			shown_chars = text_label.text.length()
		else:
			_next_line()


func _next_line() -> void:
	line_idx += 1
	if line_idx < lines.size():
		_show_line()
		return
	dialogue_panel.visible = false
	GameState.dialogue_open = false
	if on_done.is_valid():
		on_done.call()


# --- Eindschermen ------------------------------------------------------------

func _show_game_over() -> void:
	overlay_title.text = "Game over"
	overlay_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	overlay_sub.text = "Druk op R om opnieuw te beginnen"
	overlay.visible = true


func _show_victory() -> void:
	overlay_title.text = "Gewonnen!"
	overlay_title.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	overlay_sub.text = "De kaart is weer compleet.  Munten: %d  ·  Druk op R om opnieuw te spelen" % GameState.coins
	overlay.visible = true
