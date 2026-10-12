extends Node2D
## Small non-blocking resource props, independent of the map's permanent trees.

const Professions := preload("res://scripts/core/professions.gd")
const Data := preload("res://scripts/data/ext/beroepen.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Util := preload("res://scripts/core/util.gd")
const Art := preload("res://scripts/core/art.gd")

var world: Node
var obj: Dictionary = {}
var key := ""
var resource_id := ""
var kind := ""
var player: Node2D
var t := 0.0
var hint_wait := 0.0


func _ready() -> void:
	kind = obj.get("kind", "branches")
	resource_id = obj.get("id", key)
	add_to_group("interactable")
	add_to_group("profession_resources")


func _process(delta: float) -> void:
	t += delta
	hint_wait = maxf(hint_wait - delta, 0.0)
	if player == null:
		player = Util.player(self)
	queue_redraw()


func interact() -> void:
	if GameState.input_locked() or hint_wait > 0.0:
		return
	hint_wait = 0.5
	if Professions.gather(kind, resource_id):
		Sound.play("coin", -8.0)
		world.burst(global_position, Data.RESOURCES[kind]["color"], 7)
	else:
		Sound.play("error", -6.0)
	queue_redraw()


func _draw() -> void:
	if kind == "":
		return
	var wait := Professions.remaining(resource_id)
	var tint := Color(0.55, 0.55, 0.55, 0.4) if wait > 0.0 else Color.WHITE
	DrawUtil.ellipse(self, Vector2(0, 7), Vector2(11, 4), Color(0, 0, 0, 0.24))
	var frame: int = Data.RESOURCES.keys().find(kind)
	draw_texture_rect_region(Art.tex("resources_beroepen"), Rect2(-16, -24, 32, 32), Rect2(frame * 16, 0, 16, 16), tint)
	if wait <= 0.0:
		var color: Color = Data.RESOURCES[kind]["color"]
		draw_circle(Vector2(10, -18 + sin(t * 2.0) * 2.0), 1.5, color)
	if player and player.target == self and not GameState.input_locked():
		var label: String = Data.RESOURCES[kind]["name"]
		if wait > 0.0:
			label = Data.TEXT["depleted"] % ceili(wait)
		DrawUtil.name_tag(self, Vector2(0, -28), label)
		if wait <= 0.0:
			DrawUtil.prompt(self, Vector2(0, -42), t)
