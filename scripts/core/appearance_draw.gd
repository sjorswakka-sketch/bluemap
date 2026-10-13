extends RefCounted
## Tekent haar, ogen en kleding over de kale basis-sprite van de speler (assets/player.png).
## Werkt op het 16x16-vak van de sprite: `origin` is de linkerbovenhoek in het canvas,
## `px` is de schaal (2.0 in de wereld, groter in de voorvertoning van het Uiterlijk-tabblad).
## `row` is de kijkrichting (0 onder, 1 boven, 2 rechts, 3 links) en `column` het stapframe (0, 1 of 2).

const Data := preload("res://scripts/data/ext/uiterlijk.gd")


static func behind(canvas: CanvasItem, origin: Vector2, px: float, row: int, clothing: Dictionary) -> void:
	# Rugkleding hangt achter het lijf.
	var back: Variant = clothing.get("back", {})
	if not back is Dictionary:
		return
	var item := str(back.get("item", ""))
	if item == "":
		return
	var dye: Color = Data.DYE_COLORS[clampi(int(back.get("dye", 0)), 0, Data.DYE_COLORS.size() - 1)]["color"]
	var shade := dye.darkened(0.3)
	var light := dye.lightened(0.2)
	match item:
		"cloth_cape":
			match row:
				0: # voor: alleen de punten langs de schouders zichtbaar
					_px(canvas, origin, px, 3, 8, 1, 4, dye)
					_px(canvas, origin, px, 12, 8, 1, 4, shade)
				1: # achter: de hele cape
					_px(canvas, origin, px, 3, 7, 10, 6, dye)
					_px(canvas, origin, px, 3, 12, 10, 1, shade)
					_px(canvas, origin, px, 3, 7, 1, 6, shade)
				_: # zijkant: hangt achter het lijf
					_px(canvas, origin, px, 3, 7, 2, 5, dye, row == 3)
					_px(canvas, origin, px, 3, 11, 2, 1, shade, row == 3)
		"cloth_cloak": # mantel met capuchon
			match row:
				0: # voor: schouderpunten en de rand van de capuchon naast het hoofd
					_px(canvas, origin, px, 3, 8, 1, 4, dye)
					_px(canvas, origin, px, 12, 8, 1, 4, shade)
					_px(canvas, origin, px, 4, 1, 1, 3, shade)
					_px(canvas, origin, px, 11, 1, 1, 3, shade)
				1: # achter: de hele mantel met een bult voor de capuchon
					_px(canvas, origin, px, 3, 7, 10, 6, dye)
					_px(canvas, origin, px, 3, 12, 10, 1, shade)
					_px(canvas, origin, px, 5, 2, 6, 5, dye)
					_px(canvas, origin, px, 5, 6, 6, 1, shade)
				_:
					_px(canvas, origin, px, 3, 7, 2, 5, dye, row == 3)
					_px(canvas, origin, px, 3, 11, 2, 1, shade, row == 3)
					_px(canvas, origin, px, 3, 2, 2, 4, dye, row == 3)
		"cloth_backpack": # rugzak: alleen van achteren en opzij zichtbaar
			match row:
				1:
					_px(canvas, origin, px, 5, 7, 6, 5, dye)
					_px(canvas, origin, px, 5, 7, 6, 2, light) # klep
					_px(canvas, origin, px, 7, 10, 2, 1, shade) # gesp
				2, 3:
					_px(canvas, origin, px, 2, 7, 3, 4, dye, row == 3)
					_px(canvas, origin, px, 2, 7, 3, 1, light, row == 3)


static func front(canvas: CanvasItem, origin: Vector2, px: float, row: int, column: int, appearance: Dictionary, clothing: Dictionary) -> void:
	_draw_clothing_body(canvas, origin, px, row, column, clothing)
	_draw_hair(canvas, origin, px, row, appearance)
	_draw_eyes(canvas, origin, px, row, appearance)
	_draw_hat(canvas, origin, px, row, clothing)


# --- Hulpmiddelen ---------------------------------------------------------------------------

static func _px(canvas: CanvasItem, origin: Vector2, px: float, x: int, y: int, w: int, h: int, color: Color, mirror := false) -> void:
	var rx := (16 - x - w) if mirror else x
	canvas.draw_rect(Rect2(origin + Vector2(rx, y) * px, Vector2(w, h) * px), color)


