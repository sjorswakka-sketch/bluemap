extends RefCounted
## Tijdelijke uithouding. GameState bewaart dit object zodat een kaartwissel het niet bijvult.

const MAX_STAMINA := 100.0
const SPRINT_MULTIPLIER := 1.5
const DRAIN_PER_SECOND := 20.0
const REGEN_PER_SECOND := 25.0
const REGEN_DELAY := 0.8
const RECOVERY_THRESHOLD := 25.0

var stamina := MAX_STAMINA
var regen_delay := 0.0
var exhausted := false


func reset() -> void:
	stamina = MAX_STAMINA
	regen_delay = 0.0
	exhausted = false


func can_sprint() -> bool:
	return not exhausted and stamina > 0.001


## Een gemaakt drankje mag energie herstellen, maar wordt niet verspild bij een volle balk.
func restore(amount: float) -> bool:
	if amount <= 0.0 or stamina >= MAX_STAMINA:
		return false
	stamina = minf(stamina + amount, MAX_STAMINA)
	if stamina >= RECOVERY_THRESHOLD:
		exhausted = false
	return true


## Verbruik nooit meer sprinttijd dan er energie over is, ook bij een lange physics-stap.
func sprint_multiplier(delta: float) -> float:
	if delta <= 0.0 or not can_sprint():
		return 1.0
	var fraction := minf(stamina / (DRAIN_PER_SECOND * delta), 1.0)
	return 1.0 + (SPRINT_MULTIPLIER - 1.0) * fraction


## Alleen aanroepen tijdens actief spelen. sprinting betekent dat je echt vooruit kwam.
func advance(delta: float, sprinting: bool) -> void:
	if delta <= 0.0:
		return
	if sprinting and can_sprint():
		stamina = maxf(stamina - DRAIN_PER_SECOND * delta, 0.0)
		regen_delay = REGEN_DELAY
		if stamina <= 0.001:
			stamina = 0.0
			exhausted = true
		return
	var recovery_time := maxf(delta - regen_delay, 0.0)
	regen_delay = maxf(regen_delay - delta, 0.0)
	stamina = minf(stamina + REGEN_PER_SECOND * recovery_time, MAX_STAMINA)
	if exhausted and stamina >= RECOVERY_THRESHOLD:
		exhausted = false
