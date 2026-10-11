extends SceneTree
## Test voor de uitbreiding "vijanden": de Magiër (teleporteren, arcane bol) en de Slijmspuwer (waaier, hupje).
##
##   sh tools/run_tests.sh /pad/naar/godot      (alle tests, met een eigen opslagmap)
##   godot --headless --fixed-fps 60 --path . -s tests/vijanden_test.gd     (alleen deze test)
##
## Draai je hem los, dan gebruikt hij de echte opslagmap. Een opgeslagen spel dat er al was, zet hij na afloop terug.
##
## Deel 1: gegevens, plaatjes en geluiden. Deel 2: plaatsing op de kaarten (vrije, bereikbare tegels).
## Deel 3: gedrag in een echte wereld, frame voor frame. Deel 4: opslaan en laden.

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Items := preload("res://scripts/data/items.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const Content := preload("res://scripts/data/content.gd")
const Vijanden := preload("res://scripts/data/ext/vijanden.gd")

const TILE := 32.0
const FPS := 60.0
const KINDS := ["mage", "slime_spitter"]
const SHEET_CELLS := {"mage": 4, "slime_spitter": 5, "arcane_orb": 4} # vakjes van 16x16 per plaatje
const SOUND_NAMES := ["mage_teleport", "mage_charge", "mage_orb", "mage_orb_pop", "spitter_spit", "spitter_hop"]
## Kisten en unieke voorwerpen met hun nummer in `objects` van vóór deze uitbreiding. Een opgeslagen spel onthoudt ze met
## dat nummer (zie world.gd), dus nieuwe dingen moeten achteraan de lijst staan.
const SAVED_OBJECTS := {
	"forest": [[4, "chest", [10, 4]], [6, "chest", [31, 30]], [7, "pickup", [41, 4]], [47, "pickup", [20, 28]]],
	"ruins": [[18, "chest", [10, 4]], [19, "chest", [29, 29]], [20, "pickup", [36, 5]]],
	"cave": [[19, "chest", [5, 5]], [20, "chest", [43, 3]], [21, "pickup", [41, 30]], [47, "pickup", [24, 10]]],
}
const OLD_OBJECT_COUNT := {"forest": 48, "ruins": 40, "cave": 48}
const SECTIONS := 9 # zoveel testonderdelen moeten tot het eind lopen

var failures := 0
var sections_done := 0
var gs: Node
var world: Node2D
var seen_ids := {}


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


# --- Hulpjes ---------------------------------------------------------------------------------------------

func tile_pos(x: int, y: int) -> Vector2:
	return Vector2(float(x) * TILE + TILE / 2.0, float(y) * TILE + TILE / 2.0)


func start_world(map_id: String) -> void:
	gs.new_game()
	for kind: String in KINDS:
		gs.set_flag("vijanden_hint_" + kind) # de tips zijn al gezien (test_hints test ze apart)
	gs.in_game = true
	gs.map_id = map_id
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)
	await clear_all()
	world.player.invuln = 99999.0


func stop_world() -> void:
	if is_instance_valid(world):
		world.queue_free()
	await frames(3)
	gs.new_game()


func projectiles(kind := "") -> Array:
	var found: Array = []
	for child in world.entities.get_children():
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with("projectile.gd") and (kind == "" or child.kind == kind):
			found.append(child)
	return found


func clear_all() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	for pickup in get_nodes_in_group("pickups"):
		pickup.queue_free()
	for projectile in projectiles():
		projectile.queue_free()
	await frames(2)


## Projectielen van deze soort die er sinds de vorige aanroep bij gekomen zijn.
func fresh(kind: String) -> Array:
	var found: Array = []
	for projectile in projectiles(kind):
		if not seen_ids.has(projectile.get_instance_id()):
			seen_ids[projectile.get_instance_id()] = true
			found.append(projectile)
	return found


func launch(kind: String, pos: Vector2, dir: Vector2, speed: float) -> Node2D:
	world.spawn_projectile(kind, pos, dir, speed, 1, "Test")
	var made := fresh(kind)
	return made[0] if not made.is_empty() else null


func gone(node: Variant) -> bool:
	return not is_instance_valid(node) or node.is_queued_for_deletion()


func put_player(pos: Vector2) -> void:
	world.player.global_position = pos
	world.player.velocity = Vector2.ZERO
	world.player.knockback = Vector2.ZERO
	world.player.invuln = 99999.0


func spawn(kind: String, pos: Vector2) -> Node2D:
	var enemy: Node2D = world.spawn_enemy(kind, pos)
	enemy.set("player", world.player)
	return enemy


## Laat een vijand niet zomaar rondwandelen (voor tests die exacte afstanden nodig hebben).
func freeze_wander(enemy: Node2D) -> void:
	enemy.wander_timer = 99999.0
	enemy.wander_dir = Vector2.ZERO


func wait_state(enemy: Node2D, wanted: String, max_frames: int) -> bool:
	for i in max_frames:
		if enemy.state == wanted:
			return true
		await process_frame
	return enemy.state == wanted


## Ligt `cell` binnen `margin` tegels van een portaal, trigger of poort? Daar zet een test de speler liever niet neer.
func near_exit(map_id: String, cell: Vector2i, margin: int) -> bool:
	for obj: Dictionary in Maps.get_map(map_id)["objects"]:
		if not obj["type"] in ["portal", "trigger", "gate"]:
			continue
		var size: Array = obj.get("size", [1, 1])
		var low := Vector2i(obj["pos"][0], obj["pos"][1]) - Vector2i(margin, margin)
		var high := Vector2i(obj["pos"][0], obj["pos"][1]) + Vector2i(int(size[0]) - 1 + margin, int(size[1]) - 1 + margin)
		if cell.x >= low.x and cell.y >= low.y and cell.x <= high.x and cell.y <= high.y:
			return true
	return false


## Heeft de wereld net een zwevende tekst als "Mislukt!" laten zien?
func shows_text(text: String) -> bool:
	for fx in world.fx_layer.get_children():
		if fx.kind == "text" and fx.text == text:
			return true
	return false


## Het eerste ding op de kaart met deze inhoud (bijvoorbeeld de sleutelkist).
func chest_with(item: String) -> Node2D:
	for child in world.entities.get_children():
		if "contents" in child and child.contents[0][0] == item:
			return child
	return null


## Ligt er tussen `from` en `to` geen muur? Eigen controle in kleine stapjes, los van die van de Magiër.
func open_line(from: Vector2, to: Vector2) -> bool:
	var steps := int(from.distance_to(to) / 2.0)
	for i in range(0, steps + 1):
		if world.is_solid(from.lerp(to, float(i) / float(maxi(steps, 1)))):
			return false
	return true


func is_free_tile(map_rows: Array, x: int, y: int) -> bool:
	if y < 0 or x < 0 or y >= map_rows.size() or x >= String(map_rows[0]).length():
		return false
	return not Tiles.is_solid_char(String(map_rows[y])[x])


## Alle tegels die je vanaf het startpunt kunt bereiken (stappen naar boven, onder, links en rechts).
func reachable(map_id: String) -> Dictionary:
	var def: Dictionary = Maps.get_map(map_id)
	var rows: Array = def["rows"]
	var start: Array = def["spawns"]["start"]
	var seen := {Vector2i(start[0], start[1]): true}
	var todo: Array[Vector2i] = [Vector2i(start[0], start[1])]
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if not seen.has(next) and is_free_tile(rows, next.x, next.y):
				seen[next] = true
				todo.append(next)
	return seen


func objects_of(map_id: String, kinds: Array) -> Array:
	var found: Array = []
	for obj: Dictionary in Maps.get_map(map_id)["objects"]:
		if obj["type"] == "enemy" and obj["kind"] in kinds:
			found.append(obj)
	return found


