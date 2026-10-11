extends RefCounted
## Uitbreiding "vijanden": de Magiër en de Slijmspuwer. Het gedrag staat in scripts/entities/enemy.gd
## (behavior "mage" en "spitter"), de arcane bol in scripts/entities/projectile.gd.
##
## Extra velden naast die van scripts/data/enemies.gd:
##   desc  = korte beschrijving voor een toekomstig beestenboek
##   death_color = kleur van de wolk als hij verslagen is
##   hint  = tip die één keer verschijnt als je deze vijand voor het eerst tegenkomt (vlag vijanden_hint_<soort>)
##
## Magiër:       keep_distance = (te dichtbij, te ver weg) in pixels, teleport_every = seconden tussen twee teleports,
##               teleport_range = (dichtst, verst) van de speler, vanish_time / appear_time = hoe lang het rookwolkje blijft,
##               cast_time = de aanloop met oplichtende handen (raak je hem dan, dan mislukt de spreuk),
##               orb_speed = snelheid van de bol
## Slijmspuwer:  spit_range = binnen deze afstand spuugt hij, spit_every = seconden tussen twee beurten,
##               windup = de aanloop, fan / fan_spread / ball_speed = de waaier slijmballen (aantal, hoek tussen twee ballen in radialen, snelheid),
##               flee_range = dichterbij dan dit en hij hupt weg, hop_distance / hop_time / hop_cooldown = het hupje

const ENEMIES := {
	"mage": {
		"name": "Magiër", "hp": 6, "damage": 1, "behavior": "mage",
		"speed": 52.0, "chase_speed": 64.0, "sight": 240.0, "knockback": 200.0,
		"keep_distance": [90.0, 150.0], "teleport_every": 4.0, "teleport_range": [100.0, 140.0],
		"vanish_time": 0.2, "appear_time": 0.12, "cast_time": 0.7, "orb_speed": 90.0,
		"sheet": "mage", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 9.0, "fly": true,
		"death_color": Color(0.85, 0.6, 1.0),
		"hint": "Een Magiër! Sla zijn tovervonk stuk of wijk uit.",
		"drops": [["coin", 1.0, 3], ["potion", 0.1, 1], ["heart", 0.12, 1]],
		"desc": "Zweeft in zijn gewaad en is nooit waar je hem verwacht: poef, weg! Zijn tovervonk is traag, dus sla hem gewoon kapot met je zwaard.",
	},
	"slime_spitter": {
		"name": "Slijmspuwer", "hp": 4, "damage": 1, "behavior": "spitter",
		"speed": 14.0, "sight": 170.0, "knockback": 200.0,
		"spit_range": 170.0, "spit_every": 2.2, "windup": 0.45, "fan": 3, "fan_spread": 0.35, "ball_speed": 100.0,
		"flee_range": 60.0, "hop_distance": 80.0, "hop_time": 0.4, "hop_cooldown": 1.4,
		"sheet": "slime_spitter", "cell": 16, "scale": 2.0, "radius": 7.0, "shadow": 10.0,
		"hint": "Een Slijmspuwer! Rol weg als hij spuugt. Kom je dichtbij, dan hupt hij weg.",
		"drops": [["coin", 1.0, 2], ["gel", 0.6, 1], ["heart", 0.1, 1]],
		"desc": "Een slijm met een veel te grote mond, en hij gebruikt hem ook. Kom je te dichtbij, dan hupt hij weg om het opnieuw te proberen.",
	},
}

## Geluiden (assets/audio, gemaakt door tools/audio_x_vijanden.py).
const SOUNDS := ["mage_teleport", "mage_charge", "mage_orb", "mage_orb_pop", "spitter_spit", "spitter_hop"]
