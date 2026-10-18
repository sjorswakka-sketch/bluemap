extends CanvasLayer
## Het menu met zeven tabbladen: voorwerpen (I of Tab), opdrachten (Q), kaart (N), prestaties (T) en beestenboek (B).
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
const Journey := preload("res://scripts/core/journey.gd")

const ProgressionPage := preload("res://scripts/ui/progression_page.gd")

const EquipmentPage := preload("res://scripts/ui/equipment_page.gd")
const Equipment := preload("res://scripts/core/equipment.gd")
const AppearancePage := preload("res://scripts/ui/appearance_page.gd")
const Appearance := preload("res://scripts/core/appearance.gd")

const TAB_COUNT := 8 # de namen staan in tab_titles()
const TAB_QUESTS := 1
const TAB_MAP := 2
const TAB_ACHIEVEMENTS := 3
const TAB_BESTIARY := 4
const TAB_PROGRESSION := 5
const TAB_EQUIPMENT := 6
const TAB_APPEARANCE := 7
const TAB_FONT_SIZE := 14 # acht tabbladen moeten naast elkaar passen
const SIZE := Vector2(1000, 560)
const MARGIN := 24.0 # de buitenmarge van elke bladzijde
const HEADER_Y := 72.0 # de kopregel van elke bladzijde
const LIST_TOP := MenuPages.LIST_TOP # daaronder begint de inhoud (108)
const SLOT := 76.0
const INVENTORY_PAGE_SIZE := 24
const GRID_COLUMNS := 6
const QUEST_VISIBLE := 5
const QUEST_ROW := 72
const FOLLOW_RECT := Rect2(470,474,490,44)
const TRAVEL_VISIBLE := 5
const CLOSE_RECT := Rect2(956, 17, 28, 36)
const PREVIOUS_PAGE := Rect2(24, 456, 38, 32)
const NEXT_PAGE := Rect2(486, 456, 38, 32)
const USE_RECT := Rect2(620, 268, 340, 40)
const MAP_WIDTH := 600.0 # zoveel ruimte krijgt het kaartje; rechts ervan staat het lijstje voor snel reizen
const MAP_HEADER_Y := 60.0 # clear of tab buttons above and coordinate labels below
const MESSAGE_TIME := 3.0 # seconden dat een melding in het kaarttabblad blijft staan
const TAB_ANIM_TIME := 0.16 # seconden die een tabwissel duurt (markering glijdt, pagina faden)
const PAGE_SLIDE := 10.0 # hoeveel pixels de pagina bij een tabwissel meebeweegt

var stock_button: Button
var root: Control
var content: Control
var page: Control # de bladzijde onder de tabbladen; schuift en faden zacht bij een tabwissel
var progression_page: Control
var equipment_page: Control
var appearance_page: Control
var tab := 0
var tab_visual := 0.0 # waar de glijdende tabmarkering nu staat (in tabbladen)
var tab_from := 0.0 # waar de markering vandaan kwam bij de laatste wissel
var tab_anim := 1.0 # hoe ver de wissel is: 0 = net begonnen, 1 = klaar
var hover_tab := -1 # het tabblad onder de muis (-1 = geen)
var hover_close := false # de sluitknop onder de muis
var selected := 0
var quest_selected := 0
var quest_scroll := 0
var repeat_action := ""
var repeat_time := 0.0
var active := false
var opened_frame := -1
var time := 0.0
var markers: Dictionary = Content.map_markers() # extra stipjes op het kaartje voor soorten objecten van uitbreidingen
var achievement_selected := 0 # de gekozen regel in Prestaties en Beestenboek, en hoe ver er gescrold is
var achievement_scroll := 0
var bestiary_selected := 0
var bestiary_scroll := 0
var travel_selected := 0 # het gekozen altaar op de kaart
var travel_scroll := 0
var quest_detail: RichTextLabel
var quest_detail_mode := false
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
	content.gui_input.connect(_pointer_input)
	root.add_child(content)
	stock_button=Button.new()
	stock_button.position=Vector2(322,65)
	stock_button.size=Vector2(198,34)
	stock_button.add_theme_font_size_override("font_size",16)
	stock_button.pressed.connect(_open_stock)
	content.add_child(stock_button)
	page = Control.new()
	page.position = Vector2.ZERO
	page.size = SIZE
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE # muisklikken blijven bij content horen
	page.draw.connect(_draw_page)
	content.add_child(page)
	quest_detail = RichTextLabel.new()
	quest_detail.position = Vector2(470,108)
	quest_detail.size = Vector2(490,350)
	quest_detail.add_theme_font_size_override("normal_font_size",18)
	quest_detail.add_theme_color_override("default_color",Color(0.88,0.94,1))
	quest_detail.focus_mode = Control.FOCUS_ALL
	quest_detail.focus_entered.connect(func() -> void:quest_detail_mode=true)
	quest_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	quest_detail.visible = false
	page.add_child(quest_detail)
	progression_page = ProgressionPage.new()
	progression_page.position = Vector2(24, 72)
	progression_page.size = Vector2(952, 444)
	progression_page.visible = false
	progression_page.close_requested.connect(close)
	page.add_child(progression_page)
	equipment_page = EquipmentPage.new()
	equipment_page.position = Vector2(24, 72)
	equipment_page.size = Vector2(952, 444)
	equipment_page.visible = false
	equipment_page.close_requested.connect(close)
	page.add_child(equipment_page)
	appearance_page = AppearancePage.new()
	appearance_page.position = Vector2(24, 72)
	appearance_page.size = Vector2(952, 444)
	appearance_page.visible = false
	appearance_page.close_requested.connect(close)
	page.add_child(appearance_page)


