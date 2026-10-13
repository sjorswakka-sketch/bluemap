extends Control
## Eén overzicht van held-ervaring, alle beroepen en de bestaande uitrusting.
## Kosten komen uit gesprekken/winkels/recepten; dit scherm koopt of ontgrendelt niets.

const Equipment := preload("res://scripts/core/equipment.gd")
const Progression := preload("res://scripts/core/progression.gd")
const Professions := preload("res://scripts/core/professions.gd")
const Data := preload("res://scripts/data/ext/beroepen.gd")
const Items := preload("res://scripts/data/items.gd")
const Dialogue := preload("res://scripts/data/dialogue.gd")
const Shops := preload("res://scripts/data/shops.gd")
const ROW_TOP := 91.0
const ROW_HEIGHT := 31.0
const LIST_WIDTH := 302.0
const GOLD := Color(1.0, 0.88, 0.4)
const BLUE := Color(0.6, 0.85, 1.0)

signal close_requested

var selected := 0 # zwaard, laarzen, hartjes, gereedschap, daarna de zeven beroepen
var heading: Label
var detail: RichTextLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	heading = Label.new()
	heading.position = Vector2(334, 94)
	heading.size = Vector2(600, 38)
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", GOLD)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heading)
	detail = RichTextLabel.new()
	detail.position = Vector2(334, 140)
	detail.size = Vector2(600, 286)
	detail.add_theme_font_size_override("normal_font_size", 18)
	detail.add_theme_color_override("default_color", Color(0.86, 0.92, 1.0))
	detail.add_theme_constant_override("line_separation", 3)
	detail.focus_mode = Control.FOCUS_NONE
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.scroll_active = true
	detail.gui_input.connect(_detail_input)
	add_child(detail)
	gui_input.connect(_pointer_input)
	GameState.progression_changed.connect(refresh)
	GameState.items_changed.connect(refresh)
	GameState.quests_changed.connect(refresh)
	Lang.changed.connect(func(_locale: String) -> void: refresh())
	Controls.bindings_changed.connect(refresh)
	Controls.device_changed.connect(func(_pad: bool) -> void: refresh())
	refresh()


func select(index: int) -> void:
	selected = clampi(index, 0, 3 + Data.SKILLS.size())
	refresh()
	detail.get_v_scroll_bar().value = 0.0


func navigate(action: String) -> void:
	if action in ["ui_up", "ui_down"]:
		select(selected + (-1 if action == "ui_up" else 1))
	else:
		# Lange uitleg blijft ook zonder muis volledig leesbaar.
		detail.get_v_scroll_bar().value += -105.0 if action == "ui_left" else 105.0


func _pointer_input(event: InputEvent) -> void:
	if Controls.controller_active or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and Rect2(0, ROW_TOP, LIST_WIDTH, ROW_HEIGHT * (4 + Data.SKILLS.size())).has_point(event.position):
		select(int((event.position.y - ROW_TOP) / ROW_HEIGHT))
		accept_event()


func _detail_input(event: InputEvent) -> void:
	# Right-click remains the same close gesture as elsewhere in the inventory.
	if not Controls.controller_active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close_requested.emit()
		accept_event()


func refresh() -> void:
	if detail == null:
		return
	var data := selection_info()
	heading.text = data["title"]
	detail.text = data["text"]
	queue_redraw()


func selection_info() -> Dictionary:
	match selected:
		0:
			return {"title": tr("Zwaard & volgende upgrade"), "text": _weapon_text()}
		1:
			return {"title": tr("Laarzen & snelheid"), "text": _boots_text()}
		2:
			return {"title": tr("Hartjes & overleven"), "text": _hearts_text()}
		3:
			return {"title": tr("Gereedschap & boog"), "text": _tools_text()}
	var skill: String = Data.SKILLS.keys()[selected - 4]
	var level := Professions.level(skill)
	var xp_text := tr("Meester • maximaal niveau") if level == Professions.MAX_LEVEL else tr("%d / %d XP tot volgend niveau") % [Professions.xp(skill) - Professions.threshold(level), Professions.threshold(level + 1) - Professions.threshold(level)]
	var lines: Array[String] = [tr("Niveau %d / %d") % [level, Professions.MAX_LEVEL], xp_text, "", tr(Data.SKILLS[skill]["desc"]), "", tr("Beroepen stijgen door verzamelen, vissen en maken. Ze ontgrendelen eigen recepten en grondstoffen."), tr("Open %s voor recepten en hun materialen.") % Controls.action_label("crafting")]
	for recipe_id: String in Data.RECIPES:
		var recipe: Dictionary = Data.RECIPES[recipe_id]
		if recipe["skill"] == skill and int(recipe["level"]) > level:
			lines.append("\n" + tr("Volgend recept: %s (niveau %d)") % [Professions.item_name(recipe["output"]), recipe["level"]])
			break
	return {"title": tr(Data.SKILLS[skill]["name"]), "text": "\n".join(lines)}


