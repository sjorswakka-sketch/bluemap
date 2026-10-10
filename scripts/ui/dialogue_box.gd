extends CanvasLayer
## Het dialoogvenster. Speelt gesprekken af uit scripts/data/dialogue.gd, inclusief keuzes,
## vertakkingen en acties. Het spel staat stil zolang het venster open is.

const UiStyle := preload("res://scripts/core/ui_style.gd")
const Dialogue := preload("res://scripts/data/dialogue.gd")

var panel: PanelContainer
var speaker_label: Label
var text_label: Label
var hint_label: Label
var choices_box: VBoxContainer

var active := false
var node: Dictionary = {}
var lines: Array = []
var line_idx := 0
var opened_frame := -1
var shown_chars := 0.0
var buttons: Array[Button] = []


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	panel.visible = false
	GameState.dialogue_requested.connect(start)
	GameState.text_dialogue_requested.connect(start_text)


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 60.0
	panel.offset_right = -60.0
	panel.offset_top = -190.0
	panel.offset_bottom = -26.0
	panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.06, 0.1, 0.22, 0.95), Color(0.45, 0.75, 1.0), 3))
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 22)
	speaker_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	box.add_child(speaker_label)
	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 24)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0, 76)
	box.add_child(text_label)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 4)
	box.add_child(choices_box)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.modulate = Color(1, 1, 1, 0.6)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint_label)


# --- Gesprek starten en afspelen --------------------------------------------------------------

func start(talk_id: String) -> void:
	if active:
		return
	_open()
	_enter(talk_id)


## Een los berichtje zonder gesprek in dialogue.gd (borden).
func start_text(speaker: String, new_lines: Array) -> void:
	if active:
		return
	_open()
	node = {"speaker": speaker, "lines": new_lines}
	_begin_node()


func _open() -> void:
	active = true
	GameState.dialogue_open = true
	GameState.set_ui("dialogue", true)
	panel.visible = true
	# Dezelfde toetsdruk die het gesprek opende mag het niet meteen doorklikken.
	opened_frame = Engine.get_process_frames()
	Sound.play("select", -6.0)


func _enter(talk_id: String) -> void:
	node = Dialogue.get_talk(talk_id)
	_begin_node()


func _begin_node() -> void:
	speaker_label.text = node.get("speaker", "")
	lines = node.get("lines", [])
	line_idx = 0
	_clear_choices()
	if lines.is_empty():
		_finish_node()
	else:
		_show_line()


func _show_line() -> void:
	text_label.text = GameState.fmt(lines[line_idx])
	text_label.visible_characters = 0
	shown_chars = 0.0
	hint_label.text = "E / spatie  ▼" if line_idx < lines.size() - 1 else "E / spatie  ✓"


func _process(delta: float) -> void:
	if active and text_label.visible_characters >= 0 and text_label.visible_characters < text_label.text.length():
		shown_chars += delta * 60.0
		text_label.visible_characters = int(shown_chars)


func _unhandled_input(event: InputEvent) -> void:
	if not active or Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		if not buttons.is_empty():
			# Met een keuze op het scherm bevestigt E de gekozen knop.
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and focused in buttons:
				(focused as Button).pressed.emit()
			return
		_advance()


func _advance() -> void:
	if text_label.visible_characters >= 0 and text_label.visible_characters < text_label.text.length():
		text_label.visible_characters = -1 # alles in één keer tonen
		shown_chars = text_label.text.length()
		return
	Sound.play("select", -6.0)
	line_idx += 1
	if line_idx < lines.size():
		_show_line()
	else:
		_finish_node()


func _finish_node() -> void:
	if node.has("do"):
		GameState.run_all(node["do"])
	if node.has("choices"):
		_show_choices(node["choices"])
		return
	if node.has("branch"):
		for option: Dictionary in node["branch"]:
			if not option.has("if") or GameState.check_all(option["if"]):
				_enter(option["next"])
				return
	if node.has("next"):
		_enter(node["next"])
		return
	_close()


func _show_choices(choices: Array) -> void:
	_clear_choices()
	for choice: Dictionary in choices:
		if choice.has("if") and not GameState.check_all(choice["if"]):
			continue
		var button := Button.new()
		button.text = GameState.fmt(choice["text"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiStyle.style_button(button, 22)
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(_choose.bind(choice))
		choices_box.add_child(button)
		buttons.append(button)
	hint_label.text = "↑ ↓ kiezen  ·  E bevestigen"
	if buttons.is_empty():
		_close()
	else:
		buttons[0].grab_focus()


func _choose(choice: Dictionary) -> void:
	Sound.play("select", -4.0)
	_clear_choices()
	if choice.has("do"):
		GameState.run_all(choice["do"])
	if choice.has("next"):
		_enter(choice["next"])
	else:
		_close()


func _clear_choices() -> void:
	for button in buttons:
		button.queue_free()
	buttons.clear()


func _close() -> void:
	_clear_choices()
	panel.visible = false
	active = false
	GameState.dialogue_open = false
	GameState.set_ui("dialogue", false)
