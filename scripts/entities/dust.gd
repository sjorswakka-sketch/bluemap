extends Node2D
## Stof en dwarrelzand in pixelstijl: hooguit MAX_GRAINS korreltjes die met de wind over het beeld schuiven.
## Dezelfde opbouw als snow.gd: rijtjes getallen die in één keer worden getekend, dus het kost bijna niets.
## De korrels hangen aan de camera en waaien schuin omlaag, als een droge wind over de duinen.

const MAX_GRAINS := 90
const VIEW := Vector2(576, 324) # wat je ziet (zie world.gd)
const MARGIN := 16.0 # korrels beginnen en eindigen net buiten het beeld
const DRIFT := 55.0 # basissnelheid van de wind in pixels per seconde
const GUST := 30.0 # hoe sterk een korrel extra mee- of tegenvalt in een windvlaag
const GRAIN := Color(0.95, 0.85, 0.6, 0.55)
const GRAIN_DIM := Color(0.85, 0.72, 0.5, 0.35)

var world: Node
var camera: Camera2D
var level := 0.0 # 0 = windstil, 1 = volop dwarrelzand

var _pos := PackedVector2Array() # rond het midden van het beeld
var _speed := PackedFloat32Array() # 0.7 .. 1.3 keer de windsnelheid
var _phase := PackedFloat32Array() # waar in de windvlaag de korrel is
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 23 # elke keer dezelfde wind: rustig voor tests, en niemand ziet het verschil
	for i in MAX_GRAINS:
		_pos.append(Vector2.ZERO)
		_speed.append(1.0)
		_phase.append(0.0)
		_respawn(i, true)


## Het aantal korrels dat nu getekend wordt (nooit meer dan MAX_GRAINS).
func grain_count() -> int:
	return int(round(MAX_GRAINS * clampf(level, 0.0, 1.0)))


## Nieuwe kaart: niets op te ruimen (het zand waait gewoon verder). Hetzelfde recept als bij sneeuw.
func clear_splashes() -> void:
	pass


func _process(delta: float) -> void:
	var active := grain_count()
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
		_pos[i].x += DRIFT * _speed[i] * delta
		_pos[i].y += DRIFT * 0.25 * _speed[i] * delta
		if _pos[i].x >= VIEW.x / 2.0 + MARGIN:
			_respawn(i, false)
	queue_redraw()


func _draw() -> void:
	for i in grain_count():
		var gust := sin(_time * 2.3 * _speed[i] + _phase[i]) * GUST * 0.06
		var at := _pos[i] + Vector2(0.0, gust)
		draw_rect(Rect2(at.x, at.y, 2.0, 1.0), GRAIN if i % 3 != 0 else GRAIN_DIM)


## Een korrel begint weer links (of, bij het opstarten, ergens in het beeld).
func _respawn(i: int, anywhere: bool) -> void:
	var half := VIEW / 2.0
	_pos[i] = Vector2(
		_rng.randf_range(-half.x, half.x) if anywhere else -half.x - MARGIN,
		_rng.randf_range(-half.y - MARGIN, half.y + MARGIN))
	_speed[i] = _rng.randf_range(0.7, 1.3)
	_phase[i] = _rng.randf_range(0.0, TAU)
