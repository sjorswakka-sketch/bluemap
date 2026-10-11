extends RefCounted
## Uitbreidingsmodules. Elke uitbreiding van het spel (een nieuw gebied, een nieuw wapen, nieuwe vijanden...)
## krijgt een eigen bestand in scripts/data/ext/ en meldt zich hier aan met één regel.
##
## Een module is een gewoon script met constanten die dezelfde vorm hebben als de basisbestanden:
##
##   TALKS    (dialogue.gd)   QUESTS (quests.gd)   ITEMS / WEAPONS (items.gd)   ENEMIES (enemies.gd)
##   NPCS     (npcs.gd)       SHOPS  (shops.gd)    MAPS (maps/registry.gd)
##   SOUNDS / TRACKS (lijsten met namen van .wav-bestanden in assets/audio, zie scripts/core/sound.gd)
##   OBJECTS  (soort object op de kaart -> script, zie hieronder) of OBJECT_PATHS (soort -> pad van het script)
##   MAP_MARKERS (soort object -> {"color": Color, "label": "naam"}): een stipje op het kaartje in het menu (N)
##
## Eigen voorwaarden en acties voor gesprekken, poortjes enzovoort:
##
##   const CONDITIONS := ["gevangen"]     # de namen, zodat de speltest ze herkent
##   const ACTIONS := ["start_arena"]
##   static func check(cond: Array) -> bool     # wordt alleen aangeroepen voor jouw eigen voorwaarden
##   static func run(action: Array) -> void     # idem voor acties
##
## Eigen soorten objecten op de kaart ({"type": "doelwit", "pos": [3, 4], ...}):
##
##   const OBJECTS := {"doelwit": preload("res://scripts/entities/target.gd")}
##
## Het script is een Node2D met de variabelen `world` (de wereld), `obj` (het woordenboek uit de kaart)
## en `key` (een unieke naam voor deze plek, handig als vlag). De wereld vult ze in vóór add_child().
##
## Eigen {tekens} in gesprekken en opdrachtteksten (zoals {gel} en {coins}):
##
##   const FORMATS := ["boeken"]                    # {boeken} wordt ingevuld
##   static func format(token: String) -> String    # geeft de tekst voor zo'n teken
##
## LET OP: de speltesten (godot -s) compileren de modules voordat de autoloads GameState en Sound bestaan, en een script
## dat die namen gebruikt kan dan niet gecompileerd worden. Houd het moduleschript zelf daarom vrij van GameState en Sound:
## zet die code in een apart script dat je met load() aanroept wanneer het nodig is (zie ext/meer.gd en ext/meer_logic.gd),
## en geef objectscripts op via OBJECT_PATHS (pad) in plaats van OBJECTS (preload).
##
## Je hoeft alleen de constanten op te nemen die je nodig hebt. Namen (sleutels) mogen niet al bestaan.

const MODULES: Array = [
	# preload("res://scripts/data/ext/voorbeeld.gd"),
	preload("res://scripts/data/ext/meer.gd"), # het Zilvermeer: vissen, bibliotheek, Joris, Lena en Sanne
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


## Welke voorwaarden en acties de modules erbij brengen (voor de speltest).
static func condition_names() -> Array:
	return appended("CONDITIONS", [])


static func action_names() -> Array:
	return appended("ACTIONS", [])


## Voorwaarde van een module. Geeft null terug als geen enkele module de voorwaarde kent.
static func check_condition(cond: Array) -> Variant:
	for module: Script in MODULES:
		var constants := module.get_script_constant_map()
		if constants.has("CONDITIONS") and cond[0] in constants["CONDITIONS"]:
			return module.call("check", cond)
	return null


## Voert een actie van een module uit. Geeft false terug als geen enkele module de actie kent.
static func run_action(action: Array) -> bool:
	for module: Script in MODULES:
		var constants := module.get_script_constant_map()
		if constants.has("ACTIONS") and action[0] in constants["ACTIONS"]:
			module.call("run", action)
			return true
	return false


## Soorten objecten (naam -> script) die de modules toevoegen. Een module geeft ze op in OBJECTS (met preload) of,
## als de scripts autoloads zoals GameState gebruiken, in OBJECT_PATHS (naam -> pad): die worden pas geladen als de
## wereld ze nodig heeft, want de speltesten compileren de modules voordat de autoloads bestaan.
static func object_types() -> Dictionary:
	var types := merged("OBJECTS", {})
	var paths := merged("OBJECT_PATHS", {})
	for kind: String in paths:
		types[kind] = load(paths[kind])
	return types


## Vult de {tekens} van de modules in een tekst in (zie `fmt` in game_state.gd).
static func format_text(text: String) -> String:
	if not "{" in text:
		return text
	for module: Script in MODULES:
		var constants := module.get_script_constant_map()
		if constants.has("FORMATS"):
			for token: String in constants["FORMATS"]:
				if "{%s}" % token in text:
					text = text.replace("{%s}" % token, str(module.call("format", token)))
	return text


## Kleur van het stipje op het kaartje (menu) voor soorten objecten van de modules.
static func map_markers() -> Dictionary:
	return merged("MAP_MARKERS", {})
