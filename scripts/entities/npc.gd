extends StaticBody2D
## Een personage waar je mee kunt praten. Welk gesprek je krijgt staat in scripts/data/npcs.gd.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Npcs := preload("res://scripts/data/npcs.gd")

var npc_id := ""
var data: Dictionary = {}
var world: Node
var exists_if: Array = [] # voorwaarden om er te blijven (de kat verdwijnt als je haar gevonden hebt)
var t := randf() * TAU
var player: Node2D


func setup(id: String) -> void:
	npc_id = id
	data = Npcs.info(id)


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc")
	collision_layer = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 10)
	shape.shape = rect
	shape.position = Vector2(0, 8) # botsing onderin
	add_child(shape)


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = Util.player(self)
	if not exists_if.is_empty() and not GameState.check_all(exists_if):
		queue_free()
		return
	queue_redraw()


func interact() -> void:
	for rule: Dictionary in data["rules"]:
		if not rule.has("if") or GameState.check_all(rule["if"]):
			GameState.start_dialogue(rule["talk"])
			return


func _draw() -> void:
	var scale: float = data.get("scale", 2.0)
	var ghost: bool = data.get("ghost", false)
	var drop := 14.0 - 7.0 * scale # kleine personages staan op dezelfde grond
	var float_y := sin(t * 2.0) * 3.0 - 4.0 if ghost else 0.0
	DrawUtil.ellipse(self, Vector2(0, 14), Vector2(5.0 * scale, 2.0 * scale), Color(0, 0, 0, 0.12 if ghost else 0.3))
	var tint := Color(1, 1, 1, 0.78 + sin(t * 3.0) * 0.1) if ghost else Color.WHITE
	DrawUtil.sprite(self, Art.tex(data["sheet"]), int(t * 1.6) % 2, 0, Vector2(0, drop + float_y), Vector2i(16, 16), scale, tint)
	if player and player.target == self:
		DrawUtil.name_tag(self, Vector2(0, -24.0 - (2.0 - scale) * -4.0), data["name"])
		DrawUtil.prompt(self, Vector2(0, -38.0), t)
