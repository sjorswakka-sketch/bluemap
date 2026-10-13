extends Node2D
## Licht en deeltjes blijven plaatselijk: geen schermvullende effecten over aanvallen.
const Art := preload("res://scripts/core/art.gd")
var world: Node
var obj: Dictionary = {}
var key := ""
var clock := 0.0
var glow: PointLight2D
var hue := Color(0.35, 0.9, 1.0)

func _ready() -> void:
	hue = Color(0.8, 0.5, 1.0) if obj.get("violet", false) else hue
	glow = PointLight2D.new()
	glow.texture = Art.light_texture()
	glow.texture_scale = 1.2
	glow.color = hue
	add_child(glow)
	clock = position.x * 0.02

func _process(delta: float) -> void:
	clock += delta
	glow.energy = 0.55 + sin(clock * 1.4) * 0.12
	queue_redraw()

func _draw() -> void:
	draw_ellipse_shadow()
	for i in 3:
		var base := Vector2((i - 1) * 9, 6)
		var height := 30.0 if i == 1 else 18.0
		var tip := base + Vector2(0, -height)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-6, -6), tip, base + Vector2(6, -6), base + Vector2(0, 2)]), hue.darkened(0.4))
		draw_colored_polygon(PackedVector2Array([base, base + Vector2(-5, -6), tip]), hue)
		draw_line(tip + Vector2(0, 3), base + Vector2(0, -4), Color(0.9, 1, 1, 0.85), 1.0)
	for i in 4:
		var phase := fmod(clock * 0.25 + i * 0.25, 1.0)
		var point := Vector2(sin(clock + i * 2.0) * 19.0, -phase * 43.0)
		draw_rect(Rect2(point, Vector2(2, 2)), Color(hue, sin(phase * PI) * 0.8))

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 8), 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
