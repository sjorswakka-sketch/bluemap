extends SceneTree
## Test van de wereld-uitbreiding: dag en nacht, weer, slapen, snel reizen, prestaties, beestenboek en het menu.
##
##   godot --headless --fixed-fps 60 --path . -s tests/wereld_test.gd

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const Items := preload("res://scripts/data/items.gd")
const Npcs := preload("res://scripts/data/npcs.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Dialogue := preload("res://scripts/data/dialogue.gd")
const Content := preload("res://scripts/data/content.gd")
const Achievements := preload("res://scripts/data/achievements.gd")
const Daynight := preload("res://scripts/core/daynight.gd")
const RainScript := preload("res://scripts/entities/rain.gd")

## Voorwaarden die al in game_state.gd staan (de rest komt uit de modules).
const BASE_CONDITIONS := ["flag", "no_flag", "quest", "step", "has", "lacks", "coins", "map", "weapon", "crystals", "hurt"]
const BASE_MAP_IDS := ["village", "smithy", "shop", "inn", "forest", "ruins", "cave", "temple"]
const BASE_KINDS := ["slime", "slime_blue", "slime_red", "slime_mini", "bat", "skeleton", "golem", "king"]

## Deze twee scripts gebruiken GameState en worden dus pas geladen als het spel draait (bij het starten van deze test
## bestaan de autoloads nog niet).
var FastTravel: GDScript
var MenuPages: GDScript
var failures := 0
var gs: Node
var sound: Node
var world: Node2D
var user_backup := {} # opslag en prestaties van de echte speler, voor het geval deze test niet via run_tests.sh draait


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures += 1


func press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	root.push_input(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	root.push_input(up)


## Een knop van de controller indrukken (bijvoorbeeld de schouderknoppen).
func press_pad(button: int) -> void:
	var down := InputEventJoypadButton.new()
	down.button_index = button
	down.pressed = true
	root.push_input(down)
	var up := InputEventJoypadButton.new()
	up.button_index = button
	up.pressed = false
	root.push_input(up)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func tile_pos(x: int, y: int) -> Vector2:
	return Vector2(x * 32 + 16, y * 32 + 16)


func near(a: float, b: float, margin := 0.001) -> bool:
	return absf(a - b) <= margin


## Deze test schrijft in de opslag en in user://meta.cfg. Draait hij niet in de testmap van run_tests.sh, dan zetten we
## de bestanden van de echte speler eerst opzij en aan het eind terug.
func back_up_user_files() -> void:
	for path: String in [gs.SAVE_PATH, gs.META_PATH]:
		if FileAccess.file_exists(path):
			user_backup[path] = FileAccess.get_file_as_bytes(path)


func restore_user_files() -> void:
	for path: String in [gs.SAVE_PATH, gs.META_PATH]:
		if user_backup.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(user_backup[path])
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func start_world() -> void:
	gs.new_game()
	gs.in_game = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)


func stop_world() -> void:
	if is_instance_valid(world):
		world.queue_free()
	await frames(3)
	gs.new_game()


## Een nieuw, schoon spel zonder bewaarde prestaties.
func fresh_game() -> void:
	gs.meta_achievements = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.META_PATH))
	gs.new_game()
	gs.in_game = true


func entities_with(script_name: String) -> Array:
	var found: Array = []
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with(script_name):
			found.append(child)
	return found


func load_map(map_id: String, spawn := "start") -> void:
	world.load_map(map_id, spawn)
	await frames(4)


func talk(talk_id: String, picks: Array = []) -> void:
	gs.start_dialogue(talk_id)
	await frames(2)
	await finish_dialogue(picks)


## Klikt een open gesprek door; bij keuzes de gekozen knop (standaard de laatste).
func finish_dialogue(picks: Array = []) -> void:
	var index := 0
	var guard := 0
	while world.dialogue.active and guard < 300:
		guard += 1
		if not world.dialogue.buttons.is_empty():
			var choice: int = picks[index] if index < picks.size() else world.dialogue.buttons.size() - 1
			index += 1
			world.dialogue.buttons[mini(choice, world.dialogue.buttons.size() - 1)].pressed.emit()
		else:
			press("interact")
		await frames(2)


## Wacht tot de grote naam van de kaart weer weg is (pas daarna komen de meldingen van prestaties).
func wait_for_map_name() -> void:
	var guard := 0
	while world.hud.banner_time > 0.0 and guard < 400:
		guard += 1
		await process_frame
	await frames(3)


func read_save() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# --- De klok ------------------------------------------------------------------------------------

func test_clock_rules() -> void:
	print("Klok en kleuren van de dag")
	check(near(Daynight.wrap_time(1.25), 0.25) and near(Daynight.wrap_time(-0.1), 0.9), "tijd loopt rond (1.25 -> 0.25, -0.1 -> 0.9)")
	var dawn := Daynight.tint_at(0.0)
	var wrapped := Daynight.tint_at(1.0)
	check(dawn.is_equal_approx(wrapped) and near(Daynight.night_at(0.0), Daynight.night_at(1.0)), "de dag sluit netjes aan: begin en einde zijn gelijk")
	var day := Daynight.tint_at(0.3)
	check(day.is_equal_approx(Color.WHITE) and Daynight.night_at(0.3) == 0.0, "overdag is alles neutraal (wit) en is er geen kunstlicht nodig")
	var morning := Daynight.tint_at(0.07)
	check(morning.r > morning.b and morning.r >= 0.99, "ochtend is warm (meer rood dan blauw)")
	var evening := Daynight.tint_at(0.6)
	check(evening.r > evening.b + 0.2 and evening.g < 0.9, "avond is oranje")
	var night := Daynight.tint_at(0.8)
	var brightness := night.r * 0.3 + night.g * 0.59 + night.b * 0.11
	check(night.b > night.r + 0.25 and night.b > night.g, "nacht is blauw")
	check(brightness > 0.28 and brightness < 0.5, "nacht is donker maar goed speelbaar (helderheid %.2f)" % brightness)
	check(Daynight.night_at(0.8) == 1.0 and Daynight.night_at(0.6) > 0.0 and Daynight.night_at(0.6) < 0.5, "kunstlicht: volop 's nachts, een beetje 's avonds")
	# Vloeiend: geen sprongen tussen twee stapjes, en het kunstlicht neemt toe in de avond.
	var smooth := true
	var previous := Daynight.tint_at(0.0)
	var rising := true
	var last_need := Daynight.night_at(0.52)
	for i in range(1, 1001):
		var t := float(i) / 1000.0
		var tint := Daynight.tint_at(t)
		if absf(tint.r - previous.r) > 0.03 or absf(tint.g - previous.g) > 0.03 or absf(tint.b - previous.b) > 0.03:
			smooth = false
		previous = tint
		if t >= 0.52 and t <= 0.76:
			if Daynight.night_at(t) < last_need - 0.0001:
				rising = false
			last_need = Daynight.night_at(t)
	check(smooth, "de kleur verspringt nergens (stapjes van een duizendste)")
	check(rising, "tussen 0.52 en 0.76 wordt het alleen maar donkerder")
	check(Daynight.phase_at(0.0) == "ochtend" and Daynight.phase_at(0.3) == "dag" and Daynight.phase_at(0.6) == "avond" and Daynight.phase_at(0.8) == "nacht" and Daynight.phase_at(0.97) == "ochtend", "dagdelen op vaste tijdstippen")
	check(Daynight.phase_at(1.3) == "dag" and Daynight.phase_at(-0.1) == "nacht", "dagdelen kloppen ook buiten 0..1")
	var edges := [[0.169, "ochtend"], [0.17, "dag"], [0.519, "dag"], [0.52, "avond"], [0.719, "avond"], [0.72, "nacht"], [0.949, "nacht"], [0.95, "ochtend"]]
	var edges_ok := true
	for edge: Array in edges:
		if Daynight.phase_at(edge[0]) != edge[1]:
			edges_ok = false
			print("       op ", edge[0], " is het ", Daynight.phase_at(edge[0]), " in plaats van ", edge[1])
	check(edges_ok, "de grenzen tussen de dagdelen liggen op 0.17, 0.52, 0.72 en 0.95")
	check(Daynight.icon_frame(0.3) == 0 and Daynight.icon_frame(0.6) == 1 and Daynight.icon_frame(0.05) == 1 and Daynight.icon_frame(0.8) == 2, "zon, lage zon en maan")
	check(Daynight.phase_label(0.8) == "Nacht" and Daynight.phase_label(0.3) == "Dag", "namen voor in beeld")
	check(Daynight.MORNING > 0.0 and Daynight.phase_at(Daynight.MORNING) == "ochtend" and Daynight.phase_at(Daynight.START) == "ochtend", "een nieuw spel en wakker worden beginnen 's ochtends")


func test_clock_in_game_state() -> void:
	print("De klok in het spel")
	gs.new_game()
	gs.in_game = true
	check(near(gs.day_time, Daynight.START) and gs.day_count == 0, "een nieuw spel begint in de ochtend")
	var play_before: float = gs.play_time
	gs._process(10.0)
	check(near(gs.day_time, Daynight.START + 10.0 / Daynight.DAY_LENGTH, 0.0001) and near(gs.play_time - play_before, 10.0), "de klok loopt mee met de speeltijd")
	gs.day_time = Daynight.START
	gs._process(Daynight.DAY_LENGTH)
	check(near(gs.day_time, Daynight.START, 0.0001) and gs.day_count == 1, "na een hele dag (%d seconden) begint de volgende" % int(Daynight.DAY_LENGTH))
	gs.day_time = 0.99
	gs._process(Daynight.DAY_LENGTH * 0.02)
	check(gs.day_time < 0.02 and gs.day_count == 2, "over middernacht heen: de tijd begint opnieuw")
	var frozen: float = gs.day_time
	gs.ended = true
	gs._process(5.0)
	check(gs.day_time == frozen, "na game over staat de klok stil")
	gs.ended = false
	paused = true
	gs._process(5.0)
	paused = false
	check(gs.day_time == frozen, "in een menu of gesprek (spel gepauzeerd) staat de klok stil")
	gs.in_game = false
	gs._process(5.0)
	check(gs.day_time == frozen, "buiten het spel (titelscherm) loopt de klok niet")
	gs.in_game = true
	gs.day_time = 0.5
	gs.skip_to_morning()
	check(near(gs.day_time, Daynight.MORNING) and gs.day_count == 3, "naar de ochtend: de volgende dag begint")
	gs.day_time = 0.02
	gs.skip_to_morning()
	check(near(gs.day_time, Daynight.MORNING) and gs.day_count == 3, "slapen vlak voor zonsopgang telt niet als een nieuwe dag")
	gs.new_game()
	check(near(gs.day_time, Daynight.START) and gs.day_count == 0, "een nieuw spel zet de klok terug")


func test_weather_rules() -> void:
	print("Weerregels")
	check(Daynight.raining("rain", 0, 0.3) and Daynight.raining("rain", 5, 0.9), "\"rain\": het regent altijd")
	check(not Daynight.raining("", 3, 0.4) and not Daynight.raining("zon", 3, 0.4), "zonder weer (of een onbekend woord) is het droog")
	check(not Daynight.raining("random", 0, 0.05), "de eerste minuten van een nieuw spel zijn droog")
	var rainy := 0
	var total := 0
	var runs := 0
	var previous := false
	var consistent := true
	for day in 200:
		for slot in Daynight.WEATHER_SLOTS:
			var t := (float(slot) + 0.5) / float(Daynight.WEATHER_SLOTS)
			var now := Daynight.raining("random", day, t)
			if now != Daynight.raining("random", day, t):
				consistent = false
			total += 1
			if now:
				rainy += 1
			if now != previous:
				runs += 1
			previous = now
	var share := float(rainy) / float(total)
	check(consistent, "hetzelfde moment geeft altijd hetzelfde weer")
	check(share > 0.2 and share < 0.45, "ongeveer een derde van de tijd regen (%.0f%%)" % (share * 100.0))
	check(runs > 100, "het weer wisselt vaak genoeg (%d wisselingen in 200 dagen)" % runs)
	var vary := false
	for day in range(1, 30):
		if Daynight.raining("random", day, 0.3) != Daynight.raining("random", 1, 0.3):
			vary = true
	check(vary, "elke dag heeft zijn eigen weer")
	check(Daynight.rain_tint(0.0).is_equal_approx(Color.WHITE) and Daynight.rain_tint(1.0).r < 0.9 and Daynight.rain_tint(5.0).is_equal_approx(Daynight.rain_tint(1.0)), "regen maakt het donkerder en grijzer (en kent een maximum)")


# --- Gegevens ------------------------------------------------------------------------------------

