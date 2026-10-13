extends SceneTree
## Bereikbaarheid van de drie polish-gebieden (Dauwbos, IJsdal, Dorstvallei).
## Leest de objecten en beroepsplekken uit de data zelf, zodat de test meebeweegt
## als een kaart opnieuw wordt vormgegeven.

const Tiles := preload("res://scripts/data/tiles.gd")
const Beroepen := preload("res://scripts/data/ext/beroepen.gd")
const Dauwbos := preload("res://scripts/maps/dauwbos.gd")
const IJsdal := preload("res://scripts/maps/ijsdal.gd")
const Dorstvallei := preload("res://scripts/maps/dorstvallei.gd")

var failures := 0


func check(ok: bool, label: String) -> void:
	print("  ok   " if ok else "  FAIL ", label)
	if not ok:
		failures += 1


func reach(rows: Array, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := p + d
			if seen.has(n) or n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= String(rows[n.y]).length():
				continue
			if Tiles.is_solid_char(String(rows[n.y])[n.x]):
				continue
			seen[n] = true
			queue.append(n)
	return seen


func tile_free(rows: Array, pos: Vector2i) -> bool:
	return pos.y >= 0 and pos.y < rows.size() and pos.x >= 0 and pos.x < String(rows[pos.y]).length() and not Tiles.is_solid_char(String(rows[pos.y])[pos.x])


func near(seen: Dictionary, rows: Array, pos: Vector2i) -> bool:
	if tile_free(rows, pos) and seen.has(pos):
		return true
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if seen.has(pos + d):
			return true
	return false


func check_map(map_id: String, data: Dictionary) -> void:
	var rows: Array = data["rows"]
	var spawns: Dictionary = data["spawns"]
	var start := Vector2i(int(spawns["start"][0]), int(spawns["start"][1]))
	check(tile_free(rows, start), "%s: spawn begaanbaar" % map_id)
	var seen := reach(rows, start)
	for key: String in spawns:
		var pos := Vector2i(int(spawns[key][0]), int(spawns[key][1]))
		check(tile_free(rows, pos), "%s: spawn '%s' begaanbaar" % [map_id, key])
	for obj: Dictionary in data["objects"]:
		var pos := Vector2i(int(obj["pos"][0]), int(obj["pos"][1]))
		var size: Array = obj.get("size", [1, 1])
		var label := "%s %s (%d,%d)" % [obj["type"], obj.get("id", obj.get("item", "")), pos.x, pos.y]
		var bereikbaar := false
		for dy: int in int(size[1]):
			for dx: int in int(size[0]):
				if near(seen, rows, pos + Vector2i(dx, dy)):
					bereikbaar = true
		check(bereikbaar, "%s: %s bereikbaar" % [map_id, label])
	for res: Dictionary in Beroepen.resource_objects(map_id):
		var pos := Vector2i(int(res["pos"][0]), int(res["pos"][1]))
		check(tile_free(rows, pos), "%s: %s begaanbaar" % [map_id, res["id"]])
		check(near(seen, rows, pos), "%s: %s bereikbaar" % [map_id, res["id"]])


func _initialize() -> void:
	check_map("dauwbos", Dauwbos.DATA)
	check_map("ijsdal", IJsdal.DATA)
	check_map("dorstvallei", Dorstvallei.DATA)
	print("GEBIEDEN ROUTE OK" if failures == 0 else "GEBIEDEN ROUTE FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
