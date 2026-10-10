extends Node2D
## Een fakkel. In donkere gebieden geeft hij licht.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")

var world: Node
var cold := false # blauw licht (in de tempel)
var t := randf() * TAU
var light: PointLight2D


func _ready() -> void:
	if world != null and world.darkness > 0.0:
		light = PointLight2D.new()
		light.texture = Art.light_texture()
		light.color = Color(0.4, 0.7, 1.0) if cold else Color(1.0, 0.7, 0.35)
		light.texture_scale = 2.6
		light.energy = 1.0
		add_child(light)


func _process(delta: float) -> void:
	t += delta
	if light:
		light.energy = 0.9 + sin(t * 9.0) * 0.08 + sin(t * 23.0) * 0.05
	queue_redraw()


func _draw() -> void:
	var tint := Color(0.55, 0.85, 1.8) if cold else Color.WHITE
	DrawUtil.sprite(self, Art.tex("torch"), int(t * 7.0) % 2, 0, Vector2.ZERO, Vector2i(16, 16), 2.0, tint)
