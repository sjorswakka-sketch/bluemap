extends SceneTree
const Progression := preload("res://scripts/core/progression.gd")
## Test voor de Diepte, De Vergeten Wachter, het Sterrenzwaard en Nieuw spel+. Draaien met:
##   sh tools/run_tests.sh /pad/naar/godot      (alle tests, met een eigen opslagmap)
## Draai je hem los (godot --headless --fixed-fps 60 --path . -s tests/diepte_test.gd), dan zet de test je opgeslagen
## spel en je Nieuw spel+ eerst opzij en aan het eind weer terug.
## Exitcode 0 = alles goed, 1 = er ging iets mis.
##
## Deel 1: gegevens (tegels, plaatjes, geluiden, kaarten). Deel 2: bereikbaarheid met een flood-fill. Deel 3: de toegang
## (zegel, trap, Bram) en de puzzel (sleutel, poort, trap). Deel 4: de baas. Deel 5: de hele Diepte uitspelen.
## Deel 6: opslaan. Deel 7: Nieuw spel+.

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Items := preload("res://scripts/data/items.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const Dialogue := preload("res://scripts/data/dialogue.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Art := preload("res://scripts/core/art.gd")
const Content := preload("res://scripts/data/content.gd")

const DEPTH_MAPS := ["depths1", "depths2"]
const STATE_LIMIT := 3.0 # geen enkele toestand van de baas duurt langer dan dit (behalve slapen)

var failures := 0
var gs: Node
var world: Node2D
var user_backup := {} # opslag en Nieuw spel+ van de echte speler (pad -> inhoud)


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


func press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	root.push_input(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	root.push_input(up)


func tile_center(tile: Array) -> Vector2:
	return Vector2(float(tile[0]) * 32.0 + 16.0, float(tile[1]) * 32.0 + 16.0)


func objects(map_id: String, type: String) -> Array:
	return Maps.get_map(map_id)["objects"].filter(func(o: Dictionary) -> bool: return o["type"] == type)


func rect_of(obj: Dictionary) -> Rect2:
	var size: Array = obj.get("size", [1, 1])
	return Rect2(Vector2(obj["pos"][0], obj["pos"][1]) * 32.0, Vector2(size[0], size[1]) * 32.0)


func clean_meta() -> void:
	if FileAccess.file_exists(gs.NG_META_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.NG_META_PATH))


## Deze test schrijft en wist de opslag en user://ng_plus.cfg. Die van de echte speler gaan eerst opzij en straks terug.
func back_up_user_files() -> void:
	for path: String in [gs.SAVE_PATH, gs.NG_META_PATH]:
		if FileAccess.file_exists(path):
			user_backup[path] = FileAccess.get_file_as_bytes(path)


func restore_user_files() -> void:
	for path: String in [gs.SAVE_PATH, gs.NG_META_PATH]:
		if user_backup.has(path):
			FileAccess.open(path, FileAccess.WRITE).store_buffer(user_backup[path])
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Een nieuwe wereld op een bepaalde kaart, met een schoon spel (zonder opslag of meta).
func start_world(map_id: String, flags: Array = []) -> void:
	if is_instance_valid(world):
		world.queue_free()
		await frames(3)
	gs.new_game()
	gs.in_game = true
	for flag_name: String in flags:
		gs.set_flag(flag_name)
	gs.map_id = map_id
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)
	world.player.invuln = 999.0


func put_player(pos: Vector2) -> void:
	world.player.global_position = pos
	world.player.velocity = Vector2.ZERO
	await frames(3)


func find_nodes(group: String, test: Callable) -> Array:
	var found: Array = []
	for node in get_nodes_in_group(group):
		if test.call(node):
			found.append(node)
	return found


func count_coin_pickups() -> int:
	return find_nodes("pickups", func(p: Node) -> bool: return p.item == "coin").size()


func children_with_script(file_name: String) -> Array:
	var found: Array = []
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with(file_name):
			found.append(child)
	return found


## Klikt een gesprek door tot het klaar is (met een tijdslimiet).
func finish_dialogue() -> void:
	var guard := 0
	while world.dialogue.active and guard < 200:
		guard += 1
		if not world.dialogue.buttons.is_empty():
			world.dialogue.buttons[0].pressed.emit()
		else:
			press("interact")
		await frames(2)


func talk(talk_id: String) -> void:
	gs.start_dialogue(talk_id)
	await frames(2)
	await finish_dialogue()


# --- Flood-fill -------------------------------------------------------------------------------------------

func tiles_of(obj: Dictionary) -> Array[Vector2i]:
	var size: Array = obj.get("size", [1, 1])
	var found: Array[Vector2i] = []
	for dx in int(size[0]):
		for dy in int(size[1]):
			found.append(Vector2i(int(obj["pos"][0]) + dx, int(obj["pos"][1]) + dy))
	return found


## Alle tegels waar je vanaf `start` kunt komen. Met `closed_gates` zijn de poorten dicht (dan tellen ze als muur).
## `walls` zijn extra tegels die als muur tellen.
func flood(map_id: String, start: Vector2i, closed_gates: bool, walls: Array[Vector2i] = []) -> Dictionary:
	var def: Dictionary = Maps.get_map(map_id)
	var rows: Array = def["rows"]
	var blocked := {}
	for tile in walls:
		blocked[tile] = true
	if closed_gates:
		for obj: Dictionary in def["objects"]:
			if obj["type"] in ["gate", "diepte_gate"]:
				for tile in tiles_of(obj):
					blocked[tile] = true
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := at + step
			if next.y < 0 or next.y >= rows.size() or next.x < 0 or next.x >= String(rows[0]).length():
				continue
			if seen.has(next) or blocked.has(next) or Tiles.is_solid_char(String(rows[next.y])[next.x]):
				continue
			seen[next] = true
			queue.append(next)
	return seen


## Is dit voorwerp bereikbaar? Doorgangen, poorten en triggers: een van hun tegels. De rest: de tegel zelf of een buur.
func reachable(obj: Dictionary, seen: Dictionary) -> bool:
	var tiles := tiles_of(obj)
	if obj["type"] in ["portal", "trigger", "gate", "diepte_gate"]:
		for tile in tiles:
			if seen.has(tile):
				return true
		return false
	var at := tiles[0]
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if seen.has(at + Vector2i(dx, dy)):
				return true
	return false


# --- Deel 1: gegevens -----------------------------------------------------------------------------------

