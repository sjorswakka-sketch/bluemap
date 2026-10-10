extends Node2D
## Kleine tijdelijke effecten: zwevende getallen, deeltjes en schokgolven.

var kind := "text"
var text := ""
var color := Color.WHITE
var life := 0.8
var age := 0.0
var particles: Array[Dictionary] = []
var ring_radius := 40.0


static func make_text(pos: Vector2, label: String, tint: Color) -> Node2D:
	var fx: Node2D = load("res://scripts/entities/fx.gd").new()
	fx.kind = "text"
	fx.text = label
	fx.color = tint
	fx.life = 0.8
	fx.position = pos
	return fx


static func make_burst(pos: Vector2, tint: Color, amount: int) -> Node2D:
	var fx: Node2D = load("res://scripts/entities/fx.gd").new()
	fx.kind = "burst"
	fx.color = tint
	fx.life = 0.6
	fx.position = pos
	for i in amount:
		var angle := randf() * TAU
		var speed := randf_range(30.0, 110.0)
		fx.particles.append({
			"pos": Vector2.ZERO, "vel": Vector2.from_angle(angle) * speed,
			"size": randf_range(1.5, 3.5),
		})
	return fx


static func make_ring(pos: Vector2, radius: float, tint: Color) -> Node2D:
	var fx: Node2D = load("res://scripts/entities/fx.gd").new()
	fx.kind = "ring"
	fx.color = tint
	fx.life = 0.4
	fx.ring_radius = radius
	fx.position = pos
	return fx


func _process(delta: float) -> void:
	age += delta
	match kind:
		"text":
			position.y -= 24.0 * delta
		"burst":
			for p in particles:
				p["vel"] = p["vel"] * (1.0 - 3.0 * delta)
				p["pos"] += p["vel"] * delta
	if age >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := clampf(1.0 - age / life, 0.0, 1.0)
	match kind:
		"text":
			var font := ThemeDB.fallback_font
			draw_string_outline(font, Vector2(-8, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, fade))
			draw_string(font, Vector2(-8, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(color, fade))
		"burst":
			for p in particles:
				var size: float = p["size"] * (0.5 + fade * 0.5)
				draw_rect(Rect2(p["pos"] - Vector2(size, size) / 2.0, Vector2(size, size)), Color(color, fade))
		"ring":
			var progress := age / life
			draw_arc(Vector2.ZERO, ring_radius * progress, 0.0, TAU, 40, Color(color, fade * 0.8), 4.0)
			draw_arc(Vector2.ZERO, ring_radius * progress * 0.8, 0.0, TAU, 40, Color(color, fade * 0.4), 2.0)
