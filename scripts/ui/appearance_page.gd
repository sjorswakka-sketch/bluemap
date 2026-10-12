extends Control
## Het tabblad Uiterlijk: geslacht, haarstijl en -kleur, ogen, en kleding over je uitrusting.
## Bladeren verandert niets; links/rechts past de gekozen rij meteen aan, met voorvertoning links.
## Op een kledingrij opent bevestigen de verfkleuren (links/rechts kiest, bevestigen is klaar).

const Appearance := preload("res://scripts/core/appearance.gd")
const AppearanceDraw := preload("res://scripts/core/appearance_draw.gd")
const Data := preload("res://scripts/data/ext/uiterlijk.gd")
const Items := preload("res://scripts/data/items.gd")
const Art := preload("res://scripts/core/art.gd")
const GOLD := Color(1.0, 0.88, 0.4)
const BLUE := Color(0.65, 0.85, 1.0)
const ROWS := 10 # geslacht, haar, haarkleur, ogen, oogkleur + vijf kledingvakken
const ROW_TOP := 30.0
const ROW_HEIGHT := 40.0
const ROW_X := 330.0
const ROW_W := 612.0
const SWATCH := 18.0

signal close_requested

var selected := 0
var dye_mode := false # verfkleur aan het kiezen voor de huidige kledingrij
var time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gui_input.connect(_pointer_input)
	GameState.appearance_changed.connect(queue_redraw)
	GameState.items_changed.connect(queue_redraw)
	Lang.changed.connect(func(_locale: String) -> void: queue_redraw())
	Controls.device_changed.connect(func(_pad: bool) -> void: queue_redraw())


func _process(delta: float) -> void:
	time += delta
	if visible:
		queue_redraw() # de voorvertoning beweegt zachtjes


func row_rect(index: int) -> Rect2:
	return Rect2(ROW_X, ROW_TOP + index * ROW_HEIGHT, ROW_W, ROW_HEIGHT - 4)


func slot_of_row(index: int) -> String:
	return Appearance.SLOTS.keys()[index - 5] if index >= 5 else ""


func cloth_options(slot: String) -> Array[String]:
	var result: Array[String] = [""]
	result.append_array(Appearance.owned_in_slot(slot))
	return result


func _hair_ids() -> Array:
	return Appearance.hair_styles(str(GameState.appearance.get("gender", "m"))).keys()


func _eye_ids() -> Array:
	return Data.EYES.keys()


func navigate(action: String) -> void:
	if action in ["ui_up", "ui_down"]:
		selected = clampi(selected + (1 if action == "ui_down" else -1), 0, ROWS - 1)
		dye_mode = false
		return
	var step := 1 if action == "ui_right" else -1
	if dye_mode and selected >= 5:
		var entry := Appearance.worn(slot_of_row(selected))
		if not entry.is_empty():
			Appearance.dye(slot_of_row(selected), posmod(int(entry.get("dye", 0)) + step, Data.DYE_COLORS.size()))
		return
	match selected:
		0:
			Appearance.set_gender("v" if str(GameState.appearance.get("gender", "m")) == "m" else "m")
		1:
			_cycle(_hair_ids(), str(GameState.appearance.get("hair", "")), step, Appearance.set_hair)
		2:
			Appearance.set_hair_color(posmod(int(GameState.appearance.get("hair_color", 0)) + step, Data.HAIR_COLORS.size()))
		3:
			_cycle(_eye_ids(), str(GameState.appearance.get("eyes", "")), step, Appearance.set_eyes)
		4:
			Appearance.set_eye_color(posmod(int(GameState.appearance.get("eye_color", 0)) + step, Data.EYE_COLORS.size()))
		_:
			var slot := slot_of_row(selected)
			var options := cloth_options(slot)
			var worn := str(Appearance.worn(slot).get("item", ""))
			var next := options[posmod(options.find(worn) + step, options.size())]
			if next == "":
				Appearance.unwear(slot)
			else:
				Appearance.wear(next)


