extends SceneTree
## Test van het IJsdal (spoor "sneeuw"): kaart, sneeuwklimaat, doorgang met het Dauwbos, winterse
## grondstoffen en recepten, beide opdrachten, de personages en het altaar.
##
##   sh tools/run_tests.sh /pad/naar/godot      (alle tests), of alleen deze:
##   XDG_DATA_HOME=.testdata godot --headless --fixed-fps 60 --path . -s tests/ijsdal_test.gd
##
## Zonder XDG_DATA_HOME schrijft de test in de echte opslagmap van het spel (en overschrijft hij je opgeslagen spel).

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Items := preload("res://scripts/data/items.gd")
const Npcs := preload("res://scripts/data/npcs.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Art := preload("res://scripts/core/art.gd")
const Daynight := preload("res://scripts/core/daynight.gd")
const Beroepen := preload("res://scripts/data/ext/beroepen.gd")
const Professions := preload("res://scripts/core/professions.gd")
const Sneeuw := preload("res://scripts/data/ext/sneeuw.gd")

const NEW_TILES := ["snow", "snow_tufts", "snow_bush", "pine", "ice"]
const WINTER_ITEMS := ["prof_ijsbloem", "prof_winterbes", "prof_dennenhout", "prof_ijskristal", "prof_frost_tonic", "prof_winter_gloed"]
const WINTER_RESOURCES := ["winterherbs", "frostberries", "pine_stump", "ice_vein"]
## De gemiddelde kleur van elke nieuwe tegel in tiles.png: zo zie je of het plaatje nog bij de volgorde in NAMES past.
const TILE_COLORS := {
	"snow": Color("e4edf7"), "snow_tufts": Color("e1eaf3"), "snow_bush": Color("b9c9cb"),
	"pine": Color("91a9a7"), "ice": Color("a4d2e9"),
}

var failures := 0
var gs: Node
var world: Node2D
var seen_lines: Array[String] = [] # de regels van het laatste gesprek (zie talk)


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	root.push_input(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	root.push_input(up)


func tile_center(pos: Array) -> Vector2:
	return Vector2(float(pos[0]) * 32.0 + 16.0, float(pos[1]) * 32.0 + 16.0)


func put_player(pos: Vector2) -> void:
	world.player.global_position = pos
	world.player.velocity = Vector2.ZERO
	world.player.invuln = 999.0
	await frames(3)


func objects(map_id: String, type: String) -> Array:
	return Maps.get_map(map_id)["objects"].filter(func(o: Dictionary) -> bool: return o["type"] == type)


## Loopt door de doorgang naar `to_map` en controleert dat we daar aankomen.
func through_portal(to_map: String) -> void:
	var from_map: String = gs.map_id
	for obj: Dictionary in objects(from_map, "portal"):
		if obj["to"] == to_map:
			var size: Array = obj.get("size", [1, 1])
			var rect := Rect2(Vector2(obj["pos"][0], obj["pos"][1]) * 32.0, Vector2(size[0], size[1]) * 32.0)
			await put_player(rect.get_center() + Vector2(0, -96)) # eerst erbuiten, anders gaat hij niet af
			await put_player(rect.get_center())
			await frames(90)
			check(gs.map_id == to_map, "%s -> %s door de doorgang" % [from_map, to_map])
			return
	check(false, "%s heeft een doorgang naar %s" % [from_map, to_map])


## Speelt een gesprek af; `picks` zijn de keuzes (nummer van de zichtbare knop), daarna steeds de laatste.
func talk(talk_id: String, picks: Array = []) -> void:
	seen_lines.clear()
	gs.start_dialogue(talk_id)
	await frames(2)
	var index := 0
	var guard := 0
	while world.dialogue.active and guard < 400:
		guard += 1
		if not world.dialogue.buttons.is_empty():
			var choice: int = picks[index] if index < picks.size() else world.dialogue.buttons.size() - 1
			index += 1
			world.dialogue.buttons[mini(choice, world.dialogue.buttons.size() - 1)].pressed.emit()
		else:
			seen_lines.append(world.dialogue.text_label.text)
			press("interact")
		await frames(2)


## Welk gesprek een personage nu zou voeren (dezelfde regels als in npc.gd).
func pick_talk(npc_id: String) -> String:
	for rule: Dictionary in Npcs.NPCS[npc_id]["rules"]:
		if not rule.has("if") or gs.check_all(rule["if"]):
			return rule["talk"]
	return ""


func talk_npc(npc_id: String, picks: Array = []) -> void:
	gs.note_talked(npc_id) # zoals npc.gd dat doet bij een echt gesprek
	await talk(pick_talk(npc_id), picks)


## Alle begaanbare tegels die je vanaf de startplek kunt bereiken. Personages, borden en kisten zijn obstakels.
func reachable(map_id: String) -> Dictionary:
	var def: Dictionary = Maps.get_map(map_id)
	var rows: Array = def["rows"]
	var blocked := {}
	for obj: Dictionary in def["objects"]:
		if obj["type"] in ["npc", "sign", "chest"]:
			blocked[Vector2i(int(obj["pos"][0]), int(obj["pos"][1]))] = true
	var open := {}
	var start := Vector2i(int(def["spawns"]["start"][0]), int(def["spawns"]["start"][1]))
	var queue: Array[Vector2i] = [start]
	open[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if open.has(next) or next.y < 0 or next.y >= rows.size() or next.x < 0 or next.x >= String(rows[0]).length():
				continue
			if blocked.has(next):
				continue
			if Tiles.is_solid_char(String(rows[next.y])[next.x]):
				continue
			open[next] = true
			queue.append(next)
	return open


## Namen van alles op de kaart dat je niet kunt bereiken.
func unreachable_things(map_id: String) -> Array:
	var open := reachable(map_id)
	var bad: Array = []
	for obj: Dictionary in Maps.get_map(map_id)["objects"]:
		var cell := Vector2i(int(obj["pos"][0]), int(obj["pos"][1]))
		var label := "%s op %s" % [obj["type"], cell]
		match obj["type"]:
			"npc", "sign", "chest", "savepoint":
				var near := false
				for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					near = near or open.has(cell + step)
				if not near:
					bad.append(label)
			"portal":
				var size: Array = obj.get("size", [1, 1])
				var any := false
				for dy in int(size[1]):
					for dx in int(size[0]):
						any = any or open.has(cell + Vector2i(dx, dy))
				if not any:
					bad.append(label)
			"pickup", "enemy":
				if not open.has(cell):
					bad.append(label)
	for spawn_name: String in Maps.get_map(map_id)["spawns"]:
		var spawn: Array = Maps.get_map(map_id)["spawns"][spawn_name]
		if not open.has(Vector2i(int(spawn[0]), int(spawn[1]))):
			bad.append("spawn " + spawn_name)
	return bad


## De gemiddelde kleur van een stuk van een plaatje.
func mean_color(img: Image, rect: Rect2i) -> Color:
	var sum := Vector3.ZERO
	for y in rect.size.y:
		for x in rect.size.x:
			var pixel := img.get_pixel(rect.position.x + x, rect.position.y + y)
			sum += Vector3(pixel.r, pixel.g, pixel.b)
	sum /= float(rect.get_area())
	return Color(sum.x, sum.y, sum.z)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	gs = root.get_node("GameState")
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await frames(3)

	test_data()
	await test_world()
	await test_quests()

	world.queue_free()
	await frames(2)
	print("IJSDAL OK" if failures == 0 else "IJSDAL FAILED: %d" % failures)
	quit(1 if failures else 0)


# --- Deel 1: gegevens en bereikbaarheid ---------------------------------------------------------------

func test_data() -> void:
	print("Gegevens van het IJsdal")
	check(Maps.MAPS.has("ijsdal"), "kaart ijsdal is aangemeld")
	var def: Dictionary = Maps.get_map("ijsdal")
	var rows: Array = def["rows"]
	var same := true
	for row: String in rows:
		same = same and row.length() == String(rows[0]).length()
	check(same, "ijsdal: alle rijen zijn even lang")
	check(String(rows[0]).length() == 50 and rows.size() == 36, "het IJsdal is 50x36 tegels")
	check(def["name"] == "IJsdal" and def.get("music", "") == "village", "naam en muziek van het dorp")
	check(def.get("outdoor", false) and def.get("weather", "") == "snow", "buitengebied waar het altijd sneeuwt")

	var tiles_tex := Art.tex("tiles")
	check(tiles_tex.get_width() == Tiles.NAMES.size() * 16, "tiles.png heeft een plaatje per tegel (%d)" % Tiles.NAMES.size())
	var tiles_ok := true
	for tile_name: String in NEW_TILES:
		tiles_ok = tiles_ok and tile_name in Tiles.NAMES and Tiles.NAMES.find(tile_name) >= 55
		tiles_ok = tiles_ok and Tiles.map_color(tile_name) != Color(0.5, 0.5, 0.55)
	check(tiles_ok, "vijf nieuwe tegels aan het eind van de lijst, met een eigen kleur op het kaartje")
	check(not Tiles.is_solid_name("snow_bush") and Tiles.is_solid_name("pine"), "lage sneeuwstruik is doorloopbaar, den blijft vast")
	check(not Tiles.is_solid_name("snow") and not Tiles.is_solid_name("snow_tufts") and not Tiles.is_solid_name("ice"), "sneeuw en ijs zijn begaanbaar")
	check(Tiles.name_for("z", 1, 1) == "snow" and Tiles.name_for("i", 0, 0) == "ice" and Tiles.name_for("P", 0, 0) == "pine", "de tekens in de kaart kloppen")
	check(Tiles.movement_multiplier("snow") < 1.0, "sneeuw loopt iets trager dan gras")
	check(Tiles.footstep_surface("snow") == "snow", "sneeuw heeft eigen voetstappen")
	var tiles_img := tiles_tex.get_image()
	var order_ok := true
	for tile_name: String in TILE_COLORS:
		var mean := mean_color(tiles_img, Rect2i(Tiles.index_of(tile_name) * 16, 0, 16, 16))
		var want: Color = TILE_COLORS[tile_name]
		order_ok = order_ok and Vector3(mean.r - want.r, mean.g - want.g, mean.b - want.b).length() < 0.025
	check(order_ok, "tiles.png past bij de volgorde in Tiles.NAMES (anders: python tools/make_art.py)")

	check(Daynight.snowing("snow", 1, 0.5) and not Daynight.snowing("rain", 1, 0.5), "het sneeuwt alleen bij sneeuwweer")
	check(Daynight.snow_tint(0.0) == Color.WHITE and Daynight.snow_tint(1.0) != Color.WHITE, "sneeuw geeft een koude tint")
	check(FileAccess.file_exists("res://assets/audio/step_snow.wav"), "het sneeuwstapgeluid bestaat")
	var sound := root.get_node("Sound")
	check(sound.streams.has("step_snow"), "het sneeuwstapgeluid is geladen")

	# Winterse grondstoffen, voorwerpen en recepten.
	for item: String in WINTER_ITEMS:
		check(Items.ITEMS.has(item), "voorwerp geregistreerd: " + item)
	for kind: String in WINTER_RESOURCES:
		check(Beroepen.RESOURCES.has(kind), "grondstof geregistreerd: " + kind)
	check(Beroepen.RECIPES["frost_tonic"]["inputs"] == {"prof_ijsbloem": 2, "prof_winterbes": 2}, "vorstelixer gebruikt ijsbloem en winterbes")
	check(Beroepen.RECIPES["winter_glow"]["output"] == "prof_winter_gloed", "wintergloed is te koken")
	check(Beroepen.RESOURCE_PLACEMENTS.has("ijsdal") and Beroepen.RESOURCE_PLACEMENTS["ijsdal"].size() == 11, "elf grondstofplekken in het IJsdal")

	# Opdrachten, personages en gesprekken.
	check(Quests.QUESTS.has("warmte") and Quests.QUESTS.has("ijswacht"), "twee opdrachten aangemeld")
	for npc_id: String in ["fenna", "roos", "olav"]:
		check(Npcs.NPCS.has(npc_id), "personage geregistreerd: " + npc_id)
	check(Sneeuw.ACHIEVEMENTS.has("ijsdal_ontdekt"), "prestatie Sneeuwvoeten aangemeld")

	var bad := unreachable_things("ijsdal")
	check(bad.is_empty(), "ijsdal: alles is bereikbaar %s" % [bad])

	# De doorgangen tussen het Dauwbos en het IJsdal kloppen aan beide kanten.
	var links_ok := true
	for pair: Array in [["dauwbos", "ijsdal"], ["ijsdal", "dauwbos"]]:
		var found := false
		for obj: Dictionary in objects(pair[0], "portal"):
			if obj["to"] == pair[1]:
				found = true
				links_ok = links_ok and Maps.get_map(pair[1])["spawns"].has(obj.get("spawn", "start"))
		links_ok = links_ok and found
	check(links_ok, "het Dauwbos en het IJsdal hebben doorgangen naar elkaar")


# --- Deel 2: de wereld zelf ----------------------------------------------------------------------------

func test_world() -> void:
	print("De wereld van het IJsdal")
	gs.new_game()
	gs.in_game = true
	world.load_map("dauwbos", "start")
	await frames(5)
	world.player.invuln = 999.0
	await through_portal("ijsdal") # het noordelijke pad in het Dauwbos
	world.player.invuln = 999.0

	# De winterse grondstofnodes staan in de wereld.
	await frames(5)
	var nodes := get_nodes_in_group("profession_resources").filter(func(n: Node) -> bool: return str(n.resource_id).begins_with("ijsdal:"))
	check(nodes.size() == 11, "elf grondstofnodes in het IJsdal (%d)" % nodes.size())
	var kinds := {}
	for node: Node in nodes:
		kinds[node.kind] = true
	for kind: String in WINTER_RESOURCES:
		check(kinds.has(kind), "grondstofnode in de wereld: " + kind)

	# IJsbloemen plukken werkt en geeft ervaring.
	var herb_node: Node = null
	for node: Node in nodes:
		if node.kind == "winterherbs":
			herb_node = node
	check(herb_node != null, "er is een ijsbloemnode")
	if herb_node != null:
		await put_player(herb_node.global_position + Vector2(0, 24))
		herb_node.interact()
		herb_node.advance_harvest(Professions.gather_duration(herb_node.kind))
		check(gs.count("prof_ijsbloem") == 2, "plukken geeft twee ijsbloemen")
		check(Professions.remaining(herb_node.resource_id) > 100, "de ijsbloemnode herstelt later")
		gs.take("prof_ijsbloem", 2)

	# Het altaar ontdekken maakt snel reizen mogelijk.
	var altar: Node = null
	for node: Node in get_nodes_in_group("interactable"):
		if node.get_script() != null and "savepoint" in str(node.get_script().resource_path):
			altar = node
	check(altar != null, "het altaar van IJsdal staat in de wereld")
	if altar != null:
		await put_player(altar.global_position + Vector2(0, 24))
		altar.interact()
		await frames(2)
		check(gs.flag("altaar_ijsdal_25_12"), "het altaar van IJsdal is ontdekt voor snel reizen")

	await through_portal("dauwbos") # en weer terug
	world.player.invuln = 999.0


# --- Deel 3: opdrachten en personages -------------------------------------------------------------------

func test_quests() -> void:
	print("Opdrachten van het IJsdal")
	gs.new_game()
	gs.in_game = true
	world.load_map("ijsdal", "start")
	await frames(5)
	world.player.invuln = 999.0

	# Fenna: de ijsbloemenopdracht.
	await talk_npc("fenna", [0])
	check(gs.quest_state("warmte") == "active", "Fenna geeft de opdracht Warmte voor IJsdal")
	check(gs.flag("fenna_ontmoet"), "Fenna onthoudt dat je haar hebt ontmoet")
	gs.give("prof_ijsbloem", 4, true)
	check(gs.quest_step("warmte") == 0, "bloemen alleen herstellen geen huizen")
	gs.set_flag("lw_heat_west")
	gs.set_flag("lw_heat_east")
	gs.set_flag("lw_heat")
	await frames(2)
	check(gs.quest_step("warmte") == 1, "twee verwarmde huizen zetten de opdracht op de volgende stap")
	var coins_before: int = gs.coins
	await talk_npc("fenna")
	check(gs.quest_state("warmte") == "done", "Fenna rondt de opdracht af")
	check(gs.count("prof_ijsbloem") == 4 and gs.count("gear_bastion_coat") == 1, "wereldherstel geeft een harnas zonder bloemen af te nemen")
	check(gs.coins == coins_before + 30, "Fenna betaalt dertig munten")

	# Roos: de ijswachtopdracht.
	await talk_npc("roos", [0])
	check(gs.quest_state("ijswacht") == "active", "Roos geeft de opdracht De Ijswacht")
	gs.kills_by["slime_blue"] = 4
	gs._refresh_quests()
	check(gs.quest_step("ijswacht") == 1, "vier ijsblauwe slijmen zetten de opdracht op de volgende stap")
	await talk_npc("roos")
	check(gs.quest_state("ijswacht") == "done", "Roos rondt de opdracht af")
	check(gs.count("prof_winter_gloed") == 1, "Roos geeft een wintergloed")

	# Olav vertelt over het dorp en het altaar.
	await talk_npc("olav")
	check(gs.flag("olav_ontmoet"), "Olav onthoudt dat je hem hebt ontmoet")
	check(" ".join(seen_lines).length() > 40, "Olav vertelt zijn verhaal")
	check(gs.check_all([["talked_to_all", ["fenna", "roos", "olav"]]]), "de prestatie Sneeuwvoeten kan vrijspelen")
