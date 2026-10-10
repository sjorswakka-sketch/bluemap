extends StaticBody2D
## Een bord met een berichtje.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")

var lines: Array = []
var speaker := "Bord"
var world: Node
var t := 0.0
var player: Node2D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 8)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	add_child(shape)


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = Util.player(self)
	queue_redraw()


func interact() -> void:
	GameState.say(speaker, lines)


func _draw() -> void:
	DrawUtil.ellipse(self, Vector2(0, 14), Vector2(9, 3), Color(0, 0, 0, 0.25))
	DrawUtil.sprite(self, Art.tex("sign"), 0, 0)
	if player and player.target == self:
		DrawUtil.prompt(self, Vector2(0, -24.0), t, "E")
