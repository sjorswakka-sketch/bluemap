extends RefCounted
## Uitbreidingsmodules. Elke uitbreiding van het spel (een nieuw gebied, een nieuw wapen, nieuwe vijanden...)
## krijgt een eigen bestand in scripts/data/ext/ en meldt zich hier aan met één regel.
##
## Een module is een gewoon script met constanten die dezelfde vorm hebben als de basisbestanden:
##
##   TALKS    (dialogue.gd)   QUESTS (quests.gd)   ITEMS / WEAPONS (items.gd)   ENEMIES (enemies.gd)
##   NPCS     (npcs.gd)       SHOPS  (shops.gd)    MAPS (maps/registry.gd)
##   SOUNDS / TRACKS (lijsten met namen van .wav-bestanden in assets/audio, zie scripts/core/sound.gd)
##
## Je hoeft alleen de constanten op te nemen die je nodig hebt. Namen (sleutels) mogen niet al bestaan.

const MODULES: Array = [
	# preload("res://scripts/data/ext/voorbeeld.gd"),
]


## Voegt de woordenboeken met de naam `key` van alle modules samen met `base`.
static func merged(key: String, base: Dictionary) -> Dictionary:
	var result := base.duplicate()
	for module: Script in MODULES:
		var constants := module.get_script_constant_map()
		if constants.has(key):
			var extra: Dictionary = constants[key]
			for id: Variant in extra:
				if result.has(id):
					push_error("Uitbreiding %s overschrijft '%s' in %s" % [module.resource_path, id, key])
				result[id] = extra[id]
	return result


## Voegt de lijsten met de naam `key` van alle modules achter `base`.
static func appended(key: String, base: Array) -> Array:
	var result := base.duplicate()
	for module: Script in MODULES:
		var constants := module.get_script_constant_map()
		if constants.has(key):
			for entry: Variant in constants[key]:
				if not result.has(entry):
					result.append(entry)
	return result
