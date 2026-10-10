extends Node
## Autoload "Sound": geluidseffecten, muziek en de geluid-aan/uit-schakelaar (toets M).

signal mute_changed(muted: bool)

const SOUNDS := ["swing", "hit", "die", "hurt", "coin", "heart", "crystal", "select", "victory", "gameover"]
const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_DB := -9.0
const POOL_SIZE := 8

var streams := {}
var muted := false

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # ook tijdens de pauze doorspelen

	for sound_name: String in SOUNDS:
		var stream := _load("res://assets/audio/%s.wav" % sound_name)
		if stream:
			streams[sound_name] = stream
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)

	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	var music := _load("res://assets/audio/music.wav")
	if music is AudioStreamWAV:
		var wav: AudioStreamWAV = music
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		@warning_ignore("integer_division")
		wav.loop_end = wav.data.size() / 2 # 16-bit mono: 2 bytes per sample
	_music.stream = music
	add_child(_music)

	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		muted = config.get_value("audio", "muted", false)
	_apply_mute()

	# Een eigen jingle bij winst en verlies.
	GameState.victory.connect(func() -> void:
		stop_music()
		play("victory"))
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


func play_music() -> void:
	if _music.stream and not _music.playing:
		_music.play()


func stop_music() -> void:
	_music.stop()


func toggle_mute() -> void:
	muted = not muted
	_apply_mute()
	var config := ConfigFile.new()
	config.set_value("audio", "muted", muted)
	config.save(SETTINGS_PATH)
	mute_changed.emit(muted)


func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


## Geeft null terug (en dus stilte) als het bestand ontbreekt of nog niet is geïmporteerd.
func _load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("Geluid niet gevonden: %s (open het project eenmaal in Godot of draai --import)" % path)
	return null
