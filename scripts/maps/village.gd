extends RefCounted
## Dageraadsdorp. Gemaakt met tools/gen_maps.py (je mag dit bestand ook met de hand aanpassen).
## Tekens: zie scripts/data/tiles.gd. Voorwerpen in `objects`: zie scripts/world.gd (_spawn_objects).

const DATA := {
	"name": "Dageraadsdorp",
	"music": "village",
	"outdoor": true, # volgt dag en nacht
	"weather": "random", # af en toe regen
	"rows": [
		"########################################",
		"##############ZZZZZZZZZZZZ##############",
		"##....b.....#.ZZZZZZZZZZZZ..#.+++++++###",
		"##.#..#..b....ZZZZZZZZZZZZ....+!+++!+###",
		"##......#.....ZZZZZZZZZZZZ..#.+++n+++.##",
		"##.#..........ZZZZZZZZZZZZ.......,,,..##",
		"##.......##...ZZZZZTTZZZZZ.........,..##",
		"##.................,,......^^^^^^^^,.b##",
		"##..^^^^^^.^^^^^^..,,......^^^^^^^^,b.##",
		"##..^^^^^^.^^^^^^..,,......HhHHHhHh,..##",
		"##..HhHhHh.HhHhHh..,,......HHHDHHHH,.o##",
		"###.HHDHHH.HHDHHH,,,,,,,......,....,..##",
		"##....,......,..,,,,,,,,......,#o..,..##",
		"##,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,",
		"##,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,",
		"##.........#....,,,,,,,,...#..........##",
		"##..............,,,,,,,,..............##",
		"##.#...............,,...............o###",
		"##...^^^^^^.b......,,.......^^^^^^....##",
		"##...^^^^^^....#...,,.......^^^^^^....##",
		"##.#.HhHhHh..#o.xx.,,.....#.HhHHHh....##",
		"##...HHDHHH..b.....,,.......HHHDHH....##",
		"##.................,,.....|||||||||.####",
		"##.#....#.o#...#...,,..........#......##",
		"##......#..........,,........b........##",
		"##o...#....#.#.....,,...........#.....##",
		"###################,,###################",
		"###################,,###################",
	],
	# Plein [16,11]..[23,16]: de sokkel staat exact om het midden [20,14].
	# Apart van objects, zodat bestaande opslag-ID's niet verschuiven.
	"fountains": [{"pos": [19, 13], "size": [2, 2]}],
	"spawns": {"start": [19, 9], "from_forest": [36, 13], "from_smithy": [6, 12], "from_shop": [13, 12], "from_inn": [30, 11], "from_temple": [19, 8], "from_lake": [19, 24], "altar": [22, 13], "from_arena": [33, 5]},
	"objects": [
		{"type": "npc", "pos": [17, 8], "id": "bram"},
		{"type": "npc", "pos": [24, 18], "id": "pim"},
		{"type": "npc", "pos": [25, 18], "id": "muis_dorp", "if": [["flag", "cat_home"]]},
		{"type": "npc", "pos": [13, 15], "id": "anja"},
		{"type": "npc", "pos": [22, 24], "id": "joost"},
		{"type": "npc", "pos": [34, 11], "id": "hein"},
		{"type": "npc", "pos": [15, 25], "id": "lotte"}, # polish: Lotte (vrij pad)
		{"type": "npc", "pos": [11, 18], "id": "kasper"}, # polish: Kasper
		{"type": "npc", "pos": [20, 16], "id": "elke"}, # polish: Elke
		{"type": "npc", "pos": [27, 14], "id": "willem"}, # polish: Willem
		{"type": "savepoint", "pos": [22, 12]},
		{"type": "wereld_lantaarn", "pos": [18, 7]},
		{"type": "wereld_lantaarn", "pos": [21, 7]},
		{"type": "wereld_lantaarn", "pos": [3, 12]},
		{"type": "wereld_lantaarn", "pos": [7, 12]},
		{"type": "wereld_lantaarn", "pos": [14, 12]},
		{"type": "wereld_lantaarn", "pos": [31, 11]},
		{"type": "wereld_lantaarn", "pos": [36, 12]},
		{"type": "wereld_lantaarn", "pos": [12, 15]},
		{"type": "wereld_lantaarn", "pos": [25, 15]},
		{"type": "wereld_lantaarn", "pos": [18, 18]},
		{"type": "wereld_lantaarn", "pos": [9, 22]},
		{"type": "wereld_lantaarn", "pos": [21, 22]},
		{"type": "pickup", "pos": [8, 15], "item": "coin"},
		{"type": "pickup", "pos": [30, 15], "item": "coin"},
		{"type": "sign", "pos": [21, 8], "lines": ["Dageraadsdorp", "Tempel van de Blauwe Kaart. Bewaker: Oudste Bram."]},
		{"type": "sign", "pos": [37, 12], "lines": ["Oostelijke weg: Fluisterbos.", "Pas op voor slijmen!"]},
		{"type": "portal", "pos": [6, 11], "to": "smithy", "spawn": "door"},
		{"type": "portal", "pos": [13, 11], "to": "shop", "spawn": "door"},
		{"type": "portal", "pos": [30, 10], "to": "inn", "spawn": "door"},
		# De Diepte (spoor diepte): na het einde roept Bram je en wijst hij de weg.
		{"type": "trigger", "pos": [17, 8], "size": [5, 3], "conditions": [["flag", "game_completed"]], "once": "diepte_hint", "do": [["talk", "diepte_bram_hint"]]},
		{"type": "portal", "pos": [38, 13], "to": "forest", "spawn": "from_village", "size": [1, 2]},
		# De arena (noordoosten): open voor wie Oudste Bram kent en een ijzeren zwaard heeft.
		{"type": "portal", "pos": [33, 4], "to": "arena_hall", "spawn": "door", "requires": [["arena_open"]], "locked_text": "De arenadeur blijft dicht. Praat eerst met Oudste Bram, en kom terug met een ijzeren zwaard van Greta de smid."},
		{"type": "sign", "pos": [31, 5], "lines": ["Arena van Dageraadsdorp", "Voor echte vechters! Praat eerst met Oudste Bram, en kom terug met een ijzeren zwaard van Greta de smid."]},
		{"type": "torch", "pos": [32, 4]},
		{"type": "torch", "pos": [34, 4]},
		{"type": "arena_prop", "pos": [30, 4], "kind": "banner"},
		{"type": "arena_prop", "pos": [36, 4], "kind": "banner"},
		{"type": "portal", "pos": [19, 6], "to": "temple", "spawn": "start", "size": [2, 1], "requires": [["flag", "gate_temple"]], "locked_text": "De tempeldeur is verzegeld door de gebarsten kaart."},
		# Boog: Tessa's schietbaan (drie doelwitten) in de hoek onder de weg naar het bos.
		{"type": "npc", "pos": [30, 16], "id": "tessa"},
		{"type": "boog_baan", "pos": [31, 15], "size": [1, 3], "id": "schietbaan"},
		{"type": "boog_target", "pos": [35, 15], "range": "schietbaan"},
		{"type": "boog_target", "pos": [37, 16], "range": "schietbaan"},
		{"type": "boog_target", "pos": [34, 17], "range": "schietbaan"},
		{"type": "sign", "pos": [29, 17], "lines": ["Schietbaan van Tessa.", "Raak de doelwitten met je boog. Praat met Tessa om te beginnen."]},
		# Zilvermeer (achteraan, zodat de plekken van de oude dingen in opslagen niet verschuiven): de weg naar het zuiden.
		{"type": "sign", "pos": [18, 24], "lines": ["Zuidelijke weg: het Zilvermeer.", "Rustig water, grote vissen en een bibliotheek."]},
		{"type": "portal", "pos": [19, 26], "to": "lake", "spawn": "from_village", "size": [2, 2]},
	],
}