func test_data() -> void:
	print("Tegels, plaatjes en geluiden")
	var new_tiles := ["void_floor", "void_wall", "void_crystal", "rune_pad", "void_stairs"]
	var tiles_ok := true
	for tile_name: String in new_tiles:
		tiles_ok = tiles_ok and tile_name in Tiles.NAMES
	check(tiles_ok and Tiles.NAMES.find("void_floor") > Tiles.NAMES.find("mat"), "de nieuwe tegels staan achteraan in de lijst")
	check(Tiles.is_solid_name("void_wall") and Tiles.is_solid_name("void_crystal"), "muren en kristallen zijn solide")
	check(not Tiles.is_solid_name("void_floor") and not Tiles.is_solid_name("rune_pad") and not Tiles.is_solid_name("void_stairs"), "vloer, runenplaat en trap zijn begaanbaar")
	var chars_ok := true
	for tile_name: String in new_tiles:
		chars_ok = chars_ok and Tiles.CHARS.find_key(tile_name) != null
	check(chars_ok, "elke nieuwe tegel heeft een teken in de kaart")
	check(Art.tex("tiles").get_width() == Tiles.NAMES.size() * 16, "tiles.png heeft een tegel voor elke naam")
	# Staat elk plaatje op de goede plek in tiles.png? Een paar pixels uit tools/art_tiles.py (de tekenfuncties). Klopt dit
	# niet, dan is de volgorde van NAMES veranderd zonder dat tiles.png opnieuw is gemaakt (python3 tools/make_art.py).
	var spots := {
		"void_floor": [[10, 4, "9a8cf0"], [0, 0, "3f3880"]],
		"void_wall": [[2, 3, "6a5cc8"], [0, 15, "090719"]],
		"void_crystal": [[8, 2, "ffffff"], [14, 4, "a8e8ff"]],
		"rune_pad": [[8, 8, "ffffff"], [8, 1, "6a58d8"]],
		"void_stairs": [[3, 1, "7a50d8"], [0, 0, "0a0820"]],
	}
	var tiles_img: Image = Art.tex("tiles").get_image()
	var spots_ok := true
	for tile_name: String in spots:
		var cell := Tiles.NAMES.find(tile_name)
		for spot: Array in spots[tile_name]:
			var pixel := tiles_img.get_pixel(cell * 16 + int(spot[0]), int(spot[1]))
			if not pixel.is_equal_approx(Color.html(spot[2])):
				print("       ", tile_name, " ", spot, " is ", pixel.to_html(false))
				spots_ok = false
	check(spots_ok, "elke tegel van de Diepte staat op de goede plek in tiles.png")

	var guardian_tex := Art.tex("guardian")
	check(guardian_tex.get_height() == 48 and guardian_tex.get_width() == 8 * 48, "guardian.png: 8 vakjes van 48x48")
	var sheet: Image = guardian_tex.get_image()
	var frames_ok := true
	var seen_frames: Array[PackedByteArray] = []
	for i in 8:
		var frame := sheet.get_region(Rect2i(i * 48, 0, 48, 48))
		var solid := 0
		for y in 48:
			for x in 48:
				if frame.get_pixel(x, y).a > 0.5:
					solid += 1
		if solid < 600 or solid > 2000:
			frames_ok = false
		seen_frames.append(frame.get_data())
	check(frames_ok, "elk vakje van de Wachter is gevuld, maar niet vol (geen lege of kapotte plaatjes)")
	var distinct := {}
	for data: PackedByteArray in seen_frames:
		distinct[hash(data)] = true
	check(distinct.size() == 8, "alle acht de vakjes van de Wachter zijn verschillend")
	check(Art.tex("golem_void").get_width() == 4 * 32 and Art.tex("golem_void").get_height() == 32, "golem_void.png: 4 vakjes van 32x32")
	check(Art.tex("depths_pillar").get_width() == 32 and Art.tex("depths_pillar").get_height() == 32, "depths_pillar.png: 2 vakjes van 16x32")
	check(Art.tex("depths_seal").get_width() == 3 * 32 and Art.tex("depths_seal").get_height() == 32, "depths_seal.png: 3 vakjes van 32x32")
	check(Art.tex("depths_objects").get_width() >= 5 * 16, "depths_objects.png heeft lamp, poort en scherven")
	check(Art.tex("items_diepte").get_width() >= 2 * 16, "items_diepte.png heeft de iconen")

	var sound := root.get_node("Sound")
	var sounds_ok := true
	for sound_name: String in ["guardian_roar", "guardian_charge", "pillar_charge", "shard_burst", "phase_shift", "seal_break", "star_fanfare", "guardian_die"]:
		sounds_ok = sounds_ok and sound.streams.has(sound_name)
	check(sounds_ok, "alle geluiden van de Diepte zijn geladen")
	check(sound.tracks.has("depths") and sound.tracks.has("guardian"), "de muziek van de Diepte en de baas is geladen")

	print("Voorwerpen, zwaard, vijanden en opdracht")
	var star: Dictionary = Items.WEAPONS["star"]
	check(star["damage"] == 4 and float(star["reach"]) == 48.0, "Sterrenzwaard: schade 4, bereik 48")
	check(star["damage"] > Items.WEAPONS["crystal"]["damage"] and star["reach"] > Items.WEAPONS["crystal"]["reach"], "het is het sterkste zwaard")
	var color: Color = star["color"]
	check(color.b >= 0.95 and color.r > 0.7 and color.g > 0.85, "het zwaard is lichtblauw-wit (sterrenkleur)")
	check(Items.sheet_of(star["item"]) == "items_diepte" and Items.ITEMS["sword_star"]["type"] == "weapon", "het zwaard heeft een eigen icoon")
	check(Items.ITEMS["diepte_key"]["sheet"] == "items_diepte" and int(Items.ITEMS["diepte_key"]["icon"]) == 1, "de sleutel heeft een eigen icoon")
	check(Enemies.info("guardian")["hp"] >= 90 and Enemies.info("guardian")["hp"] <= 120 and Enemies.info("guardian")["boss"], "de Wachter is een baas met ongeveer honderd levens")
	check(Enemies.info("diepte_golem")["boss"] and Enemies.info("diepte_golem")["sheet"] == "golem_void", "de paarse kristalgolem heeft een eigen plaatje")
	var quest: Dictionary = Quests.info("diepte")
	check(quest["title"] == "De Vergeten Wachter" and quest["steps"].size() == 4, "de opdracht heeft vier stappen")
	check(Dialogue.TALKS.has("diepte_bram_hint") and Dialogue.TALKS.has("guardian_intro") and Dialogue.TALKS.has("guardian_defeat"), "de gesprekken bestaan")
	check(Content.object_types().has("guardian") and Content.object_types().has("diepte_seal"), "de objectsoorten zijn aangemeld")

	print("Kaarten")
	for map_id: String in DEPTH_MAPS:
		var def: Dictionary = Maps.get_map(map_id)
		var rows: Array = def["rows"]
		var even := true
		for row: String in rows:
			even = even and row.length() == String(rows[0]).length()
		check(even, "%s: alle rijen even lang (%dx%d)" % [map_id, String(rows[0]).length(), rows.size()])
		check(float(def["dark"]) >= 0.75 and def["music"] == "depths", "%s is donker en heeft eigen muziek" % map_id)
	check(Maps.get_map("depths1")["rows"].size() == 30 and String(Maps.get_map("depths1")["rows"][0]).length() == 40, "depths1 is 40x30")
	check(String(Maps.get_map("depths2")["rows"][0]).length() >= 26 and Maps.get_map("depths2")["rows"].size() >= 23, "depths2 is een groot baasplein")
	var tile_kinds := {}
	for row: String in Maps.get_map("depths1")["rows"] + Maps.get_map("depths2")["rows"]:
		for i in row.length():
			tile_kinds[Tiles.CHARS.get(row[i], "")] = true
	var all_new := true
	for tile_name: String in new_tiles:
		all_new = all_new and tile_kinds.has(tile_name)
	check(all_new, "de kaarten gebruiken alle nieuwe tegels")
	var d1_types := {}
	for obj: Dictionary in Maps.get_map("depths1")["objects"]:
		d1_types[obj.get("kind", obj["type"])] = true
	check(d1_types.has("slime_red") and d1_types.has("skeleton") and d1_types.has("diepte_golem"), "depths1: rode slijmen, skeletten en een paarse kristalgolem")
	check(objects("depths1", "chest").size() >= 2 and objects("depths1", "chest").size() <= 3, "depths1 heeft 2 of 3 kisten")
	check(objects("depths2", "guardian").size() == 1 and objects("depths2", "guardian")[0]["pillars"].size() >= 4, "depths2 heeft de Wachter met pilaren")
	var temple_portal: Dictionary = {}
	for obj: Dictionary in objects("temple", "portal"):
		if obj["to"] == "depths1":
			temple_portal = obj
	var requires: Array = temple_portal.get("requires", [])
	check(requires.has(["flag", "game_completed"]) and requires.has(["flag", "diepte_opened"]), "de trap in de tempel vraagt om game_completed en een gebroken zegel")


# --- Deel 2: bereikbaarheid ----------------------------------------------------------------------------

func test_reachability() -> void:
	print("Bereikbaarheid (flood-fill)")
	for map_id: String in DEPTH_MAPS:
		var def: Dictionary = Maps.get_map(map_id)
		var start_tile: Array = def["spawns"]["start"]
		var seen := flood(map_id, Vector2i(start_tile[0], start_tile[1]), false)
		var lost: Array = []
		for obj: Dictionary in def["objects"]:
			if not reachable(obj, seen):
				lost.append("%s %s" % [obj["type"], obj["pos"]])
		check(lost.is_empty(), "%s: alles is bereikbaar (poorten open) %s" % [map_id, lost])
		var spawns_ok := true
		for spawn_name: String in def["spawns"]:
			var tile: Array = def["spawns"][spawn_name]
			spawns_ok = spawns_ok and seen.has(Vector2i(tile[0], tile[1]))
		check(spawns_ok, "%s: elke startplek is begaanbaar en verbonden" % map_id)
		var rows: Array = def["rows"]
		var floor_total := 0
		for y in rows.size():
			for x in String(rows[0]).length():
				if not Tiles.is_solid_char(String(rows[y])[x]):
					floor_total += 1
		check(seen.size() == floor_total, "%s: geen opgesloten of onbereikbare vloer (%d van %d tegels)" % [map_id, seen.size(), floor_total])
		var on_wall := true
		for obj: Dictionary in def["objects"]:
			if obj["type"] in ["enemy", "chest", "pickup", "savepoint", "guardian", "diepte_lamp", "sign"]:
				var at: Array = obj["pos"]
				on_wall = on_wall and not Tiles.is_solid_char(String(def["rows"][at[1]])[at[0]])
		check(on_wall, "%s: niets staat in een muur" % map_id)

	# De puzzel: zonder de poort open te maken kom je wel bij de sleutel, maar niet bij de trap.
	var start1: Array = Maps.get_map("depths1")["spawns"]["start"]
	var closed := flood("depths1", Vector2i(start1[0], start1[1]), true)
	var key_chest: Dictionary = {}
	var stairs_portal: Dictionary = {}
	for obj: Dictionary in objects("depths1", "chest"):
		if obj["contents"][0][0] == "diepte_key":
			key_chest = obj
	for obj: Dictionary in objects("depths1", "portal"):
		if obj["to"] == "depths2":
			stairs_portal = obj
	check(not key_chest.is_empty() and reachable(key_chest, closed), "de sleutelkist is bereikbaar zonder poort")
	check(not stairs_portal.is_empty() and not reachable(stairs_portal, closed), "de trap naar de baas is alleen bereikbaar via de poort")
	var open_seen := flood("depths1", Vector2i(start1[0], start1[1]), false)
	check(reachable(stairs_portal, open_seen), "met de poort open is de trap bereikbaar")
	var guards_key := false
	for obj: Dictionary in objects("depths1", "enemy"):
		if obj["kind"] == "diepte_golem":
			var key_tile: Array = key_chest["pos"]
			var golem_tile: Array = obj["pos"]
			guards_key = Vector2(key_tile[0], key_tile[1]).distance_to(Vector2(golem_tile[0], golem_tile[1])) < 8.0
	check(guards_key, "de paarse kristalgolem staat bij de sleutelkist")

	# Je kunt niet om de intro van de Wachter heen lopen: wie de trigger als muur ziet, komt niet bij de baas.
	var intro: Dictionary = {}
	for obj: Dictionary in objects("depths2", "trigger"):
		if obj.get("once", "") == "guardian_started":
			intro = obj
	var start2: Array = Maps.get_map("depths2")["spawns"]["start"]
	var around := flood("depths2", Vector2i(start2[0], start2[1]), false, tiles_of(intro))
	var boss_tile: Array = objects("depths2", "guardian")[0]["pos"]
	check(not around.has(Vector2i(boss_tile[0], boss_tile[1])), "je kunt niet langs de intro van de Wachter lopen (de trigger is zo breed als de gang)")

	# De tempel is na de baas te belopen, tot aan de trap.
	var temple_seen := flood("temple", Vector2i(11, 19), false)
	check(temple_seen.has(Vector2i(11, 3)) and temple_seen.has(Vector2i(11, 1)) and temple_seen.has(Vector2i(12, 0)), "de tempel is doorloopbaar tot de trap achter de arena")
	var temple_def: Dictionary = Maps.get_map("temple")
	var from_depths: Array = temple_def["spawns"]["from_depths"]
	check(temple_seen.has(Vector2i(from_depths[0], from_depths[1])), "je komt uit de Diepte op een begaanbare plek in de tempel")


