extends RefCounted
## Uitbreiding "moeras": Het Kruipmoeras, een drassig veenland ten zuiden van het Zilvermeer.
## Eigen klimaat (een vochtige waas die het licht groenig dempt), een drijfmestplas met een
## eilandje, rietlanden, turfvelden en nieuw vreedzaam wild: moerasvorsten en waterslangen.
## De moerasgrondstoffen (veenbes, watermunt, wilgentwijg, ijzeroer) staan in ext/beroepen.gd.

const MAPS := {
	"kruipmoeras": preload("res://scripts/maps/kruipmoeras.gd"),
}

## Vreedzaam wild: gedrag "animal" betekent ronddralen, en wegrennen zodra je dichtbij komt of het raakt.
## Ze doen geen schade (aanraken is onschuldig), maar hun buit is de basis van de jacht.
const ENEMIES := {
	"moerasvors": {
		"name": "Moerasvors", "hp": 2, "damage": 0, "behavior": "animal",
		"speed": 38.0, "chase_speed": 92.0, "sight": 110.0, "panic_range": 90.0,
		"sheet": "moerasvors", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 10.0,
		"drops": [["jacht_vlees", 0.9, 1], ["moeras_huid", 0.8, 1], ["coin", 0.3, 1]],
		"desc": "Een trage vors met een kwak die door het hele veen galmt. Tot hij springt; dan is hij verdwenen.",
	},
	"waterslang": {
		"name": "Waterslang", "hp": 2, "damage": 0, "behavior": "animal",
		"speed": 50.0, "chase_speed": 110.0, "sight": 120.0, "panic_range": 95.0,
		"sheet": "waterslang", "cell": 16, "scale": 2.0, "radius": 6.0, "shadow": 8.0,
		"drops": [["jacht_vlees", 0.7, 1], ["moeras_huid", 0.9, 1], ["coin", 0.4, 1]],
		"desc": "Een gladde slang die tussen het riet glijdt. Ongevaarlijk, maar je grijpt hem zelden bij de staart.",
	},
}

const ITEMS := {
	"moeras_huid": {"name": "Moerashuid", "sheet": "items_beroepen", "icon": 62, "type": "material", "sell": 6, "desc": "Een taaie, waterdichte huid van moeraswild. Kleermakers werken er graag mee."},
	"zonneschijf_amulet": {"name": "Zonneschijfamulet", "sheet": "items", "icon": 5, "type": "quest", "desc": "Een gouden schijfje aan een verweerd koord. Het voelt warm, alsof de zon er nog in zit."},
}

const QUESTS := {
	"veenbessen": {
		"title": "Veenbessen voor Stien",
		"steps": [
			{
				"text": "Stien de turfsterke heeft 5 veenbessen nodig voor haar pap. Ze groeien laag bij de plassen van het Kruipmoeras.",
				"advance_if": [["has", "prof_veenbes", 5]],
			},
			{"text": "Breng de veenbessen naar Stien op de turfvelden."},
		],
	},
	"wilgentwijgen": {
		"title": "Wilgentwijgen voor Mees",
		"steps": [
			{
				"text": "Mees de rietvlechter heeft 4 wilgentwijgen nodig voor een nieuwe mand. Snijd ze bij de geknotte wilgen.",
				"advance_if": [["has", "prof_wilgentwijg", 4]],
			},
			{"text": "Breng de wilgentwijgen naar Mees in het rietland."},
		],
	},
	"zonneschijf": {
		"title": "De zonneschijf van Wouda",
		"steps": [
			{
				"text": "Wouda de kruidenheks vertelde over een zonneschijfamulet op het eilandje in de drijfmestplas. Zoek het.",
				"advance_if": [["has", "zonneschijf_amulet", 1]],
			},
			{"text": "Breng het amulet naar Wouda bij de wilgenhut."},
		],
	},
}

