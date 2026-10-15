extends SceneTree
## Test voor de uitbreiding "boog": winkel, schieten, pijlen tegen vijanden, muren, water en bazen, doelwitten en
## poortjes, de schietbaan-opdracht, de pijlenteller, een volle pijlenkoker, opslaan en de plaatsing op de kaarten.
##
##   godot --headless --fixed-fps 60 --path . -s tests/boog_test.gd

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Items := preload("res://scripts/data/items.gd")
const Shops := preload("res://scripts/data/shops.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const Npcs := preload("res://scripts/data/npcs.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Art := preload("res://scripts/core/art.gd")
const Content := preload("res://scripts/data/content.gd")
const BoogModule := preload("res://scripts/data/ext/boog.gd")

const TILE := 32
const FULL_QUIVER_TEXT := "Je pijlenkoker is vol"

# De scripts van de objecten gebruiken GameState en Sound: pas laden als het spel draait (een preload hier kan dat nog niet).
var ArrowScript: Script
var PickupScript: Script

var failures := 0
var gs: Node
var world: Node2D
var toasts: Array[String] = []


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures += 1


func press(action: String) -> void:
	# De echte input-pijplijn, net als een speler.
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


# --- Hulpfuncties ---------------------------------------------------------------------------------------

func tile_pos(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)


func start_world(map_id := "village") -> void:
	gs.new_game()
	gs.in_game = true
	gs.map_id = map_id
	toasts.clear()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)
	world.player.invuln = 999.0


func stop_world() -> void:
	if is_instance_valid(world):
		world.queue_free()
	await frames(3)
	gs.new_game()


func goto_map(map_id: String) -> void:
	world.load_map(map_id, "start")
	await frames(5)
	await clear_enemies()


func teleport(x: int, y: int) -> void:
	world.player.global_position = tile_pos(x, y)
	world.player.velocity = Vector2.ZERO
	await frames(2)


func toast_count(prefix: String) -> int:
	var total := 0
	for text in toasts:
		if text.begins_with(prefix):
			total += 1
	return total


func arrows() -> Array[Node]:
	var found: Array[Node] = []
	for child in world.entities.get_children():
		if child.get_script() == ArrowScript and not child.is_queued_for_deletion():
			found.append(child)
	return found


## Wacht tot alle pijlen weg zijn (geraakt, blijven steken en verdwenen, of neergevallen).
func wait_arrows(limit := 200) -> void:
	var waited := 0
	while not arrows().is_empty() and waited < limit:
		await process_frame
		waited += 1


## Zet de speler op een tegel, kijkend in een richting, en schiet een pijl. Wacht tot de pijl klaar is.
func shoot_from(x: int, y: int, direction: Vector2) -> void:
	await teleport(x, y)
	world.player.facing = direction.normalized()
	world.player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	await wait_arrows()


func spawn(kind: String, tx: int, ty: int) -> Node2D:
	var enemy: Node2D = world.spawn_enemy(kind, tile_pos(tx, ty))
	enemy.set_physics_process(false) # blijft staan waar hij staat
	return enemy


## De levens van een vijand, of -1 als hij er niet meer is (een verslagen vijand verdwijnt van het scherm).
func hp_of(enemy: Variant) -> int:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return -1
	return enemy.hp


## Haalt alleen de vijanden weg (de voorwerpen op de grond blijven liggen).
func free_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await frames(2)


func clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	for pickup in get_nodes_in_group("pickups"):
		pickup.queue_free()
	await frames(2)


func find_by_script(file_name: String) -> Array[Node]:
	var found: Array[Node] = []
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with(file_name) and not child.is_queued_for_deletion():
			found.append(child)
	return found


func target_at(x: int, y: int) -> Node:
	for target in get_nodes_in_group("boog_target"):
		if (target.global_position - tile_pos(x, y)).length() < 1.0:
			return target
	return null


func gate_with_id(gate_id: String) -> Node:
	for gate in find_by_script("gate.gd"):
		if gate.gate_id == gate_id:
			return gate
	return null


func pickup_at(x: int, y: int) -> Node:
	for pickup in get_nodes_in_group("pickups"):
		if not pickup.is_queued_for_deletion() and (pickup.global_position - tile_pos(x, y)).length() < 1.0:
			return pickup
	return null


func chest_at(x: int, y: int) -> Node:
	for chest in find_by_script("chest.gd"):
		if (chest.global_position - tile_pos(x, y)).length() < 1.0:
			return chest
	return null


func npc_by_id(npc_id: String) -> Node:
	for npc in get_nodes_in_group("npc"):
		if npc.npc_id == npc_id:
			return npc
	return null


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


# --- Gegevens ---------------------------------------------------------------------------------------------

func test_data() -> void:
	print("Gegevens van de boog")
	check(Content.MODULES.has(BoogModule), "de uitbreiding is aangemeld in content.gd")
	check(Items.ITEMS.has("bow") and Items.ITEMS.has("arrow"), "boog en pijl bestaan als voorwerpen")
	check(Items.sheet_of("bow") == "items_boog" and Items.sheet_of("arrow") == "items_boog", "ze hebben een eigen plaatje")
	check(Art.tex("items_boog").get_width() >= 48 and Art.tex("items_boog").get_height() == 16, "items_boog.png heeft de iconen (boog, pijl, vliegende pijl)")
	check(Art.tex("target").get_width() == 32 and Art.tex("target").get_height() == 16, "target.png heeft twee vakjes (gewoon en geraakt)")
	check(Art.tex("npc_tessa").get_width() == 32, "Tessa heeft een plaatje met twee vakjes")
	check(int(Items.info("arrow")["max"]) == 40, "je kunt maximaal 40 pijlen dragen")
	check(Items.icon_tex("bow").get_width() == 16 and Items.icon_tex("arrow").get_width() == 16, "iconen zijn los op te vragen voor de winkel")

	var controls: Node = root.get_node("Controls")
	var events: Array = controls.binding_events("bow", "keyboard") + controls.binding_events("bow", "controller")
	var keys: Array[int] = []
	var trigger := false
	for event in events:
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
		if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT:
			trigger = true
	check(InputMap.has_action("bow") and KEY_F in keys and KEY_L in keys, "de actie 'bow' hoort bij de toetsen F en L")
	check(trigger, "en bij de rechter trekker van een controller")

	var tobias: Array = Shops.info("tobias")["items"]
	var bow_entry: Dictionary = {}
	var arrow_entry: Dictionary = {}
	for entry: Dictionary in tobias:
		if entry["item"] == "bow":
			bow_entry = entry
		if entry["item"] == "arrow":
			arrow_entry = entry
	check(bow_entry.get("once", false) and int(bow_entry.get("price", 0)) == 80, "Tobias verkoopt de boog eenmalig voor 80 munten")
	check(bow_entry.get("with", []) == [["arrow", 5]], "met 5 pijlen erbij, zodat je meteen kunt schieten")
	check(int(arrow_entry.get("amount", 0)) == 5 and int(arrow_entry.get("price", 0)) == 10, "en pijlen in bundels van 5 voor 10 munten")
	check(tobias[0]["item"] == "potion" and tobias[1]["item"] == "boots", "de oude winkelregels staan nog op hun plek")
	var drops: Array = Enemies.info("skeleton")["drops"]
	var arrow_drop: Array = []
	for drop: Array in drops:
		if drop[0] == "arrow":
			arrow_drop = drop
	check(arrow_drop.size() == 3 and is_equal_approx(float(arrow_drop[1]), 0.3) and int(arrow_drop[2]) == 2, "skeletten laten met 30% kans 2 pijlen vallen")
	check(ArrowScript.ARMOR.has("golem") and Enemies.info("golem")["behavior"] == "golem", "de kristalgolem heeft een pantser tegen pijlen")

	var types := Content.object_types()
	check(types.has("boog_target") and types["boog_target"] is Script and types.has("boog_baan") and types["boog_baan"] is Script, "doelwit en schietbaan zijn objectsoorten")
	var sound := root.get_node("Sound")
	check(sound.streams.has("boog_twang") and sound.streams.has("boog_target") and sound.streams.has("boog_kets"), "de geluiden 'boog_twang', 'boog_target' en 'boog_kets' zijn geladen")
	check(Npcs.NPCS.has("tessa") and Quests.QUESTS.has("boog_schietbaan"), "Tessa en de opdracht Schietbaan bestaan")

	print("Eigen voorwaarde en acties")
	gs.new_game()
	check(gs.check(["boog_missing", "x_a", "x_b"]), "boog_missing: nog niets geraakt")
	gs.set_flag("x_a")
	check(gs.check(["boog_missing", "x_a", "x_b"]), "boog_missing: nog een doelwit te gaan")
	gs.set_flag("x_b")
	check(not gs.check(["boog_missing", "x_a", "x_b"]), "boog_missing: alles geraakt")
	check(not gs.check(["boog_missing"]), "boog_missing zonder vlaggen is nooit waar")
	toasts.clear()
	gs.run(["boog_progress", "x_a", "x_b"])
	check(toasts.has("Alle doelwitten geraakt!"), "boog_progress meldt dat alles geraakt is")
	gs.set_flag("x_b", false)
	gs.run(["boog_progress", "x_a", "x_b"])
	check(toasts.has("Doelwit geraakt! (1 van 2)"), "boog_progress telt de doelwitten")
	toasts.clear()
	gs.run(["boog_range_start"]) # zonder schietbaan op de kaart gebeurt er niets (en gaat er niets mis)
	check(toasts.is_empty() and gs.quest_state("boog_schietbaan") == "none" and not gs.flag("boog_range_won"), "boog_range_start zonder schietbaan doet niets")
	gs.new_game()


