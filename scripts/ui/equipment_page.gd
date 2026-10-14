extends Control
## Browsing is read-only. Only the explicit equip/remove action changes equipment.

const Equipment := preload("res://scripts/core/equipment.gd")
const Items := preload("res://scripts/data/items.gd")
const Recipes := preload("res://scripts/data/ext/beroepen.gd")
const Shops := preload("res://scripts/data/shops.gd")
const Art := preload("res://scripts/core/art.gd")
const GOLD := Color(1.0, 0.88, 0.4)
const BLUE := Color(0.65, 0.85, 1.0)
const EQUIP_RECT := Rect2(344, 386, 292, 42)
const REMOVE_RECT := Rect2(650, 386, 302, 42)
const PREV_RECT := Rect2(844,18,28,28)
const NEXT_RECT := Rect2(924,18,28,28)

signal close_requested

var selected_slot := 0
var selected_item := 0
var zone := 0 # slots, alternatives, action buttons
var action_index := 0 # equip, remove
var detail: RichTextLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail = RichTextLabel.new()
	detail.position = Vector2(354, 198)
	detail.size = Vector2(588, 178)
	detail.focus_mode = Control.FOCUS_NONE
	detail.scroll_active = false
	detail.add_theme_font_size_override("normal_font_size", 17)
	detail.add_theme_color_override("default_color", Color(0.86, 0.92, 1.0))
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail)
	gui_input.connect(_pointer_input)
	GameState.items_changed.connect(refresh)
	GameState.equipment_changed.connect(refresh)
	Lang.changed.connect(func(_locale: String) -> void: refresh())
	Controls.device_changed.connect(func(_pad: bool) -> void: queue_redraw())
	Controls.bindings_changed.connect(queue_redraw)
	refresh()


func slots() -> Array[String]:
	var result: Array[String] = []
	for id: String in Equipment.SLOTS:
		result.append(id)
	result.append_array(["weapon", "boots"])
	return result


func slot_id() -> String:
	return slots()[selected_slot]


func alternatives() -> Array[String]:
	var result: Array[String] = []
	for id: String in Items.ITEMS:
		if Equipment.slot_of(id) == slot_id():
			result.append(id)
	return result


func current_item(slot: String) -> String:
	if slot == "weapon":
		return Items.WEAPONS[GameState.weapon]["item"]
	if slot == "boots":
		return "boots" if GameState.count("boots") > 0 else ""
	return Equipment.equipped(slot)


func candidate() -> String:
	var options := alternatives()
	return "" if options.is_empty() else options[clampi(selected_item, 0, options.size() - 1)]


func select_slot(index: int) -> void:
	selected_slot = clampi(index, 0, slots().size() - 1)
	selected_item = 0
	var options := alternatives()
	var current := current_item(slot_id())
	if current in options:
		selected_item = options.find(current)
	zone = 0
	refresh()


func refresh() -> void:
	if detail == null:
		return
	selected_item = clampi(selected_item, 0, maxi(alternatives().size() - 1, 0))
	detail.text = detail_text()
	_fit_detail.call_deferred()
	queue_redraw()

func _fit_detail() -> void:
	if not is_instance_valid(detail): return
	for font_size in range(17,14,-1):
		detail.add_theme_font_size_override("normal_font_size",font_size)
		if detail.get_content_height() <= detail.size.y: break


func navigate(action: String) -> void:
	var down := action in ["ui_down", "ui_right"]
	if zone == 0:
		if action in ["ui_up", "ui_down"]:
			select_slot(selected_slot + (1 if down else -1))
		elif action == "ui_right" and not alternatives().is_empty():
			zone = 1
	elif zone == 1:
		if action == "ui_left":
			zone = 0
		elif action == "ui_right" or (action == "ui_down" and selected_item == alternatives().size() - 1):
			zone = 2
			action_index = 0
		elif action in ["ui_up", "ui_down"]:
			selected_item = clampi(selected_item + (1 if down else -1), 0, alternatives().size() - 1)
	else:
		if action == "ui_up":
			zone = 1
		elif action == "ui_left":
			if action_index == 0:
				zone = 0
			else:
				action_index = 0
		elif action in ["ui_right", "ui_down"]:
			action_index = 1
	refresh()


func confirm() -> void:
	if alternatives().is_empty():
		return
	if zone == 0:
		zone = 1
	elif zone == 1:
		zone = 2 # show the explicit action before committing a choice
		action_index = 0
	else:
		apply_action(action_index)
	queue_redraw()


