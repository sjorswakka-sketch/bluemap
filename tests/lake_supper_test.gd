extends SceneTree
const Supper:=preload("res://scripts/core/lake_supper.gd")
const Professions:=preload("res://scripts/core/professions.gd")
var world: Node2D
var gs: Node
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	print("  ok   " if ok else "  FAIL ",message)
	if not ok: failures+=1
func frames(n:=3) -> void:
	for i in n: await process_frame
func object(kind: String) -> Node2D:
	for node in get_nodes_in_group("supper_objects"):
		if node.kind==kind: return node
	return null
func close() -> void:
	world.dialogue._close()
	await frames()
func enter(map: String) -> void:
	world.load_map(map,"start")
	await frames(5)
	world.player.invuln=1000
func key(pad:=false) -> void:
	for down in [true,false]:
		if pad:
			var event:=InputEventJoypadButton.new()
			event.button_index=JOY_BUTTON_A
			event.pressed=down
			Input.parse_input_event(event)
		else:
			var event:=InputEventKey.new()
			event.keycode=KEY_E
			event.physical_keycode=KEY_E
			event.pressed=down
			Input.parse_input_event(event)
		await frames(2)
func use(node: Node2D,pad:=false,offset:=Vector2(0,32)) -> void:
	world.player.position=node.position+offset
	world.player.velocity=Vector2.ZERO
	await frames()
	world.player._update_target()
	check(world.player.target==node,"normale selectie bereikt "+node.kind)
	await key(pad)
func choices() -> void:
	for i in 12:
		if not world.dialogue.buttons.is_empty(): return
		world.dialogue._advance()
		await frames()
func audit(map: String) -> void:
	var director: Node2D=get_first_node_in_group("lake_supper")
	var start:=Vector2i(world.map_data.spawns.start[0],world.map_data.spawns.start[1])
	for node in get_nodes_in_group("supper_objects"):
		var cell:=Vector2i(node.position/32)
		var reachable:=false
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var to: Vector2i=cell+offset
			if director.grid.is_in_boundsv(to) and not director.grid.is_point_solid(to) and not director.grid.get_id_path(start,to).is_empty(): reachable=true
		check(reachable,map+": interactieplek bereikbaar "+node.kind)
		for spec: Dictionary in world.map_data.objects:
			if spec.type in ["npc","sign","chest","profession_resource","portal","wereld_bed"]:
				check(cell!=Vector2i(spec.pos[0],spec.pos[1]),map+": geen overlap "+node.kind)
func walk(at: Vector2) -> void:
	var goal:=at*32
	for i in 330:
		var offset: Vector2=goal-world.player.position
		for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
		if offset.length()<5: break
		if absf(offset.x)>3: Input.action_press("move_right" if offset.x>0 else "move_left")
		if absf(offset.y)>3: Input.action_press("move_down" if offset.y>0 else "move_up")
		await physics_frame
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	await frames()
	check(world.player.position.distance_to(goal)<8,"echt lopen bereikt "+str(at))
