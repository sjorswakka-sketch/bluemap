extends SceneTree
## Test van de Dauwbos-alchemie (spoor "dauwklauw"): de nieuwe grondstof in het Dauwbos, het
## mistedrank en de dauwsoep, de opdracht Bloemen in de mist bij Mira en de prestatie Mistvanger.
##
##   sh tools/run_tests.sh /pad/naar/godot      (alle tests), of alleen deze:
##   XDG_DATA_HOME=.testdata godot --headless --fixed-fps 60 --path . -s tests/dauwbos_alchemie_test.gd
##
## Zonder XDG_DATA_HOME schrijft de test in de echte opslagmap van het spel (en overschrijft hij je opgeslagen spel).

const Items := preload("res://scripts/data/items.gd")
const Npcs := preload("res://scripts/data/npcs.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Achievements := preload("res://scripts/data/achievements.gd")
const Art := preload("res://scripts/core/art.gd")
const Beroepen := preload("res://scripts/data/ext/beroepen.gd")
const Polijst := preload("res://scripts/data/ext/polijst.gd")
const Professions := preload("res://scripts/core/professions.gd")

const DAUW_ITEMS := ["prof_dauwklauw", "prof_mistdrank", "prof_dauwsoep"]
## De volgorde van RESOURCES is de frame-index in resources_beroepen.png (zie resource_node.gd).
const DAUWKLAUW_FRAME := 15

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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	gs = root.get_node("GameState")
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await frames(3)

	test_data()
	await test_world()
	await test_quest()

	world.queue_free()
	await frames(2)
	print("DAUWBOS-ALCHEMIE OK" if failures == 0 else "DAUWBOS-ALCHEMIE FAILED: %d" % failures)
	quit(1 if failures else 0)


# --- Deel 1: gegevens -----------------------------------------------------------------------------------

func test_data() -> void:
	print("Gegevens van de Dauwbos-alchemie")

	# De voorwerpen staan in de lijst, met een icoon dat in de sheet past.
	for item: String in DAUW_ITEMS:
		check(Items.ITEMS.has(item), "voorwerp geregistreerd: " + item)
	var icons_tex := Art.tex("items_beroepen")
	check(icons_tex.get_width() == 46 * 16, "items_beroepen.png heeft 46 iconen")
	for item: String in DAUW_ITEMS:
		var def: Dictionary = Items.ITEMS[item]
		check(def.get("sheet") == "items_beroepen" and int(def["icon"]) * 16 < icons_tex.get_width(), "icoon van %s valt in de sheet" % item)

	# De grondstof staat als laatste in RESOURCES, passend bij het laatste frame van de sheet.
	check(Beroepen.RESOURCES.has("dauwklauw"), "grondstof dauwklauw geregistreerd")
	check(Beroepen.RESOURCES.keys().find("dauwklauw") == DAUWKLAUW_FRAME, "dauwklauw is frame %d van de grondstofsheet" % DAUWKLAUW_FRAME)
	check(Art.tex("resources_beroepen").get_width() == (DAUWKLAUW_FRAME + 1) * 16, "resources_beroepen.png heeft %d frames" % (DAUWKLAUW_FRAME + 1))
	var plekken: Array = Beroepen.RESOURCE_PLACEMENTS.get("dauwbos", []).filter(
		func(p: Array) -> bool: return p[1] == "dauwklauw")
	check(plekken.size() == 3, "drie dauwklauwplekken in het Dauwbos (%d)" % plekken.size())

	# De recepten verwijzen naar bestaande voorwerpen.
	for recipe: String in ["mist_drank", "dauw_soep"]:
		check(Beroepen.RECIPES.has(recipe), "recept geregistreerd: " + recipe)
		var def: Dictionary = Beroepen.RECIPES[recipe]
		check(Items.ITEMS.has(def["output"]), "uitkomst van %s bestaat" % recipe)
		var inputs_ok := true
		for input: String in def["inputs"]:
			inputs_ok = inputs_ok and Items.ITEMS.has(input)
		check(inputs_ok, "ingrediënten van %s bestaan" % recipe)
	check(Beroepen.RECIPES["mist_drank"]["skill"] == "alchemy" and Beroepen.RECIPES["mist_drank"]["station"] == "library", "mistedrank brouw je met alchemie in de bibliotheek")
	check(Beroepen.RECIPES["dauw_soep"]["skill"] == "cooking" and Beroepen.RECIPES["dauw_soep"]["station"] == "inn", "dauwsoep kook je in de herberg")

	# Opdracht, gesprekken en prestatie.
	check(Quests.QUESTS.has("mistbloemen"), "opdracht Bloemen in de mist aangemeld")
	check(Quests.QUESTS["mistbloemen"]["steps"][0].get("advance_if") == [["has", "prof_dauwklauw", 3]], "de opdracht gaat verder bij drie dauwklauwen")
	for talk_id: String in ["mira_mist_intro", "mira_mist_vraag", "mira_mist_ok", "mira_mist_menu", "mira_mist_klaar"]:
		check(Polijst.TALKS.has(talk_id), "gesprek geregistreerd: " + talk_id)
	check(Achievements.ACHIEVEMENTS.has("mist_gebrouwen"), "prestatie Mistvanger aangemeld")


# --- Deel 2: de wereld zelf -----------------------------------------------------------------------------

func test_world() -> void:
	print("De dauwklauw in de wereld")
	gs.new_game()
	gs.in_game = true
	world.load_map("dauwbos", "start")
	await frames(5)
	world.player.invuln = 999.0

	var nodes := get_nodes_in_group("profession_resources").filter(func(n: Node) -> bool: return str(n.resource_id).begins_with("dauwbos:"))
	check(nodes.size() == 12, "twaalf grondstofnodes in het Dauwbos (%d)" % nodes.size())
	var klauw_node: Node = null
	for node: Node in nodes:
		if node.kind == "dauwklauw":
			klauw_node = node
	check(klauw_node != null, "er is een dauwklauwnode")
	if klauw_node != null:
		await put_player(klauw_node.global_position + Vector2(0, 24))
		klauw_node.interact()
		klauw_node.advance_harvest(Professions.gather_duration(klauw_node.kind))
		check(gs.count("prof_dauwklauw") == 2, "plukken geeft twee dauwklauwen")
		check(Professions.remaining(klauw_node.resource_id) > 100, "de dauwklauwnode herstelt later")
		gs.take("prof_dauwklauw", 2)


# --- Deel 3: de opdracht bij Mira ------------------------------------------------------------------------

func test_quest() -> void:
	print("De opdracht Bloemen in de mist")
	gs.new_game()
	gs.in_game = true
	world.load_map("dauwbos", "start")
	await frames(5)
	world.player.invuln = 999.0

	# Mira vraagt pas om dauwklauwen als haar eerste opdracht (De dauw) klaar is.
	check(pick_talk("mira") != "mira_mist_intro", "Mira vraagt nog niet om dauwklauwen vóór De dauw")
	gs.start_quest("dauw")
	gs.finish_quest("dauw")
	await frames(2)
	await talk_npc("mira", [0]) # "Ik pluk ze wel."
	check(gs.quest_state("mistbloemen") == "active", "Mira geeft de opdracht Bloemen in de mist")
	check(gs.flag("mira_mist_gevraagd"), "Mira onthoudt dat ze het gevraagd heeft")

	gs.give("prof_dauwklauw", 3, true)
	await frames(2)
	check(gs.quest_step("mistbloemen") == 1, "drie dauwklauwen zetten de opdracht op de volgende stap")
	var coins_before: int = gs.coins
	await talk_npc("mira")
	check(gs.quest_state("mistbloemen") == "done", "Mira rondt de opdracht af")
	check(gs.count("prof_dauwklauw") == 0 and gs.count("prof_mistdrank") == 1, "dauwklauwen ingeruild voor een mistedrank")
	# Het afronden kan ook een heldenlevel opleveren (15 munten per level), vandaar minimaal +30.
	check(gs.coins >= coins_before + 30, "Mira betaalt dertig munten")
	check(gs.check_all(Achievements.ACHIEVEMENTS["mist_gebrouwen"]["if"]), "de prestatie Mistvanger kan vrijspelen")