func can_equip() -> bool:
	return candidate() != "" and GameState.count(candidate()) > 0 and Equipment.equipped(slot_id()) != candidate()


func can_remove() -> bool:
	return Equipment.SLOTS.has(slot_id()) and Equipment.equipped(slot_id()) != ""


func apply_action(action: int) -> void:
	var changed := false
	if action == 0 and can_equip():
		changed = Equipment.equip(candidate())
	elif action == 1 and can_remove():
		changed = Equipment.unequip(slot_id())
	if changed:
		Sound.play("select", -4.0)
	refresh()


func _pointer_input(event: InputEvent) -> void:
	if Controls.controller_active or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		close_requested.emit()
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if alternatives().size() > 2 and (PREV_RECT.has_point(event.position) or NEXT_RECT.has_point(event.position)):
		selected_item = clampi(selected_item+(-2 if PREV_RECT.has_point(event.position) else 2),0,alternatives().size()-1)
		zone = 1
		refresh(); accept_event(); return
	for index in slots().size():
		if slot_rect(index).has_point(event.position):
			select_slot(index)
			accept_event()
			return
	for index in visible_indices():
		if item_rect(index).has_point(event.position):
			selected_item = index
			zone = 1
			refresh()
			accept_event()
			return
	if EQUIP_RECT.has_point(event.position) or REMOVE_RECT.has_point(event.position):
		zone = 2
		action_index = 0 if EQUIP_RECT.has_point(event.position) else 1
		apply_action(action_index)
		accept_event()


func slot_rect(index: int) -> Rect2:
	return Rect2(0, 62 + index * 52, 326, 48)


func item_rect(index: int) -> Rect2:
	return Rect2(344, 62 + (index-(selected_item/2)*2) * 65, 608, 59)

func visible_indices() -> Array[int]:
	var result: Array[int] = []
	var first := (selected_item/2)*2
	for index in range(first,mini(first+2,alternatives().size())): result.append(index)
	return result


func _draw() -> void:
	_text(Vector2(0, 24), tr("Uitrusting kiezen"), 24, GOLD)
	_text(Vector2(0, 48), tr("Vijf verwisselbare plekken; zwaard en laarzen werken automatisch."), 17, BLUE)
	for index in slots().size():
		var id: String = slots()[index]
		var rect := slot_rect(index)
		_box(rect, index == selected_slot, zone == 0 and index == selected_slot)
		var item := current_item(id)
		_icon(item, rect.position + Vector2(8, 8))
		var title := tr("Zwaard") if id == "weapon" else tr("Laarzen") if id == "boots" else tr(Equipment.SLOTS[id]["name"])
		_text(rect.position + Vector2(50, 19), title, 17, BLUE)
		_text(rect.position + Vector2(50, 39), tr("Leeg") if item == "" else tr(Items.info(item)["name"]), 16, Color.WHITE)
	var options := alternatives()
	if options.is_empty():
		_text(Vector2(356, 92), tr("Automatisch actief"), 24, GOLD)
		_text(Vector2(356, 126), tr("Deze plek volgt je bestaande upgrades."), 18, BLUE)
	else:
		if options.size() > 2:
			_box(PREV_RECT,false,false); _box(NEXT_RECT,false,false)
			_text(PREV_RECT.position+Vector2(6,22),"‹",22,BLUE)
			_text(NEXT_RECT.position+Vector2(6,22),"›",22,BLUE)
			draw_string(ThemeDB.fallback_font,Vector2(874,40),"%d/%d" % [selected_item/2+1,ceili(options.size()/2.0)],HORIZONTAL_ALIGNMENT_CENTER,48,15,BLUE)
		for index in visible_indices():
			var item: String = options[index]
			var rect := item_rect(index)
			_box(rect, index == selected_item, zone == 1 and index == selected_item)
			_icon(item, rect.position + Vector2(9, 12))
			_text(rect.position + Vector2(52, 24), tr(Items.info(item)["name"]), 19, Color.WHITE)
			draw_string(ThemeDB.fallback_font,rect.position+Vector2(52,47),Equipment.stats_text(item),HORIZONTAL_ALIGNMENT_LEFT,540,14,BLUE)
			var status := tr("Uitgerust") if Equipment.equipped(slot_id()) == item else tr("In bezit") if GameState.count(item) > 0 else tr("Niet in bezit")
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(416, 24), status, HORIZONTAL_ALIGNMENT_RIGHT, 182, 15, GOLD if GameState.count(item) > 0 else Color(0.65, 0.7, 0.8))
		_draw_action(EQUIP_RECT, tr("%s  Uitrusten") % Controls.action_label("ui_accept"), can_equip(), zone == 2 and action_index == 0)
		_draw_action(REMOVE_RECT, tr("Afdoen"), can_remove(), zone == 2 and action_index == 1)


