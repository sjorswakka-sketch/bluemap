extends RefCounted
## Selectie en effecten van gedragen uitrusting. Bezit alleen geeft nooit een bonus.
## Geen autoload-namen tijdens preload: deze module wordt ook door GameState geladen.

const Data := preload("res://scripts/data/ext/uitrusting.gd")
const SLOTS := Data.SLOTS
const BONUS_LIMITS := {"move_speed": 0.12, "stamina_max": 30.0, "armor": 2.0, "attack_cooldown_reduction": 0.16, "stamina_regen": 0.30, "magnet_range": 24.0}


static func state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


static func slot_of(item_id: String) -> String:
	return str(Data.ITEMS.get(item_id, {}).get("slot", ""))


static func _owns(inventory: Dictionary, item_id: String) -> bool:
	var count: Variant = inventory.get(item_id, 0)
	return (count is int or count is float) and is_finite(float(count)) and float(count) >= 1.0


static func normalize(raw: Variant, inventory: Dictionary) -> Dictionary:
	var result := {}
	if not raw is Dictionary:
		return result
	for slot: String in SLOTS:
		var item: Variant = raw.get(slot, "")
		if item is String and item != "" and slot_of(item) == slot and _owns(inventory, item):
			result[slot] = item
	return result


## Alleen bekende uitrusting, maximaal één exemplaar; ook voor Nieuw spel+-metadata.
static func normalize_owned(raw: Variant) -> Dictionary:
	var result := {}
	if raw is Dictionary:
		for item: String in Data.ITEMS:
			if _owns(raw, item):
				result[item] = 1
	return result


static func equipped(slot: String) -> String:
	if not SLOTS.has(slot):
		return ""
	var gs := state()
	var item: Variant = gs.equipment.get(slot, "")
	return item if item is String and slot_of(item) == slot and _owns(gs.inventory, item) else ""


static func owned(slot: String) -> Array[String]:
	var result: Array[String] = []
	if not SLOTS.has(slot):
		return result
	var gs := state()
	for item: String in Data.ITEMS:
		if slot_of(item) == slot and _owns(gs.inventory, item):
			result.append(item)
	return result


static func _notify() -> void:
	var gs := state()
	gs.movement.clamp_capacity() # wisselen vult nooit energie bij
	gs.equipment_changed.emit()
	gs.progression_changed.emit()


static func equip(item_id: String) -> bool:
	var gs := state()
	var slot := slot_of(item_id)
	if slot == "" or not _owns(gs.inventory, item_id) or equipped(slot) == item_id:
		return false
	gs.equipment[slot] = item_id
	_notify()
	return true


static func unequip(slot: String) -> bool:
	var gs := state()
	if not SLOTS.has(slot) or not gs.equipment.has(slot):
		return false
	gs.equipment.erase(slot)
	_notify()
	return true


## Voorwerp weggehaald? De selectie verliest direct het ongeldige effect.
static func reconcile() -> void:
	var gs := state()
	var valid := normalize(gs.equipment, gs.inventory)
	if valid != gs.equipment:
		gs.equipment = valid
		_notify()


static func bonus(stat: String) -> float:
	if not BONUS_LIMITS.has(stat):
		return 0.0
	var total := 0.0
	for slot: String in SLOTS:
		var item := equipped(slot)
		var value: Variant = Data.ITEMS.get(item, {}).get("bonuses", {}).get(stat, 0.0)
		if (value is int or value is float) and is_finite(float(value)):
			total += float(value) if stat == "move_speed" else maxf(float(value), 0.0)
	return clampf(total, -BONUS_LIMITS[stat], BONUS_LIMITS[stat])


## Reeds vertaald; de UI moet deze tekst niet nogmaals door tr() halen.
static func stats_text(item_id: String) -> String:
	var bonuses: Dictionary = Data.ITEMS.get(item_id, {}).get("bonuses", {})
	if bonuses.has("move_speed"):
		return TranslationServer.translate("%+d%% snelheid · %d pantser · %+d stamina") % [roundi(bonuses["move_speed"] * 100.0), int(bonuses.get("armor", 0)), int(bonuses.get("stamina_max", 0))]
	if bonuses.has("stamina_max"):
		return TranslationServer.translate("+%d uithoudingsvermogen") % int(bonuses["stamina_max"])
	if bonuses.has("armor"):
		return TranslationServer.translate("+%d pantser (minimaal 1 schade)") % int(bonuses["armor"])
	if bonuses.has("attack_cooldown_reduction"):
		return TranslationServer.translate("%d%% kortere wachttijd tussen zwaardaanvallen") % roundi(float(bonuses["attack_cooldown_reduction"]) * 100.0)
	if bonuses.has("stamina_regen"):
		return TranslationServer.translate("+%d%% herstel van uithoudingsvermogen") % roundi(float(bonuses["stamina_regen"]) * 100.0)
	if bonuses.has("magnet_range"):
		return TranslationServer.translate("+%d pixels magnetisch oppakbereik") % int(bonuses["magnet_range"])
	return ""
