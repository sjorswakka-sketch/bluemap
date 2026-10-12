extends CanvasLayer
## C opens a keyboard/controller-accessible profession journal and crafting menu.

const Data := preload("res://scripts/data/ext/beroepen.gd")
const Professions := preload("res://scripts/core/professions.gd")
const Items := preload("res://scripts/data/items.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")

var root: Control
var panel: PanelContainer
var scroll: ScrollContainer
var skill_list: VBoxContainer
var rows: VBoxContainer
var detail: Label
var filter: OptionButton
var recipes_button: Button
var supplies_button: Button
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
	box.add_child(UiStyle.make_label(Data.TEXT["title"], 30, Color(0.73, 0.91, 0.67)))
	var intro := _wrapped(Data.TEXT["intro"], 17)
	box.add_child(intro)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	box.add_child(content)
	skill_list = VBoxContainer.new()
	skill_list.custom_minimum_size = Vector2(245, 0)
	skill_list.add_theme_constant_override("separation", 5)
	content.add_child(skill_list)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(740, 0)
	content.add_child(right)
	var nav := HBoxContainer.new()
	right.add_child(nav)
	recipes_button = _button(Data.TEXT["recipes"])
	recipes_button.pressed.connect(func() -> void: supplies = false; _populate())
	nav.add_child(recipes_button)
	supplies_button = _button(Data.TEXT["supplies"])
	supplies_button.pressed.connect(func() -> void: supplies = true; _populate())
	nav.add_child(supplies_button)
	filter = OptionButton.new()
	filter.add_theme_font_size_override("font_size", 18)
	filter.add_item(Data.TEXT["skills"])
	for skill: String in Data.SKILLS:
		filter.add_item(Data.SKILLS[skill]["name"])
	filter.item_selected.connect(func(index: int) -> void:
		selected_skill = "" if index == 0 else str(Data.SKILLS.keys()[index - 1])
		_populate())
	nav.add_child(filter)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	right.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	detail = _wrapped("", 17)
	detail.custom_minimum_size = Vector2(0, 48)
	box.add_child(detail)
	box.add_child(UiStyle.make_label(Data.TEXT["hint"], 16, Color(0.72, 0.77, 0.85)))


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


func _process(_delta: float) -> void:
	if not active:
		return
	# Font metrics, translations and window sizes can differ. Fit the complete
	# panel before centering so the footer and every control stay on-screen.
	panel.size = panel.get_combined_minimum_size()
	var view: Vector2 = root.size
	var factor := minf(1.0, minf((view.x - 24.0) / panel.size.x, (view.y - 24.0) / panel.size.y))
	panel.scale = Vector2.ONE * maxf(factor, 0.1)
	panel.position = (view - panel.size * panel.scale) * 0.5


