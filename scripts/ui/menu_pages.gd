extends RefCounted
## De tekeningen van de tabbladen Prestaties en Beestenboek en van het lijstje voor snel reizen op het kaarttabblad.
## Het menu zelf (tabbladen, toetsen en de selectie) staat in scripts/ui/menu_ui.gd; dat geeft zichzelf mee als `menu`.
## Dit zijn statische functies: tekst gaat hier door TranslationServer.translate() (net als tr() in een node).

const Art := preload("res://scripts/core/art.gd")
const Items := preload("res://scripts/data/items.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const Achievements := preload("res://scripts/data/achievements.gd")
const FastTravel := preload("res://scripts/core/fast_travel.gd")

const SIZE := Vector2(1000, 560) # zoals in menu_ui.gd
const LIST_TOP := 108.0
const LIST_BOTTOM := 500.0
const ACHIEVEMENT_ROW := 56.0
const BEAST_ROW := 46.0

const GOLD := Color(1.0, 0.9, 0.5)
const DIM := Color(0.55, 0.62, 0.8)
const PANEL := Color(0.1, 0.16, 0.3)
const FRAME := Color(0.3, 0.45, 0.7)
const SILHOUETTE := Color(0.03, 0.05, 0.12) # een beest dat je nog niet kent: alleen de vorm

## Voorwaarden die een teller in GameState zijn (met dezelfde naam). Daarvan tonen we de voortgang: "(12 / 50)".
const COUNTERS := ["kills", "rolls", "potions_drunk"]

## Hoe vaak een voorwerp valt, in woorden (kans vanaf, woord). De woorden voor in beeld staan in _chance_text().
const CHANCE_WORDS: Array = [[0.95, "altijd"], [0.4, "vaak"], [0.15, "soms"], [0.0, "zelden"]]


## Tekent (eventueel afgebroken) tekst en geeft de hoogte terug.
static func text(canvas: Control, font: Font, pos: Vector2, label: String, size: int, color := Color.WHITE, width := -1.0) -> float:
	canvas.draw_multiline_string(font, pos + Vector2(0, size), label, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, color)
	return font.get_multiline_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, width, size).y


## Houdt het gekozen rijtje van een lange lijst in beeld: geeft de nieuwe bovenste rij terug.
static func follow(selected: int, scroll: int, visible: int, total: int) -> int:
	scroll = clampi(scroll, maxi(selected - visible + 1, 0), selected)
	return clampi(scroll, 0, maxi(total - visible, 0))


## Een dunne schuifbalk rechts van een lijst, alleen als er meer is dan in beeld past.
static func scrollbar(canvas: Control, scroll: int, visible: int, total: int, x: float) -> void:
	if total <= visible:
		return
	var height := LIST_BOTTOM - LIST_TOP
	canvas.draw_rect(Rect2(x, LIST_TOP, 6, height), Color(0.1, 0.16, 0.3))
	var thumb := height * float(visible) / float(total)
	var top := LIST_TOP + (height - thumb) * float(scroll) / float(total - visible)
	canvas.draw_rect(Rect2(x, top, 6, thumb), Color(0.6, 0.85, 1.0))


static func _header(canvas: Control, font: Font, title: String, right: String) -> void:
	text(canvas, font, Vector2(24, 72), title, 24, Color(0.6, 0.88, 1.0))
	var width := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	text(canvas, font, Vector2(SIZE.x - 24 - width, 74), right, 20, GOLD)


static func _trophy(canvas: Control, pos: Vector2, size: float, frame: int) -> void:
	canvas.draw_texture_rect_region(Art.tex("wereld_ui"), Rect2(pos, Vector2(size, size)), Rect2(Vector2(frame * 16, 0), Vector2(16, 16)))


# --- Prestaties ---------------------------------------------------------------------------------

