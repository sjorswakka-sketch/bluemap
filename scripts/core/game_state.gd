extends Node
## Autoload "GameState": alles wat bij je spel hoort en opgeslagen wordt (levens, voorwerpen,
## vlaggen, opdrachten), plus de regels voor dialoogvoorwaarden en -acties.

const Items := preload("res://scripts/data/items.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Content := preload("res://scripts/data/content.gd")
const Achievements := preload("res://scripts/data/achievements.gd")
const Daynight := preload("res://scripts/core/daynight.gd")
const Movement := preload("res://scripts/core/movement.gd")
const Professions := preload("res://scripts/core/professions.gd")
const Progression := preload("res://scripts/core/progression.gd")
const Equipment := preload("res://scripts/core/equipment.gd")
const CoastalHome := preload("res://scripts/core/coastal_home.gd")
const Appearance := preload("res://scripts/core/appearance.gd")

signal hp_changed
signal items_changed
signal quests_changed
signal progression_changed
signal equipment_changed
signal appearance_changed # haar, ogen of kleding veranderd (uiterlijk, puur visueel)
signal toast(text: String) # tekst die al vertaald is (zie scripts/core/lang.gd)
signal game_over
signal ending_requested
signal dialogue_requested(dialogue_id: String)
signal text_dialogue_requested(speaker: String, lines: Array) # al vertaald, zie say()
signal shop_requested(shop_id: String)
signal save_requested
signal world_action(action: Array)
signal achievement_unlocked(achievement_id: String)

const BASE_HP := 5
const BOOTS_SPEED_MULTIPLIER := 1.18
const SAVE_PATH := "user://savegame.json"
const META_PATH := "user://meta.cfg" # blijft bestaan als je een nieuw spel begint (prestaties)
const SAVE_VERSION := 1
const ACHIEVEMENT_INTERVAL := 2.0 # zo vaak (seconden) kijken we ook zonder aanleiding of er iets is behaald

var hp: int = BASE_HP
var coins: int = 0
var inventory: Dictionary = {}
var flags: Dictionary = {}
var quests: Dictionary = {}
var weapon: String = "wood"
var map_id: String = "village"
var spawn_name: String = "start"
var load_pos: Vector2 = Vector2.ZERO
var use_load_pos: bool = false
var play_time: float = 0.0
var kills: int = 0
var hero_xp: int = 0 # totale held-ervaring; levels worden hieruit berekend
var meer: Dictionary = {} # eigen opslag van het Zilvermeer (zie scripts/data/ext/meer.gd): verkochte en gevangen vis
var professions: Dictionary = {} # beroepenervaring en verzamelde grondstoffen (eigen stabiele sleutels)
var homestead: Dictionary = {}
var coastal_storage: Dictionary = {}
var equipment: Dictionary = {} # vak -> gekozen voorwerp; alleen geldig zolang je het bezit
var appearance: Dictionary = {} # geslacht, haar, ogen (zie scripts/core/appearance.gd); leeg = standaard
var clothing: Dictionary = {} # kledingvak -> {"item": id, "dye": kleurindex}; puur visueel, over de uitrusting heen
var movement := Movement.new() # stamina blijft bij gebiedsovergangen behouden

# Wereld: de klok, tellers voor prestaties en het beestenboek (worden opgeslagen).
var day_time: float = Daynight.START # 0..1, zie scripts/core/daynight.gd
var day_count: int = 0 # hoeveel dagen er voorbij zijn (bepaalt het weer)
var kills_by: Dictionary = {} # soort vijand -> aantal verslagen
var rolls: int = 0
var potions_drunk: int = 0
var deaths: int = 0
var boss_deaths: int = 0 # keren dat je doodging tijdens het gevecht met de Slijmkoning
var talked: Dictionary = {} # personage-id -> true
var achievements: Dictionary = {} # behaalde prestaties (id -> true), ook uit user://meta.cfg
var arena_records: Dictionary = {} # beste tijd (seconden) per arena-rang, bijvoorbeeld {"bronze": 95.2}

# Tijdelijke toestand (wordt niet opgeslagen).
var in_game: bool = false
var last_damage_source: String = "" # waardoor je het laatst geraakt bent (voor het game-over-scherm)
var damage_log: Dictionary = {} # voor de balansbot
var ended: bool = false
var transitioning: bool = false
var dialogue_open: bool = false
var ui_owners: Dictionary = {}
var meta_achievements: Dictionary = {} # alle prestaties ooit behaald, over alle spellen heen
var save_is_ours := false # hoort het opslagbestand bij dit spel? (bij "Nieuw spel" nog niet: dat is een oud spel)
var achievement_queue: Array[String] = [] # nog te tonen meldingen (het beeld pakt ze op zodra het er is)
var _achievements_dirty := false
var _achievement_timer := ACHIEVEMENT_INTERVAL
# Een uitbreiding (de arena) kan het verlies overnemen: geeft de handler true terug, dan is het geen game over.
var defeat_handler: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_meta()
	achievements = meta_achievements.duplicate()
	# Prestaties worden gecontroleerd zodra er iets verandert, en daarnaast op een rustig interval.
	items_changed.connect(_mark_achievements)
	quests_changed.connect(_mark_achievements)


func _process(delta: float) -> void:
	if in_game and not ended and not get_tree().paused:
		play_time += delta
		preload("res://scripts/core/homestead.gd").advance(delta)
		day_time += delta / Daynight.DAY_LENGTH
		if day_time >= 1.0:
			day_time = Daynight.wrap_time(day_time)
			day_count += 1
	if in_game:
		_achievement_timer -= delta
		if _achievements_dirty or _achievement_timer <= 0.0:
			check_achievements()


func _input(event: InputEvent) -> void:
	if Controls.capture_active or not Controls.allows_event(event):
		return
	if event.is_action_pressed("fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


# --- Nieuw spel en schermen die het spel stilzetten ----------------------------

func new_game() -> void:
	hp = BASE_HP
	coins = 0
	inventory = {}
	flags = {}
	flags["op_new_adventure"] = true
	quests = {}
	weapon = "wood"
	map_id = "village"
	spawn_name = "start"
	use_load_pos = false
	play_time = 0.0
	kills = 0
	hero_xp = 0
	meer = {}
	professions = {}
	homestead = {}
	preload("res://scripts/core/homestead.gd").reset()
	coastal_storage = {}
	equipment = {}
	appearance = Appearance.normalize_appearance({})
	clothing = {}
	movement.reset()
	day_time = Daynight.START
	day_count = 0
	kills_by = {}
	rolls = 0
	potions_drunk = 0
	deaths = 0
	boss_deaths = 0
	talked = {}
	achievements = meta_achievements.duplicate()
	achievement_queue = []
	save_is_ours = false
	arena_records = {}
	ended = false
	transitioning = false
	dialogue_open = false
	ui_owners = {}
	defeat_handler = Callable()
	last_damage_source = ""
	damage_log = {}
	ng_plus = 0
	_apply_pause()
	hp_changed.emit()
	items_changed.emit()
	quests_changed.emit()
	progression_changed.emit()
	equipment_changed.emit()
	appearance_changed.emit()


## Schermen (menu, winkel, dialoog, pauze) zetten het spel stil zolang ze open staan.
func set_ui(ui_name: String, open: bool) -> void:
	if open:
		ui_owners[ui_name] = true
	else:
		ui_owners.erase(ui_name)
	_apply_pause()


func _apply_pause() -> void:
	if get_tree():
		get_tree().paused = not ui_owners.is_empty()


func input_locked() -> bool:
	return ended or transitioning or not ui_owners.is_empty()


# --- Gezondheid ----------------------------------------------------------------

func max_hp() -> int:
	return BASE_HP + count("heart_container")


func hurt(amount: int = 1) -> void:
	if ended or amount <= 0:
		return
	hp = maxi(hp - damage_after_armor(amount), 0)
	hp_changed.emit()
	if hp == 0:
		if defeat_handler.is_valid() and defeat_handler.call():
			return # de arena handelt het verlies zelf af
		ended = true
		_record_death()
		game_over.emit()


func heal(amount: int = 1) -> void:
	hp = mini(hp + amount, max_hp())
	hp_changed.emit()


func full_heal() -> void:
	hp = max_hp()
	hp_changed.emit()

func full_rest() -> void:
	full_heal()
	movement.reset()


func damage() -> int:
	return Items.WEAPONS[weapon]["damage"]


func reach() -> float:
	return Items.WEAPONS[weapon]["reach"]


func speed_multiplier() -> float:
	return (BOOTS_SPEED_MULTIPLIER if count("boots") > 0 else 1.0) * (1.0 + Equipment.bonus("move_speed"))


func attack_cooldown_multiplier() -> float:
	return 1.0 - Equipment.bonus("attack_cooldown_reduction")


func damage_after_armor(amount: int) -> int:
	return maxi(amount - int(Equipment.bonus("armor")), 1) if amount > 0 else 0


# --- Wereld: tijd, tellers en prestaties ---------------------------------------------

## Een vijand is verslagen (voor het totaal, het beestenboek en de prestaties).
func register_kill(kind: String) -> void:
	kills += 1
	kills_by[kind] = int(kills_by.get(kind, 0)) + 1
	# De arena geeft rangbeloningen, geen buit of extra ervaringsmunten per vijand.
	if map_id != "arena":
		add_hero_xp(Progression.enemy_xp(kind))
	_mark_achievements()


## Alleen echte spelbeloningen lopen hierlangs. Laden en Nieuw spel+ zetten de XP
## rechtstreeks, zodat een bestaand level nooit opnieuw munten oplevert.
func add_hero_xp(amount: int) -> void:
	if amount <= 0:
		return
	var previous := Progression.normalize(hero_xp)
	var total := previous + mini(amount, Progression.MAX_XP - previous)
	if total == previous:
		return
	var old_level := Progression.level_for(previous)
	var new_level := Progression.level_for(total)
	hero_xp = total # vóór signalen vastleggen: een luisteraar kan geen beloning verdubbelen
	var reward := (new_level - old_level) * Progression.LEVEL_REWARD
	if reward > 0:
		add_coins(reward)
	progression_changed.emit()
	if reward > 0:
		# Vertalers: het bereikte heldenlevel en de totale muntbeloning (soms meerdere levels).
		toast.emit(tr("Heldenlevel %d! +%d munten voor je uitrusting.") % [new_level, reward])


func note_roll() -> void:
	rolls += 1
	_mark_achievements()


func note_talked(npc_id: String) -> void:
	if not talked.has(npc_id):
		talked[npc_id] = true
		_mark_achievements()


## Je wordt wakker in de ochtend van de volgende dag (of van vandaag, als het nog vroeg is).
func skip_to_morning() -> void:
	if day_time > Daynight.MORNING:
		day_count += 1
	day_time = Daynight.MORNING


## Telt een nederlaag, en zet die meteen in het opslagbestand. Anders zou herladen na je dood het weer wissen.
## Alleen als dat bestand bij dit spel hoort: een nederlaag in een nieuw spel verandert niets aan een oud spel.
func _record_death() -> void:
	deaths += 1
	if flag("boss_started") and not flag("boss_defeated"):
		boss_deaths += 1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)) if save_is_ours and has_save() else null
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = parsed
		data["deaths"] = deaths
		data["boss_deaths"] = boss_deaths
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(data))


