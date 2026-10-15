extends SceneTree
## Test van het Zilvermeer (spoor "meer"): kaarten, doorgangen, het visspel in al zijn uitkomsten, vis verkopen,
## beide opdrachten, de bibliotheek, opslaan en laden.
##
##   sh tools/run_tests.sh /pad/naar/godot      (alle tests), of alleen deze:
##   XDG_DATA_HOME=.testdata godot --headless --fixed-fps 60 --path . -s tests/meer_test.gd
##
## Zonder XDG_DATA_HOME schrijft de test in de echte opslagmap van het spel (en overschrijft hij je opgeslagen spel).

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Items := preload("res://scripts/data/items.gd")
const Npcs := preload("res://scripts/data/npcs.gd")
const Dialogue := preload("res://scripts/data/dialogue.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Art := preload("res://scripts/core/art.gd")
const Content := preload("res://scripts/data/content.gd")
const Meer := preload("res://scripts/data/ext/meer.gd")
const Vis := preload("res://scripts/data/ext/meer_vis.gd")
const Boeken := preload("res://scripts/data/ext/meer_boeken.gd")
const Reel := preload("res://scripts/ui/fishing_reel.gd")

const MEER_MAPS := ["lake", "fisher_hut", "library"]
const NEW_TILES := ["meer_sand", "meer_reeds", "meer_lelie", "meer_paal", "meer_bibvloer", "meer_tapijt"]
const FISH := ["meer_baars", "meer_snoek", "meer_laars", "meer_gouden_karper"]
const SPOT_TYPES := ["meer_visplek", "meer_diepe_visplek"]
## De gemiddelde kleur van elke nieuwe tegel in tiles.png: zo zie je of het plaatje nog bij de volgorde in NAMES past.
const TILE_COLORS := {
	"meer_sand": Color("ead8a2"), "meer_reeds": Color("53829d"), "meer_lelie": Color("428bab"),
	"meer_paal": Color("537baa"), "meer_bibvloer": Color("a9733e"), "meer_tapijt": Color("387963"),
}
## De scripts van het meer die geluiden afspelen.
const SOUND_SCRIPTS := [
	"res://scripts/ui/fishing_ui.gd", "res://scripts/entities/meer_visplek.gd", "res://scripts/entities/meer_kast.gd",
	"res://scripts/entities/meer_lessenaar.gd", "res://scripts/entities/meer_water.gd", "res://scripts/data/ext/meer_logic.gd",
]

var failures := 0
var gs: Node
var world: Node2D
var logic: GDScript # de werking van het meer gebruikt de autoloads en wordt dus pas geladen als het spel draait
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


func key_event(keycode: Key, pressed: bool) -> void:
	# Een echte toetsaanslag, zoals de speler hem geeft (de acties in project.godot luisteren naar de fysieke toets).
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _initialize() -> void:
	_run.call_deferred()


func tile_center(pos: Array) -> Vector2:
	return Vector2(float(pos[0]) * 32.0 + 16.0, float(pos[1]) * 32.0 + 16.0)


func put_player(pos: Vector2) -> void:
	world.player.global_position = pos
	world.player.velocity = Vector2.ZERO
	world.player.invuln = 999.0
	await frames(3)


func objects(map_id: String, type: String) -> Array:
	return Maps.get_map(map_id)["objects"].filter(func(o: Dictionary) -> bool: return o["type"] == type)


func find_node(group: String, test: Callable) -> Node:
	for node in get_nodes_in_group(group):
		if test.call(node):
			return node
	return null


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
	await finish_dialogue(picks)


func finish_dialogue(picks: Array = []) -> void:
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
	await talk(pick_talk(npc_id), picks)


func fresh_game(map_id := "lake") -> void:
	gs.new_game()
	gs.in_game = true
	world.load_map(map_id, "start")
	await frames(5)
	world.player.invuln = 999.0


# --- Deel 1: gegevens en bereikbaarheid ----------------------------------------------------------------

## Alle begaanbare tegels die je vanaf de startplek kunt bereiken. Personages, borden, kisten en lessenaars zijn
## zelf ook obstakels. `opened` zijn tegels die pas later vrijkomen (de geheime kast).
func reachable(map_id: String, opened: Array = []) -> Dictionary:
	var def: Dictionary = Maps.get_map(map_id)
	var rows: Array = def["rows"]
	var blocked := {}
	for obj: Dictionary in def["objects"]:
		if obj["type"] in ["npc", "sign", "chest", "meer_lessenaar"]:
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
			if Tiles.is_solid_char(String(rows[next.y])[next.x]) and not opened.has(next):
				continue
			open[next] = true
			queue.append(next)
	return open


## Namen van alles op de kaart dat je niet kunt bereiken.
func unreachable_things(map_id: String, opened: Array = []) -> Array:
	var open := reachable(map_id, opened)
	var bad: Array = []
	for obj: Dictionary in Maps.get_map(map_id)["objects"]:
		var cell := Vector2i(int(obj["pos"][0]), int(obj["pos"][1]))
		var label := "%s op %s" % [obj["type"], cell]
		match obj["type"]:
			"npc", "sign", "chest", "meer_lessenaar", "meer_visplek", "meer_diepe_visplek":
				# Je praat vanaf een tegel ernaast (40 pixels bereik, dus niet schuin).
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


func test_data() -> void:
	print("Gegevens van het Zilvermeer")
	for map_id: String in MEER_MAPS:
		check(Maps.MAPS.has(map_id), "kaart %s is aangemeld" % map_id)
		var rows: Array = Maps.get_map(map_id)["rows"]
		var same := true
		for row: String in rows:
			same = same and row.length() == String(rows[0]).length()
		check(same, "%s: alle rijen zijn even lang" % map_id)
		check(Maps.get_map(map_id).get("music", "") == "lake", "%s speelt de muziek van het meer" % map_id)
	check(Maps.get_map("lake")["rows"][0].length() == 44 and Maps.get_map("lake")["rows"].size() == 32, "het meer is 44x32 tegels")

	var tiles_tex := Art.tex("tiles")
	check(tiles_tex.get_width() == Tiles.NAMES.size() * 16, "tiles.png heeft een plaatje per tegel (%d)" % Tiles.NAMES.size())
	var tiles_ok := true
	for tile_name: String in NEW_TILES:
		tiles_ok = tiles_ok and tile_name in Tiles.NAMES and Tiles.NAMES.find(tile_name) >= 39
		tiles_ok = tiles_ok and Tiles.map_color(tile_name) != Color(0.5, 0.5, 0.55)
	check(tiles_ok, "zes nieuwe tegels aan het eind van de lijst, met een eigen kleur op het kaartje")
	check(Tiles.is_solid_name("meer_reeds") and Tiles.is_solid_name("meer_lelie") and Tiles.is_solid_name("meer_paal"), "riet, lelieblad en steigerpaal zijn vast")
	check(not Tiles.is_solid_name("meer_sand") and not Tiles.is_solid_name("meer_bibvloer") and not Tiles.is_solid_name("meer_tapijt"), "zand, vloer en tapijt zijn begaanbaar")
	check(Tiles.name_for("s", 0, 0) == "meer_sand" and Tiles.name_for("Q", 0, 0) == "meer_bibvloer", "de tekens in de kaart kloppen")
	var tiles_img := tiles_tex.get_image()
	var order_ok := true
	for tile_name: String in TILE_COLORS:
		var mean := mean_color(tiles_img, Rect2i(Tiles.index_of(tile_name) * 16, 0, 16, 16))
		var want: Color = TILE_COLORS[tile_name]
		order_ok = order_ok and Vector3(mean.r - want.r, mean.g - want.g, mean.b - want.b).length() < 0.025
	check(order_ok, "tiles.png past bij de volgorde in Tiles.NAMES (anders: python3 tools/make_art.py)")

	for map_id: String in ["lake", "fisher_hut"]:
		var bad := unreachable_things(map_id)
		check(bad.is_empty(), "%s: alles is bereikbaar %s" % [map_id, bad])
	var library_closed := unreachable_things("library")
	check(not library_closed.is_empty() and not library_closed.has("portal op (8, 13)"), "bibliotheek: het achterkamertje is dicht (%d dingen onbereikbaar)" % library_closed.size())
	var library_open := unreachable_things("library", [Vector2i(17, 6), Vector2i(17, 7)])
	check(library_open.is_empty(), "bibliotheek: met de kast open is alles bereikbaar %s" % [library_open])

	# De doorgangen tussen de kaarten kloppen aan beide kanten.
	var links_ok := true
	for pair: Array in [["village", "lake"], ["lake", "village"], ["lake", "fisher_hut"], ["fisher_hut", "lake"], ["lake", "library"], ["library", "lake"]]:
		var found := false
		for obj: Dictionary in objects(pair[0], "portal"):
			if obj["to"] == pair[1]:
				found = true
				links_ok = links_ok and Maps.get_map(pair[1])["spawns"].has(obj.get("spawn", "start"))
		links_ok = links_ok and found
	check(links_ok, "dorp, meer, huisje en bibliotheek hebben doorgangen naar elkaar")
	var village_portal: Dictionary = objects("village", "portal").filter(func(o: Dictionary) -> bool: return o["to"] == "lake")[0]
	check(village_portal["pos"] == [19,26] and village_portal.get("requires", []).is_empty(), "de doorgang naar het meer houdt zijn oude plek en staat vanaf het begin open")

	# De inhoud van het meer
	var lake_objects: Array = Maps.get_map("lake")["objects"]
	var slimes := lake_objects.filter(func(o: Dictionary) -> bool: return o["type"] == "enemy")
	check(slimes.size() <= 4 and slimes.all(func(o: Dictionary) -> bool: return o["kind"] == "slime"), "hooguit vier gewone slijmen aan de verre oever")
	var chests := lake_objects.filter(func(o: Dictionary) -> bool: return o["type"] == "chest")
	var chest_items: Array = []
	for chest: Dictionary in chests:
		for entry: Array in chest["contents"]:
			chest_items.append(entry[0])
	check(chests.size() == 3 and chest_items.has("coins") and chest_items.has("potion") and chest_items.has("meer_schelp"), "drie verborgen kisten: munten, een Helddrank en iets leuks")
	var spots := lake_objects.filter(func(o: Dictionary) -> bool: return o["type"] in SPOT_TYPES)
	var deep_spots := spots.filter(func(o: Dictionary) -> bool: return o["type"] == "meer_diepe_visplek")
	check(spots.size() >= 4 and deep_spots.size() == 1, "%d visplekken, waarvan één in diep water (de verre steiger)" % spots.size())
	var spots_on_water := true
	for spot: Dictionary in spots:
		var tile_char := String(Maps.get_map("lake")["rows"][int(spot["pos"][1])])[int(spot["pos"][0])]
		spots_on_water = spots_on_water and tile_char == "~"
	check(spots_on_water, "elke visplek ligt op een watertegel")
	var library_objects: Array = Maps.get_map("library")["objects"]
	var lecterns: Array = library_objects.filter(func(o: Dictionary) -> bool: return o["type"] == "meer_lessenaar")
	var ids := {}
	for lectern: Dictionary in lecterns:
		ids[lectern["id"]] = true
	check(lecterns.size() == 6 and ids.size() == 6 and ids.keys().all(func(id: String) -> bool: return Boeken.TEXTS.has(id)), "zes lessenaars, elk met een eigen tekst")
	var texts_ok := true
	for book_id: String in Boeken.TEXTS:
		var text: Dictionary = Boeken.TEXTS[book_id]
		texts_ok = texts_ok and String(text["title"]).length() > 3 and text["lines"].size() >= 3
		for line: String in text["lines"]:
			texts_ok = texts_ok and line.length() > 40 and line.length() < 260
	check(texts_ok, "alle lessenaar-teksten hebben een titel en goed gevulde regels")
	var lore := " ".join(Boeken.TEXTS.values().map(func(t: Dictionary) -> String: return " ".join(t["lines"])))
	check("Diepte" in lore and "Vergeten Wachter" in lore and "Sterrenkaart" in lore and "Blauwe Kaart" in lore, "de teksten gaan over de Diepte, de Wachter en de Sterrenkaart")

	var sounds_ok := true
	var sound := root.get_node("Sound")
	for sound_name: String in Meer.SOUNDS:
		sounds_ok = sounds_ok and sound.streams.has(sound_name)
	check(sounds_ok and sound.tracks.has("lake"), "alle geluiden en de muziek van het meer zijn geladen")
	var played := {}
	var play_call := RegEx.create_from_string("Sound\\.play\\(\"(meer_[a-z_]+)\"")
	for path: String in SOUND_SCRIPTS:
		for found: RegExMatch in play_call.search_all(FileAccess.get_file_as_string(path)):
			played[found.get_string(1)] = true
	check(played.size() == Meer.SOUNDS.size() and played.keys().all(func(n: String) -> bool: return sound.streams.has(n)), "elk geluid dat het meer afspeelt bestaat, en elk geluid wordt gebruikt (%s)" % [played.keys()])
	var items_ok := true
	for item_id: String in Meer.ITEMS:
		var info: Dictionary = Items.info(item_id)
		items_ok = items_ok and info.get("sheet", "") == "items_meer" and Art.tex("items_meer").get_width() >= (int(info["icon"]) + 1) * 16
	check(items_ok, "alle voorwerpen van het meer hebben een icoon in items_meer.png")
	var sells_match := true
	for fish_id: String in Vis.CATCHES:
		sells_match = sells_match and Items.info(fish_id)["sell"] == Vis.CATCHES[fish_id]["sell"]
	check(sells_match and not Items.info(Vis.GOLDEN).has("sell"), "de verkoopwaarde in het voorwerp en in de vistabel zijn gelijk (de Gouden Karper is niet te koop)")
	check(Items.info("meer_baars")["sell"] == 8 and Items.info("meer_snoek")["sell"] == 15 and Items.info("meer_laars")["sell"] == 1, "verkoopwaardes: baars 8, snoek 15, laars 1")


# --- Deel 2: de wereld ------------------------------------------------------------------------------------

func test_travel() -> void:
	print("Doorgangen")
	check(gs.map_id == "village", "we beginnen in het dorp")
	await through_portal("lake")
	check(world.map_size == Vector2i(44, 32) and root.get_node("Sound").current_track == "lake", "het meer laadt en de muziek van het meer speelt")
	check(world.is_solid(tile_center([21, 14]) + Vector2(-64, 0)) and not world.is_solid(tile_center([21, 15])), "water is vast, de steiger niet")
	check(absf(world.player.global_position.y - 3.0 * 32.0 - 16.0) < 64.0, "je komt aan bij de noordkant van het meer")
	await through_portal("fisher_hut")
	check(world.map_size == Vector2i(12, 9), "het huisje van Joris")
	await through_portal("lake")
	await through_portal("library")
	check(world.map_size == Vector2i(24, 14), "de bibliotheek van Lena")
	await through_portal("lake")
	await through_portal("village")
	check(world.player.global_position.y < 26.0 * 32.0, "terug in het dorp sta je niet in de doorgang")
	await frames(30)
	check(gs.map_id == "village", "en je blijft in het dorp (geen heen-en-weer-gestuiter)")
	check(gs.has_save(), "er is opgeslagen bij het wisselen van gebied")


func test_pickups_and_chests() -> void:
	print("Schatten en vijanden")
	await fresh_game("lake")
	var slimes := 0
	for enemy in get_nodes_in_group("enemies"):
		slimes += 1
	check(slimes == 4, "vier slijmen aan de verre oever")
	var chests: Array = []
	for node in get_nodes_in_group("interactable"):
		if "contents" in node:
			chests.append(node)
	check(chests.size() == 3, "drie kisten op het meer")
	for chest in chests:
		await put_player(chest.global_position + Vector2(0, 32))
		chest.interact()
	check(gs.coins == 35 and gs.count("potion") == 1 and gs.count("meer_schelp") == 1, "kisten: 35 munten, een Helddrank en een Zilverschelp")
	check(Items.info("meer_schelp")["type"] == "treasure", "de schelp is een verzamelstuk")
	var book: Node = find_node("pickups", func(p: Node) -> bool: return p.item == "meer_boek_eiland")
	check(book != null, "het boek ligt op het eiland")
	await put_player(book.global_position + Vector2(0, 48))
	await put_player(book.global_position)
	await frames(5)
	check(gs.count("meer_boek_eiland") == 1 and gs.flag("pickup:lake:%d" % Maps.get_map("lake")["objects"].find_custom(func(o: Dictionary) -> bool: return o["type"] == "pickup" and o["item"] == "meer_boek_eiland")), "het boek van het eiland is te pakken en verdwijnt daarna voorgoed")
	var ambient := false
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with("meer_water.gd"):
			ambient = true
			child.next_jump = 0.0
			await frames(5)
			check(not child.jump.is_empty() or child.next_jump > 0.0, "er springt af en toe een vis uit het water")
			await frames(60)
	check(ambient, "het meer heeft sfeer: glinsteringen en springende vissen")


# --- Het visspel ----------------------------------------------------------------------------------------------

func spot(deep: bool) -> Node:
	return find_node("interactable", func(n: Node) -> bool: return "deep" in n and n.deep == deep and n.has_method("interact"))


func fishing_ui() -> Node:
	return world.get_node_or_null("Vissen")


func wait_for_phase(ui: Node, phase: String, max_frames := 300) -> bool:
	var guard := 0
	while ui.phase != phase and guard < max_frames:
		guard += 1
		await frames(1)
	return ui.phase == phase


## Haalt de vis binnen. `skill`: "goed" houdt de vis in de zone, "slecht" houdt de zone juist ver van de vis.
func play_reel(ui: Node, skill: String, max_frames := 3000) -> void:
	var guard := 0
	while ui.phase == "reel" and guard < max_frames:
		guard += 1
		var reel = ui.reel
		var err: float = float(reel.fish_pos) - float(reel.zone_pos)
		var hold := (err * 6.0 - float(reel.zone_vel)) > 0.0 if skill == "goed" else float(reel.fish_pos) < 0.5
		if hold:
			Input.action_press("interact")
		else:
			Input.action_release("interact")
		await frames(1)
	Input.action_release("interact")


## Een speler die alles `delay` seconden te laat ziet, `per_second` keer per seconde E indrukt of loslaat en niet
## vooruitkijkt. Geeft het aantal beeldjes terug: positief als de vis gevangen is, negatief als niet.
func slow_reel(rng: RandomNumberGenerator, fish_id: String, delay: float, per_second: int) -> int:
	var reel = Reel.new(rng, Vis.stats(fish_id))
	var seen: Array[float] = []
	var hold := false
	var steps := 0
	while reel.state == "bezig" and steps < 60 * 120:
		seen.append(float(reel.fish_pos) - float(reel.zone_pos))
		if steps % (60 / per_second) == 0:
			hold = seen[maxi(0, seen.size() - 1 - int(delay * 60.0))] > 0.0
		reel.update(1.0 / 60.0, hold)
		steps += 1
	return steps if reel.state == "gevangen" else -steps


func test_reel_logic() -> void:
	print("Binnenhalen (zonder scherm)")
	var rng := RandomNumberGenerator.new()
	var all_win := true
	var times: Array[float] = []
	for fish_id: String in FISH:
		for seed_value in range(1, 21):
			rng.seed = seed_value
			var reel = Reel.new(rng, Vis.stats(fish_id))
			var steps := 0
			while reel.state == "bezig" and steps < 60 * 120:
				steps += 1
				var err: float = float(reel.fish_pos) - float(reel.zone_pos)
				reel.update(1.0 / 60.0, (err * 6.0 - float(reel.zone_vel)) > 0.0)
			all_win = all_win and reel.state == "gevangen"
			times.append(steps / 60.0)
	check(all_win, "met een goede speler worden alle vissen gevangen (20 keer per soort)")
	check(times.min() >= 4.5 and times.max() <= 30.0, "binnenhalen duurt %.1f tot %.1f seconden" % [times.min(), times.max()])
	# Spelers die trager reageren (en kinderen) moeten ook de snoek en de Gouden Karper kunnen vangen, en een gevecht
	# mag niet eindeloos duren: de vis wordt moe. Deze spelers zien alles te laat en kijken niet vooruit.
	for player_kind: Array in [["een gewone speler", 0.25, 8], ["een trage speler", 0.4, 4]]:
		var slow_ok := true
		var slow_max := 0.0
		for fish_id: String in ["meer_snoek", Vis.GOLDEN]:
			for seed_value in range(1, 11):
				rng.seed = seed_value
				var steps := slow_reel(rng, fish_id, player_kind[1], player_kind[2])
				slow_ok = slow_ok and steps > 0
				slow_max = maxf(slow_max, absf(steps) / 60.0)
		check(slow_ok and slow_max < 90.0, "%s vangt de snoek en de Gouden Karper ook (hooguit %.0f seconden)" % [player_kind[0], slow_max])
	rng.seed = 3
	var idle = Reel.new(rng, Vis.stats("meer_snoek"))
	var steps_idle := 0
	while idle.state == "bezig" and steps_idle < 60 * 120:
		steps_idle += 1
		idle.update(1.0 / 60.0, false)
	check(idle.state == "ontsnapt" and idle.zone_pos <= idle.zone_size / 2.0 + 0.001, "wie niets doet, laat de vis ontsnappen (de zone zakt naar beneden)")
	rng.seed = 4
	var hold_all = Reel.new(rng, Vis.stats("meer_snoek"))
	var in_bounds := true
	for i in 600:
		hold_all.update(1.0 / 60.0, true)
		in_bounds = in_bounds and hold_all.zone_pos <= 1.0 - hold_all.zone_size / 2.0 + 0.001 and hold_all.fish_pos >= 0.0 and hold_all.fish_pos <= 1.0
	check(in_bounds, "zone en vis blijven altijd binnen de balk")
	rng.seed = 5
	var done = Reel.new(rng, Vis.stats("meer_baars"))
	done.progress = 0.999
	done.fish_pos = done.zone_pos
	done.update(0.1, false)
	var state_before: String = done.state
	done.update(1.0, true)
	check(state_before == "gevangen" and done.state == "gevangen" and done.progress == 1.0, "een afgeronde vangst verandert niet meer")

	print("Welke vis bijt")
	rng.seed = 12345
	var golden_normal := 0
	var golden_deep := 0
	var golden_pity := 0
	var kinds := {}
	for i in 3000:
		golden_normal += 1 if Vis.roll(rng, false) == Vis.GOLDEN else 0
		var deep_roll := Vis.roll(rng, true)
		golden_deep += 1 if deep_roll == Vis.GOLDEN else 0
		golden_pity += 1 if Vis.roll(rng, true, 20) == Vis.GOLDEN else 0
		golden_normal += 1 if Vis.roll(rng, true, 20, false) == Vis.GOLDEN else 0
		kinds[deep_roll] = true
	check(golden_normal == 0, "op gewone plekken bijt de Gouden Karper nooit (en ook niet als hij niet mag bijten)")
	check(golden_deep > 3000 * 0.025 and golden_deep < 3000 * 0.06, "in diep water is de kans op de Gouden Karper ongeveer 4%% (%.1f%%)" % (golden_deep / 30.0))
	check(golden_pity > 3000 * 0.4 and golden_pity < 3000 * 0.6, "met pech wordt de kans groter, maar nooit boven de helft (%.0f%%)" % (golden_pity / 30.0))
	check(kinds.has("meer_baars") and kinds.has("meer_snoek") and kinds.has("meer_laars"), "baars, snoek en een oude laars komen ook voor")
	check(is_equal_approx(Vis.golden_chance(0), 0.04) and Vis.golden_chance(100) == Vis.GOLDEN_MAX_CHANCE, "de kans groeit met pech en heeft een plafond")


## Gooit `times` keer uit bij een visplek, met zo veel pech dat de kans op de Gouden Karper het grootst is.
## Geeft terug hoe vaak hij beet.
func count_golden_bites(spot_node: Node, times: int) -> int:
	var ui: Node = fishing_ui()
	var golden := 0
	for i in times:
		gs.meer["pech"] = 100
		ui.rng.seed = 300 + i
		spot_node.interact()
		await wait_for_phase(ui, "bite")
		golden += 1 if ui.catch_id == Vis.GOLDEN else 0
		press("pause")
		await frames(3)
	return golden


func test_fishing() -> void:
	print("Visspel: vooraf")
	await fresh_game("lake")
	var node: Node = spot(false)
	check(node != null and spot(true) != null, "er zijn gewone en diepe visplekken")
	var toasts: Array[String] = world.hud.toast_queue
	var toasts_before := toasts.size()
	for i in 10:
		node.interact()
	await frames(2)
	check(fishing_ui() == null and not gs.ui_owners.has("vissen") and not paused, "zonder hengel gebeurt er niets (alleen een melding)")
	check(toasts.size() <= toasts_before + 1, "vaak op E drukken geeft geen rij met dezelfde melding (%d)" % (toasts.size() - toasts_before))
	gs.give("fishing_rod", 1, true)
	await put_player(node.global_position + Vector2(32, 0)) # de visplek ligt links van de steiger
	check(world.player.target == node, "bij een visplek kun je E drukken")
	press("interact")
	await frames(3)
	var ui: Node = fishing_ui()
	check(ui != null and ui.phase == "cast" and gs.ui_owners.has("vissen") and paused, "E start het visspel en zet de wereld stil")
	check(world.player.facing.x < -0.9, "de speler kijkt naar het water")
	var frozen: Vector2 = world.player.global_position
	Input.action_press("move_up")
	await frames(20)
	Input.action_release("move_up")
	check(world.player.global_position == frozen, "tijdens het vissen kun je niet lopen")
	press("menu")
	press("map")
	press("quests")
	await frames(3)
	check(not world.menu_ui.active and ui.phase != "idle", "het menu gaat niet open tijdens het vissen")
	press("pause")
	await frames(3)
	check(ui.phase == "idle" and not paused and gs.ui_owners.is_empty() and not world.pause_menu.open, "Esc stopt (en opent geen pauzemenu)")
	var before: Vector2 = world.player.global_position
	Input.action_press("move_up")
	await frames(20)
	Input.action_release("move_up")
	check(world.player.global_position.y < before.y - 5.0, "daarna kun je weer lopen")

	print("Visspel: te laat")
	ui.forced_wait = 0.2
	ui.forced_catch = "meer_baars"
	node.interact()
	await frames(3)
	check(ui.phase == "cast", "uitwerpen")
	check(await wait_for_phase(ui, "wait"), "de dobber ligt in het water")
	check(await wait_for_phase(ui, "bite"), "BEET!")
	check(ui.catch_id == "meer_baars", "de bijtende vis is de afgesproken vis")
	await frames(30)
	check(ui.phase == "bite", "je hebt bijna een seconde de tijd")
	await frames(30)
	check(ui.phase == "result" and ui.outcome == "te_laat", "te laat: de vis is ontsnapt")
	check(gs.count("meer_baars") == 0 and int(gs.meer.get("gevangen", 0)) == 0, "geen vis in je tas")
	press("interact")
	await frames(2)
	check(ui.phase == "result", "het kaartje blijft even staan (je klikt er niet per ongeluk doorheen)")
	await frames(40)
	press("interact")
	await frames(2)
	check(ui.phase == "cast", "daarna gooit E opnieuw uit")
	press("dodge")
	await frames(3)
	check(ui.phase != "idle" and paused, "rollen (Shift) stopt het visspel niet: zo verlies je geen vis door een verkeerde toets")
	press("ui_cancel")
	await frames(3)
	check(ui.phase == "idle" and not paused and gs.ui_owners.is_empty(), "B op een controller (ui_cancel) stopt wel")

	print("Visspel: een vis vangen")
	ui.rng.seed = 11 # de vis zwemt steeds hetzelfde
	ui.forced_wait = 0.1
	ui.forced_catch = "meer_baars"
	node.interact()
	await wait_for_phase(ui, "wait")
	await frames(10)
	var splashes: Array = world.fx_layer.get_children().filter(func(fx: Node) -> bool: return fx.process_mode == Node.PROCESS_MODE_ALWAYS)
	check(paused and splashes.any(func(fx: Node) -> bool: return fx.age > 0.1), "de plons beweegt, ook al staat de wereld stil")
	await wait_for_phase(ui, "bite")
	press("interact")
	await frames(2)
	check(ui.phase == "reel" and ui.reel != null, "op tijd op E: het binnenhalen begint")
	check(ui.reel.progress > 0.0 and ui.reel.state == "bezig", "de voortgangsbalk is begonnen")
	await play_reel(ui, "goed")
	check(ui.phase == "result" and ui.outcome == "gevangen", "de vis in het groen houden vangt hem")
	check(gs.count("meer_baars") == 1 and int(gs.meer["gevangen"]) == 1, "een baars in je tas en de teller telt mee")
	var note_full: String = ui._catch_note()
	gs.meer["verkocht"] = Vis.FULL_PRICE_FISH
	var note_half: String = ui._catch_note()
	gs.meer.erase("verkocht")
	check(note_full == "Waarde: 8 munten" and note_half == "Waarde: 4 munten", "het kaartje toont wat de vis nu oplevert (%s / %s)" % [note_full, note_half])
	await frames(40)
	press("pause")
	await frames(3)
	check(ui.phase == "idle" and not paused, "klaar: Esc geeft de besturing terug")

	print("Visspel: met echte toetsen")
	ui.rng.seed = 12
	ui.forced_catch = "meer_snoek"
	node.interact()
	await wait_for_phase(ui, "bite")
	key_event(KEY_E, true)
	await frames(2)
	key_event(KEY_E, false)
	await frames(2)
	check(ui.phase == "reel", "een echte E-toets op tijd start het binnenhalen")
	var low_before: float = ui.reel.zone_pos
	key_event(KEY_E, true)
	await frames(20)
	var high: float = ui.reel.zone_pos
	key_event(KEY_E, false)
	await frames(20)
	var low_after: float = ui.reel.zone_pos
	check(high > low_before + 0.05 and low_after < high - 0.05, "E ingedrukt laat de zone stijgen, loslaten laat hem zakken")
	press("pause")
	await frames(3)
	check(ui.phase == "idle" and not paused, "en Esc stopt ook hier")

	print("Visspel: ontsnapt")
	ui.rng.seed = 13
	ui.forced_catch = "meer_snoek"
	node.interact()
	await wait_for_phase(ui, "bite")
	press("interact")
	await frames(2)
	await play_reel(ui, "slecht")
	check(ui.phase == "result" and ui.outcome == "ontsnapt", "de vis buiten de zone laten zwemmen: hij ontsnapt")
	check(gs.count("meer_snoek") == 0 and gs.count("meer_baars") == 1, "geen snoek erbij")
	press("pause")
	await frames(3)

	print("Visspel: annuleren in elke fase")
	for stop_phase: String in ["cast", "wait", "bite", "reel", "result"]:
		ui.forced_catch = "meer_baars"
		ui.forced_wait = 0.1
		node.interact()
		await frames(2)
		if stop_phase != "cast":
			await wait_for_phase(ui, "wait")
		if stop_phase in ["bite", "reel", "result"]:
			await wait_for_phase(ui, "bite")
		if stop_phase in ["reel", "result"]:
			press("interact")
			await frames(2)
		if stop_phase == "result":
			await play_reel(ui, "slecht")
		var reached: bool = ui.phase == stop_phase
		press("pause" if stop_phase != "reel" else "ui_cancel")
		await frames(3)
		check(reached and ui.phase == "idle" and not paused and gs.ui_owners.is_empty() and not gs.input_locked(),
			"stoppen tijdens '%s' sluit het menu en geeft de besturing terug" % stop_phase)
	var baars_now: int = gs.count("meer_baars")
	check(baars_now >= 1, "stoppen kost je geen vis")

	print("Visspel: de Gouden Karper")
	var deep: Node = spot(true)
	await put_player(deep.global_position + Vector2(32, 0))
	check(world.player.target == deep, "bij de verre steiger staat de diepe visplek")
	gs.start_quest("meer_karper")
	ui.rng.seed = 14
	ui.forced_catch = Vis.GOLDEN
	ui.forced_wait = 0.1
	gs.meer["pech"] = 4
	press("interact")
	await frames(3)
	await wait_for_phase(ui, "bite")
	press("interact")
	await frames(2)
	await play_reel(ui, "goed")
	check(ui.outcome == "gevangen" and gs.count(Vis.GOLDEN) == 1, "de Gouden Karper zit in je tas")
	check(gs.quest_step("meer_karper") == 1, "de opdracht gaat vanzelf verder: breng hem naar Joris")
	check(int(gs.meer["pech"]) == 0, "na de karper begint de pech-teller opnieuw")
	press("pause")
	await frames(3)
	ui.forced_catch = ""
	ui.forced_wait = -1.0
	check(not paused and gs.ui_owners.is_empty(), "het spel loopt weer")

	print("Visspel: waar en wanneer de Gouden Karper bijt")
	gs.new_game()
	gs.give("fishing_rod", 1, true)
	ui.forced_wait = 0.05
	var golden_normal := await count_golden_bites(node, 12)
	var golden_deep := await count_golden_bites(deep, 12)
	check(golden_normal == 0 and golden_deep > 0, "met veel pech bijt hij alleen bij de diepe visplek (%d keer van de 12)" % golden_deep)
	gs.give(Vis.GOLDEN, 1, true)
	var golden_twice := await count_golden_bites(deep, 8)
	gs.take(Vis.GOLDEN, 1)
	gs.start_quest("meer_karper")
	gs.finish_quest("meer_karper")
	var golden_after := await count_golden_bites(deep, 8)
	check(golden_twice == 0 and golden_after == 0, "geen tweede karper als je er al een hebt, en geen meer als Joris hem heeft gezien")
	ui.forced_wait = -1.0

	print("Visspel: echte kansen")
	gs.new_game()
	gs.give("fishing_rod", 1, true)
	ui.rng.seed = 99
	node.interact()
	var got_bite := await wait_for_phase(ui, "bite", 400)
	check(got_bite and ui.catch_id in ["meer_baars", "meer_snoek", "meer_laars"], "zonder afspraken wacht je 1 tot 3 seconden en bijt er een gewone vis (%s)" % ui.catch_id)
	check(ui.wait_time >= 1.0 and ui.wait_time <= 3.0, "de wachttijd was %.2f seconden" % ui.wait_time)
	press("pause")
	await frames(3)


# --- Vis verkopen -------------------------------------------------------------------------------------------

func test_selling() -> void:
	print("Vis verkopen")
	await fresh_game("lake")
	check(not gs.check(["meer_vis"]), "zonder vis geen verkoopkeuze")
	gs.give("meer_baars", 3, true)
	gs.give("meer_snoek", 1, true)
	gs.give("meer_laars", 2, true)
	check(gs.check(["meer_vis"]), "met vis krijg je de keuze 'Verkoop al mijn vis'")
	gs.set_flag("meer_joris_ontmoet")
	await talk_npc("meer_joris", [0]) # 'Verkoop al mijn vis' is de eerste keuze
	check(gs.coins == 3 * 8 + 15 + 2 * 1, "Joris betaalt 8, 15 en 1 munt per vis (%d munten)" % gs.coins)
	check(gs.count("meer_baars") == 0 and gs.count("meer_snoek") == 0 and gs.count("meer_laars") == 0, "alle vis is verkocht")
	check(logic.sold_count() == 6, "het dorp heeft 6 vissen gekocht")
	var coins_now: int = gs.coins
	check(not gs.check(["meer_vis"]), "daarna is er niets meer te verkopen")
	logic.sell_fish()
	check(gs.coins == coins_now, "verkopen zonder vis doet niets")

	print("Vis verkopen: het dorp raakt vol")
	gs.coins = 0
	gs.meer["verkocht"] = Vis.FULL_PRICE_FISH - 2
	gs.give("meer_baars", 4, true)
	check(not gs.check(["meer_vol"]), "na %d vissen is het dorp nog niet vol" % (Vis.FULL_PRICE_FISH - 2))
	var sell_choice: String = Dialogue.TALKS["meer_joris_menu"]["choices"][0]["text"]
	check(gs.fmt(sell_choice) == "Verkoop al mijn vis (24 munten)", "vooraf zie je wat je vis oplevert: %s" % gs.fmt(sell_choice))
	await talk_npc("meer_joris", [0])
	check(gs.coins == 8 + 8 + 4 + 4, "de eerste %d vissen krijgen de volle prijs, daarna de helft (%d munten)" % [Vis.FULL_PRICE_FISH, gs.coins])
	check(gs.check(["meer_vol"]) and gs.flag("meer_vol_gemeld") and seen_lines.any(func(line: String) -> bool: return "helft" in line), "Joris vertelt dat het dorp vol zit met vis")
	gs.coins = 0
	gs.give("meer_snoek", 2, true)
	gs.give("meer_laars", 1, true)
	await talk_npc("meer_joris", [0])
	check(gs.coins == 8 + 8 + 1, "daarna blijft het de halve prijs (en een laars is minstens 1 munt)")

	print("Vis verkopen: de Visserspet en de Gouden Karper")
	gs.new_game()
	gs.give("fishers_cap", 1, true)
	gs.give("meer_baars", 1, true)
	gs.give("meer_snoek", 1, true)
	gs.give(Vis.GOLDEN, 1, true)
	var sellable: Array = logic.sellable_fish()
	check(sellable.size() == 2 and sellable[0] == "meer_snoek" and sellable[1] == "meer_baars", "de Gouden Karper is niet te koop: hij is voor Joris")
	logic.sell_fish()
	check(gs.coins == 17 + 9 and gs.count(Vis.GOLDEN) == 1, "met de pet krijg je 10% extra (17 en 9 munten) en je houdt de karper")
	var last_full := Vis.FULL_PRICE_FISH - 1
	check(Vis.price("meer_baars", 0, false) == 8 and Vis.price("meer_baars", last_full, false) == 8 and Vis.price("meer_baars", last_full + 1, false) == 4, "prijzen: volle prijs tot en met de %de vis" % Vis.FULL_PRICE_FISH)
	check(Vis.price("meer_baars", last_full + 1, true) == 5 and Vis.price("meer_snoek", last_full + 1, true) == 9 and Vis.price("meer_laars", 0, true) == 2, "de pet geeft altijd iets extra, ook als het dorp vol vis zit")

	print("Vis verkopen: Mila")
	gs.new_game()
	gs.give("meer_snoek", 2, true)
	await talk("mila_menu", [1]) # 'Ik heb verse vis voor je!'
	check(gs.coins == 30 and gs.count("meer_snoek") == 0, "Mila koopt je vis voor soep (30 munten)")
	gs.coins = 0
	await talk("mila_menu", [0]) # zonder vis is de eerste keuze uitrusten
	check(gs.coins == 0, "zonder vis heeft Mila de keuze niet")
	gs.meer["verkocht"] = Vis.FULL_PRICE_FISH
	gs.give("meer_snoek", 2, true)
	await talk("mila_menu", [1])
	check(gs.coins == 16 and seen_lines.any(func(line: String) -> bool: return "halve prijs" in line), "zit het dorp vol vis, dan betaalt Mila de helft en zegt ze dat ook (%d munten)" % gs.coins)

	print("Economie")
	var one_full_load := 0
	for i in Vis.FULL_PRICE_FISH:
		one_full_load += Vis.price("meer_baars", i, false)
	check(one_full_load == 64 and Vis.FULL_PRICE_FISH * 15 <= 120, "de eerste %d vissen leveren hooguit 120 munten op, daarna de helft" % Vis.FULL_PRICE_FISH)
	var weights := 0.0
	var expected := 0.0
	for fish_id: String in Vis.CATCHES:
		weights += float(Vis.CATCHES[fish_id]["weight"])
		expected += float(Vis.CATCHES[fish_id]["weight"]) * float(Vis.CATCHES[fish_id]["sell"])
	check(expected / weights < 12.0, "een gewone vangst is gemiddeld %.1f munten waard" % (expected / weights))


# --- Opdrachten ----------------------------------------------------------------------------------------------

func test_quest_karper() -> void:
	print("Opdracht: De Gouden Karper")
	await fresh_game("lake")
	check(pick_talk("meer_joris") == "meer_joris_intro", "de eerste keer krijg je het kennismakingsgesprek")
	await talk_npc("meer_joris", [0, 0]) # intro, hengel, menu: 'Heb je werk voor me?', 'Ik ga hem vangen!'
	check(gs.flag("meer_joris_ontmoet") and gs.count("fishing_rod") == 1, "Joris geeft je gratis een hengel")
	check(gs.quest_state("meer_karper") == "active" and gs.quest_step("meer_karper") == 0, "Joris geeft de opdracht")
	check(gs.quest_text("meer_karper").contains("verre steiger"), "de opdrachttekst wijst naar de verre steiger")
	check(pick_talk("meer_joris") == "meer_joris_menu", "daarna krijg je zijn menu")
	await talk_npc("meer_joris", [0]) # menu: 'Hoe is het met de Gouden Karper?' (verkopen en werk vragen ontbreken nu)
	check(gs.quest_step("meer_karper") == 0 and gs.coins == 0, "zonder karper gebeurt er niets bijzonders")
	await talk_npc("meer_joris", [1, 0]) # tips, 'Hoe vang ik een vis?', en dan 'Dank je, genoeg.'
	check(not world.dialogue.active and not paused, "Joris' tips lopen netjes af")
	gs.give(Vis.GOLDEN, 1, true)
	check(gs.quest_step("meer_karper") == 1, "met de karper in je tas gaat de opdracht vanzelf naar de volgende stap")
	check(pick_talk("meer_joris") == "meer_joris_karper_klaar", "Joris wil hem zien")
	await talk_npc("meer_joris")
	check(gs.quest_state("meer_karper") == "done" and gs.coins == 40, "beloning: 40 munten")
	check(gs.count("fishers_cap") == 1 and gs.count(Vis.GOLDEN) == 0, "en de Visserspet (de karper blijft bij Joris)")
	check(not logic.golden_can_bite(), "daarna bijt de Gouden Karper niet meer")
	check(pick_talk("meer_joris") == "meer_joris_menu", "daarna is hij weer gewoon Joris")
	gs.give("meer_baars", 1, true)
	await talk_npc("meer_joris", [0])
	check(gs.coins == 49, "met de Visserspet krijg je 9 munten voor een baars")

	check(Dialogue.TALKS["meer_joris_menu"]["choices"].filter(func(c: Dictionary) -> bool: return gs.check_all(c.get("if", []))).size() == 3, "Joris' menu na de opdracht: tips, dorpstafel en weggaan")
	gs.set_flag("game_completed")
	await talk_npc("meer_joris", [1]) # 'Hoe gaat het nu de Slijmkoning weg is?', daarna weggaan
	check(not world.dialogue.active and not paused, "na het einde van het verhaal heeft Joris ook een praatje, en het gesprek sluit netjes")

	print("Opdracht: De Gouden Karper (karper eerst)")
	gs.new_game()
	gs.give(Vis.GOLDEN, 1, true)
	check(pick_talk("meer_joris") == "meer_joris_karper_direct", "met een karper in je tas voordat je de opdracht had, is Joris sprakeloos")
	await talk_npc("meer_joris")
	check(gs.quest_state("meer_karper") == "done" and gs.coins == 40 and gs.count("fishers_cap") == 1, "de opdracht is meteen afgerond")
	check(pick_talk("meer_joris") == "meer_joris_intro", "en de hengel krijg je alsnog bij het kennismakingsgesprek")


func test_quest_books() -> void:
	print("Opdracht: Boekenwurm")
	await fresh_game("library")
	check(pick_talk("meer_lena") == "meer_lena_intro", "Lena stelt zich voor")
	await talk_npc("meer_lena", [0, 0]) # intro, menu: 'Heb je werk voor me?', 'Ik zoek ze wel!'
	check(gs.quest_state("meer_boeken") == "active" and gs.flag("meer_lena_ontmoet"), "Lena geeft de opdracht")
	check(not gs.check(["meer_boeken", 1]) and pick_talk("meer_lena") == "meer_lena_voortgang", "nog geen boeken")
	check(gs.quest_text("meer_boeken").ends_with("(0/3)"), "de opdrachttekst telt mee: %s" % gs.quest_text("meer_boeken").right(6))
	await talk_npc("meer_lena")
	check(gs.quest_step("meer_boeken") == 0, "zonder boeken verandert er niets")

	# boek 1: in de kist in het huisje van Joris
	world.load_map("fisher_hut", "start")
	await frames(5)
	var chest: Node = find_node("interactable", func(n: Node) -> bool: return "contents" in n)
	check(chest != null and chest.contents[0][0] == "meer_boek_hut", "in het huisje van Joris ligt een boek in een kist")
	await put_player(chest.global_position + Vector2(0, 32))
	chest.interact()
	check(gs.count("meer_boek_hut") == 1 and gs.check(["meer_boeken", 1]), "boek 1 gevonden")
	check(gs.quest_text("meer_boeken").ends_with("(1/3)"), "de opdrachttekst telt: 1 van 3")
	check(gs.quest_step("meer_boeken") == 0, "nog twee te gaan")
	var signs := get_nodes_in_group("interactable").filter(func(n: Node) -> bool: return "lines" in n)
	check(signs.size() == 2 and signs.all(func(n: Node) -> bool: return n.lines.size() >= 2), "het huisje heeft twee leesbare briefjes")

	# boek 2: op het eiland (via de echte doorgang is het niet nodig, de wereld laadt gewoon)
	world.load_map("lake", "start")
	await frames(5)
	var book: Node = find_node("pickups", func(p: Node) -> bool: return p.item == "meer_boek_eiland")
	await put_player(book.global_position + Vector2(0, 48))
	await put_player(book.global_position)
	await frames(5)
	check(gs.count("meer_boek_eiland") == 1 and gs.check(["meer_boeken", 2]), "boek 2 gevonden op het eiland")
	await put_player(tile_center([21, 14]))
	await talk_npc("meer_lena")
	check(gs.quest_state("meer_boeken") == "active", "met twee boeken is Lena nog niet klaar (ze vertelt wat er nog mist)")

	# boek 3: van Sanne, voor een vis
	check(pick_talk("meer_sanne") == "meer_sanne_intro", "Sanne vertelt over haar laars")
	await talk_npc("meer_sanne", [0]) # alleen 'Ik kom terug met een vis.'
	check(gs.count("meer_boek_sanne") == 0 and gs.flag("meer_sanne_ontmoet"), "zonder vis geeft Sanne haar boek niet")
	check(pick_talk("meer_sanne") == "meer_sanne_menu", "de tweede keer begint ze meteen over de vis")
	gs.give("meer_laars", 1, true)
	gs.give("meer_snoek", 1, true)
	await talk_npc("meer_sanne", [1]) # keuzes: snoek, laars, 'ik kom terug' (de baars ontbreekt)
	check(gs.count("meer_boek_sanne") == 1 and gs.count("meer_laars") == 0 and gs.count("meer_snoek") == 1, "voor haar eigen laars krijg je het boek, en je houdt je snoek")
	check(gs.flag("meer_sanne_boek") and pick_talk("meer_sanne") == "meer_sanne_klaar", "Sanne bedankt je daarna alleen nog")
	check(gs.quest_step("meer_boeken") == 1, "alle drie de boeken: breng ze naar Lena")

	# terug naar Lena
	world.load_map("library", "start")
	await frames(5)
	var kast_cell := Vector2i(17, 6)
	check(world.is_solid(Vector2(kast_cell) * 32.0 + Vector2(16, 16)), "de geheime kast zit nog dicht")
	check(pick_talk("meer_lena") == "meer_lena_boeken_terug", "Lena herkent haar boeken")
	var coins_before: int = gs.coins
	await talk_npc("meer_lena")
	check(gs.quest_state("meer_boeken") == "done" and gs.coins == coins_before + 30, "beloning: 30 munten")
	check(gs.count("meer_boek_eiland") == 0 and gs.count("meer_boek_hut") == 0 and gs.count("meer_boek_sanne") == 0, "de boeken staan weer in de kast")
	check(gs.flag("meer_achterkamer"), "je bent nu lid: de achterkamer is vrij")
	await frames(10)
	check(not world.is_solid(Vector2(kast_cell) * 32.0 + Vector2(16, 16)) and not world.is_solid(Vector2(17, 7) * 32.0 + Vector2(16, 16)), "de geheime kast schuift opzij nadat het gesprek voorbij is")
	check(world.tile_layer.get_cell_atlas_coords(kast_cell).x == Tiles.index_of("meer_bibvloer"), "op die plek ligt nu vloer")
	# door de opening lopen
	await put_player(Vector2(16, 6) * 32.0 + Vector2(16, 16))
	Input.action_press("move_right")
	await frames(90)
	Input.action_release("move_right")
	check(world.player.global_position.x > 19.0 * 32.0, "je kunt echt het achterkamertje in lopen")
	var alcove_chest: Node = find_node("interactable", func(n: Node) -> bool: return "contents" in n)
	var potions: int = gs.count("potion")
	coins_before = gs.coins
	alcove_chest.interact()
	check(gs.count("potion") == potions + 1 and gs.coins == coins_before + 15, "de kist in het achterkamertje: een Helddrank en 15 munten")
	check(pick_talk("meer_lena") == "meer_lena_klaar", "Lena is blij met haar lezer")

	print("Opdracht: Boekenwurm (opslaan en opnieuw laden)")
	gs.save_game(world.player.global_position)
	gs.new_game()
	check(gs.load_game(), "laden")
	world.load_map("library", "start")
	await frames(5)
	check(not world.is_solid(Vector2(kast_cell) * 32.0 + Vector2(16, 16)), "na het laden staat de kast meteen open")
	check(gs.quest_state("meer_boeken") == "done", "en de opdracht is nog afgerond")
	gs.use_load_pos = false

	print("Opdracht: Boekenwurm (de boeken al gevonden)")
	await fresh_game("library")
	for book_id: String in ["meer_boek_eiland", "meer_boek_hut", "meer_boek_sanne"]:
		gs.give(book_id, 1, true)
	await talk_npc("meer_lena", [0, 0]) # intro, menu: 'Heb je werk voor me?', 'Ik zoek ze wel!'
	check(gs.quest_state("meer_boeken") == "done" and gs.coins == 30 and gs.flag("meer_achterkamer"), "had je de boeken al, dan lever je ze meteen in")

	print("De geheime kast wacht tot je klaar bent")
	await fresh_game("library")
	gs.start_dialogue("meer_lena_over")
	await frames(2)
	gs.set_flag("meer_achterkamer")
	await frames(5)
	check(world.dialogue.active and world.is_solid(Vector2(kast_cell) * 32.0 + Vector2(16, 16)), "zolang er een gesprek open is, blijft de kast dicht")
	await finish_dialogue()
	await frames(5)
	check(not world.is_solid(Vector2(kast_cell) * 32.0 + Vector2(16, 16)), "daarna schuift hij open")


func test_sanne() -> void:
	print("Sanne")
	for fish_id: String in ["meer_baars", "meer_snoek"]:
		await fresh_game("lake")
		gs.set_flag("meer_sanne_ontmoet")
		gs.give(fish_id, 2, true)
		await talk_npc("meer_sanne", [0]) # de vis is de eerste keuze
		check(gs.count("meer_boek_sanne") == 1 and gs.flag("meer_sanne_boek") and gs.count(fish_id) == 1, "voor een %s geeft Sanne haar boek (en ze houdt er één)" % String(Items.info(fish_id)["name"]).to_lower())


func test_library() -> void:
	print("Bibliotheek")
	await fresh_game("library")
	var stands: Array = get_nodes_in_group("interactable").filter(func(n: Node) -> bool: return "book_id" in n)
	check(stands.size() == 6, "zes lessenaars in de bibliotheek")
	var all_ok := true
	for stand in stands:
		await put_player(stand.global_position + Vector2(0, 32))
		stand.interact()
		await frames(3)
		var title: String = Boeken.TEXTS[stand.book_id]["title"]
		var shown: String = world.dialogue.text_label.text
		all_ok = all_ok and world.dialogue.active and world.dialogue.speaker_label.text == title and shown.length() > 40
		await finish_dialogue()
		all_ok = all_ok and stand.is_read() and not world.dialogue.active and not paused
	check(all_ok, "elke lessenaar toont zijn eigen tekst en sluit netjes")
	check(logic.read_count() == 6 and gs.check(["meer_gelezen", 6]), "alle zes gelezen")
	await fresh_game("library")
	check(not gs.check(["meer_gelezen", 1]), "een nieuw spel begint ongelezen")
	gs.start_quest("meer_boeken")
	gs.finish_quest("meer_boeken")
	for book_id: String in Boeken.TEXTS:
		gs.set_flag(Boeken.flag_name(book_id))
	check(pick_talk("meer_lena") == "meer_lena_klaar", "Lena na de opdracht")
	await talk_npc("meer_lena", [0])
	check(not world.dialogue.active and not paused, "het gesprek van Lena met een trotse lezer sluit netjes")
	var surprised := seen_lines.any(func(line: String) -> bool: return "álle lessenaars" in line)
	await talk_npc("meer_lena", [0])
	var surprised_again := seen_lines.any(func(line: String) -> bool: return "álle lessenaars" in line)
	check(surprised and not surprised_again, "Lena is één keer verrast dat je alles gelezen hebt, niet bij elk gesprek")
	check(not gs.check(["flag", "game_completed"]), "voor het einde van het verhaal weet Lena niets over de Diepte te vertellen")
	var lena_choices: Array = Dialogue.TALKS["meer_lena_menu"]["choices"]
	var menu_choices: Array = lena_choices.filter(func(c: Dictionary) -> bool: return gs.check_all(c.get("if", [])))
	check(menu_choices.size() == 3, "Lena behoudt boeken en weggaan, met de optionele kruidenbereiding erbij")
	gs.set_flag("game_completed")
	menu_choices = lena_choices.filter(func(c: Dictionary) -> bool: return gs.check_all(c.get("if", [])))
	check(menu_choices.size() == 4, "na het einde komt de Diepte erbij; de samenwerking blijft optioneel")
	await talk("meer_lena_menu", [0]) # 'Wat weet je over de Diepte?'
	var diepte_text: String = " ".join(Dialogue.TALKS["meer_lena_diepte"]["lines"])
	check("Sterrenkaart" in diepte_text and "Kristaltempel" in diepte_text and "Wachter" in diepte_text, "Lena vertelt over de Sterrenkaart, de Kristaltempel en de Wachter")


# --- Menu, opslaan en laden -----------------------------------------------------------------------------------

func test_menu_and_save() -> void:
	print("Kaart in het menu")
	await fresh_game("lake")
	for map_id: String in MEER_MAPS:
		world.load_map(map_id, "start")
		await frames(5)
		press("map")
		await frames(4)
		check(world.menu_ui.active and world.menu_ui.tab == 2, "N toont de kaart van %s" % Maps.get_map(map_id)["name"])
		var labels := {}
		for mark: Dictionary in world.menu_ui.extension_marks(world.map_data):
			labels[mark["label"]] = int(labels.get(mark["label"], 0)) + 1
		var want: Dictionary = {"lake": {"visplek": 5, "diepe visplek": 1, "grondstof": 4, "Dorpsmaaltijd": 3, "Werktekening":1}, "fisher_hut": {}, "library": {"lessenaar": 6,"Werktekening":1}}[map_id]
		check(labels == want, "de bijzondere plekken op het kaartje: %s" % [labels])
		press("pause")
		await frames(3)
		check(not world.menu_ui.active and not paused, "Esc sluit de kaart")
	var lake_def: Dictionary = Maps.get_map("lake")
	var cell := mini(int(940.0 / 44.0), int(400.0 / 32.0))
	check(cell * 44 <= 940 and cell * 32 <= 400 and cell >= 8, "het meer past netjes op het kaartje (%d pixels per tegel)" % cell)
	check(lake_def["name"] == "Zilvermeer", "de kaart heet Zilvermeer")

	print("Opslaan en laden")
	gs.new_game()
	gs.in_game = true
	gs.give("fishing_rod", 1, true)
	gs.give("meer_baars", 2, true)
	gs.give("fishers_cap", 1, true)
	gs.meer = {"verkocht": 7, "gevangen": 9, "pech": 3}
	gs.set_flag("meer_achterkamer")
	gs.set_flag(Boeken.flag_name("diepte"))
	gs.start_quest("meer_boeken")
	gs.map_id = "lake"
	check(gs.save_game(Vector2(700, 700)), "opslaan")
	gs.new_game()
	check(gs.count("fishing_rod") == 0 and gs.meer.is_empty(), "een nieuw spel begint zonder hengel en zonder statistieken")
	check(gs.load_game(), "laden")
	check(gs.count("fishing_rod") == 1 and gs.count("meer_baars") == 2 and gs.count("fishers_cap") == 1, "hengel, vis en pet zijn terug")
	check(logic.sold_count() == 7 and int(gs.meer["gevangen"]) == 9 and logic.pity() == 3, "de visstatistieken zijn terug")
	check(gs.flag("meer_achterkamer") and gs.flag(Boeken.flag_name("diepte")) and gs.quest_state("meer_boeken") == "active", "vlaggen en opdrachten zijn terug")
	check(gs.map_id == "lake", "en je staat weer bij het meer")
	check(gs.check(["meer_vis"]), "de opgeslagen vis is te verkopen")
	gs.use_load_pos = false

	# Een oude opslag zonder het veld "meer" blijft werken.
	var old_save := {"version": 1, "map": "village", "pos": [100.0, 100.0], "hp": 5, "coins": 12, "inventory": {"potion": 2}, "flags": {"met_greta": true}, "quests": {}, "weapon": "wood"}
	var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_save))
	file.close()
	check(gs.load_game() and gs.coins == 12 and gs.meer.is_empty() and logic.sold_count() == 0 and logic.pity() == 0, "een oude opslag zonder visgegevens laadt gewoon")
	gs.use_load_pos = false
	gs.new_game()
	gs.in_game = true


func _run() -> void:
	gs = root.get_node("GameState")
	logic = load("res://scripts/data/ext/meer_logic.gd")
	gs.new_game()
	gs.in_game = true
	test_data()
	test_reel_logic()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)
	await test_travel()
	await test_pickups_and_chests()
	await test_fishing()
	await test_selling()
	await test_quest_karper()
	await test_quest_books()
	await test_sanne()
	await test_library()
	await test_menu_and_save()

	print("")
	if failures == 0:
		print("MEER TEST OK")
		quit(0)
	else:
		print("MEER TEST: %d fout(en)" % failures)
		quit(1)