func open(start_tab: int) -> void:
	tab = clampi(start_tab, 0, TAB_COUNT - 1)
	tab_from = tab
	tab_visual = tab
	tab_anim = 0.0 # het menu faden zacht in
	repeat_action = ""
	selected = 0
	travel_confirm = false
	travel_message = ""
	hover_tab = -1
	hover_close = false
	active = true
	_fit()
	quest_detail_mode = false
	root.visible = true
	_refresh_progression_page()
	opened_frame = Engine.get_process_frames()
	GameState.set_ui("menu", true)
	Sound.play("select", -4.0)
	content.queue_redraw()


func close() -> void:
	repeat_action = ""
	active = false
	root.visible = false
	GameState.set_ui("menu", false)
	Sound.play("select", -6.0)


func _process(delta: float) -> void:
	stock_button.visible=active and tab==0
	stock_button.text=tr("Voorraad")+" ["+Controls.action_label("crafting")+"]"
	time += delta
	travel_message_time = maxf(travel_message_time - delta, 0.0)
	if travel_message_time <= 0.0:
		travel_message = ""
	if not active:
		return
	_fit()
	_repeat_navigation(delta)
	# De tabwissel: de markering glijdt naar het nieuwe tabblad, de bladzijde faden en schuift zacht mee.
	if tab_anim < 1.0:
		tab_anim = minf(tab_anim + delta / TAB_ANIM_TIME, 1.0)
	var eased := 1.0 - pow(1.0 - tab_anim, 3.0) # vlot beginnen, zacht landen
	tab_visual = lerpf(tab_from, float(tab), eased)
	page.modulate.a = eased
	page.position.y = PAGE_SLIDE * (1.0 - eased)
	# De muis licht tabbladen en de sluitknop op (met een controller is er geen aanwijzer).
	update_hover(content.get_local_mouse_position())
	content.queue_redraw()
	page.queue_redraw()

func _fit() -> void:
	var view:=get_viewport().get_visible_rect().size
	var factor:=minf(1.0,minf((view.x-48)/SIZE.x,(view.y-48)/SIZE.y))
	content.scale=Vector2.ONE*maxf(factor,0.1)
	content.position=(view-SIZE*content.scale)*0.5


func _unhandled_input(event: InputEvent) -> void:
	if not Controls.allows_event(event):
		return
	if not active:
		if GameState.input_locked():
			return
		var target := -1
		if event.is_action_pressed("menu"):
			target = 0
		elif event.is_action_pressed("quests"):
			target = TAB_QUESTS
		elif event.is_action_pressed("map"):
			target = TAB_MAP
		elif event.is_action_pressed("wereld_prestaties"):
			target = TAB_ACHIEVEMENTS
		elif event.is_action_pressed("wereld_beestenboek"):
			target = TAB_BESTIARY
		if target >= 0:
			get_viewport().set_input_as_handled()
			open(target)
		return
	if Engine.get_process_frames() == opened_frame or event.is_echo():
		return
	if tab==0 and event.is_action_pressed("crafting"):
		get_viewport().set_input_as_handled()
		_open_stock()
		return
	if travel_confirm and _answer_travel_question(event):
		return
	if UiStyle.shortcut(event, "pause") or event.is_action_pressed("ui_cancel") or UiStyle.shortcut(event, "menu"):
		close()
	elif event.is_action_pressed("ui_prev_tab"):
		_step_tab(-1)
	elif event.is_action_pressed("ui_next_tab"):
		_step_tab(1)
	elif UiStyle.shortcut(event, "quests"):
		_toggle_tab(TAB_QUESTS)
	elif UiStyle.shortcut(event, "map"):
		_toggle_tab(TAB_MAP)
	elif UiStyle.shortcut(event, "wereld_prestaties"):
		_toggle_tab(TAB_ACHIEVEMENTS)
	elif UiStyle.shortcut(event, "wereld_beestenboek"):
		_toggle_tab(TAB_BESTIARY)
	else:
		for action: String in ["ui_left", "ui_right", "ui_up", "ui_down"]:
			if event.is_action_pressed(action):
				if event is InputEventJoypadMotion:
					var stick := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
					var dominant: String = ("ui_left" if stick.x < 0 else "ui_right") if absf(stick.x) > absf(stick.y) else ("ui_up" if stick.y < 0 else "ui_down")
					if action == repeat_action or action != dominant:
						get_viewport().set_input_as_handled()
						return
				_navigate(action)
				repeat_action = action
				repeat_time = 0.35
				get_viewport().set_input_as_handled()
				return
		if tab == 0:
			if UiStyle.confirm(event):
				_use_selected()
			elif UiStyle.shortcut(event, "potion"):
				_drink()
		elif tab == TAB_EQUIPMENT and UiStyle.confirm(event):
			equipment_page.confirm()
		elif tab == TAB_APPEARANCE and UiStyle.confirm(event):
			appearance_page.confirm()
		elif tab == TAB_MAP:
			_map_input(event)
		elif tab == TAB_QUESTS and UiStyle.confirm(event):
			_follow_quest()
	# Custom drawn menus own input while open; gameplay cannot receive the close/confirm press.
	if event.is_pressed():
		get_viewport().set_input_as_handled()