# --- Deel 3: toegang en puzzel --------------------------------------------------------------------------

func walk_through(portal: Dictionary) -> void:
	var rect := rect_of(portal)
	await put_player(rect.get_center() + Vector2(0, 70))
	await put_player(rect.get_center())
	await frames(70)


func test_access() -> void:
	print("De Diepte is dicht tot het einde")
	var stairs: Dictionary = {}
	for obj: Dictionary in objects("temple", "portal"):
		if obj["to"] == "depths1":
			stairs = obj
	await start_world("temple", ["boss_started", "boss_defeated"])
	check(find_nodes("boss", func(b: Node) -> bool: return true).is_empty(), "na de baas staat er geen Slijmkoning meer in de tempel")
	var arena_gates := children_with_script("gate.gd").filter(func(g: Node) -> bool: return g.gate_id == "arena")
	check(arena_gates.size() == 1 and not arena_gates[0].blocked, "de arena-deur is open: je kunt door de hele tempel lopen")
	var seals := children_with_script("diepte_seal.gd")
	check(seals.size() == 1, "het zegel zit voor de trap")
	var seal: Node = seals[0]
	await walk_through(stairs)
	check(gs.map_id == "temple", "zonder game_completed brengt de trap je nergens heen")
	await put_player(seal.global_position + Vector2(16, 90))
	await frames(150)
	check(is_instance_valid(seal) and not gs.flag("diepte_opened"), "zonder game_completed breekt het zegel niet, ook niet als je ernaast staat")
	check(gs.quest_state("diepte") == "none", "en de opdracht begint niet")
	seal.interact()
	await frames(3)
	check(world.dialogue.active, "je kunt het zegel bekijken (E), met een uitleg")
	await finish_dialogue()

	print("Het einde opent de Diepte")
	gs.set_flag("game_completed")
	await put_player(seal.global_position + Vector2(16, 300))
	await frames(10)
	check(is_instance_valid(seal) and not gs.flag("diepte_opened"), "veraf blijft het zegel dicht")
	gs.set_flag("diepte_opened") # zo'n spel kan niet bestaan, maar dan nog moet de trap dicht blijven zonder echt einde
	gs.set_flag("game_completed", false)
	await walk_through(stairs)
	check(gs.map_id == "temple", "alleen diepte_opened zonder game_completed is niet genoeg")
	gs.set_flag("diepte_opened", false)
	gs.set_flag("game_completed")
	gs.transitioning = true # zoals tijdens een overgang of een gesprek: dan gebeurt er niets
	await put_player(seal.global_position + Vector2(16, 90))
	await frames(20)
	check(is_instance_valid(seal) and not seal.breaking, "tijdens een overgang breekt het zegel niet")
	gs.transitioning = false
	var toasts: Array[String] = []
	var record_toast := func(text: String) -> void: toasts.append(text)
	gs.toast.connect(record_toast)
	await frames(30)
	check(is_instance_valid(seal) and seal.breaking, "met game_completed begint het zegel te breken zodra je dichtbij komt")
	await frames(130)
	gs.toast.disconnect(record_toast)
	check(not is_instance_valid(seal) or seal.is_queued_for_deletion(), "het zegel is gebroken")
	check(toasts.size() >= 2 and toasts[0].begins_with("Het zegel is gebroken") and toasts[1].begins_with("Nieuwe opdracht"), "eerst 'het zegel is gebroken', dan de nieuwe opdracht (%s)" % [toasts])
	check(gs.flag("diepte_opened") and gs.quest_state("diepte") == "active" and gs.quest_step("diepte") == 1, "de vlag staat aan en de opdracht begint (stap 2)")
	await walk_through(stairs)
	check(gs.map_id == "depths1", "de trap brengt je naar de Kristalgangen")
	var start1: Array = Maps.get_map("depths1")["spawns"]["start"]
	check(world.player.global_position.distance_to(tile_center(start1)) < 40.0, "en je staat bij de start")
	check(gs.has_save(), "bij het wisselen van kaart wordt opgeslagen")
	await frames(20)

	print("Bram wijst de weg")
	await start_world("village", [])
	await put_player(tile_center([19, 9]))
	await frames(10)
	check(not world.dialogue.active and gs.quest_state("diepte") == "none", "vóór het einde zegt Bram niets over de Diepte")
	gs.set_flag("game_completed")
	await put_player(tile_center([19, 10]))
	await frames(8)
	check(world.dialogue.active and gs.flag("diepte_hint"), "na het einde roept Bram je (een keer)")
	await finish_dialogue()
	check(gs.quest_state("diepte") == "active" and gs.quest_step("diepte") == 0, "Bram geeft de opdracht (het zegel is nog dicht)")
	await put_player(tile_center([30, 20]))
	await put_player(tile_center([19, 9]))
	await frames(8)
	check(not world.dialogue.active, "hij zegt het maar één keer")

	print("De opdracht loopt mee")
	gs.new_game()
	gs.start_quest("diepte")
	check(gs.quest_step("diepte") == 0 and gs.quest_text("diepte").begins_with("Het rommelt"), "stap 1: zoek de weg naar beneden")
	gs.set_flag("diepte_opened")
	check(gs.quest_step("diepte") == 1, "zegel gebroken: stap 2")
	gs.set_flag("gate_depths")
	check(gs.quest_step("diepte") == 2, "poort open: stap 3")
	gs.set_flag("guardian_started")
	check(gs.quest_step("diepte") == 3 and gs.quest_text("diepte").find("pilaar") >= 0, "het gevecht begint: laatste stap, met een tip over de pilaren")
	gs.finish_quest("diepte")
	check(gs.quest_state("diepte") == "done", "de opdracht kan worden afgerond")
	gs.new_game()
	gs.start_quest("main")
	gs.finish_quest("main")
	check(gs.tracked_text() == "De Blauwe Kaart is hersteld!", "na het einde zonder lopende opdracht: het goede nieuws")
	gs.start_quest("diepte")
	check(gs.tracked_text() == gs.quest_text("diepte"), "na het einde toont het beeld de opdracht van de Diepte")
	gs.finish_quest("diepte")
	check(gs.tracked_text() == "De Blauwe Kaart is hersteld!", "en daarna weer het goede nieuws")
	gs.new_game()
	gs.start_quest("kat")
	gs.start_quest("main")
	gs.finish_quest("main")
	gs.start_quest("diepte")
	check(gs.tracked_text() == gs.quest_text("diepte"), "staat er nog een oudere opdracht open, dan toont het beeld toch de nieuwste (de Diepte)")

	print("Greta ziet het Sterrenzwaard")
	await start_world("smithy", [])
	gs.set_weapon("star")
	var greta: Node = children_with_script("npc.gd").filter(func(npc: Node) -> bool: return npc.npc_id == "greta")[0]
	greta.interact()
	await frames(3)
	check(world.dialogue.active and world.dialogue.node == Dialogue.TALKS["greta_star"], "met het Sterrenzwaard wil Greta het meteen zien (ook als je haar nog niet kende)")
	await finish_dialogue()
	check(gs.flag("greta_star_seen") and gs.flag("met_greta"), "dat onthoudt ze")
	greta.interact()
	await frames(3)
	check(world.dialogue.active and world.dialogue.node == Dialogue.TALKS["greta_star_again"] and world.dialogue.buttons.is_empty(), "daarna een kort praatje, zonder een lege smeedvraag")
	await finish_dialogue()


