extends Node2D
## Een pijl, steen, slijmbal of arcane bol. Verdwijnt tegen een muur en doet schade aan de speler.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")

const FRAMES := {"arrow": 0, "rock": 1, "slimeball": 2}
const DEFAULT_LIFE := 5.0 # zo lang vliegt een projectiel hoogstens

## Bijzondere projectielen. turn = hoe snel hij bijdraait naar de speler (radialen per seconde), life = hoelang hij
## leeft (seconden) en breakable = je kunt hem met je zwaard stukslaan (player.gd roept dan sword_hit aan).
const TRAITS := {
	"arcane_orb": {"turn": 1.0, "life": 3.0, "breakable": true},
}
const ORB_COLOR := Color(0.75, 0.5, 1.0)
const ORB_FADE := 0.4 # de bol vervaagt in zijn laatste seconden
const ORB_TRAIL := 6 # zoveel puntjes in de lichtstaart
const ORB_TRAIL_STEP := 0.04 # seconden tussen twee puntjes
const SWORD_MARGIN := 10.0 # een bol is iets groter dan een punt: zo ruim raakt het zwaard hem

var kind := "arrow"
var velocity := Vector2.ZERO
var damage := 1
var source := ""
var world: Node
var age := 0.0
var player: Node2D
var max_age := DEFAULT_LIFE
var turn := 0.0
var trail: Array[Vector2] = []
var trail_timer := 0.0


func _ready() -> void:
	var traits: Dictionary = TRAITS.get(kind, {})
	max_age = traits.get("life", DEFAULT_LIFE)
	turn = traits.get("turn", 0.0)
	if traits.get("breakable", false):
		add_to_group("breakable")
	if kind == "arcane_orb" and world != null and world.darkness > 0.0:
		# In donkere gebieden geeft de bol zelf licht, anders zie je hem niet aankomen.
		var light := PointLight2D.new()
		light.texture = Art.light_texture()
		light.texture_scale = 0.8
		light.color = ORB_COLOR
		light.energy = 0.9
		add_child(light)


func _process(delta: float) -> void:
	if is_queued_for_deletion():
		return # net stukgeslagen: raakt niemand meer
	age += delta
	if player == null:
		player = Util.player(self)
	if turn > 0.0 and player and not GameState.ended:
		# Langzaam bijdraaien naar de speler: je kunt hem ontwijken, maar hij laat je niet los.
		var wanted := player.global_position + Vector2(0, 4) - global_position
		velocity = velocity.rotated(clampf(velocity.angle_to(wanted), -turn * delta, turn * delta))
	position += velocity * delta
	if age > max_age or world.is_solid(global_position):
		world.burst(global_position, ORB_COLOR if kind == "arcane_orb" else Color(0.9, 0.9, 0.9), 4)
		queue_free()
		return
	if player and not GameState.ended and global_position.distance_to(player.global_position + Vector2(0, 4)) < 11.0:
		player.hurt(global_position - velocity.normalized() * 8.0, damage, source)
		queue_free()
		return
	if kind == "arcane_orb":
		trail_timer += delta
		if trail_timer >= ORB_TRAIL_STEP:
			trail_timer = 0.0
			trail.append(global_position)
			if trail.size() > ORB_TRAIL:
				trail.pop_front()
	queue_redraw()


## Het zwaard van de speler zwaait vanaf `from` in de richting `facing` en reikt `reach` ver (zie player.gd, alleen
## voor projectielen in de groep "breakable"). Raakt het zwaard hem, dan spat hij uit elkaar.
func sword_hit(from: Vector2, facing: Vector2, reach: float) -> void:
	var to_me := global_position - from
	if to_me.length() <= reach + SWORD_MARGIN and facing.dot(to_me.normalized()) > 0.2:
		shatter()


func shatter() -> void:
	if is_queued_for_deletion():
		return
	Sound.play("mage_orb_pop", 1.0, randf_range(0.95, 1.1))
	world.burst(global_position, ORB_COLOR, 10)
	world.ring(global_position, 22.0, ORB_COLOR)
	queue_free()


func _draw() -> void:
	if kind == "arcane_orb":
		_draw_orb()
		return
	var column: int = FRAMES.get(kind, 0)
	draw_set_transform(Vector2.ZERO, velocity.angle() if kind == "arrow" else age * 8.0, Vector2.ONE)
	DrawUtil.sprite(self, Art.tex("projectiles"), column, 0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_orb() -> void:
	var fade := clampf((max_age - age) / ORB_FADE, 0.0, 1.0)
	for i in trail.size():
		var step := float(i + 1) / float(trail.size() + 1)
		draw_circle(to_local(trail[i]), 2.0 + 3.0 * step, Color(ORB_COLOR, (0.1 + 0.25 * step) * fade))
	draw_circle(Vector2.ZERO, 10.0 + sin(age * 14.0) * 1.5, Color(ORB_COLOR, 0.22 * fade))
	DrawUtil.sprite(self, Art.tex("arcane_orb"), int(age * 12.0) % 4, 0, Vector2.ZERO, Vector2i(16, 16), 2.0, Color(1, 1, 1, fade))
