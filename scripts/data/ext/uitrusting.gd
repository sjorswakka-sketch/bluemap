extends RefCounted
## Uitrusting wordt pas actief als de speler een voorwerp in het bijbehorende vak aantrekt.
## Eén exemplaar per voorwerp; zwaarden, laarzen en gereedschap houden hun bestaande gedrag.

const SLOTS := {
	"head": {"name": "Hoofd", "desc": "Kappen en helmen vergroten je uithoudingsvermogen."},
	"chest": {"name": "Borst", "desc": "Harnassen verminderen zware treffers. Een treffer doet altijd minstens 1 schade."},
	"hands": {"name": "Handen", "desc": "Handschoenen verkorten de wachttijd tussen zwaardaanvallen."},
	"neck": {"name": "Hals", "desc": "Amuletten laten je uithoudingsvermogen sneller herstellen."},
	"ring": {"name": "Ring", "desc": "Ringen trekken voorwerpen van verder weg naar je toe."},
}

const ITEMS := {
	"gear_cloth_hood": {"name": "Linnen kap", "sheet": "items_equipment", "icon": 0, "type": "gear", "max": 1, "slot": "head", "bonuses": {"stamina_max": 15.0}, "desc": "Een lichte reiskap. Draag hem op je hoofd voor 15 extra uithoudingsvermogen."},
	"gear_bronze_helm": {"name": "Bronzen helm", "sheet": "items_equipment", "icon": 1, "type": "gear", "max": 1, "slot": "head", "bonuses": {"stamina_max": 30.0}, "desc": "Een stevige helm voor lange tochten. Draag hem op je hoofd voor 30 extra uithoudingsvermogen."},
	"gear_leather_armor": {"name": "Leren harnas", "sheet": "items_equipment", "icon": 2, "type": "gear", "max": 1, "slot": "chest", "bonuses": {"armor": 1.0}, "desc": "Vangt zware klappen op. Vermindert schade met 1, tot minimaal 1 schade per treffer."},
	"gear_iron_armor": {"name": "IJzeren harnas", "sheet": "items_equipment", "icon": 3, "type": "gear", "max": 1, "slot": "chest", "bonuses": {"armor": 2.0}, "desc": "Gesmede bescherming. Vermindert schade met 2, tot minimaal 1 schade per treffer."},
	"gear_novice_gloves": {"name": "Leerlinghandschoenen", "sheet": "items_equipment", "icon": 4, "type": "gear", "max": 1, "slot": "hands", "bonuses": {"attack_cooldown_reduction": 0.08}, "desc": "Een goede grip op je zwaard. Draag ze voor 8% kortere wachttijd tussen zwaardaanvallen."},
	"gear_smith_gloves": {"name": "Smeedhandschoenen", "sheet": "items_equipment", "icon": 5, "type": "gear", "max": 1, "slot": "hands", "bonuses": {"attack_cooldown_reduction": 0.16}, "desc": "Perfect passende handschoenen. Draag ze voor 16% kortere wachttijd tussen zwaardaanvallen."},
	"gear_copper_amulet": {"name": "Koperen amulet", "sheet": "items_equipment", "icon": 6, "type": "gear", "max": 1, "slot": "neck", "bonuses": {"stamina_regen": 0.15}, "desc": "Een warm koperen sieraad. Draag het om je hals voor 15% sneller herstel van uithoudingsvermogen."},
	"gear_crystal_amulet": {"name": "Kristallen amulet", "sheet": "items_equipment", "icon": 7, "type": "gear", "max": 1, "slot": "neck", "bonuses": {"stamina_regen": 0.30}, "desc": "Alchemie laat gel kristalliseren rond koper. Draag het voor 30% sneller herstel van uithoudingsvermogen."},
	"gear_copper_ring": {"name": "Koperen ring", "sheet": "items_equipment", "icon": 8, "type": "gear", "max": 1, "slot": "ring", "bonuses": {"magnet_range": 12.0}, "desc": "Een ring die verloren spullen aantrekt. Vergroot je magnetische oppakbereik met 12 pixels."},
	"gear_crystal_ring": {"name": "Kristallen ring", "sheet": "items_equipment", "icon": 9, "type": "gear", "max": 1, "slot": "ring", "bonuses": {"magnet_range": 24.0}, "desc": "Een ring van koper en alchemistisch kristal. Vergroot je magnetische oppakbereik met 24 pixels."},
}
