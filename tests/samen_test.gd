extends SceneTree
## Samenhang tussen de uitbreidingen (boog, vijanden, Zilvermeer, Diepte, wereld en arena): dingen die geen enkele
## losse test ziet, omdat ze pas bestaan als alles samen in het spel zit.
##
##   sh tools/run_tests.sh /pad/naar/godot      (of: godot --headless --fixed-fps 60 --path . -s tests/samen_test.gd)

const Maps := preload("res://scripts/maps/registry.gd")
const Items := preload("res://scripts/data/items.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const Content := preload("res://scripts/data/content.gd")

## Base-voorwaarden (zie game_state.gd check()); die van de uitbreidingen komen uit Content.condition_names().
const BASE_CONDITIONS := ["flag", "no_flag", "quest", "step", "has", "lacks", "coins", "map", "weapon", "crystals", "hurt"]

## Kisten en unieke voorwerpen uit de kaarten van vóór de uitbreidingen: [kaart, plek in de lijst, soort, tegel].
## De opslag onthoudt ze als "soort:kaart:plek", dus deze plekken mogen nooit verschuiven (anders gaan geopende
## kisten in oude opslagen weer dicht). Nieuwe objecten horen daarom achteraan de lijst.
const OLD_KEYS := [
	["inn", 4, "chest", [12, 7]],
	["forest", 4, "chest", [10, 4]],
	["forest", 6, "chest", [31, 30]],
	["forest", 7, "pickup", [41, 4]],
	["forest", 47, "pickup", [20, 28]],
	["ruins", 18, "chest", [10, 4]],
	["ruins", 19, "chest", [29, 29]],
	["ruins", 20, "pickup", [36, 5]],
	["cave", 19, "chest", [5, 5]],
	["cave", 20, "chest", [43, 3]],
	["cave", 21, "pickup", [41, 30]],
	["cave", 47, "pickup", [24, 10]],
]

var failures := 0
var gs: Node
var world: Node2D


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func test_old_save_keys() -> void:
	print("Oude opslagen")
	for entry: Array in OLD_KEYS:
		var objects: Array = Maps.get_map(entry[0])["objects"]
		var obj: Dictionary = objects[entry[1]] if entry[1] < objects.size() else {}
		check(obj.get("type", "") == entry[2] and obj.get("pos", []) == entry[3],
			"%s:%s:%d staat nog op dezelfde plek in de lijst" % [entry[2], entry[0], entry[1]])


func test_achievements() -> void:
	print("Prestaties van alle uitbreidingen")
	var Achievements: GDScript = load("res://scripts/data/achievements.gd")
	var known: Array = BASE_CONDITIONS + Content.condition_names()
	var bad: Array = []
	for id: String in Achievements.ACHIEVEMENTS:
		var info: Dictionary = Achievements.ACHIEVEMENTS[id]
		if str(info.get("name", "")) == "" or str(info.get("desc", "")) == "" or info.get("if", []).is_empty():
			bad.append(id)
			continue
		for cond: Array in info["if"]:
			if not (cond[0] in known):
				bad.append("%s (%s)" % [id, cond[0]])
			elif cond[0] in ["quest", "step"] and not load("res://scripts/data/quests.gd").QUESTS.has(cond[1]):
				bad.append("%s (opdracht %s)" % [id, cond[1]])
			elif cond[0] in ["has", "lacks"] and not Items.ITEMS.has(cond[1]):
				bad.append("%s (voorwerp %s)" % [id, cond[1]])
	check(bad.is_empty(), "elke prestatie heeft een naam, uitleg en bestaande voorwerpen, opdrachten en voorwaarden %s" % [bad])
	for id: String in ["boog_schietbaan", "vijanden_magier", "meer_karper", "diepte_wachter"]:
		check(Achievements.ACHIEVEMENTS.has(id), "prestatie %s van een uitbreiding staat in de lijst" % id)
	var Boeken: GDScript = load("res://scripts/data/ext/meer_boeken.gd")
	check(Boeken.TEXTS.size() == 6, "'Kenner van Azura' vraagt om 6 boeken en de bibliotheek heeft er 6")


func test_bestiary() -> void:
	print("Beestenboek en arena")
	var missing: Array = []
	for kind: String in Enemies.ENEMIES:
		if str(Enemies.ENEMIES[kind].get("desc", "")) == "":
			missing.append(kind)
	check(missing.is_empty(), "elke soort vijand heeft een beschrijving voor het beestenboek %s" % [missing])
	var Arena: GDScript = load("res://scripts/data/arena.gd")
	var wrong: Array = []
	for rank: String in Arena.RANKS:
		for wave: Array in Arena.RANKS[rank]["rounds"]:
			for group: Array in wave:
				var data: Dictionary = Enemies.ENEMIES.get(group[0], {})
				if data.is_empty() or not (data.has("cell") and data.has("scale") and data.has("radius")):
					wrong.append(group[0])
	check(wrong.is_empty(), "alle vijanden in de arenarondes bestaan en hebben een maat %s" % [wrong])


func test_save_roundtrip() -> void:
	print("Opslaan en laden met alles erop en eraan")
	gs.new_game()
	gs.give("bow", 1, true)
	gs.give("arrow", 17, true)
	gs.give("fishing_rod", 1, true)
	gs.give("meer_baars", 2, true)
	gs.give("heart_container", 5, true)
	gs.meer["gevangen"] = 7
	gs.arena_records = {"bronze": 81.5}
	gs.kills_by = {"mage": 3, "slime_spitter": 2}
	gs.kills = 5
	gs.ng_plus = 1
	gs.set_flag("boog_bos_a")
	gs.day_time = 0.75
	check(gs.count("heart_container") == 3 and gs.max_hp() == 8, "meer dan 3 hartcontainers past niet (8 hartjes)")
	check(gs.save_game(Vector2(100, 100)), "opslaan lukt")
	gs.new_game()
	check(gs.count("bow") == 0 and gs.arena_records.is_empty() and gs.meer.is_empty() and gs.ng_plus == 0, "een nieuw spel begint leeg")
	check(gs.load_game(), "laden lukt")
	check(gs.count("bow") == 1 and gs.count("arrow") == 17 and gs.count("meer_baars") == 2, "boog, pijlen en vis komen terug")
	check(int(gs.meer.get("gevangen", 0)) == 7 and is_equal_approx(float(gs.arena_records.get("bronze", 0.0)), 81.5), "visstand en arenarecord komen terug")
	check(int(gs.kills_by.get("mage", 0)) == 3 and gs.ng_plus == 1 and gs.flag("boog_bos_a"), "beestenboek, Nieuw spel+ en vlaggen komen terug")
	check(is_equal_approx(gs.day_time, 0.75), "de klok komt terug")

	# Een opslag van vóór de uitbreidingen (alleen de oude velden).
	var old := {
		"version": 1, "map": "forest", "pos": [320, 320], "hp": 4, "coins": 33,
		"inventory": {"potion": 1, "ruin_key": 1}, "flags": {"met_greta": true}, "quests": {"main": {"state": "active", "step": 0}},
		"weapon": "iron", "play_time": 600.0, "kills": 12,
	}
	var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(gs.load_game(), "een oude opslag laadt")
	check(gs.map_id == "forest" and gs.coins == 33 and gs.weapon == "iron" and gs.count("ruin_key") == 1, "de oude gegevens kloppen")
	check(gs.arena_records.is_empty() and gs.meer.is_empty() and gs.kills_by.is_empty() and gs.ng_plus == 0, "nieuwe velden krijgen hun standaardwaarde")


func test_text_tokens() -> void:
	print("Tekens in teksten")
	gs.new_game()
	gs.give("meer_boek_eiland", 1, true)
	check(gs.fmt("{boeken}/3") == "1/3", "{boeken} van het Zilvermeer (%s)" % gs.fmt("{boeken}/3"))
	check(gs.fmt("{arena_title}") == "nieuwkomer", "{arena_title} van de arena (%s)" % gs.fmt("{arena_title}"))
	check(gs.fmt("{coins} munten, {onbekend}") == "0 munten, {onbekend}", "gewone en onbekende tekens")


func test_fast_travel_in_arena() -> void:
	print("Snel reizen tijdens een arenagevecht")
	var FastTravel: GDScript = load("res://scripts/core/fast_travel.gd")
	var Arena: GDScript = load("res://scripts/data/arena.gd")
	gs.new_game()
	gs.in_game = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)
	Arena.run_active = true
	check("arena" in FastTravel.blocked_reason(world), "tijdens een toernooi kun je niet reizen (%s)" % FastTravel.blocked_reason(world))
	Arena.run_active = false
	check(not ("arena" in FastTravel.blocked_reason(world)), "daarna weer wel")
	check(Maps.get_map("lake").get("outdoor", false) and Maps.get_map("lake").has("weather"), "het Zilvermeer volgt dag, nacht en weer")


func _run() -> void:
	gs = root.get_node("GameState")
	var save_path := ProjectSettings.globalize_path(gs.SAVE_PATH)
	var backup := ""
	if FileAccess.file_exists(gs.SAVE_PATH):
		backup = FileAccess.get_file_as_string(gs.SAVE_PATH)
	test_old_save_keys()
	test_achievements()
	test_bestiary()
	test_save_roundtrip()
	test_text_tokens()
	await test_fast_travel_in_arena()
	if backup != "":
		var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
		file.store_string(backup)
	else:
		DirAccess.remove_absolute(save_path)
	print("")
	if failures == 0:
		print("SAMEN TEST OK")
		quit(0)
	else:
		print("SAMEN TEST: %d fout(en)" % failures)
		quit(1)
