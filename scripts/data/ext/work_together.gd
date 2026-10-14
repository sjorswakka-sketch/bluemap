extends RefCounted
## Optional collaborations, reached through the two existing residents.
const ACTIONS := ["wt_open"]
const SOUNDS := ["wt_clamp","wt_grind","wt_pour"]
static func run(action: Array) -> void:
	var tree:=Engine.get_main_loop() as SceneTree
	for workshop in tree.get_nodes_in_group("workshop"):
		if not workshop.is_queued_for_deletion() and workshop.kind==str(action[1]):workshop.open.call_deferred(str(action[1]));return
