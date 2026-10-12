extends RefCounted
## Polish-uitbreiding: extra content zonder nieuwe systemen.
## Korte side-quest "De Verdwenen Lantaarn" met bestaande stijl.
## Plaats de NPC op een kaart (bijv. village.gd) om hem te activeren.

const QUESTS := {
	"lantaarn": {
		"title": "De Verdwenen Lantaarn",
		"steps": [
			{
				"text": "Lotte zoekt haar speciale nachtlantaarn. Ze denkt dat die ergens in de Vergeten Ruïne is achtergebleven.",
				"advance_if": [["has", "special_lantern", 1]],
			},
			{"text": "Breng de nachtlantaarn terug naar Lotte in het dorp."},
		],
	},
}

const ITEMS := {
	"special_lantern": {
		"name": "Nachtlantaarn", "sheet": "items", "icon": 20, "type": "quest",
		"desc": "Een lantaarn die 's nachts verder en warmer schijnt dan een gewone fakkel.",
	},
}

const NPCS := {
	"lotte": {
		"name": "Lotte de lantaarnmaker", "sheet": "npc_greta", # tijdelijk hergebruik; eigen art later
		"rules": [
			{"if": [["step", "lantaarn", 1]], "talk": "lotte_klaar"},
			{"if": [["no_flag", "lotte_ontmoet"]], "talk": "lotte_intro"},
			{"talk": "lotte_menu"},
		],
	},
}

const TALKS := {
	"lotte_intro": {
		"speaker": "Lotte",
		"lines": [
			"Ik ben Lotte. Ik maak lantaarns voor het dorp.",
			"Mijn beste werk, de nachtlantaarn, is verdwenen. Ik had hem meegenomen naar de ruïne en daar gelaten.",
		],
		"do": [["set_flag", "lotte_ontmoet"]],
		"next": "lotte_vraag",
	},
	"lotte_vraag": {
		"speaker": "Lotte",
		"lines": ["Wil je hem voor me zoeken? Hij geeft veel beter licht in het donker."],
		"choices": [
			{"text": "Ik zoek hem wel.", "do": [["start_quest", "lantaarn"]], "next": "lotte_ok"},
			{"text": "Later misschien."},
		],
	},
	"lotte_ok": {
		"speaker": "Lotte",
		"lines": ["Dank je. Kijk in de Vergeten Ruïne, ergens bij de oude gangen."],
		"do": [["sound", "quest"]],
	},
	"lotte_menu": {
		"speaker": "Lotte",
		"lines": ["Heb je de nachtlantaarn al gevonden?"],
		"choices": [
			{"text": "Nog niet."},
			{"text": "Tot later."},
		],
	},
	"lotte_klaar": {
		"speaker": "Lotte",
		"lines": [
			"Je hebt hem! Hij werkt nog. Neem hem maar, hij helpt je beter in het donker dan een gewone.",
			"En hier wat munten voor de moeite.",
		],
		"do": [
			["take", "special_lantern"],
			["give", "special_lantern"], # player keeps it as gear-like
			["coins", 25],
			["finish_quest", "lantaarn"],
			["sound", "quest"],
		],
	},
}

const ACHIEVEMENTS := {
	"lantaarn_gevonden": {
		"name": "Licht in de duisternis",
		"desc": "Vind en terugbreng de nachtlantaarn van Lotte.",
		"if": [["quest", "lantaarn", "done"]],
	},
}
