extends Node
## De lucht boven de wereld: de kleur van de dag, het weer (regen of sneeuw) en de lichtjes 's nachts.
## Dit hoort bij world.gd, dat deze node aanmaakt en bij elke kaartwissel `enter_map()` aanroept.
##
## In de kaart staat wat hier van toepassing is:  "outdoor": true  (de kaart volgt dag en nacht)
## en  "weather": "rain" (altijd regen), "snow" (altijd sneeuw), "heat" (altijd snikheet)
## of "swamp" (altijd een vochtige waas), of "random" (wisselt met de klok). Zie scripts/core/daynight.gd.

const Daynight := preload("res://scripts/core/daynight.gd")
const RainScript := preload("res://scripts/entities/rain.gd")
const SnowScript := preload("res://scripts/entities/snow.gd")
const DustScript := preload("res://scripts/entities/dust.gd")
const WindowGlowScript := preload("res://scripts/entities/window_glow.gd")
const Tiles := preload("res://scripts/data/tiles.gd")

const RAIN_FADE := 4.0 # seconden die de regen nodig heeft om aan of uit te gaan
const SNOW_FADE := 4.0 # seconden die de sneeuw nodig heeft om aan of uit te gaan
const DUST_FADE := 4.0 # seconden die het dwarrelzand nodig heeft om aan of uit te gaan
const RAIN_VOLUME_DB := -13.0 # zachte regen, bij volle regen
const AMB_FADE := 2.0 # seconden die de achtergrondsfeer nodig heeft om te wisselen
const AMB_VOLUME_DB := -17.0 # de sfeer blijft zachtjes onder de muziek en de regen
const BED_PRICE := 5 # munten voor een nachtje in de herberg
const SLEEP_FADE := 1.0 # seconden om naar zwart (en terug) te gaan bij het slapen
const NIGHT_LIGHT := 0.3 # hoe sterk je eigen lamp 's nachts buiten schijnt (1 = zoals in de grot)

var world: Node2D
var outdoor := false
var weather := ""
var rain_level := 0.0 # hoe hard het regent: 0..1
var snow_level := 0.0 # hoe hard het sneeuwt: 0..1
var dust_level := 0.0 # hoeveel zand er dwarrelt: 0..1
var haze_level := 0.0 # hoe dik het moeraswaas is: 0..1
var light_need := 0.0 # hoeveel kunstlicht er nu nodig is: 0 = geen, 1 = zo donker als in de grot
var rain: Node2D
var snow: Node2D
var dust: Node2D
var rain_audio: AudioStreamPlayer
var amb_audio: AudioStreamPlayer
var amb_key := "" # welke sfeerlus nu klinkt ("" = geen), bijvoorbeeld "amb_bos_ochtend"
var amb_level := 0.0 # hoe hard die klinkt tijdens een overgang: 0..1
var amb_loops := {} # sleutel -> loopende stream (Wordt eenmalig klaargezet)
var windows: Node2D


func _ready() -> void:
	rain = RainScript.new()
	rain.world = world
	world.fx_layer.add_child(rain)
	snow = SnowScript.new()
	snow.world = world
	world.fx_layer.add_child(snow)
	dust = DustScript.new()
	dust.world = world
	world.fx_layer.add_child(dust)
	rain_audio = AudioStreamPlayer.new()
	rain_audio.bus = "SFX"
	rain_audio.process_mode = Node.PROCESS_MODE_ALWAYS # de regen hoor je ook in het menu
	var stream: AudioStream = Sound.streams.get("wereld_regen")
	if stream is AudioStreamWAV:
		var loop: AudioStreamWAV = stream.duplicate()
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		# In samples. Uit de lengte rekenen, niet uit de grootte van de data: die is ingepakt (QOA, zie het .import-bestand).
		loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
		rain_audio.stream = loop
	add_child(rain_audio)
	amb_audio = AudioStreamPlayer.new()
	amb_audio.bus = "SFX"
	amb_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(amb_audio)
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
	snow_level = _snow_target() # idem voor sneeuw
	dust_level = _dust_target() # idem voor dwarrelzand
	haze_level = _haze_target() # idem voor het moeraswaas
	rain.clear_splashes()
	snow.clear_splashes()
	dust.clear_splashes()
	_build_windows(data)
	var night_lamp: bool = outdoor and world.darkness <= 0.0
	world.player.set_lit(world.darkness > 0.0 or night_lamp, 1.0 if not night_lamp else NIGHT_LIGHT, 3.2 if not night_lamp else 2.2)
	# De achtergrondsfeer wisselt meteen mee met de kaart (geen hoorbare overgang bij een kaartwissel).
	amb_key = _amb_target()
	amb_level = 1.0 if amb_key != "" else 0.0
	if amb_key != "":
		amb_audio.stream = _amb_loop(amb_key)
		if not amb_audio.playing:
			amb_audio.play()
	elif amb_audio.playing:
		amb_audio.stop()
	_apply()


