extends Node2D
## De ramen van de huizen gloeien 's nachts warm geel. Elk raam krijgt een klein lichtje (PointLight2D)
## en een gele gloed over het glas. Overdag is er niets te zien.

const Art := preload("res://scripts/core/art.gd")

const TILE := 32.0 # grootte van een tegel in de wereld
const PANES: Array[Rect2] = [ # de vier ruitjes van het raam, in pixels van de tegel (16x16)
	Rect2(4, 4, 3, 3), Rect2(8, 4, 4, 3), Rect2(4, 8, 3, 4), Rect2(8, 8, 4, 4),
]
const GLASS := Color(1.0, 0.86, 0.48)
const WINDOW_LIGHT := 0.55 # zachter dan een lantaarn

var world: Node
var cells: Array[Vector2i] = [] # de tegels met een raam
var lights: Array[PointLight2D] = []


func _ready() -> void:
	for cell in cells:
		var light := PointLight2D.new()
		light.texture = Art.light_texture()
		light.color = Color(1.0, 0.8, 0.45)
		light.texture_scale = 1.0 # een straal van ongeveer twee tegels
		light.energy = 0.0
		light.enabled = false
		light.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE + Vector2(0, 6) # iets onder het midden van het raam
		add_child(light)
		lights.append(light)


func _process(_delta: float) -> void:
	var need := _need()
	for light in lights:
		light.enabled = need > 0.02
		light.energy = WINDOW_LIGHT * need
	queue_redraw()


func _need() -> float:
	return world.light_need() if world != null else 0.0


func _draw() -> void:
	var need := _need()
	if need <= 0.02:
		return
	for cell in cells:
		var origin := Vector2(cell) * TILE
		for pane in PANES:
			draw_rect(Rect2(origin + pane.position * 2.0, pane.size * 2.0), Color(GLASS, clampf(need * 1.2, 0.0, 1.0)))
