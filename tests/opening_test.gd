extends SceneTree
const Opening := preload("res://scripts/core/opening.gd")
var gs: Node
var world: Node2D
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("  ok   " if ok else "  FAIL ",label)
	if not ok: failures+=1
func frames(n:=3) -> void:
	for i in n: await process_frame
func close_dialogue() -> void:
	world.dialogue._close()
	await frames()
func tap(pad: bool) -> void:
	for down in [true,false]:
		if pad:
			var e := InputEventJoypadButton.new()
			e.button_index = JOY_BUTTON_A
			e.pressed = down
			Input.parse_input_event(e)
		else:
			var e := InputEventKey.new()
			e.keycode = KEY_E
			e.physical_keycode = KEY_E
			e.pressed = down
			Input.parse_input_event(e)
		await frames(3)
func use(node: Node2D,pad:=false) -> void:
	world.player.position = node.position+Vector2(0,27)
	await frames(4)
	world.player._update_target()
	check(world.player.target==node,"normale interactie bereikt "+node.name)
	await tap(pad)
func _run() -> void:
	await frames()
	gs=root.get_node("GameState")
	gs.new_game()
	gs.in_game=true
	world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	await frames(12)
	var director: Node2D=get_first_node_in_group("village_opening")
	var fountain: Node2D=get_first_node_in_group("fountains")
	var devices:=get_nodes_in_group("opening_devices")
	var grate: Node2D=devices[0]
	var wheel: Node2D=devices[1]
	check(Opening.enabled() and not Opening.flowing() and fountain.water_strength<0.2,"nieuw avontuur begint met sputterende fontein")
	check(not world.hud.xp_bar.visible and not world.hud.clock.visible and not world.hud.stats.visible,"eerste HUD toont geen lege voortgangsmeters")
	check(world.hud.opening_hint.visible and world.hud.toast_queue.is_empty(),"één bedieningshint zonder stapel introductiemeldingen")
	check(world.hud.tracker.text.contains("Nelle"),"eerste doel verwijst naar zichtbare dorpsbewoner")
	for actor in get_nodes_in_group("opening_actors"):
		check(actor is CharacterBody2D and actor.collision_mask==3 and actor.get_parent()==world.entities,"bewoner gebruikt botsing en y-sortering")
		for point: Vector2 in actor.route():
			var route: PackedVector2Array=director.grid.get_point_path(Vector2i(actor.position/32),Vector2i(point))
			check(not route.is_empty(),"dagbestemming bereikbaar zonder deuren of fontein te kruisen")
	await use(wheel)
	check(not gs.flag("op_water"),"sluis weigert openen zolang rooster verstopt is")
	await close_dialogue()
	await use(grate)
	check(not grate.working and gs.count("op_rake")==0,"hark is echt vereist")
	await close_dialogue()
	await use(director.gardener,true)
	check(gs.count("op_rake")==1 and gs.quest_state("first_water")=="active","controller leent hark en start de opdracht")
	await close_dialogue()
	await use(grate,true)
	check(grate.working,"controller start zichtbare gereedschapsactie")
	grate._process(0.4)
	world.player.position+=Vector2(100,0)
	grate._process(0.1)
	check(not grate.working and not gs.flag("op_grate"),"weglopen onderbreekt harken zonder gratis voltooiing")
	await use(grate)
	grate.set_process(false)
	grate._process(1.7)
	check(gs.flag("op_grate") and gs.quest_step("first_water")==1,"harken maakt rooster vrij en onthult teken")
	gs.save_game(world.player.position)
	gs.flags.clear()
	check(gs.load_game() and gs.flag("op_grate") and gs.count("op_rake")==1,"tussenstap en geleende hark blijven opgeslagen")
	await use(wheel)
	check(gs.flag("op_water") and gs.count("op_rake")==0 and gs.coins==12,"waterherstel geeft eenmalige beloning en retourneert hark")
	wheel.interact()
	check(gs.coins==12,"herhalen kan beloning niet dupliceren")
	fountain._process(2)
	await frames(6)
	check(fountain.water_strength==1 and director.water_audio.playing,"zichtbaar water en plaatselijk watergeluid komen terug")
	check(director.gardener.route()[0]==Vector2(14.5,15.5),"hovenier hervat werk bij de bloemen")
	var before: Vector2=director.courier.position
	world.player.position=Vector2(24.5,20.5)*32
	await frames(1000)
	check(director.courier.position.distance_to(before)>10,"bezorger beweegt werkelijk door het dorp")
	check(director.gardener.position.distance_to(Vector2(14.5,15.5)*32)<40,"hovenier bereikt de bloembakken via de vrije route")
	gs.day_time=0.9
	check(director.courier.route()==[Vector2(7.5,13.5)],"avond schakelt bezorger naar rustplek")
	gs.day_time=0.4
	gs.save_game(world.player.position)
	check(gs.load_game() and Opening.flowing(),"herstelde fontein blijft na laden hersteld")
	world.load_map("smithy","start")
	await frames(5)
	var greta: Node2D
	for npc in get_nodes_in_group("npc"):
		if npc.npc_id=="greta": greta=npc
	await use(greta)
	check(gs.quest_state("first_water")=="done" and gs.flag("op_greta"),"Greta verbindt opening aan bestaande prismaverhaallijn")
	await close_dialogue()
	var xp: int=gs.hero_xp
	greta.interact()
	check(not world.dialogue.lines.is_empty() and gs.hero_xp==xp,"normale smederijdialoog blijft daarna beschikbaar")
	await close_dialogue()
	# Simuleer een 0.8-save: geen introductievlag, geen opdracht afpakken.
	gs.flags.erase("op_new_adventure")
	gs.save_game(world.player.position)
	check(gs.load_game() and not Opening.enabled() and Opening.flowing(),"oude save krijgt geen kapotte fontein of gedwongen tutorial")
	world.load_map("village","start")
	await frames(5)
	check(get_nodes_in_group("opening_devices").is_empty() and world.hud.xp_bar.visible,"oude save houdt gewone HUD en krijgt alleen dorpsleven")
	world.load_map("village","start",Vector2(14.5,16.5)*32)
	await frames(3)
	check(Vector2i(world.player.position/32) not in [Vector2i(14,16),Vector2i(15,16)],"oude positie in nieuwe bloembak komt veilig ernaast terecht")
	gs.new_game()
	gs.ng_plus=1
	check(not Opening.enabled(),"Nieuw spel+ hoeft introductie niet te herhalen")
	world.queue_free()
	await frames()
	print("OPENING OK" if failures==0 else "OPENING FAILED: %d"%failures)
	quit(0 if failures==0 else 1)