func count_pickups(item: String) -> int:
	var total := 0
	for pickup in get_nodes_in_group("pickups"):
		if is_instance_valid(pickup) and not pickup.is_queued_for_deletion() and pickup.item == item:
			total += 1
	return total


func drop_table(kind: String) -> Dictionary:
	var table := {}
	for drop: Array in Enemies.info(kind)["drops"]:
		table[drop[0]] = [float(drop[1]), int(drop[2])]
	return table


# --- Deel 1: gegevens, plaatjes en geluiden -----------------------------------------------------------------

func test_data() -> void:
	print("Gegevens van de nieuwe vijanden")
	var mage: Dictionary = Enemies.info("mage")
	var spitter: Dictionary = Enemies.info("slime_spitter")
	var skeleton: Dictionary = Enemies.info("skeleton")
	check(Enemies.ENEMIES.has("mage") and Enemies.ENEMIES.has("slime_spitter"), "beide vijanden zitten via de module in ENEMIES")
	check(Content.MODULES.has(Vijanden), "de module is aangemeld in content.gd")
	check(mage["behavior"] == "mage" and spitter["behavior"] == "spitter", "het gedrag heet mage en spitter")
	check(mage["hp"] == 6 and spitter["hp"] == 4, "levens: Magiër 6, Slijmspuwer 4")
	check(int(mage["damage"]) >= 1 and int(mage["damage"]) <= 2 and int(spitter["damage"]) >= 1 and int(spitter["damage"]) <= 2,
		"schade is 1 of 2 hartjes (je begint met 5)")
	check(int(mage["hp"]) >= int(skeleton["hp"]) and int(mage["hp"]) <= int(skeleton["hp"]) + 3, "de Magiër is iets taaier dan een skelet")
	check(not mage.get("boss", false) and not spitter.get("boss", false), "geen van beide is een baas")
	check(mage["teleport_every"] == 4.0 and mage["cast_time"] == 0.7, "teleport elke 4 seconden, aanloop van 0,7 seconde")
	var span: Array = mage["teleport_range"]
	check(span[0] == 100.0 and span[1] == 140.0, "teleport naar 100-140 pixels van de speler")
	check(mage["orb_speed"] == 90.0, "de arcane bol vliegt met snelheid 90")
	check(spitter["fan"] == 3 and spitter["fan_spread"] == 0.35 and spitter["spit_every"] == 2.2 and spitter["spit_range"] == 170.0
		and spitter["flee_range"] == 60.0, "waaier van 3 (0,35 radialen uit elkaar), elke 2,2 seconden, binnen 170 px, hupt weg binnen 60 px")
	check(float(spitter["speed"]) <= 20.0, "de Slijmspuwer staat bijna stil")

	var drops_ok := true
	for kind: String in KINDS:
		for drop: Array in Enemies.info(kind)["drops"]:
			if not (Items.ITEMS.has(drop[0]) or drop[0] == "heart") or float(drop[1]) <= 0.0 or float(drop[1]) > 1.0 or int(drop[2]) < 1:
				drops_ok = false
	check(drops_ok, "alle drops zijn bestaande voorwerpen met een kans tussen 0 en 1")
	var mage_drops := drop_table("mage")
	check(mage_drops.has("coin") and mage_drops["coin"][0] == 1.0 and mage_drops["coin"][1] == 3, "de Magiër laat altijd 3 munten vallen")
	var skeleton_drops := drop_table("skeleton")
	check(mage_drops.has("potion") and mage_drops.has("heart") and mage_drops["potion"][0] <= skeleton_drops["potion"][0]
		and mage_drops["heart"][0] <= skeleton_drops["heart"][0], "en soms een helddrank of een hartje, niet vaker dan bij een skelet")
	var spit_drops := drop_table("slime_spitter")
	check(spit_drops.has("gel") and absf(spit_drops["gel"][0] - 0.6) < 0.001 and spit_drops.has("coin"), "de Slijmspuwer laat slijmgel (60%) en munten vallen")
	var most_coins := 0
	for kind in ["slime", "slime_blue", "slime_red", "skeleton"]:
		most_coins = maxi(most_coins, int(drop_table(kind)["coin"][1]))
	check(int(mage_drops["coin"][1]) <= most_coins + 1 and int(spit_drops["coin"][1]) <= most_coins, "de munten blijven bij de bestaande economie in de buurt")
	var descs_ok := true
	for kind: String in KINDS:
		var text: String = Enemies.info(kind)["desc"]
		if text.length() < 40 or text.length() > 220 or not (text.ends_with(".") or text.ends_with("!")):
			descs_ok = false
	check(descs_ok, "beide hebben een beschrijving van een of twee zinnen")
	check(mage["name"] == "Magiër" and spitter["name"] == "Slijmspuwer", "de namen volgens het canon")

	print("Plaatjes en geluiden")
	for sheet: String in SHEET_CELLS:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/%s.png" % sheet))
		var cells: int = SHEET_CELLS[sheet]
		check(img != null and img.get_width() == 16 * cells and img.get_height() == 16, "%s.png is %d vakjes van 16x16" % [sheet, cells])
		var filled := 0
		for cell in cells:
			var opaque := 0
			for y in 16:
				for x in 16:
					if img.get_pixel(cell * 16 + x, y).a > 0.5:
						opaque += 1
			if opaque >= 20:
				filled += 1
		check(filled == cells, "elk vakje van %s.png bevat een tekening" % sheet)
	for kind: String in KINDS:
		var info: Dictionary = Enemies.info(kind)
		var tex: Texture2D = load("res://assets/%s.png" % info["sheet"])
		check(info["cell"] == 16 and tex.get_height() == info["cell"] and tex.get_width() == 16 * int(SHEET_CELLS[info["sheet"]]),
			"%s: celgrootte en aantal vakjes in de gegevens kloppen met het plaatje" % kind)
	var snd: Node = root.get_node("Sound")
	var sounds_ok := true
	for sound_name: String in Vijanden.SOUNDS:
		if not snd.SOUNDS.has(sound_name) or not snd.streams.has(sound_name) or not (snd.streams[sound_name] is AudioStreamWAV) \
				or snd.streams[sound_name].get_length() < 0.1:
			sounds_ok = false
			print("       geluid ontbreekt of is te kort: ", sound_name)
	check(sounds_ok, "alle %d nieuwe geluiden zijn geladen" % Vijanden.SOUNDS.size())
	for needed: String in SOUND_NAMES:
		check(Vijanden.SOUNDS.has(needed) and snd.SOUNDS.has(needed), "er is een geluid %s" % needed)
	# Sound.play zegt niets bij een onbekende naam, dus kijken we of elk geluid uit de code ook echt bestaat.
	var missing: Array = []
	var pattern := RegEx.create_from_string("Sound\\.play\\(\"(\\w+)\"")
	for path in ["res://scripts/entities/enemy.gd", "res://scripts/entities/projectile.gd"]:
		for found in pattern.search_all(FileAccess.get_file_as_string(path)):
			if not snd.SOUNDS.has(found.get_string(1)):
				missing.append(found.get_string(1))
	check(missing.is_empty(), "elk geluid dat de vijanden en bollen afspelen bestaat %s" % [missing])
	sections_done += 1


# --- Deel 2: plaatsing op de kaarten ---------------------------------------------------------------------------

