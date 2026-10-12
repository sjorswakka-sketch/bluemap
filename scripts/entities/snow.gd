extends Node2D
## Sneeuw in pixelstijl: hooguit MAX_FLAKES vlokjes die langzaam dwarrelend naar beneden zweven.
## Net als de regen zijn het rijtjes getallen die in één keer worden getekend, dus het kost bijna niets.
## De vlokken hangen aan de camera (de sneeuw valt over je beeld). Er zijn geen spetters: vlokken smelten.

const MAX_FLAKES := 120
const VIEW := Vector2(576, 324) # wat je ziet (zie world.gd)
const MARGIN := 16.0 # vlokken beginnen en eindigen net buiten het beeld
const FALL := 30.0 # basisvalsnelheid in pixels per seconde (sneeuw zweeft, regen stort)
const SWAY := 22.0 # hoe ver een vlok heen en weer dwarrelt
const FLAKE := Color(0.96, 0.98, 1.0, 0.9)
const FLAKE_DIM := Color(0.82, 0.88, 0.97, 0.65)

var world: Node
var camera: Camera2D
var level := 0.0 # 0 = helder, 1 = volop sneeuw

var _pos := PackedVector2Array() # rond het midden van het beeld
var _speed := PackedFloat32Array() # 0.7 .. 1.3 keer de valsnelheid
var _phase := PackedFloat32Array() # waar in de dwarrelbeweging de vlok is
var _size := PackedFloat32Array() # 1 of 2 pixels
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 11 # elke keer dezelfde sneeuwval: rustig voor tests, en niemand ziet het verschil
	for i in MAX_FLAKES:
		_pos.append(Vector2.ZERO)
		_speed.append(1.0)
		_phase.append(0.0)
		_size.append(1.0)
		_respawn(i, true)


## Het aantal vlokken dat nu getekend wordt (nooit meer dan MAX_FLAKES).
func flake_count() -> int:
	return int(round(MAX_FLAKES * clampf(level, 0.0, 1.0)))


## Nieuwe kaart: niets op te ruimen (vlokken dwarrelen gewoon verder). Hetzelfde recept als bij regen.
func clear_splashes() -> void:
	pass


func _process(delta: float) -> void:
	var active := flake_count()
	if active == 0:
		visible = false
		return
	visible = true
	_time += delta
	if camera == null and world != null and world.player != null:
		camera = world.player.camera # de speler (en zijn camera) komt pas na de wereld in beeld
	if camera != null and is_instance_valid(camera):
		global_position = camera.get_screen_center_position()
	for i in active:
		_pos[i].y += FALL * _speed[i] * delta
		if _pos[i].y >= VIEW.y / 2.0 + MARGIN:
			_respawn(i, false)
	queue_redraw()


func _draw() -> void:
	for i in flake_count():
		var sway := sin(_time * 1.7 * _speed[i] + _phase[i]) * SWAY * 0.12
		var at := _pos[i] + Vector2(sway, 0.0)
		var s := _size[i]
		draw_rect(Rect2(at.x, at.y, s, s), FLAKE if i % 3 != 0 else FLAKE_DIM)


## Een vlok begint weer bovenaan (of, bij het opstarten, ergens in het beeld).
func _respawn(i: int, anywhere: bool) -> void:
	var half := VIEW / 2.0
	_pos[i] = Vector2(
		_rng.randf_range(-half.x - MARGIN, half.x + MARGIN),
		_rng.randf_range(-half.y, half.y) if anywhere else -half.y - MARGIN)
	_speed[i] = _rng.randf_range(0.7, 1.3)
	_phase[i] = _rng.randf_range(0.0, TAU)
	_size[i] = 2.0 if _rng.randf() < 0.25 else 1.0