# --- Winkel -----------------------------------------------------------------------------------------------

func shop_texts() -> Array[String]:
	var texts: Array[String] = []
	for child in world.shop_ui.list.get_children():
		if child is Button and not child.is_queued_for_deletion():
			texts.append((child as Button).text)
	return texts


func shop_entry(item: String) -> Dictionary:
	for entry: Dictionary in world.shop_ui.shop["items"]:
		if entry["item"] == item:
			return entry
	return {}


func test_shop() -> void:
	print("Winkel van Tobias")
	gs.coins = 200
	gs.run(["shop", "tobias"])
	await frames(3)
	check(world.shop_ui.active, "de winkel opent")
	var texts := shop_texts()
	var has_bow_line := false
	var has_arrow_line := false
	for text in texts:
		has_bow_line = has_bow_line or text.begins_with("Boog")
		has_arrow_line = has_arrow_line or text.begins_with("5 pijlen")
	check(has_bow_line, "de boog staat in de winkel: %s" % [texts])
	check(not has_arrow_line, "pijlen zijn pas te koop als je een boog hebt")
	world.shop_ui._buy(shop_entry("arrow"), 3)
	check(gs.count("arrow") == 0 and gs.coins == 200, "en zonder boog verkoopt Tobias ze ook niet")

	world.shop_ui._buy(shop_entry("bow"), 2)
	await frames(3)
	check(gs.count("bow") == 1 and gs.coins == 120, "boog gekocht voor 80 munten")
	check(gs.count("arrow") == 5, "je krijgt er meteen 5 pijlen bij")
	check(toasts.has("Gekocht: Boog + 5 pijlen"), "er komt een melding bij het kopen")
	world.shop_ui._buy(shop_entry("bow"), 2)
	await frames(2)
	check(gs.count("bow") == 1 and gs.coins == 120 and gs.count("arrow") == 5, "de boog koop je maar een keer")
	var bow_button_disabled := false
	var arrow_line := ""
	for child in world.shop_ui.list.get_children():
		if child is Button and not child.is_queued_for_deletion():
			var button := child as Button
			if button.text.begins_with("Boog"):
				bow_button_disabled = button.disabled and button.text.contains("gekocht")
			if button.text.begins_with("5 pijlen"):
				arrow_line = button.text
	check(bow_button_disabled, "de knop van de boog is uitgeschakeld (gekocht)")
	check(arrow_line.begins_with("5 pijlen") and arrow_line.contains("10 munten"), "nu zijn er pijlen te koop: %s" % arrow_line)

	world.shop_ui._buy(shop_entry("arrow"), 3)
	check(gs.count("arrow") == 10 and gs.coins == 110, "een bundel geeft 5 pijlen voor 10 munten")
	world.shop_ui._buy(shop_entry("arrow"), 3)
	check(gs.count("arrow") == 15 and gs.coins == 100, "en nog een bundel: 15 pijlen")

	toasts.clear()
	gs.coins = 9
	world.shop_ui._buy(shop_entry("arrow"), 3)
	check(gs.count("arrow") == 15 and gs.coins == 9 and toasts.has("Je hebt niet genoeg munten."), "te weinig munten: er verandert niets")

	gs.coins = 100
	gs.inventory["arrow"] = 38
	toasts.clear()
	world.shop_ui._buy(shop_entry("arrow"), 3)
	check(gs.count("arrow") == 38 and gs.coins == 100, "een bundel die niet meer past wordt niet verkocht")
	check(toasts.has("Je pijlenkoker zit bijna vol (38 van de 40)"), "de melding zegt hoeveel je er al hebt: %s" % [toasts])
	gs.inventory["arrow"] = 35
	world.shop_ui._buy(shop_entry("arrow"), 3)
	check(gs.count("arrow") == 40 and gs.coins == 90, "een bundel die er precies in past kan wel")
	toasts.clear()
	world.shop_ui._buy(shop_entry("arrow"), 3)
	check(gs.count("arrow") == 40 and gs.coins == 90 and toasts.has(FULL_QUIVER_TEXT), "met een volle pijlenkoker koop je niets meer")

	press("pause")
	await frames(3)
	check(not world.shop_ui.active, "Esc sluit de winkel")
	check(gs.count("potion") == 0 and gs.count("boots") == 0, "de andere waren zijn onaangeroerd")
	gs.new_game()
	gs.coins = 20
	gs.run(["shop", "tobias"])
	await frames(3)
	world.shop_ui._buy(shop_entry("potion"), 0)
	check(gs.count("potion") == 1 and gs.coins == 5, "gewone waren (1 per keer) werken nog zoals vroeger")
	press("pause")
	await frames(3)


# --- Schieten ---------------------------------------------------------------------------------------------

