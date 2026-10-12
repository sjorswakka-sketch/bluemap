extends SceneTree
## Test van de arena: ingang en voorwaarden, inschrijven, de golven, het gesloten veld, rangen, verliezen en opgeven,
## beloningen, records, opslaan en laden, bereikbaarheid van alles op de kaarten en vijanden die niet in muren komen.
##
##   godot --headless --fixed-fps 60 --path . -s tests/arena_test.gd

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Items := preload("res://scripts/data/items.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const Npcs := preload("res://scripts/data/npcs.gd")
const Dialogue := preload("res://scripts/data/dialogue.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Content := preload("res://scripts/data/content.gd")
const Art := preload("res://scripts/core/art.gd")

var failures := 0
var gs: Node
var sound: Node
var world: Node2D
var Arena: GDScript # de regels van de arena; gebruikt GameState, dus pas laden als het spel draait


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


# --- Hulpjes ---------------------------------------------------------------------------------------

func tile_center(x: int, y: int) -> Vector2:
	return Vector2(float(x) * 32.0 + 16.0, float(y) * 32.0 + 16.0)


func start_world(map_id: String, weapon := "iron", with_quest := true) -> void:
	gs.new_game()
	gs.in_game = true
	gs.weapon = weapon
	if with_quest:
		gs.start_quest("main")
	gs.map_id = map_id
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)


func stop_world() -> void:
	if is_instance_valid(world):
		world.queue_free()
	await frames(3)


func put_player(pos: Vector2, invulnerable := true) -> void:
	world.player.global_position = pos
	world.player.velocity = Vector2.ZERO
	world.player.invuln = 999.0 if invulnerable else 0.0
	await frames(3)


func object_of(map_id: String, type: String, key := "", value: Variant = null) -> Dictionary:
	for obj: Dictionary in Maps.get_map(map_id)["objects"]:
		if obj["type"] == type and (key == "" or obj.get(key) == value):
			return obj
	return {}


func portal_rect(obj: Dictionary) -> Rect2:
	var size: Array = obj.get("size", [1, 1])
	return Rect2(Vector2(obj["pos"][0], obj["pos"][1]) * 32.0, Vector2(size[0], size[1]) * 32.0)


## Loopt van onder het poortje erin (zoals een speler) en wacht tot de overgang klaar is.
func walk_into(obj: Dictionary) -> void:
	var rect := portal_rect(obj)
	await put_player(rect.get_center() + Vector2(0, 64))
	await put_player(rect.get_center())
	await frames(90)


func master() -> Node:
	return get_first_node_in_group("arena_master")


func talk(talk_id: String, picks: Array = []) -> void:
	gs.start_dialogue(talk_id)
	await frames(2)
	var index := 0
	var guard := 0
	while world.dialogue.active and guard < 300:
		guard += 1
		if not world.dialogue.buttons.is_empty():
			var choice: int = picks[index] if index < picks.size() else world.dialogue.buttons.size() - 1
			index += 1
			world.dialogue.buttons[mini(choice, world.dialogue.buttons.size() - 1)].pressed.emit()
		else:
			var down := InputEventAction.new()
			down.action = "interact"
			down.pressed = true
			root.push_input(down)
		await frames(2)


## Welk gesprek Bruno nu zou voeren (dezelfde regels als in npc.gd).
func bruno_talk() -> String:
	for rule: Dictionary in Npcs.NPCS["arena_bruno"]["rules"]:
		if not rule.has("if") or gs.check_all(rule["if"]):
			return rule["talk"]
	return ""


## Wacht (hoogstens `limit` beeldjes) tot `done` waar is. Geeft terug of het gelukt is.
func wait_for(done: Callable, limit := 600) -> bool:
	for i in limit:
		if done.call():
			return true
		await process_frame
	return done.call()


## Zet je in de arena met een inschrijving voor `rank`, zoals na een wandeling door de arenadeur.
func enter_arena(rank: String, coins := 100) -> void:
	await start_world("arena_hall")
	gs.set_flag("arena_met_bruno") # Bruno heeft je al uitgelegd hoe het werkt
	gs.coins = coins
	check(Arena.register(rank), "ingeschreven voor %s" % rank)
	await walk_into(object_of("arena_hall", "portal", "to", "arena"))


func kill_all_foes() -> void:
	for enemy in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.active = true
			enemy.hurt(9999, Vector2.RIGHT)
	await frames(2)


## Alle vijanden van een ronde zijn verschenen (en niemand moet nog komen).
func round_ready(m: Node) -> bool:
	return m.queue.is_empty() and m.warnings.is_empty() and m.phase == "fight"


func kinds_of(foes: Array) -> Dictionary:
	var kinds := {}
	for enemy in foes:
		kinds[enemy.kind] = int(kinds.get(enemy.kind, 0)) + 1
	return kinds


func round_kinds(rank: String, index: int) -> Dictionary:
	var kinds := {}
	for entry: Array in Arena.RANKS[rank]["rounds"][index]:
		kinds[entry[0]] = int(kinds.get(entry[0], 0)) + int(entry[1])
	return kinds


func projectile_count() -> int:
	var total := 0
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with("projectile.gd") and not child.is_queued_for_deletion():
			total += 1
	return total


func foes_in_walls() -> int:
	var inside := 0
	for enemy in get_nodes_in_group("enemies"):
		if world.is_solid(enemy.global_position):
			inside += 1
	return inside


## Alle toegankelijke tegels vanaf een beginpunt (vier richtingen), zoals een speler kan lopen.
func reachable_from(map_id: String, start: Array) -> Dictionary:
	var rows: Array = Maps.get_map(map_id)["rows"]
	var seen := {}
	var todo: Array = [Vector2i(start[0], start[1])]
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		if seen.has(cell) or cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[0].length():
			continue
		if Tiles.is_solid_char(rows[cell.y][cell.x]):
			continue
		seen[cell] = true
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			todo.append(cell + step)
	return seen


## Kun je bij dit tegeltje komen, of er direct naast staan (bijvoorbeeld om iets aan te spreken)?
func touchable(seen: Dictionary, x: int, y: int) -> bool:
	for step: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if seen.has(Vector2i(x, y) + step):
			return true
	return false


# --- Gegevens ----------------------------------------------------------------------------------------

func test_data() -> void:
	print("Gegevens: rangen, rondes en voorwerpen")
	check(Arena.ORDER == ["bronze", "silver", "gold"], "drie rangen in volgorde: Brons, Zilver, Goud")
	var fees := [10, 25, 50]
	var rewards := [50, 150, 400]
	var round_counts := [3, 5, 7]
	for i in 3:
		var rank: String = Arena.ORDER[i]
		var info: Dictionary = Arena.RANKS[rank]
		check(info["fee"] == fees[i] and info["reward"] == rewards[i] and info["rounds"].size() == round_counts[i],
			"%s: inschrijving %d, beloning %d, %d rondes" % [info["name"], fees[i], rewards[i], round_counts[i]])
		var kinds_ok := true
		var threat: Array[int] = []
		for round_list: Array in info["rounds"]:
			var hp := 0
			for entry: Array in round_list:
				if not Enemies.ENEMIES.has(entry[0]) or int(entry[1]) <= 0:
					kinds_ok = false
				else:
					hp += int(Enemies.ENEMIES[entry[0]]["hp"]) * int(entry[1])
			threat.append(hp)
		check(kinds_ok, "%s: alle rondes gebruiken bestaande vijanden" % info["name"])
		check(threat[threat.size() - 1] > threat[0], "%s: de laatste ronde is zwaarder dan de eerste (%d tegen %d levenspunten)" % [info["name"], threat[threat.size() - 1], threat[0]])
		check(Items.ITEMS.has(info["trophy"]), "%s: de trofee bestaat als voorwerp" % info["name"])
	var last_gold: Array = Arena.RANKS["gold"]["rounds"][6]
	check(last_gold.size() == 1 and last_gold[0][0] == "golem" and last_gold[0][1] == 1, "de laatste ronde van Goud is een kristalgolem")
	var icons_ok := true
	for item_id: String in ["arena_trophy_bronze", "arena_trophy_silver", "arena_trophy_gold", "arena_helm"]:
		icons_ok = icons_ok and Items.ITEMS.has(item_id) and Items.sheet_of(item_id) == "items_arena"
	check(icons_ok and Art.tex("items_arena").get_width() == 4 * 16, "trofeeën en helm hebben eigen iconen in items_arena.png")
	check(Art.tex("arena_crowd").get_width() >= 16 * 16 and Art.tex("npc_bruno").get_width() == 32 and Art.tex("tiles").get_width() == Tiles.NAMES.size() * 16, "publiek, Bruno en tegels hebben hun plaatjes")
	check(has_all_sounds(), "geluiden en muziek van de arena zijn geladen")
	var types := Content.object_types()
	var types_ok := true
	for type_name: String in ["arena_master", "arena_crowd", "arena_board", "arena_gong", "arena_prop"]:
		types_ok = types_ok and types.get(type_name) is Script
	check(types_ok, "de objectsoorten van de arena zijn geladen")

	print("Gesprekken en tekens")
	var numbers_ok := true
	for rank: String in Arena.ORDER:
		var info: Dictionary = Arena.RANKS[rank]
		var text: String = " ".join(Dialogue.TALKS["arena_%s_info" % rank]["lines"])
		numbers_ok = numbers_ok and ("%d munten" % info["fee"]) in text and ("%d munten" % info["reward"]) in text
		var menu_text := ""
		for choice: Dictionary in Dialogue.TALKS["arena_bruno_ranks"]["choices"]:
			if choice["text"].begins_with(info["name"] + ":"):
				menu_text = choice["text"]
		numbers_ok = numbers_ok and ("%d rondes" % info["rounds"].size()) in menu_text and ("%d munten" % info["fee"]) in menu_text
	check(numbers_ok, "Bruno noemt de juiste bedragen en aantallen rondes")
	var tokens_ok := true
	var regex := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for talk_id: String in Dialogue.TALKS:
		if not talk_id.begins_with("arena_"):
			continue
		var node: Dictionary = Dialogue.TALKS[talk_id]
		var all_text: Array = node.get("lines", []).duplicate()
		for choice: Dictionary in node.get("choices", []):
			all_text.append(choice["text"])
		for line: String in all_text:
			for found in regex.search_all(line):
				var token := found.get_string(1)
				if not (token in ["crystals", "gel", "shards", "coins"] or token in Content.format_names()):
					print("       onbekend teken {%s} in %s" % [token, talk_id])
					tokens_ok = false
	check(tokens_ok, "alle {tekens} in de gesprekken van de arena bestaan")
	gs.new_game()
	check(gs.fmt("Hé {arena_title}! Goud: {arena_best_gold}") == "Hé nieuwkomer! Goud: nog niet gehaald", "zonder records: nieuwkomer en 'nog niet gehaald'")
	gs.arena_records = {"bronze": 92.4}
	gs.set_flag("arena_bronze_done")
	check(gs.fmt("{arena_best_bronze}, {arena_title}") == "1:32, Arenastrijder", "met een record: de tijd en de titel (%s)" % gs.fmt("{arena_best_bronze}, {arena_title}"))
	check(gs.fmt("{coins} munten en {arena_unknown}") == "0 munten en {arena_unknown}", "onbekende tekens blijven staan, gewone tekens werken nog")
	var filled := true
	for token: String in Content.format_names():
		filled = filled and Content.format_text("{%s}" % token) != "{%s}" % token and Content.format_text("{%s}" % token) != ""
	var arena_tokens := ["arena_title", "arena_best_bronze", "arena_best_silver", "arena_best_gold"]
	var all_there := arena_tokens.all(func(token: String) -> bool: return token in Content.format_names())
	check(filled and all_there, "Content.format_text vult elk teken in, ook die van de arena %s" % [Content.format_names()])
	check(Content.format_text("Goud: {arena_best_gold}!") == "Goud: nog niet gehaald!" and Content.format_text("geen tekens") == "geen tekens", "en laat de rest van de tekst staan")
	var quest: Dictionary = Quests.info("arena_kampioen")
	check(quest["steps"].size() == 3, "de opdracht Arenakampioen heeft drie stappen")
	gs.new_game()


func has_all_sounds() -> bool:
	for sound_name: String in ["arena_gong", "arena_crowd", "arena_cheer", "arena_gate", "arena_fanfare", "arena_defeat"]:
		if not sound.streams.has(sound_name):
			return false
	return sound.tracks.has("arena")


# --- Kaarten: alles bereikbaar, niets in een muur --------------------------------------------------------

func test_maps() -> void:
	print("Kaarten: bereikbaarheid")
	for map_id: String in ["arena_hall", "arena"]:
		var unknown := {}
		for row: String in Maps.get_map(map_id)["rows"]:
			for ch in row:
				if not Tiles.CHARS.has(ch):
					unknown[ch] = true
		check(unknown.is_empty(), "%s: elk teken in de kaart is een bekende tegel %s" % [map_id, unknown.keys()])
	for map_id: String in ["arena_hall", "arena", "village"]:
		var def: Dictionary = Maps.get_map(map_id)
		var seen := reachable_from(map_id, def["spawns"]["start"])
		var missing: Array = []
		for spawn_name: String in def["spawns"]:
			var spawn: Array = def["spawns"][spawn_name]
			if not seen.has(Vector2i(spawn[0], spawn[1])):
				missing.append("spawn " + spawn_name)
		for obj: Dictionary in def["objects"]:
			var pos: Array = obj["pos"]
			match obj["type"]:
				"npc", "sign", "chest", "pickup", "savepoint", "arena_gong":
					if not touchable(seen, pos[0], pos[1]):
						missing.append("%s op %s" % [obj["type"], pos])
				"arena_board":
					var near := false
					for x in int(obj.get("span", 4)):
						near = near or seen.has(Vector2i(pos[0] + x, pos[1] + 1))
					if not near:
						missing.append("bord op %s" % [pos])
				"portal", "gate":
					var size: Array = obj.get("size", [1, 1])
					var any_reachable := false
					for dx in int(size[0]):
						for dy in int(size[1]):
							any_reachable = any_reachable or seen.has(Vector2i(pos[0] + dx, pos[1] + dy))
					if not any_reachable:
						missing.append("%s op %s" % [obj["type"], pos])
		check(missing.is_empty(), "%s: alles is bereikbaar %s" % [map_id, missing])
	var village := Maps.get_map("village")
	var village_seen := reachable_from("village", village["spawns"]["start"])
	var arena_door := object_of("village", "portal", "to", "arena_hall")
	check(not arena_door.is_empty() and village_seen.has(Vector2i(arena_door["pos"][0], arena_door["pos"][1] + 1)), "de arena-ingang in het dorp is te bereiken")
	check(village_seen.has(Vector2i(village["spawns"]["from_arena"][0], village["spawns"]["from_arena"][1])), "en je komt er terug uit bij de ingang")
	check(arena_door["pos"][0] >= 28 and arena_door["pos"][1] <= 6, "de ingang staat in het noordoosten van het dorp")

	var arena_def := Maps.get_map("arena")
	var arena_seen := reachable_from("arena", arena_def["spawns"]["start"])
	var master_obj := object_of("arena", "arena_master")
	var free_ok := true
	for gate: Array in master_obj["gates"]:
		var out := Vector2i(gate[0] + gate[2], gate[1] + gate[3])
		if not Tiles.is_solid_char(arena_def["rows"][gate[1]][gate[0]]):
			free_ok = false # de poort zelf is een hek in de muur
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx * int(gate[2]) + dy * int(gate[3]) < 0:
					continue # dit stukje ligt in de muur zelf
				free_ok = free_ok and arena_seen.has(out + Vector2i(dx, dy)) # ook voor de grote golem is er ruimte
	check(free_ok and master_obj["gates"].size() >= 4, "alle %d poorten komen uit op vrij zand met ruimte eromheen" % master_obj["gates"].size())
	var field: Array = master_obj["field"]
	var field_ok := true
	for y in range(field[1], field[3] + 1):
		for x in range(field[0], field[2] + 1):
			field_ok = field_ok and arena_seen.has(Vector2i(x, y))
	check(field_ok, "het hele veld is te belopen")


# --- Ingang en voorwaarden ------------------------------------------------------------------------------

func test_entrance() -> void:
	print("Ingang: wie mag de arena in")
	await start_world("village", "wood", false)
	check(not gs.check(["arena_open"]), "met een houten zwaard en zonder Bram: dicht")
	gs.weapon = "iron"
	check(not gs.check(["arena_open"]), "met een ijzeren zwaard maar zonder Bram te kennen: nog dicht")
	gs.weapon = "wood"
	gs.start_quest("main")
	check(not gs.check(["arena_open"]), "Bram gesproken maar nog een houten zwaard: nog dicht")
	gs.weapon = "iron"
	check(gs.check(["arena_open"]), "Bram gesproken en een ijzeren zwaard: open")
	gs.weapon = "crystal"
	check(gs.check(["arena_open"]), "ook met het kristalzwaard")

	gs.weapon = "wood"
	var door := object_of("village", "portal", "to", "arena_hall")
	await put_player(tile_center(33, 8))
	await walk_into(door)
	check(gs.map_id == "village", "met een houten zwaard stuurt de wachter je weg")
	gs.weapon = "iron"
	await put_player(tile_center(33, 8))
	await walk_into(door)
	check(gs.map_id == "arena_hall" and not gs.transitioning, "met een ijzeren zwaard loop je door de arena-ingang naar de hal")
	check(get_nodes_in_group("npc").size() == 1 and get_nodes_in_group("npc")[0].npc_id == "arena_bruno", "Bruno staat in de hal")

	print("De hal: de deur naar de arena zit dicht tot je bent ingeschreven")
	var arena_door := object_of("arena_hall", "portal", "to", "arena")
	check(not gs.check_all(arena_door["requires"]), "zonder inschrijving is de arenadeur dicht")
	await walk_into(arena_door)
	check(gs.map_id == "arena_hall", "je komt er niet door")
	gs.coins = 10
	check(Arena.register("bronze"), "inschrijven voor Brons")
	check(gs.check_all(arena_door["requires"]), "met een inschrijving gaat de deur open")
	await walk_into(arena_door)
	check(gs.map_id == "arena", "door de deur kom je in de arena")
	await stop_world()
	await start_world("arena_hall")
	var back := object_of("arena_hall", "portal", "to", "village")
	await walk_into(back)
	check(gs.map_id == "village" and world.player.global_position.distance_to(tile_center(33, 5)) < 40.0, "de deur terug brengt je bij de arena-ingang in het dorp")
	await stop_world()


# --- Inschrijven -------------------------------------------------------------------------------------------

func test_registration() -> void:
	print("Inschrijven")
	await start_world("arena_hall")
	gs.coins = 9
	check(not Arena.register("bronze") and gs.coins == 9 and Arena.registered_rank() == "", "met 9 munten kun je je niet inschrijven voor Brons (10)")
	gs.coins = 10
	check(Arena.register("bronze") and gs.coins == 0 and Arena.registered_rank() == "bronze", "met 10 munten wel: je betaalt en staat op de lijst")
	check(not Arena.register("bronze") and gs.coins == 0, "je kunt je niet nog een keer inschrijven")
	gs.coins = 100
	check(not Arena.register("silver") and gs.coins == 100, "Zilver is dicht: eerst Brons halen")
	check(not Arena.register("gold") and gs.coins == 100, "en Goud ook")
	check(Arena.cancel() and gs.coins == 110 and Arena.registered_rank() == "", "uitschrijven geeft je inschrijfgeld terug")
	check(not Arena.cancel() and gs.coins == 110, "uitschrijven zonder inschrijving doet niets")
	check(not Arena.register("platina") and gs.coins == 110, "een rang die niet bestaat kan niet")

	print("Inschrijven bij Bruno (gesprek)")
	gs.coins = 5
	check(bruno_talk() == "arena_bruno_intro", "de eerste keer legt Bruno uit hoe het werkt")
	await talk("arena_bruno_intro", [3])
	check(gs.flag("arena_met_bruno") and gs.quest_state("arena_kampioen") == "active" and bruno_talk() == "arena_bruno_menu", "daarna start de opdracht Arenakampioen en krijg je het gewone menu")
	await talk("arena_bruno_menu", [0, 0])
	check(Arena.registered_rank() == "" and gs.coins == 5, "zonder genoeg munten zegt Bruno nee")
	gs.coins = 10
	await talk("arena_bruno_menu", [0, 0, 0])
	check(Arena.registered_rank() == "bronze" and gs.coins == 0, "met genoeg munten schrijft Bruno je in")
	check(bruno_talk() == "arena_bruno_registered", "daarna herinnert Bruno je aan de deur")
	await talk("arena_bruno_registered", [1])
	check(Arena.registered_rank() == "" and gs.coins == 10, "je kunt je bedenken en krijgt je munten terug")
	check(bruno_talk() == "arena_bruno_menu", "en Bruno praat weer gewoon")
	await talk("arena_bruno_menu", [0, 1])
	gs.start_dialogue("arena_bruno_ranks")
	await frames(3)
	while world.dialogue.active and world.dialogue.buttons.is_empty():
		world.dialogue._advance()
		await frames(2)
	check(world.dialogue.buttons.size() == 2, "in het begin staat alleen Brons in de lijst (en 'toch maar niet')")
	world.dialogue.buttons[1].pressed.emit()
	await frames(2)
	await talk("arena_bruno_menu", [3])
	await stop_world()


# --- Een toernooi spelen ---------------------------------------------------------------------------------

func test_bronze_run() -> void:
	print("Brons: de golven")
	await enter_arena("bronze", 40)
	var m := master()
	check(m != null and gs.map_id == "arena", "we staan in de arena met de arenameester")
	check(m.rank == "bronze" and m.phase == "intro", "het toernooi begint met een korte introductie")
	check(Arena.registered_rank() == "bronze", "de inschrijving blijft staan tot de eerste gong (een afgesloten spel verliest niets)")
	check(gs.coins == 40 - 10 + 0, "het inschrijfgeld was 10 munten (%d over)" % gs.coins)
	m.rng.seed = 12345
	var exit_gate: Node = null
	for node in get_nodes_in_group("interactable"):
		if "gate_id" in node and node.gate_id == "arena_exit":
			exit_gate = node
	check(Arena.run_active and gs.check(["arena_fight"]) and not gs.check(["arena_free"]), "de poorten zijn dicht zodra het toernooi begint")
	await frames(3)
	check(exit_gate != null and exit_gate.blocked, "het hek voor de uitgang zit dicht")
	var crowd := get_first_node_in_group("arena_crowd")
	check(crowd != null and crowd.seats.size() > 80, "het publiek zit op de tribunes (%d toeschouwers)" % crowd.seats.size())

	# De uitgang is echt dicht, ook als je er tegenaan loopt.
	await put_player(tile_center(12, 14))
	Input.action_press("move_down")
	await frames(70)
	Input.action_release("move_down")
	check(world.player.global_position.y < 16.0 * 32.0 and gs.map_id == "arena", "tegen het hek aan lopen: je blijft in de arena")
	await put_player(portal_rect(object_of("arena", "portal")).get_center())
	await frames(60)
	check(gs.map_id == "arena", "ook een sprong naar de uitgang werkt niet: de poorten zijn dicht")
	await put_player(tile_center(12, 11))

	# Ronde 1
	m.timer = 0.0
	await frames(2)
	check(m.phase == "fight" and m.round_index == 0, "na de gong begint ronde 1")
	check(Arena.registered_rank() == "", "met de gong is de inschrijving gebruikt")
	check(await wait_for(func() -> bool: return m.foes.size() >= 1), "de eerste vijand komt uit een poort")
	var newcomer: Node2D = m.foes[0]
	check(not newcomer.active and newcomer.modulate.a < 1.0 and m.emerging.size() >= 1, "hij is eerst nog doorzichtig en kan nog niet vechten")
	var hits_before: int = newcomer.hp
	newcomer.hurt(2, Vector2.RIGHT)
	check(newcomer.hp == hits_before, "en je kunt hem nog niet raken (korte animatie)")
	check(await wait_for(func() -> bool: return round_ready(m)), "de vijanden komen een voor een uit de poorten")
	check(kinds_of(m.foes) == round_kinds("bronze", 0), "ronde 1: precies de vijanden uit de data %s" % [kinds_of(m.foes)])
	var first_total := 0
	for amount: int in round_kinds("bronze", 0).values():
		first_total += amount
	check(m.foes.size() == first_total and get_nodes_in_group("enemies").size() == first_total, "ronde 1 heeft %d vijanden" % first_total)
	check(foes_in_walls() == 0, "geen vijand staat in een muur")
	var dropless := true
	for enemy in m.foes:
		dropless = dropless and enemy.data["drops"].is_empty() and enemy.data["sight"] > 500.0
	check(dropless, "vijanden in de arena laten niets vallen en zien je altijd")
	check(Enemies.ENEMIES["slime"]["drops"].size() > 0 and Enemies.ENEMIES["slime"]["sight"] < 200.0, "de gewone gegevens van de slijm zijn niet veranderd")
	await frames(40)
	var active_now := true
	for enemy in m.foes:
		active_now = active_now and enemy.active
	check(active_now, "na een korte animatie kunnen ze vechten")

	var pickups_before := get_nodes_in_group("pickups").size()
	var first_foes: Array = m.foes.duplicate()
	crowd.ambient = 999.0 # geen losse juichers tussendoor: we willen alleen het gejuich om de verslagen vijanden zien
	for seat: Dictionary in crowd.seats:
		seat["jump"] = -1.0
	for i in first_foes.size() - 1:
		first_foes[i].hurt(9999, Vector2.RIGHT)
	await frames(30)
	check(m.phase == "fight" and m.round_index == 0, "alle vijanden op een na dood: de ronde gaat nog door")
	check(crowd.cheering() >= crowd.seats.size() * 0.1, "het publiek juicht bij een verslagen vijand (%d van de %d)" % [crowd.cheering(), crowd.seats.size()])
	var hp_before: int = gs.hp
	gs.hp = 3
	world.spawn_projectile("arrow", tile_center(20, 8), Vector2.RIGHT, 5.0, 1, "testpijl")
	check(projectile_count() == 1, "(er vliegt een pijl rond)")
	first_foes[first_foes.size() - 1].hurt(9999, Vector2.RIGHT)
	await frames(5)
	check(m.phase == "rest" and m.timer > 2.5 and m.timer <= 3.0, "alles dood: drie seconden rust")
	check(gs.hp == 4, "en een hartje van het publiek (%d -> %d)" % [3, gs.hp])
	check(get_nodes_in_group("pickups").size() == pickups_before, "er is niets op de grond gevallen")
	await frames(2)
	check(projectile_count() == 0, "pijlen die nog onderweg waren verdwijnen als de ronde voorbij is")
	gs.hp = hp_before
	await frames(150)
	check(m.phase == "rest", "de rust duurt drie seconden")
	await frames(60)
	check(m.phase == "fight" and m.round_index == 1, "daarna begint ronde 2")

	# Ronde 2 en 3
	check(await wait_for(func() -> bool: return round_ready(m)), "ronde 2: de vijanden verschijnen")
	check(kinds_of(m.foes) == round_kinds("bronze", 1), "ronde 2: precies de vijanden uit de data %s" % [kinds_of(m.foes)])
	await frames(40)
	check(exit_gate.blocked, "de uitgang blijft dicht")
	await kill_all_foes()
	await frames(5)
	check(m.phase == "rest", "ronde 2 gehaald")
	m.timer = 0.0
	await frames(3)
	check(await wait_for(func() -> bool: return round_ready(m)) and m.round_index == 2, "ronde 3 begint")
	check(kinds_of(m.foes) == round_kinds("bronze", 2), "ronde 3: precies de vijanden uit de data %s" % [kinds_of(m.foes)])
	check(foes_in_walls() == 0, "ook in ronde 3 staat niemand in een muur")
	await frames(40)
	var coins_before: int = gs.coins
	world.spawn_projectile("arrow", tile_center(20, 8), Vector2.RIGHT, 5.0, 1, "testpijl")
	await kill_all_foes()
	await frames(5)
	check(m.phase == "done" and not Arena.run_active, "na de laatste ronde is het toernooi voorbij")
	check(projectile_count() == 0, "een pijl die nog vloog verdwijnt: na de overwinning kan niets je meer raken")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH))
	check(saved is Dictionary and saved["map"] == "arena" and saved["flags"].has("arena_bronze_done") and saved["arena_records"].has("bronze")
		and int(saved["coins"]) == gs.coins and not saved["flags"].has("arena_signed_bronze"), "de overwinning is meteen opgeslagen (ook als je nu afsluit)")
	check(gs.flag("arena_bronze_done") and gs.coins == coins_before + 50, "beloning: 50 munten (%d)" % (gs.coins - coins_before))
	check(gs.count("arena_trophy_bronze") == 1 and gs.arena_records.has("bronze") and gs.arena_records["bronze"] > 0.0, "een bronzen trofee en een eerste record (%.1f s)" % gs.arena_records.get("bronze", 0.0))
	check(Arena.title() == "Arenastrijder" and Arena.unlocked("silver") and not Arena.unlocked("gold"), "titel Arenastrijder; Zilver is open, Goud nog niet")
	check(gs.flag("arena_fresh_bronze") and gs.flag("arena_first_bronze") and bruno_talk() == "arena_bruno_won_bronze", "Bruno reageert op de overwinning")
	await frames(60)
	check(not exit_gate.blocked and gs.check(["arena_free"]), "het veld gaat open: de uitgang is vrij")
	check(not gs.ended and not gs.transitioning and gs.ui_owners.is_empty(), "het spel staat niet vast")
	await walk_into(object_of("arena", "portal"))
	check(gs.map_id == "arena_hall", "door de uitgang loop je terug naar de hal")
	await talk("arena_bruno_won_bronze")
	check(not gs.flag("arena_fresh_bronze") and not gs.flag("arena_first_bronze") and bruno_talk() == "arena_bruno_menu", "Bruno feliciteert je een keer (daarna weer het gewone menu)")
	await stop_world()


