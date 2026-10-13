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
	"prof_ijsbloem": {"name": "IJsbloem", "sheet": "items_beroepen", "icon": 18, "type": "material", "desc": "Een bloem die alleen in het IJsdal bloeit. Koud en helder; basis voor vorstelixers."},
	"prof_winterbes": {"name": "Winterbes", "sheet": "items_beroepen", "icon": 19, "type": "material", "desc": "Zoete bes die juist in de sneeuw rijpt. Lekker en verwarmend."},
	"prof_dennenhout": {"name": "Dennenhout", "sheet": "items_beroepen", "icon": 20, "type": "material", "desc": "Harsachtig hout uit het IJsdal. Brandt lang en warm."},
	"prof_ijskristal": {"name": "IJskristal", "sheet": "items_beroepen", "icon": 21, "type": "material", "desc": "Een zuivere kristalspalk uit een bevroren ader. Gezocht door alchemisten."},
	"prof_frost_tonic": {"name": "Vorstelixer", "sheet": "items_beroepen", "icon": 22, "type": "use", "stamina": 40, "desc": "Herstelt 40 uithoudingsvermogen. Gebruik via Beroepen → Eten & drinken."},
	"prof_winter_gloed": {"name": "Wintergloed", "sheet": "items_beroepen", "icon": 23, "type": "use", "heal": 2, "desc": "Een warme winterbespap. Herstelt 2 hartjes. Gebruik via Beroepen → Eten & drinken."},
	"prof_cactusvijg": {"name": "Cactusvijg", "sheet": "items_beroepen", "icon": 24, "type": "material", "desc": "Zoete vrucht van de zuilcactus. Verkoelend; Sana maakt er drankjes van."},
	"prof_zandkruid": {"name": "Zandkruid", "sheet": "items_beroepen", "icon": 25, "type": "material", "desc": "Een taai, geurig kruid dat tussen het duinzand groeit. Voor balsems en braadstukken."},
	"prof_zandsteen": {"name": "Zandsteen", "sheet": "items_beroepen", "icon": 26, "type": "material", "desc": "Warme, gelaagde steen uit de klippen van de Dorstvallei. Licht en goed te bewerken."},
	"prof_zandbalsem": {"name": "Zandbalsem", "sheet": "items_beroepen", "icon": 27, "type": "use", "stamina": 30, "desc": "Verkoelende balsem van zandkruid en cactusvijg. Herstelt 30 uithoudingsvermogen. Gebruik via Beroepen → Eten & drinken."},
	"prof_dauwklauw": {"name": "Dauwklauw", "sheet": "items_beroepen", "icon": 43, "type": "material", "sell": 3, "desc": "Een bleke bloem die alleen in de mist van het Dauwbos bloeit. Basis voor het mistedrank."},
	"prof_mistdrank": {"name": "Mistedrank", "sheet": "items_beroepen", "icon": 44, "type": "use", "stamina": 35, "desc": "Een koel, kolkend elixer van dauwklauwen en honingzwam. Herstelt 35 uithoudingsvermogen. Gebruik via Beroepen → Eten & drinken."},
	"prof_dauwsoep": {"name": "Dauwsoep", "sheet": "items_beroepen", "icon": 45, "type": "use", "heal": 2, "stamina": 10, "desc": "Lichte soep van honingzwammen met dauwklauw. Herstelt 2 hartjes en 10 uithoudingsvermogen. Gebruik via Beroepen → Eten & drinken."},
	"prof_veenbes": {"name": "Veenbes", "sheet": "items_beroepen", "icon": 58, "type": "material", "sell": 3, "desc": "Een rode, zure bes die laag boven het veenwater groeit. Voor pap en elixers."},
	"prof_watermunt": {"name": "Watermunt", "sheet": "items_beroepen", "icon": 59, "type": "material", "sell": 3, "desc": "Fris kruid uit de plasranden van het Kruipmoeras. Prikt lekker in thee en brouwsels."},
	"prof_wilgentwijg": {"name": "Wilgentwijg", "sheet": "items_beroepen", "icon": 60, "type": "material", "sell": 2, "desc": "Buigzame twijg van een geknotte wilg. Rietvlechters zweren erbij."},
	"prof_ijzeroer": {"name": "IJzeroer", "sheet": "items_beroepen", "icon": 61, "type": "material", "sell": 5, "desc": "Bruin erts uit de turfvelden, het bloed van het veen. Alchemisten smeden er rare dingen mee."},
	"prof_moeraselixer": {"name": "Moeraselixer", "sheet": "items_beroepen", "icon": 63, "type": "use", "stamina": 45, "desc": "Kolkend groen brouwsel van watermunt en veenbes. Herstelt 45 uithoudingsvermogen. Gebruik via Beroepen → Eten & drinken."},
	"prof_veenbespap": {"name": "Veenbespap", "sheet": "items_beroepen", "icon": 64, "type": "use", "heal": 2, "stamina": 5, "desc": "Warme pap met veenbessen, zoals Stien hem maakt. Herstelt 2 hartjes en 5 uithoudingsvermogen. Gebruik via Beroepen → Eten & drinken."},
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
	"bronze_helm": {"skill": "smithing", "level": 2, "xp": 18, "station": "smithy", "inputs": {"prof_copper_bar": 2, "prof_iron_bar": 1}, "output": "gear_bronze_helm"},
	"iron_armor": {"skill": "smithing", "level": 3, "xp": 25, "station": "smithy", "inputs": {"prof_iron_bar": 3, "prof_log": 1}, "output": "gear_iron_armor"},
	"smith_gloves": {"skill": "smithing", "level": 2, "xp": 18, "station": "smithy", "inputs": {"prof_iron_bar": 2, "gel": 2}, "output": "gear_smith_gloves"},
	"crystal_amulet": {"skill": "alchemy", "level": 3, "xp": 25, "station": "library", "inputs": {"prof_copper_bar": 2, "prof_herb": 6, "gel": 3}, "output": "gear_crystal_amulet"},
	"crystal_ring": {"skill": "alchemy", "level": 2, "xp": 18, "station": "library", "inputs": {"prof_copper_bar": 1, "prof_herb": 4, "gel": 4}, "output": "gear_crystal_ring"},
	"frost_tonic": {"skill": "alchemy", "level": 2, "xp": 12, "station": "library", "inputs": {"prof_ijsbloem": 2, "prof_winterbes": 2}, "output": "prof_frost_tonic"},
	"winter_glow": {"skill": "cooking", "level": 2, "xp": 10, "station": "inn", "inputs": {"prof_winterbes": 3, "prof_ijsbloem": 1}, "output": "prof_winter_gloed"},
	"sand_balm": {"skill": "alchemy", "level": 2, "xp": 12, "station": "library", "inputs": {"prof_zandkruid": 2, "prof_cactusvijg": 1}, "output": "prof_zandbalsem"},
	"roast_meat": {"skill": "cooking", "level": 2, "xp": 12, "station": "inn", "inputs": {"jacht_vlees": 2, "prof_zandkruid": 1}, "output": "jacht_braadstuk"},
	"mist_drank": {"skill": "alchemy", "level": 2, "xp": 12, "station": "library", "inputs": {"prof_dauwklauw": 2, "prof_mushroom": 1}, "output": "prof_mistdrank"},
	"dauw_soep": {"skill": "cooking", "level": 2, "xp": 10, "station": "inn", "inputs": {"prof_mushroom": 2, "prof_dauwklauw": 1}, "output": "prof_dauwsoep"},
	"moeras_elixer": {"skill": "alchemy", "level": 2, "xp": 12, "station": "library", "inputs": {"prof_watermunt": 2, "prof_veenbes": 1}, "output": "prof_moeraselixer"},
	"veenbes_pap": {"skill": "cooking", "level": 2, "xp": 10, "station": "inn", "inputs": {"prof_veenbes": 3, "prof_watermunt": 1}, "output": "prof_veenbespap"},
	"prism_lantern": {
	"skill": "smithing",
	"level": 1,
	"xp": 20,
	"station": "smithy",
	"unlock": "lw_workshop",
	"inputs": {
		"lw_lens": 1,
		"prof_branch": 2
	},
	"output": "lw_lantern"
},
	"grounding_powder": {
	"skill": "alchemy",
	"level": 1,
	"xp": 12,
	"station": "library",
	"inputs": {
		"prof_stone": 2,
		"gel": 2
	},
	"output": "lw_powder"
},
	"bridge_components": {
	"skill": "woodcutting",
	"level": 1,
	"xp": 15,
	"inputs": {
		"prof_wilgentwijg": 4,
		"prof_branch": 2
	},
	"output": "lw_bridge_kit"
},
	"living_resin": {
	"skill": "alchemy",
	"level": 1,
	"xp": 15,
	"station": "library",
	"inputs": {
		"prof_watermunt": 2,
		"gel": 2
	},
	"output": "lw_resin"
},
	"scout_coat": {
	"skill": "woodcutting",
	"level": 1,
	"xp": 20,
	"unlock": "lw_tailoring",
	"inputs": {
		"prof_wilgentwijg": 2,
		"moeras_huid": 2
	},
	"output": "gear_scout_coat"
},
	"ls_chowder":{"skill":"cooking","level":1,"xp":12,"station":"inn","unlock":"ls_served","unlock_hint":"Deel eerst een maaltijd aan Mila’s dorpstafel.","inputs":{"meer_baars":2,"prof_herb":1},"output":"ls_chowder"},
	"ls_broth":{"skill":"cooking","level":1,"xp":12,"station":"inn","unlock":"ls_served","unlock_hint":"Deel eerst een maaltijd aan Mila’s dorpstafel.","inputs":{"meer_baars":1,"prof_berry":2},"output":"ls_broth"},
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
	"winterherbs": {"name": "IJsbloemen", "skill": "foraging", "item": "prof_ijsbloem", "amount": 2, "xp": 8, "cooldown": 150.0, "color": Color("a5e8f2")},
	"frostberries": {"name": "Winterbessenstruik", "skill": "foraging", "item": "prof_winterbes", "amount": 3, "xp": 8, "cooldown": 150.0, "color": Color("e8a5b5")},
	"pine_stump": {"name": "Dennenstronk", "skill": "woodcutting", "item": "prof_dennenhout", "amount": 2, "xp": 8, "cooldown": 150.0, "tools": ["prof_iron_axe", "prof_axe"], "duration": 1.1, "animation": "woodcutting", "color": Color("7a5c3d")},
	"ice_vein": {"name": "IJskristalader", "skill": "mining", "item": "prof_ijskristal", "amount": 2, "xp": 12, "cooldown": 180.0, "level": 2, "tools": ["prof_copper_pickaxe"], "duration": 1.35, "animation": "mining", "color": Color("9fd8f0")},
	"cactusfigs": {"name": "Cactusvijgen", "skill": "foraging", "item": "prof_cactusvijg", "amount": 2, "xp": 8, "cooldown": 150.0, "color": Color("e87a9a")},
	"sandwort": {"name": "Zandkruid", "skill": "foraging", "item": "prof_zandkruid", "amount": 2, "xp": 8, "cooldown": 150.0, "color": Color("b3a04f")},
	"sandstone_rock": {"name": "Zandsteenklip", "skill": "mining", "item": "prof_zandsteen", "amount": 2, "xp": 10, "cooldown": 180.0, "tools": ["prof_copper_pickaxe", "prof_pickaxe"], "duration": 1.35, "animation": "mining", "color": Color("c08a54")},
	"dauwklauw": {"name": "Dauwklauwen", "skill": "foraging", "item": "prof_dauwklauw", "amount": 2, "xp": 8, "cooldown": 150.0, "color": Color("a8d8e8")},
	"veenbessen": {"name": "Veenbessenstruik", "skill": "foraging", "item": "prof_veenbes", "amount": 3, "xp": 8, "cooldown": 150.0, "color": Color("c23a52")},
	"watermunt": {"name": "Watermunt", "skill": "foraging", "item": "prof_watermunt", "amount": 2, "xp": 8, "cooldown": 150.0, "color": Color("4fae6a")},
	"wilgstronk": {"name": "Geknotte wilg", "skill": "woodcutting", "item": "prof_wilgentwijg", "amount": 2, "xp": 8, "cooldown": 150.0, "tools": ["prof_iron_axe", "prof_axe"], "duration": 1.1, "animation": "woodcutting", "color": Color("9a7a52")},
	"ijzeroer_ader": {"name": "IJzeroerklomp", "skill": "mining", "item": "prof_ijzeroer", "amount": 2, "xp": 12, "cooldown": 180.0, "level": 2, "tools": ["prof_copper_pickaxe"], "duration": 1.35, "animation": "mining", "color": Color("8a5a34")},
}
# Explicit IDs keep cooldowns stable when maps or the original object lists change.
# Nodes are small, non-blocking props on walkable tiles away from doors and quest items.
const RESOURCE_PLACEMENTS := {
	"village": [["twigs_west", "branches", 10, 16], ["twigs_south", "branches", 16, 22], ["flint_west", "stones", 5, 16], ["flint_south", "stones", 23, 22], ["herbs_south", "herbs", 25, 23], ["berries_west", "berries", 8, 17]],
	"forest": [["twigs_entry", "branches", 4, 15], ["flint_entry", "stones", 3, 20], ["birch_west", "stump", 7, 21], ["birch_north", "stump", 12, 12], ["herbs_west", "herbs", 8, 20], ["berries_west", "berries", 10, 21], ["mushrooms_west", "mushrooms", 8, 25], ["copper_west", "copper", 5, 26], ["copper_east", "copper", 30, 20], ["birch_east", "stump", 32, 22], ["mushrooms_east", "mushrooms", 43, 23]],
	"lake": [["herbs_north", "herbs", 17, 10], ["berries_north", "berries", 25, 10], ["twigs_shore", "branches", 6, 13], ["flint_shore", "stones", 35, 12]],
	"cave": [["copper_entry", "copper", 9, 32], ["iron_entry", "iron", 3, 29], ["iron_west", "iron", 10, 22], ["iron_east", "iron", 29, 28]],
	"ijsdal": [["ijsbloem_west", "winterherbs", 5, 14], ["ijsbloem_meer", "winterherbs", 16, 25], ["ijsbloem_noord", "winterherbs", 30, 5], ["winterbes_west", "frostberries", 4, 19], ["winterbes_oost", "frostberries", 42, 6], ["den_west", "pine_stump", 7, 16], ["den_oost", "pine_stump", 33, 20], ["ijskristal_mijn", "ice_vein", 40, 24], ["ijskristal_diep", "ice_vein", 44, 28], ["vuursteen_mijn", "stones", 38, 26], ["takken_plein", "branches", 28, 19]],
	"dorstvallei": [["vijgen_west", "cactusfigs", 6, 7], ["vijgen_oost", "cactusfigs", 41, 8], ["vijgen_zuidoost", "cactusfigs", 38, 12], ["kruid_noord", "sandwort", 11, 8], ["kruid_midden", "sandwort", 20, 12], ["kruid_oost", "sandwort", 37, 22], ["zandsteen_west", "sandstone_rock", 7, 27], ["zandsteen_noord", "sandstone_rock", 25, 4], ["zandsteen_zuid", "sandstone_rock", 13, 30], ["vuursteen_zuid", "stones", 21, 26], ["kruiden_oase", "herbs", 12, 13]],
	"dauwbos": [["padden_kring", "mushrooms", 20, 9], ["padden_zuid", "mushrooms", 27, 27], ["kruiden_plein", "herbs", 20, 20], ["kruiden_oost", "herbs", 36, 22], ["bessen_heg", "berries", 16, 16], ["bessen_noord", "berries", 30, 6], ["takken_west", "branches", 8, 24], ["stronk_oud", "stump", 34, 10], ["vuursteen_vijver", "stones", 38, 29], ["klauw_west", "dauwklauw", 7, 16], ["klauw_vijver", "dauwklauw", 30, 24], ["klauw_zuid", "dauwklauw", 14, 22]],
	"kruipmoeras": [["veenbes_west", "veenbessen", 17, 13], ["veenbes_zuid", "veenbessen", 33, 18], ["veenbes_oost", "veenbessen", 30, 21], ["munt_noord", "watermunt", 25, 6], ["munt_pad", "watermunt", 21, 24], ["munt_zuid", "watermunt", 13, 21], ["wilg_west", "wilgstronk", 5, 10], ["wilg_oost", "wilgstronk", 40, 20], ["oer_west", "ijzeroer_ader", 7, 27], ["oer_oost", "ijzeroer_ader", 12, 24], ["takken_ingang", "branches", 21, 5], ["vuursteen_turf", "stones", 9, 23]],
}


static func resource_objects(map_id: String) -> Array:
	var result: Array = []
	for entry: Array in RESOURCE_PLACEMENTS.get(map_id, []):
		result.append({"type": "profession_resource", "id": "%s:%s" % [map_id, entry[0]], "kind": entry[1], "pos": [entry[2], entry[3]]})
	return result