func test_puzzle() -> void:
	print("Puzzel: sleutel, poort en trap")
	await start_world("depths1", ["game_completed", "diepte_opened"])
	var gates := children_with_script("diepte_gate.gd")
	check(gates.size() == 1 and gates[0].blocked and gates[0].gate_id == "depths", "de kristalpoort is dicht")
	var gate: Node = gates[0]
	var chests := children_with_script("chest.gd")
	var key_chest: Node = null
	for chest in chests:
		if chest.contents[0][0] == "diepte_key":
			key_chest = chest
	check(key_chest != null and chests.size() == 3, "er staan drie kisten, een met de sleutel")
	gs.start_quest("diepte")
	await put_player(gate.global_position + Vector2(0, 30))
	check(world.player.target == gate, "je kunt de poort aanspreken")
	gate.interact()
	check(gate.blocked and not gs.flag("gate_depths"), "zonder sleutel gaat hij niet open")
	key_chest.interact()
	check(gs.count("diepte_key") == 1 and key_chest.opened, "de kist geeft de sleutel")
	key_chest.interact()
	check(gs.count("diepte_key") == 1, "maar maar een keer")
	gate.interact()
	await frames(4)
	check(gs.flag("gate_depths") and not gate.blocked and gs.count("diepte_key") == 0, "met de sleutel gaat de poort open (en de sleutel is op)")
	check(gate.shape.disabled, "je kunt er nu doorheen lopen")
	check(gs.quest_step("diepte") == 2, "de opdracht gaat naar de volgende stap")
	await world.load_map("depths1", "start")
	await frames(5)
	var reloaded := children_with_script("diepte_gate.gd")
	check(reloaded.size() == 1 and not reloaded[0].blocked, "de poort blijft open na opnieuw laden van de kaart")
	var stairs: Dictionary = {}
	for obj: Dictionary in objects("depths1", "portal"):
		if obj["to"] == "depths2":
			stairs = obj
	await walk_through(stairs)
	check(gs.map_id == "depths2", "de trap brengt je naar Het Hart van de Kaart")
	await frames(20)
	check(find_nodes("boss", func(b: Node) -> bool: return b.kind == "guardian").size() == 1, "daar wacht De Vergeten Wachter")


# --- Deel 4: de baas -----------------------------------------------------------------------------------------

func guardian_node() -> Node:
	var found := find_nodes("boss", func(b: Node) -> bool: return b.kind == "guardian")
	return found[0] if not found.is_empty() else null