static func _hair_colors(appearance: Dictionary) -> Array:
	var index := clampi(int(appearance.get("hair_color", 2)), 0, Data.HAIR_COLORS.size() - 1)
	var base: Color = Data.HAIR_COLORS[index]["color"]
	return [base, base.darkened(0.3), base.lightened(0.2)]


static func _dye(entry: Variant) -> Color:
	if not entry is Dictionary:
		return Color.WHITE
	return Data.DYE_COLORS[clampi(int(entry.get("dye", 0)), 0, Data.DYE_COLORS.size() - 1)]["color"]


# --- Haar -----------------------------------------------------------------------------------

static func _draw_hair(canvas: CanvasItem, origin: Vector2, px: float, row: int, appearance: Dictionary) -> void:
	var gender := str(appearance.get("gender", "m"))
	var styles: Dictionary = Data.HAIR_V if gender == "v" else Data.HAIR_M
	var style: Dictionary = styles.get(str(appearance.get("hair", "")), {})
	if style.is_empty() or style.get("bald", false):
		return
	var colors := _hair_colors(appearance)
	var base: Color = colors[0]
	var shade: Color = colors[1]
	var light: Color = colors[2]
	var length := int(style.get("len", 1))
	var mirror := row == 3
	match row:
		0:
			_hair_front(canvas, origin, px, style, length, base, shade, light)
		1:
			_hair_back(canvas, origin, px, style, length, base, shade)
		_:
			_hair_side(canvas, origin, px, style, length, base, shade, mirror)


static func _hair_front(canvas: CanvasItem, origin: Vector2, px: float, style: Dictionary, length: int, base: Color, shade: Color, light: Color) -> void:
	# kap op het hoofd
	if length <= 0:
		_px(canvas, origin, px, 4, 1, 8, 1, shade) # stoppels
	else:
		_px(canvas, origin, px, 4, 1, 8, 3, base)
		_px(canvas, origin, px, 4, 3, 8, 1, shade)
		if length >= 2:
			_px(canvas, origin, px, 4, 4, 1, 3, base) # over de oren
			_px(canvas, origin, px, 11, 4, 1, 3, base)
		if length >= 3:
			_px(canvas, origin, px, 3, 7, 2, 4, base) # over de schouders
			_px(canvas, origin, px, 11, 7, 2, 4, base)
			_px(canvas, origin, px, 3, 10, 2, 1, shade)
			_px(canvas, origin, px, 11, 10, 2, 1, shade)
	# pony en varianten over het voorhoofd
	match int(style.get("bangs", 0)):
		1:
			_px(canvas, origin, px, 5, 4, 6, 1, base)
		2:
			_px(canvas, origin, px, 5, 4, 4, 1, base)
			_px(canvas, origin, px, 5, 5, 2, 1, base) # valt over één oog
		3:
			_px(canvas, origin, px, 5, 4, 2, 2, base)
			_px(canvas, origin, px, 9, 4, 2, 2, base)
	# kuif, mohawk of scheiding
	match int(style.get("top", 0)):
		1:
			_px(canvas, origin, px, 6, 0, 4, 1, light)
		2:
			_px(canvas, origin, px, 7, 0, 2, 4, light)
		3:
			_px(canvas, origin, px, 7, 1, 1, 3, shade)
	if style.get("vol", 0) != 0:
		_px(canvas, origin, px, 3, 2, 1, 3, base)
		_px(canvas, origin, px, 12, 2, 1, 3, base)
	if style.get("curl", false):
		for x: int in [4, 6, 8, 10, 12]:
			_px(canvas, origin, px, x, 0, 1, 1, base)
	if int(style.get("spiky", 0)) != 0:
		for x: int in [4, 7, 10, 13]:
			_px(canvas, origin, px, x, 0, 1, 2, base)
			_px(canvas, origin, px, x, 0, 1, 1, light)
	if style.get("bun", false):
		_px(canvas, origin, px, 3, 1, 1, 2, base)
		_px(canvas, origin, px, 12, 1, 1, 2, base)
	match int(style.get("tail", 0)):
		1:
			_px(canvas, origin, px, 12, 5, 1, 5, base)
			_px(canvas, origin, px, 12, 9, 1, 1, shade)
		2:
			for i: int in 5:
				_px(canvas, origin, px, 12, 5 + i, 1, 1, base if i % 2 == 0 else shade)
	if int(style.get("sidetail", 0)) != 0:
		_px(canvas, origin, px, 13, 4, 1, 4, base) # losse lok naast het gezicht
		_px(canvas, origin, px, 13, 8, 1, 1, shade)