func _draw() -> void:
	var hero := Progression.progress()
	draw_rect(Rect2(0, 0, 952, 76), Color(0.11, 0.2, 0.35))
	_draw_text(Vector2(14, 29), tr("Held · niveau %d") % hero["level"], 23, GOLD)
	var xp_text := tr("Maximaal niveau") if hero["max_level"] else tr("%d / %d XP") % [hero["current"], hero["needed"]]
	_draw_text(Vector2(240, 25), xp_text, 17, BLUE)
	var ratio := 1.0 if hero["max_level"] else float(hero["current"]) / maxi(int(hero["needed"]), 1)
	_bar(Rect2(240, 33, 275, 8), ratio, BLUE)
	_draw_text(Vector2(548, 27), tr("Alle heldlevels behaald") if hero["max_level"] else tr("Volgend level: +%d munten") % hero["next_reward"], 19, GOLD)
	_draw_text(Vector2(14, 62), tr("Verdien XP met gevechten buiten de arena en opdrachten. Levels geven munten voor uitrusting."), 16, Color(0.8, 0.88, 0.97))
	draw_rect(Rect2(318, 91, 634, 342), Color(0.08, 0.14, 0.26))
	var labels: Array[String] = [tr("Zwaard"), tr("Laarzen"), tr("Hartjes"), tr("Gereedschap & boog")]
	for i in 4 + Data.SKILLS.size():
		var rect := row_rect(i)
		draw_rect(rect, Color(0.2, 0.32, 0.5) if i == selected else Color(0.1, 0.16, 0.29))
		if i == selected:
			draw_rect(rect, GOLD, false, 2.0)
		if i < 4:
			_draw_text(rect.position + Vector2(10, 22), labels[i], 18, GOLD if i == selected else BLUE)
			continue
		var skill: String = Data.SKILLS.keys()[i - 4]
		var level := Professions.level(skill)
		var current := Professions.xp(skill) - Professions.threshold(level)
		var needed := Professions.threshold(level + 1) - Professions.threshold(level)
		_draw_text(rect.position + Vector2(10, 20), tr(Data.SKILLS[skill]["name"]), 17, Color.WHITE)
		_draw_text(rect.position + Vector2(244, 20), "%d/%d" % [level, Professions.MAX_LEVEL], 15, BLUE)
		_bar(Rect2(rect.position + Vector2(10, 25), Vector2(226, 3)), 1.0 if level == Professions.MAX_LEVEL else float(current) / maxi(needed, 1), Color(0.4, 0.85, 0.67))


func row_rect(index: int) -> Rect2:
	return Rect2(0, ROW_TOP + index * ROW_HEIGHT, LIST_WIDTH, ROW_HEIGHT - 2)


func _draw_text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, Color(0.03, 0.06, 0.12))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)


## Read the actual Greta transaction instead of maintaining a second price list.
func weapon_upgrade() -> Dictionary:
	var next := "iron" if GameState.weapon == "wood" else "crystal" if GameState.weapon == "iron" else "star" if GameState.weapon == "crystal" else ""
	if next not in ["iron", "crystal"]:
		return {"weapon": next, "coins": 0, "materials": {}}
	var costs := {"weapon": next, "coins": 0, "materials": {}}
	for action: Array in Dialogue.get_talk("greta_%s_ask" % next)["choices"][0]["do"]:
		if action[0] == "coins":
			costs["coins"] = -int(action[1])
		elif action[0] == "take":
			costs["materials"][action[1]] = int(action[2]) if action.size() > 2 else 1
	return costs


func _weapon_text() -> String:
	var current: Dictionary = Items.WEAPONS[GameState.weapon]
	var lines: Array[String] = [tr("Nu: %s") % tr(current["name"]), tr("Schade: %d per klap · bereik: %d") % [current["damage"], current["reach"]], tr("Uitrusting: pantser %d · uithouding %d") % [Equipment.bonus("armor"), GameState.movement.capacity()], tr("Wissel hoofd, borst, handen, hals en ring op het tabblad Uitrusting."), ""]
	var upgrade := weapon_upgrade()
	var next: String = upgrade["weapon"]
	if next == "":
		lines.append(tr("Je hebt het sterkste zwaard van Azura."))
	else:
		var better: Dictionary = Items.WEAPONS[next]
		lines.append(tr("Volgende upgrade: %s") % tr(better["name"]))
		lines.append(tr("Schade %d → %d · bereik %d → %d") % [current["damage"], better["damage"], current["reach"], better["reach"]])
		if next == "star":
			lines.append(tr("Herstel eerst de Blauwe Kaart. Daal daarna onder de Kristaltempel af en versla De Vergeten Wachter. Geen muntkosten."))
		else:
			lines.append(tr("Greta · smederij in het noordwesten van het dorp"))
			lines.append(tr("Munten: %d / %d") % [GameState.coins, upgrade["coins"]])
			for item: String in upgrade["materials"]:
				lines.append(tr("%s: %d / %d") % [Professions.item_name(item), GameState.count(item), upgrade["materials"][item]])
			lines.append(tr("Slijmen geven slijmgel; golembewakers in de ruïne en grot geven scherven."))
			lines.append(tr("Praat met Greta om te laten smeden. Heldniveau en beroep Smeden zijn hiervoor niet vereist."))
	var path: Array[String] = []
	lines.append(tr("Schildbreker geleerd: de derde comboslag breekt een frontaal schild (18 stamina).") if GameState.flag("lw_workshop") else tr("Nieuwe techniek: herstel Greta’s prismabank om met je derde comboslag schilden te breken."))
	for weapon: String in ["wood", "iron", "crystal", "star"]:
		path.append(tr(Items.WEAPONS[weapon]["name"]))
	lines.append("\n" + " → ".join(path))
	return "\n".join(lines)


