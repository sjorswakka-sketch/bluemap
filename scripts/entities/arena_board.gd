extends Node2D
## Een bord aan de muur van de arenahal: de trofeeënplank of het scorebord met je beste tijden.
## Op de kaart: {"type": "arena_board", "pos": [2, 1], "span": 4, "board": "trophies"} (of "scores").
## `pos` is de meest linkse tegel, `span` het aantal tegels breed.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Arena := preload("res://scripts/data/arena.gd")

const TILE := 32.0
const REACH := 14.0 # het bord hangt een stukje lager, zodat je er makkelijker bij kunt
const SLOTS := ["arena_trophy_bronze", "arena_trophy_silver", "arena_trophy_gold", "arena_helm"]

var world: Node
var obj: Dictionary = {}
var key := ""
var board := "trophies"
var span := 4
var t := 0.0
var player: Node2D


func _ready() -> void:
	add_to_group("interactable")
	board = obj.get("board", "trophies")
	span = int(obj.get("span", 4))
	# Het midden van het bord is het punt waar je bij moet komen om te praten.
	position += Vector2((span - 1) * TILE / 2.0, REACH)


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = Util.player(self)
	queue_redraw()


func interact() -> void:
	Sound.play("select", -6.0)
	if board == "scores":
		GameState.say("Scorebord", scoreboard_lines())
	else:
		GameState.say("Trofeeënplank", shelf_lines())


## De tekst van het scorebord (ook handig om te testen).
func scoreboard_lines() -> Array:
	var lines: Array = ["Beste tijden in de arena. Jouw titel: %s." % Arena.title()]
	for rank: String in Arena.ORDER:
		lines.append("%s: %s" % [Arena.RANKS[rank]["name"], Arena.record_text(rank)])
	return lines


func shelf_lines() -> Array:
	var lines: Array = ["De trofeeënplank van de arena."]
	var owned := 0
	for item_id: String in SLOTS:
		if GameState.count(item_id) > 0:
			owned += 1
			lines.append("%s: %s" % [Arena.ITEMS[item_id]["name"], "een verzamelstuk voor kampioenen." if item_id == Arena.HELM else "gewonnen!"])
	if owned == 0:
		lines.append("Nog niets op de plank. Win een rang en zet hier je eerste trofee neer!")
	elif owned < SLOTS.size():
		lines.append("Er is nog plek op de plank. Win meer rangen!")
	else:
		lines.append("Een volle plank! Jij bent een echte kampioen.")
	return lines


func _draw() -> void:
	if board == "scores":
		_draw_scores()
	else:
		_draw_shelf()
	if player and player.target == self:
		DrawUtil.prompt(self, Vector2(0, -REACH - 50.0), t)


func _draw_shelf() -> void:
	var width := span * TILE
	var left := -width / 2.0
	var plank := -8.0 # bovenkant van de plank, vlak boven de vloer
	var wood := Color(0.54, 0.35, 0.17)
	var wood_light := Color(0.69, 0.46, 0.22)
	var wood_dark := Color(0.29, 0.18, 0.09)
	# De plank met steuntjes.
	draw_rect(Rect2(left + 2, plank, width - 4, 7), wood_dark)
	draw_rect(Rect2(left + 2, plank, width - 4, 5), wood)
	draw_rect(Rect2(left + 2, plank, width - 4, 1), wood_light)
	for i in span + 1:
		draw_rect(Rect2(left + i * TILE - 2, plank + 6, 4, 5), wood_dark)
	for i in SLOTS.size():
		var center := Vector2(left + (i + 0.5) * TILE, plank - 16.0)
		var owned := GameState.count(SLOTS[i]) > 0
		if owned:
			var sparkle := 0.5 + 0.5 * sin(t * 2.5 + float(i))
			if i == 2 or i == 3:
				draw_circle(center, 14.0 + sparkle * 2.0, Color(1.0, 0.9, 0.4, 0.12 + sparkle * 0.08))
		var tint := Color.WHITE if owned else Color(0.12, 0.1, 0.2, 0.55)
		DrawUtil.sprite(self, Art.tex(Arena.SHEET), i, 0, center, Vector2i(16, 16), 2.0, tint)


func _draw_scores() -> void:
	var width := span * TILE
	var left := -width / 2.0
	var top := -REACH - 46.0
	var height := 60.0
	draw_rect(Rect2(left + 2, top, width - 4, height), Color(0.29, 0.18, 0.09))
	draw_rect(Rect2(left + 2, top, width - 4, height), Color(0.69, 0.46, 0.22), false, 2.0)
	draw_rect(Rect2(left + 6, top + 4, width - 12, height - 8), Color(0.1, 0.14, 0.2))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(left + 12, top + 16), "SCOREBORD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.85, 0.4))
	for i in Arena.ORDER.size():
		var rank: String = Arena.ORDER[i]
		var y := top + 30.0 + i * 13.0
		var row_color := Color(Arena.RANKS[rank]["color"])
		draw_rect(Rect2(left + 12, y - 8, 6, 6), row_color)
		draw_string(font, Vector2(left + 22, y), Arena.RANKS[rank]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.93, 1.0))
		var has_record := Arena.best(rank) > 0.0
		draw_string(font, Vector2(left + 62, y), Arena.format_time(Arena.best(rank)) if has_record else "--:--",
			HORIZONTAL_ALIGNMENT_RIGHT, width - 82, 10, Color(1.0, 0.95, 0.6) if has_record else Color(0.5, 0.55, 0.65))
