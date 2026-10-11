extends RefCounted
## De bibliotheek van Lena aan het Zilvermeer. Met de hand aan te passen.
## Tekens: zie scripts/data/tiles.gd. Voorwerpen in `objects`: zie scripts/world.gd (_spawn_objects) en scripts/data/ext/meer.gd.

const DATA := {
	"name": "Bibliotheek van Lena",
	"music": "lake",
	"rows": [
		"NNNNNNNNNNNNNNNNNNNNNNNN",
		"NSSSSSSSSSSSSSSSSNNNNNNN",
		"NSSSSSSSSSSSSSSSSNSSSSSN",
		"NSQQQQQQQQQQQQQQQSQQQQQN",
		"NSQQQQQQQQQQQQQQQSQQQQQN",
		"NSQQQQCCQCCCQQQQQSQJJJQN",
		"NSQQQQQQJJQQQQQQQSQJJJQN",
		"NSQQQQQQJJQQQQQQQSQJJJQN",
		"NSQCCCQQJJQQCCCQQSQQQQQN",
		"NSQQQQQQJJQQQQQQQSQQQQQN",
		"NSQQQQQQJJQQQQQQQSNNNNNN",
		"NSQQQQQQJJQQQQQQQSNNNNNN",
		"NSQQQQQQJJQQQQQQQSNNNNNN",
		"NNNNNNNNmmNNNNNNNNNNNNNN",
	],
	"spawns": {"start": [8, 12], "door": [8, 12]},
	"objects": [
		{"type": "npc", "pos": [8, 5], "id": "meer_lena"},
		{"type": "portal", "pos": [8, 13], "to": "lake", "spawn": "from_library", "size": [2, 1]},
		{"type": "meer_lessenaar", "pos": [3, 4], "id": "geschiedenis"},
		{"type": "meer_lessenaar", "pos": [15, 4], "id": "blauwe_kaart"},
		{"type": "meer_lessenaar", "pos": [3, 11], "id": "wachter"},
		{"type": "meer_lessenaar", "pos": [15, 11], "id": "diepte"},
		{"type": "meer_lessenaar", "pos": [12, 11], "id": "slijmen"},
		{"type": "meer_lessenaar", "pos": [20, 4], "id": "dagboek"},
		{"type": "meer_kast", "pos": [17, 6], "size": [1, 2], "open_if": [["flag", "meer_achterkamer"]]},
		{"type": "chest", "pos": [22, 8], "contents": [["potion", 1], ["coins", 15]]},
		{"type": "torch", "pos": [4, 3]},
		{"type": "torch", "pos": [14, 3]},
	],
}
