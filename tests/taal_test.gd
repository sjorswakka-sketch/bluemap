extends SceneTree
## Talen: de taalkeuze (autoload Lang), het spel in het Engels en de dekking van de vertaling (translations/en.po).
##
##   sh tools/run_tests.sh /pad/naar/godot      (of: BLUEMAP_LANG=nl godot --headless --fixed-fps 60 --path . -s tests/taal_test.gd)
##
## (a) Taalkeuze: de regels bij het starten, opslaan naast de instellingen van Sound, het signaal, en de taalknop op
##     het titelscherm en in het pauzemenu (ook met een controller), waarna alle tekst meteen meeverandert.
## (b) Engels in het spel: met een kleine test-vertaling (hieronder, TEST_PO) staan een gesprek, een melding met %s,
##     een voorwerpnaam, een opdrachttekst met {teken}, de prestatiemelding en het game-over-scherm in het Engels.
## (c) Dekking: elke tekst die de extractie vindt (tools/i18n_extract.gd) staat in en.po, elke tekst heeft een
##     (niet-lege, niet-fuzzy) Engelse vertaling, en elke vertaling heeft dezelfde plaatsaanduidingen als de brontekst.
##     Een ontbrekende vertaling is dus een fout. Alleen met I18N_ALLOW_MISSING=1 is dat even toegestaan (handig
##     tijdens het vertalen van nieuwe tekst). Fouten in plaatsaanduidingen, teksten die niet in en.po staan en
##     verouderde teksten in en.po zijn altijd fout, ook met die vlag.

const Items := preload("res://scripts/data/items.gd")
const Dialogue := preload("res://scripts/data/dialogue.gd")
const Achievements := preload("res://scripts/data/achievements.gd")

const PO_PATH := "res://translations/en.po"
const TEST_PO_PATH := "user://taal_test_en.po"
## De test-vertaling (Engels) voor (a) en (b). "Doorgaan" wordt hier expres "Nieuw spel": wordt tekst dubbel vertaald,
## dan zou die knop "New game" laten zien.
const TEST_PO := """msgid ""
msgstr ""
"Language: en\\n"
"Plural-Forms: nplurals=2; plural=(n != 1);\\n"

msgid "Nieuw spel"
msgstr "New game"

msgid "Doorgaan"
msgstr "Nieuw spel"

msgid "Afsluiten"
msgstr "Quit"

msgid "Een kleine fantasy-quest"
msgstr "A small fantasy quest"

msgid "Pauze"
msgstr "Paused"

msgid "Verder spelen"
msgstr "Resume"

msgid "Muziek"
msgstr "Music"

msgid "Dageraadsdorp"
msgstr "Dawnhaven"

msgid "Dag"
msgstr "Day"

msgid "Oudste Bram"
msgstr "Elder Bram"

msgid "Hoe gaat het met de zoektocht? Je hebt {crystals} van de 3 kristallen."
msgstr "How is the quest going? You have {crystals} of the 3 crystals."

msgid "Ik help je!"
msgstr "I'll help you!"

msgid "Vind de drie kaartkristallen: in het Fluisterbos, de Vergeten Ruïne en de Echo-grot. ({crystals}/3)"
msgstr "Find the three map crystals: in the Whisperwood, the Forgotten Ruin and the Echo Cave. ({crystals}/3)"

msgid "De Blauwe Kaart"
msgstr "The Blue Map"

msgid "Nieuwe opdracht: %s"
msgstr "New quest: %s"

msgid "Gekregen: %s"
msgstr "Received: %s"

msgid "Helddrank"
msgstr "Hero potion"

msgid "Prestatie behaald!"
msgstr "Achievement unlocked!"

msgid "Eerste klap"
msgstr "First strike"

msgid "Voorwerpen"
msgstr "Items"

msgid "Verslagen door: %s"
msgstr "Defeated by: %s"

msgid "Kristalgolem"
msgstr "Crystal golem"

msgctxt "aanval"
msgid "klap"
msgstr "slam"

msgid "%s (%s)"
msgstr "%s (%s)"

msgid "Druk op %s om opnieuw te beginnen"
msgstr "Press %s to start over"

msgid "Druk op %s om verder te gaan vanaf je laatste opslag"
msgstr "Press %s to continue from your last save"

msgid "%s voor het menu"
msgstr "%s for the menu"

msgid "%d hartje"
msgid_plural "%d hartjes"
msgstr[0] "%d heart"
msgstr[1] "%d hearts"
"""

