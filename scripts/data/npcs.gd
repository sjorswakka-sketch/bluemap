extends RefCounted
## Alle personages. `rules` wordt van boven naar beneden bekeken: de eerste regel waarvan de
## voorwaarden (`if`) kloppen bepaalt welk gesprek (`talk`, zie dialogue.gd) je krijgt.
## `sheet` is het plaatje in assets/ (2 vakjes van 16x16: rustig en een beetje bewegen).

const NPCS := {
	"bram": {
		"name": "Oudste Bram", "sheet": "npc_bram",
		"rules": [
			{"if": [["quest", "main", "done"]], "talk": "bram_done"},
			{"if": [["step", "main", 2]], "talk": "bram_boss_wait"},
			{"if": [["step", "main", 1]], "talk": "bram_crystals"},
			{"if": [["quest", "main", "active"]], "talk": "bram_progress"},
			{"talk": "bram_intro"},
		],
	},
	"greta": {
		"name": "Greta de smid", "sheet": "npc_greta",
		"rules": [
			{"if": [["no_flag", "met_greta"]], "talk": "greta_intro"},
			{"if": [["quest", "main", "done"], ["no_flag", "heard_greta_done"]], "talk": "greta_done"},
			{"if": [["weapon", "crystal"]], "talk": "greta_max"},
			{"talk": "greta_menu"},
		],
	},
	"tobias": {
		"name": "Tobias de koopman", "sheet": "npc_tobias",
		"rules": [
			{"if": [["no_flag", "met_tobias"]], "talk": "tobias_intro"},
			{"if": [["quest", "main", "done"], ["no_flag", "heard_tobias_done"]], "talk": "tobias_done"},
			{"talk": "tobias_menu"},
		],
	},
	"mila": {
		"name": "Mila de herbergierster", "sheet": "npc_mila",
		"rules": [
			{"if": [["step", "drank", 1]], "talk": "mila_potion_done"},
			{"if": [["quest", "drank", "active"]], "talk": "mila_potion_progress"},
			{"if": [["no_flag", "met_mila"]], "talk": "mila_intro"},
			{"if": [["quest", "main", "done"], ["no_flag", "heard_mila_done"]], "talk": "mila_done"},
			{"talk": "mila_menu"},
		],
	},
	"pim": {
		"name": "Pim", "sheet": "npc_pim",
		"rules": [
			{"if": [["quest", "kat", "done"]], "talk": "pim_done"},
			{"if": [["step", "kat", 1]], "talk": "pim_cat_back"},
			{"if": [["quest", "kat", "active"]], "talk": "pim_progress"},
			{"talk": "pim_intro"},
		],
	},
	"hein": {
		"name": "Wachter Hein", "sheet": "npc_hein",
		"rules": [
			{"if": [["quest", "main", "done"]], "talk": "hein_done"},
			{"talk": "hein_talk"},
		],
	},
	"anja": {
		"name": "Anja", "sheet": "npc_anja",
		"rules": [
			{"if": [["quest", "main", "done"]], "talk": "anja_done"},
			{"talk": "anja_talk"},
		],
	},
	"joost": {
		"name": "Joost", "sheet": "npc_joost",
		"rules": [
			{"if": [["quest", "main", "done"]], "talk": "joost_done"},
			{"if": [["has", "ruin_key", 1]], "talk": "joost_key"},
			{"talk": "joost_talk"},
		],
	},
	"wilfred": {
		"name": "Wilfred", "sheet": "npc_wilfred", "ghost": true,
		"rules": [
			{"if": [["quest", "medaillon", "done"]], "talk": "wilfred_done"},
			{"if": [["step", "medaillon", 1]], "talk": "wilfred_return"},
			{"if": [["quest", "medaillon", "active"]], "talk": "wilfred_progress"},
			{"talk": "wilfred_intro"},
		],
	},
	"muis_bos": {
		"name": "Muis", "sheet": "npc_muis", "scale": 1.5,
		"rules": [{"talk": "muis_bos"}],
	},
	"muis_dorp": {
		"name": "Muis", "sheet": "npc_muis", "scale": 1.5,
		"rules": [{"talk": "muis_dorp"}],
	},
}


static func info(npc_id: String) -> Dictionary:
	return NPCS[npc_id]
