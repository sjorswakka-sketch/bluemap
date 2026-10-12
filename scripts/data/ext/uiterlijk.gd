extends RefCounted
## Uiterlijk: kleding over je uitrusting heen, haarstijlen, ogen en verf.
## Puur visueel: kleding geeft geen bonussen (dat blijft bij uitrusting.gd).
## De renderer staat in scripts/core/appearance_draw.gd, de staat in scripts/core/appearance.gd.
##
## Kleding heeft vijf eigen vakken (CLOTHING_SLOTS) naast de vijf uitrustingsvakken.
## Elk kledingstuk kan in de verf: de speler kiest per gedragen stuk een kleur uit DYE_COLORS.
##
## Haarstijlen zijn parametrisch: de renderer tekent ze uit deze velden:
##   bald  - helemaal kaal
##   len   - 0 stoppels, 1 kort, 2 middel (bedekt de oren), 3 lang (over de schouders)
##   bangs - 0 geen, 1 pony, 2 zijpony (valt over één oog), 3 gordijntjes
##   top   - 0 vlak, 1 kuif, 2 mohawk, 3 scheiding
##   tail  - 0 geen, 1 staart, 2 vlecht
##   bun   - knotje op het achterhoofd
##   curl  - krullende rand
##   vol   - extra volume aan de zijkanten

const GENDERS := {
	"m": {"name": "Man"},
	"v": {"name": "Vrouw"},
}

const HAIR_M := {
	"m_kaal": {"name": "Kaal", "bald": true},
	"m_buzz": {"name": "Buzz cut", "len": 0},
	"m_kort": {"name": "Kort", "len": 1},
	"m_kort_kuif": {"name": "Kort met kuif", "len": 1, "top": 1},
	"m_kuif": {"name": "Hoge kuif", "len": 1, "top": 1, "vol": 1},
	"m_mohawk": {"name": "Mohawk", "len": 1, "top": 2},
	"m_mohawk_lang": {"name": "Lange mohawk", "len": 2, "top": 2},
	"m_scheiding": {"name": "Scheiding", "len": 1, "top": 3},
	"m_scheiding_lang": {"name": "Scheiding met lengte", "len": 2, "top": 3},
	"m_krullen": {"name": "Krullen", "len": 1, "curl": true},
	"m_krullen_lang": {"name": "Lange krullen", "len": 3, "curl": true},
	"m_bos": {"name": "Wilderbos", "len": 2, "vol": 1, "curl": true},
	"m_staart": {"name": "Staart", "len": 2, "tail": 1},
	"m_staart_lang": {"name": "Lange staart", "len": 3, "tail": 1},
	"m_vlecht": {"name": "Vlecht", "len": 3, "tail": 2},
	"m_knot": {"name": "Manenknot", "len": 2, "bun": true},
	"m_lang": {"name": "Lang haar", "len": 3},
	"m_lang_vol": {"name": "Vol lang haar", "len": 3, "vol": 1},
	"m_pony": {"name": "Pony", "len": 1, "bangs": 1},
	"m_pony_lang": {"name": "Pony met lengte", "len": 3, "bangs": 1},
	"m_zijpony": {"name": "Zijpony", "len": 2, "bangs": 2, "top": 3},
	"m_gordijn": {"name": "Gordijntjes", "len": 2, "bangs": 3},
	"m_krul_kuif": {"name": "Krullende kuif", "len": 1, "curl": true, "top": 1},
	"m_halflang": {"name": "Halflang", "len": 2},
	"m_halflang_vol": {"name": "Vol halflang", "len": 2, "vol": 1},
	"m_knot_kort": {"name": "Knotje", "len": 1, "bun": true},
	"m_vlecht_kort": {"name": "Korte vlecht", "len": 2, "tail": 2},
	"m_golvend": {"name": "Golvend", "len": 2, "curl": true, "top": 3},
	"m_dreads": {"name": "Dreads", "len": 3, "tail": 1, "vol": 1},
	"m_emopony": {"name": "Emopony", "len": 2, "bangs": 2, "vol": 1},
}