func test_unlock_order_and_rewards() -> void:
	print("Rangen ontgrendelen in volgorde")
	await start_world("arena_hall")
	gs.coins = 1000
	check(Arena.unlocked("bronze") and not Arena.unlocked("silver") and not Arena.unlocked("gold"), "aan het begin alleen Brons")
	check(not Arena.register("gold"), "Goud overslaan kan niet")
	gs.set_flag("arena_bronze_done")
	check(Arena.unlocked("silver") and not Arena.unlocked("gold"), "na Brons: Zilver open, Goud nog niet")
	check(not Arena.register("gold") and Arena.register("silver") and gs.coins == 975, "Zilver kost 25 munten")
	Arena.cancel()
	gs.set_flag("arena_silver_done")
	check(Arena.unlocked("gold") and Arena.register("gold") and gs.coins == 950, "na Zilver: Goud (50 munten)")
	Arena.cancel()
	gs.new_game()
	gs.in_game = true

	print("Beloningen: de eerste keer en herhalen")
	gs.start_quest("arena_kampioen")
	gs.coins = 0
	var first: Dictionary = Arena.complete("bronze", 100.0)
	check(first["first_time"] and gs.coins == 50 and gs.count("arena_trophy_bronze") == 1 and gs.flag("arena_bronze_done"), "Brons de eerste keer: 50 munten en een trofee")
	check(gs.quest_step("arena_kampioen") == 1, "de opdracht Arenakampioen gaat door naar Zilver")
	var again: Dictionary = Arena.complete("bronze", 120.0)
	check(not again["first_time"] and gs.coins == 75 and gs.count("arena_trophy_bronze") == 1, "Brons herhalen: de helft (25 munten) en geen tweede trofee")
	check(is_equal_approx(gs.arena_records["bronze"], 100.0) and not again["record"], "een tragere tijd verandert het record niet")
	var faster: Dictionary = Arena.complete("bronze", 90.0)
	check(faster["record"] and is_equal_approx(gs.arena_records["bronze"], 90.0) and gs.coins == 100, "een snellere tijd is een nieuw record")
	gs.coins = 0
	Arena.complete("silver", 200.0)
	check(gs.coins == 150 and gs.count("arena_trophy_silver") == 1 and gs.quest_step("arena_kampioen") == 2, "Zilver: 150 munten, een zilveren trofee")
	gs.coins = 0
	check(gs.quest_state("arena_kampioen") == "active", "de opdracht is nog niet klaar")
	Arena.complete("gold", 400.0)
	check(gs.coins == 400 and gs.count("arena_trophy_gold") == 1 and gs.count("arena_helm") == 1, "Goud: 400 munten, een gouden trofee en de Arenahelm")
	check(gs.quest_state("arena_kampioen") == "done" and Arena.title() == "Arenakampioen", "de opdracht is klaar en je bent Arenakampioen")
	gs.coins = 0
	Arena.complete("gold", 380.0)
	check(gs.coins == 200 and gs.count("arena_helm") == 1 and gs.count("arena_trophy_gold") == 1, "Goud herhalen: 200 munten, de helm krijg je maar één keer")
	check(is_equal_approx(gs.arena_records["gold"], 380.0) and is_equal_approx(gs.arena_records["silver"], 200.0), "elke rang heeft zijn eigen record")
	await stop_world()


