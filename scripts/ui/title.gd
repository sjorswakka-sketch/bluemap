extends Control
## Titelscherm: een nachtelijke lucht, de personages uit het spel en het hoofdmenu.

const Art := preload("res://scripts/core/art.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")

const GAME_SCENE := "res://scenes/main.tscn"
const INTRO_SCENE := "res://scenes/intro.tscn"
const SKY_TOP := Color(0.05, 0.07, 0.2)
const SKY_BOTTOM := Color(0.2, 0.32, 0.6)
const GROUND_SCALE := 4.0 # 16 pixels per tegel -> 64 op het scherm
const SPRITE_SCALE := 6.0

var t := 0.0
var stars: Array[Dictionary] = []
var start_button: Button
var continue_button: Button
var sound_button: Button
var quit_button: Button


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
	_build_ui()
	GameState.in_game = false
	Sound.play_music("village")
	Sound.mute_changed.connect(func(_muted: bool) -> void: _refresh_sound_label())


func _build_ui() -> void:
	var title := UiStyle.make_label("Bluemap Quest", 84, Color(0.7, 0.92, 1.0))
	title.position = Vector2(0, 22)
	title.size = Vector2(1152, 110)
	add_child(title)

	var subtitle := UiStyle.make_label("Een kleine fantasy-quest", 28, Color(0.85, 0.9, 1.0))
	subtitle.position = Vector2(0, 124)
	subtitle.size = Vector2(1152, 40)
	add_child(subtitle)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	menu.position = Vector2(576 - 170, 310)
	add_child(menu)
	continue_button = _button(menu, "Doorgaan", continue_game)
	start_button = _button(menu, "Nieuw spel", start_game)
	sound_button = _button(menu, "", Sound.toggle_mute)
	quit_button = _button(menu, "Afsluiten", quit_game)
	continue_button.disabled = not GameState.has_save()
	_refresh_sound_label()
	(start_button if continue_button.disabled else continue_button).grab_focus()

	var hint := UiStyle.make_label(
		"WASD lopen  ·  SPATIE zwaard  ·  SHIFT rollen  ·  E praten  ·  I menu  ·  ESC pauze  ·  M geluid", 20)
	hint.position = Vector2(0, 596)
	hint.size = Vector2(1152, 30)
	add_child(hint)

	var version := UiStyle.make_label("v" + str(ProjectSettings.get_setting("application/config/version", "")), 16)
	version.position = Vector2(1152 - 120, 620)
	version.size = Vector2(110, 22)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	UiStyle.style_button(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _refresh_sound_label() -> void:
	sound_button.text = "Geluid: uit  (M)" if Sound.muted else "Geluid: aan  (M)"


func start_game() -> void:
	Sound.play("select")
	GameState.new_game()
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
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	for star in stars:
		var twinkle := 0.35 + 0.65 * absf(sin(t * star["speed"] + star["phase"]))
		draw_rect(Rect2(star["pos"], Vector2(3, 3)), Color(1, 1, 1, twinkle))

	# Grond: twee rijen gras met wat afwisseling.
	var tiles := Art.tex("tiles")
	var tile := 16.0 * GROUND_SCALE
	var ground_y := h - tile * 2.0
	for row in 2:
		for col in int(ceil(w / tile)):
			var variant := 5 if (col * 3 + row * 5) % 7 == 0 else 6 if (col * 2 + row) % 5 == 0 else 0
			draw_texture_rect_region(tiles, Rect2(col * tile, ground_y + row * tile, tile, tile),
				Rect2(variant * 16.0, 0, 16, 16))

	# De personages, op de grond.
	var feet_y := ground_y + 30.0
	var size_px := 16.0 * SPRITE_SCALE
	var center_y := feet_y - size_px * (14.5 / 16.0 - 0.5)
	var step := 1 + int(t * 4.0) % 2
	DrawUtil.sprite(self, Art.tex("npc_bram"), int(t * 1.6) % 2, 0, Vector2(190, center_y), Vector2i(16, 16), SPRITE_SCALE)
	DrawUtil.sprite(self, Art.tex("player"), step, 2, Vector2(330, center_y), Vector2i(16, 16), SPRITE_SCALE)
	DrawUtil.sprite(self, Art.tex("slime"), int(t * 1.6) % 2, 0, Vector2(900, center_y), Vector2i(16, 16), SPRITE_SCALE)

	# De zwevende kristal.
	var crystal := Vector2(w / 2.0, 238.0 + sin(t * 2.0) * 8.0)
	draw_circle(crystal, 100.0 + sin(t * 3.0) * 5.0, Color(0.3, 0.7, 1.0, 0.10))
	draw_circle(crystal, 66.0 + sin(t * 3.0) * 3.0, Color(0.4, 0.8, 1.0, 0.16))
	DrawUtil.sprite(self, Art.tex("crystal"), int(t * 1.4) % 2, 0, crystal, Vector2i(16, 16), 8.0)