var failures := 0
var gs: Node
var lang: Node
var sound: Node
var Extract: GDScript
var MenuPages: GDScript
var world: Node2D
var test_translation: Translation
var project_translation: Translation # en.po zelf: tijdens (a) en (b) even weg, zodat alleen de test-vertaling telt
var user_backup := {} # opslag, prestaties en instellingen van de echte speler (als de test niet via run_tests.sh draait)


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures += 1


func info(label: String) -> void:
	print("  info ", label)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	root.push_input(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	root.push_input(up)


func press_pad(button: int) -> void:
	var down := InputEventJoypadButton.new()
	down.button_index = button
	down.pressed = true
	root.push_input(down)
	var up := InputEventJoypadButton.new()
	up.button_index = button
	up.pressed = false
	root.push_input(up)


func _initialize() -> void:
	_run.call_deferred()


func user_files() -> Array[String]:
	return [gs.SAVE_PATH, gs.META_PATH, lang.SETTINGS_PATH]


func back_up_user_files() -> void:
	for path: String in user_files():
		if FileAccess.file_exists(path):
			user_backup[path] = FileAccess.get_file_as_bytes(path)


func restore_user_files() -> void:
	for path: String in user_files():
		if user_backup.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(user_backup[path])
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func settings() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(lang.SETTINGS_PATH)
	return config


# --- (a) De taalkeuze -------------------------------------------------------------------------------------------

func test_startup_rules() -> void:
	print("Taal bij het starten")
	var env_before := OS.get_environment("BLUEMAP_LANG")
	if env_before == "nl":
		check(lang.locale == "nl" and TranslationServer.get_locale() == "nl", "met BLUEMAP_LANG=nl (zoals in run_tests.sh) start het spel in het Nederlands")
	else:
		info("BLUEMAP_LANG is niet nl (draai via tools/run_tests.sh); de begintaal is %s" % lang.locale)
	check(ProjectSettings.get_setting("internationalization/locale/fallback") == "nl", "terugvaltaal is Nederlands (anders toont Nederlands de Engelse tekst)")
	check(lang.supported("en_US") == "en" and lang.supported("EN") == "en" and lang.supported("nl-BE") == "nl" and lang.supported("de") == "", "taalcodes: en_US, EN en nl-BE worden en/nl, onbekende talen niet")
	check(lang.LANGUAGES.has("nl") and lang.LANGUAGES.has("en"), "Nederlands en Engels zijn de talen van het spel")

	lang.forget_choice()
	var os_rule := "nl" if OS.get_locale_language() == "nl" else "en"
	OS.set_environment("BLUEMAP_LANG", "en")
	check(lang.startup_locale() == "en", "zonder opgeslagen keuze: BLUEMAP_LANG=en geeft Engels")
	OS.set_environment("BLUEMAP_LANG", "nl")
	check(lang.startup_locale() == "nl", "zonder opgeslagen keuze: BLUEMAP_LANG=nl geeft Nederlands")
	OS.set_environment("BLUEMAP_LANG", "en_GB")
	check(lang.startup_locale() == "en", "BLUEMAP_LANG=en_GB geeft ook Engels")
	OS.unset_environment("BLUEMAP_LANG")
	check(lang.startup_locale() == os_rule, "zonder keuze en zonder BLUEMAP_LANG: de taal van het systeem (%s -> %s)" % [OS.get_locale_language(), os_rule])

	lang.set_language("en")
	OS.set_environment("BLUEMAP_LANG", "nl")
	check(settings().get_value("taal", "locale", "") == "en", "de keuze staat in user://settings.cfg ([taal] locale)")
	check(lang.startup_locale() == "en", "een opgeslagen keuze gaat voor BLUEMAP_LANG")
	lang.set_language("nl")
	check(lang.startup_locale() == "nl" and TranslationServer.get_locale() == "nl", "terug naar Nederlands (ook opgeslagen)")
	lang.forget_choice()
	check(not settings().has_section("taal"), "forget_choice() wist de keuze weer")
	if env_before == "":
		OS.unset_environment("BLUEMAP_LANG")
	else:
		OS.set_environment("BLUEMAP_LANG", env_before)


func test_signal_and_settings() -> void:
	print("Signaal en instellingen")
	var heard: Array[String] = []
	var listener := func(code: String) -> void: heard.append(code)
	lang.changed.connect(listener)
	lang.toggle()
	check(lang.locale == "en" and TranslationServer.get_locale() == "en" and heard == ["en"], "toggle(): Engels, met het signaal changed(\"en\")")
	lang.set_language("en")
	check(heard == ["en"], "dezelfde taal nog eens kiezen geeft geen signaal")
	lang.toggle()
	check(lang.locale == "nl" and heard == ["en", "nl"], "toggle() nog eens: terug naar Nederlands")
	lang.changed.disconnect(listener)

	# De taal en het geluid delen user://settings.cfg: de een mag de ander niet wissen.
	sound.save_settings()
	lang.set_language("en")
	var config := settings()
	check(config.has_section_key("audio", "music") and config.get_value("taal", "locale", "") == "en", "de taal staat naast de instellingen van het geluid")
	sound.save_settings()
	check(settings().get_value("taal", "locale", "") == "en", "het geluid opslaan wist de taal niet")
	lang.set_language("nl")
	check(lang.button_text() == "Taal: Nederlands", "de taalknop in het Nederlands: \"Taal: Nederlands\"")
	lang.set_language("en", false)
	check(lang.button_text() == "Language: English", "de taalknop in het Engels: \"Language: English\"")
	lang.set_language("nl", false)


func test_title_screen() -> void:
	print("Titelscherm: de taalknop")
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await frames(3)
	var button: Button = title.language_button
	check(button != null and button.text == "Taal: Nederlands", "rechtsboven staat \"Taal: Nederlands\"")
	check(title.start_button.text == "Nieuw spel" and title.continue_button.text == "Doorgaan", "het menu is Nederlands")
	var top: Button = title.start_button if title.continue_button.disabled else title.continue_button
	check(top.get_node(top.focus_neighbor_top) == button and button.get_node(button.focus_neighbor_bottom) == top, "met omhoog/omlaag kom je bij de taalknop en terug")
	check(title.quit_button.get_node(title.quit_button.focus_neighbor_bottom) == button, "omlaag vanaf Afsluiten gaat ook naar de taalknop")
	button.grab_focus()
	press_pad(JOY_BUTTON_A)
	await frames(2)
	check(lang.locale == "en" and button.text == "Language: English", "één druk op A (controller) wisselt naar Engels")
	check(title.start_button.text == "New game" and title.subtitle_label.text == "A small fantasy quest" and title.quit_button.text == "Quit", "de tekst op het titelscherm verandert meteen mee")
	check(title.continue_button.text == "Nieuw spel", "niets wordt dubbel vertaald (Doorgaan -> \"Nieuw spel\" blijft zo staan)")
	check(button.has_focus(), "de taalknop houdt de focus: nog een druk wisselt weer terug")
	press("ui_accept")
	await frames(2)
	check(lang.locale == "nl" and button.text == "Taal: Nederlands" and title.start_button.text == "Nieuw spel", "Enter wisselt terug naar Nederlands")
	check(settings().get_value("taal", "locale", "") == "nl", "de keuze is opgeslagen")
	title.queue_free()
	await frames(2)


# --- (b) Engels in het spel ------------------------------------------------------------------------------------------

func start_world() -> void:
	gs.new_game()
	gs.in_game = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)