func test_data() -> void:
	print("Gegevens van de wereld-uitbreiding")
	var outdoor_ok := true
	var weather_ok := true
	for map_id: String in Maps.MAPS:
		var def: Dictionary = Maps.get_map(map_id)
		if map_id in BASE_MAP_IDS and def.get("weather", "") not in ["", "rain", "random"]:
			weather_ok = false
		if typeof(def.get("weather", "")) != TYPE_STRING or typeof(def.get("outdoor", false)) != TYPE_BOOL:
			weather_ok = false
		if def.get("outdoor", false) != (map_id in ["village", "forest"]) and map_id in BASE_MAP_IDS:
			outdoor_ok = false
	check(outdoor_ok, "dorp en bos zijn buitenkaarten, de rest niet")
	check(weather_ok, "de weer-sleutels van kaarten hebben het goede soort waarde (en de basiskaarten een bekend soort weer)")
	check(Maps.get_map("village").get("weather", "") == "random" and Maps.get_map("forest").get("weather", "") == "random", "dorp en bos hebben wisselend weer")
	var sounds_ok := true
	for sound_name in ["wereld_regen", "wereld_slapen", "wereld_prestatie", "wereld_reis", "wereld_altaar"]:
		if not sound.streams.has(sound_name):
			sounds_ok = false
			print("       geluid ontbreekt: ", sound_name)
	check(sounds_ok, "alle nieuwe geluiden zijn geladen")
	var types := Content.object_types()
	check(types.has("wereld_bed") and types.has("wereld_lantaarn") and types["wereld_bed"] is Script and types["wereld_lantaarn"] is Script, "bed en lantaarn zijn als objectsoort aangemeld (en geladen)")
	check("wereld_sleep" in Content.action_names() and "kills" in Content.condition_names() and "any" in Content.condition_names(), "nieuwe acties en voorwaarden zijn aangemeld")
	var mila_links := false
	for choice: Dictionary in Dialogue.TALKS["mila_menu"]["choices"]:
		if choice.get("next", "") == "wereld_bed_info":
			mila_links = true
	check(mila_links and Dialogue.TALKS.has("wereld_bed") and Dialogue.TALKS.has("wereld_bed_menu") and Dialogue.TALKS.has("wereld_bed_poor"), "Mila vertelt over de bedden en de gesprekken bestaan")
	var beds: Array = []
	var lanterns: Array = []
	for obj: Dictionary in Maps.get_map("inn")["objects"]:
		if obj["type"] == "wereld_bed":
			beds.append(obj)
	for obj: Dictionary in Maps.get_map("village")["objects"]:
		if obj["type"] == "wereld_lantaarn":
			lanterns.append(obj)
	var beds_on_beds := not beds.is_empty()
	for obj: Dictionary in beds:
		var row: String = Maps.get_map("inn")["rows"][obj["pos"][1]]
		if Tiles.CHARS.get(row[obj["pos"][0]], "") != "bed":
			beds_on_beds = false
	check(beds_on_beds and beds.size() == 3, "de drie bedden in de herberg staan op een bedtegel")
	var lanterns_ok := lanterns.size() >= 6
	var seen := {}
	for obj: Dictionary in lanterns:
		var tile := Vector2i(int(obj["pos"][0]), int(obj["pos"][1]))
		var row: String = Maps.get_map("village")["rows"][tile.y]
		if Tiles.is_solid_char(row[tile.x]) or seen.has(tile):
			lanterns_ok = false
		seen[tile] = true
	check(lanterns_ok, "de lantaarns in het dorp staan op vrije, verschillende plekken (%d)" % lanterns.size())


func test_achievement_data() -> void:
	print("Gegevens van de prestaties")
	var all: Dictionary = Achievements.ACHIEVEMENTS
	check(all.size() >= 20, "er zijn minstens 20 prestaties (%d)" % all.size())
	var secrets := 0
	var names := {}
	var texts_ok := true
	var conds_ok := true
	for id: String in all:
		var def: Dictionary = all[id]
		if String(def.get("name", "")) == "" or String(def.get("desc", "")) == "" or not def.has("if") or (def["if"] as Array).is_empty():
			texts_ok = false
			print("       onvolledig: ", id)
		if def.get("secret", false):
			secrets += 1
		names[def.get("name", "")] = true
		for cond: Array in def.get("if", []):
			if not (cond[0] in BASE_CONDITIONS or cond[0] in Content.condition_names()):
				conds_ok = false
				print("       onbekende voorwaarde in ", id, ": ", cond)
			elif not _references_exist(cond):
				conds_ok = false
				print("       verwijst naar iets dat niet bestaat in ", id, ": ", cond)
	check(texts_ok, "elke prestatie heeft een naam, uitleg en voorwaarden")
	check(names.size() == all.size(), "alle namen zijn verschillend")
	check(conds_ok, "alle voorwaarden bestaan en verwijzen naar echte voorwerpen, vijanden, personages en kaarten")
	check(secrets >= 1 and secrets < all.size() / 2, "er zijn een paar geheime prestaties (%d)" % secrets)
	for id in ["first_blood", "slayer_50", "slayer_200", "hearts_all", "boots", "crystal_bos", "crystal_ruine", "crystal_grot", "golems", "king", "completed", "speedrun", "flawless_boss", "talked_all", "sidequests", "potions_10", "rolls_50", "fast_travel", "chests_all"]:
		if not all.has(id):
			check(false, "prestatie %s ontbreekt" % id)
	check(Achievements.count_owned({"first_blood": true, "bestaat_niet": true}) == 1, "alleen bekende prestaties worden geteld")
	var wrong := Achievements.info("bestaat_niet")
	check(wrong["name"] == "bestaat_niet" and (wrong["if"] as Array).is_empty(), "een onbekende prestatie geeft geen fout")


func _references_exist(cond: Array) -> bool:
	match cond[0]:
		"has", "lacks":
			return Items.ITEMS.has(cond[1])
		"quest", "step":
			return Quests.QUESTS.has(cond[1])
		"kills_of":
			return Enemies.ENEMIES.has(cond[1])
		"kinds_killed":
			for kind: String in cond[1]:
				if not Enemies.ENEMIES.has(kind):
					return false
		"talked_to_all":
			for npc_id: String in cond[1]:
				if not Npcs.NPCS.has(npc_id):
					return false
		"chests_in":
			for map_id: String in cond[1]:
				if not Maps.MAPS.has(map_id):
					return false
		"any":
			for sub: Array in cond.slice(1):
				if not (sub[0] in BASE_CONDITIONS or sub[0] in Content.condition_names()) or not _references_exist(sub):
					return false
	return true


func test_conditions() -> void:
	print("Nieuwe voorwaarden")
	fresh_game()
	check(not gs.check(["kills", 1]) and not gs.check(["rolls", 1]) and gs.check(["max_deaths", 0]), "een schoon spel: niets behaald, nooit doodgegaan")
	gs.register_kill("slime")
	gs.register_kill("slime")
	gs.register_kill("bat")
	check(gs.check(["kills", 3]) and not gs.check(["kills", 4]) and gs.kills == 3, "kills: minstens zoveel verslagen")
	check(gs.check(["kills_of", "slime", 2]) and not gs.check(["kills_of", "slime", 3]) and gs.check(["kills_of", "bat", 1]) and not gs.check(["kills_of", "golem", 1]), "kills_of: per soort")
	check(gs.check(["kinds_killed", ["slime", "bat"]]) and not gs.check(["kinds_killed", ["slime", "golem"]]) and gs.check(["kinds_killed", []]), "kinds_killed: alle genoemde soorten")
	gs.rolls = 5
	gs.potions_drunk = 2
	check(gs.check(["rolls", 5]) and not gs.check(["rolls", 6]) and gs.check(["potions_drunk", 2]) and not gs.check(["potions_drunk", 3]), "rolls en potions_drunk")
	check(not gs.check(["talked_to_all", ["bram", "greta"]]), "talked_to_all: nog niemand gesproken")
	gs.note_talked("bram")
	gs.note_talked("bram")
	check(not gs.check(["talked_to_all", ["bram", "greta"]]) and gs.check(["talked_to_all", ["bram"]]) and gs.talked.size() == 1, "talked_to_all: een personage telt een keer")
	gs.note_talked("greta")
	check(gs.check(["talked_to_all", ["bram", "greta"]]), "talked_to_all: beide gesproken")
	gs.deaths = 2
	gs.boss_deaths = 1
	check(gs.check(["max_deaths", 2]) and not gs.check(["max_deaths", 1]) and gs.check(["max_boss_deaths", 1]) and not gs.check(["max_boss_deaths", 0]), "max_deaths en max_boss_deaths")
	check(not gs.check(["finished_within", 3600]), "finished_within: nog niet uitgespeeld")
	gs.set_flag("game_completed")
	gs.play_time = 3599.0
	check(gs.check(["finished_within", 3600]), "finished_within: uitgespeeld in 59:59")
	gs.play_time = 3600.5
	check(not gs.check(["finished_within", 3600]), "finished_within: een halve seconde te laat")
	check(not gs.check(["chests_in", ["forest"]]), "chests_in: nog geen kist open")
	gs.set_flag("chest:forest:3")
	gs.set_flag("chest:cave:9")
	check(gs.check(["chests_in", ["forest"]]) and gs.check(["chests_in", ["forest", "cave"]]) and not gs.check(["chests_in", ["forest", "inn"]]), "chests_in: een kist in elk genoemd gebied")
	check(not gs.check(["chests_in", ["fores"]]), "chests_in: een gebied dat hier op lijkt telt niet mee")
	check(gs.check(["any", ["flag", "nee"], ["flag", "chest:forest:3"]]) and not gs.check(["any", ["flag", "nee"], ["flag", "ook_nee"]]) and not gs.check(["any"]), "any: minstens een van de voorwaarden")
	gs.day_time = 0.8
	check(gs.check(["phase", "nacht"]) and not gs.check(["phase", "dag"]), "phase: het is nacht")
	gs.day_time = 0.3
	check(gs.check(["phase", "dag"]) and not gs.check(["phase", "nacht"]), "phase: het is dag")


# --- Dag en nacht in de wereld ---------------------------------------------------------------------

