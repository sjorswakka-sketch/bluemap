extends StaticBody2D
## Een blauw altaar: je wordt genezen en je voortgang wordt opgeslagen. Zo ontdek je het ook: daarna kun je
## er snel naartoe reizen via de kaart in het menu (zie scripts/core/fast_travel.gd).

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const FastTravel := preload("res://scripts/core/fast_travel.gd")

const LIGHT_ENERGY := 0.9

var world: Node
var t := randf() * TAU
var flash := 0.0
var player: Node2D
var light: PointLight2D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 12)
	shape.shape = rect
	shape.position = Vector2(0, 6)
	add_child(shape)
	light = PointLight2D.new()
	light.texture = Art.light_texture()
	light.color = Color(0.4, 0.75, 1.0)
	light.texture_scale = 1.6
	light.energy = LIGHT_ENERGY
	light.enabled = false
	add_child(light)


func _process(delta: float) -> void:
	t += delta
	flash = maxf(flash - delta, 0.0)
	if player == null:
		player = Util.player(self)
	# Het altaar gloeit in donkere gebieden, en buiten 's avonds en 's nachts.
	var need: float = world.light_need() if world != null else 0.0
	light.enabled = need > 0.02
	light.energy = LIGHT_ENERGY * need
	queue_redraw()


## De vlag die onthoudt dat dit altaar ontdekt is (opgeslagen met de rest van de vlaggen).
func discovery_key() -> String:
	return FastTravel.altar_key(GameState.map_id, Vector2i(int(position.x / 32.0), int(position.y / 32.0)))


func interact() -> void:
	GameState.full_rest()
	var first_time := not GameState.flag(discovery_key())
	GameState.set_flag(discovery_key())
	world.autosave()
	Sound.play("save")
	flash = 0.6
	world.burst(global_position + Vector2(0, -6), Color(0.5, 0.85, 1.0), 16)
	GameState.toast.emit(tr("Voortgang opgeslagen. Je bent genezen!"))
	if first_time:
		Sound.play("wereld_altaar", -2.0)
		world.ring(global_position + Vector2(0, -6), 54.0, Color(0.5, 0.85, 1.0))
		GameState.toast.emit(tr("Altaar ontdekt! Via de kaart (N) reis je er later snel naartoe."))


func _draw() -> void:
	DrawUtil.ellipse(self, Vector2(0, 12), Vector2(11, 3.5), Color(0, 0, 0, 0.3))
	draw_circle(Vector2(0, -4), 16.0 + sin(t * 2.0) * 2.0 + flash * 14.0, Color(0.3, 0.7, 1.0, 0.14 + flash * 0.25))
	DrawUtil.sprite(self, Art.tex("altar"), int(t * 1.1) % 2, 0)
	if player and player.target == self:
		DrawUtil.prompt(self, Vector2(0, -28.0), t)