func test_placement() -> void:
	print("Plaatsing op de kaarten")
	var spitters := objects_of("forest", ["slime_spitter"]).size()
	check(spitters >= 3 and spitters <= 4, "Fluisterbos: 3 of 4 Slijmspuwers (%d)" % spitters)
	check(objects_of("ruins", ["mage"]).size() == 2, "Vergeten Ruïne: 2 Magiërs")
	check(objects_of("cave", ["mage"]).size() == 2, "Echo-grot: 2 Magiërs")
	check(objects_of("forest", ["mage"]).is_empty() and objects_of("ruins", ["slime_spitter"]).is_empty()
		and objects_of("cave", ["slime_spitter"]).is_empty(), "Magiërs in de ruïne en grot, Slijmspuwers in het bos")
	var elsewhere := 0
	for map_id: String in Maps.MAPS:
		if not map_id in ["forest", "ruins", "cave"]:
			elsewhere += objects_of(map_id, KINDS).size()
	check(elsewhere == 0, "niet in het dorp, de gebouwen en de Kristaltempel (de baasarena blijft zoals hij was)")

	for map_id in ["forest", "ruins", "cave"]:
		var def: Dictionary = Maps.get_map(map_id)
		var rows: Array = def["rows"]
		var reach := reachable(map_id)
		var start: Array = def["spawns"]["start"]
		var taken := {}
		var on_free_tiles := true
		var roomy := true
		var far_from_entrance := true
		var in_company := true
		for obj: Dictionary in def["objects"]:
			if obj["type"] != "enemy":
				continue
			var at := Vector2i(obj["pos"][0], obj["pos"][1])
			if not reach.has(at) or taken.has(at):
				on_free_tiles = false
				print("       %s: %s op %s staat op een onbereikbare of dubbele tegel" % [map_id, obj["kind"], at])
			taken[at] = true
			if not obj["kind"] in KINDS:
				continue
			var free_neighbours := 0
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if is_free_tile(rows, at.x + step.x, at.y + step.y):
					free_neighbours += 1
			if free_neighbours < 4:
				roomy = false
				print("       %s: %s op %s heeft een muur direct naast zich" % [map_id, obj["kind"], at])
			if Vector2(at).distance_to(Vector2(start[0], start[1])) < 8.0:
				far_from_entrance = false
			if obj["kind"] == "slime_spitter":
				var company := 0
				for other: Dictionary in def["objects"]:
					if other["type"] == "enemy" and other != obj and String(other["kind"]).begins_with("slime") \
							and Vector2(at).distance_to(Vector2(other["pos"][0], other["pos"][1])) <= 6.0:
						company += 1
				if company < 1:
					in_company = false
		check(on_free_tiles, "%s: alle vijanden staan op vrije, bereikbare tegels, nooit twee op dezelfde" % map_id)
		check(roomy, "%s: de nieuwe vijanden hebben ruimte om zich heen" % map_id)
		check(far_from_entrance, "%s: de nieuwe vijanden staan niet vlak bij de ingang" % map_id)
		if map_id == "forest":
			check(in_company, "Fluisterbos: elke Slijmspuwer staat bij een groepje slijmen")

		# Alles wat je moet kunnen aanraken is bereikbaar: je kunt op de tegel of ernaast komen.
		var unreachable := []
		for obj: Dictionary in def["objects"]:
			if obj["type"] in ["torch", "trigger", "gate"]:
				continue
			var size: Array = obj.get("size", [1, 1])
			var found := false
			for dx in int(size[0]):
				for dy in int(size[1]):
					var cell := Vector2i(int(obj["pos"][0]) + dx, int(obj["pos"][1]) + dy)
					for step in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if reach.has(cell + step):
							found = true
			if not found:
				unreachable.append("%s@%s" % [obj["type"], obj["pos"]])
		check(unreachable.is_empty(), "%s: personages, kisten, bordjes, voorwerpen en doorgangen zijn bereikbaar %s" % [map_id, unreachable])

	var warnings := {"forest": "slijmspuwers", "ruins": "magiërs", "cave": "magiërs"}
	var warned := {}
	for map_id: String in warnings:
		for obj: Dictionary in Maps.get_map(map_id)["objects"]:
			if obj["type"] == "sign" and warnings[map_id] in String(obj["lines"][0]).to_lower():
				warned[map_id] = true
	check(warned.size() == 3, "een bordje in het bos, de ruïne en de grot waarschuwt voor de nieuwe vijanden")

	# Een opgeslagen spel onthoudt kisten en unieke voorwerpen met hun nummer in de lijst: dat mag niet verschuiven.
	for map_id: String in SAVED_OBJECTS:
		var objects: Array = Maps.get_map(map_id)["objects"]
		var same := true
		for saved: Array in SAVED_OBJECTS[map_id]:
			var obj: Dictionary = objects[saved[0]] if objects.size() > saved[0] else {}
			if obj.get("type", "") != saved[1] or obj.get("pos", []) != saved[2]:
				same = false
				print("       %s: op nummer %d hoort %s %s" % [map_id, saved[0], saved[1], saved[2]])
		var new_at_end := true
		for index in objects.size():
			var obj: Dictionary = objects[index]
			var ours: bool = (obj["type"] == "enemy" and obj["kind"] in KINDS) \
				or (obj["type"] == "sign" and ("magiërs" in String(obj["lines"][0]) or "slijmspuwers" in String(obj["lines"][0])))
			if ours and index < OLD_OBJECT_COUNT[map_id]:
				new_at_end = false
		check(same and new_at_end, "%s: de nieuwe dingen staan achteraan, kisten en kristallen houden hun nummer voor oude opslagen" % map_id)

	# In de echte wereld: ze verschijnen op de juiste plek en staan niet in of tegen een muur.
	for map_id in ["forest", "ruins", "cave"]:
		await start_world(map_id)
		world.load_map(map_id, "start")
		await frames(10)
		var wanted := objects_of(map_id, KINDS)
		var placed: Array = []
		for enemy in get_nodes_in_group("enemies"):
			if enemy.kind in KINDS:
				placed.append(enemy)
		check(placed.size() == wanted.size() and placed.size() > 0, "%s: %d nieuwe vijanden verschijnen in de wereld" % [map_id, placed.size()])
		var fits := true
		for enemy in placed:
			if world.is_solid(enemy.global_position) or not enemy._fits_at(enemy.global_position):
				fits = false
		check(fits, "%s: geen van hen staat in of tegen een muur" % map_id)
		await stop_world()

	# Een opslag van vóór deze uitbreiding: de geopende sleutelkist en het opgepakte boskristal blijven weg.
	gs.new_game()
	gs.set_flag("chest:forest:4")
	gs.set_flag("pickup:forest:7")
	gs.in_game = true
	gs.map_id = "forest"
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)
	var key_chest := chest_with("ruin_key")
	check(key_chest != null and key_chest.opened, "een oude opslag: de sleutelkist is nog steeds open")
	check(count_pickups("crystal_bos") == 0, "en het boskristal ligt er niet opnieuw")
	await stop_world()
	sections_done += 1


# --- Deel 3: de Magiër ---------------------------------------------------------------------------------------------

## De Magiër in de grote zaal van de ruïne, met de speler `gap` pixels links van hem.
func mage_arena(gap: float) -> Node2D:
	await clear_all()
	var mage := spawn("mage", tile_pos(16, 14))
	put_player(mage.global_position + Vector2(-gap, 0))
	await frames(2)
	return mage


