extends RefCounted
## Selectie en effecten van gedragen uitrusting. Bezit alleen geeft nooit een bonus.
## Geen autoload-namen tijdens preload: deze module wordt ook door GameState geladen.

const Data := preload("res://scripts/data/ext/uitrusting.gd")
const SLOTS := Data.SLOTS
const BONUS_LIMITS := {"move_speed": 0.12, "stamina_max": 30.0, "armor": 2.0, "attack_cooldown_reduction": 0.16, "stamina_regen": 0.30, "magnet_range": 24.0, "technique_cost_reduction":0.20, "bow_preparation_reduction":0.25, "harvest_time_reduction":0.25}


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


## All bonuses are visible; comparison uses effective whole-set caps.
static func stat_text(stat: String, value: float) -> String:
	match stat:
		"move_speed": return TranslationServer.translate("%+d%% snelheid") % roundi(value*100)
		"stamina_max": return TranslationServer.translate("%+d stamina") % roundi(value)
		"armor": return TranslationServer.translate("%+d pantser") % roundi(value)
		"attack_cooldown_reduction": return TranslationServer.translate("%+d%% zwaardwachttijd") % -roundi(value*100)
		"stamina_regen": return TranslationServer.translate("%+d%% staminaherstel") % roundi(value*100)
		"magnet_range": return TranslationServer.translate("%+d oppakbereik") % roundi(value)
		"technique_cost_reduction": return TranslationServer.translate("%+d%% techniekstamina") % -roundi(value*100)
		"bow_preparation_reduction": return TranslationServer.translate("%+d%% boogvoorbereiding") % -roundi(value*100)
		"harvest_time_reduction": return TranslationServer.translate("%+d%% verzameltijd") % -roundi(value*100)
	return ""
static func stats_text(item_id: String) -> String:
	var values: Dictionary = Data.ITEMS.get(item_id,{}).get("bonuses",{})
	var pieces: Array[String] = []
	for stat: String in values: pieces.append(stat_text(stat,float(values[stat])))
	return " · ".join(pieces)
static func preview_bonus(stat: String, candidate: String) -> float:
	var total := 0.0
	var replace := slot_of(candidate)
	for slot: String in SLOTS:
		var item := candidate if slot == replace else equipped(slot)
		total += float(Data.ITEMS.get(item,{}).get("bonuses",{}).get(stat,0.0))
	return clampf(total,-float(BONUS_LIMITS[stat]),float(BONUS_LIMITS[stat]))
static func comparison_text(candidate: String) -> String:
	var changes: Array[String] = []
	for stat: String in BONUS_LIMITS:
		var difference := preview_bonus(stat,candidate)-bonus(stat)
		if absf(difference) > 0.001: changes.append(stat_text(stat,difference))
	return TranslationServer.translate("Geen verandering in je gedragen set.") if changes.is_empty() else TranslationServer.translate("Verschil gedragen set: %s") % " · ".join(changes)
