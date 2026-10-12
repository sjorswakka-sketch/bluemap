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
## Eigen soorten objecten op de kaart ({"type": "doelwit", "pos": [3, 4], ...}):
##
##   const OBJECTS := {"doelwit": "res://scripts/entities/target.gd"}
##
## Het pad staat als tekst (geen preload): een preload laadt het objectscript al terwijl GameState nog wordt opgebouwd,
## en dan kent dat script GameState en Sound nog niet. Zo kan een objectscript ze gewoon bij naam gebruiken.
##
## Het script is een Node2D met de variabelen `world` (de wereld), `obj` (het woordenboek uit de kaart)
## en `key` (een unieke naam voor deze plek, handig als vlag). De wereld vult ze in vóór add_child().
##
## Je hoeft alleen de constanten op te nemen die je nodig hebt. Namen (sleutels) mogen niet al bestaan.
##
## Let op: gebruik in de module zelf GameState en Sound niet bij naam (compileerfout, want game_state.gd laadt dit
## bestand al). Haal ze in check() en run() uit de scenetree: (Engine.get_main_loop() as SceneTree).root.get_node("GameState").

const MODULES: Array = [
	# preload("res://scripts/data/ext/voorbeeld.gd"),
	preload("res://scripts/data/ext/boog.gd"),
	preload("res://scripts/data/ext/vijanden.gd"),
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


## Soorten objecten (naam -> script) die de modules toevoegen. Paden (tekst) worden hier geladen.
static func object_types() -> Dictionary:
	var types := merged("OBJECTS", {})
	for type_name: String in types:
		if types[type_name] is String:
			types[type_name] = load(types[type_name])
	return types