const HAIR_V := {
	"v_bob": {"name": "Bob", "len": 2, "bangs": 1},
	"v_bob_krul": {"name": "Krullende bob", "len": 2, "bangs": 1, "curl": true},
	"v_pixie": {"name": "Pixie", "len": 1, "vol": 1},
	"v_pixie_kuif": {"name": "Pixie met kuif", "len": 1, "top": 1},
	"v_lang": {"name": "Lang", "len": 3},
	"v_lang_pony": {"name": "Lang met pony", "len": 3, "bangs": 1},
	"v_staart": {"name": "Staart", "len": 3, "tail": 1},
	"v_staart_vol": {"name": "Volle staart", "len": 2, "tail": 1, "vol": 1},
	"v_vlecht": {"name": "Vlecht", "len": 3, "tail": 2},
	"v_vlechtjes": {"name": "Dubbele vlecht", "len": 2, "tail": 2, "vol": 1},
	"v_knot": {"name": "Knot", "len": 2, "bun": true},
	"v_knot_lang": {"name": "Knot met lengte", "len": 3, "bun": true},
	"v_krullen": {"name": "Krullen", "len": 2, "curl": true},
	"v_krullen_lang": {"name": "Lange krullen", "len": 3, "curl": true},
	"v_golvend": {"name": "Golvend", "len": 3, "curl": true, "top": 3},
	"v_gordijn": {"name": "Gordijntjes", "len": 2, "bangs": 3},
	"v_gordijn_lang": {"name": "Lange gordijntjes", "len": 3, "bangs": 3},
	"v_zijpony": {"name": "Zijpony", "len": 3, "bangs": 2},
	"v_halflang": {"name": "Halflang", "len": 2},
	"v_halflang_vol": {"name": "Vol halflang", "len": 2, "vol": 1},
	"v_bob_lang": {"name": "Lange bob", "len": 2, "vol": 1, "bangs": 1},
	"v_afro": {"name": "Afro", "len": 1, "vol": 1, "curl": true},
	"v_knotjes": {"name": "Dubbele knotjes", "len": 2, "bun": true, "vol": 1},
	"v_kroonvlecht": {"name": "Kroonvlecht", "len": 2, "tail": 2, "top": 3},
	"v_kort": {"name": "Kort", "len": 1},
	"v_kort_pony": {"name": "Kort met pony", "len": 1, "bangs": 1},
	"v_mohawk": {"name": "Mohawk", "len": 1, "top": 2},
	"v_krulstaart": {"name": "Krulstaart", "len": 3, "tail": 1, "curl": true},
	"v_emopony": {"name": "Emopony", "len": 2, "bangs": 2, "vol": 1},
	"v_kaal": {"name": "Kaal", "bald": true},
}

const HAIR_COLORS := [
	{"name": "Zwart", "color": Color("1e1a16")},
	{"name": "Donkerbruin", "color": Color("3a2414")},
	{"name": "Bruin", "color": Color("7a4a24")},
	{"name": "Kastanje", "color": Color("9a5a2e")},
	{"name": "Koper", "color": Color("b56a30")},
	{"name": "Rood", "color": Color("a03828")},
	{"name": "Blond", "color": Color("dcb86a")},
	{"name": "Goudblond", "color": Color("f0d080")},
	{"name": "Grijs", "color": Color("a8a8ae")},
	{"name": "Wit", "color": Color("ece8e0")},
]

## Oogstijlen: de renderer tekent ze op de vaste oogplekken van de kale basis-sprite.
const EYES := {
	"rond": {"name": "Rond"},
	"stip": {"name": "Stip"},
	"groot": {"name": "Groot"},
	"wimpers": {"name": "Wimpers"},
	"knipoog": {"name": "Knipoog"},
	"slaperig": {"name": "Slaperig"},
	"boos": {"name": "Boos"},
	"sterretjes": {"name": "Sterretjes"},
	"vonkel": {"name": "Vonkel"},
	"vriendelijk": {"name": "Vriendelijk"},
}

