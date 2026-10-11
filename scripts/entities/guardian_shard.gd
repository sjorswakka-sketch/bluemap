extends Node2D
## Een kristalscherf van De Vergeten Wachter of zijn pilaren. Vliegt rechtdoor, verdwijnt tegen een muur en doet
## schade aan de speler (rollen maakt je even onraakbaar, net als bij pijlen).

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")

const HIT_RANGE := 11.0 # hoe dichtbij de speler moet zijn om geraakt te worden (zoals projectile.gd)
const MAX_AGE := 6.0
const GLOW := Color(0.7, 0.45, 1.0)

var velocity := Vector2.ZERO
var damage := 1
var source := "De Vergeten Wachter (scherf)"
var world: Node
var age := 0.0
var player: Node2D


func _ready() -> void:
	add_to_group("guardian_shards")


func _process(delta: float) -> void:
	age += delta
	position += velocity * delta
	if age > MAX_AGE or world.is_solid(global_position):
		world.burst(global_position, GLOW, 4)
		queue_free()
		return
	if player == null:
		player = Util.player(self)
	if player and not GameState.ended and global_position.distance_to(player.global_position + Vector2(0, 4)) < HIT_RANGE:
		player.hurt(global_position - velocity.normalized() * 8.0, damage, source)
		world.burst(global_position, GLOW, 5)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color(GLOW, 0.18))
	draw_set_transform(Vector2.ZERO, velocity.angle(), Vector2.ONE)
	DrawUtil.sprite(self, Art.tex("depths_objects"), 3 + int(age * 10.0) % 2, 0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
