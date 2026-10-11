extends Node2D
## De schietbaan: houdt de tijd bij tijdens een poging en telt hoeveel doelwitten je raakt. Tessa (scripts/data/ext/boog.gd)
## start een poging met de actie ["boog_range_start"].
##
##   {"type": "boog_baan", "pos": [31, 15], "size": [1, 3], "id": "schietbaan"}
##
## `pos` en `size` (in tegels) zijn de schietlijn: een strook planken waar je achter staat. Alle doelwitten met
## "range": "schietbaan" horen bij deze baan. `time` (seconden) is de tijd voor een poging, standaard 20.

const Util := preload("res://scripts/core/util.gd")

const DEFAULT_TIME := 20.0
const READY_TIME := 1.2 # tussen "Klaar?" en "Af!"
const END_TIME := 2.5 # zo lang blijft het resultaat staan voordat de doelwitten weer recht staan
const PRACTICE_RESET := 1.6 # een oefenschot: het doelwit staat daarna vanzelf weer recht
const WON_FLAG := "boog_range_won"
const QUEST := "boog_schietbaan"
const LOW_TIME := 5.0 # onder deze tijd kleurt de teller rood

var world: Node
var obj: Dictionary = {}
var key := ""
var range_id := "schietbaan"
var time_limit := DEFAULT_TIME
var state := "idle" # idle, ready, run, won of lost
var time_left := 0.0
var ready_left := 0.0
var end_left := 0.0
var elapsed := 0.0
var hits := 0
var player: Node2D
var floor_node: Node2D # de planken op de grond (onder de personages getekend)
var overlay: Node2D # de teller boven je hoofd (boven alles getekend)


func _ready() -> void:
	add_to_group("boog_range")
	range_id = obj.get("id", "schietbaan")
	time_limit = float(obj.get("time", DEFAULT_TIME))
	floor_node = Node2D.new()
	floor_node.position = position
	floor_node.draw.connect(_draw_floor)
	world.ground.add_child(floor_node) # de grondlaag wordt bij een nieuwe kaart vanzelf opgeruimd
	overlay = Node2D.new()
	overlay.z_index = 45
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)


func _exit_tree() -> void:
	if is_instance_valid(floor_node):
		floor_node.queue_free()


func targets() -> Array[Node2D]:
	var found: Array[Node2D] = []
	for target: Node2D in get_tree().get_nodes_in_group("boog_target"):
		if target.range_id == range_id:
			found.append(target)
	return found


func _count_hits() -> int:
	var total := 0
	for target in targets():
		if target.hit:
			total += 1
	return total


func _reset_targets() -> void:
	for target in targets():
		target.reset()


## Begint een poging (door Tessa). Tijdens een lopende poging doet dit niets.
func start_run() -> void:
	if state == "ready" or state == "run":
		return
	_reset_targets()
	state = "ready"
	ready_left = READY_TIME
	hits = 0
	Sound.play("select", -2.0)


func _process(delta: float) -> void:
	if player == null:
		player = Util.player(self)
	match state:
		"idle":
			for target in targets():
				if target.hit and target.hit_age > PRACTICE_RESET:
					target.reset()
		"ready":
			ready_left -= delta
			if ready_left <= 0.0:
				_go()
		"run":
			elapsed += delta
			time_left -= delta
			var now := _count_hits()
			if now > hits:
				hits = now
				_floating_text("%d/%d" % [hits, targets().size()], Color(1.0, 0.9, 0.4))
			if hits >= targets().size():
				_win()
			elif time_left <= 0.0:
				_lose()
		"won", "lost":
			end_left -= delta
			if end_left <= 0.0:
				_reset_targets()
				state = "idle"
	overlay.queue_redraw()


func _go() -> void:
	_reset_targets()
	state = "run"
	time_left = time_limit
	elapsed = 0.0
	hits = 0
	Sound.play("select", -2.0, 1.6)
	_floating_text("Af!", Color(0.6, 1.0, 0.7))


func _win() -> void:
	state = "won"
	end_left = END_TIME
	Sound.play("quest")
	var seconds := ("%.1f" % elapsed).replace(".", ",")
	if GameState.quest_state(QUEST) == "active" and not GameState.flag(WON_FLAG):
		GameState.set_flag(WON_FLAG)
		GameState.toast.emit("Gehaald in %s seconden! Ga naar Tessa voor je beloning." % seconds)
	else:
		GameState.toast.emit("Gehaald in %s seconden!" % seconds)


func _lose() -> void:
	state = "lost"
	end_left = END_TIME
	Sound.play("error")
	GameState.toast.emit("Tijd om! Je raakte %d van de %d. Praat met Tessa voor een nieuwe poging." % [hits, targets().size()])


func _floating_text(text: String, color: Color) -> void:
	if player and is_instance_valid(player):
		world.damage_number(player.global_position + Vector2(0, -30), text, color)


# --- Tekenen -----------------------------------------------------------------------------------

func _draw_floor() -> void:
	var size: Array = obj.get("size", [1, 1])
	var length := float(size[1]) * 32.0
	# Een strook planken: dit is de schietlijn.
	var left := -8.0
	var top := -16.0
	var width := 16.0
	floor_node.draw_rect(Rect2(left, top, width, length), Color(0.55, 0.38, 0.2))
	floor_node.draw_rect(Rect2(left, top, 3.0, length), Color(0.72, 0.52, 0.3))
	floor_node.draw_rect(Rect2(left + width - 3.0, top, 3.0, length), Color(0.4, 0.27, 0.14))
	var y := top + 8.0
	while y < top + length:
		floor_node.draw_line(Vector2(left, y), Vector2(left + width, y), Color(0.3, 0.2, 0.1, 0.8), 1.0)
		y += 16.0


func _draw_overlay() -> void:
	if state == "idle" or player == null or not is_instance_valid(player):
		return
	var text := ""
	var color := Color.WHITE
	match state:
		"ready":
			text = "Klaar?"
		"run":
			text = "%s  %d/%d" % [("%.1f" % maxf(time_left, 0.0)).replace(".", ","), hits, targets().size()]
			if time_left < LOW_TIME:
				color = Color(1.0, 0.5, 0.45)
		"won":
			text = "Gehaald!"
			color = Color(0.6, 1.0, 0.7)
		"lost":
			text = "Te laat!"
			color = Color(1.0, 0.5, 0.45)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var center := to_local(player.global_position) + Vector2(0, -44)
	overlay.draw_rect(Rect2(center.x - width / 2.0 - 6.0, center.y - 14.0, width + 12.0, 22.0), Color(0.04, 0.06, 0.14, 0.85))
	overlay.draw_rect(Rect2(center.x - width / 2.0 - 6.0, center.y - 14.0, width + 12.0, 22.0), Color(color, 0.8), false, 1.0)
	overlay.draw_string(font, center + Vector2(-width / 2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
