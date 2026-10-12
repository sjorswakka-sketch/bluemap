extends Control
## Het einde: de baas valt, de Blauwe Kaart wordt hersteld, een epiloog, je statistieken en de aftiteling.

const Art := preload("res://scripts/core/art.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Items := preload("res://scripts/data/items.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Credits := preload("res://scripts/data/credits.gd")
const MenuUi := preload("res://scripts/ui/menu_ui.gd")
const AchievementBanner := preload("res://scripts/ui/achievement_banner.gd")

const W := 1152.0
const H := 648.0
const SCALE := 4 # pixels per tegel op de kaart

# Waar elk gebied op de kaart komt (in pixels, linksboven).
const ISLANDS := {
	"temple": Vector2(150, 110), "village": Vector2(130, 240), "forest": Vector2(350, 200),
	"ruins": Vector2(610, 100), "cave": Vector2(620, 290),
}
const CRYSTAL_SPOTS := [Vector2(440, 120), Vector2(790, 70), Vector2(790, 250)]

var pages: Array[Dictionary] = []
var page := -1
var t := 0.0
var typed := 0.0
var map_color_tex: Texture2D
var map_gray_tex: Texture2D
var map_origin := Vector2(60, 40)
var credits_scroll := 0.0
var lit := [false, false, false]
var finished := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.in_game = false
	GameState.ui_owners = {}
	get_tree().paused = false
	_build_map_textures()
	add_child(AchievementBanner.new()) # prestaties van het einde (de Slijmkoning, uitgespeeld...) zie je hier
	# De epiloog, meteen vertaald (de taal kan op dit scherm niet meer veranderen).
	pages = [
		{"type": "text", "speaker": "", "lines": [
			tr("Met een enorme plof zakt de Slijmkoning in elkaar."),
			tr("Het groene gel trekt weg uit de tempel, sijpelt als een rivier door het land... en verdwijnt."),
			tr("Het wordt heel stil in de Kristaltempel."),
		]},
		{"type": "map"},
		{"type": "text", "speaker": tr("Oudste Bram"), "lines": [tr("Dankzij jou is Azura weer veilig. De Blauwe Kaart laat weer zien waar het land rustig is.")]},
		{"type": "text", "speaker": tr("Greta"), "lines": [tr("Ik smeed vanaf nu zwaarden voor op het feest. Nou ja, voor het snijden van de taart.")]},
		{"type": "text", "speaker": tr("Tobias"), "lines": [tr("Mijn winkel draait beter dan ooit! De eerste helddrank van de week is voor jou. Gratis. Ehm... bijna gratis.")]},
		{"type": "text", "speaker": tr("Mila"), "lines": [tr("De herberg zit vol. Iedereen wil de held van Dageraadsdorp zien.")]},
		{"type": "text", "speaker": tr("Pim"), "lines": [tr("Muis en ik gaan ook slijmen verslaan. Als ze groter worden dan Muis, rennen we weg.")]},
		{"type": "stats"},
		{"type": "credits"},
		{"type": "end"},
	]
	Sound.play_music("ending")
	_next_page()


func _build_map_textures() -> void:
	var size := Vector2i(int(W - 120.0), int(H - 100.0))
	var color_img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var gray_img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for map_id: String in ISLANDS:
		var rows: Array = Maps.get_map(map_id)["rows"]
		var origin: Vector2 = ISLANDS[map_id]
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				var color := Tiles.map_color(Tiles.name_for(row[x], x, y))
				var rect := Rect2i(int(origin.x) + x * SCALE, int(origin.y) + y * SCALE, SCALE, SCALE)
				color_img.fill_rect(rect, color)
				var gray := color.get_luminance() * 0.55
				gray_img.fill_rect(rect, Color(gray, gray, gray * 1.1))
	map_color_tex = ImageTexture.create_from_image(color_img)
	map_gray_tex = ImageTexture.create_from_image(gray_img)


func _next_page() -> void:
	page += 1
	t = 0.0
	typed = 0.0
	if pages[page]["type"] == "text":
		pages[page]["line"] = 0
	if pages[page]["type"] == "credits":
		credits_scroll = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not Controls.allows_event(event):
		return
	if event.is_echo():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_to_title()
		return
	if not (event.is_action_pressed("interact") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept")):
		return
	get_viewport().set_input_as_handled()
	var current := pages[page]
	match current["type"]:
		"text":
			var line: String = current["lines"][current["line"]]
			if typed < line.length():
				typed = line.length()
			elif current["line"] < current["lines"].size() - 1:
				current["line"] += 1
				typed = 0.0
				Sound.play("select", -8.0)
			else:
				_next_page()
		"map":
			if t > 9.0:
				_next_page()
			else:
				t = maxf(t, 9.0)
		"stats":
			if t > 1.0:
				_next_page()
		"credits":
			credits_scroll += 400.0
		"end":
			_to_title()


func _to_title() -> void:
	if finished:
		return
	finished = true
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _process(delta: float) -> void:
	t += delta
	var current := pages[page]
	match current["type"]:
		"text":
			typed += delta * 40.0
		"map":
			var times := [0.8, 2.6, 4.4]
			for i in 3:
				if not lit[i] and t > times[i]:
					lit[i] = true
					Sound.play("crystal", -2.0)
			if t > 6.2 and t - delta <= 6.2:
				Sound.play("upgrade", -2.0)
		"credits":
			credits_scroll += delta * 55.0
			if credits_scroll > Credits.LINES.size() * 40.0 + H:
				_next_page()
	queue_redraw()


# --- Tekenen ------------------------------------------------------------------------------------

func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([Color(0.03, 0.05, 0.14), Color(0.03, 0.05, 0.14), Color(0.1, 0.18, 0.38), Color(0.1, 0.18, 0.38)]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 60:
		var p := Vector2(rng.randf() * W, rng.randf() * H * 0.8)
		var twinkle := 0.3 + 0.7 * absf(sin(t * rng.randf_range(0.8, 2.2) + rng.randf() * TAU))
		draw_rect(Rect2(p, Vector2(3, 3)), Color(1, 1, 1, twinkle))
	var current := pages[page]
	match current["type"]:
		"text":
			_draw_text_page(current)
		"map":
			_draw_map_page()
		"stats":
			_draw_stats()
		"credits":
			_draw_credits()
		"end":
			_draw_end()


func _draw_box(rect: Rect2) -> void:
	draw_style_box(UiStyle.flat(Color(0.05, 0.08, 0.2, 0.9), Color(0.45, 0.75, 1.0), 3), rect)


func _text_centered(text: String, y: float, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, W, size, 6, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, W, size, color)


func _draw_text_page(current: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var line: String = current["lines"][current["line"]]
	var shown := line.substr(0, int(typed))
	var box := Rect2(120, 220, W - 240, 220)
	_draw_box(box)
	if current["speaker"] != "":
		draw_string(font, box.position + Vector2(28, 44), current["speaker"], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.55, 0.85, 1.0))
	draw_multiline_string(font, box.position + Vector2(28, 90), shown, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 56.0, 28, -1, Color.WHITE)
	var hint := Controls.action_label("ui_accept") + "  ▼" if typed >= line.length() else ""
	draw_string(font, box.position + Vector2(box.size.x - 70, box.size.y - 16), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))


func _draw_map_page() -> void:
	var font := ThemeDB.fallback_font
	var progress := clampf((t - 6.2) / 2.0, 0.0, 1.0)
	var frame := Rect2(map_origin - Vector2(20, 14), Vector2(W - 80, H - 72))
	draw_style_box(UiStyle.flat(Color(0.05, 0.1, 0.26, 0.95), Color(0.9, 0.8, 0.4), 4), frame)
	draw_texture(map_gray_tex, map_origin, Color(1, 1, 1, 1.0 - progress))
	draw_texture(map_color_tex, map_origin, Color(1, 1, 1, progress))
	# naamplaatjes
	var names := {"temple": tr("Kristaltempel"), "village": tr("Dageraadsdorp"), "forest": tr("Fluisterbos"), "ruins": tr("Vergeten Ruïne"), "cave": tr("Echo-grot")}
	for map_id: String in ISLANDS:
		var p: Vector2 = map_origin + ISLANDS[map_id]
		draw_string_outline(font, p + Vector2(0, -6), names[map_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
		draw_string(font, p + Vector2(0, -6), names[map_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.5 + progress * 0.5))
	# de drie kristallen
	var items_tex := Art.tex("items")
	var crystal_ids := ["crystal_bos", "crystal_ruine", "crystal_grot"]
	for i in 3:
		var spot: Vector2 = map_origin + CRYSTAL_SPOTS[i] + Vector2(0, sin(t * 2.0 + float(i)) * 4.0)
		var icon: int = Items.ITEMS[crystal_ids[i]]["icon"]
		if lit[i]:
			var since: float = t - float([0.8, 2.6, 4.4][i])
			var glow := 40.0 + sin(t * 4.0) * 6.0 + maxf(0.0, 2.0 - since) * 40.0
			draw_circle(spot, glow, Color(0.4, 0.8, 1.0, 0.16))
			draw_circle(spot, glow * 0.6, Color(0.6, 0.9, 1.0, 0.2))
			draw_line(spot, map_origin + Vector2(480, 220), Color(0.6, 0.9, 1.0, 0.3 * minf(since, 1.0)), 3.0)
		draw_texture_rect_region(items_tex, Rect2(spot - Vector2(32, 32), Vector2(64, 64)), Rect2(Vector2(icon * 16, 0), Vector2(16, 16)),
			Color(1, 1, 1, 1.0 if lit[i] else 0.3))
	if progress > 0.5:
		var alpha := clampf((t - 7.2) / 1.0, 0.0, 1.0)
		_text_centered(tr("De Blauwe Kaart is weer heel."), H - 24.0, 34, Color(0.85, 0.95, 1.0, alpha))


func _draw_stats() -> void:
	var font := ThemeDB.fallback_font
	_text_centered(tr("Jouw avontuur"), 120, 54, Color(0.7, 0.92, 1.0))
	var done := 0
	for quest_id: String in Quests.QUESTS:
		if GameState.quest_state(quest_id) == "done":
			done += 1
	var weapon: Dictionary = Items.WEAPONS[GameState.weapon]
	var rows := [
		[tr("Speeltijd"), MenuUi.format_time(GameState.play_time)],
		[tr("Verslagen vijanden"), str(GameState.kills)],
		[tr("Munten"), str(GameState.coins)],
		[tr("Zwaard"), tr(weapon["name"])],
		[tr("Hartjes"), str(GameState.max_hp())],
		# Vertalers: aantal voltooide opdrachten: "5 van 9"
		[tr("Opdrachten voltooid"), tr("%d van %d") % [done, Quests.QUESTS.size()]],
	]
	var box := Rect2(280, 170, W - 560, 330)
	_draw_box(box)
	for i in rows.size():
		var shown := clampf((t - 0.3 - float(i) * 0.35) * 3.0, 0.0, 1.0)
		var y := box.position.y + 62.0 + i * 46.0
		draw_string(font, Vector2(box.position.x + 30, y), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.8, 0.9, 1.0, shown))
		draw_string(font, Vector2(box.position.x, y), rows[i][1], HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 30.0, 26, Color(1.0, 0.9, 0.5, shown))
	if t > 3.0:
		draw_string(font, Vector2(box.position.x, box.end.y + 40.0), Controls.action_label("ui_accept") + "  ▼", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 20, Color(1, 1, 1, 0.6))


func _draw_credits() -> void:
	var y := H - credits_scroll
	for entry: Array in Credits.LINES:
		match entry[0]:
			"title":
				_text_centered(tr(entry[1]), y, 64, Color(0.7, 0.92, 1.0))
			"heading":
				_text_centered(tr(entry[1]), y, 28, Color(1.0, 0.88, 0.5))
			"text":
				_text_centered(tr(entry[1]), y, 24, Color(0.9, 0.95, 1.0))
		y += 40.0


func _draw_end() -> void:
	var pulse := 0.75 + 0.25 * sin(t * 3.0)
	var crystal := Vector2(W / 2.0, 200.0 + sin(t * 2.0) * 8.0)
	draw_circle(crystal, 90.0, Color(0.4, 0.8, 1.0, 0.12))
	DrawUtil.sprite(self, Art.tex("crystal"), int(t * 1.4) % 2, 0, crystal, Vector2i(16, 16), 8.0)
	_text_centered(tr("Bedankt voor het spelen!"), 400, 64, Color(0.7, 0.92, 1.0))
	_text_centered(tr("Je voortgang is bewaard: je kunt verder in het dorp."), 450, 24, Color(0.85, 0.9, 1.0))
	_text_centered(tr("Druk op %s om naar het titelscherm te gaan") % Controls.action_label("ui_accept"), 520, 26, Color(1, 1, 1, pulse))