func test_day_night_in_world() -> void:
	print("Dag en nacht in de wereld")
	gs.new_game()
	await load_map("village")
	var atmosphere: Node = world.atmosphere
	atmosphere.weather = "" # de kleur hangt anders af van het weer
	check(atmosphere.outdoor and world.is_outdoor() and world.darkness == 0.0, "het dorp is een buitenkaart")
	gs.day_time = 0.3
	await frames(3)
	check(world.canvas_mod.color.is_equal_approx(Color.WHITE) and world.light_need() == 0.0, "overdag: gewone kleuren en geen kunstlicht")
	gs.day_time = 0.8
	await frames(3)
	check(world.canvas_mod.color.is_equal_approx(Daynight.tint_at(0.8)) and world.light_need() == 1.0, "'s nachts: de kleur van de nacht en volop kunstlicht")
	gs.day_time = 0.6
	await frames(3)
	check(world.canvas_mod.color.is_equal_approx(Daynight.tint_at(0.6)) and world.canvas_mod.color.r > world.canvas_mod.color.b, "'s avonds: oranje")

	# Lantaarns, ramen, altaar en je eigen lamp.
	var lanterns := entities_with("lantern.gd")
	var altars := entities_with("savepoint.gd")
	check(lanterns.size() == 12 and altars.size() == 1, "lantaarns en altaar staan er (%d lantaarns)" % lanterns.size())
	var south_lit := false
	for lantern in lanterns:
		if lantern.global_position.y > tile_pos(0, 20).y:
			south_lit = true
	check(south_lit, "ook in de zuidelijke helft van het dorp staan lantaarns")
	var windows: Node2D = atmosphere.windows
	var window_count := 0
	for row: String in Maps.get_map("village")["rows"]:
		for ch in row:
			if Tiles.CHARS.get(ch, "") == "house_window":
				window_count += 1
	check(window_count >= 6 and is_instance_valid(windows) and windows.cells.size() == window_count and windows.lights.size() == window_count, "alle %d ramen van de huizen kunnen gloeien" % window_count)
	gs.day_time = 0.3
	await frames(3)
	var any_lit := false
	for lantern in lanterns:
		if lantern.light.enabled:
			any_lit = true
	for light in windows.lights:
		if light.enabled:
			any_lit = true
	check(not any_lit and not altars[0].light.enabled and not world.player.light.enabled, "overdag zijn alle lichten uit")
	gs.day_time = 0.8
	await frames(3)
	var all_lit := true
	for lantern in lanterns:
		if not lantern.light.enabled or lantern.light.energy <= 0.2:
			all_lit = false
	for light in windows.lights:
		if not light.enabled or light.energy <= 0.2:
			all_lit = false
	check(all_lit, "'s nachts branden alle lantaarns en gloeien alle ramen")
	check(altars[0].light.enabled and world.player.light.enabled and world.player.light.energy > 0.0 and world.player.light.energy < 0.6, "'s nachts gloeit het altaar en heb je een zacht lampje")
	gs.day_time = 0.57
	await frames(3)
	check(world.light_need() > 0.0 and world.light_need() < 0.3 and lanterns[0].light.energy < 0.2, "in de avond gaan de lichten zachtjes aan")

	# Gewone fakkels doen ook mee: 's nachts buiten branden ze, overdag niet.
	var torch_script: Script = load("res://scripts/entities/torch.gd")
	var torch: Node2D = torch_script.new()
	torch.world = world
	torch.position = tile_pos(18, 13)
	world.entities.add_child(torch)
	gs.day_time = 0.3
	await frames(3)
	check(torch.light != null and not torch.light.enabled, "een fakkel in het dorp geeft overdag geen licht")
	gs.day_time = 0.8
	await frames(3)
	check(torch.light.enabled and torch.light.energy > 0.4, "'s nachts wel (%.2f)" % torch.light.energy)
	torch.queue_free()

	# De klok in beeld.
	gs.day_time = 0.8
	await frames(3)
	check(world.hud._clock_label() == "Nacht", "in beeld staat 'Nacht' (%s)" % world.hud._clock_label())
	check(world.hud.clock_state == "2 Nacht", "met de maan erbij (%s)" % world.hud.clock_state)
	gs.day_time = 0.3
	await frames(3)
	check(world.hud._clock_label() == "Dag", "overdag staat er 'Dag'")
	check(world.hud.clock_state == "0 Dag", "met de zon erbij, en het beeld volgt de klok vanzelf (%s)" % world.hud.clock_state)

	# Binnen en in grotten verandert er niets.
	gs.day_time = 0.8
	await load_map("inn")
	check(not world.is_outdoor() and world.canvas_mod.color.is_equal_approx(Color.WHITE) and world.light_need() == 0.0 and not world.player.light.enabled, "in de herberg is het altijd gewoon licht")
	await load_map("smithy")
	check(world.canvas_mod.color.is_equal_approx(Color.WHITE), "ook in de smederij")
	await load_map("cave")
	var cave_tint: Color = Color.WHITE.lerp(world.DARK_COLOR, Maps.get_map("cave")["dark"])
	check(world.canvas_mod.color.is_equal_approx(cave_tint) and world.light_need() == 1.0 and world.player.light.enabled and near(world.player.light.energy, 1.0), "in de grot blijft alles zoals het was (donker, eigen lamp)")
	gs.day_time = 0.3
	await frames(3)
	check(world.canvas_mod.color.is_equal_approx(cave_tint), "en de grot verandert niet met de klok")
	var cave_altar: Node2D = entities_with("savepoint.gd")[0]
	var cave_torches := entities_with("torch.gd")
	check(cave_altar.light.enabled and near(cave_altar.light.energy, 0.9) and not cave_torches.is_empty() and cave_torches[0].light.enabled and cave_torches[0].light.energy > 0.7, "de lichten van altaar en fakkels in de grot branden zoals voorheen")
	await load_map("temple")
	check(world.canvas_mod.color.is_equal_approx(Color.WHITE.lerp(world.DARK_COLOR, Maps.get_map("temple")["dark"])), "de tempel ook niet")
	await load_map("forest")
	atmosphere.weather = ""
	gs.day_time = 0.8
	await frames(3)
	check(world.canvas_mod.color.is_equal_approx(Daynight.tint_at(0.8)) and world.is_outdoor(), "het bos volgt de nacht")
	check(not is_instance_valid(atmosphere.windows), "het bos heeft geen ramen")
	await load_map("village")
	gs.day_time = 0.3
	await frames(3)
	check(is_instance_valid(atmosphere.windows) and atmosphere.windows.cells.size() == window_count, "terug in het dorp zijn de ramen er weer")
	check(world.canvas_mod.color.is_equal_approx(Daynight.tint_at(0.3) * Daynight.rain_tint(atmosphere.rain_level)), "de kleur van de kaart volgt de klok (en eventueel de regen)")


# --- Slapen ---------------------------------------------------------------------------------------

func test_sleep() -> void:
	print("Slapen in de herberg")
	gs.new_game()
	await load_map("inn")
	var beds := entities_with("bed.gd")
	check(beds.size() == 3, "er staan drie bedden in de herberg")
	gs.day_time = 0.8
	gs.day_count = 0
	gs.hp = 1
	gs.coins = 3

	# Te weinig geld: geen keuze, niets verandert.
	world.player.global_position = beds[1].global_position + Vector2(0, 32)
	await frames(3)
	check(world.player.target == beds[1], "naast het bed kun je er iets mee doen")
	beds[1].interact()
	await frames(2)
	check(world.dialogue.active and world.dialogue.buttons.is_empty(), "met 3 munten krijg je geen keuze om te slapen")
	await finish_dialogue()
	check(gs.hp == 1 and gs.coins == 3 and near(gs.day_time, 0.8, 0.01) and not gs.flag("wereld_geslapen"), "te arm: geen munten kwijt, niet genezen, nog steeds nacht")
	await talk("wereld_bed", [0])
	check(gs.coins == 3 and gs.hp == 1, "ook via een tweede weg lukt het niet zonder geld")

	# Precies genoeg geld.
	gs.coins = 5
	beds[0].interact()
	await frames(2)
	var shown_choices: int = world.dialogue.buttons.size()
	check(shown_choices == 0, "het eerste gesprek is een gewone tekstregel (nog geen keuze op het scherm)")
	var guard := 0
	while world.dialogue.buttons.is_empty() and guard < 20:
		press("interact")
		guard += 1
		await frames(2)
	check(world.dialogue.buttons.size() == 2 and world.dialogue.buttons[0].text.begins_with("Slapen"), "met 5 munten kun je kiezen: slapen of nog even niet")
	world.dialogue.buttons[1].pressed.emit() # nog even niet
	await frames(3)
	check(gs.coins == 5 and gs.hp == 1 and not world.dialogue.active and not gs.transitioning, "'nog even niet' kost niets")

	# Echt slapen.
	beds[0].interact()
	await frames(2)
	await finish_dialogue([0])
	await frames(2)
	check(gs.transitioning and gs.coins == 0, "tijdens het slapen kun je niets doen en betaal je 5 munten")
	await frames(200)
	check(not gs.transitioning and not gs.dialogue_open and gs.ui_owners.is_empty(), "daarna is alles weer vrij (geen blokkades achtergebleven)")
	check(gs.hp == gs.max_hp(), "je bent helemaal genezen (%d/%d)" % [gs.hp, gs.max_hp()])
	check(near(gs.day_time, Daynight.MORNING, 0.01) and gs.day_count == 1, "het is ochtend en een nieuwe dag begonnen")
	check(gs.flag("wereld_geslapen"), "onthouden dat je geslapen hebt")
	var saved := read_save()
	check(near(float(saved.get("day_time", -1.0)), Daynight.MORNING, 0.01) and int(saved.get("day_count", 0)) == 1 and int(saved.get("hp", 0)) == gs.max_hp(), "het is opgeslagen (ochtend, volle hartjes)")
	check(world.fader.rect.color.a < 0.01, "het scherm is weer helder")

	# Twee keer tegelijk betaalt maar een keer; zonder geld doet het niets.
	gs.coins = 20
	gs.hp = 2
	world.atmosphere.sleep_in_bed()
	world.atmosphere.sleep_in_bed()
	await frames(2)
	check(gs.coins == 15, "dubbel op het bed drukken kost maar 5 munten")
	await frames(200)
	check(not gs.transitioning and gs.hp == gs.max_hp(), "en je wordt gewoon wakker")
	gs.coins = 4
	gs.hp = 1
	world.atmosphere.sleep_in_bed()
	await frames(5)
	check(not gs.transitioning and gs.hp == 1 and gs.coins == 4, "de actie zelf weigert ook als je te weinig munten hebt")

	# Via Mila.
	gs.coins = 10
	gs.hp = 1
	gs.day_time = 0.7
	await talk("wereld_bed_info", [0])
	await frames(200)
	check(gs.hp == gs.max_hp() and gs.coins == 5 and near(gs.day_time, Daynight.MORNING, 0.01), "Mila stuurt je naar bed en het werkt hetzelfde")
	check(gs.day_count == 3, "elke nacht slapen is een nieuwe dag (%d)" % gs.day_count)
	gs.day_time = 0.01
	gs.coins = 5
	world.atmosphere.sleep_in_bed()
	await frames(200)
	check(near(gs.day_time, Daynight.MORNING, 0.01) and gs.day_count == 3, "slapen vlak voor zonsopgang slaat geen dag over")
	# Het hele gesprek met Mila, zoals een speler het doet: "Mag ik hier slapen?" en dan "Slapen".
	gs.coins = 9
	gs.hp = 3
	gs.day_time = 0.75
	gs.quests.erase("drank")
	await talk("mila_menu", [2, 0])
	await frames(200)
	check(gs.coins == 4 and gs.hp == gs.max_hp() and near(gs.day_time, Daynight.MORNING, 0.01), "in het gesprek met Mila: 'Mag ik hier slapen?' en dan 'Slapen' werkt")
	gs.day_time = 0.3
	await load_map("village")
	check(gs.map_id == "village", "en daarna loop je gewoon naar buiten")


# --- Regen -----------------------------------------------------------------------------------------

func test_rain() -> void:
	print("Regen")
	gs.new_game()
	await load_map("forest")
	var atmosphere: Node = world.atmosphere
	var rain: Node2D = atmosphere.rain
	check(rain.get_parent() == world.fx_layer, "de regen hangt in de fx_layer")
	check(rain.MAX_DROPS <= 150 and rain.MAX_SPLASHES > 0, "grenzen: hooguit %d strepen en %d spetters" % [rain.MAX_DROPS, rain.MAX_SPLASHES])
	atmosphere.weather = ""
	atmosphere.rain_level = 0.0
	gs.day_time = 0.3
	await frames(3)
	check(rain.drop_count() == 0 and not rain.visible and not atmosphere.rain_audio.playing, "droog weer: geen strepen en geen geluid")
	var dry_color: Color = world.canvas_mod.color

	atmosphere.weather = "rain"
	var children_before: int = world.fx_layer.get_child_count()
	await frames(60)
	check(atmosphere.rain_level > 0.0 and atmosphere.rain_level < 1.0, "de regen zet geleidelijk aan (%.2f na een seconde)" % atmosphere.rain_level)
	await frames(300)
	check(near(atmosphere.rain_level, 1.0), "na een tijdje regent het volop")
	check(rain.visible and rain.drop_count() == rain.MAX_DROPS, "volop regen: precies het maximum aan strepen (%d)" % rain.drop_count())
	check(world.fx_layer.get_child_count() <= children_before + rain.MAX_SPLASHES, "regen maakt geen losse objecten aan")
	check(atmosphere.rain_audio.playing and atmosphere.rain_audio.bus == "SFX" and atmosphere.rain_audio.stream is AudioStreamWAV, "het regengeluid speelt op het geluidseffecten-kanaal (volume en mute werken)")
	var loop: AudioStreamWAV = atmosphere.rain_audio.stream
	check(loop.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.loop_end > 0, "en het is een lus")
	check(near(loop.loop_end / float(loop.mix_rate), loop.get_length(), 0.05), "de lus is het hele geluid (%.2f van %.2f seconden), niet alleen het begin" % [loop.loop_end / float(loop.mix_rate), loop.get_length()])
	var rain_color: Color = world.canvas_mod.color
	check(rain_color.r < dry_color.r - 0.05 and rain_color.b < dry_color.b, "het wordt iets donkerder als het regent")
	var splashes := 0
	for i in 120:
		await process_frame
		splashes = maxi(splashes, rain.splash_count())
		if rain.splash_count() > rain.MAX_SPLASHES:
			break
	check(splashes > 0 and splashes <= rain.MAX_SPLASHES, "er zijn spetters, maar nooit meer dan %d (hoogste: %d)" % [rain.MAX_SPLASHES, splashes])
	rain.level = 9.0
	check(rain.drop_count() == rain.MAX_DROPS, "een te hoge waarde geeft nog steeds hooguit het maximum")
	rain.level = atmosphere.rain_level
	check(rain._pos.size() == rain.MAX_DROPS, "de rijtjes met strepen groeien nooit")

	# De strepen blijven rond het beeld en de camera.
	world.player.global_position = tile_pos(20, 20)
	world.player.camera.reset_smoothing()
	await frames(5)
	var inside := true
	for i in rain.drop_count():
		var p: Vector2 = rain._pos[i]
		if absf(p.x) > rain.VIEW.x or p.y < -rain.VIEW.y or p.y > rain.VIEW.y:
			inside = false
	check(inside and rain.global_position.distance_to(world.player.camera.get_screen_center_position()) < 40.0, "de strepen blijven bij je beeld, ook als je loopt")

	# Kaartwissel naar binnen: regen stopt meteen. Terug: weer regen.
	await load_map("inn")
	check(atmosphere.rain_level == 0.0 and not rain.visible and not atmosphere.rain_audio.playing, "binnen regent het niet en is het stil")
	check(world.canvas_mod.color.is_equal_approx(Color.WHITE), "en binnen is het niet donkerder")
	await load_map("village")
	check(atmosphere.weather == "random", "het dorp heeft weer zijn eigen weer")
	atmosphere.weather = "rain"
	await load_map("forest")
	atmosphere.weather = "rain"
	atmosphere.rain_level = 1.0
	await frames(5)
	check(atmosphere.rain_audio.playing, "in een regenachtig bos hoor je weer regen")

	# Droog worden.
	atmosphere.weather = ""
	await frames(300)
	check(atmosphere.rain_level == 0.0 and rain.drop_count() == 0 and not atmosphere.rain_audio.playing, "de regen stopt vanzelf en het geluid ook")
	await frames(40)
	check(not rain.visible and rain.splash_count() == 0, "ook de laatste spetters zijn weg")

	# Willekeurig weer volgt de klok.
	var rainy_slot := -1
	var dry_slot := -1
	for day in 50:
		for slot in range(1, Daynight.WEATHER_SLOTS):
			var t := (float(slot) + 0.5) / float(Daynight.WEATHER_SLOTS)
			if rainy_slot < 0 and Daynight.raining("random", day, t):
				rainy_slot = day * 10 + slot
			if dry_slot < 0 and not Daynight.raining("random", day, t):
				dry_slot = day * 10 + slot
	atmosphere.weather = "random"
	gs.day_count = int(rainy_slot / 10)
	gs.day_time = (float(rainy_slot % 10) + 0.5) / float(Daynight.WEATHER_SLOTS)
	check(atmosphere._rain_target() == 1.0, "willekeurig weer: in een regenachtig vakje regent het")
	gs.day_count = int(dry_slot / 10)
	gs.day_time = (float(dry_slot % 10) + 0.5) / float(Daynight.WEATHER_SLOTS)
	check(atmosphere._rain_target() == 0.0, "en in een droog vakje niet")
	gs.new_game()
	gs.in_game = true

	# Een regenmaker los gebruiken, ook zonder wereld, mag niets stukmaken.
	var loose: Node2D = RainScript.new()
	root.add_child(loose)
	loose.level = 1.0
	await frames(30)
	check(loose.drop_count() == loose.MAX_DROPS and loose.splash_count() <= loose.MAX_SPLASHES, "een losse regenmaker zonder camera werkt ook")
	loose.queue_free()
	await frames(2)