func _cycle(ids: Array, current: String, step: int, setter: Callable) -> void:
	if ids.is_empty():
		return
	setter.call(ids[posmod(ids.find(current) + step, ids.size())])


func confirm() -> void:
	if selected >= 5 and not Appearance.worn(slot_of_row(selected)).is_empty():
		dye_mode = not dye_mode
		Sound.play("select", -6.0)
	elif selected < 5:
		navigate("ui_right")


func _pointer_input(event: InputEvent) -> void:
	if Controls.controller_active or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		close_requested.emit()
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	for index in ROWS:
		var rect := row_rect(index)
		if not rect.has_point(event.position):
			continue
		selected = index
		dye_mode = false
		var left_arrow := Rect2(rect.position + Vector2(rect.size.x - 96, 4), Vector2(28, 28))
		var right_arrow := Rect2(rect.position + Vector2(rect.size.x - 34, 4), Vector2(28, 28))
		if left_arrow.has_point(event.position):
			navigate("ui_left")
		elif right_arrow.has_point(event.position):
			navigate("ui_right")
		elif event.double_click:
			confirm()
		accept_event()
		return
	if dye_mode and selected >= 5:
		for index in Data.DYE_COLORS.size():
			if _swatch_rect(index).has_point(event.position):
				Appearance.dye(slot_of_row(selected), index)
				accept_event()
				return


func _swatch_rect(index: int) -> Rect2:
	var row := row_rect(selected)
	return Rect2(ROW_X + 20 + index * (SWATCH + 6), row.end.y + 6, SWATCH, SWATCH)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	_text(Vector2(0, 24), tr("Uiterlijk en kleding"), 24, GOLD)
	_text(Vector2(ROW_X, 24), tr("Kleding draag je over je uitrusting; verf kies je per stuk."), 17, BLUE)
	_draw_preview()
	for index in ROWS:
		_draw_row(font, index)
	if dye_mode and selected >= 5:
		_draw_swatches(font)


func _draw_preview() -> void:
	var panel := Rect2(16, 40, 286, 350)
	draw_rect(panel, Color(0.09, 0.14, 0.26))
	draw_rect(panel, Color(0.3, 0.45, 0.7), false, 2.0)
	var appearance: Dictionary = GameState.appearance
	var clothing: Dictionary = GameState.clothing
	# drie gezichten: voor, achter en opzij
	for i in 3:
		var row: int = [0, 1, 2][i]
		var center := panel.position + Vector2(52 + i * 94, 130)
		var scale := 5.0
		var origin := center - Vector2(16, 16) * scale / 2.0 + Vector2(0, sin(time * 2.4) * 1.5)
		var source := Rect2(Vector2(0, row * 16), Vector2(16, 16))
		AppearanceDraw.behind(self, origin, scale, row, clothing)
		draw_texture_rect_region(Art.tex("player"), Rect2(origin, Vector2(16, 16) * scale), source)
		AppearanceDraw.front(self, origin, scale, row, 0, appearance, clothing)
	# haarkleur-staafje als kleine legenda
	var hair_color: Color = Data.HAIR_COLORS[clampi(int(appearance.get("hair_color", 2)), 0, Data.HAIR_COLORS.size() - 1)]["color"]
	draw_rect(Rect2(panel.position + Vector2(20, panel.size.y - 40), Vector2(20, 20)), hair_color)
	draw_rect(Rect2(panel.position + Vector2(20, panel.size.y - 40), Vector2(20, 20)), Color(1, 1, 1, 0.4), false, 1.0)
	_text(panel.position + Vector2(50, panel.size.y - 24), tr("Haarkleur"), 16, BLUE)
	var eye_color: Color = Data.EYE_COLORS[clampi(int(appearance.get("eye_color", 0)), 0, Data.EYE_COLORS.size() - 1)]["color"]
	draw_rect(Rect2(panel.position + Vector2(160, panel.size.y - 40), Vector2(20, 20)), eye_color)
	draw_rect(Rect2(panel.position + Vector2(160, panel.size.y - 40), Vector2(20, 20)), Color(1, 1, 1, 0.4), false, 1.0)
	_text(panel.position + Vector2(190, panel.size.y - 24), tr("Oogkleur"), 16, BLUE)