func test_mage() -> void:
	print("Magiër: teleporteren")
	await start_world("ruins")
	var player: Node2D = world.player
	var mage := await mage_arena(130.0)
	var spots: Array = []
	var vanish_at: Array = []
	var orb_count := 0
	var last_state := ""
	seen_ids.clear()
	for i in int(FPS * 14.0):
		await process_frame
		if mage.state != last_state:
			if mage.state == "vanish":
				vanish_at.append(i)
			if mage.state == "appear":
				spots.append(mage.global_position)
			last_state = mage.state
		orb_count += fresh("arcane_orb").size()
	check(vanish_at.size() >= 3, "de Magiër teleporteert steeds opnieuw (%d keer in 14 seconden)" % vanish_at.size())
	check(not vanish_at.is_empty() and float(vanish_at[0]) / FPS <= 1.6, "de eerste teleport komt kort nadat hij je ziet")
	var spacing_ok := vanish_at.size() >= 3
	for i in range(1, vanish_at.size()):
		var gap_seconds := float(vanish_at[i] - vanish_at[i - 1]) / FPS
		if gap_seconds < 3.8 or gap_seconds > 4.3:
			spacing_ok = false
	check(spacing_ok, "ongeveer elke 4 seconden")
	var place_ok := not spots.is_empty()
	for spot: Vector2 in spots:
		var d := spot.distance_to(player.global_position)
		if d < 99.0 or d > 141.0 or world.is_solid(spot) or not mage._fits_at(spot):
			place_ok = false
	check(place_ok, "hij landt steeds 100-140 px van je vandaan, nooit in een muur")
	check(orb_count >= 2 and orb_count >= vanish_at.size() - 1, "na elke teleport schiet hij een bol (%d bollen)" % orb_count)

	print("Magiër: aanloop en arcane bol")
	mage = await mage_arena(130.0)
	seen_ids.clear()
	mage.special_timer = 0.0
	var cast_frame := -1
	var orb_frame := -1
	var orb: Node2D = null
	for i in 90:
		await process_frame
		if cast_frame < 0 and mage.state == "cast":
			cast_frame = i
		var made := fresh("arcane_orb")
		if not made.is_empty():
			orb_frame = i
			orb = made[0]
			break
	check(cast_frame >= 0 and orb_frame > cast_frame, "eerst een aanloop, dan pas het schot")
	var windup := float(orb_frame - cast_frame) / FPS
	check(windup >= 0.65 and windup <= 0.78, "de aanloop duurt ongeveer 0,7 seconde (%.2f s)" % windup)
	var orb_start: Vector2 = mage.global_position + Vector2(0, -14)
	check(orb != null and orb.global_position.distance_to(orb_start) < 4.0, "de bol ontstaat boven zijn handen, 14 px boven zijn midden")
	var info: Dictionary = Enemies.info("mage")
	var span: Array = info["teleport_range"]
	var run_and_hit: float = (float(info["appear_time"]) + float(info["cast_time"])) * float(player.SPEED) \
		+ float(Items.WEAPONS["wood"]["reach"]) + float(info["radius"])
	check(run_and_hit >= (float(span[0]) + float(span[1])) / 2.0,
		"ren je meteen op hem af, dan haal je hem meestal nog tijdens de aanloop, zelfs met het houten zwaard (%.0f px)" % run_and_hit)
	check(orb != null and absf(orb.velocity.length() - 90.0) < 1.0, "de bol vliegt met snelheid 90")
	var to_player: Vector2 = player.global_position + Vector2(0, 4) - orb.global_position
	check(absf(orb.velocity.angle_to(to_player)) < 0.1, "en wijst naar de speler")
	check(orb.damage == 1 and orb.is_in_group("breakable"), "de bol doet 1 schade en is stuk te slaan")
	check(mage.state == "idle", "na het schot kit hij weer")

	print("Magiër: de bol raakt de speler")
	await clear_all()
	player.invuln = 0.0
	var hp_before: int = gs.hp
	world.spawn_projectile("arcane_orb", player.global_position + Vector2(60, 0), Vector2.LEFT, 90.0, 1, "Magiër (tovervonk)")
	await frames(70)
	check(gs.hp == hp_before - 1, "een treffer kost 1 hartje (%d -> %d)" % [hp_before, gs.hp])
	check(projectiles("arcane_orb").is_empty(), "de bol verdwijnt na de treffer")
	check(gs.last_damage_source.begins_with("Magiër"), "het game-over-scherm weet wie het was: %s" % gs.last_damage_source)
	var source_ok := false
	mage = await mage_arena(130.0)
	seen_ids.clear()
	mage.special_timer = 0.0
	for i in 120:
		await process_frame
		var shot := fresh("arcane_orb")
		if not shot.is_empty():
			source_ok = shot[0].source == "Magiër (tovervonk)"
			break
	check(source_ok, "een echte bol heet op het game-over-scherm 'Magiër (tovervonk)'")
	await clear_all()
	player.invuln = 99999.0

	print("Magiër: de bol met het zwaard stukslaan")
	await clear_all()
	world.solid_cells.clear() # open veld: alleen het zwaard of de speler kan de bol nog stoppen
	var hp_now: int = gs.hp
	player.facing = Vector2.RIGHT
	put_player(tile_pos(10, 14))
	var near := launch("arcane_orb", player.global_position + Vector2(36, 0), Vector2.LEFT, 90.0)
	var behind := launch("arcane_orb", player.global_position + Vector2(-34, 0), Vector2.LEFT, 0.0)
	var too_far := launch("arcane_orb", player.global_position + Vector2(95, 0), Vector2.RIGHT, 0.0)
	await frames(1)
	player.cooldown = 0.0
	player._attack()
	await frames(2)
	check(gone(near), "een zwaardslag slaat de bol voor je stuk")
	check(not gone(behind), "een bol achter je rug blijft heel")
	check(not gone(too_far), "een bol buiten bereik ook")
	player.facing = Vector2.LEFT
	player.cooldown = 0.0
	player._attack()
	await frames(2)
	check(gone(behind) and not gone(too_far), "draai je om, dan sla je hem alsnog stuk")
	check(gs.hp == hp_now, "en dat kost de speler niets")
	await clear_all()
	player.facing = Vector2.RIGHT
	var point_blank := launch("arcane_orb", player.global_position + Vector2(9, 0), Vector2.LEFT, 90.0)
	player.invuln = 0.0
	player.cooldown = 0.0
	player._attack()
	await frames(3)
	check(gone(point_blank) and gs.hp == hp_now, "ook een bol die al bijna bij je is, sla je nog stuk zonder schade")
	player.invuln = 99999.0
	var twice := launch("arcane_orb", player.global_position + Vector2(60, 0), Vector2.ZERO, 0.0)
	var effects_before: int = world.fx_layer.get_child_count()
	twice.shatter()
	twice.shatter()
	check(world.fx_layer.get_child_count() == effects_before + 2, "twee keer raken in hetzelfde moment geeft maar een knal (wolkje en ring)")
	await clear_all()

	print("Magiër: de bol draait bij en dooft uit")
	put_player(tile_pos(6, 14))
	var curving := launch("arcane_orb", player.global_position + Vector2(200, 0), Vector2.UP, 90.0)
	await frames(1)
	var angle_start := absf(curving.velocity.angle_to(player.global_position + Vector2(0, 4) - curving.global_position))
	await frames(30)
	var angle_later := absf(curving.velocity.angle_to(player.global_position + Vector2(0, 4) - curving.global_position))
	check(angle_later < angle_start - 0.1, "de bol draait langzaam naar je toe (%.2f -> %.2f radialen)" % [angle_start, angle_later])
	check(absf(curving.velocity.length() - 90.0) < 0.5, "zonder sneller te worden")
	curving.queue_free()
	await frames(2)
	var fading := launch("arcane_orb", tile_pos(20, 17), Vector2.RIGHT, 90.0)
	put_player(tile_pos(3, 10)) # ver weg, dus de bol raakt niemand
	var last_age := 0.0
	for i in int(FPS * 4.0):
		await process_frame
		if gone(fading):
			break
		last_age = fading.age
	check(gone(fading) and last_age > 2.9 and last_age < 3.1, "na 3 seconden is de bol weg (%.2f s)" % last_age)
	world.load_map("ruins", "start") # de muren terug
	await frames(5)
	await clear_all()
	put_player(tile_pos(8, 29))
	var wall_orb := launch("arcane_orb", tile_pos(2, 29), Vector2.LEFT, 90.0)
	await frames(30)
	check(gone(wall_orb), "tegen een muur spat de bol uit elkaar")

	print("Magiër: toverspreuk onderbreken")
	mage = await mage_arena(130.0)
	seen_ids.clear()
	mage.special_timer = 0.0
	await wait_state(mage, "cast", 120)
	await frames(8)
	mage.hurt(1, Vector2.RIGHT)
	check(mage.state == "idle" and mage.hp == 5, "een klap tijdens de aanloop onderbreekt de spreuk")
	check(shows_text("Mislukt!"), "en dan zie je 'Mislukt!'")
	await frames(45)
	check(fresh("arcane_orb").is_empty(), "er komt dan geen bol uit")
	mage.special_timer = 99.0
	await frames(3)
	mage.hurt(1, Vector2.RIGHT)
	check(mage.state == "idle" and mage.hp == 4, "een klap op een rustig moment kost alleen een leven")
	mage.special_timer = 0.0
	await wait_state(mage, "vanish", 60)
	mage.hurt(1, Vector2.RIGHT)
	check(mage.state == "vanish" and mage.hp == 3, "een klap terwijl hij verdwijnt houdt de teleport niet tegen")

	print("Magiër: afstand houden")
	mage = await mage_arena(40.0)
	mage.special_timer = 99.0
	await frames(60)
	check(mage.global_position.distance_to(player.global_position) > 70.0,
		"komt de speler dichtbij, dan zweeft hij weg (%.0f px)" % mage.global_position.distance_to(player.global_position))
	mage = await mage_arena(210.0)
	mage.special_timer = 99.0
	await frames(90)
	check(mage.global_position.distance_to(player.global_position) < 170.0, "is de speler te ver weg, dan komt hij dichterbij")
	mage = await mage_arena(400.0)
	freeze_wander(mage)
	seen_ids.clear()
	await frames(int(FPS * 4.0))
	check(mage.state == "idle" and fresh("arcane_orb").is_empty(), "buiten zijn zicht doet hij niets")
	put_player(mage.global_position + Vector2(-130, 0))
	var seen_after := -1
	for i in int(FPS * 2.0):
		await process_frame
		if mage.state == "vanish":
			seen_after = i
			break
	check(seen_after >= int(FPS * 1.0) and seen_after <= int(FPS * 1.4),
		"kom je in zicht, dan teleporteert hij pas na ongeveer 1,2 seconde (%.2f s)" % (float(seen_after) / FPS))

	print("Magiër: dood en drops")
	mage = await mage_arena(130.0)
	seen_ids.clear()
	var died := [0]
	mage.died.connect(func() -> void: died[0] += 1)
	var kills_before: int = gs.kills
	var enemies_before := get_nodes_in_group("enemies").size()
	for i in 5:
		mage.hurt(1, Vector2.RIGHT)
	check(not mage.dead and mage.hp == 1, "na vijf klappen heeft hij nog 1 leven")
	mage.hurt(1, Vector2.RIGHT)
	check(mage.dead and died[0] == 1 and gs.kills == kills_before + 1, "zesde klap: verslagen (signaal en teller)")
	check(get_nodes_in_group("enemies").size() == enemies_before - 1, "hij verdwijnt uit de groep vijanden")
	check(count_pickups("coin") == 3, "hij laat 3 munten vallen")
	mage.hurt(1, Vector2.RIGHT)
	check(died[0] == 1 and gs.kills == kills_before + 1, "een tweede keer doodgaan telt niet mee")
	await clear_all()
	seed(2024)
	var potions := 0
	var hearts := 0
	var coins := 0
	for i in 100:
		var victim := spawn("mage", tile_pos(16, 14))
		victim.hurt(99, Vector2.RIGHT)
		coins += count_pickups("coin")
		potions += count_pickups("potion")
		hearts += count_pickups("heart")
		await clear_all()
	check(coins == 300, "100 Magiërs laten precies 300 munten vallen")
	check(potions >= 3 and potions <= 20 and hearts >= 4 and hearts <= 22, "en soms een helddrank (%d) en een hartje (%d)" % [potions, hearts])

	print("Magiër: lichtje in het donker")
	var lit := spawn("mage", tile_pos(16, 14))
	check(lit.glow != null and lit.glow.energy > 0.0, "in de donkere ruïne geeft de Magiër zelf licht")
	lit.special_timer = 0.0
	await wait_state(lit, "cast", 120)
	await frames(25)
	check(lit.glow.energy > 1.0, "tijdens de aanloop wordt het lichtje feller")
	var dark_orb := launch("arcane_orb", tile_pos(10, 14), Vector2.RIGHT, 0.0)
	check(dark_orb.get_children().any(func(child: Node) -> bool: return child is PointLight2D), "ook zijn tovervonk geeft licht in het donker")
	await stop_world()
	await start_world("forest")
	var daylight := spawn("mage", tile_pos(30, 20))
	check(daylight.glow == null, "in een lichte omgeving is dat niet nodig")
	var day_orb := launch("arcane_orb", tile_pos(30, 22), Vector2.RIGHT, 0.0)
	check(day_orb.get_child_count() == 0, "en zijn tovervonk ook niet")
	await stop_world()
	sections_done += 1


