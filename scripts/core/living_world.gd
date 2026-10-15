extends RefCounted
## Blijvende mijlpalen gebruiken de bestaande save-vlaggen. Geen parallel saveformaat.
static var pending: WeakRef

static func gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")

static func migrate() -> void:
	var state := gs()
	# Completed saves must show the same safe gate positions as newly solved sluices.
	if state.flag("lw_drained") or state.quest_state("wilgentwijgen")=="done":
		state.flags["lw_sluice_west"]=true
		state.flags["lw_sluice_east"]=false
		state.flags["lw_sluice_west_seen"]=true
		state.flags["lw_sluice_east_seen"]=true
	if state.flag("lw_revision_1"):
		return
	# Oude afgeronde opdrachten verdienen hun nieuwe wereldgevolg ook.
	if state.quest_state("warmte") == "done":
		for id in ["lw_heat_west", "lw_heat_east", "lw_heat"]:
			state.flags[id] = true
	elif state.quest_state("warmte") == "active":
		state.quests["warmte"]["step"] = 0
	if state.quest_state("wilgentwijgen") == "done":
		for id in ["lw_drained", "lw_bridge", "lw_tailoring"]:
			state.flags[id] = true
	elif state.quest_state("wilgentwijgen") == "active":
		state.quests["wilgentwijgen"]["step"] = 0
	state.flags["lw_revision_1"] = true

static func mark(flag_name: String) -> bool:
	if gs().flag(flag_name):
		return false
	gs().set_flag(flag_name)
	gs().save_requested.emit()
	return true

static func open(node: Node2D, talk: String) -> void:
	pending = weakref(node)
	gs().start_dialogue(talk)

static func run(action: String) -> void:
	if pending == null:
		return
	var node: Variant = pending.get_ref()
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node.world.player.global_position.distance_to(node.global_position) > 72.0:
		return
	node.choose(action)

static func lantern_made() -> void:
	var state := gs()
	if state.count("lw_lantern") < 1:
		return
	state.start_quest("lichtwerk")
	state.finish_quest("lichtwerk")
	state.start_quest("mistsporen")
	mark("lw_lantern_made")

static func direction(id: String) -> int:
	for i in range(1, 4):
		if gs().flag(id + "_turn_" + str(i)):
			return i
	return 0

static func turn(id: String) -> int:
	var next := (direction(id) + 1) % 4
	for i in range(1, 4):
		gs().set_flag(id + "_turn_" + str(i), next == i)
	return next

static func beams_ready() -> bool:
	return direction("lw_mirror_a") == 0 and direction("lw_mirror_b") == 1 and direction("lw_mirror_c") == 2

static func light_at(position: Vector2) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var player := tree.get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and gs().count("lw_lantern") > 0 and position.distance_to(player.global_position) < 66.0:
		return true
	for node: Node2D in tree.get_nodes_in_group("living_objects"):
		if node.kind == "brazier" and (gs().flag(node.id) or node.active) and position.distance_to(node.global_position) < 86.0:
			return true
	return false

static func npc_lines(id: String) -> Array:
	# Bijzaken blijven via de normale NPC-menu's beschikbaar.
	match id:
		"mira":
			if gs().flag("lw_forest") and gs().quest_state("dauw") == "done" and gs().quest_state("mistbloemen") == "done":
				return [TranslationServer.translate("Je hebt de oude lichtkring hersteld. In de Dauwtuin bloeien de kruiden weer.")]
		"olav":
			if gs().flag("lw_heat"):
				return [TranslationServer.translate("Kijk naar de huizen: de families zijn terug. De Bergpas achter het oostelijke huis is open.")]
		"stien":
			if gs().flag("lw_bridge") and gs().quest_state("veenbessen") == "done":
				return [TranslationServer.translate("Mijn turf gaat weer over de brug. Aan de drooggevallen oever kun je nu vissen.")]
	return []
