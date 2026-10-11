extends StaticBody2D
## Een kristalpilaar in Het Hart van de Kaart. Op bevel van De Vergeten Wachter laadt hij op (rode lijnen laten zien
## waar de scherven heen gaan) en schiet dan een ring scherven weg, met gaten waar je doorheen kunt lopen of rollen.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const ShardScript := preload("res://scripts/entities/guardian_shard.gd")

const LANE_LENGTH := 150.0 # hoe lang de rode lijnen zijn
const SHARD_START := 22.0 # de scherven beginnen een stukje van de pilaar vandaan
const RING_PAUSE := 0.7 # tijd tussen twee ringen vlak na elkaar (woede-fase)
const WARNING := Color(1.0, 0.25, 0.3)

var world: Node
var t := randf() * TAU
var angles: Array[float] = [] # de richtingen van de scherven in de volgende ring (de gaten ontbreken)
var step := 0.0 # hoek tussen twee scherven, voor de tweede ring
var windup := 0.0 # tijd tot de eerste ring (alleen als de pilaar oplaadt)
var windup_total := 1.0
var rings_left := 0
var ring_wait := 0.0
var shard_speed := 100.0
var charging := false
var flash := 0.0
var source := "De Vergeten Wachter (scherf)"


func _ready() -> void:
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 14)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	add_child(shape)


## Laat de pilaar opladen. `ring_angles` zijn de richtingen van de scherven (zonder de gaten), `rings` hoeveel ringen
## er na elkaar komen (de tweede ring is een halve stap gedraaid).
func begin_volley(ring_angles: Array[float], ring_step: float, wind_up: float, speed: float, rings: int) -> void:
	angles = ring_angles
	step = ring_step
	windup = wind_up
	windup_total = wind_up
	shard_speed = speed
	rings_left = rings
	ring_wait = 0.0
	charging = true
	Sound.play("pillar_charge", -6.0)


## Stopt direct met opladen en schieten (bij een fasewissel of als de baas valt).
func cancel() -> void:
	charging = false
	rings_left = 0
	windup = 0.0


func is_busy() -> bool:
	return charging


func _process(delta: float) -> void:
	t += delta
	flash = maxf(flash - delta, 0.0)
	if charging:
		if windup > 0.0:
			windup -= delta
			if windup <= 0.0:
				_fire()
		elif rings_left > 0:
			ring_wait -= delta
			if ring_wait <= 0.0:
				_fire()
		if rings_left <= 0 and windup <= 0.0:
			charging = false
	queue_redraw()


func _fire() -> void:
	rings_left -= 1
	flash = 0.25
	Sound.play("shard_burst", -4.0)
	var origin := global_position + Vector2(0, 2)
	for angle in angles:
		var dir := Vector2.from_angle(angle)
		var shard: Node2D = ShardScript.new()
		shard.set("world", world)
		shard.set("velocity", dir * shard_speed)
		shard.set("source", source)
		shard.position = origin + dir * SHARD_START
		get_parent().add_child(shard)
	world.burst(origin, Color(0.8, 0.55, 1.0), 10)
	world.ring(origin, 44.0, Color(0.8, 0.55, 1.0))
	if rings_left > 0:
		# De volgende ring zit een halve stap verder gedraaid, en de gaten schuiven mee.
		var turned: Array[float] = []
		for angle in angles:
			turned.append(angle + step * 0.5)
		angles = turned
		ring_wait = RING_PAUSE


func _draw() -> void:
	var hot := charging and windup > 0.0
	var pulse := 0.5 + 0.5 * sin(t * 18.0)
	# de kring op de grond
	DrawUtil.ellipse(self, Vector2(0, 14), Vector2(15, 5), Color(0, 0, 0, 0.3))
	if hot:
		var progress := 1.0 - windup / maxf(windup_total, 0.01)
		draw_circle(Vector2(0, -22), 18.0 + progress * 10.0, Color(WARNING, 0.12 + progress * 0.25))
		# rode lijnen: de paden van de scherven. Zonder lijn = een gat waar je veilig doorheen kunt.
		var alpha := 0.25 + progress * 0.5 + (pulse * 0.2 if progress > 0.7 else 0.0)
		for angle in angles:
			var dir := Vector2.from_angle(angle)
			draw_line(Vector2(0, 2) + dir * SHARD_START, Vector2(0, 2) + dir * LANE_LENGTH, Color(WARNING, alpha), 3.0)
	elif flash > 0.0:
		draw_circle(Vector2(0, -22), 24.0 * (flash / 0.25), Color(0.9, 0.7, 1.0, 0.35))
	var frame := 1 if hot or flash > 0.0 else 0
	DrawUtil.sprite(self, Art.tex("depths_pillar"), frame, 0, Vector2(0, -16), Vector2i(16, 32), 2.0)
