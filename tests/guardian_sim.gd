extends SceneTree
## Balans-simulatie voor De Vergeten Wachter: een zorgvuldige bot vecht steeds opnieuw tegen de baas, met verschillende
## zwaarden en hartjes. Zo zie je of het gevecht eerlijk is. Het doel: met het kristalzwaard en 6 tot 8 hartjes wint
## de bot in ongeveer 50 tot 75 procent van de pogingen.
##
##   godot --headless --fixed-fps 60 --path . -s tests/guardian_sim.gd
##   (optioneel: GUARDIAN_EPISODES=20 voor meer pogingen per instelling)
##
## Gemeten (24 pogingen per rij): met het kristalzwaard en 6, 7 of 8 hartjes wint de bot 71%, 67% en 79% van de pogingen; met
## een ijzeren zwaard en 7 hartjes 33%, met het Sterrenzwaard en 8 hartjes 92%. Elk gevecht duurt dan 1 tot 2 minuten.
##
## De bot ontwijkt de rode banen en klappen, rolt door scherven, valt aan als de baas moe is en drinkt een drankje als hij
## bijna dood is. Hij heeft een reactietijd en maakt soms een foutje, zoals een mens. Elke poging heeft een vaste
## willekeurige reeks (seed), dus dezelfde instellingen geven steeds dezelfde uitkomst.

const MAX_SECONDS := 240.0 # langer dan dit is een mislukte poging (de baas mag nooit onoverwinnelijk zijn)
const FOOT := Vector2(0, 14)
const REACT_MIN := 0.22 # de bot ziet een aankondiging pas na zo'n reactietijd (seconden)
const REACT_MAX := 0.50
const BLUNDER := 0.12 # kans dat hij een aanval van de baas niet ziet

var episodes := 8
var gs: Node
var world: Node2D


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


func steer(direction: Vector2) -> void:
	# Analoge besturing, net als een stick.
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if direction.length() < 0.05:
		return
	var d := direction.normalized()
	if d.x < -0.1:
		Input.action_press("move_left", -d.x)
	if d.x > 0.1:
		Input.action_press("move_right", d.x)
	if d.y < -0.1:
		Input.action_press("move_up", -d.y)
	if d.y > 0.1:
		Input.action_press("move_down", d.y)


func setup(weapon: String, containers: int, potions: int) -> void:
	gs.new_game()
	gs.in_game = true
	gs.weapon = weapon
	if containers > 0:
		gs.give("heart_container", containers, true)
	gs.give("potion", potions, true)
	gs.full_heal()
	gs.set_flag("game_completed")
	gs.set_flag("diepte_opened")
	gs.map_id = "depths2"
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(6)


## Een gevecht. Geeft {won, seconds, damage, potions, by} terug.
func fight(weapon: String, containers: int, potions: int, episode: int) -> Dictionary:
	seed(7000 + episode * 31 + containers * 7 + weapon.length())
	await setup(weapon, containers, potions)
	var player = world.player
	var boss: Node2D = null
	for b in get_nodes_in_group("boss"):
		boss = b
	player.global_position = Vector2(13 * 32 + 16, 14 * 32 + 16)
	player.invuln = 0.0
	gs.set_flag("guardian_started")
	gs.damage_log = {}
	var frames_run := 0
	var potions_used := 0
	var damage_taken := 0
	var last_hp: int = gs.hp
	var react_until := 0.0
	var last_state := ""
	var blind := false
	var side := 1.0
	var last_boss_hp: int = boss.hp
	var hits_by_state := {}
	var time_by_state := {}
	while frames_run < int(MAX_SECONDS * 60.0):
		await process_frame
		frames_run += 1
		if gs.ended or not is_instance_valid(boss) or boss.dead:
			break
		if gs.hp < last_hp:
			damage_taken += last_hp - gs.hp
		last_hp = gs.hp
		if OS.get_environment("GUARDIAN_TRACE") != "" and frames_run % 300 == 0:
			print("    t=%.0fs hp=%d boss=%d/%d fase %d %s schervenaantal %d" % [float(frames_run) / 60.0, gs.hp, boss.hp, boss.max_hp, boss.phase, boss.state, get_nodes_in_group("guardian_shards").size()])
		if boss.hp < last_boss_hp:
			var key := "%d:%s" % [boss.phase, boss.state]
			hits_by_state[key] = int(hits_by_state.get(key, 0)) + 1
		last_boss_hp = boss.hp
		var tkey := "%d:%s" % [boss.phase, boss.state]
		time_by_state[tkey] = float(time_by_state.get(tkey, 0.0)) + 1.0 / 60.0
		if boss.state != last_state:
			last_state = boss.state
			react_until = randf_range(REACT_MIN, REACT_MAX)
			blind = randf() < BLUNDER
			side = 1.0 if randf() < 0.5 else -1.0
		if gs.hp <= 2 and gs.count("potion") > 0 and frames_run % 20 == 0:
			press("potion")
			potions_used += 1
		var plan := think(boss, player, react_until, blind, side)
		steer(plan["move"])
		if plan["roll"]:
			press("dodge")
		if plan["attack"] and player.cooldown <= 0.0 and not player.is_rolling():
			player.facing = plan["face"]
			press("attack")
	steer(Vector2.ZERO)
	var won: bool = not gs.ended and (not is_instance_valid(boss) or boss.dead)
	var seconds := float(frames_run) / 60.0
	var by: Dictionary = gs.damage_log.duplicate()
	world.queue_free()
	await frames(3)
	return {"won": won, "seconds": seconds, "damage": damage_taken, "potions": potions_used, "by": by, "hits": hits_by_state, "times": time_by_state}


