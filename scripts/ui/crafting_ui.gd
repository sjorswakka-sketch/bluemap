extends CanvasLayer
## C opens a keyboard/controller-accessible profession journal and crafting menu.

const Data := preload("res://scripts/data/ext/beroepen.gd")
const Professions := preload("res://scripts/core/professions.gd")
const Items := preload("res://scripts/data/items.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")
const Journal := preload("res://scripts/core/craft_journal.gd")

var root: Control
var panel: PanelContainer
var scroll: ScrollContainer
var skill_list: VBoxContainer
var rows: VBoxContainer
var detail: RichTextLabel
var goal_button: Button
var filter: OptionButton
var recipes_button: Button
var supplies_button: Button
var close_button: Button
var hint: Label
var title_label: Label
var intro_label: Label
var active := false
var opened_frame := -1
var supplies := false
var selected_skill := ""
var selected_entry := ""
var _population_version := 0


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	root.hide()
	Lang.changed.connect(_refresh_language)


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	root.add_child(dim)
	panel = PanelContainer.new()
	UiStyle.style_panel(panel)
	panel.custom_minimum_size = Vector2(1050, 580)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	title_label = UiStyle.make_label(tr(Data.TEXT["title"]), 30, Color(0.73, 0.91, 0.67))
	box.add_child(title_label)
	intro_label = _wrapped("", 17)
	intro_label.custom_minimum_size.x = 985
	box.add_child(intro_label)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	box.add_child(content)
	skill_list = VBoxContainer.new()
	skill_list.custom_minimum_size = Vector2(245, 0)
	skill_list.add_theme_constant_override("separation", 3)
	content.add_child(skill_list)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(740, 0)
	content.add_child(right)
	var nav := HBoxContainer.new()
	right.add_child(nav)
	recipes_button = _button(tr(Data.TEXT["recipes"]))
	recipes_button.pressed.connect(func() -> void: supplies = false; _populate())
	nav.add_child(recipes_button)
	supplies_button = _button(tr(Data.TEXT["supplies"]))
	supplies_button.pressed.connect(func() -> void: supplies = true; _populate())
	nav.add_child(supplies_button)
	filter = OptionButton.new()
	UiStyle.style_button(filter, 18)
	filter.custom_minimum_size = Vector2(180, 38)
	filter.add_item(tr(Data.TEXT["skills"]))
	for skill: String in Data.SKILLS:
		filter.add_item(tr(Data.SKILLS[skill]["name"]))
	filter.item_selected.connect(func(index: int) -> void:
		selected_skill = "" if index == 0 else str(Data.SKILLS.keys()[index - 1])
		_populate())
	nav.add_child(filter)
	close_button = _button(tr("Sluiten"))
	close_button.custom_minimum_size.x = 100
	close_button.pressed.connect(close)
	nav.add_child(close_button)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Scroll in local coordinates: native follow_focus overshoots inside a scaled panel.
	scroll.follow_focus = false
	right.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	detail = RichTextLabel.new()
	detail.custom_minimum_size = Vector2(0,100)
	detail.add_theme_font_size_override("normal_font_size",16)
	detail.focus_mode = Control.FOCUS_ALL
	detail.scroll_active = true
	detail.gui_input.connect(_detail_input)
	box.add_child(detail)
	goal_button = _button("")
	_compact(goal_button)
	goal_button.custom_minimum_size.y = 32
	goal_button.pressed.connect(func() -> void:
		Journal.toggle_goal(selected_entry)
		_refresh_goal_button())
	box.add_child(goal_button)
	hint = UiStyle.make_label("", 16, Color(0.72, 0.77, 0.85))
	box.add_child(hint)


func _button(text: String) -> Button:
	var button := Button.new()
	UiStyle.style_button(button, 18)
	button.text = text
	button.custom_minimum_size = Vector2(160, 38)
	return button