func test_mage_walls() -> void:
	print("Magiër: muren, hoeken en krappe plekken")
	var tested := 0
	var bad := 0
	var no_view := 0
	for map_id in ["ruins", "cave", "forest"]:
		await start_world(map_id)
		var mage := spawn("mage", tile_pos(3, 3))
		mage.set_physics_process(false)
		var cells := reachable(map_id).keys()
		var stride := maxi(int(float(cells.size()) / 150.0), 1)
		var tested_here := 0
		for index in range(0, cells.size(), stride):
			var cell: Vector2i = cells[index]
			put_player(tile_pos(cell.x, cell.y))
			for attempt in 8:
				var spot: Vector2 = mage._mage_pick_spot()
				tested_here += 1
				if spot == Vector2.INF:
					continue
				var d := spot.distance_to(world.player.global_position)
				if d < 99.9 or d > 140.1 or world.is_solid(spot) or not mage._fits_at(spot):
					bad += 1
				# Waar de bol ontstaat (boven zijn handen) mag geen muur zijn, en de weg naar de speler moet vrij zijn.
				var orb_start: Vector2 = spot + Vector2(0, -14)
				if world.is_solid(orb_start) or not open_line(orb_start, world.player.global_position + Vector2(0, 4)):
					no_view += 1
		check(tested_here > 100, "%s: %d teleportplekken gekozen" % [map_id, tested_here])
		tested += tested_here
		await stop_world()
	check(bad == 0, "elke gekozen plek ligt 100-140 px weg en past tussen de muren (%d fout)" % bad)
	check(float(no_view) <= float(tested) * 0.02,
		"en van bijna elke plek vliegt zijn bol vrij naar de speler (%d zonder vrije baan van %d)" % [no_view, tested])

	print("Magiër: in een hoek en zonder ruimte")
	await start_world("ruins")
	var corner := spawn("mage", tile_pos(3, 9))
	corner.special_timer = 99.0
	put_player(tile_pos(5, 10))
	var start_pos: Vector2 = corner.global_position
	var moved := 0.0
	var in_wall := false
	var panicked := false
	for i in int(FPS * 3.0):
		await process_frame
		moved = maxf(moved, corner.global_position.distance_to(start_pos))
		if world.is_solid(corner.global_position):
			in_wall = true
		if corner.state == "vanish":
			panicked = true
	check(not in_wall, "in de hoek komt hij niet in de muur")
	check(moved > 40.0 or panicked, "hij blijft niet vastzitten tegen de muur: hij glijdt weg of teleporteert (%.0f px)" % moved)

	await clear_all()
	var boxed := spawn("mage", tile_pos(12, 14))
	boxed.special_timer = 0.0
	put_player(tile_pos(18, 14))
	for dx in range(-7, 8):
		for dy in range(-7, 8):
			var cell := Vector2i(18 + dx, 14 + dy)
			if cell != Vector2i(18, 14) and Vector2(dx, dy).length() < 6.0:
				world.solid_cells[cell] = true # rondom de speler is geen vrije plek meer
	check(boxed._mage_pick_spot() == Vector2.INF, "zonder vrije plek geeft het zoeken niets terug")
	seen_ids.clear()
	var shots := 0
	var boxed_in_wall := false
	for i in int(FPS * 2.0):
		await process_frame
		shots += fresh("arcane_orb").size()
		if world.is_solid(boxed.global_position):
			boxed_in_wall = true
	check(shots >= 1 and not boxed_in_wall, "dan blijft hij gewoon waar het kan en schiet toch (de bol spat uit elkaar)")
	await stop_world()
	sections_done += 1


