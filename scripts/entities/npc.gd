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
	var previous_beat := floori(t*2.4/PI)
	t += delta
	if npc_id=="greta" and floori(t*2.4/PI)!=previous_beat and GameState.day_time>0.12 and GameState.day_time<0.78 and is_instance_valid(world.player):
		var distance: float = position.distance_to(world.player.position)
		if distance<160: Sound.play("op_hammer",-14-distance/12)
	if player == null:
		player = Util.player(self)
	if not exists_if.is_empty() and not GameState.check_all(exists_if):
		queue_free()
		return
	queue_redraw()


func interact() -> void:
	GameState.note_talked(npc_id)
	if npc_id == "greta" and preload("res://scripts/core/opening.gd").greta_intro():
		return
	var reaction: Array = preload("res://scripts/core/living_world.gd").npc_lines(npc_id)
	if not reaction.is_empty():
		GameState.say(tr(data["name"]), reaction)
		return
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
	if npc_id == "greta" and not GameState.dialogue_open and GameState.day_time>0.12 and GameState.day_time<0.78:
		var lift := -absf(sin(t*2.4))*12
		draw_line(Vector2(10,4),Vector2(20,lift),Color("bc955e"),3)
		draw_rect(Rect2(16,lift-3,10,6),Color("8eabb8"))
		if absf(sin(t*2.4))<0.18:
			draw_line(Vector2(22,5),Vector2(27,0),Color("ffcd70"),2)
	if player and player.target == self:
		DrawUtil.name_tag(self, Vector2(0, -24.0 - (2.0 - scale) * -4.0), tr(data["name"]))
		DrawUtil.prompt(self, Vector2(0, -38.0), t)