static func _hair_back(canvas: CanvasItem, origin: Vector2, px: float, style: Dictionary, length: int, base: Color, shade: Color) -> void:
	if length <= 0:
		_px(canvas, origin, px, 4, 1, 8, 2, shade)
		return
	_px(canvas, origin, px, 4, 1, 8, 4, base)
	if length == 1:
		_px(canvas, origin, px, 4, 4, 8, 1, shade)
	elif length == 2:
		_px(canvas, origin, px, 4, 4, 8, 3, base)
		_px(canvas, origin, px, 4, 6, 8, 1, shade)
	else:
		_px(canvas, origin, px, 3, 1, 10, 9, base)
		_px(canvas, origin, px, 3, 9, 10, 1, shade)
	if int(style.get("top", 0)) == 2:
		_px(canvas, origin, px, 7, 0, 2, 4, base.lightened(0.2))
	if style.get("vol", 0) != 0:
		_px(canvas, origin, px, 2, 3, 1, 4, base)
		_px(canvas, origin, px, 13, 3, 1, 4, base)
	if style.get("bun", false):
		_px(canvas, origin, px, 6, 0, 4, 2, base)
		_px(canvas, origin, px, 6, 1, 4, 1, shade)
	match int(style.get("tail", 0)):
		1:
			_px(canvas, origin, px, 7, 7, 2, 5, base)
			_px(canvas, origin, px, 7, 11, 2, 1, shade)
		2:
			for i: int in 5:
				_px(canvas, origin, px, 7, 7 + i, 2, 1, base if i % 2 == 0 else shade)
	if style.get("curl", false):
		for x: int in [4, 6, 8, 10]:
			_px(canvas, origin, px, x, 5 if length < 3 else 10, 1, 1, shade)
	if int(style.get("spiky", 0)) != 0:
		for x: int in [4, 7, 10, 13]:
			_px(canvas, origin, px, x, 0, 1, 2, base)
	if int(style.get("sidetail", 0)) != 0:
		_px(canvas, origin, px, 13, 4, 1, 4, base)
		_px(canvas, origin, px, 13, 8, 1, 1, shade)


static func _hair_side(canvas: CanvasItem, origin: Vector2, px: float, style: Dictionary, length: int, base: Color, shade: Color, mirror: bool) -> void:
	# de neus wijst naar x=11; de achterkant van het hoofd zit bij x=4
	if length <= 0:
		_px(canvas, origin, px, 4, 1, 8, 2, shade, mirror)
		return
	_px(canvas, origin, px, 4, 1, 8, 3, base, mirror)
	_px(canvas, origin, px, 4, 4, 3, 3, base, mirror) # achterhoofd
	if length >= 2:
		_px(canvas, origin, px, 4, 6, 3, 3, base, mirror)
	if length >= 3:
		_px(canvas, origin, px, 3, 4, 3, 6, base, mirror)
		_px(canvas, origin, px, 3, 9, 3, 1, shade, mirror)
	match int(style.get("bangs", 0)):
		1:
			_px(canvas, origin, px, 7, 4, 4, 1, base, mirror)
		2:
			_px(canvas, origin, px, 7, 4, 3, 2, base, mirror)
		3:
			_px(canvas, origin, px, 7, 4, 2, 2, base, mirror)
			_px(canvas, origin, px, 10, 4, 2, 1, base, mirror)
	match int(style.get("top", 0)):
		1:
			_px(canvas, origin, px, 7, 0, 4, 1, base.lightened(0.2), mirror)
		2:
			_px(canvas, origin, px, 6, 0, 2, 4, base.lightened(0.2), mirror)
		3:
			_px(canvas, origin, px, 7, 1, 1, 3, shade, mirror)
	if style.get("vol", 0) != 0:
		_px(canvas, origin, px, 3, 2, 1, 4, base, mirror)
	if style.get("curl", false):
		for x: int in [5, 8, 11]:
			_px(canvas, origin, px, x, 0, 1, 1, base, mirror)
	if style.get("bun", false):
		_px(canvas, origin, px, 2, 2, 2, 2, base, mirror)
	match int(style.get("tail", 0)):
		1:
			_px(canvas, origin, px, 2, 5, 2, 5, base, mirror)
			_px(canvas, origin, px, 2, 9, 2, 1, shade, mirror)
		2:
			for i: int in 5:
				_px(canvas, origin, px, 2, 5 + i, 2, 1, base if i % 2 == 0 else shade, mirror)
	if int(style.get("spiky", 0)) != 0:
		for x: int in [5, 8, 11]:
			_px(canvas, origin, px, x, 0, 1, 2, base, mirror)
	if int(style.get("sidetail", 0)) != 0:
		_px(canvas, origin, px, 12, 4, 1, 5, base, mirror) # de lok hangt vóór het gezicht
		_px(canvas, origin, px, 12, 8, 1, 1, shade, mirror)


