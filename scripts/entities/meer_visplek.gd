extends Node2D
## Een visplek in het Zilvermeer: kringetjes in het water. Met een hengel start E het visspel (scripts/ui/fishing_ui.gd).
## In de kaart: {"type": "meer_visplek", "pos": [x, y]} op een watertegel naast de oever of steiger.
## Het soort "meer_diepe_visplek" is diep water, waar de Gouden Karper zwemt (met een eigen kleur op het kaartje).

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Util := preload("res://scripts/core/util.gd")

const UI_SCRIPT := "res://scripts/ui/fishing_ui.gd"
const RIPPLE_COLOR := Color(1, 1, 1)
const DEEP_RIPPLE_COLOR := Color(0.75, 0.9, 1.0)
const GOLD_GLINT := Color(1.0, 0.9, 0.4)
const HINT_COOLDOWN := 3.0 # zo lang komt de melding "geen hengel" niet nog een keer

var world: Node
var obj: Dictionary = {}
var key := ""
var deep := false
var t := randf() * 10.0
var player: Node2D
var hint_wait := 0.0


func _ready() -> void:
	add_to_group("interactable")
	deep = obj.get("type", "") == "meer_diepe_visplek"


func _process(delta: float) -> void:
	t += delta
	hint_wait -= delta
	if player == null:
		player = Util.player(self)
	queue_redraw()


func interact() -> void:
	if GameState.count("fishing_rod") <= 0:
		Sound.play("error", -3.0)
		if hint_wait <= 0.0: # vaak op E drukken stapelt geen rij met dezelfde melding op
			hint_wait = HINT_COOLDOWN
			GameState.toast.emit("Je hebt een hengel nodig. Misschien heeft Visser Joris er een.")
		return
	var ui: Node = world.get_node_or_null("Vissen")
	if ui == null:
		var script: Script = load(UI_SCRIPT)
		ui = script.new()
		ui.name = "Vissen"
		world.add_child(ui)
	ui.call("start", self)


func _draw() -> void:
	# Twee kringetjes die uitdijen en vervagen, een beetje platgedrukt zoals water in perspectief.
	var color := DEEP_RIPPLE_COLOR if deep else RIPPLE_COLOR
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	for i in 2:
		var phase := fmod(t * 0.7 + i * 0.5, 1.0)
		draw_arc(Vector2.ZERO, 3.0 + phase * 13.0, 0.0, TAU, 24, Color(color, (1.0 - phase) * 0.7), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if deep:
		# Hier en daar een gouden glinstering: de Gouden Karper zwemt hier ergens.
		var glint := sin(t * 1.7) * sin(t * 0.9 + 1.0)
		if glint > 0.55:
			var size := (glint - 0.55) * 14.0
			draw_rect(Rect2(Vector2(5, -6) - Vector2(1, size) / 2.0, Vector2(2, size)), GOLD_GLINT)
			draw_rect(Rect2(Vector2(5, -6) - Vector2(size, 1) / 2.0, Vector2(size, 2)), GOLD_GLINT)
	if player and player.target == self and not GameState.input_locked():
		DrawUtil.name_tag(self, Vector2(0, -22.0), "Diepe visplek" if deep else "Visplek")
		DrawUtil.prompt(self, Vector2(0, -36.0), t)
