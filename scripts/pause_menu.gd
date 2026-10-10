extends CanvasLayer
## Pauzemenu (Esc of P). Zet het hele spel stil en laat je verder spelen, opnieuw beginnen
## of terug naar het titelscherm gaan.

const UiStyle := preload("res://scripts/ui_style.gd")

var root: Control
var resume_button: Button
var sound_button: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS # moet blijven werken terwijl de rest pauzeert
	_build_ui()
	root.visible = false
	Sound.mute_changed.connect(func(_muted: bool) -> void: _refresh_sound_label())


func _exit_tree() -> void:
	if get_tree():
		get_tree().paused = false


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
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiStyle.make_label("Pauze", 44, Color(0.6, 0.88, 1.0)))

	resume_button = _button(box, "Verder spelen", toggle)
	_button(box, "Opnieuw beginnen", _restart)
	sound_button = _button(box, "", Sound.toggle_mute)
	_button(box, "Naar titelscherm", _to_title)
	_refresh_sound_label()


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	UiStyle.style_button(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _refresh_sound_label() -> void:
	sound_button.text = "Geluid: uit  (M)" if Sound.muted else "Geluid: aan  (M)"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		toggle()


func toggle() -> void:
	root.visible = not root.visible
	get_tree().paused = root.visible
	Sound.play("select")
	if root.visible:
		resume_button.grab_focus()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
