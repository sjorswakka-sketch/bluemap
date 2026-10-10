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
	button.add_theme_stylebox_override("normal", _box(Color(0.10, 0.17, 0.34), Color(0.35, 0.55, 0.9)))
	button.add_theme_stylebox_override("hover", _box(Color(0.16, 0.27, 0.52), Color(0.6, 0.85, 1.0)))
	button.add_theme_stylebox_override("pressed", _box(Color(0.22, 0.36, 0.66), Color(0.8, 0.95, 1.0)))
	# De rand om de knop die met het toetsenbord is geselecteerd.
	button.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color(1.0, 0.88, 0.35), 4, false))
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size = Vector2(340, 56)
	button.focus_mode = Control.FOCUS_ALL


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
