extends RefCounted
## Alle voorwerpen en zwaarden. `icon` is het vakje (16x16) in assets/items.png. Een uitbreiding kan een eigen
## plaatje gebruiken met `"sheet": "items_vissen"` (een rij van 16x16 vakjes in assets/items_vissen.png).

const Content := preload("res://scripts/data/content.gd")
const Art := preload("res://scripts/core/art.gd")

const BASE_ITEMS := {
	"coin": {"name": "Munt", "icon": 0, "desc": "Je betaalt er mee."},
	"potion": {
		"name": "Helddrank", "icon": 1, "type": "use", "heal": 3, "price": 15,
		"desc": "Geneest 3 hartjes. Druk op H om te drinken.",
	},
	"gel": {
		"name": "Slijmgel", "icon": 2, "type": "material", "sell": 3,
		"desc": "Plakkerig spul van slijmen. Handig voor smeden en drankjes.",
	},
	"shard": {
		"name": "Kristalscherf", "icon": 3, "type": "material",
		"desc": "Een stukje kaartkristal. De smid kan er een bijzonder zwaard van maken.",
	},
	"ruin_key": {
		"name": "Ruïnesleutel", "icon": 4, "type": "key",
		"desc": "Een roestige sleutel. Hij past op het poortje van de Vergeten Ruïne.",
	},
	"medallion": {
		"name": "Oud medaillon", "icon": 5, "type": "quest",
		"desc": "Een zilveren medaillon met een naam erin gegraveerd: Wilfred.",
	},
	"boots": {
		"name": "Snelle laarzen", "icon": 6, "type": "gear", "price": 60,
		"desc": "Je loopt een stuk sneller. Altijd handig.",
	},
	"heart_container": {
		"name": "Hartcontainer", "icon": 7, "type": "gear",
		"desc": "Je kunt er een hartje meer door hebben. Blijvend!",
	},
	"crystal_bos": {
		"name": "Kaartkristal van het Bos", "icon": 8, "type": "crystal",
		"desc": "Een gloeiend kristal uit het Fluisterbos. Hoort in de Blauwe Kaart.",
	},
	"crystal_ruine": {
		"name": "Kaartkristal van de Ruïne", "icon": 9, "type": "crystal",
		"desc": "Een gloeiend kristal uit de Vergeten Ruïne. Hoort in de Blauwe Kaart.",
	},
	"crystal_grot": {
		"name": "Kaartkristal van de Grot", "icon": 10, "type": "crystal",
		"desc": "Een gloeiend kristal uit de Echo-grot. Hoort in de Blauwe Kaart.",
	},
	"sword_wood": {"name": "Houten zwaard", "icon": 11, "type": "weapon", "desc": "Klein, maar het werkt."},
	"sword_iron": {"name": "IJzeren zwaard", "icon": 12, "type": "weapon", "desc": "Door Greta gesmeed. Raakt harder."},
	"sword_crystal": {
		"name": "Kristalzwaard", "icon": 13, "type": "weapon",
		"desc": "Gloeit zachtblauw. Het sterkste zwaard van Azura.",
	},
}

## Zwaarden. `reach` is hoe ver je raakt, `damage` hoeveel schade per klap.
const BASE_WEAPONS := {
	"wood": {"name": "Houten zwaard", "item": "sword_wood", "damage": 1, "reach": 34.0, "color": Color(0.85, 0.7, 0.45)},
	"iron": {"name": "IJzeren zwaard", "item": "sword_iron", "damage": 2, "reach": 38.0, "color": Color(0.85, 0.9, 1.0)},
	"crystal": {"name": "Kristalzwaard", "item": "sword_crystal", "damage": 3, "reach": 44.0, "color": Color(0.5, 0.85, 1.0)},
}

const CRYSTALS := ["crystal_bos", "crystal_ruine", "crystal_grot"]


## Basis en uitbreidingen samen (zie content.gd).
static var ITEMS: Dictionary = Content.merged("ITEMS", BASE_ITEMS)
static var WEAPONS: Dictionary = Content.merged("WEAPONS", BASE_WEAPONS)


static func info(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {"name": item_id, "icon": 0, "desc": ""})


## Naam van het plaatje (in assets/) waar het icoon van dit voorwerp in staat.
static func sheet_of(item_id: String) -> String:
	return info(item_id).get("sheet", "items")


## Het icoon van een voorwerp als los plaatje van 16x16 (voor knoppen en menu's).
static func icon_tex(item_id: String) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = Art.tex(sheet_of(item_id))
	atlas.region = Rect2(int(info(item_id).get("icon", 0)) * 16, 0, 16, 16)
	return atlas
