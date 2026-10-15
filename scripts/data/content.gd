extends RefCounted
## Uitbreidingsmodules. Elke uitbreiding van het spel (een nieuw gebied, een nieuw wapen, nieuwe vijanden...)
## krijgt een eigen bestand in scripts/data/ext/ en meldt zich hier aan met één regel.
##
## Een module is een gewoon script met constanten die dezelfde vorm hebben als de basisbestanden:
##
##   TALKS    (dialogue.gd)   QUESTS (quests.gd)   ITEMS / WEAPONS (items.gd)   ENEMIES (enemies.gd)
##   NPCS     (npcs.gd)       SHOPS  (shops.gd)    MAPS (maps/registry.gd)
##   ACHIEVEMENTS (achievements.gd: naam, uitleg en voorwaarden; behaald in het menu onder Prestaties)
##   SOUNDS / TRACKS (lijsten met namen van .wav-bestanden in assets/audio, zie scripts/core/sound.gd)
##   OBJECTS  (soort object op de kaart -> script, zie hieronder)
##   MAP_MARKERS (soort object -> {"color": Color, "label": "naam"}): een stipje op het kaartje in het menu (N)
##
## Eigen voorwaarden en acties voor gesprekken, poortjes enzovoort:
##
##   const CONDITIONS := ["gevangen"]     # de namen, zodat de speltest ze herkent
##   const ACTIONS := ["start_arena"]
##   static func check(cond: Array) -> bool     # wordt alleen aangeroepen voor jouw eigen voorwaarden
##   static func run(action: Array) -> void     # idem voor acties
##
## Eigen {tekens} in gesprekken en opdrachtteksten (zoals {coins} en {gel} in game_state.gd):
##
##   const FORMATS := ["arena_title"]              # de namen van de tekens (zonder haakjes)
##   static func format(token: String) -> String   # de tekst voor één teken, bijvoorbeeld "Arenastrijder"
##
## Eigen soorten objecten op de kaart ({"type": "doelwit", "pos": [3, 4], ...}):
##
##   const OBJECTS := {"doelwit": "res://scripts/entities/target.gd"}   # het PAD als tekst, geen preload()
##
## Het script is een Node2D met de variabelen `world` (de wereld), `obj` (het woordenboek uit de kaart)
## en `key` (een unieke naam voor deze plek, handig als vlag). De wereld vult ze in vóór add_child().
##
## LET OP (compileervolgorde): game_state.gd laadt dit bestand en dus alle modules al terwijl de autoloads GameState en
## Sound nog niet bestaan. Gebruik in een module (en in alles wat hij met preload() laadt) daarom nooit de namen GameState
## of Sound. Haal GameState in check() en run() op via (Engine.get_main_loop() as SceneTree).root.get_node("GameState"),
## of zet de code in een apart script dat je met load() aanroept (zie ext/meer.gd en ext/meer_logic.gd). Daarom staan
## objectscripts als pad in OBJECTS: ze worden pas geladen als de wereld ze nodig heeft.
##
## Tekst in een module (gesprekken, namen, beschrijvingen...) schrijf je gewoon in het Nederlands: het scherm dat hem toont
## vertaalt hem, en tools/i18n.py extract vindt hem vanzelf (zie de README, sectie "Talen"). Maak je in code zelf een
## melding (bijvoorbeeld in run()), gebruik dan TranslationServer.translate("...") (de naam Lang mag hier ook niet).
##
## Je hoeft alleen de constanten op te nemen die je nodig hebt. Namen (sleutels) mogen niet al bestaan.

const MODULES: Array = [
	preload("res://scripts/data/ext/tides.gd"),
	preload("res://scripts/data/ext/coast.gd"),
	preload("res://scripts/data/ext/habitat.gd"),
	preload("res://scripts/data/ext/work_together.gd"),
	preload("res://scripts/data/ext/world_memory.gd"),
	preload("res://scripts/data/ext/craft_progression.gd"),
	preload("res://scripts/data/ext/combat.gd"),
	preload("res://scripts/data/ext/regional.gd"),
	preload("res://scripts/data/ext/lake_supper.gd"),
	# preload("res://scripts/data/ext/voorbeeld.gd"),
	preload("res://scripts/data/ext/boog.gd"),
	preload("res://scripts/data/ext/vijanden.gd"),
	preload("res://scripts/data/ext/meer.gd"), # het Zilvermeer: vissen, bibliotheek, Joris, Lena en Sanne
	preload("res://scripts/data/ext/wereld.gd"),
	preload("res://scripts/data/ext/diepte.gd"),
	preload("res://scripts/data/ext/arena.gd"),
	preload("res://scripts/data/ext/beroepen.gd"),
	preload("res://scripts/data/ext/uitrusting.gd"),
	preload("res://scripts/data/ext/polijst.gd"), # polish: Dauwbos + extra quests & NPC's
	preload("res://scripts/data/ext/sneeuw.gd"), # IJsdal: sneeuwdorp, sneeuwklimaat, wintergrondstoffen
	preload("res://scripts/data/ext/dorst.gd"), # Dorstvallei: woestijn, hitte, wild en jacht
	preload("res://scripts/data/ext/uiterlijk.gd"), # uiterlijk: kleding over je uitrusting, haarstijlen, ogen en verf
	preload("res://scripts/data/ext/dagritme.gd"), # dagritme: achtergrondsfeer per klimaat en dagdeel
	preload("res://scripts/data/ext/moeras.gd"), # Kruipmoeras: veenland, waas, wild en de zonneschijf
	preload("res://scripts/data/ext/living.gd"),
	preload("res://scripts/data/ext/opening.gd"),
	preload("res://scripts/data/ext/first_route.gd"),
	preload("res://scripts/data/ext/echo.gd"), # Prismamijn en Resonantieproef
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


## Vult de {tekens} van de modules in een tekst in (zie FORMATS bovenaan dit bestand). Onbekende tekens blijven staan.
static func format_text(text: String) -> String:
	if not "{" in text:
		return text
	for module: Script in MODULES:
		for token: String in module.get_script_constant_map().get("FORMATS", []):
			var tag := "{%s}" % token
			if tag in text:
				text = text.replace(tag, module.call("format", token))
	return text


## Namen van de tekens die de modules kennen (voor de speltest).
static func format_names() -> Array:
	return appended("FORMATS", [])


## Soorten objecten (naam -> script) die de modules toevoegen. Paden (tekst) worden hier pas geladen.
static func object_types() -> Dictionary:
	var types := merged("OBJECTS", {})
	for type_name: String in types:
		if types[type_name] is String:
			types[type_name] = load(types[type_name])
	return types


## Kleur van het stipje op het kaartje (menu) voor soorten objecten van de modules.
static func map_markers() -> Dictionary:
	return merged("MAP_MARKERS", {})
