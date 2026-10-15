extends Node2D
## De geheime boekenkast in de bibliotheek. Hij staat gewoon als boekenkast in de kaart; zodra `open_if` klopt
## (Lena heeft haar boeken terug) schuift hij open en wordt de plek vloer, zodat je het achterkamertje in kunt.
## In de kaart: {"type": "meer_kast", "pos": [x, y], "size": [1, 2], "open_if": [["flag", "meer_achterkamer"]]}.

const Tiles := preload("res://scripts/data/tiles.gd")

const DUST := Color(0.85, 0.78, 0.65)

var world: Node
var obj: Dictionary = {}
var key := ""
var cells: Array[Vector2i] = []
var open_if: Array = []
var opened := false


func _ready() -> void:
	open_if = obj.get("open_if", [])
	var size: Array = obj.get("size", [1, 1])
	for dy in int(size[1]):
		for dx in int(size[0]):
			cells.append(Vector2i(int(obj["pos"][0]) + dx, int(obj["pos"][1]) + dy))
	# Was de kast al open toen je het spel laadde? Dan meteen, zonder effecten.
	if GameState.check_all(open_if):
		_clear_cells()


func _process(_delta: float) -> void:
	# Pas als het gesprek met Lena voorbij is gaat de kast open, zodat je het ziet gebeuren.
	if not opened and not GameState.input_locked() and GameState.check_all(open_if):
		_clear_cells()
		Sound.play("meer_kast")
		world.shake(4.0)
		for cell in cells:
			world.burst(Vector2(cell) * 32.0 + Vector2(16, 16), DUST, 14)
		GameState.toast.emit(tr("De geheime kast schuift opzij!"))


func _clear_cells() -> void:
	opened = true
	for cell in cells:
		var row: String=world.map_data.rows[cell.y]
		world.map_data.rows[cell.y]=row.substr(0,cell.x)+"Q"+row.substr(cell.x+1)
		world.tile_layer.set_cell(cell, 0, preload("res://scripts/core/pixel_landscape.gd").atlas("meer_bibvloer",cell.x,cell.y))
		world.solid_cells.erase(cell)
	if is_instance_valid(world.landscape):world.landscape.refresh()
