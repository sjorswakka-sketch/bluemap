extends SceneTree
## Bereikbaarheid van de drie polish-gebieden (Dauwbos, IJsdal, Dorstvallei).
## Leest de objecten en beroepsplekken uit de data zelf, zodat de test meebeweegt
## als een kaart opnieuw wordt vormgegeven.

const Tiles := preload("res://scripts/data/tiles.gd")
const Beroepen := preload("res://scripts/data/ext/beroepen.gd")
const Dauwbos := preload("res://scripts/maps/dauwbos.gd")
const IJsdal := preload("res://scripts/maps/ijsdal.gd")
const Dorstvallei := preload("res://scripts/maps/dorstvallei.gd")
const Kruipmoeras := preload("res://scripts/maps/kruipmoeras.gd")
const Village := preload("res://scripts/maps/village.gd")
const Forest := preload("res://scripts/maps/forest.gd")
const Lake := preload("res://scripts/maps/lake.gd")
const Ruins := preload("res://scripts/maps/ruins.gd")
const Cave := preload("res://scripts/maps/cave.gd")
const Temple := preload("res://scripts/maps/temple.gd")
const Arena := preload("res://scripts/maps/arena.gd")
const ArenaHall := preload("res://scripts/maps/arena_hall.gd")
const Depths1 := preload("res://scripts/maps/depths1.gd")
const Depths2 := preload("res://scripts/maps/depths2.gd")

## Objecten zonder fysieke tegel (markeringen, banen) en objecten die op het water horen.
const NIET_FYSIEK := ["meer_water", "trigger", "boog_baan", "arena_crowd", "arena_prop"]
const OP_WATER := ["meer_visplek", "meer_diepe_visplek"]

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


func dichtbij_oever(seen: Dictionary, pos: Vector2i, radius: int) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if seen.has(pos + Vector2i(dx, dy)):
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
		if obj["type"] in NIET_FYSIEK:
			continue
		var pos := Vector2i(int(obj["pos"][0]), int(obj["pos"][1]))
		var size: Array = obj.get("size", [1, 1])
		var label := "%s %s (%d,%d)" % [obj["type"], obj.get("id", obj.get("item", "")), pos.x, pos.y]
		if obj["type"] in OP_WATER:
			check(dichtbij_oever(seen, pos, 4), "%s: %s bij bereikbare oever" % [map_id, label])
			continue
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
	check_map("kruipmoeras", Kruipmoeras.DATA)
	check_map("village", Village.DATA)
	check_map("forest", Forest.DATA)
	check_map("lake", Lake.DATA)
	check_map("ruins", Ruins.DATA)
	check_map("cave", Cave.DATA)
	check_map("temple", Temple.DATA)
	check_map("arena", Arena.DATA)
	check_map("arena_hall", ArenaHall.DATA)
	check_map("depths1", Depths1.DATA)
	check_map("depths2", Depths2.DATA)
	print("GEBIEDEN ROUTE OK" if failures == 0 else "GEBIEDEN ROUTE FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
