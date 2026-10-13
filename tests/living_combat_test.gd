extends SceneTree
const Living := preload("res://scripts/core/living_world.gd")
const Professions := preload("res://scripts/core/professions.gd")
var gs: Node
var world: Node2D
var ai: Script
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, text: String) -> void:
	print("  ok   " if ok else "  FAIL ",text)
	if not ok: failures += 1
func frames(n := 3) -> void:
	for i in n:
		await process_frame
		await physics_frame
func find(id: String) -> Node2D:
	for n in get_nodes_in_group("living_objects"):
		if n.id==id and not n.is_queued_for_deletion(): return n
	return null
func kill_encounter(n: Node2D) -> void:
	for foe in n.foes:
		foe.break_guard()
		foe.hurt(999,Vector2.RIGHT)
	await frames(8)
	n._process(0.1)
func _run() -> void:
	await process_frame
	gs=root.get_node("GameState")
	ai=load("res://scripts/entities/living_enemy.gd")
	gs.new_game()
	gs.in_game=true
	gs.weapon="iron"
	world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	await frames(6)
	world.load_map("prismamine","start")
	await frames()
	world.player.invuln=999
	world.player.set_physics_process(false)
	Living.turn("lw_mirror_b")
	Living.turn("lw_mirror_c")
	Living.turn("lw_mirror_c")
	var core:=find("lw_core")
	core.set_process(false)
	world.player.global_position=core.global_position+Vector2(0,28)
	core.choose("core_fight")
	check(core.active and core.foes.is_empty(),"combatkeuze geeft eerst waarschuwing")
	for at in core.spawn_positions():check(not world.is_solid(at),"kernbewaker verschijnt op vrije tegel")
	world.player.global_position=core.spawn_positions()[0]
	core._process(3)
	check(core.foes.is_empty(),"geen vijand verschijnt bovenop de speler")
	world.player.global_position=core.global_position+Vector2(0,28)
	core._process(0.1)
	check(core.foes.size()==2,"kern start echte verdediger en genezer")
	for f in core.foes:f.set_physics_process(false)
	var guard:Node2D=core.foes[0]
	var singer:Node2D=core.foes[1]
	guard.aim_dir=Vector2.DOWN
	var hp:int=guard.hp
	guard.hurt(2,Vector2.UP)
	check(guard.hp==hp,"schild blokkeert een frontale slag")
	guard.hurt(1,Vector2.DOWN)
	check(guard.hp==hp-1,"flankeren werkt zonder ontgrendelde techniek")
	singer.global_position=guard.global_position+Vector2(40,0)
	singer.player=world.player
	singer.state="lw_song"
	singer.state_time=1.1
	ai.update(singer,0.1)
	check(guard.hp==hp,"genezer helpt een gewonde bondgenoot")
	guard.hp=hp-1
	singer.state="lw_song"
	singer.state_time=0.9
	singer.hurt(1,Vector2.RIGHT)
	ai.update(singer,0.1)
	check(singer.state!="lw_song" and guard.hp==hp-1,"zwaard onderbreekt genezing")
	# Dezelfde aanvalsknop leert na de werkplaats een nuttige techniek.
	gs.set_flag("lw_workshop")
	gs.movement.reset()
	world.player.global_position=guard.global_position+Vector2(0,30)
	world.player.facing=Vector2.UP
	root.get_node("Controls").mouse_aim_active=false
	world.player.combo_step=2
	world.player.combo_window=0.8
	world.player.cooldown=0
	world.player._attack()
	check(guard.guard_broken>0 and guard.hp<hp-1,"derde comboslag breekt het schild met echte zwaardinput")
	await kill_encounter(core)
	check(gs.flag("lw_mine") and gs.count("lw_lens")==1,"gevechtsoplossing geeft dezelfde blijvende kern")
	core.choose("core_fight")
	check(not core.active,"afgeronde kern kan geen herhaalbeloningen spawnen")
	world.load_map("smithy","start")
	await frames()
	var forge:=find("lw_forge")
	gs.hero_xp=0 # geen losse level-up-munten tijdens de controle op de koopprijs
	gs.coins=40
	forge.choose("buy_lantern")
	check(gs.coins==0 and gs.count("lw_lantern")==1,"Greta’s alternatief vereist geen ambachtsniveau")
	forge.choose("buy_lantern")
	check(gs.coins==0 and gs.count("lw_lantern")==1,"kopen kan niet dubbel afschrijven")
	world.load_map("dauwbos","start")
	await frames()
	world.player.global_position=Vector2(20.5,20.5)*32
	var stalker:Node2D=world.spawn_enemy("lw_stalker",world.player.global_position+Vector2(50,0))
	stalker.player=world.player
	stalker.set_physics_process(false)
	ai.update(stalker,0.1)
	check(stalker.desired.x>0,"mistjager wijkt van de lantaarn terug")
	gs.take("lw_lantern")
	stalker.global_position=world.player.global_position+Vector2(130,0)
	stalker.state_time=2
	ai.update(stalker,0.1)
	check(stalker.state=="lw_warn","zonder licht kondigt de mistjager zijn uitval aan")
	world.load_map("kruipmoeras","start")
	await frames()
	var bridge:=find("lw_bridge_control")
	bridge.set_process(false)
	gs.set_flag("lw_drained")
	world.player.global_position=bridge.global_position+Vector2(0,28)
	bridge.choose("bridge_fight")
	for at in bridge.spawn_positions():check(not world.is_solid(at),"lierbewaker verschijnt op vrije tegel")
	bridge._process(3)
	check(bridge.foes.size()==2,"lier biedt een gevechtsoplossing zonder materialen")
	await kill_encounter(bridge)
	check(gs.flag("lw_bridge"),"bewakers verslaan herstelt de oversteek")
	# Tweede avontuur: de alchemieroute gebruikt de hars precies eenmaal.
	gs.new_game()
	gs.in_game=true
	world.load_map("kruipmoeras","start")
	await frames()
	gs.set_flag("lw_drained")
	gs.give("lw_resin",1,true)
	bridge=find("lw_bridge_control")
	bridge.choose("bridge_resin")
	bridge.choose("bridge_resin")
	check(gs.flag("lw_bridge") and gs.count("lw_resin")==0,"hars biedt een zelfstandige, eenmalige oplossing")
	gs.new_game()
	check(Professions.craft_reason("prism_lantern")!="","recept is voor herstel echt vergrendeld")
	gs.start_quest("warmte")
	gs.set_quest_step("warmte",1)
	gs.give("prof_ijsbloem",4,true)
	Living.migrate()
	check(gs.quest_state("warmte")=="active" and gs.quest_step("warmte")==0 and gs.count("prof_ijsbloem")==4,"oude lopende opdracht behoudt materialen en krijgt nieuw doel")
	world.queue_free()
	await frames()
	print("LIVING COMBAT OK" if failures==0 else "LIVING COMBAT FAILED: %d"%failures)
	quit(0 if failures==0 else 1)
