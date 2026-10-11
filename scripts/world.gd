extends Node2D
## De wereld. Laadt kaarten (scripts/maps/), zet alles neer (personages, vijanden, voorwerpen,
## poortjes, kisten...) en houdt de speler, camera, belichting en overgangen bij.
##
## De kaarten zelf staan als tekst in scripts/maps/*.gd (zie README).

const PlayerScript := preload("res://scripts/entities/player.gd")
const EnemyScript := preload("res://scripts/entities/enemy.gd")
const NpcScript := preload("res://scripts/entities/npc.gd")
const PickupScript := preload("res://scripts/entities/pickup.gd")
const PortalScript := preload("res://scripts/entities/portal.gd")
const ChestScript := preload("res://scripts/entities/chest.gd")
const SignScript := preload("res://scripts/entities/sign.gd")
const GateScript := preload("res://scripts/entities/gate.gd")
const SavepointScript := preload("res://scripts/entities/savepoint.gd")
const TorchScript := preload("res://scripts/entities/torch.gd")
const ProjectileScript := preload("res://scripts/entities/projectile.gd")
const TriggerScript := preload("res://scripts/entities/trigger.gd")
const FxScript := preload("res://scripts/entities/fx.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const PauseScript := preload("res://scripts/ui/pause_menu.gd")
const DialogueScript := preload("res://scripts/ui/dialogue_box.gd")
const ShopScript := preload("res://scripts/ui/shop_ui.gd")
const MenuScript := preload("res://scripts/ui/menu_ui.gd")
const FaderScript := preload("res://scripts/ui/fader.gd")
const Art := preload("res://scripts/core/art.gd")
const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Content := preload("res://scripts/data/content.gd")

const TILE := 32 # grootte van een tegel in de spelwereld
const ART_TILE := 16 # pixels per tegel in assets/tiles.png (wordt 2x vergroot getoond)
const VIEW := Vector2(576, 324) # wat je ziet: 1152x648 gedeeld door de camerazoom (2)
const DARK_COLOR := Color(0.1, 0.12, 0.24)

var player: CharacterBody2D
var ground: Node2D
var entities: Node2D
var fx_layer: Node2D
var canvas_mod: CanvasModulate
var tile_set: TileSet
var tile_layer: TileMapLayer
var fader: CanvasLayer
var hud: CanvasLayer
var dialogue: CanvasLayer
var shop_ui: CanvasLayer
var menu_ui: CanvasLayer
var pause_menu: CanvasLayer
var map_data: Dictionary = {}
var object_types: Dictionary = Content.object_types() # soorten objecten uit uitbreidingen
var map_size := Vector2i.ZERO
var solid_cells: Dictionary = {}
var darkness := 0.0


func _ready() -> void:
	add_to_group("world")
	if not GameState.in_game:
		GameState.new_game()
	GameState.in_game = true
	GameState.ui_owners = {}
	GameState.transitioning = false
	get_tree().paused = false

	ground = Node2D.new()
	add_child(ground)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	fx_layer = Node2D.new()
	fx_layer.z_index = 50
	add_child(fx_layer)
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	_build_tile_set()

	player = PlayerScript.new()
	player.world = self

	hud = HudScript.new()
	add_child(hud)
	dialogue = DialogueScript.new()
	add_child(dialogue)
	shop_ui = ShopScript.new()
	add_child(shop_ui)
	menu_ui = MenuScript.new()
	add_child(menu_ui)
	pause_menu = PauseScript.new()
	add_child(pause_menu)
	fader = FaderScript.new()
	add_child(fader)

	GameState.world_action.connect(_on_world_action)
	GameState.ending_requested.connect(_on_ending)
	GameState.save_requested.connect(autosave)

	if GameState.use_load_pos:
		GameState.use_load_pos = false
		load_map(GameState.map_id, "start", GameState.load_pos)
	else:
		load_map(GameState.map_id, GameState.spawn_name)
	fader.set_alpha(1.0)
	fader.fade_in(0.5)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if GameState.world_action.is_connected(_on_world_action):
		GameState.world_action.disconnect(_on_world_action)
	if GameState.ending_requested.is_connected(_on_ending):
		GameState.ending_requested.disconnect(_on_ending)
	if GameState.save_requested.is_connected(autosave):
		GameState.save_requested.disconnect(autosave)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.ended and event.is_action_pressed("restart"):
		restart_from_save(true)


## Doorgaan vanaf je laatste opslag (of opnieuw beginnen als je nog niet hebt opgeslagen).
func restart_from_save(full_heal := false) -> void:
	if not GameState.load_game():
		GameState.new_game()
	elif full_heal:
		GameState.full_heal()
	GameState.in_game = true
	get_tree().reload_current_scene()


# --- Kaarten ----------------------------------------------------------------------

func load_map(map_id: String, spawn: String, pos_override := Vector2.INF) -> void:
	GameState.map_id = map_id
	GameState.spawn_name = spawn
	map_data = Maps.get_map(map_id)
	_clear_map()
	_build_tiles(map_data["rows"])

	darkness = map_data.get("dark", 0.0)
	canvas_mod.color = Color.WHITE.lerp(DARK_COLOR, darkness)

	if player.get_parent() != entities:
		entities.add_child(player)
	player.set_lit(darkness > 0.0)
	var start: Vector2
	if pos_override != Vector2.INF:
		start = pos_override
	else:
		var spawns: Dictionary = map_data["spawns"]
		start = _tile_center(spawns.get(spawn, spawns["start"]))
	player.global_position = start
	player.velocity = Vector2.ZERO
	player.knockback = Vector2.ZERO
	_set_camera_limits()
	_spawn_objects()
	player.camera.reset_smoothing()

	Sound.play_music(map_data.get("music", "forest"))
	hud.show_banner(map_data["name"])


func travel(map_id: String, spawn: String) -> void:
	if GameState.transitioning:
		return
	GameState.transitioning = true
	Sound.play("door", -4.0)
	await fader.fade_out(0.25)
	load_map(map_id, spawn)
	autosave()
	await fader.fade_in(0.25)
	GameState.transitioning = false


func autosave() -> void:
	GameState.save_game(player.global_position)


func _clear_map() -> void:
	for child in entities.get_children():
		if child != player:
			child.queue_free()
	for child in ground.get_children():
		child.queue_free()
	solid_cells.clear()


func _tile_center(tile: Array) -> Vector2:
	return Vector2(float(tile[0]) * TILE + TILE / 2.0, float(tile[1]) * TILE + TILE / 2.0)


func _set_camera_limits() -> void:
	var map_px := Vector2(map_size) * TILE
	var pad := Vector2(maxf((VIEW.x - map_px.x) / 2.0, 0.0), maxf((VIEW.y - map_px.y) / 2.0, 0.0))
	var cam: Camera2D = player.camera
	cam.limit_left = int(-pad.x)
	cam.limit_top = int(-pad.y)
	cam.limit_right = int(map_px.x + pad.x)
	cam.limit_bottom = int(map_px.y + pad.y)


func is_solid(pos: Vector2) -> bool:
	var cell := Vector2i(int(floorf(pos.x / TILE)), int(floorf(pos.y / TILE)))
	return solid_cells.has(cell) or cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y


func clamp_to_map(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, TILE * 1.5, map_size.x * TILE - TILE * 1.5), clampf(pos.y, TILE * 1.5, map_size.y * TILE - TILE * 1.5))