## Een opslag van voor de wereld-uitbreiding kent het beestenboek en de praatjes nog niet. Wat we uit de vlaggen weten
## vullen we aan: golems en de Slijmkoning komen nooit terug, en de Muis in het bos is weg als je de kat gevonden hebt.
func _fill_in_old_save(data: Dictionary) -> void:
	if not data.has("kills_by"):
		for golem_flag: String in ["golem_ruins", "golem_cave"]:
			if flag(golem_flag):
				kills_by["golem"] = int(kills_by.get("golem", 0)) + 1
		if flag("boss_defeated"):
			kills_by["king"] = 1
	if not data.has("talked") and flag("cat_found"):
		talked["muis_bos"] = true


func _mark_achievements() -> void:
	_achievements_dirty = true


## Kijkt of er prestaties zijn behaald. Wordt vanzelf aangeroepen; je kunt het ook zelf doen.
func check_achievements() -> void:
	_achievements_dirty = false
	_achievement_timer = ACHIEVEMENT_INTERVAL
	for id: String in Achievements.ACHIEVEMENTS:
		var conditions: Array = Achievements.ACHIEVEMENTS[id].get("if", [])
		# Een prestatie zonder voorwaarden is nooit vanzelf behaald (die geef je zelf met unlock_achievement).
		if not achievements.has(id) and not conditions.is_empty() and check_all(conditions):
			unlock_achievement(id)


