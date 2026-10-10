extends Node2D
## Een voorwerp op de grond: munt, hartje of blauw kristal.

const DrawUtil := preload("res://scripts/draw_util.gd")

const PICKUP_RANGE := 16.0

## "coin", "heart" of "crystal"
var kind := "coin"
var t := randf() * TAU
var player: Node2D


func _ready() -> void:
	add_to_group("pickups")


func _process(delta: float) -> void:
	t += delta * 3.0
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player and not GameState.ended and player.global_position.distance_to(global_position) < PICKUP_RANGE:
		_collect()
	queue_redraw()


func _collect() -> void:
	match kind:
		"coin":
			GameState.add_coin()
		"crystal":
			GameState.add_crystal()
		"heart":
			if GameState.hp >= GameState.MAX_HP:
				return # Bewaren voor als je gewond bent.
			GameState.heal(1)
	queue_free()


func _draw() -> void:
	var bob := sin(t) * 2.0
	DrawUtil.ellipse(self, Vector2(0, 8), Vector2(6, 2.5), Color(0, 0, 0, 0.25))
	match kind:
		"coin":
			var squeeze := absf(cos(t * 0.8))
			DrawUtil.ellipse(self, Vector2(0, bob), Vector2(5.5 * squeeze + 1.0, 5.5), Color(0.75, 0.55, 0.1))
			DrawUtil.ellipse(self, Vector2(0, bob), Vector2(3.5 * squeeze + 0.5, 3.5), Color(1.0, 0.85, 0.25))
		"heart":
			DrawUtil.heart(self, Vector2(0, bob), 7.0, Color(0.92, 0.2, 0.3))
		"crystal":
			draw_circle(Vector2(0, bob), 11.0 + sin(t * 2.0) * 1.5, Color(0.3, 0.7, 1.0, 0.18))
			var top := Vector2(0, -10 + bob)
			var right := Vector2(6, -1 + bob)
			var bottom := Vector2(0, 9 + bob)
			var left := Vector2(-6, -1 + bob)
			draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), Color(0.3, 0.72, 1.0))
			draw_colored_polygon(PackedVector2Array([top, right, Vector2(0, -1 + bob)]), Color(0.7, 0.92, 1.0))
			draw_colored_polygon(PackedVector2Array([bottom, left, Vector2(0, -1 + bob)]), Color(0.15, 0.5, 0.85))