# --- Tegels ---------------------------------------------------------------------------

func _build_tile_set() -> void:
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(ART_TILE, ART_TILE)
	tile_set.add_physics_layer()
	var source := TileSetAtlasSource.new()
	source.texture = Art.tex("tiles")
	source.texture_region_size = Vector2i(ART_TILE, ART_TILE)
	tile_set.add_source(source, 0)
	var half := ART_TILE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for i in Tiles.NAMES.size():
		source.create_tile(Vector2i(i, 0))
		if Tiles.is_solid_name(Tiles.NAMES[i]):
			var data := source.get_tile_data(Vector2i(i, 0), 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)


func _build_tiles(rows: Array) -> void:
	tile_layer = TileMapLayer.new()
	tile_layer.tile_set = tile_set
	tile_layer.scale = Vector2.ONE * (float(TILE) / ART_TILE)
	ground.add_child(tile_layer)
	map_size = Vector2i(rows[0].length(), rows.size())
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var tile_name := Tiles.name_for(row[x], x, y)
			tile_layer.set_cell(Vector2i(x, y), 0, Vector2i(Tiles.index_of(tile_name), 0))
			if Tiles.is_solid_name(tile_name):
				solid_cells[Vector2i(x, y)] = true


# --- Voorwerpen op de kaart ---------------------------------------------------------