# --- Ogen -----------------------------------------------------------------------------------

static func _draw_eyes(canvas: CanvasItem, origin: Vector2, px: float, row: int, appearance: Dictionary) -> void:
	if row == 1: # van achteren zie je geen ogen
		return
	var style := str(appearance.get("eyes", "rond"))
	var color: Color = Data.EYE_COLORS[clampi(int(appearance.get("eye_color", 0)), 0, Data.EYE_COLORS.size() - 1)]["color"]
	var dark := Color("1c1c22")
	var white := Color("f4f2ec")
	var lash := Color("3a2a20")
	if row == 0:
		_eye_front(canvas, origin, px, style, color, dark, white, lash, 6, 6, false)
		_eye_front(canvas, origin, px, style, color, dark, white, lash, 9, 6, true)
	else:
		_eye_side(canvas, origin, px, style, color, dark, white, lash, 9, 5, row == 3)


## Eén oog op het vooraanzicht. `right_eye` bepaalt aan welke kant wimpers en wenkbrauwen zitten.
static func _eye_front(canvas: CanvasItem, origin: Vector2, px: float, style: String, color: Color, dark: Color, white: Color, lash: Color, x: int, y: int, right_eye: bool) -> void:
	match style:
		"rond":
			_px(canvas, origin, px, x, y, 1, 1, color)
		"stip":
			_px(canvas, origin, px, x, y, 1, 1, dark)
		"groot":
			_px(canvas, origin, px, x, y - 1, 1, 2, color)
		"wimpers":
			_px(canvas, origin, px, x, y, 1, 1, color)
			_px(canvas, origin, px, x + (1 if right_eye else -1), y - 1, 1, 1, lash)
		"knipoog":
			if right_eye:
				_px(canvas, origin, px, x - 1, y, 2, 1, dark) # geknipogd: een streepje
			else:
				_px(canvas, origin, px, x, y, 1, 1, color)
		"slaperig":
			_px(canvas, origin, px, x, y, 1, 1, color)
			_px(canvas, origin, px, x, y - 1, 1, 1, Color("dba57c")) # zwaar ooglid
		"boos":
			_px(canvas, origin, px, x, y, 1, 1, color)
			_px(canvas, origin, px, x + (-1 if right_eye else 1), y - 1, 1, 1, lash) # schuine wenkbrauw naar binnen
		"sterretjes":
			_px(canvas, origin, px, x, y, 1, 1, color)
			_px(canvas, origin, px, x - 1, y - 1, 1, 1, white)
			_px(canvas, origin, px, x + 1, y + 1, 1, 1, white)
		"vonkel":
			_px(canvas, origin, px, x, y, 1, 1, color)
			_px(canvas, origin, px, x, y - 1, 1, 1, white)
		"vriendelijk":
			_px(canvas, origin, px, x, y, 1, 1, color)
			_px(canvas, origin, px, x, y - 1, 1, 1, Color("e8c9a0")) # zachte wenkbrauw
		"dicht": # blij dichtgeknepen: een lachend boogje
			_px(canvas, origin, px, x, y, 1, 1, dark)
			_px(canvas, origin, px, x + (1 if right_eye else -1), y - 1, 1, 1, dark)
		"smal": # gefocust: donker ooglid erover
			_px(canvas, origin, px, x, y, 1, 1, color)
			_px(canvas, origin, px, x, y - 1, 1, 1, dark)
		"ovaal":
			_px(canvas, origin, px, x, y - 1, 1, 2, color)
			_px(canvas, origin, px, x, y - 1, 1, 1, white)
		"wijs": # halve oogleden met een grijze wenkbrauw erboven
			_px(canvas, origin, px, x, y, 1, 1, color)
			_px(canvas, origin, px, x, y - 2, 1, 1, Color("c8c8ce"))
		"straler": # twee glinsteringen boven het oog
			_px(canvas, origin, px, x, y, 1, 1, color)
			_px(canvas, origin, px, x - 1, y - 1, 1, 1, white)
			_px(canvas, origin, px, x + 1, y - 1, 1, 1, white)
		"dromerig": # glinstering schuin naar buiten
			_px(canvas, origin, px, x, y, 1, 1, color)
			_px(canvas, origin, px, x + (1 if right_eye else -1), y - 1, 1, 1, white)


