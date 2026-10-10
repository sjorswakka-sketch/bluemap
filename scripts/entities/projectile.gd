extends Node2D
## Een pijl, steen of slijmbal. Verdwijnt tegen een muur en doet schade aan de speler.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")

const FRAMES := {"arrow": 0, "rock": 1, "slimeball": 2}

var kind := "arrow"
var velocity := Vector2.ZERO
var damage := 1
var source := ""
var world: Node
var age := 0.0
var player: Node2D


func _process(delta: float) -> void:
	age += delta
	position += velocity * delta
	if age > 5.0 or world.is_solid(global_position):
		world.burst(global_position, Color(0.9, 0.9, 0.9), 4)
		queue_free()
		return
	if player == null:
		player = Util.player(self)
	if player and not GameState.ended and global_position.distance_to(player.global_position + Vector2(0, 4)) < 11.0:
		player.hurt(global_position - velocity.normalized() * 8.0, damage, source)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var column: int = FRAMES.get(kind, 0)
	draw_set_transform(Vector2.ZERO, velocity.angle() if kind == "arrow" else age * 8.0, Vector2.ONE)
	DrawUtil.sprite(self, Art.tex("projectiles"), column, 0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