func test_guardian() -> void:
	print("De Vergeten Wachter: ontwaken")
	seed(4242)
	await start_world("depths2", ["game_completed", "diepte_opened", "gate_depths"])
	gs.start_quest("diepte")
	var boss: Node = guardian_node()
	check(boss != null and boss.max_hp == Enemies.info("guardian")["hp"] and boss.hp == boss.max_hp, "de baas heeft zijn levens uit enemies.gd (%d)" % boss.max_hp)
	check(boss.is_in_group("enemies") and boss.is_in_group("boss") and boss.data["name"] == "De Vergeten Wachter", "dezelfde groepen en gegevens als andere vijanden")
	check(not boss.active and boss.state == "dormant" and not boss.dead, "hij slaapt")
	boss.hurt(5, Vector2.RIGHT)
	check(boss.hp == boss.max_hp, "een slapende baas is onraakbaar")
	check(boss.pillars.size() == 6 and boss.pillars.all(func(p: Node) -> bool: return is_instance_valid(p)), "zes pilaren staan om de arena")
	check(children_with_script("diepte_lamp.gd").size() >= 8, "kristallampen verlichten de arena")
	var intro_trigger: Dictionary = {}
	for obj: Dictionary in objects("depths2", "trigger"):
		if obj.get("once", "") == "guardian_started":
			intro_trigger = obj
	await put_player(tile_center([13, 20]))
	await frames(5)
	check(not gs.flag("guardian_started") and not boss.active, "in de voorkamer begint het gevecht nog niet")
	var door := children_with_script("gate.gd").filter(func(g: Node) -> bool: return g.gate_id == "guardian_door")
	check(door.size() == 1 and not door[0].blocked, "de deur terug staat nog open")
	check(door.size() == 1 and door[0].get_script().resource_path.ends_with("diepte_gate.gd"), "de deur is een kristalpoort, net als in de Kristalgangen")
	await put_player(tile_center([13, 17]))
	await put_player(tile_center([10, 17]))
	await put_player(tile_center([10, 16])) # helemaal langs de linkerkant van de gang
	await frames(4)
	check(world.dialogue.active and gs.flag("guardian_started"), "de baas begroet je zodra je het plein op loopt, ook langs de zijkant")
	await finish_dialogue()
	await frames(4)
	check(boss.active and boss.state == "waking", "hij ontwaakt")
	check(root.get_node("Sound").current_track == "guardian", "de baasmuziek begint")
	check(door[0].blocked, "de deur gaat dicht: geen weg terug")
	check(gs.quest_step("diepte") == 3, "de opdracht staat op de laatste stap")
	boss.hurt(10, Vector2.RIGHT)
	check(boss.hp == boss.max_hp, "tijdens het ontwaken is hij beschermd")
	var shield_text: Array = world.fx_layer.get_children().filter(func(fx: Node) -> bool: return fx.get("text") == "Beschermd!")
	check(shield_text.size() == 1, "en dat zie je: 'Beschermd!'")
	await put_player(tile_center([13, 9]))
	await frames(5)
	check(world.hud.boss == boss and world.hud.boss_bar.visible, "de baasbalk in de HUD ziet hem")
	await put_player(tile_center([13, 19]))
	await frames(5)
	check(world.hud.boss == boss, "de baasbalk blijft zichtbaar, ook helemaal aan de andere kant van de arena")
	await put_player(tile_center([13, 9]))
	await frames(int(boss.WAKE_TIME * 60.0) + 5)
	check(boss.state != "waking" and boss.phase == 1, "daarna vecht hij (fase 1)")
	boss.set_physics_process(false)
	var shield_before: int = boss.hp
	boss.hurt(3, Vector2.RIGHT)
	check(boss.hp == shield_before - 3, "hij is nu te raken")
	boss.set_physics_process(true)

	print("De Vergeten Wachter: de aanvallen")
	boss.set_physics_process(false)
	boss.hp = boss.max_hp
	var player: Node = world.player
	var hp_before: int = gs.hp
	# storm: de rode baan
	boss.global_position = tile_center([13, 4])
	await put_player(tile_center([13, 11]))
	boss.set_physics_process(true)
	boss._enter("idle")
	boss._choose_attack(250.0)
	check(boss.state == "charge_windup" and boss.line_length > 100.0, "de storm begint met een aankondiging (baan van %d pixels)" % int(boss.line_length))
	gs.full_heal()
	player.invuln = 0.0
	hp_before = gs.hp
	var windup_frames := int(boss.PHASES[0]["charge_windup"] * 60.0) + 2
	await frames(windup_frames)
	check(boss.state == "charge_dash", "na de aankondiging stormt hij")
	var dash_start: Vector2 = boss.global_position
	await frames(60)
	check(gs.hp == hp_before - 2 and boss.global_position.distance_to(dash_start) > 60.0, "wie in de baan blijft staan, krijgt 2 schade")
	await frames(120)
	check(not boss.state in ["dormant", "waking", "phase_shift", "dying"], "na de storm gaat het gevecht gewoon door (%s)" % boss.state)

	# opzij stappen als de baan vastligt
	gs.full_heal()
	boss.set_physics_process(false)
	boss.global_position = tile_center([13, 4])
	await put_player(tile_center([13, 11]))
	boss.set_physics_process(true)
	boss._enter("idle")
	boss._choose_attack(250.0)
	await frames(int(boss.PHASES[0]["charge_windup"] * 60.0 * 0.75))
	check(boss.state == "charge_windup" and boss.state_time >= boss.PHASES[0]["charge_windup"] * 0.6, "de baan ligt vast")
	player.invuln = 0.0
	hp_before = gs.hp
	await put_player(tile_center([13, 11]) + Vector2(150, 0))
	await frames(100)
	check(gs.hp == hp_before, "wie opzij stapt, wordt niet geraakt")

	gs.full_heal()
	boss._enter("idle")
	boss.global_position = tile_center([13, 5])
	await put_player(tile_center([13, 11]))
	boss._choose_attack(250.0)
	player.invuln = 0.0
	hp_before = gs.hp
	await frames(windup_frames)
	player.roll_timer = player.ROLL_TIME
	await frames(10)
	check(gs.hp == hp_before, "een ontwijkrol (onraakbaar) redt je van de storm")
	player.roll_timer = 0.0
	player.invuln = 999.0

	# tegen de muur knallen
	boss._enter("idle")
	boss.global_position = tile_center([13, 3])
	boss.aim_dir = Vector2.UP
	boss.dash_left = 300.0
	boss._enter("charge_dash")
	await frames(60)
	check(boss.state == "stunned", "tegen een muur geknald: de baas is duizelig")
	boss.hp = boss.max_hp
	boss.hurt(3, Vector2.RIGHT)
	check(boss.hp == boss.max_hp - 3, "en dan kun je hem slaan")
	await frames(int(boss.PHASES[0]["stun"] * 60.0) + 5)
	check(boss.state != "stunned", "de duizeligheid gaat over")

	# klap
	boss._enter("idle")
	boss.global_position = tile_center([13, 9])
	await put_player(tile_center([13, 9]) + Vector2(40, 0))
	boss._enter("slam_windup")
	gs.full_heal()
	player.invuln = 0.0
	hp_before = gs.hp
	await frames(int(boss.PHASES[0]["slam_windup"] * 60.0) + 3)
	check(gs.hp == hp_before - 2 and boss.state == "slam_recover", "de klap raakt wie dichtbij staat (2 schade, nu %d van %d, %s)" % [gs.hp, hp_before, boss.state])
	boss._enter("idle")
	boss.global_position = tile_center([13, 9])
	await put_player(tile_center([13, 9]) + Vector2(150, 0))
	boss._enter("slam_windup")
	gs.full_heal()
	player.invuln = 0.0
	hp_before = gs.hp
	await frames(int(boss.PHASES[0]["slam_windup"] * 60.0) + 3)
	check(gs.hp == hp_before, "wie ver genoeg weg staat, is veilig")
	player.invuln = 999.0

	print("De Vergeten Wachter: de ringen")
	# Elke ring mist precies twee scherven per gat, ook als het gat over de rand (scherf 15 -> 0) heen valt.
	var ring_sizes := {}
	for i in 3000:
		var gaps := 1 + i % 2
		var size: int = boss._ring_angles(0.0, gaps).size()
		ring_sizes[size] = true
		if size != boss.RING_SHARDS - 2 * gaps:
			ring_sizes["fout bij %d gaten" % gaps] = size
	check(ring_sizes.size() == 2 and ring_sizes.has(boss.RING_SHARDS - 2) and ring_sizes.has(boss.RING_SHARDS - 4), "elk gat is precies twee scherven breed (%s)" % [ring_sizes.keys()])

	print("De Vergeten Wachter: fasen en pilaren")
	boss.set_physics_process(false)
	boss.global_position = tile_center([13, 4])
	var limit := int(ceil(0.66 * float(boss.max_hp)))
	boss.hp = limit + 2
	boss._enter("idle")
	boss.hurt(3, Vector2.RIGHT)
	check(boss.state == "phase_shift" and boss.shift_to == 2 and boss.hp == limit - 1, "onder 66% begint fase 2 (met een fasewissel)")
	boss.hurt(3, Vector2.RIGHT)
	check(boss.hp == limit - 1, "tijdens de fasewissel is hij beschermd")
	boss.set_physics_process(true)
	await frames(int(boss.SHIFT_TIME * 60.0) + 5)
	check(boss.phase == 2 and boss.state != "phase_shift", "fase 2 is begonnen")
	boss.set_physics_process(false)
	boss.phase = 1
	boss.hp = boss.max_hp
	boss._enter("idle")
	boss.hurt(boss.max_hp - 20, Vector2.RIGHT) # een gigantische klap mag geen fase overslaan: dit is al fase 3
	check(boss.state == "phase_shift" and boss.shift_to == 2 and boss.hp == 20, "ook een enorme klap slaat geen fase over (eerst fase 2)")
	boss.set_physics_process(true)
	await frames(int(boss.SHIFT_TIME * 60.0) + 5)
	check(boss.phase == 2, "fase 2 begint")
	boss.set_physics_process(false)
	boss._enter("idle")
	boss.hurt(1, Vector2.RIGHT)
	check(boss.state == "phase_shift" and boss.shift_to == 3, "de volgende klap brengt hem in fase 3")
	boss.set_physics_process(true)
	await frames(int(boss.SHIFT_TIME * 60.0) + 5)
	check(boss.phase == 3, "fase 3 (woede)")

	# pilaren schieten ringen met gaten (in fase 2)
	boss.phase = 2
	boss.hp = 55
	boss._enter("idle")
	boss.set_physics_process(false)
	await put_player(tile_center([13, 9]))
	var near_pillar: Node = boss.pillars[0]
	await put_player(near_pillar.global_position + Vector2(40, 10))
	boss._start_volley()
	check(not near_pillar.charging, "een pilaar waar je vlak naast staat schiet niet (eerlijk)")
	var charging: Array = boss.pillars.filter(func(p: Node) -> bool: return p.charging)
	check(charging.size() == boss.PHASES[1]["volley_pillars"], "de pilaren laden op (%d)" % charging.size())
	var gaps_ok := true
	var spoke_counts: Array = []
	for pillar in charging:
		var angles: Array = pillar.angles.duplicate()
		angles.sort()
		spoke_counts.append(angles.size())
		var biggest := TAU - float(angles[angles.size() - 1]) + float(angles[0])
		for i in range(1, angles.size()):
			biggest = maxf(biggest, float(angles[i]) - float(angles[i - 1]))
		# de gaten zijn minstens drie stappen breed: je kunt er doorheen lopen
		if biggest < 3.0 * TAU / float(boss.RING_SHARDS) - 0.05 and angles.size() > 0:
			gaps_ok = false
		var step := TAU / float(boss.RING_SHARDS)
		var normalized: Array = angles.map(func(a: float) -> float: return fposmod(a, step))
		for value: float in normalized:
			if absf(value - float(normalized[0])) > 0.01 and absf(value - float(normalized[0]) - step) > 0.01 and absf(value - float(normalized[0]) + step) > 0.01:
				gaps_ok = false
	check(gaps_ok and spoke_counts.all(func(n: int) -> bool: return n < boss.RING_SHARDS and n >= boss.RING_SHARDS - 6), "elke ring heeft gaten (%s scherven van %d)" % [spoke_counts, boss.RING_SHARDS])
	await frames(int(boss.PHASES[1]["volley_windup"] * 60.0) + 8)
	var shards := get_nodes_in_group("guardian_shards")
	check(shards.size() >= 20, "daarna vliegen er scherven (%d)" % shards.size())
	# een scherf die je raakt doet 1 schade; tijdens een rol niet
	for shard in shards:
		shard.queue_free()
	await frames(2)
	gs.full_heal()
	player.invuln = 0.0
	hp_before = gs.hp
	var shard_script: Script = load("res://scripts/entities/guardian_shard.gd")
	var test_shard: Node2D = shard_script.new()
	test_shard.set("world", world)
	test_shard.position = player.global_position + Vector2(0, 4)
	test_shard.set("velocity", Vector2.RIGHT * 100.0)
	world.entities.add_child(test_shard)
	await frames(3)
	check(gs.hp == hp_before - 1, "een scherf doet 1 schade")
	gs.full_heal()
	player.invuln = 0.0
	player.roll_timer = player.ROLL_TIME
	hp_before = gs.hp
	var rolled_shard: Node2D = shard_script.new()
	rolled_shard.set("world", world)
	rolled_shard.position = player.global_position + Vector2(0, 4)
	rolled_shard.set("velocity", Vector2.RIGHT * 100.0)
	world.entities.add_child(rolled_shard)
	await frames(3)
	check(gs.hp == hp_before, "tijdens een ontwijkrol gaat een scherf dwars door je heen")
	player.roll_timer = 0.0
	player.invuln = 999.0

	# fase 3: twee ringen na elkaar
	boss.phase = 3
	for pillar in boss.pillars:
		pillar.cancel()
	boss.set_physics_process(false)
	for shard in get_nodes_in_group("guardian_shards"):
		shard.queue_free()
	await put_player(tile_center([13, 9]))
	boss._start_volley()
	var rings_pillar: Node = boss.pillars.filter(func(p: Node) -> bool: return p.charging)[0]
	check(rings_pillar.rings_left == 2 and boss.PHASES[2]["shard_speed"] > boss.PHASES[0].get("shard_speed", 0.0), "in fase 3 komen er twee ringen na elkaar")
	check(boss.PHASES[2]["charge_speed"] > boss.PHASES[0]["charge_speed"] and boss.PHASES[2]["charge_windup"] < boss.PHASES[0]["charge_windup"] and boss.PHASES[2]["idle"] < boss.PHASES[0]["idle"], "in fase 3 gaat alles sneller")
	await frames(120)
	check(not rings_pillar.charging and get_nodes_in_group("guardian_shards").size() > 20, "beide ringen zijn afgeschoten")
	for shard in get_nodes_in_group("guardian_shards"):
		shard.queue_free()
	for pillar in boss.pillars:
		pillar.cancel()
	await frames(2)

	# fase 3: de klap schiet ook een ring scherven weg
	boss.global_position = tile_center([13, 8])
	await put_player(tile_center([20, 12])) # ver weg, zodat geen scherf je raakt (dan zijn er minder om te tellen)
	boss._enter("idle")
	boss._choose_attack(10.0) # 10 = de afstand tot de speler: dichtbij, dus een klap
	check(boss.state == "slam_windup" and boss.slam_angles.size() == boss.RING_SHARDS - 2, "in fase 3 kondigt de klap een ring scherven aan (%d lijnen)" % boss.slam_angles.size())
	boss.set_physics_process(true)
	await frames(int(boss.PHASES[2]["slam_windup"] * 60.0) + 3)
	boss.set_physics_process(false)
	check(get_nodes_in_group("guardian_shards").size() == boss.RING_SHARDS - 2, "en schiet ze weg bij de klap (%d)" % get_nodes_in_group("guardian_shards").size())

	# een scherf verdwijnt tegen een muur
	for shard in get_nodes_in_group("guardian_shards"):
		shard.queue_free()
	await frames(2)
	var wall_shard: Node2D = shard_script.new()
	wall_shard.set("world", world)
	wall_shard.position = tile_center([13, 2])
	wall_shard.set("velocity", Vector2.UP * 200.0)
	world.entities.add_child(wall_shard)
	await frames(30)
	check(not is_instance_valid(wall_shard) or wall_shard.is_queued_for_deletion(), "een scherf vliegt niet door een muur")

	# een fasewissel stopt de pilaren die aan het opladen zijn
	boss.phase = 2
	await put_player(tile_center([13, 9]))
	boss._start_volley()
	check(boss.pillars.any(func(p: Node) -> bool: return p.charging), "(de pilaren laden op)")
	boss._begin_phase_shift(3)
	check(not boss.pillars.any(func(p: Node) -> bool: return p.charging), "een fasewissel stopt de pilaren meteen")
	boss._enter("idle")


