extends RefCounted
## Alles over het vissen in het Zilvermeer: welke vis je kunt vangen, hoe lastig hij binnen te halen is,
## en wat het dorp ervoor betaalt. Zonder afhankelijkheden, zodat het visspel en de test het allebei kunnen gebruiken.

## Vissen die je op elke visplek kunt vangen.
##   weight / deep_weight = kans (gewicht) op een gewone en op een diepe visplek
##   sell      = wat Joris en Mila ervoor betalen
##   fill_time = seconden die het kost om de vis binnen te halen als hij steeds in de groene zone zit
##   speed     = hoe wild hij zwemt (1 = rustig), zone = hoe groot de groene zone is (deel van de balk)
const CATCHES := {
	"meer_baars": {"weight": 60, "deep_weight": 42, "sell": 8, "fill_time": 8.0, "speed": 0.9, "zone": 0.36},
	"meer_snoek": {"weight": 30, "deep_weight": 40, "sell": 15, "fill_time": 9.0, "speed": 1.2, "zone": 0.32},
	"meer_laars": {"weight": 10, "deep_weight": 6, "sell": 1, "fill_time": 7.0, "speed": 0.6, "zone": 0.40},
}

## De Gouden Karper zwemt alleen in diep water (de verre steiger) en is het lastigst binnen te halen. Je vangt hem
## één keer, voor Joris: hij is niet te koop (zie golden_can_bite in meer_logic.gd).
const GOLDEN := "meer_gouden_karper"
const GOLDEN_STATS := {"fill_time": 9.5, "speed": 1.3, "zone": 0.30}
const GOLDEN_CHANCE := 0.04 # kans per vangst in diep water
const GOLDEN_PITY := 0.03 # erbij voor elke diepe vangst zonder karper, zodat het nooit eindeloos duurt
const GOLDEN_MAX_CHANCE := 0.5

## De eerste vissen die je verkoopt, brengen de volle prijs op; daarna zit het dorp vol vis en krijg je de helft
## (gemiddeld zo'n 5 munten per vangst). Zo blijft vissen een gezellig tijdverdrijf en geen geldmachine.
const FULL_PRICE_FISH := 8
const CAP_BONUS := 0.1 # de Visserspet: 10% extra, en altijd minstens 1 munt

const WAIT_MIN := 1.0 # seconden wachten op een beet
const WAIT_MAX := 3.0


## De vissen die je kunt verkopen, de duurste eerst.
static func fish_ids() -> Array[String]:
	return ["meer_snoek", "meer_baars", "meer_laars"]


static func stats(fish_id: String) -> Dictionary:
	return GOLDEN_STATS if fish_id == GOLDEN else CATCHES[fish_id]


static func golden_chance(pity: int) -> float:
	return minf(GOLDEN_CHANCE + GOLDEN_PITY * pity, GOLDEN_MAX_CHANCE)


## Welke vis bijt er? `pity` is het aantal diepe vangsten sinds de laatste Gouden Karper. Met `golden` = false
## bijt de Gouden Karper niet (Joris heeft hem al, of hij zit al in je tas).
static func roll(rng: RandomNumberGenerator, deep: bool, pity := 0, golden := true) -> String:
	if deep and golden and rng.randf() < golden_chance(pity):
		return GOLDEN
	var total := 0.0
	for fish_id: String in CATCHES:
		total += float(CATCHES[fish_id]["deep_weight" if deep else "weight"])
	var pick := rng.randf() * total
	for fish_id: String in CATCHES:
		pick -= float(CATCHES[fish_id]["deep_weight" if deep else "weight"])
		if pick < 0.0:
			return fish_id
	return "meer_baars"


## Wat de n-de verkochte vis oplevert (n telt vanaf 0): de volle prijs voor de eerste vissen, daarna de helft.
static func price(fish_id: String, nth: int, has_cap: bool) -> int:
	var value := float(CATCHES[fish_id]["sell"])
	if nth >= FULL_PRICE_FISH:
		value *= 0.5
	var coins := maxi(1, roundi(value))
	if has_cap:
		coins += maxi(1, roundi(coins * CAP_BONUS))
	return coins
