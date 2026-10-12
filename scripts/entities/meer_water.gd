extends Node2D
## Sfeer op het meer: glinsteringen op het water en af en toe een vis die uit het water springt.
## Staat onzichtbaar op de kaart: {"type": "meer_water", "pos": [1, 1]}. Verandert niets aan het spel zelf.

const Art := preload("res://scripts/core/art.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Util := preload("res://scripts/core/util.gd")

const TILE := 32.0
const VIEW_TILES := Vector2i(11, 7) # zoveel tegels om de speler heen krijgen glinsteringen
const GLINT_COLOR := Color(1, 1, 1, 0.85)
const JUMP_TIME := 0.75
const JUMP_HEIGHT := 26.0
const FISH_ICON := 1 # de baars in items_meer.png

var world: Node
var obj: Dictionary = {}
var key := ""
var t := 0.0
var player: Node2D
var water: Dictionary = {} # Vector2i -> true voor elke watertegel
var next_jump := 3.0
var jump: Dictionary = {} # {"from": Vector2, "to": Vector2, "age": float}


func _ready() -> void:
	position = Vector2.ZERO
	var rows: Array = world.map_data["rows"]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if Tiles.name_for(row[x], x, y) in ["water", "meer_lelie"]:
				water[Vector2i(x, y)] = true


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = Util.player(self)
		return
	next_jump -= delta
	if jump.is_empty() and next_jump <= 0.0:
		next_jump = randf_range(3.0, 8.0)
		_start_jump()
	elif not jump.is_empty():
		jump["age"] = float(jump["age"]) + delta
		if jump["age"] >= JUMP_TIME:
			_splash(jump["to"])
			jump = {}
	queue_redraw()


func _start_jump() -> void:
	# Een plek op het water in beeld, niet vlak bij de speler.
	var centre := Vector2i((player.global_position / TILE).floor())
	for attempt in 12:
		var cell := centre + Vector2i(randi_range(-VIEW_TILES.x, VIEW_TILES.x), randi_range(-VIEW_TILES.y, VIEW_TILES.y))
		if water.has(cell) and Vector2(cell - centre).length() > 3.0:
			var from := Vector2(cell) * TILE + Vector2(16, 16)
			jump = {"from": from, "to": from + Vector2(randf_range(-28.0, 28.0), randf_range(-8.0, 8.0)), "age": 0.0}
			_splash(from)
			return


func _splash(at: Vector2) -> void:
	world.ring(at, 16.0, Color(1, 1, 1, 0.8))
	world.burst(at, Color(0.8, 0.92, 1.0), 5)
	Sound.play("meer_plons", -18.0, randf_range(0.9, 1.2))


func _draw() -> void:
	if player == null:
		return
	var centre := Vector2i((player.global_position / TILE).floor())
	for dy in range(-VIEW_TILES.y, VIEW_TILES.y + 1):
		for dx in range(-VIEW_TILES.x, VIEW_TILES.x + 1):
			var cell := centre + Vector2i(dx, dy)
			if not water.has(cell):
				continue
			# Elke tegel heeft zijn eigen ritme; hij glinstert heel even per ronde.
			var h := (cell.x * 73856093) ^ (cell.y * 19349663)
			var phase := float(h & 1023) / 1023.0 * TAU
			if sin(t * 1.1 + phase) > 0.96:
				var at := Vector2(cell) * TILE + Vector2(float(h >> 10 & 15) + 6.0, float(h >> 14 & 15) + 6.0)
				draw_rect(Rect2(at, Vector2(4, 2)), GLINT_COLOR)
				draw_rect(Rect2(at + Vector2(1, -2), Vector2(2, 6)), Color(GLINT_COLOR, 0.6))
	if not jump.is_empty():
		var progress := float(jump["age"]) / JUMP_TIME
		var pos: Vector2 = Vector2(jump["from"]).lerp(jump["to"], progress)
		pos.y -= sin(progress * PI) * JUMP_HEIGHT
		var angle := (progress - 0.5) * 1.8
		draw_set_transform(pos, angle, Vector2.ONE)
		draw_texture_rect_region(Art.tex("items_meer"), Rect2(Vector2(-12, -12), Vector2(24, 24)),
			Rect2(Vector2(FISH_ICON * 16, 0), Vector2(16, 16)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
