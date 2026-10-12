extends RefCounted
## Gedeelde opmaak voor knoppen en vensters (titelscherm en pauzemenu).


static func _box(bg: Color, border: Color, width := 3, filled := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.draw_center = filled
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(10)
	return box


static func style_button(button: Button, font_size := 28) -> void:
	button.add_theme_stylebox_override("disabled", _box(Color(0.07, 0.11, 0.22), Color(0.22, 0.3, 0.45)))
	button.add_theme_stylebox_override("normal", _box(Color(0.10, 0.17, 0.34), Color(0.35, 0.55, 0.9)))
	button.add_theme_stylebox_override("hover", _box(Color(0.16, 0.27, 0.52), Color(0.6, 0.85, 1.0)))
	button.add_theme_stylebox_override("pressed", _box(Color(0.22, 0.36, 0.66), Color(0.8, 0.95, 1.0)))
	# De rand om de knop die met het toetsenbord is geselecteerd.
	button.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color(1.0, 0.88, 0.35), 4, false))
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size = Vector2(340, 56)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_entered.connect(func() -> void:
		if not Controls.controller_active and not button.disabled and button.is_visible_in_tree():
			button.grab_focus())


static func style_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _box(Color(0.06, 0.1, 0.22, 0.96), Color(0.45, 0.75, 1.0)))


static func make_label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.15, 0.95))
	label.add_theme_constant_override("outline_size", maxi(4, font_size / 8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Een effen vlak met rand, voor panelen.
static func flat(bg: Color, border: Color, width := 3) -> StyleBoxFlat:
	return _box(bg, border, width)


## Een ster met vijf punten (gebruikt voor Nieuw spel+).
static func draw_star(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + TAU * float(i) / 10.0
		points.append(center + Vector2.from_angle(angle) * (radius if i % 2 == 0 else radius * 0.45))
	canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	canvas.draw_polyline(points, color.darkened(0.5), 1.5)


## Explicit vertical focus links prevent the engine jumping across panels or disabled rows.
static func link_vertical(controls: Array[Control], wrap := true) -> void:
	for i in controls.size():
		var item := controls[i]
		var before := controls[posmod(i - 1, controls.size()) if wrap else maxi(i - 1, 0)]
		var after := controls[(i + 1) % controls.size() if wrap else mini(i + 1, controls.size() - 1)]
		item.focus_neighbor_top = item.get_path_to(before)
		item.focus_neighbor_bottom = item.get_path_to(after)
		item.focus_previous = item.get_path_to(before)
		item.focus_next = item.get_path_to(after)


## E may supplement the built-in A/Enter activation, but never bypass a disabled button.
static func activate_focused(owner: Control, event: InputEvent) -> bool:
	if event.is_echo() or not event.is_action_pressed("interact") or Controls.is_ui_navigation_event(event):
		return false
	var focused := owner.get_viewport().gui_get_focus_owner()
	if focused is Button and owner.is_ancestor_of(focused) and focused.is_visible_in_tree() and not focused.disabled:
		if focused is OptionButton:
			(focused as OptionButton).show_popup()
		else:
			(focused as Button).pressed.emit()
		return true
	return false


static func shortcut(event: InputEvent, action: String) -> bool:
	return event.is_action_pressed(action) and not Controls.is_ui_navigation_event(event)


static func confirm(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or shortcut(event, "interact")


static func focus_if_visible(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and not control.is_queued_for_deletion():
		control.grab_focus()