func test_shooting() -> void:
	print("Schieten")
	await goto_map("village")
	var player = world.player
	await teleport(5, 14)
	player.facing = Vector2.RIGHT

	gs.inventory = {"arrow": 5}
	gs.items_changed.emit()
	player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	check(gs.count("arrow") == 5 and arrows().is_empty(), "zonder boog gebeurt er niets")

	gs.give("bow", 1, true)
	press("bow")
	await frames(2)
	check(gs.count("arrow") == 4 and arrows().size() == 1, "F schiet een pijl en kost een pijl")
	check(player.bow_anim > 0.0, "de speler heeft even de boog in de hand")
	var arrow: Node = arrows()[0]
	check(arrow.direction.is_equal_approx(Vector2.RIGHT) and arrow.global_position.x > player.global_position.x, "de pijl vliegt de kant op waar je kijkt")
	press("bow")
	await frames(2)
	check(gs.count("arrow") == 4 and arrows().size() == 1, "de boog moet even afkoelen (0,4 seconde)")
	await wait_arrows()
	player.bow_cooldown = 0.0
	player.facing = Vector2(1, 1).normalized()
	press("bow")
	await frames(2)
	check(gs.count("arrow") == 3 and arrows().size() == 1 and arrows()[0].direction.is_equal_approx(Vector2(1, 1).normalized()), "schuin lopen geeft een schuine pijl")
	await wait_arrows()

	# Afkoelen in seconden: na 0,4 seconde mag het weer.
	player.facing = Vector2.RIGHT
	player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	var shots_before: int = gs.count("arrow")
	await frames(20)
	press("bow")
	await frames(2)
	check(gs.count("arrow") == shots_before, "na 0,3 seconde nog niet")
	await frames(10)
	press("bow")
	await frames(2)
	check(gs.count("arrow") == shots_before - 1, "na 0,4 seconde wel")
	await wait_arrows()

	print("Zonder pijlen")
	gs.inventory = {"bow": 1}
	gs.items_changed.emit()
	toasts.clear()
	player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	check(gs.count("arrow") == 0 and arrows().is_empty() and toast_count("Geen pijlen!") == 1, "zonder pijlen: geen pijl en een melding 'Geen pijlen!'")
	for i in 5:
		await frames(30)
		press("bow")
	await frames(2)
	check(toast_count("Geen pijlen!") == 1, "de melding komt niet bij elke druk op F opnieuw")
	await frames(240)
	player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	check(toast_count("Geen pijlen!") == 2, "na een paar seconden wel weer")
	check(gs.count("arrow") == 0 and arrows().is_empty(), "er is nog steeds niets geschoten")

	print("Niet tijdens rollen, gesprekken of menu's")
	gs.inventory = {"bow": 1, "arrow": 6}
	player.bow_cooldown = 0.0
	player.roll_timer = 0.2
	press("bow")
	await frames(2)
	check(gs.count("arrow") == 6 and arrows().is_empty(), "tijdens het rollen schiet je niet")
	player.roll_timer = 0.0
	gs.set_ui("dialogue", true)
	press("bow")
	await frames(2)
	gs.set_ui("dialogue", false)
	check(gs.count("arrow") == 6 and arrows().is_empty(), "tijdens een gesprek of menu schiet je niet")
	gs.transitioning = true
	press("bow")
	await frames(2)
	gs.transitioning = false
	check(gs.count("arrow") == 6 and arrows().is_empty(), "ook niet tijdens het wisselen van gebied")
	player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	check(gs.count("arrow") == 5, "daarna gewoon weer wel")
	await wait_arrows()

	print("Een controller-trekker telt een keer per haal")
	gs.inventory = {"bow": 1, "arrow": 10}
	player.bow_cooldown = 0.0
	var pull := InputEventJoypadMotion.new()
	pull.axis = JOY_AXIS_TRIGGER_RIGHT
	pull.axis_value = 1.0
	root.push_input(pull)
	await frames(1)
	check(gs.count("arrow") == 9, "de trekker schiet een pijl")
	player.bow_cooldown = 0.0
	var wiggle := InputEventJoypadMotion.new()
	wiggle.axis = JOY_AXIS_TRIGGER_RIGHT
	wiggle.axis_value = 0.8
	root.push_input(wiggle) # nog steeds ingedrukt, alleen een beetje losser
	await frames(1)
	check(gs.count("arrow") == 9, "een trekker die ingedrukt blijft schiet niet nog eens")
	var release := InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_TRIGGER_RIGHT
	release.axis_value = 0.0
	root.push_input(release)
	await frames(1)
	root.push_input(pull)
	await frames(1)
	check(gs.count("arrow") == 8, "los laten en opnieuw intrekken schiet weer")
	await wait_arrows()
	# Losgelaten terwijl een menu open is (de speler hoort dat niet): de volgende haal moet toch schieten.
	player.bow_cooldown = 0.0
	gs.set_ui("menu", true)
	await frames(2)
	check(player.trigger_down, "de trekker is nog ingedrukt als het menu opengaat")
	root.push_input(release)
	await frames(2)
	gs.set_ui("menu", false)
	await frames(2)
	root.push_input(pull)
	await frames(1)
	check(gs.count("arrow") == 7, "na het menu schiet de eerste nieuwe haal meteen (geen verloren schot)")
	await wait_arrows()

	print("Echt lopen en dan schieten")
	await teleport(8, 14)
	gs.inventory = {"bow": 1, "arrow": 5}
	Input.action_press("move_up")
	Input.action_press("move_right")
	await frames(4)
	player.bow_cooldown = 0.0
	press("bow")
	await frames(1)
	check(not arrows().is_empty() and arrows()[0].direction.is_equal_approx(Vector2(1, -1).normalized()), "omhoog en naar rechts lopen geeft een schuine pijl")
	Input.action_release("move_up")
	Input.action_release("move_right")
	await wait_arrows()
	await teleport(8, 14)
	Input.action_press("move_left")
	await frames(4)
	Input.action_release("move_left")
	await frames(3)
	player.bow_cooldown = 0.0
	press("bow")
	await frames(1)
	check(not arrows().is_empty() and arrows()[0].direction.is_equal_approx(Vector2.LEFT), "na naar links lopen schiet je naar links, ook als je stilstaat")
	await wait_arrows()


