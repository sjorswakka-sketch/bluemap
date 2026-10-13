extends SceneTree
const Npcs := preload("res://scripts/data/npcs.gd")
const Appearance := preload("res://scripts/core/appearance.gd")
const Clothing := preload("res://scripts/data/ext/uiterlijk.gd")
var failures := 0
var gs: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("  ok   " if ok else "  FAIL ", message)
	if not ok:
		failures += 1

func frames(n := 3) -> void:
	for i in n:
		await process_frame

func pick_talk(npc: String) -> String:
	for rule: Dictionary in Npcs.NPCS[npc]["rules"]:
		if not rule.has("if") or gs.check_all(rule["if"]):
			return rule["talk"]
	return ""

func _run() -> void:
	root.size = Vector2i(1152, 648)
	await process_frame
	gs = root.get_node("GameState")
	for spec: Array in [["stien", "veenbessen", "prof_veenbes", 5], ["wouda", "zonneschijf", "zonneschijf_amulet", 1], ["sana", "cactusvijgen", "prof_cactusvijg", 5], ["elke", "kruiden", "herb", 4], ["lotte", "lantaarn", "special_lantern", 1]]:
		gs.new_game()
		gs.set_flag(spec[0] + "_ontmoet")
		check(pick_talk(spec[0]) == spec[0] + "_intro", spec[0] + ": na weigeren kan de opdracht opnieuw aangeboden worden")
		gs.start_quest(spec[1])
		gs.give(spec[2], spec[3], true)
		check(pick_talk(spec[0]) == spec[0] + "_klaar", spec[0] + ": verzamelde spullen kunnen worden ingeleverd")
		gs.take(spec[2], spec[3])
		check(pick_talk(spec[0]) != spec[0] + "_klaar", spec[0] + ": verbruikte spullen geven geen gratis beloning")
		gs.give(spec[2], spec[3], true)
		check(pick_talk(spec[0]) == spec[0] + "_klaar", spec[0] + ": opnieuw verzamelen herstelt inleveren")
	gs.new_game()
	gs.set_flag("roos_ontmoet")
	check(pick_talk("roos") == "roos_intro", "Roos kan haar gevechtsopdracht opnieuw aanbieden")
	gs.set_flag("jelle_ontmoet")
	check(pick_talk("jelle") == "jelle_intro", "Jelle kan zijn opdracht opnieuw aanbieden")
	gs.start_quest("vellen_en_vlees")
	gs.give("jacht_vacht", 2, true)
	gs.give("jacht_vlees", 2, true)
	gs.take("jacht_vlees", 2)
	check(pick_talk("jelle") != "jelle_klaar", "Jelle vereist beide soorten materiaal bij het inleveren")
	gs.new_game()
	gs.set_flag("mira_ontmoet")
	check(pick_talk("mira") == "mira_intro", "Mira kan de dauwsteenopdracht opnieuw aanbieden")
	gs.start_quest("dauw")
	gs.finish_quest("dauw")
	gs.set_flag("mira_mist_gevraagd")
	check(pick_talk("mira") == "mira_mist_intro", "Mira kan ook de uitgestelde alchemieopdracht opnieuw aanbieden")
	gs.start_quest("mistbloemen")
	gs.give("prof_dauwklauw", 3, true)
	gs.take("prof_dauwklauw", 3)
	check(pick_talk("mira") != "mira_mist_klaar", "Mira vereist nog aanwezige dauwklauwen")
	gs.new_game()
	gs.in_game = true
	var world: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(10)
	for item: String in Clothing.ITEMS:
		gs.give(item, 1, true)
	world.menu_ui.open(7)
	await frames(20)
	var page: Control = world.menu_ui.appearance_page
	root.get_node("Controls").controller_active = false
	for row in range(5, 10):
		var slot: String = page.slot_of_row(row)
		Appearance.wear(Appearance.owned_in_slot(slot)[0])
		page.selected = row
		page.dye_mode = true
		var panel: Rect2 = page._dye_panel_rect()
		check(panel.position.y >= 0 and panel.end.y <= page.size.y, "verfkleuren blijven zichtbaar voor " + slot)
		var at: Vector2 = page.get_global_transform_with_canvas() * page._swatch_rect(3).get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		motion.relative = Vector2(10, 0)
		root.push_input(motion)
		var click := InputEventMouseButton.new()
		click.position = at
		click.global_position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		root.push_input(click)
		await frames(2)
		click.pressed = false
		root.push_input(click)
		await frames(2)
		check(int(Appearance.worn(slot)["dye"]) == 3 and page.selected == row and page.dye_mode, "echte muisklik kiest kleur zonder rij erachter te activeren: " + slot)
	world.menu_ui.close()
	world.queue_free()
	await frames()
	print("POLISH REGRESSION OK" if failures == 0 else "POLISH REGRESSION FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
