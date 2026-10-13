extends RefCounted
## Three regions, three different adventures. All artwork is generated locally.
const QUESTS := {
	"ra_ridge": {
		"title": "Een lijn door de storm",
		"effect": "Een vaste klimlijn en klimhandschoenen; de weerkaart helpt IJsdals reizigers.",
		"steps": [
			{
				"text": "Lees het kampbord bij de ingang van de Bergpas en neem het klimtouw mee.",
				"advance_if": [
					[
						"flag",
						"ra_rope_kit"
					]
				]
			},
			{
				"text": "Steek de noordelijke pas over wanneer de wimpels slap hangen. Zet het touw vast aan de oostelijke paal.",
				"advance_if": [
					[
						"flag",
						"ra_rope"
					]
				]
			},
			{
				"text": "Haal de verloren weerkaart op bij de schuilhut in het zuidoosten van de Bergpas.",
				"advance_if": [
					[
						"flag",
						"ra_chart"
					]
				]
			},
			{
				"text": "Breng de weerkaart naar het kamp bij de ingang van de Bergpas."
			}
		]
	},
	"ra_archive": {
		"title": "Wat het water onthield",
		"effect": "Een tentoonstelling bij Mees en een archiefkompas voor ontdekkingsreizigers.",
		"steps": [
			{
				"text": "Onderzoek de drie reliëfs in het Rietarchief: rietvelden, aanlegplaats en hoogwater. Ga daarna naar de leestafel in het zuiden."
			}
		]
	}
}
const TALKS := {
	"ra_spring": {
		"speaker": "De oude bron",
		"lines": [
			"De bron is vrij. De oase krijgt altijd water; kies waar het overschot stroomt. Je kunt later hier terugkomen om de aftakking te veranderen."
		],
		"choices": [
			{
				"text": "Maak een drinkplaats voor het wild.",
				"do": [
					[
						"regional",
						"wild"
					]
				]
			},
			{
				"text": "Vul de rustplaats voor reizigers.",
				"do": [
					[
						"regional",
						"caravan"
					]
				]
			},
			{
				"text": "Ik kijk nog even rond."
			}
		]
	},
	"ra_order": {
		"speaker": "De leestafel",
		"lines": [
			"Welke geschiedenis vertellen de reliëfs? Let op de huizen, de aanlegpalen en de hoogte van het water."
		],
		"choices": [
			{
				"text": "Rietvelden → aanlegplaats → hoogwater.",
				"do": [
					[
						"regional",
						"correct"
					]
				],
				"next": "ra_exhibit"
			},
			{
				"text": "Hoogwater → rietvelden → aanlegplaats.",
				"do": [
					[
						"regional",
						"wrong"
					]
				]
			},
			{
				"text": "Aanlegplaats → hoogwater → rietvelden.",
				"do": [
					[
						"regional",
						"wrong"
					]
				]
			},
			{
				"text": "Ik bekijk de reliëfs opnieuw."
			}
		]
	},
	"ra_exhibit": {
		"speaker": "Het verhaal van het moeras",
		"lines": [
			"Eerst leefden de bewoners tussen het riet. Daarna bouwden ze een aanlegplaats. Het hoge water verdreef hen naar het eiland. Hun kennis kan nu weer worden gedeeld.",
			"Wat laat je bij Mees zien? Beide keuzes houden alle routes en beloningen beschikbaar. Je kunt de tentoonstelling later veranderen."
		],
		"choices": [
			{
				"text": "Toon de oude vluchtroutes.",
				"do": [
					[
						"regional",
						"routes"
					]
				]
			},
			{
				"text": "Toon verhalen van de bewoners.",
				"do": [
					[
						"regional",
						"stories"
					]
				]
			},
			{
				"text": "Laat de tentoonstelling zo."
			}
		]
	},
	"ra_sana_done": {
		"speaker": "Sana",
		"lines": [
			"De bron voedt de oase weer. Het extra water gaat naar jouw gekozen plek: de drinkplaats ten oosten van mij of de rustplaats naast Jelles huis.",
			"De bron blijft bereikbaar. Daar kun je de aftakking veranderen; bij mijn blauwe waterpunt kun je altijd je waterzak vullen."
		]
	}
}
const ITEMS := {
	"ra_waterskin": {
		"name": "Nours waterzak",
		"sheet": "ra_items",
		"icon": 0,
		"type": "quest",
		"max": 1,
		"desc": "Een hervulbare waterzak voor de Zonnekloof. Je drinkt automatisch; vul gratis bij onder de blauwe luifels."
	}
}
const MAPS := {"sunwell":preload("res://scripts/maps/sunwell.gd")}
const OBJECTS := {
	"regional_object": "res://scripts/entities/regional_object.gd"
}
const MAP_MARKERS := {"regional_object":{"color":Color("dfbd7b"),"label":"Streekavontuur"}}
const ACTIONS := [
	"regional"
]
const SOUNDS := [
	"ra_water",
	"ra_rope",
	"ra_pages"
]
static func run(action: Array) -> void:
	load("res://scripts/core/regional_adventures.gd").action(action)