const NPCS := {
	"stien": {
		"name": "Stien de turfsterke", "sheet": "npc_stien",
		"rules": [
			{"if": [["step", "veenbessen", 1], ["has", "prof_veenbes", 5]], "talk": "stien_klaar"},
			{"if": [["no_flag", "stien_ontmoet"]], "talk": "stien_intro"},
			{"if": [["quest", "veenbessen", "none"]], "talk": "stien_intro"},
			{"talk": "stien_menu"},
		],
	},
	"mees": {
		"name": "Mees de rietvlechter", "sheet": "npc_mees",
		"rules": [
			{"if": [["step", "wilgentwijgen", 1], ["has", "prof_wilgentwijg", 4]], "talk": "mees_klaar"},
			{"if": [["no_flag", "mees_ontmoet"]], "talk": "mees_intro"},
			{"if": [["quest", "wilgentwijgen", "none"]], "talk": "mees_intro"},
			{"talk": "mees_menu"},
		],
	},
	"wouda": {
		"name": "Wouda de kruidenheks", "sheet": "npc_wouda",
		"rules": [
			{"if": [["step", "zonneschijf", 1], ["has", "zonneschijf_amulet", 1]], "talk": "wouda_klaar"},
			{"if": [["no_flag", "wouda_ontmoet"]], "talk": "wouda_intro"},
			{"if": [["quest", "zonneschijf", "none"]], "talk": "wouda_intro"},
			{"talk": "wouda_menu"},
		],
	},
}

