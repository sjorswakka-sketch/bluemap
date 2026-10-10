extends Node2D
## Een voorwerp op de grond: munt, hartje of blauw kristal.

const DrawUtil := preload("res://scripts/draw_util.gd")
const Art := preload("res://scripts/art.gd")

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
	var bob := Vector2(0, sin(t) * 2.0)
	DrawUtil.ellipse(self, Vector2(0, 11), Vector2(6, 2.5), Color(0, 0, 0, 0.25))
	match kind:
		"coin":
			DrawUtil.sprite(self, Art.tex("coin"), int(t * 1.3) % 4, 0, bob)
		"heart":
			DrawUtil.sprite(self, Art.tex("heart"), 0, 0, bob)
		"crystal":
			draw_circle(bob, 13.0 + sin(t * 2.0) * 1.5, Color(0.3, 0.7, 1.0, 0.18))
			DrawUtil.sprite(self, Art.tex("crystal"), int(t * 0.7) % 2, 0, bob)