static func draw_achievements(menu: Node, font: Font) -> void:
	var canvas: Control = menu.page
	var ids: Array = Achievements.ACHIEVEMENTS.keys()
	var visible := int((LIST_BOTTOM - LIST_TOP) / ACHIEVEMENT_ROW)
	menu.achievement_selected = clampi(menu.achievement_selected, 0, maxi(ids.size() - 1, 0))
	menu.achievement_scroll = follow(menu.achievement_selected, menu.achievement_scroll, visible, ids.size())
	var heading := TranslationServer.translate("Prestaties")
	_header(canvas, font, heading, TranslationServer.translate("%d / %d behaald") % [Achievements.count_owned(GameState.achievements), ids.size()])
	var title_width := font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	text(canvas, font, Vector2(24 + title_width + 16, 79), TranslationServer.translate("Die houd je, ook als je een nieuw spel begint."), 16, DIM)
	var width := SIZE.x - 48.0 - (14.0 if ids.size() > visible else 0.0)
	for row in visible:
		var index: int = menu.achievement_scroll + row
		if index >= ids.size():
			break
		var def := Achievements.info(ids[index])
		var done := GameState.achievements.has(ids[index])
		var secret: bool = def.get("secret", false) and not done
		var rect := Rect2(24, LIST_TOP + row * ACHIEVEMENT_ROW, width, ACHIEVEMENT_ROW - 6)
		var chosen: bool = index == menu.achievement_selected
		canvas.draw_rect(rect, Color(0.18, 0.3, 0.55) if chosen else PANEL)
		canvas.draw_rect(rect, Color(1.0, 0.88, 0.35) if chosen else FRAME, false, 3.0 if chosen else 2.0)
		_trophy(canvas, rect.position + Vector2(8, 5), 40.0, 3 if done else 5 if secret else 4)
		var title: String = TranslationServer.translate(def["name"]) if not secret else "???"
		var desc: String = TranslationServer.translate(def["desc"]) if not secret else TranslationServer.translate("Een geheime prestatie. Blijf het spel ontdekken!")
		if not done and not secret:
			desc += progress(def.get("if", []))
		text(canvas, font, rect.position + Vector2(62, 3), title, 21, GOLD if done else Color(0.75, 0.8, 0.92) if not secret else DIM)
		text(canvas, font, rect.position + Vector2(62, 27), desc, 16, Color(0.9, 0.95, 1.0) if done else Color(0.62, 0.7, 0.88), width - 80.0)
		if done:
			text(canvas, font, rect.position + Vector2(width - 24, 12), "✓", 24, Color(0.55, 1.0, 0.65))
	scrollbar(canvas, menu.achievement_scroll, visible, ids.size(), SIZE.x - 30.0)


## Hoe ver je bent met een tellerprestatie, bijvoorbeeld "  (12 / 50)". Leeg als er niets te tellen valt.
static func progress(conditions: Array) -> String:
	for cond: Array in conditions:
		if cond[0] in COUNTERS:
			var goal := int(cond[1])
			return "  (%d / %d)" % [mini(int(GameState.get(cond[0])), goal), goal]
	return ""


# --- Beestenboek ---------------------------------------------------------------------------------

static func is_known(kind: String) -> bool:
	return int(GameState.kills_by.get(kind, 0)) > 0


## Teken het eerste plaatje van een vijand (het stilstaande vakje linksboven) in een vierkant van `box` pixels.
static func _enemy_sprite(canvas: Control, kind: String, center: Vector2, box: float, tint: Color) -> void:
	var data: Dictionary = Enemies.info(kind)
	var cell: float = data["cell"]
	var scale := maxf(floorf(box / cell), 1.0) if cell <= box else box / cell
	var size := cell * scale
	canvas.draw_texture_rect_region(Art.tex(data["sheet"]), Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size)), Rect2(Vector2.ZERO, Vector2(cell, cell)), tint)