func test_gold_final() -> void:
	print("Goud: de laatste ronde met de kristalgolem")
	await start_world("arena_hall", "crystal")
	gs.set_flag("arena_met_bruno")
	gs.set_flag("arena_bronze_done")
	gs.set_flag("arena_silver_done")
	gs.coins = 100
	check(Arena.register("gold") and gs.coins == 50, "Goud kost 50 munten")
	await walk_into(object_of("arena_hall", "portal", "to", "arena"))
	var m := master()
	check(m != null and m.rank == "gold" and m.rounds.size() == 7, "een toernooi van 7 rondes")
	m.rng.seed = 3
	m.timer = 1000.0 # we slaan de eerste zes rondes over
	m._start_round(6)
	check(await wait_for(func() -> bool: return round_ready(m)), "de laatste ronde: er komt iemand uit de poort")
	check(kinds_of(m.foes) == {"golem": 1} and m.foes[0].is_in_group("boss"), "de kristalgolem")
	check(sound.current_track == "boss", "de baasmuziek begint")
	check(foes_in_walls() == 0 and not world.is_solid(m.foes[0].global_position), "ook de grote golem staat niet in een muur")
	await frames(40)
	check(m.foes[0].active and m.foes[0].data["drops"].is_empty(), "hij vecht, en laat niets vallen")
	var gold_before: int = gs.coins
	m.foes[0].hurt(9999, Vector2.RIGHT)
	await frames(5)
	check(m.phase == "done" and gs.flag("arena_gold_done") and gs.coins == gold_before + 400, "golem verslagen: Goud gehaald, 400 munten")
	check(gs.count("arena_helm") == 1 and gs.count("arena_trophy_gold") == 1, "de gouden trofee en de Arenahelm")
	check(sound.current_track == "arena", "de strijdmuziek komt terug")
	check(gs.quest_state("arena_kampioen") != "active", "de opdracht Arenakampioen is niet meer actief")
	await stop_world()

	print("Spawnpunten")
	await start_world("arena")
	var arena_master_node := master()
	var spawn_ok := true
	var spots := 0
	var kinds := {}
	for rank: String in Arena.ORDER:
		for round_list: Array in Arena.RANKS[rank]["rounds"]:
			for entry: Array in round_list:
				kinds[entry[0]] = true
	for kind: String in kinds:
		# de botsing van een vijand is een cirkel bij zijn voeten (zie enemy.gd): die moet helemaal op het zand staan
		var info: Dictionary = Enemies.info(kind)
		var feet := Vector2(0, float(info["cell"]) * float(info["scale"]) * 0.28)
		var radius: float = info["radius"]
		for gate_index in arena_master_node.gates.size():
			for i in 20:
				var spot: Vector2 = arena_master_node._spawn_point(gate_index, kind)
				spots += 1
				for angle in 12:
					if world.is_solid(spot + feet + Vector2.from_angle(float(angle) * TAU / 12.0) * radius):
						spawn_ok = false
				if world.is_solid(spot) or world.is_solid(spot + feet):
					spawn_ok = false
	check(spawn_ok and kinds.has("golem"), "%d spawnpunten (%d soorten, alle poorten): de vijand staat er met zijn hele botsing op het zand" % [spots, kinds.size()])
	# Hetzelfde met de natuurkunde: raakt de botsing van een golem (cirkel bij zijn voeten) een muur?
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	query.shape = circle
	query.collision_mask = 1
	var space := world.get_world_2d().direct_space_state
	var golem_feet := Vector2(0, 64.0 * 0.28)
	var touching := 0
	for gate_index in arena_master_node.gates.size():
		query.transform = Transform2D(0.0, arena_master_node._spawn_point(gate_index, "golem") + golem_feet)
		touching += space.intersect_shape(query).size()
	query.transform = Transform2D(0.0, tile_center(7, 15) + golem_feet)
	var naive: int = space.intersect_shape(query).size()
	check(touching == 0 and naive > 0, "een golem raakt bij geen enkele poort de muur (midden op de tegel voor de onderste poort zou dat wel doen)")
	await stop_world()


