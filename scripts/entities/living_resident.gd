extends StaticBody2D
## Teruggekeerde bewoners delen de botsing en y-sortering van gewone NPC's.
const Art := preload("res://scripts/core/art.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const CharacterDraw := preload("res://scripts/core/character_draw.gd")
var sheet := "npc_fenna"
var time := 0.0

func _ready() -> void:
	add_to_group("living_residents")
	collision_layer = 1
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(14, 10)
	collider.shape = box
	collider.position = Vector2(0, 8)
	add_child(collider)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	DrawUtil.ellipse(self, Vector2(0, 14), Vector2(10, 4), Color(0, 0, 0, 0.25))
	CharacterDraw.actor(self,sheet,time,Vector2.ZERO)