# --- Snel reizen -----------------------------------------------------------------------------------

## De tegels waar je kunt lopen, vanaf een startpunt (dezelfde regels als de botsing: alleen vaste tegels blokkeren).
func walkable_from(def: Dictionary, start: Array) -> Dictionary:
	var rows: Array = def["rows"]
	var seen := {Vector2i(int(start[0]), int(start[1])): true}
	var queue: Array[Vector2i] = [Vector2i(int(start[0]), int(start[1]))]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next := cell + step
			if next.y < 0 or next.y >= rows.size() or next.x < 0 or next.x >= String(rows[next.y]).length() or seen.has(next):
				continue
			if not Tiles.is_solid_char(String(rows[next.y])[next.x]):
				seen[next] = true
				queue.append(next)
	return seen


func test_map_reachability() -> void:
	print("Alles op de kaarten is bereikbaar")
	var problems: Array[String] = []
	for map_id: String in BASE_MAP_IDS:
		var def: Dictionary = Maps.get_map(map_id)
		var region := walkable_from(def, def["spawns"]["start"])
		for obj: Dictionary in def["objects"]:
			var tile := Vector2i(int(obj["pos"][0]), int(obj["pos"][1]))
			match obj["type"]:
				"npc", "chest", "sign", "savepoint", "wereld_lantaarn", "wereld_bed", "gate":
					# Je staat ernaast: een van de vier buren moet begaanbaar zijn.
					var reachable := false
					for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
						if region.has(tile + step):
							reachable = true
					if not reachable:
						problems.append("%s: %s op %s is niet bereikbaar" % [map_id, obj["type"], tile])
				"portal", "pickup", "enemy":
					if not region.has(tile):
						problems.append("%s: %s op %s is niet bereikbaar" % [map_id, obj["type"], tile])
	check(problems.is_empty(), "alle personages, kisten, borden, altaren, poorten, portalen en voorwerpen zijn bereikbaar %s" % [problems])
	var arrival_problems: Array[String] = []
	var altar_count := 0
	for altar in FastTravel.all_altars():
		altar_count += 1
		var def: Dictionary = Maps.get_map(altar["map"])
		var region := walkable_from(def, def["spawns"]["start"])
		var tile := Vector2i(int(altar["pos"].x / 32.0), int(altar["pos"].y / 32.0))
		if not region.has(tile):
			arrival_problems.append("%s: aankomst %s is niet bereikbaar" % [altar["map"], tile])
		if absi(tile.x - altar["tile"].x) > 2 or absi(tile.y - altar["tile"].y) > 2 or tile == altar["tile"]:
			arrival_problems.append("%s: aankomst %s ligt niet naast het altaar %s" % [altar["map"], tile, altar["tile"]])
		if not def["spawns"].has(altar["spawn"]):
			arrival_problems.append("%s: spawnpunt %s bestaat niet" % [altar["map"], altar["spawn"]])
		for obj: Dictionary in def["objects"]:
			if obj["type"] == "enemy" and absi(int(obj["pos"][0]) - tile.x) <= 1 and absi(int(obj["pos"][1]) - tile.y) <= 1:
				arrival_problems.append("%s: een vijand staat bij de aankomstplek %s" % [altar["map"], tile])
	check(arrival_problems.is_empty() and altar_count >= 5, "elk van de %d altaren heeft een geschikte plek om aan te komen %s" % [altar_count, arrival_problems])
	var explicit := true
	for map_id in ["village", "forest", "ruins", "cave", "temple"]:
		if not Maps.get_map(map_id)["spawns"].has("altar"):
			explicit = false
	check(explicit, "de vijf altaarkaarten hebben een eigen spawnpunt 'altar'")

	# Een altaar zonder eigen spawnpunt krijgt de dichtstbijzijnde vrije tegel, liefst eronder.
	var fake := {
		"rows": ["#####", "#...#", "#.#.#", "#...#", "#####"],
		"spawns": {"start": [1, 1]},
		"objects": [{"type": "savepoint", "pos": [2, 1]}, {"type": "chest", "pos": [2, 3]}],
	}
	var fallback: Vector2i = FastTravel.arrival_tile(fake, fake["objects"][0])
	check(fallback == Vector2i(1, 2), "zonder spawnpunt: de vrije tegel het dichtst bij het altaar (%s)" % fallback)
	var walled := {"rows": ["###", "#.#", "###"], "spawns": {"start": [1, 1]}, "objects": [{"type": "savepoint", "pos": [1, 1]}]}
	check(FastTravel.arrival_tile(walled, walled["objects"][0]) == Vector2i(1, 1), "helemaal ingesloten: terugvallen op het startpunt, nooit een fout")


func test_fast_travel() -> void:
	print("Snel reizen")
	fresh_game()
	await load_map("village", "start")
	var all: Array = FastTravel.all_altars()
	var ids: Array[String] = []
	for altar in all:
		ids.append(altar["map"])
	check(ids.slice(0, 5) == ["village", "forest", "ruins", "cave", "temple"], "alle altaren in de volgorde van de kaarten %s" % [ids])
	check(FastTravel.discovered_altars().is_empty() and FastTravel.blocked_reason(world) == "Je hebt nog geen altaar ontdekt.", "in het begin is er niets ontdekt")
	var toasts: Array[String] = []
	var catcher := func(text: String) -> void: toasts.append(text)
	gs.toast.connect(catcher)
	var result: bool = await FastTravel.travel(world, all[1])
	check(not result and gs.map_id == "village" and not gs.transitioning, "reizen naar een niet-ontdekt altaar kan niet")
	check(not toasts.is_empty() and toasts[toasts.size() - 1] == "Je hebt nog geen altaar ontdekt.", "met een duidelijke melding (%s)" % [toasts])

	# Een altaar ontdekken door het te gebruiken.
	var altar_node: Node2D = entities_with("savepoint.gd")[0]
	var key: String = all[0]["key"]
	check(altar_node.discovery_key() == key and not gs.flag(key), "het dorpsaltaar is nog niet ontdekt")
	gs.hp = 2
	altar_node.interact()
	check(gs.flag(key) and gs.hp == gs.max_hp() and gs.has_save(), "gebruiken ontdekt het altaar (en geneest en slaat op zoals altijd)")
	check(toasts.has("Altaar ontdekt! Via de kaart (N) reis je er later snel naartoe."), "de eerste keer krijg je een melding dat het ontdekt is")
	toasts.clear()
	altar_node.interact()
	check(not toasts.has("Altaar ontdekt! Via de kaart (N) reis je er later snel naartoe.") and FastTravel.discovered_altars().size() == 1, "de tweede keer is het niet opnieuw 'ontdekt'")
	check(read_save().get("flags", {}).has(key), "de ontdekking staat in de opslag")
	check(FastTravel.blocked_reason(world) == "", "met een ontdekt altaar en rust om je heen mag het")

	# Wanneer het niet mag.
	gs.dialogue_open = true
	check(FastTravel.blocked_reason(world).contains("gesprek"), "niet tijdens een gesprek")
	gs.dialogue_open = false
	gs.ui_owners["shop"] = true
	check(FastTravel.blocked_reason(world) != "", "niet terwijl een winkel of ander scherm open staat")
	gs.ui_owners = {}
	gs.ui_owners["menu"] = true
	check(FastTravel.blocked_reason(world) == "", "wel vanuit het menu zelf")
	gs.ui_owners = {}
	gs.transitioning = true
	check(FastTravel.blocked_reason(world) != "", "niet tijdens een overgang")
	gs.transitioning = false
	gs.ended = true
	check(FastTravel.blocked_reason(world) != "", "niet na game over")
	gs.ended = false
	var map_before: String = gs.map_id
	gs.dialogue_open = true
	result = await FastTravel.travel(world, all[0])
	gs.dialogue_open = false
	check(not result and gs.map_id == map_before and not gs.transitioning, "reizen tijdens een gesprek gebeurt niet en laat niets hangen")

	# Echt reizen: dorp -> bos.
	gs.set_flag(all[1]["key"])
	world.player.global_position = tile_pos(10, 10)
	var ui_before: int = gs.ui_owners.size()
	result = await FastTravel.travel(world, all[1])
	check(result and gs.map_id == "forest", "reizen naar het bosaltaar brengt je naar het bos")
	check(world.player.global_position.is_equal_approx(all[1]["pos"]) and world.player.global_position.distance_to(entities_with("savepoint.gd")[0].global_position) < 64.0, "je komt vlak naast het altaar aan")
	check(not gs.transitioning and not gs.dialogue_open and gs.ui_owners.size() == ui_before and not paused, "daarna is alles weer vrij (transitioning, gesprek en schermen)")
	check(gs.flag("wereld_snel_gereisd"), "onthouden dat je snel gereisd hebt")
	check(read_save().get("map", "") == "forest", "de aankomst is meteen opgeslagen")
	check(world.fader.rect.color.a < 0.01, "het scherm is weer helder")
	var walk_start: Vector2 = world.player.global_position
	Input.action_press("move_down")
	await frames(20)
	Input.action_release("move_down")
	check(world.player.global_position.y > walk_start.y + 5.0, "en je kunt meteen weer lopen")

	# Naar het altaar van de kaart waar je al bent: alleen jij gaat erheen, de kaart wordt niet opnieuw geladen.
	var enemies_before: int = get_nodes_in_group("enemies").size()
	get_nodes_in_group("enemies")[0].queue_free() # deze is "verslagen"
	await frames(2)
	var forest_altar: Node2D = entities_with("savepoint.gd")[0]
	world.player.global_position = tile_pos(20, 20)
	result = await FastTravel.travel(world, all[1])
	check(result and gs.map_id == "forest" and world.player.global_position.is_equal_approx(all[1]["pos"]), "naar het altaar op dezelfde kaart: je staat er meteen naast")
	check(get_nodes_in_group("enemies").size() == enemies_before - 1 and is_instance_valid(forest_altar) and not forest_altar.is_queued_for_deletion(), "verslagen vijanden komen niet terug (de kaart is niet opnieuw geladen)")
	check(not gs.transitioning and read_save().get("map", "") == "forest" and world.fader.rect.color.a < 0.01, "en daarna is alles weer vrij en opgeslagen")

	# Naar een kaart met een donker gebied en terug.
	gs.set_flag(all[3]["key"])
	result = await FastTravel.travel(world, all[3])
	check(result and gs.map_id == "cave" and world.darkness > 0.0 and world.player.light.enabled, "naar de grot: het is donker en je lamp brandt")
	gs.set_flag(all[0]["key"])
	result = await FastTravel.travel(world, all[0])
	check(result and gs.map_id == "village" and world.player.global_position.is_equal_approx(all[0]["pos"]), "en weer terug naar het dorp")
	result = await FastTravel.travel(world, all[0])
	check(result and gs.map_id == "village", "reizen naar het altaar op dezelfde kaart mag ook")

	# Onderweg verslagen (een vijand raakt je nog terwijl het scherm zwart wordt).
	var save_before := read_save()
	FastTravel.travel(world, all[3])
	await frames(5)
	gs.hurt(99)
	var guard := 0
	while gs.transitioning and guard < 200:
		guard += 1
		await process_frame
	var save_after := read_save()
	check(gs.ended and gs.map_id == "village", "wie onderweg verslagen wordt, reist niet")
	check(save_after.get("map") == save_before.get("map") and save_after.get("pos") == save_before.get("pos") and int(save_after.get("hp", 0)) > 0, "en de laatste opslag wordt niet overschreven door een verslagen held")
	check(world.fader.rect.color.a < 0.01 and world.hud.overlay.visible, "het scherm wordt weer helder, met het game-over-scherm erop")
	gs.ended = false
	gs.full_heal()
	world.hud.overlay.visible = false

	# Een baasgevecht.
	gs.set_flag(all[4]["key"])
	await load_map("temple")
	var king: Node2D = null
	for boss in get_nodes_in_group("boss"):
		if boss.kind == "king":
			king = boss
	check(king != null and not king.active and not FastTravel.boss_fight(world), "de slapende Slijmkoning is nog geen gevecht")
	check(FastTravel.blocked_reason(world) == "", "voor het gevecht mag je gewoon weg")
	king.activate()
	check(FastTravel.boss_fight(world) and FastTravel.blocked_reason(world).contains("baasgevecht"), "tijdens het baasgevecht niet")
	world.player.global_position = king.global_position + Vector2(0, 900)
	check(FastTravel.boss_fight(world), "ook niet als je ver weg rent (de baas is wakker)")
	map_before = gs.map_id
	result = await FastTravel.travel(world, all[0])
	check(not result and gs.map_id == map_before and not gs.transitioning, "reizen tijdens het baasgevecht wordt geweigerd")
	king.dead = true
	check(FastTravel.boss_fight(world), "een verslagen baas die nog aan het verdwijnen is, telt nog mee")
	king.dead = false
	king.queue_free()
	await frames(3)
	check(not FastTravel.boss_fight(world) and FastTravel.blocked_reason(world) == "", "als de baas weg is mag het weer")

	# Een golem (altijd wakker) telt alleen als je dichtbij bent.
	await load_map("ruins")
	var golem: Node2D = null
	for boss in get_nodes_in_group("boss"):
		if boss.kind == "golem":
			golem = boss
	world.player.global_position = golem.global_position + Vector2(0, 700)
	check(not FastTravel.boss_fight(world), "een golem in de verte is geen baasgevecht")
	world.player.global_position = golem.global_position + Vector2(0, 200)
	check(FastTravel.boss_fight(world), "dichtbij een golem wel")
	gs.toast.disconnect(catcher)