# --- Verliezen en opgeven ----------------------------------------------------------------------------------

func test_defeat() -> void:
	print("Verliezen: geen game over")
	await enter_arena("bronze", 50)
	var m := master()
	m.timer = 0.0
	check(await wait_for(func() -> bool: return round_ready(m)), "de eerste ronde is begonnen")
	await frames(40)
	check(gs.defeat_handler.is_valid(), "de arena heeft het verlies overgenomen")
	var coins_before: int = gs.coins
	gs.hp = 1
	world.player.invuln = 0.0
	world.player.hurt(world.player.global_position + Vector2(10, 0), 3, "Slijm")
	check(gs.hp == 0 and not gs.ended and m.phase == "defeat", "op 0 hartjes: Verslagen! (en geen game over)")
	await frames(2)
	check(not world.hud.overlay.visible and gs.transitioning, "geen game-over-scherm, de invoer staat even vast")
	check(get_nodes_in_group("enemies").is_empty(), "alle vijanden zijn weg")
	await frames(10)
	gs.hurt(1)
	check(not gs.ended and m.phase == "defeat", "nog een klap tijdens het wachten verandert niets")
	check(await wait_for(func() -> bool: return gs.map_id == "arena_hall" and not gs.transitioning, 400), "na een korte pauze sta je in de hal")
	await frames(40)
	check(gs.hp == gs.max_hp(), "met volle gezondheid (%d)" % gs.hp)
	check(not gs.ended and not gs.transitioning and gs.ui_owners.is_empty() and not gs.dialogue_open, "geen toestand blijft hangen: niet afgelopen, geen overgang, geen scherm open")
	check(world.player.invuln == 0.0 and world.player.knockback == Vector2.ZERO and not paused, "de speler is gewoon speelbaar (geen onkwetsbaarheid, spel loopt)")
	check(not Arena.run_active and not gs.defeat_handler.is_valid() and Arena.registered_rank() == "", "de poorten, de handler en de inschrijving zijn opgeruimd")
	check(gs.coins == coins_before and gs.flag("arena_just_lost") and not gs.flag("arena_bronze_done"), "het inschrijfgeld is kwijt, er is niets gewonnen")
	check(bruno_talk() == "arena_bruno_lost", "Bruno reageert op de nederlaag")
	check(gs.has_save(), "de hal is automatisch opgeslagen")
	await talk("arena_bruno_lost")
	check(not gs.flag("arena_just_lost") and bruno_talk() == "arena_bruno_menu", "na zijn troostende woorden is alles weer normaal")
	await walk_into(object_of("arena_hall", "portal", "to", "arena"))
	check(gs.map_id == "arena_hall", "zonder nieuwe inschrijving blijft de arenadeur dicht")
	# Daarna werkt een echte game over gewoon nog.
	world.player.invuln = 0.0
	gs.hurt(gs.max_hp())
	await frames(3)
	check(gs.ended and world.hud.overlay.visible, "buiten een toernooi is 0 hartjes nog steeds game over")
	await stop_world()
	gs.new_game()

	print("Verliezen na de overwinning en in andere gebieden")
	await start_world("village")
	world.player.invuln = 0.0
	gs.hurt(gs.max_hp())
	check(gs.ended, "in het dorp is 0 hartjes game over")
	await stop_world()

	print("Opgeven bij de gong")
	await enter_arena("bronze", 50)
	m = master()
	m.timer = 0.0
	check(await wait_for(func() -> bool: return round_ready(m)), "ronde 1 is bezig")
	var gong: Node = null
	for node in get_nodes_in_group("interactable"):
		if node.has_method("interact") and node.get_script().resource_path.ends_with("arena_gong.gd"):
			gong = node
	check(gong != null, "de gong staat bij de uitgang")
	await put_player(gong.global_position + Vector2(0, -30))
	check(world.player.target == gong, "je kunt de gong aanspreken")
	gong.interact()
	await frames(3)
	var clock: float = m.run_time
	await frames(10)
	check(world.dialogue.active and m.phase == "fight" and paused and m.run_time == clock, "de gong vraagt of je wilt opgeven; het gevecht (en de klok) staat ondertussen stil")
	while world.dialogue.active and world.dialogue.buttons.is_empty():
		world.dialogue._advance()
		await frames(2)
	world.dialogue.buttons[1].pressed.emit()
	await frames(3)
	check(not world.dialogue.active and m.phase == "fight" and Arena.run_active, "'Nee, ik vecht door!': er verandert niets")
	gong.interact()
	await frames(3)
	while world.dialogue.active and world.dialogue.buttons.is_empty():
		world.dialogue._advance()
		await frames(2)
	world.dialogue.buttons[0].pressed.emit()
	await frames(3)
	check(m.phase == "defeat" and not gs.ended, "'Ja, ik geef op': het gevecht stopt")
	check(await wait_for(func() -> bool: return gs.map_id == "arena_hall" and not gs.transitioning, 400), "je staat weer in de hal")
	await frames(40)
	check(gs.hp == gs.max_hp() and gs.flag("arena_just_quit") and not Arena.run_active and bruno_talk() == "arena_bruno_quit", "volledig beter, Bruno weet dat je hebt opgegeven")
	check(not gs.transitioning and gs.ui_owners.is_empty() and world.player.invuln == 0.0 and not gs.defeat_handler.is_valid(), "ook na opgeven blijft er niets hangen")
	await stop_world()

	print("De gong buiten een toernooi")
	await start_world("arena")
	check(master().phase == "idle" and not Arena.run_active, "zonder inschrijving is de arena gewoon open (geen toernooi)")
	var idle_gate: Node = null
	for node in get_nodes_in_group("interactable"):
		if node.get_script().resource_path.ends_with("arena_gong.gd"):
			idle_gate = node
	idle_gate.interact()
	await frames(3)
	check(world.dialogue.active and not Arena.run_active, "de gong galmt alleen (geen opgeefvraag)")
	while world.dialogue.active:
		world.dialogue._advance()
		await frames(2)
	await put_player(portal_rect(object_of("arena", "portal")).get_center())
	await frames(90)
	check(gs.map_id == "arena_hall", "en je kunt gewoon naar buiten lopen")
	await stop_world()


