extends RefCounted
## Alle prestaties. Een prestatie heeft een naam, een uitleg en voorwaarden (`if`, hetzelfde formaat als bij
## gesprekken: zie game_state.gd en scripts/data/ext/wereld.gd). Zodra alle voorwaarden kloppen is hij behaald.
##
##   name    naam van de prestatie
##   desc    uitleg voor de speler
##   if      voorwaarden (allemaal waar)
##   secret  (optioneel) naam en uitleg blijven verborgen tot hij behaald is
##
## Een uitbreiding voegt er eigen toe met een constante ACHIEVEMENTS in haar module (zie content.gd).
## Behaalde prestaties staan in de savegame en in user://meta.cfg, dus ze blijven na een nieuw spel.

const Content := preload("res://scripts/data/content.gd")

const BASE_ACHIEVEMENTS := {
	"first_blood": {
		"name": "Eerste klap", "desc": "Versla je eerste vijand.",
		"if": [["kills", 1]],
	},
	"slayer_50": {
		"name": "Slijmenjager", "desc": "Versla 50 vijanden.",
		"if": [["kills", 50]],
	},
	"slayer_200": {
		"name": "Schrik van Azura", "desc": "Versla 200 vijanden.",
		"if": [["kills", 200]],
	},
	"bestiary_all": {
		"name": "Beestenkenner", "desc": "Versla elke soort vijand uit het begin van het spel minstens één keer.",
		"if": [["kinds_killed", ["slime", "slime_blue", "slime_red", "slime_mini", "bat", "skeleton", "golem", "king"]]],
	},
	"hearts_all": {
		"name": "Hart van goud", "desc": "Vind alle hartcontainers.",
		"if": [["has", "heart_container", 2]],
	},
	"boots": {
		"name": "Snelle voeten", "desc": "Koop de snelle laarzen bij Tobias.",
		"if": [["has", "boots"]],
	},
	"crystal_bos": {
		"name": "Licht in het bos", "desc": "Vind het kaartkristal in het Fluisterbos.",
		"if": [["any", ["has", "crystal_bos"], ["flag", "gate_temple"]]],
	},
	"crystal_ruine": {
		"name": "Licht uit het verleden", "desc": "Vind het kaartkristal in de Vergeten Ruïne.",
		"if": [["any", ["has", "crystal_ruine"], ["flag", "gate_temple"]]],
	},
	"crystal_grot": {
		"name": "Echo van licht", "desc": "Vind het kaartkristal in de Echo-grot.",
		"if": [["any", ["has", "crystal_grot"], ["flag", "gate_temple"]]],
	},
	"golems": {
		"name": "Golemvechter", "desc": "Versla beide kristalgolems.",
		"if": [["flag", "golem_ruins"], ["flag", "golem_cave"]],
	},
	"king": {
		"name": "Einde van de Slijmkoning", "desc": "Versla de Slijmkoning in de Kristaltempel.",
		"if": [["flag", "boss_defeated"]],
	},
	"completed": {
		"name": "Held van Azura", "desc": "Speel het verhaal uit en herstel de Blauwe Kaart.",
		"if": [["flag", "game_completed"]],
	},
	"speedrun": {
		"name": "Bliksemheld", "desc": "Speel het spel uit in minder dan 60 minuten.",
		"if": [["finished_within", 3600]],
	},
	"flawless_boss": {
		"name": "Ongeraakbaar", "desc": "Versla de Slijmkoning zonder dat je in dat gevecht doodgaat.",
		"if": [["flag", "boss_defeated"], ["max_boss_deaths", 0]],
	},
	"talked_all": {
		"name": "Gezellig babbelen", "desc": "Praat met alle personages.",
		"if": [["talked_to_all", ["bram", "greta", "tobias", "mila", "pim", "hein", "anja", "joost", "wilfred", "muis_bos"]]],
	},
	"sidequests": {
		"name": "Vriend van het dorp", "desc": "Voltooi alle zij-opdrachten.",
		"if": [["quest", "kat", "done"], ["quest", "medaillon", "done"], ["quest", "drank", "done"]],
	},
	"potions_10": {
		"name": "Proost!", "desc": "Drink 10 helddrankjes.",
		"if": [["potions_drunk", 10]],
	},
	"rolls_50": {
		"name": "Rolmeester", "desc": "Rol 50 keer.",
		"if": [["rolls", 50]],
	},
	"fast_travel": {
		"name": "Wereldreiziger", "desc": "Reis snel naar een ontdekt blauw altaar via de kaart.",
		"if": [["flag", "wereld_snel_gereisd"]],
	},
	"chests_all": {
		"name": "Schatzoeker", "desc": "Open een kist in de herberg, het bos, de ruïne en de grot.",
		"if": [["chests_in", ["inn", "forest", "ruins", "cave"]]],
	},
	"slept": {
		"name": "Welterusten", "desc": "Slaap een nachtje in de herberg.",
		"if": [["flag", "wereld_geslapen"]],
		"secret": true,
	},
	"rich": {
		"name": "Goudkoorts", "desc": "Heb 150 munten tegelijk in je zak.",
		"if": [["coins", 150]],
		"secret": true,
	},
}

## Basis en uitbreidingen samen (zie content.gd).
static var ACHIEVEMENTS: Dictionary = Content.merged("ACHIEVEMENTS", BASE_ACHIEVEMENTS)


static func info(achievement_id: String) -> Dictionary:
	return ACHIEVEMENTS.get(achievement_id, {"name": achievement_id, "desc": "", "if": []})


## Hoeveel van de bekende prestaties zijn behaald (in `owned`: id -> true).
static func count_owned(owned: Dictionary) -> int:
	var total := 0
	for id: String in ACHIEVEMENTS:
		if owned.has(id):
			total += 1
	return total
