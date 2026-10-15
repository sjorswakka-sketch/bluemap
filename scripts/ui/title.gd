extends Control
## Titelscherm: een nachtelijke lucht, de personages uit het spel en het hoofdmenu. Rechtsboven staat de taalknop
## ("Taal: Nederlands" / "Language: English"): één druk wisselt de taal, en alle tekst verandert meteen mee.

const Art := preload("res://scripts/core/art.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")

const GAME_SCENE := "res://scenes/main.tscn"
const INTRO_SCENE := "res://scenes/intro.tscn"
const SKY_TOP := Color(0.05, 0.07, 0.2)
const SKY_BOTTOM := Color(0.2, 0.32, 0.6)
const GROUND_SCALE := 4.0 # 16 pixels per tegel -> 64 op het scherm
const SPRITE_SCALE := 6.0

var content: Control
var t := 0.0
var stars: Array[Dictionary] = []
var title_label: Label
var subtitle_label: Label
var hint_label: Label
var language_button: Button
var start_button: Button
var ng_button: Button # Nieuw spel+: alleen als je het spel al hebt uitgespeeld
var continue_button: Button
var sound_button: Button
var quit_button: Button
var controls_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 70:
		stars.append({
			"pos": Vector2(rng.randf() * 1152.0, rng.randf() * 380.0),
			"speed": rng.randf_range(0.8, 2.5),
			"phase": rng.randf() * TAU,
		})
	content = Control.new()
	content.size = Vector2(1152, 648)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	content.draw.connect(_draw_scene)
	resized.connect(queue_redraw)
	_build_ui()
	_layout()
	GameState.in_game = false
	Sound.play_music("village")
	Sound.mute_changed.connect(func(_muted: bool) -> void: _refresh_sound_label())
	Controls.device_changed.connect(func(_controller: bool) -> void: _refresh_controls_hint())
	Controls.bindings_changed.connect(_refresh_controls_hint)
	Lang.changed.connect(_on_language_changed)


func _build_ui() -> void:
	title_label = UiStyle.make_label("", 84, Color(0.7, 0.92, 1.0))
	title_label.position = Vector2(0, 36)
	title_label.size = Vector2(1152, 110)
	content.add_child(title_label)

	subtitle_label = UiStyle.make_label("", 28, Color(0.85, 0.9, 1.0))
	subtitle_label.position = Vector2(0, 124)
	subtitle_label.size = Vector2(1152, 40)
	content.add_child(subtitle_label)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	menu.position = Vector2(576 - 170, 290)
	content.add_child(menu)
	continue_button = _button(menu, "", continue_game)
	# "Nieuw spel" en "Nieuw spel+" staan naast elkaar, zodat het menu niet hoger wordt (het kristal blijft vrij).
	var new_row := HBoxContainer.new()
	new_row.add_theme_constant_override("separation", 8)
	menu.add_child(new_row)
	start_button = _button(new_row, "", start_game)
	ng_button = _button(new_row, "", start_game_plus)
	ng_button.visible = GameState.ng_plus_available()
	if ng_button.visible:
		for button: Button in [start_button, ng_button]:
			button.custom_minimum_size.x = 166
	sound_button = _button(menu, "", Sound.toggle_mute)
	controls_button = _button(menu, "", _open_controls)
	quit_button = _button(menu, "", quit_game)
	continue_button.disabled = not GameState.has_save()
	(start_button if continue_button.disabled else continue_button).grab_focus()

	# De taalknop rechtsboven, in de taal zelf. Met de pijltjes of de controller kom je er vanuit het menu (omhoog
	# vanaf de bovenste knop, of omlaag vanaf Afsluiten).
	language_button = _button(content, "", _toggle_language)
	language_button.custom_minimum_size = Vector2(250, 44)
	language_button.add_theme_font_size_override("font_size", 20)
	language_button.position = Vector2(1152 - 16 - 250, 16)
	var top_row: Array[Button] = [continue_button]
	if continue_button.disabled:
		top_row = [start_button, ng_button]
	for button in top_row:
		button.focus_neighbor_top = button.get_path_to(language_button)
	quit_button.focus_neighbor_bottom = quit_button.get_path_to(language_button)
	language_button.focus_neighbor_bottom = language_button.get_path_to(top_row[0])
	language_button.focus_neighbor_top = language_button.get_path_to(quit_button)

	hint_label = UiStyle.make_label("", 18)
	hint_label.position = Vector2(0, 596)
	hint_label.size = Vector2(1152, 30)
	content.add_child(hint_label)

	var version := UiStyle.make_label("v" + str(ProjectSettings.get_setting("application/config/version", "")), 16)
	version.position = Vector2(1152 - 250, 620)
	version.size = Vector2(234, 22)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(version)
	_refresh_texts()


