extends RefCounted
## Het huisje van Visser Joris aan het Zilvermeer. Met de hand aan te passen.
## Tekens: zie scripts/data/tiles.gd. Voorwerpen in `objects`: zie scripts/world.gd (_spawn_objects) en scripts/data/ext/meer.gd.

const DATA := {
	"name": "Het huisje van Joris",
	"music": "lake",
	"rows": [
		"NNNNNNNNNNNN",
		"NSNSNSNxNSNN",
		"NwwwwwwwwwwN",
		"NwBww%%wwCwN",
		"Nwwww%%wwwwN",
		"NwxwwwCCwwwN",
		"NwwwwwwwwwxN",
		"NwwwwwwwwwwN",
		"NNNNNmmNNNNN",
	],
	"spawns": {"start": [6, 7], "door": [6, 7]},
	"objects": [
		{"type": "torch", "pos": [3, 2]},
		{"type": "torch", "pos": [9, 2]},
		{"type": "chest", "pos": [10, 3], "contents": [["meer_boek_hut", 1]]},
		{"type": "sign", "pos": [3, 6], "lines": ["Het visdagboek van Joris", "Dag 1: geen vis. Dag 2: geen vis. Dag 3: een laars. Dag 4: nog een laars. Dag 5: ik begin een collectie."]},
		{"type": "sign", "pos": [8, 5], "lines": ["Een briefje op de tafel", "Voor de Gouden Karper: niet met brood proberen. Hij is te slim voor brood. Probeer het in diep water."]},
		{"type": "portal", "pos": [5, 8], "to": "lake", "spawn": "from_hut", "size": [2, 1]},
	],
}