static func _eye_side(canvas: CanvasItem, origin: Vector2, px: float, style: String, color: Color, dark: Color, white: Color, lash: Color, x: int, y: int, mirror: bool) -> void:
	match style:
		"stip":
			_px(canvas, origin, px, x, y, 1, 1, dark, mirror)
		"groot":
			_px(canvas, origin, px, x, y - 1, 1, 2, color, mirror)
		"wimpers":
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)
			_px(canvas, origin, px, x + 1, y - 1, 1, 1, lash, mirror)
		"knipoog":
			_px(canvas, origin, px, x - 1, y, 2, 1, dark, mirror)
		"slaperig":
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)
			_px(canvas, origin, px, x, y - 1, 1, 1, Color("dba57c"), mirror)
		"boos":
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)
			_px(canvas, origin, px, x + 1, y - 1, 1, 1, lash, mirror)
		"sterretjes":
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)
			_px(canvas, origin, px, x - 1, y - 1, 1, 1, white, mirror)
		"vonkel":
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)
			_px(canvas, origin, px, x, y - 1, 1, 1, white, mirror)
		"vriendelijk":
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)
			_px(canvas, origin, px, x, y - 1, 1, 1, Color("e8c9a0"), mirror)
		"dicht":
			_px(canvas, origin, px, x, y, 1, 1, dark, mirror)
			_px(canvas, origin, px, x - 1, y - 1, 2, 1, dark, mirror)
		"smal":
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)
			_px(canvas, origin, px, x, y - 1, 1, 1, dark, mirror)
		"ovaal":
			_px(canvas, origin, px, x, y - 1, 1, 2, color, mirror)
			_px(canvas, origin, px, x, y - 1, 1, 1, white, mirror)
		"wijs":
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)
			_px(canvas, origin, px, x, y - 2, 1, 1, Color("c8c8ce"), mirror)
		"straler":
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)
			_px(canvas, origin, px, x - 1, y - 1, 1, 1, white, mirror)
			_px(canvas, origin, px, x + 1, y - 1, 1, 1, white, mirror)
		"dromerig":
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)
			_px(canvas, origin, px, x + 1, y - 1, 1, 1, white, mirror)
		_:
			_px(canvas, origin, px, x, y, 1, 1, color, mirror)


# --- Kleding --------------------------------------------------------------------------------

