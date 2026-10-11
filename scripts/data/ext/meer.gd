extends RefCounted
## Uitbreiding "meer": het Zilvermeer. Een rustig gebied ten zuiden van het dorp met vissen, een bibliotheek,
## drie nieuwe personages (Visser Joris, Lena en Sanne) en twee opdrachten (De Gouden Karper, Boekenwurm).
##
## Het visspel zelf staat in scripts/ui/fishing_ui.gd (en fishing_reel.gd), de vissen en prijzen in meer_vis.gd,
## de lessenaar-teksten in meer_boeken.gd en de kaarten in scripts/maps/lake.gd, fisher_hut.gd en library.gd.
## Eigen opslag: GameState.meer ({"verkocht", "gevangen", "pech"}).
##
## Dit bestand bevat alleen gegevens. De werking (voorwaarden, acties, vis verkopen) staat in meer_logic.gd en wordt pas
## geladen als het spel draait: de speltesten compileren dit bestand voordat de autoloads (GameState, Sound) bestaan,
## en scripts die daarnaar verwijzen kunnen dan niet gecompileerd worden.

const LOGIC := "res://scripts/data/ext/meer_logic.gd"

const MAPS := {
	"lake": preload("res://scripts/maps/lake.gd"),
	"fisher_hut": preload("res://scripts/maps/fisher_hut.gd"),
	"library": preload("res://scripts/maps/library.gd"),
}

const SOUNDS := ["meer_plons", "meer_beet", "meer_haspel", "meer_vangst", "meer_ontsnapt", "meer_blad", "meer_kast"]
const TRACKS := ["lake"]

## Onze objecten op de kaart (soort -> pad van het script, zie content.gd).
const OBJECT_PATHS := {
	"meer_visplek": "res://scripts/entities/meer_visplek.gd",
	"meer_lessenaar": "res://scripts/entities/meer_lessenaar.gd",
	"meer_kast": "res://scripts/entities/meer_kast.gd",
	"meer_water": "res://scripts/entities/meer_water.gd",
}

## Stipjes op het kaartje in het menu (N) voor onze soorten objecten, met een naam voor de legenda.
const MAP_MARKERS := {
	"meer_visplek": {"color": Color(0.7, 0.95, 1.0), "label": "visplek"},
	"meer_lessenaar": {"color": Color(1.0, 0.75, 0.9), "label": "lessenaar"},
}

const CONDITIONS := ["meer_vis", "meer_vol", "meer_boeken", "meer_gelezen"]
const ACTIONS := ["meer_verkoop"]
const FORMATS := ["boeken"] # {boeken} in een opdrachttekst: hoeveel boeken je al hebt

