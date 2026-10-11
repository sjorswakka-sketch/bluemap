extends RefCounted
## Winkels. `once: true` betekent dat je het maar één keer kunt kopen.

const Content := preload("res://scripts/data/content.gd")

const BASE_SHOPS := {
	"tobias": {
		"name": "Tobias' Winkel",
		"items": [
			{"item": "potion", "price": 15},
			{"item": "boots", "price": 60, "once": true},
		],
	},
}


## Basis en uitbreidingen samen (zie content.gd).
static var SHOPS: Dictionary = Content.merged("SHOPS", BASE_SHOPS)


static func info(shop_id: String) -> Dictionary:
	return SHOPS[shop_id]
