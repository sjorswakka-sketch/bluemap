extends RefCounted
## De teksten op de lessenaars in de bibliotheek van Lena. Ze verdiepen het verhaal van Azura en geven hints
## over de Diepte, de Vergeten Wachter en de Sterrenkaart, zonder alles te verklappen.
##
## Elke lessenaar op de kaart heeft een `id` uit deze lijst. `title` staat boven de tekst, `lines` zijn de regels.

const TEXTS := {
	"geschiedenis": {
		"title": "Geschiedenis van Azura",
		"lines": [
			"Lang geleden was Azura een wilde streek zonder naam. Er woonde niemand. Alleen de wind, het water en de slijmen.",
			"Toen de eerste mensen kwamen, hing er een kaart van sterren aan de hemel: de Sterrenkaart. Hij liet zien waar het land veilig was.",
			"De mensen bouwden hun dorpen precies waar de kaart het aanwees. Het eerste dorp kreeg daarom de naam Dageraadsdorp: het lag in het eerste licht.",
		],
	},
	"blauwe_kaart": {
		"title": "De Blauwe Kaart",
		"lines": [
			"De Sterrenkaart was veel te groot om mee te nemen. Daarom maakten de oudsten er een kopie van, uit gloeiend kristal: de Blauwe Kaart.",
			"Een kopie is nooit zo sterk als het origineel. Daarom kon de Blauwe Kaart barsten. De Sterrenkaart barst nooit.",
			"Wie de kopie goed bewaart, houdt de slijmen rustig. De oudsten van Dageraadsdorp deden dat al duizend jaar.",
		],
	},
	"wachter": {
		"title": "Over Wachters",
		"lines": [
			"Wie iets kostbaars heeft, laat het niet onbewaakt. De oudsten maakten daarom een Wachter van steen en sterrenlicht.",
			"Hij kreeg één opdracht: de Sterrenkaart bewaken, voor altijd. Dat is heel lang. Op een gegeven moment werd hij moe en ging hij slapen.",
			"De mensen vergaten waar hij sliep. Daarom heet hij in de oude boeken De Vergeten Wachter.",
		],
	},
	"diepte": {
		"title": "De Diepte",
		"lines": [
			"Onder de Kristaltempel ligt een plek die op geen enkele kaart staat. De oudsten noemden haar de Diepte.",
			"Daar slaapt de Wachter, en daar ligt de Sterrenkaart. De weg erheen is eeuwenlang dicht geweest.",
			"Zolang de Blauwe Kaart gebarsten is, blijft de weg dicht. Pas als het gevaar boven is bezworen, schuift de steen aan de kant.",
		],
	},
	"slijmen": {
		"title": "Slijmen voor beginners",
		"lines": [
			"Slijmen zijn niet kwaad. Ze zijn gewoon dol op het licht van de Blauwe Kaart. Als het licht flikkert, worden ze wild.",
			"Handige tips: lach nooit om een slijm. Ze begrijpen meer dan je denkt. En geef ze geen appels, want die eten ze op. (Bron: een boer uit Dageraadsdorp, die het zelf heeft geprobeerd.)",
			"Slijmgel is overigens prima voor drankjes en zwaarden. Bedank de slijm daarvoor. In gedachten, dat is genoeg.",
		],
	},
	"dagboek": {
		"title": "Dagboek van de laatste bibliothecaris",
		"lines": [
			"Ik schrijf dit voor wie na mij komt. Ik heb mijn hele leven naar de Diepte gezocht, maar de weg nooit gevonden.",
			"Dit weet ik zeker: wie de Wachter wil wekken, heeft drie dingen nodig. Een sterke arm, een hart dat niet opgeeft en genoeg drankjes.",
			"De weg begint in de Kristaltempel. Pas als de Blauwe Kaart weer heel is, durft de steen te bewegen.",
			"De Sterrenkaart laat zich niet zomaar lezen. De Wachter zet je eerst op de proef. Doe het rustig aan. Slaap goed vooraf. En eet iets.",
		],
	},
}


static func flag_name(book_id: String) -> String:
	return "meer_gelezen_%s" % book_id
