extends SceneTree
## Werkelijke UI-invoer, volle inventaris en samenhang van de nieuwe uitbreiding.

const Items := preload("res://scripts/data/items.gd")

var failures := 0
var gs: Node
var world: Node2D


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures += 1


func frames(count: int = 3) -> void:
	for i in count:
		await process_frame


func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	root.push_input(event)


func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.new_game()
	gs.in_game = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(10)
	world.fader.set_alpha(0.0)
	world.set_process(false)
	world.player.set_physics_process(false)
	for item: String in Items.ITEMS:
		if item != "coin":
			gs.give(item, 1, true)
	press("menu")
	await frames()
	var menu: Node = world.menu_ui
	check(menu.active and paused, "inventaris opent met echte invoer")
	var owned: Array = menu._owned()
	check(owned.size() > menu.INVENTORY_PAGE_SIZE, "alle nieuwe en oude spullen passen over meerdere pagina's")
	var seen: Dictionary = {0: true}
	var all_visible := true
	for i in owned.size() + 3:
		press("ui_right")
		await frames(1)
		seen[menu.selected] = true
		var first: int = menu.inventory_page_start()
		all_visible = all_visible and menu.selected >= first and menu.selected < first + menu.INVENTORY_PAGE_SIZE
	check(seen.size() == owned.size(), "elk voorwerp is selecteerbaar met toetsenbord/controller")
	check(all_visible and menu.selected == owned.size() - 1, "gekozen voorwerp blijft binnen de zichtbare pagina")
	for i in owned.size() + 3:
		press("ui_left")
	check(menu.selected == 0 and menu.inventory_page_start() == 0, "links keert terug naar de eerste pagina")
	gs.hp = 1
	menu.selected = owned.find("prof_berry_meal")
	press("interact")
	check(gs.hp == 4 and gs.count("prof_berry_meal") == 0, "nieuwe voeding is ook uit de gewone inventaris te gebruiken")
	gs.movement.stamina = 10.0
	menu.selected = menu._owned().find("prof_tonic")
	press("interact")
	check(is_equal_approx(gs.movement.stamina, 70.0) and gs.count("prof_tonic") == 0, "energie-elixer vult echte stamina aan")
	press("ui_next_tab")
	check(menu.tab == 1, "schouderknoppen wisselen tabblad los van de inventarisrichting")
	press("pause")
	await frames()
	check(not paused and not world.pause_menu.open, "inventaris sluiten opent geen tweede menu")
	press("crafting")
	await frames()
	check(world.crafting_ui.active and paused, "C opent beroepen via de wereld")
	var before: int = gs.count("prof_axe")
	press("interact")
	await frames()
	check(gs.count("prof_axe") == before, "een bestaand uniek gereedschap wordt niet dubbel gemaakt")
	press("crafting")
	await frames()
	check(not world.crafting_ui.active and not paused, "C sluit beroepen zonder direct te heropenen")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_STICK
	pad.pressed = true
	root.push_input(pad)
	await frames()
	check(world.crafting_ui.active and paused, "R3 opent het beroepenmenu op een controller")
	press("pause")
	await frames()
	check(not world.crafting_ui.active and not paused and not world.pause_menu.open, "Esc sluit alleen het beroepenmenu")
	world.queue_free()
	await frames()
	print("ADVENTURE INTEGRATION OK" if failures == 0 else "ADVENTURE INTEGRATION MISLUKT: %d" % failures)
	quit(0 if failures == 0 else 1)
