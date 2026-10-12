extends RefCounted
## Uitbreiding "arena": een gevechtsarena met golven vijanden, rangen en trofeeën, bij het dorp.
##
## Arenameester Bruno schrijft je in voor Brons, Zilver of Goud. In de arena sluiten de poorten en komen er rondes
## vijanden uit de poorten, met rust en een hartje van het publiek ertussen. De rondes, beloningen en regels staan in
## scripts/data/arena.gd, de golven worden gespeeld door scripts/entities/arena_master.gd.
##
## Kaarten: arena_hall (de hal) en arena (het veld). De ingang staat in het noordoosten van Dageraadsdorp.

## Let op: dit bestand wordt al geladen als GameState zichzelf nog aan het laden is (via Content). Daarom staan er hier
## geen preload()s van scripts die GameState of Sound gebruiken: de regels (scripts/data/arena.gd) en de objectsoorten
## worden pas geladen als ze nodig zijn.
const LOGIC := "res://scripts/data/arena.gd"

const MAPS := {
	"arena_hall": preload("res://scripts/maps/arena_hall.gd"),
	"arena": preload("res://scripts/maps/arena.gd"),
}

const OBJECTS := {
	"arena_master": "res://scripts/entities/arena_master.gd",
	"arena_crowd": "res://scripts/entities/arena_crowd.gd",
	"arena_board": "res://scripts/entities/arena_board.gd",
	"arena_gong": "res://scripts/entities/arena_gong.gd",
	"arena_prop": "res://scripts/entities/arena_prop.gd",
}

## Voorwerpen. De iconen staan in assets/items_arena.png.
const ITEMS := {
	"arena_trophy_bronze": {
		"name": "Bronzen trofee", "icon": 0, "sheet": "items_arena", "type": "trophy",
		"desc": "Voor het winnen van de Brons-rang in de arena. Staat mooi op de trofeeënplank.",
	},
	"arena_trophy_silver": {
		"name": "Zilveren trofee", "icon": 1, "sheet": "items_arena", "type": "trophy",
		"desc": "Voor het winnen van de Zilver-rang in de arena. Hij glimt als een spiegel.",
	},
	"arena_trophy_gold": {
		"name": "Gouden trofee", "icon": 2, "sheet": "items_arena", "type": "trophy",
		"desc": "Voor het winnen van de Goud-rang in de arena. De hoogste eer van Dageraadsdorp!",
	},
	"arena_helm": {
		"name": "Arenahelm", "icon": 3, "sheet": "items_arena", "type": "trophy",
		"desc": "Een stalen helm met een rode pluim. Alleen een echte Arenakampioen mag hem dragen. Een verzamelstuk.",
	},
}

const SOUNDS := ["arena_gong", "arena_crowd", "arena_cheer", "arena_gate", "arena_fanfare", "arena_defeat"]
const TRACKS := ["arena"]

## Voorwaarden:  arena_open (de ingang in het dorp), arena_registered (je staat op de lijst),
##               arena_fight (er loopt een toernooi, de poorten zijn dicht), arena_free (andersom)
## Acties:       arena_enter <rang> (inschrijven), arena_cancel (uitschrijven), arena_forfeit (opgeven in de arena)
## Tekens in gesprekken: {arena_title} en {arena_best_bronze}, {arena_best_silver}, {arena_best_gold}
const CONDITIONS := ["arena_open", "arena_registered", "arena_fight", "arena_free"]
const ACTIONS := ["arena_enter", "arena_cancel", "arena_forfeit"]
const FORMATS := ["arena_title", "arena_best_bronze", "arena_best_silver", "arena_best_gold"]

const QUESTS := {
	"arena_kampioen": {
		"title": "Arenakampioen",
		"steps": [
			{
				"text": "Win de Brons-rang in de arena, in het noordoosten van het dorp. Arenameester Bruno schrijft je in.",
				"advance_if": [["flag", "arena_bronze_done"]],
			},
			{
				"text": "Win de Zilver-rang in de arena.",
				"advance_if": [["flag", "arena_silver_done"]],
			},
			{"text": "Win de Goud-rang en word Arenakampioen! In de laatste ronde staat een kristalgolem."},
		],
	},
}

