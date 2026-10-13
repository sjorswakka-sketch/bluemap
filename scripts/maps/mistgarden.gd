extends RefCounted
## Dauwtuin: groeit weer na het herstellen van de lichtkring.
const DATA := {
	"name": "De Dauwtuin",
	"music": "forest",
	"rows": [
		"############################",
		"#..........................#",
		"#..........................#",
		"#.......#..~~~~~......#....#",
		"#...#......~~~~~...........#",
		"#..........~~~~~...........#",
		"#..........~~~~~...........#",
		"#..........~~~~~...........#",
		"#..........~~~~~...........#",
		"#........=========.........#",
		"#........=========.........#",
		"#..........~~~~~...........#",
		"#..........~~~~~...........#",
		"#..........~~~~~.......#...#",
		"#..........~~~~~...........#",
		"#..........................#",
		"#.....#.............#......#",
		"#..........................#",
		"############################"
	],
	"spawns": {
		"start": [
			3,
			13
		]
	},
	"objects": [
		{
			"type": "portal",
			"pos": [
				2,
				14
			],
			"to": "dauwbos",
			"spawn": "from_mistgarden"
		},
		{
			"type": "sign",
			"pos": [
				4,
				12
			],
			"lines": [
				"Terug naar Dauwbos: zuidwestelijk lichtpad.",
				"Het licht heeft de tuin gewekt. Dauwklauwen groeien langs de stroom; honingzwammen onder de oude bomen."
			]
		},
		{
			"type": "profession_resource",
			"id": "lw_garden_herb",
			"kind": "dauwklauw",
			"pos": [
				8,
				8
			]
		},
		{
			"type": "profession_resource",
			"id": "lw_garden_mushroom",
			"kind": "mushrooms",
			"pos": [
				22,
				8
			]
		},
		{
			"type": "chest",
			"pos": [
				23,
				5
			],
			"contents": [
				[
					"prof_mistdrank",
					2
				],
				[
					"coins",
					40
				]
			]
		},
		{
			"type": "echo_crystal",
			"pos": [
				18,
				10
			]
		}
	],
	"outdoor": true,
	"weather": "random"
}
