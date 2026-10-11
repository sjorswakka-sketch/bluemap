extends RefCounted
## Het binnenhalen van een vis (het laatste deel van het visspel), zonder tekenwerk zodat het te testen is.
##
## De balk loopt van 0 (onderaan) tot 1 (bovenaan). Jij bestuurt de groene zone met E: ingedrukt stijgt hij,
## losgelaten zakt hij. De vis zwemt zelf heen en weer. Zit hij in de zone, dan vult de voortgangsbalk;
## zit hij ernaast, dan loopt de balk langzaam leeg. Vol = gevangen, leeg = ontsnapt.
## Hoe langer het duurt, hoe moeier de vis: hij zwemt trager en trekt minder hard, zodat het nooit eindeloos duurt.

const START_PROGRESS := 0.3
const DRAIN_TIME := 14.0 # seconden om van vol tot leeg te lopen als de vis buiten de zone zit
const LIFT := 7.0 # versnelling omhoog met E ingedrukt (balklengtes per seconde per seconde)
const GRAVITY := 6.0 # versnelling omlaag als je loslaat
const DRAG := 7.0 # wrijving: de zone reageert snel en wordt nooit sneller dan 1 balklengte per seconde
const BOUNCE := 0.35 # hoeveel snelheid de zone terugkaatst tegen de rand
const FISH_SPEED := 0.4 # balklengtes per seconde van een rustige vis
const FISH_MARGIN := 0.08 # de vis blijft zo ver van de rand
const TIRE_TIME := 30.0 # na zoveel seconden is de vis zo moe als hij kan worden
const TIRED := 0.4 # een moeie vis zwemt en trekt nog maar zo hard (deel van zijn eigen kracht)

var rng: RandomNumberGenerator
var zone_size := 0.3
var zone_pos := 0.5 # midden van de zone
var zone_vel := 0.0
var fish_pos := 0.5
var fish_target := 0.5
var fish_speed := 1.0
var fill_time := 8.0
var progress := START_PROGRESS
var in_zone := false
var state := "bezig" # "bezig", "gevangen" of "ontsnapt"
var elapsed := 0.0
var _retarget_in := 0.0


## `params` heeft "zone", "speed" en "fill_time" (zie meer_vis.gd).
func _init(random: RandomNumberGenerator, params: Dictionary) -> void:
	rng = random
	zone_size = params["zone"]
	fish_speed = params["speed"]
	fill_time = params["fill_time"]
	fish_pos = rng.randf_range(0.25, 0.75)
	fish_target = fish_pos
	zone_pos = fish_pos # je begint met de vis in de zone


func update(delta: float, holding: bool) -> void:
	if state != "bezig":
		return
	elapsed += delta
	# De zone: E ingedrukt trekt omhoog, anders zakt hij.
	var accel := LIFT if holding else -GRAVITY
	zone_vel += (accel - zone_vel * DRAG) * delta
	zone_pos += zone_vel * delta
	var half := zone_size / 2.0
	if zone_pos < half:
		zone_pos = half
		zone_vel = absf(zone_vel) * BOUNCE
	elif zone_pos > 1.0 - half:
		zone_pos = 1.0 - half
		zone_vel = -absf(zone_vel) * BOUNCE
	# De vis zwemt naar een willekeurig punt en kiest na een tijdje een nieuw punt. Hoe langer het duurt, hoe moeier.
	var strength := lerpf(1.0, TIRED, minf(elapsed / TIRE_TIME, 1.0))
	_retarget_in -= delta
	if _retarget_in <= 0.0:
		_retarget_in = rng.randf_range(0.5, 1.4) / (fish_speed * strength)
		fish_target = rng.randf_range(FISH_MARGIN, 1.0 - FISH_MARGIN)
	fish_pos = move_toward(fish_pos, fish_target, FISH_SPEED * fish_speed * strength * delta)
	in_zone = absf(fish_pos - zone_pos) <= half
	progress += delta / fill_time if in_zone else -delta * strength / DRAIN_TIME
	if progress >= 1.0:
		progress = 1.0
		state = "gevangen"
	elif progress <= 0.0:
		progress = 0.0
		state = "ontsnapt"
