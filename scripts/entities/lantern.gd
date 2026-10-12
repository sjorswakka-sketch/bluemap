extends StaticBody2D
## Een lantaarnpaal. Overdag is hij uit, 's avonds en 's nachts brandt hij en geeft hij warm licht.
## Op de kaart:  {"type": "wereld_lantaarn", "pos": [18, 10]}

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")

const CELL := Vector2i(16, 32) # een vakje in assets/wereld_lantaarn.png: uit, aan, aan (flikkert)
const LIGHT_ENERGY := 0.55 # zo fel schijnt hij 's nachts

var world: Node
var obj: Dictionary = {}
var key := ""
var t := randf() * TAU
var light: PointLight2D


func _ready() -> void:
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 6)
	shape.shape = rect
	shape.position = Vector2(0, 10) # alleen de voet van de paal botst
	add_child(shape)
	light = PointLight2D.new()
	light.texture = Art.light_texture()
	light.color = Color(1.0, 0.76, 0.42)
	light.texture_scale = 2.0 # een straal van ongeveer vier tegels
	light.position = Vector2(0, -24) # bij de lamp, bovenin de paal
	light.enabled = false
	add_child(light)


func _process(delta: float) -> void:
	t += delta
	var need := _need()
	light.enabled = need > 0.02
	light.energy = need * (LIGHT_ENERGY + sin(t * 7.0) * 0.03 + sin(t * 19.0) * 0.02) # een heel klein beetje flikkeren
	queue_redraw()


func _need() -> float:
	return world.light_need() if world != null else 0.0


func _draw() -> void:
	DrawUtil.ellipse(self, Vector2(0, 14), Vector2(7, 2.5), Color(0, 0, 0, 0.3))
	var lit := _need() > 0.15
	var frame := 0 if not lit else 1 + int(t * 4.0) % 2
	DrawUtil.sprite(self, Art.tex("wereld_lantaarn"), frame, 0, Vector2(0, -16), CELL, 2.0)