# --- Als het misgaat tussendoor -------------------------------------------------------------------------------

func test_interrupted() -> void:
	print("Opgeven nog voor de eerste gong")
	await enter_arena("bronze", 50)
	var m := master()
	check(m.phase == "intro" and Arena.registered_rank() == "bronze", "in de introductie sta je nog ingeschreven")
	m.forfeit()
	check(await wait_for(func() -> bool: return gs.map_id == "arena_hall" and not gs.transitioning, 400), "opgeven bij de gong: je staat in de hal")
	check(Arena.registered_rank() == "" and gs.coins == 40 and bruno_talk() == "arena_bruno_quit", "je inschrijving is weg, zoals de gong en Bruno zeggen")
	await walk_into(object_of("arena_hall", "portal", "to", "arena"))
	check(gs.map_id == "arena_hall", "de arenadeur gaat niet meer open")
	await stop_world()

	print("Opgeven in de rust, en niet opgeven als het voorbij is")
	await enter_arena("bronze", 50)
	m = master()
	m.timer = 0.0
	check(await wait_for(func() -> bool: return round_ready(m)), "ronde 1 loopt")
	await kill_all_foes()
	await frames(5)
	check(m.phase == "rest", "rust tussen de rondes")
	m.forfeit()
	check(m.phase == "defeat", "ook in de rust kun je opgeven")
	check(await wait_for(func() -> bool: return gs.map_id == "arena_hall" and not gs.transitioning, 400), "en dan sta je in de hal")
	await frames(40)
	check(gs.flag("arena_just_quit") and not Arena.run_active and gs.hp == gs.max_hp(), "netjes opgeruimd")
	await stop_world()

	await enter_arena("bronze", 50)
	m = master()
	m.timer = 0.0
	for i in 3:
		check(await wait_for(func() -> bool: return round_ready(m)), "ronde %d" % (i + 1))
		await kill_all_foes()
		await frames(5)
		m.timer = 0.0
		await frames(3)
	check(m.phase == "done", "alle rondes gehaald")
	m.forfeit()
	await frames(5)
	check(m.phase == "done" and gs.map_id == "arena" and not gs.transitioning, "na de overwinning doet opgeven niets meer")
	await stop_world()

	print("Het spel stopt midden in een toernooi")
	await enter_arena("bronze", 50)
	m = master()
	m.timer = 0.0
	check(await wait_for(func() -> bool: return round_ready(m)), "ronde 1 loopt")
	check(Arena.run_active and gs.defeat_handler.is_valid(), "er loopt een toernooi")
	await stop_world()
	check(not Arena.run_active and not gs.defeat_handler.is_valid(), "als de wereld verdwijnt (bijvoorbeeld naar het titelscherm) is er niets blijven hangen")
	gs.new_game()
	await start_world("village")
	world.player.invuln = 0.0
	gs.hurt(gs.max_hp())
	check(gs.ended, "en een nieuw spel heeft gewoon game over")
	await stop_world()

	print("Afsluiten vlak na het binnenkomen: de inschrijving gaat niet verloren")
	await enter_arena("bronze", 50)
	check(gs.has_save(), "bij het binnenkomen is er opgeslagen")
	gs.new_game()
	check(gs.load_game() and gs.map_id == "arena" and Arena.registered_rank() == "bronze", "wie hier doorgaat vanaf de opslag staat nog ingeschreven")
	await stop_world()
	await start_world("arena")
	gs.set_flag("arena_signed_bronze")
	world.load_map("arena", "from_hall")
	await frames(3)
	check(master().phase == "intro" and master().rank == "bronze", "en begint gewoon weer aan het toernooi")
	check(Arena.run_active and gs.defeat_handler.is_valid() and get_nodes_in_group("arena_master").size() == 1, "de oude arenameester is weg en zet het nieuwe toernooi niet stop")
	await stop_world()


