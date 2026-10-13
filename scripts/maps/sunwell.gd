extends RefCounted
## Original sandstone expedition, with refill shelters and optional detours.
const DATA := {
	"name": "De Zonnekloof",
	"music": "cave",
	"outdoor": true,
	"weather": "heat",
	"rows": [
		"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
		"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
		"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
		"qqqaaaaaaaaaaaaaaaaqqqqqqqqqaaaaaaaaqq",
		"qqqaaaaaaaaaaaaaaaaqqqqqqqqqaaaaaaaaqq",
		"qqqaaaaaaaaaaaaaaaaqqqqqqqqqaaaaaaaaqq",
		"qqqaaaaaaaaaaaaaaaaqqqqqqqqqaaaaaaaaqq",
		"qqqaaaaqqqqqqaaaaaaqqqqqqqqqaaaaaaaaqq",
		"qqqaaaaqqqqqqaaaaaaqqqqqqqqqaaaaaaaaqq",
		"qqqaaaaqqqqqqqqaaaaqqqqqqqqqaaaaqaaaqq",
		"qqqaaaaqqqqqqqqaaaaqqqqqqqqqaaaaqaaaqq",
		"qqqaaaaqqqqqqqqaaaaqqqqqqqqqaaaaqaaaqq",
		"qqqaaaaqqqqqqqqaaaaqqqqqqqqqaaaaqqqqqq",
		"qqqaaaaqqqqqqqqaaaaqqqqqqqqqaaaaqqqqqq",
		"qqqaaaaqqqqqqqqaaaaqqqqqqqqqaaaaqqqqqq",
		"qqqaaaaqqqqqqqqaaaaqqqqqqqqqaaaaqqqqqq",
		"qqaaaaaaqqqqqqqaaaaqqqqqqqaaaaaaaqqqqq",
		"qqaaaaaaqqqqqqqaaaaaaaaaaaaaaaaaaqqqqq",
		"qqaaaaaaqqqqqqqaaaaaaaaaaaaaaaaaaqqqqq",
		"qqaaaaaaqqqqqqqaaaaaaaaaaaaaaaaaaqqqqq",
		"qqaaaaaaqqqqqqqqaaaaaaaaaaaaaaaaaqqqqq",
		"qqaaaaaaqqqqqqqqqqqqqaaaqqaaaaaaaqqqqq",
		"qqqqqqqqqqqqqqqqqqqqqaaaqqqqqqqqqqqqqq",
		"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"
	],
	"spawns": {
		"start": [
			4,
			20
		]
	},
	"objects": [
		{
			"type": "portal",
			"pos": [
				4,
				21
			],
			"to": "dorstvallei",
			"spawn": "from_sunwell"
		},
		{
			"type": "regional_object",
			"kind": "refill",
			"name": "De eerste waterluifel",
			"pos": [
				4,
				18
			]
		},
		{
			"type": "regional_object",
			"kind": "refill",
			"name": "De hoge waterluifel",
			"pos": [
				15,
				5
			]
		},
		{
			"type": "regional_object",
			"kind": "refill",
			"name": "De zuidelijke waterluifel",
			"pos": [
				28,
				18
			]
		},
		{
			"type": "regional_object",
			"kind": "spring",
			"name": "De oude bron",
			"pos": [
				34,
				5
			],
			"talk": "ra_spring"
		},
		{
			"type": "chest",
			"pos": [
				22,
				21
			],
			"contents": [
				[
					"coins",
					45
				],
				[
					"prof_zandbalsem",
					1
				]
			]
		},
		{
			"type": "chest",
			"pos": [
				34,
				10
			],
			"contents": [
				[
					"prof_zandsteen",
					4
				],
				[
					"prof_cactusvijg",
					3
				]
			]
		}
	]
}
