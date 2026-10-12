extends RefCounted
## De arena: rangen, rondes, beloningen, records en de regels eromheen.
##
## Alleen gegevens en regels. De golven zelf worden gespeeld door scripts/entities/arena_master.gd.
## Dit bestand wordt pas geladen als het nodig is (zie scripts/data/ext/arena.gd), dus het mag GameState en Sound gebruiken.
## Namen en titels hieronder zijn Nederlands; meldingen en tekens (title(), record_text()) komen vertaald terug.
## Laad het in een test dus ook pas als het spel draait: load("res://scripts/data/arena.gd").

const Ext := preload("res://scripts/data/ext/arena.gd")

## Per rang: naam, inschrijfgeld, beloning (de eerste keer; daarna de helft), trofee en titel.
## `rounds` is een lijst rondes; elke ronde is een lijst [soort vijand, aantal]. De soorten staan in enemies.gd.
## Een nieuwe vijand toevoegen? Zet hem gewoon in een ronde.
const RANKS := {
	"bronze": {
		"name": "Brons", "fee": 10, "reward": 50, "trophy": "arena_trophy_bronze", "title": "Arenastrijder",
		"color": Color(0.94, 0.62, 0.32),
		"rounds": [
			[["slime", 3], ["bat", 1]],
			[["slime", 3], ["slime_blue", 2]],
			[["slime_blue", 4], ["slime_red", 2], ["bat", 2]],
		],
	},
	"silver": {
		"name": "Zilver", "fee": 25, "reward": 150, "trophy": "arena_trophy_silver", "title": "Arenaridder",
		"color": Color(0.82, 0.88, 1.0),
		"rounds": [
			[["slime", 3], ["bat", 2]],
			[["slime_blue", 3], ["slime", 2]],
			[["skeleton", 2], ["slime", 3]],
			[["slime_red", 1], ["slime_blue", 3], ["slime_spitter", 1]], # de slijmspuwer uit het Fluisterbos
			[["skeleton", 2], ["slime_red", 1], ["slime_blue", 3], ["bat", 1]],
		],
	},
	"gold": {
		"name": "Goud", "fee": 50, "reward": 400, "trophy": "arena_trophy_gold", "title": "Arenakampioen",
		"color": Color(1.0, 0.85, 0.3),
		"rounds": [
			[["slime_blue", 3], ["bat", 3]],
			[["skeleton", 2], ["slime_blue", 3]],
			[["slime_red", 2], ["slime_blue", 3], ["bat", 2]],
			[["skeleton", 3], ["slime_red", 2], ["bat", 3]],
			[["slime_red", 3], ["skeleton", 1], ["mage", 1]], # een magiër uit de Vergeten Ruïne
			[["slime_red", 2], ["slime_blue", 3], ["skeleton", 2], ["bat", 3]],
			[["golem", 1]],
		],
	},
}

## De volgorde van de rangen: een rang gaat open als je de vorige hebt gehaald.
const ORDER := ["bronze", "silver", "gold"]

const ITEMS := Ext.ITEMS # de voorwerpen staan in de module
const SHEET := "items_arena" # de plaatjes van de trofeeën (zie ITEMS)
const HELM := "arena_helm"
const SIGNED_FLAG := "arena_signed_%s" # ingeschreven voor deze rang (nog niet begonnen)
const DONE_FLAG := "arena_%s_done" # de rang is gehaald
const QUEST := "arena_kampioen"

## Een toernooi loopt (de poorten van de arena zijn dicht). Wordt gezet door de arenameester op de kaart.
static var run_active := false
## Welke arenameester het toernooi speelt (zijn instance-id), zodat een oude die net wordt opgeruimd het niet stopzet.
static var run_owner := 0


static func is_run_active() -> bool:
	return run_active


# --- Wie mag de arena in, en welke rangen zijn er open ----------------------------------------------

## De arena is open voor wie Oudste Bram kent en minstens een ijzeren zwaard (schade 2) heeft.
static func is_open() -> bool:
	return GameState.quest_state("main") != "none" and GameState.damage() >= 2


static func unlocked(rank: String) -> bool:
	var index := ORDER.find(rank)
	if index < 0:
		return false
	return index == 0 or GameState.flag(DONE_FLAG % ORDER[index - 1])


static func is_done(rank: String) -> bool:
	return GameState.flag(DONE_FLAG % rank)


## Voor welke rang ben je ingeschreven? Leeg als je niet bent ingeschreven.
static func registered_rank() -> String:
	for rank: String in ORDER:
		if GameState.flag(SIGNED_FLAG % rank):
			return rank
	return ""


## Schrijft je in (of niet). Geeft terug of het gelukt is; bij een fout krijg je een melding.
static func register(rank: String) -> bool:
	if not RANKS.has(rank) or run_active:
		return false
	if registered_rank() != "":
		GameState.toast.emit(TranslationServer.translate("Je staat al ingeschreven. Loop maar naar de arenadeur!"))
		return false
	if not unlocked(rank):
		GameState.toast.emit(TranslationServer.translate("Die rang is nog niet open. Win eerst de vorige."))
		return false
	var fee: int = RANKS[rank]["fee"]
	if GameState.coins < fee:
		GameState.toast.emit(TranslationServer.translate("Je hebt niet genoeg munten (%d nodig).") % fee)
		Sound.play("error", -3.0)
		return false
	GameState.add_coins(-fee)
	GameState.set_flag(SIGNED_FLAG % rank)
	Sound.play("buy")
	GameState.toast.emit(TranslationServer.translate("Ingeschreven voor %s! Loop door de deur naar de arena.") % TranslationServer.translate(RANKS[rank]["name"]))
	return true


