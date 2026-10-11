extends Node
## Autoload "GameState": alles wat bij je spel hoort en opgeslagen wordt (levens, voorwerpen,
## vlaggen, opdrachten), plus de regels voor dialoogvoorwaarden en -acties.

const Items := preload("res://scripts/data/items.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Content := preload("res://scripts/data/content.gd")

signal hp_changed
signal items_changed
signal quests_changed
signal toast(text: String)
signal game_over
signal ending_requested
signal dialogue_requested(dialogue_id: String)
signal text_dialogue_requested(speaker: String, lines: Array)
signal shop_requested(shop_id: String)
signal save_requested
signal world_action(action: Array)

const BASE_HP := 5
const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

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
var meer: Dictionary = {} # eigen opslag van het Zilvermeer (zie scripts/data/ext/meer.gd): verkochte en gevangen vis

# Tijdelijke toestand (wordt niet opgeslagen).
var in_game: bool = false
var last_damage_source: String = "" # waardoor je het laatst geraakt bent (voor het game-over-scherm)
var damage_log: Dictionary = {} # voor de balansbot
var ended: bool = false
var transitioning: bool = false
var dialogue_open: bool = false
var ui_owners: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if in_game and not ended and not get_tree().paused:
		play_time += delta


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


# --- Nieuw spel en schermen die het spel stilzetten ----------------------------

func new_game() -> void:
	hp = BASE_HP
	coins = 0
	inventory = {}
	flags = {}
	quests = {}
	weapon = "wood"
	map_id = "village"
	spawn_name = "start"
	use_load_pos = false
	play_time = 0.0
	kills = 0
	meer = {}
	ended = false
	transitioning = false
	dialogue_open = false
	ui_owners = {}
	last_damage_source = ""
	damage_log = {}
	_apply_pause()
	hp_changed.emit()
	items_changed.emit()
	quests_changed.emit()


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
	if ended:
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit()
	if hp == 0:
		ended = true
		game_over.emit()


func heal(amount: int = 1) -> void:
	hp = mini(hp + amount, max_hp())
	hp_changed.emit()


func full_heal() -> void:
	hp = max_hp()
	hp_changed.emit()


func damage() -> int:
	return Items.WEAPONS[weapon]["damage"]


func reach() -> float:
	return Items.WEAPONS[weapon]["reach"]


func speed_multiplier() -> float:
	return 1.18 if count("boots") > 0 else 1.0


# --- Voorwerpen ----------------------------------------------------------------

func count(item_id: String) -> int:
	return inventory.get(item_id, 0)


func crystal_count() -> int:
	var total := 0
	for crystal: String in Items.CRYSTALS:
		if count(crystal) > 0:
			total += 1
	return total


func give(item_id: String, amount: int = 1, quiet: bool = false) -> void:
	inventory[item_id] = count(item_id) + amount
	if item_id == "heart_container":
		hp = mini(hp + amount, max_hp())
		hp_changed.emit()
	items_changed.emit()
	if not quiet:
		var label: String = Items.info(item_id)["name"]
		toast.emit("Gekregen: %s%s" % [label, "" if amount == 1 else " x%d" % amount])
	_refresh_quests()


func take(item_id: String, amount: int = 1) -> void:
	var left := count(item_id) - amount
	if left > 0:
		inventory[item_id] = left
	else:
		inventory.erase(item_id)
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
	toast.emit("Nieuwe opdracht: %s" % Quests.info(quest_id)["title"])
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
		toast.emit("Opdracht voltooid: %s" % Quests.info(quest_id)["title"])
		quests_changed.emit()


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


func quest_text(quest_id: String) -> String:
	var steps: Array = Quests.info(quest_id)["steps"]
	var step := clampi(quest_step(quest_id), 0, maxi(steps.size() - 1, 0))
	if steps.is_empty():
		return ""
	return fmt(steps[step]["text"])


## De opdracht die in beeld getoond wordt (de hoofdopdracht, anders de eerste lopende).
func tracked_text() -> String:
	if quest_state("main") == "done":
		return "De Blauwe Kaart is hersteld!"
	if quest_state("main") == "active":
		return quest_text("main")
	if quest_state("main") == "none":
		return "Praat met Oudste Bram bij de tempel."
	return ""


func fmt(text: String) -> String:
	text = text \
		.replace("{crystals}", str(crystal_count())) \
		.replace("{gel}", str(count("gel"))) \
		.replace("{shards}", str(count("shard"))) \
		.replace("{coins}", str(coins))
	return Content.format(text)


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
			full_heal()
		"weapon":
			set_weapon(action[1])
			toast.emit("Nieuw zwaard: %s" % Items.WEAPONS[action[1]]["name"])
		"toast":
			toast.emit(action[1])
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
				toast.emit("Verkocht: %d x %s" % [amount, Items.info(action[1])["name"]])
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


## Een los berichtje (bijvoorbeeld een bord): spreker + regels.
func say(speaker: String, lines: Array) -> void:
	text_dialogue_requested.emit(speaker, lines)


# --- Opslaan en laden -------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(pos: Vector2) -> bool:
	var data := {
		"version": SAVE_VERSION, "map": map_id, "pos": [pos.x, pos.y], "hp": hp, "coins": coins,
		"inventory": inventory, "flags": flags, "quests": quests, "weapon": weapon,
		"play_time": play_time, "kills": kills, "meer": meer,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Opslaan mislukt: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	new_game()
	map_id = data.get("map", "village")
	var pos: Array = data.get("pos", [0, 0])
	load_pos = Vector2(pos[0], pos[1])
	use_load_pos = true
	coins = int(data.get("coins", 0))
	weapon = data.get("weapon", "wood")
	play_time = float(data.get("play_time", 0.0))
	kills = int(data.get("kills", 0))
	for stat: String in data.get("meer", {}):
		meer[stat] = int(data["meer"][stat])
	for item_id: String in data.get("inventory", {}):
		inventory[item_id] = int(data["inventory"][item_id])
	for flag_name: String in data.get("flags", {}):
		flags[flag_name] = true
	var saved_quests: Dictionary = data.get("quests", {})
	for quest_id: String in saved_quests:
		quests[quest_id] = {"state": saved_quests[quest_id]["state"], "step": int(saved_quests[quest_id]["step"])}
	hp = clampi(int(data.get("hp", BASE_HP)), 1, max_hp())
	hp_changed.emit()
	items_changed.emit()
	quests_changed.emit()
	return true
