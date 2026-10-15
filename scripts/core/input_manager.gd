extends Node
## Eén actief invoerapparaat, leesbare hints en opgeslagen bediening per apparaat.

signal device_changed(using_controller: bool)
signal bindings_changed

const SAVE_PATH := "user://controls.cfg"
const SWITCH_DEADZONE := 0.5
const AIM_DEADZONE := 0.24
const ACTION_NAMES := {
	"homestead": "Tuinstanden",
	"move_up": "Omhoog lopen", "move_down": "Omlaag lopen",
	"move_left": "Naar links lopen", "move_right": "Naar rechts lopen",
	"technique": "Techniek (vasthouden + zwaard / boog)",
	"attack": "Zwaard", "bow": "Boog", "interact": "Praten / gebruiken",
	"dodge": "Rollen", "sprint": "Rennen (vasthouden)", "potion": "Drankje",
	"menu": "Inventaris", "crafting": "Beroepen / maken", "quests": "Opdrachten",
	"map": "Kaart", "wereld_prestaties": "Prestaties", "wereld_beestenboek": "Beestenboek",
	"pause": "Pauze", "restart": "Opnieuw na verlies", "mute": "Geluid aan / uit", "fullscreen": "Volledig scherm",
}
const JOY_NAMES := ["A / kruis", "B / cirkel", "X / vierkant", "Y / driehoek", "Select / View", "Home", "Start / Menu", "L3", "R3", "LB / L1", "RB / R1", "D-pad omhoog", "D-pad omlaag", "D-pad links", "D-pad rechts"]

