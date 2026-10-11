extends RefCounted
## De klok van de wereld: dag en nacht, en het weer dat daarbij hoort.
##
## `GameState.day_time` loopt van 0 (zonsopgang) tot 1 en begint dan weer van voren. Een hele dag duurt
## DAY_LENGTH seconden speeltijd. Alles hier is een gewone rekenfunctie, zodat het makkelijk te testen is.

const DAY_LENGTH := 480.0 # seconden speeltijd voor een hele dag (8 minuten)
const START := 0.15 # een nieuw spel begint 's ochtends
const MORNING := 0.08 # zo laat is het als je wakker wordt na het slapen

## De kleur van de wereld op een tijdstip: [tijd, kleur, kunstlicht]. Tussen twee regels loopt alles vloeiend over.
## `kunstlicht` is hoeveel fakkels en lantaarns nodig zijn: 0 overdag, 1 midden in de nacht.
## De eerste en de laatste regel zijn gelijk, zodat de dag mooi rondloopt.
const KEYS: Array = [
	[0.00, Color(1.00, 0.82, 0.72), 0.35], # zonsopgang
	[0.07, Color(1.00, 0.92, 0.82), 0.05], # ochtend: warm
	[0.17, Color(1.00, 1.00, 1.00), 0.0], # dag: gewoon
	[0.52, Color(1.00, 1.00, 1.00), 0.0],
	[0.60, Color(1.00, 0.78, 0.56), 0.15], # avond: oranje
	[0.68, Color(0.62, 0.46, 0.62), 0.6], # schemering
	[0.76, Color(0.30, 0.36, 0.66), 1.0], # nacht: blauw en donker, maar goed te zien
	[0.90, Color(0.30, 0.36, 0.66), 1.0],
	[0.96, Color(0.58, 0.48, 0.70), 0.7], # vlak voor zonsopgang
	[1.00, Color(1.00, 0.82, 0.72), 0.35],
]

## Het weer wisselt per vakje van een zesde dag (80 seconden), op kaarten met "weather": "random".
const WEATHER_SLOTS := 6
const RAIN_CHANCE := 33 # procent van de vakjes met regen
const RAIN_TINT := Color(0.80, 0.86, 0.95) # het wordt iets donkerder en grijzer als het regent


## Houdt een tijdstip tussen 0 en 1.
static func wrap_time(t: float) -> float:
	return fposmod(t, 1.0)


## De kleur waarmee het hele buitenbeeld wordt ingekleurd (CanvasModulate).
static func tint_at(t: float) -> Color:
	var pair := _segment(t)
	return (pair[0][1] as Color).lerp(pair[1][1], pair[2])


## Hoeveel kunstlicht nodig is: 0 overdag, 1 midden in de nacht.
static func night_at(t: float) -> float:
	var pair := _segment(t)
	return lerpf(pair[0][2], pair[1][2], pair[2])


## Welk deel van de dag het is: "ochtend", "dag", "avond" of "nacht".
static func phase_at(t: float) -> String:
	t = wrap_time(t)
	if t < 0.17 or t >= 0.95:
		return "ochtend"
	if t < 0.52:
		return "dag"
	if t < 0.72:
		return "avond"
	return "nacht"


## Het vakje in de zon/maan-plaat (assets/wereld_ui.png): 0 zon, 1 lage zon, 2 maan.
static func icon_frame(t: float) -> int:
	match phase_at(t):
		"dag":
			return 0
		"nacht":
			return 2
	return 1


## Twee naburige regels van KEYS en hoe ver we ertussen zijn (zacht afgerond).
static func _segment(t: float) -> Array:
	t = wrap_time(t)
	for i in range(1, KEYS.size()):
		var next: Array = KEYS[i]
		if t <= next[0]:
			var prev: Array = KEYS[i - 1]
			var u := inverse_lerp(prev[0], next[0], t)
			return [prev, next, u * u * (3.0 - 2.0 * u)]
	return [KEYS[KEYS.size() - 2], KEYS[KEYS.size() - 1], 1.0]


# --- Weer ---------------------------------------------------------------------------------------

## Regent het op dit moment? `weather` komt uit de kaart: "rain" (altijd), "random" (wisselt met de klok) of leeg.
static func raining(weather: String, day_count: int, t: float) -> bool:
	match weather:
		"rain":
			return true
		"random":
			var slot := mini(int(wrap_time(t) * WEATHER_SLOTS), WEATHER_SLOTS - 1)
			if day_count == 0 and slot == 0:
				return false # de eerste minuten van een nieuw spel zijn droog
			return _hash(day_count * WEATHER_SLOTS + slot) % 100 < RAIN_CHANCE
	return false


## Een vaste "willekeurige" waarde voor een vakje, zodat het weer bij elke dag hetzelfde is als je opnieuw laadt.
static func _hash(n: int) -> int:
	var h := (n * 73856093) ^ ((n + 17) * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## De tint van de lucht bij regen (0 = droog, 1 = volop regen).
static func rain_tint(level: float) -> Color:
	return Color.WHITE.lerp(RAIN_TINT, clampf(level, 0.0, 1.0))


static func phase_label(t: float) -> String:
	return phase_at(t).capitalize()