static func draw_bestiary(menu: Node, font: Font) -> void:
	var canvas: Control = menu.page
	var kinds: Array = Enemies.ENEMIES.keys()
	var visible := int((LIST_BOTTOM - LIST_TOP) / BEAST_ROW)
	menu.bestiary_selected = clampi(menu.bestiary_selected, 0, maxi(kinds.size() - 1, 0))
	menu.bestiary_scroll = follow(menu.bestiary_selected, menu.bestiary_scroll, visible, kinds.size())
	var known := 0
	for kind: String in kinds:
		if is_known(kind):
			known += 1
	_header(canvas, font, TranslationServer.translate("Beestenboek"), TranslationServer.translate("%d / %d ontdekt") % [known, kinds.size()])
	for row in visible:
		var index: int = menu.bestiary_scroll + row
		if index >= kinds.size():
			break
		var kind: String = kinds[index]
		var rect := Rect2(24, LIST_TOP + row * BEAST_ROW, 300, BEAST_ROW - 4)
		var chosen: bool = index == menu.bestiary_selected
		canvas.draw_rect(rect, Color(0.18, 0.3, 0.55) if chosen else PANEL)
		canvas.draw_rect(rect, Color(1.0, 0.88, 0.35) if chosen else FRAME, false, 3.0 if chosen else 2.0)
		_enemy_sprite(canvas, kind, rect.position + Vector2(24, rect.size.y / 2.0), 32.0, Color.WHITE if is_known(kind) else SILHOUETTE)
		var label: String = TranslationServer.translate(Enemies.info(kind)["name"]) if is_known(kind) else "???"
		text(canvas, font, rect.position + Vector2(52, 7), label, 20, Color.WHITE if is_known(kind) else DIM)
		if is_known(kind):
			var count := "x%d" % int(GameState.kills_by[kind])
			var count_width := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			text(canvas, font, rect.position + Vector2(rect.size.x - count_width - 10, 9), count, 18, GOLD)
	scrollbar(canvas, menu.bestiary_scroll, visible, kinds.size(), 332.0)
	if not kinds.is_empty():
		_draw_beast_detail(canvas, font, kinds[menu.bestiary_selected])


static func _draw_beast_detail(canvas: Control, font: Font, kind: String) -> void:
	var data: Dictionary = Enemies.info(kind)
	var known := is_known(kind)
	var left := 368.0
	var width := SIZE.x - left - 24.0
	# Het grote plaatje (of alleen de vorm van een beest dat je nog niet kent).
	var frame := Rect2(left, LIST_TOP, 156, 156)
	canvas.draw_rect(frame, Color(0.05, 0.09, 0.2) if known else Color(0.16, 0.23, 0.42))
	canvas.draw_rect(frame, FRAME, false, 2.0)
	_enemy_sprite(canvas, kind, frame.get_center(), 144.0, Color.WHITE if known else SILHOUETTE)
	var x := left + 176.0
	if not known:
		text(canvas, font, Vector2(x, LIST_TOP), "???", 28, DIM)
		text(canvas, font, Vector2(x, LIST_TOP + 44), TranslationServer.translate("Dit beest ken je nog niet.\nVersla hem één keer, dan komt hij in je boek te staan!"), 19, Color(0.75, 0.82, 0.95), width - 176.0)
		return
	var y := LIST_TOP
	y += text(canvas, font, Vector2(x, y), TranslationServer.translate(data["name"]), 28, GOLD) + 4
	if data.get("boss", false):
		y += text(canvas, font, Vector2(x, y), TranslationServer.translate("Baas"), 18, Color(1.0, 0.55, 0.55)) + 2
	var stats := [
		TranslationServer.translate("Levens:  %d") % int(data["hp"]),
		TranslationServer.translate("Schade:  %s") % _damage_text(data),
		TranslationServer.translate("Verslagen:  %d") % int(GameState.kills_by.get(kind, 0)),
	]
	for line: String in stats:
		y += text(canvas, font, Vector2(x, y + 4), line, 20, Color(0.88, 0.94, 1.0)) + 4
	# Wat hij laat vallen.
	var drops_y := LIST_TOP + 172.0
	text(canvas, font, Vector2(left, drops_y), TranslationServer.translate("Laat vallen"), 20, Color(0.6, 0.88, 1.0))
	var drops: Array = data.get("drops", [])
	if drops.is_empty():
		text(canvas, font, Vector2(left + 8, drops_y + 28), TranslationServer.translate("Niets."), 18, Color(0.8, 0.86, 0.98))
	for i in drops.size():
		var drop: Array = drops[i]
		var pos := Vector2(left + 8 + (i % 2) * 300, drops_y + 30 + floori(i / 2.0) * 32)
		_draw_drop_icon(canvas, drop[0], pos)
		text(canvas, font, pos + Vector2(32, 3), _drop_text(drop), 18, Color(0.88, 0.94, 1.0))
	# De grappige beschrijving; ontbreekt die, dan tonen we niets.
	var desc: String = data.get("desc", "")
	if desc != "":
		var desc_y := drops_y + 30 + maxi(ceili(drops.size() / 2.0), 1) * 32 + 14.0 # minstens een regel ("Niets.")
		canvas.draw_line(Vector2(left, desc_y - 6), Vector2(left + width, desc_y - 6), FRAME, 2.0)
		text(canvas, font, Vector2(left, desc_y + 4), TranslationServer.translate(desc), 19, Color(0.95, 0.93, 0.8), width)


