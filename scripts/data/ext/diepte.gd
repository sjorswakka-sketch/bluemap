extends RefCounted
## De Diepte: inhoud na het einde van het hoofdverhaal (vlag game_completed).
##
## Onder de Kristaltempel ligt een verzegelde trap. Zodra de Blauwe Kaart hersteld is, breekt het zegel en kun je naar
## de Kristalgangen (depths1) en Het Hart van de Kaart (depths2), waar De Vergeten Wachter slaapt: de oude bewaker van de
## Sterrenkaart. Wie hem verslaat krijgt het Sterrenzwaard. Zie ook scripts/entities/guardian.gd (de baas),
## scripts/maps/depths1.gd en depths2.gd, en tools/art_x_diepte.py en tools/audio_x_diepte.py.
##
## Eigen soorten objecten op de kaart:
##   guardian      de baas (met zijn pilaren en de beloning); `pillars` = tegels van de pilaren, `chest` = tegel van de kist
##   diepte_seal   het zegel voor de trap in de tempel (breekt na het einde)
##   diepte_gate   de kristalpoort in de Kristalgangen (een poort met een eigen uiterlijk)
##   diepte_lamp   een zwevend kristal dat licht geeft

const TALKS := {
	# Oudste Bram wijst je na het einde de weg (een trigger in het dorp, zie scripts/maps/village.gd).
	"diepte_bram_hint": {
		"speaker": "Oudste Bram",
		"lines": [
			"Held! Wacht even, voor je gaat rusten.",
			"Sinds de Blauwe Kaart weer heel is, hoor ik een zacht gerommel onder de tempel.",
			"Mijn oma vertelde over een oude bewaker die diep onder de grond slaapt: De Vergeten Wachter.",
			"Hij bewaakt de Sterrenkaart. Dat is de allereerste kaart. Onze Blauwe Kaart is daar maar een kopie van.",
			"Kijk achter in de tempel, waar de Slijmkoning stond. Daar zit een oud zegel in de muur. Pas goed op!",
		],
		"do": [["start_quest", "diepte"], ["sound", "quest"]],
	},
	# Greta ziet het Sterrenzwaard (haar eerste regels in scripts/data/npcs.gd). Smeden hoeft dan niet meer.
	"greta_star": {
		"speaker": "Greta",
		"lines": [
			"Wacht eens even... Is dat... het STERRENZWAARD?!",
			"Ik ken het alleen uit de oude verhalen van mijn opa. Het is niet van ijzer gemaakt, maar van sterrenlicht!",
			"Daar kan zelfs ik niets meer aan verbeteren. Pas er goed op, held!",
		],
		"do": [["set_flag", "met_greta"], ["set_flag", "greta_star_seen"]],
	},
	"greta_star_again": {
		"speaker": "Greta",
		"lines": ["Mag ik het Sterrenzwaard nog één keertje vasthouden? ... Prachtig. Ga maar, held, de wereld wacht!"],
	},
	"guardian_intro": {
		"speaker": "De Vergeten Wachter",
		"lines": [
			"...",
			"Wie... wekt... mij?",
			"Ik ben de Wachter van de Sterrenkaart. Al meer dan duizend jaar waak ik hier.",
			"De Blauwe Kaart was maar een kopie. En toch hebben jullie hem aangeraakt!",
			"Alleen wie sterker is dan de Wachter, mag de Sterrenkaart zien. Laat maar zien wat je kunt!",
		],
	},
	"guardian_defeat": {
		"speaker": "De Vergeten Wachter",
		"lines": [
			"Je bent sterk. En slim. Je rolde door mijn scherven alsof het niets was.",
			"Meer dan duizend jaar heb ik gewaakt. Nu mag ik eindelijk rusten.",
			"Het Sterrenzwaard is nu van jou. Het is gemaakt van het licht van de Sterrenkaart. Gebruik het goed, held van Azura.",
			"En kijk omhoog... Dit is wat ik al die tijd heb bewaakt.",
		],
		"next": "guardian_defeat2",
	},
	"guardian_defeat2": {
		"speaker": "",
		"lines": [
			"Boven je hoofd gaan duizenden kleine lichtjes aan. Ze vormen samen een kaart van heel Azura: de Sterrenkaart!",
			"Het Sterrenzwaard gloeit in je hand. Het is zo licht als een veertje en zo scherp als een sterrenstraal.",
			"Greta de smid gaat hier zeker van opkijken! Laat het haar maar eens zien in de smederij.",
		],
	},
}

