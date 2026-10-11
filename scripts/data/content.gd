extends RefCounted
## Uitbreidingsmodules. Elke uitbreiding van het spel (een nieuw gebied, een nieuw wapen, nieuwe vijanden...)
## krijgt een eigen bestand in scripts/data/ext/ en meldt zich hier aan met één regel.
##
## Een module is een gewoon script met constanten die dezelfde vorm hebben als de basisbestanden:
##
##   TALKS    (dialogue.gd)   QUESTS (quests.gd)   ITEMS / WEAPONS (items.gd)   ENEMIES (enemies.gd)
##   NPCS     (npcs.gd)       SHOPS  (shops.gd)    MAPS (maps/registry.gd)
##   SOUNDS / TRACKS (lijsten met namen van .wav-bestanden in assets/audio, zie scripts/core/sound.gd)
##   OBJECTS  (soort object op de kaart -> script, zie hieronder)
##
## Eigen voorwaarden en acties voor gesprekken, poortjes enzovoort:
##
##   const CONDITIONS := ["gevangen"]     # de namen, zodat de speltest ze herkent
##   const ACTIONS := ["start_arena"]
##   static func check(cond: Array) -> bool     # wordt alleen aangeroepen voor jouw eigen voorwaarden
##   static func run(action: Array) -> void     # idem voor acties
##
## Eigen tekens in gesprekken ({arena_title}, zoals {coins} en {gel} in game_state.gd):
##
##   const FORMATS := ["arena_title"]           # de namen van de tekens, zodat de speltest ze herkent
##   static func format(text: String) -> String # vult jouw tekens in
##
## Eigen soorten objecten op de kaart ({"type": "doelwit", "pos": [3, 4], ...}):
##
##   const OBJECTS := {"doelwit": "res://scripts/entities/target.gd"}   # een pad, of een preload() van het script
##
## Modules worden geladen voordat GameState en Sound bestaan. Gebruik daarom in een module zelf (en in alles wat hij
## preload()) niet de namen GameState of Sound: laat dat in scripts die pas later geladen worden (zoals een pad bij OBJECTS).
##
## Het script is een Node2D met de variabelen `world` (de wereld), `obj` (het woordenboek uit de kaart)
## en `key` (een unieke naam voor deze plek, handig als vlag). De wereld vult ze in vóór add_child().
##
## Je hoeft alleen de constanten op te nemen die je nodig hebt. Namen (sleutels) mogen niet al bestaan.

const MODULES: Array = [
	# preload("res://scripts/data/ext/voorbeeld.gd"),
	preload("res://scripts/data/ext/arena.gd"),
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


## Laat de modules hun eigen {tekens} invullen in een tekst (zie FORMATS bovenaan dit bestand).
static func format(text: String) -> String:
	if not "{" in text:
		return text
	for module: Script in MODULES:
		if module.get_script_constant_map().has("FORMATS"):
			text = module.call("format", text)
	return text


## Namen van de tekens die de modules kennen (voor de speltest).
static func format_names() -> Array:
	return appended("FORMATS", [])


## Soorten objecten (naam -> script) die de modules toevoegen.
## Een module mag het script ook als pad opgeven ("res://scripts/entities/doelwit.gd"): dat wordt hier pas geladen. Handig
## als het script GameState of Sound gebruikt, want modules worden geladen voordat die autoloads bestaan.
static func object_types() -> Dictionary:
	var types := merged("OBJECTS", {})
	for type_name: String in types:
		if types[type_name] is String:
			types[type_name] = load(types[type_name])
	return types