func unlock_achievement(id: String) -> void:
	if achievements.has(id):
		return
	achievements[id] = true
	if not meta_achievements.has(id):
		meta_achievements[id] = true
		_save_meta()
	achievement_queue.append(id)
	achievement_unlocked.emit(id)


func _load_meta() -> void:
	var config := ConfigFile.new()
	if config.load(META_PATH) == OK and config.has_section("achievements"):
		for id: String in config.get_section_keys("achievements"):
			meta_achievements[id] = true


func _save_meta() -> void:
	var config := ConfigFile.new()
	for id: String in meta_achievements:
		config.set_value("achievements", id, true)
	config.save(META_PATH)


# --- Voorwerpen ----------------------------------------------------------------

func count(item_id: String) -> int:
	return inventory.get(item_id, 0)


func crystal_count() -> int:
	var total := 0
	for crystal: String in Items.CRYSTALS:
		if count(crystal) > 0:
			total += 1
	return total


const NO_LIMIT := 1000000 # "ruimte" voor voorwerpen zonder maximum


## Hoeveel van dit voorwerp er nog bij kunnen. Voorwerpen met een "max" (pijlen) passen maar tot dat maximum.
func room(item_id: String) -> int:
	var cap := int(Items.info(item_id).get("max", 0))
	return maxi(cap - count(item_id), 0) if cap > 0 else NO_LIMIT


