extends Node2D
## Een onzichtbaar vlak. Loop je erin, dan worden eenmalig acties uitgevoerd (bijvoorbeeld de baas starten).

const Util := preload("res://scripts/core/util.gd")

var rect := Rect2()
var conditions: Array = []
var once_flag := ""
var actions: Array = []
var world: Node
var player: Node2D


func _process(_delta: float) -> void:
	if player == null:
		player = Util.player(self)
		return
	if GameState.input_locked() or not rect.has_point(player.global_position):
		return
	if once_flag != "" and GameState.flag(once_flag):
		return
	if not conditions.is_empty() and not GameState.check_all(conditions):
		return
	if once_flag != "":
		GameState.set_flag(once_flag)
	GameState.run_all(actions)