func stop_world() -> void:
	if is_instance_valid(world):
		world.queue_free()
	await frames(3)
	gs.new_game()


func test_pause_menu() -> void:
	print("Pauzemenu: de taalknop en de HUD erachter")
	await start_world()
	gs.start_quest("main")
	gs.day_time = 0.3
	await frames(2)
	var hud: Node = world.hud
	var pause: Node = world.pause_menu
	check(hud.tracker.text.begins_with("Vind de drie kaartkristallen") and hud.banner.text == "Dageraadsdorp", "in het Nederlands: opdracht en gebiedsnaam")
	pause.toggle()
	await frames(2)
	check(pause.open and pause.language_button.text == "Taal: Nederlands" and pause.title_label.text == "Pauze", "het pauzemenu heeft een taalknop")
	pause.language_button.grab_focus()
	press_pad(JOY_BUTTON_A)
	await frames(2)
	check(lang.locale == "en" and pause.language_button.text == "Language: English", "één druk op A wisselt naar Engels")
	check(pause.title_label.text == "Paused" and pause.resume_button.text == "Resume" and pause.music_label.text == "Music", "het pauzemenu staat meteen in het Engels")
	check(hud.tracker.text == "Find the three map crystals: in the Whisperwood, the Forgotten Ruin and the Echo Cave. (0/3)", "de opdracht in de HUD erachter ook, met het teken ingevuld")
	check(hud.banner.text == "Dawnhaven", "de gebiedsnaam die nog in beeld is ook")
	check(hud._clock_label() == "Day", "en het dagdeel bij de klok")
	check(pause.open and gs.ui_owners.has("pause"), "het spel blijft gepauzeerd")
	press_pad(JOY_BUTTON_A)
	await frames(2)
	check(lang.locale == "nl" and pause.title_label.text == "Pauze" and hud.tracker.text.begins_with("Vind de drie") and hud.banner.text == "Dageraadsdorp", "nog een druk: alles weer Nederlands")
	pause.toggle()
	await frames(2)
	await stop_world()