var controller_active := false
var mouse_aim_active := false
var capture_active := false
var controller_device := -1
var _bindings: Dictionary = {}
var _defaults: Dictionary = {}
var _axis_values: Dictionary = {}
var _last_event: InputEvent


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_defaults()
	for action: StringName in InputMap.get_actions():
		var categories := {"keyboard": [], "controller": []}
		for event: InputEvent in InputMap.action_get_events(action):
			categories[_category(event)].append(event.duplicate())
		_bindings[str(action)] = categories
	_defaults = _bindings.duplicate(true)
	_load_bindings()
	_apply_bindings()
	Input.joy_connection_changed.connect(_joy_connection_changed)


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _button(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	return event


func _axis(index: int, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = direction
	return event


func _mouse(index: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	return event


func _define(action: String, events: Array, deadzone := 0.3) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	InputMap.action_erase_events(action)
	InputMap.action_set_deadzone(action, deadzone)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


func _install_defaults() -> void:
	_define("homestead", [_key(KEY_U)])
	_define("technique", [_key(KEY_V), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)], 0.5)
	InputMap.action_add_event("attack", _mouse(MOUSE_BUTTON_LEFT))
	InputMap.action_add_event("bow", _mouse(MOUSE_BUTTON_RIGHT))
	for spec in [["ui_left", KEY_LEFT, KEY_A, JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT],
		["ui_right", KEY_RIGHT, KEY_D, JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT],
		["ui_up", KEY_UP, KEY_W, JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP],
		["ui_down", KEY_DOWN, KEY_S, JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN]]:
		_define(spec[0], [_key(spec[1]), _key(spec[2]), _axis(spec[3], spec[4]), _button(spec[5])])
	_define("ui_accept", [_key(KEY_ENTER), _key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_define("ui_cancel", [_key(KEY_ESCAPE), _button(JOY_BUTTON_B)])
	_define("ui_prev_tab", [_key(KEY_PAGEUP), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_define("ui_next_tab", [_key(KEY_PAGEDOWN), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_define("aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)], AIM_DEADZONE)
	_define("aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)], AIM_DEADZONE)
	_define("aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)], AIM_DEADZONE)
	_define("aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)], AIM_DEADZONE)


func _category(event: InputEvent) -> String:
	return "controller" if event is InputEventJoypadButton or event is InputEventJoypadMotion else "keyboard"


func _input(event: InputEvent) -> void:
	if not allows_event(event):
		get_viewport().set_input_as_handled()


func allows_event(event: InputEvent) -> bool:
	# Menuschermen mogen dit vóór hun eigen verwerking aanroepen.
	if event == _last_event:
		return _event_matches_device(event)
	_last_event = event
	if capture_active:
		return true
	if event is InputEventJoypadMotion:
		var axis_key := "%d:%d" % [event.device, event.axis]
		var previous := float(_axis_values.get(axis_key, 0.0))
		_axis_values[axis_key] = event.axis_value
		# Een vastgehouden stick of drift steelt de muis niet terug.
		if absf(event.axis_value) >= SWITCH_DEADZONE and absf(previous) < SWITCH_DEADZONE:
			_set_device(true, event)
	elif event is InputEventJoypadButton:
		if event.pressed:
			_set_device(true, event)
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			_set_device(false, event)
	elif event is InputEventMouseButton:
		if event.pressed:
			mouse_aim_active = true
			_set_device(false, event)
	elif event is InputEventMouseMotion and _mouse_distance(event) >= 3.0:
		mouse_aim_active = true
		_set_device(false, event)
	return _event_matches_device(event)


func _mouse_distance(event: InputEventMouseMotion) -> float:
	# schermpixels blijven gelijk bij een klein venster of viewport-stretch.
	return event.screen_relative.length() if event.screen_relative != Vector2.ZERO else event.relative.length()


func _event_matches_device(event: InputEvent) -> bool:
	if event is InputEventAction:
		return true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return controller_active and (controller_device < 0 or event.device == controller_device)
	if event is InputEventMouse or event is InputEventKey:
		return not controller_active
	return true


func _set_device(use_controller: bool, event: InputEvent = null) -> void:
	var device := event.device if use_controller and event != null else -1
	if controller_active == use_controller and (not use_controller or controller_device == device):
		return
	controller_active = use_controller
	controller_device = device
	if use_controller:
		mouse_aim_active = false
	_apply_bindings()
	# Het omschakelende event is vóór _input gemapt. Herstel het na vrijgeven
	# zodat de eerste druk werkt én de vorige invoer niet blijft hangen.
	if event != null and event.is_pressed():
		for action: String in _bindings:
			if event.is_action(action):
				Input.action_press(action, event.get_action_strength(action))
	_update_cursor()
	device_changed.emit(controller_active)


func _joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and controller_active and device == controller_device:
		_set_device(false)


func _process(_delta: float) -> void:
	_update_cursor()


func _update_cursor() -> void:
	var mode := desired_mouse_mode()
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


func desired_mouse_mode() -> int:
	var hide_cursor := controller_active or (GameState.in_game and not GameState.input_locked())
	return Input.MOUSE_MODE_HIDDEN if hide_cursor else Input.MOUSE_MODE_VISIBLE


func _apply_bindings() -> void:
	var category := "controller" if controller_active else "keyboard"
	for action: String in _bindings:
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for original: InputEvent in _bindings[action][category]:
			var event := original.duplicate() as InputEvent
			if category == "controller":
				event.device = controller_device
			InputMap.action_add_event(action, event)


func aim_vector() -> Vector2:
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", AIM_DEADZONE) if controller_active else Vector2.ZERO


func is_ui_navigation_event(event: InputEvent) -> bool:
	# Vaste menu-invoer houdt voorrang op vrij ingestelde speelacties.
	if event is InputEventMouseButton:
		return true
	for action: String in ["ui_left", "ui_right", "ui_up", "ui_down", "ui_accept", "ui_prev_tab", "ui_next_tab", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action(action):
			return true
	return false


func binding_events(action: String, device := "") -> Array:
	if device.is_empty():
		device = "controller" if controller_active else "keyboard"
	return _bindings.get(action, {}).get(device, []).duplicate()


func action_label(action: String, device := "", full := false) -> String:
	var events := binding_events(action, device)
	var labels: Array[String] = []
	for event: InputEvent in events:
		var label := event_label(event, full)
		if not labels.has(label):
			labels.append(label)
		if not full:
			break
	return " / ".join(labels) if not labels.is_empty() else tr("Niet ingesteld")


func binding_label(action: String, device := "") -> String:
	return action_label(action, device, true)


func event_label(event: InputEvent, full := false) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: return tr("Linkermuis")
			MOUSE_BUTTON_RIGHT: return tr("Rechtermuis")
			MOUSE_BUTTON_MIDDLE: return tr("Middelmuisknop")
			MOUSE_BUTTON_WHEEL_UP: return tr("Wiel omhoog")
			MOUSE_BUTTON_WHEEL_DOWN: return tr("Wiel omlaag")
		return tr("Muisknop %d") % event.button_index
	if event is InputEventJoypadButton:
		var name: String = tr(JOY_NAMES[event.button_index]) if event.button_index < JOY_NAMES.size() else tr("Knop %d") % event.button_index
		return name if full else name.split(" / ")[0]
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_TRIGGER_LEFT:
			return "LT / L2" if full else "LT"
		if event.axis == JOY_AXIS_TRIGGER_RIGHT:
			return "RT / R2" if full else "RT"
		if event.axis == JOY_AXIS_LEFT_X:
			return tr("Linkerstick links") if event.axis_value < 0 else tr("Linkerstick rechts")
		return tr("Linkerstick omhoog") if event.axis_value < 0 else tr("Linkerstick omlaag")
	return event.as_text()


func rebind(action: String, device: String, event: InputEvent, save := true) -> String:
	if not ACTION_NAMES.has(action) or not ["keyboard", "controller"].has(device) or _category(event) != device:
		return tr("Kies een geldige toets of controllerknop.")
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			return tr("De rechterstick blijft beschikbaar om te richten.")
		if absf(event.axis_value) < 0.6:
			return tr("Beweeg de stick of trigger verder.")
	elif not event is InputEventKey and not event is InputEventJoypadButton and not event is InputEventMouseButton:
		return tr("Kies een toets, muisknop, stickrichting of trigger.")
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and action != "pause":
		return tr("Esc blijft beschikbaar om menu's te sluiten.")
	var normalized := event.duplicate() as InputEvent
	normalized.device = -1
	if normalized is InputEventWithModifiers:
		normalized.alt_pressed = false
		normalized.ctrl_pressed = false
		normalized.meta_pressed = false
		normalized.shift_pressed = false
	if normalized is InputEventKey:
		normalized.pressed = false
		normalized.echo = false
		if normalized.physical_keycode == 0:
			normalized.physical_keycode = normalized.keycode
		normalized.keycode = 0
	elif normalized is InputEventJoypadButton or normalized is InputEventMouseButton:
		normalized.pressed = false
	if normalized is InputEventJoypadMotion:
		normalized.axis_value = signf(normalized.axis_value)
	var conflicts: Array[String] = []
	for other: String in ACTION_NAMES:
		if other == action:
			continue
		for bound: InputEvent in _bindings[other][device]:
			if _same_binding(bound, normalized):
				conflicts.append(other)
				break
	# We wisselen hele koppelingen om: geen actie raakt onbedoeld onbereikbaar.
	if conflicts.size() > 1:
		return tr("Deze invoer hoort bij meerdere acties; kies een andere.")
	var old: Array = _bindings[action][device].duplicate()
	if conflicts.size() == 1:
		if old.is_empty():
			return tr("Die invoer is al gekoppeld aan %s. Kies een vrije knop.") % tr(ACTION_NAMES[conflicts[0]])
		_bindings[conflicts[0]][device] = old
	_bindings[action][device] = [normalized]
	_apply_bindings()
	bindings_changed.emit()
	if save:
		_save_bindings()
	return ""


func _same_binding(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a.physical_keycode if a.physical_keycode else a.keycode) == (b.physical_keycode if b.physical_keycode else b.keycode)
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false


func reset_bindings(device: String, save := true) -> void:
	if not ["keyboard", "controller"].has(device):
		return
	for action: String in ACTION_NAMES:
		_bindings[action][device] = _defaults[action][device].duplicate(true)
	_apply_bindings()
	bindings_changed.emit()
	if save:
		_save_bindings()


func _save_bindings() -> void:
	var config := ConfigFile.new()
	for action: String in ACTION_NAMES:
		for device: String in ["keyboard", "controller"]:
			config.set_value(device, action, _bindings[action][device])
	if config.save(SAVE_PATH) != OK:
		GameState.toast.emit(tr("Bediening kon niet worden opgeslagen."))


func _load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for action: String in ACTION_NAMES:
		for device: String in ["keyboard", "controller"]:
			if not config.has_section_key(device,action): continue
			var stored: Variant = config.get_value(device, action, null)
			if not stored is Array or stored.size() > 8:
				continue
			var valid: Array = []
			for event: Variant in stored:
				if event is InputEvent and _category(event) == device:
					valid.append(event)
			if valid.size() == stored.size():
				_bindings[action][device] = valid
	# An older custom scheme may already use V or LT. Keep those bindings and
	# choose a free technique modifier instead of silently firing two actions.
	for device: String in ["keyboard","controller"]:
		if config.has_section_key(device,"technique"): continue
		var choices: Array = [_key(KEY_V),_key(KEY_G),_key(KEY_Z)] if device == "keyboard" else [_axis(JOY_AXIS_TRIGGER_LEFT,1.0),_axis(JOY_AXIS_TRIGGER_RIGHT,1.0),_button(JOY_BUTTON_RIGHT_STICK)]
		_bindings.technique[device] = []
		for candidate: InputEvent in choices:
			var used := false
			for action: String in ACTION_NAMES:
				if action == "technique": continue
				for binding: InputEvent in _bindings[action][device]:
					if _same_binding(candidate,binding): used = true
			if not used:
				_bindings.technique[device] = [candidate]
				break

	# A new garden shortcut must not steal an existing saved binding.
	for device: String in ["keyboard","controller"]:
		if config.has_section_key(device,"homestead"):continue
		var choices: Array=[_key(KEY_U),_key(KEY_O),_key(KEY_Z)] if device=="keyboard" else []
		_bindings.homestead[device]=[]
		for candidate: InputEvent in choices:
			var used:=false
			for action: String in ACTION_NAMES:
				if action=="homestead":continue
				for binding: InputEvent in _bindings[action][device]:
					if _same_binding(candidate,binding):used=true
			if not used:
				_bindings.homestead[device]=[candidate];break
