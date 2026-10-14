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

	"gear_ra_grip":{"name":"Klimhandschoenen","sheet":"ra_items","icon":1,"type":"gear","max":1,"slot":"hands","bonuses":{"move_speed":0.04,"stamina_max":15.0},"desc":"Grip en een lichte tred: 4% sneller lopen en 15 extra stamina. Gebruikt hetzelfde handvak als aanvalshandschoenen."},
	"gear_ra_compass":{"name":"Archiefkompas","sheet":"ra_items","icon":2,"type":"gear","max":1,"slot":"neck","bonuses":{"magnet_range":16.0,"stamina_regen":0.10},"desc":"Een kompas uit het Rietarchief: 16 extra oppakbereik en 10% sneller staminaherstel. Draag het in je halsvak."},
	"gear_rf_keepsake": {"name":"Wilfreds herinnering","sheet":"rf_gear","icon":0,"type":"gear","max":1,"slot":"ring","bonuses":{"stamina_regen":0.15,"magnet_range":6.0},"desc":"Een ring uit de herdenkingsplek: 15% sneller staminaherstel en 6 extra oppakbereik. Minder bereik dan een koperen ring."},
	"gear_rf_cord": {"name":"Stiltekoord","sheet":"rf_gear","icon":1,"type":"gear","max":1,"slot":"neck","bonuses":{"stamina_max":20.0},"desc":"Een oud koord uit de schuilroute. Geeft gedragen 20 extra stamina; amuletten voor sneller herstel gebruiken hetzelfde halsvak."},
	"gear_scout_coat": {
	"name": "Verkennersjas",
	"sheet": "items_equipment",
	"icon": 2,
	"type": "gear",
	"max": 1,
	"slot": "chest",
	"bonuses": {
		"move_speed": 0.08,
		"stamina_max": 10.0
	},
	"desc": "8% sneller en 10 extra stamina, maar geen pantser. Voor verkennen en ontwijken."
},
	"gear_bastion_coat": {
	"name": "Wachtharnas",
	"sheet": "items_equipment",
	"icon": 3,
	"type": "gear",
	"max": 1,
	"slot": "chest",
	"bonuses": {
		"armor": 2.0,
		"move_speed": -0.08
	},
	"desc": "2 pantser, maar 8% langzamer. Elke treffer doet minimaal 1 schade. Voor standhouden bij een vuurkorf."
},

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
	"gear_pg_grip":{"name":"Slagbanden","sheet":"pg_gear","icon":0,"type":"gear","max":1,"slot":"hands","bonuses":{"technique_cost_reduction":0.10},"desc":"10% minder stamina voor voorbereide zwaardtechnieken en precisieschoten. Gewone slagen en sprinten veranderen niet."},
	"gear_pg_grip_plus":{"name":"Geharde slagbanden","sheet":"pg_gear","icon":1,"type":"gear","max":1,"slot":"hands","bonuses":{"technique_cost_reduction":0.20,"attack_cooldown_reduction":0.06},"desc":"20% minder techniekstamina en 6% kortere wachttijd tussen gewone zwaardaanvallen. Verbeterde slagbanden met zandsteen uit Dorstvallei."},
	"gear_pg_focus":{"name":"Richtlens","sheet":"pg_gear","icon":2,"type":"gear","max":1,"slot":"neck","bonuses":{"bow_preparation_reduction":0.15},"desc":"15% kortere voorbereiding van je precisieschot. Draag de lens in het halsvak; pijlschade en staminakosten blijven gelijk."},
	"gear_pg_focus_plus":{"name":"Heldere richtlens","sheet":"pg_gear","icon":3,"type":"gear","max":1,"slot":"neck","bonuses":{"bow_preparation_reduction":0.25,"stamina_regen":0.10},"desc":"25% kortere voorbereiding van precisieschoten en 10% sneller staminaherstel. Gebruikt ijskristal en watermunt na je onderzoek in het Rietarchief."},
	"gear_pg_pack":{"name":"Werkpak","sheet":"pg_gear","icon":4,"type":"gear","max":1,"slot":"chest","bonuses":{"harvest_time_reduction":0.15},"desc":"15% korter verzamelen met kruiden, bijl en pikhouweel. Een gevlochten werkpak voor ambachten; geeft geen pantser."},
	"gear_pg_pack_plus":{"name":"Bergwerkpak","sheet":"pg_gear","icon":5,"type":"gear","max":1,"slot":"chest","bonuses":{"harvest_time_reduction":0.25,"magnet_range":10.0},"desc":"25% korter verzamelen en 10 extra oppakbereik. Versterkt met dennenhout en wilgentwijgen na het vastzetten van de klimlijn; geeft geen pantser."},
}