func test_guardian_safety() -> void:
	print("De Vergeten Wachter: nooit onoverwinnelijk of vast")
	seed(99)
	await start_world("depths2", ["game_completed", "diepte_opened", "gate_depths", "guardian_started"])
	var boss: Node = guardian_node()
	var player: Node = world.player
	player.invuln = 999.0
	await put_player(tile_center([13, 12]))
	var last_state := ""
	var in_state := 0.0
	var longest := 0.0
	var longest_state := ""
	var visited := {}
	var protected_frames := 0
	var total_frames := 0
	var inside := true
	for ratio: float in [1.0, 0.55, 0.2]:
		boss.hp = int(ratio * float(boss.max_hp))
		if boss._phase_for_hp() > boss.phase:
			boss.phase = boss._phase_for_hp()
		for frame in 900:
			await process_frame
			player.invuln = 999.0
			total_frames += 1
			if boss.state != last_state:
				last_state = boss.state
				in_state = 0.0
			in_state += 1.0 / 60.0
			if boss.state != "dormant" and in_state > longest:
				longest = in_state
				longest_state = boss.state
			visited[boss.state] = true
			if boss.state in ["waking", "phase_shift", "dying"]:
				protected_frames += 1
			if world.is_solid(boss.global_position + Vector2(0, 27)):
				inside = false
			if frame % 150 == 0:
				# de speler loopt rond zodat de baas achter hem aan gaat
				await put_player(tile_center([13, 12]) + Vector2.from_angle(float(frame) * 0.7) * 150.0)
	check(longest <= STATE_LIMIT, "geen enkele toestand duurt langer dan %.0f seconden (langste: %s %.1fs)" % [STATE_LIMIT, longest_state, longest])
	for needed: String in ["idle", "charge_windup", "charge_dash", "slam_windup", "recover"]:
		check(visited.has(needed) or visited.has("stunned"), "de baas komt in toestand %s" % needed)
	check(float(protected_frames) / float(total_frames) < 0.1, "hij is bijna altijd te raken (beschermd: %.1f%% van de tijd)" % (100.0 * float(protected_frames) / float(total_frames)))
	check(inside, "hij blijft binnen de arena (nooit in een muur)")
	check(boss.state != "dormant" and not boss.dead and boss.hp > 0, "en hij heeft de speler niet verslagen of zichzelf vastgezet")


func test_guardian_death() -> void:
	print("De Vergeten Wachter: verslagen")
	seed(7)
	await start_world("depths2", ["game_completed", "diepte_opened", "gate_depths", "guardian_started"])
	gs.start_quest("diepte")
	var boss: Node = guardian_node()
	var player: Node = world.player
	boss.set_physics_process(false)
	await frames(2)
	boss.activate()
	boss.set_physics_process(true)
	await frames(int(boss.WAKE_TIME * 60.0) + 5)
	await put_player(tile_center([13, 10])) # je staat in de arena
	var kills_before: int = gs.kills
	var coins_before: int = gs.coins
	var xp_before: int = gs.hero_xp
	var expected_xp := mini(xp_before + 200 + 100, Progression.MAX_XP) # Wachter + voltooide Diepte-opdracht
	var expected_level_coins := (Progression.level_for(expected_xp) - Progression.level_for(xp_before)) * Progression.LEVEL_REWARD
	var died := [0]
	boss.died.connect(func() -> void: died[0] += 1)
	# Net als in een echt gevecht: er vliegen scherven en de pilaren laden op.
	boss.phase = 2
	boss._start_volley()
	boss._shoot_ring(boss.global_position, boss._ring_angles(0.0, 1), 110.0)
	check(boss.pillars.any(func(p: Node) -> bool: return p.charging) and not get_nodes_in_group("guardian_shards").is_empty(), "(er vliegen scherven en de pilaren laden op)")
	boss.hp = 3
	boss.hurt(9999, Vector2.RIGHT)
	check(boss.dead and boss.hp == 0 and boss.state == "dying", "de baas valt")
	check(get_nodes_in_group("guardian_shards").all(func(s: Node) -> bool: return s.is_queued_for_deletion()), "alle scherven verdwijnen meteen")
	check(not boss.pillars.any(func(p: Node) -> bool: return p.charging), "en de pilaren stoppen met opladen")
	check(root.get_node("Sound").current_track == "", "de baasmuziek stopt")
	check(not boss.is_in_group("enemies") and died[0] == 1 and gs.kills == kills_before + 1, "hij telt als verslagen en het signaal klinkt")
	check(not gs.flag("guardian_defeated") and gs.weapon == "wood", "tijdens het uiteenvallen is de beloning er nog niet")
	boss.hurt(5, Vector2.RIGHT)
	check(boss.hp == 0, "een tweede klap doet niets meer")
	await frames(int(boss.DEATH_TIME * 60.0) + 20)
	check(gs.flag("guardian_defeated"), "de vlag guardian_defeated staat aan")
	check(gs.hero_xp == expected_xp, "ervaring voor de Wachter en de Diepte-opdracht, elk één keer")
	check(gs.coins == coins_before + 500 + expected_level_coins, "500 baasmunten plus de precieze beloning voor nieuwe heldenlevels")
	check(gs.weapon == "star" and gs.damage() == 4, "het Sterrenzwaard is je nieuwe zwaard")
	check(gs.quest_state("diepte") == "done", "de opdracht is voltooid")
	check(guardian_node() == null or boss.is_queued_for_deletion() or not is_instance_valid(boss), "de baas is weg")
	check(get_nodes_in_group("guardian_shards").is_empty() and children_with_script("guardian_pillar.gd").size() == 0, "scherven en pilaren zijn weg")
	check(world.dialogue.active, "het slotgesprek begint")
	check(world.dialogue.node.get("speaker", "") == "De Vergeten Wachter", "de Wachter neemt afscheid")
	await finish_dialogue()
	check(gs.flag("guardian_epilogue") and not world.dialogue.active, "het slotgesprek wordt maar een keer gevoerd")
	var chests := children_with_script("chest.gd")
	check(chests.size() == 1 and chests[0].contents[0][0] == "heart_container", "er staat een hartcontainer-kist")
	var max_before: int = gs.max_hp()
	var chest: Node = chests[0]
	await put_player(chest.global_position + Vector2(0, 30))
	chest.interact()
	check(gs.max_hp() == max_before + 1 and chest.opened, "de kist geeft een hartje erbij")

	print("Na de overwinning")
	await world.load_map("depths2", "start")
	await frames(10)
	check(guardian_node() == null, "bij terugkomst is de baas weg")
	check(children_with_script("chest.gd").size() == 1 and children_with_script("chest.gd")[0].opened, "de kist is leeg en blijft leeg")
	var door := children_with_script("gate.gd").filter(func(g: Node) -> bool: return g.gate_id == "guardian_door")
	check(door.size() == 1 and not door[0].blocked, "de deur terug is open")
	# onaangeroerde kist komt terug
	gs.set_flag("chest:depths2:heart", false)
	await world.load_map("depths2", "start")
	await frames(10)
	check(children_with_script("chest.gd").size() == 1 and not children_with_script("chest.gd")[0].opened, "een ongeopende kist staat er na het laden weer")
	# niet meer dan 8 hartjes
	gs.new_game()
	gs.give("heart_container", 3, true)
	gs.set_flag("game_completed")
	gs.set_flag("guardian_defeated")
	await world.load_map("depths2", "start")
	await frames(10)
	var capped := children_with_script("chest.gd")
	check(capped.size() == 1 and capped[0].contents[0][0] != "heart_container" and gs.max_hp() == 8, "met 8 hartjes geeft de kist geen hartcontainer meer")

	print("Het zwaard zelf")
	await start_world("depths2", ["game_completed", "diepte_opened", "gate_depths"])
	boss = guardian_node()
	player = world.player
	boss.set_physics_process(false)
	boss.active = true
	boss.state = "idle"
	boss.global_position = tile_center([13, 6])
	var distance := 66.0
	await put_player(boss.global_position + Vector2(0, distance))
	player.facing = Vector2.UP
	gs.weapon = "crystal"
	press("attack")
	await frames(2)
	check(boss.hp == boss.max_hp, "het kristalzwaard (bereik 44) is te kort op 66 pixels")
	player.cooldown = 0.0
	gs.weapon = "star"
	press("attack")
	await frames(2)
	check(boss.hp == boss.max_hp - 4, "het Sterrenzwaard (bereik 48) raakt hem wel, met schade 4")
	check(Items.WEAPONS["star"].get("sparkle", false) and not Items.WEAPONS["crystal"].get("sparkle", false), "alleen het Sterrenzwaard strooit sterretjes")
	player.attack_timer = 0.1 # midden in de zwaai: het zwaard wordt getekend, met sterretjes
	await frames(3)


