extends RefCounted
## Rietarchief: de ingang valt droog wanneer de sluizen juist staan.
const DATA := {
	"name": "Het Rietarchief",
	"music": "cave",
	"rows": [
		"MMMMMMMMMMMMMMMMMMMMMMMMMMMM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrIrrrrrrrrrIrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"Mrrr~~~~~~~~===~~~~~~~~~rrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrIrrrrrrrrrIrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrIrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MrrrrrrrrrrrrrrrrrrrrrrrrrrM",
		"MMMMMMMMMMMMMMMMMMMMMMMMMMMM"
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
			"to": "kruipmoeras",
			"spawn": "from_reedvault"
		},
		{
			"type": "sign",
			"pos": [
				4,
				12
			],
			"lines": [
				"Het water verbergt geen geschiedenis meer. De schildwachten beschermen hun zanger; breek de formatie of gebruik de pilaren als dekking."
			]
		},
		{
			"type": "enemy",
			"kind": "lw_warden",
			"pos": [
				12,
				5
			]
		},
		{
			"type": "enemy",
			"kind": "lw_singer",
			"pos": [
				15,
				4
			]
		},
		{
			"type": "enemy",
			"kind": "lw_stalker",
			"pos": [
				21,
				12
			]
		},
		{
			"type": "chest",
			"pos": [
				24,
				3
			],
			"contents": [
				[
					"gear_crystal_ring",
					1
				],
				[
					"coins",
					90
				]
			]
		},
		{
			"type": "torch",
			"pos": [
				5,
				6
			]
		},
		{
			"type": "torch",
			"pos": [
				23,
				6
			]
		},
		{
			"type": "sign",
			"pos": [
				24,
				15
			],
			"lines": [
				"De bewoners van Azura voerden het licht door de bergen, de wortels en het water. Hun bouwwerken delen dezelfde oorsprong."
			]
		}
	],
	"dark": 0.3
}