func give(item_id: String, amount: int = 1, quiet: bool = false) -> void:
	var space := room(item_id)
	var cut_off := space < amount # past niet alles? dan krijg je wat er nog in past
	if cut_off:
		amount = space
		if amount <= 0:
			if not quiet:
				toast.emit(full_text(item_id))
			return
	inventory[item_id] = count(item_id) + amount
	if item_id == "heart_container":
		hp = mini(hp + amount, max_hp())
		hp_changed.emit()
	items_changed.emit()
	if not quiet:
		var label := tr(Items.info(item_id)["name"])
		if cut_off:
			if amount == 1:
				# Vertalers: een voorwerp, en waarom er niet meer bij past: "Gekregen: Pijl. Je pijlenkoker is vol!"
				toast.emit(tr("Gekregen: %s. %s!") % [label, full_text(item_id)])
			else:
				# Vertalers: voorwerp, aantal en waarom er niet meer bij past: "Gekregen: Pijl x3. Je pijlenkoker is vol!"
				toast.emit(tr("Gekregen: %s x%d. %s!") % [label, amount, full_text(item_id)])
		elif amount == 1:
			toast.emit(tr("Gekregen: %s") % label)
		else:
			# Vertalers: een voorwerp en hoeveel: "Gekregen: Pijl x5"
			toast.emit(tr("Gekregen: %s x%d") % [label, amount])
	_refresh_quests()


## Waarom een voorwerp niet meer in je tas past (vertaald): de eigen `full_text` van het voorwerp, of "Je tas is vol".
func full_text(item_id: String) -> String:
	var info := Items.info(item_id)
	return tr(info["full_text"]) if info.has("full_text") else tr("Je tas is vol")


func take(item_id: String, amount: int = 1) -> void:
	var left := count(item_id) - amount
	if left > 0:
		inventory[item_id] = left
	else:
		inventory.erase(item_id)
	Equipment.reconcile()
	Appearance.reconcile()
	items_changed.emit()
	_refresh_quests()


func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	items_changed.emit()


func use_potion() -> bool:
	if count("potion") <= 0 or hp >= max_hp():
		return false
	take("potion")
	heal(Items.ITEMS["potion"]["heal"])
	potions_drunk += 1
	_mark_achievements()
	return true


func set_weapon(weapon_id: String) -> void:
	weapon = weapon_id
	items_changed.emit()


# --- Vlaggen -------------------------------------------------------------------

func flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func set_flag(flag_name: String, value := true) -> void:
	if value:
		flags[flag_name] = true
	else:
		flags.erase(flag_name)
	_mark_achievements()
	_refresh_quests()


# --- Opdrachten ----------------------------------------------------------------

