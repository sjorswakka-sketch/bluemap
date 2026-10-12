extends RefCounted
## De arena: het gevechtsveld met tribunes, zand en zes poorten waar de vijanden uit komen.
## Tekens: zie scripts/data/tiles.gd (: zand, + muur, - tribune, ! poort, n uitgang). Voorwerpen in `objects`: zie scripts/world.gd.
## De arenameester (arena_master) speelt het toernooi, zie scripts/entities/arena_master.gd.

const DATA := {
	"name": "De Arena",
	"music": "arena",
	"rows": [
		"++++++++++++++++++++++++++",
		"+------------------------+",
		"+------------------------+",
		"+------------------------+",
		"+--++++!++++++++++!++++--+",
		"+--+::::::::::::::::::+--+",
		"+--+::::::::::::::::::+--+",
		"+--+::::::::::::::::::+--+",
		"+--+::::::::::::::::::+--+",
		"+--+::::::::::::::::::+--+",
		"+--!::::::::::::::::::!--+",
		"+--+::::::::::::::::::+--+",
		"+--+::::::::::::::::::+--+",
		"+--+::::::::::::::::::+--+",
		"+--+::::::::::::::::::+--+",
		"+--+::::::::::::::::::+--+",
		"+--++++!++++nn++++!++++--+",
		"+-----------++-----------+",
		"+-----------++-----------+",
		"++++++++++++++++++++++++++",
	],
	"spawns": {"start": [12, 13], "from_hall": [12, 13]},
	"objects": [
		{"type": "arena_crowd", "pos": [0, 0], "field": [4, 5, 21, 15]},
		{"type": "arena_master", "pos": [12, 10], "field": [4, 5, 21, 15], "exit": [12, 16, 2, 1], "gates": [[7, 4, 0, 1], [18, 4, 0, 1], [3, 10, 1, 0], [22, 10, -1, 0], [7, 16, 0, -1], [18, 16, 0, -1]]},
		{"type": "gate", "pos": [12, 16], "id": "arena_exit", "size": [2, 1], "block_if": [["arena_fight"]], "locked_text": "De poorten blijven dicht tot je alle rondes hebt gewonnen. Opgeven kan bij de gong."},
		{"type": "portal", "pos": [12, 16], "to": "arena_hall", "spawn": "from_arena", "size": [2, 1], "requires": [["arena_free"]], "locked_text": "De poorten blijven dicht tot je alle rondes hebt gewonnen. Opgeven kan bij de gong."},
		{"type": "arena_gong", "pos": [10, 15], "talk": "arena_forfeit_ask"},
		{"type": "torch", "pos": [11, 16]},
		{"type": "torch", "pos": [14, 16]},
		{"type": "arena_prop", "pos": [5, 4], "kind": "banner"},
		{"type": "arena_prop", "pos": [10, 4], "kind": "banner"},
		{"type": "arena_prop", "pos": [15, 4], "kind": "banner"},
		{"type": "arena_prop", "pos": [20, 4], "kind": "banner"},
		{"type": "arena_prop", "pos": [3, 7], "kind": "banner"},
		{"type": "arena_prop", "pos": [3, 13], "kind": "banner"},
		{"type": "arena_prop", "pos": [22, 7], "kind": "banner"},
		{"type": "arena_prop", "pos": [22, 13], "kind": "banner"},
	],
}
