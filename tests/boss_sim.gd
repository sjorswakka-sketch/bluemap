extends SceneTree
## Balans-simulatie: een eenvoudige bot speelt het baasgevecht tegen de Slijmkoning (en de golem)
## steeds opnieuw, met verschillende zwaarden en hartjes. Zo zie je of het gevecht eerlijk is.
##
##   godot --headless --fixed-fps 60 --path . -s tests/boss_sim.gd
##
## De bot is een beginnende speler: hij ontwijkt na de aanloop van de baas, valt aan als de baas
## rustig is, rolt weg voor kogels en drinkt een drankje als hij bijna dood is.

const MAX_SECONDS := 150.0
const EPISODES := 6

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


func setup(map_id: String, weapon: String, containers: int, potions: int) -> void:
	gs.new_game()
	gs.in_game = true
	gs.weapon = weapon
	if containers > 0:
		gs.give("heart_container", containers, true)
	gs.give("potion", potions, true)
	gs.full_heal()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)
	world.load_map(map_id, "start")
	await frames(5)
	for obj in get_nodes_in_group("enemies"):
		if obj.kind != "king" and map_id == "temple":
			obj.queue_free()


## Speelt een gevecht. Geeft [gewonnen, seconden, schade, drankjes] terug.
func fight(boss_kind: String, weapon: String, containers: int, potions: int) -> Array:
	var map_id := "temple" if boss_kind == "king" else "ruins"
	await setup(map_id, weapon, containers, potions)
	var player = world.player
	var boss: Node2D = null
	for enemy in get_nodes_in_group("boss"):
		if enemy.kind == boss_kind:
			boss = enemy
	if boss_kind == "king":
		player.global_position = Vector2(11 * 32 + 16, 13 * 32 + 16)
		gs.set_flag("boss_started")
		gs.run(["boss_start"])
	else:
		player.global_position = boss.global_position + Vector2(-110, 40)
	var start_hp: int = gs.hp
	var damage_taken := 0
	var potions_used := 0
	var last_hp: int = gs.hp
	var dodge_dir := 1.0
	var frames_run := 0
	var pause_attack := 0
	while frames_run < int(MAX_SECONDS * 60.0):
		await process_frame
		frames_run += 1
		if gs.ended or not is_instance_valid(boss) or boss.dead:
			break
		if gs.hp < last_hp:
			damage_taken += last_hp - gs.hp
		last_hp = gs.hp
		var to_boss: Vector2 = boss.global_position - player.global_position
		var dist := to_boss.length()
		var reach: float = gs.reach()
		var move := Vector2.ZERO
		var danger := false

		# Drankje als het bijna misgaat
		if gs.hp <= 2 and gs.count("potion") > 0 and frames_run % 20 == 0:
			press("potion")
			potions_used += 1

		# Aanloop en sprong: wegrennen van de plek waar hij landt
		if boss.state == "crouch" or boss.state == "hop":
			danger = true
			var landing: Vector2 = boss.hop_to if boss.state == "hop" else player.global_position
			var shock: float = 56.0
			if boss_kind == "king":
				shock = 64.0 + (10.0 if boss._king_phase() >= 2 else 0.0) + (12.0 if boss._king_phase() == 3 else 0.0)
			var away: Vector2 = player.global_position - landing
			if away.length() < shock + 36.0:
				if away.length() < 4.0:
					away = Vector2.from_angle(randf() * TAU)
				move = away.normalized().rotated(0.5 * dodge_dir)
			else:
				danger = false

		# Kogels ontwijken
		var close_projectile := false
		for child in world.entities.get_children():
			var script: Script = child.get_script()
			if script and script.resource_path.ends_with("projectile.gd") and child.global_position.distance_to(player.global_position) < 52.0:
				close_projectile = true
				if frames_run % 4 == 0:
					player.roll_cooldown = player.roll_cooldown  # (de bot mag gewoon rollen)
					press("dodge")
				move = (player.global_position - child.global_position).orthogonal().normalized() * dodge_dir
		if close_projectile:
			danger = true

		if not danger:
			# Golem: eerst een stukje naast hem blijven, slaan als hij net geslagen heeft
			var want := reach * 0.75
			if boss_kind == "golem" and boss.state == "windup":
				move = -to_boss.normalized()
			elif dist > want:
				move = to_boss.normalized()
			else:
				move = Vector2.ZERO
			if dist < reach + boss.radius - 4.0 and player.cooldown <= 0.0:
				player.facing = to_boss.normalized()
				pause_attack += 1
				press("attack")
		steer(move)
		if frames_run % 180 == 0:
			dodge_dir = -dodge_dir
	steer(Vector2.ZERO)
	var won: bool = (is_instance_valid(boss) and boss.dead) or not is_instance_valid(boss)
	var seconds := float(frames_run) / 60.0
	if gs.ended:
		won = false
	world.queue_free()
	await frames(3)
	return [won, seconds, damage_taken, potions_used, start_hp]


func _run() -> void:
	gs = root.get_node("GameState")
	var configs := [
		["king", "wood", 0, 3], ["king", "iron", 0, 3], ["king", "iron", 1, 3], ["king", "crystal", 0, 3],
		["king", "crystal", 1, 3], ["golem", "wood", 0, 2], ["golem", "iron", 0, 2],
	]
	for config in configs:
		var wins := 0
		var total_time := 0.0
		var total_damage := 0
		var total_potions := 0
		for i in EPISODES:
			var result: Array = await fight(config[0], config[1], config[2], config[3])
			if result[0]:
				wins += 1
				total_time += result[1]
			total_damage += result[2]
			total_potions += result[3]
		var avg_time := total_time / maxf(float(wins), 1.0)
		print("%-6s zwaard %-8s hartjes %d  drankjes %d:  gewonnen %d/%d  gem. tijd %5.1fs  schade/gevecht %.1f  drankjes/gevecht %.1f" % [
			config[0], config[1], 5 + config[2], config[3], wins, EPISODES, avg_time, float(total_damage) / EPISODES, float(total_potions) / EPISODES])
	quit()