func quest_state(quest_id: String) -> String:
	if not quests.has(quest_id):
		return "none"
	return quests[quest_id]["state"]


func quest_step(quest_id: String) -> int:
	return quests[quest_id]["step"] if quests.has(quest_id) else -1


func start_quest(quest_id: String) -> void:
	if quests.has(quest_id):
		return
	quests[quest_id] = {"state": "active", "step": 0}
	toast.emit(tr("Nieuwe opdracht: %s") % tr(Quests.info(quest_id)["title"]))
	quests_changed.emit()
	_refresh_quests()


func set_quest_step(quest_id: String, step: int) -> void:
	if quests.has(quest_id):
		quests[quest_id]["step"] = step
		quests_changed.emit()
		_refresh_quests()


func finish_quest(quest_id: String) -> void:
	if quests.has(quest_id) and quests[quest_id]["state"] != "done":
		quests[quest_id]["state"] = "done"
		toast.emit(tr("Opdracht voltooid: %s") % tr(Quests.info(quest_id)["title"]))
		add_hero_xp(Progression.quest_xp(quest_id))
		quests_changed.emit()
		_refresh_quests() # Ook opdrachten die op deze afronding wachten direct bijwerken.


## Gaat naar de volgende stap zodra de voorwaarden van de huidige stap kloppen.
func _refresh_quests() -> void:
	var changed := false
	for quest_id: String in quests:
		var q: Dictionary = quests[quest_id]
		if q["state"] != "active":
			continue
		var steps: Array = Quests.info(quest_id)["steps"]
		var moved := true
		while moved:
			moved = false
			var step: int = q["step"]
			if step < steps.size() - 1 and steps[step].has("advance_if") and check_all(steps[step]["advance_if"]):
				q["step"] = step + 1
				moved = true
				changed = true
	if changed:
		quests_changed.emit()


## De tekst van de huidige stap, vertaald en met de {tekens} ingevuld.
func quest_text(quest_id: String) -> String:
	var steps: Array = Quests.info(quest_id)["steps"]
	var step := clampi(quest_step(quest_id), 0, maxi(steps.size() - 1, 0))
	if steps.is_empty():
		return ""
	return fmt(tr(steps[step]["text"]))


## De opdracht die in beeld getoond wordt (de hoofdopdracht, anders de eerste lopende).
func tracked_text() -> String:
	var focused := preload("res://scripts/core/journey.gd").tracker()
	if focused!="": return focused
	if quest_state("main") == "done":
		# Na het einde: de lopende opdracht die je het laatst bent begonnen (bijvoorbeeld De Vergeten Wachter).
		var latest := ""
		for quest_id: String in quests:
			if quests[quest_id]["state"] == "active":
				latest = quest_id
		return quest_text(latest) if latest != "" else tr("De Blauwe Kaart is hersteld!")
	if quest_state("main") == "active":
		return quest_text("main")
	if quest_state("main") == "none":
		return tr("Praat met Oudste Bram bij de tempel.")
	return ""


## Vult de {tekens} in een tekst in. Vertaal de tekst eerst (tr), zodat de vertaling dezelfde tekens bevat.
func fmt(text: String) -> String:
	text = text \
		.replace("{crystals}", str(crystal_count())) \
		.replace("{gel}", str(count("gel"))) \
		.replace("{shards}", str(count("shard"))) \
		.replace("{coins}", str(coins))
	return Content.format_text(text)


# --- Voorwaarden en acties (gebruikt door dialogen en poortjes) ---------------

func check(cond: Array) -> bool:
	match cond[0]:
		"flag":
			return flag(cond[1])
		"no_flag":
			return not flag(cond[1])
		"quest":
			return quest_state(cond[1]) == cond[2]
		"step":
			return quest_state(cond[1]) == "active" and quest_step(cond[1]) == cond[2]
		"has":
			return count(cond[1]) >= (cond[2] if cond.size() > 2 else 1)
		"lacks":
			return count(cond[1]) < (cond[2] if cond.size() > 2 else 1)
		"coins":
			return coins >= cond[1]
		"map":
			return map_id == cond[1]
		"weapon":
			return weapon == cond[1]
		"crystals":
			return crystal_count() >= cond[1]
		"hurt":
			return hp < max_hp()
	var extra: Variant = Content.check_condition(cond)
	if extra != null:
		return extra
	push_warning("Onbekende voorwaarde: %s" % [cond])
	return false