const QUESTS := {
	"diepte": {
		"title": "De Vergeten Wachter",
		"steps": [
			{
				"text": "Het rommelt onder de Kristaltempel. Zoek achterin de tempel naar een weg naar beneden.",
				"advance_if": [["flag", "diepte_opened"]],
			},
			{
				"text": "Het zegel is gebroken! Zoek in de Kristalgangen een sleutel voor de kristalpoort.",
				"advance_if": [["flag", "gate_depths"]],
			},
			{
				"text": "De poort is open. Neem de trap naar Het Hart van de Kaart. Neem genoeg drankjes mee!",
				"advance_if": [["flag", "guardian_started"]],
			},
			{
				"text": "Versla De Vergeten Wachter! Rol door zijn scherven en sla toe na zijn aanval. Laat hem tegen een pilaar knallen: dan is hij even duizelig!",
			},
		],
	},
}

const ITEMS := {
	"sword_star": {
		"name": "Sterrenzwaard", "icon": 0, "sheet": "items_diepte", "type": "weapon",
		"desc": "Het legendarische zwaard van de Sterrenkaart. Het schijnt als een ster en raakt harder dan alle andere zwaarden.",
	},
	"diepte_key": {
		"name": "Kristalsleutel", "icon": 1, "sheet": "items_diepte", "type": "key",
		"desc": "Een sleutel van gloeiend kristal. Hij past op de kristalpoort in de Diepte.",
	},
}

## Het sterkste zwaard: schade 4 en het grootste bereik. `sparkle` laat het sterretjes strooien (player.gd).
const WEAPONS := {
	"star": {
		"name": "Sterrenzwaard", "item": "sword_star", "damage": 4, "reach": 48.0,
		"color": Color(0.82, 0.92, 1.0), "sparkle": true,
	},
}

## De paarse kristalgolem bewaakt de sleutel in de Kristalgangen. De Vergeten Wachter wordt niet door enemy.gd
## bestuurd maar door scripts/entities/guardian.gd (object "guardian"); deze gegevens zijn zijn levens, schade en plaatje.
const ENEMIES := {
	"diepte_golem": {
		"name": "Paarse kristalgolem", "hp": 26, "damage": 1, "slam_damage": 2, "behavior": "golem", "boss": true,
		"speed": 26.0, "chase_speed": 40.0, "sight": 200.0,
		"sheet": "golem_void", "cell": 32, "scale": 2.0, "radius": 13.0, "shadow": 22.0, "knockback": 40.0,
		"drops": [["coin", 1.0, 10], ["shard", 1.0, 1], ["heart", 1.0, 1]],
	},
	"guardian": {
		"name": "De Vergeten Wachter", "hp": 110, "damage": 1, "slam_damage": 2, "behavior": "guardian", "boss": true,
		"speed": 40.0, "chase_speed": 48.0, "sight": 600.0,
		"sheet": "guardian", "cell": 48, "scale": 2.0, "radius": 20.0, "shadow": 36.0,
		"start_inactive": true, "knockback": 0.0,
		"drops": [],
	},
}

const MAPS := {
	"depths1": preload("res://scripts/maps/depths1.gd"),
	"depths2": preload("res://scripts/maps/depths2.gd"),
}

const SOUNDS := [
	"guardian_roar", "guardian_charge", "pillar_charge", "shard_burst", "phase_shift", "seal_break", "star_fanfare",
	"guardian_die",
]
const TRACKS := ["depths", "guardian"]

## Paden (tekst), geen preload(): deze scripts gebruiken GameState en worden pas geladen als de wereld ze nodig heeft.
const OBJECTS := {
	"guardian": "res://scripts/entities/guardian.gd",
	"diepte_seal": "res://scripts/entities/diepte_seal.gd",
	"diepte_gate": "res://scripts/entities/diepte_gate.gd",
	"diepte_lamp": "res://scripts/entities/diepte_lamp.gd",
}