## Hoeveel schade een vijand doet: "1 hartje", "2 hartjes", en bij een klap "1 hartje (klap: 2)".
static func _damage_text(data: Dictionary) -> String:
	var damage := int(data.get("damage", 1))
	var label := TranslationServer.translate_plural("%d hartje", "%d hartjes", damage) % damage
	if data.has("slam_damage"):
		# Vertalers: schade van een vijand, met die van zijn klap: "1 hartje (klap: 2)"
		label = TranslationServer.translate("%s (klap: %d)") % [label, int(data["slam_damage"])]
	return label


## Wat een vijand laat vallen, met een woord voor de kans: "Munt x2 (altijd)".
static func _drop_text(drop: Array) -> String:
	var item: String = drop[0]
	var label: String = TranslationServer.translate("Hartje") if item == "heart" else TranslationServer.translate(Items.info(item)["name"])
	if int(drop[2]) > 1:
		label += " x%d" % int(drop[2])
	for entry: Array in CHANCE_WORDS:
		if float(drop[1]) >= entry[0]:
			# Vertalers: wat een vijand laat vallen en hoe vaak: "Slijmgel (vaak)"
			return TranslationServer.translate("%s (%s)") % [label, _chance_text(entry[1])]
	return label


## Het woord voor een kans (zie CHANCE_WORDS) in de taal van de speler.
static func _chance_text(word: String) -> String:
	match word:
		"altijd":
			# Vertalers: hoe vaak een vijand iets laat vallen (altijd, vaak, soms, zelden)
			return TranslationServer.translate("altijd")
		"vaak":
			return TranslationServer.translate("vaak")
		"soms":
			return TranslationServer.translate("soms")
		"zelden":
			return TranslationServer.translate("zelden")
	return word


static func _draw_drop_icon(canvas: Control, item: String, pos: Vector2) -> void:
	if item == "heart":
		canvas.draw_texture_rect_region(Art.tex("ui_heart"), Rect2(pos + Vector2(3, 2), Vector2(26, 24)), Rect2(0, 0, 13, 12))
	else:
		canvas.draw_texture_rect(Items.icon_tex(item), Rect2(pos, Vector2(28, 28)), false)


# --- Snel reizen (op het kaarttabblad) ---------------------------------------------------------------

