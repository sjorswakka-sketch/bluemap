extends RefCounted
## Herberg De Blauwe Slijm. Gemaakt met tools/gen_maps.py (je mag dit bestand ook met de hand aanpassen).
## Tekens: zie scripts/data/tiles.gd. Voorwerpen in `objects`: zie scripts/world.gd (_spawn_objects).

const DATA := {
	"name": "Herberg De Blauwe Slijm",
	"music": "village",
	"rows": [
		"NNNNNNNNNNNNNNNN",
		"NNSNSNSNSNSNSNNN",
		"NwxwwwwwwwwwwxwN",
		"NwwwwwwwwwwwwwwN",
		"NwwCCCCCwCCCCwwN",
		"NwwwwwwwwwwwwwwN",
		"NwBwBwBwwwwwwwwN",
		"NwwwwwwwwwwwwwwN",
		"NwwwwwwwwwwwwwwN",
		"NNNNNNNmmNNNNNNN",
	],
	"spawns": {"start": [8, 8], "door": [8, 8]},
	"objects": [
		{"type": "npc", "pos": [8, 4], "id": "mila"},
		{"type": "wereld_bed", "pos": [2, 6]},
		{"type": "wereld_bed", "pos": [4, 6]},
		{"type": "wereld_bed", "pos": [6, 6]},
		{"type": "torch", "pos": [3, 2]},
		{"type": "torch", "pos": [12, 2]},
		{"type": "portal", "pos": [7, 9], "to": "village", "spawn": "from_inn", "size": [2, 1]},
		{"type": "chest", "pos": [12, 7], "contents": [["potion", 1], ["coins", 15]]},
	],
}
