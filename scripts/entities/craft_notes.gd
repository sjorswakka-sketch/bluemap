extends StaticBody2D
const Notes := preload("res://scripts/data/ext/craft_progression.gd")
const Journal := preload("res://scripts/core/craft_journal.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
var world: Node
var obj: Dictionary = {}
var key := ""
var t := 0.0
func _ready() -> void:
	add_to_group("interactable")
	add_to_group("craft_notes")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22,8)
	shape.shape = rect; shape.position = Vector2(0,12)
	add_child(shape)
func _process(delta: float) -> void:
	t += delta
	queue_redraw()
func interact() -> void:
	if GameState.input_locked() or world.player.global_position.distance_to(global_position) > 40: return
	var kind: String = obj.kind
	var note: Dictionary = Notes.NOTES[kind]
	if Journal.learn(kind): Sound.play("pg_pattern",-5)
	GameState.say(tr(note.name),note.lines.map(func(line: String) -> String: return tr(line)))
func _draw() -> void:
	var index: int = ["smith","focus","pack"].find(obj.kind)
	DrawUtil.ellipse(self,Vector2(0,14),Vector2(14,4),Color(0,0,0,0.25))
	DrawUtil.sprite(self,Art.tex("pg_notes"),index*2+int(t*3)%2,0,Vector2(0,-8),Vector2i(24,24),2)
	if not GameState.flag(Notes.NOTES[obj.kind].flag):
		draw_circle(Vector2(14,-23+sin(t*2)),2,Color(1,0.85,0.4))
	if world.player.target == self: DrawUtil.prompt(self,Vector2(0,-38),t)
