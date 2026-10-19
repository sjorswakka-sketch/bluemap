extends SceneTree
const Route := preload("res://scripts/core/first_route.gd")
const RouteNPC := preload("res://scripts/entities/route_npc.gd")
var RouteAI: Script
var Director: Script
const Maps := preload("res://scripts/maps/registry.gd")
const Gear := preload("res://scripts/core/equipment.gd")
var world: Node2D
var gs: Node
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,text: String) -> void:
	print("  ok   " if ok else "  FAIL ",text)
	if not ok: failures+=1
func frames(n:=3) -> void:
	for i in n: await process_frame
func close() -> void:
	world.dialogue._close()
	await frames()
func object(id: String) -> Node2D:
	for node in get_nodes_in_group("route_objects"):
		if node.id==id: return node
	return null
func enter(map: String) -> void:
	world.load_map(map,"start")
	await frames(4)
	# Bescherm alleen de testspeler; echte vijanden en botsingen blijven aanwezig.
	world.player.invuln=1000
func use(node: Node2D,pad:=false) -> void:
	world.player.position=node.position+Vector2(0,25)
	world.player.velocity=Vector2.ZERO
	await frames(3)
	world.player._update_target()
	check(world.player.target==node,"bereikbaar via normale selectie: "+str(node.id if "id" in node else node.npc_id))
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
func audit(map: String) -> void:
	var grid:=AStarGrid2D.new()
	grid.region=Rect2i(Vector2i.ZERO,world.map_size)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for cell in world.solid_cells: grid.set_point_solid(cell)
	var start: Vector2i=Vector2i(world.map_data.spawns.start[0],world.map_data.spawns.start[1])
	for node in get_nodes_in_group("route_objects"):
		var cell:=Vector2i(node.position/32)
		check(not world.is_solid(node.position) and not grid.get_id_path(start,cell).is_empty(),map+": nieuwe plek op bereikbare vloer "+node.id)
		for spec: Dictionary in world.map_data.objects:
			if spec.type in ["chest","npc","sign","savepoint","resource","torch"]:
				check(Vector2(spec.pos[0],spec.pos[1])*32+Vector2(16,16)!=node.position,map+": geen object-overlap "+node.id)
		if map=="forest" and node.kind=="track":
			check(node.id=="rf_tracks","dynamic footprint retains the existing quest/save ID")
			var footprint:=Rect2(node.position+Vector2(-12,-12),Vector2(24,20)).grow(4)
			check(preload("res://scripts/core/forage_placement.gd").canopy_clear(world.map_data,cell),"dynamic footprint stays visible outside tree canopies "+str(cell))
			for plant in get_nodes_in_group("profession_resources"):
				var plant_art:=Rect2(plant.position+Vector2(-16,-24),Vector2(32,32)).grow(4)
				check(not footprint.intersects(plant_art),"dynamic footprint has rendered space beside actual harvest node "+str(cell)+" "+plant.resource_id)
			for portal in get_nodes_in_group("access_portals"):
				if portal.is_queued_for_deletion():continue
				check(not footprint.intersects(portal.rect.grow(8)),"dynamic footprint stays clear of the actual portal trigger "+str(cell)+" → "+portal.target_map)
			var old_pos: Vector2=world.player.position
			var old_aim: Vector2=world.player.aim_direction
			var old_stick: Vector2=world.player.stick_aim
			var controls: Node=root.get_node("Controls")
			var old_mouse: bool=controls.mouse_aim_active
			var approach: Vector2=node.position+Vector2(0,25)
			check(world.spawn_fits(approach),"all three footprints have a real free interaction stance outside gates "+str(cell))
			world.player.position=approach;world.player.aim_direction=Vector2.UP;world.player.stick_aim=Vector2.ZERO;controls.mouse_aim_active=false
			world.player._update_target()
			check(world.player.target==node,"every dynamic footprint is independently selected through the normal player target system "+str(cell))
			world.player.position=old_pos;world.player.aim_direction=old_aim;world.player.stick_aim=old_stick;controls.mouse_aim_active=old_mouse
			world.player._update_target()
	for enemy in get_nodes_in_group("enemies"):
		if enemy.kind.begins_with("rf_"): check(not world.is_solid(enemy.position),"nieuwe vijand staat vrij")
	if map=="cave":
		for p in Director.ECHO_PATH: check(not world.is_solid(p*32),"echobaken staat op vloer "+str(p))
