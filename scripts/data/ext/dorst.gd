extends RefCounted
## Uitbreiding "dorst": de Dorstvallei, een snikhete woestijnvallei ten oosten van het Dauwbos.
## Eigen klimaat (dwarrelzand en een warme gloed), een oase, cactusvelden, zandsteenklippen en de
## eerste wilde dieren van het spel: woestijnvossen en zandhazen, vreedzaam maar goed voor vel en vlees.
## De woestijngrondstoffen (cactusvijg, zandkruid, zandsteen) staan in ext/beroepen.gd.

const MAPS := {
	"dorstvallei": preload("res://scripts/maps/dorstvallei.gd"),
}

## Vreedzaam wild: gedrag "animal" betekent ronddralen, en wegrennen zodra je dichtbij komt of het raakt.
## Ze doen geen schade (aanraken is onschuldig), maar hun buit is de basis van de jacht.
const ENEMIES := {
	"woestijnvos": {
		"name": "Woestijnvos", "hp": 3, "damage": 0, "behavior": "animal",
		"speed": 42.0, "chase_speed": 96.0, "sight": 120.0, "panic_range": 85.0,
		"sheet": "woestijnvos", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 10.0,
		"drops": [["jacht_vlees", 0.9, 1], ["jacht_vacht", 0.8, 1], ["coin", 0.5, 1]],
		"desc": "Een sluwe vos met oren als warmtepanelen. Hij is niet gevaarlijk, maar wel verdomd snel.",
	},
	"zandhaas": {
		"name": "Zandhaas", "hp": 2, "damage": 0, "behavior": "animal",
		"speed": 48.0, "chase_speed": 108.0, "sight": 110.0, "panic_range": 95.0,
		"sheet": "zandhaas", "cell": 16, "scale": 2.0, "radius": 6.0, "shadow": 8.0,
		"drops": [["jacht_vlees", 0.9, 1], ["coin", 0.3, 1]],
		"desc": "Een haas die tussen de duinen huppelt. Zijn achterpoten zijn sneller dan je zwaard, bijna dan.",
	},
}

const ITEMS := {
	"jacht_vlees": {"name": "Rauw vlees", "sheet": "items_beroepen", "icon": 28, "type": "material", "sell": 4, "desc": "Vers vlees van wild uit de Dorstvallei. Braad het in de keuken van de herberg."},
	"jacht_vacht": {"name": "Dierenvacht", "sheet": "items_beroepen", "icon": 29, "type": "material", "sell": 6, "desc": "Een zachte vossenvacht. Handelaars en kleermakers betalen er goed voor."},
	"jacht_braadstuk": {"name": "Braadstuk", "sheet": "items_beroepen", "icon": 30, "type": "use", "heal": 3, "desc": "Sappig gebraden vlees met zandkruid. Herstelt 3 hartjes. Gebruik via Beroepen → Eten & drinken."},
}

const QUESTS := {
	"vellen_en_vlees": {
		"title": "Vellen en vlees",
		"steps": [
			{
				"text": "Jelle de vellenhandelaar vraagt 2 dierenvachten en 2 stukken rauw vlees. Jaag op het wild van de Dorstvallei.",
				"advance_if": [["has", "jacht_vacht", 2], ["has", "jacht_vlees", 2]],
			},
			{"text": "Breng de vellen en het vlees naar Jelle in de Dorstvallei."},
		],
	},
	"cactusvijgen": {
		"title": "Cactusvijgen voor Sana",
		"steps": [
			{
				"text": "Sana bij de oase heeft 5 cactusvijgen nodig voor haar koele drankjes. Ze groeien op de cactussen van de vallei.",
				"advance_if": [["has", "prof_cactusvijg", 5]],
			},
			{"text": "Breng de cactusvijgen naar Sana bij de oase."},
		],
	},
}

const NPCS := {
	"jelle": {
		"name": "Jelle de vellenhandelaar", "sheet": "npc_joost",
		"rules": [
			{"if": [["step", "vellen_en_vlees", 1]], "talk": "jelle_klaar"},
			{"if": [["no_flag", "jelle_ontmoet"]], "talk": "jelle_intro"},
			{"talk": "jelle_menu"},
		],
	},
	"sana": {
		"name": "Sana van de oase", "sheet": "npc_anja",
		"rules": [
			{"if": [["step", "cactusvijgen", 1]], "talk": "sana_klaar"},
			{"if": [["no_flag", "sana_ontmoet"]], "talk": "sana_intro"},
			{"talk": "sana_menu"},
		],
	},
	"nour": {
		"name": "Nour de woestijngids", "sheet": "npc_hein",
		"rules": [
			{"if": [["no_flag", "nour_ontmoet"]], "talk": "nour_intro"},
			{"talk": "nour_menu"},
		],
	},
}

