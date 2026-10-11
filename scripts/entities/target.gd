extends Node2D
## Een doelwit. Raakt een pijl van de speler het, dan licht het op en gebeurt er iets: de vlag `sets` gaat aan
## (blijvend, ook na opslaan) en de acties in `do` worden uitgevoerd. Het zwaard doet er niets mee.
##
##   {"type": "target", "pos": [27, 30], "sets": "boog_bos_a", "do": [["boog_progress", "boog_bos_a", "boog_bos_b"]]}
##
## Een poortje opent ermee via `block_if`: [["no_flag", "boog_bos_a"]] voor een doelwit, of
## [["boog_missing", "boog_bos_a", "boog_bos_b"]] (de poort blijft dicht zolang er nog een ontbreekt) voor meer doelwitten.
##
## Zonder `sets` is een treffer tijdelijk. Zo werken de doelwitten van de schietbaan (`range`: de naam van de baan),
## die zet ze na een poging zelf weer overeind.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")

const HIT_RADIUS := 13.0 # de grootte van het bord (een tegel is 32 breed)
const BOARD_OFFSET := Vector2(0, -3) # het midden van het bord ligt iets boven het midden van het plaatje
const GOLD := Color(1.0, 0.85, 0.35)
const WOBBLE_TIME := 0.5

var world: Node
var obj: Dictionary = {}
var key := ""
var sets := ""
var range_id := ""
var hit := false # tijdelijke treffer (alleen zonder `sets`)
var hit_age := 0.0 # hoe lang geleden het doelwit geraakt is
var t := randf() * TAU


func _ready() -> void:
	add_to_group("boog_target")
	sets = obj.get("sets", "")
	range_id = obj.get("range", "")
	if is_hit():
		hit_age = WOBBLE_TIME # al raak (uit een opslag): niet opnieuw wiebelen bij het binnenkomen


func _process(delta: float) -> void:
	t += delta
	if is_hit():
		hit_age += delta
	queue_redraw()


func is_hit() -> bool:
	return hit or (sets != "" and GameState.flag(sets))


## Haalt de treffer weg (de schietbaan zet het doelwit weer overeind).
func reset() -> void:
	hit = false
	hit_age = 0.0


func hit_center() -> Vector2:
	return global_position + BOARD_OFFSET


func hit_radius() -> float:
	return HIT_RADIUS


## Wordt aangeroepen door een pijl die het doelwit raakt.
func arrow_hit(_arrow: Node2D) -> void:
	if is_hit():
		Sound.play("hit", -12.0, 1.7) # een tikje op een bord dat al raak was
		return
	hit = true
	hit_age = 0.0
	if sets != "":
		GameState.set_flag(sets)
	Sound.play("boog_target")
	world.burst(hit_center(), GOLD, 12)
	world.ring(hit_center(), 26.0, GOLD)
	GameState.run_all(obj.get("do", []))


func _draw() -> void:
	var lit := is_hit()
	DrawUtil.ellipse(self, Vector2(0, 13), Vector2(10, 3.5), Color(0, 0, 0, 0.3))
	if lit:
		draw_circle(BOARD_OFFSET, 20.0 + sin(t * 3.0) * 1.5, Color(GOLD, 0.16))
	# Na een treffer wiebelt het bord even, om de voet heen.
	var wobble := 0.0
	if lit and hit_age < WOBBLE_TIME:
		wobble = sin(hit_age * 45.0) * 0.14 * (1.0 - hit_age / WOBBLE_TIME)
	draw_set_transform(Vector2(0, 14), wobble, Vector2.ONE)
	DrawUtil.sprite(self, Art.tex("target"), 1 if lit else 0, 0, Vector2(0, -14))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