static func _draw_hat(canvas: CanvasItem, origin: Vector2, px: float, row: int, clothing: Dictionary) -> void:
	var entry: Variant = clothing.get("hat", {})
	if not entry is Dictionary or str(entry.get("item", "")) == "":
		return
	var item := str(entry["item"])
	var dye := _dye(entry)
	var shade := dye.darkened(0.3)
	var light := dye.lightened(0.2)
	var mirror := row == 3
	match item:
		"cloth_straw_hat":
			if row == 1:
				_px(canvas, origin, px, 2, 2, 12, 2, dye)
				_px(canvas, origin, px, 5, 0, 6, 2, dye)
				_px(canvas, origin, px, 5, 1, 6, 1, light)
			else:
				_px(canvas, origin, px, 2, 2, 12, 1, dye, mirror)
				_px(canvas, origin, px, 2, 3, 12, 1, shade, mirror)
				_px(canvas, origin, px, 5, 0, 6, 2, dye, mirror)
				_px(canvas, origin, px, 5, 0, 6, 1, light, mirror)
		"cloth_beret":
			_px(canvas, origin, px, 4, 0, 8, 2, dye, mirror)
			_px(canvas, origin, px, 3, 1, 6, 1, dye, mirror) # schuin gekapt
			_px(canvas, origin, px, 9, 0, 1, 1, shade, mirror) # steeltje
		"cloth_beanie":
			_px(canvas, origin, px, 4, 0, 8, 3, dye, mirror)
			_px(canvas, origin, px, 4, 2, 8, 1, shade, mirror) # omgeslagen rand
			_px(canvas, origin, px, 7, 0, 2, 1, light, mirror) # pompon
		"cloth_headband":
			_px(canvas, origin, px, 4, 3, 8, 1, dye, mirror) # band over de haargrens
			if row == 1:
				_px(canvas, origin, px, 7, 3, 2, 1, shade) # knoop achter
			elif row == 0:
				_px(canvas, origin, px, 11, 2, 1, 2, shade) # knoop opzij
			else:
				_px(canvas, origin, px, 4, 2, 1, 2, shade, mirror) # knoop achterop
		"cloth_felt_hat": # hogere bol dan de strohoed, met een lint
			if row == 1:
				_px(canvas, origin, px, 2, 3, 12, 1, dye)
				_px(canvas, origin, px, 5, 0, 6, 3, dye)
				_px(canvas, origin, px, 5, 2, 6, 1, shade)
			else:
				_px(canvas, origin, px, 2, 3, 12, 1, dye, mirror)
				_px(canvas, origin, px, 2, 4, 12, 1, shade, mirror)
				_px(canvas, origin, px, 5, 0, 6, 3, dye, mirror)
				_px(canvas, origin, px, 5, 2, 6, 1, shade, mirror) # lint
		"cloth_nightcap": # slappe muts die naar één kant afhangt
			_px(canvas, origin, px, 4, 0, 8, 2, dye, mirror)
			_px(canvas, origin, px, 4, 2, 8, 1, shade, mirror) # rand
			if mirror:
				_px(canvas, origin, px, 11, 1, 2, 3, dye)
				_px(canvas, origin, px, 12, 4, 1, 1, light) # pompon aan het puntje
			else:
				_px(canvas, origin, px, 3, 1, 2, 3, dye)
				_px(canvas, origin, px, 3, 4, 1, 1, light)
	if row == 0 and item == "cloth_beret":
		_px(canvas, origin, px, 4, 2, 4, 1, shade)