func test_arrow_hits() -> void:
	print("Pijlen tegen vijanden")
	await goto_map("village")
	var player = world.player
	gs.inventory = {"bow": 1, "arrow": 30}

	var slime := spawn("slime", 10, 14)
	await shoot_from(5, 14, Vector2.RIGHT)
	check(hp_of(slime) == 1, "een pijl in een rechte lijn doet 2 schade aan een slijm (3 -> 1)")
	check(gs.count("arrow") == 29, "en kost een pijl")
	await shoot_from(5, 14, Vector2.RIGHT)
	check(not is_instance_valid(slime) or slime.dead, "de tweede pijl verslaat het slijm")
	check(gs.kills >= 1, "dat telt als verslagen")
	await clear_enemies()

	var beside := spawn("slime", 10, 16)
	await shoot_from(5, 14, Vector2.RIGHT)
	check(hp_of(beside) == 3, "een slijm naast de lijn wordt niet geraakt")
	await clear_enemies()

	var first := spawn("slime", 8, 14)
	var second := spawn("slime", 11, 14)
	await shoot_from(5, 14, Vector2.RIGHT)
	check(hp_of(first) == 1 and hp_of(second) == 3, "de pijl raakt alleen de eerste vijand op zijn pad")
	await clear_enemies()

	var left := spawn("slime", 1 + 3, 14)
	await shoot_from(9, 14, Vector2.LEFT)
	check(hp_of(left) == 1, "ook naar links, en omhoog en omlaag, raakt hij")
	await clear_enemies()
	# Test beide richtingen in de vrije strook naast de grotere dorpsfontein.
	# Kolom 20 valt nu in de sokkel; dat zou terecht een pijl tegenhouden.
	var vertical_lane := 18
	var clear_lane := true
	for y in range(10, 18):
		clear_lane = clear_lane and not world.is_solid(tile_pos(vertical_lane, y))
	check(clear_lane, "de verticale schietproef heeft een vrije baan naast de fontein")
	var above := spawn("slime", vertical_lane, 10)
	await shoot_from(vertical_lane, 14, Vector2.UP)
	var below := spawn("slime", vertical_lane, 17)
	await shoot_from(vertical_lane, 14, Vector2.DOWN)
	check(hp_of(above) == 1 and hp_of(below) == 1, "naar boven en naar beneden")
	await clear_enemies()
	## The home compost now occupies the former southwest shooting lane.
	var diagonal := spawn("slime", 29, 36)
	await shoot_from(26, 33, Vector2(1, 1))
	check(hp_of(diagonal) == 1, "schuin raakt hij ook")
	await clear_enemies()

	print("Bereik")
	var near := spawn("slime", 5 + 8, 14)
	await shoot_from(5, 14, Vector2.RIGHT)
	check(hp_of(near) == 1, "op 8 tegels afstand raakt hij nog")
	await clear_enemies()
	var far := spawn("slime", 5 + 11, 14)
	await shoot_from(5, 14, Vector2.RIGHT)
	check(hp_of(far) == 3, "op 11 tegels afstand komt hij niet meer aan")
	check(arrows().is_empty(), "een pijl valt aan het eind van zijn bereik neer en verdwijnt")
	await clear_enemies()

	print("Muren")
	check(world.is_solid(tile_pos(12, 2)), "op de kaart staat een boom op (12, 2)")
	var behind_wall := spawn("slime", 13, 2)
	await teleport(10, 2)
	player.facing = Vector2.RIGHT
	player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	var stuck := false
	var arrow_node: Node = arrows()[0] if not arrows().is_empty() else null
	for i in 60:
		await process_frame
		if arrow_node and is_instance_valid(arrow_node) and arrow_node.state == "stuck":
			stuck = true
			break
	check(stuck, "een pijl blijft in de boom steken")
	check(arrow_node != null and is_instance_valid(arrow_node) and arrow_node.global_position.x < 12 * TILE + 8.0, "en hij vliegt er niet doorheen")
	await wait_arrows()
	check(hp_of(behind_wall) == 3, "een slijm achter de muur wordt niet geraakt")
	check(arrows().is_empty(), "een pijl in de muur verdwijnt na een tijdje")
	await clear_enemies()
	var open_row := spawn("slime", 13, 3)
	check(not world.is_solid(tile_pos(11, 3)) and not world.is_solid(tile_pos(12, 3)), "zonder muur ertussen...")
	await shoot_from(10, 3, Vector2.RIGHT)
	check(hp_of(open_row) == 1, "...raakt dezelfde pijl wel")
	await clear_enemies()
	# Heel dicht bij een muur schieten: de pijl blijft meteen steken en er gebeurt niets geks.
	await teleport(13, 2)
	player.facing = Vector2.RIGHT
	player.bow_cooldown = 0.0
	var before: int = gs.count("arrow")
	press("bow")
	await frames(3)
	check(gs.count("arrow") == before - 1 and (arrows().is_empty() or arrows()[0].state != "flying"), "tegen een muur aan schieten blijft meteen steken")
	await wait_arrows()

	print("Water")
	world.load_map("forest", "start")
	await frames(5)
	await clear_enemies()
	check(world.is_solid(tile_pos(24, 10)) and world.is_solid(tile_pos(25, 10)), "de rivier in het bos is water (daar kun je niet lopen)")
	var across := spawn("slime", 27, 10)
	await shoot_from(23, 10, Vector2.RIGHT)
	check(hp_of(across) == 1, "een pijl vliegt over het water en raakt de vijand aan de overkant")
	await clear_enemies()
	var out_of_reach := spawn("slime", 29, 14)
	await shoot_from(16, 14, Vector2.RIGHT)
	await frames(30)
	check(hp_of(out_of_reach) == 3 and arrows().is_empty(), "boven het water uitgeput: een plons, geen fouten en de pijl verdwijnt")
	await clear_enemies()

	print("Bazen")
	await goto_map("village")
	gs.inventory = {"bow": 1, "arrow": 40}
	var king := spawn("king", 10, 14)
	var behind_king := spawn("slime", 12, 14)
	await shoot_from(5, 14, Vector2.RIGHT)
	check(king.hp == king.max_hp and hp_of(behind_king) == 1, "een slapende baas wordt niet geraakt: de pijl vliegt erlangs en raakt het slijm erachter")
	king.activate()
	await shoot_from(5, 14, Vector2.RIGHT)
	check(king.hp == king.max_hp - 1 and hp_of(behind_king) == 1, "een wakkere Slijmkoning wel, voor 1 schade (en het slijm erachter niet)")
	king.state = "hop"
	king.air_height = 30.0
	await shoot_from(5, 14, Vector2.RIGHT)
	check(king.hp == king.max_hp - 1 and hp_of(behind_king) == -1, "in de lucht vlieg je eronderdoor: het slijm erachter is nu verslagen")
	await clear_enemies()

	print("De kristalgolem: pijlen ketsen af, behalve als hij uithaalt")
	var golem := spawn("golem", 10, 14)
	toasts.clear()
	var arrows_before: int = gs.count("arrow")
	await shoot_from(5, 14, Vector2.RIGHT)
	check(golem.hp == golem.max_hp, "een rustige golem: de pijl ketst af (geen schade)")
	check(toast_count("Je pijl ketst af op het kristal!") == 1, "een melding vertelt wanneer je wel moet schieten")
	check(gs.count("arrow") == arrows_before - 1, "de afgeketste pijl ben je kwijt")
	await shoot_from(5, 14, Vector2.RIGHT)
	check(golem.hp == golem.max_hp and toast_count("Je pijl ketst af op het kristal!") == 1, "nog een keer: weer geen schade, en de melding komt maar een keer")
	golem.state = "windup"
	await shoot_from(5, 14, Vector2.RIGHT)
	check(golem.hp == golem.max_hp - 1, "als hij uithaalt voor een klap doet een pijl 1 schade (golem 22 -> 21)")
	golem.state = "recover"
	await shoot_from(5, 14, Vector2.RIGHT)
	check(golem.hp == golem.max_hp - 2, "en vlak na zijn klap ook")
	await clear_enemies()

	# Van veraf schieten terwijl hij op je af komt (de truc uit de review): hij blijft heel.
	var walker: Node2D = world.spawn_enemy("golem", tile_pos(11, 14))
	await teleport(5, 14)
	var shots := 0
	for i in 6:
		player.facing = Vector2.RIGHT
		player.bow_cooldown = 0.0
		press("bow")
		shots += 1
		await frames(25)
	await wait_arrows()
	check(is_instance_valid(walker) and walker.hp == walker.max_hp and walker.global_position.x > player.global_position.x + 66.0,
		"%d pijlen van veraf op een naderende golem: geen schade" % shots)
	await clear_enemies()

	print("De pijl raakt het dichtstbijzijnde op zijn pad")
	# Twee vijanden die allebei in het eerste stukje van de vlucht liggen, in beide volgordes aangemaakt.
	for near_first in [true, false]:
		await teleport(5, 14)
		var hand: Vector2 = world.player.global_position + Vector2(0, 4)
		var near_pos := hand + Vector2(6, -4) # vijanden zitten 4 pixels hoger dan hun lichaam
		var far_pos := hand + Vector2(16, -4)
		var near_slime: Node2D = spawn("slime", 5, 14) if near_first else null
		var far_slime := spawn("slime", 5, 14)
		if not near_first:
			near_slime = spawn("slime", 5, 14)
		near_slime.global_position = near_pos
		far_slime.global_position = far_pos
		world.player.facing = Vector2.RIGHT
		world.player.bow_cooldown = 0.0
		press("bow")
		await frames(2)
		await wait_arrows()
		check(hp_of(near_slime) == 1 and hp_of(far_slime) == 3, "de dichtste van twee vijanden wordt geraakt (%s eerst gemaakt)" % ("dichtste" if near_first else "verste"))
		await clear_enemies()
	# Hetzelfde voor doelwitten, en voor een doelwit en een vijand door elkaar.
	var target_script: Script = load("res://scripts/entities/target.gd")
	for near_first in [true, false]:
		await teleport(5, 14)
		var hand: Vector2 = world.player.global_position + Vector2(0, 4)
		var boards: Array[Node2D] = []
		for i in 2:
			var board: Node2D = target_script.new()
			board.world = world
			board.obj = {}
			world.entities.add_child(board)
			boards.append(board)
		var near_board: Node2D = boards[0] if near_first else boards[1]
		var far_board: Node2D = boards[1] if near_first else boards[0]
		near_board.global_position = hand + Vector2(8, 3) # het bord zit 3 pixels boven zijn voet
		far_board.global_position = hand + Vector2(20, 3)
		world.player.facing = Vector2.RIGHT
		world.player.bow_cooldown = 0.0
		press("bow")
		await frames(2)
		await wait_arrows()
		check(near_board.hit and not far_board.hit, "het dichtste van twee doelwitten wordt geraakt (%s eerst gemaakt)" % ("dichtste" if near_first else "verste"))
		for board in boards:
			board.queue_free()
	await frames(2)
	await teleport(5, 14)
	var hand_pos: Vector2 = world.player.global_position + Vector2(0, 4)
	var board_near: Node2D = target_script.new()
	board_near.world = world
	board_near.obj = {}
	world.entities.add_child(board_near)
	board_near.global_position = hand_pos + Vector2(6, 3)
	var slime_far := spawn("slime", 5, 14)
	slime_far.global_position = hand_pos + Vector2(16, -4)
	world.player.facing = Vector2.RIGHT
	world.player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	await wait_arrows()
	check(board_near.hit and hp_of(slime_far) == 3, "een doelwit voor een vijand: het doelwit wordt geraakt")
	board_near.queue_free()
	await clear_enemies()
	var board_far: Node2D = target_script.new()
	board_far.world = world
	board_far.obj = {}
	world.entities.add_child(board_far)
	board_far.global_position = hand_pos + Vector2(20, 3)
	var slime_near := spawn("slime", 5, 14)
	slime_near.global_position = hand_pos + Vector2(6, -4)
	world.player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	await wait_arrows()
	check(hp_of(slime_near) == 1 and not board_far.hit, "een vijand voor een doelwit: de vijand wordt geraakt")
	board_far.queue_free()
	await clear_enemies()

	print("Skeletten laten pijlen vallen")
	seed(7) # vaste dobbelstenen, zodat de test elke keer hetzelfde doet
	const SKELETONS := 120
	for i in SKELETONS:
		var skeleton := spawn("skeleton", 20, 14)
		skeleton.hurt(99, Vector2.RIGHT)
		await frames(1)
	var dropped := 0
	for pickup in get_nodes_in_group("pickups"):
		if pickup.item == "arrow" and not pickup.is_queued_for_deletion():
			dropped += 1
	var share := float(dropped) / 2.0 / float(SKELETONS)
	check(dropped > 0 and dropped % 2 == 0, "van %d skeletten vallen er pijlen, steeds twee tegelijk: %d" % [SKELETONS, dropped])
	check(share > 0.18 and share < 0.42, "ongeveer 30%% van de skeletten laat pijlen vallen (%.0f%%)" % (share * 100.0))
	await clear_enemies()

	print("Pijlen na het wisselen van gebied")
	await teleport(5, 14)
	player.facing = Vector2.RIGHT
	player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	check(arrows().size() == 1, "een pijl in de lucht")
	world.load_map("forest", "start")
	await frames(3)
	check(arrows().is_empty(), "bij een nieuwe kaart is hij weg")
	await goto_map("village")


# --- Doelwitten, poortjes en puzzels -------------------------------------------------------------------------