const TALKS := {
	"stien_intro": {
		"speaker": "Stien",
		"lines": ["Hé daar, oppassen waar je loopt! De turfvelden verrassen je, voor je het weet zak je tot je enkels.", "Ik ben Stien. Ik steek turf, zodat het dorp warm blijft in de winter."],
		"do": [["set_flag", "stien_ontmoet"]],
		"next": "stien_vraag",
	},
	"stien_vraag": {
		"speaker": "Stien",
		"lines": ["Ik werk hier van ochtend tot avond en vergeet steeds te eten. Pluk je 5 veenbessen voor me? Dan maak ik mijn beroemde veenbespap.", "Ze groeien laag bij de plassen; zoek de rode stipjes tussen het groen."],
		"choices": [
			{"text": "Ik pluk ze voor je.", "do": [["start_quest", "veenbessen"]], "next": "stien_ok"},
			{"text": "Nu even niet."},
		],
	},
	"stien_ok": {"speaker": "Stien", "lines": ["Lekker bezig. En als je een vors hoort kwaken, kwak maar terug. Werkt altijd."], "do": [["sound", "quest"]]},
	"stien_menu": {"speaker": "Stien", "lines": ["Heb je de veenbessen al? Mijn maag knort luider dan de vorsten."], "choices": [{"text": "Nog niet."}, {"text": "Tot zo."}]},
	"stien_klaar": {
		"speaker": "Stien",
		"lines": ["Oooh, prachtige bessen! Zo rood als de zon achter de wilgen.", "Hier, een klomp ijzeroer uit mijn veld. En een paar munten; een deal is een deal."],
		"do": [["take", "prof_veenbes", 5], ["give", "prof_ijzeroer"], ["coins", 30], ["finish_quest", "veenbessen"], ["sound", "quest"]],
	},

	"mees_intro": {
		"speaker": "Mees",
		"lines": ["Welkom in het rietland. Hoor je dat knetteren? Dat is het riet dat met de wind praat.", "Ik ben Mees. Van riet en wilg vlecht ik manden, hoeden en af en toe een leugen van een visverhaal."],
		"do": [["set_flag", "mees_ontmoet"]],
		"next": "mees_vraag",
	},
	"mees_vraag": {
		"speaker": "Mees",
		"lines": ["Mijn beste mand vraagt om wilgentwijgen; buigzaam en sterk tegelijk. Snijd je er 4 voor me bij de geknotte wilgen?", "Neem wel een bijl mee, anders word je niet vrolijk van dat hout."],
		"choices": [
			{"text": "Ik snijd ze wel.", "do": [["start_quest", "wilgentwijgen"]], "next": "mees_ok"},
			{"text": "Misschien later."},
		],
	},
	"mees_ok": {"speaker": "Mees", "lines": ["Mooi. De wilgen staan hier overal, maar de beste twijgen groeien bij de hut van Wouda in het noordwesten."], "do": [["sound", "quest"]]},
	"mees_menu": {"speaker": "Mees", "lines": ["Zijn de twijgen al gesneden?"], "choices": [{"text": "Nog niet."}, {"text": "Tot zo."}]},
	"mees_klaar": {
		"speaker": "Mees",
		"lines": ["Ah, kijk die buigen! Hier wordt een mand van waar je U tegen zegt.", "Voor jou: een bos watermunt uit mijn eigen voorraad. Fris voor in de thee, of sterker spul als je Wouda vraagt."],
		"do": [["take", "prof_wilgentwijg", 4], ["give", "prof_watermunt", 2], ["coins", 25], ["finish_quest", "wilgentwijgen"], ["sound", "quest"]],
	},

	"wouda_intro": {
		"speaker": "Wouda",
		"lines": ["Ah... een wandelaar uit het noorden. Ik ben Wouda; het moeras kent mij en ik ken het moeras.", "Weet je wat dit land ooit was? De zilverzijde van het meer. De zon lag hier op het water en de schijf werd aanbeden.", "Toen zakte de grond, steeg het veen, en verdween de tempel onder de drijfmest."],
		"do": [["set_flag", "wouda_ontmoet"]],
		"next": "wouda_vraag",
	},
	"wouda_vraag": {
		"speaker": "Wouda",
		"lines": ["Op het eilandje in de grote plas ligt nog het zonneschijfamulet, het laatste stuk van die oude wereld.", "De loopbruggen houden je droog... meestal. Haal het voor me, dan vertel ik je wat de Diepte met dit alles te maken heeft."],
		"choices": [
			{"text": "Ik zoek het amulet.", "do": [["start_quest", "zonneschijf"]], "next": "wouda_ok"},
			{"text": "Dat klinkt gevaarlijk."},
		],
	},
	"wouda_ok": {"speaker": "Wouda", "lines": ["Volg de modderpaden naar het hart van het veen. Het eiland wacht al honderd jaar; hij wacht jou ook wel af."], "do": [["sound", "quest"]]},
	"wouda_menu": {
		"speaker": "Wouda",
		"lines": ["Het moeras ademt, hoor je dat? Vraag maar wat je wilt weten."],
		"choices": [
			{"text": "Over het amulet.", "next": "wouda_amulet"},
			{"text": "Over de kruiden hier.", "next": "wouda_kruiden"},
			{"text": "Een andere keer."},
		],
	},
	"wouda_amulet": {"speaker": "Wouda", "lines": ["Het amulet ligt op het eilandje, midden in de drijfmestplas. Over de loopbruggen kom je er.", "Het is goud dat nooit roestte, omdat het de zon zelf bewaarde. Dat zeggen ze tenminste."], "next": "wouda_menu"},
	"wouda_kruiden": {"speaker": "Wouda", "lines": ["Watermunt langs de paden, veenbessen bij de plassen. En diep in de turf zit ijzeroer, het bloed van het veen.", "Met munt en bes brouw ik een elixer dat je benen nieuw leven geeft. De bibliotheek heeft het fornuis ervoor."], "next": "wouda_menu"},
	"wouda_klaar": {
		"speaker": "Wouda",
		"lines": ["De zonneschijf... honderd jaar veen en hij gloeit nog. Voel je dat? Warm.", "De Diepte onder de grot en dit moeras zijn zussen: waar het water de wereld opslokte, bleef het licht in kleine dingen wonen.", "Neem mijn moeraselixer mee. En kom terug als het veen je weer roept."],
		"do": [["take", "zonneschijf_amulet"], ["give", "prof_moeraselixer"], ["coins", 40], ["finish_quest", "zonneschijf"], ["sound", "quest"]],
	},
}

const ACHIEVEMENTS := {
	"kruipmoeras_ontdekt": {
		"name": "Veenvoeten", "desc": "Ontdek het Kruipmoeras en praat met Stien, Mees en Wouda.",
		"if": [["talked_to_all", ["stien", "mees", "wouda"]]],
	},
}
