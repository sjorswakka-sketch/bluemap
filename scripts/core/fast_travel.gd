extends RefCounted
## Snel reizen tussen de blauwe altaren. Een altaar is "ontdekt" zodra je het gebruikt hebt (een vlag, die
## wordt opgeslagen). Het kaarttabblad van het menu (scripts/ui/menu_ui.gd) toont de ontdekte altaren en
## roept `travel()` aan. Waar je aankomt staat in de kaart: een spawnpunt "altar" (of `"spawn": "naam"` bij het
## altaar zelf). Ontbreekt dat, dan wordt de dichtstbijzijnde vrije tegel naast het altaar gebruikt.

const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")

const TILE := 32 # grootte van een tegel in de wereld (zie world.gd)
const BOSS_RANGE := 360.0 # zo dichtbij een baas is het een baasgevecht (net als de baasbalk in beeld)
const FADE := 0.35 # seconden naar zwart en terug
## Objecten waar je niet op kunt staan: daar komen we niet aan bij het reizen.
const BLOCKING := ["npc", "chest", "sign", "gate", "savepoint", "wereld_lantaarn"]


## De vlag die onthoudt dat het altaar op deze plek ontdekt is.
static func altar_key(map_id: String, tile: Vector2i) -> String:
	return "altaar_%s_%d_%d" % [map_id, tile.x, tile.y]


## Alle altaren in alle kaarten, in de volgorde van de kaarten. Elk altaar:
## {map, name, key, tile (Vector2i), spawn (naam van het spawnpunt), pos (aankomstplek in de wereld)}.
static func all_altars() -> Array[Dictionary]:
	var altars: Array[Dictionary] = []
	for map_id: String in Maps.MAPS:
		var def: Dictionary = Maps.get_map(map_id)
		for obj: Dictionary in def["objects"]:
			if obj["type"] != "savepoint":
				continue
			var tile := Vector2i(int(obj["pos"][0]), int(obj["pos"][1]))
			var arrival := arrival_tile(def, obj)
			var spawn_name: String = obj.get("spawn", "altar")
			altars.append({
				"map": map_id, "name": def["name"], "key": altar_key(map_id, tile), "tile": tile,
				"spawn": spawn_name if def["spawns"].has(spawn_name) else "start",
				"pos": Vector2(arrival.x * TILE + TILE / 2.0, arrival.y * TILE + TILE / 2.0),
			})
	return altars


## De altaren die de speler heeft ontdekt.
static func discovered_altars() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for altar in all_altars():
		if GameState.flag(altar["key"]):
			found.append(altar)
	return found


## De tegel waar je aankomt bij een altaar: het spawnpunt uit de kaart, anders de dichtstbijzijnde vrije tegel.
static func arrival_tile(def: Dictionary, altar_obj: Dictionary) -> Vector2i:
	var spawns: Dictionary = def["spawns"]
	var spawn_name: String = altar_obj.get("spawn", "altar")
	if spawns.has(spawn_name):
		return Vector2i(int(spawns[spawn_name][0]), int(spawns[spawn_name][1]))
	var rows: Array = def["rows"]
	var taken := {}
	for obj: Dictionary in def["objects"]:
		if obj["type"] in BLOCKING:
			var size: Array = obj.get("size", [1, 1])
			for dx in int(size[0]):
				for dy in int(size[1]):
					taken[Vector2i(int(obj["pos"][0]) + dx, int(obj["pos"][1]) + dy)] = true
	var center := Vector2i(int(altar_obj["pos"][0]), int(altar_obj["pos"][1]))
	for radius in range(1, 6):
		# Eerst onder het altaar (daar sta je het mooist), dan opzij en erboven.
		for offset: Vector2i in _ring(radius):
			var tile := center + offset
			if tile.y < 0 or tile.y >= rows.size() or tile.x < 0 or tile.x >= String(rows[tile.y]).length():
				continue
			if not Tiles.is_solid_char(String(rows[tile.y])[tile.x]) and not taken.has(tile):
				return tile
	return Vector2i(int(spawns["start"][0]), int(spawns["start"][1]))


