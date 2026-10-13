extends Node2D
## Een vrijwillige proef. Verlaten wist de lokale golven; de eindbeloning is permanent.
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const WAVES := [["crystal_beetle", "crystal_beetle"], ["prism_moth", "prism_moth"], ["crystal_beetle", "prism_moth", "crystal_beetle"]]
const SPAWNS := [Vector2(8.5, 7.5) * 32, Vector2(23.5, 7.5) * 32, Vector2(16.5, 6.5) * 32]
var world: Node
var obj: Dictionary = {}
var key := ""
var active := false
var wave := 0
var countdown := 0.0
var foes: Array[Node2D] = []
var time := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("echo_trials")

func interact() -> void:
	if GameState.input_locked() or active:
		return
	if GameState.flag("echo_trial_won"):
		GameState.say(tr("Resonantieproef"), [tr("De kristallen zingen jouw naam. Je hebt deze proef al voltooid.")])
		return
	active = true
	wave = 0
	countdown = 3.0
	GameState.toast.emit(tr("Drie golven. Volg de lichtstralen. De uitgang blijft open als je wilt terugtrekken."))
	Sound.play("quest", -5.0)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()
	if not active or GameState.input_locked() or GameState.hp <= 0:
		return
	# Geen getypeerde filter: een reeds vrijgegeven Godot-object kan niet meer
	# naar Node2D worden omgezet voordat is_instance_valid het controleert.
	for index in range(foes.size() - 1, -1, -1):
		if not is_instance_valid(foes[index]) or foes[index].dead:
			foes.remove_at(index)
	if not foes.is_empty():
		return
	if countdown <= 0.0:
		if wave >= WAVES.size():
			_finish()
			return
		countdown = 3.0
	countdown = maxf(countdown - delta, 0.0)
	if countdown <= 0.0:
		_spawn_wave()

func _spawn_wave() -> void:
	if not active or wave >= WAVES.size():
		return
	for index in WAVES[wave].size():
		var at: Vector2 = SPAWNS[index]
		# Geef iemand die op een spawn staat eerst ruimte om weg te lopen.
		if world.player.global_position.distance_to(at) < 70.0:
			countdown = 1.0
			return
	for index in WAVES[wave].size():
		var foe: Node2D = world.spawn_enemy(WAVES[wave][index], SPAWNS[index])
		foe.state_time = 0.0
		foes.append(foe)
		world.ring(SPAWNS[index], 26.0, Color(0.6, 0.9, 1.0))
	wave += 1
	GameState.toast.emit(tr("Resonantieproef: golf %d / 3") % wave)

func _finish() -> void:
	active = false
	if GameState.flag("echo_trial_won"):
		return
	GameState.set_flag("echo_trial_won")
	GameState.give("gear_crystal_amulet", 1, true)
	GameState.add_coins(120)
	GameState.toast.emit(tr("Proef voltooid! Kristallen amulet + 120 munten. Trek het aan via Uitrusting."))
	world.ring(global_position, 96.0, Color(0.6, 0.95, 1.0))
	world.burst(global_position, Color(0.6, 0.95, 1.0), 24)
	Sound.play("quest")
	GameState.save_requested.emit()

func _draw() -> void:
	var won := GameState.flag("echo_trial_won")
	var color := Color(0.6, 1.0, 0.75) if won else Color(0.55, 0.85, 1.0)
	draw_arc(Vector2.ZERO, 24.0, 0, TAU, 40, Color(color, 0.6), 2.0)
	for i in 3:
		var point := Vector2.from_angle(time * 0.3 + i * TAU / 3) * 16.0
		draw_circle(point, 3.0, color if won or i < wave else color.darkened(0.5))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(10, -7), Vector2(0, 4), Vector2(-10, -7)]), color)
	if world.player.target == self and not active:
		DrawUtil.prompt(self, Vector2(0, -40), time)
	if active and countdown > 0 and wave < WAVES.size():
		for index in WAVES[wave].size():
			var at: Vector2 = SPAWNS[index] - global_position
			draw_arc(at, 23.0 + sin(time * 5.0) * 3, 0, TAU, 32, Color(1, 0.7, 0.3, 0.9), 2.0)
			DrawUtil.prompt(self, at + Vector2(0, -24), time, str(ceili(countdown)))
