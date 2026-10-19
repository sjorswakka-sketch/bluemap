extends StaticBody2D
## Het zegel voor de trap achter in de Kristaltempel. Zolang het einde niet is gehaald zit het muurvast.
## Is de Blauwe Kaart hersteld (vlag game_completed) en kom je dichtbij, dan breekt het en gaat de Diepte open.
##
## Kaartvorm: {"type": "diepte_seal", "pos": [11, 0], "size": [1, 2], "if": [["no_flag", "diepte_opened"]]}
## `pos` is de linkerbovenste tegel; `size` bepaalt dezelfde voetafdruk voor botsing en pixelart.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")

const BREAK_RANGE := 112.0 # zo dichtbij (in pixels, vanaf het midden van de plaat) breekt het zegel
const BREAK_TIME := 1.8 # hoe lang het scheurt voor het uiteenspat
const GLOW := Color(0.6, 0.5, 1.0)
const CRACKED_FRAME := 2
const TILE := 32.0

var world: Node
var obj: Dictionary = {}
var key := ""
var t := 0.0
var player: Node2D
var breaking := false
var break_time := 0.0
var shape: CollisionShape2D
var light: PointLight2D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _plate_size()
	shape.shape = rect
	shape.position = _center_offset()
	add_child(shape)
	if world != null and world.darkness > 0.0:
		light = PointLight2D.new()
		light.texture = Art.light_texture()
		light.color = GLOW
		light.texture_scale = 1.8
		light.energy = 0.7
		light.position = _center_offset()
		add_child(light)


## Afmeting van de zichtbare plaat en zijn echte botsingsvorm.
func _plate_size() -> Vector2:
	var tiles: Array = obj.get("size", [2, 2])
	return Vector2(maxi(1, int(tiles[0])), maxi(1, int(tiles[1]))) * TILE


## Het midden van de plaat vanaf het midden van de linkerbovenste tegel.
func _center_offset() -> Vector2:
	return (_plate_size() - Vector2.ONE * TILE) / 2.0


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = Util.player(self)
	if breaking:
		_break_step(delta)
	elif player and GameState.flag("game_completed") and not GameState.input_locked() \
			and (global_position + _center_offset()).distance_to(player.global_position) < BREAK_RANGE:
		_start_break()
	if light and not breaking:
		light.energy = 0.65 + sin(t * 2.0) * 0.1
	queue_redraw()


func interact() -> void:
	if breaking:
		return
	GameState.say(tr("Zegel"), [
		tr("Een zware steenplaat met een ster erin. De runen gloeien zachtjes."),
		tr("Hij zit muurvast. Misschien gaat hij pas open als de Blauwe Kaart weer heel is."),
	])


func _start_break() -> void:
	breaking = true
	break_time = 0.0
	remove_from_group("interactable")
	Sound.play("seal_break")
	world.shake(3.0)
	world.ring(global_position + _center_offset(), 60.0, GLOW)


func _break_step(delta: float) -> void:
	var before := break_time
	break_time += delta
	# Het zegel trilt en er springen steeds kleine splinters af.
	if int(before / 0.3) != int(break_time / 0.3):
		world.shake(2.5)
		world.burst(global_position + _center_offset() + Vector2(randf_range(-0.44, 0.44), randf_range(-0.44, 0.44)) * _plate_size(), GLOW, 6)
	if light:
		light.energy = 0.7 + break_time * 1.4
	if break_time >= BREAK_TIME:
		_open()


func _open() -> void:
	var center := global_position + _center_offset()
	world.burst(center, Color(0.85, 0.75, 1.0), 28)
	world.burst(center, Color(1, 1, 1), 14)
	world.ring(center, 90.0, Color(0.85, 0.75, 1.0))
	world.shake(6.0)
	GameState.toast.emit(tr("Het zegel is gebroken! Er is een trap naar beneden."))
	GameState.start_quest("diepte")
	GameState.set_flag("diepte_opened")
	queue_free()


func _draw() -> void:
	var center := _center_offset()
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	draw_circle(center, 46.0 + pulse * 4.0 + break_time * 20.0, Color(GLOW, 0.1 + pulse * 0.06))
	var frame := CRACKED_FRAME if breaking and break_time > BREAK_TIME * 0.4 else int(t * 1.2) % 2
	var offset := Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0)) if breaking else Vector2.ZERO
	var tint := Color(1.6, 1.6, 2.0) if breaking and int(break_time * 14.0) % 2 == 0 else Color.WHITE
	var narrow := _plate_size().x < TILE * 1.5
	var cell := Vector2(16, 32) if narrow else Vector2(32, 32)
	var base := Art.tex("depths_seal_narrow" if narrow else "depths_seal")
	var texture := Art.detailed(base)
	var density := 2.0 if texture != base else 1.0
	draw_texture_rect_region(texture, Rect2(center + offset - _plate_size() / 2.0, _plate_size()), Rect2(Vector2(frame * cell.x, 0) * density, cell * density), tint)
	if player and player.target == self and not breaking:
		DrawUtil.prompt(self, center + Vector2(0, -44.0), t)
