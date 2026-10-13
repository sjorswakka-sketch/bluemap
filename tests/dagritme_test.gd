extends SceneTree
## Test van het dagritme-geluid (spoor "amb"): de zestien sfeerlussen, de klimaat- en dagdeelmapping,
## en de sfeerspeler van de atmosfeer (wisselen tussen dagdelen, kaartklimaten en stilte binnen).
##
##   sh tools/run_tests.sh /pad/naar/godot      (alle tests), of alleen deze:
##   XDG_DATA_HOME=.testdata godot --headless --fixed-fps 60 --path . -s tests/dagritme_test.gd
##
## Zonder XDG_DATA_HOME schrijft de test in de echte opslagmap van het spel (en overschrijft hij je opgeslagen spel).

const Daynight := preload("res://scripts/core/daynight.gd")

const CLIMATES := ["bos", "sneeuw", "dorst", "moeras"]
const PHASES := ["ochtend", "dag", "avond", "nacht"]
## Een klokstand midden in elk dagdeel (zie Daynight.phase_at).
const PHASE_TIMES := {"ochtend": 0.05, "dag": 0.35, "avond": 0.6, "nacht": 0.85}
## Wachttijd voor een sfeerovergang: AMB_FADE (2 s) bij 60 fps, plus marge.
const FADE_FRAMES := 160

var failures := 0
var gs: Node
var world: Node2D


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	gs = root.get_node("GameState")
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await frames(3)

	test_data()
	await test_world()

	world.queue_free()
	await frames(2)
	print("DAGRITME OK" if failures == 0 else "DAGRITME FAILED: %d" % failures)
	quit(1 if failures else 0)


# --- Deel 1: gegevens -----------------------------------------------------------------------------------

func test_data() -> void:
	print("Gegevens van het dagritme-geluid")
	var sound := root.get_node("Sound")
	for climate: String in CLIMATES:
		for phase: String in PHASES:
			var key := "amb_%s_%s" % [climate, phase]
			check(FileAccess.file_exists("res://assets/audio/%s.wav" % key), "sfeerlus bestaat: " + key)
			check(sound.streams.has(key), "sfeerlus geladen: " + key)

	check(Daynight.climate("snow") == "sneeuw" and Daynight.climate("heat") == "dorst", "sneeuw- en hittekaarten krijgen hun eigen klimaat")
	check(Daynight.climate("swamp") == "moeras", "het Kruipmoeras krijgt het moerasklimaat")
	check(Daynight.climate("random") == "bos" and Daynight.climate("") == "bos" and Daynight.climate("rain") == "bos", "gematigde kaarten krijgen het bosklimaat")
	for phase: String in PHASES:
		var t: float = PHASE_TIMES[phase]
		check(Daynight.phase_at(t) == phase, "de klokstand van de test zit midden in de fase " + phase)
		check(Daynight.ambience("snow", t) == "amb_sneeuw_" + phase, "het IJsdal klinkt in de %s als sneeuw" % phase)
		check(Daynight.ambience("swamp", t) == "amb_moeras_" + phase, "het Kruipmoeras klinkt in de %s als moeras" % phase)


# --- Deel 2: de wereld zelf -----------------------------------------------------------------------------

func test_world() -> void:
	print("De sfeerspeler in de wereld")
	gs.new_game()
	gs.in_game = true
	world.load_map("forest", "start")
	await frames(5)
	world.player.invuln = 999.0
	var amb: Node = world.atmosphere

	# Ochtend in het bos: de bosochtend-lus klinkt meteen.
	gs.day_time = PHASE_TIMES["ochtend"]
	await frames(5)
	check(amb.amb_key == "amb_bos_ochtend", "het bos klinkt 's ochtends als amb_bos_ochtend")
	check(amb.amb_audio.playing and amb.amb_level > 0.9, "de sfeerlus speelt op volle sterkte")

	# Naar de nacht: eerst een overgang, dan klinkt de nachtlus.
	gs.day_time = PHASE_TIMES["nacht"]
	await frames(10)
	check(amb.amb_key == "amb_bos_ochtend" and amb.amb_level < 1.0, "de ochtend fadet eerst zachtjes uit")
	await frames(FADE_FRAMES)
	check(amb.amb_key == "amb_bos_nacht", "na de overgang klinkt de bosnacht")
	await frames(FADE_FRAMES)
	check(amb.amb_level > 0.9, "de nachtlus is weer op volle sterkte")

	# Een koude kaart klinkt als sneeuw, een hete als dorst, een drassige als moeras.
	world.load_map("ijsdal", "start")
	await frames(5)
	check(amb.amb_key == "amb_sneeuw_nacht", "het IJsdal klinkt als sneeuw (zelfde dagdeel)")
	world.load_map("dorstvallei", "start")
	await frames(5)
	check(amb.amb_key == "amb_dorst_nacht", "de Dorstvallei klinkt als dorst (zelfde dagdeel)")
	world.load_map("kruipmoeras", "start")
	await frames(5)
	check(amb.amb_key == "amb_moeras_nacht", "het Kruipmoeras klinkt als moeras (zelfde dagdeel)")

	# Binnen is het stil.
	world.load_map("cave", "start")
	await frames(5)
	check(amb.amb_key == "" and not amb.amb_audio.playing, "binnen klinkt er geen sfeerlus")