## Rechts naast de kaart: de ontdekte altaren, met een vraag om te bevestigen als je er een gekozen hebt.
static func draw_travel_panel(menu: Node, font: Font, altars: Array) -> void:
	var canvas: Control = menu.page
	var left := 660.0
	var width := SIZE.x - left - 24.0
	text(canvas, font, Vector2(left, 66), TranslationServer.translate("Snel reizen"), 24, Color(0.6, 0.88, 1.0))
	if altars.is_empty():
		text(canvas, font, Vector2(left, 106), TranslationServer.translate("Je hebt nog geen blauw altaar ontdekt. Gebruik een altaar, dan kun je er later snel naartoe reizen."), 18, Color(0.8, 0.86, 0.98), width)
		return
	menu.travel_selected = clampi(menu.travel_selected, 0, altars.size() - 1)
	for i in altars.size():
		var altar: Dictionary = altars[i]
		var rect := Rect2(left, 104 + i * 48.0, width, 42)
		var chosen: bool = i == menu.travel_selected
		canvas.draw_rect(rect, Color(0.18, 0.3, 0.55) if chosen else PANEL)
		canvas.draw_rect(rect, Color(1.0, 0.88, 0.35) if chosen else FRAME, false, 3.0 if chosen else 2.0)
		canvas.draw_texture_rect_region(Art.tex("wereld_ui"), Rect2(rect.position + Vector2(8, 5), Vector2(32, 32)), Rect2(Vector2(6 * 16, 0), Vector2(16, 16)))
		text(canvas, font, rect.position + Vector2(50, 8), TranslationServer.translate(altar["name"]), 20, Color.WHITE)
		if altar["map"] == GameState.map_id:
			# Vertalers: in de lijst voor snel reizen achter het altaar in het gebied waar je nu bent
			var here := TranslationServer.translate("hier")
			var here_width := font.get_string_size(here, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			text(canvas, font, rect.position + Vector2(rect.size.x - here_width - 10, 12), here, 16, DIM)
	var box_y := 104 + altars.size() * 48.0 + 12.0
	if menu.travel_confirm:
		var altar: Dictionary = altars[menu.travel_selected]
		var box := Rect2(left, box_y, width, 110) # ruimte voor een naam over twee regels
		canvas.draw_rect(box, Color(0.2, 0.18, 0.06))
		canvas.draw_rect(box, Color(1.0, 0.85, 0.3), false, 3.0)
		text(canvas, font, box.position + Vector2(12, 8), TranslationServer.translate("Reizen naar %s?") % TranslationServer.translate(in_sentence(altar["name"])), 20, GOLD, width - 24.0)
		canvas.draw_rect(Rect2(box.position + Vector2(12, 70), Vector2(142, 32)), Color(0.15, 0.36, 0.28))
		canvas.draw_rect(Rect2(box.position + Vector2(166, 70), Vector2(138, 32)), Color(0.3, 0.24, 0.25))
		text(canvas, font, box.position + Vector2(20, 74), TranslationServer.translate("%s  Reizen") % Controls.action_label("ui_accept"), 17, Color.WHITE)
		text(canvas, font, box.position + Vector2(174, 74), TranslationServer.translate("%s  Terug") % Controls.action_label("ui_cancel"), 17, Color.WHITE)
	elif menu.travel_message != "":
		text(canvas, font, Vector2(left, box_y), menu.travel_message, 18, Color(1.0, 0.65, 0.55), width)


## Een kaartnaam midden in een zin: "De Vergeten Ruïne" wordt "de Vergeten Ruïne". Dat is Nederlandse grammatica, dus
## dit werkt op de Nederlandse naam; de vertaling van "de Vergeten Ruïne" is een eigen tekst in de vertaling (de
## extractie neemt de vorm midden in de zin van elke kaartnaam op).
static func in_sentence(map_name: String) -> String:
	for article: String in ["De ", "Het "]:
		if map_name.begins_with(article):
			return article.to_lower() + map_name.substr(article.length())
	return map_name