func shop_offer(item_id: String) -> Dictionary:
	for offer: Dictionary in Shops.info("tobias")["items"]:
		if offer["item"] == item_id:
			return offer
	return {}


func _boots_text() -> String:
	var bonus := roundi((GameState.BOOTS_SPEED_MULTIPLIER - 1.0) * 100.0)
	if GameState.count("boots") > 0:
		return tr("Uitgerust: %s") % Professions.item_name("boots") + "\n\n" + tr("Blijvend %d%% sneller lopen en rennen.") % bonus + "\n\n" + tr("Je hebt de beste laarzen. Paden en rennen geven daarbovenop hun eigen snelheidsbonus.")
	return tr("Nu: gewone schoenen") + "\n\n" + tr("Volgende upgrade: %s") % Professions.item_name("boots") + "\n" + tr("Blijvend %d%% sneller lopen en rennen.") % bonus + "\n\n" + tr("Tobias · winkel naast de smederij in het dorp") + "\n" + tr("Munten: %d / %d") % [GameState.coins, shop_offer("boots")["price"]] + "\n" + tr("Geen niveau of materialen vereist. Koop ze via het gesprek met Tobias.")


func _hearts_text() -> String:
	var maximum := GameState.BASE_HP + int(Items.info("heart_container")["max"])
	var lines: Array[String] = [tr("Levens: %d / %d hartjes maximaal") % [GameState.max_hp(), maximum]]
	if GameState.room("heart_container") == 0:
		lines.append(tr("Alle hartcontainers verzameld."))
	else:
		lines.append(tr("Elke hartcontainer geeft blijvend +1 hartje. Geen muntkosten."))
		lines.append("")
		lines.append(tr("Pim · bij zijn kat in het oosten van het dorp") if GameState.flag("cat_home") else tr("Pim · oosten van het dorp: vind zijn kat Muis in het Fluisterbos en keer bij hem terug."))
		lines.append(tr("Beloning van Pim ontvangen.") if GameState.flag("cat_home") else tr("Nog te verdienen: één hartcontainer van Pim."))
		lines.append("")
		lines.append(tr("Andere hartcontainers: een kist in het noordoosten van de Echo-grot en de beloningskist van De Vergeten Wachter in de Diepte."))
		lines.append(tr("De Diepte opent nadat de Blauwe Kaart is hersteld."))
	return "\n".join(lines)


func _recipe_text(recipe_id: String) -> String:
	var recipe: Dictionary = Data.RECIPES[recipe_id]
	var materials: Array[String] = []
	for item: String in recipe["inputs"]:
		materials.append(tr("%s %d/%d") % [Professions.item_name(item), GameState.count(item), recipe["inputs"][item]])
	var station: String = recipe.get("station", "anywhere")
	return tr("%s niveau %d · %s") % [tr(Data.SKILLS[recipe["skill"]]["name"]), recipe["level"], tr(Data.TEXT[station])] + "\n" + ", ".join(materials)


func _tools_text() -> String:
	var lines: Array[String] = [tr("Gereedschap wordt automatisch gebruikt en slijt niet."), tr("Open %s om te maken; materialen en vereiste niveaus staan hieronder.") % Controls.action_label("crafting"), ""]
	for tools: Array in [["prof_axe", "prof_iron_axe", "stone_axe", "iron_axe"], ["prof_pickaxe", "prof_copper_pickaxe", "stone_pickaxe", "copper_pickaxe"]]:
		var best: String = tools[1] if GameState.count(tools[1]) > 0 else tools[0] if GameState.count(tools[0]) > 0 else ""
		var next: String = tools[1] if best == tools[0] else tools[0]
		lines.append(tr("Nu: %s") % (tr("Nog geen gereedschap") if best == "" else Professions.item_name(best)))
		if best == tools[1]:
			lines.append(tr(Items.info(best)["desc"]))
		else:
			lines.append(tr("Volgende upgrade: %s") % Professions.item_name(next))
			lines.append(tr(Items.info(next)["desc"]))
			lines.append(_recipe_text(tools[3] if best == tools[0] else tools[2]))
		lines.append("")
	lines.append(tr("Hengel: in bezit") if GameState.count("fishing_rod") > 0 else tr("Hengel: gratis van Visser Joris aan het Zilvermeer."))
	lines.append(tr("Boog: in bezit") if GameState.count("bow") > 0 else tr("Boog: %d munten bij Tobias, met %d pijlen. Geen niveau vereist.") % [shop_offer("bow")["price"], shop_offer("bow")["with"][0][1]])
	return "\n".join(lines)
