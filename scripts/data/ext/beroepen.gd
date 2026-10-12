extends RefCounted
## Beroepen: alle nieuwe namen, uitleg, recepten en plekken staan hier bij elkaar
## zodat een taalpakket ze onafhankelijk van de spelregels kan vertalen.

const OBJECTS := {"profession_resource": "res://scripts/entities/resource_node.gd"}
const MAP_MARKERS := {"profession_resource": {"color": Color(0.55, 0.88, 0.52), "label": "grondstof"}}
const SKILLS := {
	"foraging": {"name": "Kruidenzoeken", "desc": "Zoek kruiden, bessen en paddenstoelen in dorp, bos en langs het meer."},
	"woodcutting": {"name": "Houthakken", "desc": "Raap takken op en hak boomstronken met een bijl. Een ijzeren bijl geeft extra hout."},
	"mining": {"name": "Mijnbouw", "desc": "Raap stenen op, maak een pikhouweel en win koper. IJzer vereist niveau 2 en een koperen pikhouweel."},
	"fishing": {"name": "Vissen", "desc": "Vraag Joris om een hengel. Elke echte vangst bij het Zilvermeer geeft ervaring."},
	"smithing": {"name": "Smeden", "desc": "Smelt erts en maak beter gereedschap bij Greta in de smederij."},
	"alchemy": {"name": "Alchemie", "desc": "Meng kruiden met slijmgel of bessen in Lena's bibliotheek."},
	"cooking": {"name": "Koken", "desc": "Maak onderweg bessensnacks. Gebruik de keuken van de herberg voor warme gerechten."},
}
const TEXT := {
	"title": "Beroepen & ambachten", "skills": "Beroepen", "recipes": "Maken", "supplies": "Eten & drinken",
	"hint": "C / Esc sluiten  ·  pijltjes kiezen  ·  E / Enter gebruiken",
	"intro": "Verzamel met E. Maak eerst een stenen bijl en pikhouweel van losse takken en stenen. Gereedschap wordt automatisch gebruikt en slijt niet.",
	"level": "Niveau %d / %d", "xp": "%d / %d XP tot volgend niveau", "master": "Meester • maximaal niveau",
	"station": "Werkplek: %s", "anywhere": "Overal", "smithy": "Greta's smederij", "inn": "Keuken van de herberg", "library": "Alchemietafel in de bibliotheek",
	"required": "Nodig: %s", "skill_required": "%s niveau %d vereist", "station_required": "Ga naar: %s",
	"missing": "Te weinig: %s", "full": "Geen ruimte voor: %s", "ready": "Klaar om te maken", "made": "Gemaakt: %s x%d", "unknown": "Onbekend recept",
	"skill_up": "%s: niveau %d!", "gathered": "%s x%d  ·  +%d XP %s", "recovering": "%s groeit / verschijnt opnieuw over %d s",
	"tool_required": "Nodig: %s", "gather_hint": "Verzamelen", "depleted": "Herstelt over %d s", "harvesting": "Verzamelen…",
	"use": "Gebruik %s (%d)", "used": "Gebruikt: %s", "none": "Je hebt nog geen eten of drankjes. Maak iets op het tabblad Maken.",
	"health_full": "Je hartjes zijn al vol", "stamina_full": "Je uithoudingsvermogen is al vol", "missing_item": "Je hebt dit niet bij je", "busy": "Wacht even",
	"materials": "Materialen: %s", "recipe_line": "%s x%d  ·  %s %d", "skill_line": "%s  ·  niveau %d", "world_hint": "C: beroepen, recepten en eten",
	"inventory_navigation": "↑ ↓ voorwerp kiezen  ·  E gebruiken  ·  ", "inventory_page": "Voorwerpen %d–%d / %d", "inventory_use": "Druk op E om te gebruiken",
}
const ITEMS := {
	"prof_branch": {"name": "Droge tak", "sheet": "items_beroepen", "icon": 0, "type": "material", "desc": "Los hout uit dorp en bos. Voor je eerste bijl en pikhouweel."},
	"prof_stone": {"name": "Vuursteen", "sheet": "items_beroepen", "icon": 1, "type": "material", "desc": "Een scherpe losse steen. Je kunt hem zonder gereedschap oprapen."},
	"prof_herb": {"name": "Zilverkruid", "sheet": "items_beroepen", "icon": 2, "type": "material", "desc": "Geurig kruid voor alchemie en stevige soep."},
	"prof_berry": {"name": "Bosbes", "sheet": "items_beroepen", "icon": 3, "type": "material", "desc": "Maak er een bessensnack of een energie-elixer van."},
	"prof_log": {"name": "Berkenhout", "sheet": "items_beroepen", "icon": 4, "type": "material", "desc": "Hout van een oogstbare stronk. Voor smeltvuur, gereedschap en pijlen."},
	"prof_copper_ore": {"name": "Kopererts", "sheet": "items_beroepen", "icon": 5, "type": "material", "desc": "Win met een stenen pikhouweel. Smelt het bij Greta tot koper."},
	"prof_iron_ore": {"name": "IJzererts", "sheet": "items_beroepen", "icon": 6, "type": "material", "desc": "Win in de Echo-grot met mijnbouw 2 en een koperen pikhouweel."},
	"prof_copper_bar": {"name": "Koperstaaf", "sheet": "items_beroepen", "icon": 7, "type": "material", "desc": "Gesmolten koper voor een beter pikhouweel."},
	"prof_iron_bar": {"name": "IJzerstaaf", "sheet": "items_beroepen", "icon": 8, "type": "material", "desc": "Gesmolten ijzer voor een efficiëntere bijl."},
	"prof_axe": {"name": "Stenen bijl", "sheet": "items_beroepen", "icon": 9, "type": "gear", "max": 1, "desc": "Hak oogstbare stronken. Wordt automatisch gebruikt; slijt niet."},
	"prof_pickaxe": {"name": "Stenen pikhouweel", "sheet": "items_beroepen", "icon": 10, "type": "gear", "max": 1, "desc": "Win koperaders. Wordt automatisch gebruikt; slijt niet."},
	"prof_copper_pickaxe": {"name": "Koperen pikhouweel", "sheet": "items_beroepen", "icon": 11, "type": "gear", "max": 1, "desc": "Ontsluit ijzererts vanaf mijnbouw 2. Vervangt je stenen pikhouweel automatisch."},
	"prof_iron_axe": {"name": "IJzeren bijl", "sheet": "items_beroepen", "icon": 12, "type": "gear", "max": 1, "desc": "Oogst 3 berkenhout per stronk in plaats van 2. Slijt niet."},
	"prof_tonic": {"name": "Energie-elixer", "sheet": "items_beroepen", "icon": 13, "type": "use", "stamina": 60, "desc": "Herstelt 60 uithoudingsvermogen. Gebruik via Beroepen → Eten & drinken."},
	"prof_berry_meal": {"name": "Bessensnack", "sheet": "items_beroepen", "icon": 14, "type": "use", "heal": 1, "desc": "Herstelt 1 hartje. Gebruik via Beroepen → Eten & drinken."},
	"prof_fish_meal": {"name": "Gebakken baars", "sheet": "items_beroepen", "icon": 15, "type": "use", "heal": 3, "desc": "Herstelt 3 hartjes. Gemaakt in de herberg. Gebruik via Beroepen → Eten & drinken."},
	"prof_mushroom": {"name": "Honingzwam", "sheet": "items_beroepen", "icon": 16, "type": "material", "desc": "Een eetbare zwam uit het Fluisterbos. Voor stevige paddenstoelensoep."},
	"prof_stew": {"name": "Paddenstoelensoep", "sheet": "items_beroepen", "icon": 17, "type": "use", "heal": 2, "desc": "Herstelt 2 hartjes. Gebruik via Beroepen → Eten & drinken."},
}
const RECIPES := {
	"stone_axe": {"skill": "woodcutting", "level": 1, "xp": 8, "inputs": {"prof_branch": 2, "prof_stone": 2}, "output": "prof_axe"},
	"stone_pickaxe": {"skill": "mining", "level": 1, "xp": 8, "inputs": {"prof_branch": 2, "prof_stone": 2}, "output": "prof_pickaxe"},
	"arrows": {"skill": "woodcutting", "level": 2, "xp": 5, "inputs": {"prof_log": 1, "prof_stone": 1}, "output": "arrow", "amount": 5},
	"copper_bar": {"skill": "smithing", "level": 1, "xp": 10, "station": "smithy", "inputs": {"prof_copper_ore": 2, "prof_log": 1}, "output": "prof_copper_bar"},
	"copper_pickaxe": {"skill": "smithing", "level": 2, "xp": 15, "station": "smithy", "inputs": {"prof_copper_bar": 3, "prof_log": 2}, "output": "prof_copper_pickaxe"},
	"iron_bar": {"skill": "smithing", "level": 2, "xp": 12, "station": "smithy", "inputs": {"prof_iron_ore": 2, "prof_log": 1}, "output": "prof_iron_bar"},
	"iron_axe": {"skill": "smithing", "level": 3, "xp": 20, "station": "smithy", "inputs": {"prof_iron_bar": 3, "prof_log": 2}, "output": "prof_iron_axe"},
	"potion": {"skill": "alchemy", "level": 1, "xp": 10, "station": "library", "inputs": {"prof_herb": 2, "gel": 1}, "output": "potion"},
	"tonic": {"skill": "alchemy", "level": 2, "xp": 10, "station": "library", "inputs": {"prof_herb": 1, "prof_berry": 2}, "output": "prof_tonic"},
	"berry_meal": {"skill": "cooking", "level": 1, "xp": 6, "inputs": {"prof_berry": 3}, "output": "prof_berry_meal"},
	"stew": {"skill": "cooking", "level": 2, "xp": 10, "station": "inn", "inputs": {"prof_mushroom": 2, "prof_herb": 1}, "output": "prof_stew"},
	"fish_meal": {"skill": "cooking", "level": 2, "xp": 12, "station": "inn", "inputs": {"meer_baars": 1, "prof_herb": 1}, "output": "prof_fish_meal"},
}
const RESOURCES := {
	"branches": {"name": "Losse takken", "skill": "woodcutting", "item": "prof_branch", "amount": 2, "xp": 5, "cooldown": 90.0, "color": Color("bd8955")},
	"stones": {"name": "Losse vuurstenen", "skill": "mining", "item": "prof_stone", "amount": 2, "xp": 5, "cooldown": 90.0, "color": Color("a9b5c9")},
	"herbs": {"name": "Zilverkruid", "skill": "foraging", "item": "prof_herb", "amount": 2, "xp": 6, "cooldown": 120.0, "color": Color("85dfb5")},
	"berries": {"name": "Bosbessenstruik", "skill": "foraging", "item": "prof_berry", "amount": 3, "xp": 6, "cooldown": 120.0, "color": Color("9b9ee9")},
	"mushrooms": {"name": "Honingzwammen", "skill": "foraging", "item": "prof_mushroom", "amount": 2, "xp": 8, "cooldown": 150.0, "level": 2, "color": Color("e5ad57")},
	"stump": {"name": "Berkenstronk", "skill": "woodcutting", "item": "prof_log", "amount": 2, "xp": 8, "cooldown": 150.0, "tools": ["prof_iron_axe", "prof_axe"], "duration": 1.1, "animation": "woodcutting", "color": Color("cbac70")},
	"copper": {"name": "Koperader", "skill": "mining", "item": "prof_copper_ore", "amount": 2, "xp": 10, "cooldown": 180.0, "tools": ["prof_copper_pickaxe", "prof_pickaxe"], "duration": 1.35, "animation": "mining", "color": Color("e39760")},
	"iron": {"name": "IJzerader", "skill": "mining", "item": "prof_iron_ore", "amount": 2, "xp": 12, "cooldown": 180.0, "level": 2, "tools": ["prof_copper_pickaxe"], "duration": 1.35, "animation": "mining", "color": Color("bdcfdd")},
}
# Explicit IDs keep cooldowns stable when maps or the original object lists change.
# Nodes are small, non-blocking props on walkable tiles away from doors and quest items.
const RESOURCE_PLACEMENTS := {
	"village": [["twigs_west", "branches", 10, 16], ["twigs_south", "branches", 16, 22], ["flint_west", "stones", 5, 16], ["flint_south", "stones", 23, 22], ["herbs_south", "herbs", 25, 23], ["berries_west", "berries", 8, 17]],
	"forest": [["twigs_entry", "branches", 4, 15], ["flint_entry", "stones", 3, 20], ["birch_west", "stump", 7, 21], ["birch_north", "stump", 12, 12], ["herbs_west", "herbs", 8, 20], ["berries_west", "berries", 10, 21], ["mushrooms_west", "mushrooms", 8, 25], ["copper_west", "copper", 5, 26], ["copper_east", "copper", 30, 20], ["birch_east", "stump", 32, 22], ["mushrooms_east", "mushrooms", 43, 23]],
	"lake": [["herbs_north", "herbs", 17, 10], ["berries_north", "berries", 25, 10], ["twigs_shore", "branches", 6, 13], ["flint_shore", "stones", 35, 12]],
	"cave": [["copper_entry", "copper", 9, 32], ["iron_entry", "iron", 3, 29], ["iron_west", "iron", 10, 22], ["iron_east", "iron", 29, 28]],
}


static func resource_objects(map_id: String) -> Array:
	var result: Array = []
	for entry: Array in RESOURCE_PLACEMENTS.get(map_id, []):
		result.append({"type": "profession_resource", "id": "%s:%s" % [map_id, entry[0]], "kind": entry[1], "pos": [entry[2], entry[3]]})
	return result
