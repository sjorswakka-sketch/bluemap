extends RefCounted
## De werking van het Zilvermeer: voorwaarden en acties voor gesprekken, vis verkopen en de statistieken van het vissen.
## Gebruikt de autoloads (GameState, Sound) en wordt daarom pas geladen als het spel draait (zie meer.gd).

const Vis := preload("res://scripts/data/ext/meer_vis.gd")
const Boeken := preload("res://scripts/data/ext/meer_boeken.gd")

const BOOKS := ["meer_boek_eiland", "meer_boek_hut", "meer_boek_sanne"]


static func check(cond: Array) -> bool:
	match cond[0]:
		"meer_vis":
			return not sellable_fish().is_empty()
		"meer_vol":
			return sold_count() >= Vis.FULL_PRICE_FISH
		"meer_boeken":
			return books_found() >= int(cond[1])
		"meer_gelezen":
			return read_count() >= int(cond[1])
	return false


static func run(action: Array) -> void:
	if action[0] == "meer_verkoop":
		sell_fish()


## Vult {boeken} en {visgeld} in (zie FORMATS in meer.gd).
static func format(token: String) -> String:
	match token:
		"boeken":
			return str(books_found())
		"visgeld":
			return str(sale_value())
	return "{%s}" % token


# --- Vis verkopen en bijhouden -------------------------------------------------------------------------

## Hoeveel vissen het dorp van je gekocht heeft (bepaalt de prijs, zie meer_vis.gd).
static func sold_count() -> int:
	return int(GameState.meer.get("verkocht", 0))


## Diepe vangsten sinds de laatste Gouden Karper.
static func pity() -> int:
	return int(GameState.meer.get("pech", 0))


## Hoeveel van de lessenaars in de bibliotheek je al gelezen hebt.
static func read_count() -> int:
	var total := 0
	for book_id: String in Boeken.TEXTS:
		if GameState.flag(Boeken.flag_name(book_id)):
			total += 1
	return total


static func books_found() -> int:
	var total := 0
	for book: String in BOOKS:
		if GameState.count(book) > 0:
			total += 1
	return total


## De vissen in je tas die je kunt verkopen.
static func sellable_fish() -> Array[String]:
	var found: Array[String] = []
	for fish_id in Vis.fish_ids():
		if GameState.count(fish_id) > 0:
			found.append(fish_id)
	return found


## Wat deze vis nu oplevert (de volgende die je verkoopt).
static func price_now(fish_id: String) -> int:
	return Vis.price(fish_id, sold_count(), GameState.count("fishers_cap") > 0)


## Wat al je vis samen oplevert als je hem nu verkoopt (de duurste eerst, want die krijgen het eerst de volle prijs).
static func sale_value() -> int:
	var nth := sold_count()
	var has_cap := GameState.count("fishers_cap") > 0
	var coins := 0
	for fish_id in sellable_fish():
		for i in GameState.count(fish_id):
			coins += Vis.price(fish_id, nth, has_cap)
			nth += 1
	return coins


## Verkoopt al je vis en geeft het geld. Geeft het aantal munten terug.
static func sell_fish() -> int:
	var coins := sale_value()
	var amount := 0
	for fish_id in sellable_fish():
		amount += GameState.count(fish_id)
		GameState.take(fish_id, GameState.count(fish_id))
	if amount == 0:
		return 0
	GameState.add_coins(coins)
	GameState.meer["verkocht"] = sold_count() + amount
	Sound.play("buy")
	var fish := TranslationServer.translate_plural("%d vis", "%d vissen", amount) % amount
	var money := TranslationServer.translate_plural("%d munt", "%d munten", coins) % coins
	# Vertalers: bijvoorbeeld "Verkocht: 3 vissen voor 24 munten" (de eerste %s is "3 vissen", de tweede "24 munten")
	GameState.toast.emit(TranslationServer.translate("Verkocht: %s voor %s") % [fish, money])
	return coins


## Kan de Gouden Karper nog bijten? Alleen zolang Joris hem niet gezien heeft, en niet als je er al een in je tas hebt.
static func golden_can_bite() -> bool:
	return GameState.quest_state("meer_karper") != "done" and GameState.count(Vis.GOLDEN) == 0


## Onthoudt een vangst: voor de statistieken en voor de kans op de Gouden Karper.
static func record_catch(fish_id: String, deep: bool) -> void:
	GameState.meer["gevangen"] = int(GameState.meer.get("gevangen", 0)) + 1
	load("res://scripts/core/professions.gd").record_fish(fish_id)
	if deep:
		GameState.meer["pech"] = 0 if fish_id == Vis.GOLDEN else pity() + 1
