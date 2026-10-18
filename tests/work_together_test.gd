extends SceneTree
const Prof:=preload("res://scripts/core/professions.gd")
const Maps:=preload("res://scripts/maps/registry.gd")
var gs: Node
var world: Node2D
var workshop: Node2D
var ui: CanvasLayer
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,text: String):
	print("  ok   " if ok else "  FAIL ",text)
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
func click(button: Button):
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;motion.relative=Vector2(4,0)
	Input.parse_input_event(motion);await frames(2)
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=point;e.global_position=point;e.pressed=down;e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(e);await frames(3)
func enter(map: String):
	world.dialogue._close();world.load_map(map,"start");await frames(6)
	workshop=null;ui=null
	for node in get_nodes_in_group("workshop"):
		if not node.is_queued_for_deletion():workshop=node;ui=node.ui
	if workshop!=null:
		world.player.position=workshop.source.get_ref().position+Vector2(0,28);world.player.velocity=Vector2.ZERO
		await frames(3)
func start(pad:=false):
	# The real existing NPC conversation, including a deferred action after close.
	gs.start_dialogue("greta_menu" if workshop.kind=="smith" else "meer_lena_menu")
	for i in 4:
		if world.dialogue.buttons.is_empty():world.dialogue._advance();await frames(2)
	var buttons: Array=world.dialogue.buttons
	for b in buttons:
		if b.text.begins_with("Samen"):
			b.grab_focus();await tap(pad,JOY_BUTTON_A if pad else KEY_ENTER);break
	await frames(4)
	check(ui.active and not world.dialogue.active and gs.ui_owners.has("work_together"),"NPC menu opens work after dialogue releases its input owner")
func smith_steps(pad:=false):
	await tap(pad,JOY_BUTTON_DPAD_RIGHT if pad else KEY_RIGHT);await tap(pad,JOY_BUTTON_DPAD_RIGHT if pad else KEY_RIGHT)
	check(ui.alignment==0,"directional controls align the loose jaw")
	ui.primary.grab_focus();await tap(pad,JOY_BUTTON_A if pad else KEY_ENTER)
	check(ui.stage==1,"confirm enters pressure adjustment")
	await tap(pad,JOY_BUTTON_DPAD_RIGHT if pad else KEY_RIGHT)
	ui.primary.grab_focus();await tap(pad,JOY_BUTTON_A if pad else KEY_ENTER)
	await frames(100)
