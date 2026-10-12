extends "res://scripts/entities/gate.gd"
## De kristalpoort in de Kristalgangen. Werkt precies als een gewone poort (zie gate.gd): dicht zolang `block_if`
## klopt, en een sleutel (`key`) opent hem. Alleen het uiterlijk is anders.
##
## Kaartvorm: {"type": "diepte_gate", "pos": [21, 10], "id": "depths", "size": [3, 1], "key": "diepte_key",
##             "block_if": [["no_flag", "gate_depths"]], "locked_text": "..."}

const OPEN_COLOR := Color(0.8, 0.6, 1.0)

var obj: Dictionary = {}
var key := "" # (de wereld vult dit in, de poort gebruikt `key_item` uit gate.gd)


func _ready() -> void:
	gate_id = obj["id"]
	var size: Array = obj.get("size", [1, 1])
	size_tiles = Vector2i(size[0], size[1])
	block_if = obj.get("block_if", [])
	key_item = obj.get("key", "")
	locked_text = obj.get("locked_text", "De poort zit op slot.")
	super._ready()


func interact() -> void:
	var had_key := key_item != "" and GameState.count(key_item) > 0
	super.interact()
	if had_key:
		# De staven spatten uiteen in kristalsplinters.
		Sound.play("crystal", -2.0)
		world.shake(3.0)
		for x in size_tiles.x:
			world.burst(global_position + Vector2(x * 32.0, 0.0), OPEN_COLOR, 14)


func _draw() -> void:
	if not blocked:
		return
	for y in size_tiles.y:
		for x in size_tiles.x:
			DrawUtil.sprite(self, Art.tex("depths_objects"), 2, 0, Vector2(x * 32.0, y * 32.0))
	if player and player.target == self:
		DrawUtil.prompt(self, Vector2(float(size_tiles.x - 1) * 16.0, -26.0), t)
