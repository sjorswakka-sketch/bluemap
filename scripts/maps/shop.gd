extends RefCounted
## Winkel van Tobias. Gemaakt met tools/gen_maps.py (je mag dit bestand ook met de hand aanpassen).
## Tekens: zie scripts/data/tiles.gd. Voorwerpen in `objects`: zie scripts/world.gd (_spawn_objects).

const DATA := {
	"name": "Winkel van Tobias",
	"music": "village",
	"rows": [
		"NNNNNNNNNNNNNN",
		"NNSNSNSNSNSNNN",
		"NwxwwwwwwwwxwN",
		"NwwwwwwwwwwwwN",
		"NwwCCCCwCCCwwN",
		"NwwwwwwwwwwwwN",
		"NwwwwwwwwwwwwN",
		"NwwwwwwwwwwwwN",
		"NwwwwwwwwwwwwN",
		"NNNNNNmmNNNNNN",
	],
	"spawns": {"start": [7, 8], "door": [7, 8]},
	"objects": [
		{"type": "npc", "pos": [7, 4], "id": "tobias"},
		{"type": "torch", "pos": [3, 2]},
		{"type": "torch", "pos": [10, 2]},
		{"type": "portal", "pos": [6, 9], "to": "village", "spawn": "from_shop", "size": [2, 1]},
	],
}
