extends SceneTree
## Real physical input checks: grid, mouse, controller focus, one activation and modal cancellation.

const Items := preload("res://scripts/data/items.gd")
const Quests := preload("res://scripts/data/quests.gd")

var failures := 0
var gs: Node
var world: Node
var controls: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("  ok   " if ok else "  FAIL ", label)
	if not ok:
		failures += 1

func frames(count := 3) -> void:
	for i in count:
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap_key(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(3)

func pad(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func tap_pad(button: JoyButton) -> void:
	pad(button, true)
	await frames(3)
	pad(button, false)
	await frames(3)

func click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.relative = Vector2(40, 0)
	motion.screen_relative = motion.relative
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = button
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
		await frames(2)

func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	controls = root.get_node("Controls")
	gs.new_game()
	gs.in_game = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(10)
	world.fader.set_alpha(0.0)
	world.set_process(false)
	world.player.set_physics_process(false)
	for id: String in Items.ITEMS:
		if id != "coin":
			gs.give(id, 1, true)
	await _inventory()
	await _crafting()
	await _shop()
	await _dialogue()
	await _remapped_menu_controls()
	await _live_language_refresh()
	world.queue_free()
	await frames()
	check(not paused and gs.ui_owners.is_empty(), "All modal owners are released")
	print("UI NAVIGATION OK" if failures == 0 else "UI NAVIGATION FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)

func _inventory() -> void:
	var menu: Node = world.menu_ui
	await tap_key(KEY_I)
	check(menu.active and paused, "Physical I opens inventory")
	await tap_key(KEY_S)
	check(menu.selected == 6 and menu.tab == 0, "WASD down moves one grid row without switching tabs")
	await tap_key(KEY_D)
	check(menu.selected == 7, "WASD right moves one column")
	await tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(menu.selected == 13 and controls.controller_active, "D-pad navigates grid after device switch")
	for value: float in [0.8, 0.82, 0.78, 0.84]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_LEFT_Y
		motion.axis_value = value
		Input.parse_input_event(motion)
		await frames(1)
	check(menu.selected == 19, "Analog stick jitter produces one grid step before repeat delay (%d)" % menu.selected)
	var neutral := InputEventJoypadMotion.new()
	neutral.axis = JOY_AXIS_LEFT_Y
	neutral.axis_value = 0.0
	Input.parse_input_event(neutral)
	await frames(3)
	await tap_pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(menu.tab == 1, "RB switches tabs exactly once")
	for id: String in Quests.QUESTS:
		gs.start_quest(id)
	for i in menu._quest_order().size():
		await tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(menu.quest_selected == menu._quest_order().size() - 1 and menu.quest_scroll > 0, "Long quest list is fully reachable by controller")
	await click(menu.content.position + Vector2(110, 34))
	check(menu.tab == 0 and not controls.controller_active, "Mouse takes over and clicks the inventory tab")
	await click(menu.content.position + Vector2(150, 145))
	check(menu.selected == 1, "Mouse selects a grid slot")
	await click(menu.content.position + menu.NEXT_PAGE.get_center())
	check(menu.inventory_page_start() == 24, "Mouse page button reaches the second inventory page")
	await click(menu.content.position + menu.PREVIOUS_PAGE.get_center())
	check(menu.selected == 0, "Mouse previous page returns to the first page")
	key(KEY_S, true)
	await frames(38)
	key(KEY_S, false)
	check(menu.selected > 6, "Holding a navigation key repeats after the initial delay")
	await frames(3)
	await click(menu.content.position + menu.CLOSE_RECT.get_center())
	check(not menu.active and not paused and not world.pause_menu.open, "Mouse close releases inventory without opening pause")

func _crafting() -> void:
	gs.inventory.erase("prof_axe")
	gs.give("prof_branch", 6, true)
	gs.give("prof_stone", 6, true)
	await tap_pad(JOY_BUTTON_RIGHT_STICK)
	await frames(5)
	var menu: Node = world.crafting_ui
	check(menu.active and root.gui_get_focus_owner() is Button, "R3 opens crafting with a focused recipe")
	var before: int = gs.count("prof_branch")
	pad(JOY_BUTTON_A, true)
	await frames(20)
	pad(JOY_BUTTON_A, false)
	await frames(5)
	check(gs.count("prof_axe") == 1 and gs.count("prof_branch") == before - 2, "Holding and releasing A crafts once, without duplicate ingredients")
	await tap_pad(JOY_BUTTON_DPAD_LEFT)
	check(menu.skill_list.is_ancestor_of(root.gui_get_focus_owner()), "Left moves from recipes to professions")
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(menu.rows.is_ancestor_of(root.gui_get_focus_owner()), "Right moves back to recipe list")
	await tap_pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(menu.supplies, "RB opens supplies without triggering a recipe")
	await tap_pad(JOY_BUTTON_B)
	check(not menu.active and not paused and not world.pause_menu.open, "B closes crafting without leaking into dodge or pause")

func _shop() -> void:
	gs.coins = 500
	gs.inventory.erase("potion")
	world.shop_ui.open("tobias")
	await frames(5)
	var start_coins: int = gs.coins
	pad(JOY_BUTTON_A, true)
	await frames(20)
	pad(JOY_BUTTON_A, false)
	await frames(5)
	check(gs.coins == start_coins - 15 and gs.count("potion") == 1, "A buys one item even when held and the list rebuilds")
	await tap_key(KEY_E)
	check(gs.coins == start_coins - 30 and gs.count("potion") == 2, "E buys one item after switching back to keyboard")
	var disabled: Button
	for child: Node in world.shop_ui.list.get_children():
		if child is Button and child.disabled:
			disabled = child
	if disabled:
		disabled.grab_focus()
		await tap_key(KEY_E)
		check(gs.coins == start_coins - 30, "E cannot activate a disabled owned item")
	check(Rect2(Vector2.ZERO, Vector2(1152, 648)).encloses(world.shop_ui.panel.get_global_rect()), "The shop fits inside the viewport")
	await click(world.shop_ui.close_button.get_global_rect().get_center())
	check(not world.shop_ui.active and not paused, "Shop has a working mouse close button")

func _dialogue() -> void:
	var dialogue: Node = world.dialogue
	dialogue.start_text("Test", ["First line.", "Second line."])
	await frames(3)
	await tap_pad(JOY_BUTTON_A)
	check(dialogue.line_idx == 0 and dialogue.text_label.visible_characters == -1, "A first reveals the current dialogue line")
	await tap_pad(JOY_BUTTON_A)
	check(dialogue.line_idx == 1 and dialogue.active, "A advances dialogue by one line")
	await click(dialogue.panel.get_global_rect().get_center())
	check(dialogue.text_label.visible_characters == -1, "Mouse click reveals dialogue text")
	await tap_pad(JOY_BUTTON_B)
	check(not dialogue.active and not paused and not gs.dialogue_open, "B exits dialogue and releases the pause owner")

func _remap_action(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	check(controls.rebind(action, "controller", event, false) == "", "Controller binding can be changed: " + action)

func _remapped_menu_controls() -> void:
	var menu: Node = world.menu_ui
	_remap_action("menu", JOY_BUTTON_DPAD_DOWN)
	menu.open(0)
	await frames(4)
	await tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(menu.active and menu.selected == 6, "Remapped inventory hotkey cannot override directional UI navigation")
	menu.close()
	controls.reset_bindings("controller", false)
	_remap_action("pause", JOY_BUTTON_A)
	menu.open(0)
	await frames(4)
	await tap_pad(JOY_BUTTON_A)
	check(menu.active and paused, "Remapped pause cannot override A confirm inside inventory")
	menu.close()
	controls.reset_bindings("controller", false)
	_remap_action("interact", JOY_BUTTON_DPAD_RIGHT)
	menu.open(0)
	await frames(4)
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(menu.active and menu.selected == 1, "Remapped interact cannot consume an item while navigating")
	menu.close()
	controls.reset_bindings("controller", false)
	_remap_action("crafting", JOY_BUTTON_A)
	world.crafting_ui.open()
	await frames(5)
	await tap_pad(JOY_BUTTON_A)
	check(world.crafting_ui.active and paused, "Remapped crafting hotkey cannot close the journal on A confirm")
	world.crafting_ui.close()
	controls.reset_bindings("controller", false)

func _live_language_refresh() -> void:
	var lang := root.get_node("Lang")
	var data: Script = load("res://scripts/data/ext/beroepen.gd")
	var menu: Node = world.crafting_ui
	menu.supplies = false
	menu.selected_skill = ""
	menu.open()
	await frames(5)
	lang.set_language("en", false)
	await frames(8)
	check(menu.title_label.text == TranslationServer.translate(data.TEXT["title"]) and menu.title_label.text != data.TEXT["title"], "Open crafting title refreshes to English without rebuilding the world")
	check(menu.filter.get_item_text(1) == TranslationServer.translate(data.SKILLS["foraging"]["name"]), "Profession filters use translated data names")
	check(Rect2(Vector2.ZERO, Vector2(1152, 648)).encloses(menu.panel.get_global_rect()), "English crafting panel remains entirely visible")
	check(root.gui_get_focus_owner() is Button and menu.rows.is_ancestor_of(root.gui_get_focus_owner()), "Language refresh preserves usable recipe focus")
	lang.set_language("nl", false)
	await frames(5)
	check(menu.title_label.text == data.TEXT["title"] and menu.close_button.text == "Sluiten", "Open crafting menu returns to Dutch immediately")
	menu.close()