func _repeat_navigation(delta: float) -> void:
	if repeat_action == "":
		return
	if not Input.is_action_pressed(repeat_action):
		repeat_action = ""
		return
	repeat_time -= delta
	if repeat_time <= 0.0:
		_navigate(repeat_action)
		repeat_time = 0.11


func _navigate(action: String) -> void:
	travel_confirm = false
	var step := -1 if action in ["ui_up", "ui_left"] else 1
	match tab:
		0:
			var count := _owned().size()
			if action in ["ui_up", "ui_down"]:
				step *= GRID_COLUMNS
			selected = clampi(selected + step, 0, maxi(count - 1, 0))
		TAB_QUESTS:
			if action=="ui_right":
				quest_detail_mode=true;quest_detail.grab_focus()
			elif action=="ui_left":
				quest_detail_mode=false;quest_detail.release_focus()
			elif quest_detail_mode:
				quest_detail.get_v_scroll_bar().value += step*48
			else:
				quest_selected = clampi(quest_selected + step, 0, maxi(_quest_order().size() - 1, 0))
		TAB_MAP:
			travel_selected = clampi(travel_selected + step, 0, maxi(FastTravel.discovered_altars().size() - 1, 0))
			refresh_travel_scroll()
		TAB_ACHIEVEMENTS:
			achievement_selected = clampi(achievement_selected + step, 0, Achievements.ACHIEVEMENTS.size() - 1)
		TAB_EQUIPMENT:
			equipment_page.navigate(action)
		TAB_APPEARANCE:
			appearance_page.navigate(action)
		TAB_PROGRESSION:
			progression_page.navigate(action)
		TAB_BESTIARY:
			bestiary_selected = clampi(bestiary_selected + step, 0, Enemies.ENEMIES.size() - 1)
	Sound.play("select", -12.0)


func _pointer_input(event: InputEvent) -> void:
	if not active or Controls.controller_active or not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed:
		return
	content.accept_event()
	if click.button_index == MOUSE_BUTTON_RIGHT:
		if travel_confirm:
			travel_confirm = false
		else:
			close()
		return
	if click.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_navigate("ui_up" if click.button_index == MOUSE_BUTTON_WHEEL_UP else "ui_down")
		return
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	var at := click.position
	if CLOSE_RECT.has_point(at):
		close()
		return
	for i in TAB_COUNT:
		if tab_rect(i).has_point(at):
			_set_tab(i)
			return
	match tab:
		0:
			var count := _owned().size()
			if PREVIOUS_PAGE.has_point(at):
				selected = maxi(inventory_page_start() - INVENTORY_PAGE_SIZE, 0)
			elif NEXT_PAGE.has_point(at):
				selected = mini(inventory_page_start() + INVENTORY_PAGE_SIZE, maxi(count - 1, 0))
			elif USE_RECT.has_point(at):
				_use_selected()
			else:
				for i in range(inventory_page_start(), mini(inventory_page_start() + INVENTORY_PAGE_SIZE, count)):
					var index := i - inventory_page_start()
					var slot := Rect2(24 + (index % GRID_COLUMNS) * (SLOT + 8), 110 + (index / GRID_COLUMNS) * (SLOT + 8), SLOT, SLOT)
					if slot.has_point(at):
						selected = i
						if click.double_click:
							_use_selected()
						break
		TAB_QUESTS:
			if FOLLOW_RECT.has_point(at): _follow_quest()
			elif Rect2(24, 108, 420, QUEST_VISIBLE * QUEST_ROW).has_point(at):
				quest_detail_mode=false
				quest_detail.release_focus()
				quest_selected = mini(quest_scroll + int((at.y - 108) / QUEST_ROW), maxi(_quest_order().size() - 1, 0))
		TAB_ACHIEVEMENTS:
			if Rect2(24, MenuPages.LIST_TOP, 938, MenuPages.LIST_BOTTOM - MenuPages.LIST_TOP).has_point(at):
				achievement_selected = mini(achievement_scroll + int((at.y - MenuPages.LIST_TOP) / MenuPages.ACHIEVEMENT_ROW), Achievements.ACHIEVEMENTS.size() - 1)
		TAB_BESTIARY:
			if Rect2(24, MenuPages.LIST_TOP, 300, MenuPages.LIST_BOTTOM - MenuPages.LIST_TOP).has_point(at):
				bestiary_selected = mini(bestiary_scroll + int((at.y - MenuPages.LIST_TOP) / MenuPages.BEAST_ROW), Enemies.ENEMIES.size() - 1)
		TAB_MAP:
			var altars := FastTravel.discovered_altars()
			refresh_travel_scroll(altars.size())
			for i in range(travel_scroll,mini(travel_scroll+TRAVEL_VISIBLE,altars.size())):
				if Rect2(660, 104 + (i-travel_scroll) * 48, 316, 42).has_point(at):
					travel_selected = i
					travel_confirm = false
					_map_input(_confirm_event())
					return
			if travel_confirm:
				var box_y := travel_box_y(altars.size())
				if Rect2(672, box_y + 70, 142, 32).has_point(at):
					_answer_travel_question(_confirm_event())
				elif Rect2(826, box_y + 70, 138, 32).has_point(at):
					travel_confirm = false


