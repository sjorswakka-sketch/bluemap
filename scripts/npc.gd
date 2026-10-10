extends StaticBody2D
## Oudste Bram: geeft de opdracht en neemt de kristallen in ontvangst.

const DrawUtil := preload("res://scripts/draw_util.gd")

const NPC_NAME := "Oudste Bram"

var t := 0.0
var player: Node2D


func _ready() -> void:
	add_to_group("npc")
	collision_layer = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	shape.shape = rect
	add_child(shape)


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	queue_redraw()


func interact() -> void:
	var lines: Array = []
	var on_done := Callable()
	var needed := GameState.CRYSTALS_NEEDED

	if GameState.quest_done:
		lines = ["Dankzij jou is de kaart weer compleet!"]
	elif not GameState.quest_started:
		lines = [
			"Welkom, reiziger! Fijn dat je er bent.",
			"Onze blauwe kristallen zijn verdwenen. Zonder hen klopt de kaart van ons land niet meer.",
			"Slijmen hebben ze verspreid door het bos aan de overkant van de rivier.",
			"Breng me %d blauwe kristallen en ik beloon je. Pas op voor de slijmen!" % needed,
			"(Tip: met SPATIE zwaai je je zwaard.)",
		]
		on_done = GameState.start_quest
	elif GameState.crystals < needed:
		lines = [
			"Je hebt er nog maar %d van de %d." % [GameState.crystals, needed],
			"Zoek verder aan de overkant van de brug. Ze glinsteren in het bos en in de oude ruïne.",
		]
	else:
		lines = [
			"Daar zijn ze! Blauw als de diepste zee...",
			"Met deze kristallen klopt de kaart weer. Dankjewel, held!",
		]
		on_done = GameState.finish_quest

	GameState.dialogue_requested.emit(NPC_NAME, lines, on_done)


func _draw() -> void:
	DrawUtil.ellipse(self, Vector2(0, 12), Vector2(10, 4), Color(0, 0, 0, 0.3))
	# Paarse mantel, wit hoofd met baard.
	draw_colored_polygon(
		PackedVector2Array([Vector2(-6, -4), Vector2(6, -4), Vector2(10, 12), Vector2(-10, 12)]),
		Color(0.45, 0.25, 0.65))
	draw_circle(Vector2(0, -9), 7.0, Color(0.96, 0.78, 0.62))
	draw_colored_polygon(
		PackedVector2Array([Vector2(-6, -7), Vector2(6, -7), Vector2(0, 5)]),
		Color(0.92, 0.92, 0.95))
	draw_circle(Vector2(-2.5, -9), 1.1, Color(0.1, 0.1, 0.15))
	draw_circle(Vector2(2.5, -9), 1.1, Color(0.1, 0.1, 0.15))
	# Puntmuts.
	draw_colored_polygon(
		PackedVector2Array([Vector2(-7, -14), Vector2(7, -14), Vector2(0, -28)]),
		Color(0.35, 0.18, 0.55))

	# Ropje om te laten zien dat je kunt praten.
	if player and not GameState.dialogue_open and not GameState.ended \
			and player.global_position.distance_to(global_position) < 44.0:
		var bob := sin(t * 5.0) * 2.0
		draw_rect(Rect2(-8, -46 + bob, 16, 14), Color(0, 0, 0, 0.75))
		draw_string(ThemeDB.fallback_font, Vector2(-4, -35 + bob), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
