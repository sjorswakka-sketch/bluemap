extends RefCounted
## Gedeelde, opgeslagen wereldgevolgen. Alleen data bij preload.
const QUESTS := {
	"prisma_herstel": {
		"title": "Licht onder de bergen",
		"steps": [
			{
				"text": "Prismamijn: richt de drie spiegels van de noordelijke kamer op hun gemarkeerde ontvangers. Elke aanraking draait een kwartslag.",
				"advance_if": [
					[
						"flag",
						"lw_beams"
					]
				]
			},
			{
				"text": "Activeer de kern naast de laatste ontvanger. Versla de bewakers of gebruik aardingspoeder.",
				"advance_if": [
					[
						"flag",
						"lw_mine"
					]
				]
			},
			{
				"text": "De mijn is stabiel. Herstel de prismabank links in Greta’s smederij."
			}
		],
		"effect": "Prismawerkplaats, nieuwe ertsaders en de schildbreker-combo vrijgespeeld."
	},
	"lichtwerk": {
		"title": "Een licht voor Mira",
		"steps": [
			{
				"text": "Maak een prismalantaarn bij Greta: via Maken met de prismalens en twee takken, of laat Greta hem voor 40 munten monteren."
			}
		],
		"effect": "Prismalantaarn: onthult bosrunen en houdt mistjagers op afstand."
	},
	"mistsporen": {
		"title": "Wat de mist verbergt",
		"steps": [
			{
				"text": "Neem je prismalantaarn mee. Onderzoek de tekens bij de westelijke wortels, de vijver en de oostelijke steen in het Dauwbos.",
				"advance_if": [
					[
						"flag",
						"lw_clues"
					]
				]
			},
			{
				"text": "Ontsteek de drie runen in de volgorde van het gedicht: water, wortel, ster. Een fout dooft de reeks, niet je aanwijzingen."
			}
		],
		"effect": "Mist verdreven, Dauwtuin geopend en verkennersjas ontvangen."
	}
}
const REWORKED_QUESTS := {
	"warmte": {
		"title": "Warmte voor IJsdal",
		"steps": [
			{
				"text": "Herstel de twee vuurkorven voor de noordelijke huizen. Voed ze met hout, wintergloed of de prismatechniek; houd koudevijanden weg tijdens het opwarmen.",
				"advance_if": [
					[
						"flag",
						"lw_heat"
					]
				]
			},
			{
				"text": "Beide huizen zijn warm. Vertel Fenna dat de bergpas weer veilig bereikbaar is."
			}
		],
		"effect": "Huizen verwarmd, bewoners terug en Bergpas geopend."
	},
	"wilgentwijgen": {
		"title": "De oversteek van Mees",
		"steps": [
			{
				"text": "Onderzoek de lier ten westen van het moeraseiland. Zet de westelijke sluis open en de oostelijke dicht; herstel daarna de oversteek met een bouwpakket, hars of de bewaakte lier.",
				"advance_if": [
					[
						"flag",
						"lw_bridge"
					]
				]
			},
			{
				"text": "Het water staat lager en de brug is bruikbaar. Breng Mees het goede nieuws."
			}
		],
		"effect": "Water verlaagd, handelsbrug hersteld, visplek en Rietarchief geopend."
	}
}
const ITEMS := {
	"lw_lens": {
		"name": "Prismalens",
		"sheet": "items",
		"icon": 3,
		"type": "quest",
		"max": 1,
		"desc": "De gestabiliseerde kern uit de Prismamijn. Greta kan er een lantaarn van maken."
	},
	"lw_lantern": {
		"name": "Prismalantaarn",
		"sheet": "items",
		"icon": 1,
		"type": "quest",
		"max": 1,
		"desc": "Onthult de verborgen bosrunen. Mistjagers wijken terug binnen de lichtkring. Werkt automatisch zolang je hem draagt."
	},
	"lw_powder": {
		"name": "Aardingspoeder",
		"sheet": "items_beroepen",
		"icon": 44,
		"type": "material",
		"desc": "Stabiliseert de mijnkern zonder gevecht. Meng steen met slijmgel aan de alchemietafel."
	},
	"lw_bridge_kit": {
		"name": "Brugonderdelen",
		"sheet": "items_beroepen",
		"icon": 60,
		"type": "material",
		"desc": "Een houten constructie voor Mees’ oversteek. Te maken zonder werkbank."
	},
	"lw_resin": {
		"name": "Levende hars",
		"sheet": "items_beroepen",
		"icon": 63,
		"type": "material",
		"desc": "Watermunt en slijmgel verbinden het gebroken hout van de oversteek."
	}
}
const TALKS := {
	"lw_core": {
		"speaker": "Prismakern",
		"lines": [
			"De spiegels voeden de kern. De bewakers reageren op elke poging hem los te maken. Hoe wil je hem stabiliseren?"
		],
		"choices": [
			{
				"text": "Ik neem het op tegen de bewakers.",
				"do": [
					[
						"living",
						"core_fight"
					]
				]
			},
			{
				"text": "Gebruik aardingspoeder (1).",
				"if": [
					[
						"has",
						"lw_powder",
						1
					]
				],
				"do": [
					[
						"living",
						"core_powder"
					]
				]
			},
			{
				"text": "Eerst voorbereiden."
			}
		]
	},
	"lw_forge": {
		"speaker": "Greta",
		"lines": [
			"De werkplaats leeft weer! Je derde comboslag kan nu een schild breken. Maak hier ook een lantaarn voor Mira."
		],
		"choices": [
			{
				"text": "Monteer mijn lantaarn (40 munten).",
				"if": [
					[
						"coins",
						40
					],
					[
						"has",
						"lw_lens",
						1
					],
					[
						"lacks",
						"lw_lantern",
						1
					]
				],
				"do": [
					[
						"living",
						"buy_lantern"
					]
				]
			},
			{
				"text": "Ik maak hem zelf via Beroepen → Maken."
			}
		]
	},
	"lw_bridge": {
		"speaker": "De oude lier",
		"lines": [
			"De oversteek brak door de waterdruk. West open, oost dicht: zo voert het water veilig af. Onderzoek beide sluizen vóór de reparatie."
		],
		"choices": [
			{
				"text": "Plaats brugonderdelen (1).",
				"if": [
					[
						"has",
						"lw_bridge_kit",
						1
					]
				],
				"do": [
					[
						"living",
						"bridge_kit"
					]
				]
			},
			{
				"text": "Verbind het hout met levende hars (1).",
				"if": [
					[
						"has",
						"lw_resin",
						1
					]
				],
				"do": [
					[
						"living",
						"bridge_resin"
					]
				]
			},
			{
				"text": "Gebruik de lier; verjaag de bewakers.",
				"do": [
					[
						"living",
						"bridge_fight"
					]
				]
			},
			{
				"text": "Ik bekijk eerst de sluizen."
			}
		]
	},
	"lw_heat": {
		"speaker": "Verlaten vuurkorf",
		"lines": [
			"Blijf bij de korf terwijl hij twintig seconden opwarmt. Vijanden vlak bij de vlam houden de opwarming tegen. Versla alle aanvallers om het huis veilig te maken."
		],
		"choices": [
			{
				"text": "Gebruik drie takken.",
				"if": [
					[
						"has",
						"prof_branch",
						3
					]
				],
				"do": [
					[
						"living",
						"heat_wood"
					]
				]
			},
			{
				"text": "Gebruik een wintergloed.",
				"if": [
					[
						"has",
						"prof_winter_gloed",
						1
					]
				],
				"do": [
					[
						"living",
						"heat_food"
					]
				]
			},
			{
				"text": "Gebruik de herstelde prismatechniek.",
				"if": [
					[
						"flag",
						"lw_workshop"
					]
				],
				"do": [
					[
						"living",
						"heat_prism"
					]
				]
			},
			{
				"text": "Ik kom voorbereid terug."
			}
		]
	}
}
const ENEMIES := {
	"lw_warden": {
		"name": "Schildwachter",
		"sheet": "lw_warden",
		"cell": 16,
		"scale": 2.0,
		"radius": 8.0,
		"shadow": 9.0,
		"hp": 7,
		"damage": 1,
		"behavior": "lw_guard",
		"speed": 37,
		"chase_speed": 37,
		"sight": 300.0,
		"drops": [
			[
				"coin",
				1.0,
				3
			]
		],
		"desc": "Blokkeert frontale treffers. Flankeer hem of breek zijn schild met je vrijgespeelde derde comboslag."
	},
	"lw_stalker": {
		"name": "Mistjager",
		"sheet": "lw_stalker",
		"cell": 16,
		"scale": 2.0,
		"radius": 8.0,
		"shadow": 9.0,
		"hp": 4,
		"damage": 1,
		"behavior": "lw_flank",
		"speed": 58,
		"chase_speed": 58,
		"sight": 300.0,
		"drops": [
			[
				"coin",
				1.0,
				3
			]
		],
		"desc": "Loopt om je heen voor een korte uitval. Wijkt terug voor prismalicht en brandende vuurkorven."
	},
	"lw_singer": {
		"name": "Rietzanger",
		"sheet": "lw_singer",
		"cell": 16,
		"scale": 2.0,
		"radius": 8.0,
		"shadow": 9.0,
		"hp": 4,
		"damage": 1,
		"behavior": "lw_support",
		"speed": 25,
		"chase_speed": 25,
		"sight": 300.0,
		"drops": [
			[
				"coin",
				1.0,
				3
			]
		],
		"desc": "Helpt gewonde vijanden met een zichtbaar lied. Een zwaardtreffer onderbreekt de genezing."
	}
}
const OBJECTS := {"living_object": "res://scripts/entities/living_object.gd"}
const MAP_MARKERS := {"living_object": {"color": Color(0.95, 0.7, 0.3), "label": "Wereldopdracht"}}
const ACTIONS := ["living"]
static func run(action: Array) -> void:
	load("res://scripts/core/living_world.gd").run(action[1])

const MAPS := {
	"mistgarden": preload("res://scripts/maps/mistgarden.gd"),
	"ridgepass": preload("res://scripts/maps/ridgepass.gd"),
	"reedvault": preload("res://scripts/maps/reedvault.gd"),
}