const EYE_COLORS := [
	{"name": "Bruin", "color": Color("5a3a1c")},
	{"name": "Blauw", "color": Color("3a6ac8")},
	{"name": "Groen", "color": Color("3a8a4a")},
	{"name": "Grijs", "color": Color("8a929e")},
	{"name": "Hazelnoot", "color": Color("8a6a3a")},
	{"name": "Amber", "color": Color("c8862a")},
	{"name": "Violet", "color": Color("7a4ab0")},
	{"name": "Zwart", "color": Color("1c1c22")},
]

const CLOTHING_SLOTS := {
	"hat": {"name": "Hoofd", "desc": "Hoeden en mutsen boven je haar."},
	"back": {"name": "Rug", "desc": "Capes en sjals over je schouders."},
	"top": {"name": "Bovenlijf", "desc": "Tunieken, blouses en hemden over je harnas."},
	"bottom": {"name": "Onderlijf", "desc": "Broeken en rokken."},
	"feet": {"name": "Voeten", "desc": "Schoenen en sloffen."},
}

## Verfkleuren voor kleding: de speler kiest er per gedragen stuk één.
const DYE_COLORS := [
	{"name": "Rood", "color": Color("c04040")},
	{"name": "Oranje", "color": Color("d07830")},
	{"name": "Geel", "color": Color("d8b83a")},
	{"name": "Groen", "color": Color("4a8a4a")},
	{"name": "Mosgroen", "color": Color("6a7a3a")},
	{"name": "Blauw", "color": Color("3a6ac8")},
	{"name": "Marine", "color": Color("2e3a64")},
	{"name": "Paars", "color": Color("7a4a8a")},
	{"name": "Roze", "color": Color("d87a9a")},
	{"name": "Bruin", "color": Color("8a6238")},
	{"name": "Wit", "color": Color("e8e4da")},
	{"name": "Zwart", "color": Color("2a2a32")},
]

## De kledingstukken zelf. "type": "cloth" en "slot" verwijst naar CLOTHING_SLOTS.
## Pictogrammen 31 t/m 42 op de items_beroepen-sheet (zie tools/art_x_beroepen.py).
const ITEMS := {
	"cloth_straw_hat": {"name": "Strohoed", "sheet": "items_beroepen", "icon": 31, "type": "cloth", "max": 1, "slot": "hat", "desc": "Een zonnehoed van gevlochten stro. Puur voor de look; draag hem over je uitrusting."},
	"cloth_beret": {"name": "Baret", "sheet": "items_beroepen", "icon": 32, "type": "cloth", "max": 1, "slot": "hat", "desc": "Een kunstzinnige baret, schuin op je hoofd. Puur voor de look; draag hem over je uitrusting."},
	"cloth_beanie": {"name": "Muts", "sheet": "items_beroepen", "icon": 33, "type": "cloth", "max": 1, "slot": "hat", "desc": "Een warme gebreide muts met pompon. Puur voor de look; draag hem over je uitrusting."},
	"cloth_cape": {"name": "Cape", "sheet": "items_beroepen", "icon": 34, "type": "cloth", "max": 1, "slot": "back", "desc": "Een wapperende cape voor over je schouders. Puur voor de look; draag hem over je uitrusting."},
	"cloth_scarf": {"name": "Sjaal", "sheet": "items_beroepen", "icon": 35, "type": "cloth", "max": 1, "slot": "back", "desc": "Een zachte sjaal met een losse punt. Puur voor de look; draag hem over je uitrusting."},
	"cloth_tunic": {"name": "Tuniek", "sheet": "items_beroepen", "icon": 36, "type": "cloth", "max": 1, "slot": "top", "desc": "Een ruimvallende tuniek met ceintuur. Puur voor de look; draag hem over je uitrusting."},
	"cloth_blouse": {"name": "Blouse", "sheet": "items_beroepen", "icon": 37, "type": "cloth", "max": 1, "slot": "top", "desc": "Een fijne blouse met knoopjes. Puur voor de look; draag hem over je uitrusting."},
	"cloth_shirt": {"name": "Hemd", "sheet": "items_beroepen", "icon": 38, "type": "cloth", "max": 1, "slot": "top", "desc": "Een stevig hemd met kraag. Puur voor de look; draag hem over je uitrusting."},
	"cloth_trousers": {"name": "Broek", "sheet": "items_beroepen", "icon": 39, "type": "cloth", "max": 1, "slot": "bottom", "desc": "Een nette broek met stevige pijpen. Puur voor de look; draag hem over je uitrusting."},
	"cloth_skirt": {"name": "Rok", "sheet": "items_beroepen", "icon": 40, "type": "cloth", "max": 1, "slot": "bottom", "desc": "Een zwierige rok tot over de knieën. Puur voor de look; draag hem over je uitrusting."},
	"cloth_shoes": {"name": "Schoenen", "sheet": "items_beroepen", "icon": 41, "type": "cloth", "max": 1, "slot": "feet", "desc": "Stevige leren schoenen. Puur voor de look; draag ze over je uitrusting."},
	"cloth_slippers": {"name": "Sloffen", "sheet": "items_beroepen", "icon": 42, "type": "cloth", "max": 1, "slot": "feet", "desc": "Zachte sloffen met een bontje. Puur voor de look; draag ze over je uitrusting."},
}

