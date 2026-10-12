extends SceneTree
## Gevels moeten op de bestaande gebouwen passen en de echte ingangen ongemoeid laten.
## Deze test laadt geen spelwereld en schrijft geen spelvoortgang.

const Buildings := preload("res://scripts/data/buildings.gd")
const Landmarks := preload("res://scripts/entities/building_landmarks.gd")
const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
var failures := 0


func check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var destinations: Array[String] = []
	for map_id: String in Buildings.BUILDINGS:
		var data: Dictionary = Maps.get_map(map_id)
		var rows: Array = data["rows"]
		for building: Dictionary in Buildings.for_map(map_id):
			var id: String = building["id"]
			check(not destinations.has(id), "%s heeft één herkenbare buitenkant" % id)
			destinations.append(id)
			var footprint: Rect2i = building["rect"]
			var doorway: Rect2i = building["door"]
			check(Rect2i(0, 0, rows[0].length(), rows.size()).encloses(footprint), "%s past binnen de kaart" % id)
			check(footprint.encloses(doorway), "%s deur ligt binnen zijn gebouw" % id)
			var portal_matches := 0
			for object: Dictionary in data["objects"]:
				if object["type"] != "portal" or object.get("to", "") != id:
					continue
				var pos: Array = object["pos"]
				var size: Array = object.get("size", [1, 1])
				if doorway == Rect2i(pos[0], pos[1], size[0], size[1]):
					portal_matches += 1
			check(portal_matches == 1, "%s versiering houdt precies zijn bestaande ingang vrij" % id)
			var bad_cells: Array = []
			for y in range(footprint.position.y, footprint.end.y):
				for x in range(footprint.position.x, footprint.end.x):
					var cell := Vector2i(x, y)
					if doorway.has_point(cell):
						check(not Tiles.is_solid_char(rows[y][x]), "%s deur %s is beloopbaar" % [id, cell])
					elif not Tiles.is_solid_char(rows[y][x]):
						bad_cells.append(cell)
			check(bad_cells.is_empty(), "%s gevel staat alleen op bestaande muren/daken: %s" % [id, bad_cells])
			var world_door := Buildings.local_door(building)
			world_door.position += Buildings.world_rect(building).position
			check(world_door == Rect2(Vector2(doorway.position) * 32, Vector2(doorway.size) * 32), "%s deuruitsparing gebruikt de echte wereldmaat" % id)
		var node := Landmarks.new()
		node.setup(map_id)
		root.add_child(node)
		await process_frame
		check(_only_decoration(node), "%s gevels hebben geen botsingen of interactie" % map_id)
		node.queue_free()
		await process_frame
	check(destinations.size() == 7, "alle zeven betreedbare openbare gebouwen zijn herkenbaar")
	check(Buildings.for_map("forest").is_empty(), "gevels lekken niet naar andere kaarten")
	var isolated := Buildings.for_map("village")
	isolated[0]["id"] = "changed"
	check(Buildings.for_map("village")[0]["id"] == "smithy", "kaartinstanties delen geen veranderlijke gebouwgegevens")
	print("BUILDINGS TEST OK" if failures == 0 else "BUILDINGS TEST: %d fout(en)" % failures)
	quit(0 if failures == 0 else 1)


func _only_decoration(node: Node) -> bool:
	if node is CollisionObject2D or node is CollisionShape2D or node.has_method("interact"):
		return false
	for child: Node in node.get_children():
		if not _only_decoration(child):
			return false
	return true
