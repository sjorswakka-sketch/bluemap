extends Node2D
## De wereld. Laadt kaarten (scripts/maps/), zet alles neer (personages, vijanden, voorwerpen,
## poortjes, kisten...) en houdt de speler, camera, belichting en overgangen bij.
##
## De kaarten zelf staan als tekst in scripts/maps/*.gd (zie README).

const Living := preload("res://scripts/core/living_world.gd")
const LivingScenery := preload("res://scripts/entities/living_scenery.gd")

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
const AtmosphereScript := preload("res://scripts/entities/atmosphere.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const PauseScript := preload("res://scripts/ui/pause_menu.gd")
const DialogueScript := preload("res://scripts/ui/dialogue_box.gd")
const ShopScript := preload("res://scripts/ui/shop_ui.gd")
const MenuScript := preload("res://scripts/ui/menu_ui.gd")
const CraftingScript := preload("res://scripts/ui/crafting_ui.gd")
const BuildingLandmarksScript := preload("res://scripts/entities/building_landmarks.gd")
const FountainScript := preload("res://scripts/entities/fountain.gd")
const Beroepen := preload("res://scripts/data/ext/beroepen.gd")
const FaderScript := preload("res://scripts/ui/fader.gd")
const Art := preload("res://scripts/core/art.gd")
const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Content := preload("res://scripts/data/content.gd")

const TILE := 32 # grootte van een tegel in de spelwereld
const ART_TILE := 32 # native pixel landscape; world footprints remain 32x32
const VIEW := Vector2(576, 324) # wat je ziet: 1152x648 gedeeld door de camerazoom (2)
const DARK_COLOR := Color(0.1, 0.12, 0.24)

var player: CharacterBody2D
var ground: Node2D
var entities: Node2D
var fx_layer: Node2D
var canvas_mod: CanvasModulate
var atmosphere: Node # dag en nacht, weer en lichtjes (scripts/entities/atmosphere.gd)
var tile_set: TileSet
var landscape: Node2D
var tile_layer: TileMapLayer
var fader: CanvasLayer
var hud: CanvasLayer
var dialogue: CanvasLayer
var shop_ui: CanvasLayer
var menu_ui: CanvasLayer
var craft_goal: CanvasLayer
var crafting_ui: CanvasLayer
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
	atmosphere = AtmosphereScript.new()
	atmosphere.world = self
	add_child(atmosphere)

	hud = HudScript.new()
	add_child(hud)
	craft_goal = preload("res://scripts/ui/craft_goal.gd").new()
	craft_goal.world = self
	add_child(craft_goal)
	dialogue = DialogueScript.new()
	add_child(dialogue)
	shop_ui = ShopScript.new()
	add_child(shop_ui)
	menu_ui = MenuScript.new()
	add_child(menu_ui)
	crafting_ui = CraftingScript.new()
	add_child(crafting_ui)
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
	if Controls.capture_active or not Controls.allows_event(event):
		return
	if GameState.ended and event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		restart_from_save(true)
	elif event.is_action_pressed("crafting") and not GameState.input_locked():
		crafting_ui.open()
		get_viewport().set_input_as_handled()


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
	player.stop_for_transition()
	Living.migrate()
	preload("res://scripts/core/regional_adventures.gd").migrate()
	preload("res://scripts/core/first_route.gd").migrate()
	GameState.map_id = map_id
	GameState.spawn_name = spawn
	map_data = Maps.get_map(map_id).duplicate(true)
	preload("res://scripts/entities/first_route.gd").prepare(map_data,map_id)
	preload("res://scripts/core/access_points.gd").prepare(map_data)
	# Achteraan toevoegen: bestaande kisten en unieke voorwerpen houden hun opslag-ID.
	map_data["objects"].append_array(Beroepen.resource_objects(map_id))
	for obj: Dictionary in map_data.objects:preload("res://scripts/data/forest_food_species.gd").decorate(map_id,obj)
	_clear_map()
	if map_id=="tide_cove":preload("res://scripts/core/tides.gd").prepare(map_data,GameState.day_time)
	if map_id=="tidal_hollow":preload("res://scripts/core/coastal_adventures.gd").prepare(map_data)
	preload("res://scripts/core/water_features.gd").describe(map_id,map_data)
	_build_tiles(map_data["rows"])
	landscape = preload("res://scripts/entities/pixel_landscape.gd").new()
	landscape.world = self
	ground.add_child(landscape)
	_build_fountains()
	var waters:=preload("res://scripts/entities/water_scenery.gd").new();waters.world=self;ground.add_child(waters)

	darkness = map_data.get("dark", 0.0)
	canvas_mod.color = Color.WHITE.lerp(DARK_COLOR, darkness)

	if player.get_parent() != entities:
		entities.add_child(player)
	player.set_lit(darkness > 0.0)
	atmosphere.enter_map(map_data)
	var start: Vector2
	if pos_override != Vector2.INF:
		start = pos_override
	else:
		var spawns: Dictionary = map_data["spawns"]
		start = _tile_center(spawns.get(spawn, spawns["start"]))
		if map_id=="village" and spawn=="start" and GameState.play_time<1 and preload("res://scripts/core/opening.gd").enabled():
			start += Vector2(0,48) # het hele plein is bij aankomst meteen in beeld
	player.global_position = _safe_fountain_spawn(preload("res://scripts/core/regional_adventures.gd").safe_position(map_id,start))
	player.velocity = Vector2.ZERO
	player.knockback = Vector2.ZERO
	player.camera.offset=Vector2.ZERO
	_set_camera_limits()
	_spawn_objects()
	var landmarks := BuildingLandmarksScript.new()
	landmarks.setup(map_id, self)
	ground.add_child(landmarks)
	var living_scenery := LivingScenery.new()
	living_scenery.world = self
	ground.add_child(living_scenery)
	living_scenery.refresh()
	if map_id=="kruipmoeras":
		var waterworks:=preload("res://scripts/entities/marsh_waterworks.gd").new()
		waterworks.world=self
		ground.add_child(waterworks)
	if map_id=="forest_edge":ground.add_child(load("res://scripts/entities/edge_scenery.gd").new())
	if map_id in ["coast","gull_island","tide_cove","river_mouth","harbor","headland"]:
		var scenery: Node2D=load("res://scripts/entities/coast_scenery.gd").new()
		scenery.world=self
		ground.add_child(scenery)
		var voyage: CanvasLayer=load("res://scripts/ui/coast_voyage.gd").new()
		voyage.world=self
		ground.add_child(voyage)
		var routes: CanvasLayer=load("res://scripts/ui/coast_routes.gd").new()
		routes.world=self
		ground.add_child(routes)
		var atlas: CanvasLayer=load("res://scripts/ui/coast_atlas.gd").new()
		atlas.world=self
		ground.add_child(atlas)
	if map_id in ["river_mouth","harbor","headland"]:
		var region_scenery: Node2D=load("res://scripts/entities/coastal_region_scenery.gd").new()
		region_scenery.world=self
		ground.add_child(region_scenery)
	if map_id=="tidal_hollow":
		var adventure: Node2D=load("res://scripts/entities/coastal_adventure_director.gd").new()
		adventure.world=self;entities.add_child(adventure)
	if map_id=="tide_cove":
		var tide: Node2D=load("res://scripts/entities/tide_cove.gd").new()
		tide.world=self
		ground.add_child(tide)
	if map_id in ["smithy","library"]:
		var workshop: Node2D=load("res://scripts/entities/workshop.gd").new()
		workshop.world=self
		ground.add_child(workshop)
	var memory := preload("res://scripts/entities/world_memory.gd").new()
	memory.world = self
	ground.add_child(memory)
	if map_id in ["forest","ruins","cave"]:
		var route: Node2D=load("res://scripts/entities/first_route.gd").new()
		route.world=self
		ground.add_child(route)
	if map_id == "village":
		var opening: Node2D = load("res://scripts/entities/village_opening.gd").new()
		opening.world = self
		ground.add_child(opening)
	if map_id in ["lake","inn"]:
		var supper: Node2D=load("res://scripts/entities/lake_supper.gd").new()
		supper.world=self
		ground.add_child(supper)
	if map_id in ["dorstvallei","sunwell","ijsdal","ridgepass","kruipmoeras","reedvault"]:
		var region: Node2D=load("res://scripts/entities/regional_adventures.gd").new()
		region.world=self
		ground.add_child(region)
	if map_id=="village":
		var yard: Node2D=load("res://scripts/entities/yard_scenery.gd").new();yard.world=self;ground.add_child(yard)
	var home: Node2D=load("res://scripts/entities/homestead.gd").new()
	home.world=self
	ground.add_child(home)
	if map_id=="player_home":
		var room: Node2D=load("res://scripts/entities/personal_house.gd").new()
		room.world=self;ground.add_child(room)
	if map_id=="player_home":
		var decor: Script=load("res://scripts/core/personal_home.gd")
		if decor.player_reason(decor.state().layout,player.position)!="":player.position=Vector2(6.5,10.5)*TILE
	player.global_position = safe_spawn_position(player.global_position)
	player.camera.reset_smoothing()

	Sound.play_music(map_data.get("music", "forest"))
	var map_name: String = map_data["name"]
	hud.show_banner(func() -> String: return tr(map_name))
	hud.refresh_opening()
	if map_id == "forest" and preload("res://scripts/core/opening.gd").enabled() and not GameState.flag("op_combat_hint"):
		GameState.set_flag("op_combat_hint")
		GameState.toast.emit(tr("Buiten het dorp: %s om aan te vallen, %s om te rollen. Je kunt altijd terug naar het plein.") % [Controls.action_label("attack"),Controls.action_label("dodge")])


## Hoeveel kunstlicht (fakkels, lantaarns, ramen) er nu nodig is: 0 overdag, 1 in het donker.
func light_need() -> float:
	return atmosphere.light_need


func is_outdoor() -> bool:
	return atmosphere.outdoor


func travel(map_id: String, spawn: String, cue: String="door") -> void:
	if GameState.transitioning:
		return
	GameState.transitioning = true
	player.stop_for_transition()
	if cue!="":Sound.play(cue, -4.0)
	await fader.fade_out(0.25)
	load_map(map_id, spawn)
	player.invuln = maxf(player.invuln,1.25) # arriving gives time to read the new area
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

## Check actual foot shapes, including moving residents, before restoring or travelling.
## Reading shapes directly also works before the next physics frame registers a new map.
func spawn_fits(at: Vector2) -> bool:
	if not is_finite(at.x) or not is_finite(at.y):return false
	var foot:=at+Vector2(0,8)
	for offset in [Vector2.ZERO,Vector2(8,0),Vector2(-8,0),Vector2(0,8),Vector2(0,-8),Vector2(6,6),Vector2(-6,6),Vector2(6,-6),Vector2(-6,-6)]:
		if is_solid(foot+offset):return false
	for body in entities.get_children():
		if body==player or body.is_queued_for_deletion() or not body is PhysicsBody2D or not (body.collision_layer & 1):continue
		if body is GateScript and not body.blocked:continue
		for collider in body.get_children():
			if not collider is CollisionShape2D or collider.disabled or collider.shape==null:continue
			if collider.shape is RectangleShape2D:
				var size: Vector2=collider.shape.size*collider.global_scale.abs()
				var bounds:=Rect2(collider.global_position-size/2,size)
				var nearest:=Vector2(clampf(foot.x,bounds.position.x,bounds.end.x),clampf(foot.y,bounds.position.y,bounds.end.y))
				if nearest.distance_to(foot)<8:return false
			elif collider.shape is CircleShape2D:
				if collider.global_position.distance_to(foot)<8+collider.shape.radius*maxf(absf(collider.global_scale.x),absf(collider.global_scale.y)):return false
	for spec: Dictionary in map_data.objects:
		if spec.type!="portal":continue
		var size: Array=spec.get("size",[1,1])
		if Rect2(Vector2(spec.pos[0],spec.pos[1])*TILE,Vector2(size[0],size[1])*TILE).has_point(at):return false
	return true

func safe_spawn_position(at: Vector2) -> Vector2:
	if spawn_fits(at):return at
	var cell:=Vector2i(at/TILE) if is_finite(at.x) and is_finite(at.y) else Vector2i(map_data.spawns.start[0],map_data.spawns.start[1])
	for radius in range(1,9):
		for offset: Vector2i in preload("res://scripts/core/fast_travel.gd")._ring(radius):
			var candidate: Vector2=(Vector2(cell+offset)+Vector2(0.5,0.5))*TILE
			if spawn_fits(candidate):return candidate
	return _tile_center(map_data.spawns.start)


# --- Tegels ---------------------------------------------------------------------------

func _build_tile_set() -> void:
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(ART_TILE, ART_TILE)
	tile_set.add_physics_layer()
	var source := TileSetAtlasSource.new()
	source.texture = Art.tex("pixel_landscape")
	source.texture_region_size = Vector2i(ART_TILE, ART_TILE)
	tile_set.add_source(source, 0)
	var half := ART_TILE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for i in Tiles.NAMES.size():
		for variant in 8:
			var coords := Vector2i(i,variant)
			source.create_tile(coords)
			if Tiles.is_solid_name(Tiles.NAMES[i]):
				var data := source.get_tile_data(coords, 0)
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
			tile_layer.set_cell(Vector2i(x, y), 0, preload("res://scripts/core/pixel_landscape.gd").atlas(tile_name,x,y))
			if Tiles.is_solid_name(tile_name):
				solid_cells[Vector2i(x, y)] = true


## Fonteinen zitten buiten objects: uitbreiden verplaatst geen bestaande opslag-ID's.
func _build_fountains() -> void:
	for spec: Dictionary in map_data.get("fountains", []):
		var pos: Array = spec["pos"]
		var size: Array = spec.get("size", [2, 2])
		var cells := Rect2i(pos[0], pos[1], size[0], size[1])
		var fountain := FountainScript.new()
		fountain.setup(cells)
		entities.add_child(fountain)
		for y in range(cells.position.y, cells.end.y):
			for x in range(cells.position.x, cells.end.x):
				solid_cells[Vector2i(x, y)] = true


## Een oude opslag kan precies staan waar het grotere bassin nu ligt.
## Alleen die overlap corrigeren; iedere andere opgeslagen positie blijft gelijk.
func _safe_fountain_spawn(wanted: Vector2) -> Vector2:
	var foot := wanted + PlayerScript.FOOT_OFFSET
	var basins: Array[Rect2] = []
	for spec: Dictionary in map_data.get("fountains", []):
		var pos: Array = spec["pos"]
		var size: Array = spec.get("size", [2, 2])
		# Spelervoet heeft radius 7; 2 pixels extra houden de rand vrij.
		basins.append(Rect2(Vector2(pos[0], pos[1]) * TILE, Vector2(size[0], size[1]) * TILE).grow(9.0))
	var candidates: Array[Vector2] = []
	for basin: Rect2 in basins:
		if not basin.has_point(foot):
			continue
		candidates.append(Vector2(basin.position.x, foot.y))
		candidates.append(Vector2(basin.end.x, foot.y))
		candidates.append(Vector2(foot.x, basin.position.y))
		candidates.append(Vector2(foot.x, basin.end.y))
	var best := wanted
	var distance := INF
	for candidate: Vector2 in candidates:
		if is_solid(candidate):
			continue
		var blocked := false
		for basin: Rect2 in basins:
			if basin.grow(-0.1).has_point(candidate):
				blocked = true
		if not blocked and candidate.distance_squared_to(foot) < distance:
			best = candidate - PlayerScript.FOOT_OFFSET
			distance = candidate.distance_squared_to(foot)
	return best


# --- Voorwerpen op de kaart ---------------------------------------------------------

func _spawn_objects() -> void:
	var objects: Array = map_data.get("objects", [])
	for i in objects.size():
		var obj: Dictionary = objects[i]
		if not obj.get("enabled",true): continue # retained slots preserve existing save IDs
		if obj.has("if") and not GameState.check_all(obj["if"]):
			continue
		var pos := _tile_center(obj["pos"])
		var key := "%s:%s:%d" % [obj["type"], GameState.map_id, i]
		match obj["type"]:
			"npc":
				var npc: Node2D = load("res://scripts/entities/coast_resident.gd").new() if obj["id"] in ["rg_ise","rg_raf"] else load("res://scripts/entities/supper_actor.gd").new() if obj["id"]=="meer_joris" and GameState.map_id=="lake" else NpcScript.new()
				npc.setup(obj["id"])
				npc.world = self
				npc.exists_if = obj.get("exists_if", [])
				npc.position = pos
				entities.add_child(npc)
			"enemy":
				var flag: String = obj.get("flag", "")
				if flag == "" or not GameState.flag(flag):
					var enemy:=spawn_enemy(obj["kind"], pos, flag)
					enemy.patrol_radius=float(obj.get("patrol_radius",0.0))
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
				sign_node.speaker = obj.get("speaker", "")
				sign_node.world = self
				sign_node.position = pos
				entities.add_child(sign_node)
			"portal":
				var portal: Node2D = PortalScript.new()
				var size: Array = obj.get("size", [1, 1])
				portal.rect = Rect2(Vector2(float(obj["pos"][0]), float(obj["pos"][1])) * TILE, Vector2(float(size[0]), float(size[1])) * TILE)
				portal.position = portal.rect.position # de node zelf staat op de plek, voor y-sortering van de gloed
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
				gate.locked_text = obj.get("locked_text", "")
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
	GameState.check_achievements() # meteen, zodat de prestaties van het einde ook in de opslag staan
	# De opslag begint na het einde weer in het dorp.
	GameState.map_id = "village"
	var spawns: Dictionary = Maps.get_map("village")["spawns"]
	GameState.save_game(_tile_center(spawns["start"]))
	Sound.stop_music()
	await fader.fade_out(1.2)
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
