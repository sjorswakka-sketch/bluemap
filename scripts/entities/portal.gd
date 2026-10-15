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
var previous_position:=Vector2.ZERO
var has_previous:=false

func _ready() -> void:
	add_to_group("access_portals")

func available() -> bool:
	return conditions.is_empty() or GameState.check_all(conditions)

## Clip the movement segment against the interior; touching a corner is not entering.
func crossed(from: Vector2,to: Vector2) -> bool:
	var inner:=rect.grow(-0.01)
	var motion:=to-from
	var first:=0.0
	var last:=1.0
	for axis in 2:
		if is_zero_approx(motion[axis]):
			if from[axis]<=inner.position[axis] or from[axis]>=inner.end[axis]:return false
		else:
			var a: float=(inner.position[axis]-from[axis])/motion[axis]
			var b: float=(inner.end[axis]-from[axis])/motion[axis]
			first=maxf(first,minf(a,b));last=minf(last,maxf(a,b))
			if first>=last:return false
	return last-first>0.00001


func _process(delta: float) -> void:
	queue_redraw() # de gloed pulseert en de vonkjes drijven
	message_cooldown = maxf(message_cooldown - delta, 0.0)
	if player == null:
		player = Util.player(self)
		if player!=null:previous_position=player.global_position;has_previous=true
		return
	var at:=player.global_position
	var before:=previous_position
	var had_previous:=has_previous
	previous_position=at;has_previous=true
	if GameState.transitioning or GameState.input_locked():
		armed=false
		return
	var natural_distance: float=(maxf(player.velocity.length(),235.0)+100.0)*maxf(delta,0.0)+8.0
	var entered: bool=rect.has_point(at) or (armed and had_previous and before.distance_to(at)<=natural_distance and crossed(before,at))
	if not entered:
		armed = true
		return
	if not armed:
		return
	if available():
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
	var glow:=GLOW if available() else Color("d6ad68")
	var t := fmod(Time.get_ticks_msec() / 1000.0, 1000.0)
	var pulse := 0.5 + 0.5 * sin(t * 2.2)
	# Een zachte waas over het vlak en een glinsterende rand.
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(glow, 0.07 + 0.06 * pulse))
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(glow, 0.3 + 0.25 * pulse), false, 2.0)
	# Drie vonkjes die langzaam omhoog drijven en onderweg oplichten en doven.
	var span := maxf(rect.size.y, 16.0)
	for i in 3:
		var cycle := fmod(t * 14.0 + i * span / 3.0, span)
		var fx := rect.size.x * (0.2 + 0.3 * i)
		var fy := rect.size.y - cycle
		var fade := sin(PI * cycle / span)
		draw_circle(Vector2(fx, fy), 2.0, Color(1.0, 1.0, 1.0, 0.55 * fade))
