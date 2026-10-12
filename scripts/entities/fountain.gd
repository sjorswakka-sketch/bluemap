extends StaticBody2D
## Een stenen fontein op hetzelfde 2-pixelraster als de andere dorpskunst.
## De hele sokkel is solide; world.solid_cells gebruikt dezelfde rechthoek.

const TILE := 32.0
const INK := Color("263747")
const STONE := Color("7c939e")
const LIGHT := Color("bdd1d7")
const WATER := Color("3689b3")
const FOAM := Color("bceff5")

var footprint := Rect2i(0, 0, 2, 2)
var clock := 0.0
var animation_frame := 0


func setup(cells: Rect2i) -> void:
	footprint = cells
	position = (Vector2(cells.position) + Vector2(cells.size) * 0.5) * TILE


func _ready() -> void:
	add_to_group("fountains")
	collision_layer = 1
	collision_mask = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(footprint.size) * TILE
	collider.shape = shape
	add_child(collider)


func _process(delta: float) -> void:
	clock = fmod(clock + maxf(delta, 0.0), 12.0)
	var next_frame := int(clock * 12.0)
	if next_frame != animation_frame:
		animation_frame = next_frame
		queue_redraw()


func _r(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(x, y, width, height), color)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(footprint.size) / 2.0)
	# De brede vierkante sokkel staat geheel binnen de botsingsvoetafdruk.
	_r(-32, -32, 64, 64, INK)
	_r(-30, -30, 60, 56, STONE)
	_r(-30, 26, 60, 4, Color("536f7e"))
	_r(-28, -30, 56, 4, LIGHT)
	_r(-30, -26, 4, 48, Color("9fbac3"))
	_r(26, -26, 4, 48, Color("647f90"))
	# Open water, schaduw onder de rand en de voorwand met steenvoegen.
	_r(-24, -24, 48, 40, Color("235975"))
	_r(-22, -22, 44, 36, WATER)
	_r(-22, 10, 44, 4, Color("2c739a"))
	_r(-26, 16, 52, 8, Color("8da7b3"))
	_r(-26, 16, 52, 2, LIGHT)
	for x in [-20, -6, 8, 22]:
		_r(x, 20, 2, 6, Color("587584"))
	for y in [-22, -8, 6]:
		_r(-30, y, 6, 2, Color("587584"))
		_r(24, y + 6, 6, 2, Color("587584"))
	# Kringetjes en lichtjes bewegen los van elkaar.
	var phase := float(animation_frame) / 12.0
	for i in 5:
		var p := fmod(phase * 0.9 + i * 0.21, 1.0)
		var x := -18.0 + float((i * 11) % 36)
		var y := -16.0 + float((i * 7) % 24)
		var radius := 2.0 + floorf(p * 3.0) * 2.0
		_r(x - radius, y, radius * 2.0, 2, Color(FOAM, (1.0 - p) * 0.7))
	# Centrale zuil en schaal; de fontein spuit boven het bassin uit.
	_r(-8, -12, 16, 22, INK)
	_r(-6, -12, 12, 20, STONE)
	_r(-6, -12, 4, 18, LIGHT)
	_r(-12, -18, 24, 8, INK)
	_r(-10, -18, 20, 4, LIGHT)
	_r(-8, -16, 16, 2, Color("64b9d1"))
	_r(-2, -34, 4, 18, Color("5cc5df"))
	_r(0, -34, 2, 18, FOAM)
	for side in [-1.0, 1.0]:
		for i in 5:
			var p := fmod(phase * 0.85 + i * 0.2, 1.0)
			var drop := Vector2(side * (2.0 + p * 16.0), -34.0 - sin(p * PI) * 8.0 + p * p * 34.0)
			drop = (drop / 2.0).floor() * 2.0
			_r(drop.x, drop.y, 2, 4, FOAM if i % 2 == 0 else Color("74d8e8"))
		var splash := 2.0 + float(animation_frame % 3) * 2.0
		_r(side * 18.0 - splash, 2, splash * 2.0, 2, FOAM)
	draw_set_transform(Vector2.ZERO)
