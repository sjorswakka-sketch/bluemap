extends RefCounted
static var pending: WeakRef
static func gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
static func migrate() -> void:
	if gs().flag("rf_revision_1"): return
	# Eerder afgeronde verhalen krijgen hun decor zonder nogmaals een beloning.
	if gs().quest_state("medaillon")=="done":
		for id in ["rf_relief","rf_journal","rf_memorial","rf_guard"]: gs().flags[id]=true
	gs().flags["rf_revision_1"]=true
static func mark(id: String) -> void:
	gs().set_flag(id)
	gs().save_requested.emit()
static func loud(player: Node2D) -> bool:
	return player.sprinting or player.roll_timer>0 or player.attack_timer>0 or player.bow_anim>0
static func choose(choice: String) -> void:
	if pending==null or choice not in ["guard","guide"]: return
	var node: Variant=pending.get_ref()
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	if node.global_position.distance_to(node.world.player.global_position)>64.0: return
	node.remember(choice)
static func tracker() -> String:
	if gs().map_id=="ruins" and gs().quest_state("rf_memory")=="active": return gs().quest_text("rf_memory")
	if gs().map_id=="cave" and gs().quest_state("rf_echo")=="active": return gs().quest_text("rf_echo")
	if gs().map_id=="forest" and gs().quest_state("kat")=="active" and not gs().flag("cat_found"):
		return TranslationServer.translate("Volg de pootafdrukken vanaf het zuidelijke bospad. Bij Muis: stop met rennen, praat met haar en blijf rustig staan.")
	return ""
static func npc_interact(npc: Node2D) -> bool:
	if npc.npc_id=="muis_bos":
		if npc.route_calm>=2.0:
			gs().start_quest("kat")
			return false # het bestaande gesprek rondt het vinden van Muis af
		if npc.route_panic>0 or loud(npc.world.player):
			gs().toast.emit(TranslationServer.translate("Muis schrikt van het lawaai. Geef haar even rust."))
		else:
			npc.route_wait=true
			gs().toast.emit(TranslationServer.translate("Je steekt rustig je hand uit. Blijf bij Muis staan tot ze je vertrouwt."))
		return true
	if npc.npc_id=="bram" and gs().flag("rf_memorial") and gs().flag("rf_echo_end") and not gs().flag("rf_homecoming"):
		mark("rf_homecoming")
		gs().say("Bram",[TranslationServer.translate("De oude route licht weer op. En Wilfred heeft eindelijk een naam op zijn steen. De Blauwe Kaart gaat over de mensen tussen de kristallen, net zo goed als over de kristallen zelf.")])
		return true
	return false
