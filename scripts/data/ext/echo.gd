extends RefCounted
## Prismagrotten: een optionele zijroute met twee leesbare vijandpatronen en een proef.

const MAPS := {
	"prismamine": preload("res://scripts/maps/prismamine.gd"),
	"resonance": preload("res://scripts/maps/resonance.gd"),
}
const OBJECTS := {
	"echo_crystal": "res://scripts/entities/echo_crystal.gd",
	"echo_trial": "res://scripts/entities/echo_trial.gd",
}
const CONDITIONS := ["echo_ready"]

static func check(_condition: Array) -> bool:
	var state := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	return state.weapon in ["iron", "crystal", "star"]

const MAP_MARKERS := {
	"echo_trial": {"color": Color(0.5, 0.95, 1.0), "label": "Resonantieproef"},
}
const ENEMIES := {
	"crystal_beetle": {
		"name": "Kristalkever", "hp": 5, "damage": 1, "behavior": "echo_charge",
		"speed": 28.0, "chase_speed": 48.0, "sight": 250.0,
		"sheet": "crystal_beetle", "cell": 16, "scale": 2.0, "radius": 8.0, "shadow": 10.0,
		"drops": [["shard", 0.25, 1], ["coin", 1.0, 3]],
		"death_color": Color(0.3, 0.9, 0.95),
		"desc": "Zijn turquoise pantser licht op voor hij recht vooruit stormt. Stap opzij; na de botsing is hij even weerloos.",
	},
	"prism_moth": {
		"name": "Prismamot", "hp": 4, "damage": 1, "behavior": "echo_volley",
		"speed": 34.0, "chase_speed": 44.0, "sight": 260.0,
		"sheet": "prism_moth", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 9.0,
		"drops": [["shard", 0.25, 1], ["coin", 1.0, 2]],
		"death_color": Color(0.85, 0.55, 1.0),
		"desc": "Tekent drie lichtstralen voordat ze kristalvonken schiet. Zoek de ruimte ertussen of onderbreek haar met je zwaard.",
	},
}
const ACHIEVEMENTS := {
	"echo_master": {"name": "Meester van de resonantie", "desc": "Doorsta alle drie golven van de Resonantieproef.", "if": [["flag", "echo_trial_won"]]},
}
