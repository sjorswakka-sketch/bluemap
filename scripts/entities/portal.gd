extends Node2D
## Een doorgang naar een andere kaart. Je loopt er gewoon in. Optioneel op slot met voorwaarden.

const Util := preload("res://scripts/core/util.gd")

var target_map := ""
var target_spawn := "start"
var rect := Rect2() # in wereldcoördinaten
var conditions: Array = []
var locked_text := ""
var world: Node
var player: Node2D
var armed := false # pas actief als je er een keer niet in stond (anders stuiter je heen en weer)
var message_cooldown := 0.0


func _process(delta: float) -> void:
	message_cooldown = maxf(message_cooldown - delta, 0.0)
	if player == null:
		player = Util.player(self)
		return
	if GameState.transitioning or GameState.input_locked():
		return
	if not rect.has_point(player.global_position):
		armed = true
		return
	if not armed:
		return
	if conditions.is_empty() or GameState.check_all(conditions):
		armed = false
		world.travel(target_map, target_spawn)
	elif message_cooldown <= 0.0:
		message_cooldown = 2.5
		Sound.play("error", -3.0)
		if locked_text != "":
			GameState.toast.emit(tr(locked_text))