func test_forest_puzzle() -> void:
	print("Fluisterbos: doelwitten over de rivier")
	gs.new_game()
	gs.inventory = {"bow": 1, "arrow": 20}
	toasts.clear()
	await goto_map("forest")
	var target_a := target_at(27, 30)
	var target_b := target_at(27, 32)
	var gate := gate_with_id("boog_bos")
	var chest := chest_at(22, 35)
	check(target_a != null and target_b != null and gate != null and chest != null, "twee doelwitten, een poortje en een kist staan er")
	check(gate.blocked and not target_a.is_hit() and not target_b.is_hit(), "het poortje zit dicht en de doelwitten staan recht")
	check(gate.is_in_group("interactable"), "je kunt het poortje aanspreken voor een hint")
	gate.interact()
	check(toasts.has("Het poortje is dicht. Schiet met je boog op de twee doelwitten over de rivier!"), "dat geeft een hint (met de boog erbij)")
	var in_nook := spawn("slime", 22, 34)
	await shoot_from(22, 31, Vector2.DOWN)
	check(hp_of(in_nook) == 3, "een dicht poortje houdt een pijl tegen")
	# Ook als je er vlak tegenaan staat: de pijl begint dan al bijna in het poortje.
	await teleport(22, 31)
	Input.action_press("move_down")
	await frames(40)
	Input.action_release("move_down")
	await frames(2)
	var against: float = world.player.global_position.y
	check(against > 32 * TILE - 2.0 and against < 33 * TILE, "de speler loopt tegen het dichte poortje aan (y = %.0f)" % against)
	world.player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	var lowest := 0.0
	for i in 40:
		for arrow in arrows():
			lowest = maxf(lowest, arrow.global_position.y)
		await process_frame
	await wait_arrows()
	check(hp_of(in_nook) == 3 and lowest < 34 * TILE, "vlak voor het poortje geschoten blijft de pijl er ook in steken (tot y = %.0f)" % lowest)

	# Het zwaard doet niets met een doelwit.
	await teleport(26, 30)
	world.player.facing = Vector2.RIGHT
	world.player.cooldown = 0.0
	press("attack")
	await frames(3)
	check(not gs.flag("boog_bos_a") and not target_a.is_hit(), "het zwaard raakt een doelwit niet")

	toasts.clear()
	await shoot_from(23, 30, Vector2.RIGHT)
	check(gs.flag("boog_bos_a") and target_a.is_hit() and not gs.flag("boog_bos_b"), "een pijl over de rivier raakt het eerste doelwit en zet de vlag")
	check(gate.blocked, "met een doelwit is het poortje nog dicht")
	check(toast_count("Doelwit geraakt! (1 van 2)") == 1, "een melding: 1 van 2")
	var messages_before := toast_count("Doelwit geraakt!")
	await shoot_from(23, 30, Vector2.RIGHT)
	check(toast_count("Doelwit geraakt!") == messages_before and gate.blocked, "nog een keer raken verandert niets")
	check(arrows().is_empty(), "de pijl blijft in het doelwit zitten")

	# Het tweede doelwit ligt twee rijen lager: een pijl ertussen door raakt geen van beide.
	await shoot_from(23, 31, Vector2.RIGHT)
	check(not gs.flag("boog_bos_b") and gate.blocked, "een pijl tussen de doelwitten door raakt het tweede niet")
	await shoot_from(23, 32, Vector2.RIGHT)
	check(gs.flag("boog_bos_b") and target_b.is_hit(), "vanaf de juiste rij raak je het tweede doelwit")
	await frames(5)
	check(not gate.blocked, "met beide doelwitten gaat het poortje open")
	check(toasts.has("Alle doelwitten geraakt!"), "en de melding zegt dat alles geraakt is")
	await shoot_from(22, 31, Vector2.DOWN)
	check(hp_of(in_nook) == 1, "een open poortje laat een pijl door")

	await teleport(22, 34)
	check(world.player.global_position.y > 33 * TILE, "de speler staat in het verborgen hoekje")
	# Met een bijna volle pijlenkoker blijft de kist dicht, zodat de 10 pijlen niet verloren gaan.
	var own_arrows: int = gs.count("arrow")
	gs.inventory["arrow"] = 35
	toasts.clear()
	chest.interact()
	check(not chest.opened and gs.coins == 0 and gs.count("arrow") == 35, "met 35 pijlen gaat de kist niet open (er zitten er 10 in)")
	check(toast_count("Er zitten pijlen in deze kist, maar ze passen niet meer in je pijlenkoker.") == 1, "een melding zegt waarom")
	gs.inventory["arrow"] = own_arrows
	chest.interact()
	check(gs.coins == 60 and gs.count("arrow") == own_arrows + 10 and chest.opened, "met ruimte geeft de kist 60 munten en 10 pijlen")
	var arrows_now: int = gs.count("arrow")
	chest.interact()
	check(gs.coins == 60 and gs.count("arrow") == arrows_now, "een kist geeft maar een keer iets")

	print("Opslaan en laden: de doelwitten blijven geraakt")
	gs.save_game(world.player.global_position)
	gs.new_game()
	check(not gs.flag("boog_bos_a") and not gs.flag("boog_bos_b"), "een nieuw spel begint zonder treffers")
	check(gs.load_game(), "de opslag wordt gevonden")
	check(gs.flag("boog_bos_a") and gs.flag("boog_bos_b") and gs.count("bow") == 1, "de vlaggen en de boog zijn terug")
	world.load_map("forest", "start")
	await frames(5)
	var loaded_gate := gate_with_id("boog_bos")
	check(target_at(27, 30).is_hit() and target_at(27, 32).is_hit(), "na het laden zijn de doelwitten nog geraakt")
	check(loaded_gate != null and not loaded_gate.blocked, "en het poortje staat nog open")
	check(chest_at(22, 35).opened, "de kist is nog leeg")
	gs.new_game()
	gs.in_game = true
	world.load_map("forest", "start")
	await frames(5)
	check(gate_with_id("boog_bos").blocked and not target_at(27, 30).is_hit(), "in een nieuw spel zit alles weer dicht")

	print("Unieke pijlen in het bos komen niet terug")
	await free_enemies()
	var loose := pickup_at(22, 15)
	check(loose != null and loose.item == "arrow" and loose.unique_key != "", "op (22, 15) ligt een unieke pijl")
	gs.inventory = {"bow": 1, "arrow": 3}
	await teleport(22, 15)
	await frames(20)
	check(gs.count("arrow") == 4 and not is_instance_valid(loose), "oppakken geeft een pijl")
	world.load_map("forest", "start")
	await frames(5)
	check(pickup_at(22, 15) == null and pickup_at(30, 10) != null, "na het opnieuw laden van het bos is hij weg (de andere nog niet)")

	print("Oude opslagen: de plekken van de oude voorwerpen zijn niet verschoven")
	gs.new_game()
	gs.in_game = true
	gs.set_flag("pickup:forest:47") # het drankje op (20, 28), opgepakt in een versie van voor de boog
	world.load_map("forest", "start")
	await frames(5)
	var potion := pickup_at(20, 28)
	check(potion == null, "het al opgepakte drankje komt niet terug")
	gs.new_game()
	gs.in_game = true
	world.load_map("forest", "start")
	await frames(5)
	potion = pickup_at(20, 28)
	check(potion != null and potion.unique_key == "pickup:forest:47", "in een nieuw spel ligt het er wel, met dezelfde sleutel als vroeger")

	print("Het ruïnepoortje sluit de hele opening af")
	await free_enemies()
	await teleport(49, 18)
	Input.action_press("move_up")
	await frames(90)
	Input.action_release("move_up")
	await frames(2)
	check(world.player.global_position.y > 15 * TILE and gs.map_id == "forest", "zonder sleutel loop je niet langs het poortje, ook niet aan de rechterkant (y = %.0f)" % world.player.global_position.y)
	await teleport(48, 18)
	Input.action_press("move_up")
	await frames(90)
	Input.action_release("move_up")
	await frames(2)
	check(world.player.global_position.y > 15 * TILE and gs.map_id == "forest", "en ook niet aan de linkerkant")