# --- Deel 3b: de Slijmspuwer ---------------------------------------------------------------------------------------

## De Slijmspuwer in een open stuk van het bos, met de speler `gap` pixels links van hem.
func spitter_arena(gap: float) -> Node2D:
	await clear_all()
	var sp := spawn("slime_spitter", tile_pos(36, 20))
	freeze_wander(sp)
	put_player(sp.global_position + Vector2(-gap, 0))
	await frames(2)
	return sp


func test_spitter() -> void:
	print("Slijmspuwer: een waaier van drie")
	await start_world("forest")
	var player: Node2D = world.player
	var sp := await spitter_arena(120.0)
	seen_ids.clear()
	var volleys: Array = []
	var sizes: Array = []
	var fan_ok := true
	var fan_text := ""
	var spread: float = Enemies.info("slime_spitter")["fan_spread"]
	for i in int(FPS * 8.0):
		await process_frame
		var made := fresh("slimeball")
		if made.is_empty():
			continue
		volleys.append(i)
		sizes.append(made.size())
		if volleys.size() > 1:
			continue
		# De eerste beurt meten we meteen, want de ballen vliegen daarna weg.
		var aim: float = (player.global_position - sp.global_position).angle()
		var offsets: Array[float] = []
		for ball: Node2D in made:
			offsets.append(angle_difference(aim, ball.velocity.angle()))
			if absf(ball.velocity.length() - 100.0) > 1.0 or ball.damage != 1 or not ball.source.begins_with("Slijmspuwer"):
				fan_ok = false
		offsets.sort()
		fan_ok = fan_ok and offsets.size() == 3 and absf(offsets[0] + spread) < 0.04 and absf(offsets[1]) < 0.04 and absf(offsets[2] - spread) < 0.04
		fan_text = " (hoeken %s)" % [offsets]
	check(volleys.size() >= 3, "hij spuugt steeds opnieuw (%d beurten in 8 seconden)" % volleys.size())
	check(not sizes.is_empty() and sizes.all(func(n: int) -> bool: return n == 3), "elke beurt zijn het precies drie slijmballen tegelijk")
	var interval_ok := volleys.size() >= 3
	for i in range(1, volleys.size()):
		var seconds := float(volleys[i] - volleys[i - 1]) / FPS
		if seconds < 2.1 or seconds > 2.3:
			interval_ok = false
	check(interval_ok, "ongeveer elke 2,2 seconden")
	check(fan_ok, "de middelste wijst naar jou, de andere twee waaieren eromheen, snelheid 100%s" % fan_text)

	print("Slijmspuwer: richten en vastzetten")
	sp = await spitter_arena(120.0)
	sp.special_timer = 0.0
	await wait_state(sp, "windup", 30)
	var windup_time: float = Enemies.info("slime_spitter")["windup"]
	while sp.state == "windup" and sp.state_time < windup_time - 0.1:
		await process_frame
	var locked: Vector2 = sp.aim_dir
	put_player(sp.global_position + Vector2(0, -120)) # de speler stapt vlak voor het spugen opzij
	seen_ids.clear()
	var middle: Node2D = null
	for i in 30:
		await process_frame
		var balls := fresh("slimeball")
		if balls.size() == 3:
			middle = balls[1]
			break
	check(middle != null and absf(middle.velocity.angle_to(locked)) < 0.02,
		"de laatste tel richt hij niet meer: wie vlak voor het spugen opzij stapt, ontwijkt de waaier")

	print("Slijmspuwer: afstand en bereik")
	sp = await spitter_arena(220.0)
	seen_ids.clear()
	await frames(int(FPS * 5.0))
	check(fresh("slimeball").is_empty() and sp.state == "idle", "op 220 px spuugt hij niet (te ver weg)")
	sp = await spitter_arena(160.0)
	seen_ids.clear()
	var shots := 0
	for i in int(FPS * 3.5):
		await process_frame
		shots += fresh("slimeball").size()
	check(shots >= 3, "op 160 px wel")
	sp = await spitter_arena(110.0)
	var path := 0.0
	var last_pos: Vector2 = sp.global_position
	sp.wander_timer = 0.0 # hier mag hij wél rondschuifelen
	for i in int(FPS * 6.0):
		await process_frame
		path += sp.global_position.distance_to(last_pos)
		last_pos = sp.global_position
	check(path / 6.0 < 25.0, "hij blijft bijna stil staan (gemiddeld %.0f px per seconde)" % (path / 6.0))
	sp = await spitter_arena(165.0)
	seen_ids.clear()
	var late_volleys := 0
	for i in int(FPS * 14.0):
		await process_frame
		if i >= int(FPS * 8.0) and not fresh("slimeball").is_empty():
			late_volleys += 1
		elif i < int(FPS * 8.0):
			fresh("slimeball")
	check(late_volleys >= 2 and sp.global_position.distance_to(player.global_position) < 170.0,
		"staat de speler aan de rand van zijn bereik, dan schuifelt hij dichterbij en blijft hij spugen (%d beurten in de laatste 6 s)" % late_volleys)

	print("Slijmspuwer: wegspringen")
	sp = await spitter_arena(40.0)
	sp.special_timer = 99.0
	var started := await wait_state(sp, "hop", 30)
	var highest := 0.0
	for i in 40:
		await process_frame
		highest = maxf(highest, sp.air_height)
	check(started and sp.hop_count == 1, "komt de speler dichterbij dan 60 px, dan hupt hij weg")
	check(highest > 8.0, "het hupje heeft een boog door de lucht (%.0f px hoog)" % highest)
	check(sp.state == "idle" and sp.global_position.distance_to(player.global_position) > 60.0, "hij landt buiten die 60 px (%.0f px)" % sp.global_position.distance_to(player.global_position))
	check(not world.is_solid(sp.global_position) and sp._fits_at(sp.global_position), "op een vrije plek")
	check(sp.global_position.distance_to(player.global_position) >= 40.0 + 15.0, "en echt verder van je af dan eerst")
	sp = await spitter_arena(40.0)
	sp.special_timer = 0.0 # hij wil ook spugen, maar eerst hupt hij weg
	await wait_state(sp, "hop", 30)
	await wait_state(sp, "idle", 60)
	var calm := 0
	while sp.state == "idle" and calm < int(FPS * 2.0):
		calm += 1
		await process_frame
	check(sp.state == "windup" and float(calm) / FPS >= 0.65 and float(calm) / FPS <= 0.8,
		"na het landen wacht hij even voor hij weer spuugt (%.2f s)" % (float(calm) / FPS))
	# Rechts van hem een muur, onder hem een boom en boven hem een plank met net genoeg plek voor een klein sprongetje
	# opzij. Dat brengt hem nauwelijks verder van de speler af, dus dan blijft hij liever staan.
	sp = await spitter_arena(100.0)
	sp.special_timer = 99.0
	var home := Vector2i(36, 20)
	var added: Array[Vector2i] = [Vector2i(home.x, home.y - 2), Vector2i(home.x, home.y + 2)]
	for y in range(home.y - 4, home.y + 5):
		for x in range(home.x + 1, home.x + 5):
			added.append(Vector2i(x, y))
	added = added.filter(func(cell: Vector2i) -> bool: return not world.solid_cells.has(cell))
	for cell in added:
		world.solid_cells[cell] = true
	var plank := StaticBody2D.new() # op botsingslaag 1, net als een kist
	var plank_shape := CollisionShape2D.new()
	plank_shape.shape = RectangleShape2D.new()
	plank_shape.shape.size = Vector2(40, 16)
	plank.add_child(plank_shape)
	plank.position = sp.global_position + Vector2(2, -52) # 44 px boven hem past hij niet meer, 36 px wel
	world.entities.add_child(plank)
	await frames(2)
	put_player(sp.global_position + Vector2(-58, 0))
	await frames(20)
	check(sp.hop_count == 0 and sp.hop_cooldown > 0.0, "een sprongetje opzij dat hem nauwelijks verder weg brengt, doet hij niet")
	for cell in added:
		world.solid_cells.erase(cell)
	plank.queue_free()
	sp = await spitter_arena(40.0)
	sp.special_timer = 99.0
	sp.state = "hop"
	sp.hop_from = sp.global_position
	sp.hop_to = sp.global_position
	sp.state_time = 0.0
	put_player(sp.global_position + Vector2(4, 0))
	player.invuln = 0.0
	var hp_before: int = gs.hp
	await frames(5)
	check(gs.hp == hp_before, "in de lucht raakt hij niemand")
	player.invuln = 99999.0
	sp = await spitter_arena(80.0)
	sp.special_timer = 99.0
	await frames(90)
	check(sp.hop_count == 0, "op 80 px blijft hij gewoon staan")

	sp = await spitter_arena(40.0)
	sp.special_timer = 99.0
	var hop_frames: Array = []
	var last_state := ""
	for i in int(FPS * 6.0):
		await process_frame
		if sp.state != last_state:
			if sp.state == "hop":
				hop_frames.append(i)
			last_state = sp.state
		put_player(sp.global_position + Vector2(-40, 0)) # de speler blijft maar vlak bij hem komen
	var cooldown_ok := hop_frames.size() >= 2
	for i in range(1, hop_frames.size()):
		if float(hop_frames[i] - hop_frames[i - 1]) / FPS < 1.3:
			cooldown_ok = false
	check(cooldown_ok, "hij hupt niet achter elkaar door (%d hupjes in 6 seconden)" % hop_frames.size())

	print("Slijmspuwer: dood en drops")
	sp = await spitter_arena(120.0)
	var died := [0]
	sp.died.connect(func() -> void: died[0] += 1)
	for i in 3:
		sp.hurt(1, Vector2.RIGHT)
	check(not sp.dead and sp.hp == 1, "na 3 klappen heeft hij nog 1 leven")
	sp.hurt(1, Vector2.RIGHT)
	check(sp.dead and died[0] == 1 and count_pickups("coin") == 2, "vierde klap: verslagen en 2 munten")
	await clear_all()
	seed(77)
	var gel := 0
	var hearts := 0
	for i in 100:
		var victim := spawn("slime_spitter", tile_pos(36, 20))
		victim.hurt(99, Vector2.RIGHT)
		gel += count_pickups("gel")
		hearts += count_pickups("heart")
		await clear_all()
	check(gel >= 45 and gel <= 75, "ongeveer 60%% van de Slijmspuwers laat slijmgel vallen (%d van 100)" % gel)
	check(hearts <= 25, "en maar zelden een hartje (%d van 100)" % hearts)
	await stop_world()
	sections_done += 1


