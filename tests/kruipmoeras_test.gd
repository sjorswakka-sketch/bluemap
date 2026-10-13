extends SceneTree
## Test van Het Kruipmoeras (spoor "moeras"): kaart, moerasklimaat (waas), doorgang met het
## Zilvermeer, veengrondstoffen, nieuw wild (moerasvorsten en waterslangen), de drie opdrachten
## en het altaar.
##
##   sh tools/run_tests.sh /pad/naar/godot      (alle tests), of alleen deze:
##   XDG_DATA_HOME=.testdata godot --headless --fixed-fps 60 --path . -s tests/kruipmoeras_test.gd
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
const Moeras := preload("res://scripts/data/ext/moeras.gd")

const NEW_TILES := ["marsh_grass", "marsh_tufts", "mud", "bog_water", "reed", "willow"]
const MOERAS_ITEMS := ["prof_veenbes", "prof_watermunt", "prof_wilgentwijg", "prof_ijzeroer", "prof_moeraselixer", "prof_veenbespap", "moeras_huid", "zonneschijf_amulet"]
const MOERAS_RESOURCES := ["veenbessen", "watermunt", "wilgstronk", "ijzeroer_ader"]
const ANIMALS := ["moerasvors", "waterslang"]
## De gemiddelde kleur van elke nieuwe tegel in tiles.png: zo zie je of het plaatje nog bij de volgorde in NAMES past.
const TILE_COLORS := {
	"marsh_grass": Color("5a6a34"), "marsh_tufts": Color("5a6a34"), "mud": Color("6a5536"),
	"bog_water": Color("405239"), "reed": Color("606d37"), "willow": Color("556932"),
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
	print("MOERAS OK" if failures == 0 else "MOERAS FAILED: %d" % failures)
	quit(1 if failures else 0)


# --- Deel 1: gegevens en bereikbaarheid ---------------------------------------------------------------

func test_data() -> void:
	print("Gegevens van het Kruipmoeras")
	check(Maps.MAPS.has("kruipmoeras"), "kaart kruipmoeras is aangemeld")
	var def: Dictionary = Maps.get_map("kruipmoeras")
	var rows: Array = def["rows"]
	var same := true
	for row: String in rows:
		same = same and row.length() == String(rows[0]).length()
	check(same, "kruipmoeras: alle rijen zijn even lang")
	check(String(rows[0]).length() == 48 and rows.size() == 34, "het Kruipmoeras is 48x34 tegels")
	check(def["name"] == "Kruipmoeras" and def.get("music", "") == "forest", "naam en muziek van het moeras")
	check(def.get("outdoor", false) and def.get("weather", "") == "swamp", "buitengebied waar altijd een waas hangt")

	var tiles_tex := Art.tex("tiles")
	check(tiles_tex.get_width() == Tiles.NAMES.size() * 16, "tiles.png heeft een plaatje per tegel (%d)" % Tiles.NAMES.size())
	var tiles_ok := true
	for tile_name: String in NEW_TILES:
		tiles_ok = tiles_ok and tile_name in Tiles.NAMES and Tiles.NAMES.find(tile_name) >= 65
		tiles_ok = tiles_ok and Tiles.map_color(tile_name) != Color(0.5, 0.5, 0.55)
	check(tiles_ok, "zes nieuwe tegels aan het eind van de lijst, met een eigen kleur op het kaartje")
	check(Tiles.is_solid_name("bog_water") and Tiles.is_solid_name("reed") and Tiles.is_solid_name("willow"), "drijfmest, riet en knotwilg zijn vast")
	check(not Tiles.is_solid_name("marsh_grass") and not Tiles.is_solid_name("marsh_tufts") and not Tiles.is_solid_name("mud"), "moerasgras en modder zijn begaanbaar")
	check(Tiles.name_for("U", 1, 1) == "marsh_grass" and Tiles.name_for("F", 0, 0) == "bog_water" and Tiles.name_for("Y", 0, 0) == "willow", "de tekens in de kaart kloppen")
	check(Tiles.name_for("U", 0, 1) == "marsh_tufts", "polgras groeit als variatie op het moerasgras")
	check(Tiles.movement_multiplier("mud") < 1.0, "modder loopt iets trager dan gras")
	check(Tiles.footstep_surface("marsh_grass") == "grass", "moerasgras heeft het grasloopgeluid")
	var tiles_img := tiles_tex.get_image()
	var order_ok := true
	for tile_name: String in TILE_COLORS:
		var mean := mean_color(tiles_img, Rect2i(Tiles.index_of(tile_name) * 16, 0, 16, 16))
		var want: Color = TILE_COLORS[tile_name]
		order_ok = order_ok and Vector3(mean.r - want.r, mean.g - want.g, mean.b - want.b).length() < 0.025
	check(order_ok, "tiles.png past bij de volgorde in Tiles.NAMES (anders: python tools/make_art.py)")

	# Het moerasklimaat: eigen waas en eigen sfeergeluiden.
	check(Daynight.climate("swamp") == "moeras", "het moeras is een eigen klimaat")
	check(Daynight.swampy("swamp", 1, 0.5) and not Daynight.swampy("snow", 1, 0.5), "de waas hoort alleen bij moerasweer")
	check(Daynight.swamp_tint(0.0) == Color.WHITE and Daynight.swamp_tint(1.0) != Color.WHITE, "de waas dempt en vergroent het licht")
	check(Daynight.ambience("swamp", 0.15) == "amb_moeras_ochtend" and Daynight.ambience("swamp", 0.85) == "amb_moeras_nacht", "het moeras klinkt per dagdeel anders")

	# Veengrondstoffen, jachtbuit, het amulet en recepten.
	for item: String in MOERAS_ITEMS:
		check(Items.ITEMS.has(item), "voorwerp geregistreerd: " + item)
	for kind: String in MOERAS_RESOURCES:
		check(Beroepen.RESOURCES.has(kind), "grondstof geregistreerd: " + kind)
	# Elk nieuwe grondstofsoort heeft een eigen frame op de sheet, op zijn plek in de lijst.
	for kind: String in MOERAS_RESOURCES:
		var frame: int = Beroepen.RESOURCES.keys().find(kind)
		check(Art.tex("resources_beroepen").get_width() > frame * 16, "frame van %s past op de grondstofsheet" % kind)
	check(Beroepen.RECIPES["moeras_elixer"]["inputs"] == {"prof_watermunt": 2, "prof_veenbes": 1}, "moeraselixer gebruikt watermunt en veenbes")
	check(Beroepen.RECIPES["veenbes_pap"]["inputs"] == {"prof_veenbes": 3, "prof_watermunt": 1}, "veenbespap gebruikt veenbessen en watermunt")
	check(Beroepen.RESOURCE_PLACEMENTS.has("kruipmoeras") and Beroepen.RESOURCE_PLACEMENTS["kruipmoeras"].size() == 12, "twaalf grondstofplekken in het Kruipmoeras")

	# Het wild: vreedzaam, vluchtend, met buit.
	for kind: String in ANIMALS:
		check(Enemies.ENEMIES.has(kind), "dier geregistreerd: " + kind)
		var data: Dictionary = Enemies.ENEMIES[kind]
		check(data["behavior"] == "animal" and int(data["damage"]) == 0, "%s is vreedzaam wild" % kind)
		check(data["drops"].any(func(d: Array) -> bool: return d[0] == "moeras_huid"), "%s geeft moerashuid" % kind)

	# Opdrachten, personages en gesprekken.
	check(Quests.QUESTS.has("veenbessen") and Quests.QUESTS.has("wilgentwijgen") and Quests.QUESTS.has("zonneschijf"), "drie opdrachten aangemeld")
	for npc_id: String in ["stien", "mees", "wouda"]:
		check(Npcs.NPCS.has(npc_id), "personage geregistreerd: " + npc_id)
	check(Moeras.ACHIEVEMENTS.has("kruipmoeras_ontdekt"), "prestatie Veenvoeten aangemeld")

	var bad := unreachable_things("kruipmoeras")
	check(bad.is_empty(), "kruipmoeras: alles is bereikbaar %s" % [bad])
	bad = unreachable_things("lake")
	check(bad.is_empty(), "zilvermeer: alles is bereikbaar met de nieuwe doorgang %s" % [bad])

	# De doorgangen tussen het Zilvermeer en het Kruipmoeras kloppen aan beide kanten.
	var links_ok := true
	for pair: Array in [["lake", "kruipmoeras"], ["kruipmoeras", "lake"]]:
		var found := false
		for obj: Dictionary in objects(pair[0], "portal"):
			if obj["to"] == pair[1]:
				found = true
				links_ok = links_ok and Maps.get_map(pair[1])["spawns"].has(obj.get("spawn", "start"))
		links_ok = links_ok and found
	check(links_ok, "het Zilvermeer en het Kruipmoeras hebben doorgangen naar elkaar")


# --- Deel 2: de wereld zelf ----------------------------------------------------------------------------

func test_world() -> void:
	print("De wereld van het Kruipmoeras")
	gs.new_game()
	gs.in_game = true
	world.load_map("lake", "start")
	await frames(5)
	world.player.invuln = 999.0
	await through_portal("kruipmoeras") # het zuidelijke veenpad in het Zilvermeer
	world.player.invuln = 999.0

	# De veengrondstoffen staan in de wereld.
	await frames(5)
	var nodes := get_nodes_in_group("profession_resources").filter(func(n: Node) -> bool: return str(n.resource_id).begins_with("kruipmoeras:"))
	check(nodes.size() == 12, "twaalf grondstofnodes in het Kruipmoeras (%d)" % nodes.size())
	var kinds := {}
	for node: Node in nodes:
		kinds[node.kind] = true
	for kind: String in MOERAS_RESOURCES:
		check(kinds.has(kind), "grondstofnode in de wereld: " + kind)

	# Veenbessen plukken werkt.
	var bes_node: Node = null
	for node: Node in nodes:
		if node.kind == "veenbessen":
			bes_node = node
	check(bes_node != null, "er is een veenbessenstruik")
	if bes_node != null:
		await put_player(bes_node.global_position + Vector2(0, 24))
		bes_node.interact()
		bes_node.advance_harvest(Professions.gather_duration(bes_node.kind))
		check(gs.count("prof_veenbes") == 3, "plukken geeft drie veenbessen")
		gs.take("prof_veenbes", 3)

	# Het wild draalt rond, vlucht als je dichtbij komt, en laat buit vallen.
	var animals := get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return e.data.get("behavior", "") == "animal")
	check(animals.size() == 6, "zes wilde dieren in het moeras (%d)" % animals.size())
	var vors: Node = null
	for animal: Node in animals:
		if animal.kind == "moerasvors":
			vors = animal
	check(vors != null, "er loopt een moerasvors")
	if vors != null:
		await put_player(vors.global_position + Vector2(200, 0))
		await frames(10)
		check(not vors.fleeing, "de vors rent niet weg als je ver weg bent")
		await put_player(vors.global_position + Vector2(40, 0))
		await frames(10)
		check(vors.fleeing, "de vors rent weg als je dichtbij komt")
		var hp_before: int = gs.hp
		await frames(10)
		check(gs.hp == hp_before, "een aanraking met de vors doet geen schade")
		vors.hurt(1, Vector2.LEFT)
		check(vors.panic > 0.0, "een klap zet de vors in paniek, ook uit de verte")
		var loot_before: int = gs.count("moeras_huid") + gs.count("jacht_vlees")
		vors.hurt(99, Vector2.LEFT)
		await frames(10)
		check(gs.kills_by.get("moerasvors", 0) == 1, "de vors telt als verslagen wild")
		check(get_nodes_in_group("pickups").size() > 0 or gs.count("moeras_huid") + gs.count("jacht_vlees") > loot_before, "de vors laat buit vallen")

	# Het altaar ontdekken maakt snel reizen mogelijk.
	var altar: Node = null
	for node: Node in get_nodes_in_group("interactable"):
		if node.get_script() != null and "savepoint" in str(node.get_script().resource_path):
			altar = node
	check(altar != null, "het altaar van het Kruipmoeras staat in de wereld")
	if altar != null:
		await put_player(altar.global_position + Vector2(0, 24))
		altar.interact()
		await frames(2)
		check(gs.flag("altaar_kruipmoeras_28_7"), "het altaar van het Kruipmoeras is ontdekt voor snel reizen")

	await through_portal("lake") # en weer terug
	world.player.invuln = 999.0


