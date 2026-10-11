extends StaticBody2D
## Versiering in de arena en de hal: een vaandel aan de muur of een wapenrek.
## Op de kaart: {"type": "arena_prop", "pos": [5, 4], "kind": "banner"} of kind "rack" (daar loop je niet doorheen).

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")

## Vakje in assets/arena_props.png per soort (0 en 1 zijn de gong).
const FRAMES := {"rack": 2, "banner": 3}

var world: Node
var obj: Dictionary = {}
var key := ""
var kind := "banner"


func _ready() -> void:
	kind = obj.get("kind", "banner")
	if kind == "rack":
		collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(26, 12)
		shape.shape = rect
		shape.position = Vector2(0, 8)
		add_child(shape)
	queue_redraw()


func _draw() -> void:
	if kind == "rack":
		DrawUtil.ellipse(self, Vector2(0, 14), Vector2(12, 3), Color(0, 0, 0, 0.25))
	DrawUtil.sprite(self, Art.tex("arena_props"), int(FRAMES.get(kind, 3)), 0)
