extends RefCounted
## Uiterlijk van de speler: geslacht, haar, ogen en de kleding over de uitrusting heen.
## Puur visueel — kleding geeft nooit een bonus (zie ext/uitrusting.gd voor echte uitrusting).
## Geen autoload-namen tijdens preload: deze module wordt ook door GameState geladen.

const Data := preload("res://scripts/data/ext/uiterlijk.gd")
const SLOTS := Data.CLOTHING_SLOTS

const DEFAULT := {"gender": "m", "hair": "m_kort", "hair_color": 2, "eyes": "rond", "eye_color": 0}


static func state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


static func hair_styles(gender: String) -> Dictionary:
	return Data.HAIR_V if gender == "v" else Data.HAIR_M


## Geldige waarden, met de standaard voor alles wat ontbreekt of niet klopt (oude opslagen).
static func normalize_appearance(raw: Variant) -> Dictionary:
	var result := DEFAULT.duplicate()
	if not raw is Dictionary:
		return result
	var gender: Variant = raw.get("gender", "m")
	result["gender"] = "v" if gender == "v" else "m"
	var hair: Variant = raw.get("hair", "")
	if hair is String and hair_styles(result["gender"]).has(hair):
		result["hair"] = hair
	else:
		result["hair"] = hair_styles(result["gender"]).keys()[2] # derde stijl: kort/pixie-achtig
	result["hair_color"] = clampi(int(raw.get("hair_color", 2)), 0, Data.HAIR_COLORS.size() - 1)
	var eyes: Variant = raw.get("eyes", "")
	if eyes is String and Data.EYES.has(eyes):
		result["eyes"] = eyes
	result["eye_color"] = clampi(int(raw.get("eye_color", 0)), 0, Data.EYE_COLORS.size() - 1)
	return result


static func clothing_slot_of(item_id: String) -> String:
	var slot: String = str(Data.ITEMS.get(item_id, {}).get("slot", ""))
	return slot if SLOTS.has(slot) else ""


static func _owns(inventory: Dictionary, item_id: String) -> bool:
	var count: Variant = inventory.get(item_id, 0)
	return (count is int or count is float) and is_finite(float(count)) and float(count) >= 1.0


## Gedragen kleding: vak -> {"item": id, "dye": kleurindex}. Alleen geldig wat je ook bezit.
static func normalize_clothing(raw: Variant, inventory: Dictionary) -> Dictionary:
	var result := {}
	if not raw is Dictionary:
		return result
	for slot: String in SLOTS:
		var entry: Variant = raw.get(slot, {})
		if not entry is Dictionary:
			continue
		var item: Variant = entry.get("item", "")
		if item is String and clothing_slot_of(item) == slot and _owns(inventory, item):
			result[slot] = {"item": item, "dye": clampi(int(entry.get("dye", 0)), 0, Data.DYE_COLORS.size() - 1)}
	return result


static func worn(slot: String) -> Dictionary:
	if not SLOTS.has(slot):
		return {}
	var gs := state()
	var entry: Variant = gs.clothing.get(slot, {})
	if entry is Dictionary and _owns(gs.inventory, str(entry.get("item", ""))):
		return entry
	return {}


static func owned_in_slot(slot: String) -> Array[String]:
	var result: Array[String] = []
	var gs := state()
	for item: String in Data.ITEMS:
		if clothing_slot_of(item) == slot and _owns(gs.inventory, item):
			result.append(item)
	return result


static func _notify() -> void:
	state().appearance_changed.emit()


static func set_gender(gender: String) -> void:
	var gs := state()
	if not Data.GENDERS.has(gender) or gs.appearance.get("gender") == gender:
		return
	gs.appearance["gender"] = gender
	# Het huidige kapsel bestaat niet per se voor het andere geslacht: kies een nette standaard.
	if not hair_styles(gender).has(str(gs.appearance.get("hair", ""))):
		gs.appearance["hair"] = hair_styles(gender).keys()[2]
	_notify()


static func set_hair(hair_id: String) -> void:
	var gs := state()
	if hair_styles(str(gs.appearance.get("gender", "m"))).has(hair_id):
		gs.appearance["hair"] = hair_id
		_notify()


static func set_hair_color(index: int) -> void:
	var gs := state()
	gs.appearance["hair_color"] = clampi(index, 0, Data.HAIR_COLORS.size() - 1)
	_notify()


static func set_eyes(eyes_id: String) -> void:
	var gs := state()
	if Data.EYES.has(eyes_id):
		gs.appearance["eyes"] = eyes_id
		_notify()


static func set_eye_color(index: int) -> void:
	var gs := state()
	gs.appearance["eye_color"] = clampi(index, 0, Data.EYE_COLORS.size() - 1)
	_notify()


static func wear(item_id: String) -> bool:
	var gs := state()
	var slot := clothing_slot_of(item_id)
	if slot == "" or not _owns(gs.inventory, item_id):
		return false
	var old := worn(slot)
	gs.clothing[slot] = {"item": item_id, "dye": int(old.get("dye", 0))} # de verf van het vak blijft
	_notify()
	return true


static func unwear(slot: String) -> bool:
	var gs := state()
	if not SLOTS.has(slot) or not gs.clothing.has(slot):
		return false
	gs.clothing.erase(slot)
	_notify()
	return true


static func dye(slot: String, index: int) -> bool:
	var gs := state()
	var entry := worn(slot)
	if entry.is_empty():
		return false
	gs.clothing[slot]["dye"] = clampi(index, 0, Data.DYE_COLORS.size() - 1)
	_notify()
	return true


## Voorwerp weggehaald? Het vak verliest direct wat er niet meer past.
static func reconcile() -> void:
	var gs := state()
	var valid := normalize_clothing(gs.clothing, gs.inventory)
	if valid != gs.clothing:
		gs.clothing = valid
		_notify()
