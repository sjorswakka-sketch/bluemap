extends RefCounted
## Runtime rules for professions. Uses no autoload identifiers at preload time.
## Resource cooldowns use saved active play time; map changes, sleep and reloads do
## not respawn a node. Saves from before this module normalize to empty progress.

const Data := preload("res://scripts/data/ext/beroepen.gd")
const Journal := preload("res://scripts/core/craft_journal.gd")
const Equipment := preload("res://scripts/core/equipment.gd")
const MAX_LEVEL := 10
const MAX_XP := 1350 # 30 * (10 - 1) * 10 / 2
const CONSUMABLES := ["cw_broth","potion", "prof_berry_meal", "prof_stew", "prof_fish_meal", "prof_tonic", "ls_chowder", "ls_broth", "prof_frost_tonic", "prof_winter_gloed", "prof_zandbalsem", "jacht_braadstuk", "prof_mistdrank", "prof_dauwsoep", "prof_moeraselixer", "prof_veenbespap"]
static var _busy := false


static func state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


static func normalize(raw: Variant, clock: float = 0.0) -> Dictionary:
	var result := {"xp": {}, "cooldowns": {}}
	if not raw is Dictionary:
		return result
	var goal: Variant = raw.get("goal", "")
	if goal is String and Data.RECIPES.has(goal): result["goal"] = goal
	var xp: Variant = raw.get("xp", {})
	if xp is Dictionary:
		for skill: String in Data.SKILLS:
			var value: Variant = xp.get(skill, 0)
			if (value is int or value is float) and is_finite(float(value)):
				result["xp"][skill] = clampi(int(value), 0, MAX_XP)
	var cooldowns: Variant = raw.get("cooldowns", {})
	if cooldowns is Dictionary:
		for map_id: String in Data.RESOURCE_PLACEMENTS:
			for obj: Dictionary in Data.resource_objects(map_id):
				var value: Variant = cooldowns.get(obj["id"], 0.0)
				if (value is int or value is float) and is_finite(float(value)) and float(value) > clock:
					# No node can legitimately remain exhausted beyond its own cooldown.
					result["cooldowns"][obj["id"]] = minf(float(value), clock + float(Data.RESOURCES[obj["kind"]]["cooldown"]))
	return result


static func _ensure() -> Node:
	var gs := state()
	if not gs.professions.has("xp") or not gs.professions.has("cooldowns"):
		gs.professions = normalize(gs.professions, gs.play_time)
	return gs


static func threshold(for_level: int) -> int:
	return 15 * (clampi(for_level, 1, MAX_LEVEL) - 1) * clampi(for_level, 1, MAX_LEVEL)


static func xp(skill: String) -> int:
	return int(_ensure().professions["xp"].get(skill, 0))


static func level(skill: String) -> int:
	var total := xp(skill)
	var result := 1
	while result < MAX_LEVEL and total >= threshold(result + 1):
		result += 1
	return result


static func add_xp(skill: String, amount: int) -> void:
	if not Data.SKILLS.has(skill) or amount <= 0:
		return
	var gs := _ensure()
	var previous := xp(skill)
	var old_level := level(skill)
	gs.professions["xp"][skill] = previous + mini(amount, MAX_XP - previous)
	if xp(skill) == previous:
		return
	var new_level := level(skill)
	gs.progression_changed.emit()
	if new_level > old_level:
		gs.toast.emit(TranslationServer.translate(Data.TEXT["skill_up"]) % [TranslationServer.translate(Data.SKILLS[skill]["name"]), new_level])


static func record_fish(item_id: String) -> void:
	# Junk is not a fish; quest fish retain their original quest/sale behavior.
	var amounts := {"meer_baars": 8, "meer_snoek": 12, "meer_gouden_karper": 20}
	if amounts.has(item_id):
		add_xp("fishing", amounts[item_id])


static func _item_info(item_id: String) -> Dictionary:
	return (load("res://scripts/data/items.gd") as Script).call("info", item_id)


static func item_name(item_id: String) -> String:
	return TranslationServer.translate(str(_item_info(item_id)["name"]))


static func craft_reason(recipe_id: String) -> String:
	if not Data.RECIPES.has(recipe_id):
		return TranslationServer.translate(Data.TEXT["unknown"])
	var gs := _ensure()
	var recipe: Dictionary = Data.RECIPES[recipe_id]
	if recipe.has("unlock") and not gs.flag(recipe["unlock"]):
		if recipe.has("unlock_hint"): return TranslationServer.translate(recipe["unlock_hint"])
		return TranslationServer.translate("Nog vergrendeld: herstel de prismabank of Mees’ oversteek.")
	var skill: String = recipe["skill"]
	if level(skill) < int(recipe["level"]):
		return TranslationServer.translate(Data.TEXT["skill_required"]) % [TranslationServer.translate(Data.SKILLS[skill]["name"]), recipe["level"]]
	var station: String = recipe.get("station", "")
	if station != "" and gs.map_id != station:
		return TranslationServer.translate(Data.TEXT["station_required"]) % TranslationServer.translate(Data.TEXT[station])
	var output: String = recipe["output"]
	if gs.room(output) < int(recipe.get("amount", 1)):
		return TranslationServer.translate(Data.TEXT["full"]) % item_name(output)
	for item: String in recipe["inputs"]:
		if gs.count(item) < int(recipe["inputs"][item]):
			return TranslationServer.translate(Data.TEXT["missing"]) % item_name(item)
	return ""