func test_ruins_puzzle() -> void:
	print("De Vergeten Ruïne: doelwitten in de muren")
	gs.new_game()
	gs.inventory = {"bow": 1, "arrow": 20}
	await goto_map("ruins")
	var gate := gate_with_id("boog_ruine")
	var chest := chest_at(15, 5)
	var target_a := target_at(18, 8)
	var target_b := target_at(2, 16)
	check(gate != null and chest != null and target_a != null and target_b != null, "poortje, bonuskist en twee doelwitten staan er")
	check(gate.blocked and gate.is_in_group("interactable"), "het poortje zit dicht")
	check(world.is_solid(tile_pos(18, 11)) and world.is_solid(tile_pos(6, 16)), "de pilaren (18, 11) en (6, 16) staan in de weg")

	await shoot_from(18, 14, Vector2.UP)
	check(not target_a.is_hit(), "recht omhoog langs de pilaar raak je het eerste doelwit niet")
	await shoot_from(14, 12, Vector2(1, -1))
	check(target_a.is_hit() and gs.flag("boog_ruine_a"), "maar schuin tussen de pilaren door wel")
	await shoot_from(10, 16, Vector2.LEFT)
	check(not target_b.is_hit(), "ook het tweede doelwit zit achter een pilaar")
	check(gate.blocked, "met een doelwit is het poortje nog dicht")
	await shoot_from(4, 16, Vector2.LEFT)
	check(target_b.is_hit() and gs.flag("boog_ruine_b"), "van dichtbij raak je het wel")
	await frames(5)
	check(not gate.blocked, "het poortje gaat open")

	await teleport(15, 6)
	chest.interact()
	check(gs.count("potion") == 1 and gs.coins == 30, "de bonuskist geeft een helddrank en 30 munten")
	chest.interact()
	check(gs.count("potion") == 1 and gs.coins == 30, "maar maar een keer")

	gs.save_game(world.player.global_position)
	gs.new_game()
	gs.load_game()
	world.load_map("ruins", "start")
	await frames(5)
	check(not gate_with_id("boog_ruine").blocked and target_at(18, 8).is_hit(), "ook hier blijft alles na het laden zoals het was")
	await clear_enemies()
	gs.new_game()
	gs.in_game = true


# --- Schietbaan --------------------------------------------------------------------------------------------

func range_node() -> Node:
	return get_first_node_in_group("boog_range")


## Raak alle drie de doelwitten van de schietbaan, elk vanaf de schietlijn (x = 31).
func hit_all_range_targets() -> void:
	await shoot_from(31, 15, Vector2.RIGHT)
	await shoot_from(31, 16, Vector2.RIGHT)
	await shoot_from(31, 17, Vector2.RIGHT)


func wait_for_state(range_state: String, limit := 300) -> void:
	var waited := 0
	while range_node().state != range_state and waited < limit:
		await process_frame
		waited += 1


func test_range() -> void:
	print("Schietbaan: de baan en Tessa")
	gs.new_game()
	gs.inventory = {}
	await goto_map("village")
	var tessa := npc_by_id("tessa")
	var baan := range_node()
	check(tessa != null and baan != null, "Tessa en de schietbaan staan in het dorp")
	check(get_nodes_in_group("boog_target").size() == 3 and baan.targets().size() == 3, "er zijn drie doelwitten")
	check(baan.state == "idle", "de baan wacht op een poging")
	check(pick_talk("tessa") == "tessa_nobow", "zonder boog stuurt Tessa je naar Tobias")
	await run_dialogue("tessa_nobow")
	check(gs.quest_state("boog_schietbaan") == "none", "dat start de opdracht nog niet")
	gs.give("bow", 1, true)
	gs.give("arrow", 10, true)
	check(pick_talk("tessa") == "tessa_intro", "met een boog biedt Tessa de schietbaan aan")

	print("Oefenschoten")
	await shoot_from(31, 17, Vector2.RIGHT)
	var practice := target_at(34, 17)
	check(practice.hit and baan.state == "idle", "een schot zonder poging licht het doelwit even op")
	check(gs.count("arrow") == 9 and not baan.lends_arrows(), "buiten een poging kost een schot gewoon een pijl")
	check(not gs.flag("boog_range_won") and gs.quest_state("boog_schietbaan") == "none", "maar het telt nergens voor")
	await frames(110)
	check(not practice.hit, "daarna staat het doelwit vanzelf weer recht")

	print("Een poging: begin tot eind")
	toasts.clear()
	await run_dialogue("tessa_intro", [0])
	check(gs.quest_state("boog_schietbaan") == "active" and gs.quest_step("boog_schietbaan") == 0, "'Ik doe mee!' start de opdracht")
	check(baan.state == "ready", "en een poging: 'Klaar?'")
	await frames(150)
	check(baan.state == "ready" and baan.count_shown == 1, "Tessa telt drie seconden af (3, 2, 1), zo heb je tijd om naar de schietlijn te lopen")
	await wait_for_state("run")
	check(baan.state == "run" and absf(baan.time_left - 20.0) < 1.0, "daarna loopt de tijd: 20 seconden")
	baan.start_run()
	check(baan.state == "run", "tijdens een poging begint 'start' niet opnieuw")
	check(baan.hits == 0, "nog niets geraakt")
	await shoot_from(31, 15, Vector2.RIGHT)
	await frames(2)
	check(baan.hits == 1 and baan.state == "run", "een doelwit geraakt: 1 van 3")
	await shoot_from(31, 16, Vector2.RIGHT)
	await frames(2)
	check(baan.hits == 2 and baan.state == "run", "twee van de drie")
	check(baan.time_left > 5.0 and baan.time_left < 20.0, "de klok loopt (nog %.1f seconden)" % baan.time_left)
	await shoot_from(31, 17, Vector2.RIGHT)
	await frames(3)
	check(baan.state == "won", "alle drie geraakt binnen de tijd: gehaald!")
	check(gs.count("arrow") == 9, "tijdens de poging schoot je met Tessa's pijlen: je hebt er nog evenveel")
	world.player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	check(gs.count("arrow") == 8, "na de poging kost een schot weer een eigen pijl")
	await wait_arrows()
	check(gs.flag("boog_range_won") and gs.quest_step("boog_schietbaan") == 1, "de opdracht gaat naar stap 2: ga naar Tessa")
	check(toast_count("Gehaald in") == 1, "er komt een melding met je tijd")
	check(gs.coins == 0, "de beloning krijg je pas bij Tessa")
	check(pick_talk("tessa") == "tessa_reward", "Tessa heeft nu de beloning")
	await frames(170)
	check(baan.state == "idle" and not target_at(34, 17).hit and not target_at(35, 15).hit and not target_at(37, 16).hit, "na het resultaat staan de doelwitten weer recht")

	print("De beloning")
	var arrows_before: int = gs.count("arrow")
	await run_dialogue("tessa_reward")
	check(gs.coins == 25 and gs.count("arrow") == arrows_before + 10, "25 munten en 10 pijlen")
	check(gs.quest_state("boog_schietbaan") == "done", "de opdracht is voltooid")
	check(pick_talk("tessa") == "tessa_done", "Tessa praat nu over oefenen")

	print("Herhalen kan, maar zonder beloning")
	toasts.clear()
	await run_dialogue("tessa_done", [0])
	check(baan.state == "ready", "'Oefenen' begint een nieuwe poging")
	await wait_for_state("run")
	await hit_all_range_targets()
	await frames(3)
	check(baan.state == "won", "weer gehaald")
	check(toast_count("Gehaald in") == 1, "met een melding over je tijd")
	check(gs.coins == 25 and gs.quest_state("boog_schietbaan") == "done", "maar niets extra's: nog steeds 25 munten")
	check(pick_talk("tessa") == "tessa_done", "Tessa biedt de beloning niet nog eens aan")
	await frames(170)

	print("Te laat (en meedoen zonder eigen pijlen)")
	gs.new_game()
	gs.inventory = {"bow": 1}
	await goto_map("village")
	baan = range_node()
	toasts.clear()
	await run_dialogue("tessa_intro", [0])
	check(baan.state == "ready", "ook zonder pijlen kun je meedoen")
	await wait_for_state("run")
	await shoot_from(31, 15, Vector2.RIGHT)
	await frames(2)
	baan.time_left = 0.05
	await frames(5)
	check(baan.state == "lost", "als de tijd om is, mislukt de poging")
	check(not gs.flag("boog_range_won") and gs.quest_step("boog_schietbaan") == 0, "de opdracht blijft bij stap 1")
	check(toast_count("Tijd om! Je raakte 1 van de 3.") == 1, "een melding vertelt hoeveel je raakte")
	check(toast_count("Geen pijlen!") == 0, "met Tessa's pijlen kon je schieten, ook zonder eigen pijlen")
	check(gs.coins == 0, "geen beloning")
	gs.inventory["arrow"] = 10
	await shoot_from(31, 16, Vector2.RIGHT)
	await shoot_from(31, 17, Vector2.RIGHT)
	check(not gs.flag("boog_range_won"), "schieten nadat de tijd om is telt niet meer")
	check(gs.count("arrow") == 8, "en kost weer je eigen pijlen")
	await frames(170)
	check(baan.state == "idle" and not target_at(35, 15).hit, "daarna staat alles weer klaar")
	check(pick_talk("tessa") == "tessa_active", "Tessa weet dat je het nog eens wilt proberen")
	await run_dialogue("tessa_active", [0])
	check(baan.state == "ready", "'Nog een poging!' begint opnieuw")
	await wait_for_state("run")
	check(baan.hits == 0 and not target_at(35, 15).hit, "alle doelwitten staan weer recht")
	gs.inventory["arrow"] = 0
	await hit_all_range_targets()
	await frames(3)
	check(gs.flag("boog_range_won") and gs.quest_step("boog_schietbaan") == 1, "de tweede poging lukt, helemaal zonder eigen pijlen")

	print("Beloning bij een bijna volle pijlenkoker")
	gs.inventory = {"bow": 1, "arrow": 35}
	gs.coins = 0
	await run_dialogue("tessa_reward")
	check(gs.coins == 0 and gs.count("arrow") == 35 and gs.quest_state("boog_schietbaan") == "active", "Tessa wacht met betalen tot er ruimte is (geen pijlen weggooien)")
	gs.inventory["arrow"] = 30
	await run_dialogue("tessa_reward")
	check(gs.coins == 25 and gs.count("arrow") == 40 and gs.quest_state("boog_schietbaan") == "done", "met ruimte voor 10 pijlen krijg je alles")
	await frames(170)

	print("De opdracht in het logboek")
	var quest: Dictionary = Quests.info("boog_schietbaan")
	check(quest["steps"].size() == 2 and quest["title"] == "Schietbaan", "de opdracht heet Schietbaan en heeft twee stappen")
	gs.new_game()
	gs.start_quest("boog_schietbaan")
	check(gs.quest_text("boog_schietbaan").contains("20 seconden"), "de tekst noemt de tijd")
	gs.set_flag("boog_range_won")
	check(gs.quest_step("boog_schietbaan") == 1 and gs.quest_text("boog_schietbaan").contains("Tessa"), "na het halen: ga naar Tessa")
	gs.new_game()