func test_fast_travel_menu() -> void:
	print("Snel reizen via het menu")
	fresh_game()
	await load_map("village", "start")
	var all: Array = FastTravel.all_altars()
	var menu: Node = world.menu_ui
	press("map")
	await frames(3)
	check(menu.active and menu.tab == menu.TAB_MAP, "N opent de kaart")
	press("interact")
	await frames(2)
	check(not menu.travel_confirm and menu.travel_message == "Je hebt nog geen altaar ontdekt." and menu.active, "zonder altaren krijg je alleen een melding in het menu")
	press("ui_down")
	press("ui_up")
	await frames(2)
	check(menu.active and menu.tab == menu.TAB_MAP, "pijltjes doen niets geks zonder altaren")
	press("pause")
	await frames(3)
	check(not menu.active and not paused, "Esc sluit het menu")

	gs.set_flag(all[0]["key"])
	gs.set_flag(all[1]["key"])
	gs.set_flag(all[3]["key"])
	press("map")
	await frames(3)
	check(FastTravel.discovered_altars().size() == 3 and menu.travel_selected == 0, "drie ontdekte altaren, het eerste is gekozen")
	press("ui_down")
	await frames(2)
	press("ui_down")
	await frames(2)
	press("ui_down")
	await frames(2)
	check(menu.travel_selected == 2, "pijl omlaag kiest het volgende altaar, en blijft bij het laatste")
	press("ui_up")
	await frames(2)
	check(menu.travel_selected == 1, "pijl omhoog gaat terug")

	# Esc annuleert alleen de vraag.
	press("interact")
	await frames(2)
	check(menu.travel_confirm and menu.active, "E vraagt om bevestiging")
	check(MenuPages.in_sentence("De Vergeten Ruïne") == "de Vergeten Ruïne" and MenuPages.in_sentence("Het Oude Bos") == "het Oude Bos" and MenuPages.in_sentence("Fluisterbos") == "Fluisterbos", "in de vraag staat \"Reizen naar de Vergeten Ruïne?\" (kleine letter midden in de zin)")
	press("pause")
	await frames(2)
	check(not menu.travel_confirm and menu.active and gs.map_id == "village", "Esc annuleert de vraag en laat het menu open")
	press("interact")
	await frames(2)
	press("ui_down")
	await frames(2)
	check(not menu.travel_confirm and menu.travel_selected == 2, "een pijl annuleert de vraag en kiest daarna gewoon")
	press("ui_up")
	await frames(2)
	press("interact")
	await frames(2)
	press("ui_right")
	await frames(2)
	check(not menu.travel_confirm and menu.tab == menu.TAB_MAP + 1, "naar een ander tabblad annuleert de vraag")
	press("ui_left")
	await frames(2)

	# Bevestigen.
	check(menu.tab == menu.TAB_MAP, "terug op de kaart")
	press("interact")
	await frames(2)
	check(menu.travel_confirm, "vraag staat weer open")
	press("interact")
	await frames(2)
	check(not menu.active and not menu.travel_confirm and gs.transitioning, "bevestigen sluit het menu en begint de reis")
	var guard := 0
	while gs.transitioning and guard < 200:
		guard += 1
		await process_frame
	check(gs.map_id == "forest" and not gs.transitioning and gs.ui_owners.is_empty() and not paused, "je bent in het bos, vrij om te lopen (geen blokkades)")
	check(world.player.global_position.distance_to(all[1]["pos"]) < 4.0, "op de aankomstplek van het bosaltaar")

	# Geblokkeerd vanuit het menu: een baasgevecht.
	await load_map("temple")
	for boss in get_nodes_in_group("boss"):
		if boss.kind == "king":
			boss.activate()
	press("map")
	await frames(3)
	press("interact")
	await frames(2)
	check(not menu.travel_confirm and menu.travel_message.contains("baasgevecht") and menu.active, "tijdens een baasgevecht krijg je een melding en reist er niets")
	press("pause")
	await frames(3)
	for boss in get_nodes_in_group("boss"):
		boss.queue_free()
	await frames(3)

	# In een gesprek kan het menu niet eens open.
	gs.dialogue_open = true
	gs.set_ui("dialogue", true)
	press("map")
	await frames(3)
	check(not menu.active, "tijdens een gesprek opent N het menu niet")
	gs.dialogue_open = false
	gs.set_ui("dialogue", false)
	await frames(2)

	# Een open vraag blijft niet hangen als je het menu sluit (met I) en weer opent.
	var map_now: String = gs.map_id
	press("map")
	await frames(3)
	press("interact")
	await frames(2)
	check(menu.travel_confirm, "de vraag staat open")
	press("menu")
	await frames(3)
	check(not menu.active, "I sluit het menu")
	press("map")
	await frames(3)
	check(menu.active and not menu.travel_confirm and gs.map_id == map_now, "weer open: geen oude vraag meer, en er is niet gereisd")
	press("pause")
	await frames(3)


## De Slijmkoning is verslagen en verdwijnt langzaam; daarna begint het einde. Wegreizen mag dan niet,
## anders verdwijnt hij met de oude kaart en komt het einde nooit.
func test_fast_travel_dying_king() -> void:
	print("Snel reizen terwijl de Slijmkoning verdwijnt")
	fresh_game()
	var all: Array = FastTravel.all_altars()
	gs.set_flag(all[0]["key"])
	gs.set_flag(all[4]["key"])
	gs.set_flag("gate_temple")
	await load_map("temple")
	var king: Node2D = null
	for boss in get_nodes_in_group("boss"):
		if boss.kind == "king":
			king = boss
	king.activate()
	await frames(2)
	king.hurt(999, Vector2.DOWN)
	check(king.dead and gs.flag("boss_defeated"), "de Slijmkoning is verslagen")
	await frames(6)
	check(FastTravel.blocked_reason(world) != "", "terwijl hij verdwijnt kun je niet reizen")
	var menu: Node = world.menu_ui
	press("map")
	await frames(3)
	press("interact")
	await frames(2)
	press("interact")
	await frames(2)
	check(menu.active and not menu.travel_confirm and menu.travel_message != "" and gs.map_id == "temple" and not gs.transitioning, "ook niet via de kaart (N, E, E): je krijgt een melding")
	press("pause")
	await frames(3)
	var guard := 0
	while not (current_scene != null and current_scene.scene_file_path.ends_with("ending.tscn")) and guard < 400:
		guard += 1
		await process_frame
	check(gs.flag("game_completed") and current_scene != null and current_scene.scene_file_path.ends_with("ending.tscn"), "daarna begint het einde gewoon")
	current_scene.queue_free()
	await frames(3)
	gs.transitioning = false
	await start_world()


# --- Prestaties -------------------------------------------------------------------------------------

