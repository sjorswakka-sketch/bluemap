extends "res://tests/coast_expedition_test.gd"
const Tide:=preload("res://scripts/core/tides.gd")
func routes() -> Node:
	for ui in get_nodes_in_group("coast_routes"):
		if not ui.is_queued_for_deletion():return ui
	return null
func station(role: String,east:=false) -> Node2D:
	for node in get_nodes_in_group("tide_stations"):
		if not node.is_queued_for_deletion() and node.obj.role==role and (role!="line" or (node.obj.pos[0]>25)==east):return node
	return null
func tide() -> Node:
	for node in get_nodes_in_group("tide_cove"):
		if not node.is_queued_for_deletion():return node
	return null
func open_station(role: String,east:=false,pad:=false):
	var node:=station(role,east);p.position=node.position+Vector2(0,30)
	await frames(5);await tap(JOY_BUTTON_A if pad else KEY_E,pad)
	check(routes().active,"native interaction opens "+role)
func clock(seconds: float):
	gs.day_time=seconds/480.0
	if tide()!=null:tide().sync()
func key_hold(code: int,down: bool):
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);await frames(2)
func axis(value: float):
	var e:=InputEventJoypadMotion.new();e.axis=JOY_AXIS_LEFT_X;e.axis_value=value;Input.parse_input_event(e);await frames(2)
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true;clock(20)
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
	check(Journey.path("tide_cove","village")==["tide_cove","coast","lake","village"],"walking and ferry graph keeps a permanent route home")
	check(Tide.state(20.0/480)=="low" and Tide.state(54.0/480)=="rising" and Tide.state(70.0/480)=="high" and Tide.state(90.0/480)=="falling","four readable tide stages")
	# Walk the real connection in each direction.
	await enter("gull_island","from_cove");p.position=Vector2(44.5,23.5)*32
	Input.action_press("move_right")
	for i in 90:
		await physics_frame
		if gs.map_id=="tide_cove":break
	release();await frames(40)
	check(gs.map_id=="tide_cove" and world.spawn_fits(p.position),"native movement crosses raised island connection")
	var hp: int=gs.hp
	var coins: int=gs.coins
	check(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("pickups").is_empty(),"new route has no enemies or collecting pressure")
	clock(20);p.position=Vector2(19.5,25.5)*32
	await walk_to(Vector2(32.5,25.5)*32)
	check(not tide().flooded and world.spawn_fits(p.position),"low-water sandbank is physically walkable")
	clock(20);p.position=Vector2(25.5,25.5)*32;await frames()
	clock(54);check(not tide().flooded and Tide.label(gs.day_time).contains("water"),"rising water warns before closing")
	clock(70);check(tide().held and not tide().flooded and not world.is_solid(p.position),"high tide does not close collision around an occupied bank")
	await walk_to(Vector2(32.5,25.5)*32);await frames(5)
	check(tide().flooded and world.is_solid(Vector2(25.5,25.5)*32),"bank actually closes after safe exit")
	p.position=Vector2(32.5,25.5)*32
	Input.action_press("move_left")
	for i in 75:await physics_frame
	release();check(p.position.x>32*32 and not world.is_solid(p.position+Vector2(0,8)),"high-water collision really blocks walking into water")
	await route_to(Vector2i(18,25))
	check(p.position.x<20*32 and gs.hp==hp,"high loop really returns from east to west with no waiting or damage")
	# Native input, disabled requirement and safe cancellation.
	await open_station("line")
	var ui:=routes()
	check(ui.buttons[0].disabled and ui.detail.text.contains("leenkist"),"missing line is explained before a disabled crossing action")
	ui.start_crossing();check(not ui.crossing,"direct action also checks missing tool")
	ui.borrow();check(gs.count("td_line")==0,"line post cannot act as loan chest")
	await click(ui.back);check(not gs.input_locked(),"native mouse closes missing-tool panel and releases input")
	await open_station("kit",false,true);ui=routes();ui.buttons[0].grab_focus();await tap(JOY_BUTTON_A,true);await frames()
	ui.borrow();check(gs.count("td_line")==1 and gs.coins==coins,"borrow is free and repeated activation cannot duplicate tool")
	await tap(JOY_BUTTON_B,true)
	await open_station("line");ui=routes()
	var original: Vector2=p.position
	ui.start_crossing();ui.set_process(false);ui._process(0.4)
	check(ui.crossing and p.position.x>original.x,"line crossing is visibly animated")
	await tap(KEY_ESCAPE);ui.set_process(true);check(p.position.distance_to(original)<1 and gs.count("td_line")==1 and not gs.input_locked(),"cancel mid-line safely returns with tool retained")
	await open_station("line",false,true);ui=routes();ui.buttons[0].grab_focus();await tap(JOY_BUTTON_A,true);await frames(85)
	check(p.position.x>32*32 and world.spawn_fits(p.position) and gs.count("td_line")==1,"controller activates reusable line to safe eastern shore at high water")
	await open_station("line",true);ui=routes();ui.start_crossing();await frames(85)
	check(p.position.x<20*32 and gs.count("td_line")==1,"same tool works on return without consumption")
	# Tides and old completion/collection state survive a real reload.
	clock(70);gs.set_flag("game_completed");gs.set_flag("chest:lake:26");gs.save_game(Vector2(25.5,25.5)*32)
	check(gs.load_game() and gs.count("td_line")==1 and gs.flag("game_completed") and gs.flag("chest:lake:26"),"existing save format retains tide clock, tool and completed-game flags")
	world.queue_free();await frames(6);gs.in_game=true
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(14);p=world.player
	check(gs.map_id=="tide_cove" and tide().flooded and world.spawn_fits(p.position) and not Tide.BANK.has_point(Vector2i(p.position/32)),"reload on flooded bank resolves to a real dry shore")
	# All published arrival spawns remain safe in every tide stage.
	for seconds in [20,54,70,90]:
		clock(seconds);await enter("tide_cove","from_coast")
		check(world.spawn_fits(p.position),"arrival is dry at tide second "+str(seconds))
	# Sandbox steering has momentum, collision and no world consequences.
	await open_station("kit");ui=routes();ui.start_sailing()
	var before: Dictionary=gs.inventory.duplicate(true)
	var world_pos: Vector2=p.position
	var old_time: float=gs.day_time
	var before_boat: Vector2=ui.boat
	await key_hold(KEY_D,true);await frames(20);await key_hold(KEY_D,false)
	check(ui.boat.x>before_boat.x+15 and p.position==world_pos,"native keyboard steers prototype while world stays still")
	await frames(30);check(ui.boat_velocity.length()<1,"releasing steering brakes smoothly")
	await axis(1);await frames(20);await axis(0)
	check(root.get_node("Controls").controller_active and ui.back.mouse_filter==Control.MOUSE_FILTER_IGNORE,"left stick steers and switches prototype exclusively to controller")
	ui.boat=Vector2(200,45);ui.boat_velocity=Vector2.ZERO
	Input.action_press("move_right")
	for i in 60:ui.steer(1.0/60.0)
	release();check(ui.boat.x<221,"prototype rocks stop boat collision without damage")
	ui.boat=Vector2(580,90);ui.boat_velocity=Vector2(150,0);ui.steer(1)
	check(ui.boat.x<=ui.preview.size.x-24,"prototype cannot leave its test harbour")
	check(gs.inventory==before and gs.day_time==old_time and gs.hp==hp and gs.coins==coins,"prototype pauses tide and has no inventory health or money effects")
	await tap(JOY_BUTTON_B,true);check(not ui.active and not gs.input_locked(),"controller exits prototype to same dry landing")
	# Route board offers actual destinations, fits and can be cancelled.
	await enter("coast","from_island");await open_station("routes");ui=routes()
	for locale in ["nl","en"]:
		root.get_node("Lang").set_language(locale,false)
		for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
			root.size=size;await frames(4);ui.layout()
			check(Rect2(Vector2.ZERO,Vector2(size)).encloses(ui.panel.get_global_rect()),"destination panel fits "+locale+str(size))
	root.size=Vector2i(1152,648);root.get_node("Lang").set_language("nl",false)
	ui.buttons[1].grab_focus();await tap(KEY_ENTER);await frames(3)
	check(voyage().active and voyage().target=="tide_cove" and not ui.active,"destination choice starts validated free cove ferry")
	voyage().set_process(false);await tap(KEY_ESCAPE)
	check(gs.map_id=="coast" and not gs.input_locked() and gs.inventory==before,"cancel destination voyage preserves resources")
	await open_station("routes");ui=routes();ui.choose_route(station("routes").obj.routes[1])
	voyage().depart();await frames(65)
	check(gs.map_id=="tide_cove" and world.spawn_fits(p.position),"selected cove destination really arrives on dry land")
	p.position=Vector2(3.5,26.5)*32;await frames(4)
	Input.action_press("move_left")
	for i in 95:
		await physics_frame
		if gs.map_id=="gull_island":break
	release();await frames(40)
	check(gs.map_id=="gull_island" and world.spawn_fits(p.position),"actual cove boardwalk also returns safely to island")
	await enter("tide_cove","from_coast")
	await open_station("kit");world.load_map("coast","from_island");await frames(7)
	check(not gs.ui_owners.has("td_routes"),"forced map unload releases regional UI")
	gs.new_game();check(gs.count("td_line")==0,"new game resets borrowed tool")
	world.queue_free();await frames()
	print("TIDES OK" if failures==0 else "TIDES FAILED "+str(failures));quit(0 if failures==0 else 1)
