extends SceneTree
## Speelt het hele spel uit, van begin tot eind, met de echte kaartgegevens:
## Bram -> sleutelkist -> poortje -> drie kristallen (met minibazen) -> tempel -> baas -> einde.
##
##   godot --headless --fixed-fps 60 --path . -s tests/playthrough_test.gd
##
## Zo weten we zeker dat het spel uit te spelen is: alle poortjes, sleutels, kisten en doorgangen werken.

const Maps := preload("res://scripts/maps/registry.gd")

var failures := 0
var gs: Node
var world: Node2D


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


func objects(map_id: String, type: String) -> Array:
	return Maps.get_map(map_id)["objects"].filter(func(o: Dictionary) -> bool: return o["type"] == type)


func tile_center(pos: Array) -> Vector2:
	return Vector2(float(pos[0]) * 32.0 + 16.0, float(pos[1]) * 32.0 + 16.0)


func put_player(pos: Vector2) -> void:
	world.player.global_position = pos
	world.player.velocity = Vector2.ZERO
	world.player.invuln = 999.0
	await frames(3)


func through_portal(to_map: String) -> void:
	var from_map: String = gs.map_id
	for obj: Dictionary in objects(from_map, "portal"):
		if obj["to"] == to_map:
			var size: Array = obj.get("size", [1, 1])
			var rect := Rect2(Vector2(obj["pos"][0], obj["pos"][1]) * 32.0, Vector2(size[0], size[1]) * 32.0)
			await put_player(rect.get_center() + Vector2(0, 64))
			await put_player(rect.get_center())
			await frames(90)
			check(gs.map_id == to_map, "%s -> %s door de doorgang" % [from_map, to_map])
			return
	check(false, "%s heeft een doorgang naar %s" % [from_map, to_map])


func find_node(group: String, test: Callable) -> Node:
	for node in get_nodes_in_group(group):
		if test.call(node):
			return node
	return null


func collect_pickup(item: String) -> void:
	for pickup in get_nodes_in_group("pickups"):
		if pickup.item == item:
			await put_player(pickup.global_position)
			await frames(5)
			return


func collect_all_drops() -> void:
	for pickup in get_nodes_in_group("pickups"):
		if is_instance_valid(pickup) and pickup.age < 5.0:
			await put_player(pickup.global_position)
			await frames(4)


func kill_boss(kind: String, flag: String) -> void:
	var boss: Node = find_node("boss", func(b): return b.kind == kind)
	check(boss != null, "%s staat er" % kind)
	if boss == null:
		return
	await put_player(boss.global_position + Vector2(-30, 0))
	boss.hurt(9999, Vector2.RIGHT)
	await frames(10)
	check(gs.flag(flag), "%s verslagen (vlag %s)" % [kind, flag])
	await collect_all_drops()


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


