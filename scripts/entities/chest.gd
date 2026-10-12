extends StaticBody2D
## Een kist met spullen erin. Eenmaal geopend blijft hij open (ook na opslaan).

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Items := preload("res://scripts/data/items.gd")

var contents: Array = [] # [["potion", 1], ["coins", 25]]
var unique_key := ""
var world: Node
var opened := false
var t := 0.0
var player: Node2D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	opened = unique_key != "" and GameState.flag(unique_key)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 12)
	shape.shape = rect
	shape.position = Vector2(0, 6)
	add_child(shape)


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = Util.player(self)
	queue_redraw()


func interact() -> void:
	if opened:
		GameState.toast.emit(tr("De kist is leeg."))
		return
	# Past iets niet meer (een volle pijlenkoker)? Dan blijft de kist dicht, zodat er niets verloren gaat.
	for entry: Array in contents:
		if entry[0] != "coins" and GameState.room(entry[0]) < int(entry[1]):
			Sound.play("error", -3.0)
			var info := Items.info(entry[0])
			GameState.toast.emit(tr(info["chest_full_text"]) if info.has("chest_full_text") else tr("Je tas is te vol voor wat er in deze kist zit."))
			return
	opened = true
	if unique_key != "":
		GameState.set_flag(unique_key)
	Sound.play("chest")
	world.burst(global_position + Vector2(0, -6), Color(1, 0.9, 0.5), 12)
	for entry: Array in contents:
		if entry[0] == "coins":
			GameState.add_coins(int(entry[1]))
			var coins := int(entry[1])
			GameState.toast.emit(tr_n("Gevonden: %d munt", "Gevonden: %d munten", coins) % coins)
		else:
			GameState.give(entry[0], int(entry[1]))


func _draw() -> void:
	DrawUtil.ellipse(self, Vector2(0, 12), Vector2(11, 3.5), Color(0, 0, 0, 0.3))
	DrawUtil.sprite(self, Art.tex("chest"), 1 if opened else 0, 0)
	if not opened and player and player.target == self:
		DrawUtil.prompt(self, Vector2(0, -26.0), t)
