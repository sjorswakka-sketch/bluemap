extends StaticBody2D
## Een lessenaar met een open boek in de bibliotheek. E om te lezen. De teksten staan in scripts/data/ext/meer_boeken.gd.
## In de kaart: {"type": "meer_lessenaar", "pos": [x, y], "id": "wachter"}.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Boeken := preload("res://scripts/data/ext/meer_boeken.gd")
const Logic := preload("res://scripts/data/ext/meer_logic.gd")

var world: Node
var obj: Dictionary = {}
var key := ""
var book_id := ""
var t := randf() * 4.0
var player: Node2D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	book_id = obj.get("id", "")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 10)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	add_child(shape)


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = Util.player(self)
	queue_redraw()


func is_read() -> bool:
	return GameState.flag(Boeken.flag_name(book_id))


func interact() -> void:
	var text: Dictionary = Boeken.TEXTS[book_id]
	var first_time := not is_read()
	GameState.set_flag(Boeken.flag_name(book_id))
	Sound.play("meer_blad", -4.0)
	GameState.say(text["title"], text["lines"])
	if first_time and Logic.read_count() == Boeken.TEXTS.size():
		GameState.toast.emit("Je hebt alle boeken in de bibliotheek gelezen!")


func _draw() -> void:
	DrawUtil.ellipse(self, Vector2(0, 14), Vector2(10, 3), Color(0, 0, 0, 0.25))
	# Een boek dat je nog niet gelezen hebt, glinstert af en toe.
	var glint := not is_read() and fmod(t, 2.4) < 0.5
	DrawUtil.sprite(self, Art.tex("meer_objects"), 1 if glint else 0, 0)
	if player and player.target == self:
		DrawUtil.prompt(self, Vector2(0, -24.0), t)
