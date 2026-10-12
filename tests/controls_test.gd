extends SceneTree
## Fysieke events, opslaan/herladen, veilige conflicten en de echte instellingsdialoog.

var failures := 0
var controls: Node


func check(condition: bool, label: String) -> void:
	print("  ok   " if condition else "  FAIL ", label)
	if not condition:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func frames(count := 2) -> void:
	for i in count:
		await process_frame


func key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event


func button(code: int, pressed := true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = code
	event.pressed = pressed
	return event


func axis(code: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = code
	event.axis_value = value
	return event


func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await frames()


func _run() -> void:
	controls = root.get_node("Controls")
	var gs: Node = root.get_node("GameState")
	gs.new_game()
	controls.reset_bindings("keyboard", false)
	controls.reset_bindings("controller", false)
	check(controls.action_label("bow", "controller") == "RT", "korte knopnamen passen in hints")
	check(controls.binding_label("attack", "keyboard").contains("Linkermuis"), "zwaard heeft standaard linkermuisknop")
	await send(key(KEY_D))
	check(Input.is_action_pressed("move_right") and not controls.controller_active, "fysieke D begint lopen")
	await send(axis(JOY_AXIS_LEFT_X, 0.13))
	check(not controls.controller_active and Input.is_action_pressed("move_right"), "stickdrift steelt geen toetsenbordinvoer")
	await send(button(JOY_BUTTON_X))
	check(controls.controller_active and Input.is_action_pressed("attack"), "eerste controllerdruk schakelt om en werkt direct")
	check(not Input.is_action_pressed("move_right"), "omschakelen geeft vastgehouden toetsen vrij")
	check(controls.desired_mouse_mode() == Input.MOUSE_MODE_HIDDEN, "controller verbergt de muis")
	await send(button(JOY_BUTTON_X, false))
	check(not Input.is_action_pressed("attack"), "losgelaten omschakelknop blijft niet hangen")
	await send(axis(JOY_AXIS_RIGHT_X, 0.9))
	check(controls.aim_vector().x > 0.8, "rechterstick stuurt richting")
	await send(key(KEY_H))
	check(not controls.controller_active and Input.is_action_pressed("potion"), "eerste toetsenborddruk schakelt terug en werkt")
	check(controls.aim_vector() == Vector2.ZERO and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "keyboardmenu negeert controllerdoel en toont muis")
	await send(key(KEY_H, false))
	check(not Input.is_action_pressed("potion"), "losgelaten omschakeltoets blijft niet hangen")
	await send(axis(JOY_AXIS_RIGHT_X, 0.85))
	check(not controls.controller_active, "vastgehouden stick trekt bediening niet terug")
	await send(axis(JOY_AXIS_RIGHT_X, 0.0))
	await send(axis(JOY_AXIS_RIGHT_X, -0.9))
	check(controls.controller_active and controls.aim_vector().x < -0.8, "nieuwe bewuste stickbeweging schakelt controller in")
	await send(axis(JOY_AXIS_RIGHT_X, 0.0))
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(1, 0)
	mouse.screen_relative = mouse.relative
	await send(mouse)
	check(controls.controller_active, "muisruis onder drempel blijft genegeerd")
	mouse = InputEventMouseMotion.new()
	mouse.relative = Vector2(10, 0)
	mouse.screen_relative = mouse.relative
	await send(mouse)
	check(not controls.controller_active and controls.mouse_aim_active, "bewuste muisbeweging activeert richten")
	var old_attack: String = controls.binding_label("attack", "keyboard")
	check(controls.rebind("attack", "keyboard", key(KEY_H), false).is_empty(), "bezette toets kan veilig worden gewisseld")
	check(controls.action_label("attack", "keyboard") == "H" and controls.binding_label("potion", "keyboard") == old_attack, "wisseling behoudt beide acties")
	var old_interact: String = controls.binding_label("interact", "controller")
	check(not controls.rebind("fullscreen", "controller", button(JOY_BUTTON_A), false).is_empty(), "ongebonden actie mag bestaande controllerknop niet wissen")
	check(controls.binding_label("interact", "controller") == old_interact, "interactie blijft bereikbaar na afgewezen conflict")
	check(not controls.rebind("bow", "controller", axis(JOY_AXIS_RIGHT_X, 1.0), false).is_empty(), "rechterstick blijft voor richten gereserveerd")
	check(controls.rebind("bow", "controller", button(JOY_BUTTON_RIGHT_SHOULDER), false).is_empty(), "boog kan op een knop en wisselt kaart veilig")
	check(controls.action_label("bow", "controller") == "RB" and controls.action_label("map", "controller") == "RT", "trigger en gewone knop zijn verwisselbaar")
	controls._save_bindings()
	controls.reset_bindings("keyboard", false)
	controls.reset_bindings("controller", false)
	controls._load_bindings()
	controls._apply_bindings()
	check(controls.action_label("attack", "keyboard") == "H" and controls.action_label("bow", "controller") == "RB", "beide apparaatprofielen worden opgeslagen en herladen")
	var menu: CanvasLayer = load("res://scripts/ui/controls_menu.gd").new()
	root.add_child(menu)
	await frames()
	check(paused and gs.ui_owners.has("controls"), "instellingen pauzeren het spel via bestaande schermregistratie")
	check(menu.binding_buttons.size() == controls.ACTION_NAMES.size(), "iedere speelactie is bereikbaar in instelmenu")
	menu._begin_capture("attack")
	await send(key(KEY_F8))
	check(menu.capture_action.is_empty() and controls.action_label("attack", "keyboard") == "F8", "echt remappen via modal onderschept nieuwe toets")
	menu._begin_capture("attack")
	await send(key(KEY_ESCAPE))
	check(menu.capture_action.is_empty() and controls.action_label("attack", "keyboard") == "F8", "Escape annuleert opname zonder koppeling te wijzigen")
	check(controls.rebind("pause", "controller", button(JOY_BUTTON_A), false).is_empty(), "speelactie mag vaste menubevestiging gebruiken")
	await send(button(JOY_BUTTON_DPAD_DOWN))
	await send(button(JOY_BUTTON_DPAD_DOWN, false))
	menu.controller_button.grab_focus()
	await send(button(JOY_BUTTON_A))
	await send(button(JOY_BUTTON_A, false))
	check(is_instance_valid(menu) and menu.device == "controller", "A bevestigt in menu ook als pauze op A is ingesteld")
	await send(button(JOY_BUTTON_B))
	await send(button(JOY_BUTTON_B, false))
	check(not paused and not controls.capture_active, "sluiten geeft pauze en invoer weer vrij")
	controls._joy_connection_changed(0, false)
	check(not controls.controller_active and not Input.is_action_pressed("pause"), "loskoppelen controller geeft invoer en toetsenbord vrij")
	controls.reset_bindings("keyboard")
	controls.reset_bindings("controller")
	check(controls.action_label("attack", "keyboard") == "Space" and controls.action_label("bow", "controller") == "RT", "standaardherstel herstelt beide profielen")
	var world: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(10)
	await send(button(JOY_BUTTON_START))
	await send(button(JOY_BUTTON_START, false))
	check(world.pause_menu.open and paused, "Start opent het echte pauzemenu")
	await send(button(JOY_BUTTON_B))
	await send(button(JOY_BUTTON_B, false))
	check(not world.pause_menu.open and not paused, "B sluit ook het echte pauzemenu")
	gs.ended = true
	await send(button(JOY_BUTTON_START))
	await send(button(JOY_BUTTON_START, false))
	await frames(10)
	check(not gs.ended and not paused and not current_scene.pause_menu.open, "Start na verlies herstart de wereld zonder pauzemenu")
	current_scene.queue_free()
	await frames()
	print("CONTROLS OK" if failures == 0 else "CONTROLS FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
