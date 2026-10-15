extends Control
## De introductie bij een nieuw spel: een paar zinnen over Azura en de Blauwe Kaart.

const Art := preload("res://scripts/core/art.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")

const W := 1152.0
const H := 648.0
const GAME_SCENE := "res://scenes/main.tscn"

var pages: Array[String] = [] # in de taal van de speler; bij Nieuw spel+ heeft de laatste pagina een zin meer
var page := 0
var t := 0.0
var typed := 0.0
var done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.in_game = false
	get_tree().paused = false
	Sound.play_music("temple")
	pages = build_pages(GameState.ng_plus)


## De pagina's van de intro (vertaald). In Nieuw spel+ (ng_plus > 0) is de laatste pagina langer.
func build_pages(ng_plus: int) -> Array[String]:
	if ng_plus == 0:
		return [tr("Je komt aan in Dageraadsdorp. Brood wordt bezorgd, de smid is aan het werk… maar op het plein sputtert de fontein. Een hovenier kan je hulp gebruiken.")]
	var result: Array[String] = [
		tr("Azura is een land vol bossen, ruïnes en grotten. Eeuwenlang werd het beschermd door de Blauwe Kaart."),
		tr("De kaart is gemaakt van gloeiend kristal. Hij houdt de slijmen rustig en laat zien waar het land veilig is."),
		tr("Maar op een nacht barstte de kaart. De drie grote kristallen vlogen het land in, en overal werden de slijmen wild."),
	]
	if ng_plus > 0:
		result.append(tr("Jij komt aan in Dageraadsdorp, het dorpje onder de tempel waar de kaart hangt. Daar begint je avontuur... Maar let op: dit is Nieuw spel+. De slijmen zijn sterker geworden, en jij hebt je beste spullen mee!"))
	else:
		result.append(tr("Jij komt aan in Dageraadsdorp, het dorpje onder de tempel waar de kaart hangt. Daar begint je avontuur..."))
	return result


func _unhandled_input(event: InputEvent) -> void:
	if not Controls.allows_event(event):
		return
	if event.is_echo():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()
		return
	if not (event.is_action_pressed("interact") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept")):
		return
	get_viewport().set_input_as_handled()
	if typed < pages[page].length():
		typed = pages[page].length()
		return
	Sound.play("select", -8.0)
	if page < pages.size() - 1:
		page += 1
		typed = 0.0
		t = 0.0
	else:
		finish()


func finish() -> void:
	if done:
		return
	done = true
	GameState.in_game = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _process(delta: float) -> void:
	t += delta
	typed += delta * 38.0
	queue_redraw()


func _draw() -> void:
	# Keep the original composition together at small and large window sizes.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.14))
	var factor := minf(size.x / W, size.y / H)
	draw_set_transform((size - Vector2(W, H) * factor) * 0.5, 0.0, Vector2.ONE * factor)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([Color(0.03, 0.05, 0.14), Color(0.03, 0.05, 0.14), Color(0.1, 0.18, 0.38), Color(0.1, 0.18, 0.38)]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 70:
		var p := Vector2(rng.randf() * W, rng.randf() * H * 0.75)
		draw_rect(Rect2(p, Vector2(3, 3)), Color(1, 1, 1, 0.3 + 0.7 * absf(sin(t * rng.randf_range(0.8, 2.2) + rng.randf() * TAU))))

	# Plaatje bij het verhaal: de kaartkristallen
	var center := Vector2(W / 2.0, 150.0)
	var items := Art.tex("items")
	match page if GameState.ng_plus>0 else 3:
		0, 1:
			draw_circle(center, 80.0 + sin(t * 2.0) * 6.0, Color(0.4, 0.8, 1.0, 0.14))
			DrawUtil.sprite(self, Art.tex("crystal"), int(t * 1.4) % 2, 0, center, Vector2i(16, 16), 8.0)
		2:
			# De kristallen vliegen alle kanten op
			var spread := minf(t * 0.5, 1.0)
			for i in 3:
				var dir := Vector2.from_angle(-PI / 2.0 + (float(i) - 1.0) * 0.9)
				var pos := center + dir * (spread * 120.0) + Vector2(0, spread * 40.0)
				draw_circle(pos, 36.0, Color(0.4, 0.8, 1.0, 0.14))
				draw_texture_rect_region(items, Rect2(pos - Vector2(32, 32), Vector2(64, 64)), Rect2(Vector2((8 + i) * 16, 0), Vector2(16, 16)))
		3:
			DrawUtil.sprite(self, Art.tex("npc_bram" if GameState.ng_plus>0 else "op_gardener"), int(t * 1.6) % 2, 0, center + Vector2(-80, 20), Vector2i(16, 16), 6.0)
			DrawUtil.sprite(self, Art.tex("player"), 1 + int(t * 4.0) % 2, 2, center + Vector2(80, 20), Vector2i(16, 16), 6.0)

	var box := Rect2(120, 300, W - 240, 220)
	draw_style_box(UiStyle.flat(Color(0.05, 0.08, 0.2, 0.9), Color(0.45, 0.75, 1.0), 3), box)
	var font := ThemeDB.fallback_font
	var line: String = pages[page]
	draw_multiline_string(font, box.position + Vector2(30, 60), line.substr(0, int(typed)), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 60.0, 30, -1, Color.WHITE)
	var hint := Controls.action_label("ui_accept") + "  ▼" if typed >= line.length() else ""
	draw_string(font, box.position + Vector2(box.size.x - 80, box.size.y - 18), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(0, H - 24), tr("%s = overslaan") % Controls.action_label("ui_cancel"), HORIZONTAL_ALIGNMENT_CENTER, W, 18, Color(1, 1, 1, 0.4))
