extends SceneTree
const Journal := preload("res://scripts/core/craft_journal.gd")
const Prof := preload("res://scripts/core/professions.gd")
const Equipment := preload("res://scripts/core/equipment.gd")
const Data := preload("res://scripts/data/ext/beroepen.gd")
var failures := 0
var gs: Node
var world: Node2D
var controls: Node
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	print("  ok   " if ok else "  FAIL ",message)
	if not ok: failures += 1
func frames(n:=3) -> void:
	for i in n: await process_frame; await physics_frame
func key(code: Key,down:=true) -> void:
	var e:=InputEventKey.new(); e.physical_keycode=code; e.pressed=down; Input.parse_input_event(e)
func pad(code: JoyButton,down:=true) -> void:
	var e:=InputEventJoypadButton.new(); e.button_index=code; e.pressed=down; Input.parse_input_event(e)
func tap_pad(code: JoyButton) -> void:
	pad(code); await frames(); pad(code,false); await frames()
func enter(id: String) -> void:
	world.dialogue._close()
	world.load_map(id,"start")
	await frames(6)
	world.player.invuln=999
	world.player.set_physics_process(false)
func notes() -> Node2D:
	for n in get_nodes_in_group("craft_notes"):
		if not n.is_queued_for_deletion(): return n
	return null