# --- Publiek en hartjes -----------------------------------------------------------------------------------

func test_crowd_hearts() -> void:
	print("Publiek: een hartje bij laag leven")
	await enter_arena("bronze", 50)
	var m := master()
	m.timer = 0.0
	check(await wait_for(func() -> bool: return round_ready(m)), "ronde 1 loopt")
	await frames(30)
	var hearts_before := 0
	for pickup in get_nodes_in_group("pickups"):
		if pickup.item == "heart":
			hearts_before += 1
	gs.hp = 3
	await frames(3)
	check(not m.heart_thrown, "bij 3 hartjes gooit het publiek nog niets")
	gs.hp = 2
	await frames(3)
	check(m.heart_thrown and m.flying_hearts.size() == 1, "bij 2 hartjes gooit het publiek een hartje")
	var heart: Node2D = m.flying_hearts[0]["heart"]
	check(not world.is_solid(m.flying_hearts[0]["land"]) and field_contains(m, m.flying_hearts[0]["land"]), "het hartje landt op het zand")
	await frames(70)
	check(m.flying_hearts.is_empty() and is_instance_valid(heart) and not world.is_solid(heart.global_position), "het hartje is geland")
	gs.hp = 1
	await frames(5)
	var hearts_now := 0
	for pickup in get_nodes_in_group("pickups"):
		if pickup.item == "heart":
			hearts_now += 1
	check(hearts_now == hearts_before + 1 and m.flying_hearts.is_empty(), "per ronde maar een hartje, ook als het nog slechter gaat")
	await put_player(heart.global_position)
	await frames(10)
	check(gs.hp == 2, "als je het hartje pakt krijg je er een bij (%d)" % gs.hp)
	await kill_all_foes()
	await frames(5)
	m.timer = 0.0
	await frames(3)
	check(await wait_for(func() -> bool: return round_ready(m)) and not m.heart_thrown, "in de volgende ronde kan het publiek weer iets gooien")
	await stop_world()