func leaves_and_mix(pad:=false):
	ui.leaves[0].grab_focus();await tap(pad,JOY_BUTTON_A if pad else KEY_ENTER)
	ui.leaves[3].grab_focus();await tap(pad,JOY_BUTTON_A if pad else KEY_ENTER)
	check(ui.selected.size()==2,"keyboard/controller choose both whole leaves")
	ui.primary.grab_focus();await tap(pad,JOY_BUTTON_A if pad else KEY_ENTER);await frames(100)
	check(ui.stage==1 and not ui.working,"mortar animation ends before the paid bottling decision")
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	# Headless starts with a tiny physical window; native pointer events use window pixels.
	root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_flag("op_greta")
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12)
	for id in ["village","forest_edge","forest","lake"]:
		await enter(id)
		check(workshop==null,"no new activity/actor on the outdoor route: "+id)
		if id=="forest":check(get_nodes_in_group("enemies").filter(func(n):return n.data.behavior!="animal").size()==18,"phase-one enemy reduction preserved")
		if id=="forest_edge":check(world.map_data.objects.filter(func(o):return not o.get("trail_wildlife",false) and not o.get("id","").begins_with("trail:") and not o.get("id","").begins_with("forestfood:")).size()==5 and world.map_data.objects.filter(func(o):return o.type=="enemy" and not o.get("trail_wildlife",false)).is_empty(),"quiet meadow only adds a scenic waterfall beside exits and wayfinding")
	check(load("res://scripts/data/quests.gd").QUESTS.size()==load("res://scripts/core/journey.gd").TARGETS.size(),"quest list still matches the unchanged journey targets")
	await enter("smithy")
	var objects: int=world.map_data.objects.size();var bodies: int=world.entities.get_child_count()
	await start();ui.primary.grab_focus();await tap(false,KEY_ENTER)
	check(ui.stage==0 and not gs.flag("wt_smith_done"),"misaligned clamp cannot award the repair")
	await smith_steps()
	check(ui.finished and gs.flag("wt_smith_done") and gs.flag("pg_smith_notes") and Prof.xp("smithing")==6,"first repair persists, teaches existing pattern and awards six XP once")
	check(world.map_data.objects.size()==objects and world.entities.get_child_count()==bodies,"collaboration adds no floor bodies or saved object slots")
	var flags: Dictionary=gs.flags.duplicate();var xp: int=Prof.xp("smithing")
	ui.primary.grab_focus();await tap(false,KEY_ENTER);await smith_steps(true)
	check(gs.flags==flags and Prof.xp("smithing")==xp,"repeated clamp practice grants no extra flags or XP")
	ui.close();await start(true)
	await tap(true,JOY_BUTTON_DPAD_RIGHT);await tap(true,JOY_BUTTON_B)
	check(not ui.active and not gs.input_locked(),"controller cancellation releases work ownership")
	gs.set_flag("met_greta");gs.set_flag("greta_star_seen")
	for weapon in ["crystal","star"]:
		gs.weapon=weapon
		workshop.source.get_ref().interact()
		for i in 8:
			if world.dialogue.buttons.is_empty():world.dialogue._advance();await frames(2)
		var offered:=false
		for b in world.dialogue.buttons:
			if b.text.begins_with("Samen"):offered=true;b.grab_focus();await tap(false,KEY_ENTER);break
		check(offered and ui.active,"real Greta interaction stays available with "+weapon+" weapon")
		ui.close()
	gs.weapon="wood"
	await start();await click(ui.right);await click(ui.right);await click(ui.primary)
	print("POINTER alignment=",ui.alignment," stage=",ui.stage," mouse=",root.get_mouse_position()," scale=",root.content_scale_factor)
	await click(ui.right);await click(ui.primary);await frames(100)
	print("POINTER pressure=",ui.pressure," stage=",ui.stage," finished=",ui.finished)
	check(ui.finished and Prof.xp("smithing")==xp,"real pointer arrows and confirm finish free practice without XP")
	ui.close()
	world.hud.banner_time=0;gs.achievement_queue.clear()
	var announcement: Node=world.hud.achievement_banner
	announcement.time=0;announcement.hinted=true;gs.achievement_queue.append("first_blood")
	await frames(36)
	check(announcement.is_showing(),"baseline achievement is visible before work begins")
	await start();var card_time: float=announcement.time
	gs.achievement_queue.append("first_blood");gs.toast.emit("pending work test notice")
	var notice_time: float=world.hud.toast_time;await frames(20)
	print("NOTIFY active=",ui.active," owners=",gs.ui_owners," busy=",announcement._screen_is_busy()," card=",card_time,"/",announcement.time," alpha=",announcement.root.modulate.a," queue=",gs.achievement_queue.size()," toast=",notice_time,"/",world.hud.toast_time," toastalpha=",world.hud.toast_panel.modulate.a)
	check(announcement.root.modulate.a==0 and is_equal_approx(announcement.time,card_time) and gs.achievement_queue.size()==1,"active card pauses and queued card waits during collaboration")
	check(world.hud.toast_panel.modulate.a==0 and is_equal_approx(world.hud.toast_time,notice_time),"ordinary notices wait behind the modal without losing time")
	ui.close();await frames(10)
	check(announcement.root.modulate.a>0 and announcement.time<card_time,"existing card resumes when work closes")
	gs.achievement_queue.clear();announcement.time=0
	await enter("library");await start()
	check(ui.primary.disabled and ui.detail.text.contains("Zilverkruid"),"missing ingredients and counts shown before preparation")
	ui.practice_button.grab_focus();await tap(false,KEY_ENTER)
	check(ui.practice,"free trial leaves are available without gathering")
	ui.leaves[1].grab_focus();await tap(false,KEY_ENTER)
	check(ui.selected.is_empty(),"bruised leaf gives feedback without consuming items")
	await leaves_and_mix(true);ui.primary.grab_focus();await tap(true,JOY_BUTTON_A)
	check(ui.finished and not gs.flag("wt_alchemy_done") and not gs.flag("pg_focus_notes") and Prof.xp("alchemy")==0 and gs.count("potion")==0,"practice changes no inventory, pattern or XP")
	ui.close();gs.give("prof_herb",4,true);gs.give("gel",2,true)
	await start(true);await leaves_and_mix(true)
	await tap(true,JOY_BUTTON_B)
	check(gs.count("prof_herb")==4 and gs.count("gel")==2 and gs.count("potion")==0,"cancelling mixed preparation keeps every ingredient")
	await start();await leaves_and_mix();ui.primary.grab_focus();await tap(false,KEY_ENTER)
	check(gs.count("prof_herb")==2 and gs.count("gel")==1 and gs.count("potion")==1 and Prof.xp("alchemy")==10,"bottling uses exact existing recipe costs/output/XP")
	check(gs.flag("wt_alchemy_done") and gs.flag("pg_focus_notes"),"first real preparation teaches existing lens pattern and changes table")
	await tap(false,KEY_ENTER)
	check(gs.count("potion")==1,"same confirmation cannot bottle twice")
	ui.close();await start();await leaves_and_mix();gs.take("prof_herb",2)
	ui.act();check(gs.count("potion")==1 and gs.count("gel")==1,"ingredients revalidated at final commit")
	ui.close();gs.give("prof_herb",2,true);gs.give("potion",100,true)
	await start();check(ui.primary.disabled,"full potion stack prevents preparation and material loss");ui.close()
	var saved: Vector2=world.player.position;gs.save_game(saved);gs.flags.clear()
	check(gs.load_game() and gs.flag("wt_smith_done") and gs.flag("wt_alchemy_done"),"actual save/load preserves both workplace changes")
	await enter("smithy");check(workshop.station_frame()==1,"repaired clamp remains visible after reload")
	await start();ui.alignment=0;ui.act();ui.pressure=1;ui.act();await frames(20)
	await enter("forest_edge");await frames(100)
	check(not gs.ui_owners.has("work_together") and Prof.xp("smithing")==6,"map change during animation cannot retain UI or award another repair")
	gs.new_game();gs.in_game=true;gs.set_flag("op_greta");await enter("smithy")
	check(not gs.flag("wt_smith_done") and workshop.station_frame()==0,"new game resets workplace decoration")
	await start()
	var sizes: Array[Vector2i]=[Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]
	for size in sizes:
		root.size=size;root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;await frames(8)
		var rect: Rect2=ui.panel.get_global_rect()
		check(rect.position.x>=12 and rect.position.y>=12 and rect.end.x<=size.x-12 and rect.end.y<=size.y-12,"work panel fits actual viewport: "+str(size))
	ui.close();world.queue_free();await frames()
	print("WORK TOGETHER OK" if failures==0 else "WORK TOGETHER FAILED: %d"%failures)
	quit(0 if failures==0 else 1)
