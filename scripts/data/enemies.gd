extends RefCounted
## Alle vijanden. Elke vijand heeft een `behavior` (zie scripts/entities/enemy.gd).
##
## sheet   = bestandsnaam in assets/ (zonder .png), cell = pixels per vakje, scale = vergroting
## drops   = lijst van [voorwerp, kans, aantal]; "coin" laat munten vallen
## desc    = (optioneel) de grappige beschrijving in het beestenboek (menu); ontbreekt hij, dan wordt er niets getoond
## radius  = botsing, size = hoe groot hij getekend wordt (voor schaduw en raken)

const Content := preload("res://scripts/data/content.gd")

const BASE_ENEMIES := {
	"slime": {
		"name": "Slijm", "hp": 3, "damage": 1, "behavior": "chase",
		"speed": 35.0, "chase_speed": 62.0, "sight": 120.0,
		"sheet": "slime", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 10.0,
		"drops": [["coin", 1.0, 1], ["gel", 0.4, 1], ["heart", 0.12, 1]],
		"desc": "Een vrolijk groen slijm. Hij wil alleen maar knuffelen, maar dat doet toch een beetje pijn.",
	},
	"slime_blue": {
		"name": "Blauw slijm", "hp": 5, "damage": 1, "behavior": "chase",
		"speed": 40.0, "chase_speed": 74.0, "sight": 140.0,
		"sheet": "slime_blue", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 10.0,
		"drops": [["coin", 1.0, 2], ["gel", 0.5, 1], ["heart", 0.12, 1]],
		"desc": "Een blauw slijm dat net iets sneller is. Hij ruikt naar regen en natte sokken.",
	},
	"slime_red": {
		"name": "Rood slijm", "hp": 7, "damage": 2, "behavior": "chase",
		"speed": 44.0, "chase_speed": 86.0, "sight": 150.0,
		"sheet": "slime_red", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 10.0,
		"drops": [["coin", 1.0, 2], ["gel", 0.55, 1], ["heart", 0.15, 1], ["potion", 0.06, 1]],
		"desc": "Een rood slijm met een slecht humeur. Hij slaat harder dan zijn zachte buik doet vermoeden.",
	},
	"slime_mini": {
		"name": "Minislijm", "hp": 1, "damage": 1, "behavior": "chase",
		"speed": 40.0, "chase_speed": 58.0, "sight": 400.0,
		"sheet": "slime", "cell": 16, "scale": 1.5, "radius": 5.0, "shadow": 7.0, "knockback": 300.0,
		"drops": [["heart", 0.3, 1]],
		"desc": "Een piepklein slijmpje uit de Slijmkoning. Ze komen nooit alleen en vallen om bij een kriebel.",
	},
	"bat": {
		"name": "Vleermuis", "hp": 2, "damage": 1, "behavior": "bat",
		"speed": 90.0, "chase_speed": 120.0, "sight": 170.0,
		"sheet": "bat", "cell": 16, "scale": 2.0, "radius": 6.0, "shadow": 7.0, "fly": true,
		"drops": [["coin", 0.8, 1], ["heart", 0.12, 1]],
		"desc": "Een vleermuis die dol is op duiken. Hij komt altijd net uit de hoek waar je niet keek.",
	},
	"skeleton": {
		"name": "Skelet", "hp": 5, "damage": 1, "behavior": "archer",
		"speed": 40.0, "chase_speed": 60.0, "sight": 190.0,
		"sheet": "skeleton", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 10.0,
		"drops": [["coin", 1.0, 2], ["potion", 0.12, 1], ["heart", 0.12, 1]],
		"desc": "Een skelet met een boog. Hij is al eeuwen dood, maar zijn mikken is nog prima.",
	},
	"golem": {
		"name": "Kristalgolem", "hp": 22, "damage": 1, "slam_damage": 2, "behavior": "golem", "boss": true,
		"speed": 26.0, "chase_speed": 36.0, "sight": 200.0,
		"sheet": "golem", "cell": 32, "scale": 2.0, "radius": 13.0, "shadow": 22.0, "knockback": 40.0,
		"drops": [["coin", 1.0, 8], ["shard", 1.0, 1], ["heart", 1.0, 1]],
		"desc": "Een reus van kristal en steen. Hij is traag, maar zijn klap voel je tot in je tenen.",
	},
	"king": {
		"name": "De Slijmkoning", "hp": 60, "damage": 1, "slam_damage": 2, "behavior": "king", "boss": true,
		"speed": 30.0, "chase_speed": 50.0, "sight": 400.0,
		"sheet": "king", "cell": 48, "scale": 2.0, "radius": 20.0, "shadow": 36.0,
		"start_inactive": true, "knockback": 0.0,
		"drops": [],
		"desc": "De baas van alle slijmen. Hij springt, spuugt slijm en vindt zichzelf erg belangrijk.",
	},
}


## Basis en uitbreidingen samen (zie content.gd).
static var ENEMIES: Dictionary = Content.merged("ENEMIES", BASE_ENEMIES)


static func info(kind: String) -> Dictionary:
	return ENEMIES[kind]
