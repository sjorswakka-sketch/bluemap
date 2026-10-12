extends SceneTree
## Balans-simulatie voor de arena: een eenvoudige bot speelt Brons, Zilver en Goud steeds opnieuw met het echte
## toernooi (arena_master) en verschillende zwaarden en hartjes. Zo zie je of de rangen eerlijk zijn.
##
##   godot --headless --fixed-fps 60 --path . -s tests/arena_sim.gd
##   EPISODES=20 godot --headless --fixed-fps 60 --path . -s tests/arena_sim.gd     (meer rondjes per instelling)
##
## Doel: een redelijke speler met het passende zwaard haalt Brons ongeveer 90% van de keren, Zilver ongeveer 65% en
## Goud ongeveer 40%. De bot is die redelijke speler: hij loopt op de dichtstbijzijnde vijand af en slaat, rolt meestal
## weg voor duikende vleermuizen en pijlen, wijkt uit voor de klap van de golem en drinkt een drankje als hij bijna
## dood is. Hij kijkt niet vooruit en houdt geen afstand: hij reageert pas na een paar beeldjes en mist soms een
## uitwijkmoment, net als een gewone speler. (Een perfecte bot die elke slijm op afstand houdt haalt alles altijd.)
## Referentie-instellingen (de eerste drie): Brons met het ijzeren zwaard en 5 hartjes, Zilver met het ijzeren zwaard en
## 6 hartjes, Goud met het kristalzwaard en 7 hartjes, steeds met 2 drankjes. Laatste meting (Brons 160 beurten, Zilver en
## Goud 80): Brons 91%, Zilver 62%, Goud 40%. Het zwaard maakt veel uit: Brons met het houten zwaard lukt maar 12% van de
## keren (daarom moet je voor de arena een ijzeren zwaard hebben), Goud met het ijzeren zwaard helemaal niet.
## Dit bestand heet geen *_test.gd, dus run_tests.sh slaat het over.

const MAX_SECONDS := 900.0
const DEFAULT_EPISODES := 12
const REACTION := 9 # de bot beslist maar eens per zoveel beeldjes (0,15 seconde)
const DODGE_CHANCE := 0.55 # kans dat hij een aanval (duik, pijl) op tijd ziet en wegrolt

var gs: Node
var world: Node2D
var Arena: GDScript


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


## Een toernooi spelen. Geeft [gewonnen, seconden, schade, drankjes, ronde waar het misging, schade per bron] terug.
func play(rank: String, weapon: String, containers: int, potions: int, episode: int) -> Array:
	gs.new_game()
	gs.in_game = true
	gs.weapon = weapon
	gs.start_quest("main")
	if containers > 0:
		gs.give("heart_container", containers, true)
	gs.give("potion", potions, true)
	gs.full_heal()
	gs.damage_log = {}
	gs.map_id = "arena_hall"
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)
	gs.set_flag(Arena.SIGNED_FLAG % rank)
	world.load_map("arena", "from_hall")
	await frames(3)
	var m: Node = get_first_node_in_group("arena_master")
	m.rng.seed = 9000 + episode # zelfde volgorde van poorten en vijanden bij elke herhaling van de simulatie
	m.timer = 0.0
	var player: Node2D = world.player
	var damage_taken := 0
	var potions_used := 0
	var last_hp: int = gs.hp
	var dodge_dir := 1.0
	var frame := 0
	var center := Vector2(12.5 * 32.0, 10.5 * 32.0)
	var move := Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + frame
	while frame < int(MAX_SECONDS * 60.0):
		await process_frame
		frame += 1
		if not is_instance_valid(m) or m.phase == "done" or m.phase == "defeat" or gs.ended:
			break
		if gs.hp < last_hp:
			damage_taken += last_hp - gs.hp
		last_hp = gs.hp
		if gs.hp <= 2 and gs.count("potion") > 0 and frame % 30 == 0:
			press("potion")
			potions_used += 1
		if frame % REACTION == 0:
			move = _decide(m, player, rng, dodge_dir)
			if m.phase == "intro" or m.phase == "rest" or m.foes.is_empty():
				move = (center - player.global_position) * 0.02 if player.global_position.distance_to(center) > 40.0 else Vector2.ZERO
			steer(move)
		if frame % 150 == 0:
			dodge_dir = -dodge_dir
	steer(Vector2.ZERO)
	var won: bool = m.phase == "done"
	var failed_round: int = m.round_index + 1
	var seconds: float = m.run_time
	world.queue_free()
	await frames(3)
	return [won, seconds, damage_taken, potions_used, failed_round, gs.damage_log.duplicate()]


