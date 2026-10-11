extends RefCounted
## De arenahal: hier schrijf je je in bij Arenameester Bruno. Aan de hoge muur hangen de trofeeënplank en het scorebord.
## Tekens: zie scripts/data/tiles.gd. Voorwerpen in `objects`: zie scripts/world.gd.

const DATA := {
	"name": "Arenahal",
	"music": "village",
	"rows": [
		"&&&&&&&&&&&&&&&&&&",
		"&&&&&&&&&&&&&&&&&&",
		"&&&&&&&&&&&&&&&&&&",
		"&&&&&&&&@@&&&&&&&&",
		"&wwwwwww%%wwwwwww&",
		"&wwwwwww%%wwwwwww&",
		"&wwwwwww%%wwCCwCC&",
		"&wwwwwww%%wwwwwww&",
		"&wwwwwww%%wwwwwww&",
		"&wwwwwww%%wwwwwww&",
		"&xwwwwww%%wwwwwwx&",
		"&&&&&&&&@@&&&&&&&&",
	],
	"spawns": {"start": [8, 10], "door": [8, 10], "from_arena": [8, 5]},
	"objects": [
		{"type": "npc", "pos": [14, 6], "id": "arena_bruno"},
		{"type": "arena_board", "pos": [2, 3], "span": 4, "board": "trophies"},
		{"type": "arena_board", "pos": [11, 3], "span": 4, "board": "scores"},
		{"type": "torch", "pos": [7, 3]},
		{"type": "torch", "pos": [10, 3]},
		{"type": "torch", "pos": [7, 11]},
		{"type": "torch", "pos": [10, 11]},
		{"type": "arena_prop", "pos": [1, 2], "kind": "banner"},
		{"type": "arena_prop", "pos": [16, 2], "kind": "banner"},
		{"type": "arena_prop", "pos": [6, 2], "kind": "banner"},
		{"type": "arena_prop", "pos": [2, 8], "kind": "rack"},
		{"type": "arena_prop", "pos": [15, 9], "kind": "rack"},
		{"type": "portal", "pos": [8, 3], "to": "arena", "spawn": "from_hall", "size": [2, 1], "requires": [["arena_registered"]], "locked_text": "De arenadeur zit dicht. Schrijf je eerst in bij Bruno."},
		{"type": "portal", "pos": [8, 11], "to": "village", "spawn": "from_arena", "size": [2, 1]},
	],
}
