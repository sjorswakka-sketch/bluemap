extends SceneTree
## Run only with an isolated user data directory, like the other integration tests.
const Data := preload("res://scripts/data/ext/beroepen.gd")
const Professions := preload("res://scripts/core/professions.gd")
const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Items := preload("res://scripts/data/items.gd")

var failures := 0
var gs: Node


func check(value: bool, message: String) -> void:
	print("  ok   " if value else "  FAIL ", message)
	if not value:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	gs = root.get_node("GameState")
	gs.new_game()
	gs.in_game = false
	check(Data.SKILLS.size() == 7, "Seven distinct professions")
	check(Professions.normalize(null) == {"xp": {}, "cooldowns": {}}, "Older saves get safe empty defaults")
	var safe := Professions.normalize({"xp": {"mining": -3, "cooking": 9999999, "alchemy": "bad", "unknown": 8}, "cooldowns": {"village:twigs_west": 999999, "bad": 90}}, 100)
	check(safe["xp"]["mining"] == 0 and safe["xp"]["cooking"] == Professions.MAX_XP and not safe["xp"].has("alchemy") and not safe["xp"].has("unknown"), "Corrupt or unknown skill entries normalized")
	check(safe["cooldowns"] == {"village:twigs_west": 190.0}, "Resource timers bounded and unknown IDs removed")
	_validate_resources()
	for item: String in Data.ITEMS:
		check(Items.ITEMS.has(item), "Registered item: " + item)
	gs.map_id = "village"
	check(not Professions.craft("unknown") and not Professions.craft("stone_axe"), "Invalid and unaffordable recipes fail")
	check(not Professions.gather("stump", "forest:birch_west"), "Axe required to cut wood")
	check(not Professions.gather("copper", "forest:copper_west"), "Pickaxe required to mine copper")
	check(Professions.gather("branches", "village:twigs_west"), "First branches gathered without tools")
	check(Professions.gather("branches", "village:twigs_south"), "Second branches supply both starter tools")
	check(Professions.gather("stones", "village:flint_west") and Professions.gather("stones", "village:flint_south"), "Starter flint gathered without tools")
	var branches: int = gs.count("prof_branch")
	var wood_xp := Professions.xp("woodcutting")
	check(not Professions.gather("branches", "village:twigs_west") and gs.count("prof_branch") == branches and Professions.xp("woodcutting") == wood_xp, "Repeated E cannot duplicate materials or XP")
	check(Professions.craft("stone_axe") and Professions.craft("stone_pickaxe"), "Both starter tools can be crafted from freely gathered material")
	check(gs.count("prof_branch") == 0 and gs.count("prof_stone") == 0, "Crafting removes exactly the required ingredients")
	check(Professions.gather("stump", "forest:birch_west") and gs.count("prof_log") == 2, "Basic axe yields two logs")
	check(Professions.gather("copper", "forest:copper_west"), "Basic pickaxe unlocks copper")
	check(not Professions.craft("copper_bar"), "Smelting requires the smithy")
	gs.map_id = "smithy"
	check(Professions.craft("copper_bar") and gs.count("prof_copper_bar") == 1, "Ore and wood become a copper bar at the smithy")
	check(not Professions.craft("copper_pickaxe"), "Advanced tools are locked by skill level")
	check(not Professions.gather("iron", "cave:iron_entry"), "Iron requires advanced pickaxe")
	gs.give("prof_copper_ore", 4, true)
	gs.give("prof_log", 10, true)
	check(Professions.craft("copper_bar") and Professions.craft("copper_bar") and Professions.level("smithing") == 2, "Making three ingots advances smithing to level two")
	check(Professions.craft("copper_pickaxe"), "Progression unlocks a copper pickaxe")
	var before: Dictionary = gs.inventory.duplicate()
	check(not Professions.craft("copper_pickaxe") and before == gs.inventory, "Owned tool cannot consume ingredients twice")
	Professions.add_xp("mining", 30)
	check(Professions.gather("iron", "cave:iron_entry"), "Upgraded pickaxe and skill unlock iron")
	gs.give("prof_iron_axe", 1, true)
	gs.play_time += 151.0
	check(Professions.gather("stump", "forest:birch_west") and Professions.gather_amount("stump") == 3, "Iron axe gives more logs after cooldown")
	var fishing_before := Professions.xp("fishing")
	Professions.record_fish("meer_laars")
	check(Professions.xp("fishing") == fishing_before, "Junk catches do not award fishing experience")
	Professions.record_fish("meer_baars")
	check(Professions.xp("fishing") == fishing_before + 8, "Successful fish award fishing experience")
	gs.give("prof_berry", 15, true)
	gs.map_id = "forest"
	for i in 5:
		Professions.craft("berry_meal")
	check(Professions.level("cooking") == 2 and gs.count("prof_berry_meal") == 5, "Portable cooking opens warm meal recipes")
	gs.hp = gs.max_hp()
	check(not Professions.use_item("prof_berry_meal") and gs.count("prof_berry_meal") == 5, "Food is not wasted at full health")
	gs.hp -= 2
	check(Professions.use_item("prof_berry_meal") and gs.hp == gs.max_hp() - 1 and gs.count("prof_berry_meal") == 4, "Food heals and consumes exactly one")
	gs.give("prof_tonic", 2, true)
	gs.movement.stamina = 100.0
	check(not Professions.use_item("prof_tonic") and gs.count("prof_tonic") == 2, "Tonic is not wasted at full stamina")
	gs.movement.stamina = 15.0
	check(Professions.use_item("prof_tonic") and gs.movement.stamina == 75.0 and gs.count("prof_tonic") == 1, "Tonic restores sixty stamina")
	Professions.add_xp("foraging", 999999)
	check(Professions.level("foraging") == 10 and Professions.xp("foraging") == Professions.MAX_XP, "Profession levels and XP are capped")
	# Persistence test goes through the existing game's complete save/load path.
	gs.in_game = true
	gs.map_id = "village"
	gs.save_game(Vector2(624, 304))
	var saved: Dictionary = gs.professions.duplicate(true)
	gs.professions = {}
	check(gs.load_game(), "Save loads successfully with profession data")
	check(gs.professions["xp"] == saved["xp"], "Profession XP survives save/load")
	check(Professions.remaining("forest:birch_west") > 140, "Resource cooldown survives save/load")
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH))
	old_save.erase("professions")
	var old_file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	old_file.store_string(JSON.stringify(old_save))
	old_file.close()
	check(gs.load_game() and Professions.level("smithing") == 1, "An actual old-format save without professions still loads")
	gs.new_game()
	check(Professions.level("mining") == 1 and Professions.remaining("forest:birch_west") == 0.0, "New game resets profession progress and resource timers")
	await _world_ui()
	print("PROFESSIONS OK" if failures == 0 else "PROFESSIONS FAILED: %d" % failures)
	quit(1 if failures else 0)


