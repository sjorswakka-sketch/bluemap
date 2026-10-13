extends SceneTree
## Held-XP: echte beloningen, levelmunten, opslagmigratie en Nieuw spel+.
## Draai via tools/run_tests.py: deze test schrijft uitsluitend in een geïsoleerde testopslag.

const Progression := preload("res://scripts/core/progression.gd")
const Professions := preload("res://scripts/core/professions.gd")

class FakeWorld extends Node2D:
	func burst(_pos: Vector2, _color: Color, _amount: int) -> void:
		pass
	func damage_number(_pos: Vector2, _text: String, _color: Color) -> void:
		pass
	func hitstop(_duration: float) -> void:
		pass
	func spawn_pickup(_kind: String, _pos: Vector2, _flag: String, _tossed: bool) -> void:
		pass

var failures := 0
var gs: Node
var changes := 0
var messages: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("  ok   " if ok else "  FAIL ", label)
	if not ok:
		failures += 1


func _on_progression() -> void:
	changes += 1


func _on_toast(message: String) -> void:
	messages.append(message)


func _retry_completion(_message: String) -> void:
	gs.finish_quest("main")


func _run() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):
		push_error("Use tools/run_tests.py for an isolated save directory")
		quit(1)
		return
	gs = root.get_node("GameState")
	gs.in_game = false
	gs.progression_changed.connect(_on_progression)
	gs.toast.connect(_on_toast)
	_test_levels()
	_test_quests()
	await _test_kills()
	_test_profession_signal()
	_test_persistence()
	_test_new_game_plus()
	print("PROGRESSION OK" if failures == 0 else "PROGRESSION FAILED: %d" % failures)
	quit(1 if failures else 0)


func _test_levels() -> void:
	gs.new_game()
	var previous_flags: Dictionary = gs.flags.duplicate(true)
	check(Progression.state() == gs and Progression.xp() == 0 and Progression.level() == 1, "A new hero starts at level one with zero XP")
	check(Progression.progress() == {"level": 1, "xp": 0, "current": 0, "needed": 50, "max_level": false, "next_reward": 15}, "Progress reports the next threshold and upgrade coin reward")
	for raw: Variant in [null, "100", true, [], {}, NAN, INF, -INF, -2]:
		check(Progression.normalize(raw) == 0, "Invalid XP defaults safely: " + str(raw))
	check(Progression.normalize(24.9) == 24 and Progression.normalize(1.0e100) == 2250, "Fractional and huge saved XP normalize without overflow")
	var previous_damage: int = gs.damage()
	var previous_reach: float = gs.reach()
	var previous_speed: float = gs.speed_multiplier()
	changes = 0
	messages.clear()
	gs.add_hero_xp(-5)
	gs.add_hero_xp(0)
	check(changes == 0 and gs.hero_xp == 0 and gs.coins == 0, "Nonpositive rewards do nothing")
	gs.add_hero_xp(49)
	check(changes == 1 and gs.coins == 0 and messages.is_empty() and Progression.level() == 1, "XP below a threshold refreshes progress without a level reward")
	gs.add_hero_xp(1)
	check(changes == 2 and gs.coins == 15 and messages.size() == 1 and Progression.level() == 2, "Crossing a threshold awards exactly fifteen coins and one toast")
	check(Progression.progress()["current"] == 0 and Progression.progress()["needed"] == 100, "Level two displays progress within its own XP span")
	gs.add_hero_xp(250)
	check(gs.coins == 45 and Progression.level() == 4 and messages.size() == 2, "A multi-level gain pays each crossed level once")
	gs.add_hero_xp(9223372036854775807)
	check(Progression.xp() == 2250 and gs.coins == 135 and Progression.level() == 10, "Huge rewards clamp at level ten without overflow")
	var capped_changes := changes
	gs.add_hero_xp(500)
	check(changes == capped_changes and gs.coins == 135 and Progression.progress()["max_level"] and Progression.progress()["needed"] == 0 and Progression.progress()["next_reward"] == 0, "The level cap grants no repeat reward or invalid next-level progress")
	check(gs.damage() == previous_damage and gs.reach() == previous_reach and gs.speed_multiplier() == previous_speed and gs.max_hp() == gs.BASE_HP and gs.weapon == "wood" and gs.flags == previous_flags, "Hero levels preserve combat stats and all existing upgrade gates")


func _test_quests() -> void:
	gs.new_game()
	gs.finish_quest("kat")
	check(gs.hero_xp == 0, "An unstarted quest cannot award XP")
	gs.start_quest("kat")
	gs.finish_quest("kat")
	gs.finish_quest("kat")
	check(gs.hero_xp == 40 and gs.coins == 0, "A completed side quest awards forty XP exactly once")
	gs.start_quest("main")
	gs.toast.connect(_retry_completion)
	gs.finish_quest("main")
	gs.toast.disconnect(_retry_completion)
	check(gs.hero_xp == 140 and gs.coins == 15 and gs.quest_state("main") == "done", "Main quest completion grants one hundred XP even with a reentrant listener")
	gs.start_quest("diepte")
	gs.finish_quest("diepte")
	check(gs.hero_xp == 240, "The depths finale also awards one hundred XP")
	gs.start_quest("unknown_test_quest")
	gs.finish_quest("unknown_test_quest")
	check(gs.hero_xp == 240, "Unknown quest identifiers do not manufacture XP")