func _wrapped(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _compact(button: Button) -> void:
	button.add_theme_font_size_override("font_size",16)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(state,style)


func _process(_delta: float) -> void:
	if not active:
		return
	hint.text = tr("↑ ↓ ← → kiezen  ·  %s bevestigen  ·  %s / %s recepten/voorraad  ·  %s sluiten") % [Controls.action_label("ui_accept"), Controls.action_label("ui_prev_tab"), Controls.action_label("ui_next_tab"), Controls.action_label("ui_cancel")]
	intro_label.text = tr("Verzamel met %s. Vindplaatsen staan bij het recept; stel een materiaaldoel in. Gereedschap slijt niet.") % Controls.action_label("interact")
	# Font metrics, translations and window sizes can differ. Fit the complete
	# panel before centering so the footer and every control stay on-screen.
	panel.size = panel.get_combined_minimum_size()
	var view: Vector2 = root.size
	var factor := minf(1.0, minf((view.x - 24.0) / panel.size.x, (view.y - 24.0) / panel.size.y))
	panel.scale = Vector2.ONE * maxf(factor, 0.1)
	panel.position = (view - panel.size * panel.scale) * 0.5


func open(recipe_id: String = "") -> void:
	if active or GameState.input_locked():
		return
	if Data.RECIPES.has(recipe_id):
		selected_entry=recipe_id;selected_skill=Data.RECIPES[recipe_id].skill;supplies=false;filter.select(Data.SKILLS.keys().find(selected_skill)+1)
	elif Journal.goal() != "":
		selected_entry = Journal.goal()
		selected_skill = Data.RECIPES[selected_entry].skill
		supplies = false
		filter.select(Data.SKILLS.keys().find(selected_skill)+1)
	active = true
	opened_frame = Engine.get_process_frames()
	root.show()
	GameState.set_ui("crafting", true)
	_populate()


func close() -> void:
	active = false
	root.hide()
	GameState.set_ui("crafting", false)


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _populate() -> void:
	_population_version += 1
	scroll.scroll_vertical = 0
	_clear(skill_list)
	_clear(rows)
	detail.text = ""
	for skill: String in Data.SKILLS:
		var lv := Professions.level(skill)
		var button := _button(tr(Data.TEXT["skill_line"]) % [tr(Data.SKILLS[skill]["name"]), lv])
		_compact(button)
		button.custom_minimum_size.y = 34
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void:
			supplies = false
			selected_skill = skill
			filter.select(Data.SKILLS.keys().find(skill) + 1)
			_populate())
		var xp_text: String = tr(Data.TEXT["master"]) if lv == Professions.MAX_LEVEL else tr(Data.TEXT["xp"]) % [Professions.xp(skill) - Professions.threshold(lv), Professions.threshold(lv + 1) - Professions.threshold(lv)]
		button.focus_entered.connect(func() -> void: detail.text = tr(Data.SKILLS[skill]["desc"]) + "\n" + xp_text)
		skill_list.add_child(button)
		var progress := ProgressBar.new()
		progress.custom_minimum_size = Vector2(0, 7)
		progress.show_percentage = false
		progress.max_value = 1.0 if lv == Professions.MAX_LEVEL else float(Professions.threshold(lv + 1) - Professions.threshold(lv))
		progress.value = 1.0 if lv == Professions.MAX_LEVEL else float(Professions.xp(skill) - Professions.threshold(lv))
		progress.tooltip_text = tr(Data.TEXT["master"]) if lv == Professions.MAX_LEVEL else tr(Data.TEXT["xp"]) % [int(progress.value), int(progress.max_value)]
		skill_list.add_child(progress)
	filter.visible = not supplies
	recipes_button.modulate = Color.WHITE if not supplies else Color(0.65, 0.65, 0.65)
	supplies_button.modulate = Color.WHITE if supplies else Color(0.65, 0.65, 0.65)
	var focus: Button = null
	if supplies:
		for item: String in Professions.CONSUMABLES:
			if GameState.count(item) <= 0:
				continue
			var button := _button(tr(Data.TEXT["use"]) % [Professions.item_name(item), GameState.count(item)])
			button.icon = Items.icon_tex(item)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_use.bind(item))
			button.focus_entered.connect(func() -> void:
				selected_entry = item
				detail.text = tr(Items.info(item)["desc"]) + "\n" + Professions.use_reason(item))
			button.focus_entered.connect(_scroll_to_entry.bind(button))
			rows.add_child(button)
			if focus == null or selected_entry == item:
				focus = button
		if focus == null:
			rows.add_child(_wrapped(tr(Data.TEXT["none"]), 20))
	else:
		if selected_skill != "":
			rows.add_child(_wrapped(tr(Data.SKILLS[selected_skill]["desc"]), 18))
			var lv := Professions.level(selected_skill)
			rows.add_child(_wrapped(tr(Data.TEXT["master"]) if lv == Professions.MAX_LEVEL else tr(Data.TEXT["xp"]) % [Professions.xp(selected_skill) - Professions.threshold(lv), Professions.threshold(lv + 1) - Professions.threshold(lv)], 17))
		for recipe_id: String in Data.RECIPES:
			var recipe: Dictionary = Data.RECIPES[recipe_id]
			if selected_skill != "" and recipe["skill"] != selected_skill:
				continue
			var button := _recipe_button(recipe_id)
			rows.add_child(button)
			if focus == null or selected_entry == recipe_id:
				focus = button
	_link_focus()
	_refresh_goal_button()
	if focus:
		_focus_after_layout.call_deferred(focus, _population_version)
	else:
		UiStyle.focus_if_visible.call_deferred(recipes_button)