func test_achievements() -> void:
	print("Prestaties")
	fresh_game()
	await load_map("village")
	var banner: Node = world.hud.achievement_banner
	gs.achievement_queue.clear() # meldingen van eerdere onderdelen van deze test
	banner.time = 0.0
	var unlocked: Array[String] = []
	var listener := func(id: String) -> void: unlocked.append(id)
	gs.achievement_unlocked.connect(listener)
	gs.check_achievements()
	check(unlocked.is_empty() and gs.achievements.is_empty(), "een schoon spel heeft geen prestaties")

	# Ontgrendelen en de melding.
	var fx_before: int = world.fx_layer.get_child_count()
	gs.register_kill("slime")
	gs.check_achievements()
	check(unlocked == ["first_blood"] and gs.achievements.has("first_blood"), "de eerste vijand geeft 'Eerste klap'")
	check(world.fx_layer.get_child_count() >= fx_before + 2, "met gouden glinsteringen rond de speler")
	await frames(3)
	check(not banner.is_showing() and gs.achievement_queue == ["first_blood"] and world.hud.banner_time > 0.0, "zolang de naam van de kaart groot in beeld staat, wacht de melding (anders vallen ze over elkaar)")
	var toasts: Array[String] = []
	var catcher := func(text: String) -> void: toasts.append(text)
	gs.toast.connect(catcher)
	banner.hinted = false
	await wait_for_map_name()
	check(banner.is_showing() and gs.achievement_queue.is_empty(), "de melding verschijnt in beeld en de wachtrij is leeg")
	check(toasts.has(banner.hint_text()), "bij de eerste melding hoor je waar je de prestaties (T) en het beestenboek (B) vindt")
	check(banner.name_label.text == Achievements.info("first_blood")["name"], "met de naam van de prestatie")
	gs.check_achievements()
	check(unlocked.size() == 1, "dezelfde prestatie komt maar een keer")
	gs.unlock_achievement("first_blood")
	check(unlocked.size() == 1, "ook niet als je hem zelf nog eens geeft")
	check(banner.root.position.y > -60.0, "de melding schuift in beeld")
	await frames(60 * 5)
	check(not banner.is_showing() and banner.root.modulate.a == 0.0, "en verdwijnt na een paar seconden")
	# Tijdens een overgang (zwart scherm) wacht de melding.
	gs.transitioning = true
	gs.unlock_achievement("boots")
	await frames(20)
	check(not banner.is_showing() and gs.achievement_queue == ["boots"], "tijdens een overgang wacht de melding, en gaat niet verloren")
	gs.transitioning = false
	await frames(5)
	check(banner.is_showing() and gs.achievement_queue.is_empty() and banner.name_label.text == Achievements.info("boots")["name"], "na de overgang wordt hij getoond")
	check(toasts.count(banner.hint_text()) == 1, "die tip krijg je maar een keer")
	gs.toast.disconnect(catcher)
	await frames(60 * 5)

	# Tellen: kills, rollen, drankjes.
	for i in 48:
		gs.register_kill("slime")
	gs.check_achievements()
	check(gs.kills == 49 and not gs.achievements.has("slayer_50"), "49 vijanden: nog geen 'Slijmenjager'")
	gs.register_kill("bat")
	gs.check_achievements()
	check(gs.achievements.has("slayer_50") and gs.kills_by["slime"] == 49 and gs.kills_by["bat"] == 1, "bij 50 wel (en per soort geteld)")
	gs.kills = 199
	gs.register_kill("slime")
	gs.check_achievements()
	check(gs.achievements.has("slayer_200"), "bij 200 'Schrik van Azura'")
	gs.kills = 12
	check(MenuPages.progress([["kills", 50]]) == "  (12 / 50)" and MenuPages.progress([["kills", 10]]) == "  (10 / 10)", "in de lijst zie je hoe ver je bent (12 / 50), en nooit verder dan het doel")
	check(MenuPages.progress([["flag", "boss_defeated"]]) == "" and MenuPages.progress([]) == "", "zonder teller geen voortgang")
	gs.kills = 200
	world.player.roll_cooldown = 0.0
	var rolls_before: int = gs.rolls
	press("dodge")
	await frames(2)
	check(gs.rolls == rolls_before + 1, "een echte rol (Shift) wordt geteld")
	world.player.roll_cooldown = 0.0
	world.player.roll_timer = 0.0
	press("dodge")
	press("dodge")
	await frames(2)
	check(gs.rolls == rolls_before + 2, "een rol die niet mag (nog bezig) telt niet mee")
	gs.rolls = 49
	gs.check_achievements()
	check(not gs.achievements.has("rolls_50"), "49 keer gerold is nog niet genoeg")
	gs.note_roll()
	gs.check_achievements()
	check(gs.achievements.has("rolls_50"), "50 keer gerold: 'Rolmeester'")
	gs.give("potion", 12, true)
	gs.full_heal()
	var before_drunk: int = gs.potions_drunk
	check(not gs.use_potion() and gs.potions_drunk == before_drunk, "een drankje bij volle gezondheid wordt niet gedronken en niet geteld")
	for i in 10:
		gs.hp = 1
		gs.use_potion()
	check(gs.potions_drunk == before_drunk + 10 and gs.count("potion") == 2, "tien echte drankjes gedronken")
	gs.check_achievements()
	check(gs.achievements.has("potions_10"), "'Proost!'")

	# Voorwerpen, vlaggen en opdrachten.
	gs.give("boots", 1, true)
	gs.give("heart_container", 1, true)
	gs.check_achievements()
	check(gs.achievements.has("boots") and not gs.achievements.has("hearts_all"), "laarzen zijn gekocht, hartcontainers nog niet allemaal")
	gs.give("heart_container", 1, true)
	gs.check_achievements()
	check(gs.achievements.has("hearts_all"), "alle hartcontainers")
	gs.give("crystal_bos", 1, true)
	gs.check_achievements()
	check(gs.achievements.has("crystal_bos") and not gs.achievements.has("crystal_grot"), "het bos-kristal telt, de andere nog niet")
	gs.take("crystal_bos")
	gs.set_flag("gate_temple")
	gs.check_achievements()
	check(gs.achievements.has("crystal_ruine") and gs.achievements.has("crystal_grot"), "als Bram de kristallen heeft gehad tellen alle drie")
	gs.set_flag("golem_ruins")
	gs.check_achievements()
	check(not gs.achievements.has("golems"), "een golem is nog geen twee")
	gs.set_flag("golem_cave")
	gs.check_achievements()
	check(gs.achievements.has("golems"), "beide golems")
	for quest_id in ["kat", "medaillon"]:
		gs.start_quest(quest_id)
		gs.finish_quest(quest_id)
	gs.check_achievements()
	check(not gs.achievements.has("sidequests"), "twee van de drie zij-opdrachten is niet genoeg")
	gs.start_quest("drank")
	gs.finish_quest("drank")
	gs.check_achievements()
	check(gs.achievements.has("sidequests"), "alle zij-opdrachten")
	for kind in BASE_KINDS:
		gs.register_kill(kind)
	gs.check_achievements()
	check(gs.achievements.has("bestiary_all"), "elke soort vijand verslagen: 'Beestenkenner'")
	check(not gs.achievements.has("king") and not gs.achievements.has("completed") and not gs.achievements.has("speedrun"), "het einde is nog niet gehaald")
	for id in ["fast_travel", "chests_all", "talked_all", "flawless_boss", "slept", "rich"]:
		if gs.achievements.has(id):
			check(false, "%s mag nog niet behaald zijn" % id)

	# Echte personages en kisten.
	var bram: Node2D = null
	for npc in get_nodes_in_group("npc"):
		if npc.npc_id == "bram":
			bram = npc
	bram.interact()
	check(gs.talked.has("bram"), "praten met een personage wordt onthouden")
	await finish_dialogue([0])
	for npc_id in ["greta", "tobias", "mila", "pim", "hein", "anja", "joost", "wilfred"]:
		gs.note_talked(npc_id)
	gs.check_achievements()
	check(not gs.achievements.has("talked_all"), "nog niet iedereen gesproken (Muis ontbreekt)")
	gs.note_talked("muis_bos")
	gs.check_achievements()
	check(gs.achievements.has("talked_all"), "iedereen gesproken: 'Gezellig babbelen'")
	gs.set_flag("chest:forest:1")
	gs.set_flag("chest:ruins:2")
	gs.set_flag("chest:cave:3")
	gs.check_achievements()
	check(not gs.achievements.has("chests_all"), "een kist in drie van de vier gebieden is niet genoeg")
	gs.set_flag("chest:inn:4")
	gs.check_achievements()
	check(gs.achievements.has("chests_all"), "een kist in elk gebied: 'Schatzoeker'")

	# Het einde en de baasstrijd.
	gs.play_time = 4000.0
	gs.set_flag("boss_defeated")
	gs.set_flag("game_completed")
	gs.check_achievements()
	check(gs.achievements.has("king") and gs.achievements.has("completed") and gs.achievements.has("flawless_boss"), "Slijmkoning verslagen, uitgespeeld en zonder te sterven in dat gevecht")
	check(not gs.achievements.has("speedrun"), "maar na 66 minuten is het geen 'Bliksemheld'")
	gs.play_time = 3000.0
	gs.check_achievements()
	check(gs.achievements.has("speedrun"), "met een snelle tijd (50 minuten) wel")

	# Geheimen.
	check(Achievements.info("slept").get("secret", false) and not gs.achievements.has("slept"), "'Welterusten' is geheim")
	gs.set_flag("wereld_geslapen")
	gs.coins = 149
	gs.check_achievements()
	check(gs.achievements.has("slept") and not gs.achievements.has("rich"), "slapen geeft het geheim; 149 munten nog niet")
	gs.add_coins(1)
	await frames(3)
	check(gs.achievements.has("rich"), "150 munten: 'Goudkoorts' (vanzelf gecontroleerd)")
	check(unlocked.has("rich") and unlocked.has("slept") and unlocked.size() == gs.achievements.size(), "elke prestatie gaf precies een melding (%d)" % unlocked.size())
	gs.achievement_unlocked.disconnect(listener)

	# Meerdere meldingen achter elkaar.
	# Na het einde (game_completed hierboven) begint Bram bij de start over de Diepte. Zolang dat gesprek open is,
	# wachten de meldingen; klik het dus eerst weg.
	await finish_dialogue()
	gs.achievement_queue.clear()
	banner.time = 0.0
	await frames(2)
	var first: String = Achievements.ACHIEVEMENTS.keys()[0]
	gs.achievements.erase(first)
	gs.meta_achievements.erase(first)
	var second: String = Achievements.ACHIEVEMENTS.keys()[1]
	gs.achievements.erase(second)
	gs.meta_achievements.erase(second)
	gs.unlock_achievement(first)
	gs.unlock_achievement(second)
	await frames(3)
	check(gs.achievement_queue == [second] and banner.name_label.text == Achievements.info(first)["name"], "twee tegelijk: een voor een, de eerste staat in beeld")
	await frames(60 * 4 + 30)
	check(banner.name_label.text == Achievements.info(second)["name"], "daarna de tweede")
	await frames(60 * 5)
	# Heel veel tegelijk (bijvoorbeeld na het laden van een oude opslag) gaat sneller.
	var many: Array = Achievements.ACHIEVEMENTS.keys().slice(0, 6)
	for id: String in many:
		gs.achievements.erase(id)
		gs.meta_achievements.erase(id)
		gs.unlock_achievement(id)
	await frames(3)
	check(near(banner.duration, banner.SHOW_TIME_RUSH) and gs.achievement_queue.size() == 5, "bij zes tegelijk gaan de meldingen sneller (%.1f seconden per stuk)" % banner.duration)
	await frames(int(banner.SHOW_TIME_RUSH * 60.0 * 4.0) + 40)
	check(gs.achievement_queue.size() <= 1 and near(banner.duration, banner.SHOW_TIME), "als er nog maar twee wachten, krijgen ze weer de gewone tijd")
	gs.achievement_queue.clear()
	banner.time = 0.0


func test_achievement_checks() -> void:
	print("Wanneer wordt er gecontroleerd")
	fresh_game()
	await load_map("village")
	# Via een signaal: voorwerpen.
	gs.check_achievements()
	gs.give("boots", 1, true)
	await frames(2)
	check(gs.achievements.has("boots"), "een voorwerp krijgen (items_changed) geeft meteen een controle")
	# Via een vlag.
	gs.set_flag("golem_ruins")
	gs.set_flag("golem_cave")
	await frames(2)
	check(gs.achievements.has("golems"), "een vlag zetten geeft meteen een controle")
	# Op een rustig interval: iets wat zonder signaal verandert.
	gs.flags["boss_defeated"] = true
	await frames(30)
	check(not gs.achievements.has("king"), "zonder aanleiding wordt er niet elk beeldje gecontroleerd")
	await frames(int(gs.ACHIEVEMENT_INTERVAL * 60.0) + 10)
	check(gs.achievements.has("king"), "maar op een rustig interval (%d seconden) wel" % int(gs.ACHIEVEMENT_INTERVAL))
	# Buiten het spel niet.
	gs.in_game = false
	gs.kills = 500
	gs.register_kill("slime")
	await frames(int(gs.ACHIEVEMENT_INTERVAL * 60.0) + 10)
	check(not gs.achievements.has("slayer_200"), "op het titelscherm (buiten het spel) wordt niets behaald")
	gs.in_game = true
	await frames(5)
	check(gs.achievements.has("slayer_200"), "terug in het spel gebeurt het alsnog")

	# Doodgaan.
	fresh_game()
	await frames(2)
	gs.save_game(world.player.global_position)
	gs.hp = 1
	gs.hurt(1)
	check(gs.deaths == 1 and gs.boss_deaths == 0 and gs.ended, "doodgaan wordt geteld")
	check(int(read_save().get("deaths", 0)) == 1, "en meteen in de opslag gezet, zodat herladen het niet wist")
	check(gs.load_game() and gs.deaths == 1 and gs.boss_deaths == 0 and not gs.ended, "na herladen (R) staat de nederlaag er nog")
	gs.in_game = true
	gs.set_flag("boss_started")
	gs.hp = 1
	gs.hurt(1)
	check(gs.deaths == 2 and gs.boss_deaths == 1, "doodgaan tijdens het baasgevecht telt apart")
	check(gs.load_game() and gs.boss_deaths == 1 and gs.deaths == 2, "ook die blijft na herladen")
	gs.in_game = true
	gs.set_flag("boss_defeated")
	gs.check_achievements()
	check(not gs.achievements.has("flawless_boss"), "met een nederlaag in het baasgevecht geen 'In één keer'")
	gs.new_game()
	check(gs.deaths == 0 and gs.boss_deaths == 0 and gs.rolls == 0 and gs.kills_by.is_empty() and gs.talked.is_empty() and gs.potions_drunk == 0, "een nieuw spel zet alle tellers terug")
	gs.in_game = true
	# Zonder opslagbestand mag doodgaan geen fout geven.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.SAVE_PATH))
	gs.hp = 1
	gs.hurt(1)
	check(gs.deaths == 1 and gs.ended, "doodgaan zonder opslag geeft geen fout")
	# Een nederlaag in een nieuw spel verandert niets aan het opslagbestand van het oude spel.
	gs.new_game()
	gs.in_game = true
	gs.deaths = 4
	gs.boss_deaths = 2
	gs.save_game(world.player.global_position)
	gs.new_game() # "Nieuw spel" op het titelscherm: het oude bestand blijft staan
	gs.in_game = true
	gs.hp = 1
	gs.hurt(1)
	var old_save := read_save()
	check(gs.deaths == 1 and int(old_save.get("deaths", 0)) == 4 and int(old_save.get("boss_deaths", 0)) == 2, "doodgaan in een nieuw spel laat de tellers van het oude spel met rust")
	gs.save_game(world.player.global_position)
	gs.ended = false
	gs.hp = 1
	gs.hurt(1)
	check(int(read_save().get("deaths", 0)) == 2, "maar zodra dit spel is opgeslagen, telt het wel in het eigen bestand")
	gs.new_game()
	gs.in_game = true