func check_all(conds: Array) -> bool:
	for cond: Array in conds:
		if not check(cond):
			return false
	return true


func run(action: Array) -> void:
	match action[0]:
		"start_quest":
			start_quest(action[1])
		"quest_step":
			set_quest_step(action[1], action[2])
		"finish_quest":
			finish_quest(action[1])
		"set_flag":
			set_flag(action[1])
		"clear_flag":
			set_flag(action[1], false)
		"give":
			give(action[1], action[2] if action.size() > 2 else 1)
		"take":
			take(action[1], action[2] if action.size() > 2 else 1)
		"coins":
			add_coins(action[1])
		"heal":
			full_rest()
		"weapon":
			set_weapon(action[1])
			toast.emit(tr("Nieuw zwaard: %s") % tr(Items.WEAPONS[action[1]]["name"]))
		"toast":
			toast.emit(tr(action[1])) # een melding uit de data (Nederlands): hier vertaald
		"sound":
			Sound.play(action[1])
		"shop":
			shop_requested.emit(action[1])
		"save":
			save_requested.emit()
		"ending":
			ending_requested.emit()
		"sell_all":
			var amount := count(action[1])
			if amount > 0:
				add_coins(amount * int(Items.info(action[1]).get("sell", 1)))
				take(action[1], amount)
				# Vertalers: aantal en voorwerp: "Verkocht: 4 x Slijmgel"
				toast.emit(tr("Verkocht: %d x %s") % [amount, tr(Items.info(action[1])["name"])])
		"talk":
			start_dialogue(action[1])
		"boss_start", "music", "lock_arena":
			world_action.emit(action)
		_:
			if not Content.run_action(action):
				push_warning("Onbekende actie: %s" % [action])


func run_all(actions: Array) -> void:
	for action: Array in actions:
		run(action)


func start_dialogue(dialogue_id: String) -> void:
	dialogue_requested.emit(dialogue_id)


## Een los berichtje (bijvoorbeeld een bord): spreker + regels. Die zijn al vertaald door wie say() aanroept
## (een bord doet tr() op de tekst uit de kaart); het dialoogvenster vult alleen nog de {tekens} in.
func say(speaker: String, lines: Array) -> void:
	text_dialogue_requested.emit(speaker, lines)


