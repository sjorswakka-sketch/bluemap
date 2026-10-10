extends Node2D
## De wereld: bouwt de kaart (tegels met botsingen) en zet alle spelers/vijanden/voorwerpen neer.
##
## Tekens in MAP:
##   #  boom (blokkeert)     ~  water (blokkeert)    W  steen (blokkeert)
##   .  gras                 ,  zandpad
##   P  speler (start)       N  Oudste Bram          e  slijm
##   c  blauw kristal        h  hartje               o  munt

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const NpcScript := preload("res://scripts/npc.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const HudScript := preload("res://scripts/hud.gd")

const TILE := 32

enum Tile { GRASS, TREE, WATER, PATH, STONE }
const SOLID_TILES := [Tile.TREE, Tile.WATER, Tile.STONE]

const MAP := [
	"########################################",
	"#........#.........~~...#...#.......##.#",
	"#..................~~..#....WWWWW....#.#",
	"#......#...........~~.......W...W....#.#",
	"#..WWWW............~~.o.##.#W.c.W...#..#",
	"#..W..W..#..e.#....~~.......W...W.....##",
	"##.W..W.........o..~~..#....WW.WW.h....#",
	"#..W..W.....#......~~.........,........#",
	"#...,.....h........~~...e.....,....e...#",
	"#...,..............~~.........,......#.#",
	"#...,.N............~~..##..#..,#.#.....#",
	"#..,,,,,,,,o,,o,,,,,,,,o,,,,,o,,,,..#.##",
	"#.......P..#.....,,,,,,#...h..........##",
	"#..................~~...........#.#.##.#",
	"#.............#....~~.....e......#.....#",
	"#....#.......o.....~~........#.e....c..#",
	"#...........#......~~..................#",
	"#.....#............~~..#.c.......~~~~..#",
	"#..#.....#....e....~~............~~~~#.#",
	"#..................~~......##....~~~~..#",
	"#...........#...o..~~...e......#.......#",
	"#..e.#.......#.....~~................o.#",
	"#.c..............#.~~....#...#......#..#",
	"########################################",
]

var player: Node2D


func _ready() -> void:
	y_sort_enabled = true
	GameState.reset()
	_build_tiles()
	_spawn_entities()
	add_child(HudScript.new())


func _unhandled_input(event: InputEvent) -> void:
	if GameState.ended and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


## Wordt ook door vijanden gebruikt om buit te laten vallen.
func spawn_pickup(kind: String, pos: Vector2) -> void:
	var pickup: Node2D = PickupScript.new()
	pickup.kind = kind
	pickup.position = pos
	add_child(pickup)


func _spawn_entities() -> void:
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var pos := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match row[x]:
				"P":
					player = PlayerScript.new()
					player.position = pos
					add_child(player)
				"N":
					var npc: Node2D = NpcScript.new()
					npc.position = pos
					add_child(npc)
				"e":
					var enemy: Node2D = EnemyScript.new()
					enemy.position = pos
					add_child(enemy)
				"c":
					spawn_pickup("crystal", pos)
				"h":
					spawn_pickup("heart", pos)
				"o":
					spawn_pickup("coin", pos)

	# De camera blijft binnen de kaart.
	var cam: Camera2D = player.camera
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP[0].length() * TILE
	cam.limit_bottom = MAP.size() * TILE


# --- Tegels ------------------------------------------------------------------

func _build_tiles() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()

	var source := TileSetAtlasSource.new()
	source.texture = _make_atlas()
	source.texture_region_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, 0)

	var half := TILE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for tile in Tile.values():
		source.create_tile(Vector2i(tile, 0))
		if tile in SOLID_TILES:
			var data := source.get_tile_data(Vector2i(tile, 0), 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)

	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	add_child(layer)
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			layer.set_cell(Vector2i(x, y), 0, Vector2i(_tile_for(row[x]), 0))


func _tile_for(c: String) -> int:
	match c:
		"#":
			return Tile.TREE
		"~":
			return Tile.WATER
		",":
			return Tile.PATH
		"W":
			return Tile.STONE
		_:
			return Tile.GRASS


## Maakt de tegelplaatjes tijdens het opstarten. Vervang later door echte pixel art:
## geef de TileSet dan gewoon een eigen PNG met dezelfde volgorde (gras, boom, water, pad, steen).
func _make_atlas() -> ImageTexture:
	var count := Tile.values().size()
	var img := Image.create_empty(TILE * count, TILE, false, Image.FORMAT_RGBA8)
	for tile in count:
		for y in TILE:
			for x in TILE:
				img.set_pixel(tile * TILE + x, y, _pixel(tile, x, y))
	return ImageTexture.create_from_image(img)


func _noise(tile: int, x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (tile * 83492791)
	return float(h & 0xff) / 255.0


func _pixel(tile: int, x: int, y: int) -> Color:
	var n := _noise(tile, x, y)
	var grass := Color(0.33, 0.64, 0.33)
	if n > 0.94:
		grass = Color(0.45, 0.76, 0.4)
	elif n < 0.05:
		grass = Color(0.26, 0.54, 0.28)

	match tile:
		Tile.GRASS:
			return grass
		Tile.TREE:
			var d := Vector2(x, y).distance_to(Vector2(16, 13))
			if d < 13.0:
				var canopy := Color(0.12, 0.38, 0.2)
				if d < 8.0 and x + y < 26:
					canopy = Color(0.2, 0.5, 0.25)
				return canopy
			if x >= 14 and x <= 17 and y >= 22 and y <= 29:
				return Color(0.4, 0.25, 0.12)
			return grass
		Tile.WATER:
			var water := Color(0.2, 0.45, 0.8)
			if (y + x / 2) % 8 == 0 and n > 0.2:
				water = Color(0.45, 0.68, 0.95)
			return water
		Tile.PATH:
			var sand := Color(0.76, 0.66, 0.45)
			if n > 0.9:
				sand = Color(0.66, 0.56, 0.38)
			elif n < 0.06:
				sand = Color(0.84, 0.75, 0.55)
			return sand
		Tile.STONE:
			var stone := Color(0.56, 0.58, 0.63)
			var row_offset := 8 if (y / 8) % 2 == 1 else 0
			if y % 8 == 0 or (x + row_offset) % 16 == 0:
				stone = Color(0.38, 0.4, 0.45)
			elif n > 0.92:
				stone = Color(0.64, 0.66, 0.7)
			return stone
	return Color.MAGENTA
