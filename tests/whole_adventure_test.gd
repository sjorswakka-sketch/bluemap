extends SceneTree
const Journey:=preload("res://scripts/core/journey.gd")
const Maps:=preload("res://scripts/maps/registry.gd")
const Quests:=preload("res://scripts/data/quests.gd")
var FastTravel: Script
var gs: Node
var world: Node2D
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String) -> void:
	print("  ok   " if ok else "  FAIL ",message)
	if not ok:failures+=1
func frames(n:=4):
	for i in n:await process_frame
func tap(pad: bool,code: int):
	for down in [true,false]:
		if pad:
			var e:=InputEventJoypadButton.new();e.button_index=code;e.pressed=down;Input.parse_input_event(e)
		else:
			var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e)
		await frames(2)
func enter(map: String,spawn: String="start",at:=Vector2.INF):
	world.dialogue._close();world.menu_ui.close()
	world.load_map(map,spawn,at)
	world.player.set_physics_process(false)
	for e in get_nodes_in_group("enemies"):e.set_physics_process(false)
	await frames(5)
	world.dialogue._close()
func physics_free(at: Vector2) -> bool:
	var shape:=CircleShape2D.new();shape.radius=7
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape;query.collision_mask=1
	query.transform=Transform2D(0,at+Vector2(0,8))
	return world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	gs=root.get_node("GameState");FastTravel=load("res://scripts/core/fast_travel.gd")
	gs.new_game();gs.in_game=true
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world
	await frames(12)
	check(Journey.focus()=="" and gs.tracked_text().begins_with("Praat met"),"old automatic goal preserved until player chooses")
	check(Journey.TARGETS.size()==Quests.QUESTS.size(),"every existing quest has route metadata")
	for id: String in Quests.QUESTS:
		gs.start_quest(id)
		check(Journey.TARGETS[id].size()==Quests.QUESTS[id].steps.size(),"all steps mapped: "+id)
		for step in Quests.QUESTS[id].steps.size():
			gs.set_quest_step(id,step)
			var to:=Journey.target(id)
			check(Maps.MAPS.has(to) and not Journey.path("village",to,false).is_empty(),"goal reachable through actual world portals: "+id+str(step))
	gs.new_game();gs.in_game=true;gs.set_flag("op_greta")
	gs.start_quest("main");gs.start_quest("kat");gs.start_quest("ls_supper")
	await enter("lake")
	var menu: Node=world.menu_ui
	menu.open(menu.TAB_QUESTS);menu.quest_selected=menu._quest_order().find("kat");await frames(8)
	await tap(false,KEY_ENTER)
	check(Journey.focus()=="kat" and gs.tracked_text().contains("Muis"),"keyboard pins chosen quest instead of unrelated local override")
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=menu.FOLLOW_RECT.get_center()
	menu._pointer_input(click)
	check(Journey.focus()=="","mouse follow button stops tracking")
	await tap(false,KEY_ENTER)
	menu.close();await frames()
	check(world.hud.tracker.text.contains("Volg:") and world.hud.tracker.text.contains("Muis"),"chosen goal really appears on HUD")
	var flags: Dictionary=gs.flags.duplicate()
	gs.save_game(world.player.position);gs.flags.clear()
	check(gs.load_game() and Journey.focus()=="kat" and gs.flags==flags,"actual save/load retains chosen quest")
	menu.open(menu.TAB_QUESTS);menu.quest_selected=menu._quest_order().find("ls_supper");await frames(8)
	await tap(true,JOY_BUTTON_A)
	check(Journey.focus()=="ls_supper" and not gs.flag("jr_focus_kat"),"controller changes focus atomically")
	await tap(true,JOY_BUTTON_DPAD_RIGHT)
	await tap(true,JOY_BUTTON_DPAD_DOWN)
	check(menu.quest_detail_mode and menu.quest_detail.get_v_scroll_bar().value>0,"controller scrolls long preparation text")
	await tap(true,JOY_BUTTON_DPAD_LEFT)
	check(not menu.quest_detail_mode,"controller returns to quest list")
	menu.close();gs.finish_quest("ls_supper")
	check(Journey.focus()=="" and not Journey.toggle("ls_supper"),"completed focus returns to automatic goal without tracking dead task")
	gs.flags["jr_focus_unknown"]=true
	check(Journey.focus()=="" and not Journey.toggle("unknown"),"unknown legacy focus is ignored")
	gs.new_game();gs.in_game=true;gs.start_quest("main")
	gs.give("crystal_bos",1,true)
	check(Journey.target("main")=="ruins","crystal objective moves to a remaining crystal")
	await enter("forest")
	check(Journey.route_text("main").contains("bossleutel"),"closed ruin gate gives concrete prerequisite")
	gs.set_flag("gate_ruin")
	check(Journey.route_text("main").contains("doorgang") and Journey.route_text("main").contains("50, 12"),"opened route gives real portal coordinate")
	gs.start_quest("meer_boeken");gs.give("meer_boek_eiland",1,true);gs.give("meer_boek_sanne",1,true)
	check(Journey.target("meer_boeken")=="fisher_hut","book route follows still-missing book")
	gs.give("meer_boek_hut",1,true)
	check(Journey.target("meer_boeken")=="library","all books point back to actual recipient")
	gs.hp=2;gs.movement.stamina=17
	check("\n".join(Journey.preparation("temple")).contains("2/5") and "\n".join(Journey.preparation("temple")).contains("geen verplichte"),"preparation shows current supplies without an invented level gate")
	await enter("village")
	var all: Array=FastTravel.all_altars()
	for altar in all:gs.set_flag(altar.key)
	menu.open(menu.TAB_MAP);await frames(8)
	for i in all.size()+2:await tap(true,JOY_BUTTON_DPAD_DOWN)
	check(menu.travel_selected==all.size()-1 and menu.travel_scroll>0,"controller reaches last of twelve altars")
	check(menu.travel_selected>=menu.travel_scroll and menu.travel_selected<menu.travel_scroll+menu.TRAVEL_VISIBLE,"selected late altar remains visible")
	await tap(true,JOY_BUTTON_A)
	check(menu.travel_confirm and menu.travel_box_y(all.size())+110<menu.SIZE.y-40,"travel confirmation stays inside panel")
	await tap(true,JOY_BUTTON_B)
	check(menu.active and not menu.travel_confirm,"controller cancels travel without leaving menu")
	await tap(false,KEY_UP)
	click.position=Vector2(790,104+(all.size()-1-menu.travel_scroll)*48+21)
	menu._pointer_input(click)
	check(menu.travel_selected==all.size()-1 and menu.travel_confirm,"mouse selects correct altar in scrolled list")
	click.position=Vector2(880,menu.travel_box_y(all.size())+86)
	menu._pointer_input(click)
	check(not menu.travel_confirm and menu.active,"mouse cancellation matches visible button")
	menu.close()
	var old_size:=root.size
	var old_scale:=root.content_scale_size
	var old_mode:=root.content_scale_mode
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	for dimensions in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
		root.size=dimensions;menu.open(menu.TAB_MAP);await frames(6)
		var bounds:=Rect2(menu.content.global_position,menu.SIZE*menu.content.scale)
		check(bounds.position.x>=20 and bounds.position.y>=20 and bounds.end.x<=dimensions.x-20 and bounds.end.y<=dimensions.y-20,"whole menu fits actual viewport: "+str(dimensions))
		menu.close()
	root.size=old_size;root.content_scale_size=old_scale;root.content_scale_mode=old_mode
	# Every portal return and altar is checked against actual, instantiated shapes.
	for restored in [false,true]:
		gs.new_game();gs.in_game=true
		if restored:
			for flag in ["gate_ruin","gate_temple","gate_depths","diepte_opened","game_completed","guardian_defeated","boss_defeated","lw_forest","lw_mine","lw_heat_west","lw_heat_east","lw_heat","lw_drained","lw_bridge","ra_spring","ra_water_wild","ra_archive_done","ra_rope"]:gs.set_flag(flag)
		for map: String in Maps.MAPS:
			for spawn: String in Maps.get_map(map).spawns:
				await enter(map,spawn)
				check(world.spawn_fits(world.player.position),"free physical spawn: "+map+"/"+spawn+" restored="+str(restored))
				check(physics_free(world.player.position),"independent physics query agrees at returned spawn")
			var legend: Dictionary={}
			for mark in menu.extension_marks(world.map_data):legend[mark.label]=mark.color
			var layout: Array=menu.map_legend_layout(legend,ThemeDB.fallback_font)
			check(layout.size()==legend.size(),"all map legend entries fit: "+map)
			for entry in layout:check(entry.at.x+entry.width<=menu.MARGIN+menu.MAP_WIDTH and entry.at.y<=500,"legend avoids travel panel and footer")
		for altar in all:
			await enter(altar.map,altar.spawn,altar.pos)
			check(world.spawn_fits(world.player.position),"free actual altar arrival: "+altar.map)
			check(physics_free(world.player.position),"independent physics query agrees at altar arrival")
			check(world.player.position.distance_to(altar.pos)<96,"arrival remains at chosen altar, not another part of map")
	# Existing same-map travel never reloads entities or grants free healing.
	gs.new_game();gs.in_game=true
	await enter("village")
	var home: Dictionary=all[0]
	gs.set_flag(home.key);gs.hp=2;gs.movement.stamina=17
	var block:=StaticBody2D.new();block.collision_layer=1;block.position=home.pos
	var box:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(24,20);box.shape=rect;box.position.y=8;block.add_child(box);world.entities.add_child(block)
	check(not world.spawn_fits(home.pos),"occupied arrival detected from real collider")
	var before: int=world.entities.get_child_count()
	check(await FastTravel.travel(world,home),"same-map travel succeeds with occupied arrival")
	check(world.spawn_fits(world.player.position) and world.player.position!=home.pos and world.entities.get_child_count()==before,"relocation avoids obstacle without respawning cleared map")
	check(gs.hp==2 and gs.movement.stamina==17 and world.player.invuln>0,"travel gives orientation time without healing or stamina refill")
	var altar: Node2D
	for node in world.entities.get_children():
		if node.get_script()!=null and node.get_script().resource_path.ends_with("savepoint.gd"):altar=node
	world.player.position=altar.position+Vector2(0,30);altar.interact()
	check(gs.hp==gs.max_hp() and gs.movement.stamina==gs.movement.capacity(),"explicit rest restores both hearts and stamina")
	gs.hp=1;gs.movement.stamina=1;gs.run(["heal"])
	check(gs.hp==gs.max_hp() and gs.movement.stamina==gs.movement.capacity(),"Mila's normal rest action restores both bars too")
	gs.start_quest("ls_supper");Journey.toggle("ls_supper")
	gs.set_flag("pg_pack_notes");load("res://scripts/core/craft_journal.gd").toggle_goal("pg_pack")
	world.hud.banner_time=0
	var announcement: Node=world.hud.achievement_banner
	announcement.time=0;announcement.hinted=true;gs.achievement_queue.clear();gs.achievement_queue.append("first_blood")
	await frames(36)
	var card:=Rect2(announcement.root.position,announcement.root.size)
	check(announcement.is_showing() and not card.intersects(Rect2(world.hud.tracker_panel.position,world.hud.tracker_panel.size)) and not card.intersects(Rect2(world.craft_goal.panel.position,world.craft_goal.panel.size)),"achievement card leaves quest and material goal readable")
	# The end boss commits a visible landing; phase changes cannot enlarge it mid-air.
	gs.new_game();gs.in_game=true;await enter("temple")
	var king: Node2D
	for node in get_nodes_in_group("boss"):
		if node.kind=="king" and not node.is_queued_for_deletion():king=node
	king.player=world.player;king.active=true;king.state="idle";king.state_time=2
	world.player.position=Vector2(11.5,12.5)*32;world.player.velocity=Vector2.ZERO
	king._ai_king(0)
	var committed: Vector2=king.hop_to
	check(king.state=="crouch" and king._fits_at(committed),"landing locks on clear floor at beginning of warning")
	world.player.position=Vector2(18.5,9.5)*32;king.hp=1
	king.state_time=king.king_charge_time()+0.01;king._ai_king(0)
	check(king.hop_to==committed and king.hop_phase==1 and king.king_shock()==64,"moving player and phase change do not move or enlarge warning")
	world.player.position=committed+Vector2(65,0);world.player.invuln=0
	var hp: int=gs.hp
	king.state_time=king.king_hop_time()+0.01;king._ai_king(0)
	check(gs.hp==hp and king.global_position==committed,"leaving visible impact radius really avoids damage")
	world.player.position=committed+Vector2(63,0);world.player.invuln=0;king._king_land(1)
	check(gs.hp==hp-1,"inside displayed radius takes the announced phase-one damage")
	king.state="idle";king.state_time=2;world.player.position=Vector2(11.5,10.5)*32;king._ai_king(0)
	check(king.hop_phase==3 and king.king_shock()==86 and king.king_charge_time()>=0.5,"later phase has its own full warning")
	await frames()
	var warning: Node2D=get_nodes_in_group("king_warnings")[0]
	check(warning.get_parent()==world.ground and warning.visible and warning.global_position==king.hop_to,"landing marker drawn on ground at exact destination")
	gs.achievement_queue.clear();gs.achievement_queue.append("first_blood");world.hud.achievement_banner.time=0
	await frames()
	check(not world.hud.achievement_banner.is_showing(),"achievements wait during boss fight instead of covering warning")
	world.queue_free();await frames()
	print("WHOLE ADVENTURE OK" if failures==0 else "WHOLE ADVENTURE FAILED: %d" % failures)
	quit(0 if failures==0 else 1)
