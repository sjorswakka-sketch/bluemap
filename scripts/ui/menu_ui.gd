extends CanvasLayer
## Het menu met vijf tabbladen: voorwerpen (I of Tab), opdrachten (Q), kaart (N), prestaties (T) en beestenboek (B).
## Op de kaart kun je ook snel reizen naar een ontdekt altaar. Met een controller bladeren de schouderknoppen.

const UiStyle := preload("res://scripts/core/ui_style.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Items := preload("res://scripts/data/items.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Content := preload("res://scripts/data/content.gd")
const MenuPages := preload("res://scripts/ui/menu_pages.gd")
const Achievements := preload("res://scripts/data/achievements.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const FastTravel := preload("res://scripts/core/fast_travel.gd")
const Professions := preload("res://scripts/core/professions.gd")
const ProfessionData := preload("res://scripts/data/ext/beroepen.gd")

const TAB_COUNT := 5 # de namen staan in tab_titles()
const TAB_QUESTS := 1
const TAB_MAP := 2
const TAB_ACHIEVEMENTS := 3
const TAB_BESTIARY := 4
const SIZE := Vector2(1000, 560)
const SLOT := 76.0
const INVENTORY_PAGE_SIZE := 24
const MAP_WIDTH := 600.0 # zoveel ruimte krijgt het kaartje; rechts ervan staat het lijstje voor snel reizen
const MESSAGE_TIME := 3.0 # seconden dat een melding in het kaarttabblad blijft staan

var root: Control
var content: Control
var tab := 0
var selected := 0
var active := false
var opened_frame := -1
var time := 0.0
var markers: Dictionary = Content.map_markers() # extra stipjes op het kaartje voor soorten objecten van uitbreidingen
var achievement_selected := 0 # de gekozen regel in Prestaties en Beestenboek, en hoe ver er gescrold is
var achievement_scroll := 0
var bestiary_selected := 0
var bestiary_scroll := 0
var travel_selected := 0 # het gekozen altaar op de kaart
var travel_confirm := false # wacht op "E" om echt te reizen
var travel_message := ""
var travel_message_time := 0.0


func _ready() -> void:
	layer = 13
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	root.add_child(dim)
	content = Control.new()
	content.position = (Vector2(1152, 648) - SIZE) / 2.0
	content.size = SIZE
	content.draw.connect(_draw_content)
	root.add_child(content)


func open(start_tab: int) -> void:
	tab = start_tab
	selected = 0
	travel_confirm = false
	travel_message = ""
	active = true
	root.visible = true
	opened_frame = Engine.get_process_frames()
	GameState.set_ui("menu", true)
	Sound.play("select", -4.0)
	content.queue_redraw()


func close() -> void:
	active = false
	root.visible = false
	GameState.set_ui("menu", false)
	Sound.play("select", -6.0)


func _process(delta: float) -> void:
	time += delta
	travel_message_time = maxf(travel_message_time - delta, 0.0)
	if travel_message_time <= 0.0:
		travel_message = ""
	if active:
		content.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		if GameState.input_locked():
			return
		if event.is_action_pressed("menu"):
			open(0)
		elif event.is_action_pressed("quests"):
			open(TAB_QUESTS)
		elif event.is_action_pressed("map"):
			open(TAB_MAP)
		elif event.is_action_pressed("wereld_prestaties"):
			open(TAB_ACHIEVEMENTS)
		elif event.is_action_pressed("wereld_beestenboek"):
			open(TAB_BESTIARY)
		return
	if Engine.get_process_frames() == opened_frame:
		return
	if travel_confirm and _answer_travel_question(event):
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("quests"):
		get_viewport().set_input_as_handled()
		# Een controller bladert met de schouderknoppen; het toetsenbord springt naar het tabblad (en sluit het weer).
		if event is InputEventJoypadButton:
			_step_tab(-1)
		else:
			_toggle_tab(TAB_QUESTS)
	elif event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		if event is InputEventJoypadButton:
			_step_tab(1)
		else:
			_toggle_tab(TAB_MAP)
	elif event.is_action_pressed("wereld_prestaties"):
		get_viewport().set_input_as_handled()
		_toggle_tab(TAB_ACHIEVEMENTS)
	elif event.is_action_pressed("wereld_beestenboek"):
		get_viewport().set_input_as_handled()
		_toggle_tab(TAB_BESTIARY)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_step_tab(1)
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_step_tab(-1)
	elif tab == 0:
		var count := _owned().size()
		if event.is_action_pressed("ui_down") and count > 0:
			selected = mini(selected + 1, count - 1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up"):
			selected = maxi(selected - 1, 0)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_use_selected()
		elif event.is_action_pressed("potion"):
			get_viewport().set_input_as_handled()
			_drink()
	elif tab == TAB_MAP:
		_map_input(event)
	elif tab == TAB_ACHIEVEMENTS:
		achievement_selected = _move_selection(event, achievement_selected, Achievements.ACHIEVEMENTS.size())
	elif tab == TAB_BESTIARY:
		bestiary_selected = _move_selection(event, bestiary_selected, Enemies.ENEMIES.size())


func _set_tab(new_tab: int) -> void:
	tab = new_tab
	selected = 0
	travel_confirm = false
	Sound.play("select", -8.0)


func _step_tab(step: int) -> void:
	_set_tab((tab + step + TAB_COUNT) % TAB_COUNT)


## De namen van de tabbladen in de taal van de speler: voorwerpen, opdrachten, kaart, prestaties en beestenboek.
func tab_titles() -> Array[String]:
	return [tr("Voorwerpen"), tr("Opdrachten"), tr("Kaart"), tr("Prestaties"), tr("Beestenboek")]


## Dezelfde toets opent het tabblad, en sluit het menu weer als je er al bent.
func _toggle_tab(target: int) -> void:
	if tab == target:
		close()
	else:
		_set_tab(target)


## Omhoog en omlaag in een lijst. Geeft de nieuwe keuze terug.
func _move_selection(event: InputEvent, current: int, total: int) -> int:
	var next := current
	if event.is_action_pressed("ui_down"):
		next = mini(current + 1, total - 1)
	elif event.is_action_pressed("ui_up"):
		next = maxi(current - 1, 0)
	else:
		return current
	get_viewport().set_input_as_handled()
	if next != current:
		Sound.play("select", -10.0)
	return next


func _map_input(event: InputEvent) -> void:
	var altars := FastTravel.discovered_altars()
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		travel_selected = _move_selection(event, clampi(travel_selected, 0, maxi(altars.size() - 1, 0)), altars.size())
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var world := Util.world(self)
		var reason := tr("Je hebt nog geen altaar ontdekt.") if altars.is_empty() or world == null else FastTravel.blocked_reason(world)
		if reason != "":
			travel_message = reason
			travel_message_time = MESSAGE_TIME
			Sound.play("error", -3.0)
		else:
			travel_confirm = true
			Sound.play("select", -4.0)


## De vraag "Reizen naar ...?" staat open. E bevestigt, Esc of een pijl annuleert. Geeft true terug als de toets op is.
func _answer_travel_question(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var altars := FastTravel.discovered_altars()
		var world := Util.world(self)
		travel_confirm = false
		if world != null and not altars.is_empty():
			var altar: Dictionary = altars[clampi(travel_selected, 0, altars.size() - 1)]
			close()
			FastTravel.travel(world, altar)
		return true
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		travel_confirm = false
		Sound.play("select", -8.0)
		return true
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		travel_confirm = false # de pijl doet daarna gewoon zijn werk
	return false


func _owned() -> Array[String]:
	var owned: Array[String] = []
	for item_id: String in Items.ITEMS:
		if item_id != "coin" and GameState.count(item_id) > 0 and Items.ITEMS[item_id].get("type", "") != "weapon":
			owned.append(item_id)
	return owned


func _use_selected() -> void:
	var owned := _owned()
	if selected >= owned.size():
		return
	if owned[selected] in Professions.CONSUMABLES:
		Sound.play("drink" if Professions.use_item(owned[selected]) else "error", -5.0)


func _drink() -> void:
	if GameState.use_potion():
		Sound.play("drink")
	elif GameState.count("potion") > 0:
		GameState.toast.emit(tr("Je hebt al alle hartjes."))


# --- Tekenen -------------------------------------------------------------------------------

func _draw_content() -> void:
	var font := ThemeDB.fallback_font
	var panel := UiStyle.flat(Color(0.06, 0.1, 0.22, 0.98), Color(0.45, 0.75, 1.0), 3)
	content.draw_style_box(panel, Rect2(Vector2.ZERO, SIZE))
	# Tabbladen
	var titles := tab_titles()
	for i in TAB_COUNT:
		var rect := Rect2(24 + i * 186, 16, 178, 40)
		var chosen := i == tab
		content.draw_rect(rect, Color(0.2, 0.35, 0.65) if chosen else Color(0.1, 0.16, 0.3))
		content.draw_rect(rect, Color(0.6, 0.85, 1.0) if chosen else Color(0.3, 0.45, 0.7), false, 2.0)
		content.draw_string(font, rect.position + Vector2(0, 28), titles[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 22,
			Color.WHITE if chosen else Color(0.7, 0.8, 1.0))
	content.draw_string(font, Vector2(24, SIZE.y - 16), _footer_hint(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.55))
	match tab:
		0:
			_draw_items(font)
		TAB_QUESTS:
			_draw_quests(font)
		TAB_MAP:
			_draw_map(font)
		TAB_ACHIEVEMENTS:
			MenuPages.draw_achievements(self, font)
		TAB_BESTIARY:
			MenuPages.draw_bestiary(self, font)


## De toetsen die op dit tabblad iets doen.
func _footer_hint() -> String:
	match tab:
		0:
			return tr(ProfessionData.TEXT["inventory_navigation"]) + tr("← → of LB / RB  tabblad   ·   Esc  sluiten")
		TAB_MAP:
			return tr("↑ ↓  altaar kiezen   ·   E  reizen   ·   ← → of LB / RB  tabblad   ·   Esc  sluiten")
		TAB_ACHIEVEMENTS, TAB_BESTIARY:
			return tr("↑ ↓  bladeren   ·   ← → of LB / RB  tabblad   ·   I Q N T B  openen en sluiten   ·   Esc  sluiten")
	return tr("← → of LB / RB  tabblad   ·   I Q N T B  openen en sluiten   ·   Esc  sluiten")


func _text(font: Font, pos: Vector2, text: String, size: int, color := Color.WHITE, width := -1.0) -> float:
	## Tekent (eventueel afgebroken) tekst en geeft de hoogte terug.
	return MenuPages.text(content, font, pos, text, size, color, width)


func inventory_page_start() -> int:
	return floori(float(selected) / INVENTORY_PAGE_SIZE) * INVENTORY_PAGE_SIZE


func _draw_items(font: Font) -> void:
	var owned := _owned()
	selected = clampi(selected, 0, maxi(owned.size() - 1, 0))
	_text(font, Vector2(24, 72), tr("Je spullen"), 24, Color(0.6, 0.88, 1.0))
	if owned.is_empty():
		_text(font, Vector2(24, 112), tr("Je hebt nog niets bij je."), 20, Color(1, 1, 1, 0.6))
	var first := inventory_page_start()
	var last := mini(first + INVENTORY_PAGE_SIZE, owned.size())
	for i in range(first, last):
		var local_index := i - first
		var pos := Vector2(24 + (local_index % 6) * (SLOT + 8), 110 + floori(float(local_index) / 6.0) * (SLOT + 8))
		var chosen := i == selected
		content.draw_rect(Rect2(pos, Vector2(SLOT, SLOT)), Color(0.18, 0.3, 0.55) if chosen else Color(0.1, 0.16, 0.3))
		content.draw_rect(Rect2(pos, Vector2(SLOT, SLOT)), Color(1.0, 0.88, 0.35) if chosen else Color(0.3, 0.45, 0.7), false, 3.0 if chosen else 2.0)
		var icon: int = Items.ITEMS[owned[i]]["icon"]
		content.draw_texture_rect_region(Art.tex(Items.sheet_of(owned[i])), Rect2(pos + Vector2(10, 6), Vector2(56, 56)), Rect2(Vector2(icon * 16, 0), Vector2(16, 16)))
		var count := GameState.count(owned[i])
		if count > 1:
			content.draw_string_outline(font, pos + Vector2(SLOT - 26, SLOT - 6), "x%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0))
			content.draw_string(font, pos + Vector2(SLOT - 26, SLOT - 6), "x%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if owned.size() > INVENTORY_PAGE_SIZE:
		_text(font, Vector2(24, 462), ProfessionData.TEXT["inventory_page"] % [first + 1, last, owned.size()], 17, Color(0.7, 0.8, 0.95))

	# Rechts: omschrijving en gegevens
	var x := 620.0
	if not owned.is_empty():
		var info: Dictionary = Items.ITEMS[owned[selected]]
		var h := _text(font, Vector2(x, 72), tr(info["name"]), 24, Color(1.0, 0.9, 0.5), 340)
		h += _text(font, Vector2(x, 72 + h + 6), tr(info["desc"]), 18, Color(0.9, 0.93, 1.0), 340) + 6
		if owned[selected] in Professions.CONSUMABLES:
			_text(font, Vector2(x, 72 + h + 10), tr(ProfessionData.TEXT["inventory_use"]), 18, Color(0.6, 1.0, 0.7))
	var weapon: Dictionary = Items.WEAPONS[GameState.weapon]
	var lines := [
		tr("Zwaard:  %s (schade %d)") % [tr(weapon["name"]), weapon["damage"]],
		tr("Levens:  %d / %d") % [GameState.hp, GameState.max_hp()],
		tr("Snelheid:  snel (laarzen)") if GameState.count("boots") > 0 else tr("Snelheid:  normaal"),
		tr("Munten:  %d") % GameState.coins,
		tr("Kristallen:  %d / 3") % (3 if GameState.flag("gate_temple") else GameState.crystal_count()),
		tr("Verslagen:  %d") % GameState.kills,
		tr("Speeltijd:  %s") % format_time(GameState.play_time),
	]
	if GameState.ng_plus > 0:
		UiStyle.draw_star(content, Vector2(36, SIZE.y - 42), 11.0, Color(1.0, 0.85, 0.3))
		# Vertalers: Nieuw spel+ is de naam van de knop op het titelscherm; ronde 2 = de tweede keer opnieuw
		_text(font, Vector2(56, SIZE.y - 56), tr("Nieuw spel+  ·  ronde %d") % GameState.ng_plus, 20, Color(1.0, 0.9, 0.5))
	content.draw_line(Vector2(x, 330), Vector2(x + 340, 330), Color(0.3, 0.45, 0.7), 2.0)
	var y := 342.0
	for line: String in lines:
		_text(font, Vector2(x, y), line, 20, Color(0.85, 0.92, 1.0))
		y += 28.0


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func _draw_quests(font: Font) -> void:
	var order: Array[String] = []
	for quest_id: String in Quests.QUESTS:
		if GameState.quest_state(quest_id) == "active":
			order.append(quest_id)
	for quest_id: String in Quests.QUESTS:
		if GameState.quest_state(quest_id) == "done":
			order.append(quest_id)
	_text(font, Vector2(24, 72), tr("Opdrachten"), 24, Color(0.6, 0.88, 1.0))
	if order.is_empty():
		_text(font, Vector2(24, 112), tr("Je hebt nog geen opdrachten. Praat met de mensen in het dorp!"), 20, Color(1, 1, 1, 0.6))
	var y := 112.0
	for quest_id in order:
		var done := GameState.quest_state(quest_id) == "done"
		var info := Quests.info(quest_id)
		var title := tr(info["title"])
		if info.get("main", false) and not done:
			# Vertalers: titel van de hoofdopdracht in het opdrachtenlogboek
			title = tr("%s   (hoofdopdracht)") % title
		title = ("✓ " if done else "• ") + title
		y += _text(font, Vector2(24, y), title, 22, Color(0.55, 1.0, 0.65) if done else Color(1.0, 0.9, 0.5)) + 4
		var text := tr("Voltooid.") if done else GameState.quest_text(quest_id)
		y += _text(font, Vector2(48, y), text, 19, Color(0.85, 0.9, 1.0), 900) + 16
		if y > SIZE.y - 60:
			break


func _draw_map(font: Font) -> void:
	var world := Util.world(self)
	if world == null or world.map_data.is_empty():
		return
	var rows: Array = world.map_data["rows"]
	var w: int = rows[0].length()
	var h: int = rows.size()
	var cell := mini(int(MAP_WIDTH / w), int(390.0 / h))
	cell = maxi(cell, 4)
	var origin := Vector2(24.0 + (MAP_WIDTH - w * cell) / 2.0, 100.0)
	_text(font, Vector2(24, 66), tr(world.map_data["name"]), 26, Color(0.6, 0.88, 1.0))
	for y in h:
		var row: String = rows[y]
		for x in w:
			content.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), Tiles.map_color(Tiles.name_for(row[x], x, y)))
	content.draw_rect(Rect2(origin, Vector2(w, h) * cell), Color(0.9, 0.95, 1.0), false, 2.0)
	var altars := FastTravel.discovered_altars()
	travel_selected = clampi(travel_selected, 0, maxi(altars.size() - 1, 0))
	for obj: Dictionary in world.map_data.get("objects", []):
		if obj.has("if") and not GameState.check_all(obj["if"]):
			continue
		var p := origin + (Vector2(float(obj["pos"][0]), float(obj["pos"][1])) + Vector2(0.5, 0.5)) * cell
		match obj["type"]:
			"npc":
				content.draw_circle(p, cell * 0.45, Color(0.4, 1.0, 1.0))
			"portal":
				content.draw_rect(Rect2(p - Vector2(cell, cell) * 0.4, Vector2(cell, cell) * 0.8), Color(1, 1, 1))
			"savepoint":
				_draw_altar_marker(p, cell, obj, altars)
			"chest":
				content.draw_rect(Rect2(p - Vector2(cell, cell) * 0.35, Vector2(cell, cell) * 0.7), Color(1.0, 0.8, 0.2))
	var marks := extension_marks(world.map_data)
	for mark: Dictionary in marks:
		_draw_diamond(origin + (Vector2(float(mark["pos"][0]), float(mark["pos"][1])) + Vector2(0.5, 0.5)) * cell, cell * 0.5, mark["color"])
	var player := Util.player(self)
	if player:
		var pp := origin + (player.global_position / 32.0) * cell
		var pulse := 0.6 + 0.4 * sin(time * 6.0)
		content.draw_circle(pp, cell * 0.6 * (0.8 + pulse * 0.4), Color(1, 0.3, 0.3))
		content.draw_circle(pp, cell * 0.3, Color(1, 1, 1))
	content.draw_string(font, Vector2(24, SIZE.y - 40), tr("● jij   ● mensen   ■ doorgang   ● altaar (opslaan)   ■ kist"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
	# Legenda voor de bijzondere plekken van uitbreidingen die op deze kaart staan.
	var legend: Dictionary = {}
	for mark: Dictionary in marks:
		legend[tr(mark["label"])] = mark["color"]
	var legend_x := 24.0
	for label: String in legend:
		content.draw_string(font, Vector2(legend_x, SIZE.y - 62), "◆ " + label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, legend[label])
		legend_x += font.get_string_size("◆ " + label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24.0
	MenuPages.draw_travel_panel(self, font, altars)


## De bijzondere plekken van uitbreidingen op een kaart (zie MAP_MARKERS in content.gd): [{"pos", "color", "label"}].
## Het label is de Nederlandse naam uit de module; de legenda vertaalt hem bij het tekenen.
func extension_marks(map_data: Dictionary) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	for obj: Dictionary in map_data.get("objects", []):
		if markers.has(obj["type"]) and (not obj.has("if") or GameState.check_all(obj["if"])):
			marks.append({"pos": obj["pos"], "color": markers[obj["type"]]["color"], "label": markers[obj["type"]]["label"]})
	return marks


## Een klein ruitje, voor de bijzondere plekken van uitbreidingen op het kaartje.
func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	content.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


## Een altaar op het kaartje: ontdekt = helder met een witte rand, anders vager. Het gekozen altaar pulseert.
func _draw_altar_marker(p: Vector2, cell: int, obj: Dictionary, altars: Array) -> void:
	var key := FastTravel.altar_key(GameState.map_id, Vector2i(int(obj["pos"][0]), int(obj["pos"][1])))
	var found := GameState.flag(key)
	content.draw_circle(p, cell * 0.45, Color(0.35, 0.6, 1.0) if found else Color(0.25, 0.4, 0.65))
	if found:
		content.draw_arc(p, cell * 0.6, 0.0, TAU, 16, Color(1, 1, 1), 2.0)
	if not altars.is_empty() and altars[travel_selected]["key"] == key:
		var pulse := 0.5 + 0.5 * sin(time * 6.0)
		content.draw_arc(p, cell * (0.9 + pulse * 0.5), 0.0, TAU, 24, Color(1.0, 0.88, 0.35), 3.0)
