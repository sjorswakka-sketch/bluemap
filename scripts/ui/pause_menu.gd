extends CanvasLayer
## Pauzemenu (Esc of P). Zet het hele spel stil.

const UiStyle := preload("res://scripts/core/ui_style.gd")

var root: Control
var resume_button: Button
var load_button: Button
var sound_button: Button
var ng_row: HBoxContainer # "Nieuw spel+ ronde N" met een ster, alleen bij Nieuw spel+
var ng_label: Label
var open := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS # moet blijven werken terwijl de rest pauzeert
	_build_ui()
	root.visible = false
	Sound.mute_changed.connect(func(_muted: bool) -> void: _refresh_sound_label())


func _exit_tree() -> void:
	GameState.set_ui("pause", false)


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	UiStyle.style_panel(panel)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UiStyle.make_label("Pauze", 44, Color(0.6, 0.88, 1.0)))
	_build_ng_row(box)

	resume_button = _button(box, "Verder spelen", toggle)
	load_button = _button(box, "Laatste opslag laden", _load_save)
	sound_button = _button(box, "", Sound.toggle_mute)
	_slider(box, "Muziek", Sound.music_volume, Sound.set_music_volume)
	_slider(box, "Effecten", Sound.sfx_volume, Sound.set_sfx_volume)
	_button(box, "Naar titelscherm", _to_title)
	_refresh_sound_label()


## Een gouden ster met "Nieuw spel+ · ronde N" onder de titel. De ster wordt getekend, zodat hij overal werkt.
func _build_ng_row(parent: Node) -> void:
	ng_row = HBoxContainer.new()
	ng_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ng_row.add_theme_constant_override("separation", 8)
	var star := Control.new()
	star.custom_minimum_size = Vector2(28, 28)
	star.draw.connect(func() -> void: UiStyle.draw_star(star, Vector2(14, 14), 13.0, Color(1.0, 0.85, 0.3)))
	ng_row.add_child(star)
	ng_label = UiStyle.make_label("", 22, Color(1.0, 0.9, 0.5))
	ng_row.add_child(ng_label)
	ng_row.visible = false
	parent.add_child(ng_row)


func _refresh_ng_row() -> void:
	ng_row.visible = GameState.ng_plus > 0
	ng_label.text = "Nieuw spel+  ·  ronde %d" % GameState.ng_plus


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	UiStyle.style_button(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _slider(parent: Node, label_text: String, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 22)
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 36)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(setter)
	row.add_child(slider)
	parent.add_child(row)


func _refresh_sound_label() -> void:
	sound_button.text = "Geluid: uit  (M)" if Sound.muted else "Geluid: aan  (M)"


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	# Geen pauzemenu bovenop een gesprek, winkel of ander menu, of tijdens een overgang.
	for owner_name: String in GameState.ui_owners:
		if owner_name != "pause":
			return
	if GameState.transitioning:
		return
	get_viewport().set_input_as_handled()
	toggle()


func toggle() -> void:
	open = not open
	root.visible = open
	GameState.set_ui("pause", open)
	Sound.play("select")
	if open:
		_refresh_ng_row()
		load_button.disabled = not GameState.has_save()
		_refresh_sound_label()
		resume_button.grab_focus()


func _load_save() -> void:
	GameState.set_ui("pause", false)
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.restart_from_save()


func _to_title() -> void:
	GameState.set_ui("pause", false)
	GameState.in_game = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