const ITEMS := {
	"fishing_rod": {
		"name": "Hengel", "sheet": "items_meer", "icon": 0, "type": "gear",
		"desc": "De reservehengel van Visser Joris. Ga bij een visplek in het Zilvermeer staan en druk op E.",
	},
	"meer_baars": {
		"name": "Baars", "sheet": "items_meer", "icon": 1, "type": "fish", "sell": 8,
		"desc": "Een gestreepte baars met rode vinnen. Joris en Mila kopen hem voor 8 munten.",
	},
	"meer_snoek": {
		"name": "Snoek", "sheet": "items_meer", "icon": 2, "type": "fish", "sell": 15,
		"desc": "Een lange snoek met een grote bek. Goed voor 15 munten bij Joris of Mila.",
	},
	"meer_gouden_karper": {
		"name": "Gouden Karper", "sheet": "items_meer", "icon": 3, "type": "quest", "sell": 60,
		"desc": "De beroemde vis van het Zilvermeer. Hij glinstert alsof hij van goud is. Visser Joris droomt van hem.",
	},
	"meer_laars": {
		"name": "Oude laars", "sheet": "items_meer", "icon": 4, "type": "fish", "sell": 1,
		"desc": "Een natte, stinkende laars. Joris verzamelt ze. Waarom, dat weet niemand. Waarde: 1 munt.",
	},
	"fishers_cap": {
		"name": "Vissershoed", "sheet": "items_meer", "icon": 5, "type": "gear",
		"desc": "De pet van Visser Joris. Met deze pet betalen Joris en Mila je 10% extra voor je vis.",
	},
	"meer_boek_eiland": {
		"name": "Sagen van het Zilvermeer", "sheet": "items_meer", "icon": 6, "type": "quest",
		"desc": "Een van de drie boeken die Lena mist. Je vond het op het eiland.",
	},
	"meer_boek_hut": {
		"name": "Het Grote Vissenboek", "sheet": "items_meer", "icon": 7, "type": "quest",
		"desc": "Een van de drie boeken die Lena mist. Het lag in het huisje van Joris, met een koffiekring erop.",
	},
	"meer_boek_sanne": {
		"name": "Sterren boven Azura", "sheet": "items_meer", "icon": 8, "type": "quest",
		"desc": "Een van de drie boeken die Lena mist. Sanne gaf het aan je.",
	},
	"meer_schelp": {
		"name": "Zilverschelp", "sheet": "items_meer", "icon": 9, "type": "treasure",
		"desc": "Een roze schelp uit het Zilvermeer. Als je goed luistert, hoor je een rustig liedje. Een verzamelstuk.",
	},
}

const QUESTS := {
	"meer_karper": {
		"title": "De Gouden Karper",
		"steps": [
			{
				"text": "Visser Joris droomt van de Gouden Karper. Vang hem in diep water, aan het eind van de verre steiger in het Zilvermeer.",
				"advance_if": [["has", "meer_gouden_karper", 1]],
			},
			{"text": "Je hebt de Gouden Karper! Breng hem naar Visser Joris in het Zilvermeer."},
		],
	},
	"meer_boeken": {
		"title": "Boekenwurm",
		"steps": [
			{
				"text": "Lena van de bibliotheek mist drie boeken: een op het eiland in het Zilvermeer, een in het huisje van Joris en een bij Sanne. ({boeken}/3)",
				"advance_if": [["meer_boeken", 3]],
			},
			{"text": "Je hebt alle drie de boeken! Breng ze naar Lena in de bibliotheek."},
		],
	},
}

const NPCS := {
	"meer_joris": {
		"name": "Visser Joris", "sheet": "npc_meer_joris",
		"rules": [
			{"if": [["step", "meer_karper", 1]], "talk": "meer_joris_karper_klaar"},
			{"if": [["has", "meer_gouden_karper", 1], ["quest", "meer_karper", "none"]], "talk": "meer_joris_karper_direct"},
			{"if": [["no_flag", "meer_joris_ontmoet"]], "talk": "meer_joris_intro"},
			{"talk": "meer_joris_menu"},
		],
	},
	"meer_lena": {
		"name": "Lena de bibliothecaresse", "sheet": "npc_meer_lena",
		"rules": [
			{"if": [["quest", "meer_boeken", "done"]], "talk": "meer_lena_klaar"},
			{"if": [["step", "meer_boeken", 1]], "talk": "meer_lena_boeken_terug"},
			{"if": [["quest", "meer_boeken", "active"]], "talk": "meer_lena_voortgang"},
			{"if": [["no_flag", "meer_lena_ontmoet"]], "talk": "meer_lena_intro"},
			{"talk": "meer_lena_menu"},
		],
	},
	"meer_sanne": {
		"name": "Sanne", "sheet": "npc_meer_sanne",
		"rules": [
			{"if": [["flag", "meer_sanne_boek"]], "talk": "meer_sanne_klaar"},
			{"if": [["no_flag", "meer_sanne_ontmoet"]], "talk": "meer_sanne_intro"},
			{"talk": "meer_sanne_menu"},
		],
	},
}

