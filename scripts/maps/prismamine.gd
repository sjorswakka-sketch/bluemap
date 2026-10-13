extends RefCounted
## Gemaakt met tools/gen_echo.py.
const DATA := {
	"name": "De Prismamijn",
	"music": "cave",
	"dark": 0.48,
	"rows": [
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		"XXXXXXXXXXXXXXXXXXXXXcycccccccccccccccXXXX",
		"XXXXXXXXXXXXXXXXXXXXXccccccccccccccccyXXXX",
		"XXXXXXXXXXXXXXXXXXXXXcccccccccccccccccXXXX",
		"XXXXXXXXXXXXXXXXXXXXXcccccccccccccccccXXXX",
		"XXXXXyccccccccccyXXXXcccccccccccccccccXXXX",
		"XXXXXccccccccccccXXXXcccccccccccccccccXXXX",
		"XXXXXccccc~~~~~cccccccccccccccccccccccXXXX",
		"XXXXXcccc=======ccccccccccccccccccccccXXXX",
		"XXXXXcccc=======ccccccccccccccccccccccXXXX",
		"XXXXXccccc~~~~~ccXXXXccccccccccccccccyXXXX",
		"XXXXXccccccccccccXXXXXXXXXXXXcccXXXXXXXXXX",
		"XXXXXccccccccccccXXXXXXXXXXXXcccXXXXXXXXXX",
		"XXXXXccccccccccccXXXXXXXXXXXXcccXXXXXXXXXX",
		"XXXXXXXcccXXXXXXXXXXXXXXXXXXXcccXXXXXXXXXX",
		"XXXXXXXcccXXXXXXXXXXXXXXXXXXXcccXXXXXXXXXX",
		"XXXXXXXcccXXXXXXXXXXXXXXcycccccccccccccXXX",
		"XXccccccccccXXXXXXXXXXXXcccccccccccccccXXX",
		"XXycccccccccXXXXXXXXXXXXcccccccccccccccXXX",
		"XXccccccccccXXXXXXXXXXXXcccccccccccccccXXX",
		"XXcccccccccccccccccccccccccccccccccccccXXX",
		"XXcccccccccccccccccccccccccccccccccccccXXX",
		"XXcccccccccccccccccccccccccccccccccccccXXX",
		"XXccccccccccXXXXXXXXXXXXccccccccccccccyXXX",
		"XXccccccccccXXXXXXXXXXXXcccccccccccccccXXX",
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
	],
	"spawns": {
		"start": [
			5,
			24
		],
		"altar": [
			6,
			23
		],
		"from_resonance": [
			34,
			5
		]
	},
	"objects": [
		{
			"type": "portal",
			"pos": [
				3,
				25
			],
			"to": "cave",
			"spawn": "from_prismamine"
		},
		{
			"type": "portal",
			"pos": [
				36,
				5
			],
			"to": "resonance",
			"spawn": "start"
		},
		{
			"type": "savepoint",
			"pos": [
				6,
				22
			]
		},
		{
			"type": "sign",
			"pos": [
				8,
				24
			],
			"lines": [
				"De Prismamijn",
				"Drie snelle zwaardaanvallen vormen een combo. De derde is een brede veeg voor 18 stamina. Zonder energie blijft het een gewone slag."
			]
		},
		{
			"type": "sign",
			"pos": [
				34,
				7
			],
			"lines": [
				"Naar de Resonantiekamer",
				"Raak daar het zwevende kristal aan om drie golven te beginnen. Je kunt altijd terugtrekken."
			]
		},
		{
			"type": "chest",
			"pos": [
				14,
				8
			],
			"contents": [
				[
					"potion",
					2
				],
				[
					"coins",
					25
				]
			]
		},
		{
			"type": "chest",
			"pos": [
				36,
				24
			],
			"contents": [
				[
					"shard",
					3
				],
				[
					"coins",
					35
				]
			]
		},
		{
			"type": "enemy",
			"pos": [
				8,
				10
			],
			"kind": "crystal_beetle"
		},
		{
			"type": "enemy",
			"pos": [
				24,
				7
			],
			"kind": "prism_moth"
		},
		{
			"type": "enemy",
			"pos": [
				28,
				24
			],
			"kind": "crystal_beetle"
		},
		{
			"type": "enemy",
			"pos": [
				34,
				20
			],
			"kind": "prism_moth"
		},
		{
			"type": "echo_crystal",
			"pos": [
				3,
				20
			],
			"violet": false
		},
		{
			"type": "echo_crystal",
			"pos": [
				10,
				20
			],
			"violet": true
		},
		{
			"type": "echo_crystal",
			"pos": [
				6,
				8
			],
			"violet": false
		},
		{
			"type": "echo_crystal",
			"pos": [
				15,
				14
			],
			"violet": true
		},
		{
			"type": "echo_crystal",
			"pos": [
				22,
				4
			],
			"violet": false
		},
		{
			"type": "echo_crystal",
			"pos": [
				35,
				11
			],
			"violet": true
		},
		{
			"type": "echo_crystal",
			"pos": [
				25,
				19
			],
			"violet": false
		},
		{
			"type": "echo_crystal",
			"pos": [
				37,
				25
			],
			"violet": true
		}
	]
}