## De bot beslist waar hij heen loopt en wanneer hij slaat of rolt.
func _decide(m: Node, player: Node2D, rng: RandomNumberGenerator, dodge_dir: float) -> Vector2:
	var foes: Array = []
	for enemy in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.dead and enemy.active:
			foes.append(enemy)
	var here: Vector2 = player.global_position

	# Pijlen en stenen: soms zie je ze op tijd en stap je opzij en rol je weg.
	for child in world.entities.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with("projectile.gd") and child.global_position.distance_to(here) < 60.0:
			if rng.randf() < DODGE_CHANCE:
				var side: Vector2 = (here - child.global_position).orthogonal().normalized() * dodge_dir
				steer(side)
				press("dodge")
				return side

	if foes.is_empty():
		return Vector2.ZERO

	# Golem: tijdens de aanloop van zijn klap wegrennen.
	for enemy in foes:
		if enemy.kind == "golem" and enemy.state == "windup" and enemy.global_position.distance_to(here) < 100.0:
			return (here - enemy.global_position).normalized()

	# Duikende vleermuis: soms op tijd wegrollen.
	for enemy in foes:
		if enemy.kind == "bat" and enemy.state == "dash" and enemy.global_position.distance_to(here) < 70.0 and player.roll_cooldown <= 0.0 and rng.randf() < DODGE_CHANCE:
			var side: Vector2 = (here - enemy.global_position).orthogonal().normalized() * dodge_dir
			steer(side)
			press("dodge")
			return side

	# Het dichtstbijzijnde gevaar bevechten.
	var target: Node2D = foes[0]
	var best := INF
	for enemy in foes:
		var d: float = enemy.global_position.distance_to(here)
		if d < best:
			best = d
			target = enemy
	var to_target: Vector2 = target.global_position - here
	var reach: float = gs.reach() + target.radius
	if best < reach and player.cooldown <= 0.0:
		player.facing = to_target.normalized()
		press("attack")
	if best > reach * 0.75:
		return to_target.normalized()
	return Vector2.ZERO


func _run() -> void:
	gs = root.get_node("GameState")
	Arena = load("res://scripts/data/arena.gd")
	var episodes := int(OS.get_environment("EPISODES")) if OS.get_environment("EPISODES") != "" else DEFAULT_EPISODES
	var only := OS.get_environment("ONLY")
	# [rang, zwaard, hartjescontainers, drankjes]. De eerste van elke rang is de referentie: Brons met het ijzeren zwaard en
	# 5 hartjes, Zilver met het ijzeren zwaard en 6 hartjes, Goud met het kristalzwaard en 7 hartjes (alles met 2 drankjes).
	var configs := [
		["bronze", "iron", 0, 2], ["silver", "iron", 1, 2], ["gold", "crystal", 2, 2],
		["bronze", "wood", 0, 2], ["bronze", "crystal", 0, 2], ["silver", "iron", 0, 2], ["silver", "iron", 2, 2],
		["silver", "crystal", 1, 2], ["gold", "crystal", 0, 2], ["gold", "crystal", 1, 2], ["gold", "iron", 2, 2],
	]
	if OS.get_environment("REF") != "":
		configs = configs.slice(0, 3)
	for config: Array in configs:
		if only != "" and not (only in "%s-%s-%d" % [config[0], config[1], config[2]]):
			continue
		var wins := 0
		var total_time := 0.0
		var total_damage := 0
		var total_potions := 0
		var failed_rounds: Array = []
		var by_source := {}
		for i in episodes:
			seed(1000 + i * 17)
			var result: Array = await play(config[0], config[1], config[2], config[3], i)
			if result[0]:
				wins += 1
				total_time += result[1]
			else:
				failed_rounds.append(result[4])
			total_damage += result[2]
			total_potions += result[3]
			for source: String in result[5]:
				by_source[source] = int(by_source.get(source, 0)) + int(result[5][source])
		var sources: Array = []
		for source: String in by_source:
			sources.append("%s %.1f" % [source, float(by_source[source]) / episodes])
		print("%-6s zwaard %-8s hartjes %d drankjes %d:  gehaald %2d/%d (%3d%%)  gem. tijd %5.1fs  schade %.1f  drankjes %.1f  verloren in ronde %s" % [
			config[0], config[1], 5 + config[2], config[3], wins, episodes, 100 * wins / episodes,
			total_time / maxf(float(wins), 1.0), float(total_damage) / episodes, float(total_potions) / episodes, failed_rounds])
		print("          schade per bron: ", ", ".join(sources))
	quit()
