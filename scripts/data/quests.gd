extends RefCounted
## Alle opdrachten. Een opdracht heeft stappen; `advance_if` gaat vanzelf naar de volgende stap
## als de voorwaarden kloppen. Voorwaarden en acties staan beschreven in scripts/core/game_state.gd.
## In de tekst kun je {crystals}, {gel}, {shards} en {coins} gebruiken.

const Content := preload("res://scripts/data/content.gd")

const BASE_QUESTS := {
	"main": {
		"title": "De Blauwe Kaart",
		"main": true,
		"steps": [
			{
				"text": "Vind de drie kaartkristallen: in het Fluisterbos, de Vergeten Ruïne en de Echo-grot. ({crystals}/3)",
				"advance_if": [["crystals", 3]],
			},
			{"text": "Breng de kristallen naar Oudste Bram bij de tempel."},
			{"text": "Versla de Slijmkoning in de Kristaltempel (de deur in het dorp staat nu open)."},
		],
	},
	"kat": {
		"title": "Muis de kat",
		"steps": [
			{
				"text": "Pim mist zijn kat Muis. Zoek haar in het Fluisterbos.",
				"advance_if": [["flag", "cat_found"]],
			},
			{"text": "Muis is gevonden! Vertel het aan Pim in het dorp."},
		],
	},
	"medaillon": {
		"title": "Het medaillon van Wilfred",
		"steps": [
			{
				"text": "Wilfred, de geest in de Ruïne, zoekt zijn medaillon. Het ligt ergens in de Echo-grot.",
				"advance_if": [["has", "medallion", 1]],
			},
			{"text": "Breng het medaillon naar Wilfred in de Vergeten Ruïne."},
		],
	},
	"drank": {
		"title": "Slijmgel voor Mila",
		"steps": [
			{
				"text": "Mila wil drankjes brouwen. Breng haar 5 slijmgel. ({gel}/5)",
				"advance_if": [["has", "gel", 5]],
			},
			{"text": "Geef de slijmgel aan Mila in de herberg."},
		],
	},
}


## Basis en uitbreidingen samen (zie content.gd).
static var QUESTS: Dictionary = Content.merged("QUESTS", BASE_QUESTS)


static func info(quest_id: String) -> Dictionary:
	return QUESTS.get(quest_id, {"title": quest_id, "steps": []})
