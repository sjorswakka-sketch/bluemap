extends Node
## Autoload "Lang": de taal van het spel. Nederlands is de brontaal; vertalingen staan in translations/ (zie de README,
## sectie "Talen", en tools/i18n.py).
##
## Alle tekst staat in het Nederlands in de code en de data, en gaat pas door de vertaling op het moment dat hij in beeld
## komt, precies één keer:
##   - tekst in code:  tr("...") in een node (of een ander object), tr_n("1 ding", "%d dingen", n) voor meervouden.
##     In een statische functie of een content-module (die de naam Lang niet mag gebruiken, zie content.gd):
##     TranslationServer.translate("...") en TranslationServer.translate_plural("...", "...", n).
##     Altijd eerst het sjabloon vertalen en dan pas invullen: tr("Gekregen: %s") % naam, nooit tr("Gekregen: " + naam).
##   - tekst uit de data (gesprekken, voorwerpen, kaarten...): het scherm dat hem toont doet tr(tekst), en vult daarna
##     pas de {tekens} in (GameState.fmt).
## Godot vertaalt de tekst van Labels en Buttons normaal ook zelf. Dat zetten we hier uit (anders wordt tekst dubbel
## vertaald): wie een Label of Button vult, geeft hem tekst die al vertaald is.
##
## De taal wordt bij het starten gekozen: de opgeslagen keuze (user://settings.cfg, sectie [taal], naast die van Sound),
## anders de omgevingsvariabele BLUEMAP_LANG (de tests zetten die op "nl"), anders Nederlands als het systeem Nederlands
## is en anders Engels. De knop "Taal: Nederlands" op het titelscherm en in het pauzemenu wisselt (toggle()).

signal changed(locale: String)

const SETTINGS_PATH := "user://settings.cfg" # hetzelfde bestand als Sound (die gebruikt de sectie "audio")
const SECTION := "taal"
const KEY := "locale"
const ENV_VAR := "BLUEMAP_LANG"
const SOURCE_LOCALE := "nl" # de brontaal: de tekst in de code en de data
## De talen van het spel, in de volgorde van de taalknop. De tekst op de knop staat in die taal zelf en gaat dus niet
## door de vertaling: zo vindt iedereen zijn eigen taal terug, ook als hij de taal op het scherm niet kan lezen.
const LANGUAGES := {
	"nl": "Taal: Nederlands",
	"en": "Language: English",
}

var locale := SOURCE_LOCALE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	locale = startup_locale()
	TranslationServer.set_locale(locale)


## De taal bij het starten: opgeslagen keuze, dan BLUEMAP_LANG, dan de taal van het systeem.
static func startup_locale() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved := supported(str(config.get_value(SECTION, KEY, "")))
		if saved != "":
			return saved
	var from_env := OS.get_environment(ENV_VAR).strip_edges()
	if from_env != "":
		var code := supported(from_env)
		if code != "":
			return code
		push_warning("%s=%s: die taal kent het spel niet (wel: %s)" % [ENV_VAR, from_env, ", ".join(LANGUAGES.keys())])
	return "nl" if OS.get_locale_language() == "nl" else "en"


## De taalcode als het spel die taal kent ("en_US" en "EN" worden "en"), anders "".
static func supported(code: String) -> String:
	var language := code.strip_edges().to_lower().replace("-", "_").get_slice("_", 0)
	return language if LANGUAGES.has(language) else ""


## Kiest een taal, slaat de keuze op en laat alle schermen die luisteren (changed) zich bijwerken.
func set_language(code: String, save := true) -> void:
	var language := supported(code)
	if language == "":
		push_warning("Onbekende taal: %s" % code)
		return
	var different := language != locale
	locale = language
	TranslationServer.set_locale(language)
	if save:
		save_choice()
	if different:
		changed.emit(language)


## De volgende taal in de lijst (de taalknop).
func toggle() -> void:
	var codes: Array = LANGUAGES.keys()
	set_language(codes[(codes.find(locale) + 1) % codes.size()])


## De tekst op de taalknop, in de taal zelf: "Taal: Nederlands" of "Language: English".
func button_text() -> String:
	return LANGUAGES.get(locale, LANGUAGES[SOURCE_LOCALE])


## Bewaart de gekozen taal in user://settings.cfg zonder de instellingen van Sound te wissen.
func save_choice() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # bestaat het nog niet, dan begint hij leeg
	config.set_value(SECTION, KEY, locale)
	config.save(SETTINGS_PATH)


## Vergeet de opgeslagen keuze (dan beslist BLUEMAP_LANG of het systeem weer bij de volgende start).
func forget_choice() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK and config.has_section(SECTION):
		config.erase_section(SECTION)
		config.save(SETTINGS_PATH)
