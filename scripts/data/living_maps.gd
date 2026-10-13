extends RefCounted
## Statische toevoegingen achteraan; de oude opslag-ID’s blijven ongewijzigd.
const EXTRAS := {
	"prismamine": [
		{
			"type": "living_object",
			"kind": "board",
			"id": "lw_notice",
			"pos": [
				22,
				6
			]
		},
		{
			"type": "living_object",
			"kind": "mirror",
			"id": "lw_mirror_a",
			"pos": [
				24,
				5
			],
			"receiver": [
				32,
				5
			]
		},
		{
			"type": "living_object",
			"kind": "mirror",
			"id": "lw_mirror_b",
			"pos": [
				32,
				5
			],
			"receiver": [
				32,
				10
			]
		},
		{
			"type": "living_object",
			"kind": "mirror",
			"id": "lw_mirror_c",
			"pos": [
				32,
				10
			],
			"receiver": [
				25,
				10
			]
		},
		{
			"type": "living_object",
			"kind": "core",
			"id": "lw_core",
			"pos": [
				25,
				10
			]
		}
	],
	"smithy": [
		{
			"type": "living_object",
			"kind": "forge",
			"id": "lw_forge",
			"pos": [
				4,
				6
			]
		}
	],
	"dauwbos": [
		{
			"type": "living_object",
			"kind": "rune",
			"id": "lw_root",
			"pos": [
				9,
				13
			]
		},
		{
			"type": "living_object",
			"kind": "rune",
			"id": "lw_water",
			"pos": [
				31,
				25
			]
		},
		{
			"type": "living_object",
			"kind": "rune",
			"id": "lw_star",
			"pos": [
				39,
				10
			]
		},
		{
			"type": "portal",
			"pos": [
				43,
				30
			],
			"to": "mistgarden",
			"spawn": "start",
			"requires": [
				[
					"flag",
					"lw_forest"
				]
			],
			"locked_text": "Deze route opent zodra je het gebied hebt hersteld. Kijk bij de gemarkeerde wereldopdracht."
		},
		{
			"type": "enemy",
			"kind": "lw_stalker",
			"pos": [
				11,
				13
			]
		},
		{
			"type": "enemy",
			"kind": "lw_stalker",
			"pos": [
				32,
				26
			]
		}
	],
	"ijsdal": [
		{
			"type": "living_object",
			"kind": "brazier",
			"id": "lw_heat_west",
			"pos": [
				12,
				11
			]
		},
		{
			"type": "living_object",
			"kind": "brazier",
			"id": "lw_heat_east",
			"pos": [
				36,
				11
			]
		},
		{
			"type": "portal",
			"pos": [
				43,
				3
			],
			"to": "ridgepass",
			"spawn": "start",
			"requires": [
				[
					"flag",
					"lw_heat"
				]
			],
			"locked_text": "Deze route opent zodra je het gebied hebt hersteld. Kijk bij de gemarkeerde wereldopdracht."
		}
	],
	"kruipmoeras": [
		{
			"type": "living_object",
			"kind": "bridge",
			"id": "lw_bridge_control",
			"pos": [
				17,
				19
			]
		},
		{
			"type": "living_object",
			"kind": "sluice",
			"id": "lw_sluice_west",
			"pos": [
				17,
				11
			]
		},
		{
			"type": "living_object",
			"kind": "sluice",
			"id": "lw_sluice_east",
			"pos": [
				35,
				18
			]
		},
		{
			"type": "portal",
			"pos": [
				24,
				17
			],
			"to": "reedvault",
			"spawn": "start",
			"requires": [
				[
					"flag",
					"lw_drained"
				]
			],
			"locked_text": "Deze route opent zodra je het gebied hebt hersteld. Kijk bij de gemarkeerde wereldopdracht."
		}
	]
}
const SPAWNS := {
	"dauwbos": {
		"from_mistgarden": [
			42,
			30
		]
	},
	"ijsdal": {
		"from_ridgepass": [
			42,
			3
		]
	},
	"kruipmoeras": {
		"from_reedvault": [
			24,
			16
		]
	}
}
static func enrich(map_id: String, data: Dictionary) -> void:
	var extras: Array = EXTRAS.get(map_id, []).duplicate(true)
	var talks := {"core":"lw_core", "forge":"lw_forge", "bridge":"lw_bridge", "brazier":"lw_heat"}
	for spec: Dictionary in extras:
		if talks.has(spec.get("kind", "")):
			spec["talk"] = talks[spec["kind"]]
	data["objects"].append_array(extras)
	if map_id == "dauwbos":
		data["objects"].append({"type":"sign", "pos":[42,31], "lines":["Oostelijk lichtpad: De Dauwtuin."]})
	elif map_id == "ijsdal":
		data["objects"].append({"type":"sign", "pos":[41,4], "lines":["Noordelijke route: De Bergpas."]})
	data["spawns"].merge(SPAWNS.get(map_id, {}))
