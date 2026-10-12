extends StaticBody2D
## Een poort die de weg blokkeert zolang `block_if` klopt. Met een sleutel kun je hem openen.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")

var gate_id := ""
var size_tiles := Vector2i(1, 1)
var block_if: Array = []   # de poort is dicht zolang dit klopt
var key_item := ""         # voorwerp dat de poort opent (wordt gebruikt)
var locked_text := "" # de melding als hij dicht zit (Nederlands, uit de kaart; leeg: "De poort zit op slot.")
var world: Node
var blocked := true
var shape: CollisionShape2D
var t := 0.0
var player: Node2D


func _ready() -> void:
	collision_layer = 1
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size_tiles) * 32.0
	shape.shape = rect
	shape.position = rect.size / 2.0 - Vector2(16, 16)
	add_child(shape)
	_refresh(true)


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = Util.player(self)
	_refresh(false)
	queue_redraw()


func _refresh(first: bool) -> void:
	var now := GameState.check_all(block_if) if not block_if.is_empty() else true
	if now == blocked and not first:
		return
	if not first and not now and blocked:
		Sound.play("door")
	blocked = now
	shape.set_deferred("disabled", not blocked)
	if blocked: # dicht: je kunt hem aanspreken (een sleutel gebruiken, of horen waarom hij dicht is)
		add_to_group("interactable")
	else:
		remove_from_group("interactable")


func interact() -> void:
	if key_item != "" and GameState.count(key_item) > 0:
		GameState.take(key_item)
		GameState.set_flag("gate_" + gate_id)
		GameState.toast.emit(tr("Je opent het poortje met de sleutel."))
	else:
		Sound.play("error", -3.0)
		GameState.toast.emit(tr(locked_text) if locked_text != "" else tr("De poort zit op slot."))


func _draw() -> void:
	if not blocked:
		return
	for y in size_tiles.y:
		for x in size_tiles.x:
			DrawUtil.sprite(self, Art.tex("gate"), 0, 0, Vector2(x * 32.0, y * 32.0), Vector2i(16, 16), 2.0)
	if player and player.target == self:
		DrawUtil.prompt(self, Vector2(float(size_tiles.x - 1) * 16.0, -26.0), t)