func _focus_after_layout(button: Button, version: int) -> void:
	# Containers need to lay out replacement rows before follow_focus can find
	# their real bounds. A generation guard ignores an older filter/craft refresh.
	await get_tree().process_frame
	await get_tree().process_frame
	if not active or version != _population_version or not is_instance_valid(button) or not button.is_inside_tree() or not button.is_visible_in_tree():
		return
	button.grab_focus()
	await get_tree().process_frame
	if not is_instance_valid(button) or version != _population_version: return
	_scroll_to_entry(button)

func _scroll_to_entry(button: Control) -> void:
	if not is_instance_valid(button) or button.get_parent() != rows: return
	var top := button.position.y
	var bottom := top + button.size.y
	if top < scroll.scroll_vertical: scroll.scroll_vertical = floori(top)
	elif bottom > scroll.scroll_vertical+scroll.size.y: scroll.scroll_vertical = ceili(bottom-scroll.size.y)+1


func _recipe_button(recipe_id: String) -> Button:
	var recipe: Dictionary = Data.RECIPES[recipe_id]
	var ingredients: Array[String] = []
	for item: String in recipe["inputs"]:
		ingredients.append("%s %d/%d" % [Professions.item_name(item), GameState.count(item), int(recipe["inputs"][item])])
	var reason := Professions.craft_reason(recipe_id)
	var title: String = tr(Data.TEXT["recipe_line"]) % [Professions.item_name(recipe["output"]), int(recipe.get("amount", 1)), tr(Data.SKILLS[recipe["skill"]]["name"]), recipe["level"]]
	var ready := 0
	for item: String in recipe.inputs:
		if GameState.count(item) >= int(recipe.inputs[item]): ready += 1
	var button := _button(title + "\n" + tr("Materialen compleet: %d/%d") % [ready,recipe.inputs.size()] + "\n" + (tr(Data.TEXT["ready"]) if reason == "" else reason))
	button.custom_minimum_size.y = 90
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.icon = Items.icon_tex(recipe["output"])
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.modulate = Color.WHITE if reason == "" else Color(0.7, 0.75, 0.82)
	button.pressed.connect(_craft.bind(recipe_id))
	button.focus_entered.connect(func() -> void:
		selected_entry = recipe_id
		detail.text = Journal.recipe_text(recipe_id)
		detail.get_v_scroll_bar().value = 0
		_refresh_goal_button())
	button.focus_entered.connect(_scroll_to_entry.bind(button))
	return button


func _craft(recipe_id: String) -> void:
	if not active:
		return
	selected_entry = recipe_id
	var made := Professions.craft(recipe_id)
	Sound.play(("pg_forge" if Data.RECIPES[recipe_id].skill == "smithing" else "buy") if made else "error", -5.0)
	_populate()


func _use(item_id: String) -> void:
	if not active:
		return
	selected_entry = item_id
	Sound.play("drink" if Professions.use_item(item_id) else "error", -5.0)
	_populate()