func _confirm_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	return event


## Werkt de hover bij voor een muispositie (plaatselijk in het menu). Met een controller is er geen aanwijzer.
func update_hover(mouse: Vector2) -> void:
	if Controls.controller_active:
		hover_tab = -1
		hover_close = false
		return
	hover_tab = -1
	for i in TAB_COUNT:
		if tab_rect(i).has_point(mouse):
			hover_tab = i
	hover_close = CLOSE_RECT.has_point(mouse)

func _set_tab(new_tab: int) -> void:
	tab_from = tab_visual
	tab = new_tab
	tab_anim = 0.0 # de markering glijdt en de bladzijde faden naar het nieuwe tabblad
	repeat_action = ""
	selected = 0
	travel_confirm = false
	quest_detail_mode = false
	Sound.play("select", -8.0)
	_refresh_progression_page()


func _step_tab(step: int) -> void:
	_set_tab((tab + step + TAB_COUNT) % TAB_COUNT)


## De namen van de tabbladen in de taal van de speler: voorwerpen, opdrachten, kaart, prestaties en beestenboek.
func tab_titles() -> Array[String]:
	return [tr("Voorwerpen"), tr("Opdrachten"), tr("Kaart"), tr("Prestaties"), tr("Beestenboek"), tr("Voortgang"), tr("Uitrusting"), tr("Uiterlijk")]


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
	elif UiStyle.confirm(event):
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
	if UiStyle.confirm(event):
		get_viewport().set_input_as_handled()
		var altars := FastTravel.discovered_altars()
		var world := Util.world(self)
		travel_confirm = false
		if world != null and not altars.is_empty():
			var altar: Dictionary = altars[clampi(travel_selected, 0, altars.size() - 1)]
			close()
			FastTravel.travel(world, altar)
		return true
	if UiStyle.shortcut(event, "pause") or event.is_action_pressed("ui_cancel"):
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
	if load("res://scripts/core/stockroom.gd").state().sort>0:
		var data: Dictionary={}
		for id: String in owned:data[id]=GameState.count(id)
		return load("res://scripts/core/stockroom.gd").ids(data)
	return owned