func test_achievement_persistence() -> void:
	print("Prestaties bewaren")
	fresh_game()
	await load_map("village")
	gs.unlock_achievement("boots")
	gs.unlock_achievement("slept")
	var config := ConfigFile.new()
	check(config.load(gs.META_PATH) == OK and config.has_section_key("achievements", "boots") and config.has_section_key("achievements", "slept"), "behaalde prestaties staan meteen in user://meta.cfg")
	gs.save_game(world.player.global_position)
	var saved: Dictionary = read_save()
	check("boots" in saved.get("achievements", []) and "slept" in saved.get("achievements", []), "en in de savegame")
	gs.new_game()
	check(gs.achievements.has("boots") and gs.achievements.has("slept") and gs.achievements.size() == 2, "een nieuw spel houdt de prestaties (uit de meta)")
	check(gs.achievement_queue.is_empty(), "maar toont ze niet opnieuw")
	gs.in_game = true
	var again: Array[String] = []
	var listener := func(id: String) -> void: again.append(id)
	gs.achievement_unlocked.connect(listener)
	gs.check_achievements()
	check(again.is_empty(), "een al behaalde prestatie geeft geen nieuwe melding in een nieuw spel")
	gs.achievement_unlocked.disconnect(listener)

	# De meta is weg (bijvoorbeeld een andere computer): de savegame brengt ze terug.
	gs.meta_achievements = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.META_PATH))
	gs.new_game()
	check(gs.achievements.is_empty(), "zonder meta en zonder opslag begin je zonder prestaties")
	check(gs.load_game() and gs.achievements.has("boots") and gs.achievements.has("slept"), "laden uit de savegame brengt ze terug")
	check(config.load(gs.META_PATH) == OK and config.has_section_key("achievements", "boots"), "en ze komen weer in de meta")
	gs.in_game = true

	# De savegame is oud of mist de meta: de meta vult aan.
	var data := read_save()
	data.erase("achievements")
	var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	gs.unlock_achievement("rich")
	gs.new_game()
	check(gs.load_game() and gs.achievements.has("rich") and gs.achievements.has("boots"), "een savegame zonder prestaties krijgt ze uit de meta")

	# Een prestatie die niet meer bestaat blijft in de meta maar telt niet mee.
	gs.meta_achievements["bestaat_niet_meer"] = true
	gs._save_meta()
	gs.new_game()
	check(Achievements.count_owned(gs.achievements) == 3 and gs.achievements.has("bestaat_niet_meer"), "onbekende prestaties worden niet geteld en geven geen fout")
	gs.meta_achievements.erase("bestaat_niet_meer")
	gs._save_meta()

	# Een GameState die net opstart (het spel gaat open) leest de meta meteen.
	var starting: Node = load("res://scripts/core/game_state.gd").new()
	root.add_child(starting)
	check(starting.meta_achievements.has("boots") and starting.meta_achievements.has("rich") and starting.achievements.has("boots"), "bij het opstarten van het spel zijn de prestaties van eerdere keren er meteen")
	starting.free()

	# Een kapotte meta mag het spel niet stoppen.
	var broken := FileAccess.open(gs.META_PATH, FileAccess.WRITE)
	broken.store_string("dit is geen [geldig bestand")
	broken.close()
	gs.meta_achievements = {}
	gs._load_meta()
	check(gs.meta_achievements.is_empty(), "een kapotte meta geeft geen prestaties en geen fout")
	gs.unlock_achievement("boots")
	check(config.load(gs.META_PATH) == OK and config.has_section_key("achievements", "boots"), "bij de volgende prestatie wordt hij netjes opnieuw geschreven")

	# Prestaties die behaald worden als er geen beeld is, komen in beeld zodra het er weer is.
	await stop_world()
	fresh_game()
	gs.unlock_achievement("slept")
	check(gs.achievement_queue == ["slept"], "zonder beeld wacht de melding in de wachtrij")
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await wait_for_map_name()
	check(gs.achievement_queue.is_empty() and world.hud.achievement_banner.is_showing() and world.hud.achievement_banner.name_label.text == Achievements.info("slept")["name"], "zodra het spel er weer is, wordt hij getoond")
	await frames(60 * 5)



func test_ending_achievements() -> void:
	print("Het einde van het spel en de prestaties")
	fresh_game()
	await load_map("temple")
	gs.set_flag("boss_defeated")
	gs.play_time = 100.0
	var saved_before := read_save().duplicate()
	world._on_ending() # begint met zwart worden; de rest van het einde volgt vanzelf
	check(gs.achievements.has("king") and gs.achievements.has("completed") and gs.achievements.has("speedrun") and gs.achievements.has("flawless_boss"), "meteen bij het einde zijn de prestaties van het einde behaald")
	var saved := read_save()
	check("completed" in saved.get("achievements", []) and "speedrun" in saved.get("achievements", []) and saved != saved_before, "en ze staan in de opslag van het einde")
	check(gs.achievement_queue.size() == 4, "ze wachten op een scherm om getoond te worden (%d)" % gs.achievement_queue.size())
	await frames(30)
	check(gs.achievement_queue.size() == 4, "tijdens het zwart worden verdwijnen ze niet achter het zwart")
	await frames(120)
	check(current_scene != null and current_scene.scene_file_path.ends_with("ending.tscn"), "daarna begint het eindscherm")
	var ending_banner: Node = null
	for child in current_scene.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("achievement_banner.gd"):
			ending_banner = child
	check(ending_banner != null and ending_banner.is_showing() and gs.achievement_queue.size() == 3, "in het eindscherm komen ze een voor een in beeld")
	check(ending_banner.duration == ending_banner.SHOW_TIME_RUSH, "en omdat het er vier zijn gaat het snel")
	current_scene.queue_free()
	await frames(3)
	gs.transitioning = false
	await start_world()


# --- Beestenboek -----------------------------------------------------------------------------------

func test_bestiary() -> void:
	print("Beestenboek")
	fresh_game()
	await load_map("village")
	check(Enemies.ENEMIES.keys().slice(0, BASE_KINDS.size()) == BASE_KINDS, "de volgorde is vast: eerst de basisvijanden, daarna de uitbreidingen")
	var known_any := false
	for kind: String in Enemies.ENEMIES:
		if MenuPages.is_known(kind):
			known_any = true
	check(not known_any, "in het begin is geen enkele vijand bekend")
	var slime: Node2D = world.spawn_enemy("slime", tile_pos(20, 14))
	slime.set_physics_process(false)
	slime.hurt(1, Vector2.RIGHT)
	check(not MenuPages.is_known("slime") and gs.kills == 0, "een gewonde vijand is nog niet verslagen")
	slime.hurt(5, Vector2.RIGHT)
	await frames(2)
	check(MenuPages.is_known("slime") and gs.kills_by["slime"] == 1 and gs.kills == 1, "een verslagen slijm is bekend, geteld per soort en in totaal")
	check(not MenuPages.is_known("bat") and not MenuPages.is_known("king"), "andere vijanden blijven onbekend")
	var bat: Node2D = world.spawn_enemy("bat", tile_pos(22, 14))
	bat.set_physics_process(false)
	bat.hurt(99, Vector2.RIGHT)
	bat.hurt(99, Vector2.RIGHT) # een dode vijand telt niet dubbel
	await frames(2)
	check(MenuPages.is_known("bat") and gs.kills_by["bat"] == 1 and gs.kills == 2, "een dode vijand telt niet nog een keer mee")

	# Teksten.
	check(MenuPages._damage_text({"damage": 1}) == "1 hartje" and MenuPages._damage_text({"damage": 2}) == "2 hartjes", "schade in goed Nederlands (hartje/hartjes)")
	check(MenuPages._damage_text(Enemies.info("golem")) == "1 hartje (klap: 2)", "een golem heeft ook een klap")
	check(MenuPages._damage_text({}) == "1 hartje", "een vijand zonder schadegegevens geeft geen fout")
	check(MenuPages._drop_text(["coin", 1.0, 2]).begins_with("Munt x2 (altijd)") and MenuPages._drop_text(["heart", 0.12, 1]) == "Hartje (zelden)", "wat een vijand laat vallen, met woorden voor de kans")
	check(MenuPages._drop_text(["gel", 0.4, 1]) == "Slijmgel (vaak)" and MenuPages._drop_text(["potion", 0.15, 1]) == "Helddrank (soms)", "vaak en soms")
	var descs_ok := true
	for kind in BASE_KINDS:
		var desc: String = Enemies.info(kind).get("desc", "")
		if desc.length() < 20 or desc.length() > 140:
			descs_ok = false
			print("       beschrijving van ", kind, " mist of is raar: ", desc)
	check(descs_ok, "elke basisvijand heeft een korte beschrijving")

	# Een uitbreiding met en zonder beschrijving.
	var originals := Enemies.ENEMIES.duplicate()
	Enemies.ENEMIES["wereld_test_a"] = {"name": "Testbeest", "hp": 4, "damage": 1, "behavior": "chase", "speed": 30.0, "chase_speed": 40.0, "sight": 100.0, "sheet": "slime_red", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 10.0, "drops": [], "desc": "Een beest voor de test."}
	Enemies.ENEMIES["wereld_test_b"] = {"name": "Zonder tekst", "hp": 2, "damage": 3, "behavior": "chase", "speed": 30.0, "chase_speed": 40.0, "sight": 100.0, "sheet": "skeleton", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 10.0, "drops": [["coin", 1.0, 1]]}
	check(Enemies.ENEMIES.keys().slice(0, BASE_KINDS.size()) == BASE_KINDS and Enemies.ENEMIES.keys()[originals.size()] == "wereld_test_a" and Enemies.ENEMIES.keys()[originals.size() + 1] == "wereld_test_b", "uitbreidingen komen erachter, in hun eigen volgorde")
	var menu: Node = world.menu_ui
	press("wereld_beestenboek")
	await frames(3)
	check(menu.active and menu.tab == menu.TAB_BESTIARY, "B opent het beestenboek")
	var count: int = Enemies.ENEMIES.size()
	for i in count + 3:
		press("ui_down")
		await frames(2)
	check(menu.bestiary_selected == count - 1, "omlaag blijft bij de laatste (%d)" % menu.bestiary_selected)
	await frames(3)
	check(not MenuPages.is_known("wereld_test_b"), "een onbekende uitbreidingsvijand blijft een silhouet (???)")
	world.spawn_enemy("wereld_test_b", tile_pos(21, 14)).hurt(99, Vector2.RIGHT)
	await frames(4)
	check(MenuPages.is_known("wereld_test_b"), "na een overwinning is ook die bekend")
	check(Enemies.info("wereld_test_b").get("desc", "") == "", "zonder beschrijving tonen we niets (en geen fout)")
	for i in count + 3:
		press("ui_up")
		await frames(2)
	check(menu.bestiary_selected == 0 and menu.bestiary_scroll == 0, "helemaal omhoog: eerste vijand, bovenaan de lijst")
	press("pause")
	await frames(3)
	# Veel vijanden: de lijst scrolt mee.
	for i in 12:
		Enemies.ENEMIES["wereld_test_extra_%d" % i] = Enemies.ENEMIES["wereld_test_a"]
	press("wereld_beestenboek")
	await frames(3)
	var many: int = Enemies.ENEMIES.size()
	for i in many:
		press("ui_down")
		await frames(2)
	var visible := int((MenuPages.LIST_BOTTOM - MenuPages.LIST_TOP) / MenuPages.BEAST_ROW)
	check(menu.bestiary_selected == many - 1 and menu.bestiary_scroll > 0 and menu.bestiary_scroll <= menu.bestiary_selected and menu.bestiary_selected < menu.bestiary_scroll + visible, "met %d vijanden scrolt de lijst en blijft de keuze in beeld (rij %d, scroll %d)" % [many, menu.bestiary_selected, menu.bestiary_scroll])
	press("pause")
	await frames(3)
	Enemies.ENEMIES.clear()
	Enemies.ENEMIES.merge(originals)
	check(Enemies.ENEMIES.size() == originals.size() and not Enemies.ENEMIES.has("wereld_test_a"), "de testvijanden zijn weer weg")
	menu.bestiary_selected = 0
	menu.bestiary_scroll = 0

	check(MenuPages.follow(0, 0, 8, 20) == 0 and MenuPages.follow(9, 0, 8, 20) == 2 and MenuPages.follow(3, 6, 8, 20) == 3 and MenuPages.follow(19, 0, 8, 20) == 12, "scrollen: de keuze blijft altijd in beeld")
	check(MenuPages.follow(0, 5, 8, 3) == 0 and MenuPages.follow(2, 0, 8, 3) == 0, "korte lijsten scrollen niet")


# --- Menu -----------------------------------------------------------------------------------------