func can_roll(player: Node2D) -> bool:
	return player.roll_cooldown <= 0.0 and not player.is_rolling()


## Wat de bot nu doet: {move, roll, attack, face}.
func think(boss: Node2D, player: Node2D, react: float, blind: bool, side: float) -> Dictionary:
	var plan := {"move": Vector2.ZERO, "roll": false, "attack": false, "face": player.facing}
	var feet: Vector2 = player.global_position + FOOT
	var to_boss: Vector2 = boss.global_position - player.global_position
	var dist := to_boss.length()
	var reach: float = gs.reach()
	var danger := false

	# 1. De rode baan van de storm
	if (boss.state == "charge_windup" or boss.state == "charge_dash") and not blind and (boss.state == "charge_dash" or boss.state_time >= react):
		var from: Vector2 = boss.global_position + FOOT
		var rel := feet - from
		var along := rel.dot(boss.aim_dir)
		var lateral := rel.cross(boss.aim_dir)
		var half: float = boss.radius + 9.0
		if along > -30.0 and along < boss.line_length + 40.0 and absf(lateral) < half + 26.0:
			danger = true
			var out_dir: Vector2 = boss.aim_dir.orthogonal() * (signf(lateral) if absf(lateral) > 3.0 else side)
			plan["move"] = out_dir
			if boss.state == "charge_dash" and absf(lateral) < half + 4.0 and along > -20.0 and along < 150.0 and can_roll(player):
				plan["roll"] = true

	# 2. De klap
	if boss.state == "slam_windup" and not blind and boss.state_time >= react and not danger:
		var radius: float = boss.SLAM_RADIUS
		if dist < radius + 26.0:
			danger = true
			plan["move"] = -to_boss.normalized()
			var left: float = boss.PHASES[boss.phase - 1]["slam_windup"] - boss.state_time
			if left < 0.16 and dist < radius + 2.0 and can_roll(player):
				plan["roll"] = true

	# 3. Scherven: een gat zoeken of erdoorheen rollen
	var shard_move := Vector2.ZERO
	for shard in get_nodes_in_group("guardian_shards"):
		if shard.age < react * 0.6:
			continue # net afgeschoten: de bot heeft hem nog niet gezien
		var rel: Vector2 = shard.global_position - player.global_position
		var v: Vector2 = shard.velocity
		var t_closest := -rel.dot(v) / maxf(v.length_squared(), 1.0)
		if t_closest < 0.0 or t_closest > 0.5:
			continue
		var closest := rel + v * t_closest
		if closest.length() < 24.0:
			danger = true
			if t_closest < 0.2 and can_roll(player):
				plan["roll"] = true
			shard_move += -closest.normalized() if closest.length() > 1.0 else v.orthogonal().normalized()
	if shard_move != Vector2.ZERO:
		plan["move"] = shard_move.normalized()

	# 4. De rode lijnen van de pilaren: uit de baan van de scherven blijven
	if not danger:
		for pillar in boss.pillars:
			if not is_instance_valid(pillar) or not pillar.charging or pillar.windup <= 0.0 or pillar.windup_total - pillar.windup < react:
				continue
			var rel: Vector2 = player.global_position - pillar.global_position
			if rel.length() > 260.0:
				continue
			var angle := rel.angle()
			var blocked := false
			for a: float in pillar.angles:
				if absf(angle_difference(angle, a)) * rel.length() < 28.0:
					blocked = true
			if blocked:
				# loop zijwaarts naar het dichtstbijzijnde gat
				var best_turn := 0.0
				for step in range(1, 40):
					var test := angle + float(step) * 0.05 * side
					var free := true
					for a: float in pillar.angles:
						if absf(angle_difference(test, a)) * rel.length() < 34.0:
							free = false
					if free:
						best_turn = float(step) * 0.05 * side
						break
				plan["move"] = rel.orthogonal().normalized() * signf(best_turn if best_turn != 0.0 else side)
				danger = true

	# 5. Aanvallen als het veilig is
	if not danger:
		var vulnerable: bool = boss.state in ["recover", "stunned", "slam_recover", "idle", "charge_windup", "slam_windup"]
		var want: float = reach + boss.radius - 12.0
		var attack_range: float = reach + boss.radius - 4.0
		if boss.state in ["waking", "phase_shift"]:
			plan["move"] = Vector2.ZERO if dist > 120.0 else -to_boss.normalized()
		elif boss.state == "charge_dash":
			plan["move"] = Vector2.ZERO
		elif boss.state in ["charge_windup", "slam_windup"]:
			# de baas maakt zich klaar: op afstand blijven staan, buiten de baan en de klap
			plan["move"] = Vector2.ZERO if dist > 100.0 else -to_boss.normalized()
		elif vulnerable:
			if boss.state == "idle" and dist < 56.0:
				plan["move"] = -to_boss.normalized() # niet tegen hem aan lopen
			elif dist > want:
				plan["move"] = to_boss.normalized()
			if dist < attack_range:
				plan["attack"] = true
				plan["face"] = to_boss.normalized()
	return plan


