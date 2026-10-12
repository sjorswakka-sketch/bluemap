extends SceneTree
## Test van de Dorstvallei (spoor "dorst"): kaart, hitteklimaat, doorgang met het Dauwbos, woestijn-
## grondstoffen, de eerste wilde dieren (vluchtgedrag en jachtbuit), beide opdrachten en het altaar.
##
##   sh tools/run_tests.sh /pad/naar/godot      (alle tests), of alleen deze:
##   XDG_DATA_HOME=.testdata godot --headless --fixed-fps 60 --path . -s tests/dorst_test.gd
##
## Zonder XDG_DATA_HOME schrijft de test in de echte opslagmap van het spel (en overschrijft hij je opgeslagen spel).

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Items := preload("res://scripts/data/items.gd")
const Npcs := preload("res://scripts/data/npcs.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const Art := preload("res://scripts/core/art.gd")
const Daynight := preload("res://scripts/core/daynight.gd")
const Beroepen := preload("res://scripts/data/ext/beroepen.gd")
const Professions := preload("res://scripts/core/professions.gd")
const Dorst := preload("res://scripts/data/ext/dorst.gd")

const NEW_TILES := ["dune_sand", "dune_tufts", "cactus", "sandstone", "oasis_grass"]
const DORST_ITEMS := ["prof_cactusvijg", "prof_zandkruid", "prof_zandsteen", "prof_zandbalsem", "jacht_vlees", "jacht_vacht", "jacht_braadstuk"]
const DORST_RESOURCES := ["cactusfigs", "sandwort", "sandstone_rock"]
const ANIMALS := ["woestijnvos", "zandhaas"]
## De gemiddelde kleur van elke nieuwe tegel in tiles.png: zo zie je of het plaatje nog bij de volgorde in NAMES past.
const TILE_COLORS := {
	"dune_sand": Color("eacf91"), "dune_tufts": Color("e7cc8e"), "cactus": Color("c7c07e"),
	"sandstone": Color("d7b379"), "oasis_grass": Color("69b351"),
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
	print("DORST OK" if failures == 0 else "DORST FAILED: %d" % failures)
	quit(1 if failures else 0)


# --- Deel 1: gegevens en bereikbaarheid ---------------------------------------------------------------

func test_data() -> void:
	print("Gegevens van de Dorstvallei")
	check(Maps.MAPS.has("dorstvallei"), "kaart dorstvallei is aangemeld")
	var def: Dictionary = Maps.get_map("dorstvallei")
	var rows: Array = def["rows"]
	var same := true
	for row: String in rows:
		same = same and row.length() == String(rows[0]).length()
	check(same, "dorstvallei: alle rijen zijn even lang")
	check(String(rows[0]).length() == 48 and rows.size() == 34, "de Dorstvallei is 48x34 tegels")
	check(def["name"] == "Dorstvallei" and def.get("music", "") == "village", "naam en muziek van het oasedorp")
	check(def.get("outdoor", false) and def.get("weather", "") == "heat", "buitengebied waar het altijd snikheet is")

	var tiles_tex := Art.tex("tiles")
	check(tiles_tex.get_width() == Tiles.NAMES.size() * 16, "tiles.png heeft een plaatje per tegel (%d)" % Tiles.NAMES.size())
	var tiles_ok := true
	for tile_name: String in NEW_TILES:
		tiles_ok = tiles_ok and tile_name in Tiles.NAMES and Tiles.NAMES.find(tile_name) >= 60
		tiles_ok = tiles_ok and Tiles.map_color(tile_name) != Color(0.5, 0.5, 0.55)
	check(tiles_ok, "vijf nieuwe tegels aan het eind van de lijst, met een eigen kleur op het kaartje")
	check(Tiles.is_solid_name("cactus") and Tiles.is_solid_name("sandstone"), "cactus en zandsteen zijn vast")
	check(not Tiles.is_solid_name("dune_sand") and not Tiles.is_solid_name("dune_tufts") and not Tiles.is_solid_name("oasis_grass"), "duin en oasegras zijn begaanbaar")
	check(Tiles.name_for("a", 1, 1) == "dune_sand" and Tiles.name_for("g", 0, 0) == "cactus" and Tiles.name_for("L", 0, 0) == "oasis_grass", "de tekens in de kaart kloppen")
	check(Tiles.movement_multiplier("dune_sand") < 1.0, "duinzand loopt iets trager dan gras")
	check(Tiles.footstep_surface("dune_sand") == "sand", "duinzand heeft het zandloopgeluid")
	var tiles_img := tiles_tex.get_image()
	var order_ok := true
	for tile_name: String in TILE_COLORS:
		var mean := mean_color(tiles_img, Rect2i(Tiles.index_of(tile_name) * 16, 0, 16, 16))
		var want: Color = TILE_COLORS[tile_name]
		order_ok = order_ok and Vector3(mean.r - want.r, mean.g - want.g, mean.b - want.b).length() < 0.025
	check(order_ok, "tiles.png past bij de volgorde in Tiles.NAMES (anders: python tools/make_art.py)")

	check(Daynight.scorching("heat", 1, 0.5) and not Daynight.scorching("snow", 1, 0.5), "de hitte hoort alleen bij hitte-weer")
	check(Daynight.heat_tint(0.0) == Color.WHITE and Daynight.heat_tint(1.0) != Color.WHITE, "hitte geeft een warme gloed")

	# Woestijngrondstoffen, jachtbuit en recepten.
	for item: String in DORST_ITEMS:
		check(Items.ITEMS.has(item), "voorwerp geregistreerd: " + item)
	for kind: String in DORST_RESOURCES:
		check(Beroepen.RESOURCES.has(kind), "grondstof geregistreerd: " + kind)
	check(Beroepen.RECIPES["sand_balm"]["inputs"] == {"prof_zandkruid": 2, "prof_cactusvijg": 1}, "zandbalsem gebruikt zandkruid en cactusvijg")
	check(Beroepen.RECIPES["roast_meat"]["inputs"] == {"jacht_vlees": 2, "prof_zandkruid": 1}, "braadstuk gebruikt rauw vlees en zandkruid")
	check(Beroepen.RESOURCE_PLACEMENTS.has("dorstvallei") and Beroepen.RESOURCE_PLACEMENTS["dorstvallei"].size() == 11, "elf grondstofplekken in de Dorstvallei")

	# Het wild: vreedzaam, vluchtend, met buit.
	for kind: String in ANIMALS:
		check(Enemies.ENEMIES.has(kind), "dier geregistreerd: " + kind)
		var data: Dictionary = Enemies.ENEMIES[kind]
		check(data["behavior"] == "animal" and int(data["damage"]) == 0, "%s is vreedzaam wild" % kind)
		check(data["drops"].any(func(d: Array) -> bool: return d[0] == "jacht_vlees"), "%s geeft vlees" % kind)
	check(Enemies.ENEMIES["woestijnvos"]["drops"].any(func(d: Array) -> bool: return d[0] == "jacht_vacht"), "de woestijnvos geeft vacht")

	# Opdrachten, personages en gesprekken.
	check(Quests.QUESTS.has("vellen_en_vlees") and Quests.QUESTS.has("cactusvijgen"), "twee opdrachten aangemeld")
	for npc_id: String in ["jelle", "sana", "nour"]:
		check(Npcs.NPCS.has(npc_id), "personage geregistreerd: " + npc_id)
	check(Dorst.ACHIEVEMENTS.has("dorstvallei_ontdekt"), "prestatie Zandvoeten aangemeld")

	var bad := unreachable_things("dorstvallei")
	check(bad.is_empty(), "dorstvallei: alles is bereikbaar %s" % [bad])

	# De doorgangen tussen het Dauwbos en de Dorstvallei kloppen aan beide kanten.
	var links_ok := true
	for pair: Array in [["dauwbos", "dorstvallei"], ["dorstvallei", "dauwbos"]]:
		var found := false
		for obj: Dictionary in objects(pair[0], "portal"):
			if obj["to"] == pair[1]:
				found = true
				links_ok = links_ok and Maps.get_map(pair[1])["spawns"].has(obj.get("spawn", "start"))
		links_ok = links_ok and found
	check(links_ok, "het Dauwbos en de Dorstvallei hebben doorgangen naar elkaar")


# --- Deel 2: de wereld zelf ----------------------------------------------------------------------------

func test_world() -> void:
	print("De wereld van de Dorstvallei")
	gs.new_game()
	gs.in_game = true
	world.load_map("dauwbos", "start")
	await frames(5)
	world.player.invuln = 999.0
	await through_portal("dorstvallei") # het oostelijke pad in het Dauwbos
	world.player.invuln = 999.0

	# De woestijngrondstoffen staan in de wereld.
	await frames(5)
	var nodes := get_nodes_in_group("profession_resources").filter(func(n: Node) -> bool: return str(n.resource_id).begins_with("dorstvallei:"))
	check(nodes.size() == 11, "elf grondstofnodes in de Dorstvallei (%d)" % nodes.size())
	var kinds := {}
	for node: Node in nodes:
		kinds[node.kind] = true
	for kind: String in DORST_RESOURCES:
		check(kinds.has(kind), "grondstofnode in de wereld: " + kind)

	# Cactusvijgen plukken werkt.
	var fig_node: Node = null
	for node: Node in nodes:
		if node.kind == "cactusfigs":
			fig_node = node
	check(fig_node != null, "er is een cactusvijgnode")
	if fig_node != null:
		await put_player(fig_node.global_position + Vector2(0, 24))
		fig_node.interact()
		fig_node.advance_harvest(Professions.gather_duration(fig_node.kind))
		check(gs.count("prof_cactusvijg") == 2, "plukken geeft twee cactusvijgen")
		gs.take("prof_cactusvijg", 2)

	# Het wild draalt rond, vlucht als je dichtbij komt, en laat buit vallen.
	var animals := get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return e.data.get("behavior", "") == "animal")
	check(animals.size() == 6, "zes wilde dieren in de vallei (%d)" % animals.size())
	var fox: Node = null
	for animal: Node in animals:
		if animal.kind == "woestijnvos":
			fox = animal
	check(fox != null, "er loopt een woestijnvos")
	if fox != null:
		await put_player(fox.global_position + Vector2(200, 0))
		await frames(10)
		check(not fox.fleeing, "de vos rent niet weg als je ver weg bent")
		await put_player(fox.global_position + Vector2(40, 0))
		await frames(10)
		check(fox.fleeing, "de vos rent weg als je dichtbij komt")
		var hp_before: int = gs.hp
		await frames(10)
		check(gs.hp == hp_before, "een aanraking met de vos doet geen schade")
		fox.hurt(1, Vector2.LEFT)
		check(fox.panic > 0.0, "een klap zet de vos in paniek, ook uit de verte")
		var loot_before: int = gs.count("jacht_vacht") + gs.count("jacht_vlees")
		fox.hurt(99, Vector2.LEFT)
		await frames(10)
		check(gs.kills_by.get("woestijnvos", 0) == 1, "de vos telt als verslagen wild")
		check(get_nodes_in_group("pickups").size() > 0 or gs.count("jacht_vacht") + gs.count("jacht_vlees") > loot_before, "de vos laat buit vallen")

	# Het altaar ontdekken maakt snel reizen mogelijk.
	var altar: Node = null
	for node: Node in get_nodes_in_group("interactable"):
		if node.get_script() != null and "savepoint" in str(node.get_script().resource_path):
			altar = node
	check(altar != null, "het altaar van de Dorstvallei staat in de wereld")
	if altar != null:
		await put_player(altar.global_position + Vector2(0, 24))
		altar.interact()
		await frames(2)
		check(gs.flag("altaar_dorstvallei_31_14"), "het altaar van de Dorstvallei is ontdekt voor snel reizen")

	await through_portal("dauwbos") # en weer terug
	world.player.invuln = 999.0


# --- Deel 3: opdrachten en personages -------------------------------------------------------------------

func test_quests() -> void:
	print("Opdrachten van de Dorstvallei")
	gs.new_game()
	gs.in_game = true
	world.load_map("dorstvallei", "start")
	await frames(5)
	world.player.invuln = 999.0

	# Jelle: de jachtopdracht.
	await talk_npc("jelle", [0])
	check(gs.quest_state("vellen_en_vlees") == "active", "Jelle geeft de opdracht Vellen en vlees")
	check(gs.flag("jelle_ontmoet"), "Jelle onthoudt dat je hem hebt ontmoet")
	gs.give("jacht_vacht", 2, true)
	gs.give("jacht_vlees", 2, true)
	await frames(2)
	check(gs.quest_step("vellen_en_vlees") == 1, "vellen en vlees zetten de opdracht op de volgende stap")
	var coins_before: int = gs.coins
	await talk_npc("jelle")
	check(gs.quest_state("vellen_en_vlees") == "done", "Jelle rondt de opdracht af")
	check(gs.count("jacht_vacht") == 0 and gs.count("jacht_braadstuk") == 1, "de buit ingeruild voor een braadstuk")
	check(gs.coins == coins_before + 40, "Jelle betaalt veertig munten")

	# Sana: de cactusvijgenopdracht.
	await talk_npc("sana", [0])
	check(gs.quest_state("cactusvijgen") == "active", "Sana geeft de opdracht Cactusvijgen voor Sana")
	gs.give("prof_cactusvijg", 5, true)
	await frames(2)
	check(gs.quest_step("cactusvijgen") == 1, "vijf cactusvijgen zetten de opdracht op de volgende stap")
	await talk_npc("sana")
	check(gs.quest_state("cactusvijgen") == "done", "Sana rondt de opdracht af")
	check(gs.count("prof_cactusvijg") == 0 and gs.count("prof_zandbalsem") == 1, "vijgen ingeruild voor een zandbalsem")

	# Nour vertelt over de vallei.
	await talk_npc("nour")
	check(gs.flag("nour_ontmoet"), "Nour onthoudt dat je hem hebt ontmoet")
	check(" ".join(seen_lines).length() > 40, "Nour vertelt zijn verhaal")
	check(gs.check_all([["talked_to_all", ["jelle", "sana", "nour"]]]), "de prestatie Zandvoeten kan vrijspelen")