static func _draw_clothing_body(canvas: CanvasItem, origin: Vector2, px: float, row: int, column: int, clothing: Dictionary) -> void:
	var mirror := row == 3
	# rug: sjaal, rugzakbanden of mantelsluiting (de cape en de mantel zelf zitten in behind())
	var back: Variant = clothing.get("back", {})
	if back is Dictionary:
		var back_item := str(back.get("item", ""))
		match back_item:
			"cloth_scarf":
				var scarf := _dye(back)
				var scarf_shade := scarf.darkened(0.3)
				match row:
					0:
						_px(canvas, origin, px, 5, 7, 6, 1, scarf)
						_px(canvas, origin, px, 5, 8, 6, 1, scarf_shade)
						_px(canvas, origin, px, 9, 9, 1, 3, scarf) # losse punt
					1:
						_px(canvas, origin, px, 5, 7, 6, 1, scarf)
						_px(canvas, origin, px, 5, 8, 6, 1, scarf_shade)
					_:
						_px(canvas, origin, px, 6, 7, 5, 1, scarf, mirror)
						_px(canvas, origin, px, 4, 8, 1, 2, scarf_shade, mirror)
			"cloth_backpack":
				var pack := _dye(back)
				var pack_shade := pack.darkened(0.3)
				match row:
					0: # schouderbanden over het lijf
						_px(canvas, origin, px, 5, 7, 1, 3, pack)
						_px(canvas, origin, px, 10, 7, 1, 3, pack_shade)
					_:
						_px(canvas, origin, px, 6, 7, 1, 3, pack, mirror)
			"cloth_cloak":
				var cloak := _dye(back)
				if row == 0: # kraag en sluiting aan de voorkant
					_px(canvas, origin, px, 5, 7, 6, 1, cloak)
					_px(canvas, origin, px, 7, 7, 2, 1, cloak.lightened(0.3))
	# bovenlijf
	var top: Variant = clothing.get("top", {})
	if top is Dictionary and str(top.get("item", "")) != "":
		var dye := _dye(top)
		var shade := dye.darkened(0.3)
		var light := dye.lightened(0.25)
		var item := str(top["item"])
		if row == 2 or row == 3:
			_px(canvas, origin, px, 5, 8, 6, 3, dye, mirror)
			_px(canvas, origin, px, 10, 8, 1, 3, shade, mirror)
			_px(canvas, origin, px, 7, 9, 2, 1, light, mirror)
			if item == "cloth_dress": # de rok van de jurk valt over de benen
				_px(canvas, origin, px, 4, 11, 7, 2, dye, mirror)
				_px(canvas, origin, px, 4, 12, 7, 1, shade, mirror)
		else:
			_px(canvas, origin, px, 4, 8, 8, 3, dye)
			_px(canvas, origin, px, 3, 8, 1, 2, dye) # mouwen
			_px(canvas, origin, px, 12, 8, 1, 2, dye)
			_px(canvas, origin, px, 11, 8, 2, 3, shade) # schaduwkant
			match item:
				"cloth_tunic":
					_px(canvas, origin, px, 5, 8, 2, 1, light)
				"cloth_blouse":
					_px(canvas, origin, px, 7, 8, 2, 1, light) # kraagje
					_px(canvas, origin, px, 7, 9, 1, 1, shade) # knoopje
				"cloth_shirt":
					_px(canvas, origin, px, 6, 8, 4, 1, light) # kraag
					_px(canvas, origin, px, 5, 9, 1, 1, shade) # borstzak
				"cloth_sweater":
					_px(canvas, origin, px, 6, 8, 4, 1, light) # opstaande kraag
					_px(canvas, origin, px, 4, 10, 8, 1, shade) # gebreide boord
				"cloth_vest":
					_px(canvas, origin, px, 7, 8, 2, 3, shade) # opengevallen midden
					_px(canvas, origin, px, 6, 8, 1, 3, light) # revers
					_px(canvas, origin, px, 9, 8, 1, 3, light)
				"cloth_dress":
					_px(canvas, origin, px, 4, 10, 8, 1, light) # tailleband
					_px(canvas, origin, px, 4, 11, 8, 2, dye) # wijde rok
					_px(canvas, origin, px, 4, 12, 8, 1, shade)
	# onderlijf
	var bottom: Variant = clothing.get("bottom", {})
	if bottom is Dictionary and str(bottom.get("item", "")) != "":
		var dye := _dye(bottom)
		var shade := dye.darkened(0.3)
		var light := dye.lightened(0.25)
		var bottom_item := str(bottom["item"])
		if bottom_item == "cloth_skirt":
			if row == 2 or row == 3:
				_px(canvas, origin, px, 4, 11, 7, 3, dye, mirror)
				_px(canvas, origin, px, 4, 13, 7, 1, shade, mirror)
			else:
				_px(canvas, origin, px, 4, 11, 8, 3, dye)
				_px(canvas, origin, px, 4, 13, 8, 1, shade)
		elif bottom_item == "cloth_shorts": # korte pijpen: één rij hoog
			if row == 2 or row == 3:
				var short_back: Vector2i = Vector2i(6, 7) if column == 0 else (Vector2i(5, 6) if column == 1 else Vector2i(7, 8))
				var short_front: Vector2i = Vector2i(8, 9) if column == 0 else (Vector2i(9, 10) if column == 1 else Vector2i(7, 8))
				_px(canvas, origin, px, short_back.x, 12, short_back.y - short_back.x + 1, 1, shade, mirror)
				_px(canvas, origin, px, short_front.x, 12, short_front.y - short_front.x + 1, 1, dye, mirror)
			else:
				_px(canvas, origin, px, 5, 12, 2, 1, dye)
				_px(canvas, origin, px, 9, 12, 2, 1, dye)
		else: # broek volgt de benen, ook tijdens een stap
			var left_up := column == 1
			var right_up := column == 2
			if row == 2 or row == 3:
				var back_leg: Vector2i = Vector2i(6, 7) if column == 0 else (Vector2i(5, 6) if column == 1 else Vector2i(7, 8))
				var front_leg: Vector2i = Vector2i(8, 9) if column == 0 else (Vector2i(9, 10) if column == 1 else Vector2i(7, 8))
				_px(canvas, origin, px, back_leg.x, 12, back_leg.y - back_leg.x + 1, 2, shade, mirror)
				_px(canvas, origin, px, front_leg.x, 12, front_leg.y - front_leg.x + 1, 2, dye, mirror)
				if bottom_item == "cloth_overalls":
					_px(canvas, origin, px, front_leg.x + 1, 12, 1, 1, light, mirror) # knielap
			else:
				_px(canvas, origin, px, 5, 12, 2, 1 if left_up else 2, dye)
				_px(canvas, origin, px, 9, 12, 2, 1 if right_up else 2, dye)
				if bottom_item == "cloth_overalls":
					_px(canvas, origin, px, 5, 12, 1, 1, light) # knielappen
					_px(canvas, origin, px, 9, 12, 1, 1, light)
	# voeten
	var feet: Variant = clothing.get("feet", {})
	if feet is Dictionary and str(feet.get("item", "")) != "":
		var dye := _dye(feet)
		var shade := dye.darkened(0.3)
		var feet_item := str(feet["item"])
		if row == 2 or row == 3:
			var back_foot: Vector2i = Vector2i(6, 7) if column == 0 else (Vector2i(5, 6) if column == 1 else Vector2i(7, 8))
			var front_foot: Vector2i = Vector2i(8, 9) if column == 0 else (Vector2i(9, 10) if column == 1 else Vector2i(7, 8))
			if feet_item == "cloth_boots": # hoge schacht
				_px(canvas, origin, px, back_foot.x, 12 if column == 2 else 13, back_foot.y - back_foot.x + 1, 2, shade, mirror)
				_px(canvas, origin, px, front_foot.x, 13, front_foot.y - front_foot.x + 1, 2, dye, mirror)
			elif feet_item == "cloth_sandals": # alleen een zool met een bandje
				_px(canvas, origin, px, back_foot.x, 13 if column == 2 else 14, back_foot.y - back_foot.x + 1, 1, shade, mirror)
				_px(canvas, origin, px, front_foot.x, 14, front_foot.y - front_foot.x + 1, 1, dye, mirror)
				_px(canvas, origin, px, front_foot.x, 13, 1, 1, dye.lightened(0.3), mirror)
			else:
				_px(canvas, origin, px, back_foot.x, 13 if column == 2 else 14, back_foot.y - back_foot.x + 1, 1, shade, mirror)
				_px(canvas, origin, px, front_foot.x, 14, front_foot.y - front_foot.x + 1, 1, dye, mirror)
		else:
			var left_up := column == 1
			var right_up := column == 2
			if feet_item == "cloth_boots":
				_px(canvas, origin, px, 5, 12 if left_up else 13, 2, 2, dye)
				_px(canvas, origin, px, 9, 12 if right_up else 13, 2, 2, dye)
				_px(canvas, origin, px, 5, 13 if left_up else 14, 2, 1, shade) # zool
				_px(canvas, origin, px, 9, 13 if right_up else 14, 2, 1, shade)
			elif feet_item == "cloth_sandals":
				_px(canvas, origin, px, 5, 13 if left_up else 14, 2, 1, dye)
				_px(canvas, origin, px, 9, 13 if right_up else 14, 2, 1, dye)
				_px(canvas, origin, px, 5, 12 if left_up else 13, 1, 1, dye.lightened(0.3)) # bandje
				_px(canvas, origin, px, 9, 12 if right_up else 13, 1, 1, dye.lightened(0.3))
			else:
				_px(canvas, origin, px, 5, 13 if left_up else 14, 2, 1, dye)
				_px(canvas, origin, px, 9, 13 if right_up else 14, 2, 1, dye)
				if feet_item == "cloth_slippers":
					_px(canvas, origin, px, 5, 13 if left_up else 14, 1, 1, dye.lightened(0.3))
					_px(canvas, origin, px, 9, 13 if right_up else 14, 1, 1, dye.lightened(0.3))
				else:
					_px(canvas, origin, px, 6, 13 if left_up else 14, 1, 1, shade)
					_px(canvas, origin, px, 10, 13 if right_up else 14, 1, 1, shade)
