extends Node
## De lucht boven de wereld: de kleur van de dag, het weer (regen, met geluid) en de lichtjes 's nachts.
## Dit hoort bij world.gd, dat deze node aanmaakt en bij elke kaartwissel `enter_map()` aanroept.
##
## In de kaart staat wat hier van toepassing is:  "outdoor": true  (de kaart volgt dag en nacht)
## en  "weather": "rain" (altijd regen) of "random" (wisselt met de klok). Zie scripts/core/daynight.gd.

const Daynight := preload("res://scripts/core/daynight.gd")
const RainScript := preload("res://scripts/entities/rain.gd")
const WindowGlowScript := preload("res://scripts/entities/window_glow.gd")
const Tiles := preload("res://scripts/data/tiles.gd")

const RAIN_FADE := 4.0 # seconden die de regen nodig heeft om aan of uit te gaan
const RAIN_VOLUME_DB := -13.0 # zachte regen, bij volle regen
const BED_PRICE := 5 # munten voor een nachtje in de herberg
const SLEEP_FADE := 1.0 # seconden om naar zwart (en terug) te gaan bij het slapen
const NIGHT_LIGHT := 0.3 # hoe sterk je eigen lamp 's nachts buiten schijnt (1 = zoals in de grot)

var world: Node2D
var outdoor := false
var weather := ""
var rain_level := 0.0 # hoe hard het regent: 0..1
var light_need := 0.0 # hoeveel kunstlicht er nu nodig is: 0 = geen, 1 = zo donker als in de grot
var rain: Node2D
var rain_audio: AudioStreamPlayer
var windows: Node2D


func _ready() -> void:
	rain = RainScript.new()
	rain.world = world
	world.fx_layer.add_child(rain)
	rain_audio = AudioStreamPlayer.new()
	rain_audio.bus = "SFX"
	rain_audio.process_mode = Node.PROCESS_MODE_ALWAYS # de regen hoor je ook in het menu
	var stream: AudioStream = Sound.streams.get("wereld_regen")
	if stream is AudioStreamWAV:
		var loop: AudioStreamWAV = stream.duplicate()
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		@warning_ignore("integer_division")
		loop.loop_end = loop.data.size() / 2 # 16 bit, mono: 2 bytes per sample
		rain_audio.stream = loop
	add_child(rain_audio)
	GameState.achievement_unlocked.connect(_celebrate)


## Een behaalde prestatie: even gouden glinsteringen rond de speler.
func _celebrate(_achievement_id: String) -> void:
	if is_instance_valid(world.player) and world.player.is_inside_tree():
		world.burst(world.player.global_position + Vector2(0, -12), Color(1.0, 0.9, 0.4), 14)
		world.ring(world.player.global_position, 36.0, Color(1.0, 0.9, 0.4))


## Wordt aangeroepen als er een kaart geladen is.
func enter_map(data: Dictionary) -> void:
	outdoor = data.get("outdoor", false)
	weather = data.get("weather", "")
	rain_level = _rain_target() # het regent meteen als het regent, en anders niet
	rain.clear_splashes()
	_build_windows(data)
	var night_lamp: bool = outdoor and world.darkness <= 0.0
	world.player.set_lit(world.darkness > 0.0 or night_lamp, 1.0 if not night_lamp else NIGHT_LIGHT, 3.2 if not night_lamp else 2.2)
	_apply()


func _process(delta: float) -> void:
	rain_level = move_toward(rain_level, _rain_target(), delta / RAIN_FADE)
	_apply()


## Of het hier nu hoort te regenen (1) of niet (0).
func _rain_target() -> float:
	return 1.0 if Daynight.raining(weather, GameState.day_count, GameState.day_time) else 0.0


func _apply() -> void:
	if outdoor:
		var t := GameState.day_time
		world.canvas_mod.color = Daynight.tint_at(t) * Daynight.rain_tint(rain_level)
		light_need = Daynight.night_at(t)
		world.player.light.enabled = light_need > 0.02 and world.darkness <= 0.0
		world.player.light.energy = NIGHT_LIGHT * light_need
	else:
		light_need = 1.0 if world.darkness > 0.0 else 0.0
	rain.level = rain_level
	_update_audio()


func _update_audio() -> void:
	if rain_audio.stream == null:
		return
	if rain_level <= 0.01:
		if rain_audio.playing:
			rain_audio.stop()
		return
	rain_audio.volume_db = RAIN_VOLUME_DB + linear_to_db(rain_level)
	if not rain_audio.playing:
		rain_audio.play()


## De ramen van de huizen op een buitenkaart gaan 's nachts gloeien.
func _build_windows(data: Dictionary) -> void:
	if is_instance_valid(windows):
		windows.queue_free()
	windows = null
	if not outdoor:
		return
	var cells: Array[Vector2i] = []
	var rows: Array = data["rows"]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if Tiles.CHARS.get(row[x], "") == "house_window":
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		return
	windows = WindowGlowScript.new()
	windows.world = world
	windows.cells = cells
	world.ground.add_child(windows)


# --- Slapen ------------------------------------------------------------------------------------

## Een nachtje slapen in de herberg: kost munten, je wordt helemaal beter en het wordt ochtend.
func sleep_in_bed() -> void:
	if GameState.transitioning or GameState.coins < BED_PRICE:
		return
	GameState.transitioning = true
	GameState.add_coins(-BED_PRICE)
	Sound.play("wereld_slapen")
	await world.fader.fade_out(SLEEP_FADE)
	GameState.full_heal()
	GameState.skip_to_morning()
	GameState.set_flag("wereld_geslapen")
	world.autosave()
	_apply()
	await get_tree().create_timer(0.6, true, false, true).timeout
	world.hud.show_banner("Goedemorgen!")
	GameState.toast.emit("Lekker geslapen! Je hebt weer alle hartjes.")
	await world.fader.fade_in(SLEEP_FADE)
	GameState.transitioning = false