# --- Opslaan en laden -------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(pos: Vector2) -> bool:
	if flag("game_completed"):
		record_completion() # na het einde onthoudt het spel je beste spullen voor Nieuw spel+ (ook bij oude opslagen)
	var data := {
		"version": SAVE_VERSION, "map": map_id, "pos": [pos.x, pos.y], "hp": hp, "coins": coins,
		"inventory": inventory, "flags": flags, "quests": quests, "weapon": weapon,
		"play_time": play_time, "kills": kills, "meer": meer,
		"day_time": day_time, "day_count": day_count, "kills_by": kills_by, "rolls": rolls,
		"potions_drunk": potions_drunk, "deaths": deaths, "boss_deaths": boss_deaths,
		"talked": talked.keys(), "achievements": achievements.keys(), "arena_records": arena_records,
		"homestead": preload("res://scripts/core/homestead.gd").normalize(homestead),
		"coastal_storage": CoastalHome.normalize(coastal_storage),
		"professions": professions, "hero_xp": Progression.normalize(hero_xp),
		"equipment": Equipment.normalize(equipment, inventory),
		"appearance": Appearance.normalize_appearance(appearance),
		"clothing": Appearance.normalize_clothing(clothing, inventory),
	}
	data["ng_plus"] = ng_plus # de ronde van Nieuw spel+ (zie onderaan)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Opslaan mislukt: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data))
	save_is_ours = true
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	new_game()
	# Nieuwe-avontuurvlaggen mogen niet naar een bestaande opslag lekken.
	flags.clear()
	map_id = data.get("map", "village")
	var pos: Array = data.get("pos", [0, 0])
	load_pos = Vector2(pos[0], pos[1])
	use_load_pos = true
	coins = int(data.get("coins", 0))
	weapon = data.get("weapon", "wood")
	ng_plus = int(data.get("ng_plus", 0)) # de ronde van Nieuw spel+ (oude opslagen: 0)
	play_time = float(data.get("play_time", 0.0))
	professions = Professions.normalize(data.get("professions", {}), play_time)
	homestead = preload("res://scripts/core/homestead.gd").normalize(data.get("homestead", {}))
	coastal_storage = CoastalHome.normalize(data.get("coastal_storage", {}))
	hero_xp = Progression.normalize(data.get("hero_xp", 0))
	kills = int(data.get("kills", 0))
	for stat: String in data.get("meer", {}):
		meer[stat] = int(data["meer"][stat])
	day_time = Daynight.wrap_time(float(data.get("day_time", Daynight.START)))
	day_count = int(data.get("day_count", 0))
	for kind: String in data.get("kills_by", {}):
		kills_by[kind] = int(data["kills_by"][kind])
	rolls = int(data.get("rolls", 0))
	potions_drunk = int(data.get("potions_drunk", 0))
	deaths = int(data.get("deaths", 0))
	boss_deaths = int(data.get("boss_deaths", 0))
	for npc_id: String in data.get("talked", []):
		talked[npc_id] = true
	var new_in_meta := false
	for id: String in data.get("achievements", []):
		achievements[id] = true
		if not meta_achievements.has(id):
			meta_achievements[id] = true
			new_in_meta = true
	if new_in_meta:
		_save_meta()
	var saved_records: Variant = data.get("arena_records", {})
	if typeof(saved_records) == TYPE_DICTIONARY:
		for rank: String in saved_records:
			arena_records[rank] = float(saved_records[rank])
	for item_id: String in data.get("inventory", {}):
		if Equipment.slot_of(item_id) != "":
			# Nieuwe draagbare spullen hebben altijd maximaal één geldig exemplaar.
			var saved_gear := Equipment.normalize_owned({item_id: data["inventory"][item_id]})
			if saved_gear.has(item_id):
				inventory[item_id] = 1
		else:
			inventory[item_id] = int(data["inventory"][item_id])
	equipment = Equipment.normalize(data.get("equipment", {}), inventory)
	appearance = Appearance.normalize_appearance(data.get("appearance", {}))
	clothing = Appearance.normalize_clothing(data.get("clothing", {}), inventory)
	movement.reset()
	for flag_name: String in data.get("flags", {}):
		flags[flag_name] = true
	var saved_quests: Dictionary = data.get("quests", {})
	for quest_id: String in saved_quests:
		quests[quest_id] = {"state": saved_quests[quest_id]["state"], "step": int(saved_quests[quest_id]["step"])}
	_fill_in_old_save(data)
	save_is_ours = true
	hp = clampi(int(data.get("hp", BASE_HP)), 1, max_hp())
	hp_changed.emit()
	items_changed.emit()
	quests_changed.emit()
	progression_changed.emit()
	equipment_changed.emit()
	appearance_changed.emit()
	return true


# --- Nieuw spel+ -------------------------------------------------------------------------------------------------
# Na het einde van het hoofdverhaal kun je opnieuw beginnen met je beste spullen, tegen sterkere vijanden.
# Dat een spel is uitgespeeld staat in user://ng_plus.cfg, los van de opslag, zodat het blijft bestaan na een nieuw spel.

const NG_META_PATH := "user://ng_plus.cfg"
const NG_START_COINS := 100
const NG_HP_PER_ROUND := 0.5 # vijanden krijgen zoveel levens extra per voltooide ronde (0.5 = de helft)
const NG_COIN_FACTOR := 1.5 # munten uit vijanden

var ng_plus: int = 0 # aantal voltooide rondes (Nieuw spel+); 0 = gewoon spel. Wordt opgeslagen.


## Levens van een vijand die normaal `base` levens heeft, in deze ronde (naar boven afgerond).
func ng_hp(base: int) -> int:
	return ceili(float(base) * (1.0 + NG_HP_PER_ROUND * float(ng_plus)))


## Aantal munten uit een vijand die normaal `amount` munten laat vallen.
func ng_coins(amount: int) -> int:
	return ceili(float(amount) * NG_COIN_FACTOR) if ng_plus > 0 else amount


