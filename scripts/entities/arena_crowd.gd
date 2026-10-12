extends Node2D
## Het publiek van de arena: figuurtjes op alle tribunetegels (arena_tribune) die juichen en springen.
## Op de kaart: {"type": "arena_crowd", "pos": [0, 0], "field": [x0, y0, x1, y1]}. Wie onder het veld zit, kijkt
## de andere kant op (je ziet zijn rug).

const Art := preload("res://scripts/core/art.gd")
const Arena := preload("res://scripts/data/arena.gd")
const Tiles := preload("res://scripts/data/tiles.gd")

const TILE := 32
const DENSITY := 82 # procent van de plaatsen dat bezet is
const LOOKS := 4 # kleurstellingen in assets/arena_crowd.png
const JUMP_TIME := 0.55
const JUMP_HEIGHT := 7.0
const SEAT_LIFT := 3.0 # ze zitten een tikje omhoog, op de bank

var world: Node
var obj: Dictionary = {}
var key := ""
var seats: Array[Dictionary] = [] # {pos, look, back, wait, jump}
var rng := RandomNumberGenerator.new()
var ambient := 1.0
var t := 0.0


@warning_ignore("integer_division")
func _ready() -> void:
	position = Vector2.ZERO # we tekenen in kaartcoördinaten
	add_to_group("arena_crowd")
	rng.randomize()
	var field: Array = obj.get("field", [0, 0, 0, 0])
	var rows: Array = world.map_data["rows"]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if Tiles.name_for(row[x], x, y) != "arena_tribune":
				continue
			var h := (x * 7919 + y * 104729 + x * y * 31) % 1000
			if h % 100 >= DENSITY:
				continue # een lege plaats
			seats.append({
				"pos": Vector2((x + 0.5) * TILE, (y + 0.5) * TILE - SEAT_LIFT),
				"look": (h / 100) % LOOKS, "back": y > int(field[3]), "wait": 0.0, "jump": -1.0,
			})


## Laat een deel van het publiek juichen en springen. `strength` is de kans per toeschouwer (0 tot 1).
func cheer(strength := 1.0) -> void:
	for seat in seats:
		if seat["jump"] < 0.0 and rng.randf() < strength:
			seat["wait"] = rng.randf_range(0.0, 0.3)
			seat["jump"] = 0.0


## Hoeveel toeschouwers juichen er nu (voor de test).
func cheering() -> int:
	var total := 0
	for seat in seats:
		if seat["jump"] >= 0.0:
			total += 1
	return total


## De plek van een toeschouwer die zo dicht mogelijk bij `near` zit (daar komt een hartje vandaan).
func seat_near(near: Vector2) -> Vector2:
	var best := near
	var best_distance := INF
	for seat in seats:
		var distance := (seat["pos"] as Vector2).distance_to(near) + rng.randf_range(0.0, 60.0)
		if distance < best_distance:
			best_distance = distance
			best = seat["pos"]
	return best


func _process(delta: float) -> void:
	t += delta
	if Arena.run_active:
		ambient -= delta
		if ambient <= 0.0:
			ambient = rng.randf_range(0.7, 1.8)
			cheer(0.05) # er springt altijd wel iemand op
	for seat in seats:
		if seat["jump"] < 0.0:
			continue
		if seat["wait"] > 0.0:
			seat["wait"] -= delta
		else:
			seat["jump"] += delta
			if seat["jump"] > JUMP_TIME:
				seat["jump"] = -1.0
	queue_redraw()


func _draw() -> void:
	var texture := Art.tex("arena_crowd")
	for i in seats.size():
		var seat: Dictionary = seats[i]
		var jumping: bool = seat["jump"] >= 0.0 and seat["wait"] <= 0.0
		var column: int = int(seat["look"]) * 4 + (2 if seat["back"] else 0) + (1 if jumping else 0)
		var lift := 0.0
		if jumping:
			lift = sin(seat["jump"] / JUMP_TIME * PI) * JUMP_HEIGHT
		else:
			lift = 1.0 if int(t * 1.6 + float(i % 7)) % 4 == 0 else 0.0 # af en toe een klein wiebeltje
		var center: Vector2 = seat["pos"] - Vector2(0, round(lift))
		draw_texture_rect_region(texture, Rect2(center - Vector2(16, 16), Vector2(32, 32)), Rect2(Vector2(column * 16, 0), Vector2(16, 16)))