func field_contains(m: Node, pos: Vector2) -> bool:
	return m.field.has_point(pos)


# --- Opslaan en laden -----------------------------------------------------------------------------------------

func test_save_load() -> void:
	print("Opslaan en laden")
	gs.new_game()
	gs.in_game = true
	gs.coins = 0
	gs.start_quest("arena_kampioen")
	Arena.complete("bronze", 95.5)
	Arena.complete("silver", 230.25)
	check(gs.save_game(Vector2(100, 100)), "opslaan")
	gs.new_game()
	check(gs.arena_records.is_empty() and gs.count("arena_trophy_bronze") == 0, "een nieuw spel begint zonder records en trofeeën")
	check(gs.load_game(), "laden")
	check(gs.count("arena_trophy_bronze") == 1 and gs.count("arena_trophy_silver") == 1 and gs.count("arena_trophy_gold") == 0, "de trofeeën zijn er nog")
	check(is_equal_approx(gs.arena_records["bronze"], 95.5) and is_equal_approx(gs.arena_records["silver"], 230.25), "de records zijn er nog")
	check(gs.flag("arena_bronze_done") and gs.flag("arena_silver_done") and Arena.unlocked("gold") and Arena.title() == "Arenaridder", "rangen en titel zijn er nog")
	check(gs.quest_step("arena_kampioen") == 2, "de opdracht staat nog op de laatste stap")
	check(Arena.record_text("bronze") == "1:36" and Arena.record_text("gold") == "nog niet gehaald", "de records worden mooi weergegeven (%s)" % Arena.record_text("bronze"))

	print("Oude spelletjes zonder arena-gegevens")
	var old_save := {"version": 1, "map": "village", "pos": [96.0, 96.0], "hp": 4, "coins": 12, "inventory": {"potion": 2}, "flags": {"met_greta": true},
		"quests": {}, "weapon": "iron", "play_time": 50.0, "kills": 3}
	var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_save))
	file.close()
	check(gs.load_game() and gs.arena_records.is_empty() and gs.coins == 12 and gs.weapon == "iron", "een oude opslag zonder arena-veld laadt gewoon")
	check(not Arena.unlocked("silver") and Arena.title() == "nieuwkomer", "en begint als nieuwkomer")
	gs.new_game()


