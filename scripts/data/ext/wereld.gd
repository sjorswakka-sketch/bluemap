extends RefCounted
## Uitbreiding "wereld": dag en nacht, weer, slapen in de herberg, snel reizen, prestaties en het beestenboek.
## De rest van deze uitbreiding staat in scripts/core/daynight.gd, scripts/core/fast_travel.gd,
## scripts/data/achievements.gd en scripts/entities/ (atmosphere, rain, bed, lantern...). Zie content.gd.
##
## Nieuwe sleutels in kaartgegevens (scripts/maps/*.gd):
##   "outdoor": true             de kaart volgt dag en nacht (kleur, lantaarns, ramen)
##   "weather": "rain"           het regent altijd;  "random": het weer wisselt met de klok
##   {"type": "wereld_bed"}      een bed waarin je kunt slapen (staat op de bed-tegel)
##   {"type": "wereld_lantaarn"} een lantaarnpaal die 's nachts brandt
##   {"type": "savepoint", "spawn": "naam"}  waar je aankomt als je snel naar dit altaar reist
## Nieuwe voorwaarden voor gesprekken, poortjes en prestaties staan hieronder bij CONDITIONS.

const Daynight := preload("res://scripts/core/daynight.gd")

const TALKS := {
	"wereld_bed_info": {
		"speaker": "Mila",
		"lines": [
			"Slapen? Natuurlijk! De bedden staan daar links.",
			"Een nachtje kost 5 munten. Je wordt helemaal beter, en als je wakker wordt is het ochtend.",
		],
		"next": "wereld_bed",
	},
	"wereld_bed": {
		"speaker": "Bed",
		"branch": [
			{"if": [["coins", 5]], "next": "wereld_bed_menu"},
			{"next": "wereld_bed_poor"},
		],
	},
	"wereld_bed_menu": {
		"speaker": "Bed",
		"lines": ["Een zacht bed met een blauwe deken. Een nachtje slapen kost 5 munten."],
		"choices": [
			{"text": "Slapen (5 munten)", "do": [["wereld_sleep"]]},
			{"text": "Nog even niet."},
		],
	},
	"wereld_bed_poor": {
		"speaker": "Bed",
		"lines": ["Een zacht bed met een blauwe deken. Een nachtje slapen kost 5 munten, en zoveel heb je nu niet."],
	},
}

## Geluiden (tools/audio_x_wereld.py): regen is een lus, de rest zijn korte effecten.
const SOUNDS := ["wereld_regen", "wereld_slapen", "wereld_prestatie", "wereld_reis", "wereld_altaar"]

const OBJECTS := {
	"wereld_bed": "res://scripts/entities/bed.gd",
	"wereld_lantaarn": "res://scripts/entities/lantern.gd",
}

## Voorwaarden:
##   ["kills", n]                    minstens n vijanden verslagen
##   ["kills_of", soort, n]          minstens n vijanden van deze soort verslagen
##   ["kinds_killed", [soorten]]     van elke genoemde soort minstens één verslagen
##   ["rolls", n] ["potions_drunk", n]   minstens n keer gerold / drankjes gedronken
##   ["talked_to_all", [id's]]       met alle genoemde personages gepraat
##   ["max_deaths", n]               hooguit n keer doodgegaan (in dit spel)
##   ["max_boss_deaths", n]          hooguit n keer doodgegaan tegen de Slijmkoning
##   ["finished_within", seconden]   het spel is uitgespeeld in minder dan zoveel speeltijd
##   ["chests_in", [kaarten]]        in elk genoemd gebied is een kist geopend
##   ["any", voorwaarde, ...]        minstens één van de voorwaarden klopt
##   ["phase", "nacht"]              het is nu ochtend, dag, avond of nacht
const CONDITIONS := [
	"kills", "kills_of", "kinds_killed", "rolls", "potions_drunk", "talked_to_all", "max_deaths",
	"max_boss_deaths", "finished_within", "chests_in", "any", "phase",
]

## Acties:  ["wereld_sleep"]  slaap een nachtje in de herberg (kost munten, het wordt ochtend)
const ACTIONS := ["wereld_sleep"]


## GameState zelf kan hier niet bij naam gebruikt worden (dit script wordt geladen terwijl GameState nog start).
static func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


static func check(cond: Array) -> bool:
	var gs := _gs()
	match cond[0]:
		"kills":
			return gs.kills >= int(cond[1])
		"kills_of":
			return int(gs.kills_by.get(cond[1], 0)) >= int(cond[2])
		"kinds_killed":
			for kind: String in cond[1]:
				if int(gs.kills_by.get(kind, 0)) <= 0:
					return false
			return true
		"rolls":
			return gs.rolls >= int(cond[1])
		"potions_drunk":
			return gs.potions_drunk >= int(cond[1])
		"talked_to_all":
			for npc_id: String in cond[1]:
				if not gs.talked.has(npc_id):
					return false
			return true
		"max_deaths":
			return gs.deaths <= int(cond[1])
		"max_boss_deaths":
			return gs.boss_deaths <= int(cond[1])
		"finished_within":
			return gs.flag("game_completed") and gs.play_time <= float(cond[1])
		"chests_in":
			for map_id: String in cond[1]:
				if not _chest_opened_in(map_id):
					return false
			return true
		"any":
			for sub: Array in cond.slice(1):
				if gs.check(sub):
					return true
			return false
		"phase":
			return Daynight.phase_at(gs.day_time) == cond[1]
	return false


static func run(action: Array) -> void:
	if action[0] == "wereld_sleep":
		var world: Node = Engine.get_main_loop().get_first_node_in_group("world")
		if world != null:
			world.atmosphere.sleep_in_bed()


## Een kist die geopend is zet de vlag "chest:<kaart>:<nummer>" (zie world.gd en chest.gd).
static func _chest_opened_in(map_id: String) -> bool:
	var prefix := "chest:%s:" % map_id
	for flag_name: String in _gs().flags:
		if flag_name.begins_with(prefix):
			return true
	return false
