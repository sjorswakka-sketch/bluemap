extends RefCounted
## Bergpas: bereikbaar na het verwarmen van de huizen in IJsdal.
const DATA := {
	"name": "De Bergpas",
	"music": "cave",
	"rows": [
		"PPPPPPPPPPPPPPPPPPPPPPPPPPPPPP",
		"PzzzzzzzzzzzzzzzzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"Pzzzzzzzzzz,,,,,,,zzzzzzzzzzzP",
		"Pzzzzzzzzzz,,,,,,,zzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzPPPPPPPPzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzPPPzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzzzzzzzzzzzzzzzzzP",
		"PzzzzzzzzzzzzzzzzzzzzzzzzzzzzP",
		"PPPPPPPPPPPPPPPPPPPPPPPPPPPPPP"
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
			"to": "ijsdal",
			"spawn": "from_ridgepass"
		},
		{
			"type": "sign",
			"pos": [
				4,
				12
			],
			"lines": [
				"Terug naar IJsdal: zuidwestelijk lichtpad.",
				"De korven markeren de veilige route. Boven de pas bewaakt een schildwachter de oude voorraad; een rietzanger houdt hem op de been."
			]
		},
		{
			"type": "enemy",
			"kind": "lw_warden",
			"pos": [
				23,
				5
			]
		},
		{
			"type": "enemy",
			"kind": "lw_singer",
			"pos": [
				25,
				6
			]
		},
		{
			"type": "chest",
			"pos": [
				26,
				3
			],
			"contents": [
				[
					"gear_bastion_coat",
					1
				],
				[
					"coins",
					75
				]
			]
		},
		{
			"type": "profession_resource",
			"id": "lw_ridge_ore",
			"kind": "ice_vein",
			"pos": [
				20,
				8
			]
		},
		{
			"type": "torch",
			"pos": [
				10,
				6
			]
		},
		{
			"type": "torch",
			"pos": [
				17,
				6
			]
		}
	],
	"outdoor": true,
	"weather": "snow"
}
