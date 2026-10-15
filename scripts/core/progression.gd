extends RefCounted
## Held-ervaring beloont verslagen vijanden en voltooide opdrachten. Levels geven
## munten voor de bestaande uitrusting; schade, levens en verhaalpoorten blijven gelijk.
## Geen autoload-referenties tijdens preload (ook bruikbaar vanuit data en tests).

const MAX_LEVEL := 10
const MAX_XP := 2250
const LEVEL_REWARD := 15
const ENEMY_XP := {
	"ad_crab":12, "ad_wisp":14, "ad_keeper":26,
	"slime": 5, "bat": 5, "slime_blue": 8, "skeleton": 10,
	"slime_red": 12, "slime_spitter": 12, "mage": 16,
	"golem": 45, "diepte_golem": 60, "king": 150, "guardian": 200,
	"slime_mini": 0, # eindeloos opgeroepen hulpjes geven geen ervaring
	"lw_warden": 18, "lw_stalker": 14, "lw_singer": 16, "crystal_beetle": 12, "prism_moth": 14,
}


static func state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


static func normalize(raw: Variant) -> int:
	if not (raw is int or raw is float) or not is_finite(float(raw)):
		return 0
	# Eerst begrenzen: ook een heel groot getal uit een oude/beschadigde opslag is veilig.
	return int(clampf(float(raw), 0.0, float(MAX_XP)))


static func threshold(for_level: int) -> int:
	var bounded := clampi(for_level, 1, MAX_LEVEL)
	return 25 * (bounded - 1) * bounded


static func xp() -> int:
	return normalize(state().hero_xp)


static func level_for(total: int) -> int:
	var result := 1
	while result < MAX_LEVEL and total >= threshold(result + 1):
		result += 1
	return result


static func level() -> int:
	return level_for(xp())


static func progress() -> Dictionary:
	var total := xp()
	var current_level := level_for(total)
	var at_max := current_level == MAX_LEVEL
	return {
		"level": current_level, "xp": total,
		"current": 0 if at_max else total - threshold(current_level),
		"needed": 0 if at_max else threshold(current_level + 1) - threshold(current_level),
		"max_level": at_max, "next_reward": 0 if at_max else LEVEL_REWARD,
	}


static func enemy_xp(kind: String) -> int:
	# Nieuwe gewone vijanden krijgen een bescheiden standaardbeloning.
	return int(ENEMY_XP.get(kind, 5))


static func quest_xp(quest_id: String) -> int:
	var quests: Dictionary = (load("res://scripts/data/quests.gd") as Script).get("QUESTS")
	if not quests.has(quest_id):
		return 0
	# De Diepte is het grote vervolgverhaal na de oorspronkelijke hoofdopdracht.
	return 100 if quests[quest_id].get("main", false) or quest_id == "diepte" else 40