## Alle tekst op het scherm in de huidige taal (bij het openen, en opnieuw als je de taal wisselt).
func _refresh_texts() -> void:
	title_label.text = tr("Bluemap Quest")
	subtitle_label.text = tr("Een kleine fantasy-quest")
	continue_button.text = tr("Doorgaan")
	start_button.text = tr("Nieuw spel")
	ng_button.text = tr("Nieuw spel+")
	quit_button.text = tr("Afsluiten")
	controls_button.text = tr("Bediening")
	_refresh_controls_hint()
	language_button.text = Lang.button_text()
	_refresh_sound_label()


func _toggle_language() -> void:
	Sound.play("select")
	Lang.toggle()


## Met een controller (A) of met E druk je de gekozen knop in; Enter en spatie doet Godot zelf al (ui_accept).
func _unhandled_input(event: InputEvent) -> void:
	if Controls.capture_active or not Controls.allows_event(event):
		return
	if UiStyle.activate_focused(self, event):
		get_viewport().set_input_as_handled()


func _on_language_changed(_locale: String) -> void:
	_refresh_texts()


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	# Stel de definitieve maat in vóór de knop in een Container komt. Een later
	# verkleinde knop laat anders tijdelijk een hogere rij bij Nieuw spel+ staan.
	UiStyle.style_button(button, 24)
	button.custom_minimum_size = Vector2(340, 48)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _refresh_sound_label() -> void:
	sound_button.text = tr("Geluid: uit") if Sound.muted else tr("Geluid: aan")


func _refresh_controls_hint() -> void:
	if not is_instance_valid(hint_label):
		return
	hint_label.text = tr("Linkerstick / D-pad kiezen  ·  A bevestigen  ·  Bediening: knoppen aanpassen") if Controls.controller_active else tr("WASD / pijlen kiezen  ·  Enter bevestigen  ·  Bediening: toetsen en muis aanpassen")


func _open_controls() -> void:
	var menu := preload("res://scripts/ui/controls_menu.gd").new()
	menu.closed.connect(func() -> void: controls_button.grab_focus())
	add_child(menu)


func start_game() -> void:
	Sound.play("select")
	GameState.new_game()
	get_tree().change_scene_to_file(INTRO_SCENE)


## Een nieuw verhaal met je beste spullen, tegen sterkere vijanden (zie GameState.new_game_plus).
func start_game_plus() -> void:
	if not GameState.new_game_plus():
		return
	Sound.play("select")
	get_tree().change_scene_to_file(INTRO_SCENE)


func continue_game() -> void:
	if not GameState.load_game():
		return
	Sound.play("select")
	GameState.in_game = true
	get_tree().change_scene_to_file(GAME_SCENE)


func quit_game() -> void:
	get_tree().quit()


func _process(delta: float) -> void:
	t += delta
	_layout()
	content.queue_redraw()


func _layout() -> void:
	var factor := minf(size.x / 1152.0, size.y / 648.0)
	content.scale = Vector2.ONE * factor
	content.position = (size - Vector2(1152, 648) * factor) * 0.5


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))


func _draw_scene() -> void:
	var w := 1152.0
	var h := 648.0
	content.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	for star in stars:
		var twinkle := 0.35 + 0.65 * absf(sin(t * star["speed"] + star["phase"]))
		content.draw_rect(Rect2(star["pos"], Vector2(3, 3)), Color(1, 1, 1, twinkle))

	# Grond: twee rijen gras met wat afwisseling.
	var tiles := Art.tex("tiles")
	var tile := 16.0 * GROUND_SCALE
	var ground_y := h - tile * 2.0
	for row in 2:
		for col in int(ceil(w / tile)):
			var variant := 5 if (col * 3 + row * 5) % 7 == 0 else 6 if (col * 2 + row) % 5 == 0 else 0
			content.draw_texture_rect_region(tiles, Rect2(col * tile, ground_y + row * tile, tile, tile),
				Rect2(variant * 16.0, 0, 16, 16))

	# De personages, op de grond.
	var feet_y := ground_y + 30.0
	var size_px := 16.0 * SPRITE_SCALE
	var center_y := feet_y - size_px * (14.5 / 16.0 - 0.5)
	var step := 1 + int(t * 4.0) % 2
	DrawUtil.sprite(content, Art.tex("npc_bram"), int(t * 1.6) % 2, 0, Vector2(190, center_y), Vector2i(16, 16), SPRITE_SCALE)
	DrawUtil.sprite(content, Art.tex("player"), step, 2, Vector2(330, center_y), Vector2i(16, 16), SPRITE_SCALE)
	DrawUtil.sprite(content, Art.tex("slime"), int(t * 1.6) % 2, 0, Vector2(900, center_y), Vector2i(16, 16), SPRITE_SCALE)

	# De zwevende kristal.
	var crystal := Vector2(w / 2.0, 238.0 + sin(t * 2.0) * 8.0)
	content.draw_circle(crystal, 100.0 + sin(t * 3.0) * 5.0, Color(0.3, 0.7, 1.0, 0.10))
	content.draw_circle(crystal, 66.0 + sin(t * 3.0) * 3.0, Color(0.4, 0.8, 1.0, 0.16))
	DrawUtil.sprite(content, Art.tex("crystal"), int(t * 1.4) % 2, 0, crystal, Vector2i(16, 16), 8.0)