# --- Deel 5: de hele Diepte, van begin tot eind -------------------------------------------------------------------

## Speelt de Diepte uit met de echte kaarten: zegel, Kristalgangen, sleutel, poort, trap, baas, beloning en terug.
func test_playthrough() -> void:
	print("De hele Diepte uitspelen")
	seed(31)
	await start_world("temple", ["boss_started", "boss_defeated", "game_completed", "diepte_hint"])
	var temple_stairs: Dictionary = {}
	for obj: Dictionary in objects("temple", "portal"):
		if obj["to"] == "depths1":
			temple_stairs = obj
	var seal: Node = children_with_script("diepte_seal.gd")[0]
	await put_player(seal.global_position + Vector2(16, 90))
	await frames(150)
	await walk_through(temple_stairs)
	check(gs.map_id == "depths1" and gs.quest_state("diepte") == "active", "van de tempel naar de Kristalgangen")
	var key_chest: Node = null
	for chest in children_with_script("chest.gd"):
		if chest.contents[0][0] == "diepte_key":
			key_chest = chest
	await put_player(key_chest.global_position + Vector2(0, 28))
	key_chest.interact()
	var gate: Node = children_with_script("diepte_gate.gd")[0]
	await put_player(gate.global_position + Vector2(0, 30))
	gate.interact()
	await frames(5)
	check(gs.flag("gate_depths") and gs.quest_step("diepte") == 2, "sleutel gevonden en de poort geopend")
	var stairs: Dictionary = {}
	for obj: Dictionary in objects("depths1", "portal"):
		if obj["to"] == "depths2":
			stairs = obj
	await walk_through(stairs)
	check(gs.map_id == "depths2", "de trap naar Het Hart van de Kaart")
	var trigger: Dictionary = {}
	for obj: Dictionary in objects("depths2", "trigger"):
		if obj.get("once", "") == "guardian_started":
			trigger = obj
	await put_player(rect_of(trigger).get_center())
	await frames(4)
	await finish_dialogue()
	var boss: Node = guardian_node()
	await frames(int(boss.WAKE_TIME * 60.0) + 10)
	var guard := 0
	while not boss.dead and guard < 2000:
		guard += 1
		world.player.invuln = 999.0
		if boss.state in ["waking", "phase_shift"]:
			await frames(10)
			continue
		boss.hurt(7, Vector2.RIGHT)
		await frames(6)
	check(boss.dead and boss.phase == 3, "de baas is verslagen na alle drie de fasen")
	await frames(int(boss.DEATH_TIME * 60.0) + 20)
	check(gs.flag("guardian_defeated") and gs.weapon == "star" and gs.coins >= 500 and gs.quest_state("diepte") == "done", "beloning: Sterrenzwaard, munten, opdracht klaar")
	await finish_dialogue()
	var heart_chest: Node = children_with_script("chest.gd")[0]
	await put_player(heart_chest.global_position + Vector2(0, 30))
	heart_chest.interact()
	check(gs.count("heart_container") == 1 and gs.max_hp() == 6, "de hartcontainer-kist is geopend")
	var back: Dictionary = objects("depths2", "portal")[0]
	await walk_through(back)
	check(gs.map_id == "depths1", "de deur terug is open: terug naar de Kristalgangen")
	await walk_through(objects("depths1", "portal").filter(func(o: Dictionary) -> bool: return o["to"] == "temple")[0])
	check(gs.map_id == "temple", "en terug naar de tempel")
	check(children_with_script("diepte_seal.gd").is_empty(), "het zegel is weg: de trap blijft open")
	check(gs.load_game() and gs.flag("guardian_defeated") and gs.weapon == "star" and gs.quest_state("diepte") == "done", "alles is opgeslagen")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.SAVE_PATH))
	gs.new_game()


# --- Deel 6: opslaan --------------------------------------------------------------------------------------------

func test_save() -> void:
	print("Opslaan en laden")
	gs.new_game()
	gs.in_game = true
	gs.start_quest("diepte")
	gs.set_flag("game_completed")
	gs.set_flag("diepte_opened")
	gs.set_flag("gate_depths")
	gs.set_flag("guardian_started")
	gs.set_flag("guardian_defeated")
	gs.set_weapon("star")
	gs.give("diepte_key", 1, true)
	gs.map_id = "depths2"
	gs.ng_plus = 2
	gs.save_game(Vector2(13 * 32 + 16, 12 * 32 + 16))
	gs.new_game()
	check(gs.ng_plus == 0 and not gs.flag("diepte_opened") and gs.weapon == "wood", "een nieuw spel begint schoon")
	check(gs.load_game(), "de opslag wordt gevonden")
	check(gs.flag("diepte_opened") and gs.flag("gate_depths") and gs.flag("guardian_defeated") and gs.flag("game_completed"), "de vlaggen van de Diepte zijn terug")
	check(gs.weapon == "star" and gs.count("diepte_key") == 1 and gs.map_id == "depths2", "zwaard, sleutel en plek zijn terug")
	check(gs.quest_state("diepte") == "active" and gs.quest_step("diepte") == 3, "de opdracht is terug")
	check(gs.ng_plus == 2, "het aantal Nieuw spel+-rondes is terug")
	# een oude opslag zonder ng_plus
	var old_save := {"version": 1, "map": "village", "pos": [100.0, 100.0], "hp": 5, "coins": 7, "inventory": {}, "flags": {}, "quests": {}, "weapon": "iron", "play_time": 5.0, "kills": 1}
	var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_save))
	file.close()
	gs.ng_plus = 5
	check(gs.load_game() and gs.ng_plus == 0 and gs.weapon == "iron" and gs.coins == 7, "een oude opslag (zonder ng_plus) werkt nog, met ng_plus 0")
	gs.new_game()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.SAVE_PATH))


# --- Deel 7: Nieuw spel+ ------------------------------------------------------------------------------------------