func _test_kills() -> void:
	gs.new_game()
	gs.map_id = "forest"
	var world := FakeWorld.new()
	root.add_child(world)
	var enemy_script: Script = load("res://scripts/entities/enemy.gd")
	var enemy: Node2D = enemy_script.new()
	enemy.world = world
	enemy.setup("slime")
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.hurt(1, Vector2.RIGHT)
	check(gs.hero_xp == 0 and gs.kills == 0, "Hitting a living enemy awards no XP")
	enemy.hurt(2, Vector2.RIGHT)
	enemy.hurt(100, Vector2.RIGHT)
	check(gs.hero_xp == 5 and gs.kills == 1, "Actual death grants XP once, including repeated hits in the same frame")
	await process_frame
	var removed: Node2D = enemy_script.new()
	removed.world = world
	removed.setup("bat")
	world.add_child(removed)
	removed.set_physics_process(false)
	removed.queue_free()
	await process_frame
	check(gs.hero_xp == 5 and gs.kills == 1, "Removing an enemy during a map cleanup is not a kill reward")
	gs.register_kill("slime_mini")
	check(gs.hero_xp == 5 and gs.kills == 2, "Summoned minis still count for the bestiary but cannot farm XP")
	gs.map_id = "arena"
	var arena_enemy: Node2D = enemy_script.new()
	arena_enemy.world = world
	arena_enemy.setup("slime_red")
	arena_enemy.data = arena_enemy.data.duplicate(true)
	arena_enemy.data["drops"] = []
	world.add_child(arena_enemy)
	arena_enemy.set_physics_process(false)
	arena_enemy.hurt(100, Vector2.RIGHT)
	check(gs.hero_xp == 5 and gs.coins == 0 and gs.kills == 3, "Arena deaths retain kill counts without adding loot-economy XP rewards")
	gs.map_id = "depths2"
	gs.register_kill("guardian")
	check(gs.hero_xp == 205 and gs.coins == 30, "The guardian's normal death hook grants the boss reward")
	gs.register_kill("future_kind")
	check(gs.hero_xp == 210, "A future enemy kind has a small safe default reward")
	world.queue_free()
	await process_frame


func _test_profession_signal() -> void:
	gs.new_game()
	changes = 0
	Professions.add_xp("mining", 5)
	check(changes == 1 and gs.hero_xp == 0, "Profession XP refreshes progression UI without granting hero XP")
	Professions.add_xp("mining", 25)
	check(changes == 2 and Professions.level("mining") == 2, "Profession level-up emits one immediate progression change")
	Professions.add_xp("unknown", 5)
	Professions.add_xp("mining", 0)
	check(changes == 2, "Invalid or empty profession awards emit no progress change")


func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _test_persistence() -> void:
	gs.new_game()
	gs.add_hero_xp(155)
	gs.start_quest("kat")
	gs.finish_quest("kat")
	check(gs.save_game(Vector2(100, 100)), "Hero progress saves through the existing save path")
	gs.hero_xp = 0
	gs.coins = 0
	messages.clear()
	check(gs.load_game() and gs.hero_xp == 195 and gs.coins == 30 and messages.is_empty(), "Loading preserves XP and coins without replaying level rewards")
	gs.finish_quest("kat")
	check(gs.hero_xp == 195 and gs.coins == 30, "Reloading a completed quest cannot grant its XP again")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH))
	data.erase("hero_xp")
	_write_save(data)
	check(gs.load_game() and gs.hero_xp == 0 and Progression.level() == 1 and gs.coins == 30, "An actual pre-XP save loads with zero XP and keeps its money")
	for raw: Variant in ["bad", -50, {"xp": 12}, 1.0e100]:
		data["hero_xp"] = raw
		_write_save(data)
		check(gs.load_game() and gs.hero_xp == Progression.normalize(raw) and gs.coins == 30, "Saved XP is sanitized with no automatic coin reward: " + str(raw))
	gs.new_game()
	check(gs.hero_xp == 0 and gs.coins == 0 and Progression.level() == 1, "A normal new game resets hero progress")


func _test_new_game_plus() -> void:
	if FileAccess.file_exists(gs.NG_META_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.NG_META_PATH))
	gs.new_game()
	gs.add_hero_xp(175)
	gs.set_flag("game_completed")
	gs.record_completion()
	check(gs.load_meta()["hero_xp"] == 175, "Completion metadata stores hero XP for New Game+")
	gs.new_game()
	messages.clear()
	check(gs.new_game_plus() and gs.hero_xp == 175 and Progression.level() == 3 and gs.coins == gs.NG_START_COINS and messages.is_empty(), "New Game+ preserves level and partial XP without repeating coin rewards")
	gs.add_hero_xp(125)
	check(Progression.level() == 4 and gs.coins == gs.NG_START_COINS + 15, "Only the next newly reached level grants coins in New Game+")
	gs.set_flag("game_completed")
	gs.save_game(Vector2.ZERO)
	check(gs.load_meta()["hero_xp"] == 300, "Saving after completion preserves subsequent XP for future rounds")
	gs.new_game()
	gs.set_flag("game_completed")
	gs.record_completion()
	check(gs.load_meta()["hero_xp"] == 300, "A less advanced completed save cannot reduce stored hero XP")
	var old_meta := {"completed": true, "rounds": 1, "weapon": "wood", "hearts": 0, "boots": false}
	gs.save_meta(old_meta)
	check(gs.new_game_plus() and gs.hero_xp == 0 and gs.coins == gs.NG_START_COINS, "Metadata from before hero XP still starts New Game+ safely")
	var config := ConfigFile.new()
	config.set_value("ng", "completed", true)
	config.set_value("ng", "hero_xp", INF)
	config.save(gs.NG_META_PATH)
	check(gs.new_game_plus() and gs.hero_xp == 0, "Non-finite XP in metadata also defaults safely")
