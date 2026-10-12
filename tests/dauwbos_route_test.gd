extends SceneTree
## Bereikbaarheid van het Dauwbos: ingang, portalen, altaar, NPCs en pickups.

const Tiles := preload("res://scripts/data/tiles.gd")
const Forest := preload("res://scripts/maps/forest.gd")
const Dauwbos := preload("res://scripts/maps/dauwbos.gd")

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


func area(rows: Array, pos: Vector2i, size: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy: int in int(size[1]):
		for dx: int in int(size[0]):
			cells.append(pos + Vector2i(dx, dy))
	return cells


func any_reachable(seen: Dictionary, cells: Array[Vector2i]) -> bool:
	for cell: Vector2i in cells:
		if seen.has(cell):
			return true
	return false


func next_to(seen: Dictionary, rows: Array, pos: Vector2i) -> bool:
	if tile_free(rows, pos) and seen.has(pos):
		return true
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if seen.has(pos + d):
			return true
	return false


func _initialize() -> void:
	var forest_rows: Array = Forest.DATA["rows"]
	var dauw_rows: Array = Dauwbos.DATA["rows"]
	# Fluisterbos: vanaf de dorpsingang naar het Dauwbos-portaal
	var forest_seen := reach(forest_rows, Vector2i(4, 17))
	check(tile_free(forest_rows, Vector2i(3, 10)) and tile_free(forest_rows, Vector2i(3, 11)), "Dauwbos-portaaltegels in het Fluisterbos zijn begaanbaar")
	check(any_reachable(forest_seen, area(forest_rows, Vector2i(3, 10), [1, 2])), "Dauwbos-portaal bereikbaar vanaf de dorpsingang")
	# Dauwbos zelf: vanaf de spawn alles belangrijke bereiken
	var dauw_seen := reach(dauw_rows, Vector2i(5, 20))
	check(any_reachable(dauw_seen, area(dauw_rows, Vector2i(2, 20), [1, 2])), "retourportaal naar het Fluisterbos bereikbaar")
	check(any_reachable(dauw_seen, area(dauw_rows, Vector2i(25, 2), [2, 1])), "IJsdal-portaal bereikbaar")
	check(any_reachable(dauw_seen, area(dauw_rows, Vector2i(48, 19), [1, 2])), "Dorstvallei-portaal bereikbaar")
	check(next_to(dauw_seen, dauw_rows, Vector2i(8, 18)), "altaar bereikbaar")
	for npc: Array in [[15, 12, "Mira"], [28, 18, "Tomas"], [22, 28, "Noor"]]:
		check(next_to(dauw_seen, dauw_rows, Vector2i(npc[0], npc[1])), "npc %s bereikbaar" % npc[2])
	for thing: Array in [[40, 10, "kist boven"], [12, 30, "kist onder"], [32, 8, "dauwsteen"], [18, 8, "hart"], [35, 25, "helddrank"], [10, 15, "kruid west"], [25, 25, "kruid oost"]]:
		check(next_to(dauw_seen, dauw_rows, Vector2i(thing[0], thing[1])), "%s bereikbaar" % thing[2])
	print("DAUWBOS ROUTE OK" if failures == 0 else "DAUWBOS ROUTE FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
