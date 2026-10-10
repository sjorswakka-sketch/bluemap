extends CanvasLayer
## Het menu met drie tabbladen: voorwerpen (I of Tab), opdrachten (Q) en kaart (N).

const UiStyle := preload("res://scripts/core/ui_style.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Items := preload("res://scripts/data/items.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Tiles := preload("res://scripts/data/tiles.gd")

const TABS := ["Voorwerpen", "Opdrachten", "Kaart"]
const SIZE := Vector2(1000, 560)
const SLOT := 76.0

var root: Control
var content: Control
var tab := 0
var selected := 0
var active := false
var opened_frame := -1
var time := 0.0


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
	if active:
		content.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		if GameState.input_locked():
			return
		if event.is_action_pressed("menu"):
			open(0)
		elif event.is_action_pressed("quests"):
			open(1)
		elif event.is_action_pressed("map"):
			open(2)
		return
	if Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("quests"):
		get_viewport().set_input_as_handled()
		if tab == 1:
			close()
		else:
			tab = 1
	elif event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		if tab == 2:
			close()
		else:
			tab = 2
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		tab = (tab + 1) % TABS.size()
		selected = 0
		Sound.play("select", -8.0)
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		tab = (tab + TABS.size() - 1) % TABS.size()
		selected = 0
		Sound.play("select", -8.0)
	elif tab == 0:
		var count := _owned().size()
		if event.is_action_pressed("ui_down") and count > 0:
			selected = mini(selected + 6, count - 1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up"):
			selected = maxi(selected - 6, 0)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_use_selected()
		elif event.is_action_pressed("potion"):
			get_viewport().set_input_as_handled()
			_drink()


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
	if owned[selected] == "potion":
		_drink()


func _drink() -> void:
	if GameState.use_potion():
		Sound.play("drink")
	elif GameState.count("potion") > 0:
		GameState.toast.emit("Je hebt al alle hartjes.")


# --- Tekenen -------------------------------------------------------------------------------

func _draw_content() -> void:
	var font := ThemeDB.fallback_font
	var panel := UiStyle.flat(Color(0.06, 0.1, 0.22, 0.98), Color(0.45, 0.75, 1.0), 3)
	content.draw_style_box(panel, Rect2(Vector2.ZERO, SIZE))
	# Tabbladen
	for i in TABS.size():
		var rect := Rect2(24 + i * 190, 16, 180, 40)
		var chosen := i == tab
		content.draw_rect(rect, Color(0.2, 0.35, 0.65) if chosen else Color(0.1, 0.16, 0.3))
		content.draw_rect(rect, Color(0.6, 0.85, 1.0) if chosen else Color(0.3, 0.45, 0.7), false, 2.0)
		content.draw_string(font, rect.position + Vector2(0, 28), TABS[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 22,
			Color.WHITE if chosen else Color(0.7, 0.8, 1.0))
	content.draw_string(font, Vector2(24, SIZE.y - 16), "← → tabblad   ·   I / Q / N openen en sluiten   ·   Esc sluiten", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.55))
	match tab:
		0:
			_draw_items(font)
		1:
			_draw_quests(font)
		2:
			_draw_map(font)


func _text(font: Font, pos: Vector2, text: String, size: int, color := Color.WHITE, width := -1.0) -> float:
	## Tekent (eventueel afgebroken) tekst en geeft de hoogte terug.
	content.draw_multiline_string(font, pos + Vector2(0, size), text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, color)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y


func _draw_items(font: Font) -> void:
	var items_tex := Art.tex("items")
	var owned := _owned()
	selected = clampi(selected, 0, maxi(owned.size() - 1, 0))
	_text(font, Vector2(24, 72), "Je spullen", 24, Color(0.6, 0.88, 1.0))
	if owned.is_empty():
		_text(font, Vector2(24, 112), "Je hebt nog niets bij je.", 20, Color(1, 1, 1, 0.6))
	for i in owned.size():
		var pos := Vector2(24 + (i % 6) * (SLOT + 8), 110 + (i / 6) * (SLOT + 8))
		var chosen := i == selected
		content.draw_rect(Rect2(pos, Vector2(SLOT, SLOT)), Color(0.18, 0.3, 0.55) if chosen else Color(0.1, 0.16, 0.3))
		content.draw_rect(Rect2(pos, Vector2(SLOT, SLOT)), Color(1.0, 0.88, 0.35) if chosen else Color(0.3, 0.45, 0.7), false, 3.0 if chosen else 2.0)
		var icon: int = Items.ITEMS[owned[i]]["icon"]
		content.draw_texture_rect_region(items_tex, Rect2(pos + Vector2(10, 6), Vector2(56, 56)), Rect2(Vector2(icon * 16, 0), Vector2(16, 16)))
		var count := GameState.count(owned[i])
		if count > 1:
			content.draw_string_outline(font, pos + Vector2(SLOT - 26, SLOT - 6), "x%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0))
			content.draw_string(font, pos + Vector2(SLOT - 26, SLOT - 6), "x%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	# Rechts: omschrijving en gegevens
	var x := 620.0
	if not owned.is_empty():
		var info: Dictionary = Items.ITEMS[owned[selected]]
		var h := _text(font, Vector2(x, 72), info["name"], 24, Color(1.0, 0.9, 0.5), 340)
		h += _text(font, Vector2(x, 72 + h + 6), info["desc"], 18, Color(0.9, 0.93, 1.0), 340) + 6
		if owned[selected] == "potion":
			_text(font, Vector2(x, 72 + h + 10), "Druk op E om te drinken", 18, Color(0.6, 1.0, 0.7))
	var weapon: Dictionary = Items.WEAPONS[GameState.weapon]
	var lines := [
		"Zwaard:  %s (schade %d)" % [weapon["name"], weapon["damage"]],
		"Levens:  %d / %d" % [GameState.hp, GameState.max_hp()],
		"Snelheid:  %s" % ("snel (laarzen)" if GameState.count("boots") > 0 else "normaal"),
		"Munten:  %d" % GameState.coins,
		"Kristallen:  %d / 3" % (3 if GameState.flag("gate_temple") else GameState.crystal_count()),
		"Verslagen:  %d" % GameState.kills,
		"Speeltijd:  %s" % format_time(GameState.play_time),
	]
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
	_text(font, Vector2(24, 72), "Opdrachten", 24, Color(0.6, 0.88, 1.0))
	if order.is_empty():
		_text(font, Vector2(24, 112), "Je hebt nog geen opdrachten. Praat met de mensen in het dorp!", 20, Color(1, 1, 1, 0.6))
	var y := 112.0
	for quest_id in order:
		var done := GameState.quest_state(quest_id) == "done"
		var info := Quests.info(quest_id)
		var title: String = ("✓ " if done else "• ") + info["title"] + ("   (hoofdopdracht)" if info.get("main", false) and not done else "")
		y += _text(font, Vector2(24, y), title, 22, Color(0.55, 1.0, 0.65) if done else Color(1.0, 0.9, 0.5)) + 4
		var text := "Voltooid." if done else GameState.quest_text(quest_id)
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
	var cell := mini(int(940.0 / w), int(400.0 / h))
	cell = maxi(cell, 4)
	var origin := Vector2((SIZE.x - w * cell) / 2.0, 100.0)
	_text(font, Vector2(24, 66), world.map_data["name"], 26, Color(0.6, 0.88, 1.0))
	for y in h:
		var row: String = rows[y]
		for x in w:
			content.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), Tiles.map_color(Tiles.name_for(row[x], x, y)))
	content.draw_rect(Rect2(origin, Vector2(w, h) * cell), Color(0.9, 0.95, 1.0), false, 2.0)
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
				content.draw_circle(p, cell * 0.45, Color(0.35, 0.6, 1.0))
			"chest":
				content.draw_rect(Rect2(p - Vector2(cell, cell) * 0.35, Vector2(cell, cell) * 0.7), Color(1.0, 0.8, 0.2))
	var player := Util.player(self)
	if player:
		var pp := origin + (player.global_position / 32.0) * cell
		var pulse := 0.6 + 0.4 * sin(time * 6.0)
		content.draw_circle(pp, cell * 0.6 * (0.8 + pulse * 0.4), Color(1, 0.3, 0.3))
		content.draw_circle(pp, cell * 0.3, Color(1, 1, 1))
	content.draw_string(font, Vector2(24, SIZE.y - 40), "● jij   ● mensen   ■ doorgang   ● altaar (opslaan)   ■ kist", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