func run() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):
		quit(1)
		return
	await frames()
	gs=root.get_node("GameState")
	gs.new_game()
	gs.in_game=true
	world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	await frames(8)
	await enter("lake")
	audit("lake")
	check(not gs.flag("ls_basket") and gs.quest_state("ls_supper")=="none","nieuwe optionele quest start niet vanzelf")
	var basket:=object("basket")
	await use(basket,false,Vector2(32,0))
	check(not basket.pulling,"mand vereist Joris' hengel")
	await close()
	gs.give("fishing_rod",1,true)
	await use(basket,true,Vector2(32,0))
	check(basket.pulling,"controller start binnenhalen")
	basket._process(0.5)
	world.player.position+=Vector2(0,16)
	basket._process(0.1)
	check(not basket.pulling and gs.count("ls_crate")==0,"weglopen breekt binnenhalen af zonder beloning")
	await use(basket,false,Vector2(32,0))
	basket._process(1.9)
	check(gs.count("ls_crate")==1 and gs.quest_step("ls_supper")==1,"gevangen mand zet kookstap klaar")
	basket.interact()
	basket._process(2)
	check(gs.count("ls_crate")==1,"mand is maar eenmaal te krijgen")
	var net:=object("net")
	await use(net,true)
	await choices()
	world.dialogue.buttons[1].pressed.emit()
	await choices()
	check(net.stitch==0 and not gs.flag("ls_net"),"verkeerde weefsteek geeft herstelbare feedback")
	for choice in [0,1,0]:
		world.dialogue.buttons[choice].pressed.emit()
		await choices()
	await close()
	check(gs.flag("ls_net") and gs.count("meer_baars")==2,"echt keuzegesprek repareert net en geeft reservevangst")
	var fish: int=gs.count("meer_baars")
	net.weave("over")
	check(gs.count("meer_baars")==fish,"netbeloning kan niet dubbel")
	var joris: Node2D
	for actor in get_nodes_in_group("supper_actors"):
		if actor.npc_id=="meer_joris": joris=actor
	world.player.position=Vector2(21.5,3.5)*32
	gs.day_time=0.4
	joris.wait_time=0
	joris.route_index=1
	await frames(620)
	check(joris.position.distance_to(Vector2(18.5,11.5)*32)<16,"Joris loopt echt naar het nettenrek")
	gs.day_time=0.9
	await frames(1250)
	check(joris.position.distance_to(Vector2(10.5,9.5)*32)<16,"Joris bereikt zijn avondplek zonder blokkades")
	await enter("inn")
	audit("inn")
	await walk(Vector2(14.5,8.5))
	await walk(Vector2(14.5,7.5))
	await use(object("stove"),true)
	var ui: Node=world.get_node("SupperKitchen")
	check(ui.active and paused,"fornuis opent toegankelijke kookinterface en pauzeert wereld")
	ui.select_dish("ls_chowder")
	ui.prepare_step()
	ui._process(1)
	ui.close()
	check(gs.count("ls_crate")==1 and gs.count("ls_chowder")==0,"koken afbreken bewaart alle ingrediënten")
	await use(object("stove"),true)
	ui.choices[0].grab_focus()
	await key(true)
	check(ui.dish=="ls_chowder","controller kiest gerecht via echte focus")
	for i in 3:
		ui.action_button.grab_focus()
		await key(true)
		check(ui.working,"controller start bereidingsstap "+str(i))
		ui._process(1)
	check(gs.count("ls_crate")==0 and gs.count("ls_chowder")==2 and gs.flag("ls_cooked"),"snijden, roeren en opscheppen levert precies twee porties")
	ui.close()
	await frames()
	gs.hp=gs.max_hp()
	gs.movement.stamina=0
	check(Professions.use_item("ls_chowder") and gs.movement.stamina>0,"gecombineerd gerecht werkt ook bij volle hartjes en lege stamina")
	gs.hp-=1
	check(Professions.use_item("ls_chowder") and gs.count("ls_chowder")==0,"speler kan beide eerste porties opeten")
	check(not Professions.craft("ls_chowder"),"receptenboek wacht op gezamenlijk eten")
	await use(object("stove"))
	ui.select_dish("ls_chowder")
	for i in 3:
		ui.action_button.grab_focus()
		await key()
		check(ui.working,"toetsenbord start opnieuw bereiden met gewone ingrediënten")
		ui._process(1)
	ui.close()
	await frames()
	check(gs.count("ls_chowder")==1 and gs.count("meer_baars")==0,"opgegeten porties blokkeren de quest niet; reservevis wordt opnieuw gekookt")
	await walk(Vector2(16.5,7.5))
	await walk(Vector2(18.5,7.5))
	gs.day_time=0.4 # verify daytime arrivals as well as Joris' evening work route
	await use(object("table"),true)
	await choices()
	world.dialogue.buttons[0].grab_focus()
	await key(true)
	await close()
	world.player.position=Vector2(14.5,8.5)*32
	await frames(800)
	check(gs.quest_state("ls_supper")=="done" and gs.count("ls_chowder")==0,"één portie delen rondt maaltijd af")
	check(get_nodes_in_group("supper_actors").size()==3,"Joris, Bo en Nelle verschijnen samen in de herberg")
	for actor in get_nodes_in_group("supper_actors"):
		check(actor.position.distance_to(actor.route().back()*32)<16,"gast bereikt eigen vrije plek: "+actor.role)
		for other in get_nodes_in_group("supper_actors"):
			if other!=actor: check(actor.position.distance_to(other.position)>28,"gasten zitten zonder visuele overlap")
	var xp: int=gs.hero_xp
	object("table").share("ls_chowder")
	check(gs.hero_xp==xp,"maaltijd geeft geen dubbele quest-XP")
	gs.set_flag("cat_found")
	gs.set_flag("rf_memorial")
	gs.set_flag("op_water")
	check(Supper.conversation("bo").size()==4,"gesprekken reageren op kat, gedenksteen en fontein")
	gs.give("meer_baars",2,true)
	gs.give("prof_herb",1,true)
	check(Professions.craft("ls_chowder"),"blijvend recept gebruikt gewone vis en kruiden")
	gs.hp=gs.max_hp()
	gs.movement.stamina=gs.movement.capacity()
	check(not Professions.use_item("ls_chowder"),"volle gezondheid én stamina verspillen geen gerecht")
	gs.save_game(world.player.position)
	gs.new_game()
	check(gs.load_game() and gs.flag("ls_served") and gs.flag("ls_net"),"maaltijd en net blijven bewaard na laden")
	await enter("inn")
	check(get_nodes_in_group("supper_actors").size()==3,"terugkeren herstelt gedekte tafel en bewoners")
	# A player at the table should not block the guests' only route to their seats.
	world.player.position=Vector2(18.5,6.5)*32
	await frames(1000)
	for actor in get_nodes_in_group("supper_actors"):
		check(actor.position.distance_to(actor.route().back()*32)<16,"gasten vinden hun stoel ook met speler naast tafel: "+actor.role)
	await enter("lake")
	check(not object("basket").visible and not object("basket").is_in_group("interactable"),"opgehaalde mand blijft weg")
	# Simulate a legacy save: no supper flags, old quests and inventory stay intact.
	gs.new_game()
	gs.flags.clear()
	gs.give("meer_gouden_karper",1,true)
	gs.start_quest("meer_karper")
	gs.finish_quest("meer_karper")
	world.load_map("inn","start",Vector2(14.5,6.5)*32)
	await frames()
	check(world.player.position.distance_to(object("stove").position)>35,"oude savepositie wordt vrij van nieuw fornuis gezet")
	check(gs.quest_state("meer_karper")=="done" and gs.count("meer_gouden_karper")==1 and not gs.flag("ls_served"),"oude voortgang behouden, nieuwe maaltijd blijft optioneel")
	world.queue_free()
	await frames()
	print("LAKE SUPPER TEST OK" if failures==0 else "LAKE SUPPER TEST FAILED: "+str(failures))
	quit(0 if failures==0 else 1)
