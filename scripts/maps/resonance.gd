extends RefCounted
## Gemaakt met tools/gen_echo.py.
const DATA := {
	"name": "De Resonantiekamer",
	"music": "cave",
	"dark": 0.35,
	"rows": [
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		"XXXddddddddddddddddddddddddddXXX",
		"XXXddddddddddddddddddddddddddXXX",
		"XXXddddd*****************ddddXXX",
		"XXXddddd*ddddddddddddddd*ddddXXX",
		"XXXddddd*ddddddddddddddd*ddddXXX",
		"XXXddddd*ddddddddddddddd*ddddXXX",
		"XXXddddd*ddddddddddddddd*ddddXXX",
		"XXXddddd*ddddddddddddddd*ddddXXX",
		"XXXddddd*ddddddddddddddd*ddddXXX",
		"XXXddddd*ddddddddddddddd*ddddXXX",
		"XXXddddd*ddddddddddddddd*ddddXXX",
		"XXXddddd*ddddddddddddddd*ddddXXX",
		"XXXddddd*ddddddddddddddd*ddddXXX",
		"XXXddddd*****************ddddXXX",
		"XXXddddddddddddddddddddddddddXXX",
		"XXXddddddddddccccccddddddddddXXX",
		"XXXddddddddddccccccddddddddddXXX",
		"XXXXXXXXXXXXXccccccXXXXXXXXXXXXX",
		"XXXXXXXXXXXXXccccccXXXXXXXXXXXXX",
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
	],
	"spawns": {
		"start": [
			16,
			19
		]
	},
	"objects": [
		{
			"type": "portal",
			"pos": [
				15,
				21
			],
			"size": [
				2,
				1
			],
			"to": "prismamine",
			"spawn": "from_resonance"
		},
		{
			"type": "echo_trial",
			"pos": [
				16,
				15
			]
		},
		{
			"type": "sign",
			"pos": [
				18,
				19
			],
			"lines": [
				"Resonantieproef",
				"Kristalkevers stormen na hun lichtspoor recht vooruit. Prismamotten schieten tussen drie stralen. Ontwijk opzij of onderbreek de mot met je zwaard.",
				"Win drie golven voor een kristallen amulet en 120 munten. De beloning krijg je eenmaal per avontuur."
			]
		},
		{
			"type": "echo_crystal",
			"pos": [
				4,
				4
			],
			"violet": false
		},
		{
			"type": "echo_crystal",
			"pos": [
				27,
				4
			],
			"violet": true
		},
		{
			"type": "echo_crystal",
			"pos": [
				4,
				17
			],
			"violet": false
		},
		{
			"type": "echo_crystal",
			"pos": [
				27,
				17
			],
			"violet": true
		},
		{
			"type": "echo_crystal",
			"pos": [
				15,
				3
			],
			"violet": false
		},
		{
			"type": "echo_crystal",
			"pos": [
				17,
				3
			],
			"violet": true
		}
	]
}
