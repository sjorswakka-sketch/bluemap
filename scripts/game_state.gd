extends Node
## Globale spelstatus (autoload "GameState"): gezondheid, verzamelde spullen en de quest.

signal hp_changed(hp: int, max_hp: int)
signal items_changed
signal toast(text: String)
signal dialogue_requested(speaker: String, lines: Array, on_done: Callable)
signal game_over
signal victory

const MAX_HP := 5
const CRYSTALS_NEEDED := 3

var hp: int = MAX_HP
var coins: int = 0
var crystals: int = 0
var quest_started: bool = false
var quest_done: bool = false
var dialogue_open: bool = false
var ended: bool = false


func reset() -> void:
	hp = MAX_HP
	coins = 0
	crystals = 0
	quest_started = false
	quest_done = false
	dialogue_open = false
	ended = false
	hp_changed.emit(hp, MAX_HP)
	items_changed.emit()


func hurt(amount: int = 1) -> void:
	if ended:
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, MAX_HP)
	if hp == 0:
		ended = true
		game_over.emit()


func heal(amount: int = 1) -> void:
	hp = mini(hp + amount, MAX_HP)
	hp_changed.emit(hp, MAX_HP)


func add_coin() -> void:
	coins += 1
	items_changed.emit()


func add_crystal() -> void:
	crystals += 1
	items_changed.emit()
	if crystals == CRYSTALS_NEEDED and quest_started:
		toast.emit("Je hebt genoeg kristallen! Breng ze naar Bram.")
	else:
		toast.emit("Blauw kristal gevonden! (%d/%d)" % [crystals, CRYSTALS_NEEDED])


func start_quest() -> void:
	quest_started = true
	items_changed.emit()
	toast.emit("Nieuwe opdracht: vind %d blauwe kristallen" % CRYSTALS_NEEDED)


func finish_quest() -> void:
	quest_done = true
	ended = true
	items_changed.emit()
	victory.emit()
