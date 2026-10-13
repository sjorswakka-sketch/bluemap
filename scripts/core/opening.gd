extends RefCounted

static func state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")

static func enabled() -> bool:
	return state().flag("op_new_adventure") and state().ng_plus == 0

static func flowing() -> bool:
	return not enabled() or state().flag("op_water")

static func quiet_hud() -> bool:
	return enabled() and not state().flag("op_greta") and state().map_id == "village" and state().quest_state("main") == "none"

static func greta_intro() -> bool:
	var gs := state()
	if not enabled() or not gs.flag("op_water") or gs.flag("op_greta"): return false
	gs.set_flag("op_greta")
	gs.finish_quest("first_water")
	gs.say("Greta", [TranslationServer.translate("Dat teken ken ik! De oude waterbouwers gebruikten hetzelfde prisma als mijn werkbank. Je hebt meer hersteld dan alleen een fontein."), TranslationServer.translate("Kijk gerust bij de prismabank links van me. Voor de mijn heb je later een ijzeren zwaard nodig. Oudste Bram bij de tempel kan je eerst op weg helpen.")])
	gs.save_requested.emit()
	return true
