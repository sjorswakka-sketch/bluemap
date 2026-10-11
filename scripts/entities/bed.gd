extends Node2D
## Een bed in de herberg. Druk op E om te slapen (zie de gesprekken "wereld_bed*" in scripts/data/ext/wereld.gd).
## De tegel zelf is het bed uit tiles.png; dit object zorgt voor de "E" en het gesprek.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Util := preload("res://scripts/core/util.gd")

var world: Node
var obj: Dictionary = {}
var key := ""
var t := randf() * TAU
var player: Node2D


func _ready() -> void:
	add_to_group("interactable")


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = Util.player(self)
	queue_redraw()


func interact() -> void:
	GameState.start_dialogue("wereld_bed")


func _draw() -> void:
	if player and player.target == self:
		DrawUtil.prompt(self, Vector2(0, -26.0), t)