const TALKS := {
	"jelle_intro": {
		"speaker": "Jelle",
		"lines": ["Vreemdeling! Welkom in de Dorstvallei. Ik ben Jelle; ik handel in vellen en vlees.", "De vossen hier hebben de zachtste vacht van het land. Maar vangen... dat is een ander verhaal."],
		"do": [["set_flag", "jelle_ontmoet"]],
		"next": "jelle_vraag",
	},
	"jelle_vraag": {
		"speaker": "Jelle",
		"lines": ["Wil je voor me jagen? Breng me 2 dierenvachten en 2 stukken rauw vlees van het wild hier."],
		"choices": [
			{"text": "Ik ga op jacht.", "do": [["start_quest", "vellen_en_vlees"]], "next": "jelle_ok"},
			{"text": "Later misschien."},
		],
	},
	"jelle_ok": {"speaker": "Jelle", "lines": ["Mooi. De vossen zitten in het oosten, de hazen in het zuiden. Ze rennen weg als je te dichtbij komt, dus zet aan met een sprint. Of neem een boog mee."], "do": [["sound", "quest"]]},
	"jelle_menu": {"speaker": "Jelle", "lines": ["Heb je de vellen en het vlees al?"], "choices": [{"text": "Nog niet."}, {"text": "Tot zo."}]},
	"jelle_klaar": {
		"speaker": "Jelle",
		"lines": ["Ah, prachtig spul! Zulke vellen zie je zelden.", "Hier, je deel van de opbrengst. En een braadstuk van mijn eigen voorraad, je hebt het verdiend."],
		"do": [["take", "jacht_vacht", 2], ["take", "jacht_vlees", 2], ["give", "jacht_braadstuk"], ["coins", 40], ["finish_quest", "vellen_en_vlees"], ["sound", "quest"]],
	},

	"sana_intro": {
		"speaker": "Sana",
		"lines": ["Welkom bij de oase, reiziger. Ik ben Sana. Dit water is het hart van de vallei.", "Ik maak koele drankjes van cactusvijgen. Zoet, en je houdt er de hitte mee uit."],
		"do": [["set_flag", "sana_ontmoet"]],
		"next": "sana_vraag",
	},
	"sana_vraag": {
		"speaker": "Sana",
		"lines": ["Wil je 5 cactusvijgen voor me plukken? Ze groeien op de cactussen, vooral in het noordwesten en het oosten."],
		"choices": [
			{"text": "Ik pluk ze wel.", "do": [["start_quest", "cactusvijgen"]], "next": "sana_ok"},
			{"text": "Niet nu."},
		],
	},
	"sana_ok": {"speaker": "Sana", "lines": ["Dank je. Pas op voor de stekels, en groet de hazen van me als je ze ziet."], "do": [["sound", "quest"]]},
	"sana_menu": {"speaker": "Sana", "lines": ["Heb je de cactusvijgen al?"], "choices": [{"text": "Nog niet."}, {"text": "Tot zo."}]},
	"sana_klaar": {
		"speaker": "Sana",
		"lines": ["Wat een mooie vijgen! Hier wordt de hele vallei blij van.", "Neem mijn zandbalsem mee; die maakte ik van het zandkruid dat hier groeit."],
		"do": [["take", "prof_cactusvijg", 5], ["give", "prof_zandbalsem"], ["coins", 30], ["finish_quest", "cactusvijgen"], ["sound", "quest"]],
	},

	"nour_intro": {
		"speaker": "Nour",
		"lines": ["Ah, iemand van over de heuvelrug. Ik ben Nour; ik gids reizigers door het zand.", "De Dorstvallei is hard maar eerlijk. De oase geeft water, de cactus geeft fruit, het wild geeft vlees."],
		"do": [["set_flag", "nour_ontmoet"]],
		"next": "nour_menu",
	},
	"nour_menu": {
		"speaker": "Nour",
		"lines": ["Wat wil je weten van de vallei?"],
		"choices": [
			{"text": "Over de oase.", "next": "nour_oase"},
			{"text": "Over het wild.", "next": "nour_wild"},
			{"text": "Over de hitte.", "next": "nour_hitte"},
			{"text": "Een andere keer."},
		],
	},
	"nour_oase": {"speaker": "Nour", "lines": ["De oase is ouder dan elk dorp in het westen. Zonder dit water was hier alleen zand geweest.", "Sana waakt erover. Pluk gerust vijgen, maar laat het water met rust."], "next": "nour_menu"},
	"nour_wild": {"speaker": "Nour", "lines": ["De vossen en hazen zijn schuw, niet gevaarlijk. Kom je te dichtbij, dan verdwijnen ze als een stofwolk.", "Jelle betaalt goed voor vel en vlees. En met een boog haal je ze neer voordat ze weg zijn."], "next": "nour_menu"},
	"nour_hitte": {"speaker": "Nour", "lines": ["De zon brandt hier de hele dag en het zand waait nooit helemaal stil.", "Draag iets luchts, drink genoeg, en zoek op het heetst de schaduw van de klippen op."], "next": "nour_menu"},
}

const ACHIEVEMENTS := {
	"dorstvallei_ontdekt": {
		"name": "Zandvoeten", "desc": "Ontdek de Dorstvallei en praat met Jelle, Sana en Nour.",
		"if": [["talked_to_all", ["jelle", "sana", "nour"]]],
	},
}