func test_boards() -> void:
	print("Scorebord en trofeeënplank")
	await start_world("arena_hall")
	var scores: Node = null
	var shelf: Node = null
	for node in get_nodes_in_group("interactable"):
		if "board" in node:
			if node.board == "scores":
				scores = node
			else:
				shelf = node
	check(scores != null and shelf != null, "het scorebord en de trofeeënplank hangen in de hal")
	var lines: Array = scores.scoreboard_lines()
	check(lines.size() == 4 and lines[1] == "Brons: nog niet gehaald", "het scorebord toont: nog niet gehaald %s" % [lines])
	gs.arena_records = {"bronze": 75.0, "gold": 301.0}
	lines = scores.scoreboard_lines()
	check(lines[1] == "Brons: 1:15" and lines[2] == "Zilver: nog niet gehaald" and lines[3] == "Goud: 5:01", "met records toont het scorebord de tijden %s" % [lines])
	check(shelf.shelf_lines().size() == 2 and "Nog niets" in shelf.shelf_lines()[1], "de lege plank zegt dat er nog niets op staat")
	gs.give("arena_trophy_bronze", 1, true)
	gs.give("arena_helm", 1, true)
	var shelf_text := " ".join(shelf.shelf_lines())
	check("Bronzen trofee" in shelf_text and "Arenahelm" in shelf_text and not "Gouden" in shelf_text, "met trofeeën staan ze op de plank (en alleen de gewonnen)")
	check("Er is nog plek" in shelf.shelf_lines()[shelf.shelf_lines().size() - 1], "met twee trofeeën is er nog plek op de plank")
	gs.give("arena_trophy_silver", 1, true)
	gs.give("arena_trophy_gold", 1, true)
	check("volle plank" in shelf.shelf_lines()[shelf.shelf_lines().size() - 1], "met alles erop is de plank vol")
	await put_player(shelf.global_position + Vector2(0, 28))
	check(world.player.target == shelf, "je kunt de plank bekijken")
	shelf.interact()
	await frames(3)
	check(world.dialogue.active, "en het scorebord leest voor")
	while world.dialogue.active:
		world.dialogue._advance()
		await frames(2)
	await stop_world()


func _run() -> void:
	gs = root.get_node("GameState")
	sound = root.get_node("Sound")
	Arena = load("res://scripts/data/arena.gd")
	seed(20240607)
	test_data()
	test_maps()
	await test_entrance()
	await test_registration()
	await test_bronze_run()
	await test_unlock_order_and_rewards()
	await test_gold_final()
	await test_defeat()
	await test_interrupted()
	await test_crowd_hearts()
	test_save_load()
	await test_boards()

	print("")
	if failures == 0:
		print("ARENA TEST OK")
		quit(0)
	else:
		print("ARENA TEST: %d fout(en)" % failures)
		quit(1)
