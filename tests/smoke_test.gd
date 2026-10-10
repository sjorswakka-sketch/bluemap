extends SceneTree
## Headless speltest. Draaien met:
##   godot --headless --path . -s tests/smoke_test.gd
## Exitcode 0 = alles goed, 1 = er ging iets mis.
##
## Deel 1 controleert alle gegevens (kaarten, gesprekken, opdrachten, voorwerpen) op samenhang.
## Deel 2 speelt het spel na: lopen, vechten, praten, kopen, opslaan, bazen.

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Items := preload("res://scripts/data/items.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const Npcs := preload("res://scripts/data/npcs.gd")
const Dialogue := preload("res://scripts/data/dialogue.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Shops := preload("res://scripts/data/shops.gd")
const Art := preload("res://scripts/core/art.gd")

const COND_NAMES := ["flag", "no_flag", "quest", "step", "has", "lacks", "coins", "map", "weapon", "crystals", "hurt"]
const ACTION_NAMES := [
	"start_quest", "quest_step", "finish_quest", "set_flag", "clear_flag", "give", "take", "coins", "heal", "weapon",
	"toast", "sound", "shop", "save", "ending", "sell_all", "talk", "boss_start", "music", "lock_arena",
]
const OBJECT_TYPES := ["npc", "enemy", "pickup", "chest", "sign", "portal", "gate", "savepoint", "torch", "trigger"]

var failures := 0
var gs: Node
var world: Node2D


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures += 1


func press(action: String) -> void:
	# Gebruik de echte input-pipeline, net als een speler.
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	root.push_input(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	root.push_input(up)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


# --- Deel 1: gegevens -----------------------------------------------------------------------------

func valid_conds(conds: Array, where: String) -> bool:
	for cond: Array in conds:
		if not (cond[0] in COND_NAMES):
			print("       onbekende voorwaarde in ", where, ": ", cond)
			return false
		if cond[0] in ["quest", "step"] and not Quests.QUESTS.has(cond[1]):
			print("       onbekende opdracht in ", where, ": ", cond)
			return false
		if cond[0] in ["has", "lacks"] and not Items.ITEMS.has(cond[1]):
			print("       onbekend voorwerp in ", where, ": ", cond)
			return false
		if cond[0] == "weapon" and not Items.WEAPONS.has(cond[1]):
			print("       onbekend zwaard in ", where, ": ", cond)
			return false
	return true


func valid_actions(actions: Array, where: String) -> bool:
	for action: Array in actions:
		if not (action[0] in ACTION_NAMES):
			print("       onbekende actie in ", where, ": ", action)
			return false
		match action[0]:
			"give", "take", "sell_all":
				if not Items.ITEMS.has(action[1]):
					print("       onbekend voorwerp in ", where, ": ", action)
					return false
			"start_quest", "quest_step", "finish_quest":
				if not Quests.QUESTS.has(action[1]):
					print("       onbekende opdracht in ", where, ": ", action)
					return false
			"weapon":
				if not Items.WEAPONS.has(action[1]):
					print("       onbekend zwaard in ", where, ": ", action)
					return false
			"shop":
				if not Shops.SHOPS.has(action[1]):
					print("       onbekende winkel in ", where, ": ", action)
					return false
			"talk":
				if not Dialogue.TALKS.has(action[1]):
					print("       onbekend gesprek in ", where, ": ", action)
					return false
	return true


func test_data() -> void:
	print("Tegels en plaatjes")
	var tiles_tex := Art.tex("tiles")
	check(tiles_tex.get_width() == Tiles.NAMES.size() * 16, "tiles.png heeft %d tegels (%d)" % [Tiles.NAMES.size(), tiles_tex.get_width() / 16])
	var tiles_ok := true
	for ch: String in Tiles.CHARS:
		if not (Tiles.CHARS[ch] in Tiles.NAMES):
			tiles_ok = false
	for solid_name: String in Tiles.SOLID:
		if not (solid_name in Tiles.NAMES):
			tiles_ok = false
	check(tiles_ok, "alle tekens en muren verwijzen naar bestaande tegels")
	var items_tex := Art.tex("items")
	var max_icon := 0
	for item_id: String in Items.ITEMS:
		max_icon = maxi(max_icon, int(Items.ITEMS[item_id]["icon"]))
	check(items_tex.get_width() >= (max_icon + 1) * 16, "items.png heeft genoeg iconen")
	var sheets_ok := true
	for kind: String in Enemies.ENEMIES:
		var tex := Art.tex(Enemies.ENEMIES[kind]["sheet"])
		var cell: int = Enemies.ENEMIES[kind]["cell"]
		if tex.get_width() < cell or tex.get_height() < cell:
			sheets_ok = false
			print("       sheet te klein voor ", kind)
	check(sheets_ok, "alle vijanden hebben een plaatje")
	var npc_ok := true
	for npc_id: String in Npcs.NPCS:
		if Art.tex(Npcs.NPCS[npc_id]["sheet"]).get_width() < 32:
			npc_ok = false
	check(npc_ok, "alle personages hebben een plaatje")

	print("Gesprekken en opdrachten")
	var referenced := {}
	var talks_ok := true
	for npc_id: String in Npcs.NPCS:
		for rule: Dictionary in Npcs.NPCS[npc_id]["rules"]:
			referenced[rule["talk"]] = true
			if not Dialogue.TALKS.has(rule["talk"]):
				print("       ", npc_id, " verwijst naar onbekend gesprek ", rule["talk"])
				talks_ok = false
			if rule.has("if") and not valid_conds(rule["if"], npc_id):
				talks_ok = false
	for talk_id: String in Dialogue.TALKS:
		var node: Dictionary = Dialogue.TALKS[talk_id]
		var targets: Array = []
		if node.has("next"):
			targets.append(node["next"])
		for option: Dictionary in node.get("branch", []):
			targets.append(option["next"])
			if option.has("if") and not valid_conds(option["if"], talk_id):
				talks_ok = false
		for choice: Dictionary in node.get("choices", []):
			if choice.has("next"):
				targets.append(choice["next"])
			if choice.has("if") and not valid_conds(choice["if"], talk_id):
				talks_ok = false
			if choice.has("do") and not valid_actions(choice["do"], talk_id):
				talks_ok = false
		if node.has("do") and not valid_actions(node["do"], talk_id):
			talks_ok = false
		for target: String in targets:
			referenced[target] = true
			if not Dialogue.TALKS.has(target):
				print("       ", talk_id, " verwijst naar onbekende knoop ", target)
				talks_ok = false
		for action_list: Array in [node.get("do", [])] + node.get("choices", []).map(func(c): return c.get("do", [])):
			for action: Array in action_list:
				if action[0] == "talk":
					referenced[action[1]] = true
		if node.get("lines", []).is_empty() and not node.has("branch"):
			print("       ", talk_id, " heeft geen regels")
			talks_ok = false
	check(talks_ok, "alle gesprekken en voorwaarden kloppen")
	var unused: Array = []
	for talk_id: String in Dialogue.TALKS:
		if not referenced.has(talk_id) and talk_id != "king_intro":
			unused.append(talk_id)
	check(unused.is_empty(), "elk gesprek wordt ergens gebruikt %s" % [unused])
	var quests_ok := true
	for quest_id: String in Quests.QUESTS:
		for step: Dictionary in Quests.QUESTS[quest_id]["steps"]:
			if step.has("advance_if") and not valid_conds(step["advance_if"], quest_id):
				quests_ok = false
	check(quests_ok, "opdrachten hebben geldige voorwaarden")

	print("Kaarten")
	var found_items := {}
	var found_flags := {}
	var maps_ok := true
	for map_id: String in Maps.MAPS:
		var def: Dictionary = Maps.get_map(map_id)
		var rows: Array = def["rows"]
		for row: String in rows:
			if row.length() != rows[0].length():
				print("       ", map_id, ": ongelijke rijen")
				maps_ok = false
				break
		if not def["spawns"].has("start"):
			print("       ", map_id, ": geen start")
			maps_ok = false
		for obj: Dictionary in def["objects"]:
			if not (obj["type"] in OBJECT_TYPES):
				print("       ", map_id, ": onbekend object ", obj["type"])
				maps_ok = false
			for cond_key in ["if", "exists_if", "requires", "block_if", "conditions"]:
				if obj.has(cond_key) and not valid_conds(obj[cond_key], map_id):
					maps_ok = false
			match obj["type"]:
				"npc":
					if not Npcs.NPCS.has(obj["id"]):
						print("       ", map_id, ": onbekend personage ", obj["id"])
						maps_ok = false
				"enemy":
					if not Enemies.ENEMIES.has(obj["kind"]):
						print("       ", map_id, ": onbekende vijand ", obj["kind"])
						maps_ok = false
					if obj.has("flag"):
						found_flags[obj["flag"]] = true
				"pickup":
					if not Items.ITEMS.has(obj["item"]) and obj["item"] != "heart":
						print("       ", map_id, ": onbekend voorwerp ", obj["item"])
						maps_ok = false
					found_items[obj["item"]] = true
				"chest":
					for entry: Array in obj["contents"]:
						if entry[0] != "coins" and not Items.ITEMS.has(entry[0]):
							print("       ", map_id, ": onbekend voorwerp in kist ", entry[0])
							maps_ok = false
						found_items[entry[0]] = true
				"portal":
					if not Maps.MAPS.has(obj["to"]) or not Maps.get_map(obj["to"])["spawns"].has(obj.get("spawn", "start")):
						print("       ", map_id, ": portaal naar onbekende plek ", obj["to"], "/", obj.get("spawn", "start"))
						maps_ok = false
				"trigger":
					if not valid_actions(obj["do"], map_id):
						maps_ok = false
	check(maps_ok, "alle kaarten en hun voorwerpen kloppen")
	var completable := true
	for needed: String in ["crystal_bos", "crystal_ruine", "crystal_grot", "ruin_key", "medallion", "heart_container", "shard", "potion"]:
		if not found_items.has(needed) and needed != "shard":
			print("       nergens te vinden: ", needed)
			completable = false
	check(completable, "alle belangrijke voorwerpen liggen ergens op de kaart")
	check(found_flags.has("golem_ruins") and found_flags.has("golem_cave") and found_flags.has("boss_defeated"), "bazen hebben een vlag")


# --- Hulpfuncties voor deel 2 ---------------------------------------------------------------------

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


func tile_pos(x: int, y: int) -> Vector2:
	return Vector2(x * 32 + 16, y * 32 + 16)


func teleport(x: int, y: int) -> void:
	world.player.global_position = tile_pos(x, y)
	world.player.velocity = Vector2.ZERO
	await frames(2)


func run_dialogue(talk_id: String, picks: Array = []) -> void:
	gs.start_dialogue(talk_id)
	await frames(2)
	var pick_index := 0
	var guard := 0
	while world.dialogue.active and guard < 300:
		guard += 1
		if not world.dialogue.buttons.is_empty():
			var choice: int = picks[pick_index] if pick_index < picks.size() else world.dialogue.buttons.size() - 1
			pick_index += 1
			world.dialogue.buttons[mini(choice, world.dialogue.buttons.size() - 1)].pressed.emit()
		else:
			press("interact")
		await frames(2)


## Welk gesprek een personage nu zou voeren (dezelfde regels als in npc.gd).
func pick_talk(npc_id: String) -> String:
	for rule: Dictionary in Npcs.NPCS[npc_id]["rules"]:
		if not rule.has("if") or gs.check_all(rule["if"]):
			return rule["talk"]
	return ""


func count_children_with_script(file_name: String) -> int:
	var total := 0
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with(file_name):
			total += 1
	return total


func spawn(kind: String, tx: int, ty: int, flag := "") -> Node2D:
	return world.spawn_enemy(kind, tile_pos(tx, ty), flag)


func clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with("projectile.gd"):
			child.queue_free()
	await frames(2)


# --- Deel 2: het spel spelen ---------------------------------------------------------------------

func test_world() -> void:
	print("Wereld en kaarten")
	check(world.player != null, "speler bestaat")
	check(gs.map_id == "village", "we beginnen in het dorp")
	check(get_nodes_in_group("npc").size() >= 5, "er zijn personages in het dorp")
	check(world.is_solid(tile_pos(0, 0)), "de rand van de kaart is solide")
	check(not world.is_solid(tile_pos(19, 9)), "de startplek is vrij")
	for action in ["move_left", "move_right", "move_up", "move_down", "attack", "dodge", "interact", "potion", "menu", "quests", "map", "pause", "mute", "restart"]:
		check(InputMap.has_action(action), "input-actie " + action)

	var start: Vector2 = world.player.global_position
	Input.action_press("move_left")
	await frames(60)
	Input.action_release("move_left")
	check(world.player.global_position.x < start.x - 20.0, "speler kan lopen")
	await teleport(1, 1)
	Input.action_press("move_up")
	Input.action_press("move_left")
	await frames(40)
	Input.action_release("move_up")
	Input.action_release("move_left")
	check(world.player.global_position.x > 32.0 and world.player.global_position.y > 32.0, "speler loopt niet door de rand")

	print("Door de wereld reizen")
	for map_id in ["smithy", "shop", "inn", "forest", "ruins", "cave", "temple", "village"]:
		world.load_map(map_id, "start")
		await frames(10)
		check(gs.map_id == map_id and world.map_size.x > 5, "kaart %s laadt (%d objecten)" % [map_id, world.entities.get_child_count()])
	await teleport(19, 9)
	var village_portal := Rect2()
	for obj: Dictionary in Maps.get_map("village")["objects"]:
		if obj["type"] == "portal" and obj["to"] == "smithy":
			village_portal = Rect2(Vector2(obj["pos"][0], obj["pos"][1]) * 32.0, Vector2(32, 32))
	world.player.global_position = village_portal.get_center() + Vector2(0, 40)
	await frames(3)
	world.player.global_position = village_portal.get_center()
	await frames(80)
	check(gs.map_id == "smithy", "door een deur lopen brengt je naar binnen")
	check(not gs.transitioning, "de overgang is klaar")
	await frames(10)
	world.player.global_position = Vector2(7 * 32 + 16, 9 * 32 + 16)
	await frames(80)
	check(gs.map_id == "village", "en weer naar buiten")
	check(gs.has_save(), "er is automatisch opgeslagen bij het wisselen van kaart")


func test_combat() -> void:
	print("Vechten")
	await teleport(19, 13)
	await clear_enemies()
	var player = world.player
	var slime := spawn("slime", 21, 13)
	slime.set_physics_process(false)
	player.facing = Vector2.RIGHT
	player.global_position = slime.global_position + Vector2(-26, 0)
	var coins_before := get_nodes_in_group("pickups").size()
	press("attack")
	await frames(2)
	check(slime.hp == 2, "houten zwaard doet 1 schade")
	for i in 2:
		player.cooldown = 0.0
		press("attack")
		await frames(2)
	await frames(2)
	check(not is_instance_valid(slime) or slime.dead, "slijm verslagen na 3 klappen")
	check(get_nodes_in_group("pickups").size() > coins_before, "slijm laat iets vallen")

	print("Ontwijkrol")
	player.invuln = 0.0
	player.roll_cooldown = 0.0
	var hp_now: int = gs.hp
	Input.action_press("move_right")
	press("dodge")
	await frames(3)
	Input.action_release("move_right")
	check(player.is_rolling(), "Shift laat je rollen")
	player.hurt(player.global_position + Vector2(10, 0))
	check(gs.hp == hp_now, "tijdens de rol kan niets je raken")
	await frames(50)
	check(not player.is_rolling(), "de rol is afgelopen")
	player.hurt(player.global_position + Vector2(10, 0))
	check(gs.hp == hp_now - 1, "daarna kun je weer geraakt worden")
	player.invuln = 0.0
	player.hurt(player.global_position + Vector2(10, 0))
	check(gs.hp == hp_now - 2, "verder niet onkwetsbaar")

	print("Drankje")
	gs.give("potion", 2, true)
	var hp_low: int = gs.hp
	press("potion")
	await frames(2)
	check(gs.hp == mini(hp_low + 3, gs.max_hp()) and gs.count("potion") == 1, "H drinkt een helddrank (+3 hartjes)")
	gs.full_heal()
	press("potion")
	await frames(2)
	check(gs.count("potion") == 1, "geen drankje verspild bij volle gezondheid")

	print("Vijanden")
	gs.full_heal()
	await clear_enemies()
	await teleport(19, 13)
	# Skelet: schiet pijlen
	var skeleton := spawn("skeleton", 24, 13)
	player.invuln = 999.0
	var arrows := 0
	for i in 600:
		await process_frame
		arrows = maxi(arrows, count_children_with_script("projectile.gd"))
		if arrows > 0:
			break
	check(arrows > 0, "skelet schiet een pijl")
	check(skeleton.global_position.distance_to(player.global_position) > 60.0, "skelet houdt afstand")
	await clear_enemies()
	# Vleermuis: duikt aan
	var bat := spawn("bat", 23, 13)
	var dashed := false
	for i in 400:
		await process_frame
		if bat.state == "dash":
			dashed = true
			break
	check(dashed, "vleermuis duikt op je af")
	await clear_enemies()
	# Golem: slaat neer en doet schade
	player.invuln = 0.0
	gs.full_heal()
	await teleport(19, 13)
	var golem := spawn("golem", 20, 13, "")
	golem.global_position = player.global_position + Vector2(40, 0)
	var hp_before: int = gs.hp
	var slammed := false
	for i in 300:
		await process_frame
		if gs.hp < hp_before:
			slammed = true
			break
		player.global_position = golem.global_position + Vector2(-40, 0)
	check(slammed, "golem raakt je met zijn klap")
	check(golem.max_hp == 22 and golem.data.get("boss", false), "golem is een minibaas")
	await clear_enemies()
	player.invuln = 999.0

	print("De Slijmkoning")
	gs.full_heal()
	var king := spawn("king", 19, 10, "boss_defeated")
	check(not king.active, "de baas wacht tot hij wordt gestart")
	king.hurt(5, Vector2.RIGHT)
	check(king.hp == king.max_hp, "inactieve baas is onraakbaar")
	king.activate()
	await frames(260)
	check(king.hop_count >= 1, "de baas springt (%d keer)" % king.hop_count)
	king.hp = int(king.max_hp * 0.5)
	check(king._king_phase() == 2, "fase 2 onder 65%")
	var balls := 0
	for i in 600:
		await process_frame
		balls = maxi(balls, count_children_with_script("projectile.gd"))
		if balls > 0:
			break
	check(balls > 0, "in fase 2 schiet hij slijmballen")
	king.hp = int(king.max_hp * 0.2)
	check(king._king_phase() == 3, "fase 3 onder 30%")
	var ending_signals := [0]
	gs.ending_requested.disconnect(world._on_ending)
	gs.ending_requested.connect(func() -> void: ending_signals[0] += 1)
	for i in 600:
		await process_frame
		if king.state != "hop":
			break
	king.hurt(999, Vector2.RIGHT)
	await frames(150)
	check(gs.flag("boss_defeated"), "baas verslagen: de vlag is gezet")
	check(ending_signals[0] == 1, "het einde wordt gestart nadat de baas is verslagen")
	player.invuln = 0.0


func test_items_and_quests() -> void:
	print("Opslaan en laden")
	gs.new_game()
	gs.in_game = true
	world.load_map("forest", "start")
	await frames(5)
	gs.coins = 77
	gs.give("potion", 3, true)
	gs.give("heart_container", 1, true)
	gs.set_flag("test_flag")
	gs.weapon = "iron"
	gs.start_quest("kat")
	gs.hp = 4
	gs.save_game(world.player.global_position + Vector2(64, 0))
	var saved_pos: Vector2 = world.player.global_position + Vector2(64, 0)
	gs.new_game()
	check(gs.coins == 0 and gs.count("potion") == 0, "nieuw spel begint leeg")
	check(gs.load_game(), "opslag wordt gevonden")
	check(gs.coins == 77 and gs.count("potion") == 3, "munten en voorwerpen terug")
	check(gs.flag("test_flag") and gs.weapon == "iron" and gs.map_id == "forest", "vlaggen, zwaard en plek terug")
	check(gs.quest_state("kat") == "active" and gs.hp == 4 and gs.max_hp() == 6, "opdrachten, hartjes en hartcontainer terug")
	check(gs.use_load_pos and gs.load_pos.distance_to(saved_pos) < 1.0, "de opgeslagen positie is bewaard")
	gs.use_load_pos = false

	print("Voorwerpen en opdrachten")
	gs.new_game()
	await frames(2)
	gs.give("crystal_bos", 1, true)
	gs.give("crystal_ruine", 1, true)
	gs.start_quest("main")
	check(gs.quest_step("main") == 0, "hoofdopdracht begint bij stap 0")
	gs.give("crystal_grot", 1, true)
	check(gs.quest_step("main") == 1, "met 3 kristallen gaat de opdracht vanzelf verder")
	check(gs.tracked_text().begins_with("Breng"), "de opdrachttekst in beeld verandert mee: " + gs.tracked_text())
	gs.new_game()
	gs.start_quest("kat")
	gs.set_flag("cat_found")
	check(gs.quest_step("kat") == 1, "vlag zorgt voor volgende stap")
	check(gs.check_all([["quest", "kat", "active"], ["step", "kat", 1], ["no_flag", "nope"]]), "voorwaarden werken")
	gs.new_game()
	gs.give("potion", 1, true)
	gs.hp = 2
	check(gs.use_potion() and gs.hp == 5, "drankje geneest")


func test_dialogues() -> void:
	print("Gesprekken")
	gs.new_game()
	gs.in_game = true
	world.load_map("village", "start")
	await frames(5)
	var bram: Node2D = null
	for npc in get_nodes_in_group("npc"):
		if npc.npc_id == "bram":
			bram = npc
	check(bram != null, "Bram staat in het dorp")
	world.player.global_position = bram.global_position + Vector2(0, 30)
	await frames(3)
	check(world.player.target == bram, "Bram is dichtbij genoeg om mee te praten")
	press("interact")
	await frames(3)
	check(world.dialogue.active and gs.dialogue_open and paused, "E start een gesprek en zet het spel stil")
	while world.dialogue.active and world.dialogue.buttons.is_empty():
		press("interact")
		await frames(2)
	check(not world.dialogue.buttons.is_empty(), "er verschijnen keuzes")
	world.dialogue.buttons[0].pressed.emit()
	await frames(2)
	var guard := 0
	while world.dialogue.active and guard < 60:
		guard += 1
		press("interact")
		await frames(2)
	check(not paused and not gs.dialogue_open, "na het gesprek loopt het spel weer")
	check(gs.quest_state("main") == "active" and gs.count("potion") == 1, "Bram geeft de opdracht en een drankje")

	gs.give("crystal_bos", 1, true)
	gs.give("crystal_ruine", 1, true)
	gs.give("crystal_grot", 1, true)
	await run_dialogue("bram_crystals")
	check(gs.crystal_count() == 0 and gs.flag("gate_temple") and gs.quest_step("main") == 2, "Bram neemt de kristallen en opent de tempel")

	# Greta: een beter zwaard
	gs.coins = 40
	gs.give("gel", 5, true)
	await run_dialogue("greta_menu", [0, 0])
	check(gs.weapon == "iron" and gs.count("gel") == 0 and gs.coins == 0, "Greta smeedt een ijzeren zwaard")
	check(gs.damage() == 2, "het zwaard doet nu 2 schade")
	gs.coins = 80
	gs.give("gel", 8, true)
	gs.give("shard", 2, true)
	await run_dialogue("greta_menu", [0, 0])
	check(gs.weapon == "crystal" and gs.damage() == 3, "en daarna een kristalzwaard")
	gs.new_game()
	gs.coins = 5
	await run_dialogue("greta_menu", [0])
	check(gs.weapon == "wood" and gs.coins == 5, "zonder genoeg spullen verandert er niets")

	# Tobias: gel verkopen en kopen
	gs.new_game()
	gs.give("gel", 4, true)
	await run_dialogue("tobias_menu", [1, 0])
	check(gs.coins == 12 and gs.count("gel") == 0, "Tobias koopt slijmgel (4 x 3 munten)")
	gs.coins = 20
	gs.run(["shop", "tobias"])
	await frames(3)
	check(world.shop_ui.active and paused, "de winkel opent")
	world.shop_ui._buy(world.shop_ui.shop["items"][0], 0)
	check(gs.count("potion") == 1 and gs.coins == 5, "helddrank gekocht voor 15 munten")
	world.shop_ui._buy(world.shop_ui.shop["items"][1], 1)
	check(gs.count("boots") == 0 and gs.coins == 5, "laarzen zijn te duur")
	gs.coins = 100
	world.shop_ui._buy(world.shop_ui.shop["items"][1], 1)
	check(gs.count("boots") == 1 and gs.speed_multiplier() > 1.0, "laarzen gekocht: sneller")
	press("pause")
	await frames(3)
	check(not world.shop_ui.active and not paused, "Esc sluit de winkel")

	# Pim en de kat
	gs.new_game()
	await run_dialogue("pim_intro", [0])
	check(gs.quest_state("kat") == "active", "Pim geeft de opdracht")
	await run_dialogue("muis_bos")
	check(gs.flag("cat_found") and gs.quest_step("kat") == 1, "Muis gevonden")
	await run_dialogue("pim_cat_back")
	check(gs.quest_state("kat") == "done" and gs.count("heart_container") == 1 and gs.max_hp() == 6, "Pim geeft een hartcontainer")

	# Mila
	gs.new_game()
	await run_dialogue("mila_menu", [1, 0])
	check(gs.quest_state("drank") == "active", "Mila geeft een opdracht")
	gs.give("gel", 5, true)
	check(gs.quest_step("drank") == 1, "met 5 gel gaat het verder")
	await run_dialogue("mila_potion_done")
	check(gs.quest_state("drank") == "done" and gs.count("potion") == 3 and gs.coins == 25, "Mila betaalt met drankjes en munten")
	gs.hp = 1
	gs.save_game(world.player.global_position)
	await run_dialogue("mila_menu", [0])
	check(gs.hp == gs.max_hp(), "uitrusten bij Mila geneest")

	# Wilfred
	gs.new_game()
	await run_dialogue("wilfred_intro", [0])
	gs.give("medallion", 1, true)
	check(gs.quest_step("medaillon") == 1, "medaillon gevonden")
	await run_dialogue("wilfred_return")
	check(gs.quest_state("medaillon") == "done" and gs.count("shard") == 2, "Wilfred beloont met kristalscherven")

	# Na het einde reageren de dorpelingen anders
	gs.new_game()
	gs.set_flag("met_greta")
	gs.start_quest("main")
	gs.finish_quest("main")
	check(pick_talk("anja") == "anja_done" and pick_talk("joost") == "joost_done" and pick_talk("hein") == "hein_done", "dorpelingen reageren op het einde")
	check(pick_talk("greta") == "greta_done", "Greta feliciteert je een keer")
	await run_dialogue("greta_done", [1])
	check(pick_talk("greta") == "greta_menu" and gs.flag("heard_greta_done"), "daarna werkt de smid weer gewoon")
	gs.new_game()
	check(pick_talk("bram") == "bram_intro" and pick_talk("greta") == "greta_intro", "vóór het einde krijg je de gewone gesprekken")

	print("Poorten, kisten en altaren")
	gs.new_game()
	world.load_map("forest", "start")
	await frames(5)
	var gate: Node2D = null
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with("gate.gd"):
			gate = child
	check(gate != null and gate.blocked, "de ruïnepoort is dicht")
	world.player.global_position = gate.global_position + Vector2(0, 30)
	await frames(3)
	check(world.player.target == gate, "je kunt de poort aanspreken")
	gate.interact()
	check(gs.flag("gate_ruin") == false, "zonder sleutel gaat hij niet open")
	gs.give("ruin_key", 1, true)
	gate.interact()
	await frames(3)
	check(gs.flag("gate_ruin") and not gate.blocked and gs.count("ruin_key") == 0, "met de sleutel gaat de poort open")
	var chest: Node2D = null
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with("chest.gd") and child.contents[0][0] == "ruin_key":
			chest = child
	check(chest != null, "de sleutelkist bestaat")
	chest.interact()
	check(gs.count("ruin_key") == 1 and chest.opened, "kist geeft de sleutel")
	var keys: int = gs.count("ruin_key")
	chest.interact()
	check(gs.count("ruin_key") == keys, "een kist geef je maar één keer iets")
	var altar: Node2D = null
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with("savepoint.gd"):
			altar = child
	gs.hp = 1
	altar.interact()
	check(gs.hp == gs.max_hp() and gs.has_save(), "altaar geneest en slaat op")


func test_menus() -> void:
	print("Menu's en pauze")
	gs.new_game()
	world.load_map("village", "start")
	await frames(5)
	check(not paused, "spel loopt")
	press("pause")
	await frames(3)
	check(paused and world.pause_menu.open, "Esc pauzeert")
	var frozen: Vector2 = world.player.global_position
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	check(world.player.global_position == frozen, "speler staat stil tijdens pauze")
	press("pause")
	await frames(3)
	check(not paused, "nogmaals Esc hervat")

	press("menu")
	await frames(3)
	check(world.menu_ui.active and paused, "I opent het menu")
	press("ui_right")
	await frames(2)
	check(world.menu_ui.tab == 1, "pijl rechts: volgende tabblad")
	press("quests")
	await frames(2)
	check(not world.menu_ui.active, "Q op het opdrachtentabblad sluit het menu")
	press("map")
	await frames(3)
	check(world.menu_ui.active and world.menu_ui.tab == 2, "N opent de kaart")
	press("pause")
	await frames(3)
	check(not world.menu_ui.active and not paused, "Esc sluit het menu (en opent geen pauzemenu)")

	var sound := root.get_node("Sound")
	var was_muted: bool = sound.muted
	press("mute")
	await frames(2)
	check(sound.muted != was_muted, "M zet het geluid uit/aan")
	press("mute")
	await frames(2)
	check(sound.muted == was_muted, "M terug")
	check(sound.streams.size() >= 20, "alle geluidseffecten geladen (%d)" % sound.streams.size())
	check(sound.tracks.size() == 7, "alle muziekstukken geladen (%d)" % sound.tracks.size())

	print("Game over")
	gs.hurt(gs.max_hp())
	await frames(3)
	check(gs.ended and world.hud.overlay.visible, "game over bij 0 hartjes")
	world.player.invuln = 0.0
	gs.save_game(tile_pos(19, 9))
	press("restart")
	await frames(6)
	check(not is_instance_valid(world) and current_scene != null and not gs.ended, "R herstart vanaf de laatste opslag")


func test_title() -> void:
	print("Titelscherm")
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await frames(3)
	check(title.start_button != null and title.continue_button != null and title.quit_button != null, "titelscherm heeft knoppen")
	check(not title.continue_button.disabled, "Doorgaan werkt als er een opslag is")
	check(title.continue_button.has_focus(), "Doorgaan is geselecteerd (toetsenbord werkt)")
	title.start_game()
	await frames(5)
	check(current_scene != null and current_scene.scene_file_path.ends_with("intro.tscn"), "Nieuw spel begint met de intro")
	current_scene.queue_free()
	await frames(3)
	var title2: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title2)
	current_scene = title2
	await frames(3)
	title = title2
	title.continue_game()
	await frames(5)
	check(current_scene != null and current_scene.scene_file_path.ends_with("main.tscn"), "Doorgaan start het spel")
	check(gs.map_id != "" and gs.use_load_pos == false, "de opslag is geladen")
	var menu_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	check(menu_scene.ends_with("title.tscn"), "het spel start op het titelscherm")
	await frames(3)


func test_story_scenes() -> void:
	print("Intro en einde")
	var intro: Control = load("res://scenes/intro.tscn").instantiate()
	root.add_child(intro)
	current_scene = intro
	await frames(3)
	var guard := 0
	while is_instance_valid(intro) and not intro.done and guard < 60:
		guard += 1
		press("interact")
		await frames(3)
	check(not is_instance_valid(intro) or intro.done, "de intro is door te klikken")
	await frames(5)
	check(current_scene != null and current_scene.scene_file_path.ends_with("main.tscn"), "na de intro begint het spel")
	await stop_world_and_scene()

	gs.new_game()
	gs.kills = 50
	gs.play_time = 1234.0
	gs.start_quest("main")
	var ending: Control = load("res://scenes/ending.tscn").instantiate()
	root.add_child(ending)
	current_scene = ending
	await frames(3)
	var seen := {}
	guard = 0
	while ending.page < ending.pages.size() - 1 and guard < 80:
		guard += 1
		seen[ending.pages[ending.page]["type"]] = true
		if ending.pages[ending.page]["type"] == "credits":
			ending.credits_scroll = 100000.0
			await frames(3)
		elif ending.pages[ending.page]["type"] == "map":
			await frames(400)
			press("interact")
			await frames(3)
		else:
			press("interact")
			await frames(2)
			press("interact")
			await frames(2)
	check(seen.has("text") and seen.has("map") and seen.has("stats") and seen.has("credits"), "einde: tekst, kaart, statistieken en aftiteling")
	check(ending.lit[0] and ending.lit[1] and ending.lit[2], "de drie kristallen lichten op")
	check(ending.pages[ending.page]["type"] == "end", "einde bereikt de slotpagina")
	press("interact")
	await frames(6)
	check(current_scene != null and current_scene.scene_file_path.ends_with("title.tscn"), "daarna terug naar het titelscherm")


func stop_world_and_scene() -> void:
	if current_scene and current_scene != root:
		current_scene.queue_free()
	await frames(3)


func _run() -> void:
	gs = root.get_node("GameState")
	test_data()
	await start_world()
	await test_world()
	await test_combat()
	await test_items_and_quests()
	await test_dialogues()
	await test_menus()
	await test_title()
	await test_story_scenes()

	print("")
	if failures == 0:
		print("SMOKE TEST OK")
		quit(0)
	else:
		print("SMOKE TEST: %d fout(en)" % failures)
		quit(1)
