extends SceneTree
const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Living := preload("res://scripts/core/living_world.gd")
const Equipment := preload("res://scripts/core/equipment.gd")
const Professions := preload("res://scripts/core/professions.gd")
var gs: Node
var world: Node2D
var failures := 0

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("  ok   " if ok else "  FAIL ",message)
	if not ok: failures += 1
func frames(n := 3) -> void:
	for i in n:
		await process_frame
		await physics_frame
func node(id: String) -> Node2D:
	for n: Node2D in get_nodes_in_group("living_objects"):
		if n.id == id and not n.is_queued_for_deletion(): return n
	return null
func press(action: String) -> void:
	for down in [true,false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		root.push_input(e)
func interact(n: Node2D) -> void:
	world.player.global_position = n.global_position + Vector2(0,24)
	world.player.invuln = 999
	await frames()
	world.player._update_target()
	check(world.player.target == n,"apparaat bereikbaar via normale interactie: " + n.id)
	press("interact")
	await frames()
func dialogue(pick := -1) -> void:
	for i in 120:
		if not world.dialogue.active: return
		if not world.dialogue.buttons.is_empty():
			world.dialogue.buttons[pick if pick >= 0 else world.dialogue.buttons.size()-1].pressed.emit()
		else: press("interact")
		await frames(1)
	check(false,"gesprek moet eindigen")
func load_map(id: String) -> void:
	if world.dialogue.active: world.dialogue._close()
	world.load_map(id,"start")
	world.player.invuln = 999
	await frames(4)
func reachability() -> void:
	for id in ["prismamine","dauwbos","ijsdal","kruipmoeras","mistgarden","ridgepass","reedvault"]:
		var data: Dictionary = Maps.get_map(id)
		var rows: Array = data["rows"]
		var start := Vector2i(data["spawns"]["start"][0],data["spawns"]["start"][1])
		var seen := {start:true}
		var queue := [start]
		var blocked := {}
		for o: Dictionary in data["objects"]:
			if o["type"] in ["npc","chest","sign"]: blocked[Vector2i(o["pos"][0],o["pos"][1])] = true
		while not queue.is_empty():
			var at: Vector2i = queue.pop_front()
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var p: Vector2i = at+d
				if p.y<0 or p.y>=rows.size() or p.x<0 or p.x>=rows[p.y].length() or seen.has(p) or blocked.has(p): continue
				if not Tiles.is_solid_char(rows[p.y][p.x]):
					seen[p] = true
					queue.append(p)
		for o: Dictionary in data["objects"]:
			var at_ground := Vector2i(o["pos"][0],o["pos"][1])
			if o["type"] == "living_object" or id in ["mistgarden","ridgepass","reedvault"] or (o["type"] == "sign" and str(o.get("lines",[])).contains("lichtpad")):
				check(not Tiles.is_solid_char(rows[at_ground.y][at_ground.x]), id+": nieuw object staat op vrije grond")
			if o["type"] not in ["living_object","portal","chest","profession_resource"]: continue
			var at := Vector2i(o["pos"][0],o["pos"][1])
			var reachable := seen.has(at)
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]: reachable = reachable or seen.has(at+d)
			check(reachable,id+": bereikbaar "+str(o.get("id",o["type"])))