func test_menu_navigation() -> void:
	print("Menu: tabbladen en toetsen")
	fresh_game()
	await load_map("village")
	var menu: Node = world.menu_ui
	var tabs: int = menu.TAB_COUNT
	var names: Array = menu.tab_titles()
	check(tabs >= 5 and names[0] == "Voorwerpen" and names[menu.TAB_QUESTS] == "Opdrachten" and names[menu.TAB_MAP] == "Kaart" and names[menu.TAB_ACHIEVEMENTS] == "Prestaties" and names[menu.TAB_BESTIARY] == "Beestenboek", "de tabbladen: voorwerpen, opdrachten, kaart, prestaties en beestenboek (%d)" % tabs)
	press("menu")
	await frames(3)
	check(menu.active and menu.tab == 0 and paused, "I opent het menu (het spel staat stil)")
	for step in tabs:
		press("ui_right")
		await frames(2)
		check(menu.tab == (step + 1) % tabs, "pijl rechts: tabblad %d" % ((step + 1) % tabs))
	press("ui_left")
	await frames(2)
	check(menu.tab == tabs - 1, "pijl links vanaf het eerste tabblad: naar het laatste")
	press("ui_left")
	await frames(2)
	check(menu.tab == tabs - 2, "pijl links: een tabblad terug")

	# Snelkoppelingen.
	menu._set_tab(menu.TAB_MAP)
	press("wereld_prestaties")
	await frames(2)
	check(menu.active and menu.tab == menu.TAB_ACHIEVEMENTS, "T gaat naar de prestaties")
	press("wereld_prestaties")
	await frames(2)
	check(not menu.active and not paused, "T op het prestatietabblad sluit het menu")
	press("wereld_prestaties")
	await frames(3)
	check(menu.active and menu.tab == menu.TAB_ACHIEVEMENTS, "T opent de prestaties vanuit het spel")
	press("wereld_beestenboek")
	await frames(2)
	check(menu.active and menu.tab == menu.TAB_BESTIARY, "B op een ander tabblad gaat naar het beestenboek")
	press("wereld_beestenboek")
	await frames(2)
	check(not menu.active, "B nog een keer sluit het menu")
	press("wereld_beestenboek")
	await frames(3)
	check(menu.active and menu.tab == menu.TAB_BESTIARY, "B opent het beestenboek vanuit het spel")
	press("quests")
	await frames(2)
	check(menu.tab == menu.TAB_QUESTS, "Q gaat naar opdrachten")
	press("map")
	await frames(2)
	check(menu.tab == menu.TAB_MAP, "N gaat naar de kaart")
	press("menu")
	await frames(3)
	check(not menu.active and not paused, "I sluit het menu weer")

	# Controller: de schouderknoppen bladeren.
	press_pad(JOY_BUTTON_LEFT_SHOULDER)
	await frames(3)
	check(menu.active and menu.tab == menu.TAB_QUESTS, "linker schouderknop opent buiten het menu de opdrachten (zoals altijd)")
	press_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(2)
	check(menu.tab == menu.TAB_QUESTS + 1, "in het menu bladert de rechter schouderknop naar rechts")
	menu._set_tab(tabs - 1)
	press_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(2)
	check(menu.tab == 0, "na het laatste tabblad weer rond naar Voorwerpen")
	press_pad(JOY_BUTTON_LEFT_SHOULDER)
	await frames(2)
	check(menu.tab == tabs - 1, "linker schouderknop bladert terug (ook rond)")
	menu._set_tab(menu.TAB_ACHIEVEMENTS)
	press("ui_down")
	await frames(2)
	check(menu.achievement_selected == 1, "d-pad omlaag: volgende prestatie")
	press("interact")
	await frames(2)
	check(menu.active and menu.tab == menu.TAB_ACHIEVEMENTS, "A op een prestatie doet niets geks")
	press("pause")
	await frames(3)
	check(not menu.active and not paused and gs.ui_owners.is_empty(), "Esc sluit het menu en laat het spel weer lopen")

	# Prestaties scrollen.
	press("wereld_prestaties")
	await frames(3)
	menu.achievement_selected = 0
	menu.achievement_scroll = 0
	var total: int = Achievements.ACHIEVEMENTS.size()
	var visible := int((MenuPages.LIST_BOTTOM - MenuPages.LIST_TOP) / MenuPages.ACHIEVEMENT_ROW)
	check(total > visible, "er zijn meer prestaties (%d) dan er in beeld passen (%d), dus er moet gescrold worden" % [total, visible])
	var always_visible := true
	for i in total + 5:
		press("ui_down")
		await frames(2)
		if menu.achievement_selected < menu.achievement_scroll or menu.achievement_selected >= menu.achievement_scroll + visible:
			always_visible = false
	check(always_visible and menu.achievement_selected == total - 1 and menu.achievement_scroll == total - visible, "omlaag door alle %d prestaties: de keuze blijft in beeld, de lijst eindigt netjes" % total)
	for i in total + 5:
		press("ui_up")
		await frames(2)
	check(menu.achievement_selected == 0 and menu.achievement_scroll == 0, "weer omhoog: begin van de lijst, niet verder")
	press("pause")
	await frames(3)

	# Het menu onthoudt geen oude keuzes in de kaart.
	press("map")
	await frames(3)
	check(not menu.travel_confirm and menu.travel_message == "", "het kaarttabblad begint zonder vragen of meldingen")
	press("pause")
	await frames(3)

	# Het menu opent niet midden in een gesprek, winkel of overgang.
	gs.start_dialogue("greta_intro")
	await frames(3)
	press("menu")
	press("wereld_prestaties")
	press("wereld_beestenboek")
	await frames(3)
	check(not menu.active, "tijdens een gesprek opent geen enkel menutoets het menu")
	await finish_dialogue()
	gs.transitioning = true
	press("wereld_prestaties")
	await frames(3)
	check(not menu.active, "tijdens een overgang ook niet")
	gs.transitioning = false

	# Het menu tekent alle tabbladen zonder fouten (ook met veel gegevens).
	gs.kills_by = {"slime": 4, "king": 1}
	gs.achievements = {"first_blood": true, "slept": true}
	var draws := [0]
	var counter := func() -> void: draws[0] += 1
	menu.content.draw.connect(counter)
	press("menu")
	await frames(3)
	for tab in tabs:
		await frames(4)
		press("ui_right")
	check(draws[0] >= tabs * 2, "elk tabblad wordt getekend (%d keer)" % draws[0])
	menu.content.draw.disconnect(counter)
	press("pause")
	await frames(3)
	check(not menu.active and not paused, "en alles is netjes gesloten")


# --- Opslaan en laden -------------------------------------------------------------------------------

func test_saving() -> void:
	print("Opslaan en laden van de nieuwe velden")
	fresh_game()
	await load_map("village")
	gs.day_time = 0.77
	gs.day_count = 4
	gs.kills = 12
	gs.kills_by = {"slime": 9, "bat": 3}
	gs.rolls = 31
	gs.potions_drunk = 6
	gs.deaths = 2
	gs.boss_deaths = 1
	gs.talked = {"bram": true, "pim": true}
	gs.unlock_achievement("boots")
	gs.set_flag("altaar_village_22_12")
	check(gs.save_game(world.player.global_position), "opslaan lukt")
	var data := read_save()
	for field in ["day_time", "day_count", "kills_by", "rolls", "potions_drunk", "deaths", "boss_deaths", "talked", "achievements"]:
		if not data.has(field):
			check(false, "het veld %s staat niet in de opslag" % field)
	check(data["version"] == gs.SAVE_VERSION, "de versie van het opslagformaat is niet veranderd")
	gs.new_game()
	check(near(gs.day_time, Daynight.START) and gs.kills_by.is_empty() and gs.rolls == 0 and gs.talked.is_empty(), "een nieuw spel begint leeg")
	check(gs.load_game(), "laden lukt")
	check(near(gs.day_time, 0.77) and gs.day_count == 4, "de klok is terug (tijd en dag)")
	check(gs.kills == 12 and gs.kills_by == {"slime": 9, "bat": 3}, "verslagen vijanden per soort zijn terug (als gehele getallen)")
	check(typeof(gs.kills_by["slime"]) == TYPE_INT and typeof(gs.day_count) == TYPE_INT and typeof(gs.rolls) == TYPE_INT, "en het zijn echte getallen, geen kommagetallen")
	check(gs.rolls == 31 and gs.potions_drunk == 6 and gs.deaths == 2 and gs.boss_deaths == 1, "rollen, drankjes en nederlagen zijn terug")
	check(gs.talked.has("bram") and gs.talked.has("pim") and gs.talked.size() == 2, "met wie je gepraat hebt is terug")
	check(gs.achievements.has("boots") and gs.flag("altaar_village_22_12") and FastTravel.discovered_altars().size() == 1, "prestaties en ontdekte altaren zijn terug")
	check(Daynight.phase_at(gs.day_time) == "nacht", "de tijd van de dag klopt met wat je opsloeg")

	# Het weer is na het laden hetzelfde als eerst.
	var before: bool = Daynight.raining("random", gs.day_count, gs.day_time)
	gs.new_game()
	gs.load_game()
	check(Daynight.raining("random", gs.day_count, gs.day_time) == before, "het weer na laden is hetzelfde als daarvoor")

	# Een oude opslag zonder de nieuwe velden.
	var old := {
		"version": 1, "map": "forest", "pos": [200.0, 300.0], "hp": 4, "coins": 33,
		"inventory": {"potion": 2}, "flags": {"met_greta": true}, "quests": {}, "weapon": "iron",
		"play_time": 100.0, "kills": 7,
	}
	var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	gs.meta_achievements = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.META_PATH))
	gs.new_game()
	check(gs.load_game(), "een oude opslag (zonder wereld-velden) laadt gewoon")
	check(gs.coins == 33 and gs.kills == 7 and gs.weapon == "iron" and gs.map_id == "forest", "alles wat er al was is goed")
	check(near(gs.day_time, Daynight.START) and gs.day_count == 0 and gs.kills_by.is_empty() and gs.rolls == 0 and gs.potions_drunk == 0 and gs.deaths == 0 and gs.talked.is_empty() and gs.achievements.is_empty(), "en de nieuwe velden hebben vaste beginwaarden")
	gs.in_game = true
	gs.check_achievements()
	check(gs.achievements.has("first_blood"), "met 7 verslagen vijanden uit de oude opslag... (kills telt zelf mee) wordt 'Eerste klap' alsnog behaald")
	# Een oude opslag van na de kat, de golems en de koning: die komen nooit meer terug, dus dat vullen we aan.
	var later := old.duplicate(true)
	later["flags"] = {"cat_found": true, "cat_home": true, "golem_ruins": true, "golem_cave": true, "boss_defeated": true}
	file = FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(later))
	file.close()
	check(gs.load_game() and gs.talked.has("muis_bos") and gs.talked.size() == 1, "de Muis in het bos (al weg) telt als gesproken, dus 'Gezellig babbelen' kan nog")
	check(gs.kills_by.get("golem", 0) == 2 and gs.kills_by.get("king", 0) == 1 and gs.kills_by.size() == 2, "de golems en de Slijmkoning staan in het beestenboek, dus 'Beestenkenner' kan nog")

	# Rare waarden in een opslag.
	var odd := old.duplicate()
	odd["day_time"] = 7.25
	odd["kills_by"] = {"slime": 2.0}
	odd["talked"] = ["bram", "greta"]
	odd["achievements"] = ["boots", "bestaat_niet"]
	file = FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(odd))
	file.close()
	check(gs.load_game(), "een opslag met rare waarden laadt")
	check(near(gs.day_time, 0.25) and gs.kills_by == {"slime": 2} and gs.talked.size() == 2 and gs.achievements.has("boots"), "een tijd boven 1 wordt teruggebracht tot 0..1 en lijsten worden goed gelezen")

	# Terug naar de wereld laden na het opslaan: je begint op dezelfde tijd.
	gs.new_game()
	gs.in_game = true
	gs.day_time = 0.66
	world.load_map("village", "start")
	gs.save_game(world.player.global_position)
	gs.new_game()
	gs.load_game()
	gs.in_game = true
	check(near(gs.day_time, 0.66), "de wereld herstart op de opgeslagen tijd")


func _run() -> void:
	gs = root.get_node("GameState")
	sound = root.get_node("Sound")
	FastTravel = load("res://scripts/core/fast_travel.gd")
	MenuPages = load("res://scripts/ui/menu_pages.gd")
	back_up_user_files()
	test_clock_rules()
	test_clock_in_game_state()
	test_weather_rules()
	test_data()
	test_achievement_data()
	test_map_reachability()
	await start_world()
	test_conditions()
	await test_day_night_in_world()
	await test_sleep()
	await test_rain()
	await test_fast_travel()
	await test_fast_travel_menu()
	await test_fast_travel_dying_king()
	await test_achievements()
	await test_achievement_checks()
	await test_achievement_persistence()
	await test_ending_achievements()
	await test_bestiary()
	await test_menu_navigation()
	await test_saving()
	if is_instance_valid(world):
		world.queue_free()
	await frames(3)
	gs.new_game()
	restore_user_files()
	gs.meta_achievements = {}
	gs._load_meta()
	gs.new_game()

	print("")
	if failures == 0:
		print("WERELD TEST OK")
		quit(0)
	else:
		print("WERELD TEST: %d fout(en)" % failures)
		quit(1)