func _use_selected() -> void:
	var owned := _owned()
	if selected >= owned.size():
		return
	if Equipment.slot_of(owned[selected]) != "":
		if Equipment.equip(owned[selected]):
			Sound.play("select", -5.0)
	elif Appearance.clothing_slot_of(owned[selected]) != "":
		if Appearance.wear(owned[selected]):
			Sound.play("select", -5.0)
	elif owned[selected] in Professions.CONSUMABLES:
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
	# Tabbladen: eerst de rustige achtergronden (met een lichtere tint onder de muis), dan de
	# markering die naar het gekozen tabblad glijdt, dan de titels.
	for i in TAB_COUNT:
		var rect := tab_rect(i)
		var fill := Color(0.1, 0.16, 0.3)
		if i == hover_tab and i != tab:
			fill = fill.lightened(0.25)
		content.draw_rect(rect, fill)
		content.draw_rect(rect, Color(0.3, 0.45, 0.7), false, 2.0)
	var mark := tab_rect(tab)
	mark.position.x = MARGIN + tab_visual * _tab_stride()
	content.draw_rect(mark, Color(0.2, 0.35, 0.65))
	content.draw_rect(mark, Color(0.6, 0.85, 1.0), false, 2.0)
	var titles := tab_titles()
	for i in TAB_COUNT:
		var rect := tab_rect(i)
		content.draw_string(font, rect.position + Vector2(0, 28), titles[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, TAB_FONT_SIZE,
			Color.WHITE if i == tab else Color(0.7, 0.8, 1.0))
	content.draw_rect(CLOSE_RECT, Color(0.32, 0.42, 0.62) if hover_close else Color(0.22, 0.3, 0.48))
	content.draw_string(font, CLOSE_RECT.position + Vector2(0, 26), "×", HORIZONTAL_ALIGNMENT_CENTER, CLOSE_RECT.size.x, 24)
	content.draw_string(font, Vector2(MARGIN, SIZE.y - 16), _footer_hint(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.55))


## De bladzijde van het gekozen tabblad (tekent op `page`, zodat de tabwissel zacht kan overgaan).
func _draw_page() -> void:
	var font := ThemeDB.fallback_font
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
	var browse := tr("%s / %s tabblad  ·  ") % [Controls.action_label("ui_prev_tab"), Controls.action_label("ui_next_tab")]
	var close_hint := tr("%s sluiten") % Controls.action_label("ui_cancel")
	if tab == 0:
		return tr("↑ ↓ ← → kiezen  ·  %s gebruiken  ·  ") % Controls.action_label("ui_accept") + browse + close_hint
	if tab == TAB_EQUIPMENT:
		return tr("↑ ↓ kiezen  ·  ← → vakken  ·  %s bevestigen  ·  ") % Controls.action_label("ui_accept") + browse + close_hint
	if tab == TAB_APPEARANCE:
		return tr("↑ ↓ rij  ·  ← → aanpassen  ·  %s verf  ·  ") % Controls.action_label("ui_accept") + browse + close_hint
	if tab == TAB_PROGRESSION:
		return tr("↑ ↓ kiezen  ·  ← → uitleg scrollen  ·  ") + browse + close_hint
	if tab == TAB_MAP:
		return tr("↑ ↓ altaar  ·  %s reizen  ·  ") % Controls.action_label("ui_accept") + browse + close_hint
	if tab == TAB_QUESTS:
		return tr("↑ ↓ opdracht  ·  → uitleg  ·  ← lijst  ·  %s volgen  ·  ") % Controls.action_label("ui_accept") + browse + close_hint
	return tr("↑ ↓ bladeren  ·  ") + browse + close_hint

func _text(font: Font, pos: Vector2, text: String, size: int, color := Color.WHITE, width := -1.0) -> float:
	## Tekent (eventueel afgebroken) tekst op de bladzijde en geeft de hoogte terug.
	return MenuPages.text(page, font, pos, text, size, color, width)


func inventory_page_start() -> int:
	return floori(float(selected) / INVENTORY_PAGE_SIZE) * INVENTORY_PAGE_SIZE


func _draw_items(font: Font) -> void:
	var owned := _owned()
	selected = clampi(selected, 0, maxi(owned.size() - 1, 0))
	_text(font, Vector2(MARGIN, HEADER_Y), tr("Je spullen"), 24, Color(0.6, 0.88, 1.0))
	if owned.is_empty():
		_text(font, Vector2(MARGIN, 112), tr("Je hebt nog niets bij je."), 20, Color(1, 1, 1, 0.6))
	var first := inventory_page_start()
	var last := mini(first + INVENTORY_PAGE_SIZE, owned.size())
	for i in range(first, last):
		var local_index := i - first
		var pos := Vector2(MARGIN + (local_index % 6) * (SLOT + 8), LIST_TOP + floori(float(local_index) / 6.0) * (SLOT + 8))
		var chosen := i == selected
		page.draw_rect(Rect2(pos, Vector2(SLOT, SLOT)), Color(0.18, 0.3, 0.55) if chosen else Color(0.1, 0.16, 0.3))
		page.draw_rect(Rect2(pos, Vector2(SLOT, SLOT)), Color(1.0, 0.88, 0.35) if chosen else Color(0.3, 0.45, 0.7), false, 3.0 if chosen else 2.0)
		var icon: int = Items.ITEMS[owned[i]]["icon"]
		# Het gekozen icoon ademt zachtjes, zodat duidelijk is waar je staat.
		var icon_size := 56.0 * (1.0 + 0.05 * sin(time * 5.0)) if chosen else 56.0
		var icon_pos := pos + (Vector2(SLOT, SLOT) - Vector2(icon_size, icon_size)) / 2.0 + Vector2(0, -4)
		page.draw_texture_rect_region(Art.tex(Items.sheet_of(owned[i])), Rect2(icon_pos, Vector2(icon_size, icon_size)), Rect2(Vector2(icon * 16, 0), Vector2(16, 16)))
		if load("res://scripts/core/stockroom.gd").favorite(owned[i]):
			page.draw_string(font,pos+Vector2(5,18),"★",HORIZONTAL_ALIGNMENT_LEFT,20,17,Color("e7d4a2"))
		var count := GameState.count(owned[i])
		if count > 1:
			page.draw_string_outline(font, pos + Vector2(SLOT - 26, SLOT - 6), "x%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0))
			page.draw_string(font, pos + Vector2(SLOT - 26, SLOT - 6), "x%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if owned.size() > INVENTORY_PAGE_SIZE:
		_text(font, Vector2(76, 459), tr(ProfessionData.TEXT["inventory_page"]) % [first + 1, last, owned.size()], 17, Color(0.7, 0.8, 0.95))
		for button_rect: Rect2 in [PREVIOUS_PAGE, NEXT_PAGE]:
			page.draw_rect(button_rect, Color(0.15, 0.25, 0.45))
		page.draw_string(font, PREVIOUS_PAGE.position + Vector2(0, 24), "‹", HORIZONTAL_ALIGNMENT_CENTER, 38, 24)
		page.draw_string(font, NEXT_PAGE.position + Vector2(0, 24), "›", HORIZONTAL_ALIGNMENT_CENTER, 38, 24)

	# Rechts: omschrijving en gegevens
	var x := 620.0
	if not owned.is_empty():
		var info: Dictionary = Items.ITEMS[owned[selected]]
		var h := _text(font, Vector2(x, HEADER_Y), tr(info["name"]), 24, Color(1.0, 0.9, 0.5), 340)
		h += _text(font, Vector2(x, HEADER_Y + h + 6), tr(info["desc"]), 18, Color(0.9, 0.93, 1.0), 340) + 6
		if info.get("type","") == "material":
			var journal: Script = preload("res://scripts/core/craft_journal.gd")
			h += _text(font,Vector2(x,HEADER_Y+h+6),tr("Vindplaats: %s") % journal.source(owned[selected]),16,Color(0.65,0.85,1),340)+6
			_text(font,Vector2(x,HEADER_Y+h+6),journal.uses_text(owned[selected]),16,Color(0.75,0.92,0.72),340)
		var equipment_slot := Equipment.slot_of(owned[selected])
		if equipment_slot != "":
			var equipped := Equipment.equipped(equipment_slot) == owned[selected]
			_text(font, Vector2(x, 216), tr("Uitgerust · %s") % Equipment.stats_text(owned[selected]) if equipped else tr("Bonus: %s") % Equipment.stats_text(owned[selected]), 17, Color(0.6, 0.95, 0.8), 340)
			page.draw_rect(USE_RECT, Color(0.12, 0.2, 0.3) if equipped else Color(0.15, 0.32, 0.3))
			page.draw_string(font, USE_RECT.position + Vector2(0, 27), tr("Uitgerust") if equipped else tr("%s  Uitrusten") % Controls.action_label("ui_accept"), HORIZONTAL_ALIGNMENT_CENTER, USE_RECT.size.x, 20, Color(0.6, 1.0, 0.7))
		elif owned[selected] in Professions.CONSUMABLES:
			page.draw_rect(USE_RECT, Color(0.15, 0.32, 0.3))
			page.draw_string(font, USE_RECT.position + Vector2(0, 27), tr("%s  Gebruiken") % Controls.action_label("ui_accept"), HORIZONTAL_ALIGNMENT_CENTER, USE_RECT.size.x, 20, Color(0.6, 1.0, 0.7))
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
		UiStyle.draw_star(page, Vector2(36, SIZE.y - 42), 11.0, Color(1.0, 0.85, 0.3))
		# Vertalers: Nieuw spel+ is de naam van de knop op het titelscherm; ronde 2 = de tweede keer opnieuw
		_text(font, Vector2(56, SIZE.y - 56), tr("Nieuw spel+  ·  ronde %d") % GameState.ng_plus, 20, Color(1.0, 0.9, 0.5))
	page.draw_line(Vector2(x, 330), Vector2(x + 340, 330), Color(0.3, 0.45, 0.7), 2.0)
	var y := 342.0
	for line: String in lines:
		_text(font, Vector2(x, y), line, 20, Color(0.85, 0.92, 1.0))
		y += 28.0


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func _quest_order() -> Array[String]:
	var order: Array[String] = []
	for state: String in ["active", "done"]:
		for quest_id: String in Quests.QUESTS:
			if GameState.quest_state(quest_id) == state:
				order.append(quest_id)
	return order


func _draw_quests(font: Font) -> void:
	var order := _quest_order()
	_text(font, Vector2(MARGIN, HEADER_Y), tr("Opdrachten"), 24, Color(0.6, 0.88, 1.0))
	if order.is_empty():
		_text(font, Vector2(MARGIN, 112), tr("Je hebt nog geen opdrachten. Praat met de mensen in het dorp!"), 20, Color(1, 1, 1, 0.6))
		return
	quest_selected = clampi(quest_selected, 0, order.size() - 1)
	quest_scroll = MenuPages.follow(quest_selected, quest_scroll, QUEST_VISIBLE, order.size())
	for index in range(quest_scroll, mini(quest_scroll + QUEST_VISIBLE, order.size())):
		var quest_id := order[index]
		var done := GameState.quest_state(quest_id) == "done"
		var info := Quests.info(quest_id)
		var title := tr(info["title"])
		title = ("✓ " if done else "◆ " if Journey.focus()==quest_id else "• ") + title
		var rect := Rect2(MARGIN, LIST_TOP + (index - quest_scroll) * QUEST_ROW, 420, QUEST_ROW-6)
		page.draw_rect(rect, Color(0.18, 0.3, 0.55) if index == quest_selected else Color(0.1, 0.16, 0.3))
		if index == quest_selected:
			page.draw_rect(rect, Color(1.0, 0.88, 0.35), false, 2.0)
		_text(font, rect.position + Vector2(12, 4), title, 19, Color(0.55, 1.0, 0.65) if done else Color(1.0, 0.9, 0.5), 392)
		var status := tr("Afgerond") if done else tr("Stap %d / %d") % [GameState.quest_step(quest_id)+1,info.steps.size()]
		if info.get("main",false) and not done:status=tr("Hoofdverhaal")+" · "+status
		_text(font, rect.position + Vector2(12, 36), status, 16, Color(0.85, 0.9, 1.0), 392)
	MenuPages.scrollbar(page, quest_scroll, QUEST_VISIBLE, order.size(), 450,LIST_TOP+QUEST_VISIBLE*QUEST_ROW)
	var chosen: String=order[quest_selected]
	var detail_text:=Journey.detail(chosen)
	if quest_detail.text!=detail_text:
		quest_detail.text=detail_text
		quest_detail.scroll_to_line(0)
	page.draw_rect(Rect2(466,104,498,358),Color(0.65,0.86,1) if quest_detail_mode else Color(0.3,0.45,0.7),false,2)
	var can_follow:=GameState.quest_state(chosen)=="active"
	page.draw_rect(FOLLOW_RECT,Color(0.15,0.36,0.28) if can_follow else Color(0.15,0.2,0.28))
	var label:=tr("Stop met volgen") if Journey.focus()==chosen else tr("Volg deze opdracht") if can_follow else tr("Deze opdracht is afgerond")
	page.draw_string(font,FOLLOW_RECT.position+Vector2(12,29),label,HORIZONTAL_ALIGNMENT_CENTER,FOLLOW_RECT.size.x-24,19,Color.WHITE)

func _follow_quest() -> void:
	var order:=_quest_order()
	if order.is_empty():return
	if Journey.toggle(order[clampi(quest_selected,0,order.size()-1)]):Sound.play("select",-6)
	else:Sound.play("error",-8)

func refresh_travel_scroll(total: int=-1) -> void:
	if total<0:total=FastTravel.discovered_altars().size()
	travel_scroll=MenuPages.follow(travel_selected,travel_scroll,TRAVEL_VISIBLE,total)

func travel_box_y(total: int) -> float:
	return 104+mini(total,TRAVEL_VISIBLE)*48+12+(16 if total>TRAVEL_VISIBLE else 0)

func _draw_map(font: Font) -> void:
	var world := Util.world(self)
	if world == null or world.map_data.is_empty():
		return
	var rows: Array = world.map_data["rows"]
	var w: int = rows[0].length()
	var h: int = rows.size()
	var cell := mini(int(MAP_WIDTH / w), int(320.0 / h))
	cell = maxi(cell, 4)
	var origin := Vector2(MARGIN + (MAP_WIDTH - w * cell) / 2.0, LIST_TOP)
	_text(font, Vector2(MARGIN, MAP_HEADER_Y), tr(world.map_data["name"]), 24, Color(0.6, 0.88, 1.0))
	for y in h:
		var row: String = rows[y]
		for x in w:
			page.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), Tiles.map_color(Tiles.name_for(row[x], x, y)))
	page.draw_rect(Rect2(origin, Vector2(w, h) * cell), Color(0.9, 0.95, 1.0), false, 2.0)
	for x in range(4,w,5):page.draw_string(font,origin+Vector2((x+0.5)*cell-4,-4),str(x+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.75,0.84,0.95))
	for y in range(4,h,5):page.draw_string(font,origin+Vector2(-16,(y+0.5)*cell+3),str(y+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.75,0.84,0.95))
	var focused:=Journey.focus()
	var route: Array[String]=[]
	if focused!="":route=Journey.path(GameState.map_id,Journey.target(focused),false)
	var altars := FastTravel.discovered_altars()
	travel_selected = clampi(travel_selected, 0, maxi(altars.size() - 1, 0))
	for obj: Dictionary in world.map_data.get("objects", []):
		if not obj.get("enabled",true):continue
		if obj.has("if") and not GameState.check_all(obj["if"]):
			continue
		var p := origin + (Vector2(float(obj["pos"][0]), float(obj["pos"][1])) + Vector2(0.5, 0.5)) * cell
		match obj["type"]:
			"npc":
				page.draw_circle(p, cell * 0.45, Color(0.4, 1.0, 1.0))
			"portal":
				page.draw_rect(Rect2(p - Vector2(cell, cell) * 0.4, Vector2(cell, cell) * 0.8), Color(1, 1, 1))
				if route.size()>1 and obj.to==route[1]:page.draw_arc(p,cell*0.9,0,TAU,24,Color(1,0.86,0.4),2)
			"savepoint":
				_draw_altar_marker(p, cell, obj, altars)
			"chest":
				page.draw_rect(Rect2(p - Vector2(cell, cell) * 0.35, Vector2(cell, cell) * 0.7), Color(1.0, 0.8, 0.2))
	var marks := extension_marks(world.map_data)
	for mark: Dictionary in marks:
		_draw_diamond(origin + (Vector2(float(mark["pos"][0]), float(mark["pos"][1])) + Vector2(0.5, 0.5)) * cell, cell * 0.5, mark["color"])
	var player := Util.player(self)
	if player:
		var pp := origin + (player.global_position / 32.0) * cell
		var pulse := 0.6 + 0.4 * sin(time * 6.0)
		page.draw_circle(pp, cell * 0.6 * (0.8 + pulse * 0.4), Color(1, 0.3, 0.3))
		page.draw_circle(pp, cell * 0.3, Color(1, 1, 1))
	page.draw_string(font, Vector2(MARGIN, SIZE.y - 40), tr("● jij   ● mensen   ■ doorgang   ● altaar (opslaan)   ■ kist"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
	# Legenda voor de bijzondere plekken van uitbreidingen die op deze kaart staan.
	var legend: Dictionary = {}
	for mark: Dictionary in marks:
		legend[tr(mark["label"])] = mark["color"]
	if route.size()>1:_text(font,Vector2(MARGIN,438),tr("Gouden ring: volgende doorgang voor je gevolgde opdracht."),14,Color(1,0.86,0.4),MAP_WIDTH)
	for entry: Dictionary in map_legend_layout(legend,font):
		page.draw_string(font,entry.at,entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(entry.get("font_size",14)),entry.color)
	MenuPages.draw_travel_panel(self, font, altars)

func map_legend_layout(legend: Dictionary,font: Font) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var x:=MARGIN
	var row:=0
	for label: String in legend:
		var text: String="◆ "+label
		var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		if x+width>MARGIN+MAP_WIDTH:x=MARGIN;row+=1
		if row>1:break
		result.append({"text":text,"at":Vector2(x,478+row*22),"color":legend[label],"width":width})
		x+=width+16
	if result.size()==legend.size():return result
	# Balance long category names across both rows instead of dropping the last entry.
	var labels: Array=legend.keys()
	labels.sort_custom(func(a,b):return font.get_string_size(str(a),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x>font.get_string_size(str(b),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x)
	for font_size in [14,13,12]:
		result.clear()
		var used: Array[float]=[0.0,0.0]
		for label: String in labels:
			var text: String="◆ "+label
			var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			var target:=0 if used[0]<=used[1] else 1
			if used[target]+width>MAP_WIDTH:target=1-target
			if used[target]+width>MAP_WIDTH:break
			result.append({"text":text,"at":Vector2(MARGIN+used[target],478+target*22),"color":legend[label],"width":width,"font_size":font_size})
			used[target]+=width+12
		if result.size()==legend.size():return result
	return result


## De bijzondere plekken van uitbreidingen op een kaart (zie MAP_MARKERS in content.gd): [{"pos", "color", "label"}].
## Het label is de Nederlandse naam uit de module; de legenda vertaalt hem bij het tekenen.
func extension_marks(map_data: Dictionary) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	for obj: Dictionary in map_data.get("objects", []):
		if not obj.get("enabled",true):continue
		if markers.has(obj["type"]) and (not obj.has("if") or GameState.check_all(obj["if"])):
			marks.append({"pos": obj["pos"], "color": markers[obj["type"]]["color"], "label": markers[obj["type"]]["label"]})
	return marks


## Een klein ruitje, voor de bijzondere plekken van uitbreidingen op het kaartje.
func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	page.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


## Een altaar op het kaartje: ontdekt = helder met een witte rand, anders vager. Het gekozen altaar pulseert.
func _draw_altar_marker(p: Vector2, cell: int, obj: Dictionary, altars: Array) -> void:
	var key := FastTravel.altar_key(GameState.map_id, Vector2i(int(obj["pos"][0]), int(obj["pos"][1])))
	var found := GameState.flag(key)
	page.draw_circle(p, cell * 0.45, Color(0.35, 0.6, 1.0) if found else Color(0.25, 0.4, 0.65))
	if found:
		page.draw_arc(p, cell * 0.6, 0.0, TAU, 16, Color(1, 1, 1), 2.0)
	if not altars.is_empty() and altars[travel_selected]["key"] == key:
		var pulse := 0.5 + 0.5 * sin(time * 6.0)
		page.draw_arc(p, cell * (0.9 + pulse * 0.5), 0.0, TAU, 24, Color(1.0, 0.88, 0.35), 3.0)

func _exit_tree() -> void:
	if active:
		GameState.set_ui("menu", false)


func _tab_stride() -> float:
	return (CLOSE_RECT.position.x - MARGIN - 8.0) / TAB_COUNT


func tab_rect(index: int) -> Rect2:
	return Rect2(MARGIN + index * _tab_stride(), 16, _tab_stride() - 8.0, 40)


func _refresh_progression_page() -> void:
	quest_detail.visible = tab == TAB_QUESTS
	equipment_page.visible = tab == TAB_EQUIPMENT
	if equipment_page.visible:
		equipment_page.refresh()
	appearance_page.visible = tab == TAB_APPEARANCE
	if appearance_page.visible:
		appearance_page.queue_redraw()
	progression_page.visible = tab == TAB_PROGRESSION
	if progression_page.visible:
		progression_page.refresh()

func _open_stock():
	if not active or tab!=0:return
	var world: Node2D=get_tree().current_scene
	var old_map:=GameState.map_id
	close()
	var ui: CanvasLayer=load("res://scripts/ui/stock_ui.gd").new()
	ui.world=world;world.add_child(ui)
	ui.closed.connect(func():
		if is_instance_valid(world) and GameState.map_id==old_map and not GameState.transitioning and not GameState.ended:open(0))
	var kind: String=load("res://scripts/core/stockroom.gd").nearby_kind()
	ui.open("coast" if kind=="coast" else "home")