func _spawn_objects() -> void:
	var objects: Array = map_data.get("objects", [])
	for i in objects.size():
		var obj: Dictionary = objects[i]
		if obj.has("if") and not GameState.check_all(obj["if"]):
			continue
		var pos := _tile_center(obj["pos"])
		var key := "%s:%s:%d" % [obj["type"], GameState.map_id, i]
		match obj["type"]:
			"npc":
				var npc: StaticBody2D = NpcScript.new()
				npc.setup(obj["id"])
				npc.world = self
				npc.exists_if = obj.get("exists_if", [])
				npc.position = pos
				entities.add_child(npc)
			"enemy":
				var flag: String = obj.get("flag", "")
				if flag == "" or not GameState.flag(flag):
					spawn_enemy(obj["kind"], pos, flag)
			"pickup":
				var unique: bool = obj.get("unique", false)
				if not (unique and GameState.flag(key)):
					spawn_pickup(obj["item"], pos, key if unique else "")
			"chest":
				var chest: StaticBody2D = ChestScript.new()
				chest.contents = obj["contents"]
				chest.unique_key = key
				chest.world = self
				chest.position = pos
				entities.add_child(chest)
			"sign":
				var sign_node: StaticBody2D = SignScript.new()
				sign_node.lines = obj["lines"]
				sign_node.speaker = obj.get("speaker", "Bord")
				sign_node.world = self
				sign_node.position = pos
				entities.add_child(sign_node)
			"portal":
				var portal: Node2D = PortalScript.new()
				var size: Array = obj.get("size", [1, 1])
				portal.rect = Rect2(Vector2(float(obj["pos"][0]), float(obj["pos"][1])) * TILE, Vector2(float(size[0]), float(size[1])) * TILE)
				portal.target_map = obj["to"]
				portal.target_spawn = obj.get("spawn", "start")
				portal.conditions = obj.get("requires", [])
				portal.locked_text = obj.get("locked_text", "")
				portal.world = self
				entities.add_child(portal)
			"gate":
				var gate: StaticBody2D = GateScript.new()
				var gsize: Array = obj.get("size", [1, 1])
				gate.gate_id = obj["id"]
				gate.size_tiles = Vector2i(gsize[0], gsize[1])
				gate.block_if = obj.get("block_if", [])
				gate.key_item = obj.get("key", "")
				gate.locked_text = obj.get("locked_text", "De poort zit op slot.")
				gate.world = self
				gate.position = pos
				entities.add_child(gate)
			"savepoint":
				var altar: StaticBody2D = SavepointScript.new()
				altar.world = self
				altar.position = pos
				entities.add_child(altar)
			"torch":
				var torch: Node2D = TorchScript.new()
				torch.world = self
				torch.cold = obj.get("glow", "") == "blue"
				torch.position = pos
				entities.add_child(torch)
			"trigger":
				var trigger: Node2D = TriggerScript.new()
				var rsize: Array = obj.get("size", [1, 1])
				trigger.rect = Rect2(Vector2(float(obj["pos"][0]), float(obj["pos"][1])) * TILE, Vector2(float(rsize[0]), float(rsize[1])) * TILE)
				trigger.conditions = obj.get("conditions", [])
				trigger.once_flag = obj.get("once", "")
				trigger.actions = obj["do"]
				trigger.world = self
				entities.add_child(trigger)
			_:
				var script: Script = object_types.get(obj["type"])
				if script == null:
					push_warning("Onbekend soort object op de kaart: %s" % obj["type"])
					continue
				var node: Node2D = script.new()
				node.set("world", self)
				node.set("obj", obj)
				node.set("key", key)
				node.position = pos
				entities.add_child(node)


func spawn_enemy(kind: String, pos: Vector2, flag := "") -> Node2D:
	var enemy: CharacterBody2D = EnemyScript.new()
	enemy.setup(kind, flag)
	enemy.world = self
	enemy.position = pos
	entities.add_child(enemy)
	return enemy


func spawn_pickup(item: String, pos: Vector2, unique_key := "", scatter := false) -> Node2D:
	var pickup: Node2D = PickupScript.new()
	pickup.item = item
	pickup.unique_key = unique_key
	pickup.world = self
	pickup.position = pos
	if scatter:
		pickup.toss = Vector2.from_angle(randf() * TAU) * randf_range(40.0, 90.0)
	entities.add_child(pickup)
	return pickup


func spawn_projectile(kind: String, pos: Vector2, dir: Vector2, speed: float, damage: int, source := "") -> void:
	var projectile: Node2D = ProjectileScript.new()
	projectile.kind = kind
	projectile.source = source
	projectile.velocity = dir.normalized() * speed
	projectile.damage = damage
	projectile.world = self
	projectile.position = pos
	entities.add_child(projectile)


# --- Effecten --------------------------------------------------------------------------

func damage_number(pos: Vector2, text: String, color: Color) -> void:
	fx_layer.add_child(FxScript.make_text(pos, text, color))


func burst(pos: Vector2, color: Color, amount: int) -> void:
	fx_layer.add_child(FxScript.make_burst(pos, color, amount))


func ring(pos: Vector2, radius: float, color: Color) -> void:
	fx_layer.add_child(FxScript.make_ring(pos, radius, color))


func shake(power: float) -> void:
	player.shake(power)


## Een heel korte stilstand bij een treffer, dat voelt steviger. (Niet in tests zonder scherm.)
var _hitstop_id := 0


func hitstop(duration := 0.05) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_hitstop_id += 1
	var id := _hitstop_id
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	if id == _hitstop_id:
		Engine.time_scale = 1.0


# --- Acties vanuit gesprekken en triggers -------------------------------------------------

func _on_world_action(action: Array) -> void:
	match action[0]:
		"music":
			Sound.play_music(action[1])
		"boss_start":
			Sound.play("boss")
			Sound.play_music("boss")
			for boss: Node in get_tree().get_nodes_in_group("boss"):
				if boss.kind == "king":
					boss.activate()


func _on_ending() -> void:
	if GameState.transitioning:
		return
	GameState.transitioning = true
	GameState.set_flag("game_completed")
	GameState.finish_quest("main")
	GameState.record_completion() # Nieuw spel+ wordt beschikbaar
	# De opslag begint na het einde weer in het dorp.
	GameState.map_id = "village"
	var spawns: Dictionary = Maps.get_map("village")["spawns"]
	GameState.save_game(_tile_center(spawns["start"]))
	Sound.stop_music()
	await fader.fade_out(1.2)
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