func test_new_game_plus() -> void:
	print("Nieuw spel+: het metabestand")
	clean_meta()
	gs.new_game()
	check(not gs.ng_plus_available() and gs.load_meta()["rounds"] == 0, "zonder voltooid spel is er geen Nieuw spel+")
	check(not gs.new_game_plus() and gs.ng_plus == 0, "en new_game_plus() doet dan niets")
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await frames(3)
	check(title.ng_button != null and not title.ng_button.visible, "de knop 'Nieuw spel+' is verborgen")
	var menu_bottom: float = title.quit_button.get_global_rect().end.y
	title.queue_free()
	await frames(3)

	# het einde van het hoofdverhaal zet het metabestand
	await start_world("temple", ["boss_started"])
	world.player.invuln = 999.0
	gs.ending_requested.disconnect(world._on_ending)
	world.player.global_position = tile_center([11, 19])
	gs.set_weapon("crystal")
	gs.give("heart_container", 2, true)
	gs.give("boots", 1, true)
	gs.give("potion", 4, true)
	gs.coins = 321
	gs.start_quest("main")
	world._on_ending() # zoals aan het einde van het spel
	await frames(5)
	check(gs.flag("game_completed") and gs.ng_plus_available(), "bij het einde van het hoofdverhaal wordt het vastgelegd")
	var meta: Dictionary = gs.load_meta()
	check(meta["completed"] and meta["rounds"] == 1 and meta["weapon"] == "crystal" and meta["hearts"] == 2 and meta["boots"], "meta: 1 ronde, kristalzwaard, 2 hartcontainers, laarzen")
	await frames(100)
	if current_scene != null and current_scene.scene_file_path.ends_with("ending.tscn"):
		current_scene.queue_free()
		await frames(3)
	world = null
	gs.new_game()
	check(gs.ng_plus_available(), "het metabestand blijft bestaan na een nieuw spel")

	print("Nieuw spel+: starten")
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await frames(3)
	check(title.ng_button.visible and not title.ng_button.disabled, "nu is de knop 'Nieuw spel+' er")
	check(title.ng_button.get_parent() == title.start_button.get_parent() and is_equal_approx(title.quit_button.get_global_rect().end.y, menu_bottom), "naast 'Nieuw spel': het menu wordt niet hoger (het kristal blijft vrij)")
	title.start_game_plus()
	await frames(5)
	check(gs.ng_plus == 1, "ng_plus is 1")
	check(gs.weapon == "crystal" and gs.damage() == 3, "je behoudt je beste zwaard")
	check(gs.count("heart_container") == 2 and gs.max_hp() == 7 and gs.hp == 7, "je behoudt je hartcontainers (7 hartjes)")
	check(gs.count("boots") == 1 and gs.speed_multiplier() > 1.0, "je behoudt je laarzen")
	check(gs.coins == 100, "je begint met 100 munten")
	check(gs.count("potion") == 0 and gs.inventory.size() == 2 and gs.flags.is_empty() and gs.quests.is_empty(), "al het andere begint opnieuw (vlaggen, opdrachten, voorwerpen)")
	check(gs.map_id == "village" and gs.kills == 0 and gs.play_time == 0.0, "het verhaal begint weer in het dorp")
	check(current_scene != null and current_scene.scene_file_path.ends_with("intro.tscn"), "het begint met de intro")
	var intro: Control = current_scene
	await frames(3)
	var plain_pages: Array[String] = intro.build_pages(0)
	check(intro.pages[intro.pages.size() - 1].find("Nieuw spel+") >= 0 and plain_pages[plain_pages.size() - 1].find("Nieuw spel+") < 0, "de intro heeft een extra zin bij Nieuw spel+")
	intro.queue_free()
	await frames(3)
	gs.new_game()
	var plain: Control = load("res://scenes/intro.tscn").instantiate()
	root.add_child(plain)
	current_scene = plain
	await frames(3)
	check(plain.pages[plain.pages.size() - 1].find("Nieuw spel+") < 0, "bij een gewoon spel is de intro zoals altijd")
	plain.queue_free()
	await frames(3)

	print("Nieuw spel+: sterkere vijanden en meer munten")
	gs.new_game()
	check(gs.ng_hp(3) == 3 and gs.ng_hp(22) == 22 and gs.ng_coins(1) == 1, "gewoon spel: niets verandert")
	gs.ng_plus = 1
	check(gs.ng_hp(3) == 5 and gs.ng_hp(22) == 33 and gs.ng_hp(60) == 90 and gs.ng_hp(1) == 2, "ronde 1: levens x1,5 naar boven afgerond (3 -> 5, 22 -> 33, 60 -> 90)")
	gs.ng_plus = 2
	check(gs.ng_hp(3) == 6 and gs.ng_hp(100) == 200, "ronde 2: levens x2 (3 -> 6, 100 -> 200)")
	check(gs.ng_coins(1) == 2 and gs.ng_coins(2) == 3 and gs.ng_coins(10) == 15, "munten uit vijanden x1,5 naar boven afgerond")
	await start_world("village", [])
	gs.ng_plus = 1
	var slime: Node = world.spawn_enemy("slime", tile_center([19, 13]))
	check(slime.max_hp == 5 and slime.hp == 5, "een slijm heeft in ronde 1 vijf levens in plaats van drie")
	var golem: Node = world.spawn_enemy("golem", tile_center([22, 13]))
	check(golem.max_hp == 33, "een golem 33 in plaats van 22")
	var king: Node = world.spawn_enemy("king", tile_center([25, 13]))
	check(king.max_hp == 90, "de Slijmkoning 90 in plaats van 60")
	slime.set_physics_process(false)
	var coins_before := count_coin_pickups()
	slime.hurt(99, Vector2.RIGHT)
	await frames(2)
	check(count_coin_pickups() - coins_before == 2, "een slijm laat in Nieuw spel+ 2 munten vallen in plaats van 1")
	gs.ng_plus = 0
	var plain_slime: Node = world.spawn_enemy("slime", tile_center([19, 14]))
	check(plain_slime.max_hp == 3, "terug naar een gewoon spel: weer 3 levens")
	plain_slime.set_physics_process(false)
	coins_before = count_coin_pickups()
	plain_slime.hurt(99, Vector2.RIGHT)
	await frames(2)
	check(count_coin_pickups() - coins_before == 1, "en 1 munt")

	print("Nieuw spel+: de baas")
	gs.ng_plus = 1
	await start_world("depths2", ["game_completed", "diepte_opened"])
	gs.ng_plus = 1
	await world.load_map("depths2", "start")
	await frames(5)
	check(guardian_node() != null and guardian_node().max_hp == gs.ng_hp(Enemies.info("guardian")["hp"]) and guardian_node().max_hp > Enemies.info("guardian")["hp"] * 1.4, "De Vergeten Wachter heeft in ronde 1 de helft meer levens (%d)" % guardian_node().max_hp)
	gs.ng_plus = 0
	await start_world("depths2", ["game_completed", "diepte_opened"])
	check(guardian_node().max_hp == Enemies.info("guardian")["hp"], "en in een gewoon spel zijn gewone levens")

	print("Nieuw spel+: de ster en het bewaren")
	await start_world("village", [])
	gs.ng_plus = 0
	press("pause")
	await frames(3)
	check(world.pause_menu.open and not world.pause_menu.ng_row.visible, "zonder Nieuw spel+ staat er geen ster in het pauzemenu")
	press("pause")
	await frames(3)
	gs.ng_plus = 3
	press("pause")
	await frames(3)
	check(world.pause_menu.ng_row.visible and world.pause_menu.ng_label.text.find("ronde 3") >= 0, "in Nieuw spel+ staat er een ster met 'ronde 3' in het pauzemenu")
	press("pause")
	await frames(3)
	press("menu")
	await frames(4)
	check(world.menu_ui.active, "het voorwerpenmenu tekent zonder fouten met de ster")
	press("menu")
	await frames(3)

	# Nooit minder bewaren dan je al had; rondes tellen op
	clean_meta()
	gs.new_game()
	gs.set_flag("game_completed")
	gs.set_weapon("star")
	gs.give("heart_container", 3, true)
	gs.record_completion()
	check(gs.load_meta()["rounds"] == 1 and gs.load_meta()["weapon"] == "star" and gs.load_meta()["hearts"] == 3 and not gs.load_meta()["boots"], "ronde 1 bewaard met Sterrenzwaard en 3 hartcontainers")
	gs.new_game()
	check(gs.new_game_plus() and gs.ng_plus == 1 and gs.weapon == "star" and gs.max_hp() == 8 and gs.count("boots") == 0, "Nieuw spel+ met het Sterrenzwaard en 8 hartjes, zonder laarzen")
	gs.give("heart_container") # de kist in de grot
	gs.give("heart_container") # van Pim
	check(gs.count("heart_container") == 3 and gs.max_hp() == 8, "de hartcontainers uit de grot en van Pim brengen je niet boven de 8 hartjes")
	gs.set_flag("game_completed")
	gs.record_completion()
	check(gs.load_meta()["rounds"] == 2 and gs.load_meta()["hearts"] == 3, "ronde 2 uitgespeeld: 2 rondes, nog steeds 3 hartcontainers")
	gs.new_game()
	gs.set_flag("game_completed")
	gs.record_completion() # een eenvoudig spel zonder spullen mag niets afnemen
	var kept: Dictionary = gs.load_meta()
	check(kept["rounds"] == 2 and kept["weapon"] == "star" and kept["hearts"] == 3, "een gewoon spel erachteraan maakt je niets minder (rondes, zwaard en hartjes blijven)")
	gs.new_game()
	gs.set_flag("game_completed")
	gs.set_weapon("iron")
	gs.save_game(Vector2.ZERO)
	check(gs.load_meta()["weapon"] == "star", "opslaan met een slechter zwaard verandert het bewaarde zwaard niet")
	# een spel dat al was uitgespeeld (oude opslag) krijgt Nieuw spel+ bij de eerstvolgende keer opslaan
	clean_meta()
	gs.new_game()
	gs.set_flag("game_completed")
	check(not gs.ng_plus_available(), "(nog geen metabestand)")
	gs.save_game(Vector2.ZERO)
	check(gs.ng_plus_available() and gs.load_meta()["rounds"] == 1, "een spel dat al was uitgespeeld krijgt Nieuw spel+ zodra je opslaat")
	# kapot of onbekend metabestand
	var config := ConfigFile.new()
	config.set_value("ng", "completed", true)
	config.set_value("ng", "weapon", "bestaat_niet")
	config.save(gs.NG_META_PATH)
	check(gs.load_meta()["weapon"] == "wood" and gs.new_game_plus() and gs.weapon == "wood", "een onbekend zwaard in het metabestand valt terug op hout")
	clean_meta()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.SAVE_PATH))
	gs.new_game()


func _run() -> void:
	gs = root.get_node("GameState")
	back_up_user_files()
	clean_meta()
	test_data()
	test_reachability()
	await test_access()
	await test_puzzle()
	await test_guardian()
	await test_guardian_safety()
	await test_guardian_death()
	await test_playthrough()
	test_save()
	await test_new_game_plus()
	restore_user_files()

	print("")
	if failures == 0:
		print("DIEPTE TEST OK")
		quit(0)
	else:
		print("DIEPTE TEST: %d fout(en)" % failures)
		quit(1)
