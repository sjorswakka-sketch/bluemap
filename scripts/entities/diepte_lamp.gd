extends Node2D
## Een zwevend kristal op een stenen voetstuk. In de donkere Diepte geeft het paars licht.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")

const LIGHT_COLOR := Color(0.62, 0.45, 1.0)

var world: Node
var obj: Dictionary = {}
var key := ""
var t := randf() * TAU
var light: PointLight2D


func _ready() -> void:
	if world != null and world.darkness > 0.0:
		light = PointLight2D.new()
		light.texture = Art.light_texture()
		light.color = LIGHT_COLOR
		light.texture_scale = 2.4
		light.energy = 0.8
		light.position = Vector2(0, -8)
		add_child(light)


func _process(delta: float) -> void:
	t += delta
	if light:
		light.energy = 0.78 + sin(t * 2.2) * 0.07 + sin(t * 5.3) * 0.03
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, -6), 11.0 + sin(t * 2.2) * 1.5, Color(0.65, 0.45, 1.0, 0.12))
	DrawUtil.sprite(self, Art.tex("depths_objects"), int(t * 1.4) % 2, 0)