func _box(rect: Rect2, selected: bool, focused: bool) -> void:
	draw_rect(rect, Color(0.17, 0.27, 0.43) if selected else Color(0.1, 0.16, 0.28))
	if selected:
		draw_rect(rect, GOLD if focused else Color(0.4, 0.6, 0.8), false, 2.0)


func _draw_action(rect: Rect2, label: String, enabled: bool, focused: bool) -> void:
	draw_rect(rect, Color(0.15, 0.33, 0.3) if enabled else Color(0.12, 0.16, 0.22))
	if focused:
		draw_rect(rect, GOLD, false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 28), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 20, Color.WHITE if enabled else Color(0.5, 0.58, 0.7))


func _text(at: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _icon(item: String, at: Vector2) -> void:
	if item == "":
		draw_rect(Rect2(at, Vector2(32, 32)), Color(0.25, 0.35, 0.5), false, 1.0)
		return
	var info := Items.info(item)
	draw_texture_rect_region(Art.tex(Items.sheet_of(item)), Rect2(at, Vector2(32, 32)), Rect2(int(info["icon"]) * 16, 0, 16, 16))


func detail_text() -> String:
	if slot_id() == "weapon":
		return tr("Zwaard: %s · schade %d · bereik %d") % [tr(Items.WEAPONS[GameState.weapon]["name"]), GameState.damage(), GameState.reach()] + "\n\n" + tr("Je beste zwaard blijft automatisch actief. Bekijk Voortgang voor Greta's prijzen en de route naar het Sterrenzwaard.")
	if slot_id() == "boots":
		return (tr("Snelle laarzen zijn actief: +%d%% loopsnelheid.") % roundi((GameState.BOOTS_SPEED_MULTIPLIER - 1.0) * 100.0) if GameState.count("boots") > 0 else tr("Koop snelle laarzen bij Tobias. Daarna zijn ze automatisch actief.")) + "\n\n" + tr("Bekijk Voortgang voor prijs en locatie. Deze bestaande upgrade hoef je niet aan of uit te zetten.")
	var current := Equipment.equipped(slot_id())
	var lines: Array[String] = [tr("Nu: %s") % (tr("Geen bonus") if current == "" else Equipment.stats_text(current)), tr("Na wisselen: %s") % Equipment.stats_text(candidate()), Equipment.comparison_text(candidate())]
	lines.append(source_text(candidate()))
	return "\n".join(lines)


func source_text(item: String) -> String:
	for offer: Dictionary in Shops.info("tobias")["items"]:
		if offer["item"] == item:
			return tr("Tobias · dorpswinkel · %d munten (je hebt %d)") % [offer["price"], GameState.coins]
	for id: String in Recipes.RECIPES:
		var recipe: Dictionary = Recipes.RECIPES[id]
		if recipe["output"] != item:
			continue
		var needs: Array[String] = []
		for material: String in recipe["inputs"]:
			needs.append(tr("%s %d/%d") % [tr(Items.info(material)["name"]), GameState.count(material), recipe["inputs"][material]])
		var text := tr("Maken via %s · %s niveau %d · %s") % [Controls.action_label("crafting"), tr(Recipes.SKILLS[recipe["skill"]]["name"]), recipe["level"], tr(Recipes.TEXT[recipe.get("station", "anywhere")])] + "\n" + ", ".join(needs)
		if recipe.has("unlock") and not GameState.flag(recipe.unlock): text += "\n" + tr(recipe.get("unlock_hint","Nog vergrendeld: herstel de prismabank of Mees’ oversteek."))
		return text
	match item:
		"gear_ra_grip": return tr("Beloning: breng de weerkaart terug naar het kamp in de Bergpas.")
		"gear_ra_compass": return tr("Beloning: orden de gebeurtenissen in het Rietarchief.")
		"gear_rf_keepsake": return tr("Beloning: voltooi Wilfreds gedenksteen in de Ruïne.")
		"gear_rf_cord": return tr("Vind de schuilplaats achter de klankschalen in de Echo-grot.")
		"gear_bastion_coat": return tr("Beloning: verdedig de twee vuurkorven in IJsdal.")
	return ""