func run() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-") and OS.get_environment("XDG_DATA_HOME")=="": quit(1); return
	root.size=Vector2i(1152,648)
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	await frames()
	gs=root.get_node("GameState");controls=root.get_node("Controls")
	gs.new_game();gs.in_game=true
	world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await frames(12)
	check(Prof.craft_reason("pg_grip")!="" and gs.count("gear_pg_grip")==0,"new pattern begins undiscovered")
	for id: String in ["smithy","library","lake"]:
		await enter(id)
		var note:=notes()
		check(note!=null and not world.is_solid(note.position),"worktable on open tile: "+id)
		for obj: Dictionary in world.map_data.objects:
			if obj.type in ["npc","sign","chest","portal","living_object","supper_object"]:
				check(note.obj.pos!=obj.pos,"notes do not overlap another object in "+id)
		world.player.position=note.position+Vector2(0,28)
		world.player._update_target()
		check(world.player.target==note,"note can be selected on foot: "+id)
		if id=="library":
			await tap_pad(JOY_BUTTON_A)
		else:
			key(KEY_E);await frames();key(KEY_E,false);await frames()
		check(gs.dialogue_open,"physical input reads pattern: "+id)
		world.dialogue._close();await frames()
		var inventory: Dictionary=gs.inventory.duplicate()
		var xp: Dictionary=gs.professions.get("xp",{}).duplicate()
		note.interact();world.dialogue._close();await frames()
		check(gs.inventory==inventory and gs.professions.get("xp",{})==xp,"rereading grants no material or XP: "+id)
	check(gs.flag("pg_smith_notes") and gs.flag("pg_focus_notes") and gs.flag("pg_pack_notes"),"three different patterns discovered")
	await enter("village")
	check(Prof.gather("branches","village:twigs_west") and Prof.gather("stones","village:flint_west"),"starter materials gathered without tools")
	check(Prof.craft("stone_axe"),"gathering leads to first tool")
	check(Prof.gather("branches","village:twigs_south"),"fresh second source supplies straps")
	await enter("forest")
	var stump: Node2D
	for n in get_nodes_in_group("profession_resources"):
		if not n.is_queued_for_deletion() and n.resource_id=="forest:birch_west": stump=n
	world.player.position=stump.position+Vector2(0,25)
	stump.player=world.player
	stump.interact()
	stump.advance_harvest(Prof.gather_duration("stump"))
	check(gs.count("prof_log")==2,"real harvest animation commits logs for pack")
	var ui: Node=world.crafting_ui
	ui.selected_entry="pg_pack"; ui.open(); await frames(8)
	check(ui.detail.text.contains("Berkenhout") and ui.detail.text.contains("Fluisterbos"),"recipe explains real materials and source")
	check(root.gui_get_focus_owner() is Button,"focused selected recipe remains a real button")
	check(ui.scroll.get_global_rect().encloses(root.gui_get_focus_owner().get_global_rect()),"selected deep recipe is fully visible after layout scaling")
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner()==ui.detail,"controller reaches source explanation")
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner()==ui.goal_button,"controller reaches material goal action")
	await tap_pad(JOY_BUTTON_A)
	check(Journal.goal()=="pg_pack","controller pins exactly the selected recipe")
	await tap_pad(JOY_BUTTON_B)
	await frames()
	check(world.craft_goal.panel.visible and world.craft_goal.label.text.contains("Werkpak"),"material goal visible in world")
	check(world.craft_goal.panel.position.y>=world.hud.tracker_panel.position.y+world.hud.tracker_panel.size.y,"material goal below quest without overlap")
	check(Prof.craft("pg_pack") and Journal.goal()=="","target clears when item is crafted")
	check(gs.count("gear_pg_pack")==1 and Equipment.bonus("harvest_time_reduction")==0,"owning pack does not grant effect")
	Equipment.equip("gear_pg_pack")
	check(is_equal_approx(Prof.gather_duration("stump"),1.1*0.85),"worn pack shortens actual work action")
	gs.give("prof_dennenhout",4,true);gs.give("prof_wilgentwijg",2,true)
	var before: Dictionary=gs.inventory.duplicate()
	check(not Prof.craft("pg_pack_plus") and gs.inventory==before,"regional upgrade locked without spending input")
	gs.set_flag("ra_rope")
	Journal.toggle_goal("pg_pack_plus")
	gs.movement.stamina=45
	check(Prof.craft("pg_pack_plus"),"climbing discovery unlocks regional pack refinement")
	check(gs.count("gear_pg_pack")==0 and gs.count("gear_pg_pack_plus")==1 and Equipment.equipped("chest")=="gear_pg_pack_plus","worn base replaced by exactly one upgraded item")
	check(gs.movement.stamina==45 and is_equal_approx(Prof.gather_duration("stump"),1.1*0.75),"upgrade improves real work speed without filling stamina")
	check(Journal.goal()=="","upgrade target cleared atomically")
	before=gs.inventory.duplicate()
	check(not Prof.craft("pg_pack_plus") and before==gs.inventory,"duplicate upgrade cannot consume materials")
	await enter("smithy")
	gs.give("prof_copper_ore",6,true);gs.give("prof_log",4,true)
	for i in 3: check(Prof.craft("copper_bar"),"ore and fuel build smithing experience")
	check(Prof.level("smithing")==2 and Prof.craft("pg_grip"),"smithing progression makes base bands")
	Equipment.equip("gear_pg_grip")
	var actions: Script=load("res://scripts/entities/combat_actions.gd")
	check(actions.effective_profile("iron").cost==25 and actions.effective_profile("iron",true).cost==18,"worn bands reduce real technique costs")
	gs.give("prof_ijzeroer",4,true);gs.give("prof_dennenhout",2,true)
	check(Prof.craft("bog_iron_bar") and Prof.craft("bog_iron_bar"),"regional ore and pine fuel substitute original ore route")
	gs.give("prof_zandsteen",2,true)
	check(not Prof.craft("pg_grip_plus"),"hardening requires restored spring")
	gs.set_flag("ra_spring")
	check(Prof.craft("pg_grip_plus") and Equipment.equipped("hands")=="gear_pg_grip_plus","restored spring connects sandstone to combat gear")
	check(actions.effective_profile("iron").cost==22 and actions.effective_profile("iron",true).cost==16,"improved bands change both live profiles")
	await enter("library")
	gs.give("prof_herb",2,true)
	check(Prof.craft("pg_focus"),"alchemy uses remaining copper and herbs for lens")
	Equipment.equip("gear_pg_focus")
	check(is_equal_approx(actions.effective_profile("iron",true).windup,0.65*0.85),"base lens shortens actual bow preparation")
	Prof.add_xp("alchemy",30)
	gs.give("prof_ijskristal",2,true);gs.give("prof_watermunt",2,true)
	check(not Prof.craft("pg_focus_plus"),"clear lens requires archive discovery")
	gs.set_flag("ra_archive_done")
	check(Prof.craft("pg_focus_plus") and Equipment.equipped("neck")=="gear_pg_focus_plus","archive research connects ice and marsh herbs to bow gear")
	check(is_equal_approx(actions.effective_profile("iron",true).windup,0.65*0.75) and Equipment.bonus("stamina_regen")==0.1,"improved lens applies both bonuses")
	check(Equipment.stats_text("gear_ra_compass").contains("16") and Equipment.stats_text("gear_ra_compass").contains("10"),"existing mixed reward displays all bonuses")
	gs.give("gear_bronze_helm",1,true);gs.give("gear_rf_cord",1,true)
	Equipment.equip("gear_bronze_helm")
	check(Equipment.comparison_text("gear_rf_cord").contains("staminaherstel") and not Equipment.comparison_text("gear_rf_cord").contains("+20 stamina"),"comparison respects whole-set stamina cap")
	check(Journal.source("prof_zandsteen").contains("Dorstvallei") and Journal.source("prof_zandsteen").contains("pikhouweel"),"source includes real area and tool")
	check(Journal.uses_text("prof_ijzeroer").contains("IJzerstaaf"),"formerly stranded ore has an explained use")
	check(Prof.normalize({"goal":"unknown"}).get("goal","")=="" and Prof.normalize({"goal":[]}).get("goal","")=="","invalid goals normalize safely")
	Journal.toggle_goal("pg_grip_plus")
	gs.save_game(world.player.position)
	var saved_gear: Dictionary=gs.equipment.duplicate()
	gs.equipment.clear();gs.professions.clear()
	check(gs.load_game() and Journal.goal()=="pg_grip_plus" and gs.equipment==saved_gear,"actual save/load retains goal and refined gear")
	world.menu_ui.open(6)
	var page: Node=world.menu_ui.equipment_page
	page.select_slot(2)
	await frames()
	check(page.candidate()=="gear_pg_grip_plus","worn refined gear selects its later page")
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	await tap_pad(JOY_BUTTON_DPAD_UP)
	check(page.candidate()=="gear_pg_grip" and Equipment.equipped("hands")=="gear_pg_grip_plus","controller browses previous gear page without changing loadout")
	await tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(page.candidate()=="gear_pg_grip_plus","controller returns to last refined option")
	for index in page.visible_indices():
		check(page.item_rect(index).end.y < page.detail.position.y,"paged option does not overlap explanation")
	world.menu_ui.close()
	for item: String in ["prof_frost_tonic","prof_winter_gloed","prof_zandbalsem","jacht_braadstuk","prof_mistdrank","prof_dauwsoep","prof_moeraselixer","prof_veenbespap"]:
		gs.give(item,1,true);gs.full_heal();gs.movement.reset()
		check(not Prof.use_item(item) and gs.count(item)==1,"regional consumable not wasted: "+item)
		if load("res://scripts/data/items.gd").info(item).has("heal"): gs.hp-=1
		else: gs.movement.stamina=1
		check(Prof.use_item(item) and gs.count(item)==0,"regional crafted item actually usable: "+item)
	gs.new_game()
	check(Journal.goal()=="" and not gs.flag("pg_smith_notes") and Equipment.bonus("technique_cost_reduction")==0,"new game clears goals, patterns and gear effects")
	world.queue_free();await frames()
	print("CRAFT PROGRESSION OK" if failures==0 else "CRAFT PROGRESSION FAILED: %d" % failures)
	quit(0 if failures==0 else 1)
