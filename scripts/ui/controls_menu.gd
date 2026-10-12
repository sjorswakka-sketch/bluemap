extends CanvasLayer
## Bereikbaar vanaf titel en pauze; toetsen en controller worden apart bewaard.

signal closed

const UiStyle := preload("res://scripts/core/ui_style.gd")

var device := "keyboard"
var capture_action := ""
var capture_time := 0.0
var status: Label
var list: VBoxContainer
var keyboard_button: Button
var controller_button: Button
var close_button: Button
var binding_buttons: Dictionary = {}
var controls_root: Control
var title_label: Label
var help_label: Label
var reset_button: Button
var action_labels: Dictionary = {}


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	device = "controller" if Controls.controller_active else "keyboard"
	GameState.set_ui("controls", true)
	_build()
	Controls.bindings_changed.connect(_refresh)
	Controls.device_changed.connect(_device_changed)
	Lang.changed.connect(func(_locale: String) -> void: _refresh())
	(keyboard_button if device == "keyboard" else controller_button).grab_focus()


func _exit_tree() -> void:
	Controls.capture_active = false
	GameState.set_ui("controls", false)


func _build() -> void:
	controls_root = Control.new()
	controls_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(controls_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.86)
	controls_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 600)
	UiStyle.style_panel(panel)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	title_label = UiStyle.make_label("", 32, Color(0.65, 0.9, 1))
	box.add_child(title_label)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(tabs)
	keyboard_button = _button(tabs, "", func() -> void: _select_device("keyboard"))
	controller_button = _button(tabs, "", func() -> void: _select_device("controller"))
	help_label = UiStyle.make_label("", 18)
	box.add_child(help_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	for action: String in Controls.ACTION_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		list.add_child(row)
		var label := UiStyle.make_label("", 21)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size = Vector2(260, 40)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		action_labels[action] = label
		var button := _button(row, "", func() -> void: _begin_capture(action))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		binding_buttons[action] = button
	status = UiStyle.make_label("", 18, Color(1, 0.88, 0.5))
	status.custom_minimum_size.y = 48
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(footer)
	reset_button = _button(footer, "", func() -> void:
		Controls.reset_bindings(device)
		status.text = tr("Standaardbediening hersteld voor dit apparaat."))
	close_button = _button(footer, "", _close)
	_refresh()


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	UiStyle.style_button(button, 21)
	button.custom_minimum_size = Vector2(300, 44)
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _select_device(next_device: String) -> void:
	device = next_device
	_refresh()


func _refresh() -> void:
	title_label.text = tr("Bediening")
	help_label.text = tr("Klik een koppeling en druk de nieuwe invoer. Bestaande koppelingen wisselen om.")
	reset_button.text = tr("Standaard herstellen")
	close_button.text = tr("Terug")
	keyboard_button.text = ("● " if device == "keyboard" else "") + tr("Toetsenbord + muis")
	controller_button.text = ("● " if device == "controller" else "") + tr("Controller")
	for action: String in binding_buttons:
		action_labels[action].text = tr(Controls.ACTION_NAMES[action])
		binding_buttons[action].text = Controls.binding_label(action, device)
		binding_buttons[action].tooltip_text = Controls.binding_label(action, device)
	status.text = tr("Menu: WASD / pijlen / linkerstick / D-pad · Enter / A kiezen · Esc / B terug\nRichten: muis / rechterstick · Actief apparaat wisselt automatisch.")
	if not capture_action.is_empty():
		_capture_prompt()


func _device_changed(_using_controller: bool) -> void:
	if not capture_action.is_empty():
		return
	if get_viewport().gui_get_focus_owner() == null:
		close_button.grab_focus()


func _begin_capture(action: String) -> void:
	capture_action = action
	capture_time = 8.0
	Controls.capture_active = true
	_capture_prompt()


func _capture_prompt() -> void:
	status.text = tr("Nieuwe invoer voor %s (%s). Esc of 8 seconden wachten annuleert.") % [tr(Controls.ACTION_NAMES[capture_action]), tr("controller") if device == "controller" else tr("toetsenbord / muis")]
	binding_buttons[capture_action].text = tr("Druk de gewenste invoer…")


func _input(event: InputEvent) -> void:
	if not capture_action.is_empty():
		get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
			_end_capture(tr("Wijzigen geannuleerd."))
			return
		if event is InputEventMouseMotion or not event.is_pressed() or (event is InputEventKey and event.echo):
			return
		var controller_event := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if controller_event != (device == "controller"):
			return
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.6:
			return
		var error := Controls.rebind(capture_action, device, event)
		if error.is_empty():
			_end_capture(tr("Bediening opgeslagen. Een bezette koppeling is automatisch omgewisseld."))
		else:
			status.text = error + "  " + tr("Esc of wachten annuleert.")
		return
	if not Controls.allows_event(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("pause") and not Controls.is_ui_navigation_event(event)):
		get_viewport().set_input_as_handled()
		_close()
	elif event.is_action_pressed("ui_prev_tab") or event.is_action_pressed("ui_next_tab"):
		get_viewport().set_input_as_handled()
		_select_device("controller" if device == "keyboard" else "keyboard")
		(keyboard_button if device == "keyboard" else controller_button).grab_focus()


func _process(delta: float) -> void:
	if capture_action.is_empty():
		return
	capture_time -= delta
	if capture_time <= 0.0:
		_end_capture(tr("Geen nieuwe invoer ontvangen; je koppeling is behouden."))


func _end_capture(message: String) -> void:
	var button: Button = binding_buttons[capture_action]
	capture_action = ""
	Controls.capture_active = false
	_refresh()
	status.text = message
	button.grab_focus()


func _close() -> void:
	Controls.capture_active = false
	GameState.set_ui("controls", false)
	closed.emit()
	queue_free()
