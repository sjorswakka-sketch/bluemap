extends RefCounted
const Professions := preload("res://scripts/core/professions.gd")
const DISHES := ["ls_chowder","ls_broth"]
static var pending: WeakRef
static var busy := false

static func gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")

static func stitch() -> int:
	var node: Variant = pending.get_ref() if pending != null else null
	return node.stitch if is_instance_valid(node) and "stitch" in node else 0

static func action(data: Array) -> void:
	var node: Variant = pending.get_ref() if pending != null else null
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	if node.position.distance_to(node.world.player.position)>66: return
	if data[0]=="ls_weave" and node.kind=="net": node.weave(str(data[1]))
	if data[0]=="ls_share" and node.kind=="table": node.share(str(data[1]))

static func inputs(dish: String) -> Dictionary:
	# The introductory hamper contains both variants; later meals use normal resources.
	if gs().count("ls_crate")>0: return {"ls_crate":1}
	return {"meer_baars":2,"prof_herb":1} if dish=="ls_chowder" else {"meer_baars":1,"prof_berry":2}

static func cook_reason(dish: String) -> String:
	if dish not in DISHES or gs().map_id!="inn": return TranslationServer.translate("Kook bij Mila's fornuis in de herberg.")
	if not gs().flag("ls_basket"): return TranslationServer.translate("Haal eerst Joris' maaltijdmand bij de middelste steiger op.")
	for item: String in inputs(dish):
		if gs().count(item)<inputs(dish)[item]: return TranslationServer.translate("Nog nodig: %s") % Professions.item_name(item)
	return ""

static func cook(dish: String) -> bool:
	if busy or cook_reason(dish)!="": return false
	busy=true
	var ingredients:=inputs(dish)
	var amount:=2 if ingredients.has("ls_crate") else 1
	for item: String in ingredients: gs().take(item,ingredients[item])
	gs().give(dish,amount,true)
	Professions.add_xp("cooking",12)
	gs().set_flag("ls_cooked")
	gs().start_quest("ls_supper")
	gs().save_requested.emit()
	busy=false
	return true

static func tracker() -> String:
	if gs().map_id in ["lake","inn"] and gs().quest_state("ls_supper")=="active":
		if gs().flag("ls_cooked") and gs().count("ls_chowder")+gs().count("ls_broth")==0:
			return TranslationServer.translate("Alle porties opgegeten? Kook opnieuw met baars en zilverkruid of bessen. Joris' nettenrek levert een reservevangst op.")
		return gs().quest_text("ls_supper")
	return ""

static func conversation(role: String) -> Array:
	var lines: Array=[]
	match role:
		"joris": lines.append(TranslationServer.translate("Van het meer naar deze tafel. Ik breng voortaan een deel van mijn vangst hierheen. De rest houd ik voor de Gouden Karper — die is me nog iets verschuldigd."))
		"bo": lines.append(TranslationServer.translate("Brood in de mand, soep op tafel. Deze stop blijft in mijn bezorgronde."))
		"nelle": lines.append(TranslationServer.translate("Zelfs een hovenier mag eens stilzitten. Morgen zet ik kruiden bij de keuken."))
	if gs().flag("op_water"):
		lines.append(TranslationServer.translate("Sinds de fontein weer stroomt, vullen we de kruiken gewoon op het plein."))
	if gs().flag("cat_found"):
		lines.append(TranslationServer.translate("Pim houdt een plekje bij het vuur vrij voor Muis. Fijn dat ze weer thuis is."))
	if gs().flag("rf_memorial"):
		lines.append(TranslationServer.translate("Op Wilfred. Lena schrijft zijn verhaal op, zodat zijn naam ook hier blijft leven."))
	return lines
