extends Node2D
## Regen in pixelstijl: hooguit MAX_DROPS korte strepen die schuin naar beneden vallen en MAX_SPLASHES spetters op de grond.
## Het zijn geen losse nodes maar rijtjes getallen die in één keer worden getekend, dus het kost bijna niets.
## De strepen hangen aan de camera (de regen valt over je beeld), de spetters blijven op hun plek in de wereld.

const MAX_DROPS := 150
const MAX_SPLASHES := 40
const VIEW := Vector2(576, 324) # wat je ziet (zie world.gd)
const MARGIN := 20.0 # strepen beginnen en eindigen net buiten het beeld
const FALL := Vector2(-34.0, 280.0) # valsnelheid in pixels per seconde
const SPLASH_TIME := 0.28
const STREAK_LIGHT := Color(0.82, 0.9, 1.0, 0.75)
const STREAK_DARK := Color(0.62, 0.76, 0.98, 0.55)

var world: Node
var camera: Camera2D
var level := 0.0 # 0 = droog, 1 = volop regen

var _pos := PackedVector2Array() # rond het midden van het beeld
var _speed := PackedFloat32Array() # 0.85 .. 1.15 keer de valsnelheid
var _length := PackedFloat32Array()
var _land := PackedFloat32Array() # hoogte in het beeld waar deze druppel de grond raakt
var _splash_pos := PackedVector2Array() # in wereldcoördinaten
var _splash_age := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7 # elke keer dezelfde buien: rustig voor tests, en niemand ziet het verschil
	for i in MAX_DROPS:
		_pos.append(Vector2.ZERO)
		_speed.append(1.0)
		_length.append(8.0)
		_land.append(0.0)
		_respawn(i, true)


## Het aantal strepen dat nu getekend wordt (nooit meer dan MAX_DROPS).
func drop_count() -> int:
	return int(round(MAX_DROPS * clampf(level, 0.0, 1.0)))


func splash_count() -> int:
	return _splash_pos.size()


## Nieuwe kaart: de spetters van de vorige horen er niet meer te zijn.
func clear_splashes() -> void:
	_splash_pos.clear()
	_splash_age.clear()


func _process(delta: float) -> void:
	var active := drop_count()
	if active == 0 and _splash_pos.is_empty():
		visible = false
		return
	visible = true
	if camera == null and world != null and world.player != null:
		camera = world.player.camera # de speler (en zijn camera) komt pas na de wereld in beeld
	if camera != null and is_instance_valid(camera):
		global_position = camera.get_screen_center_position()
	for i in active:
		_pos[i] += Vector2(FALL.x, FALL.y * _speed[i]) * delta
		if _pos[i].y >= _land[i]:
			_add_splash(global_position + _pos[i])
			_respawn(i, false)
	var s := 0
	while s < _splash_pos.size():
		_splash_age[s] += delta
		if _splash_age[s] >= SPLASH_TIME:
			_splash_pos.remove_at(s)
			_splash_age.remove_at(s)
		else:
			s += 1
	queue_redraw()


func _draw() -> void:
	var dir := FALL.normalized()
	for i in drop_count():
		var head := _pos[i]
		draw_line(head - dir * _length[i], head, STREAK_LIGHT if i % 3 != 0 else STREAK_DARK, 1.0)
	for i in _splash_pos.size():
		var progress := _splash_age[i] / SPLASH_TIME
		var color := Color(0.85, 0.93, 1.0, 0.8 * (1.0 - progress))
		var at := _splash_pos[i] - global_position
		var spread := 1.0 + progress * 3.0
		draw_rect(Rect2(at.x - spread, at.y, 1, 1), color)
		draw_rect(Rect2(at.x + spread, at.y, 1, 1), color)
		draw_rect(Rect2(at.x, at.y - 1.0 - spread * 0.6, 1, 1), color)


## Een druppel begint weer bovenaan (of, bij het opstarten, ergens in het beeld).
func _respawn(i: int, anywhere: bool) -> void:
	var half := VIEW / 2.0
	_land[i] = _rng.randf_range(-half.y * 0.55, half.y)
	_pos[i] = Vector2(
		_rng.randf_range(-half.x - MARGIN, half.x + MARGIN + 60.0),
		-half.y - MARGIN if not anywhere else _rng.randf_range(-half.y, _land[i]))
	_speed[i] = _rng.randf_range(0.85, 1.15)
	_length[i] = _rng.randf_range(6.0, 11.0)


func _add_splash(world_pos: Vector2) -> void:
	if _splash_pos.size() >= MAX_SPLASHES:
		return
	_splash_pos.append(world_pos)
	_splash_age.append(0.0)