func _run() -> void:
	gs = root.get_node("GameState")
	if OS.get_environment("GUARDIAN_EPISODES") != "":
		episodes = int(OS.get_environment("GUARDIAN_EPISODES"))
	var configs := [
		["crystal", 1, 3], ["crystal", 2, 3], ["crystal", 3, 3], ["iron", 2, 3], ["star", 3, 3],
	]
	if OS.get_environment("GUARDIAN_CONFIG") != "":
		var one := OS.get_environment("GUARDIAN_CONFIG").split(",")
		configs = [[one[0], int(one[1]), int(one[2])]]
	for config in configs:
		var wins := 0
		var total_time := 0.0
		var total_damage := 0
		var total_potions := 0
		var by_source := {}
		var hits := {}
		var times := {}
		for i in episodes:
			var result: Dictionary = await fight(config[0], config[1], config[2], i)
			if OS.get_environment("GUARDIAN_VERBOSE") != "":
				print("  poging %d: %s na %.0fs, schade %d" % [i, "gewonnen" if result["won"] else "verloren", result["seconds"], result["damage"]])
			if result["won"]:
				wins += 1
				total_time += result["seconds"]
			total_damage += result["damage"]
			total_potions += result["potions"]
			for src in result["by"]:
				by_source[src] = int(by_source.get(src, 0)) + int(result["by"][src])
			for k in result["hits"]:
				hits[k] = int(hits.get(k, 0)) + int(result["hits"][k])
			for k in result["times"]:
				times[k] = float(times.get(k, 0.0)) + float(result["times"][k])
		print("zwaard %-8s hartjes %d  drankjes %d:  gewonnen %d/%d  gem. tijd %5.1fs  schade/gevecht %.1f  drankjes/gevecht %.1f" % [
			config[0], 5 + config[1], config[2], wins, episodes, total_time / maxf(float(wins), 1.0),
			float(total_damage) / episodes, float(total_potions) / episodes])
		var parts: Array = []
		for src in by_source:
			parts.append("%s %.1f" % [src, float(by_source[src]) / episodes])
		print("        schade per bron: ", ", ".join(parts))
		if OS.get_environment("GUARDIAN_VERBOSE") != "":
			var keys := hits.keys()
			keys.sort()
			var lines: Array = []
			for k in keys:
				lines.append("%s %.1f" % [k, float(hits[k]) / episodes])
			print("        klappen per toestand: ", ", ".join(lines))
			var tkeys := times.keys()
			tkeys.sort()
			var tl: Array = []
			for k in tkeys:
				tl.append("%s %.1fs" % [k, float(times[k]) / episodes])
			print("        tijd per toestand: ", ", ".join(tl))
	quit()
