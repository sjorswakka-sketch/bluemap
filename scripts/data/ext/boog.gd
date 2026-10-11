extends RefCounted
## Uitbreiding "boog": een tweede wapen met pijlen, doelwit-puzzels en Tessa's schietbaan.
##
## De boog koop je bij Tobias (zie shops.gd), je schiet met F (scripts/entities/player.gd) en een pijl is een
## eigen object (scripts/entities/arrow.gd). Doelwitten (target.gd) zetten een vlag als je ze raakt; poortjes
## openen daarmee via `block_if`. De schietbaan (shooting_range.gd) houdt de tijd bij.
##
## Eigen voorwaarde:  ["boog_missing", "vlag1", "vlag2"]  klopt zolang er nog een van die vlaggen ontbreekt
##                    (voor een poortje dat pas opengaat als alle doelwitten geraakt zijn).
## Eigen acties:      ["boog_range_start"]  begint een poging op de schietbaan van deze kaart
##                    ["boog_progress", "vlag1", "vlag2"]  meldt hoeveel van die doelwitten al geraakt zijn

const ITEMS := {
	"bow": {
		"name": "Boog", "sheet": "items_boog", "icon": 0, "type": "gear",
		"desc": "Druk op F om een pijl te schieten. Een pijl doet 2 schade (bij bazen 1) en vliegt over water. Je krijgt er 5 pijlen bij, meer pijlen koop je apart.",
	},
	"arrow": {
		"name": "Pijl", "sheet": "items_boog", "icon": 1, "type": "ammo", "max": 40,
		"full_text": "Je pijlenkoker is vol",
		"almost_full_text": "Je pijlenkoker zit bijna vol", # de winkel zet er "(38 van de 40)" achter
		"chest_full_text": "Er zitten pijlen in deze kist, maar ze passen niet meer in je pijlenkoker. Schiet er eerst een paar af!",
		"desc": "Pijlen voor je boog. Er passen er 40 in je pijlenkoker. Skeletten laten er soms een paar vallen.",
	},
}

const SOUNDS := ["boog_twang", "boog_target", "boog_kets"]

const OBJECTS := {
	"boog_target": "res://scripts/entities/target.gd",
	"boog_baan": "res://scripts/entities/shooting_range.gd",
}

const CONDITIONS := ["boog_missing"]
const ACTIONS := ["boog_range_start", "boog_progress"]

const NPCS := {
	"tessa": {
		"name": "Tessa de boogschutter", "sheet": "npc_tessa",
		"rules": [
			{"if": [["lacks", "bow"]], "talk": "tessa_nobow"},
			{"if": [["step", "boog_schietbaan", 1]], "talk": "tessa_reward"},
			{"if": [["quest", "boog_schietbaan", "done"]], "talk": "tessa_done"},
			{"if": [["quest", "boog_schietbaan", "active"]], "talk": "tessa_active"},
			{"talk": "tessa_intro"},
		],
	},
}

const QUESTS := {
	"boog_schietbaan": {
		"title": "Schietbaan",
		"steps": [
			{
				"text": "Raak alle drie de doelwitten op Tessa's schietbaan binnen 20 seconden. Praat met Tessa voor een poging.",
				"advance_if": [["flag", "boog_range_won"]],
			},
			{"text": "Gehaald! Ga naar Tessa voor je beloning."},
		],
	},
}