func _process(delta: float) -> void:
	rain_level = move_toward(rain_level, _rain_target(), delta / RAIN_FADE)
	snow_level = move_toward(snow_level, _snow_target(), delta / SNOW_FADE)
	dust_level = move_toward(dust_level, _dust_target(), delta / DUST_FADE)
	# De sfeer loopt zachtjes over als het dagdeel kantelt: eerst uitfaden, dan de nieuwe lus infaden.
	var want := _amb_target()
	if want != amb_key:
		amb_level = move_toward(amb_level, 0.0, delta / AMB_FADE)
		if amb_level <= 0.0:
			amb_key = want
			if amb_key != "":
				amb_audio.stream = _amb_loop(amb_key)
				if not amb_audio.playing:
					amb_audio.play()
			elif amb_audio.playing:
				amb_audio.stop()
	elif amb_key != "":
		amb_level = move_toward(amb_level, 1.0, delta / AMB_FADE)
	_apply()


## Of het hier nu hoort te regenen (1) of niet (0).
func _rain_target() -> float:
	return 1.0 if Daynight.raining(weather, GameState.day_count, GameState.day_time) else 0.0


## Of het hier nu hoort te sneeuwen (1) of niet (0).
func _snow_target() -> float:
	return 1.0 if Daynight.snowing(weather, GameState.day_count, GameState.day_time) else 0.0


## Of de hitte hier nu zand hoort te doen dwarrelen (1) of niet (0).
func _dust_target() -> float:
	return 1.0 if Daynight.scorching(weather, GameState.day_count, GameState.day_time) else 0.0


## Of er hier nu een moeraswaas hoort te hangen (1) of niet (0).
func _haze_target() -> float:
	return 1.0 if Daynight.swampy(weather, GameState.day_count, GameState.day_time) else 0.0


func _apply() -> void:
	if outdoor:
		var t := GameState.day_time
		world.canvas_mod.color = Daynight.tint_at(t) * Daynight.rain_tint(rain_level) * Daynight.snow_tint(snow_level) * Daynight.heat_tint(dust_level) * Daynight.swamp_tint(haze_level)
		light_need = Daynight.night_at(t)
		world.player.light.enabled = light_need > 0.02 and world.darkness <= 0.0
		world.player.light.energy = NIGHT_LIGHT * light_need
	else:
		light_need = 1.0 if world.darkness > 0.0 else 0.0
	rain.level = rain_level
	snow.level = snow_level
	dust.level = dust_level
	_update_audio()


func _update_audio() -> void:
	if rain_audio.stream != null:
		if rain_level <= 0.01:
			if rain_audio.playing:
				rain_audio.stop()
		else:
			rain_audio.volume_db = RAIN_VOLUME_DB + linear_to_db(rain_level)
			if not rain_audio.playing:
				rain_audio.play()
	if amb_audio.stream != null:
		if amb_level <= 0.01:
			if amb_audio.playing:
				amb_audio.stop()
		else:
			amb_audio.volume_db = AMB_VOLUME_DB + linear_to_db(amb_level)
			if not amb_audio.playing:
				amb_audio.play()


## Welke sfeerlus hier nu hoort te klinken ("" = stil, bijvoorbeeld binnen).
func _amb_target() -> String:
	if not outdoor:
		return ""
	return Daynight.ambience(weather, GameState.day_time)


## De sfeerlus als naadloos doorlopende stream; elke sleutel wordt eenmalig klaargezet.
func _amb_loop(key: String) -> AudioStream:
	if not amb_loops.has(key):
		var stream: AudioStream = Sound.streams.get(key)
		if stream is AudioStreamWAV:
			var loop: AudioStreamWAV = stream.duplicate()
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			# In samples, uit de lengte gerekend (de data is ingepakt, zie het .import-bestand).
			loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
			amb_loops[key] = loop
		else:
			amb_loops[key] = stream
	return amb_loops[key]


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
	world.hud.show_banner(func() -> String: return tr("Goedemorgen!"))
	GameState.toast.emit(tr("Lekker geslapen! Je hebt weer alle hartjes."))
	await world.fader.fade_in(SLEEP_FADE)
	GameState.transitioning = false