## Alle tegels op precies `radius` vakjes van het midden, de tegels onder het altaar eerst.
static func _ring(radius: int) -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if maxi(absi(dx), absi(dy)) == radius:
				ring.append(Vector2i(dx, dy))
	ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _preference(a) < _preference(b))
	return ring


## Lager = liever: eerst onder het altaar, dan ernaast, dan erboven; en liefst recht eronder.
static func _preference(offset: Vector2i) -> int:
	var side := 0 if offset.y > 0 else 1 if offset.y == 0 else 2
	return side * 100 + absi(offset.x) * 10 + absi(offset.y)


## Waarom je nu niet kunt reizen (een melding voor de speler), of "" als het mag.
static func blocked_reason(world: Node) -> String:
	if GameState.ended:
		return "Je kunt nu niet reizen."
	if GameState.transitioning:
		return "Wacht even, je bent al onderweg."
	if GameState.dialogue_open:
		return "Je kunt niet reizen tijdens een gesprek."
	for owner_name: String in GameState.ui_owners:
		if owner_name != "menu":
			return "Je kunt nu niet reizen."
	if boss_fight(world):
		return "Je kunt niet reizen tijdens een baasgevecht!"
	if discovered_altars().is_empty():
		return "Je hebt nog geen altaar ontdekt."
	return ""


## Is er een baasgevecht bezig? Een baas die je moet starten (de Slijmkoning) telt zodra hij wakker is,
## een baas die altijd wakker is (een golem) pas als je dichtbij bent.
## Een verslagen baas die nog in beeld is telt ook: de Slijmkoning verdwijnt langzaam en daarna begint het einde.
## Zou je dan wegreizen, dan verdwijnt hij met de oude kaart en komt het einde nooit.
static func boss_fight(world: Node) -> bool:
	for boss: Node2D in world.get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(boss) or boss.is_queued_for_deletion():
			continue
		if boss.dead:
			return true
		if not boss.active:
			continue
		if boss.data.get("start_inactive", false) or boss.global_position.distance_to(world.player.global_position) < BOSS_RANGE:
			return true
	return false


## Reist naar een ontdekt altaar: fade, kaart laden, opslaan. Geeft false terug als het niet mocht.
## Een altaar op de kaart waar je al bent: dan verplaatsen we alleen jou. De kaart opnieuw laden zou alle
## verslagen vijanden en opgeraapte muntjes terugbrengen.
static func travel(world: Node, altar: Dictionary) -> bool:
	var reason := blocked_reason(world)
	if reason == "" and not GameState.flag(altar["key"]):
		reason = "Dat altaar heb je nog niet ontdekt."
	if reason != "":
		GameState.toast.emit(reason)
		Sound.play("error", -3.0)
		return false
	GameState.transitioning = true
	Sound.play("wereld_reis")
	await world.fader.fade_out(FADE)
	if GameState.ended:
		# Onderweg verslagen (een vijand raakte je nog tijdens het zwart worden): dan reis je niet en slaan we niets op.
		await world.fader.fade_in(FADE)
		GameState.transitioning = false
		return false
	if altar["map"] == GameState.map_id:
		_move_player(world, altar["pos"])
	else:
		world.load_map(altar["map"], altar["spawn"], altar["pos"])
	GameState.set_flag("wereld_snel_gereisd")
	world.autosave()
	world.ring(altar["pos"], 44.0, Color(0.5, 0.85, 1.0))
	await world.fader.fade_in(FADE)
	GameState.transitioning = false
	return true


## Zet de speler neer op een andere plek van dezelfde kaart (zoals load_map dat doet, maar zonder de kaart te herladen).
static func _move_player(world: Node, pos: Vector2) -> void:
	var player: Node2D = world.player
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.knockback = Vector2.ZERO
	player.camera.reset_smoothing()