const TALKS := {
	# --- Visser Joris ---------------------------------------------------------------------
	"meer_joris_intro": {
		"speaker": "Visser Joris",
		"lines": [
			"Hmpf. Een bezoeker. Ik dacht dat de vissen het ergste waren, maar nee: mensen.",
			"...Grapje. Ik ben Joris, visser van het Zilvermeer. Al veertig jaar. Ik heb meer vissen gezien dan jij haren hebt.",
			"Je staat naar mijn hengel te kijken. Je wilt vissen, hè? Ik zie het aan je ogen. Ze glimmen als een baars.",
		],
		"do": [["set_flag", "meer_joris_ontmoet"]],
		"next": "meer_joris_hengel",
	},
	"meer_joris_hengel": {
		"speaker": "Visser Joris",
		"lines": [
			"Hier, neem mijn reservehengel. Gratis. Maar behandel hem lief.",
			"Je vist bij een visplek: dat zijn de kringetjes in het water. Ga ernaast staan en druk op E. Wacht dan op een beet, en wees snel!",
		],
		"do": [["give", "fishing_rod"], ["sound", "quest"]],
		"next": "meer_joris_menu",
	},
	"meer_joris_menu": {
		"speaker": "Visser Joris",
		"lines": ["Nou? Wat kan ik voor je doen?"],
		"choices": [
			{"text": "Verkoop al mijn vis", "if": [["meer_vis"]], "next": "meer_joris_verkoop"},
			{"text": "Heb je werk voor me?", "if": [["quest", "meer_karper", "none"]], "next": "meer_joris_karper_vraag"},
			{"text": "Hoe is het met de Gouden Karper?", "if": [["quest", "meer_karper", "active"]], "next": "meer_joris_karper_voortgang"},
			{"text": "Heb je tips over vissen?", "next": "meer_joris_tips"},
			{"text": "Hoe gaat het nu de Slijmkoning weg is?", "if": [["flag", "game_completed"]], "next": "meer_joris_na"},
			{"text": "Tot ziens."},
		],
	},
	"meer_joris_na": {
		"speaker": "Visser Joris",
		"lines": [
			"De Slijmkoning is weg? Dat wist ik al. De slijmen aan de overkant eten niet langer mijn aas. Ze zijn gewoon... rustig.",
			"Ik begin ze bijna aardig te vinden. Vertel het niet door, ik heb een reputatie.",
		],
		"next": "meer_joris_menu",
	},
	"meer_joris_verkoop": {
		"speaker": "Visser Joris",
		"lines": ["Laat maar zien... Hm. Hm-hm. Die zijn goed. Ik geef er een eerlijke prijs voor."],
		"do": [["meer_verkoop"]],
		"branch": [
			{"if": [["meer_vol"], ["no_flag", "meer_vol_gemeld"]], "next": "meer_joris_vol"},
			{"if": [["meer_vol"]], "next": "meer_joris_vol_kort"},
			{"next": "meer_joris_verkocht"},
		],
	},
	"meer_joris_verkocht": {
		"speaker": "Visser Joris",
		"lines": ["Zo. Eerlijk zaken doen, dat vind ik prettig. Kom maar terug als je meer hebt."],
	},
	"meer_joris_vol": {
		"speaker": "Visser Joris",
		"lines": [
			"Pfff. Het hele dorp zit vol met vis. Ik heb vis in de kast, vis in de la en vis in mijn laarzen.",
			"Vanaf nu betaal ik maar de helft. Dat is niet persoonlijk, hoor. Zo werkt de vismarkt.",
		],
		"do": [["set_flag", "meer_vol_gemeld"]],
	},
	"meer_joris_vol_kort": {
		"speaker": "Visser Joris",
		"lines": ["Hmpf. Het dorp zit nog steeds vol met vis. Ik betaal de helft, weet je nog?"],
	},
	"meer_joris_tips": {
		"speaker": "Visser Joris",
		"lines": ["Tips? Ik heb alleen maar tips. Wat wil je weten?"],
		"choices": [
			{"text": "Hoe vang ik een vis?", "next": "meer_joris_tip_vangen"},
			{"text": "Waar zitten de grote vissen?", "next": "meer_joris_tip_diep"},
			{"text": "Wat doe ik met mijn vis?", "next": "meer_joris_tip_verkopen"},
			{"text": "Dank je, genoeg."},
		],
	},
	"meer_joris_tip_vangen": {
		"speaker": "Visser Joris",
		"lines": [
			"Gooi uit bij een visplek. Wacht tot de dobber zakt en er een uitroepteken verschijnt. Druk dan snel op E!",
			"Houd daarna E ingedrukt: dan stijgt de groene zone. Laat los, dan zakt hij. Houd de vis in het groen tot de balk vol is.",
		],
		"next": "meer_joris_tips",
	},
	"meer_joris_tip_diep": {
		"speaker": "Visser Joris",
		"lines": [
			"In diep water. Aan het eind van de verre steiger, helemaal aan de oostkant van het meer.",
			"Daar zwemt de grootste vis van het meer. Ik heb hem al honderd keer gezien. En nul keer gevangen.",
		],
		"next": "meer_joris_tips",
	},
	"meer_joris_tip_verkopen": {
		"speaker": "Visser Joris",
		"lines": [
			"Verkopen, natuurlijk! Aan mij, of aan Mila in de herberg. Zij maakt er soep van.",
			"Maar pas op: als het dorp te veel vis heeft, gaat de prijs omlaag. Dat gaat zo met vis. Ook met mensen, trouwens.",
		],
		"next": "meer_joris_tips",
	},
	"meer_joris_karper_vraag": {
		"speaker": "Visser Joris",
		"lines": [
			"Werk? Hmpf. Ja, eigenlijk wel. Maar je gaat me uitlachen.",
			"Ik droom al jaren van de Gouden Karper. Een vis van puur goud. Grote ogen, glimmende schubben, veel te slim.",
			"Ik heb hem één keer gezien, vanaf de verre steiger. Hij zwom langs, keek me aan en... lachte. Echt waar.",
			"Vang hem voor me. Dan weet ik tenminste dat hij echt bestaat.",
		],
		"choices": [
			{"text": "Ik ga hem vangen!", "do": [["start_quest", "meer_karper"]], "next": "meer_joris_karper_ok"},
			{"text": "Misschien later."},
		],
	},
	"meer_joris_karper_ok": {
		"speaker": "Visser Joris",
		"lines": [
			"Echt? Goed zo. Probeer het in diep water, aan het eind van de verre steiger. Hij is niet gek: een gewone plek haalt hem niet.",
			"En geduld, hè. Veel geduld. Vissen is vooral wachten. En mopperen.",
		],
		"do": [["sound", "quest"]],
	},
	"meer_joris_karper_voortgang": {
		"speaker": "Visser Joris",
		"lines": [
			"Nog geen gouden vis? Diep water, aan het eind van de verre steiger. Hij laat zich niet zomaar zien.",
			"Hoe vaker je het probeert, hoe nieuwsgieriger hij wordt. Dat zeg ik tenminste tegen mezelf.",
		],
	},
	"meer_joris_karper_direct": {
		"speaker": "Visser Joris",
		"lines": [
			"Wat heb je daar in je tas? Is dat... Nee. Dat kan niet.",
			"Je hebt hem gewoon gevangen, zonder dat ik het je vroeg? Ik moet even gaan zitten.",
		],
		"do": [["start_quest", "meer_karper"]],
		"next": "meer_joris_karper_klaar",
	},
	"meer_joris_karper_klaar": {
		"speaker": "Visser Joris",
		"lines": [
			"De Gouden Karper! Hij glimt! Hij kijkt me aan! Hij lacht! Ik wist het!",
			"Veertig jaar heb ik gewacht. Hier, hier, neem dit. Het is minder dan hij waard is, maar het is alles wat ik heb.",
		],
		"do": [
			["take", "meer_gouden_karper"], ["coins", 120], ["give", "fishers_cap"],
			["finish_quest", "meer_karper"], ["sound", "quest"],
		],
		"next": "meer_joris_karper_na",
	},
	"meer_joris_karper_na": {
		"speaker": "Visser Joris",
		"lines": [
			"Mijn Vissershoed. Ik draag hem al veertig jaar. Nu is hij van jou. Hij brengt geluk.",
			"En voor je vis betalen Mila en ik voortaan 10% extra. Dat heet respect.",
			"De Gouden Karper zet ik terug in het meer. Hij heeft het verdiend. Misschien lacht hij nog eens naar je.",
		],
	},

	# --- Lena de bibliothecaresse -----------------------------------------------------------
	"meer_lena_intro": {
		"speaker": "Lena",
		"lines": [
			"Welkom in de bibliotheek van het Zilvermeer. Ik ben Lena.",
			"Je mag alles lezen. Alleen niet met natte vingers. En niet hardop. En niet... ach, ik zie dat je het begrijpt.",
			"De lessenaars met een open boek erop zijn voor jou: loop erheen en druk op E. Elk boek vertelt een stukje van Azura.",
		],
		"do": [["set_flag", "meer_lena_ontmoet"]],
		"next": "meer_lena_menu",
	},
	"meer_lena_menu": {
		"speaker": "Lena",
		"lines": ["Kan ik je ergens mee helpen?"],
		"choices": [
			{"text": "Heb je werk voor me?", "if": [["quest", "meer_boeken", "none"]], "next": "meer_lena_vraag"},
			{"text": "Wat weet je over de Diepte?", "if": [["flag", "game_completed"]], "next": "meer_lena_diepte"},
			{"text": "Vertel eens iets over de boeken.", "next": "meer_lena_over"},
			{"text": "Nee, bedankt."},
		],
	},
	"meer_lena_over": {
		"speaker": "Lena",
		"lines": [
			"Alles wat de mensen van Azura ooit hebben opgeschreven, staat hier. Over de Blauwe Kaart, over de oude wachters, over slijmen.",
			"Sommige boeken zijn zo oud dat ze 'Azura' nog met een andere letter schrijven. Die laat ik liever niet los.",
			"Lees maar op de lessenaars. Daar staan de korte verhalen. De dikke boeken blijven in de kast. Die zijn zwaar.",
		],
		"next": "meer_lena_menu",
	},
	"meer_lena_diepte": {
		"speaker": "Lena",
		"lines": [
			"De Diepte? Ik hoopte al dat je dat ging vragen. Het staat in alle boeken, maar op geen enkele bladzijde die je kunt vinden.",
			"De Blauwe Kaart is een kopie. Het origineel, de Sterrenkaart, ligt ergens onder de Kristaltempel. Een oude Wachter bewaakt hem. Hij slaapt, maar hij slaapt licht.",
			"Nu de Slijmkoning weg is en de kaart weer heel is, gaat de weg naar beneden open. Neem veel drankjes mee. De Wachter waakt al eeuwen en vertrouwt niemand.",
		],
		"next": "meer_lena_menu",
	},
	"meer_lena_vraag": {
		"speaker": "Lena",
		"lines": [
			"Nu je het zegt... ja! Ik mis drie boeken. Ze zijn nooit teruggebracht.",
			"Eén heb ik uitgeleend aan iemand die naar het eiland in het meer ging. Hij kwam nooit terug. Het boek ook niet.",
			"Eén ligt vast in het huisje van Joris. Hij gebruikt het als onderzetter. Ik wil er niet over nadenken.",
			"En eentje heeft Sanne meegenomen. Ze vindt boeken zonder plaatjes saai, maar ze neemt ze wel mee. Kinderen!",
			"Wil je ze voor me zoeken? Dan krijg je een beloning. En iets bijzonders, achterin.",
		],
		"choices": [
			{"text": "Ik zoek ze wel!", "do": [["start_quest", "meer_boeken"]], "next": "meer_lena_ok"},
			{"text": "Misschien later."},
		],
	},
	"meer_lena_ok": {
		"speaker": "Lena",
		"lines": ["Wat fijn! Eén op het eiland, één in het huisje van Joris en één bij Sanne. Je kunt ze niet missen. Nou ja, wel. Maar ze zijn er."],
		"do": [["sound", "quest"]],
	},
	"meer_lena_voortgang": {
		"speaker": "Lena",
		"lines": ["Hoe gaat het met mijn boeken? Eén ligt op het eiland, één in het huisje van Joris en één is bij Sanne."],
		"branch": [
			{"if": [["meer_boeken", 2]], "next": "meer_lena_voortgang_2"},
			{"if": [["meer_boeken", 1]], "next": "meer_lena_voortgang_1"},
			{"next": "meer_lena_voortgang_0"},
		],
	},
	"meer_lena_voortgang_0": {"speaker": "Lena", "lines": ["Nog niets gevonden? Geen haast hoor. Boeken lopen niet weg. Nou ja, deze wel."]},
	"meer_lena_voortgang_1": {"speaker": "Lena", "lines": ["Eén boek al! Dan zijn het er nog twee. Je bent een echte boekenzoeker."]},
	"meer_lena_voortgang_2": {"speaker": "Lena", "lines": ["Twee boeken al! Nog eentje. Ik hoor de kasten al juichen."]},
	"meer_lena_boeken_terug": {
		"speaker": "Lena",
		"lines": [
			"Jij hebt ze! Alle drie! Laat eens kijken...",
			"'Sagen van het Zilvermeer', nog droog. 'Het Grote Vissenboek', met een koffiekring. En 'Sterren boven Azura'... met kleurpotloodvlekken.",
			"Het is perfect. Ik zet ze meteen terug. Hier is je beloning: tachtig munten.",
		],
		"do": [
			["take", "meer_boek_eiland"], ["take", "meer_boek_hut"], ["take", "meer_boek_sanne"],
			["coins", 80], ["finish_quest", "meer_boeken"], ["sound", "quest"],
		],
		"next": "meer_lena_achterkamer",
	},
	"meer_lena_achterkamer": {
		"speaker": "Lena",
		"lines": [
			"En nu iets bijzonders. Achter de kast aan de rechterkant van de zaal zit een geheim kamertje. Alleen leden mogen erin.",
			"Vanaf nu ben jij lid. Kijk maar eens goed naar de rechterwand...",
			"Hoor je dat? De kast schuift opzij. Hij klemde al jaren. Achterin ligt het laatste boek van de oude bibliothecarissen, en een klein cadeautje.",
		],
		"do": [["set_flag", "meer_achterkamer"]],
	},
	"meer_lena_klaar": {
		"speaker": "Lena",
		"lines": ["Mijn favoriete lezer! Het achterkamertje staat altijd voor je open. Lees vooral alles. Lessenaars bijten niet."],
		"branch": [
			{"if": [["meer_gelezen", 6]], "next": "meer_lena_alles_gelezen"},
			{"next": "meer_lena_menu"},
		],
	},
	"meer_lena_alles_gelezen": {
		"speaker": "Lena",
		"lines": [
			"Wacht eens... heb je álle lessenaars gelezen? Zelfs die in het geheime kamertje?",
			"Ik heb nog nooit zo'n goede lezer ontmoet. Jij weet nu meer over Azura dan Oudste Bram. Zeg dat maar niet tegen hem.",
		],
		"next": "meer_lena_menu",
	},

	# --- Sanne ----------------------------------------------------------------------------------
	"meer_sanne_intro": {
		"speaker": "Sanne",
		"lines": [
			"Sssst! Je maakt de vissen bang!",
			"Oh, sorry. Ik ben Sanne. Ik ben acht. En driekwart.",
			"Ik probeer al de hele dag een vis te vangen. Maar ik vang alleen laarzen. Kijk, ik heb er maar één aan. De andere is... ergens.",
		],
		"do": [["set_flag", "meer_sanne_ontmoet"]],
		"next": "meer_sanne_menu",
	},
	"meer_sanne_menu": {
		"speaker": "Sanne",
		"lines": ["Als jij een echte vis voor me hebt, geef ik je mijn schat. Het is een boek. Ik vind het saai, er staan geen plaatjes in."],
		"choices": [
			{"text": "Hier, een baars voor jou!", "if": [["has", "meer_baars", 1]], "do": [["take", "meer_baars"]], "next": "meer_sanne_boek"},
			{"text": "Hier, een snoek voor jou!", "if": [["has", "meer_snoek", 1]], "do": [["take", "meer_snoek"]], "next": "meer_sanne_boek"},
			{"text": "Is dit jouw laars?", "if": [["has", "meer_laars", 1]], "do": [["take", "meer_laars"]], "next": "meer_sanne_laars"},
			{"text": "Ik kom terug met een vis."},
		],
	},
	"meer_sanne_boek": {
		"speaker": "Sanne",
		"lines": [
			"Een echte vis! Hij is zo glad! En hij kijkt boos! Dankjewel!",
			"Hier is mijn schat. Hij zat in mijn tas, maar er past niks meer in. Veel plezier ermee.",
		],
		"do": [["give", "meer_boek_sanne"], ["set_flag", "meer_sanne_boek"], ["sound", "quest"]],
	},
	"meer_sanne_laars": {
		"speaker": "Sanne",
		"lines": [
			"MIJN LAARS! Ik zocht hem al een week! Hij stinkt precies zoals ik me herinner!",
			"Je bent de beste. Hier, neem mijn schat maar. Ik moet nu eerst mijn laars aantrekken.",
		],
		"do": [["give", "meer_boek_sanne"], ["set_flag", "meer_sanne_boek"], ["sound", "quest"]],
	},
	"meer_sanne_klaar": {
		"speaker": "Sanne",
		"lines": [
			"Bedankt voor je hulp! Ik ga nu nog meer vangen. Ik wil de Gouden Karper. Joris heeft een tekening van hem.",
			"Maar eerst moet ik stil zijn. Sssst.",
		],
	},

	# --- Mila koopt vis (een extra keuze in het gesprek in de herberg, zie mila_menu in dialogue.gd) ---------
	"meer_mila_vis": {
		"speaker": "Mila",
		"lines": ["Verse vis! Daar maak ik soep van. Laat maar zien..."],
		"do": [["meer_verkoop"]],
		"branch": [
			{"if": [["meer_vol"]], "next": "meer_mila_vol"},
			{"next": "meer_mila_klaar"},
		],
	},
	"meer_mila_klaar": {
		"speaker": "Mila",
		"lines": ["Mmm, dit wordt de beste soep van het dorp. Dank je wel!"],
	},
	"meer_mila_vol": {
		"speaker": "Mila",
		"lines": ["Mmm, soep! Al zit het dorp wel vol met vis: ik kan niet meer dan de halve prijs betalen. Maar dank je wel!"],
	},
}


# --- Eigen voorwaarden en acties (zie content.gd): de werking staat in meer_logic.gd ----------------------------

static func check(cond: Array) -> bool:
	return load(LOGIC).call("check", cond)


static func run(action: Array) -> void:
	load(LOGIC).call("run", action)


static func format(token: String) -> String:
	return load(LOGIC).call("format", token)
