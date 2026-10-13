extends SceneTree
const Region:=preload("res://scripts/core/regional_adventures.gd")
const Maps:=preload("res://scripts/maps/registry.gd")
const Tiles:=preload("res://scripts/data/tiles.gd")
const Equipment:=preload("res://scripts/core/equipment.gd")
var gs: Node
var world: Node2D
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	print("  ok   " if ok else "  FAIL ",message)
	if not ok: failures+=1
func frames(n:=3) -> void:
	for i in n: await process_frame
func close() -> void:
	world.dialogue._close()
	await frames()
func enter(map: String) -> void:
	await close()
	world.load_map(map,"start")
	await frames(6)
	world.player.invuln=1000
func object(kind: String,id: String="") -> Node2D:
	for node in get_nodes_in_group("regional_objects"):
		if not node.is_queued_for_deletion() and node.kind==kind and (id=="" or node.obj.get("id","")==id): return node
	return null
func director() -> Node:
	for node in get_nodes_in_group("regional_director"):
		if not node.is_queued_for_deletion(): return node
	return null
func key(pad:=false,button:=JOY_BUTTON_A) -> void:
	for down in [true,false]:
		if pad:
			var event:=InputEventJoypadButton.new()
			event.button_index=button
			event.pressed=down
			Input.parse_input_event(event)
		else:
			var event:=InputEventKey.new()
			event.keycode=KEY_E
			event.physical_keycode=KEY_E
			event.pressed=down
			Input.parse_input_event(event)
		await frames(2)
func use(node: Node2D,pad:=false) -> void:
	world.player.position=node.position+Vector2(0,32)
	await frames(5)
	world.player._update_target()
	if world.player.target!=node: print("target mismatch ",node.position," player ",world.player.position," target ",world.player.target," lock ",gs.input_locked())
	check(world.player.target==node,"player can target "+node.kind)
	await key(pad)
func choose(index: int,pad:=false) -> void:
	for i in 100:
		if not world.dialogue.active or not world.dialogue.buttons.is_empty(): break
		await key(pad)
	check(world.dialogue.buttons.size()>index,"dialogue choice exists")
	if world.dialogue.buttons.size()<=index: return
	world.dialogue.buttons[index].grab_focus()
	await frames()
	await key(pad)
	await frames()
func grid() -> AStarGrid2D:
	var nav:=AStarGrid2D.new()
	nav.region=Rect2i(Vector2i.ZERO,world.map_size)
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	nav.update()
	for y in world.map_size.y:
		for x in world.map_size.x: nav.set_point_solid(Vector2i(x,y),world.is_solid(Vector2(x+0.5,y+0.5)*32))
	for spec: Dictionary in world.map_data.objects:
		if spec.type in ["regional_object","npc","chest","sign","profession_resource","living_object"]:
			nav.set_point_solid(Vector2i(spec.pos[0],spec.pos[1]))
	return nav
func audit() -> void:
	var nav:=grid()
	var start:=Vector2i(world.player.position/32)
	for node in get_nodes_in_group("regional_objects"):
		var cell:=Vector2i(node.position/32)
		check(not world.is_solid(node.position),"object on walkable tile: "+node.label())
		var reachable:=false
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var end: Vector2i=cell+step
			if nav.is_in_boundsv(end) and not nav.is_point_solid(end) and not nav.get_id_path(start,end).is_empty(): reachable=true
		check(reachable,"reachable: "+node.label())
		for spec: Dictionary in world.map_data.objects:
			if spec.type in ["npc","chest","sign","profession_resource","living_object","portal"]:
				check(cell!=Vector2i(spec.pos[0],spec.pos[1]),"no object overlap: "+node.label())
	for spec: Dictionary in world.map_data.objects:
		if spec.type=="portal":
			check(Maps.get_map(spec.to).spawns.has(spec.get("spawn","start")),"portal return spawn exists")
func walk_to(cell: Vector2i) -> void:
	var nav:=grid()
	var path:=nav.get_id_path(Vector2i(world.player.position/32),cell)
	check(not path.is_empty(),"walk path exists")
	for point in path:
		var goal: Vector2=(Vector2(point)+Vector2(0.5,0.5))*32
		for i in 90:
			var offset: Vector2=goal-world.player.position
			for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
			if offset.length()<4: break
			if absf(offset.x)>2: Input.action_press("move_right" if offset.x>0 else "move_left")
			if absf(offset.y)>2: Input.action_press("move_down" if offset.y>0 else "move_up")
			await physics_frame
		if world.player.position.distance_to(goal)>10: break
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	check(world.player.position.distance_to((Vector2(cell)+Vector2(0.5,0.5))*32)<10,"real walking reaches "+str(cell))