# --- Deel 3: opdrachten en personages -------------------------------------------------------------------

func test_quests() -> void:
	print("Opdrachten van het Kruipmoeras")
	gs.new_game()
	gs.in_game = true
	world.load_map("kruipmoeras", "start")
	await frames(5)
	world.player.invuln = 999.0

	# Stien: de veenbessenopdracht.
	await talk_npc("stien", [0])
	check(gs.quest_state("veenbessen") == "active", "Stien geeft de opdracht Veenbessen voor Stien")
	check(gs.flag("stien_ontmoet"), "Stien onthoudt dat je haar hebt ontmoet")
	gs.give("prof_veenbes", 5, true)
	await frames(2)
	check(gs.quest_step("veenbessen") == 1, "vijf veenbessen zetten de opdracht op de volgende stap")
	var coins_before: int = gs.coins
	await talk_npc("stien")
	check(gs.quest_state("veenbessen") == "done", "Stien rondt de opdracht af")
	check(gs.count("prof_veenbes") == 0 and gs.count("prof_ijzeroer") == 1, "de bessen ingeruild voor ijzeroer")
	check(gs.coins == coins_before + 30, "Stien betaalt dertig munten")

	# Mees: de wilgentwijgenopdracht.
	await talk_npc("mees", [0])
	check(gs.quest_state("wilgentwijgen") == "active", "Mees geeft de opdracht Wilgentwijgen voor Mees")
	gs.give("prof_wilgentwijg", 4, true)
	check(gs.quest_step("wilgentwijgen") == 0, "twijgen in de tas herstellen nog geen brug")
	gs.set_flag("lw_drained")
	gs.set_flag("lw_bridge")
	await frames(2)
	check(gs.quest_step("wilgentwijgen") == 1, "de herstelde oversteek zet de opdracht op de volgende stap")
	await talk_npc("mees")
	check(gs.quest_state("wilgentwijgen") == "done", "Mees rondt de opdracht af")
	check(gs.count("prof_wilgentwijg") == 4 and gs.count("prof_watermunt") == 2 and gs.flag("lw_tailoring"), "reparatie opent recept en behoudt ongebruikte twijgen")

	# Wouda: het verhaal van de zonneschijf.
	await talk_npc("wouda", [0])
	check(gs.quest_state("zonneschijf") == "active", "Wouda geeft de opdracht De zonneschijf van Wouda")
	check(" ".join(seen_lines).length() > 40, "Wouda vertelt het verhaal van het moeras")
	gs.give("zonneschijf_amulet", 1, true)
	await frames(2)
	check(gs.quest_step("zonneschijf") == 1, "het amulet zet de opdracht op de volgende stap")
	await talk_npc("wouda")
	check(gs.quest_state("zonneschijf") == "done", "Wouda rondt de opdracht af")
	check(gs.count("zonneschijf_amulet") == 0 and gs.count("prof_moeraselixer") == 1, "het amulet ingeruild voor een moeraselixer")

	check(gs.check_all([["talked_to_all", ["stien", "mees", "wouda"]]]), "de prestatie Veenvoeten kan vrijspelen")