const TALKS := {
	"tessa_nobow": {
		"speaker": "Tessa",
		"lines": [
			"Hoi! Ik ben Tessa. Dit is mijn schietbaan.",
			"Zonder boog kun je hier niets doen, hoor. Tobias verkoopt ze in zijn winkel.",
			"Kom terug als je er een hebt. Dan leer ik je schieten!",
		],
	},
	"tessa_intro": {
		"speaker": "Tessa",
		"lines": [
			"Hé, een boog! Kom maar hier.",
			"Ik ben Tessa. Wachter Hein vindt het goed dat ik mijn schietbaan hier neerzet, vlak bij zijn post.",
			"Zie je die drie doelwitten? Raak ze alle drie binnen 20 seconden, dan krijg je een beloning.",
		],
		"next": "tessa_menu",
	},
	"tessa_menu": {
		"speaker": "Tessa",
		"lines": ["Zullen we schieten?"],
		"choices": [
			{
				"text": "Ik doe mee!", "if": [["quest", "boog_schietbaan", "none"]],
				"do": [["start_quest", "boog_schietbaan"], ["boog_range_start"]], "next": "tessa_go",
			},
			{
				"text": "Nog een poging!", "if": [["quest", "boog_schietbaan", "active"]],
				"do": [["boog_range_start"]], "next": "tessa_go",
			},
			{
				"text": "Oefenen, zonder beloning", "if": [["quest", "boog_schietbaan", "done"]],
				"do": [["boog_range_start"]], "next": "tessa_go",
			},
			{"text": "Hoe schiet ik?", "next": "tessa_howto"},
			{"text": "Straks misschien."},
		],
	},
	"tessa_go": {
		"speaker": "Tessa",
		"lines": [
			"Ga op de planken van de schietlijn staan. Van daar zie je alle drie de doelwitten.",
			"Ik tel af: 3, 2, 1... Bij \"Af!\" begint de tijd.",
			"Tijdens een poging schiet je met mijn pijlen. Dat kost jou dus niks. Succes!",
		],
	},
	"tessa_howto": {
		"speaker": "Tessa",
		"lines": [
			"Druk op F om een pijl te schieten. Je schiet de kant op waarin je kijkt.",
			"Loop je schuin? Dan vliegt je pijl ook schuin. Muren stoppen een pijl, maar over water vliegt hij gewoon heen.",
			"Elk schot kost een pijl uit je pijlenkoker. Je kunt er 40 dragen. Hier op mijn baan leen je mijn pijlen.",
		],
		"next": "tessa_menu",
	},
	"tessa_active": {
		"speaker": "Tessa",
		"lines": ["Het is je nog niet gelukt, hè? Geen zorgen. Iedereen mist wel eens."],
		"next": "tessa_menu",
	},
	"tessa_done": {
		"speaker": "Tessa",
		"lines": [
			"Daar is mijn beste schutter! De baan is altijd open.",
			"Een beloning krijg je maar één keer, maar oefenen mag zo vaak je wilt.",
		],
		"next": "tessa_menu",
	},
	"tessa_reward": {
		"speaker": "Tessa",
		"lines": ["Alle drie raak! En nog binnen de tijd ook!"],
		"branch": [
			# De beloning bevat 10 pijlen: die moeten wel in je pijlenkoker passen (max 40).
			{"if": [["has", "arrow", 31]], "next": "tessa_reward_full"},
			{"next": "tessa_reward_pay"},
		],
	},
	"tessa_reward_pay": {
		"speaker": "Tessa",
		"lines": ["Hier is je beloning: 25 munten en 10 pijlen. Goed geschoten!"],
		"do": [["coins", 25], ["give", "arrow", 10], ["finish_quest", "boog_schietbaan"], ["sound", "quest"]],
	},
	"tessa_reward_full": {
		"speaker": "Tessa",
		"lines": [
			"Maar je pijlenkoker zit bijna vol. Mijn beloning past er dan niet meer in!",
			"Schiet eerst een paar pijlen af en kom dan terug.",
		],
	},
}


## De autoload GameState. Een module wordt al geladen terwijl GameState zelf nog wordt opgebouwd (game_state.gd laadt
## content.gd), dus GameState bij naam gebruiken geeft een compileerfout. Via de scenetree kan het wel.
static func _state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


## De voorwaarden van deze uitbreiding (zie content.gd).
static func check(cond: Array) -> bool:
	if cond[0] == "boog_missing":
		for i in range(1, cond.size()):
			if not _state().flag(cond[i]):
				return true
	return false


## De acties van deze uitbreiding (zie content.gd).
static func run(action: Array) -> void:
	match action[0]:
		"boog_range_start":
			var range_node: Node = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("boog_range")
			if range_node:
				range_node.start_run()
		"boog_progress":
			var total := action.size() - 1
			var done := 0
			for i in range(1, action.size()):
				if _state().flag(action[i]):
					done += 1
			if done >= total:
				_state().toast.emit("Alle doelwitten geraakt!")
			else:
				_state().toast.emit("Doelwit geraakt! (%d van %d)" % [done, total])
