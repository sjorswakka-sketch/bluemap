extends RefCounted
## Winkels. `once: true` betekent dat je het maar één keer kunt kopen.

const SHOPS := {
	"tobias": {
		"name": "Tobias' Winkel",
		"items": [
			{"item": "potion", "price": 15},
			{"item": "boots", "price": 60, "once": true},
		],
	},
}


static func info(shop_id: String) -> Dictionary:
	return SHOPS[shop_id]