func test_spitter_walls() -> void:
	print("Slijmspuwer: muren en hoeken")
	await start_world("forest")
	var rows: Array = Maps.get_map("forest")["rows"]
	var cells := reachable("forest").keys()
	var sampled := 0
	var in_wall := 0
	var stuck := 0
	var hops := 0
	var too_close := 0
	var left_forest := false
	var player: Node2D = world.player
	for index in range(0, cells.size(), 17):
		var cell: Vector2i = cells[index]
		if near_exit("forest", cell, 3):
			continue # de speler mag niet per ongeluk door een portaal naar een ander gebied
		var sp := spawn("slime_spitter", tile_pos(cell.x, cell.y))
		if not sp._fits_at(sp.global_position):
			sp.queue_free()
			continue
		# De speler komt van een vrije kant, vlak bij hem.
		var near_spot := Vector2.INF
		for turn in 8:
			var candidate: Vector2 = sp.global_position + Vector2.from_angle(float(index + turn) * PI / 4.0) * 50.0
			if not world.is_solid(candidate):
				near_spot = candidate
				break
		if near_spot == Vector2.INF:
			sp.queue_free()
			continue
		sampled += 1
		sp.special_timer = 99.0
		freeze_wander(sp)
		put_player(near_spot)
		var player_at_hop := Vector2.INF
		for i in 75:
			await process_frame
			if not is_instance_valid(sp) or gs.map_id != "forest":
				break
			if world.is_solid(sp.global_position):
				in_wall += 1
			if sp.hop_count == 1 and player_at_hop == Vector2.INF:
				player_at_hop = player.global_position
		if not is_instance_valid(sp) or gs.map_id != "forest":
			left_forest = true
			break
		hops += sp.hop_count
		if player_at_hop != Vector2.INF and sp.hop_to.distance_to(player_at_hop) < sp.hop_from.distance_to(player_at_hop) + 15.0:
			too_close += 1
		var to_player: Vector2 = player.global_position - sp.global_position
		if sp.hop_count == 0 and to_player.length() < float(Enemies.info("slime_spitter")["flee_range"]):
			# Hij hupte niet terwijl je vlak bij hem stond (soms duwt een boom je net iets weg): dan moet er echt geen
			# vrije plek zijn geweest.
			sp.hop_cooldown = 0.0
			sp._spitter_hop(to_player, to_player.length())
			if sp.state == "hop":
				stuck += 1
		sp.queue_free()
		await frames(1)
	check(not left_forest, "de speler blijft in het bos (geen portaal geraakt)")
	check(sampled >= 25, "%d beginplekken uitgeprobeerd (open veld, bomen, hoeken)" % sampled)
	check(float(hops) >= float(sampled) / 2.0, "bijna overal hupt hij weg (%d van %d)" % [hops, sampled])
	check(too_close == 0, "elk hupje brengt hem echt verder van de speler af (%d niet)" % too_close)
	check(in_wall == 0, "bij het hupsen komt hij nooit in een muur terecht")
	check(stuck == 0, "en als hij kan hupsen, doet hij dat ook")

	# Een hoek: de speler komt van de open kant.
	var corner := Vector2i(-1, -1)
	for cell: Vector2i in cells:
		if not is_free_tile(rows, cell.x - 1, cell.y) and not is_free_tile(rows, cell.x, cell.y - 1) \
				and is_free_tile(rows, cell.x + 1, cell.y) and is_free_tile(rows, cell.x, cell.y + 1) and is_free_tile(rows, cell.x + 1, cell.y + 1):
			corner = cell
			break
	check(corner.x >= 0, "er is een hoek om in te testen")
	var cornered := spawn("slime_spitter", tile_pos(corner.x, corner.y))
	cornered.special_timer = 99.0
	freeze_wander(cornered)
	put_player(cornered.global_position + Vector2(24, 24))
	var wall_hits := 0
	for i in 150:
		await process_frame
		if world.is_solid(cornered.global_position):
			wall_hits += 1
	check(wall_hits == 0, "in een hoek hupt hij niet door de muur")
	check(cornered.state == "idle" or cornered.state == "hop", "en blijft in een geldige toestand (%s)" % cornered.state)

	print("Vaste dingen op de kaart: kisten, borden en poortjes")
	await clear_all()
	var chest := chest_with("ruin_key")
	var under := spawn("slime_spitter", chest.global_position + Vector2(0, 80))
	under.special_timer = 99.0
	freeze_wander(under)
	check(not under._fits_at(chest.global_position) and under._fits_at(chest.global_position + Vector2(0, 80)),
		"op een kist past hij niet, op het gras eronder wel")
	check(not under._clear_line(chest.global_position + Vector2(-40, 6), chest.global_position + Vector2(40, 6)),
		"een kist staat in de weg: daar is geen vrij zicht doorheen")
	put_player(under.global_position + Vector2(0, 40)) # de speler komt van onderen, recht weg is de kist
	await wait_state(under, "hop", 30)
	var lid: CollisionShape2D = chest.get_children().filter(func(child: Node) -> bool: return child is CollisionShape2D)[0]
	var box := Rect2(chest.global_position + lid.position - lid.shape.size / 2.0, lid.shape.size)
	var feet: Vector2 = under.hop_to + Vector2(0, 32.0 * 0.28) # waar zijn botsingsrondje zit
	var gap := feet.distance_to(Vector2(clampf(feet.x, box.position.x, box.end.x), clampf(feet.y, box.position.y, box.end.y)))
	check(under.hop_count == 1 and gap >= under.radius, "hij hupt weg, maar niet bovenop de kist (%.0f px ertussen)" % gap)
	await stop_world()
	sections_done += 1