func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.new_game()
	gs.in_game = true
	gs.weapon = "iron"
	reachability()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(8)
	await load_map("prismamine")
	await interact(node("lw_core"))
	check(not world.dialogue.active and not gs.flag("lw_mine"),"kern weigert verkeerd gericht licht")
	await interact(node("lw_mirror_b"))
	await interact(node("lw_mirror_c"))
	await interact(node("lw_mirror_c"))
	check(Living.beams_ready(),"spiegels vormen een doorlopend lichtpad")
	gs.give("lw_powder",1,true)
	await interact(node("lw_core"))
	await dialogue(1)
	check(gs.flag("lw_mine") and gs.count("lw_lens")==1 and gs.count("lw_powder")==0,"alchemie stabiliseert kern en verbruikt precies één poeder")
	node("lw_core").choose("core_powder")
	check(gs.count("lw_lens")==1,"kernbeloning is eenmalig")
	await load_map("smithy")
	await interact(node("lw_forge"))
	await dialogue()
	check(gs.flag("lw_workshop") and gs.quest_state("prisma_herstel")=="done","mijn ontsluit werkplaats en techniek")
	gs.give("prof_branch",2,true)
	check(Professions.craft("prism_lantern"),"lantaarn is echt te craften op niveau 1")
	check(gs.quest_state("lichtwerk")=="done" and gs.quest_state("mistsporen")=="active","crafting verbindt de opdrachten")
	await load_map("dauwbos")
	for id in ["lw_water","lw_root","lw_star"]:
		await interact(node(id))
		await dialogue()
	check(gs.flag("lw_clues"),"drie fysieke aanwijzingen onthuld")
	await interact(node("lw_star"))
	check(not gs.flag("lw_forest"),"verkeerde runevolgorde geeft geen beloning")
	for id in ["lw_water","lw_root","lw_star"]: await interact(node(id))
	check(gs.flag("lw_forest") and gs.count("gear_scout_coat")==1,"correcte volgorde opent tuin en geeft jas")
	await frames()
	for resource in get_nodes_in_group("profession_resources"):
		if resource.key == "lw_revealed_flower":
			check(not world.is_solid(resource.position), "onthulde bloem groeit op de oever, niet in water")
	var before: int = gs.hero_xp
	await interact(node("lw_star"))
	check(gs.hero_xp==before,"herhaalde rune geeft geen extra XP")
	await load_map("ijsdal")
	for id in ["lw_heat_west","lw_heat_east"]:
		var fire := node(id)
		await interact(fire)
		await dialogue(0) # prismatechniek is de eerste beschikbare keuze zonder hout of voedsel
		check(fire.active and fire.warning>0,"verdediging start met spawnwaarschuwing")
		fire.set_process(false)
		fire._process(2.1)
		check(fire.foes.size()==2,"vuurkorf heeft twee aanvallers")
		for foe in fire.foes: foe.set_physics_process(false)
		fire.foes[0].global_position = fire.global_position
		var elapsed: float = fire.elapsed
		fire._process(3)
		check(fire.elapsed==elapsed,"aanvaller bij vlam blokkeert opwarming")
		for foe in fire.foes:
			foe.dead = true
			foe.queue_free()
		await frames()
		world.player.global_position = fire.global_position+Vector2(0,250)
		fire._process(21)
		check(not gs.flag(id),"weglopen voltooit geen verdediging")
		world.player.global_position = fire.global_position+Vector2(0,28)
		fire._process(21)
		check(gs.flag(id),"opwarmen en verdedigen herstelt huis")
	check(gs.flag("lw_heat") and gs.quest_step("warmte")==1,"beide huizen ontsluiten bergpas en inleverstap")
	await frames()
	check(get_nodes_in_group("living_residents").size()==2,"twee bewoners verschijnen buiten de huizen")
	for resident in get_nodes_in_group("living_residents"):
		check(resident is CharacterBody2D and resident.get_parent()==world.entities and not world.is_solid(resident.position),"bewoner heeft botsing en y-sortering op vrije grond")
		for npc in get_nodes_in_group("npc"):
			check(resident.position.distance_to(npc.position)>32,"bewoner overlapt geen bestaande NPC")
	await load_map("kruipmoeras")
	gs.give("lw_bridge_kit",1,true)
	await interact(node("lw_bridge_control"))
	await dialogue(0)
	check(gs.count("lw_bridge_kit")==1 and not gs.flag("lw_bridge"),"te hoge waterdruk verbruikt geen bouwpakket")
	await interact(node("lw_sluice_west"))
	await interact(node("lw_sluice_east"))
	check(not gs.flag("lw_drained"),"beide sluizen open is geen veilige oplossing")
	await interact(node("lw_sluice_east"))
	check(gs.flag("lw_drained") and not world.is_solid(Vector2(30.5,16.5)*32),"waterdaling wijzigt echte botsing")
	await interact(node("lw_bridge_control"))
	await dialogue(0)
	check(gs.flag("lw_bridge") and gs.count("lw_bridge_kit")==0,"brugonderdelen repareren één keer")
	await frames()
	check(not world.is_solid(Vector2(20.5,16.5)*32),"herstelde brug is beloopbaar")
	gs.save_game(world.player.global_position)
	gs.flags.clear()
	check(gs.load_game(),"opslag met wereldherstel laadt")
	await load_map("kruipmoeras")
	check(gs.flag("lw_bridge") and gs.flag("lw_forest") and gs.flag("lw_heat") and not world.is_solid(Vector2(20.5,16.5)*32),"alle wereldgevolgen blijven na laden bestaan")
	# Uitrusting is een keuze: snelheid versus pantser, alleen gedragen effecten tellen.
	gs.give("gear_bastion_coat",1,true)
	Equipment.equip("gear_scout_coat")
	check(gs.speed_multiplier()>1 and Equipment.bonus("armor")==0,"verkennersjas heeft snelheid zonder pantser")
	Equipment.equip("gear_bastion_coat")
	check(gs.speed_multiplier()<1 and Equipment.bonus("armor")==2,"wachtharnas ruilt snelheid in voor pantser")
	Equipment.unequip("chest")
	check(is_equal_approx(gs.speed_multiplier(),1),"uitdoen verwijdert voor- en nadelen")
	# Migratie behoudt eenmalige beloningen en erkent afgeronde oude quests.
	gs.new_game()
	gs.start_quest("warmte")
	gs.finish_quest("warmte")
	gs.start_quest("wilgentwijgen")
	gs.finish_quest("wilgentwijgen")
	before = gs.hero_xp
	Living.migrate()
	Living.migrate()
	check(gs.flag("lw_heat") and gs.flag("lw_bridge") and gs.hero_xp==before,"oude afgeronde quests migreren zonder dubbele XP")
	world.queue_free()
	await frames()
	print("LIVING WORLD OK" if failures==0 else "LIVING WORLD FAILED: %d" % failures)
	quit(0 if failures==0 else 1)
