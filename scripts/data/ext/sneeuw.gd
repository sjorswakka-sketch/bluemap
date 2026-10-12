extends RefCounted
## Uitbreiding "sneeuw": IJsdal, een besneeuwd bergdorp ten noorden van het Dauwbos.
## Eigen klimaat (het sneeuwt er altijd), een bevroren meer, een mijnhoek met ijskristal,
## drie personages en twee opdrachten. De winterse grondstoffen staan in ext/beroepen.gd.

const MAPS := {
	"ijsdal": preload("res://scripts/maps/ijsdal.gd"),
}

const SOUNDS := ["step_snow"]

const QUESTS := {
	"warmte": {
		"title": "Warmte voor IJsdal",
		"steps": [
			{
				"text": "Fenna in IJsdal heeft 4 ijsbloemen nodig voor haar warme brouwsels. Ze bloeien in de sneeuw van het dal.",
				"advance_if": [["has", "prof_ijsbloem", 4]],
			},
			{"text": "Breng de ijsbloemen naar Fenna in IJsdal."},
		],
	},
	"ijswacht": {
		"title": "De Ijswacht",
		"steps": [
			{
				"text": "Roos de jageres houdt de paden van IJsdal veilig. Versla 4 ijsblauwe slijmen in het dal.",
				"advance_if": [["kills_of", "slime_blue", 4]],
			},
			{"text": "Vertel Roos dat de paden weer veilig zijn."},
		],
	},
}

const NPCS := {
	"fenna": {
		"name": "Fenna de kruidenvrouwe", "sheet": "npc_fenna",
		"rules": [
			{"if": [["step", "warmte", 1]], "talk": "fenna_klaar"},
			{"if": [["no_flag", "fenna_ontmoet"]], "talk": "fenna_intro"},
			{"talk": "fenna_menu"},
		],
	},
	"roos": {
		"name": "Roos de jageres", "sheet": "npc_roos",
		"rules": [
			{"if": [["step", "ijswacht", 1]], "talk": "roos_klaar"},
			{"if": [["no_flag", "roos_ontmoet"]], "talk": "roos_intro"},
			{"talk": "roos_menu"},
		],
	},
	"olav": {
		"name": "Olav de kaartenbewaarder", "sheet": "npc_olav",
		"rules": [
			{"if": [["no_flag", "olav_ontmoet"]], "talk": "olav_intro"},
			{"talk": "olav_menu"},
		],
	},
}

const TALKS := {
	"fenna_intro": {
		"speaker": "Fenna",
		"lines": ["Welkom in IJsdal, reiziger. Ik ben Fenna. Ik brouw warme drankjes van wat er in de sneeuw groeit.", "De ijsbloem is mijn beste ingrediënt, maar mijn voorraad is op."],
		"do": [["set_flag", "fenna_ontmoet"]],
		"next": "fenna_vraag",
	},
	"fenna_vraag": {
		"speaker": "Fenna",
		"lines": ["Wil je 4 ijsbloemen voor me plukken? Ze bloeien in het dal, zelfs onder de sneeuw."],
		"choices": [
			{"text": "Ik pluk ze wel.", "do": [["start_quest", "warmte"]], "next": "fenna_ok"},
			{"text": "Later misschien."},
		],
	},
	"fenna_ok": {"speaker": "Fenna", "lines": ["Dank je. Zoek naar bleke bloempjes in de sneeuw, bij het bosje en het meer."], "do": [["sound", "quest"]]},
	"fenna_menu": {"speaker": "Fenna", "lines": ["Heb je de ijsbloemen al?"], "choices": [{"text": "Nog niet."}, {"text": "Tot zo."}]},
	"fenna_klaar": {
		"speaker": "Fenna",
		"lines": ["Prachtig! Hiermee brouw ik de hele winter. Hier, mijn eerste vorstelixer is voor jou.", "En wat munten voor je koude vingers."],
		"do": [["take", "prof_ijsbloem", 4], ["give", "prof_frost_tonic"], ["coins", 30], ["finish_quest", "warmte"], ["sound", "quest"]],
	},

	"roos_intro": {
		"speaker": "Roos",
		"lines": ["Stil maar. Ik ben Roos, jageres van IJsdal. Ik houd de paden vrij van slijmen.", "De ijsblauwe slijmen worden brutaal deze winter. Ze verschuilen zich tussen de rotsen."],
		"do": [["set_flag", "roos_ontmoet"]],
		"next": "roos_vraag",
	},
	"roos_vraag": {
		"speaker": "Roos",
		"lines": ["Wil je de ijswacht helpen? Versla 4 ijsblauwe slijmen in het dal."],
		"choices": [
			{"text": "Ik regel het.", "do": [["start_quest", "ijswacht"]], "next": "roos_ok"},
			{"text": "Niet nu."},
		],
	},
	"roos_ok": {"speaker": "Roos", "lines": ["Goed. Ze zitten bij de mijnhoek en het westelijke bosje. Kijk uit voor het gladde ijs."], "do": [["sound", "quest"]]},
	"roos_menu": {"speaker": "Roos", "lines": ["Zijn de paden al veilig?"], "choices": [{"text": "Nog niet."}, {"text": "Tot later."}]},
	"roos_klaar": {
		"speaker": "Roos",
		"lines": ["Vier stuks? Netjes. Het dal ademt weer.", "Hier, een warme wintergloed en wat munten. De ijswacht vergeet dit niet."],
		"do": [["give", "prof_winter_gloed"], ["coins", 40], ["finish_quest", "ijswacht"], ["sound", "quest"]],
	},

	"olav_intro": {
		"speaker": "Olav",
		"lines": ["Ah, een nieuw gezicht bij het altaar. Ik ben Olav. Ik bewaar de kaarten van het noorden.", "IJsdal staat op geen enkele oude kaart. Wij vonden het toen de sneeuw ons hier dreef."],
		"do": [["set_flag", "olav_ontmoet"]],
		"next": "olav_menu",
	},
	"olav_menu": {
		"speaker": "Olav",
		"lines": ["Wat wil je weten van het noorden?"],
		"choices": [
			{"text": "Over IJsdal.", "next": "olav_dorp"},
			{"text": "Over het altaar.", "next": "olav_altaar"},
			{"text": "Over het ijskristal.", "next": "olav_kristal"},
			{"text": "Een ander keer."},
		],
	},
	"olav_dorp": {"speaker": "Olav", "lines": ["IJsdal leeft van de mijn en de kruiden. De sneeuw geeft en de sneeuw neemt.", "Het meer is dichtgevroren. De vissen slapen eronder tot de lente, zeggen ze."], "next": "olav_menu"},
	"olav_altaar": {"speaker": "Olav", "lines": ["Het blauwe altaar hier is ouder dan het dorp. Raak het aan en je reist ermee naar elk altaar dat je kent.", "Handig, als je ten zuiden weer groen gras wilt zien."], "next": "olav_menu"},
	"olav_kristal": {"speaker": "Olav", "lines": ["In de mijnhoek groeit ijskristal: koud, helder en harder dan koper.", "Je hebt er een koperen pikhouweel en wat mijnservaring voor nodig. Alchemisten betalen goed."], "next": "olav_menu"},
}

const ACHIEVEMENTS := {
	"ijsdal_ontdekt": {
		"name": "Sneeuwvoeten", "desc": "Ontdek IJsdal en praat met Fenna, Roos en Olav.",
		"if": [["talked_to_all", ["fenna", "roos", "olav"]]],
	},
}