# --- HUD, menu en volle pijlenkoker ---------------------------------------------------------------------------

func test_hud() -> void:
	var controls: Node = root.get_node("Controls")
	print("Pijlenteller en menu")
	gs.new_game()
	gs.in_game = true
	await goto_map("village")
	var hud = world.hud
	check(hud.arrow_text() == "", "zonder boog geen pijlenteller")
	gs.give("arrow", 12, true)
	check(hud.arrow_text() == "", "ook niet met pijlen alleen")
	gs.give("bow", 1, true)
	check(hud.arrow_text() == "12 [%s]" % controls.action_label("bow"), "met een boog: aantal en toets: %s" % hud.arrow_text())
	var text_queue: String = " ".join(PackedStringArray(hud.toast_queue)) + " " + hud.toast_label.text
	check(text_queue.contains("Boog gekregen! Druk op %s om te schieten." % controls.action_label("bow")), "bij het krijgen van de boog vertelt een melding hoe je schiet")
	world.player.facing = Vector2.RIGHT
	world.player.bow_cooldown = 0.0
	press("bow")
	await frames(2)
	check(hud.arrow_text() == "11 [%s]" % controls.action_label("bow"), "schieten verlaagt de teller")
	var normal_color: Color = hud.arrow_color()
	gs.inventory["arrow"] = 0
	gs.items_changed.emit()
	check(hud.arrow_text() == "0 [%s]" % controls.action_label("bow"), "bij nul staat er 0")
	var empty_color: Color = hud.arrow_color()
	check(empty_color.r > 0.9 and empty_color.g < 0.6 and normal_color.g > 0.8, "en dan kleurt de teller rood")
	await frames(2) # de teller wordt getekend met het eigen plaatje (items_boog) zonder fouten
	await frames(2)
	check(world.menu_ui._owned().has("bow"), "de boog staat in het menu")
	gs.give("arrow", 3, true)
	check(world.menu_ui._owned().has("arrow") and Items.sheet_of("arrow") == "items_boog", "de pijlen ook, met hun eigen icoon")
	await wait_arrows()


func test_full_quiver() -> void:
	print("Volle pijlenkoker")
	gs.new_game()
	gs.in_game = true
	await goto_map("village")
	await teleport(12, 15)
	check(gs.room("arrow") == 40 and gs.room("potion") == gs.NO_LIMIT, "ruimte voor 40 pijlen, en onbeperkt voor gewone voorwerpen")
	gs.inventory = {"bow": 1, "arrow": 40}
	check(gs.room("arrow") == 0, "40 pijlen: geen ruimte meer")
	toasts.clear()
	PickupScript._last_full_warning = -1000
	var pickup: Node = world.spawn_pickup("arrow", world.player.global_position)
	await frames(60)
	check(is_instance_valid(pickup) and not pickup.is_queued_for_deletion() and gs.count("arrow") == 40, "boven het maximum wordt een pijl niet opgepakt")
	check(toast_count(FULL_QUIVER_TEXT) == 1, "er komt een melding 'Je pijlenkoker is vol', een keer en niet elk beeld")
	await frames(250)
	check(toast_count(FULL_QUIVER_TEXT) == 2, "na een tijdje nog eens als je er nog steeds op staat")
	gs.inventory["arrow"] = 39
	await frames(5)
	check(gs.count("arrow") == 40 and not is_instance_valid(pickup), "met ruimte voor een pijl wordt hij wel opgepakt")
	check(toast_count("Gekregen: Pijl") == 0, "een pijl oppakken geeft geen melding (een plusje volstaat)")

	gs.inventory["arrow"] = 35
	toasts.clear()
	gs.give("arrow", 10)
	check(gs.count("arrow") == 40 and toasts.has("Gekregen: Pijl x5. Je pijlenkoker is vol!"), "een stapel van 10 past maar voor de helft: je houdt 40, en de melding zegt dat")
	toasts.clear()
	gs.give("arrow", 10)
	check(gs.count("arrow") == 40 and toasts.has(FULL_QUIVER_TEXT), "en met een volle koker geeft 'give' niets en meldt dat")
	toasts.clear()
	gs.give("arrow", 1, true)
	check(gs.count("arrow") == 40 and toasts.is_empty(), "stil geven blijft stil")
	gs.give("potion", 99, true)
	check(gs.count("potion") == 99, "voorwerpen zonder maximum blijven onbeperkt")

	# Een skelet laat pijlen vallen die je kunt oppakken.
	gs.inventory = {"bow": 1}
	world.spawn_pickup("arrow", world.player.global_position)
	await frames(20)
	check(gs.count("arrow") == 1, "een pijl van een skelet raap je gewoon op")


func test_save() -> void:
	print("Opslaan en laden")
	gs.new_game()
	gs.in_game = true
	await goto_map("village")
	gs.give("bow", 1, true)
	gs.give("arrow", 17, true)
	gs.set_flag("boog_range_won")
	gs.start_quest("boog_schietbaan")
	gs.save_game(world.player.global_position)
	gs.new_game()
	check(gs.count("bow") == 0 and gs.count("arrow") == 0, "nieuw spel: geen boog")
	check(gs.load_game(), "laden")
	check(gs.count("bow") == 1 and gs.count("arrow") == 17, "boog en 17 pijlen zijn teruggekomen")
	check(gs.flag("boog_range_won") and gs.quest_step("boog_schietbaan") == 1, "schietbaan-vlag en opdracht ook")
	gs.new_game()


# --- Plaatsing op de kaarten --------------------------------------------------------------------------------

## Tegels waar je niet doorheen kunt lopen, plus personages, kisten, borden en (dichte) poortjes.
func blocked_cells(map_id: String, gates_closed: bool) -> Dictionary:
	var def: Dictionary = Maps.get_map(map_id)
	var rows: Array = def["rows"]
	var cells := {}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if Tiles.is_solid_char(row[x]):
				cells[Vector2i(x, y)] = true
	for obj: Dictionary in def["objects"]:
		var cell := Vector2i(obj["pos"][0], obj["pos"][1])
		match obj["type"]:
			"npc", "chest", "sign", "savepoint":
				cells[cell] = true
			"gate":
				if gates_closed:
					var size: Array = obj.get("size", [1, 1])
					for dy in int(size[1]):
						for dx in int(size[0]):
							cells[cell + Vector2i(dx, dy)] = true
	return cells