func frames(count: int) -> void:
	for i in count:
		await process_frame


func key_event(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	Input.parse_input_event(up)


func _world_ui() -> void:
	var world: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await frames(5)
	check(get_nodes_in_group("profession_resources").size() == 6, "Village creates six usable resource nodes")
	var node: Node = get_nodes_in_group("profession_resources")[0]
	var resource_id: String = node.resource_id
	node.interact()
	check(Professions.remaining(resource_id) > 85, "World node starts its persistent timer")
	world.load_map("forest", "start")
	await frames(2)
	world.load_map("village", "start")
	await frames(2)
	check(Professions.remaining(resource_id) > 85, "Leaving and revisiting a map does not respawn resources")
	var meer_logic: Script = load("res://scripts/data/ext/meer_logic.gd")
	var previous := Professions.xp("fishing")
	meer_logic.call("record_catch", "meer_baars", false)
	check(Professions.xp("fishing") == previous + 8, "Existing fishing catch path also awards profession XP")
	key_event(KEY_C)
	await frames(3)
	check(world.crafting_ui.active and paused and gs.ui_owners.has("crafting"), "C opens professions and safely pauses the world")
	var panel: Control = world.crafting_ui.panel
	var view := Rect2(Vector2.ZERO, Vector2(1152, 648))
	print("  UI bounds: ", panel.get_global_rect())
	check(view.encloses(panel.get_global_rect()), "Profession panel fits inside the 1152×648 viewport")
	check(root.gui_get_focus_owner() is Button, "A recipe receives keyboard/controller focus")
	gs.give("prof_branch", 4, true)
	gs.give("prof_stone", 4, true)
	key_event(KEY_E)
	await frames(3)
	check(gs.count("prof_axe") == 1, "E crafts the focused starter axe once")
	world.crafting_ui.selected_skill = "smithing"
	world.crafting_ui._populate()
	await frames(6)
	var focused: Control = root.gui_get_focus_owner()
	check(world.crafting_ui.scroll.get_global_rect().encloses(focused.get_global_rect()), "Filtering keeps the focused recipe completely visible")
	key_event(KEY_C)
	await frames(3)
	check(not world.crafting_ui.active and not paused, "C closes professions and releases only its pause owner")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_RIGHT_STICK
	joy.pressed = true
	Input.parse_input_event(joy)
	await frames(3)
	check(world.crafting_ui.active, "Right stick opens profession menu on controller")
	joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_RIGHT_STICK
	Input.parse_input_event(joy)
	world.crafting_ui.close()
	world.queue_free()
	await frames(2)


func _validate_resources() -> void:
	var ids := {}
	for map_id: String in Data.RESOURCE_PLACEMENTS:
		var map: Dictionary = Maps.get_map(map_id)
		var rows: Array = map["rows"]
		var start: Array = map["spawns"]["start"]
		var frontier: Array[Vector2i] = [Vector2i(start[0], start[1])]
		var seen := {frontier[0]: true}
		var cursor := 0
		while cursor < frontier.size():
			var current := frontier[cursor]
			cursor += 1
			for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := current + dir
				if next.y < 0 or next.y >= rows.size() or next.x < 0 or next.x >= str(rows[next.y]).length() or seen.has(next):
					continue
				if Tiles.is_solid_char(str(rows[next.y])[next.x]):
					continue
				seen[next] = true
				frontier.append(next)
		for obj: Dictionary in Data.resource_objects(map_id):
			var pos := Vector2i(obj["pos"][0], obj["pos"][1])
			check(not ids.has(obj["id"]), "Stable unique node id: " + obj["id"])
			ids[obj["id"]] = true
			check(seen.has(pos), "Node is on reachable open ground: " + obj["id"])
			for existing: Dictionary in map["objects"]:
				if existing["type"] == "portal":
					var p: Array = existing["pos"]
					var size: Array = existing.get("size", [1, 1])
					check(not Rect2i(p[0], p[1], size[0], size[1]).has_point(pos), "Node clears portal: " + obj["id"])
