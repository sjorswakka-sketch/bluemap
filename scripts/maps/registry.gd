extends RefCounted
## Alle kaarten. Voeg een nieuwe kaart toe door een bestand in scripts/maps/ te maken en hier te registreren.

const Content := preload("res://scripts/data/content.gd")

const BASE_MAPS := {
	"village": preload("res://scripts/maps/village.gd"),
	"smithy": preload("res://scripts/maps/smithy.gd"),
	"shop": preload("res://scripts/maps/shop.gd"),
	"inn": preload("res://scripts/maps/inn.gd"),
	"forest": preload("res://scripts/maps/forest.gd"),
	"ruins": preload("res://scripts/maps/ruins.gd"),
	"cave": preload("res://scripts/maps/cave.gd"),
	"temple": preload("res://scripts/maps/temple.gd"),
}


## Basis en uitbreidingen samen (zie scripts/data/content.gd).
static var MAPS: Dictionary = Content.merged("MAPS", BASE_MAPS)


static func get_map(map_id: String) -> Dictionary:
	var data: Dictionary = MAPS[map_id].DATA.duplicate(true)
	preload("res://scripts/data/living_maps.gd").enrich(map_id, data)
	return data
