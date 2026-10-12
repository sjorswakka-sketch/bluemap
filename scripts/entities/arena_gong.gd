extends StaticBody2D
## De gong in de arena, naast de uitgang. Tijdens een toernooi kun je er opgeven (het gesprek `talk` van het object);
## anders galmt hij gewoon.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Arena := preload("res://scripts/data/arena.gd")

const RING_TIME := 0.9

var world: Node
var obj: Dictionary = {}
var key := ""
var ring := 0.0 # hoe lang de gong nog trilt
var t := 0.0
var player: Node2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("arena_gong")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 12)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	add_child(shape)


func _process(delta: float) -> void:
	t += delta
	ring = maxf(ring - delta, 0.0)
	if player == null:
		player = Util.player(self)
	queue_redraw()


## De gong trilt even (de arenameester slaat hem aan het begin van elke ronde).
func strike() -> void:
	ring = RING_TIME


func interact() -> void:
	if Arena.run_active:
		GameState.start_dialogue(obj.get("talk", "arena_forfeit_ask"))
		return
	Sound.play("arena_gong", -5.0)
	strike()
	GameState.say(tr("Gong"), [tr("Een enorme bronzen gong. Bruno slaat hem aan het begin van elke ronde.")])


func _draw() -> void:
	DrawUtil.ellipse(self, Vector2(0, 14), Vector2(12, 3), Color(0, 0, 0, 0.25))
	var shaking := ring > 0.0 and int(ring * 30.0) % 2 == 0
	DrawUtil.sprite(self, Art.tex("arena_props"), 1 if shaking else 0, 0)
	if player and player.target == self:
		DrawUtil.prompt(self, Vector2(0, -28.0), t)
