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
const Art := preload("res://scripts/art.gd")

const TILE := 32 # grootte van een tegel in de spelwereld
const ART_TILE := 16 # pixels per tegel in assets/tiles.png (wordt 2x vergroot getoond)

## Volgorde = volgorde in assets/tiles.png, van links naar rechts.
enum Tile { GRASS, TREE, WATER, PATH, STONE, GRASS_FLOWERS, GRASS_TUFTS }
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
	tile_set.tile_size = Vector2i(ART_TILE, ART_TILE)
	tile_set.add_physics_layer()

	var source := TileSetAtlasSource.new()
	source.texture = Art.tex("tiles")
	source.texture_region_size = Vector2i(ART_TILE, ART_TILE)
	tile_set.add_source(source, 0)

	var half := ART_TILE / 2.0
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
	layer.scale = Vector2.ONE * (float(TILE) / ART_TILE)
	add_child(layer)
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			layer.set_cell(Vector2i(x, y), 0, Vector2i(_tile_for(row[x], x, y), 0))


func _tile_for(c: String, x: int, y: int) -> int:
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
			# Een beetje afwisseling in het gras, altijd op dezelfde plekken.
			var h := (x * 7 + y * 13 + x * y) % 11
			if h < 1:
				return Tile.GRASS_FLOWERS
			if h < 5:
				return Tile.GRASS_TUFTS
			return Tile.GRASS