func _draw_row(font: Font, index: int) -> void:
	var rect := row_rect(index)
	var active := index == selected
	draw_rect(rect, Color(0.17, 0.27, 0.43) if active else Color(0.1, 0.16, 0.28))
	if active:
		draw_rect(rect, GOLD, false, 2.0)
	var label := ""
	var value := ""
	match index:
		0:
			label = tr("Geslacht")
			value = tr(Data.GENDERS[str(GameState.appearance.get("gender", "m"))]["name"])
		1:
			var ids := _hair_ids()
			var hair := str(GameState.appearance.get("hair", ""))
			label = tr("Haarstijl")
			value = "%s  (%d/%d)" % [tr(Appearance.hair_styles(str(GameState.appearance.get("gender", "m"))).get(hair, {"name": "?"})["name"]), ids.find(hair) + 1, ids.size()]
		2:
			label = tr("Haarkleur")
			value = tr(Data.HAIR_COLORS[clampi(int(GameState.appearance.get("hair_color", 0)), 0, Data.HAIR_COLORS.size() - 1)]["name"])
		3:
			var ids := _eye_ids()
			var eyes := str(GameState.appearance.get("eyes", ""))
			label = tr("Oogstijl")
			value = "%s  (%d/%d)" % [tr(Data.EYES.get(eyes, {"name": "?"})["name"]), ids.find(eyes) + 1, ids.size()]
		4:
			label = tr("Oogkleur")
			value = tr(Data.EYE_COLORS[clampi(int(GameState.appearance.get("eye_color", 0)), 0, Data.EYE_COLORS.size() - 1)]["name"])
		_:
			var slot := slot_of_row(index)
			label = tr(Appearance.SLOTS[slot]["name"])
			var worn := Appearance.worn(slot)
			if worn.is_empty():
				var options := cloth_options(slot)
				value = tr("Niets in bezit") if options.size() <= 1 else tr("Niets aan")
			else:
				var dye_index := clampi(int(worn.get("dye", 0)), 0, Data.DYE_COLORS.size() - 1)
				value = "%s  ·  %s" % [tr(Items.info(str(worn["item"]))["name"]), tr(Data.DYE_COLORS[dye_index]["name"])]
				var swatch := Rect2(rect.position + Vector2(rect.size.x - 132, 9), Vector2(18, 18))
				draw_rect(swatch, Data.DYE_COLORS[dye_index]["color"])
				draw_rect(swatch, Color(1, 1, 1, 0.5), false, 1.0)
	_text(rect.position + Vector2(14, 24), label, 18, BLUE)
	_text(rect.position + Vector2(180, 24), value, 18, Color.WHITE)
	# pijltjes
	var arrows := rect.position + Vector2(rect.size.x - 96, 0)
	_text(arrows + Vector2(4, 26), "‹", 22, GOLD if active else Color(0.5, 0.6, 0.75))
	_text(arrows + Vector2(66, 26), "›", 22, GOLD if active else Color(0.5, 0.6, 0.75))


func _draw_swatches(font: Font) -> void:
	var row := row_rect(selected)
	_text(Vector2(ROW_X, row.end.y + 2), tr("Verf:"), 16, BLUE)
	var worn := Appearance.worn(slot_of_row(selected))
	var current := clampi(int(worn.get("dye", 0)), 0, Data.DYE_COLORS.size() - 1)
	for index in Data.DYE_COLORS.size():
		var rect := _swatch_rect(index)
		draw_rect(rect, Data.DYE_COLORS[index]["color"])
		draw_rect(rect, GOLD if index == current else Color(1, 1, 1, 0.35), false, 2.0 if index == current else 1.0)
	var name_pos := Vector2(ROW_X + 20, row.end.y + 6 + SWATCH + 22)
	_text(name_pos, tr(Data.DYE_COLORS[current]["name"]), 17, Color.WHITE)


func _text(at: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
