extends RefCounted
## Winkels. `once: true` betekent dat je het maar één keer kunt kopen.
## `amount` is hoeveel je per keer krijgt (standaard 1), `label` de naam in de lijst, `if` een voorwaarde
## om het te zien (zo ziet Tobias pas pijlen te koop als je een boog hebt) en `with` wat je er gratis bij krijgt.

const Content := preload("res://scripts/data/content.gd")

const BASE_SHOPS := {
	"tobias": {
		"name": "Tobias' Winkel",
		"items": [
			{"item": "potion", "price": 15},
			{"item": "boots", "price": 60, "once": true},
			{"item": "bow", "price": 80, "once": true, "label": "Boog + 5 pijlen", "with": [["arrow", 5]]},
			{"item": "arrow", "price": 10, "amount": 5, "label": "5 pijlen", "if": [["has", "bow"]]},
		],
	},
}


## Basis en uitbreidingen samen (zie content.gd).
static var SHOPS: Dictionary = Content.merged("SHOPS", BASE_SHOPS)


static func info(shop_id: String) -> Dictionary:
	return SHOPS[shop_id]