## Vera de kleermaakster verkoopt de hele collectie in Dageraadsdorp.
const NPCS := {
	"vera": {
		"name": "Vera de kleermaakster", "sheet": "npc_mila",
		"rules": [
			{"if": [["no_flag", "vera_ontmoet"]], "talk": "vera_intro"},
			{"talk": "vera_menu"},
		],
	},
}

const TALKS := {
	"vera_intro": {
		"speaker": "Vera",
		"lines": [
			"Ah, een nieuw gezicht! Ik ben Vera, kleermaakster van Dageraadsdorp.",
			"Ik maak kleding die je gewoon óver je uitrusting draagt. Geen gedoe met omkleden: het gaat er zo overheen.",
			"En met mijn verfpotten maak je elk stuk in de kleur die jij mooi vindt. Kijk maar in het tabblad Uiterlijk van je menu!",
		],
		"do": [["set_flag", "vera_ontmoet"]],
		"next": "vera_menu",
	},
	"vera_menu": {
		"speaker": "Vera",
		"lines": ["Zeg het maar, mag het een beetje kleur zijn?"],
		"choices": [
			{"text": "Ik wil kleding kopen.", "do": [["shop", "vera"]]},
			{"text": "Hoe werkt het verven?", "next": "vera_verf"},
			{"text": "Tot ziens."},
		],
	},
	"vera_verf": {
		"speaker": "Vera",
		"lines": [
			"Open je menu en ga naar het tabblad Uiterlijk. Daar trek je een kledingstuk aan en kies je er een verfkleur bij.",
			"Je haar en je ogen kun je daar trouwens ook helemaal veranderen. Dertig kapsels! Ik knip ze allemaal zelf.",
		],
		"next": "vera_menu",
	},
}

const SHOPS := {
	"vera": {
		"name": "Vera's Kleerkast",
		"items": [
			{"item": "cloth_straw_hat", "price": 20, "once": true},
			{"item": "cloth_beret", "price": 30, "once": true},
			{"item": "cloth_beanie", "price": 30, "once": true},
			{"item": "cloth_cape", "price": 60, "once": true},
			{"item": "cloth_scarf", "price": 35, "once": true},
			{"item": "cloth_tunic", "price": 40, "once": true},
			{"item": "cloth_blouse", "price": 45, "once": true},
			{"item": "cloth_shirt", "price": 45, "once": true},
			{"item": "cloth_trousers", "price": 40, "once": true},
			{"item": "cloth_skirt", "price": 40, "once": true},
			{"item": "cloth_shoes", "price": 30, "once": true},
			{"item": "cloth_slippers", "price": 25, "once": true},
		],
	},
}
