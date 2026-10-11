extends CanvasLayer
## De melding "Prestatie behaald!" bovenin het beeld. Hij schuift naar binnen, blijft even staan en schuift weer weg.
## Alle prestaties die nog getoond moeten worden staan in GameState.achievement_queue. Deze melding pakt ze een voor een
## en haalt ze pas uit de rij als hij ze echt toont. Zo gaat er niets verloren als er even geen beeld is (bijvoorbeeld
## tijdens het zwart worden bij het einde): de volgende melding in een volgend scherm toont ze alsnog.
## Bij de eerste melding vertellen we ook waar je al je prestaties en het beestenboek vindt.

const Art := preload("res://scripts/core/art.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")
const Achievements := preload("res://scripts/data/achievements.gd")

const PANEL_SIZE := Vector2(480, 68)
const TOP := 72.0 # hoe ver van de bovenkant hij blijft staan (onder de baasbalk)
const SHOW_TIME := 4.0 # seconden in beeld
const SHOW_TIME_RUSH := 1.8 # als er meer dan twee wachten (bijvoorbeeld na het laden van een oude opslag)
const SLIDE_TIME := 0.35 # seconden om in en uit te schuiven
const TROPHY_FRAME := 3 # de gouden beker in assets/wereld_ui.png
const HINT := "Al je prestaties zie je met T, het beestenboek met B."

var root: Control
var name_label: Label
var time := 0.0 # hoe lang de huidige melding nog in beeld blijft
var duration := SHOW_TIME # hoe lang de huidige melding in totaal in beeld is
var hinted := false # de tip over T en B is al gegeven


func _ready() -> void:
	layer = 12
	root = Control.new()
	root.position = Vector2((1152.0 - PANEL_SIZE.x) / 2.0, -PANEL_SIZE.y)
	root.size = PANEL_SIZE
	root.modulate.a = 0.0
	add_child(root)
	var panel := PanelContainer.new()
	panel.size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.12, 0.1, 0.04, 0.92), Color(1.0, 0.85, 0.3), 3))
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = Art.tex("wereld_ui")
	atlas.region = Rect2(TROPHY_FRAME * 16, 0, 16, 16)
	icon.texture = atlas
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var heading := Label.new()
	heading.text = "Prestatie behaald!"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	texts.add_child(heading)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 24)
	texts.add_child(name_label)


func is_showing() -> bool:
	return time > 0.0


## Tijdens een overgang in de wereld (deur, reizen, slapen, het einde) is het scherm zwart, en daarna staat de naam van
## de kaart groot in beeld (op dezelfde hoogte). Dan wachten we met de volgende melding.
func _screen_is_busy() -> bool:
	var world := get_tree().get_first_node_in_group("world")
	return world != null and (GameState.transitioning or world.hud.banner_time > 0.0)


func _process(delta: float) -> void:
	if time <= 0.0:
		root.modulate.a = 0.0
		if GameState.achievement_queue.is_empty() or _screen_is_busy():
			return
		duration = SHOW_TIME if GameState.achievement_queue.size() <= 2 else SHOW_TIME_RUSH
		name_label.text = Achievements.info(GameState.achievement_queue.pop_front())["name"]
		time = duration
		Sound.play("wereld_prestatie", -3.0)
		if not hinted:
			hinted = true
			GameState.toast.emit(HINT)
	time -= delta
	var shown := minf(duration - time, time) / SLIDE_TIME
	root.modulate.a = clampf(shown * 1.5, 0.0, 1.0)
	root.position.y = lerpf(-PANEL_SIZE.y, TOP, ease(clampf(shown, 0.0, 1.0), 0.4))