func test_english_in_game() -> void:
	print("Engels in het spel (met de test-vertaling)")
	await start_world()
	lang.set_language("en", false)
	var toasts: Array[String] = []
	var listener := func(text: String) -> void: toasts.append(text)
	gs.toast.connect(listener)

	# Een opdracht met {teken}, en de melding met %s.
	gs.start_quest("main")
	check(toasts.has("New quest: The Blue Map"), "melding met %%s: \"New quest: The Blue Map\" (%s)" % [toasts])
	check(gs.quest_text("main") == "Find the three map crystals: in the Whisperwood, the Forgotten Ruin and the Echo Cave. (0/3)", "opdrachttekst: eerst vertaald, dan {crystals} ingevuld")
	gs.give("potion", 1)
	check(toasts.has("Received: Hero potion"), "\"Gekregen: %s\" met een vertaalde voorwerpnaam")
	check(world.shop_ui._label({"item": "potion"}) == "Hero potion" and world.menu_ui.tab_titles()[0] == "Items", "voorwerpnaam in de winkel en het menu")
	check(MenuPages._damage_text({"damage": 1}) == "1 heart" and MenuPages._damage_text({"damage": 3}) == "3 hearts", "meervoud: 1 heart, 3 hearts")
	check(tr("Nieuw spel") == "New game" and tr("Deze tekst bestaat niet") == "Deze tekst bestaat niet", "een tekst zonder vertaling blijft Nederlands")

	# Een gesprek: spreker, regel (met {teken}) en keuzes.
	gs.start_dialogue("bram_progress")
	await frames(3)
	var box: Node = world.dialogue
	check(box.speaker_label.text == "Elder Bram" and box.text_label.text == "How is the quest going? You have 0 of the 3 crystals.", "gesprek: spreker en regel in het Engels (%s: %s)" % [box.speaker_label.text, box.text_label.text])
	box._close()
	gs.start_dialogue("bram_intro2")
	await frames(2)
	box._finish_node() # meteen naar de keuzes
	await frames(1)
	check(not box.buttons.is_empty() and box.buttons[0].text == "I'll help you!", "keuzes in het Engels")
	box._close()
	await frames(2)

	# De prestatiemelding.
	gs.achievements.erase("first_blood")
	gs.achievement_queue.clear()
	gs.unlock_achievement("first_blood")
	world.hud.banner_time = 0.0
	var banner: Node = world.hud.achievement_banner
	for i in 30:
		await process_frame
		if banner.is_showing():
			break
	check(banner.is_showing() and banner.name_label.text == "First strike" and banner.heading.text == "Achievement unlocked!", "de prestatiemelding in het Engels (%s)" % banner.name_label.text)

	# Het game-over-scherm, met de naam van de vijand en zijn aanval.
	world.player.invuln = 0.0
	world.player.hurt(world.player.global_position, 99, "Kristalgolem (klap)")
	await frames(3)
	var sub: String = world.hud.overlay_sub.text
	check(world.hud.overlay.visible and sub.begins_with("Defeated by: Crystal golem (slam)\nPress " + root.get_node("Controls").action_label("restart")), "game over: \"Defeated by: Crystal golem (slam)\" (%s)" % sub.replace("\n", " | "))
	lang.set_language("nl", false)
	await frames(1)
	check(world.hud.overlay_sub.text.begins_with("Verslagen door: Kristalgolem (klap)\nDruk op " + root.get_node("Controls").action_label("restart")), "en terug in het Nederlands: \"Verslagen door: Kristalgolem (klap)\"")
	gs.toast.disconnect(listener)
	gs.ended = false
	await stop_world()