static func craft(recipe_id: String) -> bool:
	if _busy:
		return false
	var gs := _ensure()
	var reason := craft_reason(recipe_id)
	if reason != "":
		gs.toast.emit(reason)
		return false
	_busy = true
	var recipe: Dictionary = Data.RECIPES[recipe_id]
	var old_gear: String = recipe.get("upgrade_from", "")
	var worn: bool = old_gear != "" and Equipment.equipped(Equipment.slot_of(old_gear)) == old_gear
	# Validate the complete recipe first; all input removal precedes the output.
	# The guard also prevents synchronous item signals from crafting recursively.
	for item: String in recipe["inputs"]:
		gs.take(item, int(recipe["inputs"][item]))
	gs.give(recipe["output"], int(recipe.get("amount", 1)), true)
	if worn: Equipment.equip(recipe["output"])
	Journal.crafted(recipe_id)
	add_xp(recipe["skill"], int(recipe["xp"]))
	if recipe["output"] == "lw_lantern":
		load("res://scripts/core/living_world.gd").lantern_made()
	gs.toast.emit(TranslationServer.translate(Data.TEXT["made"]) % [item_name(recipe["output"]), int(recipe.get("amount", 1))])
	_busy = false
	gs.save_requested.emit()
	return true


static func remaining(resource_id: String) -> float:
	var gs := _ensure()
	return maxf(float(gs.professions["cooldowns"].get(resource_id, 0.0)) - float(gs.play_time), 0.0)


static func gather_reason(kind: String, resource_id: String) -> String:
	if not Data.RESOURCES.has(kind):
		return TranslationServer.translate(Data.TEXT["unknown"])
	var gs := _ensure()
	var resource: Dictionary = Data.RESOURCES[kind]
	var wait := remaining(resource_id)
	if wait > 0.0:
		return TranslationServer.translate(Data.TEXT["recovering"]) % [TranslationServer.translate(resource["name"]), ceili(wait)]
	var skill: String = resource["skill"]
	if level(skill) < int(resource.get("level", 1)):
		return TranslationServer.translate(Data.TEXT["skill_required"]) % [TranslationServer.translate(Data.SKILLS[skill]["name"]), resource["level"]]
	var required_tools: Array = resource.get("tools", [])
	if not required_tools.is_empty() and gather_tool(kind) == "":
		return TranslationServer.translate(Data.TEXT["tool_required"]) % item_name(required_tools.back())
	if gs.room(resource["item"]) < gather_amount(kind):
		return TranslationServer.translate(Data.TEXT["full"]) % item_name(resource["item"])
	return ""


static func gather_amount(kind: String) -> int:
	var amount := int(Data.RESOURCES[kind]["amount"])
	if kind == "stump" and state().count("prof_iron_axe") > 0:
		amount += 1
	return amount


static func gather_duration(kind: String) -> float:
	return float(Data.RESOURCES.get(kind, {}).get("duration", 0.65)) * (1.0 - Equipment.bonus("harvest_time_reduction"))


static func gather_animation(kind: String) -> String:
	return str(Data.RESOURCES.get(kind, {}).get("animation", "foraging"))


static func gather_tool(kind: String) -> String:
	# The first owned entry is the strongest usable tool, for both feedback and
	# harvest bonuses. A different tool class must never satisfy a requirement.
	for tool: String in Data.RESOURCES.get(kind, {}).get("tools", []):
		if state().count(tool) > 0:
			return tool
	return ""


static func gather(kind: String, resource_id: String) -> bool:
	if _busy:
		return false
	var gs := _ensure()
	# This commit check is deliberately repeated after the world's timed
	# animation: gear, level or free inventory space may have changed meanwhile.
	var reason := gather_reason(kind, resource_id)
	if reason != "":
		gs.toast.emit(reason)
		return false
	_busy = true
	var resource: Dictionary = Data.RESOURCES[kind]
	var amount := gather_amount(kind)
	# Set the cooldown before emitting any inventory/quest signals.
	gs.professions["cooldowns"][resource_id] = float(gs.play_time) + float(resource["cooldown"])
	gs.give(resource["item"], amount, true)
	add_xp(resource["skill"], int(resource["xp"]))
	gs.toast.emit(TranslationServer.translate(Data.TEXT["gathered"]) % [item_name(resource["item"]), amount, int(resource["xp"]), TranslationServer.translate(Data.SKILLS[resource["skill"]]["name"])])
	_busy = false
	return true


static func use_reason(item_id: String) -> String:
	var gs := _ensure()
	if not item_id in CONSUMABLES or gs.count(item_id) <= 0:
		return TranslationServer.translate(Data.TEXT["missing_item"])
	var info := _item_info(item_id)
	var heals: bool=info.has("heal") and gs.hp < gs.max_hp()
	var restores: bool=info.has("stamina") and gs.movement.stamina < gs.movement.capacity()
	if not heals and not restores:
		return TranslationServer.translate(Data.TEXT["health_full"] if info.has("heal") else Data.TEXT["stamina_full"])
	return ""


static func use_item(item_id: String) -> bool:
	if _busy:
		return false
	var gs := _ensure()
	var reason := use_reason(item_id)
	if reason != "":
		gs.toast.emit(reason)
		return false
	_busy = true
	var info := _item_info(item_id)
	if item_id == "potion":
		gs.use_potion() # preserve potion achievement counters
	else:
		gs.take(item_id, 1)
		if info.has("heal"):
			gs.heal(int(info["heal"]))
		if info.has("stamina"):
			gs.movement.restore(float(info["stamina"]))
	gs.toast.emit(TranslationServer.translate(Data.TEXT["used"]) % item_name(item_id))
	_busy = false
	return true