func test_hints() -> void:
	print("Tips bij de eerste ontmoeting")
	await start_world("ruins")
	gs.set_flag("vijanden_hint_mage", false)
	var toasts: Array = []
	var catcher := func(text: String) -> void: toasts.append(text)
	gs.toast.connect(catcher)
	var mage := await mage_arena(130.0)
	mage.special_timer = 99.0
	await frames(5)
	check(toasts.size() == 1 and toasts[0] == Enemies.info("mage")["hint"], "de eerste Magiër geeft een tip")
	check(gs.flag("vijanden_hint_mage"), "en onthoudt dat (de vlag wordt mee opgeslagen)")
	await frames(60)
	var second := await mage_arena(130.0)
	second.special_timer = 99.0
	await frames(30)
	check(toasts.size() == 1, "een tweede Magiër geeft geen tweede tip")
	gs.set_flag("vijanden_hint_mage", false)
	var far := await mage_arena(400.0)
	freeze_wander(far)
	await frames(30)
	check(toasts.size() == 1, "een Magiër die je nog niet ziet, geeft geen tip")
	gs.toast.disconnect(catcher)
	gs.set_flag("vijanden_hint_mage", false)
	var reader := await mage_arena(130.0)
	var calm := 0
	while reader.state == "idle" and calm < int(FPS * 5.0):
		calm += 1
		await process_frame
	check(float(calm) / FPS >= 3.2 and reader.state == "vanish",
		"bij de tip wacht hij met zijn eerste aanval tot de tip weer weg is (%.2f s)" % (float(calm) / FPS))
	await stop_world()
	await start_world("forest")
	gs.set_flag("vijanden_hint_slime_spitter", false)
	toasts.clear()
	gs.toast.connect(catcher)
	var sp := await spitter_arena(100.0)
	await frames(5)
	check(toasts.size() == 1 and toasts[0] == Enemies.info("slime_spitter")["hint"], "de eerste Slijmspuwer geeft een tip")
	check(gs.flag("vijanden_hint_slime_spitter"), "en onthoudt dat ook")
	check(sp.state == "idle" and sp.special_timer > 3.0, "en spuugt pas als je de tip hebt kunnen lezen")
	var long_enough := true
	for kind: String in KINDS:
		if String(Enemies.info(kind)["hint"]).length() > 75:
			long_enough = false
	check(long_enough, "de tips passen op een regel in beeld")
	gs.toast.disconnect(catcher)
	await stop_world()
	sections_done += 1


func test_touch() -> void:
	print("Aanraken en onzichtbaar zijn")
	await start_world("ruins")
	var mage := spawn("mage", tile_pos(16, 14))
	mage.special_timer = 99.0
	var player: Node2D = world.player
	put_player(mage.global_position)
	player.invuln = 0.0
	var hp_before: int = gs.hp
	mage.state = "vanish"
	mage.state_time = 0.0
	await frames(5)
	check(gs.hp == hp_before, "als rookwolkje kan de Magiër niemand raken")
	mage.state = "idle"
	player.invuln = 0.0
	await frames(3)
	check(gs.hp == hp_before - 1, "als hij gewoon zweeft doet aanraken 1 schade")
	await stop_world()
	sections_done += 1


# --- Deel 4: opslaan en laden --------------------------------------------------------------------------------------

func test_save() -> void:
	print("Opslaan en laden")
	# Draait de test los (zonder tools/run_tests.sh), dan staat hier misschien een echt opgeslagen spel: dat komt terug.
	var real_save := FileAccess.get_file_as_string(gs.SAVE_PATH) if FileAccess.file_exists(gs.SAVE_PATH) else ""
	await start_world("forest")
	world.load_map("forest", "start")
	await frames(5)
	var seen_flag := "vijanden_hint_slime_spitter"
	gs.set_flag(seen_flag, false)
	var kills_before: int = gs.kills
	var spitters: Array = []
	for enemy in get_nodes_in_group("enemies"):
		if enemy.kind == "slime_spitter":
			spitters.append(enemy)
	var placed := spitters.size()
	put_player(spitters[0].global_position + Vector2(100, 0))
	await frames(3)
	check(gs.flag(seen_flag), "wie een Slijmspuwer ziet, krijgt de vlag %s" % seen_flag)
	spitters[0].hurt(99, Vector2.RIGHT)
	check(gs.kills == kills_before + 1, "een verslagen Slijmspuwer telt mee")
	gs.coins = 12
	gs.save_game(world.player.global_position)
	await stop_world()
	check(gs.kills == 0 and gs.coins == 0 and not gs.flag(seen_flag), "een nieuw spel begint op nul")
	check(gs.load_game() and gs.kills == kills_before + 1 and gs.coins == 12 and gs.map_id == "forest", "laden brengt teller, munten en plek terug")
	check(gs.flag(seen_flag), "en onthoudt dat je de tip al hebt gezien")
	gs.in_game = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(8)
	var back := 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.kind == "slime_spitter":
			back += 1
	check(back == placed, "na het laden staan de Slijmspuwers weer in het bos (%d van %d)" % [back, placed])
	await stop_world()
	if real_save != "":
		FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE).store_string(real_save)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.SAVE_PATH))
	sections_done += 1


func _run() -> void:
	gs = root.get_node("GameState")
	seed(1)
	test_data()
	await test_placement()
	await test_mage()
	await test_mage_walls()
	await test_spitter()
	await test_spitter_walls()
	await test_hints()
	await test_touch()
	await test_save()
	check(sections_done == SECTIONS, "alle %d onderdelen zijn tot het eind gelopen (%d)" % [SECTIONS, sections_done])

	print("")
	if failures == 0:
		print("VIJANDEN TEST OK")
		quit(0)
	else:
		print("VIJANDEN TEST: %d fout(en)" % failures)
		quit(1)
