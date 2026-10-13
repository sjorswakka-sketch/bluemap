extends Node2D
## Een doorgang naar een andere kaart. Je loopt er gewoon in. Optioneel op slot met voorwaarden.
## Het vlak zelf is onzichtbaar, dus tekent _draw() een zachte gloed met zwevende vonkjes:
## zo zie je in elk gebied meteen waar je naar een andere plek kunt.

const Util := preload("res://scripts/core/util.gd")

const GLOW := Color(0.55, 0.8, 1.0) # dezelfde blauwtint als de altaren voor snel reizen

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
	queue_redraw() # de gloed pulseert en de vonkjes drijven
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


func _draw() -> void:
	# De node staat op de hoek van het vlak (zie world.gd), dus hier tekenen we plaatselijk.
	if rect.size == Vector2.ZERO:
		return
	var t := fmod(Time.get_ticks_msec() / 1000.0, 1000.0)
	var pulse := 0.5 + 0.5 * sin(t * 2.2)
	# Een zachte waas over het vlak en een glinsterende rand.
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(GLOW, 0.07 + 0.06 * pulse))
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(GLOW, 0.3 + 0.25 * pulse), false, 2.0)
	# Drie vonkjes die langzaam omhoog drijven en onderweg oplichten en doven.
	var span := maxf(rect.size.y, 16.0)
	for i in 3:
		var cycle := fmod(t * 14.0 + i * span / 3.0, span)
		var fx := rect.size.x * (0.2 + 0.3 * i)
		var fy := rect.size.y - cycle
		var fade := sin(PI * cycle / span)
		draw_circle(Vector2(fx, fy), 2.0, Color(1.0, 1.0, 1.0, 0.55 * fade))