## Wat het spel onthoudt over uitgespeelde rondes: beste spullen en held-ervaring.
func load_meta() -> Dictionary:
	var meta := {"completed": false, "rounds": 0, "weapon": "wood", "hearts": 0, "boots": false, "hero_xp": 0, "gear_items": {}, "equipment": {}}
	var config := ConfigFile.new()
	if config.load(NG_META_PATH) != OK:
		return meta
	meta["completed"] = bool(config.get_value("ng", "completed", false))
	meta["rounds"] = int(config.get_value("ng", "rounds", 0))
	meta["weapon"] = str(config.get_value("ng", "weapon", "wood"))
	meta["hearts"] = int(config.get_value("ng", "hearts", 0))
	meta["boots"] = bool(config.get_value("ng", "boots", false))
	meta["hero_xp"] = Progression.normalize(config.get_value("ng", "hero_xp", 0))
	meta["gear_items"] = Equipment.normalize_owned(config.get_value("ng", "gear_items", {}))
	meta["equipment"] = Equipment.normalize(config.get_value("ng", "equipment", {}), meta["gear_items"])
	if not Items.WEAPONS.has(meta["weapon"]):
		meta["weapon"] = "wood"
	return meta


func save_meta(meta: Dictionary) -> void:
	var config := ConfigFile.new()
	config.set_value("ng", "completed", meta["completed"])
	config.set_value("ng", "rounds", meta["rounds"])
	config.set_value("ng", "weapon", meta["weapon"])
	config.set_value("ng", "hearts", meta["hearts"])
	config.set_value("ng", "boots", meta["boots"])
	config.set_value("ng", "hero_xp", Progression.normalize(meta.get("hero_xp", 0)))
	var gear_items := Equipment.normalize_owned(meta.get("gear_items", {}))
	config.set_value("ng", "gear_items", gear_items)
	config.set_value("ng", "equipment", Equipment.normalize(meta.get("equipment", {}), gear_items))
	config.save(NG_META_PATH)


func ng_plus_available() -> bool:
	return load_meta()["completed"]


## Het hoofdverhaal is uitgespeeld: bij elke opslag na het einde (de eerste is die aan het einde zelf, zie world.gd). Zo
## hebben ook spelers die het spel al uitgespeeld hadden Nieuw spel+, zodra ze weer opslaan.
func record_completion() -> void:
	var meta := load_meta()
	meta["completed"] = true
	meta["rounds"] = maxi(int(meta["rounds"]), ng_plus + 1)
	save_meta(_merge_gear(meta))


## Bewaart je beste zwaard, hartcontainers en laarzen (nooit minder dan wat al bewaard was).
func _merge_gear(meta: Dictionary) -> Dictionary:
	if Items.WEAPONS[weapon]["damage"] > Items.WEAPONS[meta["weapon"]]["damage"]:
		meta["weapon"] = weapon
	meta["hearts"] = maxi(int(meta["hearts"]), count("heart_container"))
	meta["boots"] = bool(meta["boots"]) or count("boots") > 0
	meta["hero_xp"] = maxi(Progression.normalize(meta.get("hero_xp", 0)), Progression.normalize(hero_xp))
	var gear_items := Equipment.normalize_owned(meta.get("gear_items", {}))
	gear_items.merge(Equipment.normalize_owned(inventory), true)
	meta["gear_items"] = gear_items
	# Bezit wordt bewaard, de laatste bewuste selectie (ook leeg) blijft de keuze.
	meta["equipment"] = Equipment.normalize(equipment, inventory)
	return meta


## Begint een nieuw verhaal met je beste spullen. Geeft false als je nog niets hebt uitgespeeld.
func new_game_plus() -> bool:
	var meta := load_meta()
	if not meta["completed"]:
		return false
	new_game()
	ng_plus = int(meta["rounds"])
	flags.erase("op_new_adventure")
	weapon = meta["weapon"]
	hero_xp = meta["hero_xp"]
	if int(meta["hearts"]) > 0:
		give("heart_container", int(meta["hearts"]), true)
	if meta["boots"]:
		give("boots", 1, true)
	for item: String in meta["gear_items"]:
		give(item, 1, true)
	equipment = Equipment.normalize(meta["equipment"], inventory)
	movement.reset()
	coins = NG_START_COINS
	full_heal()
	items_changed.emit()
	progression_changed.emit()
	equipment_changed.emit()
	return true