func run() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-") and OS.get_environment("XDG_DATA_HOME")=="":
		quit(1)
		return
	await frames()
	gs=root.get_node("GameState")
	gs.new_game()
	gs.in_game=true
	world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await frames(40)
	for map in ["dorstvallei","sunwell","ridgepass","reedvault","kruipmoeras"]:
		await enter(map)
		audit()
	await enter("dorstvallei")
	await use(object("water"))
	check(gs.count("ra_waterskin")==1 and gs.flag("ra_prepared"),"keyboard water preparation")
	await close()
	await use(object("water"),true)
	check(gs.count("ra_waterskin")==1,"refill does not duplicate equipment")
	await close()
	world.player.position=Vector2(24.5,4.5)*32
	await frames(3)
	world.player.position=Vector2(24.5,3.5)*32
	await frames(90)
	check(gs.map_id=="sunwell","walk-through entrance really opens the gorge")
	world.player.position=Vector2(4.5,21.5)*32
	await frames(90)
	check(gs.map_id=="dorstvallei" and not world.is_solid(world.player.position),"gorge return uses a clear spawn")
	await enter("sunwell")
	var route:=director()
	check(route.panel.size.y<80,"expedition meter remains compact")
	check(not route.panel.get_global_rect().intersects(world.hud.tracker_panel.get_global_rect()),"expedition meter does not overlap quest tracker")
	await use(object("refill"),true)
	check(route.water==3,"controller refills water")
	world.player.position=Vector2(5.5,11.5)*32
	route.advance(10)
	check(route.water==2,"heat automatically uses water")
	var retained: int=gs.hp
	route.water=0
	route.advance(10)
	check(world.player.position==route.last_shelter and gs.hp==retained,"empty water returns safely without health loss")
	route.heat=4
	route.advance(1)
	check(route.heat<4,"shelter cools the player")
	await walk_to(Vector2i(15,6))
	await use(object("refill", "")) # first refill; restart whole physical route below
	world.player.position=Vector2(15.5,6.5)*32
	route.refill(world.player.position)
	await walk_to(Vector2i(28,19))
	route.refill(world.player.position)
	await walk_to(Vector2i(34,6))
	await use(object("spring"),true)
	check(not route.panel.visible,"expedition meter hides while dialogue is open")
	await choose(0,true)
	await close()
	check(gs.flag("ra_spring") and gs.flag("ra_water_wild"),"controller restores spring for wildlife")
	var xp: int=gs.hero_xp
	await use(object("spring"))
	await choose(1)
	await close()
	check(gs.flag("ra_water_caravan") and not gs.flag("ra_water_wild") and gs.hero_xp==xp,"water choice reversible without duplicate reward")
	await enter("dorstvallei")
	gs.start_dialogue("sana_klaar")
	for i in 30:
		if not world.dialogue.active: break
		await key()
	check(gs.quest_state("cactusvijgen")=="done","spring quest keeps old save ID and finishes at Sana")
	await enter("ridgepass")
	world.load_map("ridgepass","start",Vector2(14.5,18.5)*32)
	await frames(5)
	check(not world.is_solid(world.player.position),"old save on removed bypass relocates to safe snow")
	await use(object("camp"))
	await close()
	check(gs.flag("ra_rope_kit"),"camp lends climbing rope")
	route=director()
	route.time=8.1
	world.player.position=Vector2(11.5,6.5)*32
	route.advance(0.7)
	check(world.player.position.x<10*32,"wind returns exposed climber to safe side")
	route.time=0
	world.player.position=Vector2(9.5,6.5)*32
	await walk_to(Vector2i(18,6))
	await use(object("anchor"),true)
	check(gs.flag("ra_rope"),"controller secures permanent rope")
	route.time=8.1
	world.player.position=Vector2(12.5,6.5)*32
	route.advance(0.7)
	check(world.player.position.x>10*32,"secured rope protects during gust")
	await use(object("chart"))
	await close()
	await use(object("camp"))
	await close()
	check(gs.quest_state("ra_ridge")=="done" and gs.count("gear_ra_grip")==1,"chart returned and climbing gloves awarded")
	xp=gs.hero_xp
	await use(object("camp"))
	await close()
	check(gs.hero_xp==xp,"no repeat expedition XP")
	check(Equipment.equip("gear_ra_grip"),"new gloves equip in existing hand slot")
	await enter("reedvault")
	await use(object("desk"))
	check(not gs.flag("ra_archive_done"),"archive requires evidence")
	await close()
	for id in ["ra_folio_reed","ra_folio_port","ra_folio_flood"]:
		await use(object("folio",id))
		await close()
	await use(object("desk"),true)
	await choose(1,true)
	await close()
	check(not gs.flag("ra_archive_done"),"wrong chronology preserves clues without award")
	await use(object("desk"),true)
	await choose(0,true)
	await choose(1,true)
	await close()
	check(gs.flag("ra_archive_done") and not gs.flag("ra_exhibit_routes"),"controller reconstructs archive and chooses stories")
	check(gs.count("gear_ra_compass")==1,"archive reward awarded once")
	xp=gs.hero_xp
	await enter("kruipmoeras")
	await use(object("exhibit"))
	await choose(0)
	await close()
	check(gs.flag("ra_exhibit_routes") and gs.hero_xp==xp,"exhibition changes at Mees without new XP")
	check(gs.save_game(world.player.position) and gs.load_game(),"save and reload")
	check(gs.flag("ra_spring") and gs.flag("ra_rope") and gs.flag("ra_archive_done"),"regional world changes persist")
	check(gs.count("gear_ra_grip")==1 and gs.count("gear_ra_compass")==1,"reward gear survives normalization")
	gs.new_game()
	gs.start_quest("cactusvijgen")
	gs.finish_quest("cactusvijgen")
	xp=gs.hero_xp
	Region.migrate()
	check(gs.flag("ra_spring") and gs.flag("ra_water_wild") and gs.hero_xp==xp,"legacy completed quest receives world consequence only")
	gs.new_game()
	gs.start_quest("cactusvijgen")
	gs.quests.cactusvijgen.step=1
	Region.migrate()
	check(gs.quest_step("cactusvijgen")==0,"legacy active quest restarts at preparation without losing items")
	world.queue_free()
	await frames()
	print("REGIONAL OK" if failures==0 else "REGIONAL FAILED: %d"%failures)
	quit(0 if failures==0 else 1)