## Alle tegels waar je vanaf de startplek kunt komen.
func reachable_cells(map_id: String, gates_closed: bool) -> Dictionary:
	var def: Dictionary = Maps.get_map(map_id)
	var rows: Array = def["rows"]
	var blocked := blocked_cells(map_id, gates_closed)
	var start := Vector2i(def["spawns"]["start"][0], def["spawns"]["start"][1])
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var width: int = String(rows[0]).length()
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= rows.size():
				continue
			if seen.has(next) or blocked.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen


func object_cells(obj: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var size: Array = obj.get("size", [1, 1])
	for dy in int(size[1]):
		for dx in int(size[0]):
			cells.append(Vector2i(int(obj["pos"][0]) + dx, int(obj["pos"][1]) + dy))
	return cells


## Kun je bij dit object komen? Voorwerpen en doorgangen moet je kunnen betreden; personages, kisten en borden
## spreek je aan vanaf een buurtegel.
func object_reachable(obj: Dictionary, region: Dictionary) -> bool:
	var talkable: bool = obj["type"] in ["npc", "chest", "sign", "savepoint", "gate"]
	for cell in object_cells(obj):
		if region.has(cell):
			return true
		if talkable:
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if region.has(cell + step):
					return true
	return false


## Is er vanaf deze tegel een vrije, rechte (acht richtingen) schootslijn naar het doelwit binnen het bereik van een pijl?
## Muren, bomen, personages, borden en dichte poortjes zijn in de weg; water niet.
func clear_shot(map_id: String, from: Vector2i, to: Vector2i) -> bool:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if from == to or not (dx == 0 or dy == 0 or absi(dx) == absi(dy)):
		return false
	var rows: Array = Maps.get_map(map_id)["rows"]
	var statics := blocked_cells(map_id, true)
	var a := tile_pos(from.x, from.y)
	var b := tile_pos(to.x, to.y)
	if a.distance_to(b) > ArrowScript.RANGE:
		return false
	var steps := int(a.distance_to(b) / 4.0)
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / float(steps))
		var cell := Vector2i(int(floorf(p.x / TILE)), int(floorf(p.y / TILE)))
		if cell == to or cell == from or not statics.has(cell):
			continue
		if Tiles.CHARS.get(String(rows[cell.y])[cell.x], "grass") != "water":
			return false
	return true


func has_shot(map_id: String, target_cell: Vector2i, region: Dictionary, allowed: Callable) -> bool:
	for cell: Vector2i in region:
		if allowed.call(cell) and clear_shot(map_id, cell, target_cell):
			return true
	return false


func test_placement() -> void:
	print("Plaatsing op de kaarten")
	for map_id in ["village", "forest", "ruins"]:
		var def: Dictionary = Maps.get_map(map_id)
		var open_region := reachable_cells(map_id, false)
		var all_ok := true
		var used := {}
		for obj: Dictionary in def["objects"]:
			if not (obj["type"] in ["npc", "chest", "pickup", "sign", "portal", "savepoint", "gate", "boog_target", "boog_baan"]):
				continue
			if not object_reachable(obj, open_region):
				print("       onbereikbaar op ", map_id, ": ", obj)
				all_ok = false
			for cell in object_cells(obj):
				if Tiles.is_solid_char(String(def["rows"][cell.y])[cell.x]):
					print("       object in een muur op ", map_id, ": ", obj)
					all_ok = false
				if obj["type"] in ["npc", "chest", "sign", "savepoint", "gate", "boog_target"]:
					if used.has(cell):
						print("       twee objecten op dezelfde tegel op ", map_id, ": ", cell)
						all_ok = false
					used[cell] = true
		check(all_ok, "%s: alle personages, kisten, voorwerpen, doelwitten en doorgangen zijn bereikbaar (poortjes open)" % map_id)

	print("De verborgen kamers zitten echt op slot")
	var forest_closed := reachable_cells("forest", true)
	var forest_open := reachable_cells("forest", false)
	check(not forest_closed.has(Vector2i(22, 35)) and not forest_closed.has(Vector2i(22, 34)), "bos: zonder open poortje kom je niet in het hoekje")
	check(forest_open.has(Vector2i(22, 34)) and forest_open.has(Vector2i(21, 35)) and forest_open.has(Vector2i(23, 35)), "bos: met open poortje wel (en bij de kist)")
	var ruins_closed := reachable_cells("ruins", true)
	var ruins_open := reachable_cells("ruins", false)
	check(not ruins_closed.has(Vector2i(15, 7)) and not ruins_closed.has(Vector2i(15, 6)), "ruïne: de bonuskamer zit dicht")
	check(ruins_open.has(Vector2i(15, 6)) and ruins_open.has(Vector2i(14, 5)) and ruins_open.has(Vector2i(16, 7)), "ruïne: open poortje geeft toegang tot de hele kamer")
	check(forest_closed.has(Vector2i(22, 32)) and ruins_closed.has(Vector2i(15, 9)), "en je kunt wel tot het poortje lopen")
	check(not forest_closed.has(Vector2i(49, 13)) and not forest_closed.has(Vector2i(48, 13)) and forest_open.has(Vector2i(49, 11)), "bos: het ruïnepoortje sluit de hele opening (twee tegels breed)")

	print("De doelwitten zijn te raken")
	var forest_target_a := Vector2i(27, 30)
	var forest_target_b := Vector2i(27, 32)
	var west_bank := func(cell: Vector2i) -> bool: return cell.x <= 23
	check(has_shot("forest", forest_target_a, forest_closed, west_bank), "bos: doelwit A is vanaf de westoever te raken (over het water)")
	check(has_shot("forest", forest_target_b, forest_closed, west_bank), "bos: doelwit B ook")
	var any_cell := func(_cell: Vector2i) -> bool: return true
	check(has_shot("ruins", Vector2i(18, 8), ruins_closed, any_cell) and has_shot("ruins", Vector2i(2, 16), ruins_closed, any_cell), "ruïne: beide doelwitten zijn te raken")
	check(not clear_shot("ruins", Vector2i(18, 14), Vector2i(18, 8)) and not clear_shot("ruins", Vector2i(10, 16), Vector2i(2, 16)), "ruïne: de pilaren blokkeren de rechte lijnen op afstand")
	var village_closed := reachable_cells("village", true)
	var lane := func(cell: Vector2i) -> bool: return cell.x == 31 and cell.y >= 15 and cell.y <= 17
	var lane_ok := true
	for target_cell in [Vector2i(35, 15), Vector2i(37, 16), Vector2i(34, 17)]:
		if not has_shot("village", target_cell, village_closed, lane):
			print("       niet te raken vanaf de schietlijn: ", target_cell)
			lane_ok = false
	check(lane_ok, "dorp: elk doelwit van de schietbaan is vanaf de schietlijn te raken")
	check(not has_shot("village", Vector2i(35, 15), village_closed, func(cell: Vector2i) -> bool: return cell.x == 31 and cell.y == 17),
		"dorp: de doelwitten liggen in verschillende rijen (je moet dus lopen)")

	print("De rest van de kaarten is niet kapotgegaan")
	var village_rows: Array = Maps.get_map("village")["rows"]
	check(village_rows[16][28] == "." and village_rows[16][35] == ".", "dorp: de schietbaan is vrijgemaakt")
	var sign_cells: Array[Vector2i] = []
	for obj: Dictionary in Maps.get_map("village")["objects"]:
		if obj["type"] == "sign":
			sign_cells.append(Vector2i(obj["pos"][0], obj["pos"][1]))
	check(sign_cells.has(Vector2i(37, 12)) and not sign_cells.has(Vector2i(33, 15)), "dorp: het bord naar het bos staat niet meer in het schietveld, maar bij de uitgang")
	check(not forest_open.is_empty() and forest_open.has(Vector2i(48, 16)) and ruins_open.has(Vector2i(36, 5)), "bos en ruïne: de kristallen blijven bereikbaar")


func _run() -> void:
	gs = root.get_node("GameState")
	ArrowScript = load("res://scripts/entities/arrow.gd")
	PickupScript = load("res://scripts/entities/pickup.gd")
	gs.toast.connect(func(text: String) -> void: toasts.append(text))
	test_data()
	await start_world()
	await test_shop()
	await test_shooting()
	await test_arrow_hits()
	await test_forest_puzzle()
	await test_ruins_puzzle()
	await test_range()
	await test_hud()
	await test_full_quiver()
	await test_save()
	await stop_world()
	test_placement()

	print("")
	if failures == 0:
		print("BOOG TEST OK")
		quit(0)
	else:
		print("BOOG TEST: %d fout(en)" % failures)
		quit(1)