func _unhandled_input(event: InputEvent) -> void:
	if not Controls.allows_event(event):
		return
	if not active or Engine.get_process_frames() == opened_frame or event.is_echo():
		return
	if UiStyle.shortcut(event, "pause") or event.is_action_pressed("ui_cancel") or UiStyle.shortcut(event, "crafting"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_prev_tab") or event.is_action_pressed("ui_next_tab"):
		get_viewport().set_input_as_handled()
		supplies = not supplies
		selected_entry = ""
		_populate()
	elif UiStyle.activate_focused(root, event):
		get_viewport().set_input_as_handled()


func _link_focus() -> void:
	var skills: Array[Control] = []
	var entries: Array[Control] = []
	for child: Node in skill_list.get_children():
		if child is Button:
			skills.append(child)
	for child: Node in rows.get_children():
		if child is Button:
			entries.append(child)
	UiStyle.link_vertical(skills, false)
	UiStyle.link_vertical(entries, false)
	var header: Array[Control] = [recipes_button, supplies_button]
	if filter.visible:
		header.append(filter)
	header.append(close_button)
	var entry: Control = entries[0] if not entries.is_empty() else recipes_button
	for i in header.size():
		var button := header[i]
		button.focus_neighbor_left = button.get_path_to(header[posmod(i - 1, header.size())])
		button.focus_neighbor_right = button.get_path_to(header[(i + 1) % header.size()])
		button.focus_neighbor_bottom = button.get_path_to(entry)
		button.focus_neighbor_top = button.get_path_to(entry)
	for button: Control in skills:
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(entry)
	for button: Control in entries:
		var skill_index := maxi(Data.SKILLS.keys().find(selected_skill), 0)
		button.focus_neighbor_left = button.get_path_to(skills[skill_index])
		button.focus_neighbor_right = button.get_path_to(detail)
	if not entries.is_empty():
		entries[0].focus_neighbor_top = entries[0].get_path_to(recipes_button)
		entries[-1].focus_neighbor_bottom = entries[-1].get_path_to(detail)
	if not skills.is_empty():
		skills[0].focus_neighbor_top = skills[0].get_path_to(recipes_button)
		skills[-1].focus_neighbor_bottom = skills[-1].get_path_to(close_button)
	# Tab/Shift+Tab traverses the complete menu in a predictable order.
	detail.focus_neighbor_bottom = detail.get_path_to(goal_button)
	detail.focus_neighbor_top = detail.get_path_to(entry)
	detail.focus_neighbor_left = detail.get_path_to(entry)
	detail.focus_neighbor_right = detail.get_path_to(goal_button)
	goal_button.focus_neighbor_top = goal_button.get_path_to(detail)
	goal_button.focus_neighbor_bottom = goal_button.get_path_to(close_button)
	var cycle: Array[Control] = header + skills + entries
	cycle.append(detail)
	cycle.append(goal_button)
	for i in cycle.size():
		cycle[i].focus_next = cycle[i].get_path_to(cycle[(i + 1) % cycle.size()])
		cycle[i].focus_previous = cycle[i].get_path_to(cycle[posmod(i - 1, cycle.size())])

func _refresh_goal_button() -> void:
	goal_button.disabled = not Data.RECIPES.has(selected_entry) or supplies
	goal_button.text = tr("Materiaaldoel verwijderen") if Journal.goal() == selected_entry and selected_entry != "" else tr("Dit recept als materiaaldoel volgen")
	goal_button.tooltip_text = tr("Vindplaatsen staan in de uitleg. Rechts gaat naar de uitleg; omhoog/omlaag scrolt, rechts gaat naar Materiaaldoel.")

func _detail_input(event: InputEvent) -> void:
	if not Controls.allows_event(event) or event.is_echo(): return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		detail.get_v_scroll_bar().value += -48 if event.is_action_pressed("ui_up") else 48
		detail.accept_event()

func _exit_tree() -> void:
	if active:
		GameState.set_ui("crafting", false)


func _refresh_language(_locale: String) -> void:
	title_label.text = tr(Data.TEXT["title"])
	recipes_button.text = tr(Data.TEXT["recipes"])
	supplies_button.text = tr(Data.TEXT["supplies"])
	close_button.text = tr("Sluiten")
	filter.clear()
	filter.add_item(tr(Data.TEXT["skills"]))
	for skill: String in Data.SKILLS:
		filter.add_item(tr(Data.SKILLS[skill]["name"]))
	filter.select(Data.SKILLS.keys().find(selected_skill) + 1)
	if active:
		_populate()