# --- (c) Dekking ----------------------------------------------------------------------------------------------

func test_coverage() -> void:
	print("Dekking van de vertaling (translations/en.po)")
	var translations: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	check(PO_PATH in translations, "en.po is aangemeld in project.godot")
	var loaded: Translation = load(PO_PATH)
	check(loaded != null and loaded.locale == "en", "Godot leest en.po als Engelse vertaling")

	var found: Dictionary = Extract.collect()
	check(found["errors"].is_empty(), "de extractie geeft geen fouten %s" % [found["errors"]])
	check(found["unclaimed"].is_empty(), "alle tekst in de data wordt gevonden %s" % [found["unclaimed"].slice(0, 5)])
	var entries: Array = found["entries"]
	check(entries.size() > 500, "de extractie vindt de teksten van het spel (%d)" % entries.size())

	var po := {}
	for entry: Dictionary in Extract.read_po(PO_PATH):
		po[entry["ctx"] + "\u0004" + entry["msgid"]] = entry
	var not_in_po: Array[String] = []
	var wrong_plural: Array[String] = []
	var wanted := {}
	for entry: Dictionary in entries:
		var key: String = entry["ctx"] + "\u0004" + entry["msgid"]
		wanted[key] = true
		if not po.has(key):
			not_in_po.append(entry["msgid"])
		elif po[key]["plural"] != entry["plural"]:
			wrong_plural.append(entry["msgid"])
	var stale: Array[String] = []
	for key: String in po:
		if not wanted.has(key):
			stale.append(po[key]["msgid"])
	check(not_in_po.is_empty(), "elke tekst staat in en.po (anders: python3 tools/i18n.py extract) %s" % [not_in_po.slice(0, 5)])
	check(stale.is_empty(), "en.po heeft geen verouderde teksten (python3 tools/i18n.py extract haalt ze weg) %s" % [stale.slice(0, 5)])
	check(wrong_plural.is_empty(), "meervouden in en.po kloppen met de code %s" % [wrong_plural.slice(0, 5)])

	var translated := 0
	var missing: Array[String] = []
	var bad: Array[String] = []
	var runtime_bad: Array[String] = []
	TranslationServer.set_locale("en")
	for key: String in po:
		var entry: Dictionary = po[key]
		var forms: Array = entry["forms"]
		var complete: bool = not entry["fuzzy"] and not forms.is_empty()
		for i in forms.size():
			if forms[i] == "":
				complete = false
				continue
			var source: String = entry["plural"] if i > 0 and entry["plural"] != "" else entry["msgid"]
			var problem: String = Extract.placeholder_problem(source, forms[i])
			if problem != "":
				bad.append("\"%s\": %s" % [entry["msgid"], problem])
		if entry["plural"] != "" and forms.size() < 2:
			complete = false
		if complete:
			if wanted.has(key):
				translated += 1
			# Wat Godot er in het spel van maakt, moet de vertaling zijn.
			var shown: String
			if entry["plural"] == "":
				shown = TranslationServer.translate(entry["msgid"], entry["ctx"])
			else:
				shown = TranslationServer.translate_plural(entry["msgid"], entry["plural"], 1, entry["ctx"])
			if shown != forms[0]:
				runtime_bad.append(entry["msgid"])
		elif wanted.has(key):
			missing.append(entry["msgid"])
	TranslationServer.set_locale(lang.locale)
	check(bad.is_empty(), "elke vertaling heeft dezelfde plaatsaanduidingen ({teken}, %%s, %%d...) %s" % [bad.slice(0, 5)])
	check(runtime_bad.is_empty(), "het spel toont de vertalingen uit en.po %s" % [runtime_bad.slice(0, 5)])

	# Streng: elke tekst moet vertaald zijn (ook een tekst die nog niet in en.po staat, telt als ontbrekend).
	var allow_missing := OS.get_environment("I18N_ALLOW_MISSING") == "1"
	var untranslated: Array = missing + not_in_po
	if untranslated.is_empty():
		check(translated == wanted.size(), "alle %d teksten hebben een Engelse vertaling" % wanted.size())
	elif allow_missing:
		info("I18N_ALLOW_MISSING=1: %d van de %d teksten hebben nog geen vertaling (geen fout)" % [untranslated.size(), wanted.size()])
	else:
		check(false, "elke tekst heeft een Engelse vertaling: %d van de %d ontbreken, bijvoorbeeld %s (zie python3 tools/i18n.py check; tijdens het vertalen: I18N_ALLOW_MISSING=1)" % [untranslated.size(), wanted.size(), untranslated.slice(0, 5)])