const NPCS := {
	"arena_bruno": {
		"name": "Arenameester Bruno", "sheet": "npc_bruno",
		"rules": [
			{"if": [["flag", "arena_fresh_gold"]], "talk": "arena_bruno_won_gold"},
			{"if": [["flag", "arena_fresh_silver"]], "talk": "arena_bruno_won_silver"},
			{"if": [["flag", "arena_fresh_bronze"]], "talk": "arena_bruno_won_bronze"},
			{"if": [["flag", "arena_just_lost"]], "talk": "arena_bruno_lost"},
			{"if": [["flag", "arena_just_quit"]], "talk": "arena_bruno_quit"},
			{"if": [["arena_registered"]], "talk": "arena_bruno_registered"},
			{"if": [["no_flag", "arena_met_bruno"]], "talk": "arena_bruno_intro"},
			{"talk": "arena_bruno_menu"},
		],
	},
}

const TALKS := {
	"arena_bruno_intro": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"HA! Een nieuwe vechter! Welkom in de arena van Dageraadsdorp. Ik ben Bruno, de arenameester.",
			"Hier vecht je tegen golven vijanden, en het hele dorp kijkt toe. Dat hoor je aan het gejuich!",
			"Na elke ronde krijg je even rust en een hartje van het publiek. Maar de poorten gaan pas weer open als je alle rondes hebt gewonnen.",
		],
		"do": [["set_flag", "arena_met_bruno"], ["start_quest", "arena_kampioen"]],
		"next": "arena_bruno_menu",
	},
	"arena_bruno_menu": {
		"speaker": "Arenameester Bruno",
		"lines": ["Hé {arena_title}! Wat kan ik voor je doen?"],
		"choices": [
			{"text": "Ik wil meedoen.", "next": "arena_bruno_ranks"},
			{"text": "Hoe werkt het?", "next": "arena_bruno_rules"},
			{"text": "Mijn records.", "next": "arena_bruno_records"},
			{"text": "Tot ziens."},
		],
	},
	"arena_bruno_ranks": {
		"speaker": "Arenameester Bruno",
		"lines": ["Welke rang wil je proberen?"],
		"choices": [
			{"text": "Brons: 3 rondes, 10 munten", "next": "arena_bronze_info"},
			{"text": "Zilver: 5 rondes, 25 munten", "if": [["flag", "arena_bronze_done"]], "next": "arena_silver_info"},
			{"text": "Goud: 7 rondes, 50 munten", "if": [["flag", "arena_silver_done"]], "next": "arena_gold_info"},
			{"text": "Toch maar niet.", "next": "arena_bruno_menu"},
		],
	},
	"arena_bronze_info": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"Brons: drie rondes met slijmen en vleermuizen. Pas op voor de rode slijmen aan het eind! Inschrijven kost 10 munten.",
			"Win je, dan krijg je 50 munten en een bronzen trofee.",
		],
		"branch": [
			{"if": [["coins", 10]], "next": "arena_bronze_ask"},
			{"next": "arena_no_money"},
		],
	},
	"arena_bronze_ask": {
		"speaker": "Arenameester Bruno",
		"lines": ["Zal ik je inschrijven?"],
		"choices": [
			{"text": "Ja, schrijf me in!", "do": [["arena_enter", "bronze"]], "next": "arena_bruno_go"},
			{"text": "Nog even niet.", "next": "arena_bruno_menu"},
		],
	},
	"arena_silver_info": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"Zilver: vijf rondes, nu ook met skeletten die pijlen schieten. Inschrijven kost 25 munten.",
			"Win je, dan krijg je 150 munten en een zilveren trofee.",
		],
		"branch": [
			{"if": [["coins", 25]], "next": "arena_silver_ask"},
			{"next": "arena_no_money"},
		],
	},
	"arena_silver_ask": {
		"speaker": "Arenameester Bruno",
		"lines": ["Zal ik je inschrijven?"],
		"choices": [
			{"text": "Ja, schrijf me in!", "do": [["arena_enter", "silver"]], "next": "arena_bruno_go"},
			{"text": "Nog even niet.", "next": "arena_bruno_menu"},
		],
	},
	"arena_gold_info": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"Goud: zeven rondes, en in de laatste ronde komt er een kristalgolem uit de poort. Inschrijven kost 50 munten.",
			"Win je, dan krijg je 400 munten, een gouden trofee en een verrassing van mij. Tip: met een kristalzwaard kom je een stuk verder!",
		],
		"branch": [
			{"if": [["coins", 50]], "next": "arena_gold_ask"},
			{"next": "arena_no_money"},
		],
	},
	"arena_gold_ask": {
		"speaker": "Arenameester Bruno",
		"lines": ["Zal ik je inschrijven?"],
		"choices": [
			{"text": "Ja, schrijf me in!", "do": [["arena_enter", "gold"]], "next": "arena_bruno_go"},
			{"text": "Nog even niet.", "next": "arena_bruno_menu"},
		],
	},
	"arena_no_money": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"Hmm, je hebt niet genoeg munten voor de inschrijving.",
			"Versla wat slijmen en kom dan terug!",
		],
		"next": "arena_bruno_menu",
	},
	"arena_bruno_go": {
		"speaker": "Arenameester Bruno",
		"lines": ["Je staat op de lijst! Loop maar door de grote deur naar de arena. Succes, {arena_title}!"],
	},
	"arena_bruno_rules": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"De regels zijn simpel. Zodra je binnen bent, sluiten de poorten. Je kunt pas weg als je alle rondes hebt gewonnen.",
			"Na elke ronde heb je drie seconden rust, en het publiek gooit je een hartje toe. Gaat het tijdens een ronde heel slecht? Dan gooit het publiek er nog eentje.",
			"Word je verslagen? Dan ben je je inschrijving kwijt, maar je bent meteen weer helemaal beter. Opgeven kan ook: sla op de gong bij de uitgang.",
			"Zilver gaat open als je Brons hebt gehaald, en Goud als je Zilver hebt gehaald. Let op: vijanden in de arena laten niets vallen. Het gaat om de eer!",
			"Een rang nog een keer winnen mag altijd. Dan krijg je de helft van de munten, en misschien een nieuw record op het scorebord!",
		],
		"next": "arena_bruno_menu",
	},
	"arena_bruno_records": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"Jouw titel: {arena_title}.",
			"Je beste tijden. Brons: {arena_best_bronze}. Zilver: {arena_best_silver}. Goud: {arena_best_gold}.",
			"Ben je sneller? Dan zet ik je nieuwe tijd meteen op het scorebord.",
		],
		"next": "arena_bruno_menu",
	},
	"arena_bruno_registered": {
		"speaker": "Arenameester Bruno",
		"lines": ["Je staat al op de lijst! De grote deur naar de arena staat voor je open."],
		"choices": [
			{"text": "Top, ik ga!"},
			{"text": "Toch niet. Geef mijn munten maar terug.", "do": [["arena_cancel"]], "next": "arena_bruno_cancelled"},
		],
	},
	"arena_bruno_cancelled": {
		"speaker": "Arenameester Bruno",
		"lines": ["Geen probleem. Hier zijn je munten. Kom maar terug als je er klaar voor bent!"],
		"next": "arena_bruno_menu",
	},

	# --- Na een gevecht ---------------------------------------------------------------------------------
	"arena_bruno_won_bronze": {
		"speaker": "Arenameester Bruno",
		"lines": ["Wat een gevecht! Het publiek roept nog steeds je naam."],
		"do": [["clear_flag", "arena_fresh_bronze"]],
		"branch": [
			{"if": [["flag", "arena_first_bronze"]], "next": "arena_bruno_first_bronze"},
			{"next": "arena_bruno_menu"},
		],
	},
	"arena_bruno_first_bronze": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"Je eerste rang! Vanaf nu ben je een Arenastrijder. Je trofee staat op de plank.",
			"Zilver staat nu ook voor je open: vijf rondes, met skeletten die pijlen schieten. Succes!",
		],
		"do": [["clear_flag", "arena_first_bronze"]],
		"next": "arena_bruno_menu",
	},
	"arena_bruno_won_silver": {
		"speaker": "Arenameester Bruno",
		"lines": ["Zilver! Dat doet niet iedereen je na."],
		"do": [["clear_flag", "arena_fresh_silver"]],
		"branch": [
			{"if": [["flag", "arena_first_silver"]], "next": "arena_bruno_first_silver"},
			{"next": "arena_bruno_menu"},
		],
	},
	"arena_bruno_first_silver": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"Arenaridder! Zo mag ik je nu noemen. Nog één rang te gaan: Goud.",
			"Zeven rondes, en in de laatste komt een kristalgolem uit de poort. Neem je beste zwaard mee!",
		],
		"do": [["clear_flag", "arena_first_silver"]],
		"next": "arena_bruno_menu",
	},
	"arena_bruno_won_gold": {
		"speaker": "Arenameester Bruno",
		"lines": ["GOUD! Het dak ging bijna van de arena af!"],
		"do": [["clear_flag", "arena_fresh_gold"]],
		"branch": [
			{"if": [["flag", "arena_first_gold"]], "next": "arena_bruno_first_gold"},
			{"next": "arena_bruno_menu"},
		],
	},
	"arena_bruno_first_gold": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"Jij bent de nieuwe Arenakampioen! Er is niemand in heel Azura die dit beter kan.",
			"En dit is mijn verrassing: de Arenahelm! Een echte kampioen draagt hem met trots. Kijk maar op de plank: er staat nu van alles op!",
		],
		"do": [["clear_flag", "arena_first_gold"]],
		"next": "arena_bruno_menu",
	},
	"arena_bruno_lost": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"Au! Dat was een zware. Maar je bent weer helemaal beter, dat regel ik altijd.",
			"Je inschrijving ben je wel kwijt. Probeer het nog eens: vallen en opstaan, zo word je sterker!",
		],
		"do": [["clear_flag", "arena_just_lost"]],
		"next": "arena_bruno_menu",
	},
	"arena_bruno_quit": {
		"speaker": "Arenameester Bruno",
		"lines": [
			"Opgegeven? Geen schande hoor. Soms is stoppen slimmer dan doorvechten.",
			"Je inschrijving ben je wel kwijt, maar je bent weer helemaal beter. Kom maar terug als je klaar bent!",
		],
		"do": [["clear_flag", "arena_just_quit"]],
		"next": "arena_bruno_menu",
	},

	# --- De gong in de arena ------------------------------------------------------------------------------
	"arena_forfeit_ask": {
		"speaker": "Arenagong",
		"lines": [
			"Wil je opgeven? Dan galmt de gong en stopt het gevecht.",
			"Je inschrijving ben je dan kwijt. Je bent wel meteen weer helemaal beter.",
		],
		"choices": [
			{"text": "Ja, ik geef op.", "do": [["arena_forfeit"]]},
			{"text": "Nee, ik vecht door!"},
		],
	},
}


## De regels van de arena (scripts/data/arena.gd), geladen op het moment dat ze nodig zijn.
static func _arena() -> GDScript:
	return load(LOGIC)


static func check(cond: Array) -> bool:
	var arena := _arena()
	match cond[0]:
		"arena_open":
			return arena.is_open()
		"arena_registered":
			return arena.registered_rank() != ""
		"arena_fight":
			return arena.is_run_active()
		"arena_free":
			return not arena.is_run_active()
	return false


static func run(action: Array) -> void:
	var arena := _arena()
	match action[0]:
		"arena_enter":
			arena.register(action[1])
		"arena_cancel":
			arena.cancel()
		"arena_forfeit":
			var tree := Engine.get_main_loop() as SceneTree
			var master: Node = tree.get_first_node_in_group("arena_master")
			if master != null:
				master.forfeit()


## De tekst voor één teken uit FORMATS (zie Content.format_text).
static func format(token: String) -> String:
	return _arena().format(token)