func _run() -> void:
	gs = root.get_node("GameState")
	gs.new_game()
	gs.in_game = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)

	print("Dageraadsdorp")
	check(gs.map_id == "village" and gs.tracked_text().begins_with("Praat met"), "het spel begint met een duidelijk doel")
	await talk("bram_intro", [0])
	check(gs.quest_state("main") == "active" and gs.count("potion") == 1, "Bram geeft de hoofdopdracht")

	print("Fluisterbos")
	await through_portal("forest")
	var key_chest: Node = find_node("interactable", func(n): return n.has_method("interact") and "contents" in n and n.contents[0][0] == "ruin_key")
	check(key_chest != null, "de sleutelkist staat in het bos")
	await put_player(key_chest.global_position + Vector2(0, 28))
	key_chest.interact()
	check(gs.count("ruin_key") == 1, "sleutel gevonden")
	await collect_pickup("crystal_bos")
	check(gs.count("crystal_bos") == 1, "bos-kristal opgepakt")
	var cat: Node = find_node("npc", func(n): return n.npc_id == "muis_bos")
	check(cat != null, "Muis zit in het bos")
	await talk("pim_intro", [0])
	await talk("muis_bos")
	check(gs.quest_step("kat") == 1, "kat gevonden (zij-opdracht)")
	await collect_pickup("potion")

	print("Vergeten Ruïne")
	var gate: Node = find_node("interactable", func(n): return "gate_id" in n and n.gate_id == "ruin")
	check(gate != null and gate.blocked, "het poortje zit dicht")
	await put_player(gate.global_position + Vector2(0, 30))
	gate.interact()
	await frames(5)
	check(not gate.blocked, "sleutel opent het poortje")
	await through_portal("ruins")
	await talk("wilfred_intro", [0])
	await kill_boss("golem", "golem_ruins")
	await collect_pickup("crystal_ruine")
	check(gs.count("crystal_ruine") == 1 and gs.count("shard") >= 1, "ruïne-kristal en kristalscherf")
	await through_portal("forest")

	print("Echo-grot")
	await through_portal("cave")
	var medal_chest: Node = find_node("interactable", func(n): return "contents" in n and n.contents[0][0] == "medallion")
	var heart_chest: Node = find_node("interactable", func(n): return "contents" in n and n.contents[0][0] == "heart_container")
	check(medal_chest != null and heart_chest != null, "medaillon en hartcontainer liggen in kisten")
	await put_player(medal_chest.global_position + Vector2(0, 28))
	medal_chest.interact()
	await put_player(heart_chest.global_position + Vector2(0, 28))
	heart_chest.interact()
	check(gs.count("medallion") == 1 and gs.max_hp() == 6, "medaillon en hartcontainer (6 hartjes)")
	await kill_boss("golem", "golem_cave")
	await collect_pickup("crystal_grot")
	check(gs.count("crystal_grot") == 1 and gs.count("shard") >= 2, "grot-kristal en genoeg kristalscherven")
	await through_portal("forest")

	print("Terug naar het dorp")
	gs.give("gel", 13, true)
	gs.coins = 400
	await through_portal("village")
	check(gs.quest_step("main") == 1, "met drie kristallen: breng ze naar Bram")
	await talk("pim_cat_back")
	await talk("wilfred_return")
	check(gs.quest_state("kat") == "done" and gs.quest_state("medaillon") == "done" and gs.max_hp() == 7, "zij-opdrachten afgerond (7 hartjes)")
	await talk("greta_menu", [0, 0])
	await talk("greta_menu", [0, 0])
	check(gs.weapon == "crystal", "het kristalzwaard is gesmeed")
	await talk("bram_crystals")
	check(gs.flag("gate_temple") and gs.quest_step("main") == 2, "Bram opent de tempel")
	await talk("mila_menu", [0])

	print("Kristaltempel")
	await through_portal("temple")
	check(gs.map_id == "temple", "de tempeldeur gaat open")
	var king: Node = find_node("boss", func(b): return b.kind == "king")
	check(king != null and not king.active, "de Slijmkoning wacht")
	var trigger_obj: Dictionary = objects("temple", "trigger")[0]
	var tsize: Array = trigger_obj["size"]
	var trect := Rect2(Vector2(trigger_obj["pos"][0], trigger_obj["pos"][1]) * 32.0, Vector2(tsize[0], tsize[1]) * 32.0)
	await put_player(trect.get_center())
	await frames(5)
	check(world.dialogue.active, "de baas begroet je")
	while world.dialogue.active:
		var down := InputEventAction.new()
		down.action = "interact"
		down.pressed = true
		root.push_input(down)
		await frames(3)
	check(king.active and gs.flag("boss_started"), "het gevecht begint")
	var arena_gate: Node = find_node("interactable", func(n): return "gate_id" in n and n.gate_id == "arena")
	check(arena_gate == null or arena_gate.blocked, "de deur gaat dicht")
	var ending := [0]
	gs.ending_requested.disconnect(world._on_ending)
	gs.ending_requested.connect(func() -> void: ending[0] += 1)
	king.hp = 5
	await put_player(king.global_position + Vector2(-40, 0))
	king.state = "idle"
	king.hurt(99, Vector2.RIGHT)
	await frames(180)
	check(gs.flag("boss_defeated") and ending[0] == 1, "baas verslagen en het einde begint")

	print("")
	print("Speeltijd in de test: %s" % ("%.0f seconden" % gs.play_time))
	if failures == 0:
		print("PLAYTHROUGH OK")
		quit(0)
	else:
		print("PLAYTHROUGH: %d fout(en)" % failures)
		quit(1)
