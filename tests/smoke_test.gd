extends SceneTree
## Headless speltest. Draaien met:
##   godot --headless --path . -s tests/smoke_test.gd
## Exitcode 0 = alles goed, 1 = er ging iets mis.

var failures := 0


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


func _run() -> void:
	var gs := root.get_node("GameState")
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(3)

	print("Wereld")
	var player: CharacterBody2D = main.player
	check(player != null, "speler bestaat")
	check(get_nodes_in_group("enemies").size() == 8, "8 slijmen")
	check(get_nodes_in_group("npc").size() == 1, "1 NPC")
	var crystals := get_nodes_in_group("pickups").filter(func(p): return p.kind == "crystal")
	check(crystals.size() == 4, "4 kristallen op de kaart")
	for action in ["move_left", "move_right", "move_up", "move_down", "attack", "interact", "restart"]:
		check(InputMap.has_action(action), "input-actie " + action)

	print("Botsingen")
	var start := player.global_position
	Input.action_press("move_left")
	await frames(240)
	Input.action_release("move_left")
	check(player.global_position.x > 32.0, "speler loopt niet door de rand (x=%.0f)" % player.global_position.x)
	check(player.global_position.x < start.x, "speler kan lopen")

	print("Kristallen rapen")
	player.global_position = crystals[0].global_position
	await frames(3)
	check(gs.crystals == 1, "kristal opgepakt")

	print("Vechten")
	var enemy: Node2D = get_nodes_in_group("enemies")[0]
	enemy.set_physics_process(false)
	player.global_position = enemy.global_position + Vector2(-20, 0)
	player.facing = Vector2.RIGHT
	var hp_before: int = enemy.hp
	var coins_on_map := get_nodes_in_group("pickups").filter(func(p): return p.kind == "coin").size()
	press("attack")
	await frames(2)
	check(enemy.hp == hp_before - 1, "zwaard raakt slijm")
	for i in 2:
		player.cooldown = 0.0
		press("attack")
		await frames(2)
	await frames(2)
	check(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "slijm verslagen na 3 klappen")
	var coins_now := get_nodes_in_group("pickups").filter(func(p): return p.kind == "coin").size()
	check(coins_now == coins_on_map + 1, "slijm liet een munt vallen")

	print("Schade")
	for e in get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var hp0: int = gs.hp
	player.hurt(player.global_position + Vector2(10, 0))
	check(gs.hp == hp0 - 1, "speler raakt een leven kwijt")
	player.hurt(player.global_position + Vector2(10, 0))
	check(gs.hp == hp0 - 1, "onkwetsbaar direct na een klap")

	print("Quest")
	var npc: Node2D = get_nodes_in_group("npc")[0]
	player.global_position = npc.global_position + Vector2(0, 24)
	await frames(2)
	press("interact")
	await frames(2)
	check(gs.dialogue_open, "gesprek opent")
	for i in 12:
		press("interact")
		await frames(2)
		if not gs.dialogue_open:
			break
	check(not gs.dialogue_open, "gesprek sluit na doorklikken")
	check(gs.quest_started, "opdracht gestart")

	press("interact")
	await frames(2)
	check(gs.dialogue_open, "Bram vraagt om meer kristallen")
	for i in 12:
		press("interact")
		await frames(2)
		if not gs.dialogue_open:
			break
	check(not gs.quest_done, "nog niet klaar met 1 kristal")

	for i in 2:
		player.global_position = crystals[i + 1].global_position
		await frames(3)
	check(gs.crystals == 3, "3 kristallen verzameld")

	player.global_position = npc.global_position + Vector2(0, 24)
	await frames(2)
	press("interact")
	await frames(2)
	for i in 12:
		press("interact")
		await frames(2)
		if not gs.dialogue_open:
			break
	check(gs.quest_done, "opdracht voltooid")
	check(gs.ended, "spel is afgelopen (gewonnen)")

	print("Game over")
	gs.reset()
	gs.hurt(gs.MAX_HP)
	check(gs.ended and gs.hp == 0, "game over bij 0 hartjes")

	print("Herstart met R")
	current_scene = main
	press("restart")
	await frames(4)
	check(not is_instance_valid(main), "oude wereld is weggehaald")
	check(current_scene != null and current_scene != main, "nieuwe wereld geladen")
	check(not gs.ended and gs.hp == gs.MAX_HP and gs.crystals == 0 and gs.coins == 0, "spelstatus is gereset")
	check(not gs.quest_started and not gs.dialogue_open, "quest is gereset")
	check(get_nodes_in_group("enemies").size() == 8, "alle 8 slijmen zijn terug")
	var fresh_crystals := get_nodes_in_group("pickups").filter(func(p): return p.kind == "crystal")
	check(fresh_crystals.size() == 4, "alle 4 kristallen zijn terug")

	print("")
	if failures == 0:
		print("SMOKE TEST OK")
		quit(0)
	else:
		print("SMOKE TEST: %d fout(en)" % failures)
		quit(1)