func open() -> void:
	if active or GameState.input_locked():
		return
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
		var button := _button(Data.TEXT["skill_line"] % [Data.SKILLS[skill]["name"], lv])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void:
			supplies = false
			selected_skill = skill
			filter.select(Data.SKILLS.keys().find(skill) + 1)
			_populate())
		var xp_text: String = Data.TEXT["master"] if lv == Professions.MAX_LEVEL else Data.TEXT["xp"] % [Professions.xp(skill) - Professions.threshold(lv), Professions.threshold(lv + 1) - Professions.threshold(lv)]
		button.focus_entered.connect(func() -> void: detail.text = Data.SKILLS[skill]["desc"] + "\n" + xp_text)
		skill_list.add_child(button)
		var progress := ProgressBar.new()
		progress.custom_minimum_size = Vector2(0, 7)
		progress.show_percentage = false
		progress.max_value = 1.0 if lv == Professions.MAX_LEVEL else float(Professions.threshold(lv + 1) - Professions.threshold(lv))
		progress.value = 1.0 if lv == Professions.MAX_LEVEL else float(Professions.xp(skill) - Professions.threshold(lv))
		progress.tooltip_text = Data.TEXT["master"] if lv == Professions.MAX_LEVEL else Data.TEXT["xp"] % [int(progress.value), int(progress.max_value)]
		skill_list.add_child(progress)
	filter.visible = not supplies
	recipes_button.modulate = Color.WHITE if not supplies else Color(0.65, 0.65, 0.65)
	supplies_button.modulate = Color.WHITE if supplies else Color(0.65, 0.65, 0.65)
	var focus: Button = null
	if supplies:
		for item: String in Professions.CONSUMABLES:
			if GameState.count(item) <= 0:
				continue
			var button := _button(Data.TEXT["use"] % [Professions.item_name(item), GameState.count(item)])
			button.icon = Items.icon_tex(item)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_use.bind(item))
			button.focus_entered.connect(func() -> void: detail.text = Items.info(item)["desc"] + "\n" + Professions.use_reason(item))
			rows.add_child(button)
			if focus == null or selected_entry == item:
				focus = button
		if focus == null:
			rows.add_child(_wrapped(Data.TEXT["none"], 20))
	else:
		if selected_skill != "":
			rows.add_child(_wrapped(Data.SKILLS[selected_skill]["desc"], 18))
			var lv := Professions.level(selected_skill)
			rows.add_child(_wrapped(Data.TEXT["master"] if lv == Professions.MAX_LEVEL else Data.TEXT["xp"] % [Professions.xp(selected_skill) - Professions.threshold(lv), Professions.threshold(lv + 1) - Professions.threshold(lv)], 17))
		for recipe_id: String in Data.RECIPES:
			var recipe: Dictionary = Data.RECIPES[recipe_id]
			if selected_skill != "" and recipe["skill"] != selected_skill:
				continue
			var button := _recipe_button(recipe_id)
			rows.add_child(button)
			if focus == null or selected_entry == recipe_id:
				focus = button
	if focus:
		_focus_after_layout.call_deferred(focus, _population_version)
	else:
		recipes_button.grab_focus.call_deferred()


func _focus_after_layout(button: Button, version: int) -> void:
	# Containers need to lay out replacement rows before follow_focus can find
	# their real bounds. A generation guard ignores an older filter/craft refresh.
	await get_tree().process_frame
	await get_tree().process_frame
	if not active or version != _population_version or not is_instance_valid(button):
		return
	button.grab_focus()
	scroll.ensure_control_visible(button)


func _recipe_button(recipe_id: String) -> Button:
	var recipe: Dictionary = Data.RECIPES[recipe_id]
	var ingredients: Array[String] = []
	for item: String in recipe["inputs"]:
		ingredients.append("%s %d/%d" % [Professions.item_name(item), GameState.count(item), int(recipe["inputs"][item])])
	var reason := Professions.craft_reason(recipe_id)
	var title: String = Data.TEXT["recipe_line"] % [Professions.item_name(recipe["output"]), int(recipe.get("amount", 1)), Data.SKILLS[recipe["skill"]]["name"], recipe["level"]]
	var button := _button(title + "\n" + "  ·  ".join(ingredients) + "\n" + (Data.TEXT["ready"] if reason == "" else reason))
	button.custom_minimum_size.y = 90
	button.icon = Items.icon_tex(recipe["output"])
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.modulate = Color.WHITE if reason == "" else Color(0.7, 0.75, 0.82)
	button.pressed.connect(_craft.bind(recipe_id))
	button.focus_entered.connect(func() -> void:
		detail.text = Items.info(recipe["output"])["desc"] + "\n" + Data.TEXT["station"] % Data.TEXT.get(recipe.get("station", "anywhere"), Data.TEXT["anywhere"]))
	return button


func _craft(recipe_id: String) -> void:
	selected_entry = recipe_id
	Sound.play("buy" if Professions.craft(recipe_id) else "error", -5.0)
	_populate()


func _use(item_id: String) -> void:
	selected_entry = item_id
	Sound.play("drink" if Professions.use_item(item_id) else "error", -5.0)
	_populate()


func _unhandled_input(event: InputEvent) -> void:
	if not active or Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("crafting"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and not focused is OptionButton:
			(focused as Button).pressed.emit()


func _exit_tree() -> void:
	if active:
		GameState.set_ui("crafting", false)
