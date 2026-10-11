extends Node
## Autoload "Sound": geluidseffecten, muziek en de geluid-aan/uit-schakelaar (toets M).

signal mute_changed(muted: bool)

const Content := preload("res://scripts/data/content.gd")

const BASE_SOUNDS := [
	"swing", "hit", "die", "hurt", "coin", "heart", "crystal", "select", "victory", "gameover",
	"dodge", "arrow", "chest", "buy", "save", "door", "boss", "error", "quest", "upgrade", "slam", "drink",
]
const BASE_TRACKS := ["village", "forest", "ruins", "cave", "boss", "temple", "ending"]
const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_DB := -9.0
const POOL_SIZE := 8

## Basis en uitbreidingen samen (zie scripts/data/content.gd).
var SOUNDS: Array = Content.appended("SOUNDS", BASE_SOUNDS)
var TRACKS: Array = Content.appended("TRACKS", BASE_TRACKS)

var streams := {}
var muted := false
var music_volume := 1.0 # 0..1
var sfx_volume := 1.0 # 0..1

var tracks := {}
var current_track := ""

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # ook tijdens de pauze doorspelen

	for sound_name: String in SOUNDS:
		var stream := _load("res://assets/audio/%s.wav" % sound_name)
		if stream:
			streams[sound_name] = stream
	_setup_buses()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)

	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	_music.bus = "Music"
	add_child(_music)
	for track: String in TRACKS:
		var music := _load("res://assets/audio/music_%s.wav" % track)
		if music is AudioStreamWAV:
			var wav: AudioStreamWAV = music
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			@warning_ignore("integer_division")
			wav.loop_end = wav.data.size() / 2 # 16-bit mono: 2 bytes per sample
			tracks[track] = wav

	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		muted = config.get_value("audio", "muted", false)
		music_volume = config.get_value("audio", "music", 1.0)
		sfx_volume = config.get_value("audio", "sfx", 1.0)
	_apply_mute()
	_apply_volumes()

	# Een eigen jingle bij verlies.
	GameState.game_over.connect(func() -> void:
		stop_music()
		play("gameover"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		toggle_mute()


func play(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(sound_name):
		return
	var player := _pool[0]
	for candidate in _pool:
		if not candidate.playing:
			player = candidate
			break
	player.stream = streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Speelt een muziekstuk af (zacht ingefaded). Dezelfde track opnieuw starten doet niets.
func play_music(track := "forest") -> void:
	if not tracks.has(track):
		track = "forest"
	if not tracks.has(track):
		return
	if track == current_track and _music.playing:
		return
	current_track = track
	if _fade and _fade.is_valid():
		_fade.kill()
	_music.stream = tracks[track]
	_music.volume_db = -40.0
	_music.play()
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(_music, "volume_db", MUSIC_DB, 0.8)


func stop_music() -> void:
	current_track = ""
	_music.stop()


func toggle_mute() -> void:
	muted = not muted
	_apply_mute()
	save_settings()
	mute_changed.emit(muted)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "muted", muted)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(SETTINGS_PATH)


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))


func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


## Geeft null terug (en dus stilte) als het bestand ontbreekt of nog niet is geïmporteerd.
func _load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("Geluid niet gevonden: %s (open het project eenmaal in Godot of draai --import)" % path)
	return null
