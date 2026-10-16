extends RefCounted
## Source information derives from the actual recipe/resource tables, not a second cost list.
const Data := preload("res://scripts/data/ext/beroepen.gd")
const Stock:=preload("res://scripts/core/stockroom.gd")
const Notes := preload("res://scripts/data/ext/craft_progression.gd")
const Equipment := preload("res://scripts/core/equipment.gd")
static func state() -> Node: return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
static func name_of(item: String) -> String:
	return TranslationServer.translate(load("res://scripts/data/items.gd").info(item).name)
static func goal() -> String:
	var id: Variant = state().professions.get("goal","")
	return id if id is String and Data.RECIPES.has(id) else ""
static func toggle_goal(id: String) -> void:
	if not Data.RECIPES.has(id): return
	state().professions["goal"] = "" if goal() == id else id
	state().progression_changed.emit()
	state().save_requested.emit()
static func crafted(id: String) -> void:
	if goal() == id:
		state().professions["goal"] = ""
		state().progression_changed.emit()
static func learn(kind: String) -> bool:
	if not Notes.NOTES.has(kind): return false
	var gs := state()
	var note: Dictionary = Notes.NOTES[kind]
	var fresh: bool = not gs.flag(note.flag)
	if fresh:
		gs.set_flag(note.flag)
		gs.toast.emit(TranslationServer.translate("Werktekening geleerd: %s. Kies een materiaaldoel via Beroepen.") % name_of(Data.RECIPES[note.recipe].output))
		gs.save_requested.emit()
	return fresh
static func recipes_for(item: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in Data.RECIPES:
		if Data.RECIPES[id].output == item: result.append(id)
	return result
static func source(item: String) -> String:
	if item.begins_with("or_"):
		if item.ends_with("_seed"):return TranslationServer.translate("Tuinhulp of huisvoorraad: U → Zaden en boomgaard.")
		var crops: Script=load("res://scripts/data/orchard_catalog.gd")
		for id: String in crops.NAMES:
			if crops.CROPS[id].output==item:return TranslationServer.translate("Eigen tuin: %s. Kies zaden via U → Zaden en boomgaard.") % TranslationServer.translate(crops.NAMES[id])
	if item=="hs_honey":return TranslationServer.translate("Eigen bijenkast met drie bloeiende planten binnen vijf tegels.")
	var places: Array[String] = []
	var resource: Dictionary = {}
	var maps: Script = load("res://scripts/maps/registry.gd")
	# Prefer the current area, then list at most two other real sources.
	var ids: Array = Data.RESOURCE_PLACEMENTS.keys()
	if state().map_id in ids:
		ids.erase(state().map_id); ids.push_front(state().map_id)
	for map_id: String in ids:
		for entry: Array in Data.RESOURCE_PLACEMENTS[map_id]:
			if Data.RESOURCES[entry[1]].item == item:
				resource = Data.RESOURCES[entry[1]]
				var label: String = TranslationServer.translate(maps.MAPS[map_id].DATA.name)
				if label not in places: places.append(label)
	if not places.is_empty():
		var text := ", ".join(places.slice(0,3))
		if resource.has("tools"):
			text += " · " + name_of(resource.tools.back())
		if int(resource.get("level",1)) > 1:
			text += " · " + TranslationServer.translate("%s niveau %d") % [TranslationServer.translate(Data.SKILLS[resource.skill].name),int(resource.level)]
		return text
	var recipes := recipes_for(item)
	if not recipes.is_empty():
		var recipe: Dictionary = Data.RECIPES[recipes[0]]
		return TranslationServer.translate("Maken: %s · %s niveau %d") % [TranslationServer.translate(Data.TEXT[recipe.get("station","anywhere")]),TranslationServer.translate(Data.SKILLS[recipe.skill].name),int(recipe.level)]
	match item:
		"gel": return TranslationServer.translate("Slijmen in het Fluisterbos en de Ruïne.")
		"meer_baars": return TranslationServer.translate("Hengel van Joris; visplekken bij het Zilvermeer.")
		"jacht_vlees", "jacht_huid": return TranslationServer.translate("Jachtwild in de Dorstvallei.")
		"moeras_huid": return TranslationServer.translate("Moeraswild in het Kruipmoeras.")
		"shard": return TranslationServer.translate("Golembewakers in de Ruïne en de Echo-grot.")
	return TranslationServer.translate("Ontdek dit voorwerp tijdens je avonturen.")
static func recipe_text(id: String) -> String:
	if not Data.RECIPES.has(id): return ""
	var recipe: Dictionary = Data.RECIPES[id]
	var info: Dictionary = load("res://scripts/data/items.gd").info(recipe.output)
	var lines: Array[String] = [TranslationServer.translate(info.desc),TranslationServer.translate("%s niveau %d · %s") % [TranslationServer.translate(Data.SKILLS[recipe.skill].name),int(recipe.level),TranslationServer.translate(Data.TEXT[recipe.get("station","anywhere")])]]
	if recipe.has("unlock") and not state().flag(recipe.unlock): lines.append(TranslationServer.translate(recipe.get("unlock_hint","Nog vergrendeld: herstel de prismabank of Mees’ oversteek.")))
	for item: String in recipe.inputs:
		lines.append(TranslationServer.translate("%s: %d/%d · %s") % [name_of(item),Stock.available(item),int(recipe.inputs[item]),source(item)])
	for item: String in recipe.inputs:
		if Stock.available(item)>state().count(item):lines.append(TranslationServer.translate("Binnen bereik: %s · tas %d + kist %d.") % [name_of(item),state().count(item),Stock.available(item)-state().count(item)])
	var effect := Equipment.stats_text(recipe.output)
	if effect != "": lines.append(effect)
	if recipe.has("upgrade_from"): lines.append(TranslationServer.translate("Verbeteren verbruikt het oude voorwerp. Een gedragen exemplaar wordt meteen vervangen; stamina wordt niet bijgevuld."))
	return "\n".join(lines)
static func uses_text(item: String) -> String:
	var uses: Array[String] = []
	for id: String in Data.RECIPES:
		if Data.RECIPES[id].inputs.has(item):
			var label := name_of(Data.RECIPES[id].output)
			if label not in uses: uses.append(label)
	return "" if uses.is_empty() else TranslationServer.translate("Voor: %s") % ", ".join(uses.slice(0,4))
static func ingredient_status(id: String) -> String:
	var pieces: Array[String] = []
	for item: String in Data.RECIPES[id].inputs:
		pieces.append("%s %d/%d" % [name_of(item),Stock.available(item),int(Data.RECIPES[id].inputs[item])])
	return " · ".join(pieces)