func walk_to(at: Vector2) -> void:
	var goal:=at*32
	for i in 220:
		var offset: Vector2=goal-world.player.position
		for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
		if offset.length()<5: break
		if absf(offset.x)>3: Input.action_press("move_right" if offset.x>0 else "move_left")
		if absf(offset.y)>3: Input.action_press("move_down" if offset.y>0 else "move_up")
		await physics_frame
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	await frames(2)
	check(world.player.position.distance_to(goal)<8,"echt lopen bereikt baken zonder muur of blokkade "+str(at))
func run() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):
		quit(1)
		return
	await frames()
	RouteAI=load("res://scripts/entities/route_enemy.gd")
	Director=load("res://scripts/entities/first_route.gd")
	gs=root.get_node("GameState")
	gs.new_game()
	gs.in_game=true
	world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	await frames(8)
	await enter("forest")
	audit("forest")
	check(get_nodes_in_group("route_objects").filter(func(node):return node.kind=="track").size()==3,"all three authored cat footprints exist in the live forest")
	await use(object("rf_tracks"))
	check(gs.quest_state("kat")=="active","sporen starten zoektocht zonder vooraf verplicht gesprek")
	await close()
	var cat: Node2D
	for npc in get_nodes_in_group("npc"):
		if npc.npc_id=="muis_bos": cat=npc
	await use(cat,true)
	check(cat.route_wait and not gs.flag("cat_found"),"controller begint vertrouwen winnen; geen directe voltooiing")
	world.player.sprinting=true
	RouteNPC.update(cat,0.1)
	check(cat.route_panic>0 and cat.route_calm==0,"rennen schrikt Muis af")
	world.player.position=Vector2(10.5,31.5)*32
	RouteNPC.update(cat,1)
	check(cat.position.distance_to(world.player.position)>24,"vluchtende kat schuift niet door de speler heen")
	world.player.sprinting=false
	RouteNPC.update(cat,3)
	await use(cat)
	world.player.position+=Vector2(0,80)
	RouteNPC.update(cat,0.2)
	check(not cat.route_wait,"weglopen onderbreekt vertrouwen winnen")
	await use(cat,true)
	RouteNPC.update(cat,2.1)
	check(cat.route_calm==2,"rustig wachten wint vertrouwen")
	cat.interact()
	for i in 8:
		if world.dialogue.active: world.dialogue._advance()
		await frames()
	check(gs.flag("cat_found"),"Muis keert via bestaand verhaal naar huis")
	await close()
	await enter("ruins")
	audit("ruins")
	var memorial:=object("rf_memorial")
	memorial.remember("guide")
	check(not gs.flag("rf_memorial"),"gedenksteen weigert te vroege voltooiing")
	for id in ["rf_relief","rf_journal"]:
		await use(object(id),true)
		await close()
	check(gs.quest_step("rf_memory")==1,"twee aanwijzingen reconstrueren de vlucht naar de grot")
	gs.start_quest("medaillon")
	await enter("cave")
	audit("cave")
	var end:=object("rf_echo_end")
	await use(end)
	check(not end.listening,"laatste klankschaal kan niet als eerste worden voltooid")
	await close()
	var begin:=object("rf_echo_begin")
	await use(begin,true)
	begin._process(0.6)
	world.player.position+=Vector2(15,0)
	begin._process(0.1)
	check(not begin.listening and not gs.flag("rf_echo_begin"),"luisteren vereist stil blijven staan")
	for id in ["rf_echo_begin","rf_echo_mid","rf_echo_end"]:
		if id=="rf_echo_mid":
			for at in Director.ECHO_PATH.slice(0,7): await walk_to(at)
		elif id=="rf_echo_end":
			for at in Director.ECHO_PATH.slice(7,11): await walk_to(at)
		for foe in get_nodes_in_group("enemies"):
			if foe.kind=="rf_listener": check(foe.state=="idle","stil pad passeert slapende luisteraar")
		var bowl:=object(id)
		await use(bowl,true)
		bowl._process(1.6)
		check(gs.flag(id),"klankschaal voltooid "+id)
	check(gs.quest_state("rf_echo")=="done" and gs.count("gear_rf_cord")==1,"grot heeft eigen gedragen uitrustingsbeloning")
	var xp: int=gs.hero_xp
	end.interact()
	end._process(1.6)
	check(gs.hero_xp==xp and gs.count("gear_rf_cord")==1,"schalen geven geen dubbele beloning")
	var listener: Node2D
	for foe in get_nodes_in_group("enemies"):
		if foe.kind=="rf_listener": listener=foe
	listener.set_physics_process(false)
	world.player.position=listener.position+Vector2(65,0)
	world.player.sprinting=false
	world.player.attack_timer=0
	world.player.roll_timer=0
	world.player.bow_anim=0
	listener.state="idle"
	listener.state_time=2
	listener.flash=0
	RouteAI.update(listener,0.1)
	check(listener.state=="idle","rustig bewegen wekt luisteraar niet")
	world.player.sprinting=true
	RouteAI.update(listener,0.1)
	check(listener.state=="rf_warn","hard geluid begint zichtbare aanloop")
	var aim: Vector2=listener.aim_dir
	world.player.position+=Vector2(0,60)
	listener.state_time=0.9
	RouteAI.update(listener,0.1)
	check(listener.state=="rf_jump" and listener.aim_dir==aim,"sprong mikt op gehoord geluid en volgt speler niet heimelijk")
	world.player.sprinting=false
	gs.give("medallion",1,true)
	await enter("ruins")
	gs.start_dialogue("wilfred_return")
	for i in 10:
		if world.dialogue.active: world.dialogue._advance()
		await frames()
	await close()
	check(gs.quest_state("medaillon")=="done" and gs.count("shard")==2,"oude medaillonbeloning blijft intact")
	check(gs.quest_step("rf_memory")==2,"afgeronde medaillonopdracht werkt vervolgdoel meteen bij")
	memorial=object("rf_memorial")
	await use(memorial,true)
	Route.choose("guide")
	check(gs.flag("rf_guide") and gs.flag("rf_memorial") and gs.count("gear_rf_keepsake")==1,"keuze krijgt eigen blijvende inscriptie en ring")
	xp=gs.hero_xp
	memorial.remember("guard")
	check(not gs.flag("rf_guard") and gs.hero_xp==xp,"herhalen verandert keuze noch XP")
	await close()
	check(Gear.slot_of("gear_rf_keepsake")=="ring" and Gear.slot_of("gear_rf_cord")=="neck","nieuwe spullen sluiten aan op echte uitrustingsslots")
	gs.save_game(world.player.position)
	gs.flags.clear()
	check(gs.load_game() and gs.flag("rf_guide") and gs.flag("rf_echo_end"),"verhaal, keuze en bakens blijven na laden bestaan")
	world.load_map("ruins","start",Vector2(12.5,30.5)*32)
	await frames()
	check(world.player.position.distance_to(object("rf_memorial").position)>=25,"oude savepositie in gedenksteen wordt vrij geplaatst")
	gs.new_game()
	gs.start_quest("medaillon")
	gs.finish_quest("medaillon")
	xp=gs.hero_xp
	Route.migrate()
	check(gs.flag("rf_memorial") and gs.hero_xp==xp and gs.count("gear_rf_keepsake")==0,"oude voltooide quest krijgt decor zonder dubbele beloning")
	world.queue_free()
	await frames()
	print("FIRST ROUTE OK" if failures==0 else "FIRST ROUTE FAILED: %d"%failures)
	quit(0 if failures==0 else 1)