## Schrijft je weer uit en geeft het inschrijfgeld terug.
static func cancel() -> bool:
	var rank := registered_rank()
	if rank == "" or run_active:
		return false
	GameState.add_coins(int(RANKS[rank]["fee"]))
	GameState.set_flag(SIGNED_FLAG % rank, false)
	GameState.toast.emit(TranslationServer.translate("Je bent uitgeschreven. Je krijgt je munten terug."))
	return true


# --- Beloningen en records -----------------------------------------------------------------------------

@warning_ignore("integer_division")
static func reward_coins(rank: String, first_time: bool) -> int:
	var reward: int = RANKS[rank]["reward"]
	return reward if first_time else reward / 2


## Beste tijd in seconden (0 als je de rang nog niet hebt gehaald).
static func best(rank: String) -> float:
	return float(GameState.arena_records.get(rank, 0.0))


## Je titel in de arena (vertaald): die van de hoogste rang die je gehaald hebt.
static func title() -> String:
	for i in range(ORDER.size() - 1, -1, -1):
		if is_done(ORDER[i]):
			return TranslationServer.translate(RANKS[ORDER[i]]["title"])
	# Vertalers: je titel in de arena zolang je nog niets gewonnen hebt, midden in een zin: "Hé nieuwkomer!"
	return TranslationServer.translate("nieuwkomer")


@warning_ignore("integer_division")
static func format_time(seconds: float) -> String:
	var total := int(round(seconds))
	return "%d:%02d" % [total / 60, total % 60]


static func record_text(rank: String) -> String:
	# Vertalers: op het scorebord en bij Bruno, in plaats van een beste tijd
	return format_time(best(rank)) if best(rank) > 0.0 else TranslationServer.translate("nog niet gehaald")


## Deelt de beloning uit voor een gehaalde rang (munten, trofee, titel, record) en geeft terug wat er gebeurd is.
## Munten en records krijg je elke keer (de tweede keer de helft); trofee, helm en titel alleen de eerste keer.
static func complete(rank: String, seconds: float) -> Dictionary:
	var info: Dictionary = RANKS[rank]
	var first_time := not is_done(rank)
	var coins := reward_coins(rank, first_time)
	var old_best := best(rank)
	var new_record := old_best <= 0.0 or seconds < old_best
	GameState.add_coins(coins)
	if first_time:
		GameState.give(info["trophy"], 1, true)
		if rank == ORDER[ORDER.size() - 1]:
			GameState.give(HELM, 1, true)
		GameState.set_flag(DONE_FLAG % rank)
		GameState.set_flag("arena_first_%s" % rank)
		if rank == ORDER[ORDER.size() - 1]:
			GameState.finish_quest(QUEST)
	if new_record:
		GameState.arena_records[rank] = seconds
	GameState.set_flag("arena_fresh_%s" % rank)
	var reward := reward_text(rank, coins, first_time)
	GameState.toast.emit(reward)
	if first_time:
		GameState.toast.emit(TranslationServer.translate("Nieuwe titel: %s!") % TranslationServer.translate(info["title"]))
	if new_record and old_best > 0.0:
		GameState.toast.emit(TranslationServer.translate("Nieuw record: %s!") % format_time(seconds))
	return {"first_time": first_time, "coins": coins, "record": new_record, "reward": reward}


## De melding met de beloning (vertaald), als hele zin per rang: de munten, en de eerste keer ook de trofee (en bij
## de hoogste rang de Arenahelm).
static func reward_text(rank: String, coins: int, first_time: bool) -> String:
	if not first_time:
		return TranslationServer.translate_plural("Beloning: %d munt!", "Beloning: %d munten!", coins) % coins
	match rank:
		"bronze":
			return TranslationServer.translate_plural("Beloning: %d munt en een bronzen trofee!",
				"Beloning: %d munten en een bronzen trofee!", coins) % coins
		"silver":
			return TranslationServer.translate_plural("Beloning: %d munt en een zilveren trofee!",
				"Beloning: %d munten en een zilveren trofee!", coins) % coins
		"gold":
			return TranslationServer.translate_plural("Beloning: %d munt, een gouden trofee en de Arenahelm!",
				"Beloning: %d munten, een gouden trofee en de Arenahelm!", coins) % coins
	# Een rang die hier nog niet staat: de naam van de trofee als losse naam.
	return TranslationServer.translate_plural("Beloning: %d munt en een trofee: %s!", "Beloning: %d munten en een trofee: %s!",
		coins) % [coins, TranslationServer.translate(ITEMS[RANKS[rank]["trophy"]]["name"])]


# --- Tekens in gesprekken ----------------------------------------------------------------------------------

## De tekst voor een teken in gesprekken: arena_title of arena_best_<rang> (zie FORMATS in scripts/data/ext/arena.gd).
static func format(token: String) -> String:
	if token == "arena_title":
		return title()
	return record_text(token.trim_prefix("arena_best_"))