# --- Hulp -----------------------------------------------------------------------------------------------------------

## De test-vertaling in plaats van en.po (die kan al vertalingen hebben die anders voorgaan).
func add_test_translation() -> void:
	project_translation = TranslationServer.get_translation_object("en")
	if project_translation != null and project_translation.resource_path == PO_PATH:
		TranslationServer.remove_translation(project_translation)
	else:
		project_translation = null
	var file := FileAccess.open(TEST_PO_PATH, FileAccess.WRITE)
	file.store_string(TEST_PO)
	file.close()
	test_translation = ResourceLoader.load(TEST_PO_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	TranslationServer.add_translation(test_translation)
	check(TranslationServer.get_translation_object("en") == test_translation, "de test-vertaling staat klaar (en.po is even uit)")


func remove_test_translation() -> void:
	if test_translation != null:
		TranslationServer.remove_translation(test_translation)
	if project_translation != null:
		TranslationServer.add_translation(project_translation)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PO_PATH))


func _run() -> void:
	gs = root.get_node("GameState")
	lang = root.get_node("Lang")
	sound = root.get_node("Sound")
	Extract = load("res://tools/i18n_extract.gd")
	MenuPages = load("res://scripts/ui/menu_pages.gd")
	back_up_user_files()
	test_startup_rules()
	test_signal_and_settings()
	test_coverage() # met alleen en.po, zonder test-vertaling
	add_test_translation()
	await test_title_screen()
	await test_pause_menu()
	await test_english_in_game()
	remove_test_translation()
	lang.set_language("nl", false)
	restore_user_files()
	gs.meta_achievements = {}
	gs._load_meta()
	gs.new_game()

	print("")
	if failures == 0:
		print("TAAL TEST OK")
		quit(0)
	else:
		print("TAAL TEST: %d fout(en)" % failures)
		quit(1)
