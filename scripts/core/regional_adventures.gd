extends RefCounted
## Phase 2 shares only persistence; each region has its own play loop.
static var pending: WeakRef
static func gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")

static func migrate() -> void:
	if gs().flag("ra_revision_1"): return
	if gs().quest_state("cactusvijgen")=="done":
		gs().flags["ra_spring"]=true
		gs().flags["ra_water_wild"]=true
	elif gs().quest_state("cactusvijgen")=="active":
		gs().quests["cactusvijgen"]["step"]=0
	gs().flags["ra_revision_1"]=true

static func mark(id: String) -> void:
	gs().set_flag(id)
	gs().save_requested.emit()

static func open(node: Node2D, talk: String) -> void:
	pending=weakref(node)
	gs().start_dialogue(talk)

static func action(data: Array) -> void:
	var node: Variant=pending.get_ref() if pending!=null else null
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree(): return
	if not is_instance_valid(node.world.player) or node.position.distance_to(node.world.player.position)>64: return
	node.choose(str(data[1]))

static func tracker() -> String:
	var quest: String={"dorstvallei":"cactusvijgen","sunwell":"cactusvijgen","ridgepass":"ra_ridge","reedvault":"ra_archive"}.get(gs().map_id,"")
	if quest!="" and gs().quest_state(quest)=="active": return gs().quest_text(quest)
	return ""

static func safe_position(map_id: String,at: Vector2) -> Vector2:
	# Only the newly closed bottom bypass needs a terrain migration.
	if map_id=="ridgepass" and Rect2(13*32,17*32,3*32,2*32).has_point(at):
		return Vector2(12.5 if at.x<14.5*32 else 16.5,18.5)*32
	return at
