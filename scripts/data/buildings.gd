extends RefCounted
## Herkenbare gevels boven op bestaande gebouwtegels. Alle maten zijn in kaarttegels.
## Deuren, botsingen en de volgorde van kaartobjecten blijven van de oorspronkelijke kaart.
## Geen zichtbare tekst: de pictogrammen werken ook met een ander taalpakket.

const TILE := 32
const Routes:=preload("res://scripts/data/route_repairs.gd")
const BUILDINGS := {
	"village": [
		{"id": "smithy", "rect": Rect2i(4, 8, 6, 4), "door": Rect2i(6, 11, 1, 1)},
		{"id": "shop", "rect": Rect2i(11, 8, 6, 4), "door": Rect2i(13, 11, 1, 1)},
		{"id": "inn", "rect": Rect2i(27, 7, 8, 4), "door": Rect2i(30, 10, 1, 1)},
		{"id": "temple", "rect": Rect2i(14, 1, 12, 6), "door": Rect2i(19, 6, 2, 1)},
		{"id": "arena_hall", "rect": Rect2i(30, 2, 7, 3), "door": Rect2i(33, 4, 1, 1)},
	],
	"lake": [
		{"id": "fisher_hut", "rect": Rect2i(6, 3, 6, 4), "door": Rect2i(8, 6, 1, 1)},
		{"id": "library", "rect": Rect2i(28, 3, 9, 4), "door": Rect2i(32, 6, 1, 1)},
	],
}


static func for_map(map_id: String,map_data: Dictionary={}) -> Array:
	var buildings: Array=BUILDINGS.get(map_id, []).duplicate(true)
	for building: Dictionary in buildings:
		# The facade and its decoration mask share the real travel aperture.
		# Authored route metadata is a cycle-free fallback for catalogue callers.
		var route: Dictionary=Routes.PORTALS.get(map_id+":"+str(building.id),{})
		for obj: Dictionary in map_data.get("objects",[]):
			if obj.type=="portal" and obj.get("to","")==building.id and obj.get("enabled",true):
				route={"pos":obj.pos,"size":obj.get("size",[1,1])};break
		if not route.is_empty():
			building.door=Rect2i(route.pos[0],route.pos[1],route.size[0],route.size[1])
	return buildings


static func world_rect(building: Dictionary) -> Rect2:
	var rect: Rect2i = building["rect"]
	return Rect2(Vector2(rect.position) * TILE, Vector2(rect.size) * TILE)


## Houd de volledige deurtegel vrij, ook als een toekomstige gevelversiering groter wordt.
static func local_door(building: Dictionary) -> Rect2:
	var rect: Rect2i = building["rect"]
	var door: Rect2i = building["door"]
	return Rect2(Vector2(door.position - rect.position) * TILE, Vector2(door.size) * TILE)
